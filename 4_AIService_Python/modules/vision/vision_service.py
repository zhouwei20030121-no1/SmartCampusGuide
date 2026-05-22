import base64
import httpx
from config import settings


class VisionService:
    """多模态视觉识别服务"""

    async def recognize_building(self, image_base64: str) -> dict:
        """识别校园建筑图片"""
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(
                f"{settings.OPENAI_BASE_URL}/chat/completions",
                headers={"Authorization": f"Bearer {settings.OPENAI_API_KEY}"},
                json={
                    "model": "gpt-4-vision-preview",
                    "messages": [
                        {
                            "role": "user",
                            "content": [
                                {
                                    "type": "text",
                                    "text": "请识别这张图片中的西南大学校园建筑，给出建筑名称、简要介绍、以及所在位置。如果图片不是校园建筑，请说明。",
                                },
                                {
                                    "type": "image_url",
                                    "image_url": {"url": f"data:image/jpeg;base64,{image_base64}"},
                                },
                            ],
                        }
                    ],
                    "max_tokens": 500,
                },
            )
            data = resp.json()
            text = data["choices"][0]["message"]["content"]
            return {
                "recognized": True,
                "description": text,
                "building_name": self._extract_building_name(text),
            }

    async def scene_qa(self, image_base64: str, question: str) -> str:
        """基于图像的问答"""
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(
                f"{settings.OPENAI_BASE_URL}/chat/completions",
                headers={"Authorization": f"Bearer {settings.OPENAI_API_KEY}"},
                json={
                    "model": "gpt-4-vision-preview",
                    "messages": [
                        {
                            "role": "user",
                            "content": [
                                {"type": "text", "text": question},
                                {
                                    "type": "image_url",
                                    "image_url": {"url": f"data:image/jpeg;base64,{image_base64}"},
                                },
                            ],
                        }
                    ],
                    "max_tokens": 600,
                },
            )
            data = resp.json()
            return data["choices"][0]["message"]["content"]

    def _extract_building_name(self, text: str) -> str:
        for line in text.split("\n"):
            if "建筑" in line or "楼" in line or "馆" in line:
                return line.strip()
        return ""


vision_service = VisionService()
