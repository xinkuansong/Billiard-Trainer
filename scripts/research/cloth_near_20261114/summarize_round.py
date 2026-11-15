"""Summarize one completed exact H9 candidate and retain all paired cycles."""
from pathlib import Path
import argparse
import hashlib
import json
import statistics

p = argparse.ArgumentParser()
p.add_argument('--run', required=True, type=Path)
p.add_argument('--output', required=True, type=Path)
a = p.parse_args()
state = json.loads((a.run / 'run.json').read_text())
assert state['exit_code'] == 0 and state['state'] in ('complete', 'reclaimed')
evidence = a.run / 'evidence'
for name, digest in state['evidence_sha256'].items():
    assert hashlib.sha256((evidence / name).read_bytes()).hexdigest() == digest
abi = json.loads((evidence / 'constant-array-abi.json').read_text())
assert abi['exact'] and abi['bothComparedToCPUSentinels']
cases = []
for r in json.loads((evidence / 'results.json').read_text()):
    case = {key: r[key] for key in ('variant', 'pose', 'width', 'maximumChannelDifference', 'tolerance')}
    case['AAImageMaximum'] = max(c['aa']['maximumChannelDifference'] for c in r['comparisons'])
    case['timing'] = {}
    for metric in ('gpuMS', 'cpuEncodeMS', 'wallMS'):
        case['timing'][metric] = {}
        for kind in ('AA', 'AB'):
            cycles = []
            for i in range(6):
                arms = {}
                for arm in ('A', 'B'):
                    samples = [v for q in r['times'] if q['kind'] == kind and q['cycle'] == i and q['arm'] == arm for v in q[metric]]
                    assert len(samples) == 24
                    arms[arm] = statistics.mean(samples)
                cycles.append({'cycle': i, 'A_MS': arms['A'], 'B_MS': arms['B'], 'changePercent': 100 * (arms['B'] / arms['A'] - 1)})
            case['timing'][metric][kind] = {'pairedMedianChangePercent': statistics.median(c['changePercent'] for c in cycles), 'cycles': cycles}
    gpu = case['timing']['gpuMS']
    aa = abs(gpu['AA']['pairedMedianChangePercent'])
    ab = gpu['AB']['pairedMedianChangePercent']
    case['qualityPassed'] = case['maximumChannelDifference'] == 0 and case['AAImageMaximum'] == 0
    case['GPUCriterionPassed'] = -ab > max(5, aa) if case['pose'] == 'single-near' else ab <= max(3, aa)
    cases.append(case)
assert {c['pose'] for c in cases} == {'single-low', 'single-near', 'scatter-overview'}
report = {'runID': state['id'], 'scope': 'Native C1 material; preliminary quality/performance, not full app or energy', 'ABI': abi, 'evidenceHashesVerified': True, 'eligibleForBroaderChecks': all(c['qualityPassed'] and c['GPUCriterionPassed'] for c in cases), 'cases': cases}
a.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n')
print({'run': state['id'], 'eligible': report['eligibleForBroaderChecks'], 'GPU': {c['pose']: {k: c['timing']['gpuMS'][k]['pairedMedianChangePercent'] for k in ('AA', 'AB')} for c in cases}})
