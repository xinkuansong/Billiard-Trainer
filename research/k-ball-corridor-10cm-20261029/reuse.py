"""Regenerate 10cm geometry; reuse only byte-equivalent, previously verified shots."""
from pathlib import Path
import hashlib,json,shutil,subprocess,sys

ROOT=Path(__file__).resolve().parents[2]
OLD=ROOT/'output/k-ball-corridor-20261029'
OUT=ROOT/'output/k-ball-corridor-10cm-20261029'
OUT.mkdir(exist_ok=True)
def read(path):return json.loads(path.read_text())
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def identity(row):
    return json.dumps({k:row[k] for k in ['regionID','seed','B']},sort_keys=True,separators=(',',':'))

binding=read(OLD/'source-binding.json')
for source in binding['sources']:
    assert sha(ROOT/source['path'])==source['sha256'],source['path']
assert sha(ROOT/'research/k-ball-corridor-20261029/main.swift')==binding['entrySHA256']
for name in ['geometry.json','source-binding.json']:
    shutil.copy2(OLD/name,OUT/name)
subprocess.run([sys.executable,str(Path(__file__).with_name('candidates.py'))],check=True)
old_candidates={identity(r):r for r in read(OLD/'candidates.json')}
old_trials={r['id']:r for r in read(OLD/'trials.json')}
old_replays={r['id']:r for r in read(OLD/'replay.json')}
candidates=read(OUT/'candidates.json');regions=read(OUT/'regions.json')
renames={};trials=[];replays=[]
for c in candidates:
    old=old_candidates[identity(c)]
    # IDs stay stable across review editions; every other candidate field must match.
    renames[c['id']]=old['id'];c['id']=old['id']
    assert c==old,(c['id'],'candidate mismatch')
    trial=old_trials[c['id']]
    assert all(trial[k]==v for k,v in c.items())
    trials.append(trial)
    if trial['success']:
        replay=old_replays[c['id']]
        assert replay['success'] and replay['exactReplay']
        replays.append(replay)
assert {r['id'] for r in candidates}=={r['id'] for r in old_candidates.values() if r['initialGap']<=.10}
for region in regions:region['sampleIDs']=[renames[k] for k in region['sampleIDs']]
for name,data in [('candidates.json',candidates),('regions.json',regions),('trials.json',trials),('samples.json',[r for r in trials if r['success']]),('replay.json',replays)]:
    (OUT/name).write_text(json.dumps(data))
provenance=dict(mode='Exact-input subset reuse; no new physics runs',source=str(OLD.relative_to(ROOT)),maxSurfaceGap=.10,
    retainedIDs=[r['id'] for r in candidates],
    sourceFiles={name:sha(OLD/name) for name in ['candidates.json','trials.json','replay.json','geometry.json','source-binding.json']},
    checks=['all seed, B, region and candidate fields identical','all old <=10cm candidates retained','all retained trial and replay records unchanged','production source bindings unchanged'])
(OUT/'reuse-audit.json').write_text(json.dumps(provenance,indent=2))
print('EXACT INPUT REUSE',len(trials),'SUCCESS',len(replays),flush=True)
