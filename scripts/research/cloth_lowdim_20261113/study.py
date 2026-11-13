"""Falsifiable directional-moment research, never imported by the App.

Uses an existing NumPy environment. Actual production-generated Metal is the
independent reference. Coordinates are SceneKit world metres: XZ bed, Y up.
"""
from pathlib import Path
import argparse, json, math, subprocess, hashlib
import numpy as np

PI = 3.14159265
R = .028575
BED = .8
COLOR = np.array([1, .985, .96])

def unit(a):
    return a / np.maximum(np.linalg.norm(a, axis=-1, keepdims=True), 1e-30)

def calibration():
    # Mirror the Swift Rig's calibration; checked against extracted native output.
    def irradiance(scale):
        total = 0.
        for zc in [-.635, .635]:
            for i in range(32):
                for j in range(32):
                    x = 2.54*scale*(2*(i+.5)/32-1)
                    z = zc*scale + .635*scale*(2*(j+.5)/32-1)
                    r2 = x*x+z*z+2.2**2
                    total += 2.2**2/r2**2 * (5.08*1.27*scale**2)/1024
        return total
    return 32.84539390996302*irradiance(.5)/irradiance(1)

RADIANCE = calibration()

def light_grid(nx, nz):
    return np.array([[2.54*(2*(i+.5)/nx-1),3.,zc+.635*(2*(j+.5)/nz-1)]
        for zc in [-.635,.635] for i in range(nx) for j in range(nz)])

def transport(p, balls):
    top = balls[:,2]+R
    bound = R+top/np.maximum(.01,2.2-top)*(np.linalg.norm(balls[:,:2],axis=1)+
        math.hypot(2.54,1.27)+math.sqrt(5.08*1.27/32/PI))
    in_support = ((p[:,None,0]-balls[None,:,0])**2+(p[:,None,2]-balls[None,:,1])**2 <= bound**2)
    active = balls[:,3]>0
    support = (in_support | (top[None,:]>=2.2)) & active[None,:]
    near = support.any(axis=1)
    mask = support | ((p[:,None,1]<BED)&active[None,:])
    lp = np.broadcast_to(light_grid(8,4),(len(p),64,3)).copy()
    lp[~near,:8] = light_grid(2,2)
    cell_area = np.where(near,5.08*1.27/32,5.08*1.27/4)
    delta = lp-p[:,None,:]
    r2 = (delta*delta).sum(axis=2)
    l = delta/np.sqrt(r2[:,:,None])
    a = np.maximum(0,l[:,:,1])/r2*cell_area[:,None]*RADIANCE/PI
    a[~near,8:] = 0
    vis = np.ones_like(a)
    for k,b in enumerate(balls):
        if b[3]<=0: continue
        d = np.array([b[0],BED+b[2],b[1]])-p
        t = (d[:,None,:]*l).sum(axis=2)
        perp = (d*d).sum(axis=1)[:,None]-t*t
        radius = np.maximum(1e-6,np.sqrt(cell_area/PI)[:,None]*t/np.sqrt(r2))
        u = np.clip((np.sqrt(np.maximum(0,perp))-(R-radius))/(2*radius),0,1)
        blocked = 1-u*u*(3-2*u)
        valid = (t>0)&(t*t<r2)&near[:,None]&mask[:,k,None]
        vis *= 1-np.where(valid,min(1,b[3]/.85)*blocked,0)
    return l,a,vis,near

def brdf(n,v,rough,l):
    nv = np.maximum(.001,(n*v).sum(axis=1))[:,None]
    nl = np.maximum(.001,(n[:,None,:]*l).sum(axis=2))
    h = unit(l+v[:,None,:])
    nh = np.maximum(0,(n[:,None,:]*h).sum(axis=2))
    vh = np.maximum(0,(v[:,None,:]*h).sum(axis=2))
    alpha = np.maximum(.01,rough*rough)[:,None]
    a2 = alpha*alpha
    D = a2/(PI*(nh*nh*(a2-1)+1)**2)
    G = 2*nv/(nv+np.sqrt(a2+(1-a2)*nv*nv))*2*nl/(nl+np.sqrt(a2+(1-a2)*nl*nl))
    F = .012+.988*(1-vh)**5
    return D*G*F/(4*nv*nl)

def reference(p,n,v,rough,balls):
    l,a,vis,near = transport(p,balls)
    weighted = a*np.maximum(0,(n[:,None,:]*l).sum(axis=2))
    E0 = weighted.sum(axis=1)
    E = (weighted*vis).sum(axis=1)
    S = (weighted*vis*brdf(n,v,rough,l)).sum(axis=1)
    return E0,E,S,(l,a,vis,near)

