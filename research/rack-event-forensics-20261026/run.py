from pathlib import Path
import importlib.util,sys,json,gzip,subprocess,os,traceback
import build
ROOT,OUT=build.ROOT,build.OUT
sys.path.insert(0,str(ROOT/'research/multi-ball-full-20261026'))
spec=importlib.util.spec_from_file_location('old_worker',ROOT/'research/multi-ball-full-20261026/run.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
def write(n,x):(OUT/n).write_text(json.dumps(x,indent=2))
def main(uid):
 protocol=json.loads((OUT/'protocol.json').read_text());ids={r['rackID'] for r in protocol['racks']};old={}
 for p in (ROOT/'output/rack-contact-factorial-20261026').glob('raw-*.gz'):
  with gzip.open(p,'rt') as f:
   for l in f:
    r=json.loads(l);i=r['input']
    if i['rackID'] in ids and any(all(i[k]==v[k] for k in v) for v in protocol['variants']):old[i['id']]=r
 assert len(old)==12
 binary=build.build();w=None;boot=False;success=False;replays=[]
 write('run-start.json',dict(device=uid,work=os.environ['QIUJI_TEST_WORK'],evidence=os.environ['QIUJI_TEST_EVIDENCE']))
 try:
  subprocess.run(['xcrun','simctl','boot',uid],capture_output=True,check=True);boot=True;subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],capture_output=True,check=True)
  w=mod.Worker(uid,binary,OUT);write('metadata.json',w.ready)
  with gzip.open(OUT/'raw.jsonl.gz','xt') as f:
   for id,r in sorted(old.items()):
    new=w.run(r['input']);f.write(json.dumps(new,separators=(',',':'))+'\n');f.flush()
    for field in ['rack','board','status','samples','impulseTrace','resolvedEvents','contacts']:assert new[field]==r[field],(id,field)
    replays.append(dict(id=id,exact=True,traceRows=len(new['researchTrace'])));print(id,'exact',len(new['researchTrace']),flush=True)
  write('replays.json',replays);success=True
 finally:
  code=w.close() if w else None
  shut=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True) if boot else None
  write('closure.json',dict(success=success,workerExit=code,shutdownExit=None if shut is None else shut.returncode))
if __name__=='__main__':
 try:main(sys.argv[1])
 except BaseException:write('error.json',dict(traceback=traceback.format_exc()));raise
