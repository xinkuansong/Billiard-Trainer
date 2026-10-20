#!/usr/bin/env python3
"""Expand the complete v3 middle inventory and audit its bounded native screening."""
import argparse
import collections
import hashlib
import html
import json
import math
from pathlib import Path
import grid_inventory_report as geometry

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'output/accuracy-middle-v3-20261021'
INVENTORY = ROOT/'output/accuracy-grid-staggered-v3-20261021/inventory.json'

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,v): p.write_text(json.dumps(v,ensure_ascii=False,separators=(',',':')))

def prepare():
    OUT.mkdir(exist_ok=True)
    assert not (OUT/'consumed-request.json').exists(), 'Do not overwrite an executed run'
    data=json.loads(INVENTORY.read_text())
    assert data['version']=='pg-gc-grid-v3-15cm-2deg-staggered'
    distances=data['distanceSamples']; assert len(distances)==11
    counts=collections.Counter(); samples=[]; batches=[]; count=0
    def flush():
        nonlocal samples
        if not samples: return
        file=f'inputs-{len(batches):03d}.json'
        dump(OUT/file,dict(sourceFingerprint=data['sourceFingerprint'],samples=samples))
        batches.append(dict(file=file,sha256=sha(OUT/file),count=len(samples),offset=count-len(samples)))
        samples=[]
    for ti,t in enumerate(data['targets']):
        if t['pocket']<4: continue
        o,g,p=(geometry.point(t[k]) for k in ('object','ghost','aim'))
        dx,dz=g-o; norm=math.hypot(dx,dz); dx/=norm; dz/=norm
        gap=geometry.rail_gap(o,data['geometry'])
        ri=2 if abs(gap)<=geometry.EPSILON else 1 if gap<=.1+geometry.EPSILON else 0
        op=math.hypot(*(p-o))
        for mi,mask in enumerate(t['masks']):
            beta=mi-85; a=math.radians(beta); c,s=math.cos(a),math.sin(a)
            ux,uz=dx*c-dz*s,dx*s+dz*c
            for bit,gc in enumerate(distances):
                if not mask&(1<<bit): continue
                cx,cz=float(g[0]+ux*gc),float(g[1]+uz*gc)
                co=math.hypot(cx-o[0],cz-o[1])
                ai=next(i for i,l in enumerate([10,30,50,70,85]) if abs(beta)<=l)
                cell=dict(angleIndex=ai,pocketType=1,cueIndex=int(geometry.band(co)),objectIndex=int(geometry.band(op)),railIndex=ri)
                cid=geometry.cell_id(cell); counts[cid]+=1
                assert abs(math.hypot(cx-g[0],cz-g[1])-gc)<1e-9
                samples.append(dict(sampleIndex=count,targetIndex=ti,maskIndex=mi,distanceBit=bit,
                    cellID=cid,cell=cell,pocket=t['pocket'],signedAngle=beta,
                    cue=dict(x=cx,z=cz),target=t['object'],ghost=t['ghost'],aim=t['aim'],source=t['source']))
                count+=1
                if len(samples)==5000: flush()
    flush()
    expected={geometry.cell_id(c['cell']):c['gridPlacement']+c['boundaryPlacement'] for c in data['cells'] if c['cell']['pocketType']==1}
    assert count==272710 and all(counts[k]==v for k,v in expected.items())
    previous=json.loads((ROOT/'output/accuracy-middle-benchmark-20261021/source-manifest.json').read_text())
    files={p:sha(ROOT/p) for p in previous['files']}
    files['scripts/training-question-bank/middle_v3.py']=sha(Path(__file__))
    fingerprint=hashlib.sha256(json.dumps(files,sort_keys=True).encode()).hexdigest()
    for p in files:
        target=OUT/'source'/p;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((ROOT/p).read_bytes())
    dump(OUT/'source-manifest.json',dict(fingerprint=fingerprint,files=files))
    dump(OUT/'request.json',dict(sourceFingerprint=fingerprint,inventorySHA256=sha(INVENTORY),workers=18,total=count,batches=batches))
    dump(OUT/'input-counts.json',expected)
    print(json.dumps(dict(total=count,batches=len(batches),occupied=sum(v>0 for v in expected.values()),atLeast500=sum(v>=500 for v in expected.values())),indent=2))

