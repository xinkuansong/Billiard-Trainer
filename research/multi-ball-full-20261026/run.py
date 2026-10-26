"""Durable parallel break generation, followed by full streaming admission audit."""
from concurrent.futures import ThreadPoolExecutor, as_completed
from collections import Counter
from pathlib import Path
import argparse, gzip, json, math, os, select, shutil, subprocess, threading, time, traceback
import build as builder
from bank import KINDS, VERSION, THRESHOLD, job, classify, signature, verify_base

ROOT, HERE = builder.ROOT, builder.HERE
PILOT = ROOT/'output/multi-ball-generation-20261026'
LOCK = threading.Lock()
STOP = threading.Event()
SEEN = set()
STATES = {}

def write(path, data):
    path = Path(path); tmp = path.with_suffix(path.suffix+'.partial')
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2, allow_nan=False))
    tmp.replace(path)

def packed(path, value):
    path = Path(path); tmp = path.with_suffix(path.suffix+'.partial')
    with gzip.open(tmp, 'wt', compresslevel=6) as f: json.dump(value, f, separators=(',',':'), allow_nan=False)
    tmp.replace(path)

def unpack(path):
    with gzip.open(path, 'rt') as f: return json.load(f)

class Worker:
    def __init__(self, uid, binary, folder):
        self.log = (folder/'native.log').open('w')
        self.p = subprocess.Popen(['xcrun','simctl','spawn',uid,str(binary)], stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=self.log, text=True, bufsize=1)
        try: self.ready = self.receive('READY')
        except BaseException:
            self.p.terminate(); self.p.wait(timeout=15); self.log.close(); raise
    def receive(self, tag):
        deadline=time.monotonic()+120
        while time.monotonic()<deadline:
            if not select.select([self.p.stdout],[],[],max(0,deadline-time.monotonic()))[0]: break
            line=self.p.stdout.readline()
            if not line: raise RuntimeError(f'Native worker exited {self.p.poll()}')
            if line.startswith(tag+'\t'): return json.loads(line.split('\t',1)[1])
            if line.startswith('ERROR\t'): raise RuntimeError(line)
            self.log.write(line); self.log.flush()
        raise TimeoutError('Native worker response exceeded 120 seconds')
    def run(self, inp):
        self.p.stdin.write(json.dumps(inp)+'\n'); self.p.stdin.flush()
        return self.receive('RESULT')
    def close(self):
        if self.p.poll() is None:
            self.p.stdin.close()
            try: self.p.wait(timeout=15)
            except subprocess.TimeoutExpired:
                self.p.terminate()
                try: self.p.wait(timeout=15)
                except subprocess.TimeoutExpired: self.p.kill(); self.p.wait()
        self.log.close()
        return self.p.returncode

def publish(out, key, data):
    with LOCK:
        STATES[key]=data
        by_kind={str(n):dict(accepted=0, attempts=0, completedShards=0) for n in KINDS}
        for state in STATES.values():
            total=by_kind[str(state['n'])]
            total['accepted']+=state['accepted']; total['attempts']+=state['attempts']
            total['completedShards']+=int(state.get('complete',False))
        write(out/'progress.json',dict(updatedAt=time.time(),kinds=by_kind,
            accepted=sum(v['accepted'] for v in by_kind.values()),
            attempts=sum(v['attempts'] for v in by_kind.values()),shards=STATES))

