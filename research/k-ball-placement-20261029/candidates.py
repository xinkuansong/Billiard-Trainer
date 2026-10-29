"""Propose B on finite production rails; archived lines only propose contacts."""
from pathlib import Path
import json,math,hashlib,collections
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/k-ball-placement-20261029'
source=ROOT/'output/k-ball-natural-review-20261029/data.json'
data=json.loads(source.read_text());g=json.loads((OUT/'geometry.json').read_text());R=g['radius']
def sub(a,b):return [a[0]-b[0],a[1]-b[1]]
def dot(a,b):return a[0]*b[0]+a[1]*b[1]
def dist(a,b):return math.dist(a,b)
def segment(p,a,b):
 d=sub(b,a);u=max(0,min(1,dot(sub(p,a),d)/dot(d,d))) if dot(d,d) else 0
 return dist(p,[a[0]+u*d[0],a[1]+u*d[1]])
def first_hit(points,b):
 for i,(a,z) in enumerate(zip(points,points[1:])):
  d=sub(z,a);q=sub(a,b);aa=dot(d,d);bb=2*dot(q,d);cc=dot(q,q)-(2*R)**2
  if cc<=0:return i,0,a
  disc=bb*bb-4*aa*cc
  if aa and disc>=0:
   u=(-bb-math.sqrt(disc))/(2*aa)
   if 0<=u<=1:return i,u,[a[0]+u*d[0],a[1]+u*d[1]]
 return None
rows=[];audit=[]
for axis in ['inAngle','outAngle']:
 active={id for group in data['groups'][axis] for id in group['ids']}
 for e in data['selected']:
  if e['id'] not in active or e[axis]>45:continue
  tr=e['route']['trajectory2mm'];points=[p[1:] for p in tr['points']];rails=tr['cushions'];idx=e['pointIndex'];ordinal=e['railOrdinal']
  prev=rails[ordinal-2]['pointIndex'] if ordinal>1 else 0
  nxt=rails[ordinal]['pointIndex'] if ordinal<len(rails) else len(points)-1
  lo,hi=(prev,idx) if axis=='inAngle' else (idx,nxt)
  rail=g['rails'][e['railID']];a,z=rail['start'],rail['end'];d=sub(z,a);length=math.hypot(*d);tan=[v/length for v in d];n=rail['normal']
  seed=dict(layout=e['layout'],route=e['route']['comboIndex'],cue=e['board']['cue'],object=e['board']['object'],pocket=e['board']['pocket'],dir=e['route']['strikeDirection'],v=e['route']['velocity'],sx=e['route']['spinX'],sy=e['route']['spinY'])
  expected=ordinal-(axis=='inAngle');counts={}
  for gap in [0,.015,.03]:
   options=[]
   for step in range(1,math.ceil(length/.01)):
    along=step*.01
    if along>=length:continue
    b=[a[j]+tan[j]*along+n[j]*(R+gap) for j in [0,1]]
    pd=min(min(segment(b,p['lip'][j],p['lip'][(j+1)%len(p['lip'])]) for j in range(len(p['lip']))) for p in g['pockets'])
    if pd<.30:continue
    if min(dist(b,seed['cue']),dist(b,seed['object']))<2*R+.002:continue
    if min(segment(b,seed['cue'],points[0]),segment(b,seed['object'],e['board']['aim']))<2*R+.002:continue
    hit=first_hit(points,b)
    if hit is None:continue
    i,u,pos=hit
    if not lo<=i<hi:continue
    if sum(c['pointIndex']<=i for c in rails)!=expected:continue
    if min(dist(pos,points[c['pointIndex']]) for c in rails)<.015:continue
    v=sub(points[i+1],points[i]);ang=math.degrees(math.atan2(abs(v[0]*tan[1]-v[1]*tan[0]),abs(dot(v,tan))))
    if ang>45:continue
    miss=segment(b,points[i],points[i+1])
    if miss>2*R-.004:continue
    options.append(dict(seed=seed,B=b,sourceID=e['id'],sourceKey=e['key'],axis=axis,railOrdinal=ordinal,railID=e['railID'],expectedRails=expected,tangent=tan,initialGap=gap,pocketLipDistance=pd,sourceAngle=e[axis],proposedAngle=ang,proposedContact=pos,missDistance=miss))
   counts[str(gap)]=len(options)
   # One central hit and one separated alternative per gap, no search for desired final outcome.
   options.sort(key=lambda q:q['missDistance'])
   chosen=options[:1]
   alternatives=[q for q in options if chosen and dist(q['B'],chosen[0]['B'])>=.035]
   if alternatives:chosen.append(alternatives[0])
   for row in chosen:
    row['id']=f"P{len(rows)+1:03d}";rows.append(row)
  audit.append(dict(sourceID=e['id'],axis=axis,ordinal=ordinal,eligibleGridCounts=counts))
(OUT/'candidates.json').write_text(json.dumps(rows,ensure_ascii=False))
(OUT/'candidate-audit.json').write_text(json.dumps(dict(sourceSHA256=hashlib.sha256(source.read_bytes()).hexdigest(),geometrySHA256=hashlib.sha256((OUT/'geometry.json').read_bytes()).hexdigest(),gridMeters=.01,gaps=[0,.015,.03],minPocketLipDistance=.30,maxAngle=45,events=audit,counts=dict(collections.Counter(str(r['expectedRails']) for r in rows))),indent=2))
print('CANDIDATES',len(rows),collections.Counter((r['axis'],r['railOrdinal']) for r in rows),flush=True)
