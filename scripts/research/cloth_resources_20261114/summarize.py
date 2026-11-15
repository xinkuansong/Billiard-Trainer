"""Summarize H12 using cycle means and paired cycle deltas, without trimming."""
import argparse
import hashlib
import json
from pathlib import Path
import statistics


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('run_id')
    parser.add_argument('destination', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    run = root/'output/local-test-runs'/args.run_id
    assert json.loads((run/'run.json').read_text())['exit_code'] == 0
    raw = run/'evidence/results.json'
    rows = []
    for result in json.loads(raw.read_text()):
        row = {k: v for k, v in result.items() if k != 'times'}
        row['metrics'] = {}
        for metric in ['gpuMS', 'cpuEncodeMS', 'wallMS']:
            row['metrics'][metric] = {}
            for kind in ['AA', 'AB']:
                cycles = []
                for cycle in range(6):
                    arms = {arm: [v for t in result['times']
                                  if t['kind'] == kind and t['cycle'] == cycle and t['arm'] == arm
                                  for v in t[metric]] for arm in ['A', 'B']}
                    assert all(len(v) == 48 for v in arms.values())
                    a, b = (statistics.mean(arms[arm]) for arm in ['A', 'B'])
                    cycles.append({'cycle': cycle, 'A_ms': a, 'B_ms': b,
                                   'changePercent': (b/a-1)*100})
                row['metrics'][metric][kind] = {
                    'medianChangePercent': statistics.median(c['changePercent'] for c in cycles),
                    'meanA_ms': statistics.mean(c['A_ms'] for c in cycles),
                    'meanB_ms': statistics.mean(c['B_ms'] for c in cycles), 'cycles': cycles}
        row['visualGatePassed'] = row['maximumChannelDifference'] <= row['tolerance']
        rows.append(row)
    args.destination.write_text(json.dumps({
        'runID': args.run_id, 'resultsSHA256': hashlib.sha256(raw.read_bytes()).hexdigest(),
        'visualPairs': sum(len(r['comparisons']) for r in rows),
        'timing': '6 AA/AB groups, alternating ABBA/BAAB, 48 frames per arm per group; cycle means then median paired percent change; no discarded samples',
        'scope': 'Native diagnostic fixture, not phone or full App; consult round report for included objects',
        'rows': rows}, indent=2)+'\n')
    for row in rows:
        print(row['variant'], row['pose'], 'max', row['maximumChannelDifference'],
              {k: {kind: round(values['medianChangePercent'], 3) for kind, values in v.items()}
               for k, v in row['metrics'].items()})


if __name__ == '__main__':
    main()