def generate_part(uid,binary,out,cal,n,shard,quota):
    key=f'n{n:02}-s{shard:03}'
    epoch=0
    while (out/'parts'/f'{key}-r{epoch:02}').exists(): epoch+=1
    folder=out/'parts'/f'{key}-r{epoch:02}'; folder.mkdir(parents=True)
    start=time.time(); worker=Worker(uid,binary,folder); meta=worker.ready
    write(folder/'metadata.json',meta)
    kept=[]; counts=Counter(); attempts=0; replay=[]; completed=False
    raw=folder/'raw.jsonl.gz'
    try:
        assert all(meta[k]==cal['domain'][k] for k in ('length','width','radius'))
        assert meta['pockets']==cal['domain']['pockets']
        with gzip.open(raw,'wt',compresslevel=3) as f:
            while len(kept)<quota:
                if STOP.is_set(): raise RuntimeError('Another shard failed; stopping this shard safely')
                assert attempts<max(20000,quota*1000), 'Attempt cap reached; do not lower threshold'
                inp=job(meta,n,shard,attempts,epoch); row=worker.run(inp)
                assert row['input']==inp
                decision,base=classify(row,meta,cal)
                if decision=='accepted':
                    sig=signature(base)
                    with LOCK:
                        if sig in SEEN: decision='duplicate'
                        else: SEEN.add(sig)
                counts[decision]+=1; attempts+=1
                record=dict(result=row,decision=decision,index=None if base is None else base['index'])
                f.write(json.dumps(record,separators=(',',':'),allow_nan=False)+'\n')
                if decision=='accepted':
                    verify_base(base,meta,cal); kept.append(base)
                    if len(replay)<2:
                        again=worker.run(inp)
                        for field in ('rack','cue','power','direction','status','termination','pocketed','board'):
                            assert row[field]==again[field], (inp['id'],field)
                        replay.append(inp['id'])
                if attempts%64==0 or len(kept)==quota:
                    f.flush()
                    if shutil.disk_usage(out).free<2*1024**3: raise RuntimeError('Less than 2 GiB free; preserve evidence and stop')
                    publish(out,key,dict(n=n,shard=shard,epoch=epoch,accepted=len(kept),quota=quota,
                        attempts=attempts,counts=dict(counts),seconds=time.time()-start,complete=False))
        packed(folder/'accepted.json.gz',kept)
        completed=True
    finally:
        code=worker.close()
        write(folder/'closure.json',dict(nativePID=meta['pid'],wrapperPID=worker.p.pid,exitCode=code,finishedAt=time.time()))
        if code!=0: raise RuntimeError(f'Native close failed: {code}')
    receipt=dict(n=n,shard=shard,epoch=epoch,folder=str(folder.relative_to(out)),accepted=len(kept),quota=quota,
        attempts=attempts,counts=dict(counts),seconds=time.time()-start,complete=completed,replayIDs=replay,
        rawSHA256=builder.sha(raw),acceptedSHA256=builder.sha(folder/'accepted.json.gz'))
    write(folder/'complete.json',receipt)
    publish(out,key,receipt)
    print(f'{key}: {len(kept)}/{quota}, attempts={attempts}, seconds={receipt["seconds"]:.1f}',flush=True)
    return receipt

