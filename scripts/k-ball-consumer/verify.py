"""Check the shipped parameter bank without requiring the research archive."""
import argparse
import collections
import gzip
import hashlib
import json
from pathlib import Path


def require(value, reason):
    if not value:
        raise ValueError(reason)


def verify(root, check_project=True):
    bank = root / 'QiuJi/Resources/KBallBank'
    index = json.loads((bank / 'index.json').read_bytes())
    fingerprint = index.pop('fingerprint')
    canonical = json.dumps(index, ensure_ascii=False, separators=(',', ':'), allow_nan=False).encode()
    require(hashlib.sha256(canonical).hexdigest() == fingerprint, 'index fingerprint')
    require(index['schema'] == 'k-ball-parameters-v1' and index['policyVersion'] == 'k-ball-one-per-route-v1', 'schema/policy')
    expected = {'index.json'} | {s['name']+'.jsonl.gz' for s in index['shards']}
    require({p.name for p in bank.iterdir()} == expected, 'unexpected/missing bank files')
    locations, ids, routes = [], set(), set()
    distribution = {k: collections.Counter() for k in ('byTiming','grades','byObservedRail','byPocket')}
    for shard in index['shards']:
        require(shard['name'].isdigit() and len(shard['name']) == 5, 'unsafe shard name')
        raw = (bank / (shard['name']+'.jsonl.gz')).read_bytes()
        require(len(raw) == shard['bytes'] and hashlib.sha256(raw).hexdigest() == shard['sha256'], 'shard hash/size')
        rows = list(map(json.loads, gzip.decompress(raw).splitlines()))
        require(len(rows) == shard['rows'], 'shard rows')
        for line, row in enumerate(rows):
            locations.append(dict(id=row['id'], shard=shard['name'], line=line))
            require(set(row) == {'id','board','questions'}, 'non-parameter layout')
            require(5 <= row['board']['angle'] <= 50 and 0 <= row['board']['pocket'] < 6, 'board range')
            for q in row['questions']:
                require(set(q) == {'id','route','b','dir','v','sx','sy','rail','timing','grade','trajectoryAngle','railID','centerRailDistance','railsBeforeK'}, 'non-parameter question')
                require(q['id'] not in ids and (row['id'],q['route']) not in routes, 'duplicate question/route')
                ids.add(q['id']); routes.add((row['id'],q['route']))
                require(q['rail'] in (1,2,3) and q['grade'] in (1,2,3) and q['timing'] in ('before','after'), 'classification')
                require(len(q['railsBeforeK']) == q['rail']-(q['timing']=='before'), 'observed vs physical rail')
                require(0 <= q['trajectoryAngle'] <= 45 and 0 < q['centerRailDistance'] <= .1+1e-9, 'K region')
                distribution['byTiming']['inAngle' if q['timing']=='before' else 'outAngle'] += 1
                distribution['grades'][['','敏感','常规','宽容'][q['grade']]] += 1
                distribution['byObservedRail'][str(q['rail'])] += 1
                distribution['byPocket']['middle' if row['board']['pocket'] >= 4 else 'corner'] += 1
    require(locations == index['layouts'], 'index locations')
    require(len(set(e['id'] for e in locations)) == len(locations), 'duplicate layout')
    require(index['counts'] == dict(layouts=len(locations), questions=len(ids), routes=len(routes)), 'counts')
    require(distribution == index['distribution'], 'distributions')
    if check_project:
        project = (root/'project.yml').read_text()
        generated = (root/'QiuJi.xcodeproj/project.pbxproj').read_text()
        require('"Resources/KBallBank/**"' in project, 'source auto-resource exclusion')
        require('path: QiuJi/Resources/KBallBank\n        type: folder\n        buildPhase: resources' in project, 'source folder reference')
        require('/* KBallBank in Resources */' in generated and 'path = QiuJi/Resources/KBallBank;' in generated, 'generated folder reference')
        require('KBallBankStore.swift in Sources' in generated, 'reader in build')
    return dict(passed=True, questions=len(ids), layouts=len(locations), bytes=sum(p.stat().st_size for p in bank.iterdir()))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    print(json.dumps(verify(args.root), ensure_ascii=False))
