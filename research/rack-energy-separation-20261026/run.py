from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import importlib.util,sys,json,gzip,random,subprocess,os,time,threading,traceback
import build
ROOT,OUT=build.ROOT,build.OUT
sys.path.insert(0,str(ROOT/'research/multi-ball-full-20261026'))
spec=importlib.util.spec_from_file_location('old_worker',ROOT/'research/multi-ball-full-20261026/run.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
LOCK=threading.Lock();counts={};STOP=threading.Event()
def write(name,value):
 p=OUT/name;t=p.with_suffix(p.suffix+'.partial');t.write_text(json.dumps(value,ensure_ascii=False,indent=2,allow_nan=False));t.replace(p)
def main(uid):
 assert not list(OUT.glob('raw-*.gz'))
 protocol=json.loads((OUT/'protocol.json').read_text());binary=build.build();boot=False;success=False;closures=[]
 write('run-start.json',dict(device=uid,work=os.environ['QIUJI_TEST_WORK'],evidence=os.environ['QIUJI_TEST_EVIDENCE'],protocolSHA=build.sha(OUT/'protocol.json')))
 def inp(r,v):return dict(id=f"{r['rackID']}-{v}",n=15,seed=r['seed'],rackID=r['rackID'],split='fresh',position='center',x=meta['length']/4,z=0,power=9.75,variant=v)
 try:
  subprocess.run(['xcrun','simctl','boot',uid],capture_output=True,check=True);boot=True;subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],capture_output=True,check=True)
  folder=OUT/'preflight';folder.mkdir();w=mod.Worker(uid,binary,folder)
  try:
   meta=w.ready;write('metadata.json',meta);audit=[]
   for old in json.loads((ROOT/'output/rack-center-order-control-20261026/raw.json').read_text()):
    if old['input']['reverseRegistration']:continue
    new=w.run(inp(old['input'],'baseline'));audit.append(new)
    for field in ['rack','cue','power','direction','status','termination','pocketed','board','samples','contacts']:
     assert old[field]==new[field],(old['input']['id'],field)
   write('preflight/baseline-audit.json',audit)
   pilot=[w.run(inp(r,v)) for r in protocol['racks'][:2] for v in protocol['variants']]
   write('preflight/pilot.json',pilot)
   assert all(r['status'] in ['settled','incomplete'] for r in pilot)
  finally:
   code=w.close();write('preflight/closure.json',dict(exitCode=code));assert code==0
  jobs=[inp(r,v) for r in protocol['racks'] for v in protocol['variants']]
  random.Random(202610260702).shuffle(jobs);write('inputs.json',jobs)
  def part(k):
   folder=OUT/f'worker-{k}';folder.mkdir();w=mod.Worker(uid,binary,folder);n=0;first=[]
   try:
    with gzip.open(OUT/f'raw-{k}.jsonl.gz','xt',compresslevel=3) as f:
     for job in jobs[k::protocol['workers']]:
      if STOP.is_set():raise RuntimeError('Another worker failed')
      row=w.run(job);assert row['input']==job
      f.write(json.dumps(row,separators=(',',':'),allow_nan=False)+'\n');f.flush();n+=1
      if n<=3:first.append(row)
      if n%20==0:
       with LOCK:counts[k]=n;write('progress.json',dict(done=sum(counts.values()),total=len(jobs)))
      if n%100==0:print(f'worker{k} {n}/{len(jobs)//4}',flush=True)
    replay=[]
    for old in first:
     new=w.run(old['input'])
     for field in ['rack','board','status','samples','impulseTrace']:assert old[field]==new[field],field
     replay.append(dict(id=old['input']['id'],passed=True))
    write(f'worker-{k}/replays.json',replay)
   except BaseException:STOP.set();raise
   finally:
    code=w.close();closure=dict(worker=k,count=n,exitCode=code);write(f'worker-{k}/closure.json',closure)
    with LOCK:closures.append(closure)
   assert code==0
  with ThreadPoolExecutor(max_workers=4) as pool:
   fs=[pool.submit(part,k) for k in range(4)]
   for f in fs:f.result()
  binding=json.loads((OUT/'source-binding.json').read_text());drift=[x['path'] for x in binding['production'] if build.sha(ROOT/x['path'])!=x['sha256']]
  write('generation.json',dict(count=sum(c['count'] for c in closures),productionDrift=drift));assert not drift
  success=True
 finally:
  shut=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True) if boot else None
  write('closure.json',dict(success=success,workers=closures,shutdownExitCode=None if shut is None else shut.returncode))
if __name__=='__main__':
 try:main(sys.argv[1])
 except BaseException:write('error.json',dict(traceback=traceback.format_exc()));raise
