"""R2 exact-domain GPU partition experiment, preserving all input/output indices.

Two measured-material fixtures, same 24576-record mixed dataset as R1, plus a
synthetic raster-like grid using those paired normals/roughness. Grid material
pairs are cycled, NOT mapped via production UV. No App or iPhone claim.
"""
from pathlib import Path
import argparse,hashlib,json,subprocess
import numpy as np
import study


def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--native',type=Path,required=True);ap.add_argument('--study',type=Path,required=True)
    ap.add_argument('--out',type=Path,required=True);ap.add_argument('--repeat-input',type=int,default=64);ap.add_argument('--include-grid',action='store_true');ap.add_argument('--batch-count',type=int,default=1)
    a=ap.parse_args();a.out.mkdir(parents=True,exist_ok=False)
    repo=Path(__file__).resolve().parents[3]
    source=Path(__file__).resolve().parent
    kernel=a.out/'split.metal';binary=a.out/'split_evaluate'
    subprocess.run(['python3',str(source/'split_prepare.py'),str(a.native/'reference.metal'),str(kernel)],check=True)
    build=subprocess.run(['xcrun','swiftc','-O',str(source/'split_evaluate.swift'),'-o',str(binary)],capture_output=True,text=True)
    (a.out/'build.log').write_text(build.stdout+build.stderr)
    if build.returncode:raise RuntimeError(build.stdout+build.stderr)
    manifest={'source_hashes':{str(p.relative_to(repo)):digest(p) for p in [source/'split_run.py',source/'split_prepare.py',source/'split_evaluate.swift',source/'study.py']},
              'reference_sha256':digest(a.native/'reference.metal'),'study':str(a.study),'repeat_input':a.repeat_input,'batch_count':a.batch_count}
    (a.out/'source').mkdir()
    for name in ['split_prepare.py','split_evaluate.swift','split_run.py']:(a.out/'source'/name).write_bytes((source/name).read_bytes())
    (a.out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    rows=[];rng=np.random.default_rng(2026111302)
    for name in ['single_texture_pairs','scatter_texture_pairs']:
        folder=a.study/name
        base=np.fromfile(folder/'samples.bin',dtype='<f4').reshape(-1,12)
        balls=np.fromfile(folder/'balls.bin',dtype='<f4').reshape(-1,4)
        bm=np.fromfile(folder/'moments-8.bin',dtype='<f4').reshape(len(base),18,4)
        cpu=np.load(folder/'candidate-8.npz')
        tiled=np.tile(base,(a.repeat_input,1));tm=np.tile(bm,(a.repeat_input,1,1))
        datasets=[('fixture_interleaved',tiled,tm),('fixture_spatial_sorted',tiled,tm)]
        if a.include_grid:
            if len(tiled)!=24576:raise ValueError('grid requires standard 24576 records')
            xs=np.linspace(-1.25,1.25,192);zs=np.linspace(-.62,.62,128)
            x,z=np.meshgrid(xs,zs);samples=tiled.copy();samples[:,:3]=np.column_stack((x.ravel(),np.full(len(tiled),.8),z.ravel()))
            # Paired actual texture samples remain paired; synthetic camera sees this grid.
            v=study.unit(np.array([0.,1.6,1.6])-samples[:,:3]);n=study.unit(samples[:,4:7].astype(float))
            bad=(n*v).sum(axis=1)<.02;v[bad]=study.unit(v[bad]+2*n[bad]);samples[:,8:11]=v
            p=samples[:,:3].astype(float);n=study.unit(samples[:,4:7].astype(float));v=study.unit(samples[:,8:11].astype(float));r=samples[:,11].astype(float)
            data=study.transport(p,balls.astype(float))
            num,den,spec,use,guard,M,mv,m0=study.candidate(p,n,v,r,data,4,2)
            mom=np.zeros((len(samples),18,4),dtype='<f4');mom[:,0,:3]=mv;mom[:,0,3]=use;mom[:,1,:3]=m0;mom[:,2:,:3]=M
            datasets += [('grid_row_major',samples,mom),('grid_shuffled',samples,mom)]
        for order,samples,mom in datasets:
            indices=np.arange(len(samples))
            if order=='fixture_spatial_sorted':indices=np.lexsort((samples[:,0],samples[:,2]))
            elif order=='grid_shuffled':indices=rng.permutation(len(samples))
            selected=samples[indices].copy();moments=mom[indices].copy()
            case=a.out/(name+'-'+order);case.mkdir()
            selected.tofile(case/'samples.bin');moments.tofile(case/'moments.bin');balls.tofile(case/'balls.bin')
            np.save(case/'permutation.npy',indices)
            cmd=[str(binary),str(kernel),str(case/'samples.bin'),str(case/'balls.bin'),str(case/'moments.bin'),str(case/'gpu'),str(a.batch_count)]
            result=subprocess.run(cmd,capture_output=True,text=True);(case/'run.log').write_text(result.stdout+result.stderr)
            if result.returncode:raise RuntimeError(result.stdout+result.stderr)
            reference=np.fromfile(case/'gpu/reference.bin',dtype='<f4').reshape(-1,16)
            mixed=np.fromfile(case/'gpu/mixed.bin',dtype='<f4').reshape(-1,16)
            split=np.fromfile(case/'gpu/split.bin',dtype='<f4').reshape(-1,16)
            use=moments[:,0,3]==1
            # Cross-check production core versus existing independent CPU model on these inputs.
            p=selected[:,:3].astype(float);n=study.unit(selected[:,4:7].astype(float));v=study.unit(selected[:,8:11].astype(float));rough=selected[:,11].astype(float)
            E0,E,S,data=study.reference(p,n,v,rough,balls.astype(float))
            errors={key:study.metrics(reference[:,offset:offset+3],value[:,None]*study.COLOR)
                    for key,offset,value in [('E0',0,E0),('sampledE',4,E),('S',12,S)]}
            if any(e['abs_max']>2e-4 for e in errors.values()):raise AssertionError(errors)
            if not np.array_equal(split[~use],reference[~use]):raise AssertionError('fallback changed')
            if not np.allclose(split,mixed,rtol=0,atol=2e-4):raise AssertionError('split differs from mixed')
            native=json.loads((case/'gpu/result.json').read_text())
            rows.append({'scene':name,'order':order,'samples':len(samples),'eligible_fraction':float(use.mean()),'K_per_panel':8,
                         'cpu_reference_agreement':errors,'native':native})
            print(name,order,[(v['candidate'],round(v['pairedChangeMedianPercent'],2)) for v in native['comparisons']],flush=True)
            (a.out/'partial-results.json').write_text(json.dumps(rows,indent=2)+'\n')
    (a.out/'results.json').write_text(json.dumps({'scope':__doc__,'rows':rows},indent=2)+'\n')

if __name__=='__main__':main()
