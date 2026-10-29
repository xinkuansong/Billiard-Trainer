"""Resume completed route records; bounded native chunks with compressed evidence."""
from pathlib import Path
import gzip, hashlib, json, os, subprocess, sys, time
from scan import ROOT, OUT, sha

PREVIOUS='3358672ce7614f69a62bc5f1d3a126d9'
WORKER=ROOT/f'output/local-test-runs/{PREVIOUS}/work/KBallWorker.app/Worker'


def compress(source,destination):
    digest=hashlib.sha256()
    with source.open('rb') as inp,gzip.open(destination,'wb',compresslevel=1) as out:
        for block in iter(lambda:inp.read(1024*1024),b''):out.write(block);digest.update(block)
    check=hashlib.sha256()
    with gzip.open(destination,'rb') as inp:
        for block in iter(lambda:inp.read(1024*1024),b''):check.update(block)
    assert digest.digest()==check.digest()
    return dict(path=str(destination.relative_to(OUT)),sha256=sha(destination),uncompressedSHA256=digest.hexdigest())


def main():
    if len(sys.argv)==1:
        assert sha(WORKER)==json.loads((OUT/'build.json').read_text())['executableSHA256']
        subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','notch-phone','--task','k-ball-full-20261029-resume','--',sys.executable,__file__,'{udid}'],check=True)
        return
    uid=sys.argv[1];work=Path(os.environ['QIUJI_TEST_WORK']);chunks=OUT/'chunks';chunks.mkdir(exist_ok=True)
    manifest=[];seen=set();partial=[]
    for i in range(4):
        source=OUT/f'results-{i}.jsonl';complete=work/f'checkpoint-{i}.jsonl'
        with source.open('rb') as inp,complete.open('wb') as out:
            for raw in inp:
                if not raw.endswith(b'\n'):
                    partial.append(dict(file=source.name,bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest()));(chunks/f'partial-{i}.bin').write_bytes(raw);break
                row=json.loads(raw);assert row['key'] not in seen;seen.add(row['key']);out.write(raw)
        entry=compress(complete,chunks/f'checkpoint-{i}.jsonl.gz');manifest.append(entry)
        # Own interrupted output; every complete byte is verified in compressed evidence.
        source.unlink();complete.unlink()
    jobs=[line for line in (OUT/'jobs.jsonl').open()]
    enriched={j['key']:j for i in range(4) for j in map(json.loads,(OUT/f'jobs-{i}.jsonl').open())}
    pending=[enriched[json.loads(line)['key']] for line in jobs if json.loads(line)['key'] not in seen]
    (OUT/'checkpoint-audit.json').write_text(json.dumps(dict(completedRoutes=len(seen),remainingRoutes=len(pending),partialRecords=partial,compressed=manifest),indent=2))
    queue=[]
    for number,start in enumerate(range(0,len(pending),60)):
        subset=pending[start:start+60];inp=chunks/f'input-{number:04d}.jsonl'
        inp.write_text(''.join(json.dumps(j)+'\n' for j in subset));queue.append((number,inp,{j['key'] for j in subset}))
    state=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json']))
    original=next(d['state'] for ds in state['devices'].values() for d in ds if d['udid']==uid)
    if original=='Shutdown':
        subprocess.run(['xcrun','simctl','boot',uid],check=True);subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
    else:assert original=='Booted'
    active=[];nextjob=0
    try:
        while nextjob<len(queue) or active:
            while nextjob<len(queue) and len(active)<12:
                number,inp,expected=queue[nextjob];nextjob+=1
                raw=work/f'results-{number:04d}.jsonl';log=(chunks/f'worker-{number:04d}.log').open('w')
                p=subprocess.Popen(['xcrun','simctl','spawn',uid,str(WORKER),str(inp),str(OUT/'protocol.json'),str(raw)],stdout=log,stderr=subprocess.STDOUT)
                active.append((p,log,number,raw,expected))
            finished=[]
            for item in active:
                p,log,number,raw,expected=item
                if p.poll() is None:continue
                if p.returncode:raise RuntimeError(f'Chunk {number} failed: {p.returncode}')
                actual={r['key'] for r in map(json.loads,raw.open())};assert actual==expected and not(actual&seen)
                seen.update(actual);entry=compress(raw,chunks/f'results-{number:04d}.jsonl.gz');entry['routes']=len(actual);manifest.append(entry)
                raw.unlink();log.close();finished.append(item)
                (OUT/'execution-progress.json').write_text(json.dumps(dict(completedRoutes=len(seen),totalRoutes=len(enriched),compressedFiles=manifest,workers=12)))
                print('CHUNK',number,'COMPLETE',len(seen),'/',len(enriched),flush=True)
            active=[a for a in active if a not in finished]
            if active:time.sleep(1)
        assert seen==set(enriched)
        (OUT/'execution.json').write_text(json.dumps(dict(complete=True,routes=len(seen),compressedFiles=manifest,workers=12,workerSHA256=sha(WORKER)),indent=2))
    finally:
        for p,_,_,_,_ in active:
            if p.poll() is None:p.terminate()
        for p,log,_,_,_ in active:p.wait();log.close()
        if original=='Shutdown':subprocess.run(['xcrun','simctl','shutdown',uid],check=True)


if __name__=='__main__':main()
