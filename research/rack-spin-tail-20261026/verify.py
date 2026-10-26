import gzip,json,math
from pathlib import Path
p=Path('output/rack-spin-tail-20261026');n=0;segments=0;err=0;horizontal=0
for line in gzip.open(p/'raw.jsonl.gz','rt'):
 r=json.loads(line);n+=1;assert r['status']=='settled'
 assert all(x['state']=='pocketed' or max(map(abs,x['w']+x['v']))<1e-4 for x in r['playbackEnd'])
 for frames in r['frames']:
  for a,b in zip(frames,frames[1:]):
   if a['state']!='spinning' or b['state'] not in ('spinning','stationary'):continue
   if a['p']!=b['p'] or any(a['v']) or any(b['v']):continue
   expected=math.copysign(max(0,abs(a['w'][1])-10.9*(b['t']-a['t'])),a['w'][1])
   err=max(err,abs(expected-b['w'][1]));horizontal=max(horizontal,abs(a['w'][0]),abs(a['w'][2]));segments+=1
assert n==100 and err<0.001
closure=json.load(open(p/'closure.json'));assert closure['success'] and closure['shutdownExitCode']==0
result=dict(samples=n,pureSpinSegments=segments,maxDecayErrorRadPerSec=err,maxHorizontalSpinResidual=horizontal,allNonPocketedPlaybackEndStopped=True,success=True)
(p/'verification.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
