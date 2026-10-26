from pathlib import Path
import json,hashlib,urllib.request
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-power-sweep-20261026';D=OUT/'sweep'
plan=json.loads((D/'protocol.json').read_text());r=json.loads((OUT/'rows.json').read_text());a=json.loads((OUT/'atlas.json').read_text());s=json.loads((OUT/'summary.json').read_text())
assert len(r)==6000 and len({(x['id'],x['power']) for x in r})==6000
assert len({x['seed'] for x in r})==1000
assert len(a['cases'])==100
by={(x['id'],x['power']):x for x in r}
for c in a['cases']:
 assert len(c['powers'])==6
 for p,d in c['powers'].items():
  rr=by[c['rackID'],float(p)];assert d['score']==rr['score'] and d['potted']==rr['potted'] and int(d['scratch'])==rr['scratch']
  assert len(d['balls'])==16-d['potted']-int(d['scratch'])
for p,x in s['powers'].items():assert x['n']==1000
binding=json.loads((D/'source-binding.json').read_text());assert all(hashlib.sha256((ROOT/x['path']).read_bytes()).hexdigest()==x['sha256'] for x in binding['production'])
assert json.loads((D/'generation.json').read_text())==dict(count=6000,productionDrift=[])
closure=json.loads((D/'closure.json').read_text());assert closure['success'] and closure['shutdownExitCode']==0 and all(x['exitCode']==0 and x['count']==1500 for x in closure['workers'])
for k in range(4):assert all(x['passed'] for x in json.loads((D/f'worker-{k}/replays.json').read_text()))
files=['index.html','atlas.json','summary.json','power-comparison.png','REPORT.md']
for f in files:
 with urllib.request.urlopen('http://127.0.0.1:63611/'+f) as resp:assert resp.status==200 and resp.read()==(OUT/f).read_bytes()
result=dict(rows=6000,racks=1000,powers=6,allSettled=True,pairedRackCueAimExact=True,initialCueSpeedFormula=True,scoreScalarAndNumpy=True,galleryOriginal100Exact=True,galleryCards=600,HTTP=len(files),sourceBindings=len(binding['production']),workerReplays=12,browser=['first','next','typed last100','last boundary','back to1','visual table and ball diagrams'],simulatorShutdown=True,localTestRun='395153b955fc4153a79161d19c4dae99',server='http://127.0.0.1:63611/')
(OUT/'verification.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
