import gzip,json,math,statistics,collections,sys
from pathlib import Path
O=Path('output/rack-solver-repair-20261026')/sys.argv[1]
R=.028574999421834946;L=2.5399999618530273;W=1.2699999809265137
cal=json.load(open('output/rack-center-mechanism-20261026/calibration.json'))
rows=[json.loads(l) for l in gzip.open(O/'raw.jsonl.gz','rt')]
dist=math.dist;groups=collections.defaultdict(dict);scalars=[]
for r in rows:
 mode=r['input']['mode'];c=r['input']['condition'];rid=r['input']['rackID'];groups[rid][mode,c]=r
 points=[[p[0]*L-L/2,p[1]*L-W/2] for n,p in r['board'].items() if n!='cueBall'];N=len(points)
 score=statistics.mean(min(dist(a,b) for j,b in enumerate(points) if i!=j) for i,a in enumerate(points))/cal['reference'][str(N)]['expectedMeanM'] if N>1 else None
 before=[x for x in r['pairTrace'] if x['phase']=='beforeKiss'];bi=[x for x in r['pairTrace'] if x['phase']=='beforeImpulse']
 neg=[x for x in bi if x['approach'] < -1e-4];far=[x for x in before if x['gap']>1e-6]
 ss=dict(zip(r['names'],r['samples'][1]['states']));e={n:sum(x*x for x in ss[n]['v']) for n in r['canonicalNames']};total=sum(e.values())
 scalars.append(dict(rackID=rid,mode=mode,condition=c,status=r['status'],termination=r['termination'],score=score,tail=max(x['tail'] for x in r['spinTail']),cpuMS=r['cpuSeconds']*1000,scratch=r['cueScratched'],rejected=len(r['rejectedPairs']),far=len(far),maxGap=max([x['gap'] for x in before],default=0),separating=len(neg),energy10=e[r['canonicalNames'][10]]/total,energy14=e[r['canonicalNames'][14]]/total))
comparisons=[]
for rid,rs in groups.items():
 for mode in [0,1,2]:
  if (mode,'reverse') not in rs:continue
  a=rs[mode,'original'];ss=dict(zip(a['names'],a['samples'][1]['states']))
  for c in ['reverse']+(['mirror','shuffle'] if mode==2 else []):
   b=rs[mode,c];bb=dict(zip(b['names'],b['samples'][1]['states']));dp=dv=dw=0
   for n,x in ss.items():
    p=x['p'][:];v=x['v'][:];w=x['w'][:]
    if c=='mirror':p[2]*=-1;v[2]*=-1;w[0]*=-1;w[1]*=-1
    dp=max(dp,dist(p,bb[n]['p']));dv=max(dv,dist(v,bb[n]['v']));dw=max(dw,dist(w,bb[n]['w']))
   boarddelta=0
   for n in a['board'].keys()&b['board'].keys():
    p=a['board'][n][:]
    if c=='mirror':p[1]=.5-p[1]
    boarddelta=max(boarddelta,dist(p,b['board'][n])*L)
   comparisons.append(dict(rackID=rid,mode=mode,condition=c,earlyPass=dp<=1e-6 and dv<=1e-4 and dw<=.01,boardPass=a['board'].keys()==b['board'].keys() and boarddelta<=.001,dp=dp,dv=dv,dw=dw,boardDelta=boarddelta,pocketedMatch=a['pocketed']==b['pocketed']))
summary={}
for key in sorted({(r['mode'],r['condition']) for r in scalars}):
 a=[x for x in scalars if (x['mode'],x['condition'])==key];cc=[x for x in comparisons if (x['mode'],x['condition'])==key]
 out=dict(n=len(a),settled=sum(x['status']=='settled' for x in a),failures=dict(collections.Counter(x['termination'] for x in a if x['status']!='settled')),meanScore=statistics.mean(x['score'] for x in a),passed=sum(x['score']>=1.2 for x in a),meanTail=statistics.mean(x['tail'] for x in a),tailOver5=sum(x['tail']>5 for x in a),cpuMS=statistics.mean(x['cpuMS'] for x in a),scratch=sum(x['scratch'] for x in a),farImpulses=sum(x['far'] for x in a),maxGap=max(x['maxGap'] for x in a),separating=sum(x['separating'] for x in a),rejected=sum(x['rejected'] for x in a),energy10=statistics.mean(x['energy10'] for x in a),energy14=statistics.mean(x['energy14'] for x in a))
 if cc:out.update(earlyPass=sum(x['earlyPass'] for x in cc),boardPass=sum(x['boardPass'] for x in cc),maxVelocityDelta=max(x['dv'] for x in cc),maxBoardDelta=max(x['boardDelta'] for x in cc))
 summary[str(key)]=out
for n,d in [('summary',summary),('scalars',scalars),('comparisons',comparisons)]: (O/(n+'.json')).write_text(json.dumps(d,indent=2))
print(json.dumps(summary,indent=2))
