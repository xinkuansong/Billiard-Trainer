from pathlib import Path
import os,sys,json,subprocess,importlib.util,concurrent.futures,time,gzip,hashlib,shutil,threading,collections
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output/bank-full-20261101'
sys.path.insert(0,str(HERE));import audit
LOCK=threading.Lock();ACTIVE=set();PEAK=0

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,d):
 tmp=p.with_suffix(p.suffix+'.tmp');tmp.write_text(json.dumps(d,ensure_ascii=False,indent=2));tmp.replace(p)
def main():
 if len(sys.argv)==1:
  OUT.mkdir(exist_ok=True)
  subprocess.run([sys.executable,str(ROOT/'scripts/simulator_lifecycle.py'),'inventory','--output',str(OUT/'inventory-before.json')],stdout=subprocess.DEVNULL,check=True)
  spec=importlib.util.spec_from_file_location('build',HERE/'build.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod);app=mod.build()
  subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','notch-phone','--task','bank-full-20261101','--',sys.executable,__file__,'worker','{udid}',str(app/'Worker')],check=True)
 else:
  global PEAK
  _,uid,worker=sys.argv[1:];work=Path(os.environ['QIUJI_TEST_WORK']);start=time.time()
  def native(mode,out,*args,log=None):
   subprocess.run(['xcrun','simctl','spawn',uid,worker,mode,str(out),*map(str,args)],stdout=log,stderr=subprocess.STDOUT,check=True)
  subprocess.run(['xcrun','simctl','boot',uid],check=True)
  try:
   subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
   native('geometry',OUT/'geometry.json');native('regression',ROOT/'output/bank-distance12-20261101/selected.json',OUT/'regression.json');native('prepare',OUT)
   routes=json.loads((OUT/'route-tree.json').read_text());tree={r['id']:r for r in routes};g=json.loads((OUT/'geometry.json').read_text());audit.ns['tree_audit'](tree,g)
   identity={n:sha(OUT/n) for n in ['source-binding.json','route-tree.json','geometry.json']}
   # Identity is content-bound; shared resume results cannot silently mix source revisions.
   statefile=OUT/'generation-identity.json'
   if statefile.exists():assert json.loads(statefile.read_text())==identity,'Resume source mismatch'
   else:write(statefile,identity)
   (OUT/'routes').mkdir(exist_ok=True);(OUT/'logs').mkdir(exist_ok=True)
   receipts=[];halt=threading.Event()
   def job(index):
    global PEAK
    if halt.is_set():raise RuntimeError('Stopped after another route failed')
    route=routes[index];target=OUT/'routes'/f'{index:03d}.json.gz';receipt=OUT/'routes'/f'{index:03d}.receipt.json'
    if receipt.exists():
     r=json.loads(receipt.read_text());assert r['identity']==identity and sha(target)==r['sha256'];return r
    directory=work/f'route-{index:03d}';directory.mkdir(exist_ok=True)
    with LOCK:
     ACTIVE.add(index);PEAK=max(PEAK,len(ACTIVE));write(OUT/'active.json',{'active':sorted(ACTIVE),'peak':PEAK,'time':time.time()})
    try:
     with (OUT/'logs'/f'{index:03d}.log').open('w') as log:
      native('route',directory,index,log=log);native('verify',directory,log=log)
     rows=json.loads((directory/'selected.json').read_text());v=json.loads((directory/'verification.json').read_text());summary=json.loads((directory/'summary.json').read_text());audit.check(rows,g,v,tree,summary)
     packet={'rows':rows,'verification':v,'summary':summary}
     tmp=target.with_suffix('.tmp')
     with gzip.open(tmp,'wt',encoding='utf8',compresslevel=6) as f:json.dump(packet,f,separators=(',',':'))
     tmp.replace(target)
     r={'routeIndex':index,'routeID':route['id'],'n':len(route['reverseWalls']),'pocket':route['pocket'],'selected':len(rows),'elapsedSeconds':summary['elapsedSeconds'],'sha256':sha(target),'identity':identity,'verified':True,'counts':dict(sum((collections.Counter(p['counts']) for p in summary['targets']),collections.Counter()))}
     write(receipt,r)
     # This directory is exclusive managed scratch; compact source evidence is now retained.
     shutil.rmtree(directory)
     return r
    finally:
     with LOCK:
      ACTIVE.remove(index);write(OUT/'active.json',{'active':sorted(ACTIVE),'peak':PEAK,'time':time.time()})
   # Interleave cushion/pocket strata so the initial completed batch is representative.
   groups=collections.defaultdict(list)
   for i,r in enumerate(routes):groups[(len(r['reverseWalls']),r['pocket'])].append(i)
   order=[]
   while any(groups.values()):
    for key in sorted(groups):
     if groups[key]:order.append(groups[key].pop(0))
   with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
    futures={executor.submit(job,i):i for i in order}
    try:
     for f in concurrent.futures.as_completed(futures):
      receipts.append(f.result());elapsed=time.time()-start
      status={'state':'running','workers':8,'peakActive':PEAK,'routesCompleted':len(receipts),'routesTotal':len(routes),'selected':sum(r['selected'] for r in receipts),'elapsedSeconds':elapsed,'counts':dict(sum((collections.Counter(r['counts']) for r in receipts),collections.Counter()))}
      write(OUT/'status.json',status);print('PROGRESS',json.dumps(status),flush=True)
    except BaseException:
     halt.set()
     for pending in futures:pending.cancel()
     write(OUT/'failure.json',{'state':'failed','completed':len(receipts),'time':time.time()})
     raise
   subprocess.run([sys.executable,str(HERE/'finish.py')],check=True)
  finally:subprocess.run(['xcrun','simctl','shutdown',uid],check=True)
if __name__=='__main__':main()
