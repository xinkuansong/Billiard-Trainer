#!/usr/bin/env python3
"""Presentation clustering of verified X-Z trajectories, metres. No new physics."""
import collections,functools,json,math
from pathlib import Path
from cue_scratch_manual500 import DEST,RAW
LIMITS=dict(initialPositionMaxM=.35,postPathRMSM=.18,postPathMaxM=.30,railContactMaxM=.25,cutDifferenceDegrees=12,speedDifference=1,distanceRatio=1.4)
TRANSFORMS=[(1,1),(-1,1),(1,-1),(-1,-1)]
def transform(p,s):return [p[0]*s[0],p[1]*s[1]]
def sample(points,count=24):
 clean=[]
 for p in points:
  if not clean or math.dist(clean[-1],p)>1e-9:clean.append(p)
 assert clean
 if len(clean)==1:return [clean[0]]*count
 lengths=[0.]
 for a,b in zip(clean,clean[1:]):lengths.append(lengths[-1]+math.dist(a,b))
 out=[];i=1
 for j in range(count):
  d=lengths[-1]*j/(count-1)
  while i<len(lengths)-1 and lengths[i]<d:i+=1
  u=(d-lengths[i-1])/(lengths[i]-lengths[i-1]);out.append([clean[i-1][k]*(1-u)+clean[i][k]*u for k in (0,1)])
 return out

