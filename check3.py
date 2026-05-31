import json
data=json.load(open('4_AIService_Python/data/rag_dataset/dataset.json', encoding='utf-8'))
with open('check3.txt', 'w', encoding='utf-8') as f:
  for x in data:
    if '伴月' in x['building_name'] or '融汇' in x['building_name']:
      f.write(f"{x['building_name']} : {x['image_path']} : {x['source_url']}\n")
