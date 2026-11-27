from pathlib import Path
import json,subprocess,concurrent.futures,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/k-ball-obstacles-20261030'
def run(name,jobs):
 info=json.load(open(OUT/'worker-ready.json'));stage=OUT/name;stage.mkdir(exist_ok=True)
 def chunk(i):
  js=jobs[i::2];inp=stage/f'jobs-{i}.jsonl';out=stage/f'results-{i}.jsonl';body=''.join(json.dumps(j,sort_keys=True)+'\n' for j in js)
  if inp.exists():assert inp.read_text()==body,'Inputs changed: '+str(inp)
  else:inp.write_text(body)
  if not out.exists():
   with (stage/f'worker-{i}.log').open('w') as log:subprocess.run(['xcrun','simctl','spawn',info['uid'],info['worker'],str(inp),str(out)],stdout=log,stderr=subprocess.STDOUT,check=True)
  result=list(map(json.loads,out.open()));assert len(result)==len(js),(name,len(result),len(js));assert [r['id'] for r in result]==[j['id'] for j in js]
  return result
 with concurrent.futures.ThreadPoolExecutor(2) as ex:rows=sum(list(ex.map(chunk,range(2))),[])
 byid={r['id']:r for r in rows};assert len(byid)==len(jobs)
 print(name,len(rows),'success',sum(r['success'] for r in rows),flush=True)
 return byid
if __name__=='__main__':
 jobs=list(map(json.loads,(OUT/'initial-jobs.jsonl').open()));r=run('initial',jobs)
 samples=json.load(open(OUT/'samples.json'))
 for s in samples:
  sid=s['sampleID'];n=s['candidate']['railOrdinal'];lower=[v for k,v in r.items() if k.startswith(sid+'/archive/') and v['success'] and 1<=v['observedRail']<n]
  print(sid,'baseline',r[sid+'/reference']['success'],r[sid+'/reference'].get('observedRail'),'lower',len(lower),flush=True)
