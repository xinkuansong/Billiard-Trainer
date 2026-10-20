#!/usr/bin/env python3
"""Build gate for the current solution-free bank; no legacy bank fallback."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def verify():
    directory = ROOT / 'QiuJi/Resources'
    data = (directory / 'training-grid-bank.json').read_bytes()
    manifest = json.loads((directory / 'training-grid-bank-manifest.json').read_text())
    bank = json.loads(data)
    assert manifest['schema'] == bank['schema'] == 'layout-bank-grid-v2-combination-ids'
    assert hashlib.sha256(data).hexdigest() == manifest['contentSHA256'], 'Bank bytes changed'
    assert bank['counts'] == manifest['counts'] == {'corner': 580804, 'middle': 201724}
    assert manifest['qualification'] == {'corner': 'geometry-candidate', 'middle': 'center-direct-five-v4'}
    for path, digest in manifest['physicalSourceHashes'].items():
        assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest, f'Physics/geometry changed: {path}; revalidation required'
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
    print('Current grid bank verified: 782528 layouts / 178 occupied combinations; corners geometry-only, middle center-direct-five-v4; no stored solutions.')


if __name__ == '__main__':
    verify()
