import json,gzip,sys,subprocess,importlib.util
import build
ROOT,OUT=build.ROOT,build.OUT
sys.path.insert(0,str(ROOT/'research/multi-ball-full-20261026'))
spec=importlib.util.spec_from_file_location('worker',ROOT/'research/multi-ball-full-20261026/run.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
def write(n,v):(OUT/n).write_text(json.dumps(v,indent=2))
def main(uid):
 refs=[json.loads(l) for l in gzip.open(ROOT/'output/rack-solver-invariance-20261026/raw.jsonl.gz','rt')];refs=[r for r in refs if r['input']['condition'] in ['original','reverse']];assert len(refs)==200
 binary=build.build();success=False;boot=False;n=0
 try:
  subprocess.run(['xcrun','simctl','boot',uid],capture_output=True,check=True);boot=True;subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],capture_output=True,check=True)
  folder=OUT/'worker';folder.mkdir();w=mod.Worker(uid,binary,folder)
  try:
   write('metadata.json',w.ready)
   with gzip.open(OUT/'raw.jsonl.gz','wt') as out:
    for old in refs:
     # First six controls prove the override path is inert for the original velocity.
     if old['input']['rackID']<11303:
      inp=dict(old['input'],exactCueVelocity=old['initialCueVelocity']);r=w.run(inp)
      for field in ['board','samples','contacts','pairTrace','spinTail','duration','status']:assert r[field]==old[field],(inp['id'],field)
     velocity=old['initialCueVelocity'][:];velocity[2]*=-1
     inp=dict(old['input'],mirror=True,condition='mirror_'+old['input']['condition']+'_exact',exactCueVelocity=velocity)
     r=w.run(inp);assert r['initialCueVelocity']==velocity
     out.write(json.dumps(r)+'\n');n+=1
     if n%40==0:print('exact mirrors',n,'/200',flush=True)
  finally:code=w.close();write('worker-closure.json',dict(exitCode=code));assert code==0
  binding=json.loads((OUT/'source-binding.json').read_text());assert all(build.sha(ROOT/r['path'])==r['sha256'] for r in binding['production'])
  success=True
 finally:
  shut=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True) if boot else None
  write('closure.json',dict(success=success,total=n,overrideControls=6,shutdownExitCode=None if shut is None else shut.returncode))
if __name__=='__main__':main(sys.argv[1])
