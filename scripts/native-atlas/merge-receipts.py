#!/usr/bin/env python3
"""Merge saved plugin receipts after matching every image to reviewed evidence.

Plugin readback verifies the desktop document, not remote sync or user acceptance.
"""
import argparse
import json
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--map', type=Path, required=True)
p.add_argument('--index', type=Path, required=True)
p.add_argument('--receipts', type=Path, nargs='+', required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
mapping = json.loads(a.map.read_text())
reviewed = {(e['slotId'], e['sha256']): e
            for e in json.loads(a.index.read_text())['images']}
frames = {(e['slotId'], e['sha256']): e for e in mapping['frames']}
added = 0
for path in a.receipts:
    receipt = json.loads(path.read_text())
    if receipt['status'] != 'IMPORTED_READBACK_OK':
        raise ValueError('Unsuccessful receipt: ' + str(path))
    for entry in receipt['entries']:
        key = entry['slotId'], entry['sha256']
        evidence = reviewed[key]
        if evidence['pixels'] != [entry['pixels']['width'], entry['pixels']['height']]:
            raise ValueError('Pixel mismatch: ' + entry['captureId'])
        if not all(entry.get(field) for field in ('frame', 'image', 'imageHash', 'page', 'section')):
            raise ValueError('Incomplete node readback: ' + entry['captureId'])
        if key in frames:
            if frames[key]['frame'] != entry['frame']:
                raise ValueError('Duplicate identity points to different frames: ' + entry['slotId'])
            continue
        frames[key] = dict(entry, receipt=str(path.resolve()))
        added += 1
mapping.update(frames=list(frames.values()), count=len(frames), userAcceptance=False,
               syncStatus='Desktop readback verified; cloud sync not independently confirmed.')
a.output.parent.mkdir(parents=True, exist_ok=True)
temporary = a.output.with_suffix('.tmp')
temporary.write_text(json.dumps(mapping, ensure_ascii=False, indent=2) + '\n')
temporary.replace(a.output)
print(json.dumps({'added': added, 'savedReceiptFrames': len(frames)}))
