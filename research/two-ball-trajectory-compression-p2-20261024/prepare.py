from pathlib import Path
import json, math, struct, hashlib, shutil
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name
read=lambda p:json.loads(p.read_text())
def f32(x):return struct.unpack('f',struct.pack('f',x))[0]
def dist(a,b):return math.dist(a,b)
def segment(p,a,b):
 d=[b[k]-a[k] for k in range(2)];ll=sum(x*x for x in d)
 u=sum((p[k]-a[k])*d[k] for k in range(2))/ll if ll else 0
 v=max(0,min(1,u));return dist(p,[a[k]+v*d[k] for k in range(2)]),u

def simplify(x,anchors,tol):
 keep=set(anchors)
 def rec(a,b):
  if b<=a+1:return
  ds=[(segment(x[i],x[a],x[b])[0],i) for i in range(a+1,b)]
  err,index=max(ds)
  # Preserve ordered backtracking, even when the points lie on one line.
  maxu=0;maxi=a; chord=dist(x[a],x[b])
  for i in range(a+1,b):
   u=segment(x[i],x[a],x[b])[1]
   if (maxu-u)*chord>tol and a<maxi<b:
    index=maxi;err=max(err,tol*2);break
   if u>maxu:maxu,maxi=u,i
  if err>tol:
   keep.add(index);rec(a,index);rec(index,b)
 for a,b in zip(anchors,anchors[1:]):rec(a,b)
 return sorted(keep)

def deviation(x,idx):
 return max((segment(x[k],x[a],x[b])[0] for a,b in zip(idx,idx[1:]) for k in range(a,b+1)),default=0)
assert simplify([[0,0],[1,0],[.2,0],[2,0]],[0,3],.005)==[0,1,2,3]
assert simplify([[0,0],[1,1],[2,0]],[0,2],.005)==[0,1,2]
assert simplify([[0,0],[1,0],[2,0]],[0,2],.005)==[0,2]

native=read(ROOT/'output/two-ball-b42-dedup75-20261024/native-result.json')
rows=native['rows']+read(OUT/'native-result.json')['rows'];rows.sort(key=lambda r:r['comboIndex'])
assert len(rows)==len({r['comboIndex'] for r in rows})==95
variants={'full':[],'cushion':[],'key2mm':[],'key5mm':[],'key10mm':[]};details=[]
for r in rows:
 line=r['comparisonLine'];x=[[f32(p['position']['x']),f32(p['position']['z'])] for p in line]
 assert r['comparisonFullTermination']=='settled' and dist(x[-1],r['cueStop'])<1e-6
 anchors={0,len(line)-1};events=[]
 for e in r['events']:
  if e['kind']=='cushion' and e['ball']=='cueBall' and e['afterFirstContact']:
   rel=f32(e['time']-r['firstContactTime']);i=min(range(len(line)),key=lambda i:abs(line[i]['time']-rel))
   assert abs(line[i]['time']-rel)<1e-6 and line[i]['isEvent'],(r['comboIndex'],e,i)
   anchors.add(i);events.append(dict(index=i,cushionID=e['cushionID'],surface=e['surface'],time=line[i]['time']))
 assert len(events)==r['cueCushionTotal'] and r['cueCushionsBeforeContact']==0
 # All extraction event anchors are first contact or known cushions for these 95.
 for i in {i for i,p in enumerate(line) if p['isEvent']} - anchors:
  # Extractor can mark two adjacent positions at the same Float event time.
  assert any(abs(line[i]['time']-line[j]['time'])<1e-6 and dist(x[i],x[j])<2e-6 for j in anchors), (r['comboIndex'],i)
 anchors=sorted(anchors);sets={'full':list(range(len(line))),'cushion':anchors}
 for name,tol in [('key2mm',.002),('key5mm',.005),('key10mm',.010)]:
  sets[name]=simplify(x,anchors,tol);assert deviation(x,sets[name])<=tol+1e-12
 info=dict(comboIndex=r['comboIndex'],events=events,variants={})
 fullLength=sum(dist(a,b) for a,b in zip(x,x[1:]))
 for name,indices in sets.items():
  assert set(anchors)<=set(indices) and indices==sorted(set(indices))
  points=[dict(time=line[i]['time'],position=dict(x=x[i][0],z=x[i][1]),isEvent=line[i]['isEvent']) for i in indices]
  variants[name].append(dict(comboIndex=r['comboIndex'],points=points))
  length=sum(dist(x[a],x[b]) for a,b in zip(indices,indices[1:]))
  info['variants'][name]=dict(points=len(indices),indices=indices,maxDeviationMM=1000*deviation(x,indices),lengthM=length,lengthLossMM=1000*(fullLength-length))
 details.append(info)
(OUT/'representations.json').write_text(json.dumps(variants,separators=(',',':')))
(OUT/'point-details.json').write_text(json.dumps(details,indent=2))
source=ROOT/'QiuJi/Features/SeparationPractice/SeparationTrajectoryScore.swift';shutil.copy2(source,HERE/source.name)
provenance=dict(source=str(source.relative_to(ROOT)),sha256=hashlib.sha256(source.read_bytes()).hexdigest(),extractorSHA256=hashlib.sha256((ROOT/'QiuJi/Features/SeparationPractice/SeparationQuestionGenerator.swift').read_bytes()).hexdigest(),count=95,coordinateUnit='meters; Float32 restored before P2 centimeters conversion',anchors='first object contact + every cue cushion contact in order + stop',keypoints='event-constrained RDP with ordered-backtracking guard; 2/5/10 mm deviation tolerances',tests='straight line / bend / collinear reversal; all95 event identity/order/endpoints/bounds assertions')
(OUT/'provenance.json').write_text(json.dumps(provenance,indent=2))
print({k:sum(len(r['points']) for r in v) for k,v in variants.items()})
