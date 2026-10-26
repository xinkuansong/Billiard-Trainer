import json,gzip,sys,subprocess,importlib.util,random,math
import build
ROOT=build.ROOT;OUT=build.OUT/sys.argv[2];OUT.mkdir(parents=True,exist_ok=True);build.OUT=OUT
sys.path.insert(0,str(ROOT/'research/multi-ball-full-20261026'))
spec=importlib.util.spec_from_file_location('worker',ROOT/'research/multi-ball-full-20261026/run.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
def write(n,v):(OUT/n).write_text(json.dumps(v,indent=2))
variants=[(pattern+'__'+str(alpha),2,'han',.14,alpha) for pattern in ['current','independent','inward','sideP60','sideM120','outward'] for alpha in [10.9,22]]
def main(uid):
 refs=[]
 for phase in ['pilot-r2','holdout']:
  for l in gzip.open(ROOT/'output/rack-spin-experiments-20261026'/('sweep-r2' if phase=='pilot-r2' else 'holdout')/'raw.jsonl.gz','rt'):
   r=json.loads(l)
   if r['input']['condition']=='original' and r['input']['experiment'] in ['han14','han14_spin22']:refs.append(r)
 oldmap={(r['input']['rackID'],r['input']['experiment']):r for r in refs}
 ids=list(range(11300,11400)) if sys.argv[2].startswith('sweep') else list(range(11400,11500))
 write('design.json',dict(ids=ids,variants=variants,scoreThreshold=1.2,selection='All fixed IDs; no rejection of bad scores or failures'))
 binary=build.build();success=False;boot=False;n=0
 try:
  subprocess.run(['xcrun','simctl','boot',uid],capture_output=True,check=True);boot=True;subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],capture_output=True,check=True)
  folder=OUT/'worker';folder.mkdir();w=mod.Worker(uid,binary,folder)
  try:
   write('metadata.json',w.ready)
   reference=json.loads((build.HERE/'mathavan-reference.json').read_text());actual=w.ready['cushionProbe']
   delta=max(abs(a-b) for x,y in zip(reference,actual) for a,b in zip(x['output'],y['output']))
   assert len(reference)==len(actual)==100 and delta<1e-9,delta
   write('probe-parity.json',dict(n=100,maxDelta=delta,tolerance=1e-9))
   with gzip.open(OUT/'raw.jsonl.gz','wt') as out:
    for rid in ids:
     old=oldmap[rid,'han14']
     for label,mode,model,mu,alpha in variants:
      inp=dict(old['input'],pattern=label.split('__')[0],mode=mode,mirror=False,reverse=False,condition='original',experiment=label,cushionModel=model,mu=mu,spinScale=alpha/10.9,step=.0001,exactCueVelocity=old['initialCueVelocity'])
      r=w.run(inp)
      if label.startswith('current__'):
       prev=oldmap[rid,'han14' if alpha==10.9 else 'han14_spin22']
       for field in ['board','samples','contacts','spinTail','duration','status']:assert r[field]==prev[field],(rid,label,field)
      out.write(json.dumps(r)+'\n');out.flush();n+=1
     print('finished rack',rid,'runs',n,flush=True)
  finally:code=w.close();write('worker-closure.json',dict(exitCode=code));assert code==0
  binding=json.loads((OUT/'source-binding.json').read_text());assert all(build.sha(ROOT/r['path'])==r['sha256'] for r in binding['production'])
  success=True
 finally:
  shut=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True) if boot else None
  write('closure.json',dict(success=success,total=n,shutdownExitCode=None if shut is None else shut.returncode))
if __name__=='__main__':main(sys.argv[1])
