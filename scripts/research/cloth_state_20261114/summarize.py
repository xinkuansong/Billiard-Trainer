"""Read a completed H11 run; preserve every cycle and cost component."""
from pathlib import Path
import argparse
import hashlib
import json
import statistics


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('run_id')
    parser.add_argument('destination', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    run = root/'output/local-test-runs'/args.run_id
    evidence = run/'evidence'
    raw = evidence/'results.json'
    assert hashlib.sha256((evidence/'baseline.surface').read_bytes()).hexdigest() == '14a880284fffc793f01d0357b0a625559101609d7986c9ac0cac72e7085efa4f'
    assert json.loads((run/'run.json').read_text())['exit_code'] == 0
    rows = []
    for result in json.loads(raw.read_text()):
        row = {k: v for k, v in result.items() if k != 'times'}
        row['metrics'] = {}
        if result['times']:
            for metric in ['gpuMS', 'statePrepareMS', 'stateUploadMS', 'stateTotalMS', 'cpuEncodeMS', 'wallMS']:
                row['metrics'][metric] = {}
                for kind in ['AA', 'AB']:
                    cycles = []
                    for cycle in range(6):
                        arms = {arm: [v for t in result['times']
                                      if t['kind'] == kind and t['cycle'] == cycle and t['arm'] == arm
                                      for v in t[metric]] for arm in ['A', 'B']}
                        assert all(len(v) == 48 for v in arms.values())
                        a, b = (statistics.mean(arms[arm]) for arm in ['A', 'B'])
                        cycles.append({'cycle': cycle, 'A_ms': a, 'B_ms': b, 'changePercent': (b/a-1)*100})
                    row['metrics'][metric][kind] = {
                        'medianChangePercent': statistics.median(c['changePercent'] for c in cycles),
                        'meanA_ms': statistics.mean(c['A_ms'] for c in cycles),
                        'meanB_ms': statistics.mean(c['B_ms'] for c in cycles), 'cycles': cycles}
            gpu, wall = (row['metrics'][k] for k in ['gpuMS', 'wallMS'])
            threshold = max(5 if row['pose'] == 'single-near' else 3, abs(gpu['AA']['medianChangePercent']))
            change = gpu['AB']['medianChangePercent']
            row['gpuGatePassed'] = -change > threshold if row['pose'] == 'single-near' else change <= threshold
            row['wallGatePassed'] = wall['AB']['medianChangePercent'] <= max(3, abs(wall['AA']['medianChangePercent']))
        rows.append(row)
    args.destination.write_text(json.dumps({'runID': args.run_id,
        'resultsSHA256': hashlib.sha256(raw.read_bytes()).hexdigest(),
        'visualPairs': sum(len(r['comparisons']) for r in rows),
        'timing': '6 AA/AB groups, alternating ABBA/BAAB, 48 frames per arm per group, no discarded samples',
        'scope': 'Native imported table and cloth, no ball geometry/room/UI/phone; wall includes state preparation and synchronous frame sentinel',
        'rows': rows}, indent=2)+'\n')
    for row in rows:
        print(row['variant'], row['pose'], 'max', row['maximumChannelDifference'],
              {k: round(v['AB']['medianChangePercent'], 3) for k,v in row['metrics'].items()})


if __name__ == '__main__':
    main()
