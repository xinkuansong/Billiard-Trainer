"""Reproducible forward kick-bank research; no production edits."""
from pathlib import Path
import importlib.util, json, os, random, math, subprocess, sys, hashlib
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
OUT=ROOT/'output/kick-bank-sample-20261029'

def prepare():
    g=json.loads((OUT/'geometry.json').read_text()); rng=random.Random(20261029)
    L,W,R=g['length'],g['width'],g['radius']; cells=[]; directions=[]; rejected=[]
    for ix in range(12):
        for iz in range(6):
            x=rng.uniform(max(-L/2+R+.002,-L/2+ix*L/12),min(L/2-R-.002,-L/2+(ix+1)*L/12))
            z=rng.uniform(max(-W/2+R+.002,-W/2+iz*W/6),min(W/2-R-.002,-W/2+(iz+1)*W/6))
            cell={'cell':ix*6+iz,'ix':ix,'iz':iz,'cue':[x,z]};cells.append(cell)
            for side in range(4):
                n=24 if side<2 else 12
                for slot in range(n):
                    u=(slot+rng.random())/n
                    p=[-L/2+u*L,(-1 if side==0 else 1)*W/2] if side<2 else [(-1 if side==2 else 1)*L/2,-W/2+u*W]
                    rail=None
                    for r in g['rails']:
                        a,b=r['start'],r['end']; dx,dz=b[0]-a[0],b[1]-a[1]; ll=math.hypot(dx,dz)
                        t=((p[0]-a[0])*dx+(p[1]-a[1])*dz)/ll
                        cross=abs((p[0]-a[0])*dz-(p[1]-a[1])*dx)/ll
                        if cross<1e-5 and .10<=t<=ll-.10:rail=r;break
                    row=dict(cell=cell['cell'],cue=[x,z],railPoint=p,side=side,slot=slot)
                    if rail is None:row['reason']='pocket-buffer';rejected.append(row);continue
                    dx,dz=p[0]-x,p[1]-z;ll=math.hypot(dx,dz);d=[dx/ll,dz/ll]
                    angle=math.degrees(math.asin(min(1,abs(d[0]*rail['normal'][0]+d[1]*rail['normal'][1]))))
                    # Explicit provisional near-corner rule: both components point outwards.
                    near=L/2-abs(x)<.25 and W/2-abs(z)<.25
                    if near and d[0]*x>0 and d[1]*z>0:row['reason']='near-corner-outward';rejected.append(row);continue
                    if not 20<=angle<=75:row['reason']='initial-angle';rejected.append(row);continue
                    row.update(dir=d,initialAngle=angle,rail=rail['id']);directions.append(row)
    # All 5184 ray proposals are screened; start with two valid directions per cell.
    selected=[]
    for cell in cells:
        choices=[d for d in directions if d['cell']==cell['cell']];rng.shuffle(choices)
        selected.extend(choices[:2])
    seeds=[]
    for i,d in enumerate(selected):
        for v in [1.5,2.5,3.5,4.5]:
            for sx in [0,-.25,.25,-.5,.5]:
                seeds.append(dict(d,id=f'S{i:03d}-V{v}-X{sx}',v=v,sx=sx,sy=0,
                                  samples=[[rng.random(),rng.uniform(-.9,.9)] for _ in range(15)]))
    rng.shuffle(seeds)
    (OUT/'seeds.json').write_text(json.dumps(seeds))
    (OUT/'sampling.json').write_text(json.dumps(dict(randomSeed=20261029,cells=cells,directions=directions,rejected=rejected,selectedDirections=selected),indent=2))
    print('PREPARED',len(directions),'valid rays;',len(seeds),'shot parameter combinations',flush=True)

def main():
    if len(sys.argv)==1:
        spec=importlib.util.spec_from_file_location('kick_build',ROOT/'research/k-ball-placement-20261029/build.py')
        mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
        mod.HERE=HERE;mod.OUT=OUT
        app=mod.build()
        subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','notch-phone','--task','kick-bank-sample-20261029','--',sys.executable,__file__,'worker','{udid}',str(app/'Worker')],check=True)
    else:
        _,uid,worker=sys.argv[1:]
        def run(*args):subprocess.run(['xcrun','simctl','spawn',uid,worker,*map(str,args)],check=True)
        subprocess.run(['xcrun','simctl','boot',uid],check=True)
        try:
            subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
            run('geometry',OUT/'geometry.json')
            prepare()
            run('generate',OUT/'seeds.json',OUT)
            subprocess.run([sys.executable,str(HERE/'pick_samples.py')],check=True)
            run('verify',OUT/'accepted.json',OUT/'verification.json')
            render_python=os.environ.get('KICK_RENDER_PYTHON','/Users/song/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3')
            subprocess.run([render_python,str(HERE/'render.py')],check=True)
        finally:subprocess.run(['xcrun','simctl','shutdown',uid],check=True)
if __name__=='__main__':main()
