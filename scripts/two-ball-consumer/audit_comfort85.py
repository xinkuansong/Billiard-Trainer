#!/usr/bin/env python3
"""Independent readback: exact subset/preservation, SHA, geometry, scores, order and index."""
import gzip, hashlib, json, math, sys
from pathlib import Path

def sha(b): return hashlib.sha256(b).hexdigest()
def read(p): return json.loads(p.read_text())
def rows(b): return [json.loads(x) for x in gzip.decompress(b).splitlines()]

def audit(source, consumer, report):
    index = read(consumer/'index.json')
    parts = read(source/'parts-index.json')
    assert index['schema'] == 'two-ball-consumer-v2'
    assert index['provenance']['sourceIndexSHA256'] == sha((source/'parts-index.json').read_bytes())
    assert index['provenance']['sourceSummarySHA256'] == sha((source/'summary.json').read_bytes())
    entries = {e['id']: e for e in index['layouts']}
    shards = {s['name']: s for s in index['shards']}
    seen = set(); questions = references = routes = ties = 0; max_error = 0
    for part in parts:
        raw = (source/'final'/f"{part['stem']}.jsonl.gz").read_bytes()
        assert sha(raw) == part['finalSHA256'] and len(raw) == part['finalBytes']
        originals = rows(raw)
        exported = []
        if part['stem'] in shards:
            raw = (consumer/f"{part['stem']}.jsonl.gz").read_bytes(); s = shards[part['stem']]
            assert sha(raw) == s['sha256'] and len(raw) == s['bytes']
            exported = rows(raw)
        byid = {r['id']: r for r in exported}; assert len(byid) == len(exported)
        for old in originals:
            expected = [c for c in old['candidates'] if any(t['comfort']['totalScore'] >= 85 for t in c['top5'])]
            if not expected:
                assert old['id'] not in byid and old['id'] not in entries
                continue
            row = byid[old['id']]; e = entries[row['id']]
            assert e['shard'] == part['stem'] and exported[e['line']] == row and e['board'] == row['board']
            assert row['id'] not in seen; seen.add(row['id'])
            assert {k:v for k,v in row.items() if k not in ('routes','candidates','schema')} == {
                k:v for k,v in old.items() if k not in ('routes','candidates','schema')}
            original_routes = {r['comboIndex']: r for r in old['routes']}
            scored = {}; used = set()
            for r in row['routes']:
                assert {k:v for k,v in r.items() if k != 'executionDifficulty'} == original_routes[r['comboIndex']]
                d = r['executionDifficulty']; p = r['trajectory2mm']['points']
                length = math.fsum(math.dist(a[1:], b[1:]) for a,b in zip(p,p[1:]))
                sx, sy, speed, n = abs(r['spinX']), r['spinY'], r['velocity'], len(r['trajectory2mm']['cushions'])
                assert n == r['cueMainRailsAfterContact']
                terms = [2.5*sx + .8*max(0,sy)+1.2*max(0,-sy), .8*(speed/4.5)**2,
                         .12*n+.06*length, .6*sx*(speed/4.5)+.15*n*sx]
                effort = math.fsum(terms)
                for a,b in zip([d['lengthMeters'], *d['components'].values(), d['effort'], d['difficulty']],
                               [length, *terms, effort, 100*effort/(1+effort)]):
                    assert math.isfinite(a); error=abs(a-b); assert error < 1e-10; max_error=max(error,max_error)
                scored[r['comboIndex']] = d['effort']; routes += 1
            assert len(expected) == len(row['candidates'])
            for oldc, c in zip(expected, row['candidates']):
                assert {k:v for k,v in oldc.items() if k!='top5'} == {k:v for k,v in c.items() if k!='top5'}
                qualified = [(rank,t) for rank,t in enumerate(oldc['top5']) if t['comfort']['totalScore'] >= 85]
                qualified.sort(key=lambda pair: (scored[pair[1]['comboIndex']],pair[0]))
                assert len(c['top5']) == len(qualified)
                for (rank, oldt), t in zip(qualified,c['top5']):
                    assert t['sourceRecommendationRank'] == rank
                    assert {k:v for k,v in t.items() if k!='sourceRecommendationRank'} == oldt
                    q=t['comfort']; assert abs((q['distanceScore']*q['spaceScore']*q['angleScore'])**(1/3)-q['totalScore'])<1e-8
                    used.add(t['comboIndex']); references += 1
                ties += sum(scored[a['comboIndex']]==scored[b['comboIndex']] for a,b in zip(c['top5'],c['top5'][1:]))
                questions += 1
            assert used == set(scored)
    assert seen == set(entries) and questions == 166443 and references == 677488
    result = dict(state='complete', auditPassed=True, layouts=len(seen), questions=questions,
                  recommendations=references, uniqueLayoutRoutes=routes, equalEffortPairs=ties,
                  maximumIndependentScoreError=max_error, sourceFieldsPreserved=True,
                  exactQualifiedSubset=True, stableAscendingOrder=True, allShardsSHA256Passed=True,
                  indexSHA256=sha((consumer/'index.json').read_bytes()))
    (report/'audit.json').write_text(json.dumps(result, indent=2)); print(json.dumps(result))

if __name__ == '__main__': audit(*map(Path, sys.argv[1:]))
