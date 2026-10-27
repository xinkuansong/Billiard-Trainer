from pathlib import Path
import json,gzip,sys,subprocess,importlib.util,hashlib,random,os
import build
R,O=build.ROOT,build.OUT
sys.path.insert(0,str(R/'research/multi-ball-full-20261026'))
spec=importlib.util.spec_from_file_location('worker',R/'research/multi-ball-full-20261026/run.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
def write(n,v):(O/n).write_text(json.dumps(v,indent=2))
def main(uid):
 refs={int(k):v for k,v in json.load(open(R/'output/rack-contact-tolerance-20261027/reference-inputs.json')).items()}
 oldrepair={}
 for line in gzip.open(R/'output/rack-fixed-physics-20261027/full/raw.jsonl.gz','rt'):
  r=json.loads(line)
  if r['input']['experiment']=='baseline':oldrepair[r['input']['rackID']]={k:r[k] for k in ['board','contacts','duration','spinTail','pocketed','status']}
 ids=list(range(11300,11500))+list(range(21300,21500));checks=list(range(11300,11400))+list(range(21300,21400));inputs={}
 for rid in ids:
  if rid in refs:inp=dict(refs[rid]['input'])
  else:inp=dict(n=15,seed=str(int.from_bytes(hashlib.sha256(f'contact-repair-independent-20261027:{rid}'.encode()).digest()[:8],'big')),rackID=rid,id=f'holdout-{rid}',x=2.5399999618530273/4,z=0,power=10)
  inp.update(mirror=False,reverse=False,condition='original',mode=0,toleranceM=.00025,experiment='production',diagnostic=False)
  inputs[rid]=inp
 write('design.json',dict(ids=ids,independentIDs=list(range(21300,21500)),invarianceIDs=checks,mainRuns=800,invarianceRuns=600,diagnosticRuns=2,parameters='frozen production',sameRackSameStrike=True,scoreThreshold=1.2))
 write('inputs.json',inputs)
 parentWork=Path(os.environ['QIUJI_TEST_WORK']);candidateHere=build.HERE
 binaries={}
 for label in ['production','repair']:
  work=parentWork/label;work.mkdir();os.environ['QIUJI_TEST_WORK']=str(work)
  build.HERE=candidateHere/'control' if label=='production' else candidateHere
  binaries[label]=build.build()
  (O/'source-binding.json').rename(O/(label+'-source-binding.json'))
  evidence=Path(os.environ['QIUJI_TEST_EVIDENCE'])
  for name in ['build.log','commands.json']:(evidence/name).rename(evidence/(label+'-'+name))
 os.environ['QIUJI_TEST_WORK']=str(parentWork);build.HERE=candidateHere
 success=False;boot=False;n=0;baseMatches=0;repairMatches=0;params=None;history=[]
 try:
  subprocess.run(['xcrun','simctl','boot',uid],capture_output=True,check=True);boot=True;subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],capture_output=True,check=True)
  workers={}
  for label,binary in binaries.items():
   folder=O/('worker-'+label);folder.mkdir();workers[label]=mod.Worker(uid,binary,folder)
  try:
   write('metadata.json',{k:w.ready for k,w in workers.items()});assert all(w.ready['defaultBreakVelocity']==10 for w in workers.values())
   with gzip.open(O/'raw.jsonl.gz','wt',compresslevel=3) as out:
    for mode in [0,2]:
     inp=dict(inputs[11304],mode=mode,toleranceM=.0001,experiment='diagnostic',diagnostic=True)
     r=workers['production' if mode==0 else 'repair'].run(inp);out.write(json.dumps(r,separators=(',',':'))+'\n');out.flush();n+=1
    orderedIDs=[21300]+[i for i in ids if i!=21300]
    for idx,rid in enumerate(orderedIDs):
     # Production is needed once to freeze the actual initial velocity in new independent samples.
     modes=[0,2] if idx%2==0 or rid not in refs else [2,0];base=None;repair=None
     for mode in modes:
      inp=dict(inputs[rid],mode=mode,experiment='production' if mode==0 else 'repair')
      if base is not None:inp['exactCueVelocity']=base['initialCueVelocity']
      r=workers['production' if mode==0 else 'repair'].run(inp)
      assert r['backend']==inp['experiment']
      if params is None:params=r['parameters']
      assert r['parameters']==params
      if mode==0:
       base=r
       if rid in refs:
        mismatches=[field for field in ['rack','board','contacts','duration','status','termination','initialCueVelocity','spinTail','pocketed'] if r[field]!=refs[rid][field]]
        history.append(dict(id=rid,label='production',differentFields=mismatches));baseMatches+=not mismatches
      else:
       repair=r
       if rid in oldrepair:
        mismatches=[field for field in oldrepair[rid] if r[field]!=oldrepair[rid][field]]
        history.append(dict(id=rid,label='repair',differentFields=mismatches));repairMatches+=not mismatches
      out.write(json.dumps(r,separators=(',',':'),allow_nan=False)+'\n');out.flush();n+=1
     assert base['initialCueVelocity']==repair['initialCueVelocity'] and base['rack']==repair['rack']
     if rid in checks:
      for condition in ['reverse','shuffle','mirror']:
       inp=dict(inputs[rid],mode=2,condition=condition,experiment='repair',exactCueVelocity=base['initialCueVelocity'])
       if condition=='reverse':inp['reverse']=True
       if condition=='shuffle':perm=list(range(15));random.Random(rid+20261027).shuffle(perm);inp['permutation']=perm
       if condition=='mirror':inp['mirror']=True;inp['exactCueVelocity']=[base['initialCueVelocity'][0],base['initialCueVelocity'][1],-base['initialCueVelocity'][2]]
       r=workers['repair'].run(inp);assert r['parameters']==params and r['backend']=='repair'
       out.write(json.dumps(r,separators=(',',':'),allow_nan=False)+'\n');out.flush();n+=1
     write('progress.json',dict(rack=rid,runs=n,baselineMatches=baseMatches,oldRepairMatches=repairMatches))
     if idx%20==0:print('rack',rid,'runs',n,flush=True)
   assert n==1402
   write('historical-comparison.json',history)
  finally:
   codes={k:w.close() for k,w in workers.items()};write('worker-closure.json',codes);assert all(c==0 for c in codes.values())
  before=json.load(open(O/'production-before.json'));assert all(hashlib.sha256((R/p).read_bytes()).hexdigest()==h for p,h in before.items())
  success=True
 finally:
  shut=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True) if boot else None
  write('closure.json',dict(success=success,total=n,baselineMatches=baseMatches,oldRepairMatches=repairMatches,shutdownExitCode=None if shut is None else shut.returncode))
if __name__=='__main__':main(sys.argv[1])