def audit():
    request=json.loads((OUT/'consumed-request.json').read_text())
    progress=json.loads((OUT/'progress.json').read_text())
    assert progress['complete'] and progress['done']==request['total']==272710
    assert sha(INVENTORY)==request['inventorySHA256']
    manifest=json.loads((OUT/'source-manifest.json').read_text())
    assert manifest['fingerprint']==request['sourceFingerprint']==progress['sourceFingerprint']
    drift=[]
    for p,h in manifest['files'].items():
        assert sha(OUT/'source'/p)==h
        if sha(ROOT/p)!=h: drift.append(p)
    counts=json.loads((OUT/'input-counts.json').read_text())
    seen=collections.Counter(); passed=collections.Counter(); calls=collections.Counter()
    incomplete=collections.Counter(); scratch=collections.Counter(); pockets=collections.Counter(); pocket_pass=collections.Counter()
    feedback=collections.Counter(); attempts=collections.Counter(); total=0; durations=[]
    for bi,b in enumerate(request['batches']):
        assert sha(OUT/b['file'])==b['sha256']
        samples=json.loads((OUT/b['file']).read_text())['samples']
        results=json.loads((OUT/f'results-{bi:03d}.json').read_text())
        assert len(samples)==len(results)==b['count'] and b['offset']==total
        for s,r in zip(samples,results):
            assert r['sampleIndex']==s['sampleIndex']==total
            assert r['cellID']==s['cellID'] and r['pocket']==s['pocket']
            cid=s['cellID']; trials=r['trials']; proof=r.get('proof')
            assert 1<=len(trials)<=5 and bool(proof)==any(t['targetPotted'] for t in trials)
            lo,hi=.5,8
            for ti,t in enumerate(trials):
                assert abs(t['speed']-(lo+hi)/2)<1e-6
                assert t['feedback'] in ('pot','incomplete-stop','mouth-miss-decrease','deflection-probe-lower','short-increase')
                if t['feedback']=='short-increase': lo=t['speed']
                elif t['feedback'] in ('mouth-miss-decrease','deflection-probe-lower'): hi=t['speed']
                else: assert ti==len(trials)-1
                feedback[t['feedback']]+=1
            if proof:
                assert proof['spinX']==proof['spinY']==0 and trials[-1]['targetPotted']
                assert proof['speed']==trials[-1]['speed']
                dx=s['ghost']['x']-s['cue']['x']; dz=s['ghost']['z']-s['cue']['z']; length=math.hypot(dx,dz)
                assert abs(proof['direction']['x']-dx/length)<1e-6 and abs(proof['direction']['z']-dz/length)<1e-6
                assert any(e['kind']=='pocket' and e.get('ball')=='object' and e.get('pocketID')==f"pocket_{s['pocket']}" for e in proof['events'])
                passed[cid]+=1; pocket_pass[s['pocket']]+=1
                scratch[cid]+=int(trials[-1]['cuePocketed'])
            incomplete[cid]+=int(trials[-1]['feedback']=='incomplete-stop')
            seen[cid]+=1; calls[cid]+=len(trials); pockets[s['pocket']]+=1
            attempts[len(trials)]+=1; durations.append(r['elapsedSeconds']); total+=1
    assert all(seen[k]==v for k,v in counts.items())
    assert sum(passed.values())==progress['passed'] and sum(calls.values())==progress['calls']
    rows=[dict(cellID=k,before=v,passed=passed[k],notPassed=v-passed[k],incomplete=incomplete[k],calls=calls[k],scratchPasses=scratch[k],rate=passed[k]/v if v else None) for k,v in counts.items()]
    summary=dict(total=total,passed=sum(passed.values()),rate=sum(passed.values())/total,workers=18,
        calls=sum(calls.values()),wallSeconds=progress['wallSeconds'],meanLayoutMs=sum(durations)/total*1000,
        incomplete=sum(incomplete.values()),scratchPasses=sum(scratch.values()),attempts=dict(attempts),feedback=dict(feedback),
        cells=135,occupiedBefore=sum(v>0 for v in counts.values()),occupiedAfter=sum(r['passed']>0 for r in rows),
        atLeast500Before=sum(v>=500 for v in counts.values()),atLeast500After=sum(r['passed']>=500 for r in rows),
        emptyBefore=sum(v==0 for v in counts.values()),emptyAfter=sum(r['passed']==0 for r in rows),
        pockets={str(k):dict(total=v,passed=pocket_pass[k]) for k,v in pockets.items()},sourceDrift=drift)
    dump(OUT/'audit.json',summary);dump(OUT/'cell-results.json',rows)
    render(summary,rows)
    print(json.dumps(summary,ensure_ascii=False,indent=2))

