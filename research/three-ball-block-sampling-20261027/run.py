"""Thin the five completed three-ball samples; never rerun or modify physics."""
from pathlib import Path
from collections import defaultdict
import copy
import hashlib
import json
import random
import shutil

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
PARENT = ROOT / 'output/three-ball-middle-filter-20261027'
OUT = ROOT / 'output' / HERE.name
SEED = 'second-nonempty-2x2-preview-20261025-v1'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def block(cid):
    return (cid // 12 // 2) * 6 + (cid % 12 // 2)


def choose(identity, bid, candidates):
    digest = hashlib.sha256((SEED + '\0' + identity + '\0' + str(bid)).encode()).digest()
    return random.Random(int.from_bytes(digest, 'big')).choice(sorted(candidates, key=lambda c: c['id']))


def write(name, value):
    (OUT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sources = ['viewer-data.json', 'audit.json', 'flow-audit.json', 'filter.json', 'completion.json']
    hashes = {name: sha(PARENT / name) for name in sources}
    parent = json.loads((PARENT / 'viewer-data.json').read_text())
    data = copy.deepcopy(parent)
    summaries, selections = [], []
    for d, original in zip(data['samples'], parent['samples']):
        sample = d['sample']
        # A three-ball base includes the original layout AND its fixed second-ball cell.
        identity = sample['id'] + '/second-cell:' + str(sample['cellID'])
        groups = defaultdict(list)
        for c in d['candidates']:
            if c['chains']:
                assert c['status'] == 'validated'
                groups[block(c['id'])].append(c)
        draws = [dict(blockID=b, availableCellIDs=sorted(c['id'] for c in cs),
                      chosenCellID=choose(identity, b, cs)['id']) for b, cs in sorted(groups.items())]
        picked = {draw['chosenCellID'] for draw in draws}
        for c in d['candidates']:
            c['blockID'] = block(c['id'])
            c['sampled'] = c['id'] in picked
        d['sampling'] = dict(identity=identity, before=len([c for c in d['candidates'] if c['chains']]),
                             after=len(picked), chains=sum(len(c['chains']) for c in d['candidates'] if c['sampled']),
                             selectedCellIDs=sorted(picked), draws=draws)
        summaries.append(dict(sample=sample['number'], **d['sampling']))
        selections.append(dict(sample=copy.deepcopy(sample), positions=[copy.deepcopy(c) for c in original['candidates'] if c['id'] in picked]))

        # Independent row/column enumeration checks coverage, empty and singleton blocks.
        for row in range(0, 6, 2):
            for col in range(0, 12, 2):
                cells = {r * 12 + x for r in (row, row + 1) for x in (col, col + 1)}
                eligible = [c for c in original['candidates'] if c['id'] in cells and c['chains']]
                retained = [c for c in selections[-1]['positions'] if c['id'] in cells]
                assert len(retained) == bool(eligible)
                if len(eligible) == 1:
                    assert retained == eligible
        assert len(picked) <= 18
        assert d['sample'] == original['sample'] and d['regions'] == original['regions']
        for c, old in zip(d['candidates'], original['candidates']):
            assert {k: v for k, v in c.items() if k not in ('sampled', 'blockID')} == old
            x, z = c['position']
            g = data['geometry']
            col = int((x + g['length'] / 2 - g['radius']) / ((g['length'] - 2 * g['radius']) / 12))
            row = int((z + g['width'] / 2 - g['radius']) / ((g['width'] - 2 * g['radius']) / 6))
            assert row * 12 + col == c['id']
        assert picked == {choose(identity, b, cs)['id'] for b, cs in reversed(list(groups.items()))}
    data['sampling'] = dict(seed=SEED, stage='after complete three-shot validation; union across second pockets, once per base',
                            before=sum(s['before'] for s in summaries), after=sum(s['after'] for s in summaries),
                            chains=sum(s['chains'] for s in summaries), sourceSHA256=hashes)
    write('viewer-data.json', data)
    write('selected-positions.json', selections)
    write('sampling.json', dict(policy=data['sampling'], samples=summaries))
    assert hashes == {name: sha(PARENT / name) for name in sources}
    write('sampling-audit.json', dict(passed=True, sourceUnchanged=True, sourceSHA256=hashes,
          coordinateCellsVerified=360, independentBlockChecks=90, singletonAndEmptyBlocksVerified=True,
          onePerNonemptyBlock=True, allOriginalCandidateFieldsPreserved=True, selectedCompleteChainsPreserved=True,
          deterministicAndTraversalIndependent=True, physicsRerun=False))
    for name in ['audit.json', 'flow-audit.json', 'filter.json']:
        shutil.copy2(PARENT / name, OUT / name)
    (OUT / 'index.html').write_text((HERE / 'viewer.html').read_text().replace('/*__DATA__*/', json.dumps(data, ensure_ascii=False, separators=(',', ':'), allow_nan=False)))
    print(json.dumps(dict(totals=data['sampling'], samples=[{k: s[k] for k in ('sample', 'before', 'after', 'chains')} for s in summaries]), ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
