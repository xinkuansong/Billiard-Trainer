#!/usr/bin/env python3
"""Create a deterministic, stratified 100-shape preview from filtered source rows."""
from __future__ import annotations

import gzip
import json
import math
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
INPUT = HERE / "filtered-source-shapes.jsonl.gz"
OUT_JSON = HERE / "source-filter-sample-100.json"
OUT_HTML = HERE / "source-filter-sample-100.html"
OUT_SVG = HERE / "source-filter-sample-100.svg"


def base_key(row: dict) -> tuple[int, int, int]:
    return int(row["sourceTargetIndex"]), int(row["maskIndex"]), int(row["distanceBit"])


def pick_even(values: list[dict], count: int) -> list[dict]:
    values = sorted(values, key=lambda item: (item["sourceTargetIndex"], item["maskIndex"], item["distanceBit"]))
    if len(values) <= count:
        return values
    indexes = [min(len(values) - 1, math.floor(i * len(values) / count)) for i in range(count)]
    return [values[index] for index in indexes]


def load_groups() -> dict[tuple[int, int, int], dict[float, dict]]:
    groups: dict[tuple[int, int, int], dict[float, dict]] = defaultdict(dict)
    with gzip.open(INPUT, "rt", encoding="utf-8") as handle:
        for line in handle:
            row = json.loads(line)
            if row["technique"] != "jump" or float(row["obstacleRatio"]) not in (0.3, 0.5, 0.7):
                continue
            groups[base_key(row)][float(row["obstacleRatio"])] = row
    return groups


def make_samples(groups: dict[tuple[int, int, int], dict[float, dict]]) -> list[dict]:
    by_bucket: dict[tuple[int, int], list[dict]] = defaultdict(list)
    for variants in groups.values():
        center = variants[0.5]
        by_bucket[(int(center["distanceBit"]), int(center["pocket"]))].append(center)
    bucket_keys = sorted(by_bucket)
    selected: list[dict] = []
    cursor = 0
    while len(selected) < 100 and bucket_keys:
        key = bucket_keys[cursor % len(bucket_keys)]
        values = by_bucket[key]
        index = cursor // len(bucket_keys)
        if index < len(values):
            selected.append(values[index])
        cursor += 1
        if cursor > sum(len(items) for items in by_bucket.values()) * 2:
            break
    selected = selected[:100]
    result = []
    for index, center in enumerate(selected, start=1):
        variants = groups[base_key(center)]
        result.append({
            "sampleIndex": index,
            "sourceTargetIndex": center["sourceTargetIndex"],
            "sourceLayoutID": center["sourceLayoutID"].rsplit("-o", 1)[0],
            "sourceCombinationID": center["sourceCombinationID"],
            "distanceBit": center["distanceBit"],
            "cueTargetDistanceMetres": center["cueTargetDistanceMetres"],
            "pocket": center["pocket"],
            "angleIndex": center["angleIndex"],
            "railIndex": center["railIndex"],
            "cueNearestRailGapMetres": center["cueNearestRailGapMetres"],
            "cue": center["cue"],
            "target": center["target"],
            "ghost": center["ghost"],
            "variants": {
                str(ratio): {"obstacle": variants[ratio]["obstacle"], "obstaclePocketClearanceMetres": variants[ratio]["obstaclePocketClearanceMetres"]}
                for ratio in (0.3, 0.5, 0.7)
            },
        })
    return result


def js(value: object) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def svg_shape(sample: dict, x: float, y: float, w: float, h: float, ratio: str = "0.5") -> str:
    def px(point: dict) -> tuple[float, float]:
        return x + 8 + (point["x"] + 1.27) / 2.54 * (w - 16), y + 24 + (point["z"] + 0.635) / 1.27 * (h - 32)
    cue = px(sample["cue"]); target = px(sample["target"]); ghost = px(sample["ghost"]); obstacle = px(sample["variants"][ratio]["obstacle"])
    pockets = [(0, 0), (w / 2, 0), (w, 0), (0, h - 16), (w / 2, h - 16), (w, h - 16)]
    pocket_svg = "".join(f'<circle cx="{x + px0}" cy="{y + 24 + py}" r="5" fill="#111827"/>' for px0, py in pockets)
    return f'''<g><rect x="{x}" y="{y + 16}" width="{w}" height="{h - 16}" rx="8" fill="#176044" stroke="#0b3d2b" stroke-width="2"/>{pocket_svg}
      <line x1="{cue[0]}" y1="{cue[1]}" x2="{ghost[0]}" y2="{ghost[1]}" stroke="#d9f99d" stroke-width="1" stroke-dasharray="3 3"/>
      <circle cx="{ghost[0]}" cy="{ghost[1]}" r="5" fill="none" stroke="#d1d5db" stroke-width="1"/>
      <circle cx="{obstacle[0]}" cy="{obstacle[1]}" r="5" fill="#facc15" stroke="#713f12" stroke-width="1"/>
      <circle cx="{target[0]}" cy="{target[1]}" r="5" fill="#ef4444" stroke="#7f1d1d" stroke-width="1"/>
      <circle cx="{cue[0]}" cy="{cue[1]}" r="5" fill="#f8fafc" stroke="#1e3a8a" stroke-width="1"/>
    </g>'''


