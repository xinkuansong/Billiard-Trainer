#!/usr/bin/env python3
"""Independent CPU study of K8 field interpolation and half storage.

This is not a picture or an iOS performance test. The field stores high-grid
transport everywhere; the actual receiver still decides original near/far and
hemisphere fallback. Thus interpolation never blends incompatible 8/64 grids.
"""
import argparse
import hashlib
import json
from pathlib import Path
import time

import numpy as np
import study as s

EXTENT = np.array([1.27, .635])


def high_transport(p, balls):
    """Same near-grid visibility as study.transport, including support mask."""
    top = balls[:, 2] + s.R
    bound = s.R + top / np.maximum(.01, 2.2-top) * (
        np.linalg.norm(balls[:, :2], axis=1) + np.hypot(2.54, 1.27)
        + np.sqrt(5.08*1.27/32/s.PI))
    support = (((p[:, None, 0]-balls[None, :, 0])**2
                + (p[:, None, 2]-balls[None, :, 1])**2 <= bound**2)
               | (top[None, :] >= 2.2)) & (balls[None, :, 3] > 0)
    delta = s.light_grid(8, 4)[None, :, :] - p[:, None, :]
    r2 = (delta*delta).sum(axis=2)
    light = delta / np.sqrt(r2[:, :, None])
    area = 5.08*1.27/32
    weight = np.maximum(0, light[:, :, 1])/r2 * area*s.RADIANCE/s.PI
    visibility = np.ones_like(weight)
    mask = support | ((p[:, None, 1] < s.BED) & (balls[None, :, 3] > 0))
    for k, ball in enumerate(balls):
        if ball[3] <= 0:
            continue
        d = np.array([ball[0], s.BED+ball[2], ball[1]]) - p
        t = (d[:, None, :]*light).sum(axis=2)
        perpendicular2 = (d*d).sum(axis=1)[:, None]-t*t
        radius = np.maximum(1e-6, np.sqrt(area/s.PI)*t/np.sqrt(r2))
        u = np.clip((np.sqrt(np.maximum(0, perpendicular2))-(s.R-radius))/(2*radius), 0, 1)
        blocked = 1-u*u*(3-2*u)
        valid = (t > 0) & (t*t < r2) & mask[:, k, None]
        visibility *= 1-np.where(valid, min(1, ball[3]/.85)*blocked, 0)
    return light, weight, visibility


def point_moments(p, balls):
    light, weight, visibility = high_transport(p, balls)
    vectors = (weight*visibility)[:, :, None]*light
    shaped = vectors.reshape(-1, 2, 8, 4, 3)
    groups = np.stack([shaped[:, panel, x*2:x*2+2, z*2:z*2+2].sum(axis=(1, 2))
                       for panel in range(2) for x in range(4) for z in range(2)], axis=1)
    return np.concatenate((vectors.sum(axis=1)[:, None, :],
                           (weight[:, :, None]*light).sum(axis=1)[:, None, :], groups), axis=1)


def make_field(width, height, balls):
    xx, zz = np.meshgrid(np.linspace(-EXTENT[0], EXTENT[0], width),
                         np.linspace(-EXTENT[1], EXTENT[1], height))
    points = np.column_stack((xx.ravel(), np.full(xx.size, s.BED), zz.ravel()))
    out = np.empty((len(points), 18, 3), dtype=np.float32)
    for start in range(0, len(points), 2048):
        out[start:start+2048] = point_moments(points[start:start+2048], balls)
    return out.reshape(height, width, 18, 3)


def interpolate(field, p):
    height, width = field.shape[:2]
    coord = (p[:, [0, 2]]+EXTENT)/(2*EXTENT)*[width-1, height-1]
    coord = np.clip(coord, 0, [width-1, height-1])
    lower = np.floor(coord).astype(int)
    upper = np.minimum(lower+1, [width-1, height-1])
    t = coord-lower
    x, y = lower.T
    u, v = upper.T
    a, b = t[:, 0, None, None], t[:, 1, None, None]
    return ((1-b)*((1-a)*field[y, x]+a*field[y, u])
            + b*((1-a)*field[v, x]+a*field[v, u]))


def consume(moments, n, v, rough):
    groups = moments[:, 2:]
    spec = (np.maximum(0, (n[:, None, :]*groups).sum(axis=2))
            * s.brdf(n, v, rough, s.unit(groups))).sum(axis=1)
    num = (n*moments[:, 0]).sum(axis=1)
    den = (n*moments[:, 1]).sum(axis=1)
    ratio = (num[:, None]*s.COLOR) / np.maximum(den[:, None]*s.COLOR, 1e-6)
    return ratio, spec


