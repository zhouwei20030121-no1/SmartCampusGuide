import base64
import json
import random
from pathlib import Path
from typing import Any

import httpx
from config import settings


# 西南大学校园建筑识别 mock 数据集（无 API Key 时的兜底方案）
_MOCK_BUILDINGS = [
    {
        "building_name": "西南大学图书馆",
        "description": "西南大学图书馆是学校的文献信息中心，建筑面积约3.6万平方米，藏书量超过400万册，是西南地区重要的学术资源中心。"
    },
    {
        "building_name": "25教（计算机与信息科学学院）",
        "description": "第25教学楼是计算机与信息科学学院所在地，承担计算机科学与技术、软件工程、人工智能等专业的教学与科研工作。"
    },
    {
        "building_name": "光华楼",
        "description": "光华楼是西南大学标志性建筑之一，见证了学校百余年的办学历程，承载着深厚的历史文化底蕴。"
    },
    {
        "building_name": "樟树林",
        "description": "樟树林位于校园中心区域，是西南大学最具代表性的自然景观之一，四季常青，是师生休憩、晨读的好去处。"
    },
    {
        "building_name": "博物馆",
        "description": "西南大学博物馆收藏了大量珍贵文物与标本，集中展示了学校百年办学历史与巴渝地区文化特色。"
    },
    {
        "building_name": "行政楼",
        "description": "行政楼是学校行政管理中枢，负责处理学校日常行政事务与教学管理工作。"
    },
    {
        "building_name": "八一大礼堂",
        "description": "八一大礼堂是学校举办重大活动、文艺演出和学术报告的重要场所，可容纳数千人。"
    },
    {
        "building_name": "二号门",
        "description": "二号门是西南大学的标志性校门，毗邻天生路，是师生进出校园的主要通道之一。"
    },
]


class VisionService:
    """多模态视觉识别服务 — 基于 Qwen VL 和 CLIP Image RAG"""

    def __init__(self) -> None:
        self._model = settings.VISION_MODEL
        self._base_url = settings.VISION_BASE_URL.rstrip("/")
        self._api_key = settings.VISION_API_KEY
        self._clip_model = None
        self._image_collection = None
        
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
            print("[Vision] CLIP 模型与 Image RAG 加载成功")
        except Exception as e:
            print(f"[Vision] CLIP 模型加载失败，将仅使用 Qwen-VL: {e}")

    async def recognize_building(self, image_base64: str) -> dict[str, Any]:
        """识别校园建筑图片，优先调用 CLIP 图像匹配，再调用 Qwen VL，无 Key 时回退 mock"""

        # 1. 真正的 Visual RAG: 图像向量直接匹配
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
                    print(f"[Vision] CLIP Top-1 匹配: {metadata['title']} (距离: {dist})")
                    
                    # 适当放宽阈值至 0.45，因为 Android 相册选择器可能会压缩图片导致像素变化
                    if dist < 0.45:
                        print(f"[Vision] 🟢 距离小于 0.45，判定为同一建筑！")
                        return {
                            "recognized": True,
                            "building_name": metadata["title"],
                            "description": metadata["answer"],
                        }
                    else:
                        print(f"[Vision] 🔴 距离大于 0.45，转交 Qwen-VL 进行识别...")
            except Exception as e:
                print(f"[Vision] CLIP 匹配异常: {e}")

        # 2. 如果没有高度匹配的原图，则退化使用 Qwen-VL 大模型“裸眼”识别
        if self._api_key:
            try:
                return await self._recognize_with_qwen_vl(image_base64)
            except Exception as exc:
                print(f"[Vision] Qwen VL 调用失败，回退 mock：{exc}")

        return self._mock_recognize()

    async def scene_qa(self, image_base64: str, question: str) -> str:
        """基于图像的场景问答"""

        if self._api_key:
            try:
                return await self._qa_with_qwen_vl(image_base64, question)
            except Exception as exc:
                print(f"[Vision] Qwen VL 问答失败：{exc}")

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
            print(f"[Vision] 无法加载候选建筑列表: {e}")

        prompt_text = (
            '请识别这张图片中的西南大学校园建筑。\n'
            + (f'【重要提示】以下是所有西南大学合法的建筑名称（候选库）：{candidates_str}\n\n' if candidates_str else '') +
            '要求：\n'
            '1. 请必须从上述【候选库】中挑出一个最匹配的建筑名称（比如照片里写着书楠楼，不要错认成书斋楼）。\n'
            '2. 给出一段50-100字的简要介绍\n'
            '3. 【极其重要】如果图片中没有明显的建筑，或者候选库中完全没有能对上号的建筑，必须严格回答"未能识别"\n'
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
                
                # --- Visual RAG 结合：去伪存真 ---
                if b_name not in ["未知建筑", "未能识别", "未识别"]:
                    try:
                        from modules.rag.vector_store import vector_store
                        # 拿着大模型识别出来的名字，去向量库找“官方身份证”
                        search_results = vector_store.search(b_name, top_k=1, threshold=0.4)
                        if search_results:
                            # 如果找到官方档案，强行覆盖大模型自己瞎编的介绍，彻底消灭幻觉！
                            b_name = search_results[0].get("title", b_name)
                            description = search_results[0].get("answer", description)
                    except Exception as e:
                        print(f"[Vision] 检索视觉 RAG 失败: {e}")
                        
                is_recognized = b_name not in ["未知建筑", "未能识别", "未识别"]
                return {
                    "recognized": is_recognized,
                    "building_name": b_name,
                    "description": description,
                }
            except json.JSONDecodeError:
                b_name = self._extract_building_name(text)
                description = text
                
                # --- Visual RAG 结合：去伪存真 ---
                if b_name not in ["未知建筑", "未能识别", "未识别"]:
                    try:
                        from modules.rag.vector_store import vector_store
                        search_results = vector_store.search(b_name, top_k=1, threshold=0.4)
                        if search_results:
                            b_name = search_results[0].get("title", b_name)
                            description = search_results[0].get("answer", description)
                    except Exception as e:
                        print(f"[Vision] 检索视觉 RAG 失败: {e}")
                        
                is_recognized = b_name not in ["未知建筑", "未能识别", "未识别"]
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

    def _mock_recognize(self) -> dict[str, Any]:
        """随机返回一个校园建筑的 mock 识别结果（演示用）"""
        building = random.choice(_MOCK_BUILDINGS)
        return {
            "recognized": True,
            "building_name": building["building_name"],
            "description": building["description"],
            "fallback": True,
            "reason": "未配置 Vision API Key 或 API 调用失败，返回本地模拟识别结果",
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
