from pathlib import Path
import json,gzip,math,statistics as st,collections,random,hashlib
O=Path('output/rack-contact-tolerance-20261027');R=.028574999421834946;L=2.5399999618530273;W=1.2699999809265137
cal=json.load(open('output/rack-center-mechanism-20261026/calibration.json'))
scalars=[];compact={};cases={}
def norm(v):return math.sqrt(sum(x*x for x in v))
for line in gzip.open(O/'raw.jsonl.gz','rt'):
 r=json.loads(line);rid=r['input']['rackID'];eps=r['input']['toleranceM'];rev=r['input']['reverse'];key=(rid,eps,rev)
 pts=[[p[0]*L-L/2,p[1]*L-W/2] for n,p in r['board'].items() if n!='cueBall'];N=len(pts)
 score=st.mean(min(math.dist(a,b) for j,b in enumerate(pts) if i!=j) for i,a in enumerate(pts))/cal['reference'][str(N)]['expectedMeanM'] if N>1 else None
 pairs=[e for e in r['eventTrace'] if e['kind']=='ball'];gaps=[];separating=0;pairgain=0;maxgain=0
 def energy(b):return .5*.17000000178813934*(sum(x*x for x in b['v'])+.4*R*R*sum(x*x for x in b['w']))
 for e in pairs:
  a,b=e['beforeKissA'],e['beforeKissB'];dp=[b['p'][i]-a['p'][i] for i in [0,2]];d=norm(dp);gap=d-2*R;gaps.append(gap)
  approach=sum(dp[j]*(b['v'][i]-a['v'][i]) for j,i in enumerate([0,2]))/d
  if approach>1e-6:separating+=1
  gain=energy(e['postA'])+energy(e['postB'])-energy(e['preA'])-energy(e['preB']);maxgain=max(maxgain,gain);pairgain+=gain>1e-6
 worst=max(r['spinTail'],key=lambda x:x['tail'])
 # Canonical slots are fixed physical positions; reverse changes registration only.
 rack=list(reversed(r['rack'])) if rev else r['rack'];corners=['_'+str(rack[i]['number']) for i in [10,14]]
 early=dict(zip(r['names'],r['samples'][1]['states']));en={n:sum(v*v for v in b['v']) for n,b in early.items() if n!='cueBall'};tot=sum(en.values())
 s=dict(id=rid,eps=eps,reverse=rev,status=r['status'],termination=r['termination'],score=score,tail=worst['tail'],tailBall=worst['name'],duration=r['duration'],lastTranslation=r['lastTranslation'],scratch=r['cueScratched'],cpuMS=r['cpuSeconds']*1000,peakSpin=max(x['peakWy'] for x in r['spinTail']),contacts=len(pairs),positiveGapContacts=sum(g>1e-6 for g in gaps),maxGapMM=max(gaps,default=0)*1000,maxContactOverlapMM=max(0,-min(gaps,default=0))*1000,separatingContacts=separating,pairEnergyGainCount=pairgain,maxPairEnergyGain=maxgain,frameOverlapMM=r['overlapAudit']['maxM']*1000,overlapFrames=r['overlapAudit']['framesOver10um'],cornerSpeeds5ms=[norm(early[n]['v']) for n in corners],cornerEnergyShares5ms=[en[n]/tot for n in corners],playbackNonzero=sum(b['state']!='pocketed' and any(abs(v)>1e-4 for v in b['v']+b['w']) for b in r['playbackEnd']))
 scalars.append(s);compact[key]=dict(s=s,board=r['board'],samples=[dict(zip(r['names'],x['states'])) for x in r['samples']],pocketed=r['pocketed'])
 if rid==11331:cases[f'{eps}-{rev}']=dict(s=s,trace=r['eventTrace'],rack=rack)
