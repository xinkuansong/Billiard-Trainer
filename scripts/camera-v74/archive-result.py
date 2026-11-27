#!/usr/bin/env python3
"""Hash and verify this task's native evidence before xcresult analysis."""
import hashlib,json,sys
from pathlib import Path
mode=sys.argv[1];root=Path(sys.argv[2]).resolve();manifest=root/'archive-manifest.json'
def digest(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for block in iter(lambda:f.read(1024*1024),b''):h.update(block)
 return h.hexdigest()
if mode=='create':
 files={str(p.relative_to(root)):digest(p) for p in sorted(root.rglob('*')) if p.is_file() and p!=manifest}
 manifest.write_text(json.dumps(files,indent=2))
elif mode=='verify':
 files=json.loads(manifest.read_text())
 for rel,expected in files.items():
  path=(root/rel).resolve();assert path.is_relative_to(root)
  assert digest(path)==expected,rel
else:raise ValueError(mode)
print(json.dumps({'mode':mode,'files':len(files),'root':str(root)}))
