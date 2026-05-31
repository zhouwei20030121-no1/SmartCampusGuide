import urllib.request
from bs4 import BeautifulSoup
import urllib.parse
import os
import json
import time
import re

BASE_URL = "https://www.swu.edu.cn/whxd/hjwh.htm"
DOMAIN = "https://www.swu.edu.cn/"

# 设置存储路径
RAG_DIR = os.path.join(os.path.dirname(__file__), '..', 'data', 'rag_dataset')
IMG_DIR = os.path.join(RAG_DIR, 'images')
os.makedirs(IMG_DIR, exist_ok=True)

def fetch_html(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        html = urllib.request.urlopen(req, timeout=10).read()
        try:
            return html.decode('utf-8')
        except:
            return html.decode('gbk')
    except Exception as e:
        print(f"Error fetching {url}: {e}")
        return None

def main():
    print("开始爬取西南大学环境文化数据用于视觉 RAG...")
    dataset = []
    
    html = fetch_html(BASE_URL)
    if not html: return
    soup = BeautifulSoup(html, 'html.parser')
    
    # 1. 获取分类链接 (七门, 十大景观等)
    categories = []
    for a in soup.select('.hjlist a'):
        href = a.get('href')
        if href and not href.startswith('#'):
            categories.append(urllib.parse.urljoin(BASE_URL, href))
            
    print(f"找到 {len(categories)} 个分类页面。")
    
    # 2. 遍历分类页面获取具体条目
    for cat_url in categories:
        cat_html = fetch_html(cat_url)
        if not cat_html: continue
        cat_soup = BeautifulSoup(cat_html, 'html.parser')
        
        # 寻找条目链接
        for li in cat_soup.select('.jdllist li a'):
            href = li.get('href')
            if not href: continue
            article_url = urllib.parse.urljoin(cat_url, href)
            
            # 提取名称和简介
            title = li.find('h4').get_text(strip=True) if li.find('h4') else ''
            desc = li.find('p').get_text(strip=True) if li.find('p') else ''
            
            if not title: continue
            print(f"  正在处理: {title}")
            
            # 3. 访问条目页面提取大图
            art_html = fetch_html(article_url)
            if not art_html: continue
            art_soup = BeautifulSoup(art_html, 'html.parser')
            
            # 文章内容通常在 .v_news_content 中
            content_div = art_soup.find(class_='v_news_content')
            if not content_div:
                content_div = art_soup # fallback
                
            imgs = content_div.find_all('img')
            for i, img in enumerate(imgs):
                src = img.get('src')
                if not src or 'logo' in src.lower() or 'icon' in src.lower(): continue
                img_url = urllib.parse.urljoin(article_url, src)
                
                # 下载图片
                safe_title = re.sub(r'[\\/*?:"<>|()]', "", title)
                ext = os.path.splitext(urllib.parse.urlparse(img_url).path)[1]
                if not ext: ext = '.jpg'
                filename = f"{safe_title}_{i}{ext}"
                filepath = os.path.join(IMG_DIR, filename)
                
                try:
                    img_req = urllib.request.Request(img_url, headers={'User-Agent': 'Mozilla/5.0'})
                    with urllib.request.urlopen(img_req, timeout=10) as response, open(filepath, 'wb') as f:
                        f.write(response.read())
                    
                    # 记录到数据集
                    dataset.append({
                        "building_name": title,
                        "description": desc,
                        "image_path": f"data/rag_dataset/images/{filename}",
                        "source_url": article_url
                    })
                    print(f"    成功下载图片: {filename}")
                except Exception as e:
                    print(f"    下载图片失败 {img_url}: {e}")
            time.sleep(0.5)

    # 4. 保存 JSON 数据集
    json_path = os.path.join(RAG_DIR, 'dataset.json')
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(dataset, f, ensure_ascii=False, indent=4)
        
    print(f"\n爬取完成！共收集 {len(dataset)} 条图像数据，保存在 {RAG_DIR}")

if __name__ == "__main__":
    main()
