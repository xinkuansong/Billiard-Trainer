from pathlib import Path
import json,collections,math,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/bank-sample-20261101'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def audit(rows,g,verification):
    assert len(rows)==48
    assert len({r['id'] for r in rows})==48
    counts=collections.Counter((r['type'],r['n']) for r in rows)
    assert counts=={(t,n):6 for t in ['middle','corner'] for n in range(1,5)},counts
    assert {v['id'] for v in verification if v['exactReplay']}=={r['id'] for r in rows}
    for r in rows:
        assert r['complete'] and 'cueBall' not in r['pocketedBalls']
        assert (r['pocket']>=4)==(r['type']=='middle')
        for q in [r['cue'],r['target']]:
            assert all(math.isfinite(x) for x in q)
            assert abs(q[0])<g['length']/2-g['radius'] and abs(q[1])<g['width']/2-g['radius']
        assert math.dist(r['cue'],r['target'])>2*g['radius']
        ev=r['events'];first=next(i for i,e in enumerate(ev) if e['kind']=='ballBall')
        assert set(ev[first]['balls'])=={'cueBall','object'}
        assert not any(e['kind']=='cushion' and e['ball']=='cueBall' for e in ev[:first])
        pot=next(i for i,e in enumerate(ev) if e['kind']=='pocket' and e['ball']=='object')
        assert ev[pot]['pocket']==g['pockets'][r['pocket']]['id']
        assert not any(e['kind']=='ballBall' for e in ev[first+1:pot])
        rails=[e for e in ev[first+1:pot] if e['kind']=='cushion' and e['ball']=='object' and 0<=e['rail']<6]
        walls=[]
        for e in rails:
            normal=g['rails'][e['rail']]['normal']
            walls.append((0 if normal[0]>0 else 1) if abs(normal[0])>.5 else (2 if normal[1]>0 else 3))
        assert walls==r['walls'] and len(walls)==r['n'],r['id']
        for e in ev[first+1:pot]:
            if e['kind']=='cushion' and e['ball']=='object' and not 0<=e['rail']<6:
                assert e['time']>=rails[-1]['time'] and math.dist(e['target'],g['pockets'][r['pocket']]['center'])<.18
        assert abs(r['targetTrack'][0][0]-ev[first]['time'])<1e-5
        assert abs(r['targetTrack'][-1][0]-ev[pot]['time'])<1e-5
        assert 0<=r['actualCutAngle']<85
    return counts
if __name__=='__main__':
    rows=json.loads((OUT/'selected.json').read_text());g=json.loads((OUT/'geometry.json').read_text());v=json.loads((OUT/'verification.json').read_text())
    counts=audit(rows,g,v)
    binding=json.loads((OUT/'source-binding.json').read_text())
    drift=[s['path'] for s in binding['sources'] if s['currentProduction'] and sha(ROOT/s['path'])!=s['sha256']]
    assert not drift,drift
    # Negative fixtures must be rejected by independent event audit.
    import copy
    negatives=[]
    for name in ['wrong-pocket','wrong-rail-count','scratch','wrong-first-contact','double-contact']:
        bad=copy.deepcopy(rows);r=bad[0]
        if name=='wrong-pocket':r['pocket']=(r['pocket']+1)%6
        if name=='wrong-rail-count':r['n']+=1
        if name=='scratch':r['pocketedBalls'].append('cueBall')
        if name=='wrong-first-contact':next(e for e in r['events'] if e['kind']=='ballBall')['balls']=['cueBall','otherBall']
        if name=='double-contact':
            i=next(i for i,e in enumerate(r['events']) if e['kind']=='ballBall');r['events'].insert(i+1,copy.deepcopy(r['events'][i]))
        try:audit(bad,g,v)
        except (AssertionError,StopIteration):negatives.append(name)
        else:raise AssertionError('negative not rejected: '+name)
    result=dict(total=len(rows),counts={f'{t}-{n}':c for (t,n),c in counts.items()},exactReplay=len(v),negativeCasesRejected=negatives,sourceDrift=drift,spinCounts=dict(collections.Counter(str(r['spinX']) for r in rows)),speedRange=[min(r['speed'] for r in rows),max(r['speed'] for r in rows)],pathRange=[min(r['pathLength'] for r in rows),max(r['pathLength'] for r in rows)],selectedSHA256=sha(OUT/'selected.json'))
    (OUT/'audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print(json.dumps(result,ensure_ascii=False,indent=2))
