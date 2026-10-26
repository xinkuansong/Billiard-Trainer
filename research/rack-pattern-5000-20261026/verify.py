from pathlib import Path
import json,csv,math,statistics,hashlib,subprocess
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-pattern-5000-20261026'
a=json.loads((OUT/'analysis.json').read_text());f=json.loads((OUT/'features.json').read_text());specs=json.loads((OUT/'racks.json').read_text());lock=json.loads((OUT/'candidate-lock.json').read_text());rows=list(csv.DictReader((OUT/'shots.csv').open()))
assert len(rows)==5000 and len({(r['rackID'],r['position']) for r in rows})==5000
assert sum(int(r['success']) for r in rows)==a['baseline']['successes']
assert all(int(r['success'])==int(float(r['index'])>=1.2) for r in rows)
for c in a['candidates']:
 ids=[]
 for i,v in enumerate(f['values']):
  if all((v[x['feature']]<=x['threshold']) if x['le'] else (v[x['feature']]>x['threshold']) for x in c['conditions']):ids.append(i)
 assert ids==c['selectedRackIDs']
 for split,prefix in [('train','train'),('holdout','holdout')]:
  for selected,suffix in [(True,'Selected'),(False,'Other')]:
   rs=[r for r in rows if r['split']==split and (int(r['rackID']) in ids)==selected];expected=c[prefix+suffix]
   assert len(rs)==expected['shots'] and sum(int(r['success']) for r in rs)==expected['successes']
   assert abs(statistics.mean(float(r['index']) for r in rs)-expected['meanIndex'])<1e-12
   assert abs(statistics.median(float(r['wallMS']) for r in rs)-expected['wallMedianMS'])<1e-8
cal=json.loads((OUT/'calibration.json').read_text());meta=json.loads((OUT/'metadata.json').read_text());L,W,R=(meta[k] for k in ['length','width','radius'])
byid={(int(r['rackID']),r['position']):r for r in rows};checked=0
for p in OUT.glob('raw-*.jsonl'):
 for line in p.read_text().splitlines():
  r=json.loads(line);inp=r['input'];ps=[(v[0]*L-L/2,v[1]*L-W/2) for k,v in r['board'].items() if k!='cueBall']
  nearest=[min(math.hypot(x-u,z-v) for j,(u,v) in enumerate(ps) if i!=j) for i,(x,z) in enumerate(ps)]
  index=math.fsum(nearest)/len(ps)/cal['reference'][str(len(ps))]['expectedMeanM'];ref=byid[(inp['rackID'],inp['position'])]
  assert abs(index-float(ref['index']))<1e-12;checked+=1
assert checked==5000
closed=json.loads((OUT/'closure.json').read_text());assert closed['generationSucceeded'] and closed['shutdownExitCode']==0
for c in closed['workers']:
 assert c['exitCode']==0
 p=subprocess.run(['ps','-p',str(c['wrapperPID']),'-o','args='],capture_output=True,text=True)
 assert p.returncode!=0 or 'simctl spawn' not in p.stdout
runpath=ROOT/'output/local-test-runs/fc9613faedc545d9930df47b5bdc7eff/run.json';run=json.loads(runpath.read_text())
result=dict(passed=True,independentScoreRows=checked,independentCandidateAggregation=True,classificationExact=True,workerExitCodes=[x['exitCode'] for x in closed['workers']],shutdownExitCode=closed['shutdownExitCode'],lifecycle=run,artifacts={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.iterdir() if p.is_file() and p.name!='verification.json' and p.suffix in ['.json','.csv','.png','.md']})
(OUT/'verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print('Independent full5000 audit passed; lifecycle',run.get('state'))