def make_svg(samples: list[dict]) -> str:
    cols, rows, card_w, card_h, gap = 5, 20, 300, 190, 10
    width = cols * card_w + (cols + 1) * gap
    height = rows * card_h + (rows + 1) * gap
    cards = []
    for i, sample in enumerate(samples):
        col, row = i % cols, i // cols
        x, y = gap + col * card_w, gap + row * card_h
        title = f"{sample['sampleIndex']:03d} · {sample['sourceLayoutID']}"
        meta = f"d{sample['distanceBit']}  {sample['cueTargetDistanceMetres']:.2f}m  P{sample['pocket']}  R{sample['railIndex']}"
        cards.append(f'<g><rect x="{x}" y="{y}" width="{card_w}" height="{card_h}" rx="10" fill="#f8fafc" stroke="#cbd5e1"/><text x="{x+10}" y="{y+16}" font-family="Arial" font-size="11" fill="#0f172a">{title}</text><text x="{x+10}" y="{y+31}" font-family="Arial" font-size="10" fill="#475569">{meta}</text>{svg_shape(sample,x+10,y+38,card_w-20,card_h-48)}</g>')
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}"><rect width="100%" height="100%" fill="#e2e8f0"/>{''.join(cards)}</svg>'''


def make_html(samples: list[dict]) -> str:
    data = js(samples)
    return f'''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>CB-01 原始准度球形抽样100</title><style>body{{margin:0;background:#0f172a;color:#e2e8f0;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}}header{{position:sticky;top:0;background:#111827ee;backdrop-filter:blur(8px);padding:16px 20px;z-index:2}}h1{{font-size:20px;margin:0 0 6px}}p{{margin:4px 0;color:#94a3b8;font-size:13px}}button{{margin-right:8px;margin-top:8px;background:#334155;color:#e2e8f0;border:1px solid #64748b;border-radius:7px;padding:7px 11px;cursor:pointer}}button.active{{background:#eab308;color:#422006;border-color:#facc15}}main{{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:12px;padding:16px}}article{{background:#f8fafc;color:#0f172a;border-radius:10px;padding:8px;box-shadow:0 3px 12px #02061755}}article h2{{font-size:12px;margin:0 0 3px}}article .meta{{font-size:11px;color:#475569;margin-bottom:5px}}svg{{display:block;width:100%;height:auto}}.legend{{display:flex;gap:14px;flex-wrap:wrap;font-size:12px;margin-top:8px}}.dot{{display:inline-block;width:10px;height:10px;border-radius:50%;margin-right:4px;vertical-align:-1px}} </style></head><body><header><h1>CB-01 原始准度球形抽样 100</h1><p>按距离位元与袋口分层抽样。图中为跳球几何候选，切换障碍球在线上 30%、50%、70% 的位置。</p><button data-r="0.3">障碍 30%</button><button data-r="0.5" class="active">障碍 50%</button><button data-r="0.7">障碍 70%</button><div class="legend"><span><i class="dot" style="background:#f8fafc;border:1px solid #1e3a8a"></i>母球</span><span><i class="dot" style="background:#ef4444"></i>目标球</span><span><i class="dot" style="background:#facc15"></i>障碍球</span><span><i class="dot" style="background:#d1d5db;border:1px solid #64748b"></i>假想球</span></div></header><main id="grid"></main><script>const samples={data};let ratio='0.5';const grid=document.getElementById('grid');function point(p){{return [8+(p.x+1.27)/2.54*264,24+(p.z+0.635)/1.27*122]}}function card(s){{const cue=point(s.cue),target=point(s.target),ghost=point(s.ghost),ob=point(s.variants[ratio].obstacle);const pockets=[[0,0],[140,0],[280,0],[0,122],[140,122],[280,122]].map(([x,y])=>`<circle cx="${{x+0}}" cy="${{y+10}}" r="5" fill="#111827"/>`).join('');return `<article><h2>${{String(s.sampleIndex).padStart(3,'0')}} · ${{s.sourceLayoutID}}</h2><div class="meta">d${{s.distanceBit}} · ${{s.cueTargetDistanceMetres.toFixed(2)}}m · 袋${{s.pocket}} · rail${{s.railIndex}}</div><svg viewBox="0 0 280 142"><rect x="0" y="10" width="280" height="122" rx="8" fill="#176044" stroke="#0b3d2b" stroke-width="2"/>${{pockets}}<line x1="${{cue[0]}}" y1="${{cue[1]}}" x2="${{ghost[0]}}" y2="${{ghost[1]}}" stroke="#d9f99d" stroke-width="1" stroke-dasharray="3 3"/><circle cx="${{ghost[0]}}" cy="${{ghost[1]}}" r="5" fill="none" stroke="#d1d5db"/><circle cx="${{ob[0]}}" cy="${{ob[1]}}" r="5" fill="#facc15" stroke="#713f12"/><circle cx="${{target[0]}}" cy="${{target[1]}}" r="5" fill="#ef4444" stroke="#7f1d1d"/><circle cx="${{cue[0]}}" cy="${{cue[1]}}" r="5" fill="#f8fafc" stroke="#1e3a8a"/></svg></article>`}}function render(){{grid.innerHTML=samples.map(card).join('')}}document.querySelectorAll('button').forEach(b=>b.onclick=()=>{{ratio=b.dataset.r;document.querySelectorAll('button').forEach(x=>x.classList.toggle('active',x===b));render()}});render();</script></body></html>'''


def main() -> None:
    groups = load_groups()
    samples = make_samples(groups)
    payload = {"schema": "cb01-source-filter-sample-v1", "count": len(samples), "sampling": "stratified by distanceBit and pocket, deterministic", "rows": samples}
    OUT_JSON.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
    OUT_SVG.write_text(make_svg(samples))
    OUT_HTML.write_text(make_html(samples))
    print(json.dumps({"count": len(samples), "json": str(OUT_JSON), "html": str(OUT_HTML), "svg": str(OUT_SVG)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