def describe(ref, actual, mask):
    return s.metrics(ref[mask], actual[mask]) if mask.any() else {'receiver_count': 0}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--study', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--widths', type=int, nargs='+', default=[128, 256, 512])
    parser.add_argument('--cases', nargs='+', default=['single', 'rack', 'scatter', 'overlap_shadow', 'edge_height_opacity'])
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=False)
    report = {'scope': 'CPU numerical field study; raw paired texture domain, not actual final material normals or visible pixels; no performance claim',
              'domainXZ': [-1.27, 1.27, -.635, .635], 'bedY': s.BED,
              'grid': 'endpoint nodes; equivalent GPU normalized UV=(positionIndex+.5)/size',
              'field_layout': '18 RGB vectors; proposed GPU RGBA16F layers MV,M0,16 grouped moments',
              'candidate': 'K8 per lamp; near and hemisphere guards evaluated at receiver, outside field uses original',
              'sourceSHA256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), 'rows': []}
    for name in args.cases:
        case = args.study/(name+'_texture_pairs')
        samples = np.fromfile(case/'samples.bin', dtype='<f4').reshape(-1, 12).astype(float)
        balls = np.fromfile(case/'balls.bin', dtype='<f4').reshape(-1, 4).astype(float)
        p, n, v, rough = samples[:, :3], s.unit(samples[:, 4:7]), s.unit(samples[:, 8:11]), samples[:, 11]
        E0, E, S, transport = s.reference(p, n, v, rough, balls)
        _, _, pointS, use, _, _, _, _ = s.candidate(p, n, v, rough, transport, 4, 2)
        ratio = E[:, None]*s.COLOR/np.maximum(E0[:, None]*s.COLOR, 1e-6)
        inside = (np.abs(p[:, [0, 2]]) <= EXTENT).all(axis=1)
        use &= inside
        direct = point_moments(p, balls)
        directRatio, directS = consume(direct, n, v, rough)
        if use.any() and np.max(np.abs(directS[use]-pointS[use])) > 1e-10:
            raise AssertionError('Independent forced-high-grid differs on actual near receivers')
        reference = np.fromfile(case/'reference.bin', dtype='<f4').reshape(-1, 16)
        proxy = reference[:, 8:11]*[.02, .16, .004] / s.PI + .35*reference[:, 12:15]
        for width in args.widths:
            height = width//2
            started = time.monotonic()
            field = make_field(width, height, balls)
            # Expose exact corner reproduction, ruling out a half-texel indexing error.
            corners = np.array([[-EXTENT[0], s.BED, -EXTENT[1]], [EXTENT[0], s.BED, EXTENT[1]]])
            assert np.array_equal(interpolate(field, corners), np.stack([field[0, 0], field[-1, -1]]))
            for precision in ['float32', 'float16']:
                quantized = field if precision == 'float32' else field.astype(np.float16).astype(np.float32)
                moments = interpolate(quantized, p)
                cratio, cs = consume(moments, n, v, rough)
                cratio = np.where(use[:, None], cratio, ratio)
                cs = np.where(use, cs, S)
                corrected = reference[:, 8:11]*cratio/np.maximum(ratio, 1e-12)
                cproxy = corrected*[.02, .16, .004]/s.PI + .35*cs[:, None]*s.COLOR
                row = {'case': name, 'width': width, 'height': height, 'precision': precision,
                       'candidate_receivers': int(use.sum()), 'outside_field': int((~inside).sum()),
                       'field_bytes_RGBA': width*height*18*4*(2 if precision == 'float16' else 4),
                       'vs_R_ratio': describe(ratio, cratio, use), 'vs_R_specular': describe(S, cs, use),
                       'vs_point_K8_ratio': describe(directRatio, cratio, use),
                       'vs_point_K8_specular': describe(directS, cs, use),
                       'changed_terms_proxy': describe(proxy, cproxy, use)}
                report['rows'].append(row)
                np.savez_compressed(args.out/f'{name}-{width}-{precision}.npz', ratio=cratio, S=cs, use=use, proxy=cproxy)
                print(name, width, precision, 'ratio max', row['vs_R_ratio']['abs_max'],
                      'S max', row['vs_R_specular']['abs_max'], flush=True)
            # Compact compressed field enables independent native readback comparison.
            np.savez_compressed(args.out/f'{name}-{width}-field.npz', field=field)
            print('field wall seconds (CPU diagnostic only)', time.monotonic()-started, flush=True)
            (args.out/'results.json').write_text(json.dumps(report, indent=2)+'\n')
    print(args.out/'results.json')


if __name__ == '__main__':
    main()
