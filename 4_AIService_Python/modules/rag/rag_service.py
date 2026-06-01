import json
import logging
import re
import datetime
from pathlib import Path
from typing import Any

import httpx
from duckduckgo_search import DDGS

from config import settings
from modules.rag.vector_store import vector_store

logger = logging.getLogger(__name__)


# ──────────────── 角色提示词映射 ────────────────
_PERSONA_HINTS: dict[str, str] = {
    "新生": "你正在为一名西南大学新生服务。用热情、详细的语气介绍校园，帮助新生快速熟悉环境，多提及教学楼、宿舍、食堂等实用信息。",
    "游客": "你正在为一名来西南大学参观的游客服务。用生动、有感染力的语言介绍校园历史文化和标志性建筑，突出校园的观赏价值和人文底蕴。",
    "校友": "你正在为一名西南大学校友服务。用温暖、回忆感十足的语气，多提及校园变迁、老建筑的故事，激发怀旧情感。",
}


def _current_date() -> str:
    return datetime.datetime.now().strftime("%Y年%m月%d日")


class RAGService:
    """RAG knowledge service for the campus guide agent."""

    def __init__(self) -> None:
        self._documents: list[dict[str, Any]] = []
        self._load_default_corpus()

    def load_corpus(self, entries: list[dict]) -> None:
        """Replace in-memory documents with normalized corpus entries."""
        self._documents = [self._normalize_doc(entry) for entry in entries]

    def search(self, query: str, top_k: int = 5) -> list[dict[str, Any]]:
        """Hybrid search combining vector similarity and keyword overlap score."""
        vector_results = vector_store.search(query, top_k=max(top_k, 5), threshold=0.35)
        
        normalized_query = self._normalize_text(query)
        keyword_results: list[dict[str, Any]] = []
        if normalized_query:
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
            keyword_results = [self._public_doc(doc) for _, doc in ranked[: max(1, top_k)]]

        merged = []
        seen_ids = set()
        for doc in vector_results:
            if doc["id"] not in seen_ids:
                merged.append(doc)
                seen_ids.add(doc["id"])
                
        for doc in keyword_results:
            if doc["id"] not in seen_ids:
                merged.append(doc)
                seen_ids.add(doc["id"])
                
        return merged[: max(1, top_k)]

    async def _web_search(self, query: str, max_results: int = 3) -> list[dict[str, Any]]:
        """Perform a web search using DuckDuckGo with timeout protection."""
        results = []
        import asyncio
        try:
            def do_search():
                res = []
                with DDGS() as ddgs:
                    for r in ddgs.text(query, max_results=max_results):
                        res.append(r)
                return res
            
            # 增加 3 秒超时保护并使用后台线程以防阻塞
            results = await asyncio.wait_for(asyncio.to_thread(do_search), timeout=3.0)
        except asyncio.TimeoutError:
            logger.warning("Web search timed out after 3 seconds.")
        except Exception as exc:
            logger.warning("Web search failed: %s", exc)
        return results

    async def chat(
        self,
        query: str,
        history: list[dict] | None = None,
        top_k: int = 5,
        persona: str = "新生",
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
            
        # 简单指代消解：如果问题包含代词且有历史记录，将上一轮回答的**第一句话**拼接作为搜索词
        search_query = clean_query
        if history and len(clean_query) < 15 and any(word in clean_query for word in ["他", "她", "它", "这", "那"]):
            last_reply = history[-1].get("content", "") if history else ""
            # 取第一句完整的话（不超过 80 字），避免截断在词中间
            first_sentence = re.split(r"[。！？\n]", last_reply)[0].strip()
            if first_sentence and len(first_sentence) <= 80:
                search_query = f"{first_sentence} {clean_query}"

        sources = self.search(search_query, top_k)
        fallback_reply = self._build_fallback_reply(clean_query, sources)

        web_results_text = ""
        # 如果本地知识库找出的结果过少（低于或等于2条），说明匹配度可能不高，启动网络搜索兜底
        if len(sources) <= 2:
            web_results = await self._web_search(clean_query)
            if web_results:
                web_context = "\n".join([f"【网络来源】 {r.get('title', '')}：{r.get('body', '')}" for r in web_results])
                web_results_text = f"\n\n以下是通过网络搜索获取的补充参考信息（可能包含校外内容）：\n{web_context}"

        if not settings.OPENAI_API_KEY:
            return {
                "reply": fallback_reply,
                "sources": sources,
                "fallback": True,
                "model": "local-knowledge",
                "reason": "OPENAI_API_KEY 未配置，已使用本地知识库兜底回答。",
            }

        try:
            enhanced_query = clean_query
            if web_results_text:
                enhanced_query = f"{clean_query}{web_results_text}"
            reply = await self._chat_with_llm(enhanced_query, sources, history or [], persona)
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
        persona: str = "新生",
    ) -> str:
        context_text = self._format_context(sources)
        persona_hint = _PERSONA_HINTS.get(persona, _PERSONA_HINTS["新生"])
        messages = [
            {
                "role": "system",
                "content": (
                    f"你是西南大学智能校园导览系统中的 AI 虚拟导游“西小导”。当前系统时间是：{_current_date()}。\n"
                    f"当前角色设定：{persona_hint}\n\n"
                    "处理问题时，请遵循以下原则：\n"
                    "1. 优先结合当前的【聊天历史上下文】来理解用户的意图，尤其是当用户使用“他/她/这/那”等代词时。\n"
                    "2. 参考下方提供的【知识库内容】和【网络来源】。但是，如果检索到的这些资料与用户的【最新问题】和【聊天历史】毫无关系（即可能是垃圾检索结果），请**果断完全忽略它们**。\n"
                    "3. 如果提供的资料都无法回答问题，请直接利用你自身的丰富知识库（常识、公众人物信息等）进行解答。\n"
                    "请注意：千万不要在回答中说“根据知识库内容，我没有找到...”这类死板的话。直接自然地给出你的答案即可。\n"
                    "【严格格式要求】：请直接使用普通文本回答，绝对不要输出任何 Markdown 加粗（**）、斜体（*）或列表等格式符号。"
                ),
            }
        ]
        messages.extend(self._sanitize_history(history))
        messages.append(
            {
                "role": "user",
                "content": f"=== 检索到的参考资料 ===\n{context_text}\n========================\n\n[请结合上面的聊天历史和参考资料回答我的最新问题]：{query}",
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
            reply_text = data["choices"][0]["message"]["content"].strip()
            
            # 后处理：强力擦除大模型惯性生成的 Markdown 加粗和斜体符号
            import re
            reply_text = re.sub(r'\*\*(.*?)\*\*', r'\1', reply_text)
            reply_text = re.sub(r'\*(.*?)\*', r'\1', reply_text)
            
            return reply_text

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
            "source_file": doc.get("source_file", ""),
            "source_url": doc.get("source_url", ""),
            "entity_id": doc.get("entity_id", ""),
            "score": doc.get("score", ""),
            "retrieval": doc.get("retrieval", "keyword"),
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
                    f"（{doc.get('category', '')}/{doc.get('section', '')}"
                    f"/{doc.get('retrieval', 'keyword')}）\n"
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
