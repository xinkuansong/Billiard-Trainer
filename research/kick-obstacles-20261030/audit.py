"""Independent validation of evidence and physical-role contract."""
from place import *
import hashlib,collections
rows=json.loads((OUT/'accepted.json').read_text());assert rows,'No accepted examples'
summary=[]
for r in rows:
 row=r['row'];check=r['check'];n=row['n'];assert n in [1,2]
 assert check['referencePassed'] and check['exactReplay'] and check['incomplete']==0 and check['lowerSolutionCount']==0
 assert check['simulations']+check['unavailable']==720*8*9
 if check.get('searchMethod'):
  assert check['prefixSimulations']==51840 and check['parityChecks']==check['simulations']//113
  assert json.loads((OUT/'pruning-parity.json').read_text())['passed']
  assert check['fullSimulations']>=check['parityChecks']
 assert check['angleStepDegrees']==.5 and check['spinY']==0
 assert check['speeds']==[1,1.5,2,2.5,3,3.5,4,4.5]
 assert sorted(check['spins'])==[-.5,-.375,-.25,-.125,0,.125,.25,.375,.5]
 ref=check['reference'];assert ref['complete'] and 'cueBall' not in ref['pocketedBalls']
 first=next(e for e in ref['events'] if e['kind']=='ballBall' and 'cueBall' in e['balls'])
 assert set(first['balls'])=={'cueBall','object'}
 rails=[e['rail'] for e in ref['events'] if e['index']<first['index'] and e['kind']=='cushion' and e['ball']=='cueBall']
 assert rails==row['rails'] and len(rails)==n
 assert 1<=len(r['obstacles'])<=3
 c=np.array(row['seed']['cue']);t=np.array(row['target']);blocks=np.array(r['obstacles'])
 assert any(direct_certificate(c,t,b) for b in blocks)
 allpoints=np.array([list(c),list(t),*blocks.tolist()])
 for i,p in enumerate(allpoints):
  assert abs(p[0])<G['length']/2-R and abs(p[1])<G['width']/2-R
  for q in allpoints[i+1:]:assert np.linalg.norm(p-q)>D
 # Reference geometry screening is conservative; native first-contact check is decisive.
 assert pathdist(blocks,ref['cueTrack']).min()>D
 scan=json.loads((OUT/(r['id']+'-scan.json')).read_text())
 assert scan['simulations']+scan['unavailable']==360*4*5
 assert scan['incomplete']==0
 assert all(x['n']<n for x in scan['solutions'])
 placementInput=json.loads((OUT/r['placementInput']).read_text()) if 'placementInput' in r else scan
 for route in placementInput['solutions']:assert (pathdist(blocks,route['track'])<D-.008).any()
 summary.append({'id':r['id'],'n':n,'obstacles':len(blocks),'sourceDisplayID':row['displayID'],'beforeLowerSolutions':scan['lowerSolutionCount'],'beforeByRail':dict(collections.Counter(x['n'] for x in scan['solutions'])),'afterLowerSolutions':0,'searchedInputs':check['simulations'],'prefixSimulations':check.get('prefixSimulations',0),'fullSimulations':check.get('fullSimulations',check['simulations']),'parityChecks':check.get('parityChecks',0),'unavailable':check['unavailable'],'incomplete':check['incomplete'],'referenceFirstContact':'object','referenceCushions':len(rails),'exactReplay':True,'directShadowCertificate':True})
binding=json.loads((OUT/'source-binding.json').read_text());drift=[]
for b in binding['sources']:
 if b['currentProduction'] and hashlib.sha256((ROOT/b['path']).read_bytes()).hexdigest()!=b['sha256']:drift.append(b['path'])
assert not drift,drift
assert hashlib.sha256((ROOT/'research/kick-obstacles-20261030/main.swift').read_bytes()).hexdigest()==binding['entrySHA256']
fast=json.loads((OUT/'fast-binding.json').read_text())
assert hashlib.sha256((ROOT/'research/kick-obstacles-20261030/fast-main.swift.txt').read_bytes()).hexdigest()==fast['entrySHA256']
report={'accepted':len(summary),'perRail':dict(collections.Counter(r['n'] for r in summary)),'rows':summary,'perturbations':0,'sourceDrift':drift,'scope':'Finite lower-cushion search; not continuous uniqueness/minimum proof; spinY=0; no jump/masse/real-table validation.'}
(OUT/'audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(report,ensure_ascii=False,indent=2))
