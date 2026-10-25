#!/usr/bin/env python3
"""Compare provisional policies with a frozen human-feedback snapshot; no bank edits."""
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def candidates(sample):
    return [m for m in sample['metrics']
            if m['pocket'] != sample['original']['pocket'] and m['cut_degrees'] < 90]


def conjunct(a, b, angle=15, distance=.3, fraction=.25):
    return (a['cut_degrees']-b['cut_degrees']+1e-9 >= angle
            and a['object_distance_metres']-b['object_distance_metres']+1e-12 >= distance
            and b['object_distance_metres'] <= a['object_distance_metres']*(1-fraction)+1e-12)


def score(m, exponent=1):
    # An empirical ranking hypothesis, NOT pocket width or a success probability.
    return m['object_distance_metres']/math.cos(math.radians(m['cut_degrees']))**exponent


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    source = ROOT/'output/two-ball-pocket-filter-20261024/review-1000'
    raw = (source/'feedback.json').read_bytes()
    feedback = json.loads(raw)
    data = json.loads((source/'samples.json').read_text())
    assert feedback['meaning'] == 'agreement_with_filter_verdict'
    assert feedback['sourceSHA256'] == data['sourceSHA256']
    assert feedback['thresholds'] == data['thresholds']
    assert feedback['seed'] == data['seed']
    samples = {s['id']: s for s in data['samples']}
    for lid, r in feedback['records'].items():
        s = samples[lid]
        assert r['reviewed'] and r['number'] == s['number'] and r['algorithmStatus'] == s['status']
        assert r['expectedStatus'] == (s['status'] if r['agrees'] else ('drop' if s['status']=='keep' else 'keep'))
        assert any(conjunct(s['original'], b) for b in candidates(s)) == (s['status']=='drop')

    policies = [('original', conjunct),
                ('relax_10deg_10cm_10pct', lambda a,b: conjunct(a,b,10,.1,.1)),
                ('relax_5deg_10cm_10pct', lambda a,b: conjunct(a,b,5,.1,.1))]
    policies += [(f'score_ratio_{ratio:g}', lambda a,b,ratio=ratio: score(b)<=score(a)*ratio)
                 for ratio in [.5,.6,.65,.7,.75,.8,.85]]
    policies += [(f'score_exponent_{power:g}_ratio_{ratio:g}',
                  lambda a,b,power=power,ratio=ratio: score(b,power)<=score(a,power)*ratio)
                 for power in [.5,1.5,2] for ratio in [.6,.7,.8]]
    results = {}
    for name, policy in policies:
        rows=[]
        for s in data['samples']:
            a=s['original'];wins=[b for b in candidates(s) if policy(a,b)]
            predicted='drop' if wins else 'keep'
            r=feedback['records'].get(s['id'])
            rows.append(dict(number=s['number'],id=s['id'],originalStatus=s['status'],
                             prediction=predicted,winningPockets=[b['pocket'] for b in wins],
                             expectedStatus=r['expectedStatus'] if r else None))
        reviewed=[r for r in rows if r['expectedStatus'] is not None]
        fixed=[r['number'] for r in reviewed if r['prediction']==r['expectedStatus']!=r['originalStatus']]
        regress=[r['number'] for r in reviewed if r['prediction']!=r['expectedStatus']==r['originalStatus']]
        missed=[r['number'] for r in reviewed if r['expectedStatus']=='drop' and r['prediction']=='keep']
        excess=[r['number'] for r in reviewed if r['expectedStatus']=='keep' and r['prediction']=='drop']
        results[name]=dict(correct=len(reviewed)-len(missed)-len(excess),reviewed=len(reviewed),
                           fixed=fixed,regressions=regress,missed=missed,excess=excess,
                           counts1000=dict(Counter(r['prediction'] for r in rows)),predictions=rows)
    args.output.mkdir(parents=True, exist_ok=False)
    (args.output/'feedback-snapshot.json').write_bytes(raw)
    report=dict(feedbackSHA256=hashlib.sha256(raw).hexdigest(),
                lastFeedbackUTC=max(r['updatedAt'] for r in feedback['records'].values()),
                sourceSHA256=data['sourceSHA256'],seed=data['seed'],
                reviewedCounts=dict(Counter(f"{r['algorithmStatus']}_{r['agrees']}" for r in feedback['records'].values())),
                limitation='In-sample exploratory comparison; no held-out validation; ambiguous feedback retained literally.',
                scoreDefinition='object_distance_metres / cos(cut_degrees * pi / 180); candidates cut < 90 degrees',
                results=results)
    (args.output/'comparison.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    for name,r in results.items():
        print(name,r['correct'],len(r['fixed']),len(r['regressions']),r['counts1000'])


if __name__ == '__main__':
    main()
