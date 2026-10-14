#!/usr/bin/env python3
"""Generate one Figma import batch from a relocated recovery bundle; never run it."""
import argparse
import base64
import hashlib
import json
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--bundle', type=Path, default=Path(__file__).resolve().parent)
p.add_argument('--batch', type=int, required=True, help='One-based batch number')
p.add_argument('--batch-size', type=int, default=80)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
if a.batch < 1 or not 1 <= a.batch_size <= 80:
    p.error('batch >= 1 and 1 <= batch-size <= 80 required')
review = json.loads((a.bundle / 'review.json').read_text())
start = (a.batch - 1) * a.batch_size
rows = review['images'][start:start+a.batch_size]
if not rows:
    p.error('Batch is outside manifest')
if a.output.exists():
    p.error('Refusing to overwrite output')
entries = []
for row in rows:
    source = (a.bundle / row['path']).resolve()
    source.relative_to((a.bundle / 'assets').resolve())
    data = source.read_bytes()
    if hashlib.sha256(data).hexdigest() != row['sha256']:
        raise ValueError('PNG identity mismatch: ' + row['slotId'])
    entry = {k: v for k, v in row.items() if k not in ['path', 'status', 'pixels', 'note']}
    entry.update(pixelWidth=row['pixels'][0], pixelHeight=row['pixels'][1], png=base64.b64encode(data).decode())
    entries.append(entry)
pack = dict(batch=f'recovery-{a.batch:03d}', entries=entries)
code = 'const PACK=' + json.dumps(pack, ensure_ascii=False) + ';\n' + (a.bundle / 'import.js').read_text()
a.output.mkdir(parents=True)
(a.output / 'code.js').write_text(code)
(a.output / 'manifest.json').write_bytes((a.bundle / 'plugin-manifest.json').read_bytes())
print(json.dumps(dict(batch=pack['batch'], count=len(entries), first=start, last=start+len(entries)-1, codeSHA256=hashlib.sha256(code.encode()).hexdigest(), execution='NOT_RUN')))
