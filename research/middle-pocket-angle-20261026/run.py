"""Frozen production native worker; no App policy or geometry mutations."""
from pathlib import Path
import hashlib, json, os, select, subprocess, sys, time, traceback
import build

OUT=build.OUT
def write(p,x):
    p=Path(p); tmp=p.with_suffix(p.suffix+'.partial')
    tmp.write_text(json.dumps(x,ensure_ascii=False,indent=2,allow_nan=False));tmp.replace(p)
class Worker:
    def __init__(self,uid,binary):
        self.log=(OUT/'native.log').open('w')
        self.p=subprocess.Popen(['xcrun','simctl','spawn',uid,str(binary)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=self.log,text=True,bufsize=1)
        self.ready=self.receive('READY')
    def receive(self,tag):
        deadline=time.monotonic()+120
        while time.monotonic()<deadline:
            if not select.select([self.p.stdout],[],[],max(0,deadline-time.monotonic()))[0]:break
            line=self.p.stdout.readline()
            if not line:raise RuntimeError(f'Worker exited {self.p.poll()}')
            if line.startswith(tag+'\t'):return json.loads(line.split('\t',1)[1])
            if line.startswith('ERROR\t'):raise RuntimeError(line)
            self.log.write(line);self.log.flush()
        raise TimeoutError('Native worker exceeded response deadline')
    def run(self,x):
        self.p.stdin.write(json.dumps(x)+'\n');self.p.stdin.flush();return self.receive('RESULT')
    def close(self):
        self.p.stdin.close()
        try:self.p.wait(timeout=15)
        except subprocess.TimeoutExpired:self.p.terminate();self.p.wait(timeout=15)
        self.log.close();return self.p.returncode

def job(a,d,s,step=4,side=-1,hand=1,mode='sliding',trace=False):
    return dict(angle=a,distance=d,speed=s,side=side,hand=hand,mode=mode,trace=trace,
                offsets=[i/1000 for i in range(-80,81,step)])
def main(uid):
    assert not (OUT/'coarse.jsonl').exists(),'Never overwrite observations'
    write(OUT/'protocol.json',dict(angle='at mouth line center (0,+/-innerWidth/2); 0 normal, 90 parallel',
        distances=[.15,.3,.6,.9,1.2],speeds=[1,2,4],coarseAngleStep=2,coarseOffsetStepMM=4,
        offsetPlane='physical hole center Z, X offsets -80..80 mm',spin='zero initial omega / sliding; rolling controls',
        direct='requested pocket, no main cushion or nonlocal jaw before capture; own jaw allowed',
        scope='single object ball; current App planar model; finite search, not proof for all spin/speed/positions'))
    binary=build.build()
    write(OUT/'run-start.json',dict(device=uid,pid=os.getpid(),work=os.environ['QIUJI_TEST_WORK'],evidence=os.environ['QIUJI_TEST_EVIDENCE'],startedAt=time.time()))
    boot=False;w=None;success=False;shots=0
    try:
        subprocess.run(['xcrun','simctl','boot',uid],check=True,capture_output=True);boot=True
        subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True,capture_output=True)
        w=Worker(uid,binary);write(OUT/'metadata.json',w.ready)
        def phase(name,jobs):
            nonlocal shots
            rows=[]
            with (OUT/(name+'.jsonl')).open('x') as f:
                for n,x in enumerate(jobs):
                    row=w.run(x);assert row['input']==x
                    # Every actual simulation must complete. Invalid starting positions are separate.
                    assert all(r['termination']=='settled' for r in row.get('results',[])),row
                    shots+=len(row.get('results',[]));rows.append(row)
                    f.write(json.dumps(row,separators=(',',':'),allow_nan=False)+'\n');f.flush()
                    if n%20==0:write(OUT/'progress.json',dict(phase=name,jobs=n+1,simulations=shots,updatedAt=time.time()))
            print(name,len(rows),'positions;',shots,'cumulative simulations',flush=True)
            return rows
        coarse=phase('coarse',(job(a,d,s) for d in [.15,.3,.6,.9,1.2] for s in [1,2,4] for a in range(0,89,2)))
        bounds=[]
        for d in [.15,.3,.6,.9,1.2]:
            for s in [1,2,4]:
                group=[r for r in coarse if r['input']['distance']==d and r['input']['speed']==s and r['valid']]
                for metric in ['direct','cleanPot']:
                    good=[r['input']['angle'] for r in group if any(v[metric] for v in r['results'])]
                    bounds.append(dict(distance=d,speed=s,metric=metric,maxAngle=max(good) if good else None))
        write(OUT/'coarse-summary.json',bounds);print(json.dumps(bounds),flush=True)
        refineJobs={}
        for b in bounds:
            if b['maxAngle'] is None:continue
            # Both clean and jaw-assisted boundary neighborhoods, plus next coarse bin.
            for a4 in range(max(0,int((b['maxAngle']-2)*4)),min(352,int((b['maxAngle']+4)*4))+1):
                x=job(a4/4,b['distance'],b['speed'],2)
                refineJobs[(a4,b['distance'],b['speed'])]=x
        fine=phase('fine',refineJobs.values())
        allRows=coarse+fine
        finalBounds=[]
        for d in [.15,.3,.6,.9,1.2]:
            for s in [1,2,4]:
                group=[r for r in allRows if r['input']['distance']==d and r['input']['speed']==s and r['valid']]
                entry=dict(distance=d,speed=s)
                for metric in ['direct','cleanPot']:
                    good=[r for r in group if any(v[metric] for v in r['results'])]
                    entry[metric]=max((r['input']['angle'] for r in good),default=None)
                finalBounds.append(entry)
        write(OUT/'boundary-summary.json',finalBounds);print(json.dumps(finalBounds),flush=True)
        checks=[]
        for b in finalBounds:
            for a in sorted(set([0,45,60,b['direct'],b['direct']+.25])):
                for side,hand,mode in [(-1,-1,'sliding'),(1,1,'sliding'),(1,-1,'sliding'),(-1,1,'rolling')]:
                    checks.append(job(a,b['distance'],b['speed'],2,side,hand,mode))
        controls=phase('controls',checks)
        examples=[]
        for a in [0,45,60,65,70,75,80]:
            x=job(a,.6,2,2,trace=True)
            # Select both nominal and the best admitted offset from the existing observations.
            candidates=[r for r in allRows if r['input']['angle']==a and r['input']['distance']==.6 and r['input']['speed']==2]
            opts=[v for r in candidates for v in r['results'] if v['direct']]
            best=min(opts,key=lambda v:abs(v['offset']))['offset'] if opts else 0
            x['offsets']=sorted(set([0,best]));examples.append(x)
        phase('examples',examples)
        replays=[]
        for old in fine[::max(1,len(fine)//12)]:
            new=w.run(old['input']);assert old==new
            replays.append(old['input'])
        write(OUT/'replays.json',dict(passed=True,cases=replays))
        binding=json.loads((OUT/'source-binding.json').read_text())
        drift=[r['path'] for r in binding['production'] if build.sha(build.ROOT/r['path'])!=r['sha256']]
        assert not drift,drift
        write(OUT/'generation.json',dict(complete=True,simulations=shots,replays=len(replays),sourceDrift=drift,finishedAt=time.time()))
        success=True
    finally:
        code=w.close() if w else None
        shut=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True,text=True) if boot else None
        write(OUT/'closure.json',dict(succeeded=success,workerExit=code,shutdownExit=None if shut is None else shut.returncode))
        if w:assert code==0
        if shut:assert shut.returncode==0,shut.stderr
if __name__=='__main__':
    try:main(sys.argv[1])
    except BaseException:
        write(OUT/'error.json',dict(traceback=traceback.format_exc()));raise
