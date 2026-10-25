#!/usr/bin/env python3
"""Bounded 1,000-layout timing; never starts the full bank run."""
import argparse
import concurrent.futures
import hashlib
import json
import math
import multiprocessing
from pathlib import Path
import random
import time

from pocket_geometry_filter import Geometry, layouts
from preview_second_ball_grid import polygon_distance
from filter_second_ball_preview import assess

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/two-ball-second-grid-20261024/benchmark'
SOURCE=ROOT/'output/two-ball-object-distance-sampled-20261024/object-distance-sampled-bank.json'
STATE=None


def initialize(geometry, frozen):
    global STATE
    g=Geometry(**{k:geometry[k] for k in ('length','width','radius')})
    polys=[[(p['x'],p['z']) for p in pocket['lip']] for pocket in geometry['pockets']]
    holes=[((p['center']['x'],p['center']['z']),p['radius']) for p in geometry['pockets']]
    STATE=(g,polys,holes,frozen)


def batch(job):
    number, records, destination=job
    g,polys,holes,frozen=STATE
    r,hx,hz=g.radius,g.length/2,g.width/2
    dx,dz=(g.length-2*r)/12,(g.width-2*r)/6
    rows=[]; kept=0; retries=0
    for lid,cue,obj,pid,angle in records:
        rng=random.Random(int.from_bytes(hashlib.sha256(('second-grid-v1\0'+lid).encode()).digest(),'big'))
        accepted=[]; rejected=dict(path=0,difficulty=0)
        for row in range(6):
            for col in range(12):
                for attempt in range(10000):
                    if lid in frozen:
                        p=frozen[lid][row*12+col]
                    else:
                        p=(-hx+r+(col+.5)*dx+rng.uniform(-.05,.05),-hz+r+(row+.5)*dz+rng.uniform(-.05,.05))
                    valid=(min(hx-abs(p[0]),hz-abs(p[1]))>=r and
                           min(math.dist(p,cue),math.dist(p,obj))>=2*r and
                           all(math.dist(p,c)-rr>=r for c,rr in holes) and
                           all(polygon_distance(p,poly)>=r for poly in polys))
                    if valid: break
                    if lid in frozen: raise ValueError('Frozen sample fails placement checks')
                    retries+=1
                else: raise ValueError('No accepted point in cell')
                a=assess(cue,obj,p,pid,g)
                if a['keep']:
                    best=a['bestSecond']
                    accepted.append([row*12+col,*p,best['pocket'] if best else None,best['score'] if best else None])
                elif any(x!='second_easier' for x in a['reasons']): rejected['path']+=1
                else: rejected['difficulty']+=1
        kept+=len(accepted)
        rows.append(dict(id=lid,candidates=accepted,rejected=rejected))
    payload=''.join(json.dumps(x,separators=(',',':'),allow_nan=False)+'\n' for x in rows).encode()
    (Path(destination)/f'part-{number:03}.jsonl').write_bytes(payload)
    return dict(index=number,layouts=len(records),kept=kept,retries=retries,bytes=len(payload),sha256=hashlib.sha256(payload).hexdigest())


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--sample',type=int,default=1000)
    parser.add_argument('--workers',type=int,nargs='+',default=[1,4,8])
    args=parser.parse_args()
    assert 4<=args.sample<=10000 and all(1<=n<=8 for n in args.workers)
    out=OUT if args.sample==1000 else OUT/f'sample-{args.sample}'
    out.mkdir(parents=True,exist_ok=True)
    start=time.perf_counter()
    raw=SOURCE.read_bytes();bank=json.loads(raw)
    prev=json.loads((OUT.parent/'preview-data.json').read_text())
    assert hashlib.sha256(raw).hexdigest()==prev['sourceSHA256']
    frozen={b['id']:[p['position'] for p in b['points']] for b in prev['boards']}
    all_records=list(layouts(bank));assert len(all_records)==135700
    selected=[x for x in all_records if x[0] in frozen]
    selected+=random.Random(2026102401000).sample([x for x in all_records if x[0] not in frozen],args.sample-4)
    prep=time.perf_counter()-start
    runs=[]
    for workers in args.workers:
        dest=out/f'workers-{workers}';dest.mkdir(exist_ok=True)
        jobs=[(i,selected[j:j+25],str(dest)) for i,j in enumerate(range(0,len(selected),25))]
        start=time.perf_counter()
        with concurrent.futures.ProcessPoolExecutor(max_workers=workers,mp_context=multiprocessing.get_context('spawn'),
                initializer=initialize,initargs=(bank['geometry'],frozen)) as pool:
            results=list(pool.map(batch,jobs))
        elapsed=time.perf_counter()-start
        digest=hashlib.sha256(''.join(x['sha256'] for x in results).encode()).hexdigest()
        run=dict(workers=workers,seconds=elapsed,layoutsPerSecond=args.sample/elapsed,
                 fullBankEstimateSeconds=elapsed*135700/args.sample,bytes=sum(x['bytes'] for x in results),
                 kept=sum(x['kept'] for x in results),retries=sum(x['retries'] for x in results),digest=digest)
        runs.append(run)
        print(json.dumps(run),flush=True)
        (out/'timing.json').write_text(json.dumps(dict(sample=args.sample,candidates=args.sample*72,loadAndExpandSeconds=prep,runs=runs),indent=2)+'\n')
    assert len({x['digest'] for x in runs})==1
    all_saved=[]
    for path in sorted((out/f'workers-{args.workers[0]}').glob('part-*.jsonl')):
        all_saved += [json.loads(s) for s in path.read_text().splitlines()]
    checks={r['id']:len(r['candidates']) for r in all_saved if r['id'] in frozen}
    reference=json.loads((OUT.parent/'filtered-v1/filtered-data.json').read_text())
    assert checks=={b['id']:b['counts']['keep'] for b in reference['boards']}
    assert SOURCE.read_bytes()==raw
    print(f'PASS: worker configurations {args.workers} checked; original four boards reproduce; bank unchanged.',flush=True)


if __name__=='__main__': main()
