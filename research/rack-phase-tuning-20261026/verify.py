from pathlib import Path
import json,gzip,hashlib,math
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-phase-tuning-20261026';HERE=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
CAL=json.loads((ROOT/'output/rack-center-mechanism-20261026/calibration.json').read_text());meta=json.loads((OUT/'discovery/metadata.json').read_text());L,W,R=[meta[k] for k in ['length','width','radius']]
summary={};allseeds=set();excs=json.loads((OUT/'source-exceptions.json').read_text())
for stage in ['discovery','validation']:
 f=OUT/stage;plan=json.loads((f/'protocol.json').read_text());res=json.loads((f/'summary.json').read_text());rows={(r['id'],r['variant']):r for r in json.loads((f/'rows.json').read_text())};n=0;err=0;gap=1;group={v:[] for v in plan['variants']}
 seeds={r['seed'] for r in plan['racks']};assert not seeds&allseeds;allseeds|=seeds
 for p in sorted(f.glob('raw-*.jsonl.gz')):
  with gzip.open(p,'rt') as handle:
   for line in handle:
    raw=json.loads(line);i,v=raw['input']['rackID'],raw['input']['variant'];r=rows.pop((i,v));assert raw['status']=='settled'
    pts=[(p[0]*L-L/2,p[1]*L-W/2) for k,p in raw['board'].items() if k!='cueBall'];m=len(pts)
    score=sum(min(math.dist(x,y) for b,y in enumerate(pts) if a!=b) for a,x in enumerate(pts))/m/CAL['reference'][str(m)]['expectedMeanM'];err=max(err,abs(score-r['score']));group[v].append(score)
    assert raw['cue']==[L/4,0] and raw['power']==9.75 and raw['spin']==[0,0] and raw['simulatedElevation']==0 and r['seed']==raw['input']['seed']
    balls=raw['rack'];gap=min(gap,min(math.hypot(balls[a]['x']-balls[b]['x'],balls[a]['z']-balls[b]['z'])-2*R for a in range(15) for b in range(a+1,15)));n+=1
 assert not rows and n==len(plan['racks'])*len(plan['variants']) and err<1e-12 and gap>0
 for v,ss in group.items():assert abs(sum(ss)/len(ss)-res['variants'][v]['mean'])<1e-12
 cl=json.loads((f/'closure.json').read_text());assert cl['shutdownExitCode']==0 and len(cl['workers'])==4 and all(x['exitCode']==0 for x in cl['workers']) and sum(x['count'] for x in cl['workers'])==n
 for k in range(4):assert all(x['passed'] for x in json.loads((f/f'worker-{k}/replays.json').read_text()))
 start=json.loads((f/'run-start.json').read_text());assert start['protocolSHA']==sha(f/'protocol.json')
 run=json.loads((Path(start['work']).parent/'run.json').read_text());assert run['state']=='reclaimed'
 if stage=='discovery':assert run['exit_code']==1 and not cl['success'] and json.loads((f/'post-run-review.json').read_text())['simulationValid']
 else:assert run['exit_code']==0 and cl['success']
 b=json.loads((f/'source-binding.json').read_text());assert sha(HERE/'main.swift')==b['entrySHA256']
 for x in b['production']:
  cur=sha(ROOT/x['path'])
  if cur!=x['sha256']:
   e=next(e for e in excs if e['path']==x['path']);assert stage=='discovery' and cur==e['currentSHA256'] and x['sha256']==e['frozenSHA256']
 summary[stage]=dict(count=n,maxScalarScoreError=err,minGapMM=gap*1000,runID=Path(start['work']).parent.name,originalExitCode=run['exit_code'],lifecycle=run['state'],sourceBindings=len(b['production']))
 if stage=='discovery':firstb=b
 else:assert b['objects']==firstb['objects'] and b['frozenSources']==firstb['frozenSources'],'Frozen engine changed across stages'
d=json.loads((OUT/'discovery/summary.json').read_text());v=json.loads((OUT/'validation/protocol.json').read_text());rank=sorted((k for k in d['variants'] if k not in ['baseline','radial_contract']),key=lambda k:(-d['variants'][k]['mean'],k));assert rank[:2]==d['selected']==v['variants'][2:]
bind=json.loads((OUT/'plan-binding.json').read_text());assert sha(OUT/'discovery/protocol.json')==bind['discoveryProtocolSHA256'] and sha(OUT/'validation-plan.json')==bind['validationPlanSHA256'] and sha(HERE/'main.swift')==bind['entrySHA256']
seed=json.loads((OUT/'seed-audit.json').read_text());assert seed['overlap']==[] and seed['historicalUnique']==7700 and seed['newUnique']==len(allseeds)==1800
summary.update(total=8700,allSettled=True,selectionMatchesFrozenRule=True,newSeeds=len(allseeds),calibrationSHA256=sha(ROOT/'output/rack-center-mechanism-20261026/calibration.json'))
(OUT/'verification.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary,indent=2))
