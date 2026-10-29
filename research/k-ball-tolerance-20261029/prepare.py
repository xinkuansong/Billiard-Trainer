from pathlib import Path
import json,hashlib,shutil
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/k-ball-tolerance-20261029';OLD=ROOT/'output/k-ball-middle-rails-20261029'
OUT.mkdir(exist_ok=True)
rows=json.loads((OLD/'trials.json').read_text());assert len(rows)==293 and sum(r['success'] for r in rows)==292
levels=[dict(id='small',aim=.05,speed=.015,tip=.01),dict(id='medium',aim=.1,speed=.03,tip=.02),dict(id='large',aim=.2,speed=.06,tip=.04)]
def radical(i,b):
 value=0;f=1/b
 while i:value+=(i%b)*f;i//=b;f/=b
 return value
vectors=[]
for i in range(1,17):
 v=[2*radical(i,b)-1 for b in (2,3,5,7)];vectors.extend([v,[-x for x in v]])
probes=[]
for level in levels:
 for axis in range(4):
  for sign in (-1,1):
   v=[0]*4;v[axis]=sign
   probes.append(dict(id=f"{level['id']}-axis-{axis}-{sign}",level=level['id'],kind='axis',axis=['aim','speed','sx','sy'][axis],normalized=v,delta=[v[0]*level['aim'],v[1]*level['speed'],v[2]*level['tip'],v[3]*level['tip']]))
 for i,v in enumerate(vectors):
  probes.append(dict(id=f"{level['id']}-joint-{i:02d}",level=level['id'],kind='joint',axis='joint',normalized=v,delta=[v[0]*level['aim'],v[1]*level['speed'],v[2]*level['tip'],v[3]*level['tip']]))
protocol=dict(version='k-tolerance-v1',levels=levels,probes=probes,dimensions=['aimDegrees','relativeSpeed','spinXInR','spinYInR'],jointDesign='16 Halton points bases 2,3,5,7 plus antithetic pairs; same 32 vectors nested across levels and shared across all samples; uniform-box exploration, not human-error calibration',gradingProposal='Cumulative levels; at each level require all 8 axis endpoints and >=26/32 joint probes to succeed. Largest passing level: large=宽容, medium=常规, small=敏感, none=极敏感. Baseline-failed controls excluded from grading. Provisional simulation classification only.',baselineCount=len(rows),positiveSamples=sum(r['success'] for r in rows),probesPerPositive=len(probes),expectedSimulations=len(rows)+sum(r['success'] for r in rows)*len(probes),sourceTrialsSHA256=hashlib.sha256((OLD/'trials.json').read_bytes()).hexdigest())
(OUT/'protocol.json').write_text(json.dumps(protocol,indent=2,ensure_ascii=False));shutil.copy2(OLD/'trials.json',OUT/'samples.json');shutil.copy2(OLD/'geometry.json',OUT/'geometry.json')
print('PLANNED',protocol['expectedSimulations'],'simulations')
