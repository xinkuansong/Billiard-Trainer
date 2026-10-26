"""Finite pilot; deterministic inputs, durable per-shot JSONL and native replay checks."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import argparse, hashlib, json, os, random, select, subprocess, time
from build import build, ROOT, HERE, OUT, sha

def write(path, data):
    path = Path(path)
    temp = path.with_suffix(path.suffix + '.partial')
    temp.write_text(json.dumps(data, ensure_ascii=False, indent=2))
    temp.replace(path)

class Worker:
    def __init__(self, uid, binary, n):
        self.log = (OUT/f'worker-{n}.log').open('w')
        self.p = subprocess.Popen(['xcrun','simctl','spawn',uid,str(binary)], stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=self.log, text=True, bufsize=1)
        self.ready = self.receive('READY')
    def receive(self, tag):
        until = time.monotonic()+120
        while time.monotonic()<until:
            if not select.select([self.p.stdout], [], [], max(0, until-time.monotonic()))[0]:
                break
            line=self.p.stdout.readline()
            if not line: raise RuntimeError(f'Native process exited: {self.p.poll()}')
            if line.startswith(tag+'\t'):return json.loads(line.split('\t',1)[1])
            if line.startswith('ERROR\t'):raise RuntimeError(line)
            self.log.write(line);self.log.flush()
        raise TimeoutError('Native worker response timeout')
    def run(self, job):
        self.p.stdin.write(json.dumps(job)+'\n');self.p.stdin.flush()
        return self.receive('RESULT')
    def close(self):
        self.p.stdin.close()
        try:self.p.wait(timeout=15)
        except subprocess.TimeoutExpired:
            self.p.terminate();self.p.wait(timeout=15)
        self.log.close()
        assert self.p.returncode==0, self.p.returncode

def part(uid, binary, n, count):
    worker=Worker(uid,binary,n)
    meta=worker.ready
    write(OUT/f'metadata-{n}.json',meta)
    rng=random.Random(202610260000+n)
    rows=[]
    start=time.monotonic()
    try:
        with (OUT/f'raw-{n}.jsonl').open('x') as out:
            for i in range(count):
                job=dict(id=f'break-{n:02}-{i:06}',n=n,seed=str(rng.getrandbits(63)),
                    x=rng.uniform(meta['length']/4,meta['length']/2-meta['radius']),
                    z=rng.uniform(-meta['width']/2+meta['radius'],meta['width']/2-meta['radius']),
                    power=rng.uniform(9.5,10))
                row=worker.run(job)
                out.write(json.dumps(row,separators=(',',':'))+'\n');out.flush();rows.append(row)
                if (i+1)%32==0:
                    write(OUT/f'progress-{n}.json',dict(n=n,done=i+1,total=count,seconds=time.monotonic()-start))
                    print(f'{n} balls: {i+1}/{count}',flush=True)
        # Same production consumer twice; timestamps are diagnostic, excluded from parity.
        eligible=[r for r in rows if r['status']=='settled']
        replay=[]
        for old in eligible[:2]:
            new=worker.run(old['input'])
            for field in ['rack','cue','power','direction','status','termination','pocketed','board']:
                assert new[field]==old[field],(old['input']['id'],field)
            replay.append(old['input']['id'])
        write(OUT/f'replay-{n}.json',dict(passed=True,ids=replay))
    finally:
        worker.close()
        write(OUT/f'closed-{n}.json',dict(pid=meta['pid'],wrapperPID=worker.p.pid,exitCode=worker.p.returncode))
    return dict(n=n,attempts=len(rows),seconds=time.monotonic()-start,sha256=sha(OUT/f'raw-{n}.jsonl'))

def main():
    ap=argparse.ArgumentParser();ap.add_argument('uid');ap.add_argument('--count',type=int,default=256)
    args=ap.parse_args();OUT.mkdir(exist_ok=True)
    assert not list(OUT.glob('raw-*.jsonl')), 'Preserve prior batch; use a new directory for another run.'
    binary=build()
    write(OUT/'run-start.json',dict(device=args.uid,pid=os.getpid(),countPerKind=args.count,
        kinds=[4,5,6,7,8,9,15],startedAt=time.time(),entrySHA256=sha(HERE/'main.swift')))
    booted=False;success=False
    try:
        subprocess.run(['xcrun','simctl','boot',args.uid],check=True,capture_output=True);booted=True
        subprocess.run(['xcrun','simctl','bootstatus',args.uid,'-b'],check=True,capture_output=True)
        with ThreadPoolExecutor(max_workers=3) as executor:
            futures=[executor.submit(part,args.uid,binary,n,args.count) for n in [4,5,6,7,8,9,15]]
            results=[f.result() for f in futures]
        binding=json.loads((OUT/'source-binding.json').read_text())
        for entry in binding['production']:
            assert sha(ROOT/entry['path'])==entry['sha256'],'Production source changed during run'
        write(OUT/'generation.json',dict(completed=True,parts=results,sourceStable=True))
        success=True
    finally:
        shutdown=None
        if booted:
            shutdown=subprocess.run(['xcrun','simctl','shutdown',args.uid],capture_output=True,text=True)
        write(OUT/'closure.json',dict(generationSucceeded=success,shutdownExitCode=None if shutdown is None else shutdown.returncode))
        if shutdown is not None and shutdown.returncode:raise RuntimeError(shutdown.stderr)

if __name__=='__main__':main()
