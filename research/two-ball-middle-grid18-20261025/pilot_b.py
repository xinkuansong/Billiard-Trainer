import gzip,json,os,subprocess,sys,time,traceback
from pathlib import Path
from runner import check
import pipeline as P
uid=sys.argv[1];out=P.B/'pilot-direct';out.mkdir(exist_ok=True)
for name in ('logs','tmp','failures'): (out/name).mkdir(exist_ok=True)
P.common.OUT=out;P.common.APP=P.HERE/'Worker.app/Worker';w=None
try:
 subprocess.run(['xcrun','simctl','boot',uid],check=True,capture_output=True);subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True,capture_output=True)
 w=P.common.Worker(uid,0)
 # Explicit direct positive and rail-parallel impossible-mouth examples.
 req=[{'key':'direct','cue':[-.05,0.35],'object':[0.,0.],'aim':P.C.G.anchors()[4],'pocket':4},{'key':'parallel','cue':[-.95,-.56],'object':[-.6,-.60],'aim':P.C.G.anchors()[4],'pocket':4}]
 middles=P.Middle(w).evaluate(req);P.write(out/'middle-fixtures.json',middles);assert middles[0]['passed'] and not middles[1]['passed']
 rows=[json.loads(l) for l in gzip.decompress((P.A/'parts/00000.jsonl.gz').read_bytes()).splitlines()];proofs={r['id']:r for r in (json.loads(l) for l in gzip.decompress((P.A/'proofs/00000.jsonl.gz').read_bytes()).splitlines())}
 total={};started=time.perf_counter()
 for n,row in enumerate(rows[:3]):
  row['_middleProofs']=proofs[row['id']]['middleProofs'];tmp=out/'tmp'/str(n);tmp.mkdir(exist_ok=True)
  f,t,s=P.stage_b(row,w,tmp);check(row,f,t,'b',proofs[row['id']]);P.merge(total,s)
  P.write(out/f'result-{n}.json',f);P.write(out/f'proof-{n}.json',t)
  # Full greedy sweep must agree with the optimized first-five termination.
  subprocess.run([str(P.ROOT/'research/two-ball-refine-full-20261025/dedup'),str(tmp/'dedup-in.json'),str(tmp/'dedup-full.json'),'--full'],check=True,capture_output=True)
  full=P.read(tmp/'dedup-full.json');assert [x['top5'] for x in full['results']]==[[q['comboIndex'] for q in c['top5']] for c in f['candidates']]
  print('LAYOUT',n,s,flush=True)
 P.write(out/'summary.json',{'state':'complete','auditPassed':True,'stats':total,'seconds':time.perf_counter()-started,'fullGreedyParity':3,'middleFixturesPassed':True})
except BaseException:
 P.write(out/'failure.json',{'traceback':traceback.format_exc(),'time':time.time()});raise
finally:
 if w:w.close()
 shutdown=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True,text=True)
 P.write(out/'cleanup.json',{'workerExit':w.p.poll() if w else None,'shutdownExitCode':shutdown.returncode});assert shutdown.returncode==0
