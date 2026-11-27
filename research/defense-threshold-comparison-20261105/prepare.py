from pathlib import Path
import json,gzip,hashlib,math,shutil
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name
OLD=ROOT/'research/defense-own-potential-20261105';OUT.mkdir(parents=True,exist_ok=True)
for n in ['Scan.swift','OwnPotential.swift','DefenseRegionSolver.swift','run.py','geometric_table.py']:
    (HERE/n).write_text((OLD/n).read_text().replace('defense-own-potential-20261105',HERE.name))
base=json.loads((OLD/'scenario.json').read_text());cases=base['cases'][:5]
examples=json.loads((ROOT/'output/defense-fixed-opponent-examples-20261105/selected.json').read_text())['examples']
for label,old in [('F06','D'),('F07','A')]:
    q=next(e['question'] for e in examples if e['label']==old)
    cases.append({'label':label,'target':next(b['position'] for b in q['balls'] if b['number']==9),'question':q,'oldMap':old})
geo=json.loads((ROOT/'output/defense-own-potential-20261105/F01/geometry.json').read_text())
def gap(p):
    distances=[]
    for a,b in geo['rails']:
        v=[b[i]-a[i] for i in range(2)];u=max(0,min(1,sum((p[i]-a[i])*v[i] for i in range(2))/sum(x*x for x in v)))
        distances.append(math.dist(p,[a[i]+u*v[i] for i in range(2)])-geo['radius'])
    return min(distances)
bankpath=ROOT/'QiuJi/Resources/defense-practice-bank.json.gz';bank=json.loads(gzip.decompress(bankpath.read_bytes()))
used={c['question']['id'] for c in cases}
for label,anchor in [('F08',[.6,-.10]),('F09',[.15,-.25])]:
    eligible=[]
    for q in bank['questions']:
        if q['id'] in used or q['kind']!='two_black' or q['ownBallNumber']!=8 or q['opponentBallNumber']!=9:continue
        p={0:q['cue'],**{b['number']:b['position'] for b in q['balls']}}
        if gap(p[9])<.25 or not .35<=math.dist(p[0],p[8])<=1.8:continue
        if min(math.dist(p[a],p[b]) for a,b in [(0,8),(0,9),(8,9)])<.16:continue
        valid=False
        for ref in q['references']:
            e=ref['expected'];f={b['number']:b['position'] for b in e['finalBalls']}
            if 9 in f and math.dist(f[9],p[9])<1e-6 and not any(9 in ev['ballNumbers'] for ev in e['events']):valid=True
        if valid:eligible.append(q)
    q=min(eligible,key=lambda q:(math.dist(next(b['position'] for b in q['balls'] if b['number']==9),anchor),q['id']))
    used.add(q['id']);cases.append({'label':label,'target':next(b['position'] for b in q['balls'] if b['number']==9),'question':q})
provenance=[]
manifest=json.loads((ROOT/'output/defense-own-potential-20261105/source-manifest.json').read_text())
assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in manifest.items())
for c in cases:
    c['railSurfaceGapMeters']=gap(c['target']);c['stratum']='near' if c['railSurfaceGapMeters']<.08 else ('off' if c['railSurfaceGapMeters']<.25 else 'central')
    d=OUT/c['label'];d.mkdir(exist_ok=True)
    source=ROOT/'output/defense-own-potential-20261105'/c['label'] if c['label']<='F05' else ROOT/'output/defense-four-regions-20261105'/c.get('oldMap','MISSING')
    if source.exists():
        for n in ['scan-adaptive.json','geometry.json','windows-base.json']:
            p=source/n;shutil.copy2(p,d/n);provenance.append({'source':str(p.relative_to(ROOT)),'target':str((d/n).relative_to(ROOT)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
    print(c['label'],c['stratum'],round(c['railSurfaceGapMeters']*100,2),c['target'])
config={'thresholds':[70,80,90],'cases':cases,'bankSHA256':hashlib.sha256(bankpath.read_bytes()).hexdigest(),'gridStepMeters':.05,'refinementStepMeters':.02,'refinementScoreChange':12,'selection':'Original first five plus earlier A/D and two geometry-selected central cases; no score-based layout rejection. Deliberate diagnostic sample, not population estimate.'}
(HERE/'scenario.json').write_text(json.dumps(config,ensure_ascii=False,indent=2));(OUT/'map-provenance.json').write_text(json.dumps(provenance,indent=2))
