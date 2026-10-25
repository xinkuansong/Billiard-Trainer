from pathlib import Path
import sys,json,hashlib,random,math
from sampling import combinations
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'scripts/training-question-bank'))
from pocket_geometry_filter import layouts
BANK=ROOT/'output/two-ball-object-distance-sampled-20261024/object-distance-sampled-bank.json'
DEST=ROOT/'output/two-ball-strike-sampled100-20261024';DEST.mkdir(exist_ok=True)
if (DEST/'run-manifest.json').exists():raise SystemExit('Already prepared; do not regenerate active inputs')
raw=BANK.read_bytes();bank=json.loads(raw);byidx={t['inventoryTargetIndex']:t for t in bank['targets']}
boards=[]
for lid,cue,obj,pocket,angle in layouts(bank):
    t=byidx[int(lid.split(':')[1])];aim=t['aim']
    boards.append(dict(id=lid,cue=cue,object=obj,pocket=pocket,angle=angle,aim=[aim['x'],aim['z']]))
assert len(boards)==135700 and len({b['id'] for b in boards})==135700
p=DEST/'layouts.json';p.write_text(json.dumps(boards,separators=(',',':')))
# Frozen randomized processing order spreads angle/pocket/load across all workers.
schedule=list(range(len(boards)));random.Random(2026102408).shuffle(schedule)
(DEST/'schedule.json').write_text(json.dumps(schedule,separators=(',',':')))
old=json.loads((ROOT/'output/two-ball-strike-sampling-preview-20261024/sampling-example.json').read_text())
full=combinations(old['originalLayout'],630)
assert [{k:v for k,v in c.items() if k!='comboIndex'} for c in full]==old['combinations']
# Validate every layout's 100 samples before launch; no physics performed here.
tip_hist=[0]*45;speed_hist=[0]*14
for b in boards:
    cs=combinations(b['id']);assert len(cs)==100 and len({c['comboIndex'] for c in cs})==100
    for c in cs:
        assert math.isfinite(c['spinX']) and c['spinX']**2+c['spinY']**2<=.25
        assert .6<=c['velocity']<=4.5
        tip_hist[c['tipID']-1]+=1;speed_hist[c['speedID']-1]+=1
manifest=dict(schema='two-ball-strike-subset100-v1',status='prepared',layoutCount=len(boards),attemptsPerLayout=100,totalAttempts=13570000,workers=8,shardLayouts=100,sourceBank=str(BANK),sourceBankSHA256=hashlib.sha256(raw).hexdigest(),layoutsSHA256=hashlib.sha256(p.read_bytes()).hexdigest(),sampleProtocol='strike-grid-v1 then independent strike-subset100-v1 SHA256 Python Random; sorted uniform sample(range(630),100), no replacement/no refill',python=sys.version,tipHistogram=tip_hist,speedHistogram=speed_hist,solver='ShotPredictor.predictForPositionSolve',maxEvents=500,maxTime=15,includePresentation=False,simulationModel='planarReference',simulatedElevation=0,originalAimOverride=True)
(DEST/'run-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2));print('Prepared',len(boards),'layouts;',13570000,'attempts; original 630 jitter parity PASS')
