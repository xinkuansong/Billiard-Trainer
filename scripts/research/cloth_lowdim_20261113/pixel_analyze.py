"""Record exact GPU reference mask costs and timing sensitivity, without editing inputs."""
from pathlib import Path
import argparse
import json
import numpy as np


def distribution(a):
    if len(a)==0:
        return {'count':0}
    return {'count':len(a),'mean':float(a.mean()),'median':float(np.median(a)),
            'p95':float(np.quantile(a,.95)),'max':int(a.max()),
            'histogram':{str(int(k)):int((a==k).sum()) for k in np.unique(a)}}


def analyze(out):
    results=json.loads((out/'results.json').read_text())
    pop=np.array([i.bit_count() for i in range(256)])
    rows=[]
    for row in results['rows']:
        case=out/row['name'];samples=np.fromfile(case/'samples.bin',dtype='<f4').reshape(-1,12)
        ref=np.fromfile(case/'gpu/reference.bin',dtype='<f4').reshape(-1,16)
        masks=ref[:,7].astype(np.uint32)
        counts=pop[masks&255]+pop[(masks>>8)&255]
        bed=np.load(case/'bed-mask.npy');near=ref[:,3]>0
        below=samples[:,1]<np.float32(.8)
        timings=[]
        for comp in row['native']['comparisons']:
            stable=[c['pairedChangePercent'] for c in comp['cycles'] if c['referenceEndpointDriftPercent']<=5]
            timings.append({'candidate':comp['candidate'],'all_cycle_change':comp['pairedChangeMedianPercent'],
                            'stable_cycle_count':len(stable),'post_hoc_5pct_drift_change':float(np.median(stable)) if stable else None,
                            'max_reference_endpoint_drift':max(c['referenceEndpointDriftPercent'] for c in comp['cycles']),
                            'paired_min':min(c['pairedChangePercent'] for c in comp['cycles']),
                            'paired_max':max(c['pairedChangePercent'] for c in comp['cycles'])})
        rows.append({'name':row['name'],'kind':row['kind'],'samples':len(samples),'near_count':int(near.sum()),
                     'below_count':int(below.sum()),'near_below_count':int((near&below).sum()),
                     'near_below_fraction_of_near':float((near&below).sum()/near.sum()) if near.any() else 0,
                     'bed_count':int(bed.sum()),'bed_below_fraction':float(below[bed].mean()) if bed.any() else 0,
                     'bed_near_below_count':int((bed&near&below).sum()),
                     'mask_popcount_near':distribution(counts[near]),
                     'mask_popcount_bed_near':distribution(counts[bed&near]),
                     'mask_popcount_near_below':distribution(counts[near&below]),
                     'mask_popcount_near_not_below':distribution(counts[near&~below]),
                     'timing_sensitivity':timings})
    result={'scope':__doc__,'height_test':'input float32 y < float32(0.8), matching Metal constant; no snapping',
            'mask_source':'original reference Result.sampled.w, exact integer below 2^16',
            'timing_sensitivity':'post hoc only; all cycles retained in primary results','rows':rows}
    (out/'mask-and-timing-analysis.json').write_text(json.dumps(result,indent=2)+'\n')
    return result


if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('out',type=Path);args=ap.parse_args()
    analyze(args.out)
