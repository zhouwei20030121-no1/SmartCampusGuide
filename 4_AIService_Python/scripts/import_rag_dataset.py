import json
import os
import uuid
import sys
from pathlib import Path

# 添加项目根目录到 Python Path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from config import settings
import chromadb
from sentence_transformers import SentenceTransformer

def main():
    dataset_path = os.path.join(os.path.dirname(__file__), '..', 'data', 'rag_dataset', 'dataset.json')
    if not os.path.exists(dataset_path):
        print(f"Error: {dataset_path} does not exist.")
        return

    with open(dataset_path, 'r', encoding='utf-8') as f:
        dataset = json.load(f)

    print(f"Loaded {len(dataset)} items from dataset.")

    # Initialize Chroma DB
    persist_dir = Path(settings.CHROMA_PERSIST_DIR)
    if not persist_dir.is_absolute():
        persist_dir = Path(__file__).resolve().parents[1] / persist_dir
        
    print(f"Connecting to ChromaDB at {persist_dir}")
    client = chromadb.PersistentClient(path=str(persist_dir))
    collection = client.get_or_create_collection(settings.CHROMA_COLLECTION)
    
    print(f"Loading embedding model: {settings.EMBEDDING_MODEL}")
    model = SentenceTransformer(settings.EMBEDDING_MODEL)

    docs = []
    metadatas = []
    ids = []
    embeddings = []

    for item in dataset:
        b_name = item.get("building_name", "")
        desc = item.get("description", "")
        img_path = item.get("image_path", "")
        url = item.get("source_url", "")
        
        # We index the text content
        text_to_embed = f"西南大学建筑：{b_name}。{desc}"
        
        docs.append(text_to_embed)
        metadatas.append({
            "title": b_name,
            "category": "环境文化",
            "answer": desc,
            "source_file": img_path,
            "source_url": url
        })
        ids.append(str(uuid.uuid4()))

    print("Computing embeddings...")
    embeddings = model.encode(docs, normalize_embeddings=True).tolist()

    print(f"Adding {len(docs)} documents to collection '{settings.CHROMA_COLLECTION}'...")
    collection.add(
        ids=ids,
        documents=docs,
        embeddings=embeddings,
        metadatas=metadatas
    )

    print("Data successfully ingested into RAG vector store!")

if __name__ == "__main__":
    main()
