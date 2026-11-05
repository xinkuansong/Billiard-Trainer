"""Fail the build if the bundled pipe table no longer matches its owning geometry."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
directory = ROOT / 'QiuJi/Resources/PocketPipe'
metadata = json.loads((directory / 'pipe-grid.json').read_text())
errors = []
for name, expected in metadata['geometrySources'].items():
    if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != expected:
        errors.append('Geometry changed; regenerate pipe table: ' + name)
if hashlib.sha256((directory / 'pipe-grid.bin').read_bytes()).hexdigest() != metadata['binarySHA256']:
    errors.append('Pipe table binary checksum mismatch')
if errors:
    raise SystemExit('\n'.join(errors))
print('Pocket pipe table: geometry and binary checksums match')
