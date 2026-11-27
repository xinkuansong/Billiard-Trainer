from pathlib import Path
import hashlib,json,math,os
ROOT=Path(__file__).resolve().parents[2];OLD=ROOT/'output/defense-full-filter-20261104';OUT=ROOT/'output/defense-approved-filter-20261104'
OUT.mkdir(exist_ok=True);(OUT/'inputs').mkdir(exist_ok=True)
read=lambda p:json.loads(p.read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
m=read(OLD/'input-manifest.json')
for p,h in m['sourceFiles'].items():assert sha(ROOT/p)==h,p
for c in m['chunks']:
 src=OLD/c['file'];dst=OUT/c['file'];assert sha(src)==c['sha256']
 if not dst.exists():os.link(src,dst)
 assert sha(dst)==c['sha256']
(OUT/'input-manifest.json').write_bytes((OLD/'input-manifest.json').read_bytes())
policy=dict(policy='user-reviewed-T02-upper-bounds-v1',cueWidthLimitDegrees=.008,maxRepresentativeComfortLimit=10,comfortUpperInclusive=False,numericalPositiveFloorDegrees=1e-6,userEvidence='User accepted T02 and rejected T03, then accepted all 24 expanded T02 examples.',scope='All bundled banks; every own-target assignment; includes harder T01. Opening geometry only, not validated safety strokes.',roleExpansion={'one':1,'two':4,'three':6},dedup='Exact coordinates and role-preserving X/Z mirrors; all passing aliases retained; no coordinate quantization',unresolvedPolicy='Zero windows, subresolution, invalid placements, convergence failures and incomplete endpoints are separate from accepted layouts.')
(OUT/'protocol.json').write_text(json.dumps(policy,ensure_ascii=False,indent=2))
rows=read(ROOT/'output/defense-reuse-20261104/evaluated.json')+read(ROOT/'output/defense-t02-expand-20261104/samples.json')
controls=[]
for q in rows:
 a=q['ownAttack'];w=a['best']['cueWidth'];c=max(o.get('comfort',{}).get('total',0) for o in a['options'])
 complete=all(all(math.dist(q['positions'][q['own']],o[k])>1e-8 for k in ['leftEnd','aim','rightEnd']) for o in a['options'] if o['cueWidth']>0)
 controls.append(dict(id=q['id'],cue=q['cue'],positions=q['positions'],own=q['own'],width=w,comfort=c,accepted=1e-6<w<=.008 and c<10,completeEndpoints=complete))
(OUT/'controls.json').write_text(json.dumps(controls,separators=(',',':')))
paths=[Path(__file__).parent/n for n in ['main.swift','PipeWindow.swift','prepare.py','run.py']]+[OUT/n for n in ['protocol.json','input-manifest.json','controls.json']]
(OUT/'algorithm.json').write_text(json.dumps({str(p.relative_to(ROOT)):sha(p) for p in paths},indent=2))
print('boards',m['boards'],'target evaluations',m['targetEvaluations'],'controls',len(controls))
