import json,gzip,sys,subprocess,importlib.util,random
import build
ROOT=build.ROOT;OUT=build.OUT/sys.argv[2];OUT.mkdir(exist_ok=True);build.OUT=OUT
sys.path.insert(0,str(ROOT/'research/multi-ball-full-20261026'))
spec=importlib.util.spec_from_file_location('worker',ROOT/'research/multi-ball-full-20261026/run.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
def write(n,v):(OUT/n).write_text(json.dumps(v,indent=2))
def main(uid):
 allrefs=[json.loads(l) for l in gzip.open(ROOT/'output/rack-solver-invariance-20261026/raw.jsonl.gz','rt')]
 refs=[r for r in allrefs if r['input']['condition']=='original' and (sys.argv[2]!='pilot' or r['input']['rackID'] in list(range(11300,11310))+[11331,11399])]
 oldmap={(r['input']['rackID'],r['input']['condition']):r for r in allrefs}
 binary=build.build();success=False;boot=False;n=0
 try:
  subprocess.run(['xcrun','simctl','boot',uid],capture_output=True,check=True);boot=True;subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],capture_output=True,check=True)
  folder=OUT/'worker';folder.mkdir();w=mod.Worker(uid,binary,folder)
  try:
   write('metadata.json',w.ready)
   with gzip.open(OUT/'raw.jsonl.gz','wt') as out:
    for old in refs:
     cases=[(m,c) for m in [0,1,2] for c in ['original','reverse']]+[(2,'mirror'),(2,'shuffle')]
     for mode,condition in cases:
      inp=dict(old['input'],mode=mode,mirror=condition=='mirror',reverse=condition=='reverse',condition=condition)
      if condition=='shuffle':p=list(range(15));random.Random(old['input']['rackID']).shuffle(p);inp['permutation']=p
      v=old['initialCueVelocity'][:]
      if inp['mirror']:v[2]*=-1
      inp['exactCueVelocity']=v
      r=w.run(inp)
      if mode==0:
       prev=oldmap[inp['rackID'],condition]
       for field in ['board','samples','contacts','pairTrace','spinTail','duration','status']:assert r[field]==prev[field],(inp['id'],field)
      out.write(json.dumps(r)+'\n');out.flush();n+=1
     print('finished rack',old['input']['rackID'],'runs',n,flush=True)
  finally:code=w.close();write('worker-closure.json',dict(exitCode=code));assert code==0
  binding=json.loads((OUT/'source-binding.json').read_text());assert all(build.sha(ROOT/r['path'])==r['sha256'] for r in binding['production'])
  success=True
 finally:
  shut=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True) if boot else None
  write('closure.json',dict(success=success,total=n,shutdownExitCode=None if shut is None else shut.returncode))
if __name__=='__main__':main(sys.argv[1])
