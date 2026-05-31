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
    """多模态视觉识别服务 — 基于 DeepSeek VL 模型"""

    def __init__(self) -> None:
        self._model = settings.VISION_MODEL
        self._base_url = settings.OPENAI_BASE_URL.rstrip("/")
        self._api_key = settings.OPENAI_API_KEY

    async def recognize_building(self, image_base64: str) -> dict[str, Any]:
        """识别校园建筑图片，优先调用 DeepSeek VL，无 Key 时回退 mock"""

        if self._api_key:
            try:
                return await self._recognize_with_deepseek_vl(image_base64)
            except Exception as exc:
                print(f"[Vision] DeepSeek VL 调用失败，回退 mock：{exc}")

        return self._mock_recognize()

    async def scene_qa(self, image_base64: str, question: str) -> str:
        """基于图像的场景问答"""

        if self._api_key:
            try:
                return await self._qa_with_deepseek_vl(image_base64, question)
            except Exception as exc:
                print(f"[Vision] DeepSeek VL 问答失败：{exc}")

        return self._mock_scene_qa(question)

    async def _recognize_with_deepseek_vl(self, image_base64: str) -> dict[str, Any]:
        """调用 DeepSeek VL 识别建筑"""

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
                                    "text": (
                                        '请识别这张图片中的西南大学校园建筑。\n'
                                        '要求：\n'
                                        '1. 给出建筑名称（如图书馆、25教、光华楼等）\n'
                                        '2. 给出一段50-100字的简要介绍\n'
                                        '3. 如果无法确定建筑名称，回答"未能识别"\n'
                                        '请严格按以下JSON格式回复，不要输出其他内容：\n'
                                        '{"building_name": "建筑名称", "description": "建筑介绍"}'
                                    ),
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

            # 尝试解析 JSON，容错处理
            try:
                result = json.loads(text)
                return {
                    "recognized": True,
                    "building_name": result.get("building_name", "未知建筑"),
                    "description": result.get("description", text),
                }
            except json.JSONDecodeError:
                return {
                    "recognized": True,
                    "building_name": self._extract_building_name(text),
                    "description": text,
                }

    async def _qa_with_deepseek_vl(self, image_base64: str, question: str) -> str:
        """调用 DeepSeek VL 进行场景问答"""

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
            "reason": "未配置 DeepSeek API Key 或 API 调用失败，返回本地模拟识别结果",
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
