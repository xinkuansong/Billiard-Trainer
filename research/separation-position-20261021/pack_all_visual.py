from pathlib import Path
from collections import Counter
import copy
import json

root = Path(__file__).resolve().parent
destination = Path('/Users/song/.codex/visualizations/2026/10/21/01a15f02-cbf1-70b2-adb0-199936e10fc6')

def runs(ids):
    result = []
    for value in ids:
        if result and value == result[-2] + result[-1]:
            result[-1] += 1
        else:
            result.extend([value, 1])
    assert [start + offset for start, length in zip(result[::2], result[1::2]) for offset in range(length)] == ids
    return result

for folder, name in [(root, 'separation-position.html'), (root / 'r2-max45', 'separation-position-max45.html')]:
    data = json.loads((folder / 'all-visual-data.json').read_text())
    scan = json.loads((folder / 'scan.json').read_text())
    assert {r['id'] for r in data['rows']} == {r['id'] for r in scan['rows'] if r['accepted']}
    assert Counter(len(r['rails']) for r in data['rows']) == {int(k):v for k,v in data['counts'].items()}
    # Compare all pre-existing examples, including every candidate-grid cell.
    old = json.loads((folder / 'visual-data.json').read_text())
    lookup = {r['id']:r for r in data['rows']}
    for row in old['rows']:
        assert row == lookup[row['id']]
    packed = copy.deepcopy(data)
    packed['indexEncoding'] = 'runs'
    for row in packed['rows']:
        for region in row['regions']:
            if region:
                region['raw'] = runs(region['raw'])
                region['valid'] = runs(region['valid'])
    html = (folder / 'visual-template.html').read_text().replace('__DATA__', json.dumps(packed, separators=(',', ':')))
    assert len(html.encode()) < 1_000_000
    (folder / 'separation-position.html').write_text(html)
    (destination / name).write_text(html)
    print(name, len(data['rows']), data['counts'], len(html.encode()), 'bytes; complete IDs, example parity and lossless grid encoding passed')
