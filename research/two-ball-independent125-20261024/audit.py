from pathlib import Path
import json,gzip,collections,statistics,math,struct,hashlib,csv
from stratified_sampling import combinations, QUOTAS, VERSION
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name;BASE=ROOT/'output/two-ball-strike-sampled100-20261024'
read=lambda p:json.loads(p.read_text())
def f32(v):return struct.unpack('f',struct.pack('f',v))[0]
def stats(x):
 s=sorted(x);return dict(count=len(s),sum=sum(s),mean=statistics.mean(s),median=statistics.median(s),min=s[0],p10=s[int(.1*(len(s)-1))],p90=s[int(.9*(len(s)-1))],p95=s[int(.95*(len(s)-1))],max=s[-1])
categories={k:dict(status=collections.Counter(),milliseconds=0.,keypoints=[],validPerLayout=[]) for k in QUOTAS}
run=read(OUT/'run-complete.json');manifest=read(OUT/'manifest.json');boards={b['id']:b for b in read(OUT/'layouts.json')}
assert len(boards)==1000 and run['layoutCount']==1000
status=collections.Counter();terms=collections.Counter();points=[];fullpoints=[];deviations=[];valid=[];layouts=[];seen=set();new={};timings=collections.Counter();maxevents=0;calls=0
for receipt in run['receipts']:
 file=OUT/'parts'/receipt['file'];assert hashlib.sha256(file.read_bytes()).hexdigest()==receipt['sha256']
 with gzip.open(file,'rt') as f:
  for line in f:
   d=json.loads(line);lid=d['id'];assert lid not in seen;seen.add(lid);assert d['board']==boards[lid]
   cs=combinations(lid,125);assert len(d['rows'])==125
   n=0;catvalid=collections.Counter();catattempt=collections.Counter()
   assert d['samplingVersion']==VERSION
   for r,c in zip(d['rows'],cs,strict=True):
    assert r['comboIndex']==c['comboIndex']
    cat=c['strokeCategory'];assert r['strokeCategory']==cat;catattempt[cat]+=1
    x,y=r['spinX'],r['spinY'];assert cat==('center' if x==y==0 else 'vertical' if x==0 else 'horizontal' if y==0 else 'mixed')
    categories[cat]['status'][r['status']]+=1;categories[cat]['milliseconds']+=r['wallMilliseconds']
    if r['usableForPositionMatch']:catvalid[cat]+=1;categories[cat]['keypoints'].append(len(r['trajectory2mm']['points']))
    assert all(r[k]==f32(c[k]) for k in ['spinX','spinY','velocity'])
    status[r['status']]+=1;terms[r['termination']]+=1;calls+=r['simulationCalls'];assert r['directionRetries']==0 and r['simulationCalls']<=1
    new[lid,r['comboIndex']]=dict(success=r['usableForPositionMatch'],status=r['status'],offset=r.get('aimOffsetRadians'),cueStop=r.get('cueStop'))
    for k in ['initialAimMilliseconds','physicsMilliseconds','extractionCompressionMilliseconds','wallMilliseconds']:timings[k]+=r.get(k,0)
    assert ('trajectory2mm' in r)==r['usableForPositionMatch']
    if r['usableForPositionMatch']:
     n+=1;k=r['trajectory2mm'];p=k['points'];assert r['targetPottedSelected'] and not r['cuePocketed'] and r['cueAccessAvailable'] and r['termination']=='settled'
     assert k['toleranceMeters']==.002 and k['maxDeviationMeters']<=.002+1e-12 and k['maxDeviationMeters']>=0
     assert len(p)>=2 and all(math.isfinite(x) for point in p for x in point)
     assert p[0][0]==0 and all(a[0]<=b[0] for a,b in zip(p,p[1:]))
     assert math.dist(p[-1][1:],r['cueStop'])<1e-6
     assert k['sourcePointIndices']==sorted(set(k['sourcePointIndices'])) and k['sourcePointIndices'][0]==0 and k['sourcePointIndices'][-1]==k['sourcePointCount']-1
     es=[e for e in r['events'] if e['kind']=='cushion' and e['ball']=='cueBall' and e['afterFirstContact']]
     assert len(es)==len(k['cushions']);assert all(e.get('cushionID')==c.get('cushionID') and e['time']==c['time'] for e,c in zip(es,k['cushions']))
     assert all(0<=c['pointIndex']<len(p) and abs(p[c['pointIndex']][0]+r['firstContactTime']-c['time'])<3e-6 for c in k['cushions'])
     points.append(len(p));fullpoints.append(k['sourcePointCount']);deviations.append(k['maxDeviationMeters']);maxevents=max(maxevents,len(es))
   assert catattempt==QUOTAS
   for cat in QUOTAS:categories[cat]['validPerLayout'].append(catvalid[cat])
   valid.append(n);layouts.append(dict(id=lid,angle=d['board']['angle'],pocket=d['board']['pocket'],valid=n,attempts=125,workerBatchSeconds=d['elapsedSeconds']))
