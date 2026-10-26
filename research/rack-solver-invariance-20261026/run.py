import json,gzip,sys,subprocess,importlib.util
import build
ROOT,OUT=build.ROOT,build.OUT
sys.path.insert(0,str(ROOT/'research/multi-ball-full-20261026'))
spec=importlib.util.spec_from_file_location('worker',ROOT/'research/multi-ball-full-20261026/run.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
def write(n,v):(OUT/n).write_text(json.dumps(v,indent=2))
def main(uid):
 refs=[]
 for file in sorted((ROOT/'output/rack-power-sweep-20261026/sweep').glob('raw*.gz')):
  for line in gzip.open(file,'rt'):
   r=json.loads(line)
   if r['power']==10 and 11300<=r['input']['rackID']<11400:refs.append(r)
 refs.sort(key=lambda r:r['input']['rackID']);assert len(refs)==100
 write('protocol.json',dict(samples=100,variants=['original','reverse','mirror','mirror_reverse'],power=10,rackIDs=[11300,11399],traceWindow=.020001,productionChanges=False,earlyPositionToleranceM=1e-6,earlyVelocityToleranceMPS=1e-4,earlyOmegaToleranceRadPS=.01,boardToleranceM=.001))
 binary=build.build();success=False;boot=False;n=0;replays=0
 try:
  subprocess.run(['xcrun','simctl','boot',uid],capture_output=True,check=True);boot=True;subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],capture_output=True,check=True)
  folder=OUT/'worker';folder.mkdir();w=mod.Worker(uid,binary,folder)
  try:
   write('metadata.json',w.ready);repeat=[]
   with gzip.open(OUT/'raw.jsonl.gz','wt') as out:
    for old in refs:
     for mirror,reverse,label in [(False,False,'original'),(False,True,'reverse'),(True,False,'mirror'),(True,True,'mirror_reverse')]:
      inp=dict(old['input'],mirror=mirror,reverse=reverse,condition=label)
      r=w.run(inp)
      if label=='original':
       for field in ['rack','cue','power','direction','spin','status','termination','pocketed','board','samples','contacts','duration','initialCueVelocity']:
        assert r[field]==old[field],(inp['id'],field)
       replays+=1
      if old['input']['rackID']<11303:repeat.append((inp,r))
      out.write(json.dumps(r)+'\n');n+=1
     if n%40==0:print('completed',n,'/400',flush=True)
   for inp,r in repeat:
    q=w.run(inp)
    for field in ['pairTrace','samples','contacts','board','duration','spinTail','status']:assert q[field]==r[field],(inp['id'],inp['condition'],field)
   write('repeat-verification.json',dict(exactRuns=len(repeat)))
  finally:code=w.close();write('worker-closure.json',dict(exitCode=code));assert code==0
  binding=json.loads((OUT/'source-binding.json').read_text());assert all(build.sha(ROOT/r['path'])==r['sha256'] for r in binding['production'])
  success=True
 finally:
  shut=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True) if boot else None
  write('closure.json',dict(success=success,total=n,baselineReplays=replays,shutdownExitCode=None if shut is None else shut.returncode))
if __name__=='__main__':main(sys.argv[1])
