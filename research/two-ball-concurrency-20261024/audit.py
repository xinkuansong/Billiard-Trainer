from pathlib import Path
import json,gzip,hashlib,collections
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name;BASE=ROOT/'output/two-ball-sample125-once-20261024'
read=lambda p:json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def load(p):
 with gzip.open(p,'rt') as f:return [json.loads(l) for l in f]
def canonical(v):
 if isinstance(v,dict):return {k:canonical(x) for k,x in v.items() if k not in {'elapsedSeconds','initialAimMilliseconds','physicsMilliseconds','extractionCompressionMilliseconds','wallMilliseconds'}}
 if isinstance(v,list):return [canonical(x) for x in v]
 return v
def normalize(r):
 if 'trajectory2mm' not in r:return 0
 t=r['trajectory2mm'];ev=[e for e in r['events'] if e['kind']=='cushion' and e['ball']=='cueBall' and e['time']>=r['firstContactTime']]
 assert len(t['cushions'])==len(ev)
 for c,e in zip(t['cushions'],ev):assert c['time']==e['time'] and c['cushionID']==e.get('cushionID')
 for c,e in zip(t['cushions'],ev):
  if not e['afterFirstContact']:assert c['pointIndex']==0 and c['time']==r['firstContactTime']
 n=sum(not e['afterFirstContact'] for e in ev);t['cushions']=[c for c,e in zip(t['cushions'],ev) if e['afterFirstContact']];return n
summary=[]
for n in (8,12,16):
 p=OUT/f'p{n}';run=read(p/'run-complete.json');mem=read(p/'memory.json');cleanup=read(p/'cleanup.json')
 assert sha(p/'layouts.json')==sha(BASE/'layouts.json')
 assert len(read(p/'workers.json')['pids'])==n
 assert read(p/'workers.json')['binarySHA256']==sha(ROOT/'research/two-ball-sample125-once-20261024/Worker.app/Worker')
 assert cleanup['workerExitCodes']==[0]*n and cleanup['shutdownExitCode']==0
 assert not mem['errors'] and mem['samples']>10
 samples=read(p/'memory-samples.json');assert all(s['nativeProcessesObserved']==n for s in samples)
 counts=collections.Counter();seen=set();changes=0;attempts=0
 for rec in run['receipts']:
  f=p/'parts'/rec['file'];assert sha(f)==rec['sha256']
  actual=load(f);expected=load(BASE/'parts'/rec['file']);assert len(actual)==len(expected)==10
  for a,b in zip(actual,expected):
   assert a['id'] not in seen;seen.add(a['id']);assert len(a['rows'])==125
   assert len({r['comboIndex'] for r in a['rows']})==125
   for r in a['rows']:
    assert r['directionRetries']==0 and r['simulationCalls'] in (0,1)
    changes+=normalize(r);counts[r['status']]+=1;attempts+=1
   assert canonical(a)==canonical(b),f'Physical/parameter/trajectory parity failed: {n} {a["id"]}'
 assert len(seen)==1000 and attempts==125000 and counts['success']==100061 and changes==61
 r=dict(workers=n,computeAndWriteSeconds=run['elapsedComputeAndWriteSeconds'],includingStartupSeconds=run['elapsedIncludingStartupSeconds'],peakRSSGiB=mem['peakTotalRSSBytes']/2**30,peakNativeRSSGiB=mem['peakNativeRSSBytes']/2**30,peakControlRSSGiB=mem['peakControlRSSBytes']/2**30,memorySamples=mem['samples'],maxSampleIntervalSeconds=mem['maxIntervalSeconds'],layouts=len(seen),attempts=attempts,status=dict(counts),compressedBytes=sum(x['bytes'] for x in run['receipts']),physicsAndKeypointsExactlyMatchPilot=True,eventMetadataOrderNormalizedInComparison=changes,fullBankEstimatedHours=run['elapsedComputeAndWriteSeconds']*135.7/3600)
 summary.append(r);print(json.dumps(r),flush=True)
for r in summary:r['speedupVs8']=summary[0]['computeAndWriteSeconds']/r['computeAndWriteSeconds']
(OUT/'summary.json').write_text(json.dumps(dict(state='complete',auditPassed=True,rounds=summary,scope='1000 same layouts,125 same samples,125000 attempts per round; single run each, order8/12/16; identical frozen native binary and physics; zero aim retries; successful 2mm paths',memoryMethod=read(OUT/'p8/memory.json')['method']),ensure_ascii=False,indent=2))
