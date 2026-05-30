#!/usr/bin/env python3
"""Build a local ChromaDB vector index from knowledge chunks."""

from __future__ import annotations

import json
import os
import shutil
from pathlib import Path
from typing import Any

import chromadb
from sentence_transformers import SentenceTransformer


REPO_ROOT = Path(__file__).resolve().parents[2]
AI_ROOT = REPO_ROOT / "4_AIService_Python"
CHUNKS_PATH = AI_ROOT / "data" / "knowledge_chunks.json"
CHROMA_DIR = AI_ROOT / "chroma_db"
COLLECTION_NAME = "smart_campus_knowledge"
MODEL_NAME = os.getenv("EMBEDDING_MODEL", "BAAI/bge-small-zh-v1.5")


def main() -> None:
    os.environ.setdefault("HF_ENDPOINT", "https://huggingface.co")
    chunks = json.loads(CHUNKS_PATH.read_text(encoding="utf-8"))
    
    corpus_path = AI_ROOT / "data" / "campus_corpus.json"
    if corpus_path.exists():
        corpus_chunks = json.loads(corpus_path.read_text(encoding="utf-8"))
        for item in corpus_chunks:
            item["source"] = "campus_corpus"
            item["source_file"] = "campus_corpus.json"
        chunks.extend(corpus_chunks)
        
    if not chunks:
        raise SystemExit("No knowledge chunks or corpus data found.")

    print(f"loading embedding model: {MODEL_NAME}")
    model = SentenceTransformer(MODEL_NAME)

    if CHROMA_DIR.exists():
        shutil.rmtree(CHROMA_DIR)
    CHROMA_DIR.mkdir(parents=True, exist_ok=True)

    client = chromadb.PersistentClient(path=str(CHROMA_DIR))
    collection = client.create_collection(
        name=COLLECTION_NAME,
        metadata={"hnsw:space": "cosine"},
    )

    documents = [chunk_text(chunk) for chunk in chunks]
    ids = [str(chunk["id"]) for chunk in chunks]
    metadatas = [metadata_for(chunk) for chunk in chunks]

    print(f"encoding {len(documents)} chunks")
    embeddings = model.encode(
        documents,
        batch_size=32,
        normalize_embeddings=True,
        show_progress_bar=True,
    ).tolist()

    collection.add(
        ids=ids,
        documents=documents,
        metadatas=metadatas,
        embeddings=embeddings,
    )
    print(f"wrote vector index to {CHROMA_DIR}")


def chunk_text(chunk: dict[str, Any]) -> str:
    return (
        f"标题：{chunk.get('title', '')}\n"
        f"问题：{chunk.get('question', '')}\n"
        f"关键词：{'，'.join(chunk.get('keywords', []))}\n"
        f"内容：{chunk.get('answer', '')}"
    )


def metadata_for(chunk: dict[str, Any]) -> dict[str, str]:
    return {
        "title": str(chunk.get("title", "")),
        "question": str(chunk.get("question", "")),
        "answer": str(chunk.get("answer", "")),
        "keywords": "，".join(chunk.get("keywords", [])),
        "category": str(chunk.get("category", "")),
        "source": str(chunk.get("source", "")),
        "source_file": str(chunk.get("source_file", "")),
        "source_url": str(chunk.get("source_url", "")),
        "entity_id": str(chunk.get("entity_id", "")),
        "section": str(chunk.get("section", "")),
    }


if __name__ == "__main__":
    main()
