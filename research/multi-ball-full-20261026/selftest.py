"""Prior native evidence parity and negative admission/audit cases."""
import copy, json, math
from pathlib import Path
from bank import KINDS, classify, verify_base, job, signature
from run import write

ROOT=Path(__file__).resolve().parents[2]
PILOT=ROOT/'output/multi-ball-generation-20261026'
cal=json.loads((PILOT/'calibration.json').read_text())
old={b['id']:b for b in json.loads((PILOT/'base-candidates.json').read_text())}
counts={}; checked=0; accepted=[]
for n in KINDS:
    meta=json.loads((PILOT/f'metadata-{n}.json').read_text()); count=0
    for line in (PILOT/f'raw-{n}.jsonl').read_text().splitlines():
        row=json.loads(line); decision,base=classify(row,meta,cal); checked+=1
        if base:
            assert abs(base['index']-old[base['id']]['index'])<1e-12
        assert (decision=='accepted')==(row['input']['id'] in old and old[row['input']['id']]['index']>=1.2)
        if decision=='accepted':
            verify_base(base,meta,cal); accepted.append((row,base,meta)); count+=1
    counts[str(n)]=count
row,base,meta=accepted[0]; negative=[]
bad=copy.deepcopy(row); bad['status']='incomplete'; assert classify(bad,meta,cal)[0]=='incomplete'; negative.append('incomplete rejected')
bad=copy.deepcopy(row); key=next(k for k in bad['board'] if k!='cueBall'); bad['board'].pop(key); bad['pocketed'].append(key)
assert classify(bad,meta,cal)[0]=='target_potted'; negative.append('potted target rejected')
bad=copy.deepcopy(row); keys=[k for k in bad['board'] if k!='cueBall']; bad['board'][keys[0]]=bad['board'][keys[1]]
assert classify(bad,meta,cal)[0]=='invalid_geometry'; negative.append('overlap rejected')
bad=copy.deepcopy(base); bad['index']=1.19999
try: verify_base(bad,meta,cal)
except AssertionError: negative.append('corrupted score rejected')
else: raise AssertionError('Audit failed to reject corruption')
scratch=copy.deepcopy(row)
if 'cueBall' in scratch['board']: scratch['board'].pop('cueBall'); scratch['pocketed'].append('cueBall')
scratch['cueScratched']=True
assert classify(scratch,meta,cal)[0]=='accepted'; negative.append('cue scratch retained')
assert job(meta,4,0,0,0)==job(meta,4,0,0,0)
assert len({job(meta,4,s,i,e)['id'] for s in range(2) for i in range(3) for e in range(2)})==12
assert signature(base)==signature({**base,'balls':list(reversed(base['balls']))})
result=dict(passed=True,priorNativeRecords=checked,expectedAccepted=counts,negativeChecks=negative,
    determinism=True,uniqueAttemptIDs=True,ballOrderInvariant=True)
out=ROOT/'output/multi-ball-full-preflight-20261026'; out.mkdir(exist_ok=True)
write(out/'selftest.json',result); print(json.dumps(result,ensure_ascii=False))
