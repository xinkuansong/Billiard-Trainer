from pathlib import Path
import json,hashlib,shutil,subprocess,sys,gzip
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name;PILOT=ROOT/'research/two-ball-independent125-20261024';BASE=ROOT/'output/two-ball-strike-sampled100-20261024'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert not (OUT/'manifest.json').exists(),'Already prepared; never overwrite a run manifest'
for f in ['stratified_sampling.py','quota_sampling_v1.py']:shutil.copy2(PILOT/f,HERE/f)
source=(ROOT/'research/two-ball-strike-full-20261024/run_full.py').read_text().split('def parity(')[0].replace('from sampling import combinations','')
(HERE/'runtime_common.py').write_text(source)
monitor=(ROOT/'research/two-ball-concurrency-20261024/memory.py').read_text().replace('100ms target interval','1s target interval').replace('max(0,.1-', 'max(0,1.0-')
(HERE/'memory.py').write_text(monitor)
subprocess.run(['cp','-cR',str(ROOT/'research/two-ball-sample125-once-20261024/Worker.app'),str(HERE/'Worker.app')],check=True)
for f in ['layouts.json','schedule.json']:shutil.copy2(BASE/f,OUT/f)
b=json.loads((OUT/'layouts.json').read_text());schedule=json.loads((OUT/'schedule.json').read_text());assert len(b)==135700 and len({v['id'] for v in b})==135700 and sorted(schedule)==list(range(135700))
old=json.loads((BASE/'run-manifest.json').read_text());assert sha(Path(old['sourceBank']))==old['sourceBankSHA256'] and sha(OUT/'layouts.json')==old['layoutsSHA256']
with gzip.open(ROOT/'output/two-ball-independent125-20261024/parts/0000.jsonl.gz','rt') as f:fixture=json.loads(next(f))
(OUT/'parity-reference.json').write_text(json.dumps(fixture,separators=(',',':')))
for d in ['logs','parts','receipts','audit-paths','failures']:(OUT/d).mkdir()
from stratified_sampling import QUOTAS,VERSION
manifest=dict(state='prepared',schema='two-ball-independent125-full-v1',samplingVersion=VERSION,layoutCount=135700,attemptsPerLayout=125,totalAttempts=16962500,workers=16,shardLayouts=100,quotas=QUOTAS,categoryAttempts={k:v*135700 for k,v in QUOTAS.items()},sourceBank=old['sourceBank'],sourceBankSHA256=old['sourceBankSHA256'],layoutsSHA256=sha(OUT/'layouts.json'),scheduleSHA256=sha(OUT/'schedule.json'),samplingSHA256=sha(HERE/'stratified_sampling.py'),quotaBaselineSHA256=sha(HERE/'quota_sampling_v1.py'),binarySHA256=sha(HERE/'Worker.app/Worker'),paritySHA256=sha(OUT/'parity-reference.json'),python=sys.version,physics='Frozen pilot binary; prepareAim+positionAimOffset once, buildPrediction once; full physical termination maxTime15/maxEvents500; no direction retry/refill; success-only ordered event-anchored RDP2mm',sampling='Independent SHA256 seed per layout and combo; center fixed, vertical spinX=0, horizontal spinY=0; same disk .5 and cell +/- .075; stratified14/42/18/51; speeds .6–4.5 from14 frozen jittered bins',cushionMetadata='Normalize equal-time events by original event order before saving; keep excluded metadata on row for audit',fixtures='20 evenly spaced schedule positions, up to5 full successful trajectories each, audit only',resume='100-layout atomic gzip and SHA receipt; only committed shards reused after hash validation')
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2));print(json.dumps(manifest,ensure_ascii=False,indent=2))
