"""Independent source-to-package audit. Uses source records, not pack.py projection."""
import argparse
import collections
import gzip
import hashlib
import json
import math
from pathlib import Path


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def audit(source, destination):
    index = json.loads((destination / 'index.json').read_bytes())
    require(index['schema'] == 'k-ball-parameters-v1', 'schema')
    require(index['policyVersion'] == 'k-ball-one-per-route-v1', 'policy')
    require(index['physicsModel'] == 'planarReference' and index['coordinateSystem'] == 'scene-xz-metres', 'physics/coordinates')
    require(index['rules'] == dict(generationAngle=[5, 50], trajectoryAngleMax=45,
        centerRailDistanceMax=.1, railClassification='observed-rail-before-and-after',
        scratchFails=False, success='first-cue-contact-A; A-designated-pocket; later-cue-contact-B'), 'rules')
    fingerprint = index.pop('fingerprint')
    require(fingerprint == hashlib.sha256(json.dumps(index, ensure_ascii=False, separators=(',', ':'), allow_nan=False).encode()).hexdigest(), 'fingerprint')
    require(digest(source / 'selected.jsonl') == index['sourceSHA256'], 'source hash')
    require(digest(source / 'audit.json') == index['sourceAuditSHA256'], 'source audit hash')
    geometry = json.loads((source / 'geometry.json').read_bytes())
    require(index['geometry'] == {k: geometry[k] for k in ('length', 'width', 'radius')}, 'geometry')
    lookup, locations, routes = {}, [], set()
    for shard in index['shards']:
        require(shard['name'].isdigit() and len(shard['name']) == 5, 'shard name')
        path = destination / (shard['name'] + '.jsonl.gz')
        require(path.stat().st_size == shard['bytes'] and digest(path) == shard['sha256'], 'shard integrity')
        rows = list(map(json.loads, gzip.decompress(path.read_bytes()).splitlines()))
        require(len(rows) == shard['rows'], 'shard row count')
        for line, row in enumerate(rows):
            require(set(row) == {'id', 'board', 'questions'}, 'layout fields')
            require(set(row['board']) == {'cue', 'object', 'pocket', 'angle'}, 'board fields')
            locations.append(dict(id=row['id'], shard=shard['name'], line=line))
            for q in row['questions']:
                require(set(q) == {'id', 'route', 'b', 'v', 'sx', 'sy', 'dir', 'rail', 'timing', 'grade',
                    'trajectoryAngle', 'railID', 'centerRailDistance', 'railsBeforeK'}, 'question fields')
                key = (row['id'], q['route'])
                require(q['id'] not in lookup and key not in routes, 'duplicate identity')
                routes.add(key); lookup[q['id']] = (row['id'], row['board'], q)
    require(locations == index['layouts'], 'index locations')
    require(len(set(x['id'] for x in locations)) == len(locations), 'duplicate layout')
    seen, timing, grades, rails, pockets = set(), collections.Counter(), collections.Counter(), collections.Counter(), collections.Counter()
    with (source / 'selected.jsonl').open() as stream:
        for line in stream:
            old = json.loads(line)
            layout, board, q = lookup[old['id']]
            seed, candidate, baseline = old['seed'], old['candidate'], old['baseline']
            require(layout == seed['layout'] and old['routeKey'] == f'{layout}/{q["route"]}', 'source identity')
            for k in ('cue', 'object', 'pocket'):
                require(board[k] == seed[k], 'source board ' + k)
            require(board['angle'] == old['sourceGenerationAngle'], 'source angle')
            for k in ('route', 'v', 'sx', 'sy', 'dir'):
                require(q[k] == seed[k], 'source parameter ' + k)
            for new, original in [('b','B'), ('rail','railOrdinal'), ('railID','railID'),
                                  ('trajectoryAngle','sourceAngle'), ('centerRailDistance','centerRailDistance')]:
                require(q[new] == candidate[original], 'source candidate ' + new)
            require(q['timing'] == {'inAngle':'before', 'outAngle':'after'}[candidate['axis']], 'timing')
            require(q['grade'] == old['grade'] and q['railsBeforeK'] == baseline['railsBeforeK'], 'grade/rail events')
            require(baseline['complete'] and baseline['success'] and old['exactReplay'], 'validated reference')
            require(5 <= board['angle'] <= 50 and 0 <= q['trajectoryAngle'] <= 45, 'angle range')
            require(q['rail'] in (1,2,3) and q['grade'] in (1,2,3), 'classification')
            require(len(q['railsBeforeK']) == q['rail'] - (q['timing'] == 'before'), 'observed vs actual rails')
            require(.6 <= q['v'] <= 4.5 and q['sx']**2 + q['sy']**2 <= .25 + 1e-8, 'stroke range')
            require(abs(math.hypot(*q['dir']) - 1) < 1e-5, 'direction')
            a, b = [(r['start'], r['end']) for r in geometry['rails'] if r['id'] == q['railID']][0]
            dx, dz = b[0]-a[0], b[1]-a[1]
            t = max(0, min(1, ((q['b'][0]-a[0])*dx + (q['b'][1]-a[1])*dz)/(dx*dx+dz*dz)))
            distance = math.hypot(q['b'][0]-a[0]-t*dx, q['b'][1]-a[1]-t*dz)
            require(abs(distance-q['centerRailDistance']) < 1e-9 and geometry['radius']-1e-7 <= distance <= .1+1e-9, 'center-to-finite-rail distance')
            positions = [board['cue'], board['object'], q['b']]
            require(all(len(p) == 2 and all(math.isfinite(v) for v in p) for p in positions), 'finite coordinates')
            require(all(math.dist(a,b) >= 2*geometry['radius']-1e-7 for i,a in enumerate(positions) for b in positions[i+1:]), 'ball overlap')
            # Verify the archived success events independently of the stored success boolean.
            events = baseline['events']
            contacts = [e for e in events if e['kind'] == 'ballBall' and 'cueBall' in e['balls']]
            require(contacts and set(contacts[0]['balls']) == {'cueBall','object'}, 'first A event')
            require(any(set(e['balls']) == {'cueBall','kTarget'} for e in contacts[1:]), 'later B event')
            require(any(e['kind'] == 'pocket' and e['ball'] == 'object' and e['pocket'] == f'pocket_{board["pocket"]}' for e in events), 'A pocket event')
            seen.add(old['id']); timing[candidate['axis']]+=1; grades[['','敏感','常规','宽容'][q['grade']]]+=1
            rails[str(q['rail'])]+=1; pockets['middle' if board['pocket'] >= 4 else 'corner']+=1
    require(seen == set(lookup), 'complete source coverage')
    require(index['counts'] == dict(questions=len(seen), routes=len(routes), layouts=len(locations)), 'counts')
    require(index['distribution'] == dict(byTiming=timing, grades=grades, byObservedRail=rails, byPocket=pockets), 'distribution')
    return dict(passed=True, counts=index['counts'], fingerprint=fingerprint,
                allFieldsExact=True, archivedEventsChecked=True, newSimulations=0,
                bytes=sum(p.stat().st_size for p in destination.iterdir()), sourceSHA256=index['sourceSHA256'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('destination', type=Path)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    report = json.dumps(audit(args.source, args.destination), ensure_ascii=False, indent=2) + '\n'
    if args.report:
        args.report.write_text(report)
    print(report)
