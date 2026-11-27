import json,random,math
from native import OUT,ROOT,run

def perturb(s,delta):
 d=dict(s);angle=math.atan2(s['dir'][1],s['dir'][0])+math.radians(delta[0]);d.update(v=s['v']*(1+delta[1]),sx=s['sx']+delta[2],sy=s['sy']+delta[3])
 if delta[0]:d['dir']=[math.cos(angle),math.sin(angle)]
 return d

def main():
 samples=json.load(open(OUT/'samples.json'));rng=random.Random(2026103001);jobs=[]
 for q in samples:
  sid=q['sampleID'];base=dict(B=q['candidate']['B'],railID=q['candidate']['railID'],blockers=[],tracks=False)
  for rt in q['archiveRoutes']:
   s=dict(q['seed'],route=rt['comboIndex'],dir=rt['strikeDirection'],v=rt['velocity'],sx=rt['spinX'],sy=rt['spinY'])
   for i in range(12):
    delta=[rng.uniform(-.35,.35),rng.uniform(-.30,.30),rng.uniform(-.16,.16),rng.uniform(-.22,.22)]
    ns=perturb(s,delta)
    jobs.append(dict(base,id=f"{sid}/search/{rt['comboIndex']}/{i}",seed=ns))
 rows=run('search',jobs);byjob={j['id']:j for j in jobs}
 lower=[]
 for q in samples:
  found=[r for k,r in rows.items() if k.startswith(q['sampleID']+'/') and r['success'] and 1<=r.get('observedRail',-1)<q['candidate']['railOrdinal']]
  lower.extend(dict(byjob[r['id']],tracks=True) for r in found);print(q['sampleID'],'supplemental lower',len(found),flush=True)
 run('search-lower-tracks',lower)
 probes=json.load(open(ROOT/'output/k-ball-tolerance-20261029/protocol.json'))['probes'];jobs=[]
 for q in samples:
  for p in probes:
   jobs.append(dict(id=q['sampleID']+'/tolerance/'+p['id'],seed=perturb(q['seed'],p['delta']),B=q['candidate']['B'],railID=q['candidate']['railID'],blockers=[],tracks=True))
 run('tolerance-before',jobs)
if __name__=='__main__':main()
