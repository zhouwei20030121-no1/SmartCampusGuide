from __future__ import annotations

import argparse
import json
from collections import OrderedDict
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = ROOT / "vision_vector_trace.jsonl"
DEFAULT_OUTPUT = ROOT / "vision_vector_trace_ppt.md"
DEFAULT_COMPACT_OUTPUT = ROOT / "vision_vector_trace_ppt_onepage.md"


def _short(value: Any, limit: int = 36) -> str:
    text = "" if value is None else str(value).replace("\n", " ").strip()
    if len(text) <= limit:
        return text
    return text[: limit - 1] + "…"


def _fmt(value: Any) -> str:
    if value is None or value == "":
        return "-"
    if isinstance(value, float):
        return f"{value:.4f}"
    return str(value)


def _load_events(path: Path) -> OrderedDict[str, list[dict[str, Any]]]:
    grouped: OrderedDict[str, list[dict[str, Any]]] = OrderedDict()
    if not path.exists():
        return grouped
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        request_id = event.get("request_id")
        if not request_id:
            continue
        grouped.setdefault(request_id, []).append(event)
    return grouped


def _stage(events: list[dict[str, Any]], name: str) -> dict[str, Any]:
    for event in events:
        if event.get("stage") == name:
            return event
    return {}


def _stages(events: list[dict[str, Any]], name: str) -> list[dict[str, Any]]:
    return [event for event in events if event.get("stage") == name]


def _latest_decision(events: list[dict[str, Any]]) -> dict[str, Any]:
    decisions = _stages(events, "decision")
    return decisions[-1] if decisions else {}


def _build_summary_row(request_id: str, events: list[dict[str, Any]]) -> list[str]:
    clip = _stage(events, "clip_vector_search")
    qwen = _stage(events, "qwen_parsed_json")
    rag = _stage(events, "rag_text_vector_search")
    decision = _latest_decision(events)
    result = decision.get("result", {}) if isinstance(decision.get("result"), dict) else {}
    candidates = clip.get("candidates") or []
    top1 = candidates[0] if candidates else {}
    rag_trace = rag.get("trace", {}) if isinstance(rag.get("trace"), dict) else {}
    rag_top = (rag_trace.get("raw_candidates") or [{}])[0]
    return [
        request_id,
        _fmt(decision.get("source")),
        "是" if decision.get("accepted") else "否",
        _fmt(result.get("building_name") or result.get("verified_name") or result.get("normalized_name")),
        _fmt(top1.get("title")),
        _fmt(top1.get("distance")),
        "是" if qwen else "否",
        _fmt(qwen.get("building_name")),
        _fmt(rag_top.get("title")),
        _fmt(rag_top.get("score")),
    ]


def _build_compact_row(label: str, request_id: str, events: list[dict[str, Any]]) -> list[str]:
    clip_embedding = _stage(events, "clip_image_embedding").get("query_embedding", {})
    clip = _stage(events, "clip_vector_search")
    qwen = _stage(events, "qwen_parsed_json")
    rag = _stage(events, "rag_text_vector_search")
    decision = _latest_decision(events)
    result = decision.get("result", {}) if isinstance(decision.get("result"), dict) else {}
    candidates = clip.get("candidates") or []
    top1 = candidates[0] if candidates else {}
    rag_trace = rag.get("trace", {}) if isinstance(rag.get("trace"), dict) else {}
    rag_top = (rag_trace.get("raw_candidates") or [{}])[0]
    final_name = result.get("building_name") or result.get("verified_name") or result.get("normalized_name")
    return [
        label,
        request_id,
        f"512维 / hash={_fmt(clip_embedding.get('sha256_16'))}",
        f"{_fmt(top1.get('title'))} / d={_fmt(top1.get('distance'))}",
        f"{'调用' if qwen else '未调用'} / {_fmt(qwen.get('building_name'))}",
        f"{_fmt(rag_top.get('title'))} / score={_fmt(rag_top.get('score'))}",
        f"{'采纳' if decision.get('accepted') else '拒绝'} / {_fmt(final_name)}",
    ]


