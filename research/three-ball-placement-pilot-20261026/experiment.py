"""Bounded, read-only three-ball placement study. No production imports with side effects."""
from pathlib import Path
import gzip,json,hashlib,math,random,struct
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name
BANK=ROOT/'QiuJi/Resources/TwoBallBank';SEED=202610260301

def read(p):return json.loads(Path(p).read_text())
def write(p,x):
 p=Path(p);p.parent.mkdir(parents=True,exist_ok=True);t=p.with_suffix(p.suffix+'.partial');t.write_text(json.dumps(x,ensure_ascii=False,indent=2,allow_nan=False));t.replace(p)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def f32(v):return struct.unpack('f',struct.pack('f',v))[0]
G=read(BANK/'index.json')['geometry'];R=G['radius'];HX=G['length']/2;HZ=G['width']/2
ANCHORS=[[-HX+R,-HZ+R],[HX-R,-HZ+R],[-HX+R,HZ-R],[HX-R,HZ-R],[0,-HZ],[0,HZ]]
def metric(c,b,a):
 d=math.dist(b,a);n=[(a[i]-b[i])/d for i in (0,1)];ghost=[b[i]-2*R*n[i] for i in (0,1)];v=[ghost[i]-c[i] for i in (0,1)]
 cut=math.degrees(math.atan2(abs(v[0]*n[1]-v[1]*n[0]),v[0]*n[0]+v[1]*n[1]));s=d/math.cos(math.radians(cut)) if cut<90 else None
 return dict(score=s,angle=cut,distance=d,ghost=ghost)
def best(c,b):
 opts=[dict(pocket=i,**metric(c,b,a)) for i,a in enumerate(ANCHORS)];valid=[q for q in opts if q['score'] is not None]
 return min(valid,key=lambda q:(q['score'],q['pocket'])) if valid else None

def segment(p,a,b):
 v=[b[i]-a[i] for i in (0,1)];ll=sum(x*x for x in v);t=max(0,min(1,sum((p[i]-a[i])*v[i] for i in (0,1))/ll)) if ll else 0
 return math.dist(p,[a[i]+t*v[i] for i in (0,1)])
def path_clear(b,path):return len(path)>1 and min(segment(b,a,c) for a,c in zip(path,path[1:]))>2*R+.002

def comfort(c,b,p):
 if math.dist(c,b)<2*R:return None
 m=metric(c,b,ANCHORS[p])
 if m['score'] is None:return None
 n=[(ANCHORS[p][i]-b[i])/m['distance'] for i in (0,1)]
 depth=max(0,min(((bound-pos) if direction>0 else (-bound-pos))/direction for pos,direction,bound in zip(b,[-n[0],-n[1]],[HX-R,HZ-R]) if abs(direction)>1e-12))
 scale=min(1,max(.4,depth/.9));lo=.5*scale;hi=.8*scale;d=math.dist(c,b)
 D=100*math.exp(-(max(lo-d,0)/(.8*lo))**2-(max(d-hi,0)/.75)**2)
 norm=math.dist(c,m['ghost']);back=[(c[i]-m['ghost'][i])/norm for i in (0,1)]
 gaps=[HX-c[0]-R,HX+c[0]-R,HZ-c[1]-R,HZ+c[1]-R]
 penalties=[(45+15*max(t,0)**2)*math.exp(-(max(g,0)*100/8)**1.2) for g,t in zip(gaps,[back[0],-back[0],back[1],-back[1]])]
 k=max(range(4),key=lambda i:penalties[i]);other=max(penalties[2:]) if k<2 else max(penalties[:2]);E=100-penalties[k]-min(8,.25*other);A=100*math.exp(-(max(m['angle']-15,0)/30)**2)
 return dict(total=(D*E*A)**(1/3),distance=D,space=E,angle=A,cut=m['angle'],pocket=p)
def effort(row):
 s=abs(row['sx']);h=max(row['sy'],0);d=max(-row['sy'],0);u=row['v']/4.5;n=len(row['rails']);L=sum(math.dist(a,b) for a,b in zip(row.get('cuePath',[]),row.get('cuePath',[])[1:]))
 return 2.5*s+.8*h+1.2*d+.8*u*u+.12*n+.06*L+.6*s*u+.15*n*s

