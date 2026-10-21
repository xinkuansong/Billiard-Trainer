"""Reproducible comparison; all accuracy claims refer to this declared distribution."""
import csv, hashlib, json
from pathlib import Path
import numpy as np
from model import *

OUT=HERE/'results'
SEED=20261020

def generate(real,n_per_pocket=20000):
    rng=np.random.default_rng(SEED+int(real))
    cs=[]; os=[]; ps=[]; ids=[]; attempts=[]
    pockets=REAL_P if real else IDEAL_P
    for pocket,p in enumerate(pockets):
        count=0; drawn=0; accepted=0
        while count<n_per_pocket:
            n=25000
            c=rng.uniform([R,R],[8-R,4-R],(n,2))
            o=rng.uniform([R,R],[8-R,4-R],(n,2))
            mask=feasible(c,o,p,real,pocket)
            selected=np.flatnonzero(mask)[:n_per_pocket-count]
            cs.append(c[selected]); os.append(o[selected]); ps.append(np.tile(p,(len(selected),1)))
            ids.append(np.full(len(selected),pocket)); count+=len(selected)
            drawn+=n; accepted+=int(mask.sum())
        attempts.append(dict(pocket=pocket,drawn=drawn,geometrically_valid=accepted,retained=count))
    return np.concatenate(cs),np.concatenate(os),np.concatenate(ps),np.concatenate(ids),attempts

def metric(truth,pred,mask):
    valid=mask&np.isfinite(pred)
    e=np.rad2deg(np.abs(pred[valid]-truth[valid])); f=np.abs(np.sin(pred[valid])-np.sin(truth[valid]))
    count=int(mask.sum()); returned=int(valid.sum())
    return dict(n=count,returned=returned,coverage=returned/max(count,1),
        mae_deg=float(np.mean(e)) if returned else None,
        p95_deg=float(np.quantile(e,.95)) if returned else None,
        max_deg=float(np.max(e)) if returned else None,
        fraction_mae=float(np.mean(f)) if returned else None,
        fraction_p95=float(np.quantile(f,.95)) if returned else None,
        within3_all=float(np.sum(e<=3)/max(count,1)),within5_all=float(np.sum(e<=5)/max(count,1)))

def masks(q,ids,o,p):
    yield 'all','all',np.ones(len(ids),bool)
    for lo,hi in [(D,.5),(.5,1),(1,2),(2,4),(4,10)]:
        yield 'distance_grid',f'{lo:.3f}–{hi}',(q['r']>=lo)&(q['r']<hi)
    for lo,hi in [(0,15),(15,30),(30,45),(45,60),(60,75),(75,90)]:
        angle=np.rad2deg(q['theta'])
        yield 'cut_deg',f'{lo}–{hi}',(angle>=lo)&(angle<hi)
    for lo,hi in [(0,.125),(.125,.25),(.25,.5),(.5,.75),(.75,1.000001)]:
        yield 'fraction',f'{lo}–{min(hi,1)}',(q['f']>=lo)&(q['f']<hi)
    for i in range(6): yield 'pocket',str(i),ids==i
    yield 'screen','r>=2,OP>=1,theta<=60',(q['r']>=2)&(norm(p-o)>=1)&(q['theta']<=np.pi/3)
    yield 'screen','theta<=61.045',q['theta']<=ANCHORS[-1]
    for lo,hi in [(0,.5),(.5,1),(1,2),(2,10)]:
        yield 'OP_grid',f'{lo}–{hi}',(norm(p-o)>=lo)&(norm(p-o)<hi)

def special45():
    rng=np.random.default_rng(SEED+45); n=200000
    a=rng.uniform(R,4-R,n); o=np.stack([a,a],axis=-1)
    c=rng.uniform([R,R],[8-R,4-R],(n,2)); p=np.zeros((n,2))
    q=solve(c,o,p); valid=feasible(c,o,p)
    estimate=np.arctan2(np.abs(c[:,0]-c[:,1]),c.sum(axis=1)-2*a-.25)
    result={'n_valid':int(valid.sum()),'coefficient_exact':float(np.sqrt(2)*D),
            'quarter_approx':metric(q['theta'],estimate,valid)}
    for threshold in [.25,.5,1,2]:
        result[f'BminusD>={threshold}']=metric(q['theta'],estimate,valid&(q['h']>=threshold))
    return result

def diameter_grid():
    rows=[]
    for r in [1.01*D,2*D,.5,1,2,3,4,6,8]:
        for theta in [5,15,30,45,60,75,85]:
            t=np.deg2rad(theta)
            L=-D*np.cos(t)+np.sqrt(r*r-D*D*np.sin(t)**2)
            alpha=np.arctan2(L*np.sin(t),D+L*np.cos(t))
            rows.append(dict(distance_grid=float(r),theta=theta,alpha=float(np.rad2deg(alpha)),
                             ignored_error_deg=float(theta-np.rad2deg(alpha))))
    return rows

