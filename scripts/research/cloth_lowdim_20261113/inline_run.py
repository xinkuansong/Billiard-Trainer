"""Benchmark local moments on the exact previous mixed/sorted/uniform-grid inputs.

Grid positions cover the bed; normals/roughness are cycled paired asset samples,
not actual projected fragments or a UV-mapped mesh. All approximation errors and
timing rows remain in output; no production files are modified.
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--native', type=Path, required=True)
    ap.add_argument('--fixtures', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--batch-count', type=int, default=8)
    ap.add_argument('--prepare-only', action='store_true')
    ap.add_argument('--stream-moments', action='store_true')
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=False)
    source = Path(__file__).resolve().parent
    kernel = args.out/'inline.metal'
    binary = args.out/'inline_evaluate'
    prepare = ['python3', str(source/'inline_prepare.py'), str(args.native/'reference.metal'), str(kernel)]
    if args.stream_moments:
        prepare.append('--stream-moments')
    subprocess.run(prepare, check=True)
    proc = subprocess.run(['xcrun', 'swiftc', '-O', str(source/'inline_evaluate.swift'), '-o', str(binary)], capture_output=True, text=True)
    (args.out/'build.log').write_text(proc.stdout+proc.stderr)
    if proc.returncode:
        raise RuntimeError(proc.stdout+proc.stderr)
    (args.out/'source').mkdir()
    names = ['inline_prepare.py', 'inline_evaluate.swift', 'inline_run.py']
    for name in names:
        (args.out/'source'/name).write_bytes((source/name).read_bytes())
    manifest = {'source_hashes': {name: digest(source/name) for name in names+['study.py']},
                'reference_sha256': digest(args.native/'reference.metal'), 'fixtures': str(args.fixtures),
                'batch_count': args.batch_count, 'stream_moments': args.stream_moments, 'scope': __doc__}
    (args.out/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    commands = []
    for scene in ['single_texture_pairs', 'scatter_texture_pairs']:
        for order in ['fixture_interleaved', 'fixture_spatial_sorted', 'grid_row_major', 'grid_shuffled']:
            name = scene+'-'+order
            case = args.out/name
            case.mkdir()
            fixture = args.fixtures/name
            for filename in ['samples.bin', 'balls.bin']:
                (case/filename).write_bytes((fixture/filename).read_bytes())
            commands.append({'scene': scene, 'order': order, 'case': str(case),
                'command': [str(binary), str(kernel), str(case/'samples.bin'), str(case/'balls.bin'), str(case/'gpu'), str(args.batch_count)]})
    (args.out/'commands.json').write_text(json.dumps(commands, indent=2)+'\n')
    if args.prepare_only:
        print('CPU preparation complete:', args.out)
        return
    execute(args.out)


def execute(out):
    commands = json.loads((out/'commands.json').read_text())
    rows = []
    for item in commands:
        case = Path(item['case'])
        proc = subprocess.run(item['command'], capture_output=True, text=True)
        (case/'run.log').write_text(proc.stdout+proc.stderr)
        if proc.returncode:
            raise RuntimeError(proc.stdout+proc.stderr)
        samples = np.fromfile(case/'samples.bin', dtype='<f4').reshape(-1,12)
        balls = np.fromfile(case/'balls.bin', dtype='<f4').reshape(-1,4).astype(float)
        ref = np.fromfile(case/'gpu/reference.bin', dtype='<f4').reshape(-1,16)
        trial = np.fromfile(case/'gpu/inline.bin', dtype='<f4').reshape(-1,16)
        p = samples[:,:3].astype(float)
        n = study.unit(samples[:,4:7].astype(float))
        v = study.unit(samples[:,8:11].astype(float))
        rough = samples[:,11].astype(float)
        e0,e,s,data = study.reference(p,n,v,rough,balls)
        _,_,cs,use,_,_,_,_ = study.candidate(p,n,v,rough,data,4,2)
        cs = np.where(use,cs,s)
        errors = {key: study.metrics(ref[:,offset:offset+3], value[:,None]*study.COLOR)
                  for key,offset,value in [('E0',0,e0),('sampledE',4,e),('S',12,s)]}
        candidate_model = study.metrics(trial[:,12:15],cs[:,None]*study.COLOR)
        if any(v['abs_max']>2e-4 for v in errors.values()) or candidate_model['abs_max']>2e-4:
            raise AssertionError((errors,candidate_model))
        if not np.array_equal(trial[:,11],use.astype(float)):
            raise AssertionError('Eligibility mismatch')
        native = json.loads((case/'gpu/result.json').read_text())
        row = {'scene': item['scene'], 'order': item['order'], 'samples':len(samples),
               'reference_cpu_agreement': errors, 'candidate_cpu_agreement': candidate_model,
               'candidate_reference_specular_error':study.metrics(ref[:,12:15],trial[:,12:15]),
               'eligible_reference_specular_error':study.metrics(ref[use,12:15],trial[use,12:15]) if use.any() else None,
               'input_sha256':digest(case/'samples.bin'), 'native':native}
        rows.append(row)
        print(item['scene'],item['order'],'eligible',round(use.mean()*100,3),'change%',round(native['pairedChangeMedianPercent'],2),flush=True)
        (out/'partial-results.json').write_text(json.dumps(rows,indent=2)+'\n')
    (out/'results.json').write_text(json.dumps({'scope':__doc__,'rows':rows},indent=2)+'\n')


if __name__ == '__main__':
    main()
