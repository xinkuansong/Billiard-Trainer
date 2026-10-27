"""Second-stage geometry rules, frozen before new screening/validation seeds."""
import math
import numpy as np
from study import positions as local_positions, front, R, F

POLICIES=['B','C','C_back90','branch1_back90','legacy_back90','gates_half','gates_full']
def positions(g,policy):
    if policy in ['B','C']:return local_positions(g,policy)
    if policy=='legacy_back90':return front.old.positions(g,dict(rotations=dict(feed=0,corefront=0,corerear=0,back=90)))
    slots=np.array(g['slots']);original=np.array([[b['x'],b['z']] for b in g['rack']]);mag=np.linalg.norm(original-slots,axis=1)
    if policy in ['C_back90','branch1_back90']:
        ans=local_positions(g,'C' if policy=='C_back90' else 'branch_1')
        for i in [11,12,13]:
            sign=-1 if slots[i,1]<0 else 1
            t=math.atan2(ans[i][1]-slots[i,1],ans[i][0]-slots[i,0])+sign*math.pi/2
            ans[i]=[F(slots[i,0]+mag[i]*math.cos(t)),F(slots[i,1]+mag[i]*math.sin(t))]
    else:
        p=np.array(local_positions(g,'C'));w=.5 if policy=='gates_half' else 1.
        routes=[(0,1,3,4,w),(0,2,5,4,w),(1,3,6,7,1.),(2,5,9,8,1.)]
        def score(a):
            result=0.
            for parent,node,outer,inner,weight in routes:
                incoming=a[node]-a[parent];incoming/=np.linalg.norm(incoming)
                d1=a[outer]-a[node];d2=a[inner]-a[node];r1=np.linalg.norm(d1);r2=np.linalg.norm(d2)
                margin=(r1-2*R)/float(incoming@(d1/r1))-(r2-2*R)/float(incoming@(d2/r2))
                # Max-min style: prioritize deficient gates; no sub-ULP timing target.
                result+=weight*(min(margin,20e-6)+.05*margin)
            return result
        coords={i:np.array([[F(slots[i,0]+mag[i]*math.cos(t)),F(slots[i,1]+mag[i]*math.sin(t))] for t in np.arange(36)*math.pi/18*(-1 if slots[i,1]<0 else 1)]) for i in range(1,10)}
        for _ in range(3):
            for i in range(1,10):
                best=score(p);bestp=p[i].copy()
                for q in coords[i]:
                    p[i]=q;val=score(p)
                    if val>best+1e-14:best=val;bestp=q.copy()
                p[i]=bestp
        ans=p.tolist()
    assert ans[0]==original[0].tolist()
    for i in range(15):
        assert abs(math.dist(slots[i],ans[i])-mag[i])<1e-7
        assert math.dist(slots[i],ans[i])<.00009015
        for j in range(i):assert math.dist(ans[i],ans[j])-2*R>.0000195
    return ans
