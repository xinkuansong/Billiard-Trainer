#!/usr/bin/env python3
"""Render native-exported dedup decisions. Diagrams are not physics qualification."""
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/accuracy-dedup-review-20261021"


def svg(data, board):
    def point(p):
        return 34 + (p["x"] + data["length"]/2)*188, 32 + (p["z"] + data["width"]/2)*188
    pieces = ['<svg viewBox="0 0 546 304" role="img" aria-label="球形俯视示意">',
              '<rect x="15" y="13" width="516" height="277" rx="18" fill="#423b33"/>',
              '<rect x="34" y="32" width="477.52" height="238.76" fill="#17685d"/>']
    for rail in data["rails"]:
        x1,y1 = point(rail["start"]); x2,y2 = point(rail["end"])
        pieces.append(f'<path d="M{x1},{y1} L{x2},{y2}" stroke="#93b8a6" stroke-width="4"/>')
    for i,p in enumerate(data["pockets"]):
        x,y = point(p)
        pieces.append(f'<circle cx="{x}" cy="{y}" r="9" fill="#102c29"/>')
        if i == board["pocketIndex"]:
            pieces.append(f'<circle cx="{x}" cy="{y}" r="14" fill="none" stroke="#ffce63" stroke-width="3"/>')
    cx,cy = point(board["cue"]); tx,ty = point(board["target"]); ax,ay = point(board["effectiveAim"])
    pieces.append(f'<path d="M{cx},{cy} L{tx},{ty} L{ax},{ay}" fill="none" stroke="#b9d2c7" stroke-width="1" stroke-dasharray="4 5" opacity=".6"/>')
    for x,y,color in [(tx,ty,"#ee5a58"),(cx,cy,"#faf8ed")]:
        pieces.append(f'<circle cx="{x}" cy="{y}" r="{data["radius"]*188}" fill="{color}" stroke="#102c29" stroke-width=".8"/>')
    pieces.append('</svg>')
    return "".join(pieces)


