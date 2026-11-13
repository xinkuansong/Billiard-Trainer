#!/usr/bin/env python3
"""Local shadow-support tiles: numerical alternative to a uniform world field.

Each tile stores transport from ALL balls; it is not a per-ball shadow multiplied
after grouping. Selection is deterministic and uses the smallest containing tile.
This study measures errors and storage only, not GPU lookup/generation cost.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import spatial_study as field
import study as s


def radii(balls):
    top = balls[:, 2]+s.R
    return s.R+top/np.maximum(.01, 2.2-top)*(
        np.linalg.norm(balls[:, :2], axis=1)+np.hypot(2.54, 1.27)
        + np.sqrt(5.08*1.27/32/s.PI))


def local_sample(points, balls, resolution):
    active = balls[balls[:, 3] > 0]
    radius = radii(active)
    # Normal-height/raised test fixtures have bounded finite support. No claim for
    # a ball at/above the light: that state must use the exact renderer instead.
    assert np.all(active[:, 2]+s.R < 2.2)
    chosen = np.full(len(points), -1)
    best = np.full(len(points), np.inf)
    for index, (ball, extent) in enumerate(zip(active, radius)):
        inside = (np.abs(points[:, [0, 2]]-ball[:2]) <= extent).all(axis=1)
        select = inside & (extent < best)
        chosen[select] = index
        best[select] = extent
    result = np.zeros((len(points), 18, 3))
    for index, (ball, extent) in enumerate(zip(active, radius)):
        xx, zz = np.meshgrid(np.linspace(-extent, extent, resolution)+ball[0],
                             np.linspace(-extent, extent, resolution)+ball[1])
        grid_points = np.column_stack((xx.ravel(), np.full(xx.size, s.BED), zz.ravel()))
        moments = np.empty((len(grid_points), 18, 3), dtype=np.float32)
        for start in range(0, len(grid_points), 2048):
            moments[start:start+2048] = field.point_moments(grid_points[start:start+2048], balls)
        grid = moments.astype(np.float16).astype(np.float32).reshape(resolution, resolution, 18, 3)
        take = chosen == index
        if not take.any():
            continue
        coords = (points[take][:, [0, 2]]-ball[:2]+extent)/(2*extent)*(resolution-1)
        lo = np.floor(coords).astype(int)
        hi = np.minimum(lo+1, resolution-1)
        t = coords-lo
        x, z = lo.T
        u, v = hi.T
        a, b = t[:, 0, None, None], t[:, 1, None, None]
        result[take] = (1-b)*((1-a)*grid[z, x]+a*grid[z, u])+b*((1-a)*grid[v, x]+a*grid[v, u])
    return result, chosen, radius


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--study', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=False)
    report = {'scope': 'CPU local K8 field and FP16 interpolation only, not GPU or final pixels',
              'sourceSHA256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'tileSelection': 'smallest containing square support; original sphere mask still decides near',
              'rows': []}
    for name in ['single', 'rack', 'scatter', 'overlap_shadow', 'edge_height_opacity']:
        case = args.study/(name+'_texture_pairs')
        samples = np.fromfile(case/'samples.bin', '<f4').reshape(-1, 12).astype(float)
        balls = np.fromfile(case/'balls.bin', '<f4').reshape(-1, 4).astype(float)
        p, n, v, rough = samples[:, :3], s.unit(samples[:, 4:7]), s.unit(samples[:, 8:11]), samples[:, 11]
        E0, E, S, transport = s.reference(p, n, v, rough, balls)
        _, _, _, use, _, _, _, _ = s.candidate(p, n, v, rough, transport, 4, 2)
        use &= (np.abs(p[:, [0, 2]]) <= field.EXTENT).all(axis=1)
        ratio = E[:, None]*s.COLOR/np.maximum(E0[:, None]*s.COLOR, 1e-6)
        directRatio, directS = field.consume(field.point_moments(p, balls), n, v, rough)
        ref = np.fromfile(case/'reference.bin', '<f4').reshape(-1, 16)
        proxy = ref[:, 8:11]*[.02, .16, .004]/s.PI+.35*ref[:, 12:15]
        for resolution in [32, 48, 64]:
            moments, chosen, support = local_sample(p, balls, resolution)
            assert np.all(chosen[use] >= 0), 'Near receiver has no support tile'
            cratio, cs = field.consume(moments, n, v, rough)
            cratio = np.where(use[:, None], cratio, ratio)
            cs = np.where(use, cs, S)
            corrected = ref[:, 8:11]*cratio/np.maximum(ratio, 1e-12)
            cproxy = corrected*[.02, .16, .004]/s.PI+.35*cs[:, None]*s.COLOR
            # Distances are a diagnostic subset, not a camera visibility mask.
            outside_ball_disk = np.linalg.norm(p[:, None, [0, 2]]-balls[None, balls[:, 3] > 0, :2], axis=2).min(axis=1) >= s.R
            row = {'case': name, 'tileResolution': resolution, 'activeBalls': len(support),
                   'fieldBytesRGBA16F': len(support)*resolution*resolution*18*8,
                   'candidateReceivers': int(use.sum()),
                   'texelSpacingMM': (2*support/(resolution-1)*1000).tolist(),
                   'vs_R_ratio': field.describe(ratio, cratio, use),
                   'outside_ball_disk_ratio': field.describe(ratio, cratio, use & outside_ball_disk),
                   'vs_R_specular': field.describe(S, cs, use),
                   'vs_point_K8_specular': field.describe(directS, cs, use),
                   'vs_point_K8_ratio': field.describe(directRatio, cratio, use),
                   'changed_terms_proxy': field.describe(proxy, cproxy, use)}
            report['rows'].append(row)
            np.savez_compressed(args.out/f'{name}-{resolution}.npz', ratio=cratio, S=cs, use=use, chosen=chosen, proxy=cproxy)
            print(name, resolution, 'ratio p95/max', row['vs_R_ratio']['abs_p95'], row['vs_R_ratio']['abs_max'],
                  'MiB', row['fieldBytesRGBA16F']/1048576, flush=True)
            (args.out/'results.json').write_text(json.dumps(report, indent=2)+'\n')
    print(args.out/'results.json')


if __name__ == '__main__':
    main()
