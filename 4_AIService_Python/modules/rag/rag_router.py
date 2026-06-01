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
