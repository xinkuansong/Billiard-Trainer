from pathlib import Path
import sys,subprocess,json,sqlite3,time,math,statistics,hashlib
OUT=Path(__file__).resolve().parents[2]/"output"/Path(__file__).resolve().parent.name

def atomic(path,v):
 tmp=path.with_suffix('.tmp');tmp.write_text(json.dumps(v,ensure_ascii=False,separators=(',',':')));tmp.replace(path)

def run_batch(name,inputs,uid,binary,verify=False):
 dest=OUT/name;dest.mkdir(exist_ok=True);processes=[];logs=[]
 try:
  for i in range(min(8,len(inputs))):
   work=dest/f'worker-{i}';work.mkdir(exist_ok=True);atomic(work/'inputs.json',inputs[i::min(8,len(inputs))])
   f=(work/'run.log').open('a');logs.append(f)
   p=subprocess.Popen(['xcrun','simctl','spawn',uid,binary,str(work),*(['--verify-unpruned'] if verify else [])],stdout=f,stderr=subprocess.STDOUT);processes.append(p)
  while any(p.poll() is None for p in processes):
   if any(p.poll() not in (None,0) for p in processes):raise RuntimeError('Native filter failed; per-worker log retained')
   time.sleep(2)
  assert all(p.returncode==0 for p in processes)
 finally:
  for p in processes:
   if p.poll() is None:p.terminate()
  for p in processes:p.wait()
  for f in logs:f.close()
 rows=[json.loads(p.read_bytes()) for p in dest.glob('worker-*/results/*.json')]
 assert {r['id'] for r in rows}=={r['id'] for r in inputs}
 for r in rows:
  assert r['scoringVersion']=='defense-target-pipe-cut-lambda5-v9' and -1<=r['maximumSampled']<=100
  assert r['thresholds']==[t for t in [70,75,80,85,90,95] if r['maximumSampled']>=t]
  if r['maximumSampled']>=0:assert r['effect']['score']==r['maximumSampled'] and not r['effect'].get('unavailableReason')
  if verify:assert r['unprunedVerified']
 return rows

def main():
 uid,binary=sys.argv[1:3]
 subprocess.run(['xcrun','simctl','boot',uid],check=True)
 try:
  subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
  inputs=json.loads((OUT/'pilot-inputs.json').read_bytes());start=time.time()
  audits=run_batch('pruning-audit',[next(x for x in inputs if x['kind']==k) for k in ['two','three']],uid,binary,True)
  rows=run_batch('pilot',inputs,uid,binary)
  summary=dict(passed=True,cases=len(rows),pruningAudits=audits,wallSeconds=time.time()-start,medianMapSeconds=statistics.median(r['seconds'] for r in rows),meanMapSeconds=statistics.mean(r['seconds'] for r in rows),maximumMapSeconds=max(r['seconds'] for r in rows),estimatedMaxima=sum(r.get('estimatedMaximum',False) for r in rows),bands={str(t):sum(r['maximumSampled']>=t for r in rows) for t in [70,75,80,85,90,95]},rows=rows)
  atomic(OUT/'pilot-summary.json',summary);print({k:v for k,v in summary.items() if k not in ['rows','pruningAudits']},flush=True)
  atomic(OUT/'status.json',dict(state='pilot-complete',fullStarted=False,cases=len(rows)))
 finally:subprocess.run(['xcrun','simctl','shutdown',uid],check=True)
if __name__=='__main__':main()
