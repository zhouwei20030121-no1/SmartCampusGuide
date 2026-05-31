import json
import os
from collections import defaultdict
from pathlib import Path

data_dir = Path('4_AIService_Python/data/rag_dataset/images')
dataset_file = Path('4_AIService_Python/data/rag_dataset/dataset.json')

with open(dataset_file, 'r', encoding='utf-8') as f:
    dataset = json.load(f)

# Group by size
size_map = defaultdict(list)
for item in dataset:
    img_path = Path('4_AIService_Python') / item['image_path']
    if img_path.exists():
        size = img_path.stat().st_size
        size_map[size].append(item)

# Find dummy sizes (appear > 5 times)
dummy_sizes = set()
for size, items in size_map.items():
    if len(items) > 5:
        dummy_sizes.add(size)
        print(f"Found dummy size: {size} bytes, count: {len(items)}")

# Filter dataset
new_dataset = []
removed_count = 0
for item in dataset:
    img_path = Path('4_AIService_Python') / item['image_path']
    if img_path.exists():
        size = img_path.stat().st_size
        if size in dummy_sizes:
            removed_count += 1
            # Optional: delete the physical file too
            try:
                img_path.unlink()
            except:
                pass
            continue
    new_dataset.append(item)

with open(dataset_file, 'w', encoding='utf-8') as f:
    json.dump(new_dataset, f, ensure_ascii=False, indent=4)

print(f"Removed {removed_count} dummy image entries from dataset.json")
