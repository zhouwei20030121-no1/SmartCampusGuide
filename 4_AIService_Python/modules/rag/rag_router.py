from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from core_utils.response import ApiResponse
from modules.rag.rag_service import rag_service

router = APIRouter()


class ChatRequest(BaseModel):
    query: str
    history: list[dict] = []


class CorpusLoadRequest(BaseModel):
    entries: list[dict]


@router.post("/chat")
async def chat(req: ChatRequest):
    try:
        context = rag_service.search(req.query)
        reply = await rag_service.chat(req.query, context)
        return ApiResponse.ok({"reply": reply, "sources": context})
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
