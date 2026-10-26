from pathlib import Path
import gzip,json,hashlib,collections,math
O=Path('output/rack-solver-invariance-20261026');D=Path('research/rack-solver-invariance-20261026')
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
closure=json.load(open(O/'closure.json'));assert closure==dict(success=True,total=400,baselineReplays=100,shutdownExitCode=0)
assert json.load(open(O/'repeat-verification.json'))['exactRuns']==12
binding=json.load(open(O/'source-binding.json'));assert all(sha(r['path'])==r['sha256'] for r in binding['production'])
# Show the research engine differs only by three observation calls and appended observer.
s=(D/'EventDrivenEngine.swift').read_text();s=s[:s.index('\n// Research-only observer.')]
for phase,marker in [('beforeKiss','        InvarianceTrace.pair("beforeKiss",a:stateA,b:stateB,now:currentTime)\n'),('beforeImpulse','        InvarianceTrace.pair("beforeImpulse",a:stateA,b:stateB,now:currentTime)\n'),('afterImpulse','        InvarianceTrace.pair("afterImpulse",a:stateA,b:stateB,now:currentTime)\n')]:
 assert s.count(marker)==1;s=s.replace(marker,'')
assert s==(Path('QiuJi/Core/Physics/EventDrivenEngine.swift').read_text())
groups=collections.defaultdict(dict);events=collections.Counter();highGap=collections.defaultdict(collections.Counter)
for line in gzip.open(O/'raw.jsonl.gz','rt'):
 r=json.loads(line);assert r['status']=='settled';condition=r['input']['condition'];groups[r['input']['rackID']][condition]=r
 for j in range(0,len(r['pairTrace']),3):
  a,b,c=r['pairTrace'][j:j+3];assert a['phase']=='beforeKiss' and b['phase']=='beforeImpulse' and c['phase']=='afterImpulse'
  for threshold in [1e-6,5e-5,1e-4]:
   if a['gap']>threshold:highGap[condition][str(threshold)]+=1
  events[condition]+=1
mirrorStrikeDeltas=[]
for group in groups.values():
 b=group['original'];assert len(group)==4
 for c,r in group.items():
  assert r['canonicalNames']==b['canonicalNames']
  original=[x['number'] for x in b['rack']];expected=original[::-1] if r['input']['reverse'] else original
  assert [x['number'] for x in r['rack']]==expected
  sign=-1 if r['input']['mirror'] else 1
  assert r['cue'][0]==b['cue'][0] and r['cue'][1]==sign*b['cue'][1]
  assert r['direction'][0]==b['direction'][0] and r['direction'][1]==sign*b['direction'][1]
  # Reflection of the strike uses same power and zero spin.
  assert r['power']==10 and r['spin']==[0,0]
  dv=math.sqrt(sum((r['initialCueVelocity'][i]-b['initialCueVelocity'][i]*(sign if i==2 else 1))**2 for i in range(3)))
  if r['input']['mirror']:mirrorStrikeDeltas.append(dv)
  else:assert dv==0
assert len(groups)==100
out=dict(success=True,samples=100,runs=400,baselineExactReplays=100,repeatExactReplays=12,observationalEngineDiffVerified=True,productionHashesUnchanged=True,rackAimTransformsVerified=True,reverseInitialVelocityExact=True,mirrorInitialVelocityExact=all(v==0 for v in mirrorStrikeDeltas),mirrorInitialVelocityMaxDeltaMPS=max(mirrorStrikeDeltas),mirrorCausalAttribution='not isolated: strike trigonometry introduces numerical differences',events=dict(events),beforeCorrectionPositiveGapCounts=dict(highGap),files={str(p):sha(p) for p in [*D.glob('*.py'),*D.glob('*.swift'),O/'raw.jsonl.gz',O/'summary.json']})
(O/'verification.json').write_text(json.dumps(out,indent=2));print(json.dumps({k:v for k,v in out.items() if k!='files'},indent=2))
