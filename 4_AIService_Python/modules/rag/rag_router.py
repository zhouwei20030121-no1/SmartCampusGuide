from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from core_utils.response import ApiResponse
from modules.rag.rag_service import rag_service

router = APIRouter()


class ChatRequest(BaseModel):
    query: str
    history: list[dict] = Field(default_factory=list)
    top_k: int = 5
    persona: str = "新生"


class CorpusLoadRequest(BaseModel):
    entries: list[dict]


@router.post("/chat")
async def chat(req: ChatRequest):
    try:
        result = await rag_service.chat(req.query, req.history, req.top_k, persona=req.persona)
        return ApiResponse.ok(result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/load-corpus")
async def load_corpus(req: CorpusLoadRequest):
    rag_service.load_corpus(req.entries)
    return ApiResponse.ok({"count": len(req.entries)})


@router.get("/search")
async def search(q: str, top_k: int = 5):
    results = rag_service.search(q, top_k)
    return ApiResponse.ok(results)


class GuideGenerateRequest(BaseModel):
    spot_name: str
    user_id: str = "anonymous"
    persona: str = "新生"


@router.post("/guide/generate")
async def generate_guide(req: GuideGenerateRequest):
    """Java后端触发：根据景点名+用户画像生成AI讲解词"""
    try:
        result = await rag_service.generate_guide(req.spot_name, req.persona)
        return ApiResponse.ok(result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


class DynamicGuideRequest(BaseModel):
    spot_name: str
    user_id: str = "anonymous"
    persona: str = "新生"
    language: str = "zh"
    style: str = "auto"
    voice: str = "gentle_guide"
    environment: dict = Field(default_factory=dict)
    top_k: int = 5


class TranslateRequest(BaseModel):
    text: str
    target_language: str = "en"
    source_language: str = "zh"


class StoryGenerateRequest(BaseModel):
    spot_name: str
    user_id: str = "anonymous"
    persona: str = "新生"
    comments: list[str] = Field(default_factory=list)
    language: str = "zh"
    time_context: str | None = None


@router.post("/guide/dynamic")
async def generate_dynamic_guide(req: DynamicGuideRequest):
    """Generate a grounded, persona-aware guide script with language and voice metadata."""
    try:
        result = await rag_service.generate_dynamic_guide(
            spot_name=req.spot_name,
            persona=req.persona,
            language=req.language,
            style=req.style,
            voice=req.voice,
            environment=req.environment,
            top_k=req.top_k,
        )
        return ApiResponse.ok(result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/guide/translate")
async def translate_guide(req: TranslateRequest):
    try:
        result = await rag_service.translate_text(
            text=req.text,
            target_language=req.target_language,
            source_language=req.source_language,
        )
        return ApiResponse.ok(result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/story/generate")
async def generate_story(req: StoryGenerateRequest):
    try:
        result = await rag_service.generate_story(
            spot_name=req.spot_name,
            persona=req.persona,
            comments=req.comments,
            language=req.language,
            time_context=req.time_context,
        )
        return ApiResponse.ok(result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
