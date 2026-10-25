"""Normalize raw event-time matches by authoritative engine event order.
No trajectory coordinates, statuses, timings or physics results are modified.
Original affected files and receipts remain in event-order-originals/.
"""
from pathlib import Path
import json,gzip,hashlib,shutil
HERE=Path(__file__).resolve().parent;OUT=HERE.parents[1]/'output'/HERE.name
read=lambda p:json.loads(p.read_text())
backup=OUT/'event-order-originals';backup.mkdir(exist_ok=True)
if (OUT/'event-order-normalization.json').exists():raise SystemExit('Already normalized; do not repeat')
run=read(OUT/'run-complete.json');shutil.copy2(OUT/'run-complete.json',backup/'run-complete.json')
changes=[]
def fix(r,lid):
 if 'trajectory2mm' not in r:return False
 k=r['trajectory2mm'];allCue=[e for e in r['events'] if e['kind']=='cushion' and e['ball']=='cueBall' and e['time']>=r['firstContactTime']]
 cs=k['cushions'];assert len(cs)==len(allCue)
 assert all(c['time']==e['time'] and c['cushionID']==e.get('cushionID') for c,e in zip(cs,allCue))
 kept=[c for c,e in zip(cs,allCue) if e['afterFirstContact']]
 if len(kept)==len(cs):return False
 removed=[c for c,e in zip(cs,allCue) if not e['afterFirstContact']]
 assert all(c['time']==r['firstContactTime'] and c['pointIndex']==0 for c in removed)
 changes.append(dict(layoutID=lid,comboIndex=r['comboIndex'],removedFromPostContactCushions=removed))
 k['cushions']=kept;return True
for receipt in run['receipts']:
 path=OUT/'parts'/receipt['file']
 with gzip.open(path,'rt') as f:rows=[json.loads(l) for l in f]
 dirty=False
 for d in rows:
  for r in d['rows']:dirty=fix(r,d['id']) or dirty
 if dirty:
  shutil.copy2(path,backup/path.name)
  with gzip.open(path,'wt',compresslevel=6) as f:
   for d in rows:f.write(json.dumps(d,separators=(',',':'))+'\n')
  receipt['bytes']=path.stat().st_size;receipt['sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
(OUT/'run-complete.json').write_text(json.dumps(run,indent=2))
(OUT/'event-order-normalization.json').write_text(json.dumps(dict(changedRecords=len(changes),reason='same Float timestamp, cushion ordered before first ball-ball; exclude from post-contact event metadata only',changes=changes),indent=2))
print('Normalized',len(changes),'post-contact metadata lists; original files retained.')