assert seen==set(boards) and sum(status.values())==125000 and sum(valid)==status['success']
# Independently recompute point-to-segment deviations from the raw full-line fixtures.
fixtures=0;largest=0
for file in sorted((OUT/'audit-paths').glob('*.json.gz')):
 with gzip.open(file,'rt') as f:d=json.load(f)
 for r in d['rows']:
  line=r['line'];x=[[f32(p['position']['x']),f32(p['position']['z'])] for p in line];k=r['compact'];idx=k['sourcePointIndices'];err=0.
  assert {i for i,p in enumerate(line) if p.get('isEvent')}<=set(idx)
  for j,i in enumerate(idx):assert x[i]==k['points'][j][1:]
  for a,b in zip(idx,idx[1:]):
   delta=[x[b][j]-x[a][j] for j in range(2)];ll=sum(z*z for z in delta)
   for i in range(a,b+1):
    u=sum((x[i][j]-x[a][j])*delta[j] for j in range(2))/ll if ll else 0;u=max(0,min(1,u));err=max(err,math.dist(x[i],[x[a][j]+u*delta[j] for j in range(2)]))
  assert err<=.002+1e-12 and abs(err-k['maxDeviationMeters'])<1e-12
  fixtures+=1;largest=max(largest,err)

assert len(seen)==1000
cleanup=read(OUT/'cleanup.json');assert cleanup['shutdownExitCode']==0 and cleanup['workerExitCodes']==[0]*16
assert len(set(read(OUT/'workers.json')['pids']))==16
assert read(OUT/'workers.json')['binarySHA256']==manifest['binarySHA256']
assert hashlib.sha256((OUT/'layouts.json').read_bytes()).hexdigest()==manifest['layoutsSHA256']
assert hashlib.sha256((HERE/'stratified_sampling.py').read_bytes()).hexdigest()==manifest['samplingSHA256']
assert hashlib.sha256((HERE/'quota_sampling_v1.py').read_bytes()).hexdigest()==manifest['quotaBaselineSHA256']
for cat,v in categories.items():
 v['attempts']=sum(v['status'].values());v['success']=v['status']['success'];v['successRate']=v['success']/v['attempts'];v['meanAttemptMilliseconds']=v['milliseconds']/v['attempts'];v['summedAttemptSeconds']=v.pop('milliseconds')/1000
 v['validPerLayout']=stats(v['validPerLayout']);v['keypointsPerSuccess']=stats(v.pop('keypoints'));assert v['attempts']==QUOTAS[cat]*1000
summary=dict(state='complete',auditPassed=True,samplingVersion=VERSION,layoutCount=1000,attempts=125000,workers=16,status=dict(status),termination=dict(terms),successRate=status['success']/125000,categories=categories,validPerLayout=stats(valid),layoutsAtLeast100=sum(n>=100 for n in valid),layoutsZero=sum(n==0 for n in valid),keypointsPerSuccess=stats(points),sourcePointsPerSuccess=stats(fullpoints),pointReductionPercent=100*(1-sum(points)/sum(fullpoints)),maxDeviationMeters=max(deviations),simulationCalls=calls,directionRetries=0,elapsedComputeAndWriteSeconds=run['elapsedComputeAndWriteSeconds'],elapsedIncludingStartupSeconds=run['elapsedIncludingStartupSeconds'],summedPhaseWallMilliseconds=dict(timings),summedWorkerBatchSeconds=sum(r['summedBatchWallSeconds'] for r in run['receipts']),compressedResultBytes=sum((OUT/'parts'/r['file']).stat().st_size for r in run['receipts']),independentCompressionFixtures=fixtures,independentMaxDeviationMeters=largest,memory=read(OUT/'memory.json'),eventOrderNormalization=read(OUT/'event-order-normalization.json')['changedRecords'],scope='1000 layouts; new axis-preserving125 quotas; one simulation, no retries/refills, frozen original physics; success2mm keypoints; no second-ball interference or P2dedup')
(OUT/'summary.json').write_text(json.dumps(summary,indent=2));(OUT/'layout-statistics.json').write_text(json.dumps(layouts,separators=(',',':')))
print(json.dumps({k:v for k,v in summary.items() if k!='memory'},indent=2))
