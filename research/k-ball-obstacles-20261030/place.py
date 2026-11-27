"""Bounded geometric set-cover proposals; every result requires native replay."""
from pathlib import Path
import json,math,collections,random,sys
from native import OUT,ROOT,run
from prepare import segdist
R=.028574999421834946

def stage(name,kind):
 return {x['id']:x for p in sorted((OUT/name).glob(kind+'-*.jsonl')) for x in map(json.loads,p.open())}
def simplify(points,eps=.001):
 if len(points)<3:return points
 a,b=points[0],points[-1];d,i=max((segdist(p,a,b),i) for i,p in enumerate(points[1:-1],1))
 if d<=eps:return [a,b]
 return simplify(points[:i+1],eps)[:-1]+simplify(points[i:],eps)
def endtime(r):
 hit=next(e['time'] for e in r['events'] if e['kind']=='ballBall' and set(e['balls'])=={'cueBall','kTarget'})
 pot=next(e['time'] for e in r['events'] if e['kind']=='pocket' and e['ball']=='object')
 return max(hit,pot)
def poly(r,ball,completion=True):
 end=endtime(r) if completion else next(e['time'] for e in r['events'] if e['kind']=='ballBall' and set(e['balls'])=={'cueBall','kTarget'})
 return simplify([p[1:] for p in r['tracks'][ball] if p[0]<=end+1e-7])
def distance(p,line):return min((segdist(p,a,b) for a,b in zip(line,line[1:])),default=math.dist(p,line[0]))
def propose(q,reference,lower,small):
 geo=json.load(open(ROOT/'output/k-ball-full-20261029/geometry.json'));hx,hz=geo['length']/2,geo['width']/2
 protect=[poly(reference,k) for k in ('cueBall','object')]
 tolerance=[poly(r,k) for r in small for k in ('cueBall','object')]
 low=[poly(r,'cueBall',False) for r in lower]
 starts=[q['seed']['cue'],q['seed']['object'],q['candidate']['B']]
 candidates={};reasons=collections.Counter()
 for line in low:
  for a,b in zip(line,line[1:]):
   length=math.dist(a,b)
   if length<1e-9:continue
   norm=[-(b[1]-a[1])/length,(b[0]-a[0])/length]
   for i in range(math.ceil(length/.035)+1):
    t=min(1,i*.035/length)
    for offset in (0,-.025,.025):
     p=[a[k]+(b[k]-a[k])*t+norm[k]*offset for k in (0,1)];key=tuple(round(v,3) for v in p)
     if key in candidates:continue
     if abs(p[0])>hx-R-.002 or abs(p[1])>hz-R-.002:reasons['outside']+=1;continue
     if min(math.dist(p,s) for s in starts)<2*R+.002:reasons['start-overlap']+=1;continue
     if min(math.dist(p,lip) for pocket in geo['pockets'] for lip in pocket['lip'])<.10:reasons['near-pocket']+=1;continue
     clearance=min(distance(p,l) for l in protect)
     if clearance<2*R+.012:reasons['reference-clearance']+=1;continue
     if tolerance and min(distance(p,l) for l in tolerance)<2*R+.003:reasons['small-tolerance-clearance']+=1;continue
     mask=sum(1<<j for j,l in enumerate(low) if distance(p,l)<2*R-.004)
     if mask:candidates[key]=(mask,clearance,p)
 # Retain diverse candidate positions for each coverage mask; beam search up to three blockers.
 masks=collections.defaultdict(list)
 for c in candidates.values():masks[c[0]].append(c)
 pool=[]
 for mask,rows in masks.items():
  chosen=[]
  for c in sorted(rows,key=lambda c:-c[1]):
   if all(math.dist(c[2],v[2])>.06 for v in chosen):chosen.append(c)
   if len(chosen)==4:break
  pool+=chosen
 pool=sorted(pool,key=lambda c:(-c[0].bit_count(),-c[1]))[:400]
 full=(1<<len(low))-1;beam=[(0,[])];best=(0,[])
 for depth in range(1,4):
  nexts=[]
  for mask,positions in beam:
   for m,cl,p in pool:
    if m|mask==mask or any(math.dist(p,z)<2*R+.002 for z in positions):continue
    nxt=(m|mask,positions+[p]);nexts.append(nxt)
  if not nexts:break
  nexts.sort(key=lambda x:(-x[0].bit_count(),-min(distance(p,l) for p in x[1] for l in protect)))
  best=nexts[0]
  if best[0]==full:break
  beam=nexts[:24]
 return dict(blockers=best[1],knownLowerCount=len(low),covered=best[0].bit_count(),fullGeometricCover=best[0]==full,candidates=len(candidates),rejections=dict(reasons))

def main():
 refine='--refine' in sys.argv
 samples=json.load(open(OUT/'samples.json'));initial=stage('initial','results');additional=stage('search-lower-tracks','results');tol=stage('tolerance-before','results')
 if refine:additional.update(stage('holdout-lower-tracks','results'))
 jobs={**stage('initial','jobs'),**stage('search-lower-tracks','jobs'),**stage('tolerance-before','jobs')};plans=[];verify=[]
 if refine:jobs.update(stage('holdout-lower-tracks','jobs'))
 for q in samples:
  sid=q['sampleID'];n=q['candidate']['railOrdinal'];ref=initial[sid+'/reference']
  assert ref['success'] and ref['observedRail']==n
  lower=[r for k,r in {**initial,**additional}.items() if k.startswith(sid+'/') and r['success'] and 1<=r['observedRail']<n]
  small=[r for k,r in tol.items() if k.startswith(sid+'/tolerance/small-') and r['success'] and r.get('observedRail')==n]
  plan=propose(q,ref,lower,small) if lower else dict(blockers=[],knownLowerCount=0,covered=0,fullGeometricCover=False,candidates=0,rejections={})
  plan['sampleID']=sid;plan['lowerIDs']=[r['id'] for r in lower];rng=random.Random(20261030+int(sid[1:]));striped=bool(rng.randrange(2));numbers=rng.sample(list(range(9,16) if striped else range(1,8)),len(plan['blockers']));plan['numbers']=numbers;plan['A']=rng.choice(list(range(1,8) if striped else range(9,16)));plan['B']=8;plan['obstacleGroup']='stripes' if striped else 'solids'
  plans.append(plan)
  print(sid,'lower',len(lower),'candidates',plan['candidates'],'blockers',len(plan['blockers']),'covered',plan['covered'],flush=True)
  relevant=[sid+'/reference']+plan['lowerIDs']+[k for k in tol if k.startswith(sid+'/')]
  for k in relevant:verify.append(dict(jobs[k],blockers=plan['blockers'],tracks=True))
 (OUT/('placements-r2.json' if refine else 'placements.json')).write_text(json.dumps(plans,indent=2));run('placed-r2' if refine else 'placed',verify)
if __name__=='__main__':main()
