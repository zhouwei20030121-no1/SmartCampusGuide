from uuid import uuid4

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from core_utils.response import ApiResponse
from modules.vision.vision_service import vision_service

router = APIRouter()


class RecognizeRequest(BaseModel):
    image_base64: str


class SceneQARequest(BaseModel):
    image_base64: str
    question: str


@router.post("/recognize")
async def recognize(req: RecognizeRequest):
    request_id = f"vision_{uuid4().hex[:10]}"
    try:
        result = await vision_service.recognize_building(
            req.image_base64,
            request_id=request_id,
        )
        return ApiResponse.ok(result)
    except Exception as e:
        # 异常时回退到本地模拟识别，保证接口不崩
        result = vision_service._mock_recognize()
        result["request_id"] = request_id
        result["reason"] = f"识别异常（{e}），已回退本地模拟结果"
        return ApiResponse.ok(result)


@router.post("/scene-qa")
async def scene_qa(req: SceneQARequest):
    try:
        answer = await vision_service.scene_qa(req.image_base64, req.question)
        return ApiResponse.ok({"answer": answer})
    except Exception as e:
        return ApiResponse.ok({
            "answer": f"视觉问答暂不可用：{e}。建议使用文字版西小导问答。"
        })