def audit(out,cal,parts,target):
    start=time.time(); seen=set(); ids=set(); banks={n:[] for n in KINDS}; totals=Counter(); checks=0; duplicates=[]
    for part in sorted(parts,key=lambda p:(p['n'],p['shard'])):
        folder=out/part['folder']; meta=json.loads((folder/'metadata.json').read_text())
        assert json.loads((folder/'closure.json').read_text())['exitCode']==0
        for name,key in [('raw.jsonl.gz','rawSHA256'),('accepted.json.gz','acceptedSHA256')]:
            assert builder.sha(folder/name)==part[key]
        accepted=unpack(folder/'accepted.json.gz'); by_id={b['id']:b for b in accepted}
        assert len(by_id)==len(accepted)==part['quota'] and len(part['replayIDs'])==min(2,part['quota'])
        counts=Counter(); admitted_ids=set()
        with gzip.open(folder/'raw.jsonl.gz','rt') as f:
            for attempt,line in enumerate(f):
                record=json.loads(line); row=record['result']
                assert row['input']==job(meta,part['n'],part['shard'],attempt,part['epoch'])
                decision,base=classify(row,meta,cal)
                assert record['decision']==decision or (decision=='accepted' and record['decision']=='duplicate')
                assert record['index']==(None if base is None else base['index'])
                counts[record['decision']]+=1; checks+=1
                if record['decision']=='duplicate': duplicates.append(signature(base))
                if record['decision']=='accepted':
                    assert by_id[base['id']]==base
                    admitted_ids.add(base['id'])
        assert counts==Counter(part['counts']) and sum(counts.values())==part['attempts']
        assert admitted_ids==set(by_id)
        totals.update(counts)
        for base in accepted:
            verify_base(base,meta,cal)
            sig=signature(base); assert sig not in seen and base['id'] not in ids
            seen.add(sig); ids.add(base['id']); banks[base['n']].append(base)
    assert all(sig in seen for sig in duplicates), 'Duplicate decisions must refer to retained geometry'
    files={}; statistics={}
    for n,bank in banks.items():
        assert len(bank)==target
        bank.sort(key=lambda b:b['id'])
        name=f'bank-{n:02}.json.gz'; packed(out/name,dict(schemaVersion=1,n=n,threshold=THRESHOLD,
            metricVersion=VERSION,calibrationSHA256=builder.sha(out/'calibration.json'),boards=bank))
        loaded=unpack(out/name); assert loaded['boards']==bank
        files[name]=dict(sha256=builder.sha(out/name),bytes=(out/name).stat().st_size,count=len(bank))
        values=sorted(b['index'] for b in bank)
        statistics[str(n)]=dict(count=len(bank),minimum=values[0],median=values[len(values)//2],maximum=values[-1],
            cueScratches=sum(b['cueScratched'] for b in bank),attempts=sum(p['attempts'] for p in parts if p['n']==n))
    report=dict(passed=True,rawRecordsChecked=checks,acceptedChecked=len(ids),counts=dict(totals),
        files=files,kinds=statistics,seconds=time.time()-start)
    write(out/'audit.json',report)
    return report

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('uid'); ap.add_argument('--out',required=True)
    ap.add_argument('--target',type=int,default=10000); ap.add_argument('--shards',type=int,default=20)
    ap.add_argument('--workers',type=int,default=8); ap.add_argument('--resume',action='store_true')
    args=ap.parse_args(); assert args.target>0 and args.shards>0 and args.target%args.shards==0
    out=Path(args.out).resolve(); out.mkdir(parents=True,exist_ok=True); builder.OUT=out
    if (out/'run-start.json').exists() and not args.resume: raise RuntimeError('Existing run: require explicit --resume')
    cal=json.loads((PILOT/'calibration.json').read_text()); assert cal['version']==VERSION
    if (out/'calibration.json').exists(): assert builder.sha(out/'calibration.json')==builder.sha(PILOT/'calibration.json')
    else: shutil.copy2(PILOT/'calibration.json',out/'calibration.json')
    source={p.name:builder.sha(p) for p in HERE.iterdir() if p.suffix in ('.py','.swift')}
    config=dict(kinds=KINDS,targetPerKind=args.target,threshold=THRESHOLD,shardsPerKind=args.shards,
        workers=args.workers,metric=VERSION,calibrationSHA256=builder.sha(out/'calibration.json'),
        cueScratchPolicy='retained and labelled; ball in hand at training start',variantPolicy='random removal only; no evaluation',source=source)
    if args.resume: assert json.loads((out/'config.json').read_text())==json.loads(json.dumps(config))
    else: write(out/'config.json',config)
    binary=builder.build()
    write(out/'run-start.json',dict(pid=os.getpid(),device=args.uid,startedAt=time.time(),target=args.target*len(KINDS),resume=args.resume))
    completed={}; parts=[]
    for path in sorted((out/'parts').glob('*/complete.json')):
        receipt=json.loads(path.read_text()); key=(receipt['n'],receipt['shard']); assert key not in completed
        folder=out/receipt['folder']; assert builder.sha(folder/'accepted.json.gz')==receipt['acceptedSHA256']
        for base in unpack(folder/'accepted.json.gz'):
            sig=signature(base); assert sig not in SEEN; SEEN.add(sig)
        completed[key]=receipt; parts.append(receipt)
        publish(out,f'n{key[0]:02}-s{key[1]:03}',receipt)
    booted=False; success=False; started=time.time(); failure=None
    try:
        subprocess.run(['xcrun','simctl','boot',args.uid],check=True,capture_output=True); booted=True
        subprocess.run(['xcrun','simctl','bootstatus',args.uid,'-b'],check=True,capture_output=True)
        with ThreadPoolExecutor(max_workers=args.workers) as pool:
            futures=[pool.submit(generate_part,args.uid,binary,out,cal,n,s,args.target//args.shards)
                for s in range(args.shards) for n in (15,9,6,5,4) if (n,s) not in completed]
            try:
                for future in as_completed(futures): parts.append(future.result())
            except BaseException:
                STOP.set()
                for future in futures: future.cancel()
                raise
        report=audit(out,cal,parts,args.target)
        binding=json.loads((out/'source-binding.json').read_text())
        drift=[e['path'] for e in binding['production'] if builder.sha(ROOT/e['path'])!=e['sha256']]
        assert source=={p.name:builder.sha(p) for p in HERE.iterdir() if p.suffix in ('.py','.swift')}, 'Runner source changed'
        write(out/'summary.json',dict(complete=True,auditPassed=report['passed'],formalBank=args.target==10000,
            count=args.target*len(KINDS),kinds=report['kinds'],threshold=THRESHOLD,parts=parts,
            frozenSourceSHA256=builder.sha(out/'source-binding.json'),currentProductionDrift=drift,
            elapsedSeconds=time.time()-started,finishedAt=time.time()))
        success=True
        (out/'README.md').write_text('# 多球基础球形生成结果\n\n'
            f'已完成 {args.target*len(KINDS):,} 副，4／5／6／9／中八15球各 {args.target:,} 副；统一指数 ≥1.20。\n\n'
            '中八使用时随机删球，不评价残局。母球落袋保留标记，自由球上手。\n\n'
            f'全量重算审计 {report["rawRecordsChecked"]:,} 次开球记录通过；详情见 summary.json、audit.json 和各 bank-*.json.gz。\n\n'
            '本轮复用冻结生产物理；当前源码漂移见summary。资源收尾以closure和生命周期回执为准。App未接入。\n')
    except BaseException as exc:
        failure=repr(exc); write(out/'failure.json',dict(error=failure,traceback=traceback.format_exc(),at=time.time())); raise
    finally:
        shutdown=subprocess.run(['xcrun','simctl','shutdown',args.uid],capture_output=True,text=True) if booted else None
        write(out/'closure.json',dict(generationSucceeded=success,error=failure,
            shutdownExitCode=None if shutdown is None else shutdown.returncode,finishedAt=time.time()))
        if shutdown is not None and shutdown.returncode: raise RuntimeError(shutdown.stderr)

if __name__=='__main__': main()
