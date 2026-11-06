#!/usr/bin/env python3
"""Reproduce the historical v1 bundle. Use build_trajectory_v2.py for current trajectory content.
After changing the bank, update DefenseBankStore's SHA constants and run its tests.
"""
import argparse
import csv
import gzip
import hashlib
import json
from pathlib import Path
from pack import audit, POLICY


def encode(value):
    return json.dumps(value, ensure_ascii=False, separators=(',', ':')).encode()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--reference-dir', type=Path, required=True)
    parser.add_argument('--free-dir', type=Path, default=Path('output/defense-pocket-cleanup-20261104/catalogs'))
    parser.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    index = json.loads((args.reference_dir / 'index.json').read_text())
    audit(args.reference_dir)
    assert index['policyVersion'] in (POLICY, 'pure-defense-cut60-rails1-total2-no-target-rail-recontact-v2')
    assert index['physicsModel'] == 'planarReference'
    assert index['coordinateSystem'] == 'scenekit-xz-metres-y-up'
    rows = []
    sources = {str(args.reference_dir / 'index.json'): hashlib.sha256((args.reference_dir / 'index.json').read_bytes()).hexdigest()}
    for shard in index['shards']:
        path = args.reference_dir / (shard['name'] + '.jsonl.gz')
        raw = path.read_bytes()
        assert hashlib.sha256(raw).hexdigest() == shard['sha256'], path
        sources[str(path)] = shard['sha256']
        rows += [json.loads(line) for line in gzip.decompress(raw).splitlines() if line]
    if index['policyVersion'].endswith('no-target-rail-recontact-v2'):
        for question in rows:
            for reference in question['references']:
                contacted = bounced = False
                for event in reference['expected']['events']:
                    pair = event['kind'] == 'ballBall' and set(event['ballNumbers']) == {0, question['ownBallNumber']}
                    if pair:
                        assert not (contacted and bounced), (question['id'], reference['id'], 'target-rail-cue-recontact')
                        contacted = True
                    elif contacted and event['kind'] == 'cushion' and event['ballNumbers'] == [question['ownBallNumber']] and event.get('railIndex') in range(6):
                        bounced = True
    trajectory = encode({'schema': index['schema'], 'sourceFingerprint': index['fingerprint'], 'questions': rows})
    free = []
    for kind in ['one', 'two_black', 'two_own', 'three']:
        path = args.free_dir / (kind + '.csv')
        sources[str(path)] = hashlib.sha256(path.read_bytes()).hexdigest()
        with path.open(encoding='utf-8-sig', newline='') as file:
            for row in csv.DictReader(file):
                numbers = json.loads(row['numbers'])
                positions = json.loads(row['positions'])
                free.append(dict(id=kind + ':' + row['formationID'], sourceFormationID=row['formationID'],
                                 sampleID=row['sourceID'], kind=kind, cue=json.loads(row['cue']),
                                 balls=[dict(number=n, position=p) for n, p in zip(numbers, positions)],
                                 ownBallNumber=numbers[int(row['own'])], opponentBallNumber=numbers[int(row['enemy'])], references=[]))
    # Original v1 free package used ASCII JSON; keep byte identity reproducible.
    compressed = gzip.compress(json.dumps(free, separators=(',', ':')).encode(), mtime=0)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    outputs = {'defense-practice-bank.json.gz': gzip.compress(trajectory, mtime=0), 'defense-free-bank.json.gz': compressed}
    hashes = {}
    for name, data in outputs.items():
        (args.output_dir / name).write_bytes(data)
        hashes[name] = hashlib.sha256(data).hexdigest()
    provenance = dict(referenceQuestions=len(rows), references=sum(len(q['references']) for q in rows),
                      freeQuestions=len(free), sourceFingerprint=index['fingerprint'], sourceSHA256=sources, outputSHA256=hashes)
    (args.output_dir / 'defense-practice-provenance.json').write_text(json.dumps(provenance, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k:v for k,v in provenance.items() if k != 'sourceSHA256'}, ensure_ascii=False))


if __name__ == '__main__':
    main()
