"""Native boundary controls: a deliberate obstacle on late cue travel may be allowed."""
import json,math
from native import OUT,run
from place import stage,poly,distance,endtime,R,simplify

def main():
 samples={q['sampleID']:q for q in json.load(open(OUT/'samples.json'))};rs=stage('initial','results');js=stage('initial','jobs');jobs=[]
 for k,r in rs.items():
  if not r['success']:continue
  q=samples[k.split('/')[0]];end=endtime(r);protected=[poly(r,z) for z in ('cueBall','object')]
  # Also avoid B's full path, otherwise B can move the proposed blocker before the late cue contact.
  protected.append(simplify([p[1:] for p in r['tracks']['kTarget']]))
  starts=[q['seed']['cue'],q['seed']['object'],q['candidate']['B']]
  for p in [p[1:] for p in r['tracks']['cueBall'] if p[0]>end+.1]:
   if abs(p[0])<1.20 and abs(p[1])<.56 and min(distance(p,l) for l in protected)>.085 and min(math.dist(p,s) for s in starts)>.07:
    jobs.append(dict(js[k],id=k+'/late',blockers=[p],tracks=True));break
  if len(jobs)>=12:break
 rows=run('late-controls-r2',jobs);report=[]
 for k,r in rows.items():
  if not r['success']:continue
  contacts=[e for e in r['events'] if e['kind']=='ballBall' and any(b.startswith('block_') for b in e['balls']) and any(b in ('cueBall','object') for b in e['balls'])]
  if contacts:
   assert all(e['time']>endtime(r) for e in contacts)
   report.append(dict(id=k,success=True,completionTime=endtime(r),contactTimes=[e['time'] for e in contacts]))
 assert report,'No native positive control; do not claim this boundary verified'
 (OUT/'late-control-audit.json').write_text(json.dumps(dict(passed=True,actualLateContactSuccesses=report),indent=2));print('actual late-contact successes',len(report))
if __name__=='__main__':main()
