from pathlib import Path
import json,itertools
import numpy as np
from analyze import calc,sample,clean,arc,save
OUT=Path(__file__).resolve().parent
D=json.loads((OUT/'metrics.json').read_text());P=json.loads((OUT/'display-trajectories.json').read_text())
def weighted_chamfer(p,q):
 def weights(x):
  if len(x)==1:return np.ones(1)
  ds=np.linalg.norm(np.diff(x,axis=0),axis=1);w=np.r_[ds,0]+np.r_[0,ds];return w/w.sum()
 d=np.linalg.norm(p[:,None,:]-q[None,:,:],axis=2)
 return float((np.dot(weights(p),d.min(axis=1))+np.dot(weights(q),d.min(axis=0)))/2)
def align(p,q):
 n,m=len(p),len(q);cost=np.full((n+1,m+1),np.inf);length=np.zeros((n+1,m+1),int);steps=np.zeros((n,m),np.uint8);cost[0,0]=0
 for i in range(n):
  for j in range(m):
   candidates=[(cost[i,j],length[i,j],0),(cost[i,j+1],length[i,j+1],1),(cost[i+1,j],length[i+1,j],2)]
   v,l,k=min(candidates);cost[i+1,j+1]=v+np.linalg.norm(p[i]-q[j]);length[i+1,j+1]=l+1;steps[i,j]=k
 path=[];i=n-1;j=m-1
 while True:
  path.append([i,j])
  if i==0 and j==0:break
  k=steps[i,j]
  if k in [0,1]:i-=1
  if k in [0,2]:j-=1
 path=path[::-1];d=np.array([np.linalg.norm(p[i]-q[j]) for i,j in path]);r=calc(p,q)
 assert abs(d.mean()-r['dtw'])<1e-8
 return {'path':path,'maxDeviation':float(d.max()),'meanDeviation':float(d.mean()),'fractionBelow1cm':float(np.mean(d<1)),'pathLength':len(path),'maxProgressMismatch':max(abs(i/max(1,n-1)-j/max(1,m-1)) for i,j in path)}
rows=[]
for r in D['engine']:
 if r['budget']!=512:continue
 p=np.array(P[r['a']]);q=np.array(P[r['b']]);w=weighted_chamfer(p,q)
 rows.append({'a':r['a'],'b':r['b'],'unweighted':r['chamfer'],'arcWeighted':w,'difference':w-r['chamfer']})
examples={}
for r in D['synthetic']:
 if r['budget']==512 and r['id'] in ['local_spike','truncated','reverse','retrace','loop_order']:
  examples[r['id']]=align(np.array(r['a']),np.array(r['b']))
# Simultaneous rigid transforms and uniform scale preserve/change raw geometry as expected.
rng=np.random.default_rng(42);checked=0
for _ in range(30):
 p=rng.normal(size=(6,2));q=rng.normal(size=(8,2));r=calc(p,q)
 theta=rng.random()*6.28;rot=np.array([[np.cos(theta),-np.sin(theta)],[np.sin(theta),np.cos(theta)]])
 rt=calc(p@rot+[123,-42],q@rot+[123,-42]);rs=calc(3*p,3*q)
 for k in ['frechet','dtw','chamfer']:
  assert abs(rt[k]-r[k])<1e-9 and abs(rs[k]-3*r[k])<1e-9
 checked+=1
sensitivity=[]
for r in D['synthetic']:
 if r['budget']!=512:continue
 for t in [5,10,20]:
  scores=np.array([100*2**(-r[k]/t) for k in ['frechet','dtw','chamfer']])
  for w in [[1,0,0],[.7,.2,.1],[1/3,1/3,1/3]]:
   sensitivity.append({'id':r['id'],'t50':t,'weights':w,'scoreBlend':float(scores@w),'distanceBlendScore':100*2**(-sum(r[k]*v for k,v in zip(['frechet','dtw','chamfer'],w))/t)})
# Rank order stability across real pairs; omit near-ties in high-density reference.
ref=[r for r in D['engine'] if r['budget']==2048];rank=[]
for n in [128,256,512,1024]:
 rs=[r for r in D['engine'] if r['budget']==n]
 for k in ['frechet','dtw','chamfer','dtwSymmetric2']:
  inversions=0;eligible=0
  for i,j in itertools.combinations(range(len(ref)),2):
   gap=ref[i][k]-ref[j][k]
   if abs(gap)<=0.1:continue
   eligible+=1;inversions+=gap*(rs[i][k]-rs[j][k])<0
  rank.append({'budget':n,'metric':k,'eligibleComparisons':eligible,'inversions':int(inversions)})
save('diagnostics.json',{'weightedChamfer':rows,'dtwAlignments':examples,'transformChecks':checked,'weightSensitivity':sensitivity,'rankStability':rank})
print('diagnostics complete; weighted C max difference',max(abs(x['difference']) for x in rows))
