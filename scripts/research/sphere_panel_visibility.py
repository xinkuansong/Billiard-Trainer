"""Deterministic sphere/rectangle visibility oracle and analytic strip quadrature.
World metres, XZ table, Y up. No product physics is changed.
"""
import json
import sys
from pathlib import Path
import numpy as np
R=.028575

def oracle(p,c,panel,n=128):
    x=(np.arange(n)+.5)/n*5.08-2.54
    z=(np.arange(n)+.5)/n*1.27-.635+panel
    xx,zz=np.meshgrid(x,z)
    l=np.stack([xx-p[0],np.full_like(xx,3-p[1]),zz-p[2]],axis=-1)
    d=c-p;d2=d@d;ll=(l*l).sum(-1);dot=(l*d).sum(-1)
    blocked=(dot>0)&(dot<ll)&(dot*dot>=(d2-R*R)*ll)
    weight=l[:,:,1]**2/ll**2
    return float((weight*blocked).sum()/weight.sum())

def primitive(z,x,H):
    a=x*x+H*H
    return H*H*(z/(2*a*(a+z*z))+np.arctan(z/np.sqrt(a))/(2*a**1.5))

def analytic(p,c,panel,count):
    dx,h,dz=c-p;H=3-p[1];K=dx*dx+h*h+dz*dz-R*R
    if K<=1e-10:return 1.
    x0,x1=-2.54-p[0],2.54-p[0];z0,z1=panel-.635-p[2],panel+.635-p[2]
    nodes,weights=np.polynomial.legendre.leggauss(count)
    # Exact silhouette bounds in the light-plane X coordinate. At contact,
    # the projection is unbounded (parabola), so intersect the finite panel.
    den=h*h-R*R
    if den>1e-10:
        ext=R*np.sqrt(dx*dx+h*h-R*R)
        x0=max(x0,H*(h*dx-ext)/den);x1=min(x1,H*(h*dx+ext)/den)
    if x1<=x0:return 0.
    x=(x0+x1)/2+nodes*(x1-x0)/2
    a=dz*dz-K;b=2*dz*(dx*x+h*H);cc=(dx*x+h*H)**2-K*(x*x+H*H)
    lo=np.full(count,z0);hi=np.full(count,z1)
    if abs(a)<1e-10:
        for i in range(count):
            if abs(b[i])<1e-10:
                if cc[i]<0:hi[i]=lo[i]
            elif b[i]>0:lo[i]=max(lo[i],-cc[i]/b[i])
            else:hi[i]=min(hi[i],-cc[i]/b[i])
    else:
        disc=b*b-4*a*cc
        root=np.sqrt(np.maximum(0,disc));lo=np.maximum(lo,(-b+root)/(2*a));hi=np.minimum(hi,(-b-root)/(2*a));hi=np.where(disc>=0,hi,lo)
    integral=np.where(hi>lo,primitive(hi,x,H)-primitive(lo,x,H),0)
    blocked=float((integral*weights).sum()*(x1-x0)/2)
    # Full panel integral, evaluated at high order for oracle normalization.
    q,w=np.polynomial.legendre.leggauss(32);xx=-p[0]+q*2.54
    full=float(((primitive(z1,xx,H)-primitive(z0,xx,H))*w).sum()*2.54)
    return float(np.clip(blocked/full,0,1))

def main():
    cases=[]
    for cx,cz in [(0,0),(1.18,.53),(-.8,-.4)]:
      for h in [R,R*1.05,R*2,.15,.35]:
       c=np.array([cx,.8+h,cz])
       for angle in np.linspace(0,2*np.pi,12,endpoint=False):
        for distance in [0,.015,.03,.05,.08,.14,.25,.45]:
         p=np.array([cx+distance*np.cos(angle),.8,cz+distance*np.sin(angle)])
         for panel in [-.635,.635]:
          truth=oracle(p,c,panel);fine=oracle(p,c,panel,256)
          cases.append({'center':c.tolist(),'point':p.tolist(),'panel':panel,'oracle128':truth,'oracle256':fine,
                        **{str(n):analytic(p,c,panel,n) for n in [4,8,12]}})
    stats={}
    for n in [4,8,12]:
     errors=np.array([abs(v[str(n)]-v['oracle256']) for v in cases]);stats[str(n)]={'rmse':float(np.sqrt((errors**2).mean())),'p95':float(np.percentile(errors,95)),'max':float(errors.max())}
    convergence=np.array([abs(v['oracle128']-v['oracle256']) for v in cases])
    stats['oracle_convergence']={'p95':float(np.percentile(convergence,95)),'max':float(convergence.max())}
    assert stats['oracle_convergence']['max'] < .003
    # Geometry anchors: contact point under sphere fully blocked; remote point unblocked.
    for panel in [-.635,.635]:
        assert abs(analytic(np.array([0,.8,0]),np.array([0,.8+R,0]),panel,8)-1)<1e-8
        assert analytic(np.array([1,.8,0]),np.array([0,.8+R,0]),panel,8)<1e-8
    root=Path('build/daily-specialized-20260921');(root/'shadow-oracle.json').write_text(json.dumps({'stats':stats,'cases':cases},indent=2));print(json.dumps(stats,indent=2))
    if '--write-fixture' in sys.argv:
        selected=cases[::53]+sorted(cases,key=lambda x:abs(x['8']-x['oracle256']),reverse=True)[:5]
        Path('QiuJiTests/Fixtures/AnalyticSphereShadow.json').write_text(json.dumps([
            {'point':v['point'],'center':v['center'],'panel':0 if v['panel']<0 else 1,'expected':v['8'],'oracle':v['oracle256']} for v in selected],indent=2))
if __name__=='__main__':main()