def label(cid):
    a,p,c,o,r=[int(s[1:]) for s in cid.split('-')]
    return [geometry.ANGLES[a],geometry.DISTANCES[c],geometry.DISTANCES[o],geometry.RAILS[r]]

def render(summary,rows):
    note='统一中杆、固定C→G、18路并行，每球形最多5次力度；目标球进入指定中袋即通过，忽略母球落袋。未通过表示预算内未找到，不代表物理无解。保留镜像；未做近似去重，不是正式App题库资格验收。'
    intro=f"验证{summary['total']:,}个，通过{summary['passed']:,}个，通过率{summary['rate']:.2%}；墙钟{summary['wallSeconds']/60:.2f}分钟。"
    headers=['角度','母球距离','目标球距袋','库距','验证前','通过','未通过','通过率']
    markdown=['# 新版中袋全量验证','',intro,'',note,'','| '+' | '.join(headers)+' |','|'+'---|'*8]
    htmlrows=[]
    for r in rows:
        cells=label(r['cellID'])+[str(r['before']),str(r['passed']),str(r['notPassed']),f"{r['rate']:.1%}" if r['rate'] is not None else '—']
        markdown.append('| '+' | '.join(cells)+' |')
        htmlrows.append('<tr data-count="'+str(r['passed'])+'">'+''.join('<td>'+html.escape(c)+'</td>' for c in cells)+'</tr>')
    (OUT/'中袋验证报告.md').write_text('\n'.join(markdown)+'\n')
    page='''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>新版中袋验证分布</title><style>body{max-width:1350px;margin:32px auto;padding:0 24px;font:17px -apple-system,sans-serif;color:#193d32;background:#f4f7f6}p{line-height:1.8}table{width:100%;border-collapse:collapse;background:white}td,th{padding:10px;text-align:left;border-bottom:1px solid #ddd}th{position:sticky;top:0;background:#e1eee8}select{padding:8px;margin:12px}</style><h1>15cm／2°交错：中袋验证分布</h1>'''
    page+=f'<p>{intro}</p><p>{note}</p><p>有题组合：{summary["occupiedBefore"]} → {summary["occupiedAfter"]}；至少500题：{summary["atLeast500Before"]} → {summary["atLeast500After"]}；空组合：{summary["emptyBefore"]} → {summary["emptyAfter"]}。共135个中袋组合，两只中袋合并计数。</p>'
    page+='<label>筛选<select onchange="filterRows(this.value)"><option value="all">全部组合</option><option value="large">至少500题</option><option value="small">1～499题</option><option value="empty">0题</option></select></label><table><thead><tr>'+''.join('<th>'+h+'</th>' for h in headers)+'</tr></thead><tbody>'+''.join(htmlrows)+'</tbody></table>'
    page+='''<script>function filterRows(v){document.querySelectorAll('tbody tr').forEach(r=>{const n=+r.dataset.count;r.hidden=!(v==='all'||v==='large'&&n>=500||v==='small'&&n>0&&n<500||v==='empty'&&n===0)})}</script></html>'''
    (OUT/'中袋验证分布.html').write_text(page)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['prepare','audit']);a=p.parse_args()
    prepare() if a.action=='prepare' else audit()
