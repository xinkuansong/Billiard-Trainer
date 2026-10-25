#!/usr/bin/env python3
"""Eight persistent native solver processes, atomic compressed shards, resumable audit."""
from pathlib import Path
import signal,collections,concurrent.futures,gzip,hashlib,json,os,queue,select,shutil,struct,subprocess,sys,threading,time,traceback
from sampling import combinations
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
OUT=ROOT/'output/two-ball-strike-sampled100-20261024';APP=HERE/'Worker.app/Worker'
LOCK=threading.Lock();LIVE={};STOP=threading.Event()
def write(path,data):
    tmp=path.with_suffix(path.suffix+'.tmp');tmp.write_text(json.dumps(data,ensure_ascii=False,indent=2));tmp.replace(path)
def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda:f.read(2**20),b''):h.update(b)
    return h.hexdigest()
def f32(x):return struct.unpack('f',struct.pack('f',x))[0]
def checked(row,board,cs):
    assert row['id']==board['id'] and len(row['rows'])==len(cs)
    for trial,c in zip(row['rows'],cs):
        assert trial['comboIndex']==c['comboIndex']
        for k in ['spinX','spinY','velocity']:assert trial[k]==f32(c[k])
        assert trial['parameterStatus'] in ['legal','illegal','undetermined']
        assert trial['targetPottedSelected']==(trial['targetActualPocket']==f"pocket_{board['pocket']}")
        assert trial['cueCushionTotal']==sum(e['kind']=='cushion' and e['ball']=='cueBall' for e in trial['events'])
        assert ('cueStop' in trial)==trial['cueStopValid']
        assert not ('cuePath' in trial or 'recorder' in trial)
        if trial['parameterStatus']=='illegal':assert trial['status']=='illegal_parameters' and not trial['usableForPositionMatch']
        if trial['usableForPositionMatch']:
            assert trial['parameterStatus']=='legal' and trial['targetPottedSelected'] and not trial['cuePocketed'] and trial['cueStopValid'] and trial['resolved']
