from pathlib import Path
import json,gzip,math,itertools,hashlib,statistics
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-center-mechanism-20261026'
def write(n,v):(OUT/n).write_text(json.dumps(v,ensure_ascii=False,indent=2,allow_nan=False))
meta=json.loads((OUT/'metadata.json').read_text());cal=json.loads((OUT/'calibration.json').read_text());L,W,R=(meta[k] for k in ['length','width','radius'])
labels=[f'{chr(65+r)}{c+1}' for r in range(5) for c in range(r+1)];rowids=np.array([r for r in range(5) for c in range(r+1)]);s=2*R+.0002
nom=np.array([[-L/4-r*s*math.sqrt(3)/2,(r/2-c)*s] for r in range(5) for c in range(r+1)])
edges=[(i,j) for i,j in itertools.combinations(range(15),2) if abs(np.linalg.norm(nom[i]-nom[j])-s)<1e-6];interior=[4,7,8];assert len(edges)==30
# This addendum is based solely on source inspection and the existing-rack preflight.
if not (OUT/'candidate-lock.json').exists():
 write('source-informed-addendum.json',dict(reason='Current immediate-contact tolerance is 0.25mm, covering much of current 0.02–0.38mm gap range; preflight shows many exact same-time impulses. Add threshold-count features to the already specified apex and interior families. Do not interpret tied timestamps as physical simultaneity.',beforeHoldoutAnalysis=True,source='EngineNumerics.swift:430',timestamp=float(__import__('time').time())))

