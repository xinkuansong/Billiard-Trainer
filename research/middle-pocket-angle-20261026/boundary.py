"""Cross-check a capture-lip/expanded-jaw tangent envelope with native trajectories."""
from pathlib import Path
import json,math,os,struct,subprocess,sys,traceback
import build,extend
from run import write
OUT=build.OUT/'tangent-check'
def f32(x):return struct.unpack('f',struct.pack('f',x))[0]
def derive(meta):
    h=meta['width']/2
    jaw=min((c for c in meta['circular'] if c['center'][0]>0 and c['center'][2]>h),key=lambda c:c['center'][0])
    cx,_,cz=jaw['center'];R=f32(jaw['radius']+meta['radius'])
    lip=meta['pockets'][5]['lip'];options=[]
    for px,pz in lip:
        A=cx-px;B=cz-pz;length=math.hypot(A,B)
        if length<R:continue
        theta=math.atan2(B,A)+math.acos(R/length)
        if not 0<theta<math.pi/2:continue
        inset=(h-pz)-px/math.tan(theta)
        options.append(dict(theta=math.degrees(theta),inset=inset,point=[px,pz]))
    best=max(options,key=lambda x:x['theta']);theta=math.radians(best['theta'])
    best.update(jaw=jaw,expandedRadius=R,aimOffset=-best['inset']*math.tan(theta),halfWidth=h,
                interpretation='tangent to near expanded jaw and measured capture lip; no-contact geometric envelope, corroborated by native scan')
    for d in [.08,.15,.3,.6,.9,1.2,1.28]:
        beta=theta-math.asin(best['inset']*math.sin(theta)/d)
        x=d*math.sin(beta);y=d*math.cos(beta)
        assert abs(y-x/math.tan(theta)-best['inset'])<1e-12
    return best
def main(uid):
    OUT.mkdir(exist_ok=False);extend.OUT=OUT
    binary=build.build(build.HERE/'main-boundary.swift',OUT)
    write(OUT/'run-start.json',dict(device=uid,work=os.environ['QIUJI_TEST_WORK'],evidence=os.environ['QIUJI_TEST_EVIDENCE']))
    boot=False;w=None;success=False;rows=[]
    try:
        subprocess.run(['xcrun','simctl','boot',uid],check=True,capture_output=True);boot=True
        subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True,capture_output=True)
        w=extend.Worker(uid,binary,0);meta=w.ready;write(OUT/'metadata.json',meta)
        g=derive(meta);write(OUT/'geometry.json',g);print('geometry',json.dumps(g),flush=True)
        theta=math.radians(g['theta']);baseOffset=g['aimOffset']
        with (OUT/'raw.jsonl').open('x') as f:
            for d in [.08,.15,.3,.6,.9,1.2,1.28]:
                beta=math.degrees(theta-math.asin(g['inset']*math.sin(theta)/d))
                for s in [1,2,4]:
                    for delta in [-.1,-.02,-.005,.005,.02,.1]:
                        for side,hand,mode in [(-1,1,'sliding'),(-1,-1,'sliding'),(1,1,'sliding'),(1,-1,'sliding'),(-1,1,'rolling')]:
                            x=extend.make(beta+delta,d,s,side=side,hand=hand,mode=mode)
                            x.update(boundaryBeta=beta,delta=delta)
                            x['offsets']=[hand*(baseOffset+i*.00001) for i in range(-20,21)]
                            row=w.run(x);assert row['valid'];assert row['input']==x
                            assert all(v['termination']=='settled' for v in row['results'])
                            rows.append(row);f.write(json.dumps(row,separators=(',',':'))+'\n');f.flush()
                print('distance',d,'done',len(rows),'positions',flush=True)
        summary=[]
        for d in [.08,.15,.3,.6,.9,1.2,1.28]:
            q=[r for r in rows if r['input']['distance']==d]
            byDelta={str(delta):dict(cases=sum(r['input']['delta']==delta for r in q),
                feasible=sum(r['input']['delta']==delta and any(v['direct'] for v in r['results']) for r in q)) for delta in [-.1,-.02,-.005,.005,.02,.1]}
            summary.append(dict(distance=d,boundaryBeta=q[0]['input']['boundaryBeta'],byDelta=byDelta))
        write(OUT/'summary.json',summary);print(json.dumps(summary),flush=True)
        examples=[]
        for d in [.15,.6,1.2]:
            for delta in [-.02,.02]:
                old=next(r for r in rows if (r['input']['distance'],r['input']['speed'],r['input']['delta'],r['input']['side'],r['input']['hand'],r['input']['mode'])==(d,2,delta,-1,1,'sliding'))
                opts=[v for v in old['results'] if v['direct']]
                offset=min(opts,key=lambda v:abs(v['offset']-baseOffset))['offset'] if opts else baseOffset
                x=old['input']|dict(offsets=[offset],trace=True)
                examples.append(w.run(x))
        write(OUT/'examples.json',examples)
        replays=[]
        for old in rows[::100]:
            assert w.run(old['input'])==old;replays.append(old['input'])
        write(OUT/'replays.json',dict(passed=True,cases=replays))
        binding=json.loads((OUT/'source-binding.json').read_text())
        assert all(build.sha(build.ROOT/r['path'])==r['sha256'] for r in binding['production'])
        write(OUT/'generation.json',dict(complete=True,positions=len(rows),simulations=sum(len(r['results']) for r in rows),sourceDrift=[]))
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
