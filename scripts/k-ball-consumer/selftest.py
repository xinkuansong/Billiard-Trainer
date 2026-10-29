"""Constructive package-gate tests against isolated copies; production files are read-only."""
import copy
import gzip
import hashlib
import json
import shutil
import tempfile
from pathlib import Path
from verify import verify


ROOT = Path(__file__).resolve().parents[2]


def run():
    passed = []
    with tempfile.TemporaryDirectory(prefix='k-ball-gate-') as tmp:
        root = Path(tmp)
        bank = root / 'QiuJi/Resources/KBallBank'
        shutil.copytree(ROOT / 'QiuJi/Resources/KBallBank', bank)
        (root/'QiuJi.xcodeproj').mkdir()
        for name in ('project.yml', 'QiuJi.xcodeproj/project.pbxproj'):
            shutil.copyfile(ROOT/name, root/name)
        original_index = (bank/'index.json').read_bytes()
        index = json.loads(original_index)
        shard_path = bank/(index['shards'][0]['name']+'.jsonl.gz')
        original_shard = shard_path.read_bytes()

        def rejected(label, mutate, restore):
            mutate()
            try:
                try:
                    verify(root)
                except (ValueError, OSError, KeyError, IndexError, EOFError):
                    passed.append(label)
                else:
                    raise AssertionError('Gate accepted '+label)
            finally:
                restore()

        verify(root); passed.append('valid control')
        rejected('corrupted shard', lambda: shard_path.write_bytes(original_shard[:-1]),
                 lambda: shard_path.write_bytes(original_shard))
        rejected('missing shard', lambda: shard_path.unlink(), lambda: shard_path.write_bytes(original_shard))
        rejected('extra full trajectory', lambda: (bank/'tracks.json').write_text('{}'),
                 lambda: (bank/'tracks.json').unlink())

        def write_index(value):
            value.pop('fingerprint', None)
            value['fingerprint'] = hashlib.sha256(json.dumps(value,ensure_ascii=False,separators=(',',':')).encode()).hexdigest()
            (bank/'index.json').write_text(json.dumps(value, ensure_ascii=False, separators=(',',':')))

        bad = copy.deepcopy(index); bad['counts']['questions'] -= 1
        rejected('incorrect count with updated fingerprint', lambda: write_index(bad),
                 lambda: (bank/'index.json').write_bytes(original_index))
        bad = copy.deepcopy(index); bad['layouts'][0]['line'] = 2
        rejected('incorrect line with updated fingerprint', lambda: write_index(bad),
                 lambda: (bank/'index.json').write_bytes(original_index))
        for name, token in [('project.yml','Resources/KBallBank/**'),
                            ('QiuJi.xcodeproj/project.pbxproj','KBallBank in Resources')]:
            path = root/name; original = path.read_text()
            rejected('missing packaging '+name, lambda: path.write_text(original.replace(token,'REMOVED')),
                     lambda: path.write_text(original))
        verify(root); passed.append('restored control')
    print(json.dumps(dict(passed=True, cases=passed), ensure_ascii=False))


if __name__ == '__main__':
    run()
