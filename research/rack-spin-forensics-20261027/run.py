from pathlib import Path
import json,gzip,sys,subprocess,hashlib,importlib.util
import build
ROOT,OUT=build.ROOT,build.OUT
sys.path.insert(0,str(ROOT/'research/multi-ball-full-20261026'))
spec=importlib.util.spec_from_file_location('worker',ROOT/'research/multi-ball-full-20261026/run.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
def write(n,v):(OUT/n).write_text(json.dumps(v,indent=2))
def main(uid):
 binary=build.build();success=False;boot=False;n=0
 try:
  subprocess.run(['xcrun','simctl','boot',uid],capture_output=True,check=True);boot=True;subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],capture_output=True,check=True)
  folder=OUT/'worker';folder.mkdir();w=mod.Worker(uid,binary,folder)
  try:
   assert w.ready['defaultBreakVelocity']==10;write('metadata.json',w.ready)
   with gzip.open(OUT/'raw.jsonl.gz','wt') as out:
    old=json.loads((OUT/'frames.json').read_text())
    new=w.run(old['input'])
    for field in ['rack','status','termination','pocketed','board','contacts','duration','frames','initialCueVelocity']:
     assert new[field]==old[field],field
    assert new['status']=='settled';n+=1;out.write(json.dumps(new)+'\n')
   assert n==1
  finally:code=w.close();write('worker-closure.json',dict(exitCode=code));assert code==0
  binding=json.loads((OUT/'source-binding.json').read_text());assert all(build.sha(ROOT/r['path'])==r['sha256'] for r in binding['production'])
  success=True
 finally:
  shut=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True) if boot else None
  write('closure.json',dict(success=success,matched=n,shutdownExitCode=None if shut is None else shut.returncode))
if __name__=='__main__':main(sys.argv[1])
