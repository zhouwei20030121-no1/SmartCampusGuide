import base64
import json
import logging
from pathlib import Path
from typing import Any

import httpx
from config import settings

logger = logging.getLogger(__name__)


_UNRECOGNIZED_RESULT = {
    "recognized": False,
    "building_name": "未能识别",
    "description": "这张图片没有匹配到可确认的西南大学校园建筑。请上传清晰的校内建筑、校门或楼宇铭牌照片；如果是风景、瀑布、人物、截图等非校园建筑图片，系统不会强行猜测。",
    "fallback": True,
}

_DENYLIST_NAMES = {"光华楼"}


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

    async def recognize_building(self, image_base64: str) -> dict[str, Any]:
        """识别校园建筑图片，优先调用 CLIP 图像匹配，再调用 Qwen VL，无 Key 时回退 mock"""

        # 1. 真正的 Visual RAG: 图像向量直接匹配（懒加载 CLIP 模型）
        self._ensure_clip_loaded()
        if self._clip_model and self._image_collection:
            try:
                import io
                from PIL import Image
                image_bytes = base64.b64decode(image_base64)
                img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
                
                # 提取用户上传图片的视觉特征向量
                img_embedding = self._clip_model.encode(img, normalize_embeddings=True).tolist()
                
                # 在 ChromaDB 中进行视觉相似度检索
                results = self._image_collection.query(
                    query_embeddings=[img_embedding],
                    n_results=1,
                    include=["metadatas", "distances"]
                )
                
                if results['distances'] and results['distances'][0]:
                    dist = results['distances'][0][0]
                    metadata = results['metadatas'][0][0]
                    logger.info("CLIP Top-1 匹配: %s (距离: %s)", metadata['title'], dist)
                    
                    # 适当放宽阈值至 0.45
                    if dist < 0.45:
                        logger.info("[MATCH] 距离小于 0.45，判定为同一建筑！")
                        return {
                            "recognized": True,
                            "building_name": metadata["title"],
                            "description": metadata["answer"],
                        }
                    else:
                        logger.info("[MISS] 距离大于 0.45，转交视觉模型进行识别...")
            except Exception as e:
                logger.warning("CLIP 匹配异常: %s", e)

        # 2. 如果没有高度匹配的原图，则退化使用 Qwen-VL 大模型“裸眼”识别
        if self._api_key:
            try:
                return await self._recognize_with_qwen_vl(image_base64)
            except Exception as exc:
                logger.warning("视觉模型调用失败，返回未识别结果：%s", exc)

        return self._mock_recognize()

    async def scene_qa(self, image_base64: str, question: str) -> str:
        """基于图像的场景问答"""

        if self._api_key:
            try:
                return await self._qa_with_qwen_vl(image_base64, question)
            except Exception as exc:
                logger.warning("Qwen VL 问答失败：%s", exc)

        return self._mock_scene_qa(question)

    async def _recognize_with_qwen_vl(self, image_base64: str) -> dict[str, Any]:
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
        except Exception as e:
            logger.warning("无法加载候选建筑列表: %s", e)

        prompt_text = (
            '请识别这张图片中的西南大学校园建筑。\n'
            + (f'【重要提示】以下是所有西南大学合法的建筑名称（候选库）：{candidates_str}\n\n' if candidates_str else '') +
            '要求：\n'
            '1. 只有当图片中出现清晰的西南大学校园建筑、校门、楼宇铭牌，且能和候选库明确对应时，才允许返回建筑名称。\n'
            '2. 如果图片是瀑布、山水、人物、截图、普通街景、非校园建筑，或者没有可读楼名/明显校园建筑特征，必须返回"未能识别"，禁止猜测。\n'
            '3. 如果候选库中没有能对上号的建筑，必须返回"未能识别"。\n'
            '4. 给出一段50-100字的简要介绍。\n'
            '请严格按以下JSON格式回复，不要输出其他内容：\n'
            '{"building_name": "建筑名称", "description": "建筑介绍"}'
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
                    "max_tokens": 300,
                },
            )
            resp.raise_for_status()
            data = resp.json()
            text = data["choices"][0]["message"]["content"].strip()

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
                description = result.get("description", text)
                b_name, description, is_recognized = self._verify_and_enrich(b_name, description)
                return {
                    "recognized": is_recognized,
                    "building_name": b_name,
                    "description": description,
                }
            except json.JSONDecodeError:
                b_name = self._extract_building_name(text)
                description = text
                b_name, description, is_recognized = self._verify_and_enrich(b_name, description)
                return {
                    "recognized": is_recognized,
                    "building_name": b_name,
                    "description": description,
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

    def _verify_and_enrich(self, building_name: str, description: str) -> tuple[str, str, bool]:
        """通过 RAG 向量库验证识别结果，用权威知识库覆盖 LLM 可能编造的内容。

        返回 (建筑名, 描述, 是否识别成功)。
        """
        normalized_name = (building_name or "").strip()
        if (
            normalized_name in ["未知建筑", "未能识别", "未识别"]
            or normalized_name in _DENYLIST_NAMES
        ):
            return (
                "未能识别",
                _UNRECOGNIZED_RESULT["description"],
                False,
            )
        try:
            from modules.rag.vector_store import vector_store
            search_results = vector_store.search(normalized_name, top_k=1, threshold=0.4)
            if search_results:
                verified_name = search_results[0].get("title", building_name)
                if verified_name in _DENYLIST_NAMES:
                    return (
                        "未能识别",
                        _UNRECOGNIZED_RESULT["description"],
                        False,
                    )
                verified_desc = search_results[0].get("answer", description)
                return verified_name, verified_desc, True
        except Exception as e:
            logger.warning("检索视觉 RAG 验证失败: %s", e)
        return (
            "未能识别",
            _UNRECOGNIZED_RESULT["description"],
            False,
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
