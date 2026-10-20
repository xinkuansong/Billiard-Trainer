#!/usr/bin/env python3
"""Independent v3 mask reconstruction, 270-cell v2 comparison and native-coordinate gallery."""
import collections
import hashlib
import html
import json
import math
import re
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import grid_inventory_report as base
import grid_anchor_gallery as gallery

OUT = base.ROOT / "output/accuracy-grid-staggered-v3-20261021"
OLD = base.ROOT / "output/accuracy-grid-anchor-v2-20261021"


def audit(data, previous):
    assert data["version"] == "pg-gc-grid-v3-15cm-2deg-staggered"
    assert not data["solved"] and data["gridAngleDegrees"] == 2 and data["gridDistanceMetres"] == .15
    assert data["geometry"] == previous["geometry"], "Geometry must be identical; sampling only"
    manifest = json.loads((OUT/"source-manifest.json").read_text())
    assert data["sourceFingerprint"] == manifest["fingerprint"]
    for file, digest in manifest["files"].items():
        assert hashlib.sha256((base.ROOT/file).read_bytes()).hexdigest() == digest, file
    distances = np.array(data["distanceSamples"])
    assert len(distances) == 11 and np.allclose(distances, .3+np.arange(11)*.15, atol=1e-12, rtol=0)
    raw = 0
    for pocket in range(6):
        maximum = 90 if pocket < 4 else 180
        for pi in range(11):
            for angle in range(maximum+1):
                if angle not in (0,maximum) and angle%2 != pi%2:
                    continue
                for ci in range(11):
                    raw += sum(b in (-85,0,85) or abs(b)%2 == (pi+angle//2+ci)%2 for b in range(-85,86))
    assert raw == data["rawGridCandidates"]
    g = data["geometry"]
    rebuilt = {k: np.zeros(270, dtype=np.int64) for k in ("gridPlacement","gridClean","boundaryPlacement","boundaryClean")}
    by_pocket = collections.defaultdict(collections.Counter)
    betas = np.arange(-85,86)
    radians = np.deg2rad(betas)
    ai = np.select([abs(betas)<=10,abs(betas)<=30,abs(betas)<=50,abs(betas)<=70],[0,1,2,3],default=4)
    keys = set()
    parity = collections.Counter()
    for t in data["targets"]:
        o, ghost, p = (base.point(t[k]) for k in ("object","ghost","aim"))
        center = base.point(g["pockets"][t["pocket"]]["center"])
        expected = np.array([np.sign(center[0])*(g["length"]/2-g["radius"]) if t["pocket"]<4 else 0,
                             np.sign(center[1])*(g["width"]/2-(g["radius"] if t["pocket"]<4 else 0))])
        assert np.linalg.norm(p-expected)<1e-10
        key = (t["pocket"], *np.round(np.concatenate((o,ghost))*1e7).astype(np.int64))
        assert key not in keys
        keys.add(key)
        assert not base.captured(o,g) and not base.captured(ghost,g)
        assert abs(np.linalg.norm(ghost-o)-2*g["radius"])<1e-7
        backwards = (ghost-o)/np.linalg.norm(ghost-o)
        assert np.linalg.norm(backwards-(o-p)/np.linalg.norm(o-p))<1e-7
        local = backwards*np.array([-1 if t["pocket"]<4 and p[0]>0 else 1, -1 if p[1]>0 else 1])
        bearing = math.degrees(math.atan2(local[1],local[0]))
        # Swift rounded() is half-away-from-zero.
        rounding = lambda x: int(math.copysign(math.floor(abs(x)+.5),x))
        phase = (rounding((t["pg"]-.3)/.15)+int(rounding(bearing)/2)) % 2
        assert t["cutPhaseBase"] == phase
        masks = np.array(t["masks"],dtype=np.uint16)
        assert masks.shape==(171,) and np.all(masks < (1<<11))
        mask = ((masks[:,None] >> np.arange(11)) & 1).astype(bool)
        allowed = (abs(betas[:,None])%2 == (phase+np.arange(11)[None,:])%2) | (abs(betas[:,None])==0) | (abs(betas[:,None])==85)
        assert not np.any(mask & ~allowed), "Cut phase mismatch"
        dirs = np.stack((backwards[0]*np.cos(radians)-backwards[1]*np.sin(radians),
                         backwards[0]*np.sin(radians)+backwards[1]*np.cos(radians)),axis=-1)
        cues = ghost+dirs[:,None,:]*distances[None,:,None]
        co = np.linalg.norm(cues-o,axis=-1)
        op = float(np.linalg.norm(p-o))
        assert np.all(co[mask]>=.3-1e-6) and np.all(co[mask]<=1.8+1e-6)
        if mask.any(): assert .25-1e-6 <= op <= 1.8+1e-6
        gap = base.rail_gap(o,g)
        rail = 2 if abs(gap)<=base.EPSILON else 1 if gap<=.1+base.EPSILON else 0
        assert gap>=-base.EPSILON
        if t["source"]=="grid":
            pg_index = int(np.argmin(abs(distances-t["pg"])))
            assert abs(distances[pg_index]-t["pg"])<1e-10
            degree = round(t["bearing"])
            assert abs(degree-t["bearing"])<1e-7
            assert degree in (0,90 if t["pocket"]<4 else 180) or degree%2 == pg_index%2
            parity[degree%2] += int(mask.sum())
        else:
            assert t["source"]=="frozen-boundary" and rail==2
            # Boundary supplement must lie on a finite main rail at .15m steps or its endpoint.
            matches = []
            for line in g["lines"][:6]:
                start,end,n = (base.point(line[k]) for k in ("start","end","normal"))
                length = np.linalg.norm(end-start)
                foot = o-n*g["radius"]
                along = float(np.dot(foot-start,(end-start)/length))
                residual = np.linalg.norm(foot-(start+(end-start)*along/length))
                if residual<1e-7 and -1e-7<=along<=length+1e-7:
                    matches.append(abs(along/.15-round(along/.15))<1e-6 or abs(along-length)<1e-7)
            assert any(matches), "Frozen boundary step mismatch"
        indices = (((ai[:,None]*2+int(t["pocket"]>=4))*3+base.band(co))*3+base.band(op))*3+rail
        tally = np.bincount(indices[mask],minlength=270)
        prefix = "grid" if t["source"]=="grid" else "boundary"
        rebuilt[prefix+"Placement"] += tally
        if t["clean"]: rebuilt[prefix+"Clean"] += tally
        by_pocket[t["pocket"]][prefix+"Placement"] += int(mask.sum())
        if t["clean"]: by_pocket[t["pocket"]][prefix+"Clean"] += int(mask.sum())
    assert len(data["cells"])==270
    for k,v in rebuilt.items(): assert v.tolist()==[c[k] for c in data["cells"]],k
    assert len({by_pocket[p]["gridPlacement"] for p in range(4)})==1
    assert by_pocket[4]["gridPlacement"]==by_pocket[5]["gridPlacement"]
    assert parity[0]>0 and parity[1]>0
    changes=[]
    for old,new in zip(previous["cells"],data["cells"]):
        assert old["cell"]==new["cell"]
        before=old["gridPlacement"]+old["boundaryPlacement"]
        after=new["gridPlacement"]+new["boundaryPlacement"]
        changes.append(dict(cell=new["cell"],cellID=base.cell_id(new["cell"]),old=before,new=after,delta=after-before))
    placement = rebuilt["gridPlacement"]+rebuilt["boundaryPlacement"]
    clean = rebuilt["gridClean"]+rebuilt["boundaryClean"]
    summary=dict(version=data["version"],geometryOnly=True,physicsValidated=0,
        placement=int(placement.sum()),clean=int(clean.sum()),
        occupiedCells=int(np.count_nonzero(placement)),emptyCells=int(np.count_nonzero(placement==0)),
        atLeast500Cells=int(np.count_nonzero(placement>=500)),
        smallCells=int(np.count_nonzero((placement>0)&(placement<500))),
        counts={k:int(v.sum()) for k,v in rebuilt.items()},perPocket={str(k):dict(v) for k,v in by_pocket.items()},
        geometrySeconds=data["seconds"],angleParityCounts=dict(parity),reconstructedAllMasks=True,
        comparison=dict(previousPlacement=sum(c["old"] for c in changes),
            previousClean=sum(c["gridClean"]+c["boundaryClean"] for c in previous["cells"]),
            previousOccupied=sum(c["old"]>0 for c in changes),
            previousAtLeast500=sum(c["old"]>=500 for c in changes),
            previousSmall=sum(0<c["old"]<500 for c in changes),
            previousEmpty=sum(c["old"]==0 for c in changes),
            newlyEmpty=sum(c["old"]>0 and c["new"]==0 for c in changes),
            newlyOccupied=sum(c["old"]==0 and c["new"]>0 for c in changes),
            fellBelow500=sum(c["old"]>=500 and c["new"]<500 for c in changes)),
        oldInventorySHA256=hashlib.sha256((OLD/"inventory.json").read_bytes()).hexdigest(),
        inventorySHA256=hashlib.sha256((OUT/"inventory.json").read_bytes()).hexdigest())
    (OUT/"comparison-v2-v3.json").write_text(json.dumps(changes,ensure_ascii=False,indent=2))
    (OUT/"audit.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2))
    return summary,changes


def render(data,summary,changes):
    # Retain the existing native-coordinate, per-cell SVG preview and filters.
    base.DIRECTORY=OUT
    base.render(data,summary)
    page=(OUT/"组合分布.html").read_text()
    page=page.replace("1°／10厘米网格：组合分布","15cm／2°交错网格：新旧组合对比").replace("新基准使","采样调整使")
    notes=("仅几何统计，未求解、未做近似去重，镜像保留。PG／GC为0.30～1.80m，步长15cm；"
        "入袋角按PG距离层交替奇偶；切角奇偶随PG／GC距离层及入袋角档位交替，0°和±85°单独保留。"
        "入袋角端点保留；贴库边界每15cm及端点补采样，其PG／入袋角可不在普通网格上。"
        "角袋P为台面顶点各内收R，中袋P为长边中点；几何与旧版完全一致。空格不代表物理无解。")
    page=re.sub(r'<p class="note">.*?</p>',lambda _: '<p class="note">'+notes+'</p>',page,count=1)
    newly_empty=[]
    for d in changes:
        if d["old"] > 0 and d["new"] == 0:
            c=d["cell"]
            newly_empty.append(
                f"{base.ANGLES[c['angleIndex']]}／{base.POCKETS[c['pocketType']]}／"
                f"CO {base.DISTANCES[c['cueIndex']]}／OP {base.DISTANCES[c['objectIndex']]}／"
                f"{base.RAILS[c['railIndex']]}：{d['old']} → 0")
    overview=(f"总候选 {summary['comparison']['previousPlacement']:,} → {summary['placement']:,}；"
        f"有候选组合 {summary['comparison']['previousOccupied']} → {summary['occupiedCells']}；"
        f"至少500个候选的组合 {summary['comparison']['previousAtLeast500']} → {summary['atLeast500Cells']}。")
    page=page.replace('<div class="filters">',
        '<p>'+overview+'</p><p>新增空组合：<br>'+'<br>'.join(map(html.escape,newly_empty))+
        '</p><div class="filters">',1)
    page=page.replace("</tr></thead>","<th>旧版总候选</th><th>数量变化</th></tr></thead>",1)
    for i,c in enumerate(changes):
        pattern=rf'(<tr [^>]*onclick="show\({i}\)"[^>]*>.*?)(</tr>)'
        page=re.sub(pattern,lambda m:m[1]+f'<td>{c["old"]:,}</td><td>{c["delta"]:+,}</td>'+m[2],page,count=1)
    page=page.replace('<div class="filters">','<p><a href="球形预览.html">查看30个新网格球形 →</a> · <a href="新旧对比.md">对比摘要及270格明细</a></p><div class="filters">',1)
    (OUT/"组合分布.html").write_text(page)
    lines=["# 15cm／2°交错网格与旧版对比","",notes,"",
        "| 指标 | 旧版10cm／1° | 新版15cm／2°交错 |","|---|---:|---:|",
        f"| 几何候选 | {summary['comparison']['previousPlacement']:,} | {summary['placement']:,} |",
        f"| 有候选组合 | {summary['comparison']['previousOccupied']} | {summary['occupiedCells']} |",
        f"| ≥500题组合 | {summary['comparison']['previousAtLeast500']} | {summary['atLeast500Cells']} |",
        f"| 1～499题组合 | {summary['comparison']['previousSmall']} | {summary['smallCells']} |",
        f"| 空组合 | {summary['comparison']['previousEmpty']} | {summary['emptyCells']} |","",
        f"新增空组合{summary['comparison']['newlyEmpty']}个；新增有题组合{summary['comparison']['newlyOccupied']}个；"
        f"原≥500降至不足500的组合{summary['comparison']['fellBelow500']}个。",
        "", "新增空组合：", "", *["- "+label for label in newly_empty], "",
        "距离15cm网格不完全是旧10cm网格的子集，因此个别组合可能增加。","",
        "| 角度 | 袋型 | CO | OP | 库距 | 旧数量 | 新数量 | 变化 |","|---|---|---|---|---|---:|---:|---:|"]
    for d in changes:
        c=d["cell"]
        lines.append(f"| {base.ANGLES[c['angleIndex']]} | {base.POCKETS[c['pocketType']]} | {base.DISTANCES[c['cueIndex']]} | {base.DISTANCES[c['objectIndex']]} | {base.RAILS[c['railIndex']]} | {d['old']} | {d['new']} | {d['delta']:+} |")
    (OUT/"新旧对比.md").write_text("\n".join(lines)+"\n")
    # Replace the renderer's legacy-labelled markdown with the current comparison.
    (OUT/"组合分布.md").write_text("\n".join(lines)+"\n")
    samples=gallery.select(data)
    assert len(samples)==30
    folder=OUT/"samples";folder.mkdir(exist_ok=True)
    images=[];cards=[]
    for i,s in enumerate(samples,1):
        image=gallery.sample_image(s,data["geometry"],i)
        image.save(folder/f"{i:02d}.png");images.append(image)
        s["image"]=f"samples/{i:02d}.png"
        cards.append(f'<a href="{s["image"]}" target="_blank"><img src="{s["image"]}" alt="{html.escape(s["cellID"])}"></a>')
    (OUT/"render-samples.json").write_text(json.dumps(dict(version=data["version"],
        sourceFingerprint=data["sourceFingerprint"],samples=samples),ensure_ascii=False,indent=2))
    preview=f'''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>15cm／2°交错 · 球形预览</title><style>body{{max-width:1500px;margin:32px auto;padding:0 20px;background:#f4f7f6;color:#193d32;font:17px -apple-system,sans-serif}}p{{line-height:1.8}}.grid{{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px}}img{{width:100%;border-radius:12px}}@media(max-width:800px){{.grid{{grid-template-columns:1fr}}}}</style>
<h1>15cm／2°交错：30个球形样例</h1><p>{notes}</p><p>按5档角度×2袋型×3库距选取；白球C、红球O、蓝色空心假想球G、橙色P。连线为几何参考，不是物理轨迹。点击可放大。</p><p><a href="组合分布.html">查看270个组合的新旧数量对比</a></p><div class="grid">{"".join(cards)}</div></html>'''
    (OUT/"球形预览.html").write_text(preview)
    for group in range(3):
        overview=Image.new("RGB",(1800,1740),"#f4f7f6");draw=ImageDraw.Draw(overview)
        draw.text((24,18),f"15cm／2°交错 · 球形 {group*10+1:02d}—{group*10+10:02d}",font=ImageFont.truetype(gallery.FONT,34),fill="#193d32")
        draw.text((24,65),"原生几何候选；尚未求解。蓝空心圈为假想球，橙色P为目标袋基准。",font=ImageFont.truetype(gallery.FONT,24),fill="#50675e")
        for slot,image in enumerate(images[group*10:(group+1)*10]):
            overview.paste(image.resize((600,400),Image.Resampling.LANCZOS),((slot%3)*600,120+(slot//3)*400))
        overview.save(OUT/f"球形概览-{group+1}.png")


if __name__=="__main__":
    data=json.loads((OUT/"inventory.json").read_text())
    previous=json.loads((OLD/"inventory.json").read_text())
    summary,changes=audit(data,previous)
    render(data,summary,changes)
    print(json.dumps(summary,ensure_ascii=False,indent=2))
