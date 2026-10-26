"""Independent arithmetic and full result checks; no invocation of generator scoring functions."""
from pathlib import Path
import math,json,gzip,hashlib,collections
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/three-ball-placement-pilot-20261026'
read=lambda p:json.loads(Path(p).read_text());sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
P=read(OUT/'protocol.json');g=P['geometry'];r=g['radius'];hx=g['length']/2;hz=g['width']/2
anchors=[[-hx+r,-hz+r],[hx-r,-hz+r],[-hx+r,hz-r],[hx-r,hz-r],[0,-hz],[0,hz]]
def score(c,b,a):
 length=math.dist(a,b);n=[(a[i]-b[i])/length for i in (0,1)];v=[b[i]-2*r*n[i]-c[i] for i in (0,1)];dot=sum(v[i]*n[i] for i in (0,1))
 return length*math.hypot(*v)/dot if dot>0 else math.inf

def oracle(c,b,p):
 a=anchors[p];norm=math.dist(a,b);n=[(a[i]-b[i])/norm for i in (0,1)];ghost=[b[i]-2*r*n[i] for i in (0,1)];delta=[ghost[i]-c[i] for i in (0,1)];dn=math.hypot(*delta);cos=sum(delta[i]*n[i] for i in (0,1))/dn;angle=math.degrees(math.acos(min(1,max(-1,cos))));assert angle<90
 depth=[]
 for i,bound in enumerate([hx-r,hz-r]):
  direction=-n[i]
  if direction>1e-12:depth.append((bound-b[i])/direction)
  elif direction< -1e-12:depth.append((-bound-b[i])/direction)
 k=max(.4,min(1,max(0,min(depth))/.9));a0=.5*k;z=.8*k;distance=math.dist(c,b)
 D=100*math.exp(-max(a0-distance,0)**2/(.8*a0)**2-max(distance-z,0)**2/.75**2)
 bx,bz=-delta[0]/dn,-delta[1]/dn
 terms=[]
 for gap,t in zip([hx-c[0]-r,hx+c[0]-r,hz-c[1]-r,hz+c[1]-r],[bx,-bx,bz,-bz]):terms.append((45+15*max(0,t)**2)*math.exp(-(max(0,gap)/.08)**1.2))
 m=max(range(4),key=lambda i:terms[i]);neighbor=max(terms[2:]) if m<2 else max(terms[:2]);E=100-terms[m]-min(8,neighbor/4);A=100*math.exp(-max(angle-15,0)**2/900)
 return math.exp((math.log(D)+math.log(E)+math.log(A))/3)
assert abs(score([-1,0],[0,0],[1,0])-1)<1e-12
assert abs(score([-2*r-1,-1],[0,0],[1,0])-math.sqrt(2))<1e-12
def independent_segment(p,a,b):
 if sum((p[i]-a[i])*(b[i]-a[i]) for i in (0,1))<=0:return math.dist(p,a)
 if sum((p[i]-b[i])*(a[i]-b[i]) for i in (0,1))<=0:return math.dist(p,b)
 return abs((p[0]-a[0])*(b[1]-a[1])-(p[1]-a[1])*(b[0]-a[0]))/math.dist(a,b)
