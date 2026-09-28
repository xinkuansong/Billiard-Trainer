#!/usr/bin/env python3
"""Summarize interleaved A/R/S/RS diagnostics; never infer power or GPU utilization.
Usage: python3 scripts/research/analyze_specialized_render.py INPUT_DIR --output FILE
The MTKView harness records command-buffer spans, not hardware busy time or presentation.
"""
import argparse
import json
from pathlib import Path
from statistics import mean, median

ORDER = ['A', 'R', 'A', 'S', 'A', 'RS', 'A', 'RS', 'A', 'S', 'A', 'R', 'A']


def summarize(root, order=ORDER):
    if (len(order) < 3 or len(order) % 2 == 0
            or any(profile != 'A' for profile in order[::2])
            or any(profile not in ('R', 'S', 'RS') for profile in order[1::2])):
        raise ValueError('Order must bracket every R/S/RS candidate with A baselines')
    result = {'measurement': 'GPU command-buffer span; not GPU busy/utilization/power',
              'workload': 'fixed production board, forced continuous MTKView; not full UI', 'modes': {}}
    for mode in [2, 3]:
        reports = []
        for index, profile in enumerate(order):
            path = root / f'ab-specialized-{mode}d-{index}-{profile}.json'
            if not path.exists():
                reports.append(None)
                continue
            raw = json.loads(path.read_text())
            frames = raw['frames']
            valid = [f['gpuMS'] for f in frames if f.get('error', 0) == 0 and f.get('gpuMS', 0) > 0]
            reasons = []
            if len(valid) != len(frames) or len(valid) <= 10:
                reasons.append('missing/invalid GPU samples')
            if raw['thermalStart'] != 0 or raw['thermal'] != 0:
                reasons.append('non-nominal thermal state')
            if raw['sampleCount'] != 4 or raw['requestedFPS'] != 60 or raw['cameraMoves']:
                reasons.append('mismatched workload')
            reports.append({'profile': profile, 'source': str(path), 'samples': len(valid),
                            'width': raw['width'], 'height': raw['height'], 'device': raw['gpuDevice'],
                            'medianMS': median(valid) if valid else None,
                            'meanMS': mean(valid) if valid else None,
                            'p95MS': sorted(valid)[min(len(valid)-1, int(len(valid)*.95))] if valid else None,
                            'invalidReasons': reasons})
        pairs = []
        for index in range(1, len(order), 2):
            before, candidate, after = reports[index-1:index+2]
            reasons = []
            if any(row is None for row in [before, candidate, after]):
                pairs.append({'index': index, 'profile': order[index], 'valid': False, 'reasons': ['missing segment']})
                continue
            reasons.extend(reason for row in [before, candidate, after] for reason in row['invalidReasons'])
            if len({(row['width'], row['height'], row['device']) for row in [before, candidate, after]}) != 1:
                reasons.append('different device/dimensions')
            values = [row['medianMS'] for row in [before, candidate, after]]
            base = (values[0]+values[2])/2 if values[0] and values[2] else None
            drift = abs(values[0]-values[2])/base if base else None
            if drift is None or drift > .05:
                reasons.append('baseline drift >5% or unavailable')
            pairs.append({'index': index, 'profile': order[index], 'valid': not reasons,
                          'reasons': reasons, 'baselineDrift': drift,
                          'spanReduction': 1-values[1]/base if not reasons else None})
        candidates = {}
        for profile in ['R', 'S', 'RS']:
            valid = [p['spanReduction'] for p in pairs if p['profile'] == profile and p['valid']]
            candidates[profile] = {'validPairs': len(valid), 'medianSpanReduction': median(valid) if len(valid) >= 2 else None}
        result['modes'][str(mode)] = {'segments': reports, 'pairs': pairs, 'candidates': candidates}
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--order', default=','.join(ORDER), help='Comma-separated bracketed profiles, e.g. A,S,A,S,A')
    args = parser.parse_args()
    args.output.write_text(json.dumps(summarize(args.input, args.order.split(',')), indent=2))