def main():
    data = json.loads((OUT / "review.json").read_text())
    cards = []
    for i,pair in enumerate(data["pairs"],1):
        a,b = pair["featuresA"],pair["featuresB"]
        rows = []
        for title,key,unit,scale in [
            ("切球角","signedCut","°",1),("母球距离","cueDistance","cm",100),
            ("目标球距袋","objectDistance","cm",100),("目标球库距","targetGap","cm",100)]:
            rows.append(f"<tr><td>{title}</td><td>{abs(a[key])*scale:.2f}{unit}</td><td>{abs(b[key])*scale:.2f}{unit}</td></tr>")
        same = pair["sameFamily"]
        cards.append(f'''<article id="pair-{i}">
          <div class="top"><span class="number">{i:02}</span><h2>{html.escape(pair["title"])}</h2>
          <b class="badge {'same' if same else 'different'}">{'合并为同一家族' if same else '保留两道球形'}</b></div>
          <div class="boards"><figure><figcaption>A</figcaption>{svg(data,pair["a"])}</figure>
          <figure><figcaption>B</figcaption>{svg(data,pair["b"])}</figure></div>
          <div class="detail"><p>{html.escape(pair["note"])}</p><table><thead><tr><th>条件</th><th>A</th><th>B</th></tr></thead>
          <tbody>{''.join(rows)}</tbody></table></div></article>''')
    total = sum(data["inventory"].values())
    occupied = sum(v>0 for v in data["inventory"].values())
    page = f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
    <title>球形重复性 · 判据校准</title><style>
    *{{box-sizing:border-box}}body{{margin:0;background:#eef1ee;color:#172e28;font-family:-apple-system,BlinkMacSystemFont,sans-serif}}
    main{{max-width:1180px;margin:auto;padding:38px 24px}}h1{{font-size:32px;margin:12px 0}}.eyebrow{{color:#557067;font-size:13px}}
    .intro{{line-height:1.8;max-width:1000px;color:#435d53}}.rules{{padding:20px 24px;border:1px solid #cbd7cf;border-radius:16px;background:#fff;line-height:1.85;margin:25px 0}}
    article{{background:#fff;border-radius:18px;margin:22px 0;padding:22px;box-shadow:0 2px 12px #143b2308}}
    .top{{display:flex;gap:12px;align-items:center;flex-wrap:wrap}}h2{{font-size:19px;flex:1;margin:0}}.number{{color:#809288;font-size:17px}}
    .badge{{padding:7px 12px;font-size:13px;border-radius:20px}}.same{{background:#e3efe8;color:#285b40}}.different{{background:#f8ead6;color:#815418}}
    .boards{{display:grid;grid-template-columns:1fr 1fr;gap:18px;margin-top:18px}}figure{{margin:0}}figcaption{{font-size:13px;color:#6b8175;padding-left:16px}}svg{{display:block;width:100%}}
    .detail{{display:grid;grid-template-columns:1fr 1fr;gap:30px;font-size:14px;line-height:1.7}}.detail p{{color:#52695d}}
    table{{border-collapse:collapse;width:100%;font-variant-numeric:tabular-nums}}td,th{{padding:5px 8px;border-bottom:1px solid #e7ece9;text-align:right}}td:first-child,th:first-child{{text-align:left}}
    .foot{{font-size:13px;color:#62776b;line-height:1.8}}@media(max-width:700px){{main{{padding:22px 12px}}article{{padding:15px}}.detail{{grid-template-columns:1fr;gap:0}}h2{{font-size:16px}}.boards{{gap:5px}}}}
    </style><main><div class="eyebrow">准度题库 / 每组合 500 个球形家族 / 2026-10-21</div>
    <h1>哪些球形应该算重复？</h1>
    <p class="intro">这里展示的是去重判据，不是进球答案。白球为母球，红球为目标球，金圈是指定袋口。虚线仅表示球位关系。
    球桌和坐标来自 App 的原生计算；这些是几何示意图，合成变形样例尚未通过进球验证，不能直接入库。</p>
    <div class="rules"><strong>当前试行规则 {html.escape(data["ruleVersion"])}</strong><br>
    普通切角差 ≤ 0.75°；极薄球 ≤ 0.35°；入袋方向差 ≤ 1°；两段距离各差 ≤ 3% 且不超过 3 cm；
    镜像对齐后两球位移各 ≤ 4 cm。上述条件需同时满足。贴库／半贴库／离库不同则保留；
    近库还需同库段，目标球库距差 ≤ 1 cm、母球库距差 ≤ 1.5 cm。<br>
    力度和打点不参与球形去重。镜像算同一家族，不把近似关系传递合并成越来越大的群组。阈值是待校准的采样选择，不是物理定律。</div>
    {''.join(cards)}
    <p class="foot">旧准度库按本版规则审计：{total} 个球形家族，覆盖 {occupied}/270 个组合。
    这里只反映旧库覆盖，不是新库生成结果，也不代表旧证明已按当前源码重验。正式 Bundle 尚未替换。</p></main></html>'''
    (OUT / "球形去重校准.html").write_text(page)
    print(f"Rendered {len(cards)} pairs; {total} existing families / {occupied} occupied cells")
    # Standalone static diagram for direct in-chat visual review.
    from PIL import Image, ImageDraw, ImageFont
    font = "/System/Library/Fonts/STHeiti Medium.ttc"
    large = ImageFont.truetype(font,30); regular = ImageFont.truetype(font,22); small = ImageFont.truetype(font,19)
    chosen = [1,2,3,4,6,9]
    canvas = Image.new("RGB",(1500,2220),"#eef1ee"); draw=ImageDraw.Draw(canvas)
    draw.text((40,22),"球形去重校准 · 6 组成对示意",font=large,fill="#172e28")
    draw.text((40,65),"几何判据样例，非进球资格验证；金圈为指定袋口。",font=regular,fill="#536b60")
    for row,index in enumerate(chosen):
        p=data["pairs"][index]; top=115+row*345
        draw.rounded_rectangle((25,top,1475,top+325),radius=18,fill="white")
        draw.text((45,top+12),f'{index+1:02}  {p["title"]}',font=regular,fill="#172e28")
        verdict="同一家族" if p["sameFamily"] else "保留两题"
        draw.text((1280,top+12),verdict,font=regular,fill="#285b40" if p["sameFamily"] else "#815418")
        for col,b in enumerate([p["a"],p["b"]]):
            ox=75+col*715; oy=top+90
            scale=158
            def xy(point):
                return ox+80+(point["x"]+data["length"]/2)*scale,oy+(point["z"]+data["width"]/2)*scale
            draw.rounded_rectangle((ox+67,oy-13,ox+80+data["length"]*scale+13,oy+data["width"]*scale+13),radius=10,fill="#423b33")
            draw.rectangle((ox+80,oy,ox+80+data["length"]*scale,oy+data["width"]*scale),fill="#17685d")
            for rail in data["rails"]: draw.line([xy(rail["start"]),xy(rail["end"])],fill="#93b8a6",width=3)
            for pi,pocket in enumerate(data["pockets"]):
                x,y=xy(pocket);draw.ellipse((x-6,y-6,x+6,y+6),fill="#102c29")
                if pi==b["pocketIndex"]:draw.ellipse((x-10,y-10,x+10,y+10),outline="#ffce63",width=3)
            for name,color in [("target","#ee5a58"),("cue","#faf8ed")]:
                x,y=xy(b[name]);r=data["radius"]*scale;draw.ellipse((x-r,y-r,x+r,y+r),fill=color)
            f=p["featuresA" if col==0 else "featuresB"]
            draw.text((ox,oy-43),f'{"A" if col==0 else "B"}  {abs(f["signedCut"]):.2f}° / 母球 {f["cueDistance"]*100:.1f} cm',font=small,fill="#536b60")
    canvas.save(OUT/"去重样例.png")


if __name__ == "__main__":
    main()
