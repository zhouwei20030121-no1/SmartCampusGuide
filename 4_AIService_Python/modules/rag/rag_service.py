import json
import re
from pathlib import Path
from typing import Any

import httpx

from config import settings


class RAGService:
    """RAG knowledge service for the campus guide agent."""

    def __init__(self) -> None:
        self._documents: list[dict[str, Any]] = []
        self._load_default_corpus()

    def load_corpus(self, entries: list[dict]) -> None:
        """Replace in-memory documents with normalized corpus entries."""
        self._documents = [self._normalize_doc(entry) for entry in entries]

    def search(self, query: str, top_k: int = 5) -> list[dict[str, Any]]:
        """Score local corpus entries by token overlap and keyword hits."""
        normalized_query = self._normalize_text(query)
        if not normalized_query:
            return []

        query_tokens = self._tokenize(normalized_query)
        ranked: list[tuple[int, dict[str, Any]]] = []

        for doc in self._documents:
            searchable = self._normalize_text(
                " ".join(
                    [
                        str(doc.get("title", "")),
                        str(doc.get("question", "")),
                        str(doc.get("answer", "")),
                        " ".join(doc.get("keywords", [])),
                        str(doc.get("category", "")),
                        str(doc.get("section", "")),
                    ]
                )
            )
            score = self._score(searchable, query_tokens, normalized_query)
            if score > 0:
                ranked.append((score, doc))

        ranked.sort(key=lambda item: item[0], reverse=True)
        return [self._public_doc(doc) for _, doc in ranked[: max(1, top_k)]]

    async def chat(
        self,
        query: str,
        history: list[dict] | None = None,
        top_k: int = 5,
    ) -> dict[str, Any]:
        """Answer a user question with local retrieval and optional LLM generation."""
        clean_query = query.strip()
        if not clean_query:
            return {
                "reply": "你还没有输入问题。可以问我校园建筑、路线、校史或服务设施相关内容。",
                "sources": [],
                "fallback": True,
                "model": "local-knowledge",
            }

        sources = self.search(clean_query, top_k)
        fallback_reply = self._build_fallback_reply(clean_query, sources)

        if not settings.OPENAI_API_KEY:
            return {
                "reply": fallback_reply,
                "sources": sources,
                "fallback": True,
                "model": "local-knowledge",
                "reason": "OPENAI_API_KEY 未配置，已使用本地知识库兜底回答。",
            }

        try:
            reply = await self._chat_with_llm(clean_query, sources, history or [])
            return {
                "reply": reply or fallback_reply,
                "sources": sources,
                "fallback": not bool(reply),
                "model": settings.OPENAI_MODEL,
            }
        except Exception as exc:
            return {
                "reply": fallback_reply,
                "sources": sources,
                "fallback": True,
                "model": "local-knowledge",
                "reason": f"大模型调用失败，已使用本地知识库兜底回答：{exc}",
            }

    async def _chat_with_llm(
        self,
        query: str,
        sources: list[dict[str, Any]],
        history: list[dict],
    ) -> str:
        context_text = self._format_context(sources)
        messages = [
            {
                "role": "system",
                "content": (
                    "你是西南大学智能校园导览系统中的 AI 虚拟导游“西小导”。"
                    "请优先依据给定知识库回答，语气亲切、准确、简洁。"
                    "如果知识库不足，请明确说明不确定，并给出合理的校园导览建议。"
                    "请直接使用普通文本回答，不要输出 Markdown 加粗、列表星号等格式符号。"
                ),
            }
        ]
        messages.extend(self._sanitize_history(history))
        messages.append(
            {
                "role": "user",
                "content": f"知识库内容：\n{context_text}\n\n用户问题：{query}",
            }
        )

        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(
                f"{settings.OPENAI_BASE_URL.rstrip('/')}/chat/completions",
                headers={"Authorization": f"Bearer {settings.OPENAI_API_KEY}"},
                json={
                    "model": settings.OPENAI_MODEL,
                    "messages": messages,
                    "temperature": settings.OPENAI_TEMPERATURE,
                    "max_tokens": settings.OPENAI_MAX_TOKENS,
                },
            )
            resp.raise_for_status()
            data = resp.json()
            return data["choices"][0]["message"]["content"].strip()

    def _load_default_corpus(self) -> None:
        data_dir = Path(__file__).resolve().parents[2] / "data"
        corpus_paths = [
            data_dir / "knowledge_chunks.json",
            data_dir / "campus_corpus.json",
        ]
        entries: list[dict] = []
        for corpus_path in corpus_paths:
            if not corpus_path.exists():
                continue
            with corpus_path.open("r", encoding="utf-8") as file:
                entries.extend(json.load(file))
        self.load_corpus(entries)

    def _normalize_doc(self, doc: dict) -> dict[str, Any]:
        keywords = doc.get("keywords", [])
        if isinstance(keywords, str):
            keywords = [item.strip() for item in re.split(r"[,，、\s]+", keywords) if item.strip()]
        return {
            "id": str(doc.get("id", "")),
            "title": str(doc.get("title", doc.get("question", ""))),
            "question": str(doc.get("question", "")),
            "answer": str(doc.get("answer", "")),
            "keywords": keywords,
            "category": str(doc.get("category", "campus")),
            "source": str(doc.get("source", "")),
            "section": str(doc.get("section", "")),
        }

    def _public_doc(self, doc: dict[str, Any]) -> dict[str, Any]:
        return {
            "id": doc.get("id", ""),
            "title": doc.get("title", ""),
            "question": doc.get("question", ""),
            "answer": doc.get("answer", ""),
            "keywords": doc.get("keywords", []),
            "category": doc.get("category", ""),
            "source": doc.get("source", ""),
            "section": doc.get("section", ""),
        }

    def _build_fallback_reply(self, query: str, sources: list[dict[str, Any]]) -> str:
        if sources:
            best = sources[0]
            return (
                f"我先根据本地校园知识库回答你：{best.get('answer', '')}\n\n"
                "如果你还想继续问，可以追问这个地点的历史、位置或参观建议。"
            )
        return (
            f"我暂时没有在本地知识库中检索到“{query}”的准确资料。"
            "你可以换一个更具体的关键词，例如“图书馆”“光华楼”“博物馆”或“校车路线”。"
        )

    def _format_context(self, sources: list[dict[str, Any]]) -> str:
        if not sources:
            return "暂无命中的本地知识库内容。"
        return "\n\n".join(
            [
                (
                    f"资料{i + 1}：{doc.get('title', '')}"
                    f"（{doc.get('category', '')}/{doc.get('section', '')}）\n"
                    f"问：{doc.get('question', '')}\n答：{doc.get('answer', '')}"
                )
                for i, doc in enumerate(sources[:5])
            ]
        )

    def _sanitize_history(self, history: list[dict]) -> list[dict[str, str]]:
        clean_history: list[dict[str, str]] = []
        for item in history[-8:]:
            role = item.get("role")
            content = str(item.get("content", "")).strip()
            if role in {"user", "assistant"} and content:
                clean_history.append({"role": role, "content": content[:1000]})
        return clean_history

    def _score(self, searchable: str, query_tokens: set[str], normalized_query: str) -> int:
        score = 0
        if normalized_query in searchable:
            score += 8
        for token in query_tokens:
            if token in searchable:
                score += 2 if len(token) > 1 else 1
        return score

    def _tokenize(self, text: str) -> set[str]:
        ascii_tokens = set(re.findall(r"[a-z0-9]+", text))
        chinese_phrases = re.findall(r"[\u4e00-\u9fff]+", text)
        chinese_tokens = set()
        for phrase in chinese_phrases:
            if len(phrase) == 1:
                chinese_tokens.add(phrase)
                continue
            chinese_tokens.add(phrase)
            chinese_tokens.update(
                phrase[index : index + 2] for index in range(0, len(phrase) - 1)
            )
        phrase_tokens = {
            phrase
            for phrase in re.split(r"[\s,，。！？、；;:：()（）]+", text)
            if len(phrase) >= 2
        }
        return ascii_tokens | chinese_tokens | phrase_tokens

    def _normalize_text(self, text: str) -> str:
        return re.sub(r"\s+", " ", text.strip().lower())


rag_service = RAGService()