def extract(r):
 p=np.array([[b['x'],b['z']] for b in r['rack']]);gap={(i,j):(np.linalg.norm(p[i]-p[j])-2*R)*1000 for i,j in edges}
 def g(i,j):return gap[tuple(sorted((i,j)))]
 st={};families={}
 def add(n,v,f):st[n]=float(v);families[n]=f
 a,b=g(0,1),g(0,2)
 add('apex_gap_mean_mm',(a+b)/2,'apex');add('apex_gap_difference_mm',abs(a-b),'apex');add('apex_gap_relative_imbalance',abs(a-b)/(a+b),'apex');add('apex_immediate_count',int(a<=.25)+int(b<=.25),'apex');add('apex_both_delayed',int(min(a,b)>.25),'apex')
 for i in interior:
  incoming=[v for (u,j),v in gap.items() if i in [u,j] and rowids[u if j==i else j]<rowids[i]]
  outgoing=[v for (u,j),v in gap.items() if i in [u,j] and rowids[u if j==i else j]>rowids[i]]
  assert len(incoming)==len(outgoing)==2
  pre=labels[i]
  add(pre+'_incoming_gap_mm',np.mean(incoming),'interior');add(pre+'_outgoing_gap_mm',np.mean(outgoing),'interior');add(pre+'_out_minus_in_mm',np.mean(outgoing)-np.mean(incoming),'interior')
  add(pre+'_out_in_ratio',np.mean(outgoing)/np.mean(incoming),'interior');add(pre+'_incoming_imbalance_mm',abs(incoming[0]-incoming[1]),'interior')
  add(pre+'_incoming_immediate',sum(v<=.25 for v in incoming),'interior');add(pre+'_outgoing_immediate',sum(v<=.25 for v in outgoing),'interior')
 add('D23_mean_out_minus_in_mm',(st['D2_out_minus_in_mm']+st['D3_out_minus_in_mm'])/2,'interior');add('D23_difference_out_minus_in_mm',abs(st['D2_out_minus_in_mm']-st['D3_out_minus_in_mm']),'interior')
 add('rack_immediate_edges',sum(v<=.25 for v in gap.values()),'global');add('rack_gap_std_mm',np.std(list(gap.values())),'global')
 for rr in range(4):add(f'row_{rr}_{rr+1}_gap_mm',np.mean([v for (i,j),v in gap.items() if rowids[i]==rr and rowids[j]==rr+1]),'global')
 q=np.array([[v[0]*L-L/2,v[1]*L-W/2] for k,v in r['board'].items() if k!='cueBall']);d=np.linalg.norm(q[:,None]-q[None,:],axis=2);np.fill_diagonal(d,np.inf);index=float(d.min(1).mean()/cal['reference'][str(len(q))]['expectedMeanM'])
 scalar=statistics.mean(min(math.dist(x,y) for j,y in enumerate(q) if i!=j) for i,x in enumerate(q))/cal['reference'][str(len(q))]['expectedMeanM'];assert abs(index-scalar)<1e-12
 dyn={};trace=r['impulseTrace'];assert len(trace[0]['changed'])==2
 E0=sum(.5*.17*np.dot(c['preV'],c['preV']) for c in trace[0]['changed']);assert E0>0
 names={k:i-1 for i,k in enumerate(r['names'])};sounds=[e for e in r['contacts'] if e['kind']=='ball'];bc=[dict(t=e['t'],a=r['names'][e['changed'][0]['slot']+1],b=r['names'][e['changed'][1]['slot']+1]) for e in trace if len(e['changed'])==2];firstB={};firstSource={};order=[]
 for ei,e in enumerate(bc):
  aa,bb=names[e['a']],names[e['b']];order.append((aa,bb))
  if aa==0 or bb==0:
   other=bb if aa==0 else aa
   if other in [1,2] and other not in firstB:firstB[other]=(ei,e['t'])
  for ball,other in [(aa,bb),(bb,aa)]:
   if ball not in firstSource:firstSource[ball]=(ei,e['t'],other)
 assert len(firstB)==2
 dyn['apex_branch_delay_us']=abs(firstB[1][1]-firstB[2][1])*1e6;dyn['apex_branch_order_gap']=abs(firstB[1][0]-firstB[2][0]);dyn['apex_first_plus_z']=int(firstB[1][0]<firstB[2][0]);dyn['zero_time_contacts']=sum(e['t']==0 for e in bc)
 gains=np.zeros(15);loss=np.zeros(15);maxres=0;energyerrs=[];nonpair=[];cumedges={};eventmatch=0
 for event in trace:
  ch=event['changed']
  if len(ch)!=2:nonpair.append([event['t'],len(ch)]);continue
  res=np.sum([np.array(c['postV'])-c['preV'] for c in ch],axis=0);maxres=max(maxres,float(np.linalg.norm(res)))
  de=[.5*.17*(np.dot(c['postV'],c['postV'])-np.dot(c['preV'],c['preV'])) for c in ch]
  pairtotal=sum(de)+sum(.17*R*R/5*(np.dot(c['postW'],c['postW'])-np.dot(c['preW'],c['preW'])) for c in ch);energyerrs.append(pairtotal)
  keys={c['slot'] for c in ch}
  if any(e['t']==event['t'] and {names[e['a']],names[e['b']]}==keys for e in sounds):eventmatch+=1
  if event['t']<=.00500001:
   for c,delta in zip(ch,de):
    if c['slot']>=0:gains[c['slot']]+=max(0,delta);loss[c['slot']]+=max(0,-delta)
  if min(keys)>=0:
   ii=int(np.argmin(de));jj=1-ii;key=f"{ch[ii]['slot']}>{ch[jj]['slot']}";cumedges[key]=cumedges.get(key,0)+max(0,min(-de[ii],de[jj]))
 for sample in r['samples']:
  ms=round(sample['delay']*1000);states=sample['states'][1:];pp=np.array([x['p'] for x in states])[:,[0,2]];vv=np.array([x['v'] for x in states])[:,[0,2]];E=.5*.17*(vv*vv).sum(1)
  dd=np.linalg.norm(pp[:,None]-pp[None,:],axis=2);np.fill_diagonal(dd,np.inf);near=dd.argmin(1);nr=dd.min(1)-2*R
  rv=vv[near]-vv;rr=pp[near]-pp;opening=(rv*rr).sum(1)/dd.min(1)
  prefix=f't{ms}_';dyn[prefix+'interior_gap_mm']=float(nr[interior].mean()*1000);dyn[prefix+'interior_min_gap_mm']=float(nr[interior].min()*1000);dyn[prefix+'interior_opening_mps']=float(opening[interior].mean());dyn[prefix+'interior_speed_mps']=float(np.linalg.norm(vv[interior],axis=1).mean());dyn[prefix+'interior_energy_share']=float(E[interior].sum()/E.sum());dyn[prefix+'effective_energized_balls']=float(E.sum()**2/np.dot(E,E));dyn[prefix+'object_energy_fraction']=float(E.sum()/E0);dyn[prefix+'interior_close_count']=int(sum(nr[interior]<.02));dyn[prefix+'all_gap_mm']=float(nr.mean()*1000)
  rel=vv[interior]-vv[interior].mean(0);dyn[prefix+'internal_velocity_variance']=float((rel*rel).sum(1).mean())
 dyn['interior_gross_gain_fraction']=float(gains[interior].sum()/max(gains.sum(),1e-30));dyn['interior_gross_return_fraction']=float(loss[interior].sum()/max(gains[interior].sum(),1e-30));dyn['interior_unreached_20ms']=sum(i not in firstSource for i in interior)
 return dict(id=r['input']['rackID'],split=r['input']['split'],seed=r['input']['seed'],index=index,success=int(index>=1.2),remaining=len(q),potted=15-len(q),wallMS=r['seconds']*1000,cpuMS=r['cpuSeconds']*1000,static=st,dynamic=dyn,energyEdges=cumedges,firstOrder=order[:25],audit=dict(momentumResidual=maxres,maxPairEnergyGain=max(energyerrs),nonPairJumps=nonpair,matched=eventmatch,jumps=len(trace)),positions=p.tolist()),families

