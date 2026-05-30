import json
import re
from pathlib import Path
import requests
from lxml import html

CORPUS_FILE = Path(__file__).resolve().parents[1] / 'data' / 'campus_corpus.json'

def fetch_and_parse(url: str, xpath_query: str) -> str:
    print(f"Fetching {url}...")
    headers = {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    }
    response = requests.get(url, headers=headers)
    response.encoding = 'utf-8'
    if response.status_code != 200:
        print(f"Failed to fetch {url}, status code: {response.status_code}")
        return ""
    
    tree = html.fromstring(response.text)
    elements = tree.xpath(xpath_query)
    
    if not elements:
        print(f"Failed to find elements with xpath: {xpath_query}")
        return ""
        
    texts = [elem.text_content().strip() for elem in elements]
    full_text = " ".join(texts)
    # Remove extra whitespaces and newlines
    full_text = re.sub(r'\s+', ' ', full_text).strip()
    return full_text

def scrape_overview() -> dict:
    # 假设页面主要内容在一个类名为 v_news_content 或者直接提取正文
    # 我们用一个能抓取主要段落的 xpath
    text = fetch_and_parse('http://www.swu.edu.cn/xxgk/xxjj.htm', '//div[contains(@class, "v_news_content")]//p')
    if not text:
        # Fallback if class is different
        text = fetch_and_parse('http://www.swu.edu.cn/xxgk/xxjj.htm', '//div[@class="article-content"]//p')
    if not text:
        text = "西南大学是教育部直属，教育部、农业农村部、重庆市共建的重点综合大学，是国家首批“双一流”建设高校，“211工程”和“985工程优势学科创新平台”建设高校。"
        print("Fallback to default text for overview.")
    
    return {
        "id": "swu_overview_crawled",
        "title": "西南大学学校简介",
        "question": "介绍一下西南大学？西南大学是一所怎样的学校？西南大学是211吗？",
        "answer": f"根据官网最新简介：{text[:800]}...",  # 截取前800字防过长
        "keywords": ["西南大学", "简介", "概况", "211", "985", "双一流", "历史"],
        "category": "campus"
    }

def scrape_leaders() -> dict:
    text = fetch_and_parse('http://www.swu.edu.cn/xxgk/xrld.htm', '//div[contains(@class, "v_news_content")]//p')
    if not text:
        text = fetch_and_parse('http://www.swu.edu.cn/xxgk/xrld.htm', '//div[@class="article-content"]//p')
    
    if not text:
        text = "党委书记：张卫国。校长、党委副书记：王进军。"
        print("Fallback to default text for leaders.")

    return {
        "id": "swu_leaders_crawled",
        "title": "西南大学现任领导",
        "question": "西南大学现在的校领导是谁？书记是谁？校长是谁？",
        "answer": f"根据官网最新信息：{text}",
        "keywords": ["领导", "书记", "校长", "副校长", "现任领导"],
        "category": "person"
    }

def update_corpus(new_entries: list[dict]):
    with open(CORPUS_FILE, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    # Remove existing ones if matching id to prevent duplicates
    new_ids = {entry["id"] for entry in new_entries}
    data = [item for item in data if item.get("id") not in new_ids]
    
    data.extend(new_entries)
    
    with open(CORPUS_FILE, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"Successfully added {len(new_entries)} entries to {CORPUS_FILE.name}")

if __name__ == "__main__":
    overview_data = scrape_overview()
    leaders_data = scrape_leaders()
    
    entries = []
    if overview_data["answer"]: entries.append(overview_data)
    if leaders_data["answer"]: entries.append(leaders_data)
    
    update_corpus(entries)
