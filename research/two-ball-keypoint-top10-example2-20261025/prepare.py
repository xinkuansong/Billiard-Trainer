from pathlib import Path
import json,gzip,hashlib,shutil
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name
FULL=ROOT/'output/two-ball-independent125-full-20261024';CAND=ROOT/'output/two-ball-second-candidates-20261024';LID='grid-v3:1466:93:3'
read=lambda p:json.loads(p.read_text())
boards=read(FULL/'layouts.json');idx=next(i for i,b in enumerate(boards) if b['id']==LID);schedule=read(FULL/'schedule.json');part=FULL/f'parts/{schedule.index(idx)//100:05}.jsonl.gz'
with gzip.open(part,'rt') as f:record=next(r for line in f if (r:=json.loads(line))['id']==LID)
with (CAND/'second-ball-candidates.jsonl').open() as f:candidates=next(r for line in f if (r:=json.loads(line))['id']==LID)
geo=read(ROOT/'output/two-ball-object-distance-sampled-20261024/object-distance-sampled-bank.json')['geometry']
assert len(record['rows'])==125 and len(candidates['candidates'])==59
valid=[r for r in record['rows'] if r['status']=='success'];assert all(r['usableForPositionMatch'] and r['trajectory2mm']['toleranceMeters']==.002 for r in valid)
assert all(r['cueCushionsBeforeContact']==0 and r['simulatedElevationRadians']==0 for r in valid)
score=ROOT/'QiuJi/Features/SeparationPractice/SeparationTrajectoryScore.swift';shutil.copy2(score,HERE/score.name);shutil.copy2(ROOT/'research/two-ball-trajectory-compression-p2-20261024/main.swift',HERE/'main.swift')
subset={'record':record,'candidates':candidates,'geometry':geo,'sources':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [part,score,CAND/'manifest.json']},'candidateManifest':read(CAND/'manifest.json')}
(OUT/'input.json').write_text(json.dumps(subset,ensure_ascii=False))
paths={'key2mm':[{'comboIndex':r['comboIndex'],'points':[{'position':{'x':p[1],'z':p[2]}} for p in r['trajectory2mm']['points']]} for r in valid]}
(OUT/'p2-input.json').write_text(json.dumps(paths))
print('EXTRACTED',LID,'success',len(valid),'candidates',len(candidates['candidates']),'allPairs',len(valid)*(len(valid)-1)//2)
print('first-target pre-pocket main rail events',sum(any(e['kind']=='cushion' and e.get('ball')=='object' and e.get('surface')=='mainRail' for e in r['events']) for r in valid))
