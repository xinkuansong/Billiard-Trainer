#!/usr/bin/env python3
"""Draw unsolved center-five samples from the exact frozen input coordinates."""
import hashlib
import html
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import grid_anchor_gallery as gallery
import grid_inventory_report as report

OUT = report.ROOT / "output/accuracy-center-five-20261021"
SOURCE = report.ROOT / "output/accuracy-grid-anchor-v2-20261021"


def draw_card(sample, result, geometry):
    image = Image.new("RGB", (900, 650), "#f4f7f6")
    draw = ImageDraw.Draw(image)
    title = ImageFont.truetype(gallery.FONT, 25)
    small = ImageFont.truetype(gallery.FONT, 20)
    number = result["sampleIndex"] + 1
    rail = report.RAILS[sample["cell"]["railIndex"]]
    draw.text((24, 18), f"原图 {number:02d} · {gallery.POCKET_NAMES[sample['pocket']]} · {abs(sample['signedAngle'])}° · {rail}",
              font=title, fill="#193d32")
    draw.text((24, 57), f"母球距目标球 {sample['cueDistance']:.2f}m   目标球距P {sample['objectDistance']:.2f}m   库距 {max(0,sample['gap'])*100:.2f}cm",
              font=small, fill="#50675e")
    scale = 290
    xy = lambda p: (450 + p[0] * scale, 295 + p[1] * scale)
    gallery.table(draw, geometry, xy, scale)
    cue, target, ghost, anchor = [report.point(sample[k]) for k in ("cue", "target", "ghost", "aim")]
    draw.line([xy(cue), xy(ghost)], fill="#408dc0", width=3)
    draw.line([xy(target), xy(anchor)], fill="#8e9d94", width=2)
    for point, fill, border in [(ghost, None, "#408dc0"), (target, "#dc6558", "#8c382f"), (cue, "#ffffff", "#408dc0")]:
        x, y = xy(point)
        radius = geometry["radius"] * scale
        draw.ellipse((x-radius, y-radius, x+radius, y+radius), fill=fill, outline=border, width=2)
    gallery.cross(draw, xy, anchor)
    draw.text((24, 510), "本轮5次未找到进球力度", font=title, fill="#a55632")
    speeds = " → ".join(f"{t['speed']:.3f}".rstrip("0").rstrip(".") for t in result["trials"])
    draw.text((24, 550), f"尝试力度：{speeds} m/s", font=small, fill="#36584a")
    draw.text((24, 586), "白球 / 红色目标球 / 蓝圈假想球 / 橙色P（目标袋基准）", font=small, fill="#50675e")
    draw.text((24, 616), "蓝线是固定瞄准方向，灰线是参考进球方向；均非实测轨迹。", font=small, fill="#50675e")
    return image


def main():
    data = json.loads((OUT / "results.json").read_text())
    for name, key in [("inventory.json", "inventorySHA256"), ("render-samples.json", "gallerySHA256")]:
        assert hashlib.sha256((SOURCE / name).read_bytes()).hexdigest() == data[key]
    samples = json.loads((SOURCE / "render-samples.json").read_text())["samples"]
    geometry = json.loads((SOURCE / "inventory.json").read_text())["geometry"]
    failures = [r for r in data["results"] if not r.get("proof")]
    assert len(failures) == 15
    destination = OUT / "failed-samples"
    destination.mkdir(exist_ok=True)
    images, cards = [], []
    for result in failures:
        sample = samples[result["sampleIndex"]]
        assert not any(t["targetPotted"] for t in result["trials"])
        assert len(result["trials"]) == 5
        assert result["cellID"] == sample["cellID"]
        number = result["sampleIndex"] + 1
        name = f"{number:02d}.png"
        image = draw_card(sample, result, geometry)
        image.save(destination / name)
        images.append(image)
        c = sample["cell"]
        cards.append(f'<a class="card" data-pocket="{c["pocketType"]}" data-rail="{c["railIndex"]}" href="failed-samples/{name}" target="_blank"><img src="failed-samples/{name}" alt="原图{number:02d}，切角{abs(sample["signedAngle"])}度，{html.escape(report.RAILS[c["railIndex"]])}"></a>')
    # Fresh diagram composition, each card derived from native geometry coordinates.
    overview = Image.new("RGB", (1800, 2320), "#f4f7f6")
    draw = ImageDraw.Draw(overview)
    draw.text((24, 20), "中杆五次试跑 · 15个未通过球形", font=ImageFont.truetype(gallery.FONT, 38), fill="#193d32")
    draw.text((24, 76), "11个中袋、4个角袋；7个贴库、5个半贴库、3个非近库。未通过不等于无解。", font=ImageFont.truetype(gallery.FONT, 25), fill="#50675e")
    for i, image in enumerate(images):
        overview.paste(image.resize((600, 433), Image.Resampling.LANCZOS), ((i % 3)*600, 135+(i//3)*433))
    overview.save(OUT / "未通过球形概览.png")
    page = """<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>中杆五次 · 未通过球形</title><style>
body{font:17px -apple-system,sans-serif;background:#f4f7f6;color:#193d32;max-width:1500px;margin:32px auto;padding:0 24px}
p{line-height:1.8}a{color:#286c59}.filters{display:flex;gap:24px;margin:24px 0}select{font:inherit;padding:8px}
.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:22px}.card{border:1px solid #d7e1dc;border-radius:12px;overflow:hidden}
.card[hidden]{display:none}img{display:block;width:100%}@media(max-width:760px){.grid{grid-template-columns:1fr}}
</style><h1>中杆五次试跑：未通过的15个球形</h1>
<p>这轮30个球形中，以下15个在最多5次力度尝试内没有进指定袋。统一中杆，方向固定指向假想球；母球落袋不参与筛选。编号沿用原30例图册，点击图片可放大。</p>
<p><b>11个中袋、4个角袋；7个贴库、5个半贴库、3个非近库。</b>这些类别有重叠。“未通过”只表示本轮未找到解，不能据图断言球形无解或确定失败原因。</p>
<p>白色为母球，红色为目标球，蓝色空心圈为假想球，橙色P标记目标袋基准。蓝线是固定瞄准方向，灰线是参考进球方向，<b>不是实测运动轨迹</b>。假想球仅供这次审图查看。</p>
<div class="filters"><label>袋型 <select data-key="pocket"><option value="">全部</option><option value="0">角袋</option><option value="1">中袋</option></select></label>
<label>库距 <select data-key="rail"><option value="">全部</option><option value="0">非近库</option><option value="1">半贴库</option><option value="2">贴库</option></select></label></div>
<p id="count"></p><div class="grid">CARDS</div>
<script>function filter(){let n=0;const selections=[...document.querySelectorAll('select')];document.querySelectorAll('.card').forEach(c=>{c.hidden=!selections.every(s=>s.value===''||c.dataset[s.dataset.key]===s.value);if(!c.hidden)n++;});document.getElementById('count').textContent=`当前显示 ${n} 个球形`;}document.querySelectorAll('select').forEach(s=>s.addEventListener('change',filter));filter();</script></html>"""
    (OUT / "未通过球形.html").write_text(page.replace("CARDS", "".join(cards)))
    (OUT / "failed-gallery.json").write_text(json.dumps({
        "resultsSHA256": hashlib.sha256((OUT / "results.json").read_bytes()).hexdigest(),
        "sampleNumbers": [r["sampleIndex"] + 1 for r in failures],
        "count": len(failures), "trajectoriesShown": False,
    }, indent=2))
    print(f"Rendered {len(failures)} failed layouts")


if __name__ == "__main__":
    main()
