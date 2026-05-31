import json
import os
import uuid
import sys
from pathlib import Path
from PIL import Image

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

    persist_dir = Path(settings.CHROMA_PERSIST_DIR)
    if not persist_dir.is_absolute():
        persist_dir = Path(__file__).resolve().parents[1] / persist_dir
        
    print(f"Connecting to ChromaDB at {persist_dir}")
    client = chromadb.PersistentClient(path=str(persist_dir))
    
    # 使用专门存图片的 collection
    collection = client.get_or_create_collection("smart_campus_images")
    
    print(f"Loading CLIP model: clip-ViT-B-32")
    # 使用缓存目录避免重复下载
    cache_dir = os.path.join(os.path.dirname(__file__), '..', 'models_cache')
    model = SentenceTransformer('clip-ViT-B-32', cache_folder=cache_dir)

    batch_size = 32
    for i in range(0, len(dataset), batch_size):
        batch = dataset[i:i+batch_size]
        images = []
        metadatas = []
        ids = []
        
        for item in batch:
            b_name = item.get("building_name", "")
            desc = item.get("description", "")
            img_rel_path = item.get("image_path", "")
            url = item.get("source_url", "")
            
            img_path = os.path.join(os.path.dirname(__file__), '..', img_rel_path)
            
            if os.path.exists(img_path):
                try:
                    img = Image.open(img_path).convert("RGB")
                    images.append(img)
                    metadatas.append({
                        "title": b_name,
                        "category": "环境文化图片",
                        "answer": desc,
                        "source_file": img_rel_path,
                        "source_url": url
                    })
                    ids.append(str(uuid.uuid4()))
                except Exception as e:
                    print(f"Error opening image {img_path}: {e}")
                    
        if images:
            print(f"Computing embeddings for batch {i//batch_size + 1}...")
            embeddings = model.encode(images, normalize_embeddings=True).tolist()
            
            collection.add(
                ids=ids,
                embeddings=embeddings,
                metadatas=metadatas
            )
            
    print("Image RAG dataset successfully ingested into ChromaDB 'smart_campus_images'!")

if __name__ == "__main__":
    main()