class Worker:
    def __init__(self,uid,index):
        self.index=index;self.log=(OUT/'logs'/f'worker-{index}.log').open('a')
        self.p=subprocess.Popen(['xcrun','simctl','spawn',uid,str(APP)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=self.log,text=True,bufsize=1)
        try:self.ready=self.receive('READY',120)
        except Exception:self.close();raise
        self.pid=self.ready['pid'];print('worker',index,'native pid',self.pid,flush=True)
        write(OUT/'logs'/f'worker-{index}-metadata.json',self.ready)
    def receive(self,prefix,timeout):
        deadline=time.monotonic()+timeout
        while time.monotonic()<deadline:
            ready,_,_=select.select([self.p.stdout],[],[],max(0,deadline-time.monotonic()))
            if not ready:break
            line=self.p.stdout.readline()
            if not line:raise RuntimeError(f'worker {self.index} exited {self.p.poll()}')
            if line.startswith(prefix+'\t'):return json.loads(line.split('\t',1)[1])
            if line.startswith('ERROR\t'):raise RuntimeError(line)
            self.log.write(line);self.log.flush()
        raise TimeoutError(f'worker {self.index} response timeout')
    def run(self,board,cs):
        self.p.stdin.write(json.dumps({'board':board,'combinations':cs},separators=(',',':'))+'\n');self.p.stdin.flush()
        result=self.receive('RESULT',180);checked(result,board,cs);return result
    def close(self):
        if hasattr(self,'p'):
            if self.p.stdin:
                try:self.p.stdin.close()
                except OSError:pass
            try:self.p.wait(timeout=15)
            except subprocess.TimeoutExpired:self.p.terminate();self.p.wait(timeout=15)
        self.log.close()
def parity(worker):
    inp=json.loads((ROOT/'research/two-ball-strike-pilot-20261024/input.json').read_text());old=json.loads((ROOT/'research/two-ball-strike-pilot-20261024/results.json').read_text())['rows']
    cs=[dict(c,comboIndex=i) for i,c in enumerate(inp['combinations'])];new=worker.run(inp['board'],cs)
    differences=[]
    for i,(a,b) in enumerate(zip(old,new['rows'])):
        for k,v in a.items():
            if k=='wallMilliseconds':continue
            if b.get(k)!=v:differences.append([i,k,v,b.get(k)])
    write(OUT/'pilot-parity.json',{'passed':not differences,'rows':630,'differences':differences[:30],'differenceCount':len(differences),'elapsedSeconds':new['elapsedSeconds'],'nativePID':worker.pid})
    assert not differences,f'Pilot parity failed: {differences[:3]}'
    print('PARITY PASS: all 630 rows match native pilot (excluding timing)',flush=True)
def shard_stats(rows):
    counts=collections.Counter();valid_hist=collections.Counter();rails=collections.Counter();terms=collections.Counter();reasons=collections.Counter();parameters=collections.Counter();tips=collections.Counter();speeds=collections.Counter();sim=0.
    for b in rows:
        valid_hist[sum(t['usableForPositionMatch'] for t in b['rows'])]+=1
        for t in b['rows']:
            counts[t['status']]+=1;terms[t['termination']]+=1;parameters[t['parameterStatus']]+=1;reasons.update(t['failureReasons']);tips[t['tipID']]+=1;speeds[t['speedID']]+=1
            if t['usableForPositionMatch']:rails[t['cueMainRailsAfterContact']]+=1
        sim+=b['elapsedSeconds']
    return dict(layouts=len(rows),attempts=sum(counts.values()),status=dict(counts),parameters=dict(parameters),termination=dict(terms),failureReasonsNonexclusive=dict(reasons),validCountHistogram={str(k):v for k,v in valid_hist.items()},mainRailsForValid={str(k):v for k,v in rails.items()},tipHistogram={str(k):v for k,v in tips.items()},speedHistogram={str(k):v for k,v in speeds.items()},summedLayoutComputeSeconds=sim)
def aggregate(receipts):
    out={'completedLayouts':0,'completedAttempts':0,'completedShards':len(receipts),'compressedBytes':0,'summedLayoutComputeSeconds':0.}
    keys=['status','parameters','termination','failureReasonsNonexclusive','validCountHistogram','mainRailsForValid','tipHistogram','speedHistogram'];counters={k:collections.Counter() for k in keys}
    for r in receipts:
        s=r['stats'];out['completedLayouts']+=s['layouts'];out['completedAttempts']+=s['attempts'];out['compressedBytes']+=r['compressedBytes'];out['summedLayoutComputeSeconds']+=s['summedLayoutComputeSeconds']
        for k in keys:counters[k].update(s[k])
    out.update({k:dict(v) for k,v in counters.items()});return out
def execute(uid):
    for d in ['parts','receipts','logs']:(OUT/d).mkdir(exist_ok=True)
    meta=json.loads((OUT/'run-manifest.json').read_text());boards=json.loads((OUT/'layouts.json').read_text());schedule=json.loads((OUT/'schedule.json').read_text())
    assert sha(Path(meta['sourceBank']))==meta['sourceBankSHA256'] and sha(OUT/'layouts.json')==meta['layoutsSHA256']
    fingerprint=sha(APP);identity={'binarySHA256':fingerprint,'mainSHA256':sha(HERE/'main.swift'),'samplingSHA256':sha(HERE/'sampling.py'),'sourceHashesSHA256':sha(HERE/'source-hashes.json')}
    identity_file=OUT/'execution-identity.json'
    if identity_file.exists():assert json.loads(identity_file.read_text())==identity,'Execution changed; cannot resume'
    else:write(identity_file,identity)
    receipts=[];pending=queue.Queue();shards=[schedule[i:i+100] for i in range(0,len(schedule),100)]
    for index,indices in enumerate(shards):
        receipt=OUT/'receipts'/f'{index:05}.json';file=OUT/'parts'/f'{index:05}.jsonl.gz'
        if receipt.exists():
            r=json.loads(receipt.read_text());assert r['layoutIndices']==indices and sha(file)==r['sha256'];receipts.append(r)
        else:pending.put((index,indices))
    start=time.monotonic();started=time.time();workers=[]
    def interrupted(signum,frame):
        STOP.set()
        raise KeyboardInterrupt('Managed run interrupted')
    signal.signal(signal.SIGTERM,interrupted);signal.signal(signal.SIGINT,interrupted)
    try:
        for i in range(8):workers.append(Worker(uid,i))
        assert len({w.pid for w in workers})==8
        assert all(w.ready['profile']==workers[0].ready['profile'] for w in workers)
        parity(workers[0])
        write(OUT/'workers.json',{'pids':[w.pid for w in workers],'device':uid,'profileSHA256':hashlib.sha256(json.dumps(workers[0].ready['profile']).encode()).hexdigest(),'count':8})
        def work(w):
            while not STOP.is_set():
                try:index,indices=pending.get_nowait()
                except queue.Empty:return
                rows=[];file=OUT/'parts'/f'{index:05}.jsonl.gz';tmp=file.with_suffix('.gz.partial')
                with gzip.open(tmp,'wt',compresslevel=6,encoding='utf8') as f:
                    for j,bi in enumerate(indices):
                        if STOP.is_set():return
                        board=boards[bi];cs=combinations(board['id']);result=w.run(board,cs)
                        f.write(json.dumps(result,separators=(',',':'),ensure_ascii=False)+'\n');rows.append(result)
                        with LOCK:LIVE[w.index]={'shard':index,'done':j+1,'layoutID':board['id']}
                tmp.replace(file)
                r={'index':index,'layoutIndices':indices,'stats':shard_stats(rows),'sha256':sha(file),'compressedBytes':file.stat().st_size,'binarySHA256':fingerprint}
                write(OUT/'receipts'/f'{index:05}.json',r)
                with LOCK:receipts.append(r);LIVE.pop(w.index,None)
                pending.task_done()
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            futures=[pool.submit(work,w) for w in workers]
            while not all(f.done() for f in futures):
                failed=[f.exception() for f in futures if f.done() and f.exception() is not None]
                if failed:STOP.set();raise failed[0]
                with LOCK:
                    progress=aggregate(receipts);progress.update(state='running',startedAt=started,elapsedSeconds=time.monotonic()-start,totalLayouts=len(boards),totalAttempts=len(boards)*100,workers=8,live=dict(LIVE))
                done=progress['completedLayouts'];progress['estimatedRemainingSeconds']=(len(boards)-done)*(time.monotonic()-start)/done if done else None
                write(OUT/'progress.json',progress)
                print('PROGRESS',done,'/',len(boards),'attempts',progress['completedAttempts'],'seconds',round(progress['elapsedSeconds'],1),flush=True)
                time.sleep(30)
            for f in futures:f.result()
        write(OUT/'progress.json',dict(aggregate(receipts),state='auditing',elapsedSeconds=time.monotonic()-start,totalLayouts=len(boards),totalAttempts=len(boards)*100))
        # Independent streaming audit from saved gzip, regenerating frozen sampled inputs.
        seen=set();audited=[]
        for index,indices in enumerate(shards):
            file=OUT/'parts'/f'{index:05}.jsonl.gz';receipt=json.loads((OUT/'receipts'/f'{index:05}.json').read_text());assert sha(file)==receipt['sha256']
            with gzip.open(file,'rt') as f:rows=[json.loads(line) for line in f]
            assert len(rows)==len(indices)
            for bi,b in zip(indices,rows):
                assert b['id'] not in seen;seen.add(b['id']);checked(b,boards[bi],combinations(b['id']))
            assert shard_stats(rows)==receipt['stats'];audited.append(receipt)
        assert len(seen)==135700 and sha(Path(meta['sourceBank']))==meta['sourceBankSHA256']
        summary=aggregate(audited);assert summary['completedAttempts']==13570000
        assert [summary['tipHistogram'].get(str(i+1),0) for i in range(45)]==meta['tipHistogram']
        assert [summary['speedHistogram'].get(str(i+1),0) for i in range(14)]==meta['speedHistogram']
        summary.update(state='complete',elapsedSeconds=time.monotonic()-start,totalLayouts=len(boards),totalAttempts=13570000,auditPassed=True,sourceUnchanged=True,binarySHA256=fingerprint)
        write(OUT/'summary.json',summary);write(OUT/'progress.json',summary)
        print('FULL_RUN_COMPLETE',json.dumps(summary),flush=True)
    except BaseException as e:
        STOP.set();write(OUT/'failure.json',{'error':str(e),'traceback':traceback.format_exc(),'time':time.time()});raise
    finally:
        for w in workers:w.close()
        subprocess.run(['xcrun','simctl','shutdown',uid],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
if __name__=='__main__':
    uid=sys.argv[1]
    subprocess.run(['xcrun','simctl','boot',uid],check=True)
    subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
    execute(uid)
