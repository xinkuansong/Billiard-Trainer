#!/usr/bin/env python3
"""Preserve reviewed PNGs and an importer in a relocatable APFS clone bundle.
This is recovery material, not proof of Figma cloud sync or successful re-import.
"""
import argparse
import ctypes
import hashlib
import json
import shutil
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--index', type=Path, required=True)
parser.add_argument('--map', type=Path, required=True)
parser.add_argument('--base-fig', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
a = parser.parse_args()
script_dir = Path(__file__).resolve().parent
index = json.loads(a.index.read_text())
if a.output.exists():
    raise SystemExit('Refusing to overwrite bundle: ' + str(a.output))
a.output.mkdir(parents=True)
assets = a.output / 'assets'
assets.mkdir()
clonefile = ctypes.CDLL(None, use_errno=True).clonefile
clonefile.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int]
clonefile.restype = ctypes.c_int

def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def clone(source, dest):
    if clonefile(bytes(source.resolve()), bytes(dest.resolve()), 0):
        raise OSError(ctypes.get_errno(), 'APFS clone failed; no full-copy fallback', str(source))
    if source.stat().st_ino == dest.stat().st_ino:
        raise ValueError('Expected independent clone, not hard link')

free_before = shutil.disk_usage(a.output).free
manifest = []
unique = {}
for item in index['images']:
    if item['status'] != 'VALIDATED':
        raise ValueError('Unvalidated item: ' + item['captureId'])
    digest = item['sha256']
    source = Path(item['path'])
    dest = assets / (digest + '.png')
    if digest not in unique:
        if sha(source) != digest:
            raise ValueError('Source changed: ' + str(source))
        clone(source, dest)
        if sha(dest) != digest:
            raise ValueError('Clone mismatch: ' + str(dest))
        unique[digest] = source.stat().st_size
    elif not dest.is_file():
        raise ValueError('Missing duplicate asset')
    row = dict(item)
    row['originalPath'] = row['path']
    row['path'] = str(dest.relative_to(a.output))
    # Other old absolute paths remain provenance references, not recovery dependencies.
    manifest.append(row)
(a.output / 'review.json').write_text(json.dumps(dict(manifestKind='NATIVE_ATLAS_RECOVERY_MATERIAL', baseline=index['baseline'], images=manifest), ensure_ascii=False, indent=2)+'\n')
shutil.copy2(a.map, a.output / 'figma-map.json')
shutil.copy2(script_dir / 'figma/import.js', a.output / 'import.js')
shutil.copy2(script_dir / 'figma/manifest.json', a.output / 'plugin-manifest.json')
shutil.copy2(script_dir / 'restore-bundle-package.py', a.output / 'restore-package.py')
shutil.copy2(script_dir / 'RECOVERY.md', a.output / 'README.md')
base_dest = a.output / 'base-1773.fig'
base_sha = sha(a.base_fig)
clone(a.base_fig, base_dest)
if sha(base_dest) != base_sha:
    raise ValueError('Base Figma clone mismatch')
receipt = dict(status='ASSETS_HASH_VERIFIED_REIMPORT_NOT_VERIFIED', baseline=index['baseline'], reviewedViewports=len(manifest), uniquePNG=len(unique), pngLogicalBytes=sum(unique.values()), baseFigSHA256=base_sha, baseFigBytes=base_dest.stat().st_size, independentCloneInodes=True, freeBytesBefore=free_before, freeBytesAfter=shutil.disk_usage(a.output).free, fullExpandedFigExportVerified=False, figmaRestoreVerified=False, cloudSyncVerified=False, userAcceptance=False)
(a.output / 'verification.json').write_text(json.dumps(receipt, indent=2)+'\n')
print(json.dumps(receipt))