def main():
    OUT.mkdir(exist_ok=True)
    rows=[]; manifest={'seed':SEED,'n_per_model':120000,'draw':'uniform independent C/O in radius-inset rectangle; equal retained count per pocket',
      'noise':'independent uniform per Cx,Cy,Ox,Oy; fixed P; no clipping or resampling; one realization per amplitude; rejected predictions retained in denominator',
      'models':{},'methods':list(predictions(np.array([[4.,2.]]),np.array([[2.,2.]]),np.array([[0.,0.]])).keys())}
    fixtures=[]; half_rows=[]
    for real in [False,True]:
        label='production' if real else 'ideal'
        c,o,p,ids,attempts=generate(real)
        q=solve(c,o,p)
        # Independent center-circle intersection verification (incoming ray first root).
        e=unit(q['g']-c); w=c-o
        disc=dot(w,e)**2-(dot(w,w)-D*D)
        root=-dot(w,e)-np.sqrt(np.maximum(disc,0))
        hit=c+root[:,None]*e
        normal=unit(o-hit)
        independent=np.arccos(np.clip(dot(e,normal),-1,1))
        residual=float(np.max(np.abs(independent-q['theta'])))
        assert residual<2e-7,(label,residual)
        assert np.max(norm(hit-q['g']))<2e-8
        manifest['models'][label]={'attempts':attempts,'samples_sha256':hashlib.sha256(c.tobytes()+o.tobytes()+p.tobytes()).hexdigest(),
                                  'independent_max_error_deg':float(np.rad2deg(residual))}
        selections=list(masks(q,ids,o,p))
        for noise in [0,.1,.25]:
            rng=np.random.default_rng(SEED+100+int(real))
            cn=c+rng.uniform(-noise,noise,c.shape); on=o+rng.uniform(-noise,noise,o.shape)
            nq=solve(cn,on,p)
            pred=predictions(cn,on,p)
            mismatch=np.sign(nq['signed_a'])!=np.sign(q['signed_a'])
            # Five-to-three comparison: A/H approximately 3/5 for half-ball.
            for margin in [0,3,5]:
                selected=np.abs(np.rad2deg(q['theta'])-30)>margin
                returned=selected&nq['valid']
                wrong=((5*nq['a']>3*nq['h']) != (q['theta']>np.pi/6))&returned
                half_rows.append(dict(model=label,noise=noise,exclude_boundary_degrees=margin,n=int(selected.sum()),
                    returned=int(returned.sum()),wrong=int(wrong.sum()),error_returned=float(wrong.sum()/max(returned.sum(),1))))
            for method,estimate in pred.items():
                for grouping,band,mask in selections:
                    row=dict(model=label,noise_grid=noise,method=method,group=grouping,band=band,**metric(q['theta'],estimate,mask))
                    valid=mask&np.isfinite(estimate)
                    directed=np.where(mismatch[valid],estimate[valid]+q['theta'][valid],np.abs(estimate[valid]-q['theta'][valid]))
                    row['side_mismatch_all']=float(np.sum(valid&mismatch)/max(int(mask.sum()),1))
                    row['signed_p95_deg']=float(np.rad2deg(np.quantile(directed,.95))) if len(directed) else None
                    row['signed_within5_all']=float(np.sum(directed<=np.deg2rad(5))/max(int(mask.sum()),1))
                    rows.append(row)
            print(label,'noise',noise, 'n',len(c),flush=True)
        for index in np.linspace(0,len(c)-1,60,dtype=int):
            fixtures.append(dict(model=label,c=c[index].tolist(),o=o[index].tolist(),p=p[index].tolist(),
              theta=float(q['theta'][index]),alpha=float(q['alpha'][index]),f=float(q['f'][index]),pocket=int(ids[index])))
    manifest['half_classifier']=half_rows
    manifest['45_degree']=special45()
    manifest['diameter_grid']=diameter_grid()
    manifest['source_hashes']=RAW['source_hashes']
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    (OUT/'fixtures.json').write_text(json.dumps(fixtures,indent=2)+'\n')
    (OUT/'summary.json').write_text(json.dumps([r for r in rows if r['group'] in ['all','screen']],ensure_ascii=False,indent=2)+'\n')
    with (OUT/'metrics.csv').open('w') as f:
        writer=csv.DictWriter(f,fieldnames=rows[0].keys()); writer.writeheader(); writer.writerows(rows)
    print('wrote',len(rows),'metric rows',flush=True)

if __name__=='__main__': main()
