from pathlib import Path
import json,math,hashlib,collections,copy
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/bank-central12-20261101'
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
def audit(rows,g,v):
 assert len(rows)==12 and len({r['id'] for r in rows})==12
 assert {(r['type'],r['angleBand'],r['gapBand']) for r in rows}=={(t,a,d) for t in ['middle','corner'] for a in range(3) for d in range(2)}
 assert {p['id'] for p in v if p['bankReplay'] and p['directReplay'] and p['bestDirectRecomputed']}=={r['id'] for r in rows}
 for r in rows:
  shot(r,g);shot(r['directProof'],g)
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
  assert r['gapBand']==(0 if r['railGap']<.05 else 1) and 0<=r['railGap']<=.1
  rail=g['rails'][r['nearRail']];a,b=rail['start'],rail['end'];delta=[b[i]-a[i] for i in [0,1]]
  u=sum((r['target'][i]-a[i])*delta[i] for i in [0,1])/sum(x*x for x in delta)
  assert .25<=u<=.75 and abs(u-r['railFraction'])<1e-8
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
 for case in ['wrong-bank-count','wrong-pocket','scratch','wrong-angle','wrong-symmetry','outside-central-zone','easy-direct']:
  bad=copy.deepcopy(rows);r=bad[0]
  if case=='wrong-bank-count':r['n']=2
  elif case=='wrong-pocket':r['pocket']=(r['pocket']+1)%6
  elif case=='scratch':r['pocketedBalls'].append('cueBall')
  elif case=='wrong-angle':r['actualCutAngle']=36
  elif case=='outside-central-zone':r['railFraction']=0.1
  elif case=='easy-direct':r['bestDirect']['cut']=44
  else:r['canonicalCue'][0]+=.1
  try:audit(bad,g,v)
  except AssertionError:rejected.append(case)
  else:raise AssertionError(case)
 binding=json.loads((OUT/'source-binding.json').read_text());drift=[s['path'] for s in binding['sources'] if s['currentProduction'] and sha(ROOT/s['path'])!=s['sha256']]
 assert not drift,drift
 result={'pairs':12,'exactPhysicalReplays':24,'strata':12,'sourceDrift':drift,'negativeCasesRejected':rejected,'directCutRange':[min(r['bestDirect']['cut'] for r in rows),max(r['bestDirect']['cut'] for r in rows)],'bankCutRange':[min(r['actualCutAngle'] for r in rows),max(r['actualCutAngle'] for r in rows)],'nearRailWithin10cm':sum(r['railGap']<.1 for r in rows),'transformCounts':dict(collections.Counter(r['transform'] for r in rows)),'selectedSHA256':sha(OUT/'selected.json')}
 (OUT/'audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print(json.dumps(result,ensure_ascii=False,indent=2))
