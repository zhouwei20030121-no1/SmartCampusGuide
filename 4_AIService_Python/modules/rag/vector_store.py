from __future__ import annotations

import hashlib
import json
import math
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
        documents, _ = self.search_with_trace(query, top_k=top_k, threshold=threshold)
        return documents

    def search_with_trace(
        self,
        query: str,
        top_k: int = 5,
        threshold: float = 0.35,
    ) -> tuple[list[dict[str, Any]], dict[str, Any]]:
        trace: dict[str, Any] = {
            "query": query,
            "top_k": top_k,
            "threshold": threshold,
            "available": self.available,
            "error": self.error,
            "embedding_model": settings.EMBEDDING_MODEL,
            "collection": settings.CHROMA_COLLECTION,
            "metric_note": "ChromaDB normalized embedding distance; score = 1 - distance / 2",
        }
        if not self.available:
            return [], trace
        embedding = self._model.encode([query], normalize_embeddings=True)[0].tolist()
        trace["query_embedding"] = _vector_summary(embedding)
        results = self._collection.query(
            query_embeddings=[embedding],
            n_results=max(1, top_k),
            include=["documents", "metadatas", "distances"],
        )

        documents: list[dict[str, Any]] = []
        ids = results.get("ids", [[]])[0]
        metadatas = results.get("metadatas", [[]])[0]
        distances = results.get("distances", [[]])[0]
        trace["raw_candidates"] = []
        for item_id, metadata, distance in zip(ids, metadatas, distances):
            # ChromaDB defaults to L2 squared distance for normalized embeddings: L2^2 = 2 - 2*cos(theta)
            # Therefore, cosine_similarity = 1 - L2^2 / 2
            score = round(1 - float(distance) / 2, 4)
            trace["raw_candidates"].append(
                {
                    "id": item_id,
                    "title": (metadata or {}).get("title", ""),
                    "distance": round(float(distance), 6),
                    "score": score,
                    "passed_threshold": score >= threshold,
                    "source_file": (metadata or {}).get("source_file", ""),
                    "category": (metadata or {}).get("category", ""),
                }
            )
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
        trace["accepted_count"] = len(documents)
        return documents, trace

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


def _vector_summary(vector: list[float], sample_size: int = 16) -> dict[str, Any]:
    if not vector:
        return {"dim": 0}
    rounded_sample = [round(float(value), 6) for value in vector[:sample_size]]
    mean = sum(float(value) for value in vector) / len(vector)
    norm = math.sqrt(sum(float(value) * float(value) for value in vector))
    digest = hashlib.sha256(
        json.dumps([round(float(value), 8) for value in vector], separators=(",", ":")).encode("utf-8")
    ).hexdigest()[:16]
    return {
        "dim": len(vector),
        "norm": round(norm, 6),
        "mean": round(mean, 6),
        "min": round(float(min(vector)), 6),
        "max": round(float(max(vector)), 6),
        "sample_first_16": rounded_sample,
        "sha256_16": digest,
    }