def main():
 geo=json.loads((RAW/'geometry.json').read_text())
 pockets={int(p['id'].split('_')[-1]):p['center'] for p in geo['pockets']}
 rails={r['id']:[(a+b)/2 for a,b in zip(r['a'],r['b'])] for r in geo['rails'] if r['id']<6}
 maps={}
 for s in TRANSFORMS:
  maps[s]=[]
  for positions in (pockets,rails):
   mapping={i:min(positions,key=lambda j:math.dist(transform(p,s),positions[j])) for i,p in positions.items()}
   assert len(set(mapping.values()))==6
   assert all(math.dist(transform(p,s),positions[mapping[i]])<1e-5 for i,p in positions.items())
   assert all(mapping[mapping[i]]==i for i in positions)
   maps[s].append(mapping)
 rows=[x for x in json.loads((DEST/'cases.json').read_text()) if x['speed']<=4.5];byid={x['galleryID']:x for x in rows}; features={}
 for x in rows:
  hit=next(e['t'] for e in x['events'] if e['kind']=='ball')
  cue=x['paths']['cueBall'];j=next(i for i,f in enumerate(cue) if f[0]>=hit-1e-6)
  # Include the impact sample; do not compare incoming and outgoing paths as one line.
  paths=[sample([[f[1],f[2]] for f in cue[j:]]),sample([[f[1],f[2]] for f in x['paths']['object']])]
  contacts=[e['p'] for e in x['events'] if e['kind']=='rail' and e['ball']=='cueBall']
  assert len(contacts)==len(x['rails'])
  features[x['galleryID']]=(paths,contacts)
 @functools.lru_cache(None)
 def compare(ida,idb):
  a,b=byid[ida],byid[idb]
  if len(a['rails'])!=len(b['rails']) or (a['cut']<5)!=(b['cut']<5):return None
  da,db=math.dist(a['cue'],a['object']),math.dist(b['cue'],b['object'])
  if abs(a['cut']-b['cut'])>LIMITS['cutDifferenceDegrees'] or abs(a['speed']-b['speed'])>LIMITS['speedDifference'] or max(da,db)/min(da,db)>LIMITS['distanceRatio']:return None
  ap,ar=features[ida];bp,br=features[idb];matches=[]
  for s in TRANSFORMS:
   pm,rm=maps[s]
   if a['pocket']!=pm[b['pocket']] or int(a['cuePocket'].split('_')[-1])!=pm[int(b['cuePocket'].split('_')[-1])] or a['rails']!=[rm[r] for r in b['rails']]:continue
   initial=max(math.dist(a[k],transform(b[k],s)) for k in ('cue','object'))
   if initial>LIMITS['initialPositionMaxM']:continue
   distances=[math.dist(p,transform(q,s)) for aa,bb in zip(ap,bp) for p,q in zip(aa,bb)]
   rms=math.sqrt(sum(d*d for d in distances)/len(distances));maximum=max(distances)
   contact=max([math.dist(p,transform(q,s)) for p,q in zip(ar,br)] or [0])
   if rms>LIMITS['postPathRMSM'] or maximum>LIMITS['postPathMaxM'] or contact>LIMITS['railContactMaxM']:continue
   score=max(initial/.35,rms/.18,maximum/.3,contact/.25)
   matches.append(dict(transform=list(s),initialMaxM=initial,pathRMSM=rms,pathMaxM=maximum,railMaxM=contact,score=score))
  return min(matches,key=lambda x:x['score']) if matches else None
 def rank(x):
  c=x['speedChecks'];quality=c['sameRoute']/c['tested'] if c['tested'] else 0
  return (not bool(x.get('historicalLabel')),-quality,-x.get('cueClearance',0),x['galleryID'])
 groups=[]
 for x in sorted(rows,key=rank):
  ident=x['galleryID'];choices=[]
  for g in groups:
   evidence=[compare(ident,i) for i in g]
   if all(e is not None for e in evidence):choices.append((max(e['score'] for e in evidence),g))
  if choices:min(choices,key=lambda t:t[0])[1].append(ident)
  else:groups.append([ident])
 records=[];mapping={};representatives=[]
 for g in groups:
  rep=g[0];representatives.append(rep)
  for ident in g:
   mapping[ident]=rep
   if ident!=rep:records.append(dict(id=ident,representative=rep,**compare(rep,ident)))
  assert all(compare(a,b) is not None for i,a in enumerate(g) for b in g[:i])
 # Symmetry invariance: an exact mirrored copy of any case matches its source.
 for x in rows[::17]:
  for s in TRANSFORMS:
   pmap,rmap=maps[s];assert [rmap[rmap[r]] for r in x['rails']]==x['rails']
   assert all(math.dist(transform(transform(x[k],s),s),x[k])<1e-8 for k in ('cue','object'))
   ident='synthetic-'+x['galleryID']+str(s)
   clone=dict(x,cue=transform(x['cue'],s),object=transform(x['object'],s),pocket=pmap[x['pocket']],cuePocket='pocket_'+str(pmap[int(x['cuePocket'].split('_')[-1])]),rails=[rmap[r] for r in x['rails']])
   byid[ident]=clone
   paths,contacts=features[x['galleryID']]
   features[ident]=([[transform(p,s) for p in path] for path in paths],[transform(p,s) for p in contacts])
   match=compare(x['galleryID'],ident)
   assert match is not None and match['score']<1e-7
 result=dict(input=len(rows),kept=len(groups),removed=len(records),byRail=dict(collections.Counter(len(byid[i]['rails']) for i in representatives)),limits=LIMITS,
  grouping='complete-link: every pair in a group must satisfy all thresholds',representatives=sorted(representatives),groups=[dict(representative=g[0],members=g) for g in groups],mapping=mapping,removedDetails=records,
  mirroredMerged=sum(r['transform']!=[1,1] for r in records),sameOrientationMerged=sum(r['transform']==[1,1] for r in records),physicsChanged=False)
 (DEST/'deduplication.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
 cards=json.loads((DEST/'cards.json').read_text())
 for x in cards:
  x.pop('duplicateOf',None);x.pop('similarIDs',None)
  if x['id'] in mapping:
   rep=mapping[x['id']]
   if rep!=x['id']:x['duplicateOf']=rep
   else:x['similarIDs']=next(g[1:] for g in groups if g[0]==rep)
 (DEST/'cards.json').write_text(json.dumps(cards,ensure_ascii=False,indent=2))
 (DEST/'deduplicated-cases.json').write_text(json.dumps([x for x in rows if x['galleryID'] in representatives],ensure_ascii=False,indent=2))
 print(json.dumps({k:v for k,v in result.items() if k not in ['groups','mapping','removedDetails','representatives']},ensure_ascii=False))
if __name__=='__main__':main()
