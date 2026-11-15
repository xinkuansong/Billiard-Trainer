"""Summarize existing H10 evidence; never reruns or filters timing samples."""
from pathlib import Path
import hashlib
import json
import statistics

ROOT = Path(__file__).resolve().parents[3]
RUNS = {
    'R1': 'eaad85d8ee3f47df94f834c7fb25f563',
    'R2': 'e4623ab3b9ce4ec699d08732a8509ad5',
    'R3': 'd022fd130eac4808a11dfce137a2e457',
}


def summarize():
    rounds = {}
    for name, run_id in RUNS.items():
        run = ROOT / 'output/local-test-runs' / run_id
        evidence = run / 'evidence'
        raw = evidence / 'results.json'
        baseline = (evidence / 'baseline.surface').read_bytes()
        assert hashlib.sha256(baseline).hexdigest() == '14a880284fffc793f01d0357b0a625559101609d7986c9ac0cac72e7085efa4f'
        record = json.loads((run / 'run.json').read_text())
        assert record['exit_code'] == 0 and record['state'] == 'reclaimed'
        rows = []
        for result in json.loads(raw.read_text()):
            row = {key: result[key] for key in (
                'variant', 'pose', 'width', 'diagnosticOnly',
                'maximumChannelDifference', 'tolerance', 'comparisons')}
            row['metrics'] = {}
            if result['times']:
                for metric in ['gpuMS', 'cpuEncodeMS', 'wallMS']:
                    row['metrics'][metric] = {}
                    for kind in ['AA', 'AB']:
                        cycles = []
                        for cycle in range(6):
                            arms = {
                                arm: [value for t in result['times']
                                      if t['kind'] == kind and t['cycle'] == cycle and t['arm'] == arm
                                      for value in t[metric]]
                                for arm in ['A', 'B']
                            }
                            assert all(len(values) == 48 for values in arms.values())
                            a, b = (statistics.mean(arms[arm]) for arm in ['A', 'B'])
                            cycles.append({'cycle': cycle, 'A_ms': a, 'B_ms': b,
                                           'changePercent': (b / a - 1) * 100})
                        row['metrics'][metric][kind] = {
                            'medianChangePercent': statistics.median(x['changePercent'] for x in cycles),
                            'cycles': cycles,
                        }
                gpu = row['metrics']['gpuMS']
                aa = abs(gpu['AA']['medianChangePercent'])
                ab = gpu['AB']['medianChangePercent']
                threshold = max(5 if result['pose'] == 'single-near' else 3, aa)
                row['performanceGatePassed'] = -ab > threshold if result['pose'] == 'single-near' else ab <= threshold
            else:
                row['performanceGatePassed'] = None
            rows.append(row)
        rounds[name] = {'runID': run_id, 'resultsSHA256': hashlib.sha256(raw.read_bytes()).hexdigest(), 'rows': rows}
    destination = ROOT / 'tasks/render-highlight-20261114/H10-results.json'
    destination.write_text(json.dumps({
        'baseline': 'C1 + H9', 'scope': 'Native macOS imported table and cloth; no ball geometry, room, SwiftUI or phone',
        'timing': '6 AA / 6 AB cycles, alternating ABBA/BAAB, 48 samples per arm per cycle; no discarded samples',
        'totalVisualPairs': sum(len(row['comparisons']) for r in rounds.values() for row in r['rows']),
        'rounds': rounds,
    }, indent=2) + '\n')
    print(destination)


if __name__ == '__main__':
    summarize()
