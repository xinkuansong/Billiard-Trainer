#!/usr/bin/env python3
"""Broad, distance-stratified manual curation; uses production replays only."""
import collections, hashlib, json, math, sqlite3, sys
from pathlib import Path
import cue_scratch_research as runner
from run_cue_scratch_session import job, family
from audit_cue_scratch import audit
from report_cue_scratch import svg
ROOT=runner.ROOT; RAW=runner.OUT
BASE=ROOT/'output/cue-scratch-research-20261004'; DEST=BASE/'manual-500'
BATCH='verify-manual500'
QUOTAS={0:[60,60,80],1:[30,30,40],2:[30,30,40],3:[30,30,40]}
def dist(x): return math.dist(x['cue'],x['object'])
def band(x): return 0 if dist(x)<.9 else 1 if dist(x)<1.2 else 2
def key(x): return (tuple(x['cue']),tuple(x['object']),family(x))
def rank(x): return hashlib.sha256(x['id'].encode()).hexdigest()
def near(a,b): return family(a)==family(b) and max(math.dist(a['cue'],b['cue']),math.dist(a['object'],b['object']))<.025

def prepare():
 assert not (RAW/f'{BATCH}-selected.json').exists()
 groups=collections.defaultdict(list); counts=collections.Counter()
 db=sqlite3.connect(f'file:{RAW}/results.sqlite?mode=ro',uri=True)
 for raw, in db.execute('SELECT raw FROM trials WHERE hit=1 ORDER BY id'):
  x=json.loads(raw); counts['rawHits']+=1
  if dist(x)<.6: continue
  # Keep all angles already admitted by the original >1 degree hit predicate.
  counts['eligibleRecords']+=1;groups[key(x)].append(x)
 db.close()
 pool=[]
 for g in groups.values():
  speeds=sorted(set(x['speed'] for x in g));mid=speeds[len(speeds)//2]
  x=min(g,key=lambda x:(abs(x['speed']-mid),rank(x)));pool.append(x)
 # Historic zero-cushion references: preserve exact input where it meets distance.
 refs=[]
 for label,rows in [('r6',json.loads((BASE/'archive-r6-24/verified-cases.json').read_text())),('first',json.loads((RAW/'selected.json').read_text()))]:
  for x in rows:
   if x['rails']:continue
   x=dict(x);x['historicalLabel']=label+':'+x['id'];refs.append(x)
 pins=[x for x in refs if dist(x)>=.6];short=[]
 for n,targets in QUOTAS.items():
  for b,target in enumerate(targets):
   picked=[]
   for x in pins:
    if len(x['rails'])==n and band(x)==b and not any(near(x,y) for y in picked):picked.append(x)
   cells=collections.defaultdict(list)
   for x in pool:
    if len(x['rails'])!=n or band(x)!=b:continue
    angle=next((i for i,t in enumerate([5,20,40,60,75]) if x['cut']<t),5)
    # Include pocket relation and speed bands, without optimizing scratch robustness.
    speedband=0 if x['speed']<2 else 1 if x['speed']<4 else 2 if x['speed']<6 else 3
    cells[(angle,family(x),speedband)].append(x)
   queues=[sorted(g,key=rank) for _,g in sorted(cells.items(),key=lambda a:hashlib.sha256(str(a[0]).encode()).hexdigest())]
   while len(picked)<target+10 and any(queues):
    for q in queues:
     while q:
      x=q.pop(0)
      if not any(near(x,y) for y in picked):picked.append(x);break
     if len(picked)>=target+10:break
   assert len(picked)==target+10,(n,b,len(picked))
   short.extend(picked)
 runner.write(RAW/f'{BATCH}-selected.json',short);runner.write(RAW/f'{BATCH}-references.json',refs)
 jobs=[]
 for i,x in enumerate(short):
  jobs.extend([job(x,f'm500-{i}-full',mode='full'),job(x,f'm500-{i}-fixed',mode='fixed',offset=x['offset'])])
  for percent in [-5,-2,2,5]:
   speed=x['speed']*(1+percent/100)
   if .5<=speed<=8:jobs.append(job(x,f'm500-{i}-speed-{percent}',mode='fixed',speed=speed,offset=x['offset']))
 runner.write(RAW/f'{BATCH}-request.json',dict(batch=BATCH,workers=12,seconds=300,start=0,count=len(jobs),mode='verify',jobs=jobs))
 runner.write(RAW/f'{BATCH}-selection.json',dict(counts=dict(counts),uniquePositionRoutes=len(pool),shortlist=len(short),quotas=QUOTAS,minDistanceM=.6,nearLayoutM=.025,mirrorDedup=False,smallAngleExcluded=False,pinnedHistorical=[x['historicalLabel'] for x in pins]))
 print('PREPARED',len(short),len(jobs),dict(counts),flush=True)

def finish():
 execution=json.loads((RAW/f'{BATCH}-execution.json').read_text());assert execution['executed']
 request=json.loads((RAW/f'{BATCH}-request.json').read_text());rows=[json.loads(s) for s in (RAW/f'{BATCH}.jsonl').open()]; byid={x['id']:x for x in rows}
 assert len(byid)==len(rows)==len(request['jobs']); assert set(byid)=={x['id'] for x in request['jobs']}
 check=audit([RAW/f'{BATCH}.jsonl']);assert check['passed'];runner.write(RAW/f'{BATCH}-audit.json',check)
 source=json.loads((RAW/f'{BATCH}-selected.json').read_text());valid=[];rejected=[]
 for i,x in enumerate(source):
  a,b=byid[f'm500-{i}-full'],byid[f'm500-{i}-fixed']
  fields=['pocket','cuePocket','rails','contacts','preRails','cueJaws','objectJaws','objectRails']
  if not(a.get('hit') and b.get('hit') and all(a.get(k)==b.get(k)==x.get(k) for k in fields) and math.dist(a['aim'],b['aim'])<1e-6 and abs(a['offset']-b['offset'])<1e-6):
   rejected.append(dict(index=i,source=x['id'],reason='outcome-or-aim-mismatch'));continue
  a.update(sourceID=x['id'],distanceM=dist(a),distanceBand=band(a),historicalLabel=x.get('historicalLabel'),cueAccess='not-validated')
  pts=[v for k,v in byid.items() if k.startswith(f'm500-{i}-speed-')]
  a['speedChecks']=dict(tested=len(pts),sameRoute=sum(bool(v.get('hit') and family(v)==family(a)) for v in pts),points=[dict(speed=v['speed'],sameRoute=bool(v.get('hit') and family(v)==family(a))) for v in sorted(pts,key=lambda v:v['speed'])])
  valid.append(a)
 final=[]
 for n,targets in QUOTAS.items():
  for bandnum,target in enumerate(targets):
   group=[x for x in valid if len(x['rails'])==n and band(x)==bandnum]
   assert len(group)>=target,(n,bandnum,len(group))
   final+=group[:target]
 assert len(final)==500
 for i,x in enumerate(final):x['galleryID']=f'M{i+1:03}'
 refs=json.loads((RAW/f'{BATCH}-references.json').read_text());mapping=[];appendix=[]
 for x in refs:
  match=next((y for y in final if math.dist(x['cue'],y['cue'])<1e-5 and math.dist(x['object'],y['object'])<1e-5 and family(x)==family(y)),None)
  if match: mapping.append(dict(old=x['historicalLabel'],current=match['galleryID'],distanceM=dist(x)));continue
  if dist(x)>=.6: raise AssertionError('Lost historic reference '+x['historicalLabel'])
  existing=next((y for y in appendix if near(x,y)),None)
  if existing:ident=existing['galleryID']
  else:
   x.update(galleryID=f'R{len(appendix)+1:03}',distanceM=dist(x),archive=True);appendix.append(x);ident=x['galleryID']
  mapping.append(dict(old=x['historicalLabel'],current=ident,distanceM=dist(x),reason='Below 60cm; historical appendix only'))
 DEST.mkdir(exist_ok=True)
 geo=json.loads((RAW/'geometry.json').read_text())
 for x in final+appendix:(DEST/f'{x["galleryID"]}.svg').write_text(svg(x,geo))
 runner.write(DEST/'cases.json',final);runner.write(DEST/'historical-cases.json',appendix);runner.write(DEST/'historical-map.json',mapping)
 metadata=[]
 for x in final+appendix:
  metadata.append(dict(id=x['galleryID'],rails=len(x['rails']),distance=round(dist(x)*100,4),cut=x['cut'],speed=x['speed'],target=x['pocket'],scratch=int(x['cuePocket'].split('_')[-1]),old=x.get('historicalLabel') or '',archive=x.get('archive',False),speedChecks=x.get('speedChecks'),cue=x['cue'],object=x['object'],source=x.get('sourceID',x['id'])))
 runner.write(DEST/'cards.json',metadata)
 summary=dict(selection=json.loads((RAW/f'{BATCH}-selection.json').read_text()),displayed=500,byRail=dict(collections.Counter(len(x['rails']) for x in final)),distanceBands=dict(collections.Counter(band(x) for x in final)),smallAngleUnder5=sum(x['cut']<5 for x in final),distanceRangeCm=[min(dist(x) for x in final)*100,max(dist(x) for x in final)*100],supplementalTrials=len(rows),completeReplays=len(valid),rejected=rejected,execution=execution,historicalReferences=len(refs),historicalAppendix=len(appendix),audit=check)
 runner.write(DEST/'summary.json',summary)
 print(json.dumps(summary,ensure_ascii=False),flush=True)

if __name__=='__main__':
 {'prepare':prepare,'finish':finish}[sys.argv[1]]()
