"""Freeze one symmetry per existing question. No search, filtering or perturbation.

Coordinates: world X/Z metres. Reflection reverses axial side spin; rotation
does not. IDs remain source identities; the bank fingerprint versions layouts.
"""
from pathlib import Path
import collections
import copy
import hashlib
import json
import math

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'output/kick-bank-full-20261031'
OUT = ROOT / 'output/kick-bank-symmetry-20261101'
SOURCE_SHA = 'ab45e0387ca1669599d76cb0ea629d57fe2aee9d95c262dc6667271c7b360d66'
SEED = 'kick-symmetry-v1-20261101'
SIGNS = [(1, 1), (-1, 1), (1, -1), (-1, -1)]
NAMES = ['identity', 'mirrorX', 'mirrorZ', 'rotate180']


def digest(data):
    return hashlib.sha256(data).hexdigest()


def write(name, data):
    (OUT / name).write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n')


def wall(normal):
    x, z = normal
    return (0 if x > 0 else 1) if abs(x) > .9 else (2 if z > 0 else 3)


def maps(geometry, signs):
    sx, sz = signs
    result = []
    wall_map = {}
    for rail in geometry['rails']:
        points = sorted((sx*p[0], sz*p[1]) for p in [rail['start'], rail['end']])
        normal = [sx*rail['normal'][0], sz*rail['normal'][1]]
        matches = [r for r in geometry['rails'] if
                   sorted(tuple(p) for p in [r['start'], r['end']]) == points and r['normal'] == normal]
        assert len(matches) == 1
        result.append(matches[0]['id'])
        wall_map[wall(rail['normal'])] = wall(normal)
    assert sorted(result) == list(range(6))
    assert all(result[result[i]] == i for i in range(6))
    return result, [wall_map[i] for i in range(4)]


def transform(source, signs, wall_map):
    sx, sz = signs
    q = copy.deepcopy(source)
    for key in ['cue', 'target', 'direction']:
        q[key] = {'x': sx*source[key]['x'], 'z': sz*source[key]['z']}
    q['walls'] = [wall_map[w] for w in source['walls']]
    q['input']['spinX'] *= sx*sz
    return q


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    raw = (SOURCE / 'kick-practice-bank.json').read_bytes()
    assert digest(raw) == SOURCE_SHA
    bank = json.loads(raw)
    geometry = json.loads((SOURCE / 'geometry.json').read_text())
    index = json.loads((SOURCE / 'bank-index.json').read_text())
    by_id = {r['id']: r for r in index}
    mappings = [maps(geometry, signs) for signs in SIGNS]
    groups = collections.defaultdict(list)
    for q in bank['questions']:
        groups[(len(q['walls']), by_id[q['id']]['cell'])].append(q['id'])
    assignments, offset = {}, 0
    for key, ids in sorted(groups.items()):
        ids.sort(key=lambda id: digest((SEED + '/' + id).encode()))
        for i, id in enumerate(ids):
            assignments[id] = (offset+i) % 4
        offset += len(ids)
    transformed, provenance = [], []
    for q in bank['questions']:
        t = assignments[q['id']]
        rail_map, wall_map = mappings[t]
        new = transform(q, SIGNS[t], wall_map)
        assert transform(new, SIGNS[t], wall_map) == q, q['id']
        for key in ['cue', 'target']:
            assert abs(new[key]['x']) < geometry['length']/2 - geometry['radius']
            assert abs(new[key]['z']) < geometry['width']/2 - geometry['radius']
        assert math.hypot(new['direction']['x'], new['direction']['z']) == math.hypot(q['direction']['x'], q['direction']['z'])
        assert math.hypot(new['cue']['x']-new['target']['x'], new['cue']['z']-new['target']['z']) > 2*geometry['radius']
        assert new['input']['velocity'] == q['input']['velocity'] and new['input']['spinY'] == q['input']['spinY']
        row = dict(by_id[q['id']], transform=t, sourceSpinX=q['input']['spinX'],
                   velocity=q['input']['velocity'], rails=[rail_map[r] for r in by_id[q['id']]['rails']])
        transformed.append(new)
        provenance.append(row)
    assert len(transformed) == len({q['id'] for q in transformed}) == 53928
    assert collections.Counter(assignments.values()) == dict.fromkeys(range(4), 13482)
    for n in range(1, 5):
        counts = collections.Counter(r['transform'] for r in provenance if r['n'] == n)
        assert max(counts.values()) - min(counts.values()) <= 1
        for t in range(4):
            assert len({r['cell'] for r in provenance if r['n'] == n and r['transform'] == t}) == 72
    # Bounded coverage of input strata, every mirrored cell, first-rail identity,
    # and repeated-rail routes. Selection is independent of replay outcomes.
    selected, covered = [], set()
    for r in sorted(provenance, key=lambda r: digest(('sample/' + r['id']).encode())):
        keys = {('input', r['n'], r['transform'], r['sourceSpinX'], r['velocity']),
                ('cell', r['transform'], r['cell']),
                ('first', r['n'], r['transform'], r['rails'][0])}
        if len(set(r['rails'])) < len(r['rails']):
            keys.add(('repeat', r['n'], r['transform']))
        if keys - covered:
            selected.append(r)
            covered.update(keys)
    write('kick-practice-bank.json', dict(version=bank['version'], questions=transformed))
    write('bank-index.json', provenance)
    write('sample.json', selected)
    write('geometry.json', geometry)
    counts = {str(n): [sum(r['n'] == n and r['transform'] == t for r in provenance) for t in range(4)] for n in range(1, 5)}
    report = dict(sourceSHA256=SOURCE_SHA, bankSHA256=digest((OUT/'kick-practice-bank.json').read_bytes()),
                  total=len(transformed), seed=SEED, names=NAMES, perTransform=[13482]*4, perRail=counts,
                  perRailTransformCells=72, algebraChecked=53928, replaySampleCount=len(selected),
                  mappings=[dict(rails=r, walls=w) for r,w in mappings], generatorSHA256=digest(Path(__file__).read_bytes()))
    write('audit.json', report)
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
