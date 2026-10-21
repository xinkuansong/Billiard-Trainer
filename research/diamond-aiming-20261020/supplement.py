"""Locus/rail sensitivity and 45-degree mental rules, separate from the main cohort."""
import json
import numpy as np
from model import *
from simulate import metric

def main():
    rng=np.random.default_rng(2026102045); n=120000
    a=rng.uniform(R,4-R,n); o=np.c_[a,a]; c=rng.uniform([R,R],[8-R,4-R],(n,2));p=np.zeros((n,2))
    valid=feasible(c,o,p);c,o,p=c[valid],o[valid],p[valid];truth=solve(c,o,p)
    rows=[]
    for noise in [0,.1,.25]:
        generator=np.random.default_rng(9145)
        cn=c+generator.uniform(-noise,noise,c.shape)
        # The observer knows this is a diagonal setup, estimates a from both O coordinates.
        on=o+generator.uniform(-noise,noise,o.shape); an=on.mean(axis=1)
        delta=np.abs(cn[:,0]-cn[:,1]);net=cn.sum(axis=1)-2*an-.25
        estimate=np.arctan2(delta,net)
        safe=(net>0)&(norm(cn-on)>D)
        rows.append(dict(noise=noise,method='45_quarter_correction',**metric(truth['theta'],np.where(safe,estimate,np.nan),np.ones(len(c),bool))))
        halfwrong=((5*delta>3*net)!=(truth['theta']>np.pi/6))&safe
        rows[-1]['half_error_returned']=float(halfwrong.sum()/safe.sum())
    locus=[]
    for real in [False,True]:
        tablep=REAL_P if real else IDEAL_P
        for pi in range(6):
            o=rng.uniform([R,R],[8-R,4-R],(6000,2));u=unit(tablep[pi]-o);g=o-D*u
            mask=inside(g)
            if real: mask&=path_clear(o,capture_endpoint(o,pi))
            o,u,g=o[mask],u[mask],g[mask];normal=np.c_[-u[:,1],u[:,0]]
            for f,theta in zip(FRACTIONS,ANCHORS):
                for sign in [-1,1] if theta else [1]:
                    d=-np.cos(theta)*u+sign*np.sin(theta)*normal
                    endpoint=ray_endpoint(g,d);length=norm(endpoint-g)
                    for step in [1,.5,.25]:
                        snapped=np.round(endpoint/step)*step
                        snapped_angle=np.arctan2(np.abs(cross(u,snapped-g)),-dot(u,snapped-g))
                        for cutoff in [0,1]:
                            selected=length>=cutoff
                            locus.append(dict(model='production' if real else 'ideal',pocket=pi,f=float(f),sign=sign,
                              step=step,min_ray_length=cutoff,**metric(np.full(len(g),theta),snapped_angle,selected)))
    sight=[]
    for physical in np.array(RAW['sights_m'])/UNIT+SHIFT:
        nose=np.clip(physical,[0,0],[8,4]);o=rng.uniform([R,R],[8-R,4-R],(10000,2))
        v=unit(physical-o);w=unit(nose-o);angle=np.arctan2(np.abs(cross(v,w)),dot(v,w))
        sight.append(dict(physical=physical.tolist(),nose=nose.tolist(),offset_grid=float(norm(physical-nose)),
                          mae_deg=float(np.rad2deg(angle.mean())),p95_deg=float(np.rad2deg(np.quantile(angle,.95)))))
    result={'diagonal_noise':rows,'locus_endpoint_rounding':locus,'physical_sight_vs_nose':sight,
      'caveat':'Locus references use exact O/P and internally derived collision center; endpoint error is isolated, not human performance. 45-degree trials assume known diagonal setup.'}
    (HERE/'results/supplement.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print('45-degree valid samples',len(c),'locus strata',len(locus),'physical sights',len(sight))

if __name__=='__main__':main()
