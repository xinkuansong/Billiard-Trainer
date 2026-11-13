"""Lighting-only output benchmark with untouched diagnostic validation kernels.

Each --candidate is NAME=path/to/height-support.metal. The five actual fixture
inputs and prior reference.bin are reused byte-for-byte. Preparation is CPU only;
explicit execute(out) or omission of --prepare-only runs the coordinated GPU batch.
"""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess

POSES=['single-low','single-near','edge-low','rack-overview','scatter-overview']


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--candidate',action='append',required=True)
    ap.add_argument('--fixtures',type=Path,required=True)
    ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--batch-count',type=int,default=8)
    ap.add_argument('--prepare-only',action='store_true')
    args=ap.parse_args()
    args.out.mkdir(parents=True,exist_ok=False)
    here=Path(__file__).resolve().parent
    binary=args.out/'benchmark'
    proc=subprocess.run(['xcrun','swiftc','-O',str(here/'support_lighting_benchmark.swift'),'-o',str(binary)],capture_output=True,text=True)
    (args.out/'build.log').write_text(proc.stdout+proc.stderr)
    if proc.returncode:
        raise RuntimeError(proc.stdout+proc.stderr)
    (args.out/'source').mkdir()
    names=['support_lighting_benchmark.swift','support_lighting_run.py']
    for name in names:
        (args.out/'source'/name).write_bytes((here/name).read_bytes())
    jobs=[];reference_hash=None;candidate_names=set();sources=[]
    for item in args.candidate:
        name,location=item.split('=',1)
        if not name or any(c not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-' for c in name) or name in candidate_names:
            raise ValueError('Candidate names must be unique safe path components')
        candidate_names.add(name);source=Path(location);body=source.read_text()
        start=body.index('inline Result referenceAt(');end=body.index('inline float groupBRDF(',start)
        current=hashlib.sha256(body[start:end].encode()).hexdigest()
        if reference_hash is not None and current!=reference_hash:
            raise ValueError('Reference arithmetic differs between candidates')
        reference_hash=current
        if body.count('inline Result heightSupportAt(')!=1:
            raise ValueError('Missing or ambiguous candidate function')
        variant=args.out/name;variant.mkdir();kernel=variant/'height-support.metal';kernel.write_bytes(source.read_bytes())
        sources.append({'name':name,'origin':str(source),'sha256':digest(source),'reference_function_sha256':current})
        for pose in POSES:
            case=variant/pose;case.mkdir();fixture=args.fixtures/pose
            for file in ['samples.bin','balls.bin']:
                (case/file).write_bytes((fixture/file).read_bytes())
            (case/'expected-reference.bin').write_bytes((fixture/'gpu/reference.bin').read_bytes())
            jobs.append({'variant':name,'pose':pose,'case':str(case),
                'input_sha256':digest(case/'samples.bin'),'balls_sha256':digest(case/'balls.bin'),
                'external_reference_sha256':digest(case/'expected-reference.bin'),
                'command':[str(binary),str(kernel),str(case/'samples.bin'),str(case/'balls.bin'),str(case/'gpu'),str(args.batch_count),str(case/'expected-reference.bin')]})
    manifest={'scope':__doc__,'source_hashes':{name:digest(here/name) for name in names},'candidates':sources,
              'fixtures':str(args.fixtures),'batch_count':args.batch_count,'cases':len(jobs)}
    (args.out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (args.out/'commands.json').write_text(json.dumps(jobs,indent=2)+'\n')
    if args.prepare_only:
        print('CPU prepared and Swift compiled; GPU not run:',len(jobs),'cases')
    else:
        execute(args.out)


def execute(out):
    rows=[]
    for item in json.loads((out/'commands.json').read_text()):
        case=Path(item['case']);proc=subprocess.run(item['command'],capture_output=True,text=True)
        (case/'run.log').write_text(proc.stdout+proc.stderr)
        if proc.returncode:
            raise RuntimeError(proc.stdout+proc.stderr)
        result=json.loads((case/'gpu/result.json').read_text())
        rows.append({'variant':item['variant'],'pose':item['pose'],'native':result})
        print(item['variant'],item['pose'],round(result['pairedChangeMedianPercent'],2),flush=True)
        (out/'partial-results.json').write_text(json.dumps(rows,indent=2)+'\n')
    (out/'results.json').write_text(json.dumps({'scope':__doc__,'rows':rows},indent=2)+'\n')


if __name__=='__main__':
    main()
