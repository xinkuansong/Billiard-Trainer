"""Independent scalar final-score, input, selection and resource audit."""
from pathlib import Path
import json,gzip,math,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-global-pattern-20261026'
CAL=json.loads((ROOT/'output/rack-center-mechanism-20261026/calibration.json').read_text())
META=json.loads((OUT/'discovery/metadata.json').read_text());L,W,R=[META[k] for k in ['length','width','radius']]
results={};seeds=set()
for stage in ['discovery','validation']:
 folder=OUT/stage;plan=json.loads((folder/'protocol.json').read_text());summary=json.loads((folder/'summary.json').read_text());rows=json.loads((folder/'rows.json').read_text());bykey={(r['id'],r['variant']):r for r in rows};count=0;group={v:[] for v in plan['variants']};maxerr=0;gapmin=1
 newseeds={r['seed'] for r in plan['racks']};assert not seeds&newseeds;seeds|=newseeds
 for p in sorted(folder.glob('raw-*.jsonl.gz')):
  with gzip.open(p,'rt') as f:
   for line in f:
    raw=json.loads(line);i,v=raw['input']['rackID'],raw['input']['variant'];r=bykey.pop((i,v));assert raw['status']=='settled'
    pts=[(p[0]*L-L/2,p[1]*L-W/2) for name,p in raw['board'].items() if name!='cueBall'];n=len(pts)
    nearest=[min(math.hypot(x-xx,z-zz) for j,(xx,zz) in enumerate(pts) if j!=a) for a,(x,z) in enumerate(pts)]
    score=sum(nearest)/n/CAL['reference'][str(n)]['expectedMeanM'];maxerr=max(maxerr,abs(score-r['score']));group[v].append(score)
    balls=raw['rack']
    gapmin=min(gapmin,min(math.hypot(balls[a]['x']-balls[b]['x'],balls[a]['z']-balls[b]['z'])-2*R for a in range(15) for b in range(a+1,15)))
    assert raw['cue']==[L/4,0] and raw['power']==9.75 and raw['spin']==[0,0]
    assert raw['input']['seed']==r['seed'];count+=1
 assert not bykey and count==len(plan['racks'])*len(plan['variants']) and maxerr<1e-12 and gapmin>0
 for v,ss in group.items():assert abs(sum(ss)/len(ss)-summary['variants'][v]['mean'])<1e-12
 closure=json.loads((folder/'closure.json').read_text());assert closure['success'] and closure['shutdownExitCode']==0 and len(closure['workers'])==4
 assert all(w['exitCode']==0 for w in closure['workers']) and sum(w['count'] for w in closure['workers'])==count
 start=json.loads((folder/'run-start.json').read_text());assert hashlib.sha256((folder/'protocol.json').read_bytes()).hexdigest()==start['protocolSHA']
 run=json.loads((Path(start['work']).parent/'run.json').read_text());assert run['state']=='reclaimed' and run['exit_code']==0
 binding=json.loads((folder/'source-binding.json').read_text());assert all(hashlib.sha256((ROOT/x['path']).read_bytes()).hexdigest()==x['sha256'] for x in binding['production'])
 results[stage]=dict(count=count,seeds=len(newseeds),maxScoreError=maxerr,minInitialGapMM=gapmin*1000,productionBindings=len(binding['production']),runID=Path(start['work']).parent.name,lifecycle=run)
d=json.loads((OUT/'discovery/summary.json').read_text());v=json.loads((OUT/'validation/protocol.json').read_text())
rank=sorted((k for k in d['variants'] if k.startswith('g')),key=lambda k:(-d['variants'][k]['mean'],int(k[1:])))
assert rank[:2]==v['variants'][2:]==d['selected']
for path,sha in json.loads((OUT/'protocol-binding.json').read_text()).items():assert hashlib.sha256(Path(path).read_bytes()).hexdigest()==sha
results['total']=sum(results[s]['count'] for s in ['discovery','validation']);results['selectionMatchesFrozenRule']=True;results['disjointSeeds']=len(seeds)
(OUT/'verification.json').write_text(json.dumps(results,indent=2));print(json.dumps({s:{k:x for k,x in a.items() if k!='lifecycle'} if isinstance(a,dict) else a for s,a in results.items()},indent=2))
