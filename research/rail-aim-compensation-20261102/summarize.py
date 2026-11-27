from pathlib import Path
import json,collections,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rail-aim-compensation-20261102'
base=[json.loads(l) for l in (OUT/'results.jsonl').read_text().splitlines()]
follow=[json.loads(l) for l in (OUT/'followup.jsonl').read_text().splitlines()]
key=lambda x:(x['index'],x['speed'],x['spinX'],x['spinY'])
assert len(base)==len(follow)==750
assert [key(x) for x in base]==[key(x) for x in follow]
assert len({x['board'] for x in base})==50
assert json.loads((OUT/'execution.json').read_text())['exit']==0
assert json.loads((OUT/'followup-execution.json').read_text())['exit']==0
def strict(p):
    if p['outcome']!='success':return False
    capture=next(e['t'] for e in p['events'] if e['kind'].startswith('pocket(ball: "object"'))
    return sum(e['t']<=capture and e['kind'].startswith('ballBall') for e in p['events'])==1
def clean(p):
    if not strict(p):return False
    capture=next(e['t'] for e in p['events'] if e['kind'].startswith('pocket(ball: "object"'))
    return not any(e['t']<=capture and e['kind']=='ballCushion(ball: "object")' for e in p['events'])
groups=[]
for rail,label in enumerate(['非近库','半贴库','贴库']):
    pairs=[(b,f) for b,f in zip(base,follow) if b['combination'].endswith(f'r{rail}')]
    groups.append(dict(rail=label,boards=len({b['board'] for b,f in pairs}),cases=len(pairs),
        baselineStrict=sum(strict(b['baseline']) for b,f in pairs),
        positionStrict=sum(strict(f['position']) for b,f in pairs),
        atanGridStrict=sum(strict(f['atanGrid']) for b,f in pairs),
        coarseRescues=sum('rescue'in b and strict(b['rescue']['prediction']) for b,f in pairs),
        coarseCleanRescues=sum('rescue'in b and clean(b['rescue']['prediction']) for b,f in pairs),
        fineRescues=sum('fineRescue'in f and strict(f['fineRescue']['prediction']) for b,f in pairs)))
summary=dict(groups=groups,baselineCount=len(base),followupCount=len(follow),
    coarseScans=sum(len(b.get('scan',[]))for b in base),fineScans=sum(len(f.get('fineScan',[]))for f in follow),
    excludedCoarseSecondary=[dict(board=b['board'],speed=b['speed'],spinX=b['spinX']) for b in base if 'rescue'in b and not strict(b['rescue']['prediction'])],
    excludedFineSecondary=[dict(board=f['board'],speed=f['speed'],spinX=f['spinX']) for f in follow if 'fineRescue'in f and not strict(f['fineRescue']['prediction'])],
    currentSourceDrift=[p for p,h in json.loads((OUT/'source-manifest.json').read_text()).items() if hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=h])
assert all('settled' in b['baseline']['termination'] for b in base)
assert all('settled' in f[k]['termination'] for f in follow for k in ['position','atanGrid'])
(OUT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
print(json.dumps(summary,ensure_ascii=False,indent=2))
