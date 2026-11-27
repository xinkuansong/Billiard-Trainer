from pathlib import Path
import os,sys,json,subprocess,importlib.util,concurrent.futures,time,gzip,hashlib,shutil,threading,collections,tarfile
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output/bank-variants-20261101';BASE=ROOT/'output/bank-full-20261101'
sys.path.insert(0,str(HERE));import audit
LOCK=threading.Lock();ACTIVE=set();PEAK=0

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,d):
 tmp=p.with_suffix(p.suffix+'.tmp');tmp.write_text(json.dumps(d,ensure_ascii=False,indent=2));tmp.replace(p)
def main():
 if len(sys.argv)==1:
  OUT.mkdir(exist_ok=True)
  assert sha(BASE/'formations.jsonl.gz')==json.loads((BASE/'export.json').read_text())['sha256']
  subprocess.run([sys.executable,str(ROOT/'scripts/simulator_lifecycle.py'),'inventory','--output',str(OUT/'inventory-before.json')],stdout=subprocess.DEVNULL,check=True)
  spec=importlib.util.spec_from_file_location('build',HERE/'build.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod);app=mod.build()
  work=Path(os.environ['QIUJI_TEST_WORK'])
  with tarfile.open(OUT/'frozen-source.tar.gz','w:gz') as tar:
   tar.add(work/'source',arcname='native-source');tar.add(HERE,arcname='harness',filter=lambda x:None if '__pycache__' in x.name else x)
   tar.add(ROOT/'research/bank-full-20261101/audit.py',arcname='inherited-full-audit.py');tar.add(ROOT/'research/bank-extension24-20261101/audit.py',arcname='inherited-extension-audit.py')
  subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','notch-phone','--task','bank-variants-20261101','--',sys.executable,__file__,'worker','{udid}',str(app/'Worker')],check=True)
 else:
  global PEAK
  _,uid,worker=sys.argv[1:];work=Path(os.environ['QIUJI_TEST_WORK']);start=time.time()
  def native(mode,out,*args,log=None):subprocess.run(['xcrun','simctl','spawn',uid,worker,mode,str(out),*map(str,args)],stdout=log,stderr=subprocess.STDOUT,check=True)
  subprocess.run(['xcrun','simctl','boot',uid],check=True)
  try:
   subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
   native('geometry',OUT/'geometry.json');native('regression',ROOT/'output/bank-distance12-20261101/selected.json',OUT/'regression.json')
   g=json.loads((OUT/'geometry.json').read_text());assert g==json.loads((BASE/'geometry.json').read_text())
   shutil.copy2(BASE/'route-tree.json',OUT/'route-tree.json');tree={r['id']:r for r in json.loads((OUT/'route-tree.json').read_text())}
   bases=[]
   with gzip.open(BASE/'formations.jsonl.gz','rt') as f:
    for i,line in enumerate(f):
     r=json.loads(line);r['baseIndex']=i;bases.append(r)
   assert len(bases)==3993 and all(r['transform']==0 for r in bases)
   jobs=[bases[i:i+16] for i in range(0,len(bases),16)]
   identity={'baseSHA256':sha(BASE/'formations.jsonl.gz'),'nativeSHA256':json.loads((OUT/'build.json').read_text())['executableSHA256'],'sources':sha(OUT/'source-binding.json')}
   write(OUT/'identity.json',identity)
   (OUT/'batches').mkdir(exist_ok=True);(OUT/'logs').mkdir(exist_ok=True)
   receipts=[];halt=threading.Event()
   def job(index):
    global PEAK
    if halt.is_set():raise RuntimeError('stopped after batch failure')
    target=OUT/'batches'/f'{index:03d}.json.gz';receipt=OUT/'batches'/f'{index:03d}.receipt.json';group=jobs[index]
    if receipt.exists():
     r=json.loads(receipt.read_text());assert r['identity']==identity and r['sha256']==sha(target);return r
    directory=work/f'batch-{index:03d}';directory.mkdir(exist_ok=True);write(directory/'input.json',group)
    with LOCK:
     ACTIVE.add(index);PEAK=max(PEAK,len(ACTIVE));write(OUT/'active.json',{'active':sorted(ACTIVE),'peak':PEAK})
    try:
     with (OUT/'logs'/f'{index:03d}.log').open('w') as log:
      native('variants',directory,directory/'input.json',log=log);native('verify',directory,log=log)
     rows=json.loads((directory/'selected.json').read_text());v=json.loads((directory/'verification.json').read_text());decisions=json.loads((directory/'decisions.json').read_text());bs={r['id']:r for r in group}
     audit.audit_rows(rows,g,v,tree,bs,decisions)
     compact=[audit.compact(r) for r in rows];audit.audit_rows(compact,g,v,tree,bs,decisions)
     packet={'rows':compact,'verification':v,'decisions':decisions};tmp=target.with_suffix('.tmp')
     with gzip.open(tmp,'wt',encoding='utf8',compresslevel=6) as f:json.dump(packet,f,separators=(',',':'))
     tmp.replace(target)
     counts=collections.Counter(r['variantKind'] for r in rows)
     r={'batch':index,'bases':len(group),'rows':len(rows),'counts':dict(counts),'sha256':sha(target),'identity':identity,'verified':True}
     write(receipt,r);shutil.rmtree(directory);return r
    finally:
     with LOCK:
      ACTIVE.remove(index);write(OUT/'active.json',{'active':sorted(ACTIVE),'peak':PEAK})
   with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
    futures={executor.submit(job,i):i for i in range(len(jobs))}
    try:
     for f in concurrent.futures.as_completed(futures):
      receipts.append(f.result());s={'state':'running','workers':8,'peakActive':PEAK,'batchesCompleted':len(receipts),'batchesTotal':len(jobs),'basesCompleted':sum(r['bases'] for r in receipts),'rows':sum(r['rows'] for r in receipts),'counts':dict(sum((collections.Counter(r['counts']) for r in receipts),collections.Counter())),'elapsedSeconds':time.time()-start}
      write(OUT/'status.json',s);print('PROGRESS',json.dumps(s),flush=True)
    except BaseException:
     halt.set()
     for p in futures:p.cancel()
     write(OUT/'failure.json',{'completed':len(receipts),'time':time.time()});raise
   subprocess.run([sys.executable,str(HERE/'finish.py')],check=True)
  finally:subprocess.run(['xcrun','simctl','shutdown',uid],check=True)
if __name__=='__main__':main()
