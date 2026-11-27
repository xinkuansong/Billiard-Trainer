from pathlib import Path
import json,math,itertools
out=Path(__file__).resolve().parents[2]/'output/defense-own-potential-20261105'
report=[]
def topology(r):return [{k:v for k,v in e.items() if k!='time'} for e in r['events']]
def similar(a,b):return topology(a)==topology(b) and math.dist(a['finalPositions']['cueBall'],b['finalPositions']['cueBall'])<.08 and math.dist(a['finalPositions']['_8'],b['finalPositions']['_8'])<.1
for label in ['F01','F02','F03','F04','F05']:
    rows=json.loads((out/label/'routes.json').read_text())['routes']
    remaining=sorted(rows,key=lambda r:(r['effort'],r['shot']['speed'],-r['ownAfter']['bestClearDegrees'],r['id']));groups=[]
    while remaining:
        first=remaining.pop(0);members=[r for r in remaining if similar(first,r)]
        remaining=[r for r in remaining if r not in members]
        groups.append({'representative':first['id'],'nearDuplicates':[r['id'] for r in members]})
    ids=[g['representative'] for g in groups];kept=[r for r in rows if r['id'] in ids]
    assert not any(similar(a,b) for a,b in itertools.combinations(kept,2))
    item={'label':label,'rawParetoCount':len(rows),'representativeCount':len(kept),'ids':ids,'groups':groups}
    (out/label/'presentation-selection.json').write_text(json.dumps(item,indent=2));report.append(item)
(out/'deduplication.json').write_text(json.dumps({'criterion':'same full event sequence; cue endpoint distance <8cm and own8 endpoint distance <10cm; keep easier/lower-speed representative; all original Pareto results remain in routes.json','cases':report},indent=2))
print(json.dumps(report,indent=2))
