import json,random,math,sys
from native import OUT,run
from place import stage
from search import perturb

def main():
 final='--final' in sys.argv
 samples=json.load(open(OUT/'samples.json'));plans={p['sampleID']:p for p in json.load(open(OUT/('placements-r2.json' if final else 'placements.json')))};initial=stage('initial','jobs');search=stage('search','jobs');known={**initial,**search,**stage('holdout-before','jobs')};rng=random.Random(2026103003 if final else 2026103002);before=[];after=[]
 for q in samples:
  sid=q['sampleID'];p=plans[sid];anchors=[known[k]['seed'] for k in p['lowerIDs']] or [known[k]['seed'] for k in initial if k.startswith(sid+'/archive/')]
  for i in range(512):
   if i<256:s=perturb(rng.choice(anchors),[rng.uniform(-.18,.18),rng.uniform(-.18,.18),rng.uniform(-.10,.10),rng.uniform(-.14,.14)])
   else:
    s=perturb(q['seed'],[rng.uniform(-.8,.8),0,0,0]);angle=rng.uniform(-math.pi,math.pi);rad=.85*math.sqrt(rng.random());s.update(v=rng.uniform(.6,4),sx=rad*math.cos(angle),sy=rad*math.sin(angle))
   j=dict(id=f'{sid}/holdout/{i}',seed=s,B=q['candidate']['B'],railID=q['candidate']['railID'],tracks=False,blockers=[]);before.append(j);after.append(dict(j,blockers=p['blockers']))
 prefix='final-' if final else ''
 rb=run(prefix+'holdout-before',before);ra=run(prefix+'holdout-after',after);track=[]
 for q in samples:
  sid=q['sampleID'];n=q['candidate']['railOrdinal'];lo=lambda r:r['success'] and 1<=r.get('observedRail',-1)<n
  b=[r for k,r in rb.items() if k.startswith(sid+'/') and lo(r)];a=[r for k,r in ra.items() if k.startswith(sid+'/') and lo(r)]
  print(sid,'holdout lower',len(b),'->',len(a),flush=True)
  ids={r['id'] for r in b+a}
  for j in before:
   if j['id'] in ids:track.append(dict(j,tracks=True))
 run(prefix+'holdout-lower-tracks',track)
if __name__=='__main__':main()
