#!/usr/bin/env python3
"""Validate the supplemental run and publish 100 measured candidate cards."""
import collections
import html
import json
import math
import shutil
import time
from pathlib import Path

import cue_scratch_research as runner
from audit_cue_scratch import audit
from expand_cue_scratch_candidates import BATCH, MIN_DISTANCE, LAYOUT_SEPARATION, diverse, mirrored_distance
from report_cue_scratch import svg
from run_cue_scratch_session import family

OUT = runner.OUT
REPORT = runner.ROOT/'output/cue-scratch-research-20261004'


def main():
    evidence = json.loads((OUT/f'{BATCH}-execution.json').read_text())
    assert evidence['executed'] and evidence['exit'] == 0
    request = json.loads((OUT/f'{BATCH}-request.json').read_text())
    raw = [json.loads(line) for line in (OUT/f'{BATCH}.jsonl').open()]
    records = {x['id']: x for x in raw}
    assert len(records) == len(raw) == len(request['jobs'])
    assert set(records) == {x['id'] for x in request['jobs']}
    independent = audit([OUT/f'{BATCH}.jsonl'])
    assert independent['passed']
    runner.write(OUT/f'{BATCH}-audit.json', independent)
    selected = json.loads((OUT/f'{BATCH}-selected.json').read_text())
    valid, rejected = [], []
    keys = ['pocket', 'cuePocket', 'rails', 'contacts', 'preRails', 'cueJaws', 'objectJaws', 'objectRails']
    for i, original in enumerate(selected):
        full, fixed = records[f'd100-{i}-full'], records[f'd100-{i}-fixed']
        consistent = full.get('hit') and fixed.get('hit') and all(full.get(k) == fixed.get(k) == original.get(k) for k in keys)
        same_aim = 'aim' in full and 'aim' in fixed and math.dist(full['aim'], fixed['aim']) < 1e-6 and abs(full['offset']-fixed['offset']) < 1e-6
        consistent = consistent and same_aim
        if not consistent:
            rejected.append(dict(sourceID=original['id'], full=full['id'], fixed=fixed['id'], reason='outcome-or-aim-mismatch'))
            continue
        assert math.dist(full['cue'], full['object']) >= MIN_DISTANCE
        assert math.dist(full['aim'], fixed['aim']) < 1e-6
        assert abs(full['offset']-fixed['offset']) < 1e-6
        assert all(full['paths'].get(name) for name in ('cueBall', 'object'))
        points = sorted([x for ident, x in records.items() if ident.startswith(f'd100-{i}-speed-')], key=lambda x: x['speed'])
        assert len(points) == 16
        def same(x):
            return bool(x.get('hit') and family(x) == family(full))
        full.update(sourceID=original['id'], cueAccess='not-validated',
                    cueObjectCenterDistanceM=math.dist(full['cue'], full['object']),
                    selectionEvidence=original['selectionEvidence'],
                    fixedAimSpeedChecks=dict(tested=16, sameRoute=sum(same(x) for x in points),
                        points=[dict(speed=x['speed'], targetPot=x.get('targetPot'), hit=x.get('hit'),
                                     rails=x.get('rails'), cuePocket=x.get('cuePocket'), sameRoute=same(x)) for x in points]))
        valid.append(full)
    final = []
    for n in range(4):
        picked = diverse([x for x in valid if len(x['rails']) == n], 25, prior=final, robustness=True)
        assert len(picked) == 25, f'Insufficient verified {n}-rail candidates: {len(picked)}'
        final += sorted(picked, key=lambda x: (-x['fixedAimSpeedChecks']['sameRoute'], x['speed'], x['id']))
    assert len(final) == 100
    for i, x in enumerate(final):
        assert all(mirrored_distance(x, y) >= LAYOUT_SEPARATION for y in final[:i])
        x['galleryID'] = f'C{i+1:03}'
    archive = REPORT/'archive-r6-24'
    if not archive.exists():
        archive.mkdir()
        for pattern in ('*.svg', 'index.html', 'verified-cases.json', 'summary.json', 'REPORT.md', 'contactsheet.png'):
            for p in REPORT.glob(pattern):
                shutil.copy2(p, archive/p.name)
    selection = json.loads((OUT/f'{BATCH}-selection.json').read_text())
    summary = dict(selection, batch=BATCH, supplementalTrials=len(raw), fullSolverTrials=sum(x['mode']=='full' for x in raw),
                   completedShortlist=len(valid), rejected=rejected, displayedRepresentatives=len(final),
                   byRail=dict(collections.Counter(len(x['rails']) for x in final)),
                   centerDistanceRangeM=[min(x['cueObjectCenterDistanceM'] for x in final), max(x['cueObjectCenterDistanceM'] for x in final)],
                   mirroredLayoutMinimumM=min(mirrored_distance(a,b) for i,a in enumerate(final) for b in final[:i]),
                   fixedAimSameRouteHistogram=dict(collections.Counter(x['fixedAimSpeedChecks']['sameRoute'] for x in final)),
                   actualBatchWallSeconds=evidence['wallSeconds'], elapsedThroughGallerySeconds=time.time()-selection['startEpoch'],
                   independentAuditPassed=True, initialSearchStats='archive-r6-24/summary.json')
    runner.write(REPORT/'expansion-summary.json', summary)
    runner.write(REPORT/'verified-cases.json', final)
    runner.write(REPORT/'selection-filter.json', dict(minCenterDistanceM=MIN_DISTANCE, minCutDegrees=5, maxCutDegrees=75,
        minCueSurfaceToRectangleRailM=.05, mirroredLayoutSeparationM=LAYOUT_SEPARATION, byRail=25, count=100,
        artifactSource=BATCH, policy='Visual selection only; retained cases each independently replayed'))
    old_summary = json.loads((archive/'summary.json').read_text())
    old_summary.update(verifiedRepresentatives=100, initialVerifiedRepresentatives=24,
                       statisticsScope='Original r6 search; supplemental trials counted separately in expansion-summary.json',
                       galleryExpansion=summary)
    runner.write(REPORT/'summary.json', old_summary)
    geo = json.loads((OUT/'geometry.json').read_text())
    cards = []
    for x in final:
        case_id=x['galleryID']; n=len(x['rails']); checks=x['fixedAimSpeedChecks']; distance=x['cueObjectCenterDistanceM']*100
        filename=f'{case_id}.svg'; (REPORT/filename).write_text(svg(x,geo))
        cells=''.join(f'<span class="{"yes" if p["sameRoute"] else "no"}" title="目标进袋：{p["targetPot"]}；同袋同库序：{p["sameRoute"]}">{p["speed"]:.2f}</span>' for p in checks['points'])
        params={k:x[k] for k in ('galleryID','sourceID','id','cue','object','speed','offset','aim','cueObjectCenterDistanceM')}
        cards.append(f'''<article id="{case_id}" data-rails="{n}" data-stable="{checks['sameRoute']}" data-distance="{distance:.8f}">
<h2>{case_id} · {n}库掉袋</h2><p class="meta">球心距 <b>{distance:.1f} cm</b> · 杆速 {x['speed']:.3f} m/s · 切角 {x['cut']:.1f}°</p>
<img src="{filename}" loading="lazy" alt="{case_id}：{n}库母球掉袋的引擎采样轨迹">
<p>目标袋 {x['pocket']} → 母球袋 {x['cuePocket'].replace('pocket_','')} · 主库段 {x['rails']}</p>
<p>固定瞄准、杆速 ±1% 至 ±8%：<b>{checks['sameRoute']}/16</b> 次保持同袋同库序。</p><div class="spectrum">{cells}</div>
<details><summary>摆位与复现参数</summary><pre>{html.escape(json.dumps(params,ensure_ascii=False,indent=2))}</pre></details></article>''')
    doc='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>母球掉袋 · 100个候选</title>
