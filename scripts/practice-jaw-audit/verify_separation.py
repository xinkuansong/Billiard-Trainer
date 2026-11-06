"""Match every runtime result to its expected grid ID, exact RNG seed and spin mask."""
from collections import Counter
from pathlib import Path
import hashlib
import json
import sys

def verify(work, partial=False):
    source = (work/'Runner.app/training-grid-bank.json').read_bytes()
    stamp = json.loads((work/'rows/snapshot').read_bytes())
    assert hashlib.sha256(source).hexdigest() == stamp['training-grid-bank.json']
    grid = json.loads(source)
    pools = [[] for _ in grid['combinationTable']]
    for i, target in enumerate(grid['targets']):
        codes = iter(target['combinationIndices'])
        for mask_id, mask in enumerate(target['masks']):
            for bit in range(len(grid['distanceSamples'])):
                if mask & (1 << bit):
                    pools[next(codes)].append((i << 12) | (mask_id << 4) | bit)
        assert next(codes,None) is None
    totals = [Counter() for _ in range(4)]
    adjusted = []
    completed = 0
    file_number = 0
    for pool in pools:
        for offset in range(0,len(pool),16):
            path = work/'rows'/f'sep-{file_number}.json'
            file_number += 1
            if partial and not path.exists():
                continue
            refs = pool[offset:offset+16]
            rows = json.loads(path.read_bytes())
            assert len(rows) == len(refs)*4, path
            for pos, row in enumerate(rows):
                ref = refs[pos//4]
                t = grid['targets'][ref>>12]
                board = f"grid-v3:{t['inventoryTargetIndex']}:{(ref>>4)&255}:{ref&15}"
                axes = pos%4
                assert (row['board'],row['axes'],row['seed']) == (board,axes,20261106+4*ref+axes), path
                state = row['result']
                assert state in ('adjusted','clean','review','noMinimum','generationBudget'), path
                if state in ('adjusted','clean','review'):
                    assert 0<=row['rmsCM']<=0.5 and row['jawCount']>=0
                    assert (row['jawCount']>0) == (state=='review')
                    assert (row['original']!=row['answer']) == (state=='adjusted')
                    a=row['answer']
                    assert (axes&1 or a['spinY']==0) and (axes&2 or a['spinX']==0)
                if state=='adjusted':
                    adjusted.append({k:row[k] for k in ('board','axes','seed','original','answer')})
                totals[axes][state]+=1
            completed += 1
    count = sum(sum(c.values()) for c in totals)
    expected = 4*sum(len(pool) for pool in pools)
    if not partial:
        assert count==expected==3130112 and completed==file_number==len(list((work/'rows').glob('sep-*.json')))
    result=dict(checked=count,expected=expected,groups=completed,expectedGroups=file_number,settings=totals)
    if not partial:
        (work.parent/'sep-changed.json').write_text(json.dumps(adjusted,separators=(',',':')))
        (work/'audited.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result))
if __name__=='__main__':verify(Path(sys.argv[1]),'--partial' in sys.argv[2:])
