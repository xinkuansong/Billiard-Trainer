#!/usr/bin/env python3
"""Run the timed V023 search after a successful build; budget is wall clock."""
import collections,json,math,time,subprocess,sys
from pathlib import Path
import cue_scratch_research as r
ROOT=r.ROOT; OUT=r.OUT

def records():
 for p in sorted(OUT.glob('*.jsonl')):
  for line in p.open():
   try: yield json.loads(line)
   except json.JSONDecodeError: raise RuntimeError(f'Truncated result: {p}')
def job(row,ident,mode='probe',speed=None,cue=None,obj=None,offset=None):
 d=dict(id=ident,layout=row['layout'],cue=cue or row['cue'],object=obj or row['object'],speed=speed if speed is not None else row['speed'],mode=mode)
 if offset is not None:d['offset']=offset
 return d
def family(row):return (len(row.get('rails',[])),tuple(row.get('rails',[])),row.get('pocket'),row.get('cuePocket'))
def select(rows,limit):
 buckets=collections.defaultdict(list)
 for row in rows:
  if row.get('hit'):buckets[family(row)].append(row)
 chosen=[]; prior=[]
 for key,group in sorted(buckets.items(),key=lambda kv:(len(kv[1]),kv[0][0])):
  ranked=sorted(group,key=lambda a:(a.get('cueClearance',0)<.05,abs(a['speed']-3.3),a['id']))
  for row in ranked:
   if not any(family(p)==key and math.dist(row['cue'],p['cue'])<.05715 and math.dist(row['object'],p['object'])<.05715 for p in prior):
    prior.append(row);break
 # Interleave 0/1/2/3 rail groups so the limited shortlist does not omit long routes.
 queues={n:[x for x in prior if len(x['rails'])==n] for n in range(4)}
 while len(chosen)<limit and any(queues.values()):
  for n in range(4):
   if queues[n] and len(chosen)<limit:chosen.append(queues[n].pop(0))
 return chosen

def main():
 assert not (OUT/'session.json').exists(),'Existing session; do not overwrite'
 start=time.monotonic(); deadline=start+1800
 r.write(OUT/'session.json',dict(startEpoch=time.time(),budgetSeconds=1800,status='preflight'))
 r.run()
 timings=json.loads((OUT/'preflight-timings.json').read_text())
 winner=min(timings,key=lambda x:x['seconds']);workers=winner['workers']
 # Do not insist on multiple workers if measured lock/memory overhead loses.
 r.write(OUT/'workers.json',dict(selected=workers,measurements=timings))
 batch=0; layout=50000
 while time.monotonic()-start<1050:
  remaining=1050-(time.monotonic()-start)
  if remaining<35:break
  batch+=1; cfg=dict(batch=f'broad-{batch:03}',workers=workers,seconds=min(150,max(10,remaining-25)),start=layout,count=100000,mode='broad')
  r.run(cfg)
  summary=json.loads((OUT/f'{cfg["batch"]}-summary.json').read_text());layout+=summary['claimed']
  print('BROAD',batch,'elapsed',round(time.monotonic()-start),'rows',summary['rows'],flush=True)
 rows=list(records()); seeds=select(rows,160)
 near=sorted((x for x in rows if x.get('targetPot') and not x.get('hit') and x.get('contacts')==1 and not x.get('preRails') and not x.get('objectRails') and not x.get('cueJaws') and len(x.get('rails',[]))<=3),key=lambda x:x.get('nearLip',100))[:80]
 seeds+=near
 jobs=[]
 for i,row in enumerate(seeds):
  for k in range(-12,13):
   v=row['speed']+k*.025
   if .5<=v<=8:jobs.append(job(row,f'f-{i}-{k+12}',speed=v))
  for k,(dx,dz) in enumerate([(0.002,0),(-.002,0),(0,.002),(0,-.002),(.01,0),(-.01,0),(0,.01),(0,-.01)]):
   jobs.append(job(row,f'p-{i}-{k}',cue=[row['cue'][0]+dx,row['cue'][1]+dz]))
 remaining=1390-(time.monotonic()-start)
 if jobs and remaining>30:r.run(dict(batch='refine',workers=workers,seconds=max(1,remaining-25),start=0,count=len(jobs),mode='refine',jobs=jobs))
 # Reserved independent full-solver audit of first-direction misses.
 misses=[x for x in rows if x.get('offset') is not None and not x.get('targetPot') and x.get('resolved')]
 audit=misses[::20][:300]
 remaining=1450-(time.monotonic()-start)
 if audit and remaining>30:
  aj=[job(x,'audit-'+x['id'],mode='full') for x in audit]
  r.run(dict(batch='audit',workers=workers,seconds=max(1,remaining-25),start=0,count=len(aj),mode='audit',jobs=aj))
 chosen=select(list(records()),24)
 r.write(OUT/'selected.json',chosen)
 jobs=[]
 for i,row in enumerate(chosen):
  jobs.append(job(row,f'v-{i}-full',mode='full'))
  jobs.append(job(row,f'v-{i}-fixed',mode='fixed',offset=row['offset']))
  for k in range(1,9):
   for sign in [-1,1]:
    v=row['speed']*(1+sign*k*.01)
    if .5<=v<=8:jobs.append(job(row,f'v-{i}-speed-{sign}-{k}',mode='fixed',speed=v,offset=row['offset']))
  # Perturbed positions are re-recommended and explicitly distinguished from fixed-layout speed checks.
 remaining=1680-(time.monotonic()-start)
 if jobs and remaining>30:r.run(dict(batch='verify',workers=workers,seconds=max(1,remaining-25),start=0,count=len(jobs),mode='verify',jobs=jobs))
 elapsed=time.monotonic()-start
 r.write(OUT/'session.json',dict(startEpoch=time.time()-elapsed,budgetSeconds=1800,elapsedSeconds=elapsed,status='simulations-finished',selectedWorkers=workers,generatedLayoutEnd=layout))
 subprocess.run([sys.executable,str(ROOT/'scripts/research/report_cue_scratch.py')],check=True)
 end=time.monotonic()-start
 data=json.loads((OUT/'session.json').read_text());data.update(status='complete',totalSeconds=end);r.write(OUT/'session.json',data)
 print('SESSION COMPLETE',round(end),flush=True)
if __name__=='__main__':main()
