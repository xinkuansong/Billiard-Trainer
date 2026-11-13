#!/usr/bin/env python3
"""CPU-only independent native scene evidence validation and cross-host report.

Accept one or more --host LABEL=RESULTS. Raw evidence is never written. Reports
derive real frame quantiles from command records, not six-frame batch averages.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import statistics


def distribution(values):
    values = sorted(values)
    return {'n': len(values), 'p50': statistics.median(values),
            'p95': values[math.ceil(.95 * len(values)) - 1],
            'p99': values[math.ceil(.99 * len(values)) - 1], 'min': values[0], 'max': values[-1]}


def read(path):
    return json.loads(path.read_text())


def verify_host(label, directory):
    summary, driver, manifest = (read(directory / p) for p in ['result.json', 'driver.json', 'package-manifest.json'])
    if summary.get('passed') is not True or driver.get('status') != 'succeeded':
        raise ValueError('Host has no successful study: ' + label)
    if driver['packageID'] != manifest['packageID']:
        raise ValueError('Driver/package identity mismatch: ' + label)
    body = {k: v for k, v in manifest.items() if k != 'packageID'}
    if hashlib.sha256(json.dumps(body, sort_keys=True).encode()).hexdigest() != manifest['packageID']:
        raise ValueError('Package manifest identity is invalid: ' + label)
    calibration = read(directory / 'fill-calibration.json')
    if calibration['passed'] is not True:
        raise ValueError('Native timestamp workload calibration failed: ' + label)
    rows, checks = [], []
    for scene in read(directory / 'scene-results.json'):
        key = scene['id']
        ref = (directory / (key + '-reference.bgra8')).read_bytes()
        controls = ['repeat-reference', 'candidate', 'repeat-candidate', 'restored']
        if 'plain-safe' in manifest.get('comparisonArms', []):
            controls += ['plain-safe', 'repeat-plain-safe']
        if len(ref) != scene['width'] * scene['height'] * 4:
            raise ValueError('Unexpected image byte count: ' + key)
        for suffix in controls:
            if (directory / (key + '-' + suffix + '.bgra8')).read_bytes() != ref:
                raise ValueError('Control does not match original: ' + key + '/' + suffix)
        if (directory / (key + '-red-control.bgra8')).read_bytes() == ref:
            raise ValueError('Red control did not execute: ' + key)
        if not all(n > 0 for n in scene['bytes'].values()):
            raise ValueError('Native allocation accounting unavailable: ' + key)
        raw = read(directory / (key + '-raw-timings.json'))
        for batch in raw:
            batch.setdefault('pair', 'reference_vs_candidate')
            if batch['sameTargetBitwiseExact'] is not True or len(batch['frames']) != 6:
                raise ValueError('Measured target/frame contract failed: ' + key)
            for frame in batch['frames']:
                if not (math.isfinite(frame['gpuMS']) and frame['gpuEndTime'] > frame['gpuStartTime'] > 0 and frame['gpuMS'] > 0):
                    raise ValueError('GPU timestamps unavailable: ' + key)
        for pair in sorted({batch['pair'] for batch in raw}):
            first, second = pair.split('_vs_')
            pair_raw = [b for b in raw if b['pair'] == pair]
            if len(pair_raw) != 36:
                raise ValueError('Expected nine four-slot cycles: ' + key + '/' + pair)
            pair_cycles = []
            for cycle in range(9):
                batches = [b for b in pair_raw if b['cycle'] == cycle]
                order = [b['mode'] for b in batches]
                if order not in [[first, second, second, first], [second, first, first, second]]:
                    raise ValueError('Invalid paired order: ' + key + '/' + pair)
                means = {arm: [statistics.mean(f['gpuMS'] for f in b['frames']) for b in batches if b['mode'] == arm]
                         for arm in [first, second]}
                ma, mb = (statistics.median(means[arm]) for arm in [first, second])
                pair_cycles.append({'cycle': cycle, 'order': order, 'firstMeansMS': means[first],
                    'secondMeansMS': means[second], 'changePercent': (mb / ma - 1) * 100,
                    'firstEndpointDriftPercent': abs(means[first][1] - means[first][0]) / ma * 100,
                    'secondEndpointDriftPercent': abs(means[second][1] - means[second][0]) / mb * 100})
            changes = [c['changePercent'] for c in pair_cycles]
            row = {'host': label, 'scene': key, 'pair': pair, 'pairedMedianPercent': statistics.median(changes),
                   'pairedRangePercent': [min(changes), max(changes)], 'negativeCycles': sum(c < 0 for c in changes),
                   'worstEndpointDriftPercent': max(max(c['firstEndpointDriftPercent'], c['secondEndpointDriftPercent']) for c in pair_cycles),
                   'cycles': pair_cycles, 'allocatedBytes': scene['bytes'], 'arms': {}}
            for arm in [first, second]:
                frames = [f for b in pair_raw if b['mode'] == arm for f in b['frames']]
                if len(frames) != 108:
                    raise ValueError('Expected 108 actual render frames per pair arm')
                row['arms'][arm] = {name: distribution([f[name] for f in frames]) for name in
                    ['gpuMS', 'cpuEncodeMS', 'renderSyncWallMS', 'fullSyncWallIncludingSentinelMS']}
            rows.append(row)
        checks.append({'scene': key, 'controlsBitwiseExact': controls, 'redControlChanged': True,
                       'lastTargetChecks': len(raw), 'measuredFrames': sum(len(b['frames']) for b in raw),
                       'allGPUPositive': True, 'allExplicitAllocatedBytesPositive': True})
    return {'label': label, 'directory': str(directory), 'device': summary['device'], 'os': summary['os'],
            'packageID': manifest['packageID'], 'candidate': summary['candidate'],
            'fillHeavyLightRatio': calibration['medianHeavyLightRatio'], 'checks': checks, 'rows': rows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', action='append', required=True, help='LABEL=raw-results-directory')
    parser.add_argument('--out', type=Path, required=True, help='New independent report directory')
    args = parser.parse_args()
    results = []
    for item in args.host:
        label, directory = item.split('=', 1)
        results.append(verify_host(label, Path(directory).resolve()))
    identities = {x['packageID'] for x in results}
    if len(identities) != 1:
        raise ValueError('Cross-host report requires the same exact frozen package')
    args.out.mkdir(parents=True, exist_ok=False)
    report = {'passed': True, 'samePackageID': next(iter(identities)),
              'scope': 'Native isolated actual cloth SceneKit, independent synchronized offscreen render commands; not full App, presented pacing, iPhone, or sustained thermal acceptance',
              'quantiles': 'P50 median; P95/P99 nearest rank from 108 actual per-frame GPU spans per pair/arm. Not quantiles of batch means.',
              'hosts': results}
    (args.out / 'comparison.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    lines = ['# Native SceneKit matched-package comparison', '', report['scope'], '',
             'Package: `' + report['samePackageID'] + '`.', '',
             'Each pair has nine ABBA/BAAB cycles. Every arm has 108 independently committed/waited measured render frames. All distributions below are recomputed from raw frames. No outlier is removed.', '',
             '| Host / scene | Pair | Paired median | Nine-cycle range | Negative cycles | Worst endpoint drift |',
             '|---|---|---:|---:|---:|---:|']
    rows = [row for host in results for row in host['rows']]
    for row in rows:
        lo, hi = row['pairedRangePercent']
        lines.append(f"| {row['host']} / {row['scene']} | {row['pair']} | {row['pairedMedianPercent']:+.2f}% | {lo:+.2f}% … {hi:+.2f}% | {row['negativeCycles']}/9 | {row['worstEndpointDriftPercent']:.2f}% |")
    lines += ['', '## Actual command-frame distributions', '', report['quantiles'], '',
              'Every entry below is one synchronized offscreen render. These tail quantiles do not establish presented-frame stability.', '',
              '| Host / scene / pair / arm | n | GPU P50/P95/P99 ms | CPU encode P50/P95/P99 ms | Render sync wall P50/P95/P99 ms | Full sync wall P50/P95/P99 ms |',
              '|---|---:|---:|---:|---:|---:|']
    fmt = lambda d: f"{d['p50']:.4f}/{d['p95']:.4f}/{d['p99']:.4f}"
    for row in rows:
        for arm, values in row['arms'].items():
            lines.append(f"| {row['host']} / {row['scene']} / {row['pair']} / {arm} | {values['gpuMS']['n']} | {fmt(values['gpuMS'])} | {fmt(values['cpuEncodeMS'])} | {fmt(values['renderSyncWallMS'])} | {fmt(values['fullSyncWallIncludingSentinelMS'])} |")
    lines += ['', '## Explicit target allocations', '',
              'Actual allocatedSize for resolve/MSAA4/depth-stencil4/shared readback only; not total GPU memory. SceneKit internal HDR textures, loaded assets and driver caches are excluded.', '',
              '| Host / scene | Resolve B | MSAA4 B | Depth/stencil4 B | Readback B | Total B |',
              '|---|---:|---:|---:|---:|---:|']
    seen = set()
    for row in rows:
        key = (row['host'], row['scene'])
        if key in seen:
            continue
        seen.add(key); b = row['allocatedBytes']
        lines.append(f"| {row['host']} / {row['scene']} | {b['resolve']} | {b['MSAA4']} | {b['depthStencil4']} | {b['staging']} | {b['totalExplicitTarget']} |")
    lines += ['', 'Host device/OS, calibration ratios, all per-cycle samples, exact image-control verification and frame counts are retained in comparison.json. Raw evidence was read only.']
    (args.out / 'REPORT.md').write_text('\n'.join(lines) + '\n')
    print(json.dumps({'passed': True, 'hosts': len(results), 'pairRows': len(rows), 'report': str(args.out / 'REPORT.md')}))


if __name__ == '__main__':
    main()
