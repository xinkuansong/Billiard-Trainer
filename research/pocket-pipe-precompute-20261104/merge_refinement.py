from pathlib import Path
import json,gzip,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/pocket-pipe-precompute-20261104'
rows=json.loads((OUT/'refinement/refined.json').read_text())
assert json.loads((OUT/'geometry-manifest.json').read_text())==json.loads((OUT/'refinement/geometry-manifest.json').read_text())
rawPath=OUT/'grid-raw.json';raw=json.loads(rawPath.read_text());summary=json.loads((OUT/'summary.json').read_text())
assert len(rows)==summary['unresolved']==4
with (OUT/'grid-raw-r1.json.gz').open('wb') as f:
 with gzip.GzipFile(fileobj=f,mode='wb',mtime=0) as g:g.write(rawPath.read_bytes())
(OUT/'summary-r1.json').write_bytes((OUT/'summary.json').read_bytes())
for row in rows:
 assert row['type']=='grid'
 checks=row['refinedChecks'];assert all(c['closed'] for c in checks)
 a,b=[c['intervals'] for c in checks];assert len(a)==len(b)
 error=max((abs(x-y) for aa,bb in zip(a,b) for x,y in zip(aa,bb)),default=0)
 assert error<=.001
 raw['cells'][row['index']][row['pocket']]={'intervals':b,'closed':True,'converged':True,'difference':error,'isolated':checks[-1]['isolated']}
rawPath.write_text(json.dumps(raw,separators=(',',':')))
checks=[o for opts in raw['cells'] for o in opts]+[o for row in json.loads((OUT/'holdouts.json').read_text()) for o in row['pockets']]
summary['unresolved']=sum(not o['converged'] for o in checks)
summary['maxBoundaryDifferenceDegrees']=max(o['difference'] for o in checks)
summary['extraFineRefinements']=len(rows);summary['calls']+=2*len(rows)
summary['followup']='refinement/refined.json; initial grid/run durations remain unchanged'
(OUT/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
