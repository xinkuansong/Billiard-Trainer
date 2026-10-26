import json,gzip,sys,subprocess,importlib.util
from pathlib import Path
import build
ROOT=build.ROOT;OUT=build.OUT/'invariance';OUT.mkdir(parents=True,exist_ok=True);build.OUT=OUT
sys.path.insert(0,str(ROOT/'research/multi-ball-full-20261026'))
spec=importlib.util.spec_from_file_location('worker',ROOT/'research/multi-ball-full-20261026/run.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
def write(n,v):(OUT/n).write_text(json.dumps(v,indent=2))
def main(uid):
 refs=[json.loads(l) for l in gzip.open(OUT.parent/'full/raw.jsonl.gz','rt')]
 refs=[r for r in refs if r['input']['rackID']<11320 and r['input']['experiment'] in ['support','combined']]
 write('design.json',dict(ids=list(range(11300,11320)),variants=['support','combined'],conditions=['original','reverse','mirror'],fixtureTolerance=1e-9,earlyTolerance='exact',boardToleranceM=1e-6))
 binary=build.build();success=False;boot=False;n=0
 try:
  subprocess.run(['xcrun','simctl','boot',uid],capture_output=True,check=True);boot=True;subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],capture_output=True,check=True)
  folder=OUT/'worker';folder.mkdir();w=mod.Worker(uid,binary,folder)
  try:
   write('metadata.json',w.ready)
   assert w.ready['fixedProbe']['passed'],w.ready['fixedProbe']
   with gzip.open(OUT/'raw.jsonl.gz','wt') as out:
    for old in refs:
     for condition in ['original','reverse','mirror']:
      inp=dict(old['input'],condition=condition,reverse=condition=='reverse',mirror=condition=='mirror')
      inp['exactCueVelocity']=old['initialCueVelocity'][:]
      if condition=='mirror':inp['exactCueVelocity'][2]*=-1
      r=w.run(inp)
      if condition=='original':
       for field in ['board','samples','contacts','spinTail','duration','status']:assert r[field]==old[field],(inp,field)
      out.write(json.dumps(r)+'\n');out.flush();n+=1
     print('finished',old['input']['rackID'],old['input']['experiment'],n,flush=True)
  finally:code=w.close();write('worker-closure.json',dict(exitCode=code));assert code==0
  binding=json.loads((OUT/'source-binding.json').read_text());assert all(build.sha(ROOT/r['path'])==r['sha256'] for r in binding['production'])
  success=True
 finally:
  shut=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True) if boot else None
  write('closure.json',dict(success=success,total=n,shutdownExitCode=None if shut is None else shut.returncode))
if __name__=='__main__':main(sys.argv[1])