def prepare():
 assert not (OUT/'samples.json').exists()
 ix=read(BANK/'index.json');groups=[(0,10),(10,20),(20,30),(30,50),(50,86)];picked=[None]*5;keys=[None]*5
 for part in ix['shards']:
  fp=BANK/(part['name']+'.jsonl.gz');assert sha(fp)==part['sha256']
  for line,rowbytes in enumerate(gzip.decompress(fp.read_bytes()).splitlines()):
   row=json.loads(rowbytes);angle=abs(row['board']['angle']);gi=next(i for i,(a,b) in enumerate(groups) if a<=angle<b)
   for q in row['questions']:
    key=hashlib.sha256(f"{SEED}/{row['id']}/{q['id']}".encode()).hexdigest()
    if keys[gi] is None or key<keys[gi]:
     keys[gi]=key;byid={r['id']:r for r in row['routes']};picked[gi]=dict(id=row['id'],cellID=q['id'],board=row['board'],second=q['p'],refs=q['refs'],routes=[byid[ref[0]] for ref in q['refs']],shard=part['name'],line=line,sourceSHA=part['sha256'],band=list(groups[gi]))
 samples=[]
 for i,s in enumerate(picked):
  assert s;s['number']=i+1;board=s['board'];s['firstMetric']=metric(board['cue'],board['object'],board['aim']);rng=random.Random(SEED+i+1);cands=[]
  for iz in range(6):
   for ixcell in range(12):
    x=-HX+R+(ixcell+.5)*(2*HX-2*R)/12+rng.uniform(-.05,.05);z=-HZ+R+(iz+.5)*(2*HZ-2*R)/6+rng.uniform(-.05,.05);p=[f32(x),f32(z)];m=best(board['cue'],p);reasons=[]
    if min(math.dist(p,t) for t in [board['cue'],board['object'],s['second']])<2*R:reasons.append('overlap')
    if m and m['score']<=s['firstMetric']['score']:reasons.append('third_not_harder')
    if segment(p,board['cue'],s['firstMetric']['ghost'])<2*R or segment(p,board['object'],board['aim'])<2*R:reasons.append('blocks_first_geometry')
    cands.append(dict(id=iz*12+ixcell,position=p,bestInitial=m,reasons=reasons))
  s['candidates']=cands;samples.append(s)
 write(OUT/'samples.json',samples)
 write(OUT/'protocol.json',dict(seed=SEED,samples=5,candidatesPerSample=72,selection='minimum deterministic hash per generation angle stratum, one distinct existing question each; no outcome reselection',angleStrata=groups,bankIndexSHA=sha(BANK/'index.json'),geometry=G,orderRule='S3_best > S1_selected at initial cue; S=object-anchor distance/cos(ghost-based cut); six forward anchors regardless occlusion (conservative); no second-stop S2<S3 constraint',allForwardAbsent='retain as no forward opening, never JSON Infinity',thirdPlacement='12x6 inset-cell centers, independent x/z +/-5cm jitter; native pocket-safe check',preserved='cue,1,2 positions; first input/direction; original route-specific second pocket',secondSearch=dict(speeds=[.6,1,1.4,1.8,2.2,2.6,3,3.4,3.8,4.2,4.5],spins=[[0,0],[0,-.4],[0,-.2],[0,.2],[0,.4],[-.25,0],[.25,0],[-.25,-.25],[-.25,.25],[.25,-.25],[.25,.25]],aim='one compensated direction per parameter; no direction retries',parametersPerFirstRoute=121),thirdFinish=dict(speeds=[1,1.5,2,2.5,3,3.5],spin=[0,0],pockets='all forward pockets with comfort>=85 from actual second stop'),quality='existing comfort-d2-s3-a2-v1 >=85 at final third-ball setup; exploratory threshold inherited for comparability, not newly calibrated for three-ball',bounds='max24 ranked second+third-pocket matches per first-route/third-position; max3 complete chains per third-position, distinct first routes; search-budget exhausted is not impossible',physical='all remaining balls present; actual stopped state passed onward; no remaining-ball contacts; no scratch; specified pockets; legal strike access; no cue jaw',pathPrefilter='sampled native polylines with 2mm conservative margin, heuristic rejection; successful chains always re-simulated with obstacles',productionMutation=False))
 print('Prepared',[(s['id'],s['cellID'],len(s['routes']),sum(not c['reasons'] for c in s['candidates'])) for s in samples])
if __name__=='__main__':prepare()