def load(split):
 rows=[];fam=None
 for file in sorted(OUT.glob('raw-*.jsonl.gz')):
  with gzip.open(file,'rt') as f:
   for line in f:
    r=json.loads(line)
    if r['input']['split']==split:
     assert r['status']=='settled';v,fam=extract(r);rows.append(v)
 return sorted(rows,key=lambda r:r['id']),fam

def select(rows,families):
 names=list(rows[0]['static']);X=np.array([[r['static'][n] for n in names] for r in rows]);y=np.array([r['success'] for r in rows]);scans=[]
 for j,n in enumerate(names):
  for t in sorted(set(float(np.quantile(X[:,j],q)) for q in [.2,.4,.5,.6,.8])):
   for le in [True,False]:
    m=X[:,j]<=t if le else X[:,j]>t
    if min(m.sum(),(~m).sum())<150:continue
    scans.append(dict(conditions=[dict(feature=n,threshold=t,le=le)],family=families[n],delta=float(y[m].mean()-y[~m].mean()),selected=int(m.sum())))
 candidates=[]
 for family in ['apex','interior']:
  best=max([q for q in scans if q['family']==family],key=lambda q:q['delta']);candidates.append(best.copy())
 # Best shallow conjunction from already frozen scalar threshold grid, no holdout access.
 best=None
 masks=[np.array([all((r['static'][c['feature']]<=c['threshold'])==c['le'] for c in q['conditions']) for r in rows]) for q in scans]
 for i,q in enumerate(scans):
  for j in range(i+1,len(scans)):
   qq=scans[j]
   if q['conditions'][0]['feature']==qq['conditions'][0]['feature']:continue
   m=masks[i]&masks[j]
   if min(m.sum(),(~m).sum())<150:continue
   delta=float(y[m].mean()-y[~m].mean())
   if best is None or delta>best['delta']:best=dict(conditions=q['conditions']+qq['conditions'],family='combined',delta=delta,selected=int(m.sum()))
 if best:candidates.append(best)
 for i,c in enumerate(candidates):c['id']=f'R{i+1}'
 # Mechanism hypotheses: thresholds defined using train only. No picking based on result.
 mechs=[]
 for n,positive in [('apex_branch_order_gap',False),('t5_interior_energy_share',True),('t5_effective_energized_balls',True),('t5_interior_gap_mm',True)]:
  values=[r['dynamic'][n] for r in rows];mechs.append(dict(feature=n,positive=positive,low=float(np.quantile(values,.2)),high=float(np.quantile(values,.8))))
 return dict(candidates=candidates,mechanisms=mechs,staticFeatureNames=names,scalarSearchCount=len(scans),trainCount=len(rows),protocolSHA=hashlib.sha256((OUT/'protocol.json').read_bytes()).hexdigest(),createdAt=float(__import__('time').time()))

