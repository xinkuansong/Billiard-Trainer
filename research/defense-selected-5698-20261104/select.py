"""Select unchanged opening layouts; no reference solutions are generated here."""
import gzip
import hashlib
import json
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'output/defense-pocket-cleanup-20261104/catalogs'
OUT = ROOT / 'output/defense-selected-5698-20261104'
OUT.mkdir(parents=True, exist_ok=True)
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
manifest = {'status': 'opening-layout-selection-only', 'method': 'all one-ball; uniform sampling without replacement independently per other class; source order retained', 'catalogs': {}}
for index, (kind, expected, count) in enumerate([
    ('one', 1198, 1198), ('two_black', 10023, 1500),
    ('two_own', 10023, 1500), ('three', 37756, 1500),
]):
    source = SOURCE / f'{kind}.jsonl.gz'
    before = sha(source)
    with gzip.open(source, 'rb') as f:
        lines = [line for line in f if line.strip()]
    rows = [json.loads(line) for line in lines]
    assert len(rows) == expected
    assert len({r['formationID'] for r in rows}) == expected
    seed = 2026110450 + index
    chosen = list(range(expected)) if kind == 'one' else sorted(random.Random(seed).sample(range(expected), count))
    selected = [rows[i] for i in chosen]
    for row in selected:
        assert row['kind'] == kind
        assert 1e-6 < row['ownAttack']['best']['cueWidth'] <= .008
        assert row['maxPocketComfort'] < 10
    target = OUT / f'{kind}.jsonl.gz'
    with target.open('wb') as raw:
        with gzip.GzipFile(filename='', mode='wb', fileobj=raw, mtime=0) as f:
            f.writelines(lines[i] for i in chosen)
    with gzip.open(target, 'rb') as f:
        exported = f.readlines()
    assert exported == [lines[i] for i in chosen]
    assert len(exported) == count and sha(source) == before
    manifest['catalogs'][kind] = {
        'source': str(source.relative_to(ROOT)), 'sourceCount': expected,
        'sourceSHA256': before, 'selectedCount': count,
        'seed': None if kind == 'one' else seed,
        'file': target.name, 'sha256': sha(target),
        'formationIDs': [r['formationID'] for r in selected],
    }
manifest['total'] = sum(c['selectedCount'] for c in manifest['catalogs'].values())
assert manifest['total'] == 5698
manifest['verification'] = 'PASS: counts, unique IDs per class, opening thresholds, exact source record bytes, source hashes unchanged'
manifest['scriptSHA256'] = sha(Path(__file__))
(OUT / 'selection.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
(OUT / 'README.md').write_text('''# 防守轨迹模式候选球形选集

单颗黑八1198道全部保留；另外三类各随机抽取1500道，共5698道。
原59000条清理库保留，供自由模式使用。这里是待求解的球形，不是已验收的轨迹题。

使用独立固定随机种子、不放回抽取，输出保持源库顺序；原记录逐字节保留。
每类gzip JSONL独立存储；selection.json含原库和选集指纹、种子及全部formationID。
两种两球类别的相同几何允许共存，因为球号和球权不同；本轮不额外做跨类或近似球形去重。
重建命令：python3 research/defense-selected-5698-20261104/select.py
''')
print(json.dumps({'counts': {k: v['selectedCount'] for k, v in manifest['catalogs'].items()}, 'total': manifest['total'], 'verification': manifest['verification']}, ensure_ascii=False))
