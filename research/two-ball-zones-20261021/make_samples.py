"""Deterministic layout sketches; geometry only, not physics-certified questions."""
import json
import math
import random
from pathlib import Path

OUT = Path(__file__).parent
R, L, H = .028575, 2.54, 1.27
POCKETS = [(-.042, -.042), (2.582, -.042), (-.042, 1.312),
           (2.582, 1.312), (1.27, -.04096474), (1.27, 1.31096474)]
def add(a,b): return tuple(x+y for x,y in zip(a,b))
def sub(a,b): return tuple(x-y for x,y in zip(a,b))
def mul(a,s): return tuple(x*s for x in a)
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def norm(a): return math.hypot(*a)
def unit(a): return mul(a, 1/norm(a))
def rotate(a,t): return (a[0]*math.cos(t)-a[1]*math.sin(t), a[0]*math.sin(t)+a[1]*math.cos(t))
def inside(a, margin=.08): return margin < a[0] < L-margin and margin < a[1] < H-margin
def segdist(p,a,b):
    d=sub(b,a); t=max(0,min(1,dot(sub(p,a),d)/dot(d,d)))
    return norm(sub(p,add(a,mul(d,t))))

def zonepoint(b2,p2,theta,distance):
    u=unit(sub(POCKETS[p2],b2)); g=sub(b2,mul(u,2*R))
    a=math.radians(theta); w=rotate(mul(u,-1),a)
    s=-2*R*math.cos(a)+math.sqrt(distance**2-(2*R*math.sin(a))**2)
    return add(g,mul(w,s))

CONFIG = [
 ("D1","默认 · 右上角袋",(1.72,.38),1,.40,10,.20,.60),
 ("D2","默认 · 左下角袋",(.82,.75),2,.43,-12,.20,.60),
 ("D3","默认 · 上中袋",(1.28,.40),4,.38,8,.20,.60),
 ("N1","放近 · 右上角袋",(1.80,.42),1,.16,10,.12,.60),
 ("N2","放近 · 左下角袋",(.48,.90),2,.16,-12,.12,.60),
 ("N3","放近 · 下中袋",(1.35,.85),5,.16,8,.12,.60),
 ("F1","放远 · 右上角袋",(2.18,.28),1,.77,10,.20,.90),
 ("F2","放远 · 左下角袋",(.30,.98),2,.78,-12,.20,.90),
 ("F3","放远 · 上中袋",(1.27,.22),4,.76,8,.20,.90),
]
samples=[]
rng=random.Random(20261021)
for id,title,b2,p2,d,theta,dmin,dmax in CONFIG:
    stop=zonepoint(b2,p2,theta,d)
    options=[]
    for _ in range(45000):
        b1=(rng.uniform(.18,L-.18),rng.uniform(.16,H-.16))
        p1=rng.choice([p for p in range(6) if p!=p2])
        u=unit(sub(POCKETS[p1],b1)); ghost=sub(b1,mul(u,2*R))
        v=sub(stop,ghost); travel=norm(v)
        if not .15<travel<.65: continue
        error=abs(dot(v,u))
        if error>.004: continue
        tangent=unit(sub(v,mul(u,dot(v,u))))
        cut=math.radians(28)
        incoming=add(mul(u,math.cos(cut)),mul(tangent,math.sin(cut)))
        cue=sub(ghost,mul(incoming,.48))
        if not inside(cue) or not inside(ghost): continue
        if min(norm(sub(b1,b2)),norm(sub(cue,b2)))<.18: continue
        if segdist(b2,cue,ghost)<2*R+.02: continue
        if segdist(b2,b1,POCKETS[p1])<2*R+.02: continue
        if segdist(b2,ghost,stop)<2*R+.02: continue
        if segdist(b1,b2,POCKETS[p2])<2*R+.04: continue
        # Prefer compact first-shot positions and moderate object-ball pot distance.
        score=error*30+abs(travel-.30)+abs(norm(sub(POCKETS[p1],b1))-.65)*.2
        options.append((score,b1,cue,p1,error))
    assert options,id
    _,b1,cue,p1,error=min(options)
    sample=dict(id=id,title=title,cue=cue,b1=b1,b2=b2,p1=p1,p2=p2,
                dmin=dmin,dmax=dmax,probe=stop,probeDistance=d,
                constructionResidual=error)
    samples.append(sample)

checks=0
for s in samples:
    balls=[s[k] for k in ["cue","b1","b2"]]
    assert all(inside(p) for p in balls)
    assert all(norm(sub(a,b))>2*R for i,a in enumerate(balls) for b in balls[i+1:])
    for deg in range(-20,21):
        for d in [s["dmin"],s["dmax"]]:
            pt=zonepoint(s["b2"],s["p2"],deg,d)
            assert abs(norm(sub(pt,s["b2"]))-d)<1e-10
            u=unit(sub(POCKETS[s["p2"]],s["b2"]))
            ghost=sub(s["b2"],mul(u,2*R))
            v=unit(sub(pt,ghost))
            angle=math.degrees(math.atan2((-u[0])*v[1]-(-u[1])*v[0],dot(mul(u,-1),v)))
            assert abs(angle-deg)<1e-9
            checks+=1
    assert inside(s["probe"],R)
    assert s["dmin"]<=s["probeDistance"]<=s["dmax"]

payload=dict(coordinates="metres; origin at top-left playing surface; x right, y down",
             length=L,width=H,ballRadius=R,pockets=POCKETS,samples=samples,
             validation=dict(boundarySamples=checks,geometry="passed",
                             physics="not run",aimAxis="nominal pocket centre; not effectivePocketAimPoint",
                             note="Layouts and probes are proposals, not solved shots."))
(OUT/"samples.json").write_text(json.dumps(payload,ensure_ascii=False,indent=2))
print(json.dumps(dict(samples=len(samples),boundaryChecks=checks,physics="not run")))
for s in samples:
    print(s["id"],"cue",tuple(round(v,3) for v in s["cue"]),"b1",tuple(round(v,3) for v in s["b1"]),"b2",s["b2"],"pockets",s["p1"],s["p2"])
