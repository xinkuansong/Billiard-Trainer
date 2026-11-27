from pathlib import Path
import json,math,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/defense-distance-rail-20261103/r2'
audit=json.loads((OUT/'audit.json').read_text());assert audit['passed']
byid={q['id']:q for q in json.loads((OUT/'candidates.json').read_text())}
ids=['DR-long-004','DR-long-015','DR-long-052','DR-rail-009','DR-rail-026','DR-rail-086'];rows=[]
for i,id in enumerate(ids):
 q=byid[id];q['displayID']=('L' if i<3 else 'R')+str(i%3+1)
 assert q['openingEnemyOpportunities'][0]['score']-q['metrics']['comfort']>=10
 assert q['metrics']['visibility']==1
 ps=[p['metrics'] for p in q['perturbations']]
 q['probeSummary']={name+bound:f(p[key] for p in ps) for name,key in [('distance','ballDistance'),('gap','cueRailGap'),('comfort','comfort')] for bound,f in [('Min',min),('Max',max)]}
 rows.append(q)
for kind in ['long','rail']:assert {q['layoutFamily'] for q in rows if q['family']==kind}=={'twoA','twoB','three'}
for i,q in enumerate(rows):
 for old in rows[:i]:
  for sx in [-1,1]:
   for sz in [-1,1]:
    assert not all(math.dist(q['positions'][a],[sx*old['positions'][b][0],sz*old['positions'][b][1]])<.06 for a,b in [('cueBall','cueBall'),(q['ownKey'],old['ownKey'])])
(OUT/'questions.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
(OUT/'selection.json').write_text(json.dumps({'ids':ids,'reason':'one per role layout; distinct openings; reference best-opponent comfort drops >10 from pre-shot geometry and >10 versus a legal same-opening control; no sidespin; independent audit passed','questionsSHA256':hashlib.sha256((OUT/'questions.json').read_bytes()).hexdigest(),'mirrorBaseDedupMeters':.06},ensure_ascii=False,indent=2))
for q in rows:print(q['displayID'],q['id'],q['openingComfort'],q['metrics'],q['probeSummary'])
