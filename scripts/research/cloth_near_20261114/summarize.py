"""Recompute H6/H7 screening decisions from retained evidence only."""
from pathlib import Path
import hashlib
import json
import statistics

ROOT = Path(__file__).resolve().parents[3]
RUNS = {
    'H6-R1': '91bb5e09281d403faa369e1b139fdb70',
    'H6-R2': 'fac5adb4a01944358a4604efc926e881',
    'H6-R3': 'd4e46e73d20b4658b6c8670632c3b8b5',
    'H7-R1': 'c6bf5b703301406c8c19598254a81a9b',
    'H7-R2': '54a8ab69ba504799a03e42eca4ab51db',
    'H7-R3': '2762c571f3084ea09c4b50fd7f5ec2c6',
}


def timing(rows, kind, metric):
    cycles = []
    for cycle in range(6):
        arms = {}
        for arm in ('A', 'B'):
            values = [v for r in rows if r['kind'] == kind and r['cycle'] == cycle
                      and r['arm'] == arm for v in r[metric]]
            assert len(values) == 24
            arms[arm] = statistics.mean(values)
        cycles.append({'cycle': cycle, 'A_MS': arms['A'], 'B_MS': arms['B'],
                       'changePercent': (arms['B'] / arms['A'] - 1) * 100})
    return {'pairedMedianChangePercent': statistics.median(r['changePercent'] for r in cycles),
            'cycles': cycles}


report = {'scope': 'C1 native material; initial screening, not full App or energy',
          'newProductionCandidateAdopted': False, 'runs': [], 'decisions': {}}
identities = []
for round_name, run_id in RUNS.items():
    run = ROOT / 'output/local-test-runs' / run_id
    state = json.loads((run / 'run.json').read_text())
    assert state['state'] == 'reclaimed' and state['exit_code'] == 0
    evidence = run / 'evidence'
    for name, digest in state['evidence_sha256'].items():
        assert hashlib.sha256((evidence / name).read_bytes()).hexdigest() == digest, name
    source = json.loads((evidence / 'source-identity.json').read_text())
    identities.append({k: v for k, v in source.items()
                       if k.startswith(('QiuJi/', 'output/render-lowdim-20261113/'))})
    item = {'round': round_name, 'runID': run_id, 'state': state['state'], 'cases': []}
    for r in json.loads((evidence / 'results.json').read_text()):
        case = {k: r[k] for k in ('variant', 'pose', 'width', 'maximumChannelDifference', 'tolerance')}
        case['maximumAAChannelDifference'] = max(v['aa']['maximumChannelDifference'] for v in r['comparisons'])
        case['comparedStates'] = len(r['comparisons'])
        case['timing'] = {m: {k: timing(r['times'], k, m) for k in ('AA', 'AB')}
                          for m in ('gpuMS', 'cpuEncodeMS', 'wallMS')} if r['times'] else {}
        item['cases'].append(case)
        report['decisions'].setdefault(case['variant'], []).append(case)
    report['runs'].append(item)
assert all(s == identities[0] for s in identities)
for name, digest in identities[0].items():
    assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest, name
for name, cases in list(report['decisions'].items()):
    assert len(cases) == 3
    quality = all(c['maximumChannelDifference'] <= c['tolerance']
                  and c['maximumAAChannelDifference'] == 0 for c in cases)
    margins = {}
    for c in cases:
        if not c['timing']:
            margins[c['pose']] = False
            continue
        gpu = c['timing']['gpuMS']
        aa = abs(gpu['AA']['pairedMedianChangePercent'])
        ab = gpu['AB']['pairedMedianChangePercent']
        margins[c['pose']] = -ab > max(5, aa) if c['pose'] == 'single-near' else ab <= max(3, aa)
    report['decisions'][name] = {'qualityScreenPassed': quality,
                                 'GPUCriteriaByPose': margins,
                                 'eligibleForBroaderChecks': quality and all(margins.values())}
report['productionAndFrozenAssetIdentitiesEqualAndCurrent'] = True
report['retainedEvidenceHashesVerified'] = True
report['sourceIdentity'] = identities[0]
destination = ROOT / 'tasks/render-highlight-20261114/H6-H7-results.json'
destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print({'runs': len(RUNS), 'variants': len(report['decisions']),
       'eligible': [k for k, v in report['decisions'].items() if v['eligibleForBroaderChecks']],
       'sourceAndEvidenceVerified': True})
