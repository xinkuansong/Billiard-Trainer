#!/usr/bin/env python3
"""Build gate for the current solution-free bank; no legacy bank fallback."""
import hashlib
import json
import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# Layout compatibility is separate from the historical potting experiment.
# Keep these geometry sources pinned even when the runtime physics changes.
GEOMETRY_SOURCES = (
    'QiuJi/Core/Physics/TableGeometry.swift',
    'QiuJi/Core/Physics/TableGeometry+QiuJi.swift',
    'QiuJi/Core/Scene/AngleSceneCalculator.swift',
    'QiuJi/Core/Physics/DrillBoardBuilder.swift',
)
# Reviewed against the bank's original constants; expressions are checked, not
# evaluated as Python. Physics coefficients in the same Swift file are excluded.
GEOMETRY_CONSTANTS = {
    'diameter': '0.05715', 'radius': 'diameter / 2',
    'innerLength': '2.540', 'innerWidth': '1.270', 'height': '0.80',
    'cushionHeight': '0.037', 'cushionThickness': '0.05',
    'cornerPocketDiameter': '0.084',
    'cornerPocketRadius': 'cornerPocketDiameter / 2',
    'cornerPocketFilletRadius': '0.105', 'sidePocketDiameter': '0.086',
    'sidePocketRadius': 'sidePocketDiameter / 2',
    'sidePocketFilletRadius': '0.030', 'pocketDiameter': 'sidePocketDiameter',
    'cornerPocketCenterOffsetX': 'innerLength / 2 + cornerPocketRadius',
    'cornerPocketCenterOffsetZ': 'innerWidth / 2 + cornerPocketRadius',
    'sidePocketThroatJoinZ': '0.688', 'sidePocketNearRimZ': '0.63296474',
    'sidePocketCenterOffsetZ': 'sidePocketNearRimZ + sidePocketRadius',
}


def verify_geometry(manifest):
    for path in GEOMETRY_SOURCES:
        # A reviewed code-only extraction may rebind layout compatibility without
        # rewriting the historical physics evidence fingerprint.
        expected = manifest.get('layoutSourceHashes', {}).get(path, manifest['physicalSourceHashes'][path])
        assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == expected, f'Layout geometry changed: {path}; review bank compatibility'
    source = (ROOT / 'QiuJi/Core/Physics/BTPhysicsConstants.swift').read_text()
    source = re.sub(r'/\*.*?\*/', '', source, flags=re.S)
    source = re.sub(r'//[^\n]*', '', source)
    for name, expected in GEOMETRY_CONSTANTS.items():
        values = re.findall(r'\bstatic\s+let\s+' + name + r'\s*:\s*Float\s*=\s*([^\n]+)', source)
        assert len(values) == 1 and re.sub(r'\s+', '', values[0]) == re.sub(r'\s+', '', expected), f'Layout geometry constant changed: {name}; review bank compatibility'


def verify(require_current_physics=False):
    directory = ROOT / 'QiuJi/Resources'
    data = (directory / 'training-grid-bank.json').read_bytes()
    manifest = json.loads((directory / 'training-grid-bank-manifest.json').read_text())
    bank = json.loads(data)
    assert manifest['schema'] == bank['schema'] == 'layout-bank-grid-v2-combination-ids'
    assert hashlib.sha256(data).hexdigest() == manifest['contentSHA256'], 'Bank bytes changed'
    assert bank['counts'] == manifest['counts'] == {'corner': 580804, 'middle': 201724}
    assert manifest['qualification'] == {'corner': 'geometry-candidate', 'middle': 'center-direct-five-v4'}
    verify_geometry(manifest)
    changed = [path for path, digest in manifest['physicalSourceHashes'].items()
               if hashlib.sha256((ROOT / path).read_bytes()).hexdigest() != digest]
    assert not (directory / 'training-question-bank.json').exists(), 'Retired bank must not ship'
    assert not (directory / 'training-question-bank-manifest.json').exists(), 'Retired manifest must not ship'
    table = bank['combinationTable']
    assert len(table) == 270
    counts = [0] * 270
    for target in bank['targets']:
        assert len(target['masks']) == 171
        assert sum(bin(m).count('1') for m in target['masks']) == len(target['combinationIndices'])
        for code in target['combinationIndices']:
            assert 0 <= code < 270
            assert table[code]['pocketType'] == int(target['pocket'] >= 4)
            counts[code] += 1
    assert sum(counts) == 782528 and sum(n > 0 for n in counts) == 178
    forbidden = {'proof', 'trials', 'events', 'direction', 'velocity', 'centerSpeeds', 'trajectories'}
    def check(value):
        if isinstance(value, dict):
            assert not forbidden.intersection(value)
            for item in value.values(): check(item)
        elif isinstance(value, list):
            for item in value: check(item)
    check(bank)
    print('Grid bank integrity and layout geometry verified: 782528 layouts / 178 occupied combinations; no stored solutions.')
    if changed:
        message = 'Historical physics qualification is stale (not a layout failure): ' + ', '.join(changed)
        assert not require_current_physics, message + '; replay required before claiming current physics qualification'
        print('note: ' + message)
    else:
        print('Historical physics source fingerprint matches; no new physics replay performed.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-current-physics', action='store_true',
                        help='Also require the historical physics evidence to match current sources; does not replay shots')
    verify(parser.parse_args().require_current_physics)
