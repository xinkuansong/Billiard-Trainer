#!/usr/bin/env python3
"""Summarize all balanced H13 frames without trimming or selecting cycles."""
import argparse
import json
from pathlib import Path
import statistics as s

def distribution(values):
    if not values:
        return {'count': 0}
    ordered = sorted(values)
    return {'count': len(values), 'mean': s.mean(values), 'median': s.median(values),
            'p95': ordered[min(len(ordered)-1, int(.95*len(ordered)))],
            'min': min(values), 'max': max(values)}

def paired(slots, kind, metric):
    cycles = []
    for cycle in sorted({x['cycle'] for x in slots if x['kind'] == kind}):
        arms = {arm: [frame[metric] for slot in slots
                      if slot['kind'] == kind and slot['cycle'] == cycle and slot['arm'] == arm
                      for frame in slot['frames']] for arm in ('A', 'B')}
        assert len(arms['A']) == len(arms['B']) == 24
        a, b = s.mean(arms['A']), s.mean(arms['B'])
        cycles.append({'cycle': cycle, 'aMS': a, 'bMS': b,
                       'savedMS': a-b, 'savedPercent': 100*(a-b)/a})
    savings = [x['savedPercent'] for x in cycles]
    return {'cycles': cycles, 'meanA_MS': s.mean(x['aMS'] for x in cycles),
            'meanB_MS': s.mean(x['bMS'] for x in cycles),
            'meanSavedMS': s.mean(x['savedMS'] for x in cycles),
            'meanSavedPercent': s.mean(savings), 'rangeSavedPercent': [min(savings), max(savings)],
            'positiveCycles': sum(x > 0 for x in savings),
            'meanPercentCI95': [s.mean(savings)-2.571*s.stdev(savings)/len(savings)**.5,
                              s.mean(savings)+2.571*s.stdev(savings)/len(savings)**.5]}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('report', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    report = json.loads(args.report.read_text())
    result = {'source': str(args.report.resolve()), 'completed': report['completed'],
              'scope': report['scope'], 'inventory': report['inventory'], 'materials': [], 'cpu': []}
    for row in report['rows']:
        summary = {k: v for k,v in row.items() if k != 'times'}
        summary['metrics'] = {}
        if row['times']:
            for metric in ('gpuSpanMS', 'cpuEncodeMS', 'cpuWallMS'):
                summary['metrics'][metric] = {kind: paired(row['times'], kind, metric) for kind in ('AA', 'AB')}
            gpu = summary['metrics']['gpuSpanMS']
            print(f"{row['pose']:8} {row['group']:8} GPU {gpu['AB']['meanA_MS']:.3f} -> {gpu['AB']['meanB_MS']:.3f} ms; "
                  f"saved {gpu['AB']['meanSavedPercent']:+.2f}%; AA {gpu['AA']['meanSavedPercent']:+.2f}%")
        else:
            reason = 'quality rejected; not timed' if row.get('qualityPassed') is False else 'not visibly consumed'
            print(f"{row['pose']:8} {row['group']:8} {reason}; maximum image difference {row['maximumChannelDifference']}")
        result['materials'].append(summary)
    for row in report['cpuRows']:
        summary = {k:v for k,v in row.items() if k not in ('frames', 'callbacks', 'stableCameraUpdateMS', 'stableViewportUpdateMS')}
        for key in ('stableCameraUpdateMS', 'stableViewportUpdateMS'):
            if key in row:
                summary[key] = distribution(row[key])
        if 'frames' in row:
            summary['frames'] = {metric: distribution([x[metric] for x in row['frames']])
                                 for metric in ('gpuSpanMS', 'cpuEncodeMS', 'cpuWallMS')}
        if 'callbacks' in row:
            summary['callbacks'] = {k:distribution(v) for k,v in row['callbacks'].items()}
        result['cpu'].append(summary)
        print(json.dumps(summary, ensure_ascii=False))
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')

if __name__ == '__main__':
    main()
