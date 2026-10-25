#!/usr/bin/env python3
"""Export the audited final bank; never simulate, reselect, or mutate research data."""
import argparse
import gzip
import hashlib
import json
import math
import time
from pathlib import Path

SCHEMA = 'two-ball-comfort85-execution-v1'
POLICY = 'comfort85-execution-v1'
EXECUTION = 'execution-effort-v1'
FORMULA = 'E=2.5s+0.8h+1.2d+0.8u^2+0.12N+0.06L+0.6su+0.15Ns; D=100E/(E+1)'

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def encoded(value):
    return json.dumps(value, ensure_ascii=False, separators=(',', ':'), allow_nan=False).encode()

def execution(route):
    s, y, u = abs(route['spinX']), route['spinY'], route['velocity']/4.5
    n = route['cueMainRailsAfterContact']
    points = route['trajectory2mm']['points']
    length = sum(math.hypot(b[1]-a[1], b[2]-a[2]) for a, b in zip(points, points[1:]))
    components = dict(stroke=2.5*s+.8*max(y, 0)+1.2*max(-y, 0), power=.8*u*u,
                      route=.12*n+.06*length, interaction=.6*s*u+.15*n*s)
    effort = sum(components.values())
    return dict(version=EXECUTION, lengthMeters=length, components=components,
                effort=effort, difficulty=100*effort/(effort+1))

def pack(source, destination, report):
    started = time.monotonic()
    assert not destination.exists(), 'Use a fresh staging directory; never mix packages'
    summary_raw = (source/'summary.json').read_bytes()
    summary = json.loads(summary_raw)
    assert summary['state'] == 'complete' and summary['auditPassed'] is True
    index_raw = (source/'parts-index.json').read_bytes()
    parts = json.loads(index_raw)
    binding = dict(policy=POLICY, sourceIndexSHA256=sha(index_raw), sourceSummarySHA256=sha(summary_raw),
                   formula=FORMULA, threshold=85, ordering='unrounded effort ascending; stable source order')
    fingerprint = sha(encoded(binding))
    destination.mkdir(parents=True)
    report.mkdir(parents=True, exist_ok=True)
    counts = dict(sourceLayouts=0, sourceQuestions=0, sourceRecommendations=0, layouts=0,
                  questions=0, recommendations=0, routes=0, excludedLowRecommendations=0,
                  excludedAllLowQuestions=0, sourceEmptyQuestions=0)
    ids, layouts, shards = set(), [], []
    histogram = [0]*10
    for part in parts:
        raw = (source/'final'/f"{part['stem']}.jsonl.gz").read_bytes()
        assert len(raw) == part['finalBytes'] and sha(raw) == part['finalSHA256']
        rows = [json.loads(line) for line in gzip.decompress(raw).splitlines() if line]
        assert [r['id'] for r in rows] == part['layoutIDs']
        output = []
        for row in rows:
            assert row['schema'] == 'two-ball-comfort85-minchange-v1'
            assert row['id'] == row['board']['id'] and row['id'] not in ids
            ids.add(row['id']); counts['sourceLayouts'] += 1
            routes = {r['comboIndex']: r for r in row['routes']}
            assert len(routes) == len(row['routes'])
            for r in routes.values():
                line = r['trajectory2mm']; points = line['points']
                assert line['timeOrigin'] == 'firstTargetContact' and line['coordinateUnit'] == 'meter-XZ'
                assert points and all(len(p) == 3 and all(math.isfinite(x) for x in p) for p in points)
                assert all(a[0] <= b[0] for a,b in zip(points, points[1:]))
                assert r['cueMainRailsAfterContact'] == len(line['cushions'])
                assert all(0 <= c['cushionID'] <= 5 for c in line['cushions'])
                assert r['cueJawsAfterContact'] == r['cueOtherCushionsAfterContact'] == 0
                r['executionDifficulty'] = execution(r)
            candidates, used, cells = [], set(), set()
            for c in row['candidates']:
                assert c['cellID'] not in cells; cells.add(c['cellID'])
                assert len(c['top5']) <= 5
                counts['sourceQuestions'] += 1
                counts['sourceRecommendations'] += len(c['top5'])
                tops = []
                for rank, top in enumerate(c['top5']):
                    assert top['comboIndex'] in routes
                    score = top['comfort']['totalScore']
                    assert math.isfinite(score) and 0 <= score <= 100
                    if score >= 85:
                        top['sourceRecommendationRank'] = rank
                        tops.append(top)
                    else:
                        counts['excludedLowRecommendations'] += 1
                if not tops:
                    counts['excludedAllLowQuestions' if c['top5'] else 'sourceEmptyQuestions'] += 1
                    continue
                tops.sort(key=lambda t: routes[t['comboIndex']]['executionDifficulty']['effort'])
                c['top5'] = tops; candidates.append(c)
                used.update(t['comboIndex'] for t in tops)
                counts['questions'] += 1; counts['recommendations'] += len(tops)
                for t in tops:
                    d = routes[t['comboIndex']]['executionDifficulty']['difficulty']
                    histogram[min(9, int(d//10))] += 1
            if not candidates:
                continue
            row['schema'] = SCHEMA; row['candidates'] = candidates
            row['routes'] = [r for r in row['routes'] if r['comboIndex'] in used]
            layouts.append(dict(id=row['id'], shard=part['stem'], line=len(output), board=row['board']))
            counts['layouts'] += 1; counts['routes'] += len(row['routes'])
            output.append(row)
        if output:
            packed = gzip.compress(b''.join(encoded(r)+b'\n' for r in output), compresslevel=9, mtime=0)
            (destination/f"{part['stem']}.jsonl.gz").write_bytes(packed)
            shards.append(dict(name=part['stem'], sha256=sha(packed), bytes=len(packed)))
        if len(shards) % 100 == 0:
            (report/'progress.json').write_bytes(encoded(counts))
    assert (counts['sourceLayouts'], counts['sourceQuestions']) == (13570, 173577)
    assert (counts['questions'], counts['recommendations']) == (166443, 677488)
    assert counts['excludedAllLowQuestions'] == 679
    index = dict(schema='two-ball-consumer-v2', sourceSchema=SCHEMA, fingerprint=fingerprint,
                 policyVersion=POLICY, executionVersion=EXECUTION, minimumComfort=85,
                 geometry=dict(length=2.5399999618530273, width=1.2699999809265137, radius=.028574999421834946),
                 provenance=binding, counts=counts, shards=shards, layouts=layouts)
    (destination/'index.json').write_bytes(encoded(index))
    audit = dict(state='packed-awaiting-independent-audit', **counts, fingerprint=fingerprint,
                 consumerIndexSHA256=sha(encoded(index)), compressedBytes=sum(s['bytes'] for s in shards),
                 difficultyHistogram=histogram, seconds=time.monotonic()-started, **binding)
    (report/'pack.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2))
    print(json.dumps(audit, ensure_ascii=False))

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    for name in ['source', 'destination', 'report']:
        p.add_argument(name, type=Path)
    a = p.parse_args(); pack(a.source, a.destination, a.report)
