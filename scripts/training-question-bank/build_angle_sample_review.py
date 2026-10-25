#!/usr/bin/env python3
"""Create a uniform, without-replacement 500-layout review of the sampled bank."""
from dataclasses import asdict
import hashlib
import json
import math
from pathlib import Path
import random

from pocket_geometry_filter import ROOT, Geometry, layouts, pocket_metrics, validate_bank


def main():
    source = ROOT/'output/two-ball-angle-sampled-20261024/angle-sampled-bank.json'
    raw = source.read_bytes()
    bank = json.loads(raw)
    geometry = Geometry(**{k:bank['geometry'][k] for k in ('length','width','radius')})
    validate_bank(bank,geometry)
    total = sum(bank['counts'].values())
    seed, count = 202610240500, 500
    ranks = random.Random(seed).sample(range(total), count)
    order = {rank:i for i,rank in enumerate(ranks)}
    selected = [None]*count
    for rank,(lid,cue,obj,pid,angle) in enumerate(layouts(bank)):
        if rank not in order:
            continue
        metric = pocket_metrics(cue,obj,geometry.anchors()[pid],geometry.radius,pid)
        assert abs(metric.cut_degrees-angle)<1e-9
        index = order[rank]
        selected[index] = dict(number=index+1,id=lid,sourceRank=rank,cue=cue,target=obj,
                              original=asdict(metric),cueObjectDistance=math.dist(cue,obj))
    assert all(selected) and len({s['id'] for s in selected}) == count
    assert source.read_bytes() == raw
    output = source.parent/'review-500'
    output.mkdir(exist_ok=False)
    payload = dict(reviewId='angle-sampled-uniform-500-v1',seed=seed,count=count,bankTotal=total,
                   sourceSHA256=hashlib.sha256(raw).hexdigest(),geometry=asdict(geometry),
                   anchors=geometry.anchors(),samples=selected)
    (output/'samples.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n')
    template = Path(__file__).with_name('angle_sample_review.html').read_text()
    assert template.count('__PAYLOAD__')==1
    (output/'index.html').write_text(template.replace('__PAYLOAD__',json.dumps(payload,ensure_ascii=False,separators=(',',':'))))
    verification = dict(sourceUnchanged=True,sourceTotal=total,sampleSize=count,uniqueIDs=count,
                        uniformWithoutReplacement=True,seed=seed,
                        count5to20=sum(5<=s['original']['cut_degrees']+1e-9 and s['original']['cut_degrees']<=20+1e-9 for s in selected),
                        meanCutDegrees=sum(s['original']['cut_degrees'] for s in selected)/count)
    (output/'verification.json').write_text(json.dumps(verification,indent=2)+'\n')
    print(json.dumps(dict(output=str(output),**verification),ensure_ascii=False))


if __name__=='__main__':main()
