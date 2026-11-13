#!/usr/bin/env python3
"""Reuse frozen partition-study inputs to isolate locality in true field cost."""
import argparse
import json
from pathlib import Path
import subprocess
import numpy as np
from field_gpu_run import errors


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--native',type=Path,required=True)
    ap.add_argument('--fixtures',type=Path,required=True);ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--width',type=int,default=256);ap.add_argument('--repeats',type=int,nargs='+',default=[1,16])
    ap.add_argument('--bits',type=int,default=16);ap.add_argument('--cases',nargs='+',default=['single_texture_pairs','scatter_texture_pairs'])
    ap.add_argument('--orders',nargs='+',default=['fixture_interleaved','fixture_spatial_sorted','grid_row_major','grid_shuffled'])
    args=ap.parse_args();args.out.mkdir(parents=True,exist_ok=False)
    rows=[];channels=[0,1,2,4,5,6,8,9,10,12,13,14]
    for case in args.cases:
        for order in args.orders:
            fixture=args.fixtures/(case+'-'+order)
            previous=np.fromfile(fixture/'gpu/reference.bin',dtype='<f4').reshape(-1,16)
            previous_candidate=np.fromfile(fixture/'gpu/mixed.bin',dtype='<f4').reshape(-1,16)
            for repeat in args.repeats:
                name=f'{case}-{order}-{args.width}-repeat{repeat}-{args.bits}bit';out=args.out/name
                command=[str(args.native/'evaluate'),str(args.native/'field.metal'),str(fixture/'samples.bin'),str(fixture/'balls.bin'),str(out),str(args.width),str(args.width//2),str(repeat),str(args.bits)]
                result=subprocess.run(command,capture_output=True,text=True)
                (args.out/(name+'.log')).write_text(result.stdout+result.stderr)
                if result.returncode:raise RuntimeError(result.stderr[-2500:])
                ref=np.fromfile(out/'reference.bin',dtype='<f4').reshape(-1,16)
                point=np.fromfile(out/'point.bin',dtype='<f4').reshape(-1,16)
                field=np.fromfile(out/'total.bin',dtype='<f4').reshape(-1,16)
                use=point[:,11]==1
                assert np.array_equal(ref,previous),'Reference changed'
                assert np.array_equal(field[~use],ref[~use]),'Field fallback changed'
                assert np.array_equal(point[~use],ref[~use]),'Point fallback changed'
                assert np.array_equal(use,field[:,11]==1),'Eligibility changed'
                pointcheck=errors(previous_candidate[use][:,channels],point[use][:,channels])
                assert pointcheck['max']<2e-4,'Point extraction changed'
                row=json.loads((out/'metadata.json').read_text())
                row.update({'case':case,'order':order,'fixture':str(fixture),'used':int(use.sum()),'eligible_fraction':float(use.mean()),
                    'fallback_exact':True,'reference_matches_previous':True,'point_vs_previous_candidate':pointcheck,
                    'field_vs_point':errors(point[use][:,channels],field[use][:,channels]),
                    'field_vs_reference_corrected_diffuse':errors(ref[use,8:11],field[use,8:11]),
                    'field_vs_reference_specular':errors(ref[use,12:15],field[use,12:15])})
                (out/'validation.json').write_text(json.dumps(row,indent=2)+'\n');rows.append(row)
                print(name,'use',row['eligible_fraction'],'ms',row['referenceMedianMS'],row['totalMedianMS'],'paired%',row['pairedChangeMedianPercent'],flush=True)
                (args.out/'results.json').write_text(json.dumps({'scope':__doc__,'rows':rows},indent=2)+'\n')


if __name__=='__main__':main()
