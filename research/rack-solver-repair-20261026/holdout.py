import json,gzip,sys,subprocess,importlib.util,random
import build
ROOT=build.ROOT;OUT=build.OUT/sys.argv[2];OUT.mkdir(exist_ok=True);build.OUT=OUT
sys.path.insert(0,str(ROOT/'research/multi-ball-full-20261026'))
spec=importlib.util.spec_from_file_location('worker',ROOT/'research/multi-ball-full-20261026/run.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
def write(n,v):(OUT/n).write_text(json.dumps(v,indent=2))
def main(uid):
 allrefs=[]
 for file in sorted((ROOT/'output/rack-power-sweep-20261026/sweep').glob('raw*.gz')):
  for line in gzip.open(file,'rt'):
   r=json.loads(line)
   if r['power']==10 and 11400<=r['input']['rackID']<11500:allrefs.append(r)
 refs=sorted(allrefs,key=lambda r:r['input']['rackID']);assert len(refs)==100
 oldmap={(r['input']['rackID'],'original'):r for r in refs}
 binary=build.build();success=False;boot=False;n=0
 try:
  subprocess.run(['xcrun','simctl','boot',uid],capture_output=True,check=True);boot=True;subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],capture_output=True,check=True)
  folder=OUT/'worker';folder.mkdir();w=mod.Worker(uid,binary,folder)
  try:
   write('metadata.json',w.ready)
   with gzip.open(OUT/'raw.jsonl.gz','wt') as out:
    for old in refs:
     cases=[(0,'original')]+[(2,c) for c in ['original','reverse','mirror','shuffle']]
     for mode,condition in cases:
      inp=dict(old['input'],mode=mode,mirror=condition=='mirror',reverse=condition=='reverse',condition=condition)
      if condition=='shuffle':p=list(range(15));random.Random(old['input']['rackID']).shuffle(p);inp['permutation']=p
      v=old['initialCueVelocity'][:]
      if inp['mirror']:v[2]*=-1
      inp['exactCueVelocity']=v
      r=w.run(inp)
      if mode==0:
       prev=oldmap[inp['rackID'],condition]
       for field in ['board','samples','contacts','duration','status']:assert r[field]==prev[field],(inp['id'],field)
      out.write(json.dumps(r)+'\n');out.flush();n+=1
     print('finished rack',old['input']['rackID'],'runs',n,flush=True)
  finally:code=w.close();write('worker-closure.json',dict(exitCode=code));assert code==0
  binding=json.loads((OUT/'source-binding.json').read_text());assert all(build.sha(ROOT/r['path'])==r['sha256'] for r in binding['production'])
  success=True
 finally:
  shut=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True) if boot else None
  write('closure.json',dict(success=success,total=n,shutdownExitCode=None if shut is None else shut.returncode))
if __name__=='__main__':main(sys.argv[1])
