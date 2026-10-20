#!/usr/bin/env python3
"""Audit and render the native geometry-only PG/GC inventory. No physics solving."""
import collections
import argparse
import hashlib
import html
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
DIRECTORY = ROOT / "output/accuracy-grid-inventory-20261021"
ANGLES = ["近直球 0–10°", "小角度 11–30°", "中角度 31–50°", "大角度 51–70°", "极薄球 71–85°"]
DISTANCES = ["短", "中", "长"]
RAILS = ["离库", "半贴库", "贴库"]
POCKETS = ["角袋", "中袋"]
EPSILON = 4 * 2**-23


def point(p):
    return np.array([p["x"], p["z"]], dtype=float)


def cell_id(c):
    return f"a{c['angleIndex']}-p{c['pocketType']}-c{c['cueIndex']}-o{c['objectIndex']}-r{c['railIndex']}"


def rail_gap(p, geometry):
    gaps = []
    for line in geometry["lines"][:6]:
        a, b = point(line["start"]), point(line["end"])
        d = b-a
        t = np.clip(np.dot(p-a, d)/np.dot(d, d), 0, 1)
        gaps.append(np.linalg.norm(p-a-t*d)-geometry["radius"])
    return min(gaps)


def band(d):
    return np.where(d <= .6+1e-6, 0, np.where(d <= 1.2+1e-6, 1, 2))


def captured(p, geometry):
    for pocket in geometry["pockets"]:
        if np.linalg.norm(p-point(pocket["center"])) <= pocket["radius"]:
            return True
        lip = np.array([point(v) for v in pocket["lip"]])
        if len(lip) >= 3:
            edge = np.roll(lip, -1, axis=0)-lip
            relative = p-lip
            if np.all(edge[:, 0]*relative[:, 1]-edge[:, 1]*relative[:, 0] >= 0):
                return True
    return False


