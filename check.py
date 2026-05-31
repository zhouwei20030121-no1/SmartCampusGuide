import json
data=json.load(open('4_AIService_Python/data/rag_dataset/dataset.json', encoding='utf-8'))
for x in data:
  if '°éÔÂ' in x['building_name'] or 'ÈÚ»ã' in x['building_name']:
    print(x['building_name'], x['image_path'], x['source_url'])
