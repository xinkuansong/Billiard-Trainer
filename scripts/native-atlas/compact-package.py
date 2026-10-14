#!/usr/bin/env python3
"""Archive completed payloads by referencing immutable originals; verify exact restoration."""
import argparse, base64, gzip, hashlib, json
from pathlib import Path

def digest(data):
    return hashlib.sha256(data).hexdigest()

def restore(recipe):
    pack = json.loads(json.dumps(recipe['pack'], ensure_ascii=False))
    for entry, source in zip(pack['entries'], recipe['sources'], strict=True):
        data = Path(source).read_bytes()
        if digest(data) != entry['sha256']:
            raise ValueError('Original PNG changed: ' + source)
        entry['png'] = base64.b64encode(data).decode()
    code = ('const PACK=' + json.dumps(pack, ensure_ascii=False) + ';\n' + recipe['importer']).encode()
    if digest(code) != recipe['sha256']:
        raise ValueError('Reconstructed payload differs from archive')
    return code

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--archive', type=Path, required=True)
p.add_argument('--receipt', type=Path)
p.add_argument('--restore-to', type=Path)
a = p.parse_args()
recipe_path = a.archive / 'reconstruction.json'
if a.restore_to:
    data = restore(json.loads(recipe_path.read_text()))
    # Do not replace an active plugin or another existing artifact implicitly.
    with a.restore_to.open('xb') as f:
        f.write(data)
    print(json.dumps(dict(restored=str(a.restore_to), bytes=len(data), sha256=digest(data))))
else:
    if not a.receipt:
        p.error('--receipt required before compacting')
    receipt = json.loads(a.receipt.read_text())
    package = json.loads((a.archive / 'package.json').read_text())
    assert receipt['status'] == 'IMPORTED_READBACK_OK'
    assert receipt['batch'] == package['batch'] == a.archive.name
    key = lambda x: (x['slotId'], x['captureId'], x['sha256'])
    assert sorted(map(key, receipt['entries'])) == sorted(map(key, package['entries']))
    code_path = a.archive / 'code.js'
    gzip_path = a.archive / 'code.js.gz'
    if recipe_path.exists():
        recipe = json.loads(recipe_path.read_text())
        rebuilt = restore(recipe)
    else:
        original = code_path.read_bytes() if code_path.exists() else gzip.decompress(gzip_path.read_bytes())
        prefix, importer = original.decode().split(';\n', 1)
        assert prefix.startswith('const PACK=')
        pack = json.loads(prefix[len('const PACK='):])
        assert sorted(map(key, pack['entries'])) == sorted(map(key, receipt['entries']))
        review = json.loads(Path(package['review']).read_text())
        sources = {key(e): e['path'] for e in review['images'] if e['status'] == 'VALIDATED'}
        paths = []
        for entry in pack['entries']:
            paths.append(str(Path(sources[key(entry)]).resolve()))
            entry.pop('png')
        recipe = dict(format='native-atlas-reference-archive-v1', pack=pack, sources=paths,
                      importer=importer, sha256=digest(original), bytes=len(original),
                      receipt=str(a.receipt.resolve()), note='Keep referenced original PNGs with this archive.')
        rebuilt = restore(recipe)
        assert rebuilt == original
        recipe_path.write_text(json.dumps(recipe, ensure_ascii=False, indent=2) + '\n')
        assert restore(json.loads(recipe_path.read_text())) == original
    removed = 0
    for path in [code_path, gzip_path]:
        if path.exists():
            data = path.read_bytes()
            decoded = gzip.decompress(data) if path == gzip_path else data
            assert decoded == rebuilt
            removed += len(data)
            path.unlink()
    (a.archive / 'code-archive.json').write_text(json.dumps(dict(
        representation='reconstruction.json + referenced original PNGs', sha256=recipe['sha256'],
        bytes=recipe['bytes'], exactRoundtripVerified=True, compactBytes=recipe_path.stat().st_size,
        restore='python3 scripts/native-atlas/compact-package.py --archive <this-directory> --restore-to <new-code.js>'
    ), ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(dict(batch=package['batch'], exactRoundtrip='PASS', removedGeneratedBytes=removed,
                          recipeBytes=recipe_path.stat().st_size)))
