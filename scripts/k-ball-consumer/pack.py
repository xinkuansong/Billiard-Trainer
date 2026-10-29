"""Lossless parameter projection of the audited one-per-route K bank.

Usage: pack.py SOURCE NEW_DESTINATION
No simulation, resampling, numeric rounding, or research-bank mutation.
Publish the new destination only after audit.py succeeds.
"""
import argparse
import gzip
import hashlib
import json
from pathlib import Path


def encode(value):
    return json.dumps(value, ensure_ascii=False, separators=(',', ':'), allow_nan=False).encode()


def sha(data):
    return hashlib.sha256(data).hexdigest()


def pack(source, destination):
    if destination.exists():
        raise ValueError(f'Destination already exists: {destination}')
    audit = json.loads((source / 'audit.json').read_bytes())
    summary = json.loads((source / 'summary.json').read_bytes())
    if not (audit['passed'] and audit['exactUnmodifiedSubset'] and audit['onePerRoute'] and summary['complete']):
        raise ValueError('Source audit is incomplete')
    layouts = {}
    source_hash = hashlib.sha256()
    ids, routes = set(), set()
    with (source / 'selected.jsonl').open('rb') as stream:
        for line in stream:
            source_hash.update(line)
            row = json.loads(line)
            seed, candidate, result = row['seed'], row['candidate'], row['baseline']
            if row['id'] in ids or row['routeKey'] in routes:
                raise ValueError('Duplicate question or route')
            ids.add(row['id']); routes.add(row['routeKey'])
            if not (result['success'] and result['complete'] and row['exactReplay']):
                raise ValueError(f'Unvalidated reference: {row["id"]}')
            if candidate['axis'] not in ('inAngle', 'outAngle'):
                raise ValueError('Unknown timing')
            if result['input'] != {k: seed[k] for k in ('dir', 'v', 'sx', 'sy')}:
                raise ValueError('Reference parameters differ from source')
            board = dict(cue=seed['cue'], object=seed['object'], pocket=seed['pocket'], angle=row['sourceGenerationAngle'])
            layout = layouts.setdefault(seed['layout'], dict(id=seed['layout'], board=board, questions=[]))
            if layout['board'] != board:
                raise ValueError('Inconsistent source layout')
            layout['questions'].append(dict(
                id=row['id'], route=seed['route'], b=candidate['B'],
                v=seed['v'], sx=seed['sx'], sy=seed['sy'], dir=seed['dir'],
                rail=candidate['railOrdinal'], timing='before' if candidate['axis'] == 'inAngle' else 'after',
                grade=row['grade'], trajectoryAngle=candidate['sourceAngle'], railID=candidate['railID'],
                centerRailDistance=candidate['centerRailDistance'], railsBeforeK=result['railsBeforeK']))
    if source_hash.hexdigest() != audit['selectedSHA256']:
        raise ValueError('Source SHA differs from audited selection')
    if len(ids) != summary['selected'] or len(layouts) != summary['retainedLayouts']:
        raise ValueError('Source counts differ')
    geometry = json.loads((source / 'geometry.json').read_bytes())
    destination.mkdir(parents=True)
    rows = list(layouts.values())
    shards, entries = [], []
    for start in range(0, len(rows), 64):
        name = f'{len(shards):05d}'
        part = rows[start:start + 64]
        payload = gzip.compress(b''.join(encode(row) + b'\n' for row in part), compresslevel=9, mtime=0)
        (destination / f'{name}.jsonl.gz').write_bytes(payload)
        shards.append(dict(name=name, sha256=sha(payload), bytes=len(payload), rows=len(part)))
        entries.extend(dict(id=row['id'], shard=name, line=i) for i, row in enumerate(part))
    index = dict(schema='k-ball-parameters-v1', policyVersion='k-ball-one-per-route-v1',
                 physicsModel='planarReference', coordinateSystem='scene-xz-metres',
                 sourceSHA256=source_hash.hexdigest(), sourceAuditSHA256=sha((source / 'audit.json').read_bytes()),
                 geometry={k: geometry[k] for k in ('length', 'width', 'radius')},
                 counts=dict(questions=len(ids), layouts=len(rows), routes=len(routes)),
                 distribution={k: summary[k] for k in ('byTiming', 'grades', 'byObservedRail', 'byPocket')},
                 rules=dict(generationAngle=[5, 50], trajectoryAngleMax=45, centerRailDistanceMax=0.10,
                            railClassification='observed-rail-before-and-after', scratchFails=False,
                            success='first-cue-contact-A; A-designated-pocket; later-cue-contact-B'),
                 shards=shards, layouts=entries)
    index['fingerprint'] = sha(encode(index))
    (destination / 'index.json').write_bytes(encode(index))
    print(json.dumps(dict(counts=index['counts'], files=len(shards)+1,
                         bytes=sum(p.stat().st_size for p in destination.iterdir())), ensure_ascii=False))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('destination', type=Path)
    args = parser.parse_args()
    pack(args.source, args.destination)
