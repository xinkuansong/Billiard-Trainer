#!/usr/bin/env python3
"""Preserve a terminal diagnostic run outside the disposable build directory."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys

repo = Path(__file__).resolve().parents[2]
name = sys.argv[1]
assert re.fullmatch(r'formal-[a-z0-9-]+', name)
build = repo / 'build/quality-diagnosis'
run = build / name
assert (run / 'exit.json').is_file(), 'Only archive a terminal, recorded run'
destination = repo / 'archive/quality-diagnosis/runs' / name
assert not destination.exists(), 'Never overwrite previous evidence'
destination.parent.mkdir(parents=True, exist_ok=True)
subprocess.run(['/bin/cp', '-cR', str(run), str(destination)], check=True)
inputs = json.loads((run / 'inputs.json').read_text())
snapshot = build / inputs['config']['snapshot']
for selector in inputs['config']['selectors']:
    target, cls, _ = selector.split('/')
    relative = target + '/' + cls + '.swift'
    source = snapshot / relative
    data = source.read_bytes()
    assert hashlib.sha256(data).hexdigest() == inputs['hashes'][relative], 'Test source drifted before archival'
    output = destination / 'tested-sources' / relative
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(data)
log = (run / 'xcode-test.log').read_text()
paths = [Path(x.strip()) for x in log.splitlines() if x.strip().endswith('.xcresult')]
result_paths = []
for path in dict.fromkeys(paths):
    if path.is_absolute() and path.is_relative_to(build) and path.is_dir():
        subprocess.run(['/bin/cp', '-cR', str(path), str(destination / path.name)], check=True)
        result_paths.append(path.name)
assert result_paths, 'No actual result bundle found; preserved run needs investigation'
manifest = {}
for path in destination.rglob('*'):
    if path.is_file():
        manifest[str(path.relative_to(destination))] = hashlib.sha256(path.read_bytes()).hexdigest()
(destination / 'archive-manifest.json').write_text(json.dumps({
    'source_run': str(run), 'result_bundles': result_paths, 'files': manifest
}, indent=2))
print(json.dumps({'archived_run': name, 'file_count': len(manifest), 'result_bundles': result_paths}))
