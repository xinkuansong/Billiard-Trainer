"""Paired production-bank regression; no population success-rate claim."""
from pathlib import Path
import hashlib, json, statistics

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/rail-aim-repair-20261102'
read = lambda p: [json.loads(line) for line in p.read_text().splitlines()]
base = json.loads(Path(__file__).with_name('baseline.json').read_text())
now = read(OUT / 'results.jsonl')
execution = json.loads((OUT / 'execution.json').read_text())
assert execution['exit'] == 0
boundaries = json.loads((OUT / 'boundaries.json').read_text())
assert len(boundaries['variants']) == 96
assert boundaries['plannerSolutions'] > 0
key = lambda r: (r['index'], r['speed'], r['spinX'], r['spinY'])
assert len(now) == len(base) == 750
assert [key(r) for r in base] == [key(r) for r in now]

summary = {'groups': [], 'lost': [], 'missedKnownRescues': [], 'scoringMismatch': [], 'replayMismatch': []}
for old, new in zip(base, now):
    for entry in ['predict', 'position']:
        assert new[entry]['settled'], (key(new), entry, 'incomplete')
        if new[entry]['direct']:
            assert new[entry]['outcome'] == 'success'
            assert sum(e['kind'].startswith('ballBall') and '"object"' in e['kind']
                       for e in new[entry]['events']) == 1
        if old[entry] and not new[entry]['direct']:
            summary['lost'].append([*key(new), entry])
    if old['combination'].endswith('r1') and old['rescue']:
        for entry in ['predict', 'position']:
            if not new[entry]['direct']: summary['missedKnownRescues'].append([*key(new), entry])
    if new['scoringDirect'] != new['position']['direct']: summary['scoringMismatch'].append(key(new))
    if not new['replayExact']: summary['replayMismatch'].append(key(new))
for rail in range(3):
    pairs = [(a, c) for a, c in zip(base, now) if a['combination'].endswith(f'r{rail}')]
    row = {'rail': rail, 'cases': len(pairs)}
    for entry in ['predict', 'position']:
        row[entry + 'Before'] = sum(a[entry] for a,c in pairs)
        row[entry + 'After'] = sum(c[entry]['direct'] for a,c in pairs)
        timings = sorted(c[entry]['ms'] for a,c in pairs)
        row[entry + 'Ms'] = {'median': statistics.median(timings), 'p95': timings[int(.95 * (len(timings)-1))], 'max': max(timings)}
    summary['groups'].append(row)
summary['sourceDrift'] = [p for p,h in json.loads((OUT/'source-manifest.json').read_text()).items()
    if hashlib.sha256((ROOT/p).read_bytes()).hexdigest() != h]
summary['variants'] = len(boundaries['variants'])
summary['variantSeedPots'] = sum(row['seedDirect'] for row in boundaries['variants'])
summary['variantRepairedPots'] = sum(row['direct'] for row in boundaries['variants'])
summary['plannerSolutions'] = boundaries['plannerSolutions']
summary['plannerMs'] = boundaries['plannerMs']
(OUT/'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2))
print(json.dumps(summary, ensure_ascii=False, indent=2))
assert not summary['lost']
assert not summary['missedKnownRescues']
assert not summary['scoringMismatch']
assert not summary['replayMismatch']
assert not summary['sourceDrift']
