#!/usr/bin/env python3
"""Package audited static formations; never consume an unfinished full run."""
import argparse, gzip, hashlib, json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--destination',type=Path,required=True);p.add_argument('--pilot',action='store_true');a=p.parse_args()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
completion=json.loads((a.source/'completion.json').read_text())
assert completion['passed']
if a.pilot:
    rows=json.loads((a.source/'formations.json').read_text())['items']
    assert len(rows)==365
else:
    merged=a.source/'formations.jsonl.gz'
    assert completion['questions']==39842 and sha(merged)==completion['mergedSHA256']
    with gzip.open(merged,'rt') as f: rows=[json.loads(line) for line in f]
    assert len(rows)==completion['formations']
assert len({r['id'] for r in rows})==len(rows)
a.destination.mkdir(parents=True,exist_ok=True)
shards=[]
for start in range(0,len(rows),5000):
    selected=[{k:r[k] for k in ('id','board','second','third')} for r in rows[start:start+5000]]
    file=a.destination/f'bank-{start//5000:03}.json.gz'
    file.write_bytes(gzip.compress(json.dumps(selected,ensure_ascii=False,allow_nan=False,separators=(',',':')).encode(),mtime=0))
    assert json.loads(gzip.decompress(file.read_bytes()))==selected
    shards.append(dict(file=file.name,sha256=sha(file),count=len(selected)))
manifest=dict(version=1,count=len(rows),source='validated-pilot-128' if a.pilot else 'audited-full-39842',completionSHA256=sha(a.source/'completion.json'),shards=shards)
(a.destination/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(manifest,ensure_ascii=False))
