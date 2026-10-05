#!/usr/bin/env python3
"""Within the remaining original wall-clock budget, improve representative selection."""
import json,collections,time
from pathlib import Path
import cue_scratch_research as runner
from run_cue_scratch_session import job,family
r=runner.OUT
s=json.loads((r/'session.json').read_text());assert time.time()-s['startEpoch']<1600,'No reserved time remains'
groups=collections.defaultdict(list)
for line in (r/'refine.jsonl').open():
 x=json.loads(line)
 if x.get('hit') and 5<=x['cut']<=75 and x.get('cueClearance',0)>.05:
  key=(tuple(x['cue']),tuple(x['object']),family(x));groups[key].append(x)
ranked=[]
for key,g in groups.items():
 speeds=sorted({x['speed'] for x in g}); span=max(speeds)-min(speeds)
 middle=speeds[len(speeds)//2];representative=min(g,key=lambda x:abs(x['speed']-middle))
 representative['selectionEvidence']=dict(sampledHits=len(speeds),sampledSpan=span,continuousGuarantee=False)
 ranked.append((len(speeds),span,representative))
ranked.sort(key=lambda t:(-t[0],-t[1],abs(t[2]['speed']-3.3)))
selected=[]
for n in range(4):
 seen=set();picked=[]
 for _,_,x in ranked:
  f=family(x)
  if len(x['rails'])==n and f not in seen:
   seen.add(f);picked.append(x)
   if len(picked)==6:break
 selected+=picked
runner.write(r/'selected-stable.json',selected)
jobs=[]
for i,x in enumerate(selected):
 jobs += [job(x,f'w-{i}-full',mode='full'),job(x,f'w-{i}-fixed',mode='fixed',offset=x['offset'])]
 for k in range(1,9):
  for sign in [-1,1]:
   speed=x['speed']*(1+sign*k*.01)
   if .5<=speed<=8:jobs.append(job(x,f'w-{i}-speed-{sign}-{k}',mode='fixed',speed=speed,offset=x['offset']))
print('Selected',len(selected),collections.Counter(len(x['rails']) for x in selected),flush=True)
runner.run(dict(batch='verify-stable',workers=12,seconds=min(80,1700-(time.time()-s['startEpoch'])),start=0,count=len(jobs),mode='verify',jobs=jobs))
