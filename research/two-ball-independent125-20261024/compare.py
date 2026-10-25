from pathlib import Path
import json,gzip,collections
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name;BASE=ROOT/'output/two-ball-stratified125-20261024'
def read(p):return json.loads(p.read_text())
def load(p):
 with gzip.open(p,'rt') as f:return [json.loads(l) for l in f]
def clean(r):return {k:v for k,v in r.items() if k not in ['wallMilliseconds','initialAimMilliseconds','physicsMilliseconds','extractionCompressionMilliseconds']}
s=read(OUT/'summary.json');old=read(BASE/'summary.json');pairs=collections.Counter();centers=0;changed=0
for path in sorted((OUT/'parts').glob('*.jsonl.gz')):
 for a,b in zip(load(path),load(BASE/'parts'/path.name),strict=True):
  assert a['id']==b['id'] and a['board']==b['board']
  for x,y in zip(a['rows'],b['rows'],strict=True):
   for k in ['comboIndex','tipID','speedID','velocity','strokeCategory']:assert x[k]==y[k]
   if x['strokeCategory']=='center':assert clean(x)==clean(y);centers+=1
   else:assert (x['spinX'],x['spinY'])!=(y['spinX'],y['spinY']);changed+=1
   key='both_success' if x['usableForPositionMatch'] and y['usableForPositionMatch'] else 'new_only_success' if x['usableForPositionMatch'] else 'old_only_success' if y['usableForPositionMatch'] else 'both_failure';pairs[key]+=1
assert centers==14000 and changed==111000
comparison=dict(pairedLayouts=1000,pairedAttempts=125000,selectedIDsAndSpeedsIdentical=True,centerResultsExactlyIdentical=centers,changedNoncenterTips=changed,oldSuccess=old['status']['success'],newSuccess=s['status']['success'],successDelta=s['status']['success']-old['status']['success'],oldElapsedSeconds=old['elapsedComputeAndWriteSeconds'],newElapsedSeconds=s['elapsedComputeAndWriteSeconds'],pairedOutcomes=dict(pairs),categories={c:dict(oldSuccess=old['categories'][c]['success'],newSuccess=v['success'],delta=v['success']-old['categories'][c]['success']) for c,v in s['categories'].items()})
(OUT/'comparison.json').write_text(json.dumps(comparison,indent=2));print(json.dumps(comparison,indent=2))
