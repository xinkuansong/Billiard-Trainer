"""Frozen jitter protocol + independent uniform subset without replacement."""
import hashlib,random,math

def combinations(layout_id,count=100):
    rng=random.Random(int(hashlib.sha256(('strike-grid-v1\0'+layout_id).encode()).hexdigest(),16))
    tips=[];levels=[i*.15 for i in range(-3,4)]
    for cy in reversed(levels):
        for cx in reversed(levels):
            if max(abs(cx)-.075,0)**2+max(abs(cy)-.075,0)**2>=.25:continue
            for _ in range(10000):
                x,y=rng.uniform(cx-.075,cx+.075),rng.uniform(cy-.075,cy+.075)
                if x*x+y*y<=.25:break
            else:raise RuntimeError('jitter budget exhausted')
            tips.append((x,y))
    speeds=[]
    for i in range(14):
        c=.6+i*.3;speeds.append(rng.uniform(max(.6,c-.15),min(4.5,c+.15)))
    assert len(tips)==45
    full=[dict(comboIndex=i*14+j,tipID=i+1,speedID=j+1,spinX=x,spinY=y,velocity=v) for i,(x,y) in enumerate(tips) for j,v in enumerate(speeds)]
    seed=int(hashlib.sha256(('strike-subset100-v1\0'+layout_id).encode()).hexdigest(),16)
    indices=sorted(random.Random(seed).sample(range(630),count))
    return [full[i] for i in indices]