summary={};invariance={};epss=[.00025,.00010,.00005,.00001]
for eps in epss:
 a=[x for x in scalars if x['eps']==eps and not x['reverse']];done=[x for x in a if x['status']=='settled'];tails=sorted(x['tail'] for x in done)
 summary[str(eps)]=dict(n=len(a),settled=len(done),failures=dict(collections.Counter(x['termination'] for x in a if x['status']!='settled')),meanScore=st.mean(x['score'] for x in done),pass1p2=sum(x['score']>=1.2 for x in done),meanTail=st.mean(tails),p90Tail=tails[int(.9*(len(tails)-1))],maxTail=max(tails),tailOver5=sum(x>5 for x in tails),tailOver1=sum(x>1 for x in tails),scratch=sum(x['scratch'] for x in a),cpuMS=st.mean(x['cpuMS'] for x in a),medianCPU=st.median(x['cpuMS'] for x in a),meanPeakSpin=st.mean(x['peakSpin'] for x in a),positiveGapContacts=sum(x['positiveGapContacts'] for x in a),maxGapMM=max(x['maxGapMM'] for x in a),separatingContacts=sum(x['separatingContacts'] for x in a),maxOverlapMM=max(x['frameOverlapMM'] for x in a),overlapRuns=sum(x['overlapFrames']>0 for x in a),pairEnergyGainCount=sum(x['pairEnergyGainCount'] for x in a),maxPairEnergyGain=max(x['maxPairEnergyGain'] for x in a),playbackNonzero=sum(x['playbackNonzero'] for x in a),cornerSpeeds5ms=[st.mean(x['cornerSpeeds5ms'][i] for x in a) for i in [0,1]],cornerShares5ms=[st.mean(x['cornerEnergyShares5ms'][i] for x in a) for i in [0,1]])
 comparisons=[]
 for rid in range(11300,11340):
  a,b=compact[rid,eps,False],compact[rid,eps,True];same=set(a['board'])==set(b['board']);maxpos=max((math.dist(a['board'][n],b['board'][n])*L for n in a['board']),default=0) if same else None
  comparisons.append(dict(id=rid,samePocketed=a['pocketed']==b['pocketed'],boardWithin1mm=same and maxpos<=.001,maxBoardDistanceM=maxpos,earlyExact=a['samples']==b['samples'],earlyMaxVelocityDifference=max(math.dist(a['samples'][1][n]['v'],b['samples'][1][n]['v']) for n in a['samples'][1]),scoreDifference=b['s']['score']-a['s']['score']))
 invariance[str(eps)]=dict(n=len(comparisons),earlyExact=sum(x['earlyExact'] for x in comparisons),boardWithin1mm=sum(x['boardWithin1mm'] for x in comparisons),samePocketed=sum(x['samePocketed'] for x in comparisons),meanEarlyVelocityDifference=st.mean(x['earlyMaxVelocityDifference'] for x in comparisons),rows=comparisons)
rng=random.Random(20261027);draws=[[rng.randrange(200) for _ in range(200)] for _ in range(4000)];paired={}
for eps in epss[1:]:
 pairs=[(compact[i,.00025,False]['s'],compact[i,eps,False]['s']) for i in range(11300,11500)]
 if any(a['status']!='settled' or b['status']!='settled' for a,b in pairs):continue
 def ci(k):
  d=[b[k]-a[k] for a,b in pairs];vals=sorted(sum(d[i] for i in draw)/200 for draw in draws)
  return dict(mean=st.mean(d),ci95=[vals[100],vals[3899]])
 paired[str(eps)]={k:ci(k) for k in ['score','tail','cpuMS']}
assert len(scalars)==960
before=json.load(open(O/'production-before.json'));assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in before.items())
for name,value in [('scalars',scalars),('summary',summary),('invariance',invariance),('paired',paired),('case-11331',cases)]: (O/(name+'.json')).write_text(json.dumps(value,indent=2,allow_nan=False))
print(json.dumps(summary,indent=2));print('paired',json.dumps(paired));print('invariance',json.dumps({e:{k:v for k,v in a.items() if k!='rows'} for e,a in invariance.items()}))
