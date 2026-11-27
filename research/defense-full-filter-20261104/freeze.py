"""Prepare deterministic regression inputs and fingerprint; do not rewrite a running job."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/defense-full-filter-20261104'
policy=json.loads((OUT/'protocol.json').read_text());rows=json.loads((ROOT/'output/defense-reuse-20261104/evaluated.json').read_text())
controls=[]
for q in rows:
 w=q['ownAttack']['best']['cueWidth'];c=max(o.get('comfort',{}).get('total',0) for o in q['ownAttack']['options'])
 controls.append(dict(id=q['id'],cue=q['cue'],positions=q['positions'],own=q['own'],width=w,comfort=c,accepted=1e-6<w<=policy['cueWidthLimitDegrees'] and c<=policy['maxRepresentativeComfortLimit']))
# Preserve exact existing regression bytes when semantically identical.
p=OUT/'controls.json'
if p.exists():assert json.loads(p.read_text())==controls
else:p.write_text(json.dumps(controls,separators=(',',':')))
paths=['research/defense-full-filter-20261104/'+n for n in ['main.swift','PipeWindow.swift','prepare.py','run.py']]+['output/defense-full-filter-20261104/'+n for n in ['protocol.json','input-manifest.json','controls.json']]
algorithm={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths}
p=OUT/'algorithm.json'
if p.exists():assert json.loads(p.read_text())==algorithm,'Existing algorithm differs: archive results before a new algorithm run.'
else:p.write_text(json.dumps(algorithm,indent=2))
print('Regression cases',len(controls),'fingerprint',hashlib.sha256(p.read_bytes()).hexdigest())
