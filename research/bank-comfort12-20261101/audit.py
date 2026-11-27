from pathlib import Path
import json,math,hashlib,collections,copy
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/bank-comfort12-20261101'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def gap(p,a,b):
 d=[b[i]-a[i] for i in [0,1]];t=max(0,min(1,sum((p[i]-a[i])*d[i] for i in [0,1])/sum(x*x for x in d)))
 return math.dist(p,[a[i]+t*d[i] for i in [0,1]])
def shot(r,g):
 assert r['complete'] and 'cueBall' not in r['pocketedBalls']
 ev=r['events'];first=next(i for i,e in enumerate(ev) if e['kind']=='ballBall');pot=next(i for i,e in enumerate(ev) if e['kind']=='pocket' and e['ball']=='object')
 assert set(ev[first]['balls'])=={'cueBall','object'} and pot>first
 assert ev[pot]['pocket']==g['pockets'][r['pocket']]['id']
 assert not any(e['kind']=='cushion' and e['ball']=='cueBall' for e in ev[:first])
 assert not any(e['kind']=='ballBall' for e in ev[first+1:pot])
 rails=[e for e in ev[first+1:pot] if e['kind']=='cushion' and e['ball']=='object' and 0<=e['rail']<6]
 walls=[]
 for e in rails:
  n=g['rails'][e['rail']]['normal'];walls.append((0 if n[0]>0 else 1) if abs(n[0])>.5 else (2 if n[1]>0 else 3))
 assert len(walls)==r['n'] and walls==r['walls']
 for e in ev[first+1:pot]:
  if e['kind']=='cushion' and e['ball']=='object' and not 0<=e['rail']<6:
   assert e['time']>=(rails[-1]['time'] if rails else ev[first]['time']) and math.dist(e['target'],g['pockets'][r['pocket']]['center'])<.18
 assert r['targetTrack'][0][0]==ev[first]['time'] and r['targetTrack'][-1][0]==ev[pot]['time']
def comfort(cue,target,outgoing,incoming,length,g,cut_override=None):
 n=math.hypot(*outgoing);m=math.hypot(*incoming);u=[x/n for x in outgoing];v=[x/m for x in incoming];R=g['radius'];bounds=[g['length']/2-R,g['width']/2-R]
 depth=max(0,min(((b if -d>0 else -b)-p)/(-d) for p,d,b in zip(target,u,bounds) if abs(d)>1e-12))
 scale=min(1,max(.4,depth/.9));lo=.5*scale;hi=.8*scale;cd=math.dist(cue,target)
 ds=100*math.exp(-(max(lo-cd,0)/(.8*lo))**2-(max(cd-hi,0)/.75)**2)
 gaps=[bounds[0]-cue[0],bounds[0]+cue[0],bounds[1]-cue[1],bounds[1]+cue[1]]
 penalties=[(45+15*max(d,0)**2)*math.exp(-(max(q,0)*100/8)**1.2) for q,d in zip(gaps,[-v[0],v[0],-v[1],v[1]])]
 main=max(range(4),key=lambda i:penalties[i]);adj=max(penalties[2:]) if main<2 else max(penalties[:2]);space=100-penalties[main]-min(8,.25*adj)
 cut=math.degrees(math.atan2(abs(v[0]*u[1]-v[1]*u[0]),sum(x*y for x,y in zip(v,u)))) if cut_override is None else cut_override
 angle=100*math.exp(-(max(cut-min(15,9/length),0)/min(20,20*math.sqrt(.6/length)))**2)
 return dict(distance=ds,space=space,angle=angle,total=.5*min(ds,space,angle)+.5*(ds*space*angle)**(1/3),cut=cut,pathLength=length,cueTargetDistance=cd)
