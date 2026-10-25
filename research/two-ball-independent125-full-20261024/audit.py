from pathlib import Path
import json,gzip,math,sys,time
import runtime_common as common
from stratified_sampling import combinations,QUOTAS,VERSION
from contract import validate,stats,merge,hist_stats,f32
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name;read=lambda p:json.loads(p.read_text())
started=time.monotonic();run=read(OUT/'run-complete.json');manifest=read(OUT/'manifest.json');boards=read(OUT/'layouts.json');seen=set();aggregate={};compressed=0
assert run['layoutCount']==len(boards)==135700 and len(run['receipts'])==1357
with (OUT/'layout-statistics.jsonl').open('w') as table:
 for index,receipt in enumerate(run['receipts']):
  path=OUT/'parts'/f'{index:05d}.jsonl.gz';assert receipt['index']==index and path.stat().st_size==receipt['bytes'] and common.sha(path)==receipt['sha256'];st={};count=0
  with gzip.open(path,'rt') as f:
   for bi,line in zip(receipt['layoutIndices'],f,strict=True):
    d=json.loads(line);assert d['id'] not in seen;seen.add(d['id']);cs=combinations(d['id']);common.checked(d,boards[bi],cs);validate(d,boards[bi],cs);ss=stats(d);merge(st,ss);count+=1
    table.write(json.dumps(dict(id=d['id'],valid=ss['status'].get('success',0),byCategory={c:v['success'] for c,v in ss['categories'].items()}))+'\n')
  assert count==100 and st==receipt['stats'],'Receipt stats mismatch';merge(aggregate,st);compressed+=receipt['bytes']
  if index%10==0:common.write(OUT/'audit-progress.json',dict(state='auditing',auditedLayouts=len(seen),auditedAttempts=aggregate['attempts'],elapsedAuditSeconds=time.monotonic()-started));print('AUDIT',len(seen),'/',135700,flush=True)
assert len(seen)==135700 and aggregate['layoutCount']==135700 and aggregate['attempts']==16962500 and aggregate['directionRetries']==0
for c,v in QUOTAS.items():assert aggregate['categories'][c]['attempts']==v*135700
# Independent raw sampled-polyline compression verification, spread across the full schedule.
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
assert fixtures>0
for path,key in [(OUT/'layouts.json','layoutsSHA256'),(OUT/'schedule.json','scheduleSHA256'),(HERE/'stratified_sampling.py','samplingSHA256'),(HERE/'quota_sampling_v1.py','quotaBaselineSHA256'),(HERE/'Worker.app/Worker','binarySHA256'),(Path(manifest['sourceBank']),'sourceBankSHA256')]:assert common.sha(path)==manifest[key]
cleanup=read(OUT/'cleanup.json');assert cleanup['workerExitCodes']==[0]*16 and cleanup['shutdownExitCode']==0
assert len(set(read(OUT/'workers.json')['pids']))==16 and read(OUT/'pilot-parity.json')['passed']
for c,v in aggregate['categories'].items():v['successRate']=v['success']/v['attempts'];v['meanAttemptMilliseconds']=v['wallMilliseconds']/v['attempts'];v['validPerLayout']=hist_stats(v['validPerLayoutHistogram'])
aggregate.update(state='complete',auditPassed=True,sourceUnchanged=True,samplingVersion=VERSION,workers=16,successRate=aggregate['status'].get('success',0)/aggregate['attempts'],validPerLayout=hist_stats(aggregate['validPerLayoutHistogram']),keypointsPerSuccess=hist_stats(aggregate['keypointHistogram']),sourcePointsPerSuccess=hist_stats(aggregate['sourcePointHistogram']),compressedResultBytes=compressed,elapsedComputeAndWriteSeconds=run['elapsedComputeAndWriteSeconds'],elapsedIncludingStartupSeconds=run['elapsedIncludingStartupSeconds'],elapsedAuditSeconds=time.monotonic()-started,independentCompressionFixtures=fixtures,independentMaxDeviationMeters=largest,completedAt=time.time(),memory=read(OUT/'memory.json'))
common.write(OUT/'summary.json',aggregate);common.write(OUT/'progress.json',aggregate);print('AUDIT_PASSED',aggregate['attempts'],flush=True)
