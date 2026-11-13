"""Compare fixed-loop K2/K4/K8 and frozen K4 on captured or synthetic receivers.

Actual fixtures preserve all visible TaiNi rows, including rail cloth, in captured
pixel order; no near-only or bed-only filtering. Frozen consumption excludes all
moment generation/update/lookup costs and is an upper-bound diagnostic only.
"""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import numpy as np
import study


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare_case(case, samples, balls, bed_mask):
    case.mkdir()
    samples.astype('<f4').tofile(case/'samples.bin')
    balls.astype('<f4').tofile(case/'balls.bin')
    np.save(case/'bed-mask.npy',bed_mask)
    moments=np.zeros((len(samples),10,4),dtype='<f4')
    cpu=np.zeros((len(samples),6))
    near=np.zeros(len(samples),dtype=bool)
    use=np.zeros(len(samples),dtype=bool)
    for start in range(0,len(samples),2048):
        stop=min(start+2048,len(samples));sl=slice(start,stop);chunk=samples[sl]
        p=chunk[:,:3].astype(float);n=study.unit(chunk[:,4:7].astype(float));v=study.unit(chunk[:,8:11].astype(float));rough=chunk[:,11].astype(float)
        e0,e,s,data=study.reference(p,n,v,rough,balls.astype(float))
        cpu[sl,:3]=np.column_stack((e0,e,s));near[sl]=data[3]
        for slot,(k,nx,nz) in enumerate([(2,2,1),(4,2,2),(8,4,2)],3):
            _,_,cs,enabled,_,m,mv,m0=study.candidate(p,n,v,rough,data,nx,nz)
            cpu[sl,slot]=np.where(enabled,cs,s)
            if k==4:
                moments[sl,0,:3]=mv;moments[sl,0,3]=enabled;moments[sl,1,:3]=m0;moments[sl,2:,:3]=m
                use[sl]=enabled
    moments.tofile(case/'moments4.bin')
    np.savez(case/'cpu.npz',values=cpu,near=near,use=use)
    return {'samples':len(samples),'near_count':int(near.sum()),'eligible_count':int(use.sum()),'eligible_fraction':float(use.mean()),
            'bed_count':int(bed_mask.sum()),'bed_eligible_count':int((use&bed_mask).sum()),
            'near_guard_fallback':int((near&~use).sum()),
            'position_min':samples[:,:3].min(axis=0).tolist(),'position_max':samples[:,:3].max(axis=0).tolist(),
            'roughness_range':[float(samples[:,11].min()),float(samples[:,11].max())],
            'sample_sha256':digest(case/'samples.bin'),'balls_sha256':digest(case/'balls.bin')}


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--native',type=Path,required=True)
    ap.add_argument('--synthetic',type=Path)
    ap.add_argument('--actual',type=Path)
    ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--batch-count',type=int,default=8)
    ap.add_argument('--prepare-only',action='store_true')
    args=ap.parse_args()
    if args.synthetic is None and args.actual is None:
        raise ValueError('At least one fixture source is required')
    args.out.mkdir(parents=True,exist_ok=False)
    source=Path(__file__).resolve().parent
    kernel=args.out/'kernels.metal';binary=args.out/'pixel_evaluate'
    subprocess.run(['python3',str(source/'inline_lowk_prepare.py'),str(args.native/'reference.metal'),str(kernel)],check=True)
    proc=subprocess.run(['xcrun','swiftc','-O',str(source/'pixel_evaluate.swift'),'-o',str(binary)],capture_output=True,text=True)
    (args.out/'build.log').write_text(proc.stdout+proc.stderr)
    if proc.returncode:
        raise RuntimeError(proc.stdout+proc.stderr)
    names=['inline_lowk_prepare.py','pixel_evaluate.swift','pixel_run.py','inline_prepare.py','study.py']
    (args.out/'source').mkdir()
    for name in names:
        (args.out/'source'/name).write_bytes((source/name).read_bytes())
    manifest={'source_hashes':{name:digest(source/name) for name in names},'scope':__doc__,
              'reference_sha256':digest(args.native/'reference.metal'),'batch_count':args.batch_count,
              'synthetic_source':str(args.synthetic),'actual_source':str(args.actual)}
    jobs=[]
    if args.synthetic:
        for scene in ['single_texture_pairs','scatter_texture_pairs']:
            name=scene+'-grid_row_major';fixture=args.synthetic/name
            samples=np.fromfile(fixture/'samples.bin',dtype='<f4').reshape(-1,12)
            balls=np.fromfile(fixture/'balls.bin',dtype='<f4').reshape(-1,4)
            case=args.out/name
            stats=prepare_case(case,samples,balls,np.ones(len(samples),dtype=bool))
            jobs.append({'name':name,'kind':'previous_synthetic_uniform_grid','case':str(case),'statistics':stats})
            print('prepared',name,stats['samples'],'eligible',stats['eligible_count'],flush=True)
    if args.actual:
        fixtures=json.loads((args.actual/'pixel-fixtures.json').read_text())
        manifest['actual_fixtures_sha256']=digest(args.actual/'pixel-fixtures.json')
        (args.out/'pixel-fixtures.json').write_bytes((args.actual/'pixel-fixtures.json').read_bytes())
        for record in fixtures['records']:
            name=record['id'];raw=np.load(args.actual/(name+'-actual-inputs.npy'))
            if raw.ndim!=2 or raw.shape[1]!=10:
                raise ValueError('Expected p,n,v,rough 10-float records')
            samples=np.zeros((len(raw),12),dtype='<f4');samples[:,:3]=raw[:,:3];samples[:,4:7]=raw[:,3:6];samples[:,8:11]=raw[:,6:9];samples[:,11]=raw[:,9]
            bed=np.load(args.actual/(name+'-bed-mask.npy')).astype(bool)
            pixels=np.load(args.actual/(name+'-pixel-indices.npy'))
            if len(pixels)!=len(raw) or len(bed)!=len(raw) or not np.all(np.diff(pixels)>0):
                raise ValueError('Pixel order or mask contract failed')
            case=args.out/name
            stats=prepare_case(case,samples,np.array(record['packedBalls'],dtype='<f4'),bed)
            np.save(case/'pixel-indices.npy',pixels)
            stats['captured_input_sha256']=digest(args.actual/(name+'-actual-inputs.npy'))
            jobs.append({'name':name,'kind':'SceneKit_filtered_visible_TaiNi_row_major','case':str(case),'statistics':stats})
            print('prepared',name,stats['samples'],'eligible',stats['eligible_count'],flush=True)
    for item in jobs:
        case=Path(item['case'])
        item['command']=[str(binary),str(kernel),str(case/'samples.bin'),str(case/'balls.bin'),str(case/'moments4.bin'),str(case/'gpu'),str(args.batch_count)]
    (args.out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (args.out/'commands.json').write_text(json.dumps(jobs,indent=2)+'\n')
    if not args.prepare_only:
        execute(args.out)


def execute(out):
    jobs=json.loads((out/'commands.json').read_text())
    rows=[]
    for item in jobs:
        case=Path(item['case'])
        proc=subprocess.run(item['command'],capture_output=True,text=True)
        (case/'run.log').write_text(proc.stdout+proc.stderr)
        if proc.returncode:
            raise RuntimeError(proc.stdout+proc.stderr)
        cpu=np.load(case/'cpu.npz');values=cpu['values'];use=cpu['use']
        ref=np.fromfile(case/'gpu/reference.bin',dtype='<f4').reshape(-1,16)
        errors={key:study.metrics(ref[:,offset:offset+3],values[:,slot,None]*study.COLOR)
                for key,offset,slot in [('E0',0,0),('sampledE',4,1),('S',12,2)]}
        if any(v['abs_max']>2e-4 for v in errors.values()):
            raise AssertionError(('Reference CPU mismatch',item['name'],errors))
        candidate_rows=[]
        for mode,slot in [('grouped2',3),('grouped4',4),('grouped8',5),('frozen4',4)]:
            trial=np.fromfile(case/'gpu'/(mode+'.bin'),dtype='<f4').reshape(-1,16)
            agreement=study.metrics(trial[:,12:15],values[:,slot,None]*study.COLOR)
            if agreement['abs_max']>2e-4:
                raise AssertionError(('Candidate CPU mismatch',item['name'],mode,agreement))
            candidate_rows.append({'mode':mode,'cpu_agreement':agreement,
                'reference_error_all':study.metrics(ref[:,12:15],trial[:,12:15]),
                'reference_error_eligible':study.metrics(ref[use,12:15],trial[use,12:15]) if use.any() else None})
        native=json.loads((case/'gpu/result.json').read_text())
        rows.append({'name':item['name'],'kind':item['kind'],'statistics':item['statistics'],
                     'reference_cpu_agreement':errors,'candidate_errors':candidate_rows,'native':native})
        print(item['name'],[(c['candidate'],round(c['pairedChangeMedianPercent'],2)) for c in native['comparisons']],flush=True)
        (out/'partial-results.json').write_text(json.dumps(rows,indent=2)+'\n')
    (out/'results.json').write_text(json.dumps({'scope':__doc__,'rows':rows},indent=2)+'\n')


if __name__=='__main__':
    main()
