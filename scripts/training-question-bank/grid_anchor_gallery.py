#!/usr/bin/env python3
"""Render actual v2 inventory coordinates, with deterministic stratified samples."""
import hashlib
import html
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import grid_inventory_report as report

DIRECTORY = report.ROOT / "output/accuracy-grid-anchor-v2-20261021"
FONT = "/System/Library/Fonts/STHeiti Medium.ttc"
POCKET_NAMES = ["左上角袋", "右上角袋", "左下角袋", "右下角袋", "上中袋", "下中袋"]


def select(data):
    """One sample per angle × pocket type × rail class; prefer regular grid.

    Choose a desired actual pocket per stratum, then deterministic hash rank.
    This spreads orientations without making a claim about random-show weights.
    """
    picks = {}
    geometry = data["geometry"]
    for ti, target in enumerate(data["targets"]):
        o, g = (report.point(target[k]) for k in ("object", "ghost"))
        base = (g-o)/np.linalg.norm(g-o)
        gap = report.rail_gap(o, geometry)
        rail = 2 if abs(gap) <= report.EPSILON else 1 if gap <= .1+report.EPSILON else 0
        pocket_type = int(target["pocket"] >= 4)
        for ai, (lo, hi) in enumerate([(0, 10), (11, 30), (31, 50), (51, 70), (71, 85)]):
            options = [(j, mask) for j, mask in enumerate(target["masks"]) if lo <= abs(j-85) <= hi and mask]
            if not options:
                continue
            digest = hashlib.sha256(f"anchor-v2-gallery:{ti}:{ai}".encode()).digest()
            j, mask = options[int.from_bytes(digest[:4], "little") % len(options)]
            distances = data.get("distanceSamples", [(i+3)/10 for i in range(16)])
            bits = [bit for bit in range(len(distances)) if mask & (1 << bit)]
            bit = bits[int.from_bytes(digest[4:8], "little") % len(bits)]
            desired_pocket = (ai+rail) % 4 if pocket_type == 0 else 4+(ai+rail) % 2
            rank = (target["source"] != "grid", target["pocket"] != desired_pocket, digest)
            key = (ai, pocket_type, rail)
            if key in picks and rank >= picks[key][0]:
                continue
            beta = j-85
            a = np.deg2rad(beta)
            direction = np.array([base[0]*np.cos(a)-base[1]*np.sin(a),
                                  base[0]*np.sin(a)+base[1]*np.cos(a)])
            gc = distances[bit]
            cue = g+direction*gc
            co = np.linalg.norm(cue-o)
            op = np.linalg.norm(report.point(target["aim"])-o)
            ci, oi = int(report.band(co)), int(report.band(op))
            cell = dict(angleIndex=ai, pocketType=pocket_type, cueIndex=ci, objectIndex=oi, railIndex=rail)
            sample = dict(cellID=report.cell_id(cell), cell=cell, targetIndex=ti,
                          pocket=target["pocket"], source=target["source"], signedAngle=beta,
                          cue=dict(x=float(cue[0]), z=float(cue[1])), target=target["object"],
                          ghost=target["ghost"], aim=target["aim"], gap=gap,
                          cueDistance=float(co), objectDistance=float(op), gc=gc,
                          pg=target["pg"], bearing=target["bearing"], clean=target["clean"],
                          solved=False)
            assert target["masks"][beta+85] & (1 << bit)
            assert abs(np.linalg.norm(cue-g)-gc) < 1e-9
            picks[key] = (rank, sample)
    return [picks[key][1] for key in sorted(picks)]


def table(draw, geometry, xy, scale):
    # Display primitives are exported from the same native model as inventory.
    corners = [xy(np.array([x, z])) for x, z in
               [(-geometry["length"]/2, -geometry["width"]/2),
                (geometry["length"]/2, geometry["width"]/2)]]
    draw.rectangle((*corners[0], *corners[1]), fill="#e4f2ed")
    for line in geometry["lines"]:
        draw.line([xy(report.point(line["start"])), xy(report.point(line["end"]))],
                  fill="#235948", width=3)
    for arc in geometry["arcs"]:
        angles = np.linspace(arc["start"], arc["start"]+(arc["end"]-arc["start"]) % (2*np.pi), 48)
        points = [xy(report.point(arc["center"])+arc["radius"]*np.array([np.cos(a), np.sin(a)])) for a in angles]
        draw.line(points, fill="#235948", width=3)
    for pocket in geometry["pockets"]:
        x, y = xy(report.point(pocket["center"]))
        r = pocket["radius"]*scale
        draw.ellipse((x-r, y-r, x+r, y+r), fill="#243c34")
        draw.polygon([xy(report.point(p)) for p in pocket["lip"]], fill="#243c34")


