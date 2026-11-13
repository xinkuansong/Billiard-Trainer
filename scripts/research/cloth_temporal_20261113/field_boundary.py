"""Independent position/horizon probes; real texture fixtures are tested separately."""
from pathlib import Path
import math,random,struct,json
root=Path(__file__).resolve().parents[3]
out=root/'output/render-activity-20261113/c1-static-field-compact'
rng=random.Random(13112026)
rows=[]
for i in range(32768):
    p=[rng.uniform(-1.7,1.7),rng.uniform(.6,.95),rng.uniform(-1.05,1.05)]
    n=[rng.uniform(-1,1) for _ in range(3)]
    if i<4096:
        axis=i%3
        bounds=[[-1.6,1.6],[.65,.9],[-.95,.95]]
        p[axis]=rng.choice(bounds[axis])+rng.choice([-1e-5,0,1e-5])
    elif i<8192:
        corner=[rng.choice([-2.54,2.54]),3,rng.choice([-1.27,0,1.27])]
        delta=[corner[j]-p[j] for j in range(3)]
        n=[-delta[1],delta[0],0]
        n=[n[j]+delta[j]*rng.choice([-1e-5,0,1e-5]) for j in range(3)]
    norm=math.sqrt(sum(x*x for x in n))
    n=[x/norm for x in n]
    rows.extend(p+[0]+n+[0]+[0,1,0,.8])
(out/'boundary.bin').write_bytes(struct.pack('<'+'f'*len(rows),*rows))
(out/'boundary.json').write_text(json.dumps({'seed':13112026,'count':32768,'domainEdges':4096,'cornerHorizon':4096,'random':24576},indent=2)+'\n')
