from pathlib import Path
import json,math,hashlib
b=Path(__file__).resolve().parent
d=json.loads((b/'analysis.json').read_text());sample=json.loads((b/'sample.json').read_text());proof=json.loads((b/'validate-results.json').read_text())['rows']
for c in d['cases']:
 for band in c['bands']:
  rows=[r for r in proof if r['key']==c['key']+'/'+band['key']]
  ids=[]
  for i in band['common']:
   p=d['points'][i];group=[r for r in rows if math.dist(r['point'],p)<1e-6]
   expected=round((band['interval'][1]-band['interval'][0])/.005)+1
   assert len(group)==expected,(c['key'],band['key'],i,len(group),expected)
   assert all(r['secondAttempts']>0 for r in group)
   good=all(r['accepted'] and r['secondPass'] and r['rails']==c['source']['rails'] and r['clearance']>.1 for r in group)
   if good:ids.append(i)
  band['verified']=ids
  band['validatedPairs']=len(rows)
 c['rows']=[r for r in c['rows'] if r['v']>=2.5]
 for row in c['rows']:
  for k in list(row):
   if k not in ['v','stop','clearance','rails','sameRoute','safe','accepted','cuePath','objectPath','originalAngle']:del row[k]
  row['stop']=[round(x,7) for x in row['stop']]
 d['railNames']=['下左','下右','上左','上右','左','右']
d['rails']=[[[r['start']['x'],r['start']['z']],[r['end']['x'],r['end']['z']]] for r in sample['geometry']['lines'][:6]]
(b/'visual-data.json').write_text(json.dumps(d,separators=(',',':')))
fragment=(b/'visual-template.html').read_text().replace('__DATA__',json.dumps(d,separators=(',',':')))
assert len(fragment.encode())<1000000
(b/'fixed-route-tolerance.html').write_text(fragment)
print('visual bytes',len(fragment.encode()))
summary={'scanSamples':1502,'sampleStep':.005,'nativeTests':'scan 1/0 failures; two-shot validation 1/0 failures','twoShotPairs':len(proof),'twoShotPasses':sum(r['secondPass'] for r in proof),'secondAttempts':sum(r['secondAttempts'] for r in proof),'cases':[{k:v for k,v in c.items() if k!='rows'} for c in d['cases']],'limitations':['discrete speed grid, not a continuous interval proof','3cm candidate grid, not every continuous position tested','upper speed boundary capped at4.5','cue access uses existing geometry profile, not human stance or calibrated elevated physics'],'sourceSnapshot':'../source-snapshot.zip + Research.swift; frozen physics hash parity checked','cleanup':'pending','visualReview':'pending'}
(b/'review.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
