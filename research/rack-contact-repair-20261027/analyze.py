from pathlib import Path
import json,gzip,math,statistics as st,collections,random,hashlib
O=Path('output/rack-contact-repair-20261027');cal=json.load(open('output/rack-center-mechanism-20261026/calibration.json'));rows={};scalars=[];diagnostics=[];allstatus=collections.Counter()
R=.028574999421834946;M=.17000000178813934;L=2.5399999618530273
norm=lambda v:math.sqrt(sum(x*x for x in v))
def ulp(x):return math.ldexp(1.,max(-126,math.frexp(abs(x))[1]-1)-23)
def energy(b):return .5*M*(sum(x*x for x in b['v'])+.4*R*R*sum(x*x for x in b['w']))
params=None
for line in gzip.open(O/'raw.jsonl.gz','rt'):
 r=json.loads(line);inp=r['input'];allstatus[r['status']]+=1
 if params is None:params=r['parameters']
 assert params==r['parameters']
 if inp['experiment']=='diagnostic':diagnostics.append(r);continue
 rid=inp['rackID'];label=inp['experiment'];condition=inp['condition'];pts=[p for n,p in r['board'].items() if n!='cueBall'];N=len(pts)
 score=st.mean(min(math.dist(a,b)*L for j,b in enumerate(pts) if i!=j) for i,a in enumerate(pts))/cal['reference'][str(N)]['expectedMeanM'] if N>1 else None
 stats=dict(pairContacts=0,nonApproaching=0,positiveGapOver1um=0,gapBeyondRoundoff=0,maxGapM=0.,maxOverlapM=0.,maxPairEnergyGain=0.,pairEnergyGains=0,maxMomentumResidual=0.)
 for e in r['eventTrace']:
  if e['kind']!='ball':continue
  a,b=e['preA'],e['preB'];aa,bb=e['beforeKissA'],e['beforeKissB'];dp=[b['p'][i]-a['p'][i] for i in [0,2]];d=norm(dp);closing=-sum(dp[j]*(b['v'][i]-a['v'][i]) for j,i in enumerate([0,2]))/d
  gap=math.hypot(bb['p'][0]-aa['p'][0],bb['p'][2]-aa['p'][2])-2*R
  budget=4*(math.hypot(ulp(aa['p'][0])+ulp(bb['p'][0]),ulp(aa['p'][2])+ulp(bb['p'][2]))+ulp(R))
  gain=energy(e['postA'])+energy(e['postB'])-energy(a)-energy(b)
  mom=norm([M*(e['postA']['v'][i]+e['postB']['v'][i]-a['v'][i]-b['v'][i]) for i in range(3)])
  stats['pairContacts']+=1;stats['nonApproaching']+=closing<=0;stats['positiveGapOver1um']+=gap>1e-6;stats['gapBeyondRoundoff']+=gap>budget+1e-14;stats['maxGapM']=max(stats['maxGapM'],gap);stats['maxOverlapM']=max(stats['maxOverlapM'],-gap);stats['maxPairEnergyGain']=max(stats['maxPairEnergyGain'],gain);stats['pairEnergyGains']+=gain>1e-6;stats['maxMomentumResidual']=max(stats['maxMomentumResidual'],mom)
 canonical=r['canonicalNames'];early=dict(zip(r['names'],r['samples'][1]['states']));en={n:sum(v*v for v in early[n]['v']) for n in canonical};total=sum(en.values());corners=[canonical[i] for i in [10,14]]
 s=dict(id=rid,cohort='old' if rid<20000 else 'new',label=label,condition=condition,status=r['status'],termination=r['termination'],score=score,tail=max(x['tail'] for x in r['spinTail']),peakSpin=max(x['peakWy'] for x in r['spinTail']),duration=r['duration'],scratch=r['cueScratched'],cpuMS=r['cpuSeconds']*1000,lastTranslation=r['lastTranslation'],rejected=len(r['rejectedPairs']),frameOverlapM=r['overlapAudit']['maxM'],cornerSpeeds=[norm(early[n]['v']) for n in corners],cornerShares=[en[n]/total for n in corners],**stats)
 scalars.append(s)
 rows[rid,label,condition]=dict(s=s,board=r['board'],samples=[dict(zip(r['names'],x['states'])) for x in r['samples']],pocketed=r['pocketed'],duration=r['duration'],frames=r.get('frames'),events=r['eventTrace'],names=r['names'],initialCueVelocity=r['initialCueVelocity'],rack=r['rack'],rejected=r['rejectedPairs'])
