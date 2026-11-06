"""Replay the reviewed trajectory-only overrides on the frozen parameter package."""
import gzip
import hashlib
import json
from pathlib import Path

PATCH = Path(__file__).resolve().parents[2] / 'content/practice-jaw-audit/two.json.gz'


def encode(value):
    return json.dumps(value, ensure_ascii=False, separators=(',', ':'), allow_nan=False).encode()


def apply_revision(destination, patch_path=PATCH):
    index_path = destination / 'index.json'
    index = json.loads(index_path.read_bytes())
    patch = json.loads(gzip.decompress(patch_path.read_bytes()))
    source = index.pop('fingerprint')
    if source != patch['sourceFingerprint'] or hashlib.sha256(encode(index)).hexdigest() != source:
        raise ValueError('Two-ball jaw revision requires the original parameter package')
    changes = patch['shards']
    for shard in index['shards']:
        modifications = changes.pop(shard['name'], None)
        if modifications is None:
            continue
        path = destination / (shard['name'] + '.jsonl.gz')
        raw = path.read_bytes()
        if hashlib.sha256(raw).hexdigest() != shard['sha256']:
            raise ValueError('Source shard changed: ' + shard['name'])
        rows = list(map(json.loads, gzip.decompress(raw).splitlines()))
        for layout in rows:
            delta = modifications.pop(layout['id'], None)
            if delta is None:
                continue
            layout['routes'].extend(delta['routes'])
            index['counts']['routes'] += len(delta['routes'])
            settings = delta.get('settings', {})
            for cell in layout['questions']:
                refs = delta['questions'].pop(str(cell['id']), None)
                if refs is not None:
                    cell['trajectoryRefs'] = refs
                by_axes = settings.pop(str(cell['id']), None)
                if by_axes is not None:
                    cell['trajectoryRefsByAxes'] = by_axes
            if delta['questions'] or settings:
                raise ValueError('Unknown cell in ' + layout['id'])
        if modifications:
            raise ValueError('Unknown layout in ' + shard['name'])
        raw = gzip.compress(b''.join(encode(layout) + b'\n' for layout in rows), mtime=0)
        path.write_bytes(raw)
        shard.update(sha256=hashlib.sha256(raw).hexdigest(), bytes=len(raw))
    if changes:
        raise ValueError('Unknown source shards')
    index['jawRevision'] = dict(sourceFingerprint=source, changedReferences=patch['changedReferences'], version=1)
    index['fingerprint'] = hashlib.sha256(encode(index)).hexdigest()
    if index['fingerprint'] != patch['finalFingerprint']:
        raise ValueError('Two-ball parameter projection does not match the approved trajectory package')
    index_path.write_bytes(encode(index))
    return index
