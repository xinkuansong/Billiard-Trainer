from pathlib import Path
import subprocess
import json
import struct
import math
import random
import sys

root = Path(__file__).resolve().parents[3]
directory='c1-samples' if '--samples' in sys.argv else ('c1-integral-r2' if '--ring' in sys.argv else 'c1-integral')
out = root / 'output/render-activity-20261113' / directory
b3 = root / 'output/render-activity-20261113/b3'
boundary = out / 'boundary'
boundary.mkdir(exist_ok=True)
rng = random.Random(20261113)
floats = []
for i in range(4096):
    p = [rng.uniform(-1.5, 1.5), rng.choice([.8, .79999, 0, 3, 3.001]), rng.uniform(-.9, .9)]
    n = [rng.uniform(-1, 1) for _ in range(3)]
    if i < 2048:
        # Normals around a lamp-corner horizon; independent cross-product construction.
        corner = [rng.choice([-2.54, 2.54]), 3, rng.choice([-1.27, 0, 1.27])]
        d = [corner[j]-p[j] for j in range(3)]
        n = [-d[1], d[0], 0]
        if sum(x*x for x in n) < 1e-12:
            n = [0, -d[2], d[1]]
        n = [n[j]+d[j]*rng.choice([-1e-7, 0, 1e-7]) for j in range(3)]
    length = math.sqrt(sum(x*x for x in n))
    if length < 1e-10:
        n = [0, 1, 0]
    else:
        n = [x/length for x in n]
    floats.extend(p+[0]+n+[0]+[.1, .9, .2, rng.uniform(.01,1)])
(boundary / 'samples.bin').write_bytes(struct.pack('<'+'f'*len(floats), *floats))
(boundary / 'balls.bin').write_bytes(bytes(256))
fixtures = [boundary] + sorted(p for p in (root/'output/render-lowdim-20261113/support-legacy-stress-r2/inputs').iterdir() if p.is_dir())
rows=[]
for mode in (['fast','strict'] if '--ring' in sys.argv or '--samples' in sys.argv else ['strict','fast']):
    for fixture in fixtures:
        dest=out/'validation'/mode/fixture.name
        dest.parent.mkdir(parents=True,exist_ok=True)
        args=[str(b3/(mode+'-validate')),str(out/'candidate.metal'),str(fixture/'samples.bin'),str(fixture/'balls.bin'),str(dest),'1']
        p=subprocess.run(args,capture_output=True,text=True,timeout=45)
        (dest.parent/(fixture.name+'.log')).write_text(p.stdout+p.stderr)
        validation=json.loads((dest/'validation.json').read_text()) if (dest/'validation.json').exists() else {}
        passed=p.returncode==0 and validation.get('changedMasks')==0
        rows.append({'mode':mode,'fixture':str(fixture),'exitCode':p.returncode,'passed':passed,'validation':validation})
        (out/'validation.json').write_text(json.dumps(rows,indent=2)+'\n')
        if not passed:
            print(mode,fixture.name,'FAILED',validation,flush=True)
            raise SystemExit(1)
    print(mode,len(fixtures),'exact validation cases passed',flush=True)
performance=[]
for pose in ['single-low','single-near','edge-low','rack-overview','scatter-overview']:
    fixture=root/'output/render-lowdim-20261113/pixel-lowk-r3'/pose
    for arm in ['aa','candidate']:
        dest=out/'benchmark'/pose/arm;dest.parent.mkdir(parents=True,exist_ok=True)
        p=subprocess.run([str(b3/'benchmark'),str(out/(arm+'.metal')),str(fixture/'samples.bin'),str(fixture/'balls.bin'),str(dest),'8'],capture_output=True,text=True,timeout=45)
        (dest.parent/(arm+'.log')).write_text(p.stdout+p.stderr)
        result=json.loads((dest/'result.json').read_text()) if (dest/'result.json').exists() else {}
        performance.append({'pose':pose,'arm':arm,'exitCode':p.returncode,'result':result})
        (out/'performance.json').write_text(json.dumps(performance,indent=2)+'\n')
        print(pose,arm,p.returncode,result.get('pairedChangeMedianPercent'),flush=True)
        if p.returncode:raise SystemExit(1)
