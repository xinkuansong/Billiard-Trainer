"""H18: independently fit the production separable-Smith/F0=.012 lobe.

LTC parameterization follows the published definition, not a copied LUT or fitter.
Run with numpy/scipy through local_test_lifecycle; all outputs are evidence.
"""
import argparse
import hashlib
import json
from pathlib import Path
import time
import numpy as np
from scipy.optimize import least_squares


def brdf(l, nv, rough):
    v = np.array([np.sqrt(1-nv*nv), 0., nv])
    h = l + v
    h /= np.linalg.norm(h, axis=1)[:, None]
    nl = np.maximum(.001, l[:, 2])
    nh = np.maximum(0, h[:, 2])
    vh = np.maximum(0, h @ v)
    a2 = max(.01, rough*rough)**2
    d = a2/(np.pi*(nh*nh*(a2-1)+1)**2)
    g = 2*nv/(nv+np.sqrt(a2+(1-a2)*nv*nv))*2*nl/(nl+np.sqrt(a2+(1-a2)*nl*nl))
    f = .012+.988*(1-vh)**5
    return d*g*f/(4*nv)*np.maximum(0, l[:, 2])/nl


def matrix(p):
    sx, sy = np.exp(p[:2]); shear, beta = p[2:4]
    s, c = np.sin(beta), np.cos(beta)
    return np.array([[(c-shear*s)/sx, 0, (-s-shear*c)/sx],
                     [0, 1/sy, 0], [s, 0, c]])


def density(l, inv, amplitude):
    q = l @ inv.T
    return amplitude*np.linalg.det(inv)/np.pi*np.maximum(0, q[:, 2])/np.sum(q*q, axis=1)**2


def hemisphere(nz=24, nphi=48):
    z = (np.arange(nz)+.5)/nz
    phi = (np.arange(nphi)+.5)*2*np.pi/nphi
    z, phi = np.meshgrid(z, phi)
    return np.stack([np.sqrt(1-z*z)*np.cos(phi), np.sqrt(1-z*z)*np.sin(phi), z], axis=-1).reshape(-1, 3)


def integrate_polygon(vertices, inv):
    """Clip transformed spherical polygon to cosine hemisphere, exact edge angles."""
    q = [v for v in vertices @ inv.T]
    clipped = []
    for a, b in zip(q, q[1:]+q[:1]):
        if a[2] > 0: clipped.append(a)
        if (a[2] > 0) != (b[2] > 0):
            clipped.append(a+(b-a)*a[2]/(a[2]-b[2]))
    if len(clipped) < 3: return 0.
    q = [v/np.linalg.norm(v) for v in clipped]
    result = 0.
    for a, b in zip(q, q[1:]+q[:1]):
        cross = np.cross(a,b); length = np.linalg.norm(cross)
        result += cross[2]*np.arctan2(length, np.dot(a,b))/max(1e-12,length)
    return abs(result)/(2*np.pi)


def validate():
    l = hemisphere(200,400)
    cosine_error = np.max(abs(density(l, np.eye(3), 1)-l[:, 2]/np.pi))
    assert cosine_error < 1e-14
    vertices = np.array([[-.7,-.4,1],[.7,-.4,1],[.7,.4,1],[-.7,.4,1]])
    x,y=np.meshgrid((np.arange(240)+.5)/240*1.4-.7,(np.arange(240)+.5)/240*.8-.4)
    q=np.stack([x.ravel(),y.ravel(),np.ones(x.size)],axis=1)
    r=np.linalg.norm(q,axis=1); rays=q/r[:,None]
    checks=[]
    for p in [[0,0,0,0,0],[-.2,-.4,.1,-.6,0],[.1,-.3,.2,-1.3,0]]:
        inv=matrix(np.array(p)); analytic=integrate_polygon(vertices,inv)
        numeric=np.sum(density(rays,inv,1)/r**3)*(1.4*.8/x.size)
        checks.append({'analytic':float(analytic),'numeric':float(numeric),'error':float(abs(analytic-numeric))})
        assert abs(analytic-numeric)<1e-5
    return {'cosineError':float(cosine_error),'polygonChecks':checks,
            'localFrame':'Z=N; X=normalize(V-N*dot(N,V)); Y=cross(Z,X)',
            'world':'XZ horizontal, Y up, metres', 'bedY':.8,'ballRadius':.028575}


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--evidence',type=Path,required=True)
    ap.add_argument('--nr',type=int,default=24);ap.add_argument('--nv',type=int,default=48)
    ap.add_argument('--weighted',action='store_true')
    a=ap.parse_args();a.evidence.mkdir(parents=True,exist_ok=True)
    (a.evidence/'preflight.json').write_text(json.dumps(validate(),indent=2)+'\n')
    l=hemisphere(); lut=np.zeros((a.nv,a.nr,8),dtype=np.float32); records=[]
    params=np.zeros((a.nv,a.nr,5)); started=time.monotonic()
    # Research first domain: roughness .4..1; lower roughness uses exact original.
    for ir,rough in reversed(list(enumerate(np.linspace(.4,1,a.nr)))):
        for iv,t in enumerate(np.linspace(0,1,a.nv)):
            nv=max(.001,1-t*t); target=brdf(l,nv,rough)
            scale=max(1e-8,np.sqrt(np.mean(target*target)))
            initial=params[iv,ir+1] if ir<a.nr-1 else (params[iv-1,ir] if iv else np.array([0.,0.,0.,0.,np.log(.01)]))
            weight=np.clip((l[:,2]-.15)/.2,.03,1)**1.5 if a.weighted else 1
            def residual(p): return (density(l,matrix(p),np.exp(p[4]))-target)/scale*weight
            result=least_squares(residual,initial,bounds=([-5,-5,-5,-1.56,-14],[4,4,5,.1,1]),max_nfev=100,ftol=1e-7,xtol=1e-7,gtol=1e-7)
            p=result.x;params[iv,ir]=p;inv=matrix(p);inv/=np.linalg.norm(inv)
            lut[iv,ir]=[inv[0,0],inv[0,2],inv[1,1],inv[2,0],inv[2,2],np.exp(p[4]),np.linalg.det(inv),np.sqrt(np.mean(residual(p)**2))]
            records.append({'roughness':float(rough),'nv':nv,'relativeRMS':float(lut[iv,ir,7]),'evaluations':result.nfev,'success':bool(result.success)})
        print(f'roughness {rough:.4f} fitted; elapsed {time.monotonic()-started:.1f}s',flush=True)
    for index in range(2): lut[:,:,index*4:index*4+4].copy().tofile(a.evidence/f'ltc{index}.f32')
    np.save(a.evidence/'parameters.npy',params)
    report={'width':a.nr,'height':a.nv,'roughnessMin':.4,'roughnessMax':1.,'nvMapping':'max(.001,1-t*t)',
            'target':'D_GGX * G1(V)G1(L) * Schlick(.012) * NdotL/(4*NdotV*max(.001,NdotL))',
            'directionWeighted':a.weighted,'seconds':time.monotonic()-started,'records':records,'sourceSHA256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    (a.evidence/'fit.json').write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__':main()
