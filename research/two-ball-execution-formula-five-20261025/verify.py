"""Independent Decimal recomputation and source-preservation audit."""
from pathlib import Path
from decimal import Decimal, getcontext
import gzip,hashlib,json,shutil,urllib.request
getcontext().prec=40
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/two-ball-execution-formula-five-20261025'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def D(x):return Decimal(str(x))
new=json.loads((OUT/'data.json').read_text());oldpath=ROOT/new['previousPreview']['path']
assert sha(oldpath)==new['previousPreview']['sha256']
old=json.loads(oldpath.read_text());assert new['geometry']==old['geometry']
assert len(new['samples'])==len(old['samples'])==5
maximum=0.;changed=0
for s,o in zip(new['samples'],old['samples']):
 assert {k:v for k,v in s.items() if k!='newRanking'}==o
 p=ROOT/s['source'];assert sha(p)==s['sourceSHA256']
 raw=next(x for x in map(json.loads,gzip.decompress(p.read_bytes()).splitlines()) if x['id']==s['id'])
 assert raw['board']==s['board']
 assert next(x for x in raw['candidates'] if x['cellID']==s['candidate']['cellID'])==s['candidate']
 assert all(t==next(x for x in raw['routes'] if x['comboIndex']==t['comboIndex']) for t in s['routes'])
 pairs=[]
 for t in s['routes']:
  q=next(x for x in s['newRanking'] if x['comboIndex']==t['comboIndex'])
  xy=[(D(p[1]),D(p[2])) for p in t['trajectory2mm']['points']]
  length=sum((((b[0]-a[0])**2+(b[1]-a[1])**2).sqrt() for a,b in zip(xy,xy[1:])),D(0))
  x=abs(D(t['spinX']));y=D(t['spinY']);v=D(t['velocity']);n=D(t['cueMainRailsAfterContact'])
  values={'stroke':D('2.5')*x+(D('.8')*y if y>=0 else -D('1.2')*y),
          'power':D('.8')*v*v/D('20.25'),
          'route':D('.12')*n+D('.06')*length,
          'interaction':D('.6')*x*v/D('4.5')+D('.15')*n*x}
  e=sum(values.values());score=D(100)*e/(e+1)
  checks=[(length,q['lengthMeters']),(e,q['effort']),(score,q['difficulty'])]+[(value,q['components'][k]) for k,value in values.items()]
  for expected,actual in checks:
   delta=abs(float(expected)-actual);maximum=max(maximum,delta);assert delta<1e-11
  prev=next(x for x in o['ranking'] if x['comboIndex']==q['comboIndex'])
  assert (q['previousRank'],q['originalRank'])==(prev['rank'],prev['originalRank'])
  assert q['rankChange']==q['previousRank']-q['rank']
  changed+=q['rankChange']!=0
  pairs.append((e,q['originalRank'],q['comboIndex']))
 assert [v[2] for v in sorted(pairs)]==[q['comboIndex'] for q in s['newRanking']]
 assert [q['rank'] for q in s['newRanking']]==[1,2,3,4,5]
# Ensure every old delivered image/HTML/data file remains byte-identical to the prior receipt.
oldreceipt=json.loads((oldpath.parent/'verification.json').read_text())
for name,rec in oldreceipt['httpFilesExact'].items():assert sha(oldpath.parent/name)==rec['sha256']
served=ROOT/'output/two-ball-multi-position-top10-20261024/execution-formula-five';served.mkdir(exist_ok=True)
receipts={}
for name in ['index.html','data.json','comparison.png']+[f'sample-{i}.png' for i in range(1,6)]:
 shutil.copy2(OUT/name,served/name)
 with urllib.request.urlopen('http://127.0.0.1:51240/execution-formula-five/'+name,timeout=10) as r:body=r.read()
 assert hashlib.sha256(body).hexdigest()==sha(OUT/name)
 receipts[name]=dict(sha256=sha(OUT/name),bytes=len(body))
report=dict(status='passed',questions=5,routes=25,changedRankRoutes=changed,decimalMaximumDifference=maximum,sourceRecordsUnchanged=True,previousPreviewFilesUnchanged=True,httpFiles=receipts,visualReview='all five detail sheets and comparison inspected',simulation='not run; scoring only')
(OUT/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps({k:v for k,v in report.items() if k!='httpFiles'},ensure_ascii=False))
