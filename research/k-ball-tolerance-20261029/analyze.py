from pathlib import Path
import json,math,struct,hashlib,collections
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/k-ball-tolerance-20261029'
def read(n):return json.loads((OUT/n).read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def f32(x):return struct.unpack('f',struct.pack('f',x))[0]
protocol=read('protocol.json');samples={r['id']:r for r in read('samples.json')};probes={p['id']:p for p in protocol['probes']}
assert len(probes)==120 and len(samples)==293
assert sha(OUT/'samples.json')==protocol['sourceTrialsSHA256']
bySample=collections.defaultdict(list);seen=set();count=0
for line in (OUT/'results.jsonl').open():
 r=json.loads(line);key=(r['sampleID'],r['probeID']);assert key not in seen;seen.add(key);count+=1
 source=samples[r['sampleID']];s=source['seed'];base=r['probeID']=='baseline'
 delta=[0]*4 if base else probes[r['probeID']]['delta'];d=list(map(f32,delta))
 v=f32(f32(s['v'])*f32(1+d[1]));sx=f32(f32(s['sx'])+d[2]);sy=f32(f32(s['sy'])+d[3]);actual=r['input']
 assert (v,sx,sy)==(actual['v'],actual['sx'],actual['sy']),(key,'parameter drift')
 expectedTheta=math.atan2(f32(s['dir'][1]),f32(s['dir'][0]))+math.radians(d[0])
 measuredTheta=math.atan2(actual['dir'][1],actual['dir'][0])
 angularError=math.atan2(math.sin(expectedTheta-measuredTheta),math.cos(expectedTheta-measuredTheta))
 assert abs(angularError)<8e-7,(key,'aim drift',angularError)
 if d[0]==0:assert actual['dir']==list(map(f32,s['dir']))
 ev=r['events'];assert all(math.isfinite(e['time']) for e in ev)
 assert all(a['time']<=b['time'] for a,b in zip(ev,ev[1:]))
 hits=[(i,e) for i,e in enumerate(ev) if e['kind']=='ballBall' and 'cueBall' in e['balls']]
 firstA=bool(hits) and set(hits[0][1]['balls'])=={'cueBall','object'}
 hit=next((i for i,e in hits if i>hits[0][0] and set(e['balls'])=={'cueBall','kTarget'}),None) if hits else None
 laterB=firstA and hit is not None
 potA=any(e['kind']=='pocket' and e['ball']=='object' and e['pocket']==f"pocket_{s['pocket']}" for e in ev)
 scratch=any(e['kind']=='pocket' and e['ball']=='cueBall' for e in ev)
 assert [r[k] for k in ['firstA','laterB','potA','scratch']]==[firstA,laterB,potA,scratch],key
 success=r['complete'] and firstA and laterB and potA and not scratch
 assert success==r['success'],key
 rails=[e['cushion'] for e in ev[hits[0][0]+1:hit] if e['kind']=='cushion' and e['ball']=='cueBall' and 0<=e['cushion']<6] if laterB else []
 assert rails==r['railsBeforeK'],key
 if r['reasons']!=['inaccessible']:
  expected=[name for name,flag in [('incomplete',not r['complete']),('wrong-first-ball',not firstA),('no-cue-B-contact',not laterB),('A-not-in-specified-pocket',not potA),('scratch',scratch)] if flag] if not success else []
  assert r['reasons']==expected,key
 if base:
  assert r['exactBaselineReplay'] and ev==source['events'] and r['success']==source['success'],key
 else:assert source['success']
 compact={k:r[k] for k in ['probeID','success','reasons','firstA','laterB','potA','scratch','railsBeforeK']}
 bySample[r['sampleID']].append(compact)
assert count==protocol['expectedSimulations'],count
for id,s in samples.items():assert {r['probeID'] for r in bySample[id]}==({'baseline'}|set(probes) if s['success'] else {'baseline'})
for source in read('source-binding.json')['sources']:assert sha(ROOT/source['path'])==source['sha256'],source['path']
assert sha(ROOT/'research/k-ball-tolerance-20261029/main.swift')==read('source-binding.json')['entrySHA256']

levels=['small','medium','large'];grades=['极敏感','敏感','常规','宽容'];details=[]
for id,s in samples.items():
 rr=[r for r in bySample[id] if r['probeID']!='baseline'];stats={};prefix=True;grade=0
 for li,level in enumerate(levels):
  joint=[r for r in rr if probes[r['probeID']]['level']==level and probes[r['probeID']]['kind']=='joint']
  axes={a:[r for r in rr if probes[r['probeID']]['level']==level and probes[r['probeID']]['axis']==a] for a in ['aim','speed','sx','sy']}
  endpoint=sum(r['success'] for rows in axes.values() for r in rows);n=sum(r['success'] for r in joint)
  passed=endpoint==8 and n>=26;prefix=prefix and passed
  if prefix:grade=li+1
  stats[level]=dict(jointPass=n,jointTotal=len(joint),axisPass={a:sum(r['success'] for r in ar) for a,ar in axes.items()},passLevel=passed)
 details.append(dict(id=id,regionID=s['regionID'],sourceID=s['sourceID'],pocket=s['seed']['pocket'],axis=s['axis'],railOrdinal=s['railOrdinal'],actualRails=s['expectedRails'],initialGap=s['initialGap'],sourceAngle=s['sourceAngle'],grade=grades[grade] if s['success'] else '基线失败',stats=stats,failures=dict(collections.Counter(reason for r in rr for reason in r['reasons'])),changedSuccessfulRoute=sum(r['success'] and r['railsBeforeK']!=s['railsBeforeK'] for r in rr)))
overall={}
allProbes=[r for rows in bySample.values() for r in rows if r['probeID']!='baseline']
for level in levels:
 types={}
 for axis in ['aim','speed','sx','sy','joint']:
  rr=[r for r in allProbes if probes[r['probeID']]['level']==level and probes[r['probeID']]['axis']==axis]
  types[axis]=dict(total=len(rr),success=sum(r['success'] for r in rr),failures=dict(collections.Counter(reason for r in rr for reason in r['reasons'])))
 overall[level]=types
def grouping(key):
 groups=collections.defaultdict(list)
 for d in details:
  if d['grade']!='基线失败':groups[key(d)].append(d)
 return {k:dict(samples=len(ds),grades=dict(collections.Counter(d['grade'] for d in ds)),mediumJointPass=sum(d['stats']['medium']['jointPass'] for d in ds),mediumJointTotal=len(ds)*32) for k,ds in groups.items()}
summary=dict(simulations=count,baselines=len(samples),perturbations=len(allProbes),gradedSamples=292,baselineFailures=1,grades=dict(collections.Counter(d['grade'] for d in details)),overall=overall,byRails=grouping(lambda d:str(d['actualRails'])),byPocket=grouping(lambda d:'中袋' if d['pocket'] in (4,5) else '角袋'),byTiming=grouping(lambda d:d['axis']),changedSuccessfulRoute=sum(d['changedSuccessfulRoute'] for d in details),nonmonotoneJointSamples=sum(any(d['stats'][b]['jointPass']>d['stats'][a]['jointPass'] for a,b in zip(levels,levels[1:])) for d in details if d['grade']!='基线失败'))
for name,obj in [('difficulty.json',details),('summary.json',summary),('audit.json',dict(passed=True,simulations=count,exactBaselines=293,positiveProbeSets=292,probesPerPositive=120,checks=['actual Float input perturbations and unchanged zero axes','all ordered event rules and overlapping failure flags','baseline events equal prior full simulation','complete deterministic probe coverage','successful changed routes counted not rejected','current physics and harness SHA binding'],sha256={n:sha(OUT/n) for n in ['protocol.json','samples.json','results.jsonl','source-binding.json']}))]:
 (OUT/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2))
print(json.dumps(summary,ensure_ascii=False,indent=2))
