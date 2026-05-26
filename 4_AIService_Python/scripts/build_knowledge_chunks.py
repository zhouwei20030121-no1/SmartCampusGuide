#!/usr/bin/env python3
"""Build structured RAG chunks from the Markdown knowledge base."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = REPO_ROOT / "swu_rag_knowledge_base"
OUTPUT_PATH = REPO_ROOT / "4_AIService_Python" / "data" / "knowledge_chunks.json"


FILE_CATEGORY_HINTS = {
    "01_buildings_locations.md": "building",
    "02_colleges_departments.md": "college",
    "03_routes_navigation.md": "route",
    "04_culture_history.md": "culture",
    "05_study_services.md": "study_service",
    "06_life_services.md": "life_service",
    "07_transport_gates.md": "transport",
    "08_scenic_photo_spots.md": "scenic_spot",
    "09_ar_recognition_guide.md": "ar",
    "10_dialogue_qa.md": "qa",
    "11_agent_policy_style.md": "agent_policy",
    "12_entity_relation_index.md": "relation",
}

HEADING_PATTERN = re.compile(r"(?m)^###\s+(.+?)\s*$")
RELATION_HEADING_PATTERN = re.compile(r"(?m)^##\s+(.+?)\s*$")


def main() -> None:
    chunks: list[dict[str, Any]] = []
    for source_file in sorted(SOURCE_DIR.glob("*.md")):
        if source_file.name == "12_entity_relation_index.md":
            chunks.extend(parse_relation_file(source_file))
            continue
        chunks.extend(parse_entity_file(source_file))

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(
        json.dumps(chunks, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"wrote {len(chunks)} chunks to {OUTPUT_PATH}")


def parse_entity_file(path: Path) -> list[dict[str, Any]]:
    text = path.read_text(encoding="utf-8")
    matches = list(HEADING_PATTERN.finditer(text))
    chunks: list[dict[str, Any]] = []

    for index, match in enumerate(matches, 1):
        raw_heading = match.group(1).strip()
        block_end = matches[index].start() if index < len(matches) else len(text)
        raw_block = text[match.end() : block_end]
        label, title = split_heading(raw_heading)
        metadata = parse_metadata(raw_block)
        body = strip_metadata(raw_block)
        if not body:
            continue

        category = metadata.get("type") or FILE_CATEGORY_HINTS.get(path.name, "knowledge")
        entity_id = metadata.get("entity_id") or f"{category}_{slug(title)}"
        source_url = metadata.get("来源链接", "")
        question = infer_question(label, title, category)
        keywords = infer_keywords(title, body, label, category)

        for part_index, part in enumerate(split_body(body), 1):
            chunk_id = f"{entity_id}_{part_index:02d}"
            chunks.append(
                {
                    "id": chunk_id,
                    "title": title,
                    "question": question,
                    "answer": part,
                    "keywords": keywords,
                    "category": category,
                    "source": "swu_rag_knowledge_base",
                    "source_file": path.name,
                    "source_url": source_url,
                    "entity_id": entity_id,
                    "section": label,
                }
            )
    return chunks


def parse_relation_file(path: Path) -> list[dict[str, Any]]:
    text = path.read_text(encoding="utf-8")
    matches = list(RELATION_HEADING_PATTERN.finditer(text))
    chunks: list[dict[str, Any]] = []
    top_title = ""
    for index, match in enumerate(matches, 1):
        title = match.group(1).strip()
        if title.startswith("12."):
            top_title = title
            continue
        block_end = matches[index].start() if index < len(matches) else len(text)
        body = clean_body(text[match.end() : block_end])
        if not body:
            continue
        entity_id = f"relation_{slug(title)}"
        chunks.append(
            {
                "id": entity_id,
                "title": title,
                "question": f"{title}有哪些关系？",
                "answer": body,
                "keywords": [title, "关系", "索引", top_title or "元数据"],
                "category": "relation",
                "source": "swu_rag_knowledge_base",
                "source_file": path.name,
                "source_url": "",
                "entity_id": entity_id,
                "section": "关系索引",
            }
        )
    return chunks


def split_heading(raw_heading: str) -> tuple[str, str]:
    if "：" in raw_heading:
        label, title = raw_heading.split("：", 1)
        return label.strip(), title.strip()
    return "知识项", raw_heading


def parse_metadata(block: str) -> dict[str, str]:
    metadata: dict[str, str] = {}
    for line in block.splitlines():
        match = re.match(r"^\s*([A-Za-z_]+|来源链接)\s*:\s*(.+?)\s*$", line)
        if match:
            metadata[match.group(1)] = match.group(2).strip()
    return metadata


def strip_metadata(block: str) -> str:
    lines = []
    for line in block.splitlines():
        if re.match(r"^\s*(entity_id|type|来源链接)\s*:", line):
            continue
        if line.strip() == "---":
            continue
        lines.append(line)
    return clean_body("\n".join(lines))


def split_body(body: str, max_chars: int = 900) -> list[str]:
    paragraphs = [item.strip() for item in re.split(r"\n\s*\n", body) if item.strip()]
    if not paragraphs:
        return []

    parts: list[str] = []
    current = ""
    for paragraph in paragraphs:
        if len(paragraph) > max_chars:
            if current:
                parts.append(current)
                current = ""
            parts.extend(split_long_text(paragraph, max_chars))
            continue
        candidate = f"{current}\n\n{paragraph}".strip() if current else paragraph
        if len(candidate) > max_chars and current:
            parts.append(current)
            current = paragraph
        else:
            current = candidate
    if current:
        parts.append(current)
    return parts


def split_long_text(text: str, max_chars: int) -> list[str]:
    sentences = re.split(r"(?<=[。！？；])", text)
    parts: list[str] = []
    current = ""
    for sentence in sentences:
        sentence = sentence.strip()
        if not sentence:
            continue
        candidate = current + sentence
        if len(candidate) > max_chars and current:
            parts.append(current)
            current = sentence
        else:
            current = candidate
    if current:
        parts.append(current)
    return parts


def infer_question(label: str, title: str, category: str) -> str:
    if "路线" in label or category == "route":
        return f"{title}怎么走？"
    if "问答" in label or category == "qa":
        return title
    if "AR" in label or category == "ar":
        return f"AR识别到{title}后怎么讲解？"
    if "机构" in label or category == "college":
        return f"{title}在哪里？{title}是什么机构？"
    if "文化" in label or category in {"culture", "environment_culture"}:
        return f"{title}有什么文化含义？"
    return f"{title}在哪里？{title}有什么特点？"


def infer_keywords(title: str, body: str, label: str, category: str) -> list[str]:
    keywords = [title, label, category]
    aliases = re.findall(r"（(.+?)）", title)
    keywords.extend(aliases)
    for token in re.findall(r"第\d+教学楼|[一二三四五六七八九十]+号门|[0-9]+号门|[^\s，。；、：:（）()]{2,8}", body[:260]):
        if token not in keywords and len(keywords) < 12:
            keywords.append(token)
    return keywords


def clean_body(text: str) -> str:
    text = re.sub(r"\n{3,}", "\n\n", text.strip())
    return text


def slug(value: str) -> str:
    cleaned = re.sub(r"[^0-9A-Za-z\u4e00-\u9fff]+", "_", value).strip("_")
    return cleaned[:80] or "chunk"


if __name__ == "__main__":
    main()
