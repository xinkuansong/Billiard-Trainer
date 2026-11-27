"""Filter existing simple references by direct first-contact geometric thickness."""
from pathlib import Path
import hashlib,json,math,struct
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'output/defense-tactics-20-20261104/r4-simple'
OUT=SRC.parent/'r5-thickness'
(OUT/'questions').mkdir(parents=True,exist_ok=True)
read=lambda p:json.loads(p.read_text())
f32=lambda x:struct.unpack('f',struct.pack('f',x))[0]
R=f32(read(ROOT/'output/defense-pocket-cleanup-20261104/geometry.json')['radius'])
policy=dict(scope='Existing simple references only; no new physics/search',sourceReferenceCount=23,maxMainCushionsPerBall=1,maxMainCushionsTotal=2,maximumFirstContactCutDegrees=60,minimumProjectedThicknessFraction=1-math.sin(math.pi/3),removed=[],kept=[],sourceHashes={})
for name in ['samples.json','selection.json','source-manifest.json']:
 p=SRC/name;(OUT/name).write_bytes(p.read_bytes());policy['sourceHashes'][name]=hashlib.sha256(p.read_bytes()).hexdigest()
for p in sorted((SRC/'questions').glob('*.json')):
 d=read(p);q=d['input'];retained=[];rejected=[]
 policy['sourceHashes']['questions/'+p.name]=hashlib.sha256(p.read_bytes()).hexdigest()
 for i,r in enumerate(d['references']):
  first=next(e for e in r['events'] if e['kind']=='ballBall')
  # This calculation requires an unobstructed straight inbound trajectory.
  assert not any(e['kind']=='cushion' and e['time']<first['time'] for e in r['events'])
  assert r['shot']['spinX']==0
  cue=next(k for k in r['paths'] if not k.startswith('_'));own=f"_{q['numbers'][q['own']]}"
  assert set(first['balls'])=={cue,own}
  c=[f32(x) for x in q['cue']];t=[f32(x) for x in q['positions'][q['own']]]
  direction=r['shot']['direction'];n=math.hypot(*direction);u=[x/n for x in direction]
  delta=[t[j]-c[j] for j in range(2)];along=sum(delta[j]*u[j] for j in range(2));impact=abs(delta[0]*u[1]-delta[1]*u[0])
  ratio=impact/(2*R);assert 0<=ratio<1 and along>0
  cut=math.degrees(math.asin(ratio));thickness=1-ratio
  travel=along-math.sqrt((2*R)**2-impact**2);contact=[c[j]+u[j]*travel for j in range(2)]
  assert abs(math.dist(contact,t)-2*R)<1e-9
  # ShotPredictor.polyline uses 120 Hz samples then simplifies them. Its vertices
  # are NOT collision-time states, so nearest-vertex distance is diagnostic only.
  residual=min(math.dist(contact,p) for p in r['paths'][cue])
  # Use only the initial contiguous portion; a later return may cross that range.
  for vertex in r['paths'][cue]:
   projection=sum((vertex[j]-c[j])*u[j] for j in range(2))
   if projection>=travel-1e-5:break
   assert abs((vertex[0]-c[0])*u[1]-(vertex[1]-c[1])*u[0])<1e-5
  normal=[(t[j]-contact[j])/(2*R) for j in range(2)]
  dot=max(-1,min(1,sum(normal[j]*u[j] for j in range(2))))
  assert abs(math.degrees(math.acos(dot))-cut)<1e-5
  contactInfo=dict(cutDegrees=cut,projectedThicknessFraction=thickness,impactOffsetMeters=impact,contactCenter=contact,nearestRenderedVertexMeters=residual,method='Geometric straight inbound cue-center ray vs radius-sum circle; no precontact cushion, no side spin; rendered vertices are sampled, not exact collision frames; not pocketing angle')
  r['firstContact']=contactInfo
  entry=dict(sampleID=q['sampleID'],referenceIndex=i,shot=r['shot'],firstContact=contactInfo)
  if cut<=60:retained.append(r);policy['kept'].append(entry)
  else:rejected.append(entry);policy['removed'].append(entry)
 d['references']=retained;d['thicknessSelection']=dict(sourceReferenceCount=d['summary']['referenceCount'],removed=rejected)
 d['summary']['referenceCount']=len(retained)
 for row in d['summary']['coverage']:
  row['retainedSimpleReferences']=sum(row['tactic'] in r['tactics'] for r in retained)
  if row['status']!='not-applicable':row['status']='found' if row['retainedSimpleReferences'] else 'not-found'
 (OUT/'questions'/p.name).write_text(json.dumps(d,ensure_ascii=False))
assert len(policy['kept'])+len(policy['removed'])==23
assert any(x['sampleID']=='S01-02' for x in policy['removed'])
assert any(x['sampleID']=='S03-03' and x['referenceIndex']==0 for x in policy['kept'])
(OUT/'reference-policy.json').write_text(json.dumps(policy,ensure_ascii=False,indent=2))
(OUT/'source-summary.json').write_bytes((SRC/'summary.json').read_bytes())
s=read(SRC/'summary.json');s['questions']=[read(p)['summary'] for p in sorted((OUT/'questions').glob('*.json'))];s['referenceSelectionScope']=policy['scope']
(OUT/'summary.json').write_text(json.dumps(s,ensure_ascii=False,indent=2))
for name,digest in policy['sourceHashes'].items():assert hashlib.sha256((SRC/name).read_bytes()).hexdigest()==digest
print(json.dumps(dict(kept=len(policy['kept']),removed=len(policy['removed']),straightRayGeometryAudit=True)))
