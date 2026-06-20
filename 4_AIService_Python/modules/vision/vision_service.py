import base64
import hashlib
import json
import logging
import math
from pathlib import Path
import time
from typing import Any
from uuid import uuid4

import httpx
from config import settings

logger = logging.getLogger(__name__)
audit_logger = logging.getLogger("vision_debug")
trace_logger = logging.getLogger("vision_vector_trace")

_AI_SERVICE_ROOT = Path(__file__).resolve().parents[2]
_VISION_DEBUG_LOG = _AI_SERVICE_ROOT / "vision_debug.log"
_VISION_VECTOR_TRACE_LOG = _AI_SERVICE_ROOT / "vision_vector_trace.jsonl"

if not audit_logger.handlers:
    _VISION_DEBUG_LOG.parent.mkdir(parents=True, exist_ok=True)
    handler = logging.FileHandler(_VISION_DEBUG_LOG, encoding="utf-8")
    handler.setFormatter(logging.Formatter("%(asctime)s %(message)s"))
    audit_logger.addHandler(handler)
    audit_logger.setLevel(logging.INFO)
    audit_logger.propagate = False

if not trace_logger.handlers:
    _VISION_VECTOR_TRACE_LOG.parent.mkdir(parents=True, exist_ok=True)
    trace_handler = logging.FileHandler(_VISION_VECTOR_TRACE_LOG, encoding="utf-8")
    trace_handler.setFormatter(logging.Formatter("%(message)s"))
    trace_logger.addHandler(trace_handler)
    trace_logger.setLevel(logging.INFO)
    trace_logger.propagate = False


_UNRECOGNIZED_RESULT = {
    "recognized": False,
    "building_name": "未能识别",
    "description": "这张图片没有匹配到可确认的西南大学校园建筑。请上传清晰的校内建筑、校门或楼宇铭牌照片；如果是风景、瀑布、人物、截图等非校园建筑图片，系统不会强行猜测。",
    "fallback": True,
}

_DENYLIST_NAMES = {"光华楼"}
_CLIP_REVIEW_THRESHOLD = 0.45
_CLIP_AUTO_ACCEPT_THRESHOLD = 0.18
_CLIP_AUTO_ACCEPT_MARGIN = 0.12
_BUILDING_ALIASES = {
    "袁隆平": "袁隆平雕像",
    "袁隆平像": "袁隆平雕像",
    "袁隆平雕塑": "袁隆平雕像",
}
_CANONICAL_DESCRIPTIONS = {
    "袁隆平雕像": "“袁隆平雕像”位于西南大学校园内，用以纪念学校杰出校友袁隆平先生。袁隆平是世界杂交水稻研究的重要开拓者、中国工程院院士，雕像承载着学校农学传统、校友情感和科学报国精神。",
}
_VISIBLE_TEXT_HINTS = {
    "中心图书馆": "中心图书馆",
    "中国共产党西南大学委员会": "行署楼A栋",
    "西南大学纪律检查委员会": "行署楼A栋",
    "中国共产党西南大学纪律检查委员会": "行署楼A栋",
}


def _audit(request_id: str, event: str, **payload: Any) -> None:
    """Write a structured vision debug event without storing raw image data."""
    safe_payload = {"request_id": request_id, "event": event, **payload}
    try:
        audit_logger.info(json.dumps(safe_payload, ensure_ascii=False, default=str))
    except Exception as exc:
        logger.warning("写入视觉识别调试日志失败: %s", exc)


def _trace(request_id: str, stage: str, **payload: Any) -> None:
    """Write JSONL evidence for CLIP vector search, Qwen review, and RAG verification."""
    safe_payload = {
        "request_id": request_id,
        "stage": stage,
        "timestamp_ms": int(time.time() * 1000),
        **payload,
    }
    try:
        trace_logger.info(json.dumps(safe_payload, ensure_ascii=False, default=str))
    except Exception as exc:
        logger.warning("写入视觉向量追踪日志失败: %s", exc)


def _vector_summary(vector: list[float], sample_size: int = 16) -> dict[str, Any]:
    """Summarize a high-dimensional vector without flooding logs with hundreds of values."""
    if not vector:
        return {"dim": 0}
    values = [float(value) for value in vector]
    vector_hash = hashlib.sha256(
        json.dumps([round(value, 8) for value in values], separators=(",", ":")).encode("utf-8")
    ).hexdigest()[:16]
    return {
        "dim": len(values),
        "norm": round(math.sqrt(sum(value * value for value in values)), 6),
        "mean": round(sum(values) / len(values), 6),
        "min": round(min(values), 6),
        "max": round(max(values), 6),
        "sample_first_16": [round(value, 6) for value in values[:sample_size]],
        "sha256_16": vector_hash,
    }


