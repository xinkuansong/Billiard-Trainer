from pathlib import Path
import math,json,collections,copy
ROOT=Path(__file__).resolve().parents[2]
source=(ROOT/'research/bank-full-20261101/audit.py').read_text()
ns0={'__file__':str(ROOT/'research/bank-full-20261101/audit.py')};exec(compile(source,'inherited_full_audit','exec'),ns0)
ns=ns0['ns']
def audit_rows(rows,g,verification,tree,bases,decisions):
 ns['tree']=tree;ns['audit'](rows,g,verification)
 byid={r['id']:r for r in rows};assert len(byid)==len(rows)
 expected=[]
 for decision in decisions:
  b=bases[decision['baseID']];assert len(decision['perturbationAttempts'])==2
  pertID=decision['canonicalPerturbationID'];transforms=[0,2] if b['type']=='middle' else [0,1,2,3]
  groups=collections.defaultdict(list)
  for item in decision['outcomes']:
   groups[item['canonicalID']].append(item['transform'])
   if 'acceptedID' in item:expected.append(item['acceptedID'])
  assert groups[b['id']]==transforms
  assert set(groups)==({b['id'],pertID} if pertID else {b['id']})
  if pertID:assert groups[pertID]==transforms
  assert any(x.get('acceptedID')==b['id']+'-S0' for x in decision['outcomes']),'Original reference must remain valid'
 assert set(expected)==set(byid) and len(expected)==len(rows)
 for r in rows:
  b=bases[r['baseID']];assert r['n']==b['n'] and r['routeID']==b['routeID']
  assert r['transform'] in ([0,2] if r['type']=='middle' else [0,1,2,3])
  t=r['transform'];s=[-1 if t in [1,3] else 1,-1 if t in [2,3] else 1]
  expectedwalls=[1-w if w<2 and s[0]<0 else 5-w if w>=2 and s[1]<0 else w for w in b['walls']]
  assert r['walls']==expectedwalls
  pk=g['pockets'][b['pocket']]['center'];pos=[pk[i]*s[i] for i in [0,1]]
  assert r['pocket']==min(range(6),key=lambda p:math.dist(g['pockets'][p]['center'],pos))
  if r['variantKind']=='original':
   assert r['canonicalCue']==b['cue'] and r['canonicalTarget']==b['target']
   assert r['direction']==[b['direction'][i]*s[i] for i in [0,1]] and r['speed']==b['speed']
  else:
   assert r['variantKind']=='perturbation';delta=r['perturbation'];dt=delta['targetDeltaMeters'];dd=delta['cueDistanceDeltaMeters'];da=delta['cutDeltaDegrees']
   assert .01<=abs(dt)<=.03 and .03<=abs(dd)<=.08 and 1<=abs(da)<=3
   q=b['seedRailPoint'];v=tree[b['routeID']]['reverseDirection']
   assert math.dist(r['canonicalTarget'],[b['target'][i]+dt*v[i] for i in [0,1]])<2e-7
   assert abs(math.dist(r['canonicalCue'],r['canonicalTarget'])-math.dist(b['cue'],b['target'])-dd)<2e-7
   assert abs(r['generationCut']-b['generationCut']-da)<1e-10
   theta=math.atan2(-v[1],-v[0]);diam=2*g['radius'];o=r['canonicalTarget'];c=r['canonicalCue']
   ghost=[o[i]+diam*v[i] for i in [0,1]];aim=math.atan2(ghost[1]-c[1],ghost[0]-c[0]);cut=math.degrees(math.atan2(math.sin(aim-theta),math.cos(aim-theta)))
   assert abs(cut-r['generationCut'])<.0001
 return True

def compact(r):
 r=copy.deepcopy(r)
 for p in [r,r['directProof']]:
  for key in ['cueTrack','cueAfter','targetTrack']:
   track=p[key];times={e['time'] for e in p['events']};p[key]=[v for i,v in enumerate(track) if i==0 or i==len(track)-1 or i%6==0 or v[0] in times]
 r['trajectoryStorage']='Display samples approx 10Hz plus every physical event; full simulation used for native replay and scoring'
 return r
