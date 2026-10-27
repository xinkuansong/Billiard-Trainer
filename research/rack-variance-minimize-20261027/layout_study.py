"""Geometry-only layout candidates; full native engine used only in offline evaluation."""
from pathlib import Path
import sys,math,statistics as st
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'research/rack-variance-stability-20261027'))
from study import front,R,F,L,seed,metrics,load
from global_study import positions as previous_positions

def definitions():
    out={'E':dict(kind='base'), 'C':dict(kind='C')}
    for c in [0,180]:out[f'center_{c}']=dict(kind='rotate',inner=90,corner=0,center=c)
    for part in ['inner','corner','both']:
        for blend in [.5,1.]:
            for center in [0,90]:out[f'directed_{part}_{blend}_{center}']=dict(kind='directed',part=part,blend=blend,center=center)
    for inner in [30,60,90,120,150]:
        for corner in [0,90,180]:
            if inner==90 and corner==0:continue
            out[f'rotate_{inner}_{corner}']=dict(kind='rotate',inner=inner,corner=corner,center=90)
    out['gate20']=dict(kind='gate',targetUM=20,center=90)
    out['gate50']=dict(kind='gate',targetUM=50,center=0)
    assert len(out)==32
    return out

def positions(g,d):
    if d['kind']=='B':return previous_positions(g,'B')
    if d['kind']=='C':return previous_positions(g,'C')
    c=previous_positions(g,'C');e=previous_positions(g,'C_back90')
    if d['kind']=='base':return e
    slots=np.array(g['slots']);original=np.array([[b['x'],b['z']] for b in g['rack']]);mag=np.linalg.norm(original-slots,axis=1)
    ans=[p[:] for p in e]
    def angle(i,p):return math.atan2(p[i][1]-slots[i,1],p[i][0]-slots[i,0])
    def assign(i,theta):ans[i]=[F(slots[i,0]+mag[i]*math.cos(theta)),F(slots[i,1]+mag[i]*math.sin(theta))]
    assign(12,angle(12,c)+math.radians(d['center']))
    if d['kind']=='rotate':
        for indices,a in [([11,13],d['inner']),([10,14],d['corner'])]:
            for i in indices:assign(i,angle(i,c)+math.radians(a)*(1 if slots[i,1]>0 else -1))
    elif d['kind']=='directed':
        for node,outer,inner in [(6,10,11),(9,14,13)]:
            for i,toward in [(outer,False),(inner,True)]:
                if d['part']=='inner' and not toward or d['part']=='corner' and toward:continue
                v=np.array(e[node])-slots[i] if toward else slots[i]-np.array(e[node])
                target=math.atan2(v[1],v[0]);base=angle(i,e);delta=math.atan2(math.sin(target-base),math.cos(target-base))
                assign(i,base+d['blend']*delta)
    else:
        assert d['kind']=='gate'
        for upstream,node,outer,inner in [(3,6,10,11),(5,9,14,13)]:
            u=np.array(e[node])-e[upstream];u/=np.linalg.norm(u)
            coords=[];cost=[];travel=[]
            for i in [outer,inner]:
                theta=angle(i,e)+np.arange(-36,37)*math.pi/36
                pp=np.array([[F(slots[i,0]+mag[i]*math.cos(t)),F(slots[i,1]+mag[i]*math.sin(t))] for t in theta])
                dp=pp-np.array(e[node]);dist=np.linalg.norm(dp,axis=1);q=(dist-2*R)/(dp@u/dist)
                coords.append(pp);travel.append(q);cost.append(np.arange(-36,37,dtype=float)**2)
            margin=travel[0][:,None]-travel[1][None,:]
            valid=margin>=d['targetUM']*1e-6
            if np.any(valid):
                effort=cost[0][:,None]+cost[1][None,:];score=np.where(valid,effort,np.inf);j,k=np.unravel_index(np.argmin(score),score.shape)
            else:j,k=np.unravel_index(np.argmax(margin),margin.shape)
            ans[outer]=coords[0][j].tolist();ans[inner]=coords[1][k].tolist()
    assert ans[0]==e[0]
    for i in range(15):
        assert abs(math.dist(slots[i],ans[i])-mag[i])<1e-7
        assert math.dist(slots[i],ans[i])<.00009015
        if i not in [10,11,12,13,14]:assert ans[i]==e[i]
        for j in range(i):assert math.dist(ans[i],ans[j])-2*R>.0000195
    return ans

def statistics(rows):
    base={r['id']:r for r in rows if r['policy']=='E'};result=[]
    for p in sorted({r['policy'] for r in rows}):
        a=[r for r in rows if r['policy']==p];ds=[r['variance5']-base[r['id']]['variance5'] for r in a]
        result.append(dict(policy=p,n=len(a),variance=st.mean(r['variance5'] for r in a),delta=st.mean(ds),median=st.median(ds),
            wins=sum(d<-.01 for d in ds),losses=sum(d>.01 for d in ds),strictWins=sum(d<0 for d in ds),
            energyRatio=st.mean(r['energy5'] for r in a)/st.mean(r['energy5'] for r in base.values()),
            worstQuartileVariance=st.mean(sorted(r['variance5'] for r in a)[-max(1,len(a)//4):])))
    return sorted(result,key=lambda r:r['variance'])
