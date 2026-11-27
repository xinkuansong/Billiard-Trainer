from pathlib import Path
import json,gzip,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/bank-full-20261101'
m=json.loads((OUT/'manifest.json').read_text());wanted=set(m['retainedIDs']);seen=set();p=OUT/'formations.jsonl.gz'
with gzip.open(p,'wt',encoding='utf8',compresslevel=6) as dest:
 for q in sorted((OUT/'routes').glob('*.json.gz')):
  with gzip.open(q,'rt') as source:packet=json.load(source)
  for row in packet['rows']:
   if row['id'] in wanted:
    assert row['id'] not in seen;seen.add(row['id']);dest.write(json.dumps(row,separators=(',',':'),ensure_ascii=False)+'\n')
assert seen==wanted
with gzip.open(p,'rt') as f:assert {json.loads(line)['id'] for line in f}==wanted
(OUT/'export.json').write_text(json.dumps({'file':p.name,'count':len(seen),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'includes':'ball positions, route provenance, strike parameters, events, trajectories, scores and direct reference'},indent=2))
print('Exported',len(seen),'rows',round(p.stat().st_size/1024**2,1),'MiB')
