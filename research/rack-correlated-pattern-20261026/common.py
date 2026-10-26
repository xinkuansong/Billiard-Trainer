from pathlib import Path
import importlib.util,json,math
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-correlated-pattern-20261026'
spec=importlib.util.spec_from_file_location('global_previous',ROOT/'research/rack-global-pattern-20261026/analyze.py');prev=importlib.util.module_from_spec(spec);spec.loader.exec_module(prev)
NOM,R,L,W,EDGES=prev.NOM,prev.R,prev.L,prev.W,prev.EDGES
extract,stats,ci,readraw,write=prev.extract,prev.stats,prev.ci,prev.readraw,prev.write
ROW=np.array([r for r in range(5) for c in range(r+1)]);COL=np.array([c for r in range(5) for c in range(r+1)])
NAMES=[f'{chr(65+r)}{c+1}' for r in range(5) for c in range(r+1)]
FAMILY_NAMES={'rows':'同排联动','diagonalPlus':'斜链一联动','diagonalMinus':'斜链二联动','mirror':'左右镜像联动','neighbors':'邻球同向','contrast':'邻球反向','alternating':'整阵隔排交替','radial':'整阵径向联动'}
def label(v):
 if v=='baseline':return '生产摆法'
 if v=='toward':return '旧三球方案'
 if v=='radial_contract':return '共同向内联动'
 if v=='radial_independent':return '各球独立向内'
 f,l=v.split('_');return FAMILY_NAMES[f]+('（中）' if l=='half' else '（强）')
def expected(bp,variant):
 p=bp.copy()
 if variant=='baseline':return p
 if variant=='toward':
  slots=[4,7,8];p[slots,0]=NOM[slots,0]+np.abs(bp[slots,0]-NOM[slots,0]);return p
 family,level=variant.split('_');rho=.5 if level=='half' else 1.
 d=bp-NOM;r=np.linalg.norm(d,axis=1);u=d/np.where(r>0,r,1)[:,None];u[r==0]=[1,0]
 frames=[];can=[]
 for i in range(15):
  cs,sn,ref=1.,0.,1.
  if family=='mirror':ref=-1. if NOM[i,1]<0 else 1.
  if family=='alternating':cs=1. if ROW[i]%2==0 else -1.
  if family=='radial':
   radial=NOM[i].astype(float)-NOM.astype(float).mean(0);cs,sn=radial/np.linalg.norm(radial)
  frame=np.array([[cs,-sn*ref],[sn,cs*ref]]);frames.append(frame);can.append(frame.T@u[i])
 can=np.array(can)
 for i in range(15):
  if family=='rows':members=ROW==ROW[i]
  elif family=='diagonalPlus':members=COL==COL[i]
  elif family=='diagonalMinus':members=ROW-COL==ROW[i]-COL[i]
  elif family=='mirror':members=(ROW==ROW[i])&((COL==COL[i])|(COL==ROW[i]-COL[i]))
  elif family in ('neighbors','contrast'):
   members=np.abs(np.linalg.norm(NOM-NOM[i],axis=1)-prev.S)<1e-6
   if family=='neighbors':members[i]=True
  else:members=np.ones(15,dtype=bool)
  avg=can[members].mean(0);v=can[i]-rho*avg if family=='contrast' else (1-rho)*can[i]+rho*avg
  if np.linalg.norm(v)<1e-12:v=can[i].copy()
  if family=='radial' and level=='contract':v[0]=-abs(v[0])
  if family=='radial' and level=='independent':v=np.array([-abs(can[i,0]),can[i,1]])
  p[i]=np.float32(NOM[i].astype(float)+frames[i]@v/np.linalg.norm(v)*r[i])
 return p

def audit_geometry(raw,base):
 bp=np.array([[b['x'],b['z']] for b in base['rack']]);p=np.array([[b['x'],b['z']] for b in raw['rack']])
 v=raw['input']['variant'];err=float(np.max(np.abs(expected(bp,v)-p)));assert err<1e-7,(v,err)
 assert [b['number'] for b in raw['rack']]==[b['number'] for b in base['rack']]
 for f in ['cue','power','spin','simulatedElevation']:assert raw[f]==base[f]
 aim=p[0]-raw['cue'];aim/=np.linalg.norm(aim);assert np.max(np.abs(aim-raw['direction']))<1e-7
 radius=np.linalg.norm(p-NOM,axis=1);change=float(np.max(np.abs(radius-np.linalg.norm(bp-NOM,axis=1))))
 pair=np.linalg.norm(p[:,None]-p[None,:],axis=2);gap=pair[np.triu_indices(15,1)]-2*R
 assert gap.min()>.0000197 and radius.max()<.0000901 and change<1e-7
 u=(p-NOM)/np.where(radius>0,radius,1)[:,None]
 # Global average cosine correlation of original-neighbor jitter directions.
 alignment=float(np.mean([np.dot(u[a],u[b]) for a,b in EDGES]))
 return dict(transformErrorM=err,maxOffsetMM=float(radius.max()*1000),maxRadiusChangeMM=change*1000,minGapMM=float(gap.min()*1000)),[(pair[a,b]-2*R)*1000 for a,b in EDGES],u,alignment

def sequence(raw):
 first=np.full(15,np.nan);times=np.full(15,np.nan);seq=[];edgefirst=np.full(len(EDGES),np.nan);nonpairs=0
 for j,tr in enumerate(raw['impulseTrace']):
  assert j==0 or tr['frameIndex']>raw['impulseTrace'][j-1]['frameIndex']
  slots=sorted(c['slot'] for c in tr['changed'])
  if len(slots)!=2:nonpairs+=1
  seq.append(slots)
  for c in tr['changed']:
   i=c['slot']
   if i>=0 and np.isnan(first[i]):first[i]=j+1;times[i]=tr['t']*1000
  if tuple(slots) in EDGES:
   ix=EDGES.index(tuple(slots))
   if np.isnan(edgefirst[ix]):edgefirst[ix]=j+1
 missing=np.flatnonzero(np.isnan(first))
 for i in missing:
  s=min(raw['samples'],key=lambda x:abs(x['delay']-.02))['states'][int(i)+1]
  assert s['state']=='stationary' and np.linalg.norm(s['v'])==0, (raw['input']['id'],int(i),'unexplained missing trace')
  fc=raw['firstContacts'].get(raw['names'][int(i)+1]);assert fc is None or fc['time']>.02
 # Missing means no detected impulse within the 20ms window, not a failed shot.
 ff=np.where(np.isnan(first),np.inf,first)
 before=None if not np.isfinite(min(ff[[4,7,8]])) and not np.isfinite(min(ff[[10,14]])) else bool(min(ff[[4,7,8]])<min(ff[[10,14]]))
 return dict(censoredSlots=missing.tolist(),firstInternalBeforeEitherCorner=before,meanInternalFirstOrder=None if np.isnan(first[[4,7,8]]).any() else float(first[[4,7,8]].mean()),firstImpulseOrder=[None if np.isnan(x) else float(x) for x in first],firstImpulseMS=[None if np.isnan(x) else float(x) for x in times],sequence20=seq,nonPairJumps=nonpairs,neighborFirstOrder=[None if np.isnan(x) else float(x) for x in edgefirst])
