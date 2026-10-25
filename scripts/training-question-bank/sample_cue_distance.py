#!/usr/bin/env python3
"""Thin only the 30-45 and 45-60 cm CO bins; retain every other layout."""
import argparse
from collections import Counter, defaultdict
import json
import math
from pathlib import Path

from filter_geometric_bank import retain_target, sha, write_json
from pocket_geometry_filter import Geometry, ROOT, layouts, validate_bank
from sample_angle_curve import records

QUOTAS = {2:18000, 3:26000}
SEED = 'cue-distance-two-bins-20261024-v1'


def distance_bin(distance):
    nearest = round(distance/.15)*.15
    if abs(distance-nearest) <= 1e-9:
        distance = nearest
    return math.floor(distance/.15+1e-12)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bank',type=Path,default=ROOT/'output/two-ball-angle-sampled-20261024/angle-sampled-bank.json')
    parser.add_argument('--output',type=Path,required=True)
    args = parser.parse_args()
    raw = args.bank.read_bytes()
    bank = json.loads(raw)
    geometry = Geometry(**{k:bank['geometry'][k] for k in ('length','width','radius')})
    validate_bank(bank,geometry)
    buckets = defaultdict(list)
    for lid,cue,obj,pid,angle in layouts(bank):
        buckets[distance_bin(math.dist(cue,obj))].append(lid)
    assert sum(map(len,buckets.values())) == sum(bank['counts'].values())
    selected = set()
    for b,ids in buckets.items():
        if b in QUOTAS:
            if len(ids)<QUOTAS[b]:
                raise ValueError('Not enough candidates for distance quota')
            ids = sorted(ids,key=lambda lid:(sha((SEED+'\0'+lid).encode()),lid))[:QUOTAS[b]]
        selected.update(ids)
    targets = [retain_target(t,selected) for t in bank['targets']]
    targets = [t for t in targets if t['combinationIndices']]
    counts = Counter()
    for t in targets:
        counts['corner' if t['pocket']<4 else 'middle'] += len(t['combinationIndices'])
    policy = dict(version='cue-distance-two-bins-v1',seed=SEED,
        distanceDefinition='Euclidean cue center to object center (CO), metres',
        quotas=[dict(lowerMetres=.30,upperMetres=.45,keep=18000),
                dict(lowerMetres=.45,upperMetres=.60,keep=26000)],
        intervalConvention='left inclusive, right exclusive; 1e-9 metre boundary snap',
        otherBins='retain all existing IDs',
        selection='lowest SHA256(seed + NUL + stableID) in each selected distance bin, no replacement',
        interpretation='Approximate red sketch heights: 18,000 and 26,000; no image digitization',
        parentSHA256=sha(raw),parentSourceLayoutBankSHA256=bank['sourceLayoutBankSHA256'])
    result = dict(bank,targets=targets,counts=dict(counts),sourceLayoutBankSHA256=sha(raw),
        cueDistanceSampling=policy,distanceSamplingSourceContract=bank['contract'],
        contract=bank['contract']+' Additional thinning only of CO [0.30,0.45) and [0.45,0.60) metre bins.')
    validate_bank(result,geometry)
    args.output.mkdir(parents=True,exist_ok=False)
    destination=args.output/'distance-sampled-bank.json'
    destination.write_text(json.dumps(result,ensure_ascii=False,separators=(',',':'),allow_nan=False)+'\n')
    decoded=json.loads(destination.read_bytes())
    validate_bank(decoded,geometry)
    old_records={r[0]:r[1:] for r in records(bank)}
    new_list=list(records(decoded))
    new_records={r[0]:r[1:] for r in new_list}
    assert len(new_records)==len(new_list)==len(selected)
    assert set(new_records)==selected
    assert all(old_records[k]==v for k,v in new_records.items())
    old_targets={t['inventoryTargetIndex']:t for t in bank['targets']}
    for t in decoded['targets']:
        assert all(v==old_targets[t['inventoryTargetIndex']][k]
                   for k,v in t.items() if k not in ('masks','combinationIndices'))
    for k in ('geometry','distanceSamples','combinationTable','combinationEncoding','geometricScreening','angleSampling'):
        assert decoded[k]==bank[k]
    after=defaultdict(set)
    positions=set()
    distance_sum=0
    for lid,cue,obj,pid,angle in layouts(decoded):
        d=math.dist(cue,obj);distance_sum+=d
        after[distance_bin(d)].add(lid)
        key=tuple(round(v,9) for v in (*cue,*obj))
        assert key not in positions
        positions.add(key)
    for b,ids in buckets.items():
        if b in QUOTAS:
            assert len(after[b])==QUOTAS[b] and after[b]<=set(ids)
        else:
            assert after[b]==set(ids)
    assert args.bank.read_bytes()==raw
    rows=[dict(lowerCentimetres=i*15,upperCentimetres=(i+1)*15,
               before=len(buckets[i]),after=len(after[i]),removed=len(buckets[i])-len(after[i]))
          for i in range(max(buckets)+1)]
    write_json(args.output/'distance-counts.json',rows)
    write_json(args.output/'sampling-policy.json',policy)
    angle_counts=Counter(v[0] for v in new_records.values())
    write_json(args.output/'angle-counts.json',[dict(angle=a,count=angle_counts[a]) for a in range(86)])
    with (args.output/'selected-ids.txt').open('x') as f:
        f.writelines(r[0]+'\n' for r in new_list)
    summary=dict(sourceTotal=len(old_records),sampled=len(selected),removed=len(old_records)-len(selected),
        counts=dict(counts),changedBins=[r for r in rows if r['removed']],
        meanCueObjectDistanceCentimetres=distance_sum/len(selected)*100,
        sourceSHA256=sha(raw),outputSHA256=sha(destination.read_bytes()))
    write_json(args.output/'summary.json',summary)
    write_json(args.output/'verification.json',dict(passed=True,sourceUnchanged=True,
        duplicateIDs=0,duplicatePositionsRoundedToNanometre=0,subsetAndCodesExact=True,
        allOtherDistanceBinIDsUnchanged=True,quotasExact=True,immutableTargetFieldsUnchanged=True))
    dependencies=[Path(__file__),Path(__file__).with_name('sample_angle_curve.py'),
                  Path(__file__).with_name('filter_geometric_bank.py'),Path(__file__).with_name('pocket_geometry_filter.py')]
    write_json(args.output/'manifest.json',dict(source=str(args.bank.resolve()),sourceSHA256=sha(raw),
        scripts={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in dependencies},
        artifacts={p.name:sha(p.read_bytes()) for p in args.output.iterdir() if p.is_file()}))
    print(json.dumps(summary,ensure_ascii=False,indent=2))


if __name__=='__main__':main()