<style>body{margin:0;background:#eef2ed;color:#1c3029;font-family:-apple-system,"PingFang SC",sans-serif;line-height:1.65}main{max-width:1200px;margin:auto;padding:24px}header{background:#f8d750;padding:22px;border-radius:18px}h1{font-size:32px;margin:0}h2{margin:0;font-size:23px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,420px),1fr));gap:18px}article{background:white;border-radius:16px;padding:18px}img{width:100%;aspect-ratio:800/420}.meta{margin:5px 0 14px}.filters{position:sticky;top:0;background:#eef2edf5;padding:12px 0;z-index:1}button,select,input{font:inherit;padding:8px 12px;border:1px solid #b1c6ba;border-radius:8px;margin:3px}button{background:#173c30;color:white;cursor:pointer}button.active{background:#e4bc28;color:#173c30}input{width:105px}.spectrum span{display:inline-block;padding:3px 6px;margin:2px;border-radius:4px;font-size:13px}.yes{background:#c3e6cf}.no{background:#f6dad1}pre{white-space:pre-wrap;font-size:12px}.note{color:#50655d}a{color:#176746}details{margin-top:12px}footer{margin:30px 0}#shown{margin-left:8px}</style><main>
<header><h1>母球掉袋：100 个候选球形</h1><p>中杆无塞 · 目标球进推荐袋 · 0 / 1 / 2 / 3 库各 25 个</p><b>起始球心距 ≥ 30 cm · 排除近直球 · 完整求解与固定方向重放均已通过</b></header>
<p class="note">白线：母球；黄线：目标球；橙色数字：碰库顺序；红圈：母球落袋。X 向右、Z 向下，单位米。每个候选来自引擎真实采样轨迹；相近摆位及镜像外观已去重。力度格绿色表示该测试点保持同袋同库序，红色表示未保持；离散点通过不保证连续力度区间。</p>
<div class="filters"><div><button class="active" data-rail="-1">全部 100</button>'''
    doc+=''.join(f'<button data-rail="{n}">{n}库 · 25</button>' for n in range(4))
    doc+='''</div><label>球心距 <select id="distance"><option value="30">≥ 30 cm</option><option value="50">≥ 50 cm</option><option value="70">≥ 70 cm</option><option value="100">≥ 100 cm</option></select></label> <label>力度复现 <select id="stable"><option value="0">全部</option><option value="8">≥ 8/16</option><option value="12">≥ 12/16</option><option value="16">16/16</option></select></label> <input id="search" placeholder="编号 C001" aria-label="候选编号"><span id="shown">显示 100 / 100</span></div><div class="grid">'''+''.join(cards)+'''</div>
<footer><p><a href="verified-cases.json">100例参数与轨迹</a> · <a href="expansion-summary.json">本次筛选与复验统计</a> · <a href="REPORT.md">报告</a> · <a href="archive-r6-24/index.html">原24例归档</a></p>
<p class="note">本页是视频选材图册，尚未制作成片。实体球杆出杆空间、摆位和瞄准误差及原生场景画面尚未验收。原半小时搜索统计保持独立，本次扩充复验另计。</p></footer></main>
<script>let rail=-1;const articles=[...document.querySelectorAll('article')];function apply(){let count=0;let q=document.getElementById('search').value.trim().toUpperCase();for(const e of articles){let show=(rail<0||Number(e.dataset.rails)===rail)&&Number(e.dataset.distance)>=Number(document.getElementById('distance').value)&&Number(e.dataset.stable)>=Number(document.getElementById('stable').value)&&(!q||e.id.includes(q));e.hidden=!show;if(show)count++;}document.getElementById('shown').textContent=`显示 ${count} / 100`;}document.querySelectorAll('[data-rail]').forEach(b=>b.onclick=()=>{rail=Number(b.dataset.rail);document.querySelectorAll('[data-rail]').forEach(x=>x.classList.toggle('active',x===b));apply()});['distance','stable','search'].forEach(id=>document.getElementById(id).addEventListener('input',apply));</script></html>'''
    (REPORT/'index.html').write_text(doc)
    print(json.dumps(summary,ensure_ascii=False),flush=True)


if __name__=='__main__':
    main()