def audit(rows,g,v):
 assert len(rows)==12 and len({r['id'] for r in rows})==12
 assert {(r['type'],r['angleBand'],r['sampleIndex']) for r in rows}=={(t,a,d) for t in ['middle','corner'] for a in range(3) for d in range(2)}
 assert {p['id'] for p in v if p['bankReplay'] and p['directReplay'] and p['bestDirectRecomputed'] and p['fullScoreExactReplay']}=={r['id'] for r in rows}
 for r in rows:
  shot(r,g);shot(r['directProof'],g)
  for proof in [r,r['directProof']]:
   computed=comfort(proof['cue'],proof['target'],proof['scoreOutgoing'],proof['scoreIncoming'],proof['pathLength'],g)
   for k,vv in computed.items(): assert abs(proof['bankComfort'][k]-vv)<.0001,(r['id'],k,proof['bankComfort'][k],vv)
  f=r['bankComfort']; assert f['distance']>=85 and f['space']>=85 and f['total']>=70
  assert abs(r['cueRailGap']-(min(gap(r['cue'],q['start'],q['end']) for q in g['rails'])-g['radius']))<2e-6
  assert r['directComfortOptions'][0]['total']==max(x['total'] for x in r['directComfortOptions'])
  for option in r['directComfortOptions']:
   direction=[option['aim'][i]-r['target'][i] for i in (0,1)];length=math.hypot(*direction);u=[x/length for x in direction]
   incoming=[r['target'][i]-2*g['radius']*u[i]-r['cue'][i] for i in (0,1)]
   computed=comfort(r['cue'],r['target'],direction,incoming,length,g)
   for k in ['distance','space','angle','total']:assert abs(option[k]-computed[k])<.002,(r['id'],k)

  assert r['n']==1 and r['directProof']['n']==0
  assert r['directProof']['cue']==r['cue'] and r['directProof']['target']==r['target']
  assert r['directProof']['pocket']==r['bestDirect']['pocket']
  assert (r['pocket']>=4)==(r['type']=='middle')
  assert r['canonicalPocket']==(4 if r['type']=='middle' else 0)
  t=r['transform'];sign=[-1 if t in [1,3] else 1,-1 if t in [2,3] else 1]
  assert r['target']==[r['canonicalTarget'][i]*sign[i] for i in [0,1]]
  assert r['cue']==[r['canonicalCue'][i]*sign[i] for i in [0,1]]
  assert abs(r['railGap']-(min(gap(r['target'],q['start'],q['end']) for q in g['rails'])-g['radius']))<2e-6
  assert r['railGap']>=0 and r['spinX']==0
  for p in [r['cue'],r['target']]:
   assert abs(p[0])<g['length']/2-g['radius'] and abs(p[1])<g['width']/2-g['radius']
  assert math.dist(r['cue'],r['target'])>2*g['radius']
  d=r['bestDirect'];assert d['cut']>=45 and r['actualCutAngle']<=35
  assert r['angleBand']==(0 if d['cut']<55 else 1 if d['cut']<65 else 2)
  actual=r['directProof']['actualCutAngle'];assert actual>=45 and r['angleBand']==(0 if actual<55 else 1 if actual<65 else 2)
  rail=g['rails'][r['nearRail']];a,b=rail['start'],rail['end'];delta=[b[i]-a[i] for i in [0,1]]
  u=sum((r['target'][i]-a[i])*delta[i] for i in [0,1])/sum(x*x for x in delta)
  assert abs(u-r['railFraction'])<1e-8
  assert d['cut']==min(x['cut'] for x in r['directOptions'])
  for o in r['directOptions']:
   length=math.dist(r['target'],o['aim']);u=[(o['aim'][i]-r['target'][i])/length for i in [0,1]]
   v0=[r['target'][i]-2*g['radius']*u[i]-r['cue'][i] for i in [0,1]];dot=sum(a*b for a,b in zip(u,v0));assert dot>0
   angle=math.degrees(math.atan2(abs(v0[0]*u[1]-v0[1]*u[0]),dot))
   assert abs(angle-o['cut'])<.005,(r['id'],angle,o['cut'])
   score=100*math.exp(-(max(angle-min(15,9/length),0)/min(20,20*math.sqrt(.6/length)))**2)
   assert abs(score-o['score'])<.002,(r['id'],score,o)
 return True
if __name__=='__main__':
 rows=json.loads((OUT/'selected.json').read_text());g=json.loads((OUT/'geometry.json').read_text());v=json.loads((OUT/'verification.json').read_text());audit(rows,g,v)
 rejected=[]
 for case in ['wrong-bank-count','wrong-pocket','scratch','wrong-angle','wrong-symmetry','wrong-rail-fraction','easy-direct','fake-full-score','poor-cue-space']:
  bad=copy.deepcopy(rows);r=bad[0]
  if case=='wrong-bank-count':r['n']=2
  elif case=='wrong-pocket':r['pocket']=(r['pocket']+1)%6
  elif case=='scratch':r['pocketedBalls'].append('cueBall')
  elif case=='wrong-angle':r['actualCutAngle']=36
  elif case=='wrong-rail-fraction':r['railFraction']+=0.123
  elif case=='easy-direct':r['bestDirect']['cut']=44
  elif case=='fake-full-score':r['bankComfort']['total']+=1
  elif case=='poor-cue-space':r['bankComfort']['space']=40
  else:r['canonicalCue'][0]+=.1
  try:audit(bad,g,v)
  except AssertionError:rejected.append(case)
  else:raise AssertionError(case)
 binding=json.loads((OUT/'source-binding.json').read_text());drift=[s['path'] for s in binding['sources'] if s['currentProduction'] and sha(ROOT/s['path'])!=s['sha256']]
 assert not drift,drift
 assert sha(ROOT/'research/bank-comfort12-20261101/main.swift')==binding['entrySHA256']
 result={'pairs':12,'exactPhysicalReplays':24,'strata':12,'sourceDrift':drift,'negativeCasesRejected':rejected,'directCutRange':[min(r['bestDirect']['cut'] for r in rows),max(r['bestDirect']['cut'] for r in rows)],'bankCutRange':[min(r['actualCutAngle'] for r in rows),max(r['actualCutAngle'] for r in rows)],'nearRailWithin10cm':sum(r['railGap']<=.1 for r in rows),'outsideOldZone':sum(r['railGap']>.1 or not .25<=r['railFraction']<=.75 for r in rows),'railGapRange':[min(r['railGap'] for r in rows),max(r['railGap'] for r in rows)],'transformCounts':dict(collections.Counter(r['transform'] for r in rows)),'cueTargetCm':[min(math.dist(r['cue'],r['target'])*100 for r in rows),max(math.dist(r['cue'],r['target'])*100 for r in rows)],'cueRailGapCm':[min(r['cueRailGap']*100 for r in rows),max(r['cueRailGap']*100 for r in rows)],'comfortRanges':{k:[min(r['bankComfort'][k] for r in rows),max(r['bankComfort'][k] for r in rows)] for k in ['distance','space','angle','total']},'selectedSHA256':sha(OUT/'selected.json')}
 (OUT/'audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print(json.dumps(result,ensure_ascii=False,indent=2))