def cross(draw, xy, p, label=True):
    x, y = xy(p)
    draw.line((x-7, y, x+7, y), fill="#e78616", width=3)
    draw.line((x, y-7, x, y+7), fill="#e78616", width=3)
    if label:
        draw.text((x+8, y-21), "P", font=ImageFont.truetype(FONT, 19), fill="#a45806")


def sample_image(s, geometry, number):
    image = Image.new("RGB", (900, 600), "#f4f7f6")
    draw = ImageDraw.Draw(image)
    title, small = ImageFont.truetype(FONT, 23), ImageFont.truetype(FONT, 19)
    c = s["cell"]
    draw.text((24, 18), f"{number:02d}  {POCKET_NAMES[s['pocket']]}  ·  切角 {abs(s['signedAngle'])}°  ·  {report.RAILS[c['railIndex']]}",
              fill="#193d32", font=title)
    draw.text((24, 52), f"CO {report.DISTANCES[c['cueIndex']]} {s['cueDistance']:.2f}m   /   OP {report.DISTANCES[c['objectIndex']]} {s['objectDistance']:.2f}m",
              fill="#50675e", font=small)
    scale = 290
    xy = lambda p: (450+p[0]*scale, 294+p[1]*scale)
    table(draw, geometry, xy, scale)
    cue, ghost, target, aim = (report.point(s[k]) for k in ("cue", "ghost", "target", "aim"))
    draw.line([xy(cue), xy(ghost)], fill="#408dc0", width=2)
    draw.line([xy(ghost), xy(aim)], fill="#7b8f85", width=2)
    # Short reference extension only, not a simulated trajectory.
    direction = (aim-target)/np.linalg.norm(aim-target)
    for t in np.arange(0, .12, .02):
        draw.line([xy(aim+t*direction), xy(aim+(t+.01)*direction)], fill="#7b8f85", width=2)
    for p, color, border in [(ghost, None, "#408dc0"), (target, "#dc6558", "#8c382f"), (cue, "#fefefe", "#408dc0")]:
        x, y = xy(p); r = geometry["radius"]*scale
        draw.ellipse((x-r, y-r, x+r, y+r), fill=color, outline=border, width=2)
    cross(draw, xy, aim)
    gap = max(0, s["gap"])*100
    draw.text((24, 510), f"球面库距 {gap:.2f}cm  ·  PG {s['pg']:.2f}m  ·  GC {s['gc']:.2f}m", fill="#36584a", font=small)
    source = "普通网格" if s["source"] == "grid" else "贴库边界补充"
    route = "参考射线直达捕获区" if s["clean"] else "参考射线受阻，留待求解"
    draw.text((24, 540), f"{source}  ·  {route}", fill="#50675e", font=small)
    draw.text((24, 568), "白球C / 红球O / 蓝空心G / 橙色P；几何候选，尚未验解。", fill="#687a72", font=small)
    return image


