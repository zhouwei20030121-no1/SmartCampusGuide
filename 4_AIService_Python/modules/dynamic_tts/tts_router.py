from fastapi import APIRouter

from core_utils.response import ApiResponse
from modules.dynamic_tts.tts_service import TTSService

router = APIRouter()
tts_service = TTSService()


@router.post("/synthesize")
async def synthesize(text: str, voice: str = "default"):
    """将文本转为语音"""
    result = await tts_service.synthesize(text, voice)
    return ApiResponse.ok(result)


@router.post("/generate-script")
async def generate_script(spot_name: str, style: str = "standard"):
    """根据景点名称生成讲解文案"""
    script = await tts_service.generate_script(spot_name, style)
    return ApiResponse.ok({"script": script})
