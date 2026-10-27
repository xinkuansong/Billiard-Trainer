"""Recompute within-rack speed variance from frozen research snapshots. No simulation."""
from pathlib import Path
import gzip
import hashlib
import json
import math
import statistics
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/rack-speed-variance-20261027'
OUT.mkdir(parents=True, exist_ok=True)
SETS = ['rack-energy-layout-20261027', 'rack-core-energy-20261027', 'rack-front-core-20261027']
def sha(p):
    h = hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda: f.read(1024 * 1024), b''): h.update(b)
    return h.hexdigest()
def write(n, obj):
    (OUT / n).write_text(json.dumps(obj, ensure_ascii=False, indent=2, allow_nan=False) + '\n')
def ranks(a):
    order = np.argsort(a); r = np.empty(len(a)); i = 0
    while i < len(a):
        j = i + 1
        while j < len(a) and a[order[j]] == a[order[i]]: j += 1
        r[order[i:j]] = (i + j - 1) / 2; i = j
    return r
def corr(a, b):
    return float(np.corrcoef(a, b)[0, 1]) if np.std(a) > 0 and np.std(b) > 0 else None

production = {str(p.relative_to(ROOT)): sha(p) for p in (ROOT / 'QiuJi').rglob('*.swift')}
prior_path = ROOT / 'output/rack-global-review-20261027/rows.json'
sources = {str(prior_path.relative_to(ROOT)): sha(prior_path)}
prior = {(r['batch'], r['id'], r['policy']): r for r in json.loads(prior_path.read_text())}
rows = []; params = None; engine = None; cue = {}; checks = 0; max_error = 0.
for batch, name in enumerate(SETS):
    folder = ROOT / 'output' / name
    frozen = json.loads((folder / 'engine-freeze.json').read_text())
    if engine is None: engine = frozen
    assert engine == frozen
    for fn in ['raw.jsonl.gz', 'engine-freeze.json']:
        sources[str((folder / fn).relative_to(ROOT))] = sha(folder / fn)
    with gzip.open(folder / 'raw.jsonl.gz', 'rt') as f:
        for line in f:
            raw = json.loads(line); q = raw['input']
            if q['cohort'] != 'holdout' or q['condition'] != 'original': continue
            assert q['mode'] == 2 and q['power'] == 10 and raw['status'] == 'settled'
            if params is None: params = raw['parameters']
            assert params == raw['parameters']
            ck = (batch, q['rackID'])
            assert cue.setdefault(ck, raw['initialCueVelocity']) == raw['initialCueVelocity']
            p = prior[batch, q['rackID'], q['policy']]
            row = {k: p[k] for k in ['batch', 'id', 'policy', 'closePairs100', 'escape100', 'nearestGap', 'crowdedFraction_one', 'crowded_one', 'finalN', 'tail', 'scratch']}
            for sm in raw['samples']:
                ms = round(sm['delay'] * 1000)
                if ms not in [5, 20, 100]: continue
                by = dict(zip(raw['names'], sm['states']))
                states = [by[n] for n in raw['canonicalNames']]
                assert len(states) == 15 and all(s['state'] != 'pocketed' for s in states)
                speeds = [math.sqrt(sum(x*x for x in s['v'])) for s in states]
                mean = statistics.mean(speeds)
                variance = float(np.mean((np.array(speeds) - mean)**2))
                energy = .5 * params['ballMass'] * sum(v*v for v in speeds)
                errors = [abs(variance - statistics.pvariance(speeds)), abs(variance + mean**2 - 2*energy/(15*params['ballMass']))]
                if ms == 5:
                    errors += [abs(variance - (p['meanSpeed']*p['speedCV'])**2), abs(energy-p['energy'])]
                max_error = max(max_error, *errors); assert max(errors) < 1e-10
                row[f'variance{ms}'] = variance
                row[f'energy{ms}'] = energy
                checks += 1
            assert all(f'variance{t}' in row for t in [5, 20, 100])
            rows.append(row)
    print(name, 'done', flush=True)
assert len(rows) == 2000 and checks == 6000
groups = {}
for r in rows: groups.setdefault(f"{r['batch']}:{r['policy']}", []).append(r)
keys = [k for k in rows[0] if k not in ['batch', 'id', 'policy']]
summary = {g: dict(n=len(a), **{k: statistics.mean(r[k] for r in a) for k in keys}) for g,a in groups.items()}
assert all(s['n'] == 200 for s in summary.values())
comparisons = [(0,'inner_first','baseline'), (0,'template_09','inner_first'), (0,'independent','baseline'), (1,'corerear_90','parent'), (1,'late_60_0_90','parent'), (1,'late_60_0_90','corerear_90'), (2,'exit_-30','parentB'), (2,'exit_-60','parentB'), (2,'exit_-30','exit_-60')]
indices = np.random.default_rng(2026102709).integers(0, 200, (4000, 200))
paired = {}
for batch, new, base in comparisons:
    a = sorted(groups[f'{batch}:{new}'], key=lambda r:r['id'])
    b = sorted(groups[f'{batch}:{base}'], key=lambda r:r['id'])
    assert [r['id'] for r in a] == [r['id'] for r in b]
    delta = np.array([[x[k]-y[k] for k in keys] for x,y in zip(a,b)])
    ci = np.quantile(delta[indices].mean(axis=1), [.025, .975], axis=0)
    stats = {k: dict(mean=float(delta[:,i].mean()), median=float(np.median(delta[:,i])), ci95=ci[:,i].tolist(), decreased=int(sum(delta[:,i]<-1e-12)), increased=int(sum(delta[:,i]>1e-12))) for i,k in enumerate(keys)}
    paired[f'{batch}:{new}-{base}'] = stats
associations = {}
for g, a in groups.items():
    x = ranks(np.array([r['variance5'] for r in a]))
    controls = np.column_stack([np.ones(len(a)), ranks(np.array([r['energy5'] for r in a])), ranks(np.array([r['finalN'] for r in a]))])
    rx = x - controls @ np.linalg.lstsq(controls, x, rcond=None)[0]
    associations[g] = {}
    for k in ['closePairs100', 'escape100', 'nearestGap', 'crowdedFraction_one']:
        y = ranks(np.array([r[k] for r in a]))
        ry = y - controls @ np.linalg.lstsq(controls, y, rcond=None)[0]
        associations[g][k] = dict(spearman=corr(x,y), partialRankEnergyAndFinalN=corr(rx,ry))
assert all(sha(ROOT / p) == h for p,h in sources.items())
assert all(sha(ROOT / p) == h for p,h in production.items())
write('rows.json', rows); write('summary.json', summary); write('paired.json', paired); write('associations.json', associations)
write('verification.json', dict(rows=len(rows), snapshotChecks=checks, maxIdentityError=max_error, sourceSHA=sources, engineSHA=engine, parameters=params, productionSHA=production, pairedSeeds=len(cue), newSimulations=0))
print(json.dumps(summary, ensure_ascii=False, indent=2))
