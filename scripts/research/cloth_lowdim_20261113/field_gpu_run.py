#!/usr/bin/env python3
"""Run and validate spatial-field Metal experiments; inputs are frozen math samples."""
import argparse
import json
from pathlib import Path
import subprocess
import numpy as np


def errors(a,b):
    e=np.abs(a-b)
    return {'mean':float(e.mean()),'p95':float(np.quantile(e,.95)),'max':float(e.max())}


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--native',type=Path,required=True)
    ap.add_argument('--study',type=Path,required=True);ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--widths',type=int,nargs='+',default=[128,256,512])
    ap.add_argument('--repeats',type=int,nargs='+',default=[1,64,1024])
    ap.add_argument('--cases',nargs='+',default=['single_texture_pairs','scatter_texture_pairs'])
    args=ap.parse_args();args.out.mkdir(parents=True,exist_ok=False)
    report={'scope':'Metal core generation+consumption; original frozen sample distribution. Not final images/frame/present/iOS.', 'rows':[]}
    channels=[0,1,2,4,5,6,8,9,10,12,13,14]
    for case in args.cases:
        fixture=args.study/case
        reference0=np.fromfile(fixture/'reference.bin',dtype='<f4').reshape(-1,16)
        cpu_point=np.load(fixture/'candidate-8.npz')['S']
        for width in args.widths:
            for repeat in args.repeats:
                name=f'{case}-{width}-repeat{repeat}';out=args.out/name
                command=[str(args.native/'evaluate'),str(args.native/'field.metal'),str(fixture/'samples.bin'),str(fixture/'balls.bin'),str(out),str(width),str(width//2),str(repeat)]
                process=subprocess.run(command,capture_output=True,text=True)
                (args.out/(name+'.log')).write_text(process.stdout+process.stderr)
                if process.returncode: raise RuntimeError(f'Native experiment failed: {name}: {process.stderr[-2000:]}')
                ref=np.fromfile(out/'reference.bin',dtype='<f4').reshape(-1,16)
                point=np.fromfile(out/'point.bin',dtype='<f4').reshape(-1,16)
                field=np.fromfile(out/'total.bin',dtype='<f4').reshape(-1,16)
                use=point[:,11]==1
                assert np.array_equal(ref,reference0),'Current reference drift'
                assert np.array_equal(use,field[:,11]==1),'Eligibility drift'
                assert np.array_equal(field[~use],ref[~use]),'Fallback changed'
                assert np.array_equal(point[~use],ref[~use]),'Point fallback changed'
                point_crosscheck=errors(cpu_point[use],point[use,12])
                assert point_crosscheck['max']<2e-4,'Point transport/BRDF extraction disagrees with independent CPU'
                row=json.loads((out/'metadata.json').read_text())
                row.update({'case':case,'used':int(use.sum()),'fallback_exact':True,
                    'reference_matches_previous':True,'field_vs_point':errors(point[use][:,channels],field[use][:,channels]),
                    'point_cpu_specular_crosscheck':point_crosscheck,
                    'field_vs_reference':errors(ref[use][:,channels],field[use][:,channels]),
                    'field_vs_reference_corrected_diffuse':errors(ref[use,8:11],field[use,8:11]),
                    'field_vs_reference_specular':errors(ref[use,12:15],field[use,12:15]),
                    'point_vs_reference':errors(ref[use][:,channels],point[use][:,channels])})
                (out/'validation.json').write_text(json.dumps(row,indent=2)+'\n')
                report['rows'].append(row)
                print(name,'used',int(use.sum()),'ms',row['referenceMedianMS'],row['totalMedianMS'],'change',row['changePercent'],flush=True)
    (args.out/'results.json').write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__':main()
