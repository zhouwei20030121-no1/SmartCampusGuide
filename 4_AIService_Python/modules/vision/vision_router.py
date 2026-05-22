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
    try:
        result = await vision_service.recognize_building(req.image_base64)
        return ApiResponse.ok(result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/scene-qa")
async def scene_qa(req: SceneQARequest):
    try:
        answer = await vision_service.scene_qa(req.image_base64, req.question)
        return ApiResponse.ok({"answer": answer})
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