def _normalize_image_base64(image_base64: str) -> str:
    value = (image_base64 or "").strip()
    if value.startswith("data:image") and "," in value:
        return value.split(",", 1)[1].strip()
    return value


def _with_debug(result: dict[str, Any], diagnostics: dict[str, Any]) -> dict[str, Any]:
    result["debug"] = diagnostics
    return result


def _canonical_from_visible_text(visible_text: str) -> str:
    text = visible_text or ""
    for keyword, building_name in _VISIBLE_TEXT_HINTS.items():
        if keyword in text:
            return building_name
    return ""


def _canonical_building_name(building_name: str) -> str:
    normalized = (building_name or "").strip()
    return _BUILDING_ALIASES.get(normalized, normalized)


class VisionService:
    """多模态视觉识别服务 — 基于 Qwen VL 和 CLIP Image RAG"""

    def __init__(self) -> None:
        self._model = settings.VISION_MODEL
        self._base_url = settings.VISION_BASE_URL.rstrip("/")
        self._api_key = settings.VISION_API_KEY
        self._clip_model = None
        self._image_collection = None
        self._clip_loaded = False   # 标记是否已尝试过加载
        self._clip_failed = False   # 标记加载是否失败（避免反复重试）
        # CLIP 模型改为懒加载，不在 __init__ 中阻塞启动

    def _ensure_clip_loaded(self) -> None:
        """懒加载 CLIP 模型和 ChromaDB 图像集合（首次调用时加载）"""
        if self._clip_loaded:
            return
        self._clip_loaded = True
        try:
            import chromadb
            from sentence_transformers import SentenceTransformer
            persist_dir = Path(settings.CHROMA_PERSIST_DIR)
            if not persist_dir.is_absolute():
                persist_dir = Path(__file__).resolve().parents[2] / persist_dir
            client = chromadb.PersistentClient(path=str(persist_dir))
            self._image_collection = client.get_collection("smart_campus_images")
            cache_dir = Path(__file__).resolve().parents[2] / 'models_cache'
            self._clip_model = SentenceTransformer('clip-ViT-B-32', cache_folder=str(cache_dir))
            logger.info("CLIP 模型与 Image RAG 加载成功")
        except Exception as e:
            self._clip_failed = True
            logger.warning("CLIP 模型加载失败，将仅使用 Qwen-VL: %s", e)

    async def recognize_building(
        self,
        image_base64: str,
        request_id: str | None = None,
    ) -> dict[str, Any]:
        """识别校园建筑图片，优先调用 CLIP 图像匹配，再调用 Qwen VL，无 Key 时回退 mock"""

        request_id = request_id or f"vision_{uuid4().hex[:10]}"
        started_at = time.perf_counter()
        image_base64 = _normalize_image_base64(image_base64)
        visual_candidates: list[dict[str, Any]] = []
        image_bytes: bytes | None = None
        diagnostics: dict[str, Any] = {
            "request_id": request_id,
            "model": self._model,
            "vision_base_url": self._base_url,
            "has_api_key": bool(self._api_key),
            "clip_review_threshold": _CLIP_REVIEW_THRESHOLD,
            "clip_auto_accept_threshold": _CLIP_AUTO_ACCEPT_THRESHOLD,
            "clip_auto_accept_margin": _CLIP_AUTO_ACCEPT_MARGIN,
        }

        _audit(
            request_id,
            "request_received",
            base64_length=len(image_base64),
            model=self._model,
            vision_base_url=self._base_url,
            has_api_key=bool(self._api_key),
        )
        _trace(
            request_id,
            "pipeline_start",
            pipeline=["image_decode", "clip_image_embedding", "clip_vector_search", "qwen_vl_review_if_needed", "rag_text_vector_verify"],
            model=self._model,
            clip_model="clip-ViT-B-32",
            vector_backend="ChromaDB",
            image_vector_collection="smart_campus_images",
            text_vector_collection=settings.CHROMA_COLLECTION,
            has_qwen_api_key=bool(self._api_key),
        )

        try:
            image_bytes = base64.b64decode(image_base64, validate=True)
            image_sha = hashlib.sha256(image_bytes).hexdigest()[:16]
            diagnostics["image"] = {
                "base64_length": len(image_base64),
                "byte_length": len(image_bytes),
                "sha256": image_sha,
            }
            _audit(
                request_id,
                "image_decoded",
                byte_length=len(image_bytes),
                sha256=image_sha,
            )
            _trace(
                request_id,
                "image_decoded",
                image={
                    "base64_length": len(image_base64),
                    "byte_length": len(image_bytes),
                    "sha256_16": image_sha,
                },
            )
        except Exception as exc:
            _audit(request_id, "image_decode_failed", error=str(exc))
            diagnostics["decision"] = "图片 base64 解码失败，未进入 CLIP/Qwen 识别。"
            result = {
                **_UNRECOGNIZED_RESULT,
                "request_id": request_id,
                "reason": f"图片 base64 解码失败：{exc}",
            }
            _with_debug(result, diagnostics)
            _audit(
                request_id,
                "final_result",
                elapsed_ms=round((time.perf_counter() - started_at) * 1000, 2),
                result=result,
            )
            return result

        # 1. 真正的 Visual RAG: 图像向量直接匹配（懒加载 CLIP 模型）
        self._ensure_clip_loaded()
        if self._clip_model and self._image_collection:
            try:
                import io
                from PIL import Image
                img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
                _audit(
                    request_id,
                    "clip_image_loaded",
                    image_width=img.width,
                    image_height=img.height,
                    image_mode=img.mode,
                )
                diagnostics.setdefault("image", {}).update({
                    "width": img.width,
                    "height": img.height,
                    "mode": img.mode,
                })
                
                # 提取用户上传图片的视觉特征向量
                img_embedding = self._clip_model.encode(img, normalize_embeddings=True).tolist()
                clip_vector_summary = _vector_summary(img_embedding)
                diagnostics.setdefault("clip", {})["query_embedding"] = clip_vector_summary
                _trace(
                    request_id,
                    "clip_image_embedding",
                    model="clip-ViT-B-32",
                    normalized=True,
                    image={
                        "width": img.width,
                        "height": img.height,
                        "mode": img.mode,
                        "sha256_16": diagnostics.get("image", {}).get("sha256"),
                    },
                    query_embedding=clip_vector_summary,
                )
                
                # 在 ChromaDB 中进行视觉相似度检索
                results = self._image_collection.query(
                    query_embeddings=[img_embedding],
                    n_results=5,
                    include=["metadatas", "distances"]
                )
                
                if results['distances'] and results['distances'][0]:
                    for metadata, dist in zip(results['metadatas'][0], results['distances'][0]):
                        visual_candidates.append({
                            "title": metadata.get("title", ""),
                            "distance": round(float(dist), 4),
                            "source_file": metadata.get("source_file", ""),
                            "category": metadata.get("category", ""),
                        })
                    diagnostics["clip"] = {
                        "available": True,
                        "review_threshold": _CLIP_REVIEW_THRESHOLD,
                        "auto_accept_threshold": _CLIP_AUTO_ACCEPT_THRESHOLD,
                        "auto_accept_margin": _CLIP_AUTO_ACCEPT_MARGIN,
                        "query_embedding": clip_vector_summary,
                        "top_candidates": visual_candidates,
                    }
                    dist = results['distances'][0][0]
                    second_dist = (
                        results['distances'][0][1]
                        if len(results['distances'][0]) > 1
                        else None
                    )
                    margin = (
                        float(second_dist) - float(dist)
                        if second_dist is not None
                        else None
                    )
                    metadata = results['metadatas'][0][0]
                    logger.info("CLIP Top-1 匹配: %s (距离: %s)", metadata['title'], dist)
                    _audit(
                        request_id,
                        "clip_candidates",
                        top_candidates=visual_candidates,
                        top1_title=metadata.get("title", ""),
                        top1_distance=round(float(dist), 6),
                        second_distance=round(float(second_dist), 6) if second_dist is not None else None,
                        margin=round(margin, 6) if margin is not None else None,
                        review_threshold=_CLIP_REVIEW_THRESHOLD,
                        auto_accept_threshold=_CLIP_AUTO_ACCEPT_THRESHOLD,
                        auto_accept_margin=_CLIP_AUTO_ACCEPT_MARGIN,
                    )
                    _trace(
                        request_id,
                        "clip_vector_search",
                        collection="smart_campus_images",
                        top_k=5,
                        metric_note="ChromaDB distance; lower distance means more similar",
                        query_embedding=clip_vector_summary,
                        candidates=[
                            {
                                "rank": idx + 1,
                                **candidate,
                            }
                            for idx, candidate in enumerate(visual_candidates)
                        ],
                        top1_distance=round(float(dist), 6),
                        second_distance=round(float(second_dist), 6) if second_dist is not None else None,
                        margin=round(margin, 6) if margin is not None else None,
                        thresholds={
                            "review_threshold": _CLIP_REVIEW_THRESHOLD,
                            "auto_accept_threshold": _CLIP_AUTO_ACCEPT_THRESHOLD,
                            "auto_accept_margin": _CLIP_AUTO_ACCEPT_MARGIN,
                        },
                    )
                    
                    auto_accept = (
                        float(dist) <= _CLIP_AUTO_ACCEPT_THRESHOLD
                        and (
                            margin is None
                            or margin >= _CLIP_AUTO_ACCEPT_MARGIN
                        )
                    )
                    if auto_accept:
                        logger.info(
                            "[MATCH] 距离 %.4f 且候选间距足够，判定为高置信同一目标！",
                            float(dist),
                        )
                        diagnostics["decision"] = (
                            f"CLIP Top-1 距离 {float(dist):.4f} 小于阈值 "
                            f"{_CLIP_AUTO_ACCEPT_THRESHOLD:.2f}"
                            f"{'' if margin is None else f'，与第二名差距 {margin:.4f}'}，直接采用图像向量库结果。"
                        )
                        raw_title = metadata.get("title", "")
                        canonical_title = _canonical_building_name(raw_title)
                        description = (
                            metadata.get("answer", "")
                            or _CANONICAL_DESCRIPTIONS.get(canonical_title, "")
                        )
                        if raw_title != canonical_title:
                            diagnostics["canonicalized"] = {
                                "raw_title": raw_title,
                                "canonical_title": canonical_title,
                            }
                            _audit(
                                request_id,
                                "clip_title_canonicalized",
                                raw_title=raw_title,
                                canonical_title=canonical_title,
                            )
                        result = {
                            "recognized": True,
                            "building_name": canonical_title,
                            "description": description,
                            "request_id": request_id,
                            "match_source": "clip",
                            "clip_top1_distance": round(float(dist), 6),
                            "reason": diagnostics["decision"],
                        }
                        _with_debug(result, diagnostics)
                        _audit(
                            request_id,
                            "clip_match",
                            elapsed_ms=round((time.perf_counter() - started_at) * 1000, 2),
                            result=result,
                        )
                        _trace(
                            request_id,
                            "decision",
                            source="clip",
                            accepted=True,
                            reason=diagnostics["decision"],
                            result={
                                "recognized": result["recognized"],
                                "building_name": result["building_name"],
                                "match_source": result["match_source"],
                                "clip_top1_distance": result["clip_top1_distance"],
                            },
                        )
                        _audit(
                            request_id,
                            "final_result",
                            elapsed_ms=round((time.perf_counter() - started_at) * 1000, 2),
                            result=result,
                        )
                        return result
                    else:
                        logger.info(
                            "[REVIEW] CLIP 未达到自动采纳条件，转交视觉模型复核..."
                        )
                        diagnostics["decision"] = (
                            f"CLIP Top-1 距离 {float(dist):.4f}"
                            f"{'' if margin is None else f'，与第二名差距 {margin:.4f}'}，"
                            "未达到自动采纳条件，继续调用 Qwen-VL。"
                        )
                        _audit(
                            request_id,
                            "clip_needs_review",
                            top1_title=metadata.get("title", ""),
                            top1_distance=round(float(dist), 6),
                            second_distance=round(float(second_dist), 6) if second_dist is not None else None,
                            margin=round(margin, 6) if margin is not None else None,
                            auto_accept_threshold=_CLIP_AUTO_ACCEPT_THRESHOLD,
                            auto_accept_margin=_CLIP_AUTO_ACCEPT_MARGIN,
                        )
                else:
                    diagnostics["clip"] = {
                        "available": True,
                        "review_threshold": _CLIP_REVIEW_THRESHOLD,
                        "auto_accept_threshold": _CLIP_AUTO_ACCEPT_THRESHOLD,
                        "auto_accept_margin": _CLIP_AUTO_ACCEPT_MARGIN,
                        "top_candidates": [],
                    }
                    diagnostics["decision"] = "CLIP 图像向量库没有返回候选，继续调用 Qwen-VL。"
                    _audit(request_id, "clip_empty_result")
            except Exception as e:
                logger.warning("CLIP 匹配异常: %s", e)
                diagnostics["clip"] = {"available": False, "error": str(e)}
                diagnostics["decision"] = "CLIP 图像检索异常，继续调用 Qwen-VL。"
                _audit(request_id, "clip_error", error=str(e))
        else:
            diagnostics["clip"] = {
                "available": False,
                "clip_loaded": self._clip_loaded,
                "clip_failed": self._clip_failed,
                "has_clip_model": bool(self._clip_model),
                "has_image_collection": bool(self._image_collection),
            }
            diagnostics["decision"] = "CLIP 图像向量库不可用，继续调用 Qwen-VL。"
            _audit(
                request_id,
                "clip_unavailable",
                clip_loaded=self._clip_loaded,
                clip_failed=self._clip_failed,
                has_clip_model=bool(self._clip_model),
                has_image_collection=bool(self._image_collection),
            )

        # 2. 如果没有高度匹配的原图，则退化使用 Qwen-VL 大模型“裸眼”识别
        if self._api_key:
            try:
                result = await self._recognize_with_qwen_vl(
                    image_base64,
                    visual_candidates,
                    request_id=request_id,
                )
                result["request_id"] = request_id
                result.setdefault("match_source", "qwen_vl")
                qwen_debug = result.pop("debug", {})
                diagnostics.update(qwen_debug)
                result["debug"] = diagnostics
                _audit(
                    request_id,
                    "final_result",
                    elapsed_ms=round((time.perf_counter() - started_at) * 1000, 2),
                    result=result,
                )
                return result
            except Exception as exc:
                logger.warning("视觉模型调用失败，返回未识别结果：%s", exc)
                diagnostics["qwen"] = {"called": True, "error": str(exc)}
                diagnostics["decision"] = "Qwen-VL 调用失败，返回未识别结果。"
                _audit(request_id, "qwen_call_failed", error=str(exc))

        result = {
            **self._mock_recognize(),
            "request_id": request_id,
        }
        _with_debug(result, diagnostics)
        _audit(
            request_id,
            "final_result",
            elapsed_ms=round((time.perf_counter() - started_at) * 1000, 2),
            result=result,
        )
        return result

    async def scene_qa(self, image_base64: str, question: str) -> str:
        """基于图像的场景问答"""

        if self._api_key:
            try:
                return await self._qa_with_qwen_vl(image_base64, question)
            except Exception as exc:
                logger.warning("Qwen VL 问答失败：%s", exc)

        return self._mock_scene_qa(question)

    async def _recognize_with_qwen_vl(
        self,
        image_base64: str,
        visual_candidates: list[dict[str, Any]] | None = None,
        request_id: str = "",
    ) -> dict[str, Any]:
        """调用 Qwen VL 识别建筑"""

        # 动态加载所有合法建筑名作为候选库
        candidates_str = ""
        try:
            dataset_path = Path(__file__).resolve().parents[2] / 'data' / 'rag_dataset' / 'dataset.json'
            if dataset_path.exists():
                with open(dataset_path, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    candidate_names = list(set(d.get("building_name", "") for d in data if d.get("building_name")))
                    candidates_str = "、".join(candidate_names)
                    _audit(
                        request_id,
                        "candidate_library_loaded",
                        candidate_count=len(candidate_names),
                    )
        except Exception as e:
            logger.warning("无法加载候选建筑列表: %s", e)
            _audit(request_id, "candidate_library_error", error=str(e))

        visual_candidates_text = ""
        if visual_candidates:
            items = [
                f"{idx + 1}. {item['title']}（图像距离 {item['distance']}）"
                for idx, item in enumerate(visual_candidates)
                if item.get("title")
            ]
            if items:
                visual_candidates_text = (
                    "【图像检索候选】上传图片与知识库图片最相似的候选如下，距离越小越相似：\n"
                    + "\n".join(items)
                    + "\n请优先在这些候选中结合图片中的门牌、题字、楼名、建筑形态判断；"
                    "如果图片证据不足，不要被候选误导，仍返回“未能识别”。\n\n"
                )
        text_hints = "\n".join(
            f"- 看到“{visible_text}”文字时，优先核验为“{building_name}”。"
            for visible_text, building_name in _VISIBLE_TEXT_HINTS.items()
        )

        prompt_text = (
            '请识别这张图片中的西南大学校园建筑、校门、雕像或校园文化景观。\n'
            + visual_candidates_text
            + (f'【重要提示】以下是所有西南大学合法的建筑名称（候选库）：{candidates_str}\n\n' if candidates_str else '') +
            '【必须先读图中文字】\n'
            '请先转写图片里能看清的中文/英文文字、牌匾、楼名、机构名称、雕像铭牌，再结合图像检索候选判断。'
            '如果图片文字与候选视觉结果冲突，清晰文字证据优先于纯视觉相似度。\n'
            f'{text_hints}\n\n'
            '要求：\n'
            '1. 只有当图片中出现清晰的西南大学校园建筑、校门、楼宇铭牌、机构牌匾、雕像或校园文化景观，且能和候选库明确对应时，才允许返回名称。\n'
            '2. 如果图片中能读到“中心图书馆”，必须优先识别为“中心图书馆”，不要被相似楼体候选误导。\n'
            '3. 如果图片中能读到“中国共产党西南大学委员会”“西南大学纪律检查委员会”等学校级机关牌匾，应结合候选库优先识别为“行署楼A栋”；单独出现“纪律检查委员会”不能作为行署楼A栋的充分依据，因为学院也可能有纪委牌匾。\n'
            '4. 如果图片主体是袁隆平纪念雕像，应返回“袁隆平雕像”，不要只返回“袁隆平”。\n'
            '5. 校门识别优先读取门牌/题字文字，例如含弘门、学行门、天生门、学府门、学苑门、文星门、将军门；如果文字只露出一部分，也要结合图像检索候选和门体形态判断。\n'
            '6. 如果图片是瀑布、山水、人物、截图、普通街景、非校园建筑，或者没有可读楼名/明显校园建筑特征，必须返回"未能识别"，禁止猜测。\n'
            '7. 如果候选库中没有能对上号的建筑/景观/雕像，必须返回"未能识别"。\n'
            '8. 给出一段50-100字的简要介绍。\n'
            '请严格按以下JSON格式回复，不要输出其他内容：\n'
            '{"building_name": "建筑名称", "visible_text": "图片中读到的文字，没有则为空字符串", "evidence": "判断依据", "description": "建筑介绍"}'
                )

        _audit(
            request_id,
            "qwen_request",
            model=self._model,
            visual_candidate_count=len(visual_candidates or []),
            prompt_chars=len(prompt_text),
            max_tokens=500,
        )
        _trace(
            request_id,
            "qwen_request",
            model=self._model,
            input_evidence={
                "visual_candidate_count": len(visual_candidates or []),
                "visual_candidates": visual_candidates or [],
                "candidate_library_in_prompt": bool(candidates_str),
                "prompt_chars": len(prompt_text),
                "prompt_sha256_16": hashlib.sha256(prompt_text.encode("utf-8")).hexdigest()[:16],
                "max_tokens": 500,
            },
            note="Qwen-VL receives the original image plus CLIP TopK candidates and must return JSON.",
        )
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(
                f"{self._base_url}/chat/completions",
                headers={"Authorization": f"Bearer {self._api_key}"},
                json={
                    "model": self._model,
                    "messages": [
                        {
                            "role": "user",
                            "content": [
                                {
                                    "type": "text",
                                    "text": prompt_text,
                                },
                                {
                                    "type": "image_url",
                                    "image_url": {
                                        "url": f"data:image/jpeg;base64,{image_base64}"
                                    },
                                },
                            ],
                        }
                    ],
                    "max_tokens": 500,
                },
            )
            _audit(
                request_id,
                "qwen_response_status",
                status_code=resp.status_code,
                response_chars=len(resp.text),
            )
            resp.raise_for_status()
            data = resp.json()
            text = data["choices"][0]["message"]["content"].strip()
            _audit(request_id, "qwen_raw_output", raw_text=text)
            _trace(
                request_id,
                "qwen_response",
                status_code=resp.status_code,
                response_chars=len(resp.text),
                raw_output=text,
            )
            qwen_debug: dict[str, Any] = {
                "qwen": {
                    "called": True,
                    "status_code": resp.status_code,
                    "raw_output": text,
                    "visual_candidate_count": len(visual_candidates or []),
                }
            }

            # 清理 Markdown 代码块包裹
            if text.startswith("```json"):
                text = text[7:]
            elif text.startswith("```"):
                text = text[3:]
            if text.endswith("```"):
                text = text[:-3]
            text = text.strip()

            # 尝试解析 JSON，容错处理
            try:
                result = json.loads(text)
                b_name = result.get("building_name", "未知建筑")
                visible_text = result.get("visible_text", "")
                evidence = result.get("evidence", "")
                description = result.get("description", text)
                _audit(
                    request_id,
                    "qwen_parsed_json",
                    building_name=b_name,
                    visible_text=visible_text,
                    evidence=evidence,
                    description=description,
                )
                _trace(
                    request_id,
                    "qwen_parsed_json",
                    building_name=b_name,
                    visible_text=visible_text,
                    evidence=evidence,
                    description=description,
                )
                canonical_from_text = _canonical_from_visible_text(visible_text)
                if canonical_from_text and canonical_from_text != b_name:
                    _audit(
                        request_id,
                        "qwen_visible_text_override",
                        visible_text=visible_text,
                        raw_building_name=b_name,
                        canonical_building_name=canonical_from_text,
                    )
                    b_name = canonical_from_text
                qwen_debug["qwen"].update({
                    "parsed_json": True,
                    "building_name": b_name,
                    "visible_text": visible_text,
                    "evidence": evidence,
                })
                b_name, description, is_recognized, verify_debug = self._verify_and_enrich(
                    b_name,
                    description,
                    request_id=request_id,
                )
                qwen_debug["verification"] = verify_debug
                return {
                    "recognized": is_recognized,
                    "building_name": b_name,
                    "description": description,
                    "reason": verify_debug.get("reason", ""),
                    "debug": qwen_debug,
                }
            except json.JSONDecodeError:
                b_name = self._extract_building_name(text)
                description = text
                _audit(
                    request_id,
                    "qwen_json_parse_failed",
                    extracted_building_name=b_name,
                    raw_text=text,
                )
                _trace(
                    request_id,
                    "qwen_json_parse_failed",
                    extracted_building_name=b_name,
                    raw_text=text,
                )
                qwen_debug["qwen"].update({
                    "parsed_json": False,
                    "building_name": b_name,
                })
                b_name, description, is_recognized, verify_debug = self._verify_and_enrich(
                    b_name,
                    description,
                    request_id=request_id,
                )
                qwen_debug["verification"] = verify_debug
                return {
                    "recognized": is_recognized,
                    "building_name": b_name,
                    "description": description,
                    "reason": verify_debug.get("reason", ""),
                    "debug": qwen_debug,
                }

    async def _qa_with_qwen_vl(self, image_base64: str, question: str) -> str:
        """调用 Qwen VL 进行场景问答"""

        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(
                f"{self._base_url}/chat/completions",
                headers={"Authorization": f"Bearer {self._api_key}"},
                json={
                    "model": self._model,
                    "messages": [
                        {
                            "role": "user",
                            "content": [
                                {"type": "text", "text": question},
                                {
                                    "type": "image_url",
                                    "image_url": {
                                        "url": f"data:image/jpeg;base64,{image_base64}"
                                    },
                                },
                            ],
                        }
                    ],
                    "max_tokens": 500,
                },
            )
            resp.raise_for_status()
            data = resp.json()
            return data["choices"][0]["message"]["content"].strip()

    def _verify_and_enrich(
        self,
        building_name: str,
        description: str,
        request_id: str = "",
    ) -> tuple[str, str, bool, dict[str, Any]]:
        """通过 RAG 向量库验证识别结果，用权威知识库覆盖 LLM 可能编造的内容。

        返回 (建筑名, 描述, 是否识别成功)。
        """
        normalized_name = _canonical_building_name(building_name)
        debug_info: dict[str, Any] = {
            "raw_building_name": building_name,
            "normalized_name": normalized_name,
        }
        if (
            normalized_name in ["未知建筑", "未能识别", "未识别"]
            or normalized_name in _DENYLIST_NAMES
        ):
            debug_info.update({
                "status": "rejected_by_name",
                "reason": f"视觉模型返回“{normalized_name or '空结果'}”，属于未识别或禁用名称，已拒绝。",
            })
            _audit(
                request_id,
                "verify_rejected_by_name",
                raw_building_name=building_name,
                normalized_name=normalized_name,
            )
            _trace(
                request_id,
                "decision",
                source="qwen_vl_plus_rag",
                accepted=False,
                reason=debug_info["reason"],
                result={
                    "recognized": False,
                    "raw_building_name": building_name,
                    "normalized_name": normalized_name,
                    "reject_stage": "name_guard",
                },
            )
            return (
                "未能识别",
                _UNRECOGNIZED_RESULT["description"],
                False,
                debug_info,
            )
        try:
            from modules.rag.vector_store import vector_store
            search_results, rag_trace = vector_store.search_with_trace(
                normalized_name,
                top_k=5,
                threshold=0.4,
            )
            debug_info["rag_results"] = search_results[:1]
            _audit(
                request_id,
                "verify_rag_search",
                query=normalized_name,
                result_count=len(search_results or []),
                top_result=search_results[0] if search_results else None,
            )
            _trace(
                request_id,
                "rag_text_vector_search",
                query=normalized_name,
                trace=rag_trace,
                accepted_top_result=search_results[0] if search_results else None,
            )
            if search_results:
                verified_name = search_results[0].get("title", building_name)
                if verified_name in _DENYLIST_NAMES:
                    debug_info.update({
                        "status": "rejected_by_denylist",
                        "verified_name": verified_name,
                        "reason": f"RAG 命中“{verified_name}”，但该名称在禁用列表中，已拒绝。",
                    })
                    _audit(
                        request_id,
                        "verify_rejected_by_denylist",
                        raw_building_name=building_name,
                        verified_name=verified_name,
                    )
                    _trace(
                        request_id,
                        "decision",
                        source="qwen_vl_plus_rag",
                        accepted=False,
                        reason=debug_info["reason"],
                        result={
                            "recognized": False,
                            "raw_building_name": building_name,
                            "verified_name": verified_name,
                            "reject_stage": "denylist",
                        },
                    )
                    return (
                        "未能识别",
                        _UNRECOGNIZED_RESULT["description"],
                        False,
                        debug_info,
                    )
                verified_desc = search_results[0].get("answer", description)
                if str(verified_name).startswith(normalized_name):
                    verified_name = normalized_name
                debug_info.update({
                    "status": "accepted",
                    "verified_name": verified_name,
                    "score": search_results[0].get("score"),
                    "reason": f"Qwen-VL 判断为“{building_name}”，RAG 命中“{verified_name}”，结果已采用知识库描述。",
                })
                _audit(
                    request_id,
                    "verify_accepted",
                    raw_building_name=building_name,
                    verified_name=verified_name,
                )
                _trace(
                    request_id,
                    "decision",
                    source="qwen_vl_plus_rag",
                    accepted=True,
                    reason=debug_info["reason"],
                    result={
                        "recognized": True,
                        "raw_building_name": building_name,
                        "verified_name": verified_name,
                        "rag_score": search_results[0].get("score"),
                    },
                )
                return verified_name, verified_desc, True, debug_info
        except Exception as e:
            logger.warning("检索视觉 RAG 验证失败: %s", e)
            debug_info.update({
                "status": "error",
                "error": str(e),
                "reason": f"RAG 校验异常：{e}",
            })
            _audit(request_id, "verify_error", error=str(e))
            _trace(
                request_id,
                "decision",
                source="qwen_vl_plus_rag",
                accepted=False,
                reason=debug_info["reason"],
                result={
                    "recognized": False,
                    "raw_building_name": building_name,
                    "normalized_name": normalized_name,
                    "reject_stage": "rag_error",
                    "error": str(e),
                },
            )
            return (
                "未能识别",
                _UNRECOGNIZED_RESULT["description"],
                False,
                debug_info,
            )
        debug_info.update({
            "status": "rejected_no_rag_match",
            "reason": f"Qwen-VL 判断为“{building_name}”，但 RAG 知识库没有达到阈值的权威命中，已拒绝。",
        })
        _audit(
            request_id,
            "verify_rejected_no_rag_match",
            raw_building_name=building_name,
            normalized_name=normalized_name,
        )
        _trace(
            request_id,
            "decision",
            source="qwen_vl_plus_rag",
            accepted=False,
            reason=debug_info["reason"],
            result={
                "recognized": False,
                "raw_building_name": building_name,
                "normalized_name": normalized_name,
            },
        )
        return (
            "未能识别",
            _UNRECOGNIZED_RESULT["description"],
            False,
            debug_info,
        )

    def _mock_recognize(self) -> dict[str, Any]:
        """无可用视觉模型或低置信度时，不编造识别结果。"""
        return {
            **_UNRECOGNIZED_RESULT,
            "reason": "未配置可用视觉模型、视觉模型调用失败，或图片未匹配到可确认校园建筑。",
        }

    def _mock_scene_qa(self, question: str) -> str:
        """mock 场景问答"""
        return "当前为离线演示模式，视觉服务暂未接入真实模型。你可以尝试问问西小导文字版问答。"

    def _extract_building_name(self, text: str) -> str:
        for line in text.split("\n"):
            line = line.strip().lstrip("#").strip()
            if any(keyword in line for keyword in ["楼", "馆", "林", "门", "堂", "园"]):
                if len(line) <= 20:
                    return line
        return "未知建筑"


vision_service = VisionService()
