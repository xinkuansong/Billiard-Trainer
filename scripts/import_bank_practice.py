#!/usr/bin/env python3
"""Import the audited full bank, preserving physical inputs and event-derived rails."""
import argparse
import gzip
import hashlib
import json
import math
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "output/bank-variants-20261101/formations.jsonl.gz"
SOURCE_SHA = "ad3131c02a77615dc827134461991337463626477a5d1d41c8b3c14e55c75eb9"
REVISION = "variants-20261101"
DESTINATION = ROOT / "QiuJi/Resources/bank-practice-bank.json"
EXPECTED_COUNTS = {"1-middle": 2634, "2-middle": 1373, "3-middle": 987,
                   "1-corner": 9164, "2-corner": 4846, "3-corner": 2565}
# Production linear cushion order: +Z halves, -Z halves, -X, +X.
SEGMENT_WALLS = [3, 3, 2, 2, 0, 1]


def convert_row(row):
    def require(condition, reason):
        if not condition:
            raise ValueError(f"{row['id']}: {reason}")
    require(row['complete'] is True, 'incomplete reference')
    require(row['n'] in (1, 2, 3), 'unsupported rail count')
    require(row['type'] in ('middle', 'corner'), 'invalid pocket type')
    require(0 <= row['pocket'] < 6 and (row['pocket'] >= 4) == (row['type'] == 'middle'), 'pocket/type mismatch')
    for key in ('cue', 'target', 'direction'):
        require(len(row[key]) == 2 and all(math.isfinite(x) for x in row[key]), key)
    require(abs(math.hypot(*row['direction']) - 1) < 0.0001, 'non-unit direction')
    require(all(math.isfinite(row[k]) for k in ('speed', 'spinX', 'spinY')), 'invalid input')
    events = row['events']
    contacts = [i for i, e in enumerate(events) if e['kind'] == 'ballBall']
    pots = [i for i, e in enumerate(events) if e['kind'] == 'pocket' and e['ball'] == 'object']
    require(bool(contacts) and bool(pots), 'missing contact/pot')
    hit, pot = contacts[0], pots[0]
    require(set(events[hit]['balls']) == {'cueBall', 'object'}, 'wrong first contact')
    require(not any(e['kind'] == 'cushion' and e['ball'] == 'cueBall' for e in events[:hit]), 'cue rail before contact')
    require(not any(hit < i < pot for i in contacts[1:]), 'second contact')
    require(not any(e['kind'] == 'pocket' and e['ball'] == 'cueBall' for e in events), 'scratch')
    require(events[pot]['pocket'] == f"pocket_{row['pocket']}", 'wrong target pocket')
    rails = [e['rail'] for e in events[hit+1:pot]
             if e['kind'] == 'cushion' and e['ball'] == 'object' and 0 <= e['rail'] < 6]
    require(len(rails) == row['n'] and [SEGMENT_WALLS[x] for x in rails] == row['walls'], 'event/wall mismatch')
    return dict(id='bank-v1-' + row['id'], revision=REVISION,
                cue=dict(zip(('x', 'z'), row['cue'])), target=dict(zip(('x', 'z'), row['target'])),
                walls=row['walls'], railSegments=rails, pocket=row['pocket'], pocketType=row['type'],
                direction=dict(zip(('x', 'z'), row['direction'])),
                input=dict(spinX=row['spinX'], spinY=row['spinY'], velocity=row['speed']))


def converted(source=SOURCE):
    with source.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    if digest != SOURCE_SHA:
        raise ValueError('Audited input has changed; establish a new content revision first')
    questions, lineage, counts = [], [], Counter()
    with gzip.open(source, 'rt') as stream:
        for line in stream:
            row = json.loads(line)
            question = convert_row(row)
            questions.append(question)
            counts[f"{row['n']}-{row['type']}"] += 1
            lineage.append(dict(id=question['id'], sourceID=row['id'], baseID=row['baseID'],
                                canonicalID=row['canonicalID'], variantKind=row['variantKind'], transform=row['transform']))
    if dict(counts) != EXPECTED_COUNTS or len({q['id'] for q in questions}) != len(questions):
        raise ValueError('Audited coverage or unique identities changed')
    payload = json.dumps(dict(version=1, revision=REVISION, questions=questions),
                         ensure_ascii=False, separators=(',', ':'), allow_nan=False).encode()
    patch_path = ROOT / 'content/practice-jaw-audit/bank.json.gz'
    patch = json.loads(gzip.decompress(patch_path.read_bytes()))
    if hashlib.sha256(payload).hexdigest() != patch['source']:
        raise ValueError('Pocket-jaw adjustment requires its audited original')
    changes = dict(patch['changes'])
    for question in questions:
        adjustment = changes.pop(question['id'], None)
        if adjustment is not None:
            question['input'] = adjustment['input']
            question['direction'] = adjustment['direction']
    payload = json.dumps(dict(version=1, revision=REVISION, questions=questions),
                         ensure_ascii=False, separators=(',', ':'), allow_nan=False).encode()
    if changes or hashlib.sha256(payload).hexdigest() != patch['result']:
        raise ValueError('Unmatched adjustment or adjusted bank digest')
    report = dict(jawAdjusted=len(patch['changes']), revision=REVISION, sourceSHA256=digest, rows=len(questions), counts=dict(counts),
                  bytes=len(payload), sha256=hashlib.sha256(payload).hexdigest(), lineage=lineage)
    return payload, report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', action='store_true')
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    payload, report = converted()
    if args.verify:
        if DESTINATION.read_bytes() != payload:
            raise SystemExit('Application bank differs from the audited full-bank conversion')
        consumer = (ROOT / 'QiuJi/Features/BankPractice/BankQuestionPreparer.swift').read_text()
        if f'static let fingerprint = "{report["sha256"]}"' not in consumer:
            raise SystemExit('Application consumer fingerprint differs from resource')
    else:
        DESTINATION.write_bytes(payload)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps({k: v for k, v in report.items() if k != 'lineage'}, ensure_ascii=False))