counts=collections.Counter();reasons=collections.Counter();chains=0;maxerr=0;per=[];seen=set()
for i in range(1,6):
 d=read(OUT/f'sample-{i}.json');s=d['sample'];b=s['board'];assert len(d['candidates'])==72;assert len(set(c['id'] for c in d['candidates']))==72
 key=(s['id'],s['cellID']);assert key not in seen;seen.add(key)
 src=ROOT/'QiuJi/Resources/TwoBallBank'/(s['shard']+'.jsonl.gz');assert sha(src)==s['sourceSHA'];row=next(json.loads(x) for x in gzip.decompress(src.read_bytes()).splitlines() if json.loads(x)['id']==s['id']);q=next(q for q in row['questions'] if q['id']==s['cellID']);assert q['p']==s['second'] and q['refs']==s['refs'] and row['board']==b
 refs={r0['id']:r0 for r0 in row['routes']};assert [refs[ref[0]] for ref in q['refs']]==s['routes']
 s1=score(b['cue'],b['object'],b['aim']);assert math.isclose(s1,s['firstMetric']['score'],rel_tol=1e-11)
 for c in d['candidates']:
  s3=min(score(b['cue'],c['position'],a) for a in anchors);reported=c['bestInitial']
  assert (reported is None)==math.isinf(s3)
  if reported:assert math.isclose(s3,reported['score'],rel_tol=1e-10)
  assert ('third_not_harder' in c['reasons'])==(s3<=s1)
  assert ('overlap' in c['reasons'])==(min(math.dist(c['position'],v) for v in [b['cue'],b['object'],s['second']])<2*r)
  anchor=b['aim'];length=math.dist(anchor,b['object']);ghost=[b['object'][k]-2*r*(anchor[k]-b['object'][k])/length for k in (0,1)]
  blocked=independent_segment(c['position'],b['cue'],ghost)<2*r or independent_segment(c['position'],b['object'],anchor)<2*r
  assert ('blocks_first_geometry' in c['reasons'])==blocked
  assert (c['status']=='initial_rejected')==bool(c['reasons'])
  reasons.update(c['reasons']);counts[c['status']]+=1
  if c['status']=='validated':assert c['chains'] and not c['reasons'] and s3>s1
  if c['chains']:assert c['nativePlacementLegal'] and min(math.dist(c['position'],p) for p in [b['cue'],b['object'],s['second']])>=2*r
  assert len(c['chains'])<=3
  for ch in c['chains']:
   chains+=1;shots=ch['shots'];rank=ch['firstRank'];assert ch['pocket2']==s['refs'][rank][1]
   first=shots[0]['request'];param=s['routes'][rank]
   assert first['cue']==b['cue'] and first['object']==b['object'] and first['pocket']==b['pocket'] and first['aim']==b['aim'] and first['obstacles']==[s['second'],c['position']]
   for k in ['v','sx','sy','dir']:assert first[k]==param[k]
   for k,shot in enumerate(shots):
    req,res=shot['request'],shot['result'];assert res['success'] and res['settled'] and not res['reasons'];assert res['firstContact']=='object';assert 'cueBall' not in res['pocketed'];assert res['pocketed']==['object']
    pots=[e for e in res['events'] if e['kind']=='pocket'];assert len(pots)==1 and pots[0]['ball']=='object' and pots[0]['pocket']==f"pocket_{req['pocket']}"
    assert not any(any(v.startswith('obstacle') for v in e['balls']) for e in res['events'] if e['kind']=='ball')
    assert not any(e['kind']=='cushion' and e['ball']=='cueBall' and e['rail'] not in range(6) for e in res['events'])
    for oi,p in enumerate(req['obstacles']):assert math.dist(p,res['finals'][f'obstacle{oi}'])<1e-6
    if k:assert req['cue']==shots[k-1]['result']['stop']
   value=oracle(shots[1]['result']['stop'],c['position'],ch['pocket3']);maxerr=max(maxerr,abs(value-ch['comfort3']['total']));assert value>=85 and abs(value-ch['comfort3']['total'])<1e-9
 per.append(dict(sample=i,sourceID=s['id'],cellID=s['cellID'],generationAngle=b['angle'],actualFirstCut=s['firstMetric']['angle'],S1=s1,counts=d['counts'],chains=sum(len(c['chains']) for c in d['candidates'])))
assert counts==read(OUT/'generation.json')['counts'];assert chains==read(OUT/'generation.json')['chains'];assert sum(counts.values())==360
replay=read(OUT/'all-chain-replay/audit.json');assert replay['passed'] and replay['chains']==chains and replay['shots']==chains*3
assert sha(OUT/'all-chain-replay/chains.jsonl.gz')==replay['chainsSHA']
assert sha(ROOT/'QiuJi/Resources/TwoBallBank/index.json')==P['bankIndexSHA']
bank=ROOT/'QiuJi/Resources/TwoBallBank';index=read(bank/'index.json')
for shard in index['shards']:assert sha(bank/(shard['name']+'.jsonl.gz'))==shard['sha256']
result=dict(fullBankShardsVerified=len(index['shards']),passed=True,samples=per,counts=dict(counts),chains=chains,overlappingInitialRejectionReasons=dict(reasons),maxIndependentComfortError=maxerr,allChainNativeReplay=replay,productionBankUnchanged=True)
(OUT/'audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print(json.dumps({k:v for k,v in result.items() if k not in ['samples','allChainNativeReplay']},ensure_ascii=False))
