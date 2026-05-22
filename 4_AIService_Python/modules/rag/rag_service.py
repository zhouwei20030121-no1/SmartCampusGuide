import os
import httpx
from config import settings


class RAGService:
    """LangChain RAG 知识库检索服务"""

    def __init__(self):
        self._documents: list[dict] = []

    def load_corpus(self, entries: list[dict]) -> None:
        """从语料库加载文档"""
        self._documents = entries

    def search(self, query: str, top_k: int = 5) -> list[dict]:
        """简单关键词检索（TODO: 升级为 Chroma 向量检索）"""
        results = []
        query_lower = query.lower()
        for doc in self._documents:
            question = doc.get("question", "").lower()
            answer = doc.get("answer", "").lower()
            keywords = doc.get("keywords", "").lower()
            if query_lower in question or query_lower in answer or query_lower in keywords:
                results.append(doc)
            if len(results) >= top_k:
                break
        return results

    async def chat(self, query: str, context: list[dict]) -> str:
        """基于检索上下文进行对话"""
        context_text = "\n".join([
            f"Q: {d.get('question', '')}\nA: {d.get('answer', '')}"
            for d in context[:3]
        ])
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(
                f"{settings.OPENAI_BASE_URL}/chat/completions",
                headers={"Authorization": f"Bearer {settings.OPENAI_API_KEY}"},
                json={
                    "model": "gpt-3.5-turbo",
                    "messages": [
                        {"role": "system", "content": "你是西南大学的智能导游'西小导'，请基于提供的知识库内容回答用户问题，保持友好和专业的语气。"},
                        {"role": "user", "content": f"知识库内容：\n{context_text}\n\n用户问题：{query}"},
                    ],
                    "max_tokens": 600,
                },
            )
            data = resp.json()
            return data["choices"][0]["message"]["content"]


rag_service = RAGService()
