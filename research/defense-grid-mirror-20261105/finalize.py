"""Publish an independently replay-verified fixed-mirror grid bank to staging."""
from pathlib import Path
import copy,gzip,hashlib,importlib.util,json,sys,math,collections
from prepare import OUT,ROOT,enc,write,digest,key

def main():
 replay=json.loads((OUT/'replay-results.json').read_bytes())
 repair=json.loads((OUT/'repair-results.json').read_bytes()) if replay['failures'] else dict(repairs=[],rejected=[])
 repaired={r['referenceID']:r for r in repair['repairs']};rejected={r['referenceID'] for r in repair['rejected']}
 assert not set(repaired)&rejected
 assert set(repaired)|rejected=={r['referenceID'] for r in replay['failures']}
 geometry=json.loads((OUT/'native-geometry.json').read_bytes())
 def gap(p):
  def distance(line):
   a,b=line['start'],line['end'];d=[b[i]-a[i] for i in range(2)];v=[p[i]-a[i] for i in range(2)];t=max(0,min(1,sum(v[i]*d[i] for i in range(2))/sum(x*x for x in d)))
   return math.dist(p,[a[i]+t*d[i] for i in range(2)])
  return min(map(distance,geometry['linear'][:6]))-.028575
 def tactics(q,r,patch):
  final={b['number']:b['position'] for b in patch['expected']['finalBalls']};enemy=patch['effect']['opponentBallNumber'];potted=patch['expected']['pocketedBallNumbers'];c,t=final[0],final[enemy];block=patch['effect']['fullDirectBlock'];tags=[]
  if block:tags.append('block')
  if math.dist(c,t)>=1.27:tags.append('distance')
  if gap(c)<=.028575:tags.append('cue-rail')
  if gap(t)<=.028575:tags.append('target-rail')
  if not block:tags.append('angle')
  if q['opponentBallNumber']!=8 and q['opponentBallNumber'] in potted:tags.append('pot-opponent')
  elif q['opponentBallNumber'] not in potted:
   old=next(b['position'] for b in q['balls'] if b['number']==q['opponentBallNumber']);a=min(math.dist(old,p) for p in geometry['pockets']);b=min(math.dist(final[q['opponentBallNumber']],p) for p in geometry['pockets'])
   if a<.3 and b>a+.2:tags.append('remove-threat')
  return tags
 rows=json.loads((OUT/'trajectory-candidate.json').read_bytes());free=json.loads((OUT/'free-candidate.json').read_bytes())
 meta={x['newID']:x for x in json.loads((OUT/'mirror-and-dedup-ledger.json').read_bytes())}
 maps=json.loads((OUT/'geometry-maps.json').read_bytes())
 originalRows=rows
 for q in rows:
  q['references']=[r for r in q['references'] if r['id'] not in rejected]
  m=meta[q['id']];mapping=maps[f"{m['sx']},{m['sz']}"]
  for r in q['references']:
   patch=repaired.get(r['id'])
   r['id']=digest(r['parameters'])
   if patch:
    r['expected']=patch['expected'];r['effect']=patch['effect'];r['execution']['mainCushionsByBall']=patch['mainCushionsByBall'];r['execution']['mainCushionCount']=sum(patch['mainCushionsByBall'].values());r['execution']['totalTravelMeters']=patch['totalTravelMeters'];r['tactics']=tactics(q,r,patch)
    r['selectionProbes']=patch['probes'];r['selectionProbePolicyVersion']='fixed-mirror-actual-replay-geometry-probes-v1'
    # Probe geometry was evaluated natively; enforce original contact-angle cap.
    own=next(b['position'] for b in q['balls'] if b['number']==q['ownBallNumber']);v=[own[i]-q['cue'][i] for i in range(2)]
    angle=math.atan2(r['parameters']['direction'][1],r['parameters']['direction'][0])
    for probe in r['selectionProbes']:
     theta=angle+math.radians(probe['angleDeltaDegrees']);perp=abs(v[0]*math.sin(theta)-v[1]*math.cos(theta));cut=math.degrees(math.asin(min(1,perp/(2*.028575))))
     if cut>60:probe.update(qualifies=False,status='too-thin')
    continue
   for e in r['expected']['events']:
    if e.get('railIndex') is not None:e['railIndex']=mapping['rails'][e['railIndex']]
    if e.get('pocketIndex') is not None:
     old=e['pocketIndex'];n=int(old.removeprefix('pocket_')) if isinstance(old,str) else old
     e['pocketIndex']=mapping['pockets'][n]
 assert len(rows)==replay['questions'] and sum(len(q['references']) for q in rows)==replay['references']-len(rejected)
 dropped=[q['id'] for q in rows if not q['references']];rows=[q for q in rows if q['references']]
 write('qualified-replay.json',dict(passed=True,directlyMatched=replay['references']-len(replay['failures']),rebuiltAndRequalified=len(repaired),rejectedReferenceIDs=sorted(rejected),droppedTrajectoryQuestionIDs=dropped,trajectoryQuestions=len(rows),references=sum(len(q['references']) for q in rows),counts=dict(collections.Counter(q['kind'] for q in rows))))
 spec=importlib.util.spec_from_file_location('bank',ROOT/'research/defense-no-recontact-522-20261104/bank.py');b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
 coverage=[dict(id=q['id'],kind=q['kind'],sampleID=q['sampleID'],status='found',referenceCount=len(q['references'])) for q in rows]
 provenance=dict(operation='offline-fixed-mirror-then-role-grid20-dedup-v1',selection=digest(json.loads((OUT/'selection.json').read_bytes())),nativeReplaySHA256=hashlib.sha256((OUT/'replay-results.json').read_bytes()).hexdigest(),nativeSourceManifestSHA256=hashlib.sha256((OUT/'source-manifest.json').read_bytes()).hexdigest(),originalSourceFingerprint='8ade37155415125b2e59f50b9550802e9c70d7192fcd795db4cc7e3f85872565')
 idx=b.export(rows,coverage,OUT/'bank',provenance)
 sys.path.insert(0,str(ROOT/'scripts/defense-bank'));from pack import audit
 result=audit(OUT/'bank');write('bank/audit.json',dict(result,nativeReplay=True,forbiddenReferences=0))
 stage=OUT/'app-package';stage.mkdir(exist_ok=True)
 payload={'schema':idx['schema'],'sourceFingerprint':idx['fingerprint'],'questions':rows}
 for name,value in [('defense-practice-bank.json.gz',payload),('defense-free-bank.json.gz',free)]:
  (stage/name).write_bytes(gzip.compress(enc(value),mtime=0))
 hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in stage.glob('*.gz')}
 report=dict(referenceQuestions=len(rows),references=sum(len(q['references']) for q in rows),freeQuestions=len(free),sourceFingerprint=idx['fingerprint'],outputSHA256=hashes,provenance=provenance)
 write('app-package/defense-practice-provenance.json',report);print(json.dumps(report,indent=2))
if __name__=='__main__':main()
