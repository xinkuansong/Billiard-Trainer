from pathlib import Path
import subprocess,sys,json,time
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name
for n in (8,12,16):
 print('START_ROUND',n,flush=True)
 with (OUT/f'p{n}'/'launcher.log').open('w') as log:
  subprocess.run([sys.executable,str(HERE/'run_round.py'),sys.argv[1],str(n)],stdout=log,stderr=subprocess.STDOUT,check=True)
 r=json.loads((OUT/f'p{n}'/'run-complete.json').read_text());m=json.loads((OUT/f'p{n}'/'memory.json').read_text())
 print('ROUND_DONE',n,r['elapsedComputeAndWriteSeconds'],m['peakTotalRSSBytes'],flush=True)
(OUT/'execution-complete.json').write_text(json.dumps(dict(state='compute_complete_needs_parity',time=time.time())))
