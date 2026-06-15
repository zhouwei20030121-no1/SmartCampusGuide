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

_UNSUPPORTED_LOCATION_TERMS = ("光华楼", "南门")


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
        if any(term in query for term in _UNSUPPORTED_LOCATION_TERMS):
            return []

        vector_results = vector_store.search(query, top_k=max(top_k * 3, 10), threshold=0.35)
        
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

        merged = self._filter_conflicting_gate_results(query, merged)
        return merged[: max(1, top_k)]

    def _filter_conflicting_gate_results(self, query: str, docs: list[dict[str, Any]]) -> list[dict[str, Any]]:
        """Avoid mixing route context between clearly requested school gates."""
        gate_aliases = {
            "gate_1": ("含弘门", "1号门", "一号门"),
            "gate_2": ("学行门", "2号门", "二号门"),
            "gate_3": ("天生门", "3号门", "三号门"),
            "gate_5": ("学府门", "5号门", "五号门"),
            "gate_6": ("学苑门", "6号门", "六号门"),
            "gate_7": ("文星门", "7号门", "七号门"),
            "gate_8": ("将军门", "8号门", "八号门"),
        }
        requested = [
            gate
            for gate, aliases in gate_aliases.items()
            if any(alias in query for alias in aliases)
        ]
        if len(requested) != 1:
            return docs

        requested_gate = requested[0]
        conflicting_aliases = [
            alias
            for gate, aliases in gate_aliases.items()
            if gate != requested_gate
            for alias in aliases
        ]
        requested_aliases = gate_aliases[requested_gate]

        filtered = []
        for doc in docs:
            identity_text = " ".join(
                [
                    str(doc.get("title", "")),
                    str(doc.get("question", "")),
                    str(doc.get("entity_id", "")),
                ]
            )
            if any(alias in identity_text for alias in conflicting_aliases):
                continue

            text = " ".join(
                [
                    str(doc.get("title", "")),
                    str(doc.get("question", "")),
                    str(doc.get("answer", "")),
                    " ".join(doc.get("keywords", [])),
                    str(doc.get("entity_id", "")),
                ]
            )
            has_conflict = any(alias in text for alias in conflicting_aliases)
            has_requested = any(alias in text for alias in requested_aliases)
            if has_conflict and not has_requested:
                continue
            filtered.append(doc)
        return filtered

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

        if self._is_route_query(clean_query):
            sources = self.search(clean_query, top_k)
            return {
                "reply": self._build_route_reply(clean_query, sources),
                "sources": sources,
                "fallback": True,
                "model": "route-intent",
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
            "你可以换一个更具体的关键词，例如“图书馆”“含弘门”“第25教学楼”或“校车路线”。"
        )

    def _is_route_query(self, query: str) -> bool:
        route_words = ("怎么去", "怎么走", "到哪里走", "去哪里走", "路线", "导航", "带我去", "如何到", "如何去")
        return any(word in query for word in route_words)

    def _extract_destination(self, query: str) -> str:
        destination = query.strip()
        for word in ("怎么去", "怎么走", "如何到", "如何去", "带我去", "导航到"):
            if word in destination:
                left, right = destination.split(word, 1)
                destination = right or left
        for word in ("怎么去", "怎么走", "如何到", "如何去", "带我去", "导航到", "去", "路线", "导航"):
            destination = destination.replace(word, "")
        destination = re.sub(r"[？?。！!，,；;\s]+$", "", destination).strip()
        return destination or query.strip()

    def _build_route_reply(self, query: str, sources: list[dict[str, Any]]) -> str:
        destination = self._extract_destination(query)
        place_hint = ""
        if sources:
            best = sources[0]
            title = str(best.get("title") or best.get("question") or destination)
            answer = re.sub(r"\s+", " ", str(best.get("answer", ""))).strip()
            if answer:
                place_hint = f"我先确认到你要去的地点可能是“{title}”。{answer[:180]}"
            else:
                place_hint = f"我先确认到你要去的地点可能是“{title}”。"

        return (
            f"你这个问题是路线规划，不是单纯地点介绍。目的地我理解为“{destination}”。"
            f"{place_hint}"
            "如果你已经在 App 里开启定位，请进入“路线规划”，把终点选为这个地点，系统会按当前位置生成可行走路线。"
            "如果你希望我直接描述路线，请再补一句你的出发点，例如“我在含弘门，怎么去第八教学楼”。"
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

    async def generate_guide(self, spot_name: str, persona: str = "新生") -> dict:
        """生成AI讲解词：RAG检索 + LLM生成"""
        # 1. RAG 检索背景知识
        docs = self.search(spot_name, top_k=5)
        context = "\n".join([d.get("answer") or d.get("content", "") for d in docs])

        # 2. 组装 Prompt
        persona_map = {
            "新生": "用热情、憧憬的语气，欢迎新同学",
            "校友": "用怀旧、亲切的语气，唤起美好回忆",
            "游客": "用专业、生动的语气，介绍校园文化",
        }
        style = persona_map.get(persona, persona_map["新生"])

        prompt = (
            f"你是西南大学的虚拟导游「西小导」。\n"
            f"用户身份：{persona}。请{style}。\n"
            f"请结合以下背景知识，向用户讲解「{spot_name}」。\n"
            f"要求：口语化，适合TTS语音播报，控制在350到500字；语气像一位亲切的学长学姐在带路，不要像新闻播音稿，也不要堆砌口号；多用短句、逗号和自然停顿；必须优先使用背景知识里的具体信息，不要只说泛泛的欢迎词；如果背景知识不足，要明确说资料有限，并围绕地点功能、周边环境和参观提示展开。\n"
            f"背景知识：\n{context if context else spot_name + '是西南大学校园内的重要地点。'}"
        )

        # 3. 调用 LLM（如果配置了DeepSeek）
        text = ""
        try:
            import httpx
            api_key = settings.OPENAI_API_KEY
            if api_key:
                async with httpx.AsyncClient(timeout=30) as client:
                    resp = await client.post(
                        f"{settings.OPENAI_BASE_URL.rstrip('/')}/chat/completions",
                        headers={"Authorization": f"Bearer {api_key}"},
                        json={
                            "model": settings.OPENAI_MODEL,
                            "messages": [{"role": "user", "content": prompt}],
                            "temperature": 0.7,
                            "max_tokens": max(settings.OPENAI_MAX_TOKENS, 900),
                        }
                    )
                    if resp.status_code == 200:
                        data = resp.json()
                        text = data["choices"][0]["message"]["content"]
        except Exception as e:
            logging.warning(f"LLM调用失败，使用模板生成: {e}")

        # 4. 降级：模板生成
        if not text:
            text = (
                self._template_guide_from_context(spot_name, persona, context)
                if context
                else self._template_guide(spot_name, persona)
            )

        return {"spot_name": spot_name, "text": text, "persona": persona}

    def _template_guide(self, spot_name: str, persona: str) -> str:
        """无LLM时的模板生成"""
        templates = {
            "新生": f"欢迎来到{spot_name}！这里是西南大学最具代表性的地标之一。"
                    f"作为新同学，你将在这里度过许多难忘的时光。"
                    f"请带着好奇心，慢慢探索这片美丽的校园吧！",
            "校友": f"又见面了，{spot_name}。这里承载着无数西大学子的青春记忆。"
                    f"无论你毕业多久，这里永远是你的精神家园。",
            "游客": f"您现在看到的是西南大学{spot_name}，"
                    f"这里是校园内最具代表性的建筑之一，体现了西大深厚的历史文化底蕴。",
        }
        return templates.get(persona, templates["新生"])

    def _template_guide_from_context(self, spot_name: str, persona: str, context: str) -> str:
        """Use retrieved campus knowledge directly when the LLM is unavailable."""
        clean_context = re.sub(r"\s+", " ", context).strip()
        if len(clean_context) > 620:
            clean_context = clean_context[:620].rstrip("，。；;、 ") + "。"

        persona_opening = {
            "新生": "同学你好",
            "游客": "欢迎参观",
            "校友": "欢迎回到西大",
        }.get(persona, "同学你好")

        return (
            f"{persona_opening}，现在我们来到{spot_name}。"
            f"根据校内知识库资料，{clean_context}"
            f"你可以把这里当作认识校园的一处切入点：先观察它的功能定位、周边道路和附近建筑，"
            f"再结合自己的行程继续前往下一个地点。以上内容来自当前知识库整理，若涉及开放时间、门禁或临时安排，请以现场通知为准。"
        )


    async def generate_dynamic_guide(
        self,
        spot_name: str,
        persona: str = "新生",
        language: str = "zh",
        style: str = "auto",
        voice: str = "gentle_guide",
        environment: dict[str, Any] | None = None,
        top_k: int = 5,
    ) -> dict[str, Any]:
        """RAG grounded guide generation with persona, language and voice metadata."""
        normalized_language = (language or "zh").lower()
        normalized_persona = self._normalize_persona(persona)
        docs = self.search(spot_name, top_k=top_k)
        context = self._format_context(docs)
        selected_style = self._resolve_style(normalized_persona, style)
        env_text = self._format_environment(environment or {})
        text = ""

        if settings.OPENAI_API_KEY:
            try:
                prompt = (
                    "你是西南大学智能校园导览系统里的 AI 虚拟导游“西小导”。\n"
                    f"当前景点：{spot_name}\n"
                    f"用户身份：{normalized_persona}\n"
                    f"讲解风格：{selected_style}\n"
                    f"环境状态：{env_text}\n"
                    f"检索增强资料：\n{context}\n\n"
                    "请基于资料生成一段 450 到 700 字的中文讲解词。必须包含具体事实、空间位置、用途、历史或校园生活关联；"
                    "不要只写欢迎词。语气自然，适合 TTS 播报，多用短句和自然停顿。若资料不足，请明确说资料有限，"
                    "并围绕当前地点功能、周边环境和参观建议展开。不要输出 Markdown。"
                )
                text = await self._complete_text(prompt, temperature=0.72, max_tokens=1200)
            except Exception as exc:
                logger.warning("Dynamic guide generation failed: %s", exc)

        if not text:
            guide = await self.generate_guide(spot_name, normalized_persona)
            text = str(guide.get("text", "")).strip()

        translated = None
        if normalized_language not in {"zh", "zh-cn", "cn"}:
            translation = await self.translate_text(text, normalized_language, "zh")
            translated = translation.get("text", text)

        return {
            "spot_name": spot_name,
            "text": translated or text,
            "original_text": text,
            "persona": normalized_persona,
            "style": selected_style,
            "language": normalized_language,
            "voice": voice,
            "sources": docs,
            "grounding": {
                "retrieval": "hybrid-vector-keyword",
                "top_k": top_k,
                "source_count": len(docs),
            },
            "tts": {
                "mode": "client-native-streaming",
                "voice": voice,
                "chunking": "sentence",
            },
        }

    async def translate_text(
        self,
        text: str,
        target_language: str = "en",
        source_language: str = "zh",
    ) -> dict[str, Any]:
        """Translate guide text while keeping a compact fallback for offline demos."""
        clean_text = (text or "").strip()
        target = (target_language or "en").lower()
        source = (source_language or "zh").lower()
        if not clean_text:
            return {"text": "", "target_language": target, "source_language": source}
        if target in {source, "zh", "zh-cn", "cn"} and source in {"zh", "zh-cn", "cn"}:
            return {"text": clean_text, "target_language": target, "source_language": source}

        if settings.OPENAI_API_KEY:
            try:
                prompt = (
                    f"Translate the following campus guide script from {source} to {target}. "
                    "Keep proper names accurate, keep a warm audio-guide tone, and do not add facts.\n\n"
                    f"{clean_text}"
                )
                translated = await self._complete_text(prompt, temperature=0.2, max_tokens=1200)
                if translated:
                    return {
                        "text": translated,
                        "target_language": target,
                        "source_language": source,
                        "fallback": False,
                    }
            except Exception as exc:
                logger.warning("Guide translation failed: %s", exc)

        fallback = self._english_fallback_from_text(clean_text) if target.startswith("en") else clean_text
        return {
            "text": fallback,
            "target_language": target,
            "source_language": source,
            "fallback": True,
        }

    async def generate_story(
        self,
        spot_name: str,
        persona: str = "新生",
        comments: list[str] | None = None,
        language: str = "zh",
        time_context: str | None = None,
    ) -> dict[str, Any]:
        """Create an evolving campus story from comments and grounded campus facts."""
        normalized_persona = self._normalize_persona(persona)
        docs = self.search(spot_name, top_k=5)
        safe_comments = [c.strip()[:300] for c in (comments or []) if c and c.strip()][:8]
        comments_text = "\n".join(f"- {item}" for item in safe_comments) or "暂无用户评论。"
        context = self._format_context(docs)
        time_text = time_context or _current_date()
        story = ""

        if settings.OPENAI_API_KEY:
            try:
                prompt = (
                    "你是校园故事策划助手，请基于检索资料和用户评论生成一段有校园气质的趣味故事。\n"
                    f"景点：{spot_name}\n用户身份：{normalized_persona}\n时间节点：{time_text}\n"
                    f"检索资料：\n{context}\n"
                    f"用户评论：\n{comments_text}\n\n"
                    "要求：300 到 500 字，事实和故事感兼具；要把评论中的情绪提炼成主题，但不要编造具体人物隐私；"
                    "结尾给出一句适合继续打卡或语音播报的自然引导。不要输出 Markdown。"
                )
                story = await self._complete_text(prompt, temperature=0.78, max_tokens=900)
            except Exception as exc:
                logger.warning("Story generation failed: %s", exc)

        if not story:
            story = self._template_story(spot_name, normalized_persona, safe_comments)

        if (language or "zh").lower().startswith("en"):
            translated = await self.translate_text(story, "en", "zh")
            story = translated.get("text", story)

        return {
            "spot_name": spot_name,
            "story": story,
            "persona": normalized_persona,
            "language": language,
            "comments_used": len(safe_comments),
            "sources": docs,
        }

    async def _complete_text(
        self,
        prompt: str,
        temperature: float = 0.7,
        max_tokens: int = 900,
    ) -> str:
        async with httpx.AsyncClient(timeout=35.0) as client:
            resp = await client.post(
                f"{settings.OPENAI_BASE_URL.rstrip('/')}/chat/completions",
                headers={"Authorization": f"Bearer {settings.OPENAI_API_KEY}"},
                json={
                    "model": settings.OPENAI_MODEL,
                    "messages": [{"role": "user", "content": prompt}],
                    "temperature": temperature,
                    "max_tokens": max(settings.OPENAI_MAX_TOKENS, max_tokens),
                },
            )
            resp.raise_for_status()
            data = resp.json()
            return str(data["choices"][0]["message"]["content"]).strip()

    def _normalize_persona(self, persona: str) -> str:
        value = (persona or "新生").strip()
        aliases = {
            "freshman": "新生",
            "student": "新生",
            "alumni": "校友",
            "visitor": "游客",
            "tourist": "游客",
        }
        return aliases.get(value.lower(), value)

    def _resolve_style(self, persona: str, style: str) -> str:
        if style and style != "auto":
            return style
        return {
            "新生": "热情引导风格，像学长学姐带路，兼顾实用提示",
            "校友": "怀旧叙事风格，突出校园记忆和时间感",
            "游客": "正式官方风格，兼顾历史文化与参观价值",
        }.get(persona, "亲切自然的校园导览风格")

    def _format_environment(self, environment: dict[str, Any]) -> str:
        if not environment:
            return "未提供实时环境状态"
        pairs = [f"{key}={value}" for key, value in environment.items() if value not in (None, "")]
        return "，".join(pairs) if pairs else "未提供实时环境状态"

    def _template_story(self, spot_name: str, persona: str, comments: list[str]) -> str:
        comments_hint = "、".join(comments[:3]) if comments else "这里还在等待第一批故事被写下"
        opening = {
            "新生": "给新同学的小故事",
            "校友": "给老西大人的回忆片段",
            "游客": "给来访者的校园札记",
        }.get(persona, "校园故事")
        return (
            f"{opening}：{spot_name}最动人的地方，往往不只在建筑本身，也在来来往往的人留下的记忆里。"
            f"有人提到{comments_hint}，这些细碎的感受像路标一样，把这个地点和一天里的阳光、脚步声、"
            f"课堂前后的匆忙连在一起。你现在站在这里，可以先看看周围的道路和建筑，再想象不同年份的同学"
            f"从这里经过：有人第一次认路，有人赶去上课，也有人毕业多年后重新回到这里。"
            f"如果愿意，不妨在这里完成一次打卡，把你自己的校园一句话也留给后来的人。"
        )

    def _english_fallback_from_text(self, text: str) -> str:
        spot_match = re.search(r"来到([^，。,.!！?？]{2,30})", text)
        spot_name = spot_match.group(1) if spot_match else "this campus spot"
        return (
            f"Welcome to {spot_name}. This audio guide is generated from the campus knowledge base and the current tour context. "
            "The detailed English translation service is not available right now, so this version gives you a practical overview: "
            "please notice the function of this place, the nearby roads and buildings, and how students use this area in daily campus life. "
            "You can complete a check-in here, read other visitors' comments, and leave your own memory to help the campus story keep growing."
        )


rag_service = RAGService()
