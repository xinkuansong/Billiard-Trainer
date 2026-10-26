from pathlib import Path
import sys,json,math
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'research/rack-correlated-pattern-20261026'))
from common import NOM,readraw,write
OUT=ROOT/'output/rack-phase-tuning-20261026'
q=NOM.astype(float)-NOM.astype(float).mean(0);q/=np.linalg.norm(q,axis=1)[:,None]
rows=[]
for stage,variant in [('validation','radial_full'),('confirmation','radial_contract')]:
 folder=ROOT/'output/rack-correlated-pattern-20261026'/stage
 scores={(r['id'],r['variant']):r for r in json.loads((folder/'rows.json').read_text())}
 for raw in readraw(folder):
  if raw['input']['variant']!=variant:continue
  p=np.array([[b['x'],b['z']] for b in raw['rack']]);u=p-NOM;u/=np.linalg.norm(u,axis=1)[:,None]
  c=float(np.mean(np.sum(u*q,axis=1)));s=float(np.mean(q[:,0]*u[:,1]-q[:,1]*u[:,0]))
  if c>=0:continue
  a=math.degrees(math.atan2(abs(s),-c));i=raw['input']['rackID'];r=scores[i,variant];b=scores[i,'baseline']
  rows.append(dict(stage=stage,id=i,angle=a,sign=1 if s>=0 else -1,score=r['score'],delta=r['score']-b['score'],scratch=raw['cueScratched'],wallMS=raw['seconds']*1000))
summary={}
for stage in ['validation','confirmation']:
 summary[stage]=[]
 for lo in range(0,90,15):
  rr=[r for r in rows if r['stage']==stage and lo<=r['angle']<lo+15]
  summary[stage].append(dict(angle=[lo,lo+15],n=len(rr),**{k:float(np.mean([r[k] for r in rr])) for k in ['score','delta','scratch','wallMS']}))
write(OUT/'retrospective-rows.json',rows);write(OUT/'retrospective-summary.json',summary)
print(json.dumps(summary,indent=2))
