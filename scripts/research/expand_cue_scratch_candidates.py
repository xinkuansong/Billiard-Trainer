#!/usr/bin/env python3
"""Select a distance-filtered, diverse shortlist from the frozen search index."""
import collections
import json
import math
import sqlite3
import sys
import time

import cue_scratch_research as runner
from run_cue_scratch_session import family, job

OUT = runner.OUT
MIN_DISTANCE = .30
LAYOUT_SEPARATION = .10
BATCH = 'verify-distance100'


def mirrored_distance(a, b):
    # Visual deduplication only: each retained layout is simulated independently.
    return min(max(math.dist(a['cue'], [sx*b['cue'][0], sz*b['cue'][1]]),
                   math.dist(a['object'], [sx*b['object'][0], sz*b['object'][1]]))
               for sx in (-1, 1) for sz in (-1, 1))


def diverse(rows, count, prior=(), robustness=False):
    picked = []
    families = collections.Counter()
    remaining = [x for x in rows if all(mirrored_distance(x, y) >= LAYOUT_SEPARATION for y in prior)]
    while remaining and len(picked) < count:
        if picked:
            remaining = [x for x in remaining if mirrored_distance(x, picked[-1]) >= LAYOUT_SEPARATION]
        if not remaining:
            break
        def rank(x):
            quality = x.get('fixedAimSpeedChecks', {}).get('sameRoute', 0) if robustness else x['selectionEvidence']['sampledHits']
            return (families[family(x)], -quality, abs(x['speed']-3.3), -math.dist(x['cue'], x['object']), x['id'])
        x = min(remaining, key=rank)
        picked.append(x)
        families[family(x)] += 1
        remaining.remove(x)
    return picked


def prepare():
    start = time.time()
    assert not (OUT/f'{BATCH}-selected.json').exists(), 'Existing expansion evidence'
    db = sqlite3.connect(f'file:{OUT}/results.sqlite?mode=ro', uri=True)
    groups = collections.defaultdict(list)
    counts = collections.Counter()
    for (raw,) in db.execute('SELECT raw FROM trials WHERE hit=1 ORDER BY id'):
        x = json.loads(raw)
        counts['rawHits'] += 1
        if math.dist(x['cue'], x['object']) < MIN_DISTANCE or not 5 <= x['cut'] <= 75 or x.get('cueClearance', 0) <= .05:
            continue
        counts['eligibleRecords'] += 1
        # Reserve room for the same symmetric ±8% test at every candidate.
        if not .5/.92 <= x['speed'] <= 8/1.08:
            continue
        counts['symmetricSpeedTestEligibleRecords'] += 1
        groups[(tuple(x['cue']), tuple(x['object']), family(x))].append(x)
    db.close()
    ranked = []
    for g in groups.values():
        speeds = sorted({x['speed'] for x in g})
        middle = speeds[len(speeds)//2]
        x = min(g, key=lambda x: (abs(x['speed']-middle), x['id']))
        x['selectionEvidence'] = dict(sampledHits=len(speeds), sampledSpan=max(speeds)-min(speeds), continuousGuarantee=False)
        ranked.append(x)
    selected = []
    for n in range(4):
        picked = diverse([x for x in ranked if len(x['rails']) == n], 40, prior=selected)
        assert len(picked) == 40, (n, len(picked))
        selected += picked
    runner.write(OUT/f'{BATCH}-selected.json', selected)
    runner.write(OUT/f'{BATCH}-selection.json', dict(startEpoch=start, minCenterDistanceM=MIN_DISTANCE,
        mirroredLayoutSeparationM=LAYOUT_SEPARATION, counts=dict(counts), uniquePositionRoutes=len(groups),
        shortlisted=len(selected), perRail=40, requestedFinal=100, initialScanSeconds=time.time()-start))
    jobs = []
    for i, x in enumerate(selected):
        jobs += [job(x, f'd100-{i}-full', mode='full'), job(x, f'd100-{i}-fixed', mode='fixed', offset=x['offset'])]
        for k in range(1, 9):
            for sign in (-1, 1):
                speed = x['speed']*(1+sign*k*.01)
                if .5 <= speed <= 8:
                    jobs.append(job(x, f'd100-{i}-speed-{sign}-{k}', mode='fixed', speed=speed, offset=x['offset']))
    runner.write(OUT/f'{BATCH}-request.json', dict(batch=BATCH, workers=12, seconds=300,
        start=0, count=len(jobs), mode='verify', jobs=jobs))
    print(json.dumps(dict(shortlist=len(selected), trials=len(jobs), counts=dict(counts)), ensure_ascii=False), flush=True)


if __name__ == '__main__':
    prepare()
