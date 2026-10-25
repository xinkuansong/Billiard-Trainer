from pathlib import Path
import json,shutil,hashlib,collections
from stratified_sampling import combinations,VERSION,QUOTAS,REGIONS
import quota_sampling_v1 as baseline
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name
old=ROOT/'research/two-ball-stratified125-20261024';base=ROOT/'output/two-ball-stratified125-20261024'
assert not list((OUT/'parts').glob('*.gz')),'Do not reprepare a populated result'
shutil.copy2(base/'layouts.json',OUT/'layouts.json');boards=json.loads((OUT/'layouts.json').read_text());totals=collections.Counter();changed=0
for b in boards:
 cs=combinations(b['id']);oldcs=baseline.combinations(b['id']);assert cs==combinations(b['id']);assert len(cs)==len({c['comboIndex'] for c in cs})==125
 assert collections.Counter(c['strokeCategory'] for c in cs)==QUOTAS
 assert len({(c['spinX'],c['spinY']) for c in cs})==112
 totals.update(c['strokeCategory'] for c in cs)
 for c,prev in zip(cs,oldcs):
  assert all(c[k]==prev[k] for k in ['comboIndex','tipID','speedID','velocity','strokeCategory'])
  x,y=c['spinX'],c['spinY'];cx,cy=REGIONS[c['tipID']-1];assert x*x+y*y<=.25 and .6<=c['velocity']<=4.5
  assert abs(x-cx)<=.075+1e-12 and abs(y-cy)<=.075+1e-12
  expected='center' if x==y==0 else 'vertical' if x==0 else 'horizontal' if y==0 else 'mixed';assert c['strokeCategory']==expected
  if expected=='center':assert c==prev
  else:assert (x,y)!=(prev['spinX'],prev['spinY']);changed+=1
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=dict(state='prepared',samplingVersion=VERSION,layouts=1000,attemptsPerLayout=125,quotas=QUOTAS,totals=dict(totals),workers=16,layoutsSHA256=sha(OUT/'layouts.json'),samplingSHA256=sha(HERE/'stratified_sampling.py'),quotaBaselineSHA256=sha(HERE/'quota_sampling_v1.py'),binarySHA256=sha(ROOT/'research/two-ball-sample125-once-20261024/Worker.app/Worker'),changedNoncenterInputs=changed,unchangedCenterInputs=14000,selectedIDsAndSpeedsIdentical=True,rules='Each layout+combo has separate SHA256 RNG for its tip. Fixed center/exact zero axis; same regions/radius .5. Same125 selected comboIDs,14/42/18/51 quotas and same speed values as axis-v1. Frozen physics, zero aim retries, failures not refilled, successful 2mm keypoints.')
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2));(OUT/'sampling-preview.json').write_text(json.dumps(combinations(boards[0]['id']),indent=2))
for name in ['run.py','normalize_events.py','audit.py']:shutil.copy2(old/name,HERE/name)
s=(HERE/'audit.py').read_text().replace("assert hashlib.sha256((HERE/'stratified_sampling.py').read_bytes()).hexdigest()==manifest['samplingSHA256']", "assert hashlib.sha256((HERE/'stratified_sampling.py').read_bytes()).hexdigest()==manifest['samplingSHA256']\nassert hashlib.sha256((HERE/'quota_sampling_v1.py').read_bytes()).hexdigest()==manifest['quotaBaselineSHA256']")
(HERE/'audit.py').write_text(s)
print(json.dumps(manifest,indent=2))
