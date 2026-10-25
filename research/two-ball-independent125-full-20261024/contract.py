import collections,math,struct
from stratified_sampling import QUOTAS,VERSION

def f32(v):return struct.unpack('f',struct.pack('f',v))[0]
def normalize(r):
 if 'trajectory2mm' not in r:return
 k=r['trajectory2mm'];ev=[e for e in r['events'] if e['kind']=='cushion' and e['ball']=='cueBall' and e['time']>=r['firstContactTime']]
 assert len(k['cushions'])==len(ev)
 for c,e in zip(k['cushions'],ev):assert c['time']==e['time'] and c['cushionID']==e.get('cushionID')
 excluded=[c for c,e in zip(k['cushions'],ev) if not e['afterFirstContact']]
 assert all(c['pointIndex']==0 and c['time']==r['firstContactTime'] for c in excluded)
 if excluded:r['excludedPreContactCushionMetadata']=excluded
 k['cushions']=[c for c,e in zip(k['cushions'],ev) if e['afterFirstContact']]
def validate(d,board,cs):
 assert d['id']==board['id'] and d['board']==board and d['samplingVersion']==VERSION
 assert len(d['rows'])==len(cs)==125 and len({c['comboIndex'] for c in cs})==125
 assert collections.Counter(c['strokeCategory'] for c in cs)==QUOTAS
 for r,c in zip(d['rows'],cs,strict=True):
  assert all(r[k]==c[k] for k in ['comboIndex','tipID','speedID','strokeCategory'])
  assert all(r[k]==f32(c[k]) for k in ['spinX','spinY','velocity'])
  x,y=r['spinX'],r['spinY'];assert x*x+y*y<=.25+1e-7 and .6-1e-7<=r['velocity']<=4.5
  cat='center' if x==y==0 else 'vertical' if x==0 else 'horizontal' if y==0 else 'mixed';assert r['strokeCategory']==cat
  assert r['directionRetries']==0 and r['simulationCalls'] in (0,1)
  assert ('trajectory2mm' in r)==r['usableForPositionMatch']==(r['status']=='success')
  if r['usableForPositionMatch']:
   k=r['trajectory2mm'];p=k['points'];idx=k['sourcePointIndices']
   assert r['parameterStatus']=='legal' and r['cueAccessAvailable'] and r['targetPottedSelected'] and not r['cuePocketed'] and r['termination']=='settled' and r['cueStopValid']
   assert k['toleranceMeters']==.002 and 0<=k['maxDeviationMeters']<=.002+1e-12
   assert len(p)==len(idx)>=2 and all(math.isfinite(x) for point in p for x in point)
   assert p[0][0]==0 and all(a[0]<=b[0] for a,b in zip(p,p[1:])) and math.dist(p[-1][1:],r['cueStop'])<1e-6
   assert idx==sorted(set(idx)) and idx[0]==0 and idx[-1]==k['sourcePointCount']-1
   assert all(0<=i<len(p) for i in k['mandatoryPointIndices'])
   es=[e for e in r['events'] if e['kind']=='cushion' and e['ball']=='cueBall' and e['afterFirstContact']]
   assert len(es)==len(k['cushions'])
   assert all(e.get('cushionID')==c['cushionID'] and e['time']==c['time'] and 0<=c['pointIndex']<len(p) and abs(p[c['pointIndex']][0]+r['firstContactTime']-c['time'])<3e-6 for e,c in zip(es,k['cushions']))
def merge(a,b):
 for k,v in b.items():
  if isinstance(v,dict):merge(a.setdefault(k,{}),v)
  elif k=='maxDeviationMeters':a[k]=max(a.get(k,0),v)
  else:a[k]=a.get(k,0)+v
 return a
def inc(d,k,n=1):d[str(k)]=d.get(str(k),0)+n
def stats(d):
 s=dict(layoutCount=1,attempts=125,status={},termination={},categories={c:dict(attempts=0,success=0,status={},wallMilliseconds=0.,validPerLayoutHistogram={}) for c in QUOTAS},validPerLayoutHistogram={},keypointHistogram={},sourcePointHistogram={},cueRailsForSuccess={},maxDeviationMeters=0.,metadataNormalizedRecords=0,simulationCalls=0,directionRetries=0,summedWorkerBatchSeconds=d['elapsedSeconds'])
 n=0;vc=collections.Counter()
 for r in d['rows']:
  inc(s['status'],r['status']);inc(s['termination'],r['termination']);c=s['categories'][r['strokeCategory']];c['attempts']+=1;inc(c['status'],r['status']);c['wallMilliseconds']+=r['wallMilliseconds'];s['simulationCalls']+=r['simulationCalls'];s['directionRetries']+=r['directionRetries']
  if 'excludedPreContactCushionMetadata' in r:s['metadataNormalizedRecords']+=1
  if r['usableForPositionMatch']:
   n+=1;c['success']+=1;vc[r['strokeCategory']]+=1;k=r['trajectory2mm'];inc(s['keypointHistogram'],len(k['points']));inc(s['sourcePointHistogram'],k['sourcePointCount']);inc(s['cueRailsForSuccess'],r['cueMainRailsAfterContact']);s['maxDeviationMeters']=max(s['maxDeviationMeters'],k['maxDeviationMeters'])
 inc(s['validPerLayoutHistogram'],n)
 for cat in QUOTAS:inc(s['categories'][cat]['validPerLayoutHistogram'],vc[cat])
 return s
def hist_stats(hist):
 pairs=sorted((int(k),v) for k,v in hist.items());n=sum(v for k,v in pairs)
 if not n:return dict(count=0)
 def at(rank):
  seen=0
  for k,v in pairs:
   seen+=v
   if seen>rank:return k
 return dict(count=n,sum=sum(k*v for k,v in pairs),mean=sum(k*v for k,v in pairs)/n,min=pairs[0][0],max=pairs[-1][0],median=(at((n-1)//2)+at(n//2))/2,p10=at(int(.1*(n-1))),p90=at(int(.9*(n-1))))
