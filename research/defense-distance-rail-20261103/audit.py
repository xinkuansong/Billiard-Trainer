"""Independent audit of visible-ball defense candidates, frozen-source binding."""
from pathlib import Path
import ast,hashlib,json,math,os,tarfile
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/defense-distance-rail-20261103/r2'
os.environ['DEFENSE_PILOT_OUTPUT']=str(OUT)
ns={'__file__':str(ROOT/'research/defense-bank-2500-20261103/audit.py')}
exec((ROOT/'research/defense-bank-2500-20261103/audit.py').read_text().split('index=json.loads')[0],ns)
geom=ns['geom'];R=geom['radius'];CUE=geom['cueKey'];check=ns['audit'];sweep=ns['sweep'];comfort=ns['comfort']

rail_source=ROOT/'output/defense-pilot-20261103/r2'
rail_geom=json.loads((rail_source/'geometry.json').read_text())
a=json.loads((rail_source/'source-manifest.json').read_text());b=json.loads((OUT/'source-manifest.json').read_text())
for name in ['QiuJi/Core/Physics/BTPhysicsConstants.swift','QiuJi/Core/Physics/TableGeometry+QiuJi.swift','QiuJi/Core/Physics/TableGeometry.swift']:assert a[name]==b[name]
segments=rail_geom['railSegments']
def main_rail_gap(c):
 distances=[]
 for seg in segments:
  a,b=seg['start'],seg['end'];v=[b[i]-a[i] for i in range(2)];u=max(0,min(1,sum((c[i]-a[i])*v[i] for i in range(2))/sum(x*x for x in v)))
  nearest=[a[i]+u*v[i] for i in range(2)];distances.append(math.dist(c,nearest)-R)
 return min(distances)

def metrics(q,r):
 ps=r['positions'];c,t=ps[CUE],ps[q['enemyKey']];initial=q['positions'];top=r['opportunities'][0]
 assert top['score']==max(x['score'] for x in r['opportunities'])
 d=math.dist(c,t);gap=min(geom['length']/2-abs(c[0]),geom['width']/2-abs(c[1]))-R
 unpenalized=.5*min(top['distance'],top['angle'])+.5*(top['distance']*100*top['angle'])**(1/3)
 return dict(ballDistance=d,distanceGain=d-math.dist(initial[CUE],initial[q['enemyKey']]),cueRailGap=gap,comfort=top['score'],spacePenalty=unpenalized-top['score'])

def qualify(m,r,kind,probe=False):
 if kind=='long':
  assert m['ballDistance']>=(1.35 if probe else 1.5) and m['distanceGain']>=(.3 if probe else .45)
  assert m['comfort']<=(45 if probe else 35)
  if not probe:
   top=r['opportunities'][0];assert top['angle']>=50 and top['distance']<=min(top['space'],top['angle']);assert m['cueRailGap']>=.04
 else:
  assert m['cueRailGap']<=(.05 if probe else .015) and m['comfort']<=(60 if probe else 50)
  if not probe:assert m['ballDistance']<1.4 and m['spacePenalty']>=5

rows=json.loads((OUT/'candidates.json').read_text());reports=[]
for q in rows:
 ns['check_positions'](q['positions'],list(q['positions']))
 assert 0<=q['openingComfort']<=40 and q['exactReplay']
 assert q['openingComfort']==max(x['score'] for x in q['openingOpportunities'])
 for options,key in [(q['openingOpportunities'],q['ownKey']),(q['openingEnemyOpportunities'],q['enemyKey'])]:
  for o in options:
   for field,value in comfort(q['positions'][CUE],q['positions'][key],o['aim']).items():assert abs(value-o[field])<2e-4
 seed=q['sourceProposal'];raw=Path(seed['source']).read_bytes();assert hashlib.sha256(raw).hexdigest()==seed['sourceSHA256'];original=json.loads(raw)
 assert seed['positions']==original['positions']==q['positions'] and seed['shot']==original['comparison']['shot']
 assert check(q,q['reference'],False,True,True)>4097*.95
 m=metrics(q,q['reference']);qualify(m,q['reference'],q['family'])
 for k,v in m.items():assert abs(v-q['metrics'][k])<2e-5
 if q['family']=='rail':
  assert main_rail_gap(q['reference']['positions'][CUE])<=.015
  c=q['positions'][CUE];assert min(geom['length']/2-abs(c[0]),geom['width']/2-abs(c[1]))-R>.06
 assert not q['reference']['occlusion']['full'];assert abs(q['reference']['defenseScore']-(100-m['comfort']))<1e-8
 assert len(q['perturbations'])==8;combos=set();a0=math.atan2(q['reference']['shot']['direction'][1],q['reference']['shot']['direction'][0]);speed=q['reference']['shot']['speed']
 for p in q['perturbations']:
  r=p['result'];assert q['family']!='rail' or main_rail_gap(r['positions'][CUE])<=.05;assert check(q,r,False,True)>4097*.95;mm=metrics(q,r);qualify(mm,r,q['family'],True)
  for k,v in mm.items():assert abs(v-p['metrics'][k])<2e-5
  da=p['angleDeltaDegrees'];sf=p['speedFactor'];combos.add((round(da,2),round(sf,2)))
  a=math.atan2(r['shot']['direction'][1],r['shot']['direction'][0])-a0
  assert abs(math.degrees(math.atan2(math.sin(a),math.cos(a)))-da)<1e-4
  assert abs(r['shot']['speed']/speed-sf)<1e-6
 assert combos=={(a,s) for a in [-.15,0,.15] for s in [.95,1,1.05] if a or s!=1}
 assert check(q,q['comparison'],False,True,True)>4097*.95
 assert q['comparison']['opportunities'][0]['score']-m['comfort']>=10
 reports.append({'id':q['id'],'passed':True,'metrics':m,'opponentOpeningComfort':q['openingEnemyOpportunities'][0]['score'] if q['openingEnemyOpportunities'] else None,'comparisonComfort':q['comparisonComfort']})
manifest=json.loads((OUT/'source-manifest.json').read_text());verified=0
with tarfile.open(OUT/'source-snapshot.tar.gz') as tar:
 for name,sha in manifest.items():
  raw=tar.extractfile('sources/'+name.removeprefix('QiuJi/')).read()
  if name.endswith('/QiuJiApp.swift'):raw=raw.replace(b'// Research worker supplies main',b'@main')
  assert hashlib.sha256(raw).hexdigest()==sha;verified+=1
 assert tar.extractfile('main.swift').read()==Path(__file__).with_name('main.swift').read_bytes()
report={'passed':True,'candidateCount':len(rows),'smallProbes':len(rows)*8,'verifiedSwiftFiles':verified,'checks':reports,'railGeometrySource':str(rail_source/'geometry.json'),'scope':'physics provenance, independent geometry/comfort/legality; not pot guarantee or real-table success'}
(OUT/'audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(report,ensure_ascii=False,indent=2))
