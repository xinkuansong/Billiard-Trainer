#!/usr/bin/env python3
"""Plan incremental Figma imports without copying PNGs or touching the live plugin.

Saved receipts and offline packages remain separate delivery states. Generated
review chunks can be consumed by package.py after the pending receipt is saved.
"""
import argparse
import collections
import hashlib
import json
from pathlib import Path


def identity(entry):
    return entry['slotId'], entry['sha256']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--index', type=Path, required=True)
    parser.add_argument('--figma-map', type=Path, required=True)
    parser.add_argument('--packages', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--batch-size', type=int, default=80)
    args = parser.parse_args()
    if args.batch_size < 1:
        parser.error('batch-size must be positive')
    index = json.loads(args.index.read_text())
    confirmed = {identity(e) for e in json.loads(args.figma_map.read_text())['frames']}
    archived = collections.defaultdict(list)
    for path in sorted(args.packages.glob('*/package.json')):
        for entry in json.loads(path.read_text())['entries']:
            archived[identity(entry)].append(str(path.resolve()))
    pending, inventory, seen = [], [], set()
    for entry in index['images']:
        if entry.get('status') != 'VALIDATED':
            raise ValueError('Index contains an unreviewed image')
        key = identity(entry)
        if key in seen:
            continue
        seen.add(key)
        row = {k: entry[k] for k in ('slotId', 'sha256', 'captureId', 'page', 'path')}
        if key in confirmed:
            row['deliveryStatus'] = 'SAVED_RECEIPT'
        elif key in archived:
            row.update(deliveryStatus='PACKAGED_RECEIPT_UNCONFIRMED', packages=archived[key])
        else:
            source = Path(entry['path'])
            if hashlib.sha256(source.read_bytes()).hexdigest() != entry['sha256']:
                raise ValueError('Evidence changed: ' + str(source))
            row['deliveryStatus'] = 'QUEUED_NOT_PACKAGED'
            pending.append(entry)
        inventory.append(row)
    pending.sort(key=lambda e: (e['page'], e['pageId'], e['slotId'], e['captureId']))
    # Refuse to replace an earlier snapshot or a receipt owned by another batch.
    args.output.mkdir(parents=True, exist_ok=False)
    batches = []
    for offset in range(0, len(pending), args.batch_size):
        entries = pending[offset:offset + args.batch_size]
        path = args.output / ('review-%03d.json' % (len(batches) + 1))
        path.write_text(json.dumps({'images': entries, 'aiReviewComplete': True,
                                   'userAcceptance': False,
                                   'note': 'References already reviewed evidence; not a Figma import receipt.'},
                                  ensure_ascii=False, indent=2) + '\n')
        batches.append({'review': str(path.resolve()), 'count': len(entries)})
    counts = dict(collections.Counter(row['deliveryStatus'] for row in inventory))
    result = {'sourceIndex': str(args.index.resolve()), 'baseline': index.get('baseline'),
              'counts': counts, 'batches': batches, 'entries': inventory,
              'userAcceptance': False,
              'note': 'A package is not proof of import. Preserve the active plugin until its receipt is saved.'}
    (args.output / 'queue.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'counts': counts, 'batches': len(batches), 'output': str(args.output.resolve())}))


if __name__ == '__main__':
    main()