def ci(a,b,alpha=.05):
 rng=np.random.default_rng(202610260612);a=np.array(a);b=np.array(b)
 # Bernoulli bootstrap is exactly the nonparametric sample-mean bootstrap for independent racks.
 d=rng.binomial(len(a),a.mean(),20000)/len(a)-rng.binomial(len(b),b.mean(),20000)/len(b)
 return [float(x) for x in np.quantile(d,[alpha/2,1-alpha/2])]
def stats(rows):
 return dict(n=len(rows),successes=sum(r['success'] for r in rows),rate=float(np.mean([r['success'] for r in rows])),meanIndex=float(np.mean([r['index'] for r in rows])),wallMedianMS=float(np.median([r['wallMS'] for r in rows])),wallP95MS=float(np.quantile([r['wallMS'] for r in rows],.95)),meanPotted=float(np.mean([r['potted'] for r in rows])))
def evaluate(rows,conditions):
 a=[r for r in rows if all((r['static'][c['feature']]<=c['threshold'])==c['le'] for c in conditions)];ids={r['id'] for r in a};b=[r for r in rows if r['id'] not in ids]
 return dict(selected=stats(a),other=stats(b),delta=float(np.mean([r['success'] for r in a])-np.mean([r['success'] for r in b])),ci=ci([r['success'] for r in a],[r['success'] for r in b],.05/3),selectedIDs=sorted(ids),mechanisms={n:dict(selected=float(np.mean([r['dynamic'][n] for r in a])),other=float(np.mean([r['dynamic'][n] for r in b]))) for n in ['apex_branch_order_gap','t5_interior_energy_share','t5_effective_energized_balls','t5_interior_gap_mm']})
train,fam=load('train');assert len(train)==1000
lock=select(train,fam)
if (OUT/'candidate-lock.json').exists():
 old=json.loads((OUT/'candidate-lock.json').read_text());assert old['candidates']==lock['candidates'] and old['mechanisms']==lock['mechanisms'];lock=old
else:write('candidate-lock.json',lock)
print('Candidates locked from train only',lock['candidates'],flush=True)
hold,_=load('holdout');assert len(hold)==1000 and not {r['seed'] for r in train}&{r['seed'] for r in hold}
allrows=train+hold;write('derived.json',dict(labels=labels,edges=edges,interior=interior,rows=allrows))
results=[]
for c in lock['candidates']:results.append(dict(**c,train=evaluate(train,c['conditions']),holdout=evaluate(hold,c['conditions'])))
mechanisms=[]
for q in lock['mechanisms']:
 n=q['feature'];v=[r['dynamic'][n] for r in hold];lo=[r for r in hold if r['dynamic'][n]<=q['low']];hi=[r for r in hold if r['dynamic'][n]>q['high']]
 if not hi:hi=[r for r in hold if r['dynamic'][n]>=q['high']]
 mechanisms.append(dict(**q,lowGroup=stats(lo),highGroup=stats(hi),delta=float(np.mean([r['success'] for r in hi])-np.mean([r['success'] for r in lo])),ci=ci([r['success'] for r in hi],[r['success'] for r in lo],.05/4)))
comparison={}
for n in train[0]['dynamic']:
 yes=[r['dynamic'][n] for r in hold if r['success']];no=[r['dynamic'][n] for r in hold if not r['success']];comparison[n]=dict(passMean=float(np.mean(yes)),failMean=float(np.mean(no)))
summary=dict(baseline=dict(train=stats(train),holdout=stats(hold),all=stats(allrows)),candidates=results,mechanisms=mechanisms,descriptiveHoldoutPassFail=comparison,sourceToleranceMM=.25,order=dict(holdoutFirstPlusZ=sum(r['dynamic']['apex_first_plus_z'] for r in hold),holdoutZeroBranchDelay=sum(r['dynamic']['apex_branch_delay_us']==0 for r in hold)),audit=dict(maxMomentumResidual=max(r['audit']['momentumResidual'] for r in allrows),maxPairEnergyGain=max(r['audit']['maxPairEnergyGain'] for r in allrows),nonPairJumps=sum(len(r['audit']['nonPairJumps']) for r in allrows),unmatchedJumps=sum(r['audit']['jumps']-r['audit']['matched'] for r in allrows)))
write('analysis.json',summary);print(json.dumps(summary,ensure_ascii=False)[:1500],flush=True)
