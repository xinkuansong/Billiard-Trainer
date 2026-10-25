from pathlib import Path
import json,shutil,hashlib,collections,importlib.util
from stratified_sampling import combinations,full_grid,VERSION,QUOTAS
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name
base=ROOT/'output/two-ball-sample125-once-20261024';shutil.copy2(base/'layouts.json',OUT/'layouts.json')
boards=json.loads((OUT/'layouts.json').read_text());totals=collections.Counter()
for b in boards:
 cs=combinations(b['id']);assert cs==combinations(b['id']);assert len(cs)==len({c['comboIndex'] for c in cs})==125
 totals.update(c['strokeCategory'] for c in cs)
 for c in cs:
  x,y=c['spinX'],c['spinY'];assert x*x+y*y<=.25 and .6<=c['velocity']<=4.5
  expected='center' if x==y==0 else 'vertical' if x==0 else 'horizontal' if y==0 else 'mixed';assert c['strokeCategory']==expected
 for cat,size in [('center',14),('vertical',7),('horizontal',3)]:
  t=collections.Counter(c['tipID'] for c in cs if c['strokeCategory']==cat);assert all(v==size for v in t.values())
 mixed=[c for c in cs if c['strokeCategory']=='mixed'];assert len({c['tipID'] for c in mixed})==32
 sc=collections.Counter(c['speedID'] for c in mixed);assert len(sc)==14 and set(sc.values())=={3,4}
manifest=dict(state='prepared',samplingVersion=VERSION,layouts=1000,attemptsPerLayout=125,quotas=QUOTAS,totals=dict(totals),workers=16,layoutsSHA256=hashlib.sha256((OUT/'layouts.json').read_bytes()).hexdigest(),samplingSHA256=hashlib.sha256((HERE/'stratified_sampling.py').read_bytes()).hexdigest(),binarySHA256=hashlib.sha256((ROOT/'research/two-ball-sample125-once-20261024/Worker.app/Worker').read_bytes()).hexdigest(),rules='Frozen grid jitter and speed RNG; lock center/both axes; preserve zero axis for pure stroke. Center14speeds; vertical7 paired bins per tip; horizontal3 segments(5/5/4bins) per tip; mixed32tips covered with 51total and 3or4 per speed bin. No retries/refills. Frozen physics full termination15s/500events, success2mm keypoints.')
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2));(OUT/'sampling-preview.json').write_text(json.dumps(combinations(boards[0]['id']),indent=2))
src=(ROOT/'research/two-ball-concurrency-20261024/run_round.py').read_text()
src=src.replace("N=int(sys.argv[2]);OUT=ROOT/'output'/HERE.name/f'p{N}';sys.path.insert(0,str(ROOT/'research/two-ball-sample125-once-20261024'))","N=16;OUT=ROOT/'output'/HERE.name;sys.path.insert(0,str(ROOT/'research/two-ball-concurrency-20261024'))")
src=src.replace('from sampling import combinations','from stratified_sampling import combinations, VERSION')
src=src.replace("assert len(result['rows'])==125", "assert len(result['rows'])==125\n     result['samplingVersion']=VERSION\n     for row,c in zip(result['rows'],cs):row['strokeCategory']=c['strokeCategory']")
(HERE/'run.py').write_text(src)
# Keep original event-order repair and original backups as a separate postprocess stage.
shutil.copy2(ROOT/'research/two-ball-sample125-once-20261024/normalize_events.py',HERE/'normalize_events.py')
print(json.dumps(manifest,indent=2))
