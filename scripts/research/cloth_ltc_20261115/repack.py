"""Interpolate positive LTC parameters, rather than unconstrained inverse matrices."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from fit import matrix, density, brdf, hemisphere


def main():
    p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);p.add_argument('--fit',type=Path,required=True);a=p.parse_args();a.evidence.mkdir(parents=True,exist_ok=True)
    params=np.load(a.fit/'parameters.npy');h,w=params.shape[:2]
    table=np.zeros((h,w,16),np.float32)
    for k in range(2):table[:,:,k*8:k*8+4]=params[:,:,k*5:k*5+4];table[:,:,k*8+4]=params[:,:,k*5+4]
    for i in range(4):table[:,:,i*4:i*4+4].copy().tofile(a.evidence/f'ltc{i}.f32')
    np.save(a.evidence/'parameters.npy',params)
    report=json.loads((a.fit/'fit.json').read_text());report.update(parameterEncoding=True,repackSourceSHA=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),sourceFit=str(a.fit))
    (a.evidence/'fit.json').write_text(json.dumps(report,indent=2)+'\n')
    rows=[];l=hemisphere(32,64)
    for y in range(h-1):
        for x in range(w-1):
            p=(params[y,x]+params[y+1,x]+params[y,x+1]+params[y+1,x+1])*.25
            rough=.4+.6*(x+.5)/(w-1);nv=max(.001,1-((y+.5)/(h-1))**2)
            target=brdf(l,nv,rough);actual=np.zeros(len(l));dets=[]
            for k in range(2):
                pk=p[k*5:k*5+5];inv=matrix(pk);det=np.linalg.det(inv);assert np.isfinite(det) and det>0
                actual+=density(l,inv,np.exp(pk[4]));dets.append(float(det))
            assert np.isfinite(actual).all() and actual.min()>=0
            rows.append({'x':x,'y':y,'minDeterminant':min(dets),'relativeRMS':float(np.sqrt(np.mean((actual-target)**2)/np.mean(target**2))),'maxAbsolute':float(abs(actual-target).max())})
    (a.evidence/'interpolation.json').write_text(json.dumps({'cellCenters':rows},indent=2)+'\n')
    print('Positive finite cell centers:',len(rows),'RMS median/max',np.median([r['relativeRMS'] for r in rows]),max(r['relativeRMS'] for r in rows),'max absolute',max(r['maxAbsolute'] for r in rows))


if __name__=='__main__':main()
