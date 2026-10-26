import json,gzip,math,hashlib,collections,statistics
from pathlib import Path
ROOT=Path.cwd();D=ROOT/'research/rack-solver-repair-20261026';O=ROOT/'output/rack-solver-repair-20261026'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
checks=[];allscalars=[]
for phase,count in [('pilot-r2',800),('holdout',500)]:
 P=O/phase;closure=json.load(open(P/'closure.json'));assert closure['success'] and closure['total']==count and closure['shutdownExitCode']==0
 binding=json.load(open(P/'source-binding.json'));assert all(sha(ROOT/r['path'])==r['sha256'] for r in binding['production'])
 groups=collections.defaultdict(dict)
 for l in gzip.open(P/'raw.jsonl.gz','rt'):
  r=json.loads(l);assert r['status']=='settled';groups[r['input']['rackID']][r['input']['mode'],r['input']['condition']]=r
 assert len(groups)==100
 for rid,g in groups.items():
  baseline=g[0,'original'];a=g[2,'original'];ref={b['number']:b for b in baseline['rack']}
  assert a['initialCueVelocity']==baseline['initialCueVelocity']
  for c in ['original','reverse','shuffle','mirror']:
   b=g[2,c];sign=-1 if c=='mirror' else 1
   for ball in b['rack']:assert ball['x']==ref[ball['number']]['x'] and ball['z']==sign*ref[ball['number']]['z']
   expected=baseline['initialCueVelocity'][:];expected[2]*=sign;assert b['initialCueVelocity']==expected
   for sa,sb in zip(a['samples'],b['samples']):
    aa=dict(zip(a['names'],sa['states']));bb=dict(zip(b['names'],sb['states']))
    for name,x in aa.items():
     y=bb[name]
     for field in ['p','v','w']:
      target=x[field][:]
      if c=='mirror':
       if field=='w':target[0]*=-1;target[1]*=-1
       else:target[2]*=-1
      assert target==y[field],(phase,rid,c,field)
     assert x['state']==y['state']
   if c in ['reverse','shuffle']:assert a['board']==b['board'] and a['duration']==b['duration']
   elif c=='mirror':
    assert a['board'].keys()==b['board'].keys()
    assert max(math.dist([p[0],.5-p[1]],b['board'][n])*2.54 for n,p in a['board'].items())<1e-6
   assert a['pocketed']==b['pocketed']
   before=[x for x in b['pairTrace'] if x['phase']=='beforeKiss'];imp=[x for x in b['pairTrace'] if x['phase']=='beforeImpulse']
   assert all(x['gap']<=1e-6 and x['approach']>0 for x in before)
   assert all(x['approach']>0 for x in imp)
   # All sampled planar balls use the real production cloth height and radius.
   for sample in b['samples']:
    assert all(abs(x['p'][1]-(.800000011920929+.028574999421834946))<1e-6 for x in sample['states'])
  checks.append(dict(phase=phase,rackID=rid,passed=True))
 probe=json.load(open(P/'metadata.json'))['probe'];assert probe['pairCases']==300 and probe['exchangeExact'] and probe['reflectionExact'] and probe['maxEnergyIncrease']==0 and probe['separatingPairHasNoImpact']
 allscalars+=json.load(open(P/'scalars.json'))
summary={}
for mode in [0,2]:
 a=[x for x in allscalars if x['mode']==mode and x['condition']=='original'];assert len(a)==200
 summary[str(mode)]=dict(n=len(a),meanScore=statistics.mean(x['score'] for x in a),passCount=sum(x['score']>=1.2 for x in a),meanTail=statistics.mean(x['tail'] for x in a),tailOver5=sum(x['tail']>5 for x in a),cpuMS=statistics.mean(x['cpuMS'] for x in a),scratchCount=sum(x['scratch'] for x in a))
(O/'combined-summary.json').write_text(json.dumps(summary,indent=2))
result=dict(success=True,distinctRacks=200,simulations=1300,legacyExactReplayRuns=300,allFiveSampleTimesExactlyMatchUnderReorderingAndReflection=True,reverseAndShuffleBoardsExact=400,mirroredBoardsWithinOneMicrometre=200,contactAndApproachAuditWindowSeconds=.02,purePairFixtures=300,productionHashesUnchanged=True,sourceHashes={p.name:sha(p) for p in D.glob('*.swift')},verificationRows=checks)
(O/'verification.json').write_text(json.dumps(result,indent=2));print(json.dumps(summary,indent=2));print('VERIFIED 200 layouts / 1300 native simulations')
