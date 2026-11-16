"""H18 R4: two positive LTC lobes for the measured single-lobe residual."""
import argparse
import json
from pathlib import Path
import time
import numpy as np
from scipy.optimize import least_squares
from fit import brdf, matrix, density, hemisphere


LOW=np.array([-5,-5,-5,-1.56,-16]*2)
HIGH=np.array([4,4,5,.1,1]*2)


def fitted(l,target,single,initial=None):
    seed=np.tile(single,2)
    seed[4]+=np.log(.85);seed[9]+=np.log(.15);seed[5:7]+=np.log(1.8)
    weight=np.clip((l[:,2]-.15)/.2,.03,1)**1.5
    scale=max(1e-8,np.sqrt(np.mean(target*target)))
    def residual(p):return (density(l,matrix(p[:5]),np.exp(p[4]))+density(l,matrix(p[5:]),np.exp(p[9]))-target)/scale*weight
    p=seed if initial is None else initial
    result=least_squares(residual,p,bounds=(LOW,HIGH),max_nfev=120,ftol=1e-7,xtol=1e-7,gtol=1e-7)
    return result.x,float(np.sqrt(np.mean(residual(result.x)**2))),int(result.nfev)


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--evidence',type=Path,required=True);ap.add_argument('--fit',type=Path,required=True);ap.add_argument('--diagnosis',type=Path);a=ap.parse_args()
    a.evidence.mkdir(parents=True,exist_ok=True)
    metadata=json.loads((a.fit/'fit.json').read_text());params=np.load(a.fit/'parameters.npy');h,w=params.shape[:2];l=hemisphere()
    if a.diagnosis:
        rows=json.loads(a.diagnosis.read_text())['rows'];out=[]
        for row in rows:
            rough=row['roughnessActual'];nv=row['nvActual'];x=int(np.clip(round((rough-.4)/.6*(w-1)),0,w-1));y=int(np.clip(round(np.sqrt(1-nv)*(h-1)),0,h-1))
            target=brdf(l,nv,rough);p,error,evaluations=fitted(l,target,params[y,x])
            out.append({'pose':row['pose'],'roughness':rough,'nv':nv,'weightedRMS':error,'evaluations':evaluations,'parameters':p.tolist()})
        (a.evidence/'two-lobe-probe.json').write_text(json.dumps(out,indent=2)+'\n')
        print('Two-lobe weighted RMS',min(r['weightedRMS'] for r in out),max(r['weightedRMS'] for r in out));return
    lut=np.zeros((h,w,16),np.float32);solutions=np.zeros((h,w,10));records=[];started=time.monotonic()
    for ir,rough in reversed(list(enumerate(np.linspace(.4,1,w)))):
        for iv,t in enumerate(np.linspace(0,1,h)):
            nv=max(.001,1-t*t);target=brdf(l,nv,rough)
            initial=solutions[iv,ir+1] if ir<w-1 else (solutions[iv-1,ir] if iv else None)
            p,error,evaluations=fitted(l,target,params[iv,ir],initial)
            solutions[iv,ir]=p
            for k in range(2):
                pk=p[k*5:k*5+5];inv=matrix(pk);inv/=np.linalg.norm(inv)
                lut[iv,ir,k*8:k*8+8]=[inv[0,0],inv[0,2],inv[1,1],inv[2,0],inv[2,2],np.exp(pk[4]),np.linalg.det(inv),error]
            records.append({'roughness':float(rough),'nv':nv,'relativeRMS':error,'evaluations':evaluations})
        print(f'{rough:.4f} {time.monotonic()-started:.1f}s',flush=True)
    for i in range(4):lut[:,:,i*4:i*4+4].copy().tofile(a.evidence/f'ltc{i}.f32')
    np.save(a.evidence/'parameters.npy',solutions)
    metadata.update(lobes=2,records=records,seconds=time.monotonic()-started)
    (a.evidence/'fit.json').write_text(json.dumps(metadata,indent=2)+'\n')


if __name__=='__main__':main()