def export_compact_report(
    input_path: Path,
    output_path: Path,
    request_ids: list[str],
) -> None:
    grouped = _load_events(input_path)
    selected = [
        (request_id, grouped[request_id])
        for request_id in request_ids
        if request_id in grouped
    ]
    labels = ["CLIP直接命中", "CLIP低置信+Qwen拒绝", "CLIP低置信+Qwen+RAG通过"]
    lines: list[str] = [
        "# AI识别链路证据（一页PPT版）",
        "",
        "| 场景 | Request ID | CLIP图片向量 | 图像库Top1召回 | Qwen-VL复核 | 文本RAG校验 | 最终决策 |",
        "|---|---|---|---|---|---|---|",
    ]
    for idx, (request_id, events) in enumerate(selected):
        label = labels[idx] if idx < len(labels) else f"样例{idx + 1}"
        lines.append("| " + " | ".join(_build_compact_row(label, request_id, events)) + " |")
    lines.extend(
        [
            "",
            "## 判定规则",
            "",
            "- CLIP 将图片编码为 512 维向量，并在 ChromaDB 图像向量库召回 TopK。",
            "- 若 `distance <= 0.18` 且与第二名差距 `>= 0.12`，直接采纳 CLIP。",
            "- 若 CLIP 低置信，则把 TopK 候选和原图交给 Qwen-VL 复核。",
            "- Qwen-VL 输出的建筑名必须再进入文本 RAG 向量库校验，命中后才采用知识库描述。",
        ]
    )
    output_path.write_text("\n".join(lines), encoding="utf-8")


