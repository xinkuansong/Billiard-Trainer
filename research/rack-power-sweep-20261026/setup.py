from pathlib import Path
import json,random,hashlib
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name;PREV=ROOT/'research/rack-best-100-20261026'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert not (OUT/'sweep/protocol.json').exists()
for name in ['main.swift','build.py','run.py']:
 s=(PREV/name).read_text().replace('rack-best-100-20261026',HERE.name)
 if name=='main.swift':
  token='            let validBox = cue.x'
  s=s.replace(token,'            let initialStrike = CueBallStrike.executeStrike(aimDirection: aim, velocity: power, spinX: 0, spinY: 0)\n            row["initialCueVelocity"] = vec(initialStrike.velocity)\n'+token)
 if name=='run.py':
  s=s.replace('def inp(r,v):','def inp(r,v,p=9.75):').replace('"{r[\'rackID\']}-{v}"','"{r[\'rackID\']}-{v}-p{p}"').replace('power=9.75,variant=v','power=p,variant=v')
  s=s.replace("pilot=[w.run(inp(r,v)) for r in protocol['racks'][:2] for v in protocol['variants']]","pilot=[w.run(inp(r,v,p)) for r in protocol['racks'][:2] for v in protocol['variants'] for p in protocol['powers']]")
  s=s.replace("jobs=[inp(r,v) for r in protocol['racks'] for v in protocol['variants']]","jobs=[inp(r,v,p) for r in protocol['racks'] for v in protocol['variants'] for p in protocol['powers']]")
 (HERE/name).write_text(s)
excs=json.loads((ROOT/'output/rack-best-100-20261026/source-exceptions.json').read_text())
p=ROOT/'QiuJi/Core/Physics/BTPhysicsConstants.swift';f=ROOT/'research/two-ball-strike-full-20261024/native-source/BTPhysicsConstants.swift'
assert f.read_text().replace('/// 全 App 击打页默认力度 (m/s)（条 13.2：低速走位是常态，默认从 3.3 降至 1.5）。','/// Shared initial shot speed (m/s); saved inputs and per-page reset timing remain unchanged.').replace('static let defaultVelocity: Double = 1.5','static let defaultVelocity: Double = 2.0')==p.read_text()
excs.append(dict(path=str(p.relative_to(ROOT)),frozenSHA256=sha(f),currentSHA256=sha(p),reason='Only default shot input 1.5 to 2.0 and its comment; research explicitly passes every power. Physical constants identical.'))
assert all(sha(ROOT/x['path'])==x['currentSHA256'] for x in excs)
(OUT/'source-exceptions.json').write_text(json.dumps(excs,indent=2))
old=set()
def collect(x):
 if isinstance(x,dict):
  if 'seed' in x:old.add(str(x['seed']))
  for v in x.values():collect(v)
 elif isinstance(x,list):
  for v in x:collect(v)
for folder in ROOT.glob('output/rack-*'):
 if folder==OUT:continue
 for p in folder.rglob('*.json'):
  if p.name in ['inputs.json','racks.json','protocol.json','validation-plan.json','confirmation-plan.json']:collect(json.loads(p.read_text()))
racks=json.loads((ROOT/'output/rack-best-100-20261026/gallery/protocol.json').read_text())['racks'];assert len(racks)==100
oldN=len(old);rng=random.Random(202610262200)
for i in range(900):
 seed=str(rng.getrandbits(64));assert seed not in old;old.add(seed);racks.append(dict(rackID=11400+i,seed=seed))
plan=dict(workers=4,racks=racks,variants=['radial_sideM60'],powers=[9.75,10.,11.,12.,13.,14.],purpose='Paired fixed-rack speed sweep, all outcomes retained. First100 gallery seeds +900 new; no selection, no power retry. Primary mean unchanged dispersion; secondary >=1.20, scratch, local clusters, potting and CPU/wall cost. Simultaneous paired bootstrap intervals over5 comparisons to9.75. No production edit.',historicalSeeds=oldN,newSeeds=900,oldGallerySeeds=100,conditions='Same radial_sideM60 positions/numbers/cue/aim across powers. Center L/4,0; zero spin/elevation. Unchanged event8000/time30 budgets.',entrySHA256=sha(HERE/'main.swift'),seedGenerator=202610262200)
(OUT/'sweep/protocol.json').write_text(json.dumps(plan,indent=2))
print('Prepared1000 racks x6powers=6000 simulations')
