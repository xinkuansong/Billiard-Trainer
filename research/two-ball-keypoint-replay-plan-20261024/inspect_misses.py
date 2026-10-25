from pathlib import Path
import json,gzip,collections,math
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'output/two-ball-strike-sampled100-20261024'
groups={k:collections.defaultdict(collections.Counter) for k in ['speed','angle','pocket','sideSpin','verticalSpin','objectPocketDistance']}; facts=collections.Counter();examples={};total=0
for i in [round(i*1356/11) for i in range(12)]:
 with gzip.open(BASE/'parts'/f'{i:05d}.jsonl.gz','rt') as f:
  for line in f:
   b=json.loads(line);board=b['board'];angle=abs(board['angle']);op=math.dist(board['object'],board['aim'])
   for r in b['rows']:
    total+=1;v=r['velocity'];x=abs(r['spinX']);y=r['spinY'];miss=r['status']=='target_miss'
    keys=dict(speed='0.6–1.0' if v<1 else '1.0–2.0' if v<2 else '2.0–3.0' if v<3 else '3.0–4.5',angle='0–10' if angle<10 else '10–20' if angle<20 else '20–40' if angle<40 else '40–60' if angle<60 else '60–85',pocket='middle' if board['pocket']>=4 else 'corner',sideSpin='<0.15' if x<.15 else '0.15–0.35' if x<.35 else '>=0.35',verticalSpin='<-0.2' if y<-.2 else '-0.2–0.2' if y<.2 else '>=0.2',objectPocketDistance='<0.6m' if op<.6 else '0.6–1.0m' if op<1 else '>=1.0m')
    for key,label in keys.items():
     c=groups[key][label];c['total']+=1;c['targetMiss']+=miss;c['notPottedSelected']+=not r['targetPottedSelected'];c['success']+=r['usableForPositionMatch']
    if miss:
     if r['velocity']<1:facts['speedUnder1']+=1
     if r['cueTargetContactCount']==1 and r['objectCushionTotal']==0 and r['targetActualPocket'] is None and r['termination']=='settled':
      u=[(board['aim'][k]-board['object'][k])/op for k in range(2)];delta=[r['objectEndPosition'][k]-board['object'][k] for k in range(2)]
      along=sum(u[k]*delta[k] for k in range(2));lateral=abs(u[0]*delta[1]-u[1]*delta[0])
      if 0<along<op-.05 and lateral<.028575:
       facts['settledNoRailSingleContactWithinRadiusOfAimLineAndMoreThan5cmShort']+=1
     facts['targetMiss']+=1;facts['contacted']+=r['cueTargetContactCount']>0;facts['noContact']+=r['cueTargetContactCount']==0;facts['wrongPocket']+=r['targetActualPocket'] is not None;facts['noPocket']+=r['targetActualPocket'] is None;facts['hasObjectCushion']+=r['objectCushionTotal']>0;facts['noObjectCushion']+=r['objectCushionTotal']==0
     objEvents=[e for e in r['events'] if e['kind']=='cushion' and e['ball']=='object'];facts['hasObjectJaw']+=any(e['surface']=='jaw' for e in objEvents);facts['hasObjectMainRail']+=any(e['surface']=='mainRail' for e in objEvents)
     key='noContact' if r['cueTargetContactCount']==0 else 'noObjectCushion' if r['objectCushionTotal']==0 else 'hasObjectCushion'
     if key not in examples:examples[key]=dict(board=board,row=r)
res=dict(sampleAttempts=total,scope='Same 12 spread-out shards / 1200 layouts; descriptive correlations only, not full-bank rates or causal diagnosis',groups={k:{l:dict(c,missPercent=100*c['targetMiss']/c['total']) for l,c in g.items()} for k,g in groups.items()},missFacts=dict(facts),examples=examples)
Path(__file__).with_name('miss-inspection.json').write_text(json.dumps(res,indent=2));print(json.dumps({k:v for k,v in res.items() if k!='examples'},indent=2))
