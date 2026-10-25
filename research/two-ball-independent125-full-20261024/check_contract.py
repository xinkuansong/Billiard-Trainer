from pathlib import Path
import sys,json,gzip,copy
import runtime_common as common
from stratified_sampling import combinations
from contract import normalize,validate,stats,merge
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'output/two-ball-independent125-20261024';out=ROOT/'output/two-ball-independent125-full-20261024';count=0;changed=0;agg={}
for path in sorted((BASE/'parts').glob('*.jsonl.gz')):
 raw=BASE/'event-order-originals'/path.name
 if not raw.exists():raw=path
 with gzip.open(raw,'rt') as f:g=[json.loads(l) for l in f]
 with gzip.open(path,'rt') as f:expected=[json.loads(l) for l in f]
 for a,b in zip(g,expected,strict=True):
  for r in a['rows']:
   normalize(r)
   if 'excludedPreContactCushionMetadata' in r:changed+=1
  cs=combinations(a['id']);common.checked(a,a['board'],cs);validate(a,a['board'],cs)
  cp=copy.deepcopy(a)
  for r in cp['rows']:r.pop('excludedPreContactCushionMetadata',None)
  assert cp==b
  merge(agg,stats(a));count+=1
assert count==1000 and agg['attempts']==125000 and agg['status']['success']==101197 and changed==189
bad=copy.deepcopy(a);i=next(i for i,r in enumerate(bad['rows']) if r['usableForPositionMatch']);bad['rows'][i]['trajectory2mm']['maxDeviationMeters']=.003
try:validate(bad,a['board'],cs)
except AssertionError:pass
else:raise AssertionError('Error bound guard failed')
(out/'contract-check.json').write_text(json.dumps(dict(passed=True,layouts=count,attempts=agg['attempts'],normalizationMatchesPilot=changed,success=agg['status']['success'],badCompressionRejected=True),indent=2));print('CONTRACT PASS',count,agg['attempts'])
