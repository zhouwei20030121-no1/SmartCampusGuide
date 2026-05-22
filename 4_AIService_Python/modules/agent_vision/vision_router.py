from fastapi import APIRouter

from core_utils.response import ApiResponse
from modules.agent_vision.rag_service import RAGService

router = APIRouter()
rag_service = RAGService()


@router.post("/chat")
async def chat(question: str, user_id: str = ""):
    """AI虚拟导游多轮对话"""
    answer = await rag_service.chat(question, user_id)
    return ApiResponse.ok({"answer": answer})


@router.post("/recognize")
async def recognize(image_url: str):
    """AR多模态识别 - 识别校园建筑/植物"""
    result = await rag_service.recognize_image(image_url)
    return ApiResponse.ok(result)
