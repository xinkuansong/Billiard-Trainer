"""Purposeful stratified feasibility sample; saved paths propose, native engine certifies."""
from pathlib import Path
import json,gzip,random,math,hashlib,collections
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/k-ball-obstacles-20261030';OLD=ROOT/'output/two-ball-parameter-consumer-20261026/before/QiuJi/Resources/TwoBallBank'
def segdist(p,a,b):
 d=[b[k]-a[k] for k in (0,1)];den=sum(v*v for v in d);t=max(0,min(1,sum((p[k]-a[k])*d[k] for k in (0,1))/den)) if den else 0
 return math.dist(p,[a[k]+t*d[k] for k in (0,1)])
def load():
 rng=random.Random(20261030);groups=collections.defaultdict(list);counts=collections.Counter()
 for line in (ROOT/'output/k-ball-one-per-route-20261029/selected.jsonl').open():
  r=json.loads(line);n=r['candidate']['railOrdinal']
  if n not in (2,3):continue
  key=(n,r['candidate']['axis'],'middle' if r['seed']['pocket']>=4 else 'corner');counts[key]+=1
  pool=groups[key]
  if len(pool)<24:pool.append(r)
  else:
   j=rng.randrange(counts[key])
   if j<24:pool[j]=r
 index=json.load(open(OLD/'index.json'));layouts={x['id']:x for x in index['layouts']};wanted={r['seed']['layout'] for rows in groups.values() for r in rows};boards={}
 for sn in {layouts[k]['shard'] for k in wanted}:
  for line in gzip.open(OLD/(sn+'.jsonl.gz'),'rt'):
   d=json.loads(line)
   if d['id'] in wanted:boards[d['id']]=d
 selected=[]
 for key,rows in sorted(groups.items()):
  ranked=[]
  for r in rows:
   b=r['candidate']['B'];n=r['candidate']['railOrdinal'];near=[]
   for rt in boards[r['seed']['layout']]['routes']:
    tr=rt['trajectory2mm'];pts=tr['points'];cs=tr['cushions']
    for i,(a,z) in enumerate(zip(pts,pts[1:])):
     if segdist(b,a[1:],z[1:])<.05715:
      count=sum(c['pointIndex']<=i for c in cs)
      if count<n:near.append(rt['comboIndex'])
      break
   ranked.append((len(near),r))
  score,r=max(ranked,key=lambda x:x[0]);sid=f'O{len(selected)+1:02d}'
  r['sampleID']=sid;r['screeningNearbyCount']=score;r['archiveRoutes']=boards[r['seed']['layout']]['routes'];r.pop('tracks',None)
  selected.append(r)
 (OUT/'samples.json').write_text(json.dumps(selected))
 jobs=[]
 for r in selected:
  sid=r['sampleID'];s=r['seed'];base=dict(B=r['candidate']['B'],railID=r['candidate']['railID'],blockers=[])
  jobs.append(dict(base,id=sid+'/reference',seed=s,tracks=True))
  for rt in r['archiveRoutes']:
   ns=dict(s,route=rt['comboIndex'],dir=rt['strikeDirection'],v=rt['velocity'],sx=rt['spinX'],sy=rt['spinY'])
   jobs.append(dict(base,id=f"{sid}/archive/{rt['comboIndex']}",seed=ns,tracks=True))
 (OUT/'initial-jobs.jsonl').write_text(''.join(json.dumps(j)+'\n' for j in jobs))
 protocol=dict(seed=20261030,sampleSize=len(selected),selection='Reservoir 24 per 2/3 observed rail × before/after × corner/middle; choose largest archived fixed-B proximity count. Purposeful feasibility sample, not population prevalence.',rules=dict(blockLower='all observed rails 1..N-1',sameOrHigher='not targeted',obstacleContact='cue or A before both potA and cueB complete fails; B aftermath unrestricted',scratch='ignored',maxObstacles=3),geometry=dict(coordinates='world XZ metres, Y up; atlas X right Z down',ballRadius=.028574999421834946,minimumInitialGap=.002,referencePathMargin=.012,pocketLipClearance=.10),search=dict(archive='All saved inputs of each selected board, with fixed B, native rerun; not only geometric matches',supplement='Deterministic perturbations around saved route inputs; separate holdout seed',tolerance='same existing 120 probes, strict observed-rail plus obstacle rule before/after'),scope='research sample only; finite search, no global no-solution claim')
 (OUT/'protocol.json').write_text(json.dumps(protocol,ensure_ascii=False,indent=2));print([(r['sampleID'],r['candidate']['railOrdinal'],r['candidate']['axis'],r['seed']['pocket'],r['screeningNearbyCount'],len(r['archiveRoutes'])) for r in selected]);print('jobs',len(jobs))
if __name__=='__main__':load()
