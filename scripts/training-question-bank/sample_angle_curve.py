#!/usr/bin/env python3
"""Sample unique first-shot layouts using a smooth angle retention curve."""
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path

from filter_geometric_bank import retain_target, sha, write_json
from pocket_geometry_filter import Geometry, ROOT, layouts, validate_bank

# A numerical approximation of the user's red sketch, not an image digitization.
# Angle in degrees -> fraction of available layouts retained at that angle.
KNOTS = [(0, .03), (2, .10), (5, .45), (10, .78), (15, .97),
         (18, .95), (20, .85), (25, .45), (30, .35), (40, .30),
         (50, .15), (55, .10), (70, .10), (85, .08)]
SEED = "angle-curve-20261024-v1"


def retention(angle):
    if not 0 <= angle <= 85:
        raise ValueError("Angle outside bank domain")
    for (a, p), (b, q) in zip(KNOTS, KNOTS[1:]):
        if a <= angle <= b:
            blend = (1 - math.cos(math.pi * (angle-a)/(b-a))) / 2
            return p + (q-p)*blend
    raise ValueError("Uncovered angle")


def records(bank):
    for target in bank['targets']:
        index = 0
        for mi, mask in enumerate(target['masks']):
            for bit in range(len(bank['distanceSamples'])):
                if mask & (1 << bit):
                    yield (f"grid-v3:{target['inventoryTargetIndex']}:{mi}:{bit}",
                           abs(mi-85), target['pocket'], target['combinationIndices'][index])
                    index += 1
        assert index == len(target['combinationIndices'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bank', type=Path, default=ROOT/'output/two-ball-geometric-filter-30pct-20261024/geometric-filtered-bank.json')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    raw = args.bank.read_bytes()
    bank = json.loads(raw)
    geometry = Geometry(**{k: bank['geometry'][k] for k in ('length','width','radius')})
    validate_bank(bank, geometry)
    source_records = list(records(bank))
    original = {row[0]: row[1:] for row in source_records}
    assert len(original) == len(source_records) == sum(bank['counts'].values())
    buckets = [[] for _ in range(86)]
    for lid, angle, *_ in source_records:
        buckets[angle].append(lid)
    chosen, angle_counts = set(), []
    for angle, ids in enumerate(buckets):
        rate = retention(angle)
        count = math.floor(len(ids)*rate + .5)
        assert 0 <= count <= len(ids)
        ranked = sorted(ids, key=lambda lid: (sha((SEED+'\0'+lid).encode()), lid))
        chosen.update(ranked[:count])
        angle_counts.append(dict(angle=angle, available=len(ids), retention=rate,
                                 sampled=count, omitted=len(ids)-count))
    targets = [retain_target(t, chosen) for t in bank['targets']]
    targets = [t for t in targets if t['combinationIndices']]
    counts = Counter()
    for t in targets:
        counts['corner' if t['pocket'] < 4 else 'middle'] += len(t['combinationIndices'])
    policy = dict(version='angle-retention-red-sketch-v1', seed=SEED,
                  knots=KNOTS, interpolation='piecewise cosine easing; C1 continuous',
                  quota='floor(available_at_integer_absolute_cut * retention + 0.5)',
                  selection='lowest SHA256(seed + NUL + stableID) within each angle; no replacement',
                  totalSpecified=False, parentSHA256=sha(raw),
                  parentSourceLayoutBankSHA256=bank['sourceLayoutBankSHA256'])
    result = dict(bank, targets=targets, counts=dict(counts), sourceLayoutBankSHA256=sha(raw),
                  angleSampling=policy, samplingSourceContract=bank['contract'],
                  contract=bank['contract']+' Additional unique-ID sampling by absolute cut angle retention curve.')
    validate_bank(result, geometry)
    args.output.mkdir(parents=True, exist_ok=False)
    destination = args.output/'angle-sampled-bank.json'
    destination.write_text(json.dumps(result, ensure_ascii=False, separators=(',',':'), allow_nan=False)+'\n')
    decoded = json.loads(destination.read_bytes())
    validate_bank(decoded, geometry)
    actual = list(records(decoded))
    actual_map = {row[0]: row[1:] for row in actual}
    assert len(actual) == len(actual_map) == len(chosen) == sum(counts.values())
    assert set(actual_map) == chosen
    assert all(original[lid] == value for lid, value in actual_map.items())
    actual_angles = Counter(row[1] for row in actual)
    assert all(actual_angles[r['angle']] == r['sampled'] for r in angle_counts)
    target_map = {t['inventoryTargetIndex']: t for t in bank['targets']}
    for t in decoded['targets']:
        parent = target_map[t['inventoryTargetIndex']]
        assert set(t) == set(parent)
        assert all(value == parent[k] for k, value in t.items() if k not in ('masks','combinationIndices'))
    for key in ('geometry','distanceSamples','combinationTable','combinationEncoding','geometricScreening'):
        assert decoded[key] == bank[key]
    # Verify physical starting positions as well as stable IDs (nanometre rounding).
    seen_shots, seen_positions = set(), set()
    duplicate_shots = duplicate_positions = 0
    for lid, cue, obj, pocket, angle in layouts(decoded):
        position = tuple(round(value, 9) for value in (*cue, *obj))
        shot = position + (pocket,)
        duplicate_shots += shot in seen_shots
        duplicate_positions += position in seen_positions
        seen_shots.add(shot)
        seen_positions.add(position)
    assert duplicate_shots == 0, 'Repeated starting position and target pocket'
    assert duplicate_positions == 0, 'Repeated starting position under different target pockets'
    assert args.bank.read_bytes() == raw
    with (args.output/'selected-ids.txt').open('x') as f:
        for row in actual:
            f.write(row[0]+'\n')
    write_json(args.output/'angle-counts.json', angle_counts)
    write_json(args.output/'sampling-policy.json', policy)
    summary = dict(sourceTotal=len(source_records), sampled=len(actual),
                   notSelected=len(source_records)-len(actual), counts=counts,
                   fractionRetained=len(actual)/len(source_records),
                   meanCutDegrees=sum(row[1] for row in actual)/len(actual),
                   count5to20=sum(row['sampled'] for row in angle_counts if 5<=row['angle']<=20),
                   peakIntegerAngle=max(angle_counts,key=lambda row: row['sampled'])['angle'],
                   targetRecords=len(targets), seed=SEED, sourceSHA256=sha(raw),
                   outputSHA256=sha(destination.read_bytes()))
    write_json(args.output/'summary.json', summary)
    write_json(args.output/'verification.json', dict(passed=True,
        sourceUnchanged=True, subsetAndCombinationCodesExact=True,
        everyAngleQuotaMatched=True, immutableTargetFieldsUnchanged=True,
        duplicateStableIDs=len(actual)-len(actual_map), duplicatePositions=duplicate_positions,
        duplicatePositionAndPocket=duplicate_shots, coordinateCheckRoundingMetres=1e-9))
    scripts = [Path(__file__), Path(__file__).with_name('filter_geometric_bank.py'),
               Path(__file__).with_name('pocket_geometry_filter.py')]
    write_json(args.output/'manifest.json', dict(source=str(args.bank.resolve()), sourceSHA256=sha(raw),
        scripts={str(p.relative_to(ROOT)): sha(p.read_bytes()) for p in scripts},
        artifacts={p.name: sha(p.read_bytes()) for p in args.output.iterdir() if p.is_file()}))
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
