from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-phase-tuning-20261026'
old=set();sources=[]
def collect(x,acc):
 if isinstance(x,dict):
  if 'seed' in x:acc.add(str(x['seed']))
  for v in x.values():collect(v,acc)
 elif isinstance(x,list):
  for v in x:collect(v,acc)
for folder in ROOT.glob('output/rack-*'):
 if folder==OUT:continue
 for p in folder.rglob('*.json'):
  if p.name not in ['inputs.json','racks.json','protocol.json','validation-plan.json','confirmation-plan.json']:continue
  ss=set();collect(json.loads(p.read_text()),ss);old|=ss
  sources.append(dict(path=str(p.relative_to(ROOT)),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),uniqueSeeds=len(ss)))
new=set()
for p in [OUT/'discovery/protocol.json',OUT/'validation-plan.json']:
 ss=set();collect(json.loads(p.read_text()),ss);assert not ss&new;new|=ss
assert not old&new
result=dict(historicalUnique=len(old),newUnique=len(new),overlap=sorted(old&new),sources=sources)
(OUT/'seed-audit.json').write_text(json.dumps(result,indent=2));print({k:v for k,v in result.items() if k!='sources'})