def audit(data):
    assert data["solved"] is False
    assert data["gridAngleDegrees"] == 1 and data["gridDistanceMetres"] == .1
    manifest = json.loads((DIRECTORY/"source-manifest.json").read_text())
    assert data["sourceFingerprint"] == manifest["fingerprint"]
    for file, digest in manifest["files"].items():
        assert hashlib.sha256((ROOT/file).read_bytes()).hexdigest() == digest, f"Source changed: {file}"
    assert len(data["cells"]) == 270 and len({cell_id(c["cell"]) for c in data["cells"]}) == 270
    geometry = data["geometry"]
    anchor_v2 = data["version"] == "pg-gc-grid-v2-inset-corner-middle-baseline"
    assert len(geometry["lines"]) == 44 and len(geometry["arcs"]) == 12 and len(geometry["pockets"]) == 6
    rebuilt = {key: np.zeros(270, dtype=np.int64) for key in
               ("gridPlacement", "gridClean", "boundaryPlacement", "boundaryClean")}
    betas = np.arange(-85, 86)
    radians = np.deg2rad(betas)
    distances = np.arange(3, 19)/10
    ai = np.select([abs(betas) <= 10, abs(betas) <= 30, abs(betas) <= 50, abs(betas) <= 70],
                   [0, 1, 2, 3], default=4)
    by_pocket = collections.defaultdict(lambda: collections.Counter())
    keys = set()
    for target in data["targets"]:
        o, g, p = (point(target[k]) for k in ("object", "ghost", "aim"))
        if anchor_v2:
            center = point(geometry["pockets"][target["pocket"]]["center"])
            expected = np.array([
                np.sign(center[0])*(geometry["length"]/2-geometry["radius"]) if target["pocket"] < 4 else 0,
                np.sign(center[1])*(geometry["width"]/2-(geometry["radius"] if target["pocket"] < 4 else 0))])
            assert np.linalg.norm(p-expected) < 1e-10, "All sources must use the new anchor"
        key = (target["pocket"], *(np.round(np.concatenate((o, g))*1e7).astype(np.int64)))
        assert key not in keys
        keys.add(key)
        assert not captured(o, geometry) and not captured(g, geometry)
        assert abs(np.linalg.norm(g-o)-2*geometry["radius"]) < 1e-7
        base = (g-o)/np.linalg.norm(g-o)
        assert np.linalg.norm(base-(o-p)/np.linalg.norm(o-p)) < 1e-7
        directions = np.stack((base[0]*np.cos(radians)-base[1]*np.sin(radians),
                               base[0]*np.sin(radians)+base[1]*np.cos(radians)), axis=-1)
        cues = g+directions[:, None, :]*distances[None, :, None]
        mask_values = np.array(target["masks"], dtype=np.uint16)
        assert mask_values.shape == (171,)
        mask = ((mask_values[:, None] >> np.arange(16)) & 1).astype(bool)
        co = np.linalg.norm(cues-o, axis=-1)
        op = np.linalg.norm(p-o)
        assert np.all(co[mask] >= .30-1e-6) and np.all(co[mask] <= 1.8+1e-6)
        assert np.all(co[mask] >= 2*geometry["radius"])
        if mask.any():
            assert .25-1e-6 <= op <= 1.8+1e-6
        gap = rail_gap(o, geometry)
        r = 2 if abs(gap) <= EPSILON else 1 if gap <= .1+EPSILON else 0
        assert gap >= -EPSILON
        if target["source"] == "frozen-boundary":
            assert r == 2
        else:
            assert abs(target["pg"]*10-round(target["pg"]*10)) < 1e-7
            assert abs(target["bearing"]-round(target["bearing"])) < 1e-7
        indices = (((ai[:, None]*2+int(target["pocket"] >= 4))*3+band(co))*3+band(op))*3+r
        tally = np.bincount(indices[mask], minlength=270)
        prefix = "grid" if target["source"] == "grid" else "boundary"
        rebuilt[prefix+"Placement"] += tally
        if target["clean"]:
            rebuilt[prefix+"Clean"] += tally
        by_pocket[target["pocket"]][prefix+"Placement"] += int(mask.sum())
        by_pocket[target["pocket"]][prefix+"Clean"] += int(mask.sum()) if target["clean"] else 0
    for key, counts in rebuilt.items():
        assert counts.tolist() == [c[key] for c in data["cells"]], key
    # The regular grid is mirrored without collapsing orientations.
    assert len({by_pocket[p]["gridPlacement"] for p in range(4)}) == 1
    assert by_pocket[4]["gridPlacement"] == by_pocket[5]["gridPlacement"]
    placement = rebuilt["gridPlacement"]+rebuilt["boundaryPlacement"]
    clean = rebuilt["gridClean"]+rebuilt["boundaryClean"]
    summary = dict(
        version=data["version"], geometryOnly=True, physicsValidated=0, gridAngleDegrees=1, gridDistanceMetres=.1,
        counts={k: int(v.sum()) for k, v in rebuilt.items()},
        placement=int(placement.sum()), clean=int(clean.sum()),
        blockedReferenceRoute=int((placement-clean).sum()),
        occupiedCells=int(np.count_nonzero(placement)), emptyCells=int(np.count_nonzero(placement == 0)),
        atLeast500Cells=int(np.count_nonzero(placement >= 500)),
        cleanOccupiedCells=int(np.count_nonzero(clean)), cleanAtLeast500Cells=int(np.count_nonzero(clean >= 500)),
        geometrySeconds=data["seconds"], nativePrimitives={k: len(geometry[k]) for k in ("lines", "arcs", "pockets")},
        perPocket={str(k): dict(v) for k, v in by_pocket.items()},
        inventorySHA256=hashlib.sha256((DIRECTORY/"inventory.json").read_bytes()).hexdigest(),
        sourceFingerprint=data["sourceFingerprint"], reconstructedAllMasks=True,
        note="Counts are grid candidates before near-dedup and physics; blocked reference routes do not prove no solution. Frozen boundary sampling is separate from regular PG grid.")
    pilot_path = DIRECTORY/"validation-pilot.json"
    previous_path = ROOT/"output/accuracy-grid-inventory-20261021/inventory.json"
    if anchor_v2 and previous_path.exists():
        previous = json.loads(previous_path.read_text())
        assert previous["version"] == "pg-gc-grid-v1"
        changes = []
        for old, new in zip(previous["cells"], data["cells"]):
            assert old["cell"] == new["cell"]
            before = old["gridPlacement"]+old["boundaryPlacement"]
            after = new["gridPlacement"]+new["boundaryPlacement"]
            changes.append(dict(cell=new["cell"], old=before, new=after, delta=after-before))
        (DIRECTORY/"comparison-v1-v2.json").write_text(json.dumps(changes, ensure_ascii=False, indent=2))
        summary["comparison"] = dict(
            previousPlacement=sum(c["old"] for c in changes),
            previousClean=sum(c["gridClean"]+c["boundaryClean"] for c in previous["cells"]),
            newlyEmpty=sum(c["old"] > 0 and c["new"] == 0 for c in changes),
            newlyOccupied=sum(c["old"] == 0 and c["new"] > 0 for c in changes))
    if pilot_path.exists():
        pilot = json.loads(pilot_path.read_text())
        assert pilot["sourceFingerprint"] == data["sourceFingerprint"]
        passed = [r for r in pilot["results"] if r.get("proof")]
        for result in passed:
            proof = result["proof"]
            assert proof["boardID"] == result["board"]["id"]
            assert proof["settled"] and proof["specifiedPocket"] and proof["outcome"] == "success"
            assert len(proof["samples"]) == 9
            assert all(s["outcome"] == "success" for s in proof["samples"])
            assert {(round(s["angleDeltaDegrees"], 5), round(s["velocityDelta"], 5))
                    for s in proof["samples"]} == {(a, v) for a in [-.025, 0, .025] for v in [-.05, 0, .05]}
            assert not any(k in proof for k in ["frames", "trajectory", "cuePath", "targetPath"])
        summary["physicsPilot"] = dict(attempted=len(pilot["results"]), verified=len(passed),
                                      blockedReferenceButVerified=sum(not r["referenceRouteClean"] for r in passed),
                                      scope=pilot["scope"])
    (DIRECTORY/"audit.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2))
    return summary


def render(data, summary):
    anchor_v2 = data["version"] == "pg-gc-grid-v2-inset-corner-middle-baseline"
    title = ("新袋口基准 · " if anchor_v2 else "")+"1°／10厘米网格：组合分布"
    intro = (
        f"几何摆位与母球直达接触位置通过：{summary['placement']:,}；"
        f"其中目标球参考直线进袋通道通过：{summary['clean']:,}。"
        f"270组合中{summary['occupiedCells']}个有候选、{summary['emptyCells']}个为空。")
    intro += (f"其中{summary['atLeast500Cells']}个组合≥500；"
              f"{summary['occupiedCells']-summary['atLeast500Cells']}个组合为1–499。")
    if "comparison" in summary:
        c = summary["comparison"]
        intro += (f"旧版总候选{c['previousPlacement']:,}、参考通道通过{c['previousClean']:,}；"
                  f"新基准使{c['newlyEmpty']}格由非空变空、{c['newlyOccupied']}格由空变非空。")
    notes = (
        "这些是几何候选，不是已验证进球的题目，未做近似球形去重。镜像保留。"
        "普通网格PG／GC各0.30–1.80m，角度1°、距离10cm；分类仍按CO／OP现有距离档。"
        + ("角袋P取台面顶点向内各收一个球半径，中袋P取长边中点；普通网格与贴库补充共用同一P。参考进袋射线越过P继续检查实际捕获。"
           if anchor_v2 else "P在普通网格固定为原生袋心；贴库补充采用实际有效袋口瞄点。")
        + "贴库另按有限主库每10cm及端点补采样，单独计数；其PG和入袋方向不保证仍在普通网格上。"
        "参考通道受阻不直接判物理无解，后续可搜索实际方向并验证袋角参与的进球。空格只表示本次网格没有候选。")
    if "physicsPilot" in summary:
        p = summary["physicsPilot"]
        notes += (f"代表性求解试跑：{p['attempted']}球中{p['verified']}球获得九点验证解，"
                  f"其中{p['blockedReferenceButVerified']}球的生成参考直线通道原本受阻。该小样本不是全库成功率估计。")
    head = ["角度", "袋口", "母球距离CO", "目标球距瞄点OP", "库距", "网格候选", "贴库补充", "总候选", "直线通道通过"]
    table_rows = []
    md = ["# "+title, "", intro, "", notes, "", "| "+" | ".join(head)+" |", "|"+"---|"*len(head)]
    for index, entry in enumerate(data["cells"]):
        c = entry["cell"]
        values = [ANGLES[c["angleIndex"]], POCKETS[c["pocketType"]], DISTANCES[c["cueIndex"]],
                  DISTANCES[c["objectIndex"]], RAILS[c["railIndex"]], entry["gridPlacement"],
                  entry["boundaryPlacement"], entry["gridPlacement"]+entry["boundaryPlacement"],
                  entry["gridClean"]+entry["boundaryClean"]]
        md.append("| "+" | ".join(map(str, values))+" |")
        attrs = " ".join(f'data-{k}="{c[k]}"' for k in ("angleIndex", "pocketType", "cueIndex", "objectIndex", "railIndex"))
        table_rows.append(f'<tr {attrs} data-count="{values[7]}" onclick="show({index})">'+
                          "".join(f"<td>{html.escape(str(v))}</td>" for v in values)+"</tr>")
    (DIRECTORY/"组合分布.md").write_text("\n".join(md)+"\n")
    filters = []
    for key, label, names in [("angleIndex", "角度", ANGLES), ("pocketType", "袋口", POCKETS),
                              ("cueIndex", "母球距离", DISTANCES), ("objectIndex", "目标球距袋", DISTANCES),
                              ("railIndex", "库距", RAILS)]:
        options = '<option value="">全部</option>'+"".join(f'<option value="{i}">{n}</option>' for i, n in enumerate(names))
        filters.append(f'<label>{label}<select data-key="{key}" onchange="filterRows()">{options}</select></label>')
    payload = json.dumps({"geometry": data["geometry"], "cells": data["cells"]}, ensure_ascii=False)
    document = """<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>TITLE</title><style>
body{font:15px -apple-system,BlinkMacSystemFont,sans-serif;background:#f3f5f7;color:#182b32;margin:24px auto;max-width:1400px;padding:0 20px}
h1{font-size:28px}p{line-height:1.75}.note{color:#53646c;font-size:13px}
.filters{display:flex;gap:15px;flex-wrap:wrap;margin:24px 0}select{display:block;padding:8px;border:1px solid #ccd5d9;border-radius:7px;background:white}
.layout{display:grid;grid-template-columns:minmax(600px,2fr) minmax(350px,1fr);gap:20px;align-items:start}
.table{overflow:auto;max-height:75vh;background:white;border-radius:10px}table{border-collapse:collapse;width:100%;font-size:13px}
th{position:sticky;top:0;background:#e3edef}td,th{padding:10px;border-bottom:1px solid #e3edef;text-align:right}td:first-child,th:first-child{text-align:left}
tbody tr{cursor:pointer}tbody tr:hover{background:#e6f3ef}.preview{background:white;border-radius:10px;padding:16px;position:sticky;top:20px}
svg{width:100%;background:#eff8f5}#caption{font-size:13px;line-height:1.7}@media(max-width:950px){.layout{display:block}.preview{position:static;margin-top:20px}}
</style><h1>TITLE</h1><p>INTRO</p><p class="note">NOTES</p><div class="filters">FILTERS<label>数量<select id="count" onchange="filterRows()"><option value="">全部</option><option value="empty">空组合</option><option value="few">1–499</option><option value="enough">≥500</option></select></label></div>
<p id="visible"></p><div class="layout"><div class="table"><table><thead><tr>HEAD</tr></thead><tbody>ROWS</tbody></table></div>
<div class="preview"><strong>点击组合查看几何样例</strong><p class="note">蓝：母球C；红：目标球O；虚线圈：假想球G；橙色十字：生成基准P。仅几何示意，未验证物理进球。</p><svg id="board" viewBox="0 0 600 330"></svg><p id="caption"></p></div></div>
<script>const data=PAYLOAD;
function filterRows(){const selections=[...document.querySelectorAll('select[data-key]')];const count=document.getElementById('count').value;let visible=0,total=0;
document.querySelectorAll('tbody tr').forEach(row=>{const n=+row.getAttribute('data-count');let yes=selections.every(s=>s.value===''||row.getAttribute('data-'+s.dataset.key)===s.value);
yes=yes&&(!count||(count==='empty'?n===0:count==='few'?n>0&&n<500:n>=500));row.hidden=!yes;if(yes){visible++;total+=n}});
document.getElementById('visible').textContent=`当前显示 ${visible} 个组合，共 ${total.toLocaleString()} 个候选`;}
const xy=p=>[300+p.x*205,165+p.z*205];const f=p=>xy(p).join(',');
function show(index){const cell=data.cells[index],s=cell.samples[0],g=data.geometry;let elements=[];
for(const l of g.lines)elements.push(`<line x1="${xy(l.start)[0]}" y1="${xy(l.start)[1]}" x2="${xy(l.end)[0]}" y2="${xy(l.end)[1]}" stroke="#173d32" stroke-width="2"/>`);
for(const a of g.arcs){let span=(a.end-a.start+Math.PI*4)%(Math.PI*2);let p={x:a.center.x+a.radius*Math.cos(a.start),z:a.center.z+a.radius*Math.sin(a.start)},q={x:a.center.x+a.radius*Math.cos(a.end),z:a.center.z+a.radius*Math.sin(a.end)};
elements.push(`<path d="M ${f(p)} A ${a.radius*205} ${a.radius*205} 0 ${span>Math.PI?1:0} 1 ${f(q)}" fill="none" stroke="#173d32" stroke-width="2"/>`)}
for(const p of g.pockets){elements.push(`<circle cx="${xy(p.center)[0]}" cy="${xy(p.center)[1]}" r="${p.radius*205}" fill="#263c39"/>`);elements.push(`<polygon points="${p.lip.map(f).join(' ')}" fill="#263c39"/>`)}
if(s){elements.push(`<polyline points="${f(s.cue)} ${f(s.ghost)} ${f(s.aim)}" fill="none" stroke="${s.clean?'#3a8d73':'#c49032'}" stroke-dasharray="3 3"/>`);
let [px,pz]=xy(s.aim);elements.push(`<path d="M ${px-5} ${pz} h 10 M ${px} ${pz-5} v 10" stroke="#ed8a20" stroke-width="2"/><text x="${px+7}" y="${pz-6}" fill="#a75b08" font-size="12">P</text>`);
for(const [key,color] of [['cue','#5a9dcc'],['target','#d76252'],['ghost','none']])elements.push(`<circle cx="${xy(s[key])[0]}" cy="${xy(s[key])[1]}" r="${g.radius*205}" fill="${color}" stroke="${key==='ghost'?'#5a9dcc':'#fff'}" ${key==='ghost'?'stroke-dasharray="2 2"':''}/>`);
document.getElementById('caption').textContent=`${s.source==='grid'?'普通网格':'贴库边界补充'}；切角 ${s.angle}°；母球距离 ${s.cueDistance.toFixed(3)}m；目标球距瞄点 ${s.objectDistance.toFixed(3)}m；库边净距 ${(s.gap*100).toFixed(2)}cm。${s.clean?'参考直线通道通过':'参考直线通道受阻，是否能进留待求解'}。`}
else document.getElementById('caption').textContent='本次网格没有候选，不代表该组合物理无解。';
document.getElementById('board').innerHTML=elements.join('');}
filterRows();show(data.cells.findIndex(c=>c.samples.length));</script></html>"""
    for key, value in {"TITLE": title, "INTRO": intro, "NOTES": notes, "FILTERS": "".join(filters),
                       "HEAD": "".join(f"<th>{v}</th>" for v in head), "ROWS": "".join(table_rows), "PAYLOAD": payload}.items():
        document = document.replace(key, value)
    (DIRECTORY/"组合分布.html").write_text(document)


def preview(data):
    """Plot verified pilot inputs from native data, not a browser screenshot."""
    pilot_path = DIRECTORY/"validation-pilot.json"
    if not pilot_path.exists():
        return
    passed = [r for r in json.loads(pilot_path.read_text())["results"] if r.get("proof")]
    font_path = "/System/Library/Fonts/STHeiti Medium.ttc"
    title = ImageFont.truetype(font_path, 30)
    font = ImageFont.truetype(font_path, 18)
    small = ImageFont.truetype(font_path, 15)
    image = Image.new("RGB", (1480, 820), "#f1f5f4")
    draw = ImageDraw.Draw(image)
    draw.text((30, 22), "网格库存：已找到稳定进球解的6个试跑球形", fill="#173a31", font=title)
    draw.text((30, 66), "蓝球C / 红球O / 空心圈G；灰线是生成参考线，蓝短线是实际验证的出杆方向。", fill="#53655e", font=font)
    geometry = data["geometry"]
    for i, result in enumerate(passed[:6]):
        x, y = 20+(i % 3)*490, 110+(i//3)*350
        draw.rounded_rectangle((x, y, x+470, y+330), 12, fill="white")
        board = result["board"]
        cue, target, aim = (point(board[k]) for k in ("cue", "target", "effectiveAim"))
        ghost = target+2*geometry["radius"]*(target-aim)/np.linalg.norm(target-aim)
        def xy(p):
            return (x+235+p[0]*160, y+155+p[1]*160)
        for line in geometry["lines"]:
            draw.line([xy(point(line["start"])), xy(point(line["end"]))], fill="#245143", width=2)
        for arc in geometry["arcs"]:
            span = (arc["end"]-arc["start"]) % (2*np.pi)
            angles = np.linspace(arc["start"], arc["start"]+span, 40)
            points = [xy(point(arc["center"])+arc["radius"]*np.array([np.cos(a), np.sin(a)])) for a in angles]
            draw.line(points, fill="#245143", width=2)
        for pocket in geometry["pockets"]:
            cx, cy = xy(point(pocket["center"]))
            rr = pocket["radius"]*160
            draw.ellipse((cx-rr, cy-rr, cx+rr, cy+rr), fill="#233e35")
            draw.polygon([xy(point(p)) for p in pocket["lip"]], fill="#233e35")
        draw.line([xy(cue), xy(ghost), xy(aim)], fill="#a1aaa5", width=1)
        direction = point(result["proof"]["direction"])
        draw.line([xy(cue), xy(cue+.25*direction)], fill="#307ab7", width=2)
        for p, color in [(ghost, None), (target, "#d15e4c"), (cue, "#5799cb")]:
            cx, cy = xy(p); rr = geometry["radius"]*160
            draw.ellipse((cx-rr, cy-rr, cx+rr, cy+rr), fill=color, outline="#405d57", width=1)
        tip = result["proof"]["tip"]
        draw.text((x+15, y+12), f"{i+1:02d}  切角 {board['angle']:.0f}°  /  {result['cellID']}", fill="#173a31", font=small)
        gap = rail_gap(target, geometry)*100
        tip_label = {"center": "中杆", "right": "右塞", "lowRight": "低杆右塞"}.get(tip, tip)
        draw.text((x+15, y+280), f"目标球库距 {max(0, gap):.2f}cm；验证打点 {tip_label}", fill="#284d40", font=small)
        draw.text((x+15, y+305), "参考直线通道：" + ("通过" if result["referenceRouteClean"] else "受阻，但实际求解进球通过"),
                  fill="#53655e", font=small)
    image.save(DIRECTORY/"求解试跑样例.png")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", type=Path, default=DIRECTORY)
    args = parser.parse_args()
    DIRECTORY = args.directory.resolve()
    data = json.loads((DIRECTORY/"inventory.json").read_text())
    summary = audit(data)
    render(data, summary)
    preview(data)
    print(json.dumps(summary, ensure_ascii=False, indent=2))