def _request_block(request_id: str, events: list[dict[str, Any]]) -> list[str]:
    lines: list[str] = [f"## {request_id}", ""]
    pipeline = _stage(events, "pipeline_start")
    image = _stage(events, "image_decoded").get("image", {})
    clip_embedding = _stage(events, "clip_image_embedding").get("query_embedding", {})
    clip = _stage(events, "clip_vector_search")
    qwen_request = _stage(events, "qwen_request")
    qwen = _stage(events, "qwen_parsed_json")
    rag = _stage(events, "rag_text_vector_search")
    decision = _latest_decision(events)
    result = decision.get("result", {}) if isinstance(decision.get("result"), dict) else {}

    lines.extend(
        [
            "| 项目 | 结果 |",
            "|---|---|",
            f"| 链路 | {' -> '.join(pipeline.get('pipeline', []))} |",
            f"| 图片摘要 | bytes={_fmt(image.get('byte_length'))}, sha256={_fmt(image.get('sha256_16'))} |",
            f"| 最终来源 | {_fmt(decision.get('source'))} |",
            f"| 是否采纳 | {'是' if decision.get('accepted') else '否'} |",
            f"| 最终结果 | {_fmt(result.get('building_name') or result.get('verified_name') or result.get('normalized_name'))} |",
            "",
        ]
    )

    lines.extend(
        [
            "### 1. CLIP 图片向量",
            "",
            "| 字段 | 值 |",
            "|---|---|",
            f"| 模型 | {pipeline.get('clip_model', 'clip-ViT-B-32')} |",
            f"| 向量维度 | {_fmt(clip_embedding.get('dim'))} |",
            f"| L2 范数 | {_fmt(clip_embedding.get('norm'))} |",
            f"| 向量摘要 | {_fmt(clip_embedding.get('sha256_16'))} |",
            f"| 前 8 维样例 | {_short(clip_embedding.get('sample_first_16', [])[:8], 90)} |",
            "",
        ]
    )

    lines.extend(["### 2. 图像向量库召回 Top5", "", "| Rank | 候选 | 距离 | 来源图片 |", "|---:|---|---:|---|"])
    for item in (clip.get("candidates") or [])[:5]:
        lines.append(
            f"| {item.get('rank', '-')} | {_fmt(item.get('title'))} | {_fmt(item.get('distance'))} | {_short(item.get('source_file'), 34)} |"
        )
    if not clip.get("candidates"):
        lines.append("| - | - | - | - |")
    thresholds = clip.get("thresholds", {})
    lines.extend(
        [
            "",
            f"> 自动采纳阈值：distance <= {_fmt(thresholds.get('auto_accept_threshold'))}，候选差距 >= {_fmt(thresholds.get('auto_accept_margin'))}。",
            "",
        ]
    )

    qwen_evidence = qwen_request.get("input_evidence", {}) if isinstance(qwen_request.get("input_evidence"), dict) else {}
    lines.extend(
        [
            "### 3. Qwen-VL 复核",
            "",
            "| 字段 | 值 |",
            "|---|---|",
            f"| 是否调用 | {'是' if qwen_request else '否'} |",
            f"| 模型 | {_fmt(qwen_request.get('model'))} |",
            f"| 输入候选数 | {_fmt(qwen_evidence.get('visual_candidate_count'))} |",
            f"| Prompt 摘要 | {_fmt(qwen_evidence.get('prompt_sha256_16'))} |",
            f"| 识别名称 | {_fmt(qwen.get('building_name'))} |",
            f"| 可见文字 | {_short(qwen.get('visible_text'), 60)} |",
            f"| 判断依据 | {_short(qwen.get('evidence'), 90)} |",
            "",
        ]
    )

    rag_trace = rag.get("trace", {}) if isinstance(rag.get("trace"), dict) else {}
    rag_embedding = rag_trace.get("query_embedding", {}) if isinstance(rag_trace.get("query_embedding"), dict) else {}
    lines.extend(
        [
            "### 4. 文本 RAG 向量校验",
            "",
            "| 字段 | 值 |",
            "|---|---|",
            f"| 查询词 | {_fmt(rag.get('query'))} |",
            f"| 向量维度 | {_fmt(rag_embedding.get('dim'))} |",
            f"| 向量摘要 | {_fmt(rag_embedding.get('sha256_16'))} |",
            f"| 通过阈值数 | {_fmt(rag_trace.get('accepted_count'))} |",
            "",
            "| Rank | 候选 | Score | Distance | 是否过阈值 |",
            "|---:|---|---:|---:|---|",
        ]
    )
    for idx, item in enumerate((rag_trace.get("raw_candidates") or [])[:5], start=1):
        lines.append(
            f"| {idx} | {_fmt(item.get('title'))} | {_fmt(item.get('score'))} | {_fmt(item.get('distance'))} | {'是' if item.get('passed_threshold') else '否'} |"
        )
    if not rag_trace.get("raw_candidates"):
        lines.append("| - | - | - | - | - |")
    lines.extend(["", f"> 结论：{_fmt(decision.get('reason'))}", ""])
    return lines


def export_report(
    input_path: Path,
    output_path: Path,
    limit: int,
    request_ids: list[str] | None = None,
) -> None:
    grouped = _load_events(input_path)
    if request_ids:
        selected = [
            (request_id, grouped[request_id])
            for request_id in request_ids
            if request_id in grouped
        ]
    else:
        selected = list(grouped.items())[-limit:]
    lines: list[str] = [
        "# AI 识别向量检索展示版",
        "",
        "## 总览",
        "",
        "| Request ID | 最终来源 | 采纳 | 结果 | CLIP Top1 | CLIP距离 | Qwen | Qwen结果 | RAG Top1 | RAG分数 |",
        "|---|---|---|---|---|---:|---|---|---|---:|",
    ]
    for request_id, events in selected:
        lines.append("| " + " | ".join(_build_summary_row(request_id, events)) + " |")
    lines.append("")
    for request_id, events in selected:
        lines.extend(_request_block(request_id, events))
    output_path.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Export PPT-friendly AI vision trace report.")
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--limit", type=int, default=5)
    parser.add_argument("--request-id", action="append", default=[])
    parser.add_argument("--compact-output", type=Path, default=None)
    args = parser.parse_args()
    export_report(args.input, args.output, max(1, args.limit), args.request_id)
    if args.compact_output:
        export_compact_report(args.input, args.compact_output, args.request_id)
    print(args.output)
    if args.compact_output:
        print(args.compact_output)


if __name__ == "__main__":
    main()
