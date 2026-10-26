from pathlib import Path
import json,random,hashlib,datetime
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name;PREV=ROOT/'research/rack-regional-phase-20261026'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert not (OUT/'gallery/protocol.json').exists()
for name in ['main.swift','build.py','run.py']:
 s=(PREV/name).read_text().replace('rack-regional-phase-20261026',HERE.name);(HERE/name).write_text(s)
excs=json.loads((ROOT/'output/rack-regional-phase-20261026/source-exceptions.json').read_text());assert all(sha(ROOT/x['path'])==x['currentSHA256'] for x in excs);(OUT/'source-exceptions.json').write_text(json.dumps(excs,indent=2))
old=set();sources=[]
def collect(x):
 if isinstance(x,dict):
  if 'seed' in x:old.add(str(x['seed']))
  for v in x.values():collect(v)
 elif isinstance(x,list):
  for v in x:collect(v)
for folder in ROOT.glob('output/rack-*'):
 if folder==OUT:continue
 for p in folder.rglob('*.json'):
  if p.name in ['inputs.json','racks.json','protocol.json','validation-plan.json','confirmation-plan.json']:collect(json.loads(p.read_text()));sources.append(dict(path=str(p.relative_to(ROOT)),sha256=sha(p)))
assert len(old)==11300,len(old)
rng=random.Random(202610262010);racks=[]
for i in range(100):
 seed=str(rng.getrandbits(64));assert seed not in old;old.add(seed);racks.append(dict(rackID=11300+i,seed=seed))
plan=dict(createdUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),workers=4,racks=racks,variants=['baseline','radial_sideM60'],purpose='Show 100 consecutive newly seeded candidate outcomes, with paired baseline for optional viewing and geometry audit. No outcome filtering, no best-of reroll.',conditions='15 balls; preserve original jitter magnitudes <=0.09mm and nominal0.20mm gap. Center L/4,0 aim actual apex; cue-tip9.75m/s spin0. Same unchanged score; >=1.20 secondary.',coordinateContract='World XZ metres, Y up. Gallery maps +X right,+Z down equal scale as app landscape top-down. Coordinates are raw simulation output, not rearranged.',entrySHA256=sha(HERE/'main.swift'),seedGenerator=202610262010)
(OUT/'gallery/protocol.json').write_text(json.dumps(plan,indent=2));(OUT/'seed-audit.json').write_text(json.dumps(dict(historicalUnique=11300,newUnique=100,overlap=[],sources=sources),indent=2));print('100 new candidate cases +100 paired production controls; no outcome selection.')
