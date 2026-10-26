from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import importlib.util,json,random,subprocess,time,threading,os,hashlib,traceback
import build as builder
ROOT,HERE,OUT=builder.ROOT,builder.HERE,builder.OUT
spec=importlib.util.spec_from_file_location('existing_worker',ROOT/'research/multi-ball-full-20261026/run.py')
# Reuse only the audited native process protocol, not its bank generator or admission policy.
import sys
sys.path.insert(0,str(ROOT/'research/multi-ball-full-20261026'))
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
Worker=mod.Worker
LOCK=threading.Lock(); COUNTS={};STOP=threading.Event()
def write(p,x):
 p=Path(p);tmp=p.with_suffix(p.suffix+'.partial');tmp.write_text(json.dumps(x,ensure_ascii=False,indent=2,allow_nan=False));tmp.replace(p)
def main(uid):
 assert not list(OUT.glob('raw-*.jsonl')),'Never overwrite prior observations'
 protocol=json.loads((OUT/'protocol.json').read_text());racks=json.loads((OUT/'racks.json').read_text())
 binary=builder.build();binding=json.loads((OUT/'source-binding.json').read_text())
 write(OUT/'run-start.json',dict(device=uid,pid=os.getpid(),startedAt=time.time(),work=os.environ['QIUJI_TEST_WORK'],evidence=os.environ['QIUJI_TEST_EVIDENCE'],protocolSHA=builder.sha(OUT/'protocol.json'),entrySHA=builder.sha(HERE/'main.swift')))
 boot=False;success=False;closures=[]
 try:
  subprocess.run(['xcrun','simctl','boot',uid],check=True,capture_output=True);boot=True
  subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True,capture_output=True)
  folder=OUT/'preflight';folder.mkdir(); w=Worker(uid,binary,folder)
  try:
   meta=w.ready;write(OUT/'metadata.json',meta)
   cal=json.loads((OUT/'calibration.json').read_text());assert all(meta[k]==cal['domain'][k] for k in ['length','width','radius'])
   def job(r,pos):
    return dict(id=f"rack-{r['rackID']:04}-{pos['name']}",n=15,seed=r['seed'],rackID=r['rackID'],split=r['split'],position=pos['name'],x=meta['length']*pos['xFraction'],z=meta['width']*pos['zFraction'],power=protocol['power'])
   jobs=[job(r,p) for r in racks for p in protocol['positions']]
   random.Random(202610260503).shuffle(jobs);write(OUT/'inputs.json',jobs)
   pre=[]
   for pos in protocol['positions']:
    row=w.run(job(racks[0],pos));assert row['status']=='settled',row;pre.append(row)
   assert all(x['rack']==pre[0]['rack'] for x in pre)
   write(folder/'results.json',pre)
  finally:
   code=w.close();write(folder/'closure.json',dict(exitCode=code));assert code==0
  def part(k):
   folder=OUT/f'worker-{k}';folder.mkdir();w=Worker(uid,binary,folder);write(folder/'metadata.json',w.ready)
   rows=[];replays=[];started=time.monotonic()
   try:
    with (OUT/f'raw-{k}.jsonl').open('x') as f:
     for inp in jobs[k::protocol['compute']['workers']]:
      if STOP.is_set():raise RuntimeError('Another worker failed')
      row=w.run(inp);assert row['input']==inp
      f.write(json.dumps(row,separators=(',',':'),allow_nan=False)+'\n');f.flush();rows.append(row)
      if len(rows)%25==0:
       with LOCK:
        COUNTS[k]=len(rows);write(OUT/'progress.json',dict(done=sum(COUNTS.values()),total=5000,workers=COUNTS,updatedAt=time.time()))
       if len(rows)%250==0:print(f'worker{k} {len(rows)}/1250',flush=True)
    # Five same-input replays per worker are validation extras, not main observations.
    for old in rows[:5]:
     new=w.run(old['input'])
     for field in ['rack','cue','power','direction','status','termination','pocketed','board']:
      assert old.get(field)==new.get(field),(old['input']['id'],field)
     replays.append(dict(id=old['input']['id'],passed=True))
    write(folder/'replays.json',replays)
   except BaseException:
    STOP.set();raise
   finally:
    code=w.close();closure=dict(worker=k,nativePID=w.ready['pid'],wrapperPID=w.p.pid,exitCode=code,rows=len(rows),seconds=time.monotonic()-started)
    write(folder/'closure.json',closure)
    with LOCK:closures.append(closure)
    assert code==0,code
   return dict(worker=k,count=len(rows),sha256=builder.sha(OUT/f'raw-{k}.jsonl'),replays=len(replays))
  with ThreadPoolExecutor(max_workers=4) as pool:
   futures=[pool.submit(part,k) for k in range(4)];parts=[f.result() for f in futures]
  assert sum(p['count'] for p in parts)==5000
  drift=[x['path'] for x in binding['production'] if builder.sha(ROOT/x['path'])!=x['sha256']]
  write(OUT/'generation.json',dict(complete=True,count=5000,parts=parts,productionBindingDrift=drift,finishedAt=time.time()))
  if drift:raise RuntimeError(f'Physics/Rack drift {drift}')
  success=True
 finally:
  shutdown=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True,text=True) if boot else None
  write(OUT/'closure.json',dict(generationSucceeded=success,workers=closures,shutdownExitCode=None if shutdown is None else shutdown.returncode))
  if shutdown is not None and shutdown.returncode:raise RuntimeError(shutdown.stderr)
if __name__=='__main__':
 try:main(sys.argv[1])
 except BaseException:
  write(OUT/'error.json',dict(traceback=traceback.format_exc()));raise
