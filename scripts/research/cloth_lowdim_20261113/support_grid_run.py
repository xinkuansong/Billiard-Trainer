#!/usr/bin/env python3
"""Strict bitwise tests and measured total costs for blocker-candidate grids."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import numpy as np


def packed_samples(values):
    out=np.zeros((len(values),12),dtype='<f4')
    out[:,:3]=values[:,:3];out[:,4:7]=values[:,3:6];out[:,8:11]=values[:,6:9];out[:,11]=values[:,9]
    return out


def stress_samples(balls,seed):
    rng=np.random.default_rng(seed);points=[]
    # Cell edges and adjacent representable positions, not only cell centers.
    for w in [32,64]:
        for i in range(w+1):
            x=np.float32(-1.27+2.54*i/w)
            for xx in [np.nextafter(x,np.float32(-np.inf)),x,np.nextafter(x,np.float32(np.inf))]:
                for y in [np.nextafter(np.float32(.8),np.float32(-np.inf)),np.float32(.8),np.nextafter(np.float32(.8),np.float32(np.inf))]:
                    points.append([xx,y,rng.uniform(-.635,.635)])
        for i in range(w//2+1):
            z=np.float32(-.635+1.27*i/(w//2))
            for zz in [np.nextafter(z,np.float32(-np.inf)),z,np.nextafter(z,np.float32(np.inf))]:
                points.append([rng.uniform(-1.27,1.27),.8,zz])
    # Sample the exact support-circle region; one-ULP perturbations straddle its branch.
    for b in balls:
        if b[3]<=0:continue
        top=float(b[2])+.028575
        if top>=2.2:continue
        bound=.028575+top/max(.01,2.2-top)*(np.linalg.norm(b[:2])+3.0931346330254206)
        for angle in np.linspace(0,2*np.pi,128,endpoint=False):
            point=np.array([b[0]+bound*np.cos(angle),.8,b[1]+bound*np.sin(angle)],dtype=np.float32)
            points.extend([point,np.nextafter(point,np.array([-np.inf,.8,-np.inf],np.float32)),np.nextafter(point,np.array([np.inf,.8,np.inf],np.float32))])
    for y in [.7,.799,.8,.801,.9,1.8]:
        points.extend([[x,y,z] for x,z in [(-1.27,-.635),(1.27,.635),(-1.28,0),(1.28,0),(0,0)]])
    p=np.asarray(points,dtype='<f4');s=np.zeros((len(p),12),dtype='<f4');s[:,:3]=p;s[:,5]=1
    s[:,8:11]=[.2,.9,.4];s[:,11]=.8
    return s


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--native',type=Path,required=True);ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--study',type=Path,default=Path('output/render-lowdim-20261113/moments-r5'))
    ap.add_argument('--split',type=Path,default=Path('output/render-lowdim-20261113/split-r3'))
    ap.add_argument('--visual',type=Path,default=Path('output/render-lowdim-20261113/visual-r2'))
    ap.add_argument('--suite',choices=['check','bench','actual'],default='check')
    ap.add_argument('--widths',type=int,nargs='+',default=[32,64]);ap.add_argument('--repeats',type=int,nargs='+',default=[1])
    args=ap.parse_args();args.out.mkdir(parents=True,exist_ok=False);fixtures=[]
    if args.suite=='check':
        for k,name in enumerate(['empty','single','rack','scatter','overlap_shadow','edge_height_opacity']):
            folder=args.study/(name+'_texture_pairs');balls=np.fromfile(folder/'balls.bin',dtype='<f4').reshape(16,4)
            samples=np.fromfile(folder/'samples.bin',dtype='<f4').reshape(-1,12)
            fixtures.append((name,samples,balls));fixtures.append((name+'-boundaries',stress_samples(balls,20261113+k),balls))
        # High blocker always-near branch plus partial alpha and hidden entries.
        balls=np.zeros((16,4),dtype='<f4');balls[0]=[0,0,2.2,.85];balls[3]=[.5,.3,.12,.17]
        fixtures.append(('raised-always-near',stress_samples(balls,2026111319),balls))
    elif args.suite=='bench':
        for name in ['single_texture_pairs','scatter_texture_pairs']:
            for order in ['fixture_interleaved','fixture_spatial_sorted','grid_row_major','grid_shuffled']:
                folder=args.split/(name+'-'+order)
                fixtures.append((name+'-'+order,np.fromfile(folder/'samples.bin',dtype='<f4').reshape(-1,12),np.fromfile(folder/'balls.bin',dtype='<f4').reshape(16,4)))
    else:
        for record in json.loads((args.visual/'pixel-fixtures.json').read_text())['records']:
            name=record['id'];values=np.load(args.visual/(name+'-actual-inputs.npy'))
            fixtures.append((name,packed_samples(values),np.asarray(record['packedBalls'],dtype='<f4')))
    report={'scope':'Original R bitwise equality, conservative candidate cache only; no interpolated light values. Arbitrary actual receiver Y retained.',
        'suite':args.suite,'sourceHashes':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in Path(__file__).parent.glob('support_grid_*') if p.is_file()},'rows':[]}
    for name,samples,balls in fixtures:
        fixture=args.out/(name+'-inputs');fixture.mkdir();samples.tofile(fixture/'samples.bin');balls.tofile(fixture/'balls.bin')
        for width in args.widths:
            for repeat in args.repeats:
                output=args.out/f'{name}-{width}-repeat{repeat}'
                command=[str(args.native/'evaluate'),str(args.native/'support.metal'),str(fixture/'samples.bin'),str(fixture/'balls.bin'),str(output),str(width),str(width//2),str(repeat)]
                if args.suite=='check':command.append('check')
                result=subprocess.run(command,capture_output=True,text=True);(args.out/(output.name+'.log')).write_text(result.stdout+result.stderr)
                if result.returncode:raise RuntimeError(result.stderr[-2500:])
                ref=np.fromfile(output/'reference.bin',dtype='<f4').reshape(-1,16)
                candidate=np.fromfile(output/'total.bin',dtype='<f4').reshape(-1,16)
                lookup=np.fromfile(output/'lookup.bin',dtype='<u4').reshape(-1,2)
                changed=np.any(ref.view(np.uint32)!=candidate.view(np.uint32),axis=1)
                row=json.loads((output/'metadata.json').read_text())
                row.update({'case':name,'bitwiseEqual':not bool(changed.any()),'changedReceiverCount':int(changed.sum()),'maxAbsDifference':float(np.abs(ref-candidate).max()),
                    'insideReceivers':int(lookup[:,1].sum()),'nearReceivers':int((ref[:,3]>0).sum()),'belowBedReceivers':int((samples[:,1]<np.float32(.8)).sum())})
                if changed.any():
                    indices=np.flatnonzero(changed)[:20]
                    row['firstMismatches']=[{'index':int(i),'input':samples[i].tolist(),'ref':ref[i].tolist(),'candidate':candidate[i].tolist(),'lookup':lookup[i].tolist()} for i in indices]
                active=lookup[:,0]>>16;low=lookup[:,0]&65535;inside=lookup[:,1]!=0
                pop=np.array([int(x).bit_count() for x in low]);row['meanCandidateBitsInside']=float(pop[inside].mean()) if inside.any() else 0
                # For at/above-bed original mask is exactly the support set.
                expected=ref[:,7].astype(np.uint32);eligible=inside&(samples[:,1]>=np.float32(.8))
                missing=eligible&((expected&low)!=expected)
                below=inside&(samples[:,1]<np.float32(.8))
                row['missingSupportMasks']=int(missing.sum());row['belowActiveMasksMatch']=bool(np.array_equal(active[below],expected[below]))
                (output/'validation.json').write_text(json.dumps(row,indent=2)+'\n');report['rows'].append(row)
                (args.out/'results.json').write_text(json.dumps(report,indent=2)+'\n')
                if changed.any() or missing.any() or not row['belowActiveMasksMatch']:raise AssertionError(f'Bitwise/support mismatch {output}')
                print(name,width,repeat,'count',len(samples),'exact',row['bitwiseEqual'],'candidates',row['meanCandidateBitsInside'],'change',row.get('pairedChangeMedianPercent'),flush=True)


if __name__=='__main__':main()