def main():
    data = json.loads((DIRECTORY/"inventory.json").read_text())
    assert data["version"] == "pg-gc-grid-v2-inset-corner-middle-baseline"
    samples = select(data)
    assert len({s["pocket"] for s in samples}) == 6
    for key in ["cueIndex", "objectIndex"]:
        assert {s["cell"][key] for s in samples} == {0, 1, 2}
    out = DIRECTORY/"samples"
    out.mkdir(exist_ok=True)
    cards, images = [], []
    for i, sample in enumerate(samples, 1):
        image = sample_image(sample, data["geometry"], i)
        name = f"{i:02d}.png"
        image.save(out/name)
        sample["image"] = "samples/"+name
        images.append(image)
        c = sample["cell"]
        cards.append(f'<a class="card" data-angle="{c["angleIndex"]}" data-pocket="{c["pocketType"]}" data-rail="{c["railIndex"]}" href="samples/{name}" target="_blank"><img loading="lazy" src="samples/{name}" alt="{html.escape(sample["cellID"])}"></a>')
    (DIRECTORY/"render-samples.json").write_text(json.dumps(dict(
        version=data["version"], sourceFingerprint=data["sourceFingerprint"],
        selection="Deterministic angle/pocket-type/rail strata; regular grid preferred; not random-show weights.",
        count=len(samples), samples=samples), ensure_ascii=False, indent=2))
    # Twelve examples across both pocket types and all three rail classes.
    overview_indices = [i for i, s in enumerate(samples) if s["cell"]["angleIndex"] in (0, 3)]
    overview = Image.new("RGB", (1800, 1740), "#f4f7f6")
    d = ImageDraw.Draw(overview)
    d.text((25, 18), "新袋口基准 · 12个球形概览", fill="#193d32", font=ImageFont.truetype(FONT, 32))
    d.text((25, 63), "五档角度的完整30例见球形预览；全部为几何候选，尚未验解。", fill="#50675e", font=ImageFont.truetype(FONT, 24))
    for slot, i in enumerate(overview_indices):
        overview.paste(images[i].resize((600, 400), Image.Resampling.LANCZOS), ((slot % 3)*600, 125+(slot//3)*400))
    overview.save(DIRECTORY/"球形概览.png")
    selectors = []
    for key, label, values in [("angle", "角度", report.ANGLES), ("pocket", "袋口", report.POCKETS), ("rail", "库距", report.RAILS)]:
        options = '<option value="">全部</option>'+''.join(f'<option value="{i}">{v}</option>' for i, v in enumerate(values))
        selectors.append(f'<label>{label}<select data-key="{key}" onchange="filter()">{options}</select></label>')
    page = '''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>新袋口基准 · 球形预览</title><style>
body{font:16px -apple-system,sans-serif;background:#f4f7f6;color:#193d32;max-width:1500px;margin:32px auto;padding:0 20px}
p{line-height:1.8}a{color:#2b7461}.filters{display:flex;gap:24px;flex-wrap:wrap;margin:24px 0}select{display:block;padding:8px;font-size:16px}
.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px}.card{border:1px solid #d9e6df;border-radius:12px;overflow:hidden}
.card[hidden]{display:none}img{width:100%;display:block}@media(max-width:800px){.grid{grid-template-columns:1fr}}
</style><h1>新袋口基准 · 球形预览</h1>
<p>角袋P：有效台面顶点水平、垂直向内各收一个球半径；中袋P：长边中点。白球C、红球O、蓝色空心假想球G、橙色十字P。灰线越过P的小段是参考方向延长，不是模拟轨迹。</p>
<p>按五档角度 × 两种袋型 × 三种库距挑选30例，覆盖六个实际袋口、短中长距离。优先展示普通网格；贴库补充单独标注。所有样例来自本轮库存，尚未求解，参考通道受阻不等于无解。点击图片查看大图。</p>
<p><a href="组合分布.html">查看270个组合的数量</a> · <a href="球形概览.png">打开12例概览</a></p>
<div class="filters">FILTERS</div><p id="count"></p><div class="grid">CARDS</div>
<script>function filter(){let n=0;const selects=[...document.querySelectorAll('select')];document.querySelectorAll('.card').forEach(c=>{c.hidden=!selects.every(s=>s.value===''||c.dataset[s.dataset.key]===s.value);if(!c.hidden)n++});document.getElementById('count').textContent=`当前显示 ${n} 个球形`;}filter();</script></html>'''
    (DIRECTORY/"球形预览.html").write_text(page.replace("FILTERS", "".join(selectors)).replace("CARDS", "".join(cards)))
    distribution = DIRECTORY/"组合分布.html"
    text = distribution.read_text()
    text = text.replace('<div class="filters">', '<p><a href="球形预览.html">查看新基准的30个球形样例 →</a></p><div class="filters">', 1)
    distribution.write_text(text)
    print(json.dumps(dict(rendered=len(samples), pockets=sorted({s["pocket"] for s in samples}),
                          grid=sum(s["source"] == "grid" for s in samples)), ensure_ascii=False))


if __name__ == "__main__":
    main()
