"""Quarter-table / per-angle randomized kick examples, isolated from the app."""
from pathlib import Path
import importlib.util, json, os, random, math, subprocess, sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = ROOT / 'output/kick-grid-sample-20261030'

def prepare():
    g = json.loads((OUT/'geometry.json').read_text())
    L, W, R = g['length'], g['width'], g['radius']
    rng = random.Random(20261030)
    rays, seeds = [], []
    for ix in range(12):
        for iz in range(6):
            for deg in range(0, 360, 5):
                # New random position for EVERY angle; same position across speeds/spins.
                cue = [rng.uniform(max(-L/2+R, -L/2+ix*L/24), -L/2+(ix+1)*L/24),
                       rng.uniform(max(-W/2+R, -W/2+iz*W/12), -W/2+(iz+1)*W/12)]
                ray = dict(cell=ix*6+iz, ix=ix, iz=iz, degrees=deg, cue=cue,
                           dir=[math.cos(math.radians(deg)), math.sin(math.radians(deg))])
                rays.append(ray)
                for v in [1.5, 2.5, 3.5, 4.5]:
                    for sx in [0, -.25, .25, -.5, .5]:
                        seeds.append(dict(ray, id=f'C{ix*6+iz:02d}-A{deg:03d}-V{v}-S{sx}',
                                          side=-1, slot=deg//5, rail=-1, railPoint=[0,0], initialAngle=0,
                                          v=v, sx=sx, sy=0,
                                          samples=[[rng.random(), rng.uniform(-.9,.9)] for _ in range(18)]))
    rng.shuffle(seeds)
    assert len(rays)==5184 and len(seeds)==103680
    assert len({tuple(r['cue']) for r in rays})==5184
    (OUT/'sampling.json').write_text(json.dumps(dict(randomSeed=20261030, quarter='X<=0,Z<=0', rays=rays)))
    (OUT/'seeds.json').write_text(json.dumps(seeds,separators=(',',':')))
    print('PREPARED', len(rays), 'random positions;', len(seeds), 'parameter combinations',flush=True)

def main():
    if len(sys.argv)==1:
        spec=importlib.util.spec_from_file_location('kick_build',ROOT/'research/k-ball-placement-20261029/build.py')
        mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
        mod.HERE=HERE; mod.OUT=OUT
        app=mod.build()
        subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','notch-phone',
                        '--task','kick-grid-sample-20261030','--',sys.executable,__file__,'worker','{udid}',str(app/'Worker')],check=True)
        subprocess.run([sys.executable,str(HERE/'audit.py')],check=True)
        render_python=os.environ.get('KICK_RENDER_PYTHON','/Users/song/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3')
        subprocess.run([render_python,str(HERE/'render.py')],check=True)
    else:
        _,uid,worker=sys.argv[1:]
        def run(*args):
            subprocess.run(['xcrun','simctl','spawn',uid,worker,*map(str,args)],check=True)
        subprocess.run(['xcrun','simctl','boot',uid],check=True)
        try:
            subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
            run('geometry',OUT/'geometry.json')
            prepare()
            run('generate',OUT/'seeds.json',OUT)
            run('verify',OUT/'accepted.json',OUT/'verification.json')
        finally:
            subprocess.run(['xcrun','simctl','shutdown',uid],check=True)

if __name__=='__main__': main()
