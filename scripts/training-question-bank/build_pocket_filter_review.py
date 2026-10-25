#!/usr/bin/env python3
"""Sample existing screening results for human review; never rescan all pockets."""
from dataclasses import asdict
import hashlib
import json
from pathlib import Path
import random

from pocket_geometry_filter import Geometry, evaluate_layout, layouts, validate_bank

ROOT = Path(__file__).resolve().parents[2]


def main():
    previous = ROOT / 'output/two-ball-pocket-filter-20261024'
    output = previous / 'review-1000'
    summary = json.loads((previous / 'summary.json').read_text())
    source = (ROOT / 'QiuJi/Resources/training-grid-bank.json').read_bytes()
    if hashlib.sha256(source).hexdigest() != summary['sourceSHA256']:
        raise ValueError('Bank changed since existing screening')
    if hashlib.sha256(Path(__file__).with_name('pocket_geometry_filter.py').read_bytes()).hexdigest() != summary['scriptSHA256']:
        raise ValueError('Screening implementation changed')
    bank = json.loads(source)
    geometry = Geometry(**summary['geometry'])
    validate_bank(bank, geometry)
    excluded = {json.loads(line)['id'] for line in (previous / 'excluded.jsonl').open()}
    assert len(excluded) == summary['counts']['drop']
    total = sum(summary['counts'].values())
    seed = 20261024
    ranks = random.Random(seed).sample(range(total), 1000)
    ordinal = {rank: i for i, rank in enumerate(ranks)}
    selected = [None] * 1000
    # Walk the compact records to locate sampled IDs only. Evaluate just 1000.
    for rank, (lid, cue, target, pid, angle) in enumerate(layouts(bank)):
        if rank not in ordinal:
            continue
        decision = evaluate_layout(cue, target, pid, geometry)
        assert (decision.status == 'drop') == (lid in excluded)
        assert abs(decision.original.cut_degrees - angle) < 1e-9
        number = ordinal[rank] + 1
        selected[number-1] = dict(number=number, id=lid, cue=cue, target=target, **asdict(decision))
    assert all(selected) and len({s['id'] for s in selected}) == 1000
    counts = {key: sum(s['status'] == key for s in selected) for key in ('keep', 'drop')}
    payload = dict(seed=seed, count=1000, counts=counts, bankTotal=total,
                   sourceSHA256=summary['sourceSHA256'], geometry=summary['geometry'],
                   thresholds=summary['thresholds'], anchors=geometry.anchors(), samples=selected)
    output.mkdir(exist_ok=False)
    (output / 'samples.json').write_text(json.dumps(payload, ensure_ascii=False, indent=2)+'\n')
    template = Path(__file__).with_name('pocket_filter_review.html').read_text()
    assert template.count('__PAYLOAD__') == 1
    page = template.replace('__PAYLOAD__', json.dumps(payload, ensure_ascii=False, separators=(',', ':')))
    (output / 'index.html').write_text(page)
    (output / 'verification.json').write_text(json.dumps(dict(
        source='existing full screening', uniformSampleWithoutReplacement=True,
        sampleSize=1000, seed=seed, counts=counts, uniqueIDs=1000,
        sampledDecisionsMatchExistingResults=True, totalNewEvaluations=1000,
        bankUnmodified=hashlib.sha256((ROOT/'QiuJi/Resources/training-grid-bank.json').read_bytes()).hexdigest()==summary['sourceSHA256']
    ), ensure_ascii=False, indent=2)+'\n')
    print(json.dumps(dict(output=str(output), counts=counts, seed=seed), ensure_ascii=False))


if __name__ == '__main__':
    main()
