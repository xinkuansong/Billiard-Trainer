"""Apply the App-replayed reference parameters to the frozen research projection."""
import gzip
import hashlib
import json
from pathlib import Path

PATCH = Path(__file__).resolve().parents[2] / 'content/practice-jaw-audit/kball.json.gz'

def encode(value):
    return json.dumps(value,ensure_ascii=False,separators=(',',':'),allow_nan=False).encode()

def digest(data):
    return hashlib.sha256(data).hexdigest()

def load_patch():
    return json.loads(gzip.decompress(PATCH.read_bytes()))

def reference_fields(change):
    inputs=change['input']
    direction=change['direction']
    return dict(v=inputs['velocity'],sx=inputs['spinX'],sy=inputs['spinY'],dir=[direction['x'],direction['z']])

def apply(destination):
    path=destination/'index.json'
    raw=path.read_bytes()
    patch=load_patch()
    if digest(raw)!=patch['source']:
        raise ValueError('Expected the original K-ball projection')
    pending=dict(patch['changes'])
    index=json.loads(raw)
    old=index.pop('fingerprint')
    for shard in index['shards']:
        target=destination/(shard['name']+'.jsonl.gz')
        data=target.read_bytes()
        if digest(data)!=shard['sha256']:
            raise ValueError('K-ball shard changed '+shard['name'])
        layouts=list(map(json.loads,gzip.decompress(data).splitlines()))
        changed=False
        for layout in layouts:
            for question in layout['questions']:
                edit=pending.pop(question['id'],None)
                if edit is not None:
                    question.update(reference_fields(edit))
                    changed=True
        if changed:
            data=gzip.compress(b''.join(encode(layout)+b'\n' for layout in layouts),mtime=0)
            target.write_bytes(data)
            shard.update(bytes=len(data),sha256=digest(data))
    index['jawRevision']=dict(sourceFingerprint=old,changedReferences=len(patch['changes']),version=1)
    index['fingerprint']=digest(encode(index))
    data=encode(index)
    if pending or digest(data)!=patch['result']:
        raise ValueError('Incomplete K-ball revision or unexpected final hash')
    path.write_bytes(data)