summary={}
for cohort in ['old','new','all']:
 summary[cohort]={}
 for label in ['production','repair']:
  a=[s for s in scalars if s['label']==label and s['condition']=='original' and (cohort=='all' or s['cohort']==cohort)];done=[s for s in a if s['status']=='settled'];tails=sorted(s['tail'] for s in done)
  summary[cohort][label]=dict(n=len(a),settled=len(done),meanScore=st.mean(s['score'] for s in done),pass1p2=sum(s['score']>=1.2 for s in done),meanTail=st.mean(tails),p90Tail=tails[int(.9*(len(tails)-1))],maxTail=max(tails),tailOver5=sum(t>5 for t in tails),tailOver1=sum(t>1 for t in tails),scratch=sum(s['scratch'] for s in a),cpuMS=st.mean(s['cpuMS'] for s in a),meanPeakSpin=st.mean(s['peakSpin'] for s in a),cornerSpeeds=[st.mean(s['cornerSpeeds'][i] for s in a) for i in [0,1]],cornerShares=[st.mean(s['cornerShares'][i] for s in a) for i in [0,1]])
# Full-shot physical audit, including all alternate registration orders/mirrors.
a=[s for s in scalars if s['label']=='repair'];audit=dict(runs=len(a),parameters=params,allStatuses=dict(allstatus),**{k:sum(s[k] for s in a) for k in ['pairContacts','nonApproaching','positiveGapOver1um','gapBeyondRoundoff','pairEnergyGains','rejected']},**{k:max(s[k] for s in a) for k in ['maxGapM','maxOverlapM','maxPairEnergyGain','maxMomentumResidual','frameOverlapM']})
# Match identities, not array slots; a mirror flips polar and axial vectors differently.
def transform(b,mirror):
 if not mirror:return b
 b=dict(b);b['p']=[b['p'][0],b['p'][1],-b['p'][2]];b['v']=[b['v'][0],b['v'][1],-b['v'][2]];b['w']=[-b['w'][0],-b['w'][1],b['w'][2]];return b
invariance={}
for condition in ['reverse','shuffle','mirror']:
 checks=[]
 for (rid,label,c),r in rows.items():
  if label!='repair' or c!=condition:continue
  a=rows[rid,'repair','original'];mirror=condition=='mirror';same=a['pocketed']==r['pocketed'];maxpos=max((math.dist(p,[r['board'][n][0],.5-r['board'][n][1]] if mirror else r['board'][n])*L for n,p in a['board'].items()),default=0) if same else None
  sampleExact=all(aa=={n:transform(b,mirror) for n,b in bb.items()} for aa,bb in zip(a['samples'],r['samples']))
  # Canonical event sequence and every recorded before/after state.
  def canon(e):
   e=dict(e)
   if e['kind']=='ball':
    e.pop('beforeKissA');e.pop('beforeKissB')
    for prefix in ['pre','post']:
     x,y=transform(e.pop(prefix+'A'),mirror),transform(e.pop(prefix+'B'),mirror);e[prefix]={x['name']:x,y['name']:y}
   else:
    e.pop('normal',None);e.pop('index',None)
    e['pre']=transform(e['pre'],mirror);e['post']=transform(e['post'],mirror)
   return e
  # Original event list uses no mirror transform.
  def originalcanon(e):
   nonlocal_placeholder=0
   e=dict(e)
   if e['kind']=='ball':
    e.pop('beforeKissA');e.pop('beforeKissB')
    for prefix in ['pre','post']:
     x,y=e.pop(prefix+'A'),e.pop(prefix+'B');e[prefix]={x['name']:x,y['name']:y}
   else:e.pop('normal',None);e.pop('index',None)
   return e
  traceExact=[originalcanon(e) for e in a['events']]==[canon(e) for e in r['events']]
  checks.append(dict(id=rid,samplesExact=sampleExact,fullContactTraceExact=traceExact,samePocketed=same,boardWithin1um=same and maxpos<=1e-6,maxBoardDifferenceM=maxpos,durationExact=a['duration']==r['duration']))
 invariance[condition]=dict(n=len(checks),samplesExact=sum(c['samplesExact'] for c in checks),fullContactTraceExact=sum(c['fullContactTraceExact'] for c in checks),boardWithin1um=sum(c['boardWithin1um'] for c in checks),durationExact=sum(c['durationExact'] for c in checks),maxBoardDifferenceM=max(c['maxBoardDifferenceM'] or 0 for c in checks),rows=checks)
paired={};rng=random.Random(20261027)
for cohort in ['old','new','all']:
 ids=[s['id'] for s in scalars if s['condition']=='original' and s['label']=='production' and (cohort=='all' or s['cohort']==cohort)];draws=[[rng.randrange(len(ids)) for _ in ids] for _ in range(4000)]
 def ci(k):
  d=[rows[i,'repair','original']['s'][k]-rows[i,'production','original']['s'][k] for i in ids];bs=sorted(sum(d[j] for j in v)/len(d) for v in draws)
  return dict(mean=st.mean(d),ci95=[bs[100],bs[3899]])
 paired[cohort]={k:ci(k) for k in ['score','tail','cpuMS']}
for n,v in [('summary',summary),('scalars',scalars),('audit',audit),('invariance',invariance),('paired',paired),('diagnostics',diagnostics)]: (O/(n+'.json')).write_text(json.dumps(v,indent=2,allow_nan=False))
print(json.dumps(dict(summary=summary,audit=audit,invariance={k:{x:y for x,y in v.items() if x!='rows'} for k,v in invariance.items()},paired=paired),indent=2))
