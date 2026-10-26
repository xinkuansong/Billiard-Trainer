"""Replay every accepted chain from initial state; capture physical-only plotting evidence."""
import gzip,json,os,subprocess,sys,time,traceback
from pathlib import Path
import experiment as E
import run as R
OUT=E.OUT/'all-chain-replay';OUT.mkdir(exist_ok=True)
def main(uid):
 assert not (OUT/'raw.jsonl.gz').exists();os.environ['THREE_BALL_BUILD_OUTPUT']=str(OUT)
 p=subprocess.run(['make','-C',str(E.HERE),'build'],capture_output=True,text=True);(OUT/'build-launch.log').write_text(p.stdout+p.stderr)
 if p.returncode:raise RuntimeError(p.stdout+p.stderr)
 R.OUT=OUT;boot=False;w=None;done=[];success=False;t=time.monotonic()
 try:
  subprocess.run(['xcrun','simctl','boot',uid],check=True,capture_output=True);boot=True;subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True,capture_output=True)
  w=R.Worker(uid,Path(os.environ['QIUJI_TEST_WORK'])/'ThreeBallWorker.app/Worker')
  with gzip.open(OUT/'chains.jsonl.gz','wt',compresslevel=6) as f:
   for i in range(1,6):
    data=E.read(E.OUT/f'sample-{i}.json')
    for c in data['candidates']:
     for j,chain in enumerate(c['chains']):
      last=None;shots=[]
      for k,shot in enumerate(chain['shots']):
       q=dict(shot['request'],id=f'all-{i}-{c["id"]}-{j}-{k}')
       if last:
        q['cue']=last['stop'];q['object']=last['finals']['obstacle0']
        if k==1:q['obstacles']=[last['finals']['obstacle1']]
       r=w.run(q,'full_chain_physical_paths');assert r['success'],q['id']
       for field in ['stop','rails','events','finals','cuePath','targetPath']:assert r[field]==shot['result'][field],(q['id'],field)
       assert r['physicalPaths']['cueBall'] and r['physicalPaths']['object']
       pocketTime=next(e['time'] for e in r['events'] if e['kind']=='pocket' and e['ball']=='object')
       assert r['physicalPaths']['object'][-1][0]<=pocketTime+1e-6
       shots.append(dict(request=q,result=r));last=r
      entry=dict(sample=i,candidate=c['id'],chain=j,shots=shots);f.write(json.dumps(entry,separators=(',',':'))+'\n');done.append([i,c['id'],j])
    print('REPLAY_SAMPLE',i,'chains',len(done),flush=True)
  assert len(done)==E.read(E.OUT/'generation.json')['chains']
  binding=E.read(OUT/'source-binding.json');assert all(E.sha(E.ROOT/x['path'])==x['sha256'] for x in binding['production'])
  E.write(OUT/'audit.json',dict(passed=True,chains=len(done),shots=w.count,seconds=time.monotonic()-t,allStopsEventsRailsFinalsExact=True,actualRemainingStatesInherited=True,physicalObjectPathsEndAtPocketEntry=True,chainsSHA=E.sha(OUT/'chains.jsonl.gz'),work=os.environ['QIUJI_TEST_WORK'],evidence=os.environ['QIUJI_TEST_EVIDENCE']))
  success=True
 finally:
  code=w.close() if w else None;shut=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True,text=True) if boot else None
  E.write(OUT/'closure.json',dict(success=success,nativeExitCode=code,nativePID=w.ready['pid'] if w else None,shutdownExitCode=shut.returncode if shut else None,device=uid))
  if code is not None:assert code==0
  if shut:assert shut.returncode==0
if __name__=='__main__':
 try:main(sys.argv[1])
 except BaseException:E.write(OUT/'error.json',dict(traceback=traceback.format_exc()));raise
