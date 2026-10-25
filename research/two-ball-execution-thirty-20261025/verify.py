"""Independent arithmetic, source identity and served-asset verification."""
from pathlib import Path
from decimal import Decimal,getcontext
import collections,gzip,hashlib,json,shutil,urllib.request
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/two-ball-execution-thirty-20261025'
getcontext().prec=40
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def D(x):return Decimal(str(x))
data=json.loads((OUT/'data.json').read_text());ss=data['samples']
priorpath=ROOT/data['previousPreview']['path'];assert sha(priorpath)==data['previousPreview']['sha256']
prior=json.loads(priorpath.read_text());assert data['model']==prior['model'] and data['geometry']==prior['geometry']
assert len(ss)==len({s['id'] for s in ss})==30
for s,o in zip(ss[:5],prior['samples']):assert {k:v for k,v in s.items() if k not in ('selectionKind','features')}==o
assert collections.Counter(s['title'] for s in ss[5:25])=={'角袋 · 0–15°':4,'角袋 · 16–30°':4,'角袋 · 大于30°':4,'中袋 · 0–20°':4,'中袋 · 大于20°':4}
for rec in data['selection']['scope']:assert sha(ROOT/rec['path'])==rec['sha256']
maxdiff=0.;count=0
for s in ss:
 p=ROOT/s['source'];assert sha(p)==s['sourceSHA256']
 raw=next(r for r in map(json.loads,gzip.decompress(p.read_bytes()).splitlines()) if r['id']==s['id'])
 assert raw['board']==s['board']
 assert next(c for c in raw['candidates'] if c['cellID']==s['candidate']['cellID'])==s['candidate']
 assert len(s['routes'])==len(s['newRanking'])==len(s['ranking'])==5
 assert len({t['comboIndex'] for t in s['routes']})==5
 pairs=[];oldpairs=[]
 original={c['comboIndex']:i for i,c in enumerate(s['candidate']['top5'],1)}
 for t in s['routes']:
  assert t==next(r for r in raw['routes'] if r['comboIndex']==t['comboIndex'])
  q=next(q for q in s['newRanking'] if q['comboIndex']==t['comboIndex'])
  x=abs(D(t['spinX']));y=D(t['spinY']);v=D(t['velocity']);n=D(t['cueMainRailsAfterContact'])
  xy=[(D(p[1]),D(p[2])) for p in t['trajectory2mm']['points']]
  length=sum((((b[0]-a[0])**2+(b[1]-a[1])**2).sqrt() for a,b in zip(xy,xy[1:])),D(0))
  parts={'stroke':D('2.5')*x+(D('.8')*y if y>=0 else -D('1.2')*y),'power':D('.8')*v*v/D('20.25'),'route':D('.12')*n+D('.06')*length,'interaction':D('.6')*x*v/D('4.5')+D('.15')*n*x}
  e=sum(parts.values());score=100*e/(e+1);old=D('2.5')*x+abs(y)+D('.25')*max(D(0),v-4)
  checks=[(length,q['lengthMeters']),(e,q['effort']),(score,q['difficulty']),(old,q['previousEffort'])]+[(value,q['components'][k]) for k,value in parts.items()]
  for expected,actual in checks:
   delta=abs(float(expected)-actual);maxdiff=max(maxdiff,delta);assert delta<1e-11
  assert q['originalRank']==original[t['comboIndex']]
  assert q['rankChange']==q['previousRank']-q['rank']
  pairs.append((e,q['originalRank'],q['comboIndex']));oldpairs.append((old,q['originalRank'],q['comboIndex']));count+=1
 assert [p[2] for p in sorted(pairs)]==[q['comboIndex'] for q in s['newRanking']]
 assert [p[2] for p in sorted(oldpairs)]==[q['comboIndex'] for q in s['ranking']]
 for rank,(_,_,combo) in enumerate(sorted(oldpairs),1):assert next(q['previousRank'] for q in s['newRanking'] if q['comboIndex']==combo)==rank
 assert [q['rank'] for q in s['newRanking']]==[1,2,3,4,5]
 f=s['features'];qs=s['newRanking'];assert f['changed']==sum(q['rank']!=q['previousRank'] for q in qs)
 assert f['winnerChanged']==(qs[0]['previousRank']!=1)
 assert abs(f['minGap']-min(b['difficulty']-a['difficulty'] for a,b in zip(qs,qs[1:])))<1e-12
summary=json.loads((OUT/'summary.json').read_text())
for key,group in [('all',ss),('original',ss[:5]),('balanced',ss[5:25]),('diagnostic',ss[25:])]:
 a=summary[key];assert a['questions']==len(group) and a['routes']==5*len(group)
 assert a['orderChanged']==sum(s['features']['changed']>0 for s in group)
 assert a['winnerChanged']==sum(s['features']['winnerChanged'] for s in group)
 assert a['rankChanged']==sum(s['features']['changed'] for s in group)
 assert a['adjacentGapUnderTwo']==sum(s['features']['minGap']<2 for s in group)
oldreceipt=json.loads((priorpath.parent/'verification.json').read_text())
for name,rec in oldreceipt['httpFiles'].items():assert sha(priorpath.parent/name)==rec['sha256']
served=ROOT/'output/two-ball-multi-position-top10-20261024/execution-thirty';served.mkdir(exist_ok=True)
receipts={}
names=['index.html','data.json','summary.json','overview.png','README.md']+[f'contact-{i}.png' for i in range(1,7)]+[f'sample-{i}.png' for i in range(1,31)]
for name in names:
 shutil.copy2(OUT/name,served/name)
 with urllib.request.urlopen('http://127.0.0.1:51240/execution-thirty/'+name,timeout=10) as response:body=response.read()
 assert hashlib.sha256(body).hexdigest()==sha(OUT/name)
 receipts[name]={'sha256':sha(OUT/name),'bytes':len(body)}
report=dict(status='passed',questions=30,routes=count,decimalMaximumDifference=maxdiff,sourceRecordsUnchanged=True,scannedShardsSHAUnchanged=len(data['selection']['scope']),priorFiveDataAndEightAssetsUnchanged=True,balancedStrata='4 each in 5 pocket/angle groups',httpFiles=receipts,simulation='not run; existing trajectories only')
(OUT/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps({k:v for k,v in report.items() if k!='httpFiles'},ensure_ascii=False));print('HTTP files:',len(receipts))
