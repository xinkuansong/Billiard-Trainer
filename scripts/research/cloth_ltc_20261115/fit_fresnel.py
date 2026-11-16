"""Fit two semantically fixed LTC components of production Schlick Fresnel."""
import argparse
import hashlib
import json
from pathlib import Path
import time
import numpy as np
from scipy.optimize import least_squares
from fit import brdf, matrix, density, hemisphere


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--evidence',type=Path,required=True);a=ap.parse_args();a.evidence.mkdir(parents=True,exist_ok=True)
    w,h=48,64;l=hemisphere(32,64);table=np.zeros((h,w,16),np.float32);parameters=np.zeros((h,w,10));records=[];start=time.monotonic()
    weight=np.clip((l[:,2]-.15)/.2,.03,1)**1.5
    for ir,rough in reversed(list(enumerate(np.linspace(.4,1,w)))):
        for iv,t in enumerate(np.linspace(0,1,h)):
            nv=max(.001,1-t*t);v=np.array([np.sqrt(1-nv*nv),0,nv]);hh=l+v;hh/=np.linalg.norm(hh,axis=1)[:,None]
            tail=(1-np.maximum(0,hh@v))**5;full=brdf(l,nv,rough);base=full/(.012+.988*tail)
            for k,target in enumerate([base*.012,base*.988*tail]):
                scale=max(1e-10,np.sqrt(np.mean(target*target)))
                initial=parameters[iv,ir+1,k*5:k*5+5] if ir<w-1 else (parameters[iv-1,ir,k*5:k*5+5] if iv else np.array([0.,0.,0.,0.,np.log(max(1e-8,target.mean()*2*np.pi))]))
                def residual(p):return (density(l,matrix(p),np.exp(p[4]))-target)/scale*weight
                if iv==0:
                    def pack(p):return np.array([p[0],p[0],0,0,p[1]])
                    result=least_squares(lambda p:residual(pack(p)),initial[[0,4]],bounds=([-5,-20],[4,1]),max_nfev=120)
                    p=pack(result.x)
                else:
                    result=least_squares(residual,initial,bounds=([-5,-5,-5,-1.56,-20],[4,4,5,.1,1]),max_nfev=120)
                    p=result.x
                parameters[iv,ir,k*5:k*5+5]=p
                table[iv,ir,k*8:k*8+4]=p[:4];table[iv,ir,k*8+4]=p[4]
                records.append({'roughness':float(rough),'nv':nv,'component':k,'relativeRMS':float(np.sqrt(np.mean(residual(p)**2))),'evaluations':result.nfev})
        print(f'{rough:.4f} {time.monotonic()-start:.1f}s',flush=True)
    for i in range(4):table[:,:,i*4:i*4+4].copy().tofile(a.evidence/f'ltc{i}.f32')
    np.save(a.evidence/'parameters.npy',parameters)
    (a.evidence/'fit.json').write_text(json.dumps({'width':w,'height':h,'lobes':2,'parameterEncoding':True,'fresnelComponents':['.012','.988*(1-VdotH)^5'],'roughnessMin':.4,'roughnessMax':1,'records':records,'sourceSHA256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'seconds':time.monotonic()-start},indent=2)+'\n')


if __name__=='__main__':main()
