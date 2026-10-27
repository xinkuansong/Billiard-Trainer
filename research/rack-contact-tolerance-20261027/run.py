from pathlib import Path
import json,gzip,sys,subprocess,importlib.util,hashlib
import build
R,O=build.ROOT,build.OUT
sys.path.insert(0,str(R/'research/multi-ball-full-20261026'))
spec=importlib.util.spec_from_file_location('worker',R/'research/multi-ball-full-20261026/run.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
def write(n,v):(O/n).write_text(json.dumps(v,indent=2))
def main(uid):
 refs={}
 for line in gzip.open(R/'output/rack-fixed-physics-20261027/full/raw.jsonl.gz','rt'):
  r=json.loads(line)
  if r['input']['experiment']=='production':
   refs[r['input']['rackID']]={k:r[k] for k in ['input','rack','board','contacts','duration','status','termination','initialCueVelocity','spinTail','pocketed']}
 ids=list(range(11300,11500));assert set(refs)==set(ids)
 variants=[.00025,.00010,.00005,.00001]
 write('design.json',dict(ids=ids,tolerancesM=variants,reverseIDs=ids[:40],runs=960,oneChangedPhysicsDecision='EngineNumerics.isBallPairOverlappingOrTouching eps',registrationOrder='original for main comparison; reverse is separate diagnostic',maxTime=30,maxEvents=8000,selection='all IDs and failures retained',cpu='same read-only observer; excludes serialization and postprocessing; simulator CPU not device performance'))
 write('reference-inputs.json',refs)
 binary=build.build();success=False;boot=False;n=0;matched=0
 try:
  subprocess.run(['xcrun','simctl','boot',uid],capture_output=True,check=True);boot=True
  subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],capture_output=True,check=True)
  folder=O/'worker';folder.mkdir();w=mod.Worker(uid,binary,folder)
  try:
   assert w.ready['defaultBreakVelocity']==10;write('metadata.json',w.ready)
   with gzip.open(O/'raw.jsonl.gz','wt',compresslevel=3) as out:
    # Reference first; then balanced cyclic order within paired rack.
    for idx,rid in enumerate(ids):
     old=refs[rid]
     sequence=variants[idx%4:]+variants[:idx%4]
     for reverse in ([False,True] if rid in ids[:40] else [False]):
      for eps in sequence:
       inp=dict(old['input'],toleranceM=eps,reverse=reverse,condition='reverse' if reverse else 'original',experiment='tolerance-only')
       row=w.run(inp)
       assert row['power']==10 and row['initialCueVelocity']==old['initialCueVelocity']
       assert sorted(row['rack'],key=lambda b:b['number'])==sorted(old['rack'],key=lambda b:b['number'])
       if not reverse and eps==.00025:
        for field in ['rack','board','contacts','duration','status','termination','initialCueVelocity','spinTail','pocketed']:
         assert row[field]==old[field],(rid,field)
        if rid==11331:
         oldframes=json.load(open(R/'output/rack-spin-forensics-20261027/frames.json'))
         assert row['frames']==oldframes['frames']
        matched+=1
       out.write(json.dumps(row,separators=(',',':'),allow_nan=False)+'\n');out.flush();n+=1
     write('progress.json',dict(rack=rid,runs=n,baselineMatches=matched))
     print('rack',rid,'runs',n,'baselineMatches',matched,flush=True)
   assert n==960 and matched==200
  finally:
   code=w.close();write('worker-closure.json',dict(exitCode=code));assert code==0
  before=json.load(open(O/'production-before.json'))
  assert all(hashlib.sha256((R/p).read_bytes()).hexdigest()==h for p,h in before.items())
  success=True
 finally:
  shut=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True) if boot else None
  write('closure.json',dict(success=success,total=n,baselineMatches=matched,shutdownExitCode=None if shut is None else shut.returncode))
if __name__=='__main__':main(sys.argv[1])
