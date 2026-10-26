"""Mouth-plane search: preserve first pilot; remove deep-plane intercept truncation."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import json, math, os, select, subprocess, sys, time, traceback
import build
from run import write, job
OUT=build.OUT/'mouth-plane'
class Worker:
    def __init__(self,uid,binary,k):
        self.log=(OUT/f'native-{k}.log').open('w')
        self.p=subprocess.Popen(['xcrun','simctl','spawn',uid,str(binary)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=self.log,text=True,bufsize=1)
        self.ready=self.receive('READY')
    def receive(self,tag):
        end=time.monotonic()+120
        while time.monotonic()<end:
            if not select.select([self.p.stdout],[],[],max(0,end-time.monotonic()))[0]:break
            line=self.p.stdout.readline()
            if not line:raise RuntimeError(f'worker exit {self.p.poll()}')
            if line.startswith(tag+'\t'):return json.loads(line.split('\t',1)[1])
            if line.startswith('ERROR\t'):raise RuntimeError(line)
            self.log.write(line);self.log.flush()
        raise TimeoutError('worker deadline')
    def run(self,x):
        self.p.stdin.write(json.dumps(x)+'\n');self.p.stdin.flush();return self.receive('RESULT')
    def close(self):
        self.p.stdin.close()
        try:self.p.wait(timeout=15)
        except subprocess.TimeoutExpired:self.p.terminate();self.p.wait(timeout=15)
        self.log.close();return self.p.returncode
def make(a,d,s,step=2,side=-1,hand=1,mode='sliding'):
    x=job(a,d,s,side=side,hand=hand,mode=mode)
    x['offsets']=[round(i*step/1000,7) for i in range(-int(100/step),int(100/step)+1)]
    return x
def limits(rows):
    result=[]
    for d,s in sorted({(r['input']['distance'],r['input']['speed']) for r in rows}):
        q=[r for r in rows if r['valid'] and r['input']['distance']==d and r['input']['speed']==s]
        result.append(dict(distance=d,speed=s,**{key:max((r['input']['angle'] for r in q if any(v[key] for v in r['results'])),default=None) for key in ['direct','cleanPot']}))
    return result
def main(uid):
    OUT.mkdir(exist_ok=False)
    write(OUT/'protocol.json',dict(angleOrigin='mouth at X=0,Z=+/-innerWidth/2',aimPlane='Z=+/-innerWidth/2',aimX=[-.1,.1],
        coarse='0..88 deg by 2; X aim by 2mm',fine='boundary +/- 2 degrees by .1; X aim by .5mm',
        distances=[.08,.15,.3,.6,.9,1.2],speed=[1,2,4],note='No threshold from clipped deep-plane pilot is adopted'))
    binary=build.build(build.HERE/'main-mouth.swift',OUT)
    write(OUT/'run-start.json',dict(device=uid,work=os.environ['QIUJI_TEST_WORK'],evidence=os.environ['QIUJI_TEST_EVIDENCE']))
    boot=False;workers=[];success=False;simulations=0
    try:
        subprocess.run(['xcrun','simctl','boot',uid],check=True,capture_output=True);boot=True
        subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True,capture_output=True)
        workers=[Worker(uid,binary,k) for k in range(4)]
        write(OUT/'metadata.json',workers[0].ready)
        def phase(name,jobs):
            nonlocal simulations
            jobs=list(jobs);counts=[0]*4
            def part(k):
                records=[]
                with (OUT/f'{name}-{k}.jsonl').open('x') as f:
                    for x in jobs[k::4]:
                        row=workers[k].run(x);assert row['input']==x
                        assert all(r['termination']=='settled' for r in row.get('results',[])),row
                        f.write(json.dumps(row,separators=(',',':'),allow_nan=False)+'\n');f.flush()
                        records.append(row);counts[k]+=1
                return records
            with ThreadPoolExecutor(max_workers=4) as pool:
                futures=[pool.submit(part,k) for k in range(4)]
                while not all(f.done() for f in futures):
                    write(OUT/'progress.json',dict(phase=name,done=sum(counts),total=len(jobs),updatedAt=time.time()))
                    time.sleep(2)
                rows=[r for f in futures for r in f.result()]
            simulations+=sum(len(r.get('results',[])) for r in rows)
            print(name,len(rows),simulations,'simulations',flush=True)
            return rows
        coarse=phase('coarse',(make(a,d,s) for d in [.08,.15,.3,.6,.9,1.2] for s in [1,2,4] for a in range(0,89,2)))
        bounds=limits(coarse);write(OUT/'coarse-summary.json',bounds);print(json.dumps(bounds),flush=True)
        jobs={}
        for b in bounds:
            for metric in ['direct','cleanPot']:
                if b[metric] is None:continue
                for a10 in range(max(0,int((b[metric]-1)*10)),min(880,int((b[metric]+3)*10))+1):
                    # Boundary windows use full mouth width, not a guessed optimum band.
                    jobs[(a10,b['distance'],b['speed'])]=make(a10/10,b['distance'],b['speed'],.5)
        fine=phase('fine',jobs.values());final=limits(coarse+fine)
        write(OUT/'boundary-summary.json',final);print(json.dumps(final),flush=True)
        jobs=[]
        for b in final:
            for a in sorted(set([0,60,b['direct'],b['direct']+.1,75,80])):
                for side,hand,mode in [(-1,-1,'sliding'),(1,1,'sliding'),(1,-1,'sliding'),(-1,1,'rolling')]:
                    jobs.append(make(a,b['distance'],b['speed'],.5,side,hand,mode))
        controls=phase('controls',jobs)
        # Dense high-angle rolling scan tests for islands beyond the sliding boundary.
        phase('rolling-tail',(make(a,d,s,1,mode='rolling') for d in [.08,.15,.3,.6,.9,1.2] for s in [1,2,4] for a in range(65,89)))
        examples=[]
        for d in [.15,.6,1.2]:
            group=[r for r in coarse+fine if r['input']['distance']==d and r['input']['speed']==2 and r['valid']]
            b=next(b for b in final if b['distance']==d and b['speed']==2)
            for a in [0,60,b['direct'],round(b['direct']+.1,1),75,80]:
                rs=[r for r in group if r['input']['angle']==a]
                opts=[v for r in rs for v in r['results'] if v['direct']]
                best=min(opts,key=lambda v:abs(v['offset']))['offset'] if opts else 0
                x=make(a,d,2);x['trace']=True;x['offsets']=sorted(set([0,best]));examples.append(x)
        phase('examples',examples)
        replay=[]
        for old in fine[::max(1,len(fine)//16)]:
            new=workers[0].run(old['input']);assert new==old;replay.append(old['input'])
        write(OUT/'replays.json',dict(passed=True,cases=replay))
        binding=json.loads((OUT/'source-binding.json').read_text())
        drift=[r['path'] for r in binding['production'] if build.sha(build.ROOT/r['path'])!=r['sha256']]
        assert not drift,drift
        write(OUT/'generation.json',dict(complete=True,simulations=simulations,replays=len(replay),sourceDrift=drift))
        success=True
    finally:
        codes=[w.close() for w in workers]
        shut=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True,text=True) if boot else None
        write(OUT/'closure.json',dict(succeeded=success,workerExits=codes,shutdownExit=None if shut is None else shut.returncode))
        assert all(c==0 for c in codes)
        if shut:assert shut.returncode==0,shut.stderr
if __name__=='__main__':
    try:main(sys.argv[1])
    except BaseException:
        write(OUT/'error.json',dict(traceback=traceback.format_exc()));raise
