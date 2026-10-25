#!/usr/bin/env python3
"""Read-only consumer audit/packaging. Never imports or invokes generation code."""
import argparse
import gzip
import hashlib
import json
import math
from pathlib import Path
import shutil
import time

def sha(data):
    return hashlib.sha256(data).hexdigest()

def metric(cue, ball, pocket, length, width, radius):
    x, z = length / 2 - radius, width / 2 - radius
    p = [(-x, -z), (x, -z), (-x, z), (x, z), (0, -width/2), (0, width/2)][pocket]
    dx, dz = p[0]-ball[0], p[1]-ball[1]
    distance = math.hypot(dx, dz)
    ux, uz = dx/distance, dz/distance
    vx, vz = ball[0]-2*radius*ux-cue[0], ball[1]-2*radius*uz-cue[1]
    return distance*math.hypot(vx, vz)/(vx*ux+vz*uz)

def pack(source, destination, report):
    started = time.monotonic()
    summary = json.loads((source/'summary.json').read_text())
    assert summary['state'] == 'complete' and summary['auditPassed'] is True
    parts = json.loads((source/'parts-index.json').read_text())
    geometry = dict(length=2.5399999618530273, width=1.2699999809265137, radius=0.028574999421834946)
    destination.mkdir(parents=True, exist_ok=True)
    layouts, shards, ids = [], [], set()
    counts = dict(layouts=0, candidates=0, emptyCandidates=0, routes=0, recommendations=0)
    max_error = 0
    fixtures = []
    for part in parts:
        raw = (source/'final'/f"{part['stem']}.jsonl.gz").read_bytes()
        assert len(raw) == part['finalBytes'] and sha(raw) == part['finalSHA256']
        rows = [json.loads(line) for line in gzip.decompress(raw).splitlines() if line]
        for line, row in enumerate(rows):
            assert row['schema'] == 'two-ball-refined25-p2-60-top5-v1'
            assert row['id'] not in ids and row['id'] == row['board']['id']
            ids.add(row['id'])
            routes = {r['comboIndex']: r for r in row['routes']}
            assert len(routes) == len(row['routes'])
            cells = set()
            for route in routes.values():
                trajectory = route['trajectory2mm']
                assert trajectory['timeOrigin'] == 'firstTargetContact'
                assert trajectory['coordinateUnit'] == 'meter-XZ'
                points = trajectory['points']
                assert points and all(len(p) == 3 and all(math.isfinite(v) for v in p) for p in points)
                assert all(a[0] <= b[0] for a,b in zip(points, points[1:]))
                assert all(0 <= i < len(points) for i in trajectory['mandatoryPointIndices'])
                assert route['spinX']**2+route['spinY']**2 <= .250001
                assert .6 <= route['velocity'] <= 4.500001
            for candidate in row['candidates']:
                assert candidate['cellID'] not in cells
                cells.add(candidate['cellID'])
                assert len(candidate['top5']) <= 5
                counts['candidates'] += 1
                counts['emptyCandidates'] += not candidate['top5']
                seen = set()
                for top in candidate['top5']:
                    assert top['comboIndex'] in routes and top['comboIndex'] not in seen
                    seen.add(top['comboIndex'])
                    assert 0 <= top['pocket'] < 6 and 0 <= top['angle'] <= 25.00001
                    route = routes[top['comboIndex']]
                    value = metric(route['cueStop'], candidate['position'], top['pocket'], **geometry)
                    error = abs(value-top['score'])
                    assert error < 1e-8, (row['id'], error)
                    max_error = max(max_error, error)
                    counts['recommendations'] += 1
                    if len(fixtures) < 20:
                        fixtures.append(dict(cue=route['cueStop'], ball=candidate['position'], pocket=top['pocket'], expected=top['score']))
            layouts.append(dict(id=row['id'], shard=part['stem'], line=line, board=row['board']))
            counts['routes'] += len(routes)
        counts['layouts'] += len(rows)
        shards.append(dict(name=part['stem'], sha256=sha(raw), bytes=len(raw)))
        shutil.copyfile(source/'final'/f"{part['stem']}.jsonl.gz", destination/f"{part['stem']}.jsonl.gz")
    assert counts['layouts'] == 13570 and counts['candidates'] == 173577
    index = dict(schema='two-ball-consumer-v1', sourceSchema='two-ball-refined25-p2-60-top5-v1',
                 fingerprint=parts[0]['contract'], geometry=geometry, shards=shards, layouts=layouts)
    (destination/'index.json').write_text(json.dumps(index, separators=(',',':')))
    report.mkdir(parents=True, exist_ok=True)
    (report/'audit.json').write_text(json.dumps(dict(state='complete', **counts, maxDifficultyError=max_error,
        sourceIndexSHA256=sha((source/'parts-index.json').read_bytes()),
        consumerIndexSHA256=sha((destination/'index.json').read_bytes()),
        compressedBytes=sum(s['bytes'] for s in shards), seconds=time.monotonic()-started), indent=2))
    (report/'difficulty-fixtures.json').write_text(json.dumps(fixtures, indent=2))
    print((report/'audit.json').read_text())

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    parser.add_argument('destination', type=Path)
    parser.add_argument('report', type=Path)
    args = parser.parse_args()
    pack(args.source, args.destination, args.report)