def candidate(p,n,v,rough,data,nx,nz):
    l,a,vis,near = data
    # Only near receivers enter the candidate. Far receivers retain exact original.
    transport_vectors = (a*vis)[:,:,None]*l
    shaped = transport_vectors.reshape(-1,2,8,4,3)
    groups=[]
    for panel in range(2):
        for x in range(nx):
            for z in range(nz):
                groups.append(shaped[:,panel,x*8//nx:(x+1)*8//nx,z*4//nz:(z+1)*4//nz].sum(axis=(1,2)))
    M=np.stack(groups,axis=1)
    reps=unit(M)
    dot=np.maximum(0,(n[:,None,:]*M).sum(axis=2))
    spec=(dot*brdf(n,v,rough,reps)).sum(axis=1)
    mv=transport_vectors.sum(axis=1);m0=(a[:,:,None]*l).sum(axis=1)
    # Convex rectangle corner guard: if every corner is above the horizon,
    # all interior sample directions are too. No 64-direction runtime guard.
    corners=np.array([[x,3.,z] for x in [-2.54,2.54] for z in [-1.27,0,1.27]])
    guard=((corners[None,:,:]-p[:,None,:])*n[:,None,:]).sum(axis=2).min(axis=1)>=0
    num=(n*mv).sum(axis=1);den=(n*m0).sum(axis=1)
    return num,den,spec,guard&near,guard,M,mv,m0

def metrics(ref,value):
    e=np.abs(value-ref)
    bright=np.abs(ref)>=.001
    return {'receiver_count':len(e),'value_count':int(e.size),'abs_mean':float(e.mean()),'abs_p95':float(np.quantile(e,.95)),
        'abs_max':float(e.max()),'bright_count':int(bright.sum()),
        'bright_relative_p95':float(np.quantile(e[bright]/np.abs(ref[bright]),.95)) if bright.any() else None}

def fixtures(texture_samples=None):
    rng=np.random.default_rng(20261113)
    rack=[(-.5+row*math.sqrt(3)*R,(j-row/2)*2*R,R,.85) for row in range(5) for j in range(row+1)]
    scatter=[(x,z,R,.85) for x in [-.9,-.3,.3,.9] for z in [-.45,-.15,.15,.45]]
    scenes={'empty':[], 'single':[(0,0,R,.85)], 'rack':rack+[(.65,.2,R,.85)],
            'scatter':scatter, 'overlap_shadow':[(0,0,R,.85),(2*R,0,R,.85)],
            'edge_height_opacity':[(1.22,.58,R,.85),(-1.2,-.5,.08,.425),(.1,.1,R,.17)]}
    for name,values in scenes.items():
        balls=np.zeros((16,4))
        if values: balls[:len(values)]=values
        p=np.column_stack((rng.uniform(-1.25,1.25,384),np.full(384,BED),rng.uniform(-.62,.62,384)))
        if values:
            for i in range(300):
                b=values[i%len(values)];theta=rng.uniform(0,2*math.pi);rr=rng.uniform(R,4*R)
                p[i]=[b[0]+rr*math.cos(theta),BED,b[1]+rr*math.sin(theta)]
        # Synthetic direction stress grid; NOT sampled production texture/camera envelope.
        tilt=np.deg2rad(np.resize([0,15,30,45,60,80],len(p)))
        az=rng.uniform(0,2*math.pi,len(p))
        n=np.column_stack((np.sin(tilt)*np.cos(az),np.cos(tilt),np.sin(tilt)*np.sin(az)))
        elev=np.deg2rad(rng.choice([5,15,30,60,85],len(p)))
        az=rng.uniform(0,2*math.pi,len(p))
        v=np.column_stack((np.cos(elev)*np.cos(az),np.sin(elev),np.cos(elev)*np.sin(az)))
        # Keep visible-facing samples; extreme normals still exercise the guard.
        bad=(n*v).sum(axis=1)<.02;v[bad]=unit(v[bad]+2*n[bad])
        rough=rng.choice([.3,.5,.8,1.],len(p))
        yield name,p,n,v,rough,balls
        if texture_samples is not None:
            paired=np.load(texture_samples)
            # Paired world-normal xyz and roughness in extractor's declared bed basis.
            n_tex=paired[:len(p),:3]
            r_tex=paired[:len(p),3]
            v_tex=v.copy()
            bad=(n_tex*v_tex).sum(axis=1)<.02
            v_tex[bad]=unit(v_tex[bad]+2*n_tex[bad])
            yield name+'_texture_pairs',p,n_tex,v_tex,r_tex,balls

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--native',type=Path,required=True);ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--texture-samples',type=Path)
    args=ap.parse_args();args.out.mkdir(parents=True,exist_ok=False)
    report={'scope':'P1 synthetic numerical shader study; no spatial interpolation, texture normals, SceneKit final output, motion or phone performance acceptance',
            'radiance':RADIANCE,'candidate':'visibility-weighted directional moments, positive hemisphere guard, exact far/fallback',
            'groups_per_panel':[1,2,4,8,16,32],'rows':[]}
    for name,p,n,v,rough,balls in fixtures(args.texture_samples):
        folder=args.out/name;folder.mkdir()
        samples=np.zeros((len(p),12),dtype='<f4');samples[:,:3]=p;samples[:,4:7]=n;samples[:,8:11]=v;samples[:,11]=rough
        samples.tofile(folder/'samples.bin');balls.astype('<f4').tofile(folder/'balls.bin')
        # Compare with float32-rounded input consumed by native Metal.
        p=samples[:,:3].astype(float);n=samples[:,4:7].astype(float);v=samples[:,8:11].astype(float);rough=samples[:,11].astype(float)
        n=unit(n);v=unit(v);balls=balls.astype('<f4').astype(float)
        cmd=[str(args.native/'evaluate'),str(args.native/'reference.metal'),str(folder/'samples.bin'),str(folder/'balls.bin'),str(folder/'reference.bin')]
        proc=subprocess.run(cmd,capture_output=True,text=True);(folder/'native.log').write_text(proc.stdout+proc.stderr)
        if proc.returncode:raise RuntimeError(proc.stdout+proc.stderr)
        gpu=np.fromfile(folder/'reference.bin',dtype='<f4').reshape(-1,16)
        E0,E,S,data=reference(p,n,v,rough,balls)
        near=data[3]
        cross={key:metrics(gpu[:,offset:offset+3],values[:,None]*COLOR) for key,offset,values in [('E0',0,E0),('sampledE',4,E),('S',12,S)]}
        if not np.allclose(gpu[:,3],near.astype(float)):raise AssertionError('near/far mismatch')
        # Tight numerical-model agreement, independent GPU reference, not picture tolerance.
        if any(x['abs_max']>2e-4 for x in cross.values()):raise AssertionError(f'native mismatch: {name} {cross}')
        rows=[]
        for nx,nz in [(1,1),(2,1),(2,2),(4,2),(4,4),(8,4)]:
            num,den,cs,use,guard,M,mv,m0=candidate(p,n,v,rough,data,nx,nz)
            packed=np.zeros((len(p),2+len(M[0]),4),dtype='<f4')
            packed[:,0,:3]=mv;packed[:,0,3]=use;packed[:,1,:3]=m0;packed[:,2:,:3]=M
            packed.tofile(folder/f'moments-{nx*nz}.bin')
            cs=np.where(use,cs,S)
            ratio=(E[:,None]*COLOR)/np.maximum(E0[:,None]*COLOR,1e-6)
            cratio=np.where(use[:,None],(num[:,None]*COLOR)/np.maximum(den[:,None]*COLOR,1e-6),ratio)
            # This proxy includes only candidate-changed terms, not final rendered pixels.
            ce=np.where(ratio>1e-12,gpu[:,8:11]*cratio/np.maximum(ratio,1e-12),0)
            proxy=gpu[:,8:11]*np.array([.02,.16,.004])/PI+.35*gpu[:,12:15]
            cproxy=ce*np.array([.02,.16,.004])/PI+.35*cs[:,None]*COLOR
            err=np.abs(cproxy-proxy).max(axis=1);worst=int(err.argmax())
            row={'groups_per_panel':nx*nz,'BRDF_evaluations_near':2*nx*nz,'near_samples':int(near.sum()),'candidate_samples':int(use.sum()),
                'guard_fallback_near':int((near&~guard).sum()),'ratio_error':metrics(ratio,cratio),
                'specular_error':metrics(S,cs),'changed_terms_proxy_error':metrics(proxy,cproxy),
                'worst':{'index':worst,'sample':samples[worst].tolist(),'reference_proxy':proxy[worst].tolist(),'candidate_proxy':cproxy[worst].tolist()}}
            row['by_roughness']={str(float(r)):metrics(S[rough==r],cs[rough==r]) for r in np.unique(rough)}
            no_block=(data[2].min(axis=1)>1-1e-12)&use
            row['unblocked_near_specular_error']=metrics(S[no_block],cs[no_block]) if no_block.any() else {'count':0}
            row['candidate_only_specular_error']=metrics(S[use],cs[use]) if use.any() else {'count':0}
            row['candidate_only_proxy_error']=metrics(proxy[use],cproxy[use]) if use.any() else {'count':0}
            if nx*nz==32 and np.max(np.abs(cs-S))>1e-10:
                raise AssertionError('Single sample per group must reproduce scalar integral')
            rows.append(row)
            np.savez(folder/f'candidate-{nx*nz}.npz',ratio=cratio,S=cs,proxy=cproxy,use=use,reference_proxy=proxy)
        report['rows'].append({'scene':name,'sample_count':len(p),'cpu_native_crosscheck':cross,'candidates':rows})
        print(name,'near',int(near.sum()),'K4 proxy max',rows[2]['changed_terms_proxy_error']['abs_max'],flush=True)
    (args.out/'results.json').write_text(json.dumps(report,indent=2)+'\n')
    print(args.out/'results.json')

if __name__=='__main__':main()
