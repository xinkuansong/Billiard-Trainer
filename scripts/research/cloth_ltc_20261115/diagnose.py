"""Separate LTC fitting and continuous/discrete integration at captured pixels."""
import argparse
import json
from pathlib import Path
import numpy as np
from fit import brdf, density, integrate_polygon


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--evidence',type=Path,required=True);ap.add_argument('--probe',type=Path,required=True);ap.add_argument('--reference',type=Path,required=True);a=ap.parse_args()
    a.evidence.mkdir(parents=True,exist_ok=True)
    fit=json.loads((a.probe/'fit.json').read_text());w,h=fit['width'],fit['height']
    table=np.concatenate([np.fromfile(a.probe/f'ltc{i}.f32',dtype=np.float32).reshape(h,w,4) for i in range(2)],axis=2)
    def sample(rough,nv):
        x=np.clip((rough-.4)/.6,0,1)*(w-1);y=np.sqrt(1-np.clip(nv,0,1))*(h-1)
        ix=min(int(x),w-2);iy=min(int(y),h-2);fx=x-ix;fy=y-iy
        row=(1-fy)*((1-fx)*table[iy,ix]+fx*table[iy,ix+1])+fy*((1-fx)*table[iy+1,ix]+fx*table[iy+1,ix+1])
        return np.array([[row[0],0,row[1]],[0,row[2],0],[row[3],0,row[4]]],dtype=float),float(row[5])
    def geometry(p,center,nx,nz):
        x,z=np.meshgrid((np.arange(nx)+.5)/nx*5.08-2.54,(np.arange(nz)+.5)/nz*1.27-.635)
        q=np.stack([x.ravel(),np.zeros(x.size),z.ravel()],axis=1)+center-p
        r=np.linalg.norm(q,axis=1);l=q/r[:,None]
        return l,np.maximum(0,l[:,1])/r**2*(5.08*1.27/x.size)
    rows=[]
    for pose,frame,shadows in [('single-low',15,False),('single-near',12,False),('scatter-overview',13,False),('scatter-overview',14,False)]:
        prefix=f'{pose}-integral-{str(shadows).lower()}-{frame}'
        aa=np.fromfile(a.reference/f'{prefix}-A.bgra8',np.uint8).reshape(-1,4).astype(int)
        bb=np.fromfile(a.reference/f'{prefix}-B.bgra8',np.uint8).reshape(-1,4).astype(int)
        delta=abs(aa[:,:3]-bb[:,:3]).max(axis=1);indices=np.flatnonzero(delta==delta.max())[:16]
        nr=np.fromfile(a.probe/f'{pose}-{frame}-input0.f32',np.float32).reshape(-1,4)
        positions=np.fromfile(a.probe/f'{pose}-{frame}-input1.f32',np.float32).reshape(-1,4)
        eye=np.array({'single-low':[0,1.05,1.8],'single-near':[.16,1.15,.3],'scatter-overview':[1.8,2.7,2.1]}[pose])
        for index in indices:
            n=nr[index,:3].astype(float);p=positions[index,:3].astype(float);rough=float(nr[index,3]);v=eye-p;v/=np.linalg.norm(v)
            n/=np.linalg.norm(n);nv=max(.001,float(n@v));tx=v-n*(n@v);tx/=np.linalg.norm(tx);ty=np.cross(n,tx);basis=np.stack([tx,ty,n])
            inv,amp=sample(rough,nv)
            exact64=exactDense=ltc64=ltcAnalytic=0.;union=[]
            for center in [np.array([0,3,-.635]),np.array([0,3,.635])]:
                l,geom=geometry(p,center,8,4);local=l@basis.T
                exact64+=np.sum(brdf(local,nv,rough)*geom)
                ltc64+=np.sum(density(local,inv,amp)*geom)
                l,geom=geometry(p,center,128,64);exactDense+=np.sum(brdf(l@basis.T,nv,rough)*geom)
                u=np.array([2.54,0,0]);vv=np.array([0,0,.635]);c=center-p
                corners=np.array([c-u-vv,c+u-vv,c+u+vv,c-u+vv])@basis.T
                ltcAnalytic+=amp*integrate_polygon(corners,inv)
            c=np.array([0,3,0])-p;u=np.array([2.54,0,0]);vv=np.array([0,0,1.27])
            joined=amp*integrate_polygon(np.array([c-u-vv,c+u-vv,c+u+vv,c-u+vv])@basis.T,inv)
            assert abs(joined-ltcAnalytic)<1e-9
            rows.append({'pose':pose,'frame':frame,'pixel':[int(index%700),int(index//700)],'codeDifference':int(delta[index]),
                         'roughnessActual':rough,'nvActual':nv,'normal':n.tolist(),'position':p.tolist(),
                         'reference64':float(exact64),'referenceDense16384':float(exactDense),'ltc64':float(ltc64),'ltcAnalytic':float(ltcAnalytic),
                         'quadratureError':float(exactDense-exact64),'fitIntegralError':float(ltcAnalytic-exactDense),'unionError':float(joined-ltcAnalytic)})
    (a.evidence/'diagnosis.json').write_text(json.dumps({'rows':rows,'scope':'Unshadowed specular scalar before radiance/pi and final .35. Actual shader inputs. MSAA per-pixel probe may select one covered sample; not an exact final RGB reconstruction.'},indent=2)+'\n')
    for pose in sorted(set(r['pose'] for r in rows)):
        group=[r for r in rows if r['pose']==pose]
        print(pose,'actual roughness',[min(r['roughnessActual'] for r in group),max(r['roughnessActual'] for r in group)],'max quadrature',max(abs(r['quadratureError']) for r in group),'max fit',max(abs(r['fitIntegralError']) for r in group))


if __name__=='__main__':main()
