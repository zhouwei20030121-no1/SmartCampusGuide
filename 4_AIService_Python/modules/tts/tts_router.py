from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from core_utils.response import ApiResponse
from modules.tts.tts_service import tts_service

router = APIRouter()


class ScriptRequest(BaseModel):
    spot_name: str
    description: str = ""
    language: str = "zh"


class SynthesizeRequest(BaseModel):
    text: str
    language: str = "zh"
    voice: str = "gentle_guide"
    rate: float = 1.0


@router.post("/generate-script")
async def generate_script(req: ScriptRequest):
    try:
        script = await tts_service.generate_script(req.spot_name, req.description, req.language)
        return ApiResponse.ok({"script": script})
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/synthesize")
async def synthesize(req: SynthesizeRequest):
    try:
        result = await tts_service.synthesize(req.text, req.language, req.voice, req.rate)
        return ApiResponse.ok(result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/voices")
async def voices():
    return ApiResponse.ok(tts_service.list_voices())
