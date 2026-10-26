import json,gzip,math,collections,statistics,hashlib
from pathlib import Path
O=Path('output/rack-solver-mirror-exact-20261026');A=Path('output/rack-solver-invariance-20261026')
base={(r['input']['rackID'],r['input']['condition']):r for r in (json.loads(l) for l in gzip.open(A/'raw.jsonl.gz','rt'))}
norm=lambda a:math.sqrt(sum(x*x for x in a))
dist=lambda a,b:norm([x-y for x,y in zip(a,b)])
records=[]
for l in gzip.open(O/'raw.jsonl.gz','rt'):
 r=json.loads(l);condition='reverse' if r['input']['reverse'] else 'original';b=base[r['input']['rackID'],condition]
 expected=b['initialCueVelocity'][:];expected[2]*=-1;assert r['initialCueVelocity']==expected
 br={x['number']:x for x in b['rack']}
 for x in r['rack']:assert x['x']==br[x['number']]['x'] and x['z']==-br[x['number']]['z']
 assert r['names']==b['names'] and r['power']==b['power']==10
 ss=dict(zip(r['names'],r['samples'][1]['states']));bs=dict(zip(b['names'],b['samples'][1]['states']));mp=mv=mw=0
 for name,a in bs.items():
  p=a['p'][:];v=a['v'][:];w=a['w'][:];p[2]*=-1;v[2]*=-1;w[0]*=-1;w[1]*=-1
  mp=max(mp,dist(p,ss[name]['p']));mv=max(mv,dist(v,ss[name]['v']));mw=max(mw,dist(w,ss[name]['w']))
 delta=0
 for name in b['board'].keys()&r['board'].keys():
  a=b['board'][name][:];a[1]=.5-a[1];delta=max(delta,dist(a,r['board'][name])*2.5399999618530273)
 traces=[x for x in r['pairTrace'] if x['phase']=='beforeKiss'];bt=[x for x in b['pairTrace'] if x['phase']=='beforeKiss']
 firstPairDiff=next((i for i,(x,y) in enumerate(zip(traces,bt)) if [x[k]['name'] for k in ['a','b']]!=[y[k]['name'] for k in ['a','b']]),None)
 records.append(dict(rackID=r['input']['rackID'],condition=condition,settled=r['status']=='settled',maxPosition5ms=mp,maxVelocity5ms=mv,maxOmega5ms=mw,earlyPass=mp<=1e-6 and mv<=1e-4 and mw<=.01,boardPass=b['board'].keys()==r['board'].keys() and delta<=.001,pocketedMatch=b['pocketed']==r['pocketed'],firstPairDiff=firstPairDiff,tail=max(x['tail'] for x in r['spinTail'])))
summary={}
for condition in ['original','reverse']:
 a=[x for x in records if x['condition']==condition];assert len(a)==100
 summary[condition]=dict(n=len(a),settled=sum(x['settled'] for x in a),earlyPass=sum(x['earlyPass'] for x in a),boardPass=sum(x['boardPass'] for x in a),pocketedMatch=sum(x['pocketedMatch'] for x in a),meanMaxVelocity5ms=statistics.mean(x['maxVelocity5ms'] for x in a),maxVelocity5ms=max(x['maxVelocity5ms'] for x in a),maxPosition5ms=max(x['maxPosition5ms'] for x in a),meanTail=statistics.mean(x['tail'] for x in a))
(O/'comparisons.json').write_text(json.dumps(records,indent=2));(O/'summary.json').write_text(json.dumps(summary,indent=2))
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
closure=json.load(open(O/'closure.json'));assert closure==dict(success=True,total=200,overrideControls=6,shutdownExitCode=0)
binding=json.load(open(O/'source-binding.json'));assert all(sha(x['path'])==x['sha256'] for x in binding['production'])
S=Path('research/rack-solver-mirror-exact-20261026')
assert (S/'EventDrivenEngine.swift').read_text().replace(' static var cueVelocityOverride:SCNVector3?=nil\n','')==Path('research/rack-solver-invariance-20261026/EventDrivenEngine.swift').read_text()
assert (S/'BreakSimulator.swift').read_text().replace('InvarianceTrace.cueVelocityOverride ?? strike.velocity','strike.velocity')==Path('QiuJi/Core/Rack/BreakSimulator.swift').read_text()
verification=dict(success=True,strictInitialMirrorVerified=200,overrideControlsExact=6,productionHashesUnchanged=True,researchDiffVerified=True,files={str(p):sha(p) for p in [*S.glob('*.py'),*S.glob('*.swift'),O/'raw.jsonl.gz',O/'summary.json']})
(O/'verification.json').write_text(json.dumps(verification,indent=2));print(json.dumps(summary,indent=2))
