"""Independently recompute success and ordinal from serialized native events."""
import json,math,hashlib,collections
from native import ROOT,OUT
from place import stage,poly,distance,R
from prepare import segdist

def judgment(j,r):
 if r.get('reason')=='inaccessible':return False,-1,False
 e=r['events'];hit=lambda z,a,b:z['kind']=='ballBall' and set(z['balls'])=={a,b}
 cue=[i for i,z in enumerate(e) if z['kind']=='ballBall' and 'cueBall' in z['balls']]
 a=cue[0] if cue and hit(e[cue[0]],'cueBall','object') else None
 b=next((i for i,z in enumerate(e) if hit(z,'cueBall','kTarget')),None)
 pot=next((i for i,z in enumerate(e) if z['kind']=='pocket' and z['ball']=='object' and z['pocket']==f"pocket_{j['seed']['pocket']}"),None)
 cutoff=max(b if b is not None else len(e),pot if pot is not None else len(e))
 touched=any(z['kind']=='ballBall' and any(s.startswith('block_') for s in z['balls']) and any(s in ('cueBall','object') for s in z['balls']) for i,z in enumerate(e) if i<=cutoff)
 success=r['complete'] and a is not None and b is not None and a<b and pot is not None and not touched
 ordinal=-1;bc=r.get('BFirstContact')
 if a is not None and b is not None and a<b and bc and bc['other']=='cueBall' and abs(bc['time']-e[b]['time'])<1e-5:
  normals=[(0,-1),(0,-1),(0,1),(0,1),(1,0),(-1,0)];n=normals[j['railID']];v=bc['velocity'];rails=[z['cushion'] for z in e[a+1:b] if z['kind']=='cushion' and z['ball']=='cueBall' and 0<=z['cushion']<6]
  if sum(t*t for t in v)>0 and all(math.isfinite(t) for t in v):
   if sum(x*y for x,y in zip(v,n))<0:ordinal=len(rails)+1
   else:ordinal=len(rails) if rails and normals[rails[-1]]==n else 0
 return success,ordinal,touched

def main():
 allcount=0;stages={};hashes={};mechanisms=collections.Counter()
 for d in sorted(OUT.iterdir()):
  if not d.is_dir() or not list(d.glob('jobs-*.jsonl')):continue
  jobs=stage(d.name,'jobs');rs=stage(d.name,'results');assert set(jobs)==set(rs),d
  for k,j in jobs.items():
   r=rs[k];success,ordinal,touched=judgment(j,r)
   assert success==r['success'],(d.name,k,'success')
   if r.get('reason')!='inaccessible':
    # An A contact occurring after a prior wrong first ball may still have ordinal metadata;
    # it cannot affect success. Require exact ordinal on valid first-A trials.
    if r['firstA']:assert ordinal==r.get('observedRail'),(d.name,k,'rail')
    assert touched==r['obstacleContactBeforeCompletion'],(d.name,k,'contact')
   mechanisms['inaccessible' if r.get('reason')=='inaccessible' else ('forbidden-contact' if touched else 'no-forbidden-contact')]+=1
  stages[d.name]=len(jobs);allcount+=len(jobs)
  for p in d.glob('*.jsonl'):hashes[str(p.relative_to(OUT))]=hashlib.sha256(p.read_bytes()).hexdigest()
 samples=json.load(open(OUT/'samples.json'));plans=json.load(open(OUT/'placements-r2.json'));initial=stage('initial','results');after=stage('placed-r2','results');tb=stage('tolerance-before','results');hb=stage('final-holdout-before','results');ha=stage('final-holdout-after','results');summary=[]
 geometry=json.load(open(ROOT/'output/k-ball-full-20261029/geometry.json'))
 for q,p in zip(samples,plans):
  sid=q['sampleID'];n=q['candidate']['railOrdinal'];ref=after[sid+'/reference'];ok=lambda r:r['success'] and r.get('observedRail')==n;low=lambda r:r['success'] and 1<=r.get('observedRail',-1)<n
  assert initial[sid+'/reference']['events']==q['baseline']['events'],(sid,'archive replay drift')
  assert ok(ref),(sid,'reference lost')
  positions=[q['seed']['cue'],q['seed']['object'],q['candidate']['B']]+p['blockers']
  for i,b in enumerate(p['blockers']):
   assert abs(b[0])<=geometry['length']/2-R-.002 and abs(b[1])<=geometry['width']/2-R-.002
   assert min(math.dist(b,z) for z in positions[:3+i])>=2*R+.002
   assert min(distance(b,poly(initial[sid+'/reference'],name)) for name in ('cueBall','object'))>=2*R+.012
  assert len(set([p['A'],p['B']]+p['numbers']))==2+len(p['numbers']);assert p['B']==8
  assert all((x>=9)==(p['obstacleGroup']=='stripes') for x in p['numbers']);assert (p['A']>=9)!=(p['obstacleGroup']=='stripes')
  b=[(k,r) for k,r in tb.items() if k.startswith(sid+'/')];before=sum(ok(r) for k,r in b);aft=sum(ok(after[k]) for k,r in b);lost=[k for k,r in b if ok(r) and not ok(after[k])]
  trainRemaining=sum(low(after[k]) for k in p['lowerIDs']);holdBefore=sum(low(r) for k,r in hb.items() if k.startswith(sid+'/'));holdAfter=sum(low(r) for k,r in ha.items() if k.startswith(sid+'/'))
  status='not-needed-in-search' if not p['blockers'] else ('sample-pass' if not trainRemaining and not holdAfter and not lost else 'needs-more-search-or-placement')
  summary.append(dict(id=sid,rail=n,axis=q['candidate']['axis'],pocket=q['seed']['pocket'],obstacles=len(p['blockers']),referencePass=ok(ref),toleranceBefore=before,toleranceAfter=aft,toleranceLost=len(lost),knownLower=p['knownLowerCount'],knownLowerRemaining=trainRemaining,holdoutBefore=holdBefore,holdoutAfter=holdAfter,status=status))
 binding=json.load(open(OUT/'source-binding.json'));checked=[]
 for x in binding['sources']:
  if x['currentProduction']:
   assert hashlib.sha256((ROOT/x['path']).read_bytes()).hexdigest()==x['sha256'],x['path'];checked.append(x['path'])
 report=dict(passed=True,attemptedTrials=allcount,simulations=allcount-mechanisms["inaccessible"],stages=stages,mechanisms=dict(mechanisms),sourceFilesUnchanged=len(checked),samples=summary,limitations=['Finite sampled search; no global uniqueness proof','Purposeful sample; not an estimate of whole-bank feasibility','No App integration or physical-table calibration'])
 (OUT/'audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));(OUT/'evidence-hashes.json').write_text(json.dumps(hashes,indent=2));print(json.dumps(report,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
