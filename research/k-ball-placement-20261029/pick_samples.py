from pathlib import Path
import json,collections
OUT=Path(__file__).resolve().parents[2]/'output/k-ball-placement-20261029'
rows=json.loads((OUT/'trials.json').read_text());samples=[];contrasts=[]
for axis in ['inAngle','outAngle']:
 for ordinal in [1,2,3]:
  group=[r for r in rows if r['axis']==axis and r['railOrdinal']==ordinal]
  passed=[r for r in group if r['success']]
  # Present source diversity, then gap diversity; no threshold claiming useful breakout.
  passed.sort(key=lambda r:(-r.get('finalBGap',-1),r['id']))
  picked=[];sources=set()
  for r in passed:
   if r['sourceID'] not in sources:
    picked.append(r);sources.add(r['sourceID'])
   if len(picked)>=3:break
  if passed:
   low=min(passed,key=lambda r:r.get('BDisplacementMeters',0))
   if low not in picked:picked.append(low)
  for gap in [0,.015,.03]:
   if not any(r['initialGap']==gap for r in picked):
    other=next((r for r in passed if r['initialGap']==gap and r not in picked),None)
    if other and len(picked)<5:picked.append(other)
  samples+=picked
  fail=[r for r in group if not r['success']]
  if fail:contrasts.append(fail[0])
# Retain the two user-recognised route anchors in both groups when eligible.
for sourceID in ['N01','N08-R2']:
 for axis in ['inAngle','outAngle']:
  options=[r for r in rows if r['success'] and r['sourceID']==sourceID and r['axis']==axis]
  if options and not any(r['sourceID']==sourceID and r['axis']==axis for r in samples):
   samples.append(max(options,key=lambda r:r.get('finalBGap',-1)))
(OUT/'samples.json').write_text(json.dumps(samples,ensure_ascii=False))
(OUT/'contrasts.json').write_text(json.dumps(contrasts,ensure_ascii=False))
(OUT/'summary.json').write_text(json.dumps(dict(trials=len(rows),success=sum(r['success'] for r in rows),failures=dict(collections.Counter(r['reason'] for r in rows if not r['success'])),selected=len(samples),groups=[dict(axis=a,ordinal=n,trials=sum(r['axis']==a and r['railOrdinal']==n for r in rows),success=sum(r['axis']==a and r['railOrdinal']==n and r['success'] for r in rows)) for a in ['inAngle','outAngle'] for n in [1,2,3]]),indent=2))
print('SELECTED',len(samples),flush=True)
