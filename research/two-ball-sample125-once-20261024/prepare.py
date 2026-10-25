from pathlib import Path
import json,gzip,hashlib,collections
from sampling import combinations
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name;BASE=ROOT/'output/two-ball-strike-sampled100-20261024'
indices=[round(i*1356/9) for i in range(10)]
boards=[];oldstats=collections.Counter();oldcount=[];oldwall=0
for i in indices:
 with gzip.open(BASE/'parts'/f'{i:05d}.jsonl.gz','rt') as f:
  for line in f:
   d=json.loads(line);boards.append(d['board']);oldstats.update(r['status'] for r in d['rows']);oldcount.append(sum(r['usableForPositionMatch'] for r in d['rows']));oldwall+=d['elapsedSeconds']
assert len(boards)==1000 and len({b['id'] for b in boards})==1000
for b in boards:
 c=combinations(b['id'],125);old=combinations(b['id'],100)
 assert len(c)==len({r['comboIndex'] for r in c})==125
 assert {r['comboIndex'] for r in old}<={r['comboIndex'] for r in c}
 assert all(r['spinX']**2+r['spinY']**2<=.25 and .6<=r['velocity']<=4.5 for r in c)
(OUT/'layouts.json').write_text(json.dumps(boards,separators=(',',':')))
(OUT/'baseline.json').write_text(json.dumps(dict(shards=indices,layouts=1000,attempts=100000,status=dict(oldstats),validPerLayout=oldcount,summedBatchWallSeconds=oldwall),indent=2))
manifest=dict(state='prepared',layoutCount=1000,attemptsPerLayout=125,totalAttempts=125000,workers=8,selection='10 evenly spread shards from the original fixed uniformly shuffled layout schedule',originalShards=indices,sampling='Frozen strike-grid-v1; strike-subset100-v1 seed retained, sample count=125; uniform without replacement, contains original100 on this Python/runtime',directionPolicy='prepareAim + positionAimOffset once; buildPrediction once; zero neighbor retries',physics='frozen original production objects, planarReference, maxEvents500/maxTime15',presentation=False,searchEarlyStop=False,successOnlyCompression='post-first-contact cue, mandatory event anchors, ordered RDP <=0.002 m',layoutsSHA256=hashlib.sha256((OUT/'layouts.json').read_bytes()).hexdigest())
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2));print('Prepared 1000 unique layouts, 125000 attempts; each125 includes original100; fixed jitter valid.')
