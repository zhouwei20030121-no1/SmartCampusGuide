from __future__ import annotations

import os
from pathlib import Path
from typing import Any

from config import settings


class VectorStore:
    """Local ChromaDB vector search for campus knowledge chunks."""

    def __init__(self) -> None:
        self._collection = None
        self._model = None
        self._error = ""
        self._init()

    @property
    def available(self) -> bool:
        return self._collection is not None and self._model is not None

    @property
    def error(self) -> str:
        return self._error

    def search(self, query: str, top_k: int = 5, threshold: float = 0.35) -> list[dict[str, Any]]:
        if not self.available:
            return []
        embedding = self._model.encode([query], normalize_embeddings=True)[0].tolist()
        results = self._collection.query(
            query_embeddings=[embedding],
            n_results=max(1, top_k),
            include=["documents", "metadatas", "distances"],
        )

        documents: list[dict[str, Any]] = []
        ids = results.get("ids", [[]])[0]
        metadatas = results.get("metadatas", [[]])[0]
        distances = results.get("distances", [[]])[0]
        for item_id, metadata, distance in zip(ids, metadatas, distances):
            # ChromaDB defaults to L2 squared distance for normalized embeddings: L2^2 = 2 - 2*cos(theta)
            # Therefore, cosine_similarity = 1 - L2^2 / 2
            score = round(1 - float(distance) / 2, 4)
            if score < threshold:
                continue
            metadata = metadata or {}
            documents.append(
                {
                    "id": item_id,
                    "title": metadata.get("title", ""),
                    "question": metadata.get("question", ""),
                    "answer": metadata.get("answer", ""),
                    "keywords": [
                        item.strip()
                        for item in str(metadata.get("keywords", "")).split("，")
                        if item.strip()
                    ],
                    "category": metadata.get("category", ""),
                    "source": metadata.get("source", ""),
                    "source_file": metadata.get("source_file", ""),
                    "source_url": metadata.get("source_url", ""),
                    "entity_id": metadata.get("entity_id", ""),
                    "section": metadata.get("section", ""),
                    "score": score,
                    "retrieval": "vector",
                }
            )
        return documents

    def _init(self) -> None:
        if not settings.VECTOR_SEARCH_ENABLED:
            return
        try:
            import chromadb
            from sentence_transformers import SentenceTransformer

            os.environ.setdefault("HF_ENDPOINT", "https://huggingface.co")
            persist_dir = Path(settings.CHROMA_PERSIST_DIR)
            if not persist_dir.is_absolute():
                persist_dir = Path(__file__).resolve().parents[2] / persist_dir
            if not persist_dir.exists():
                self._error = f"向量库不存在：{persist_dir}"
                return

            client = chromadb.PersistentClient(path=str(persist_dir))
            self._collection = client.get_collection(settings.CHROMA_COLLECTION)
            self._model = SentenceTransformer(settings.EMBEDDING_MODEL)
        except Exception as exc:
            self._collection = None
            self._model = None
            self._error = str(exc)


vector_store = VectorStore()
