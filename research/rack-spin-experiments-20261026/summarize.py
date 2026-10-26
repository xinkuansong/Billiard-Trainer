from pathlib import Path
import json,statistics,collections,random
O=Path('output/rack-spin-experiments-20261026');rows=[]
for phase in ['sweep-r2','holdout']:rows+=json.loads((O/phase/'scalars.json').read_text())
summary={};by=collections.defaultdict(dict)
for r in rows:by[r['label']][r['id']]=r
rng=random.Random(20261026)
def ci(d):
 means=sorted(statistics.mean(rng.choices(d,k=len(d))) for _ in range(3000));return [means[75],means[2924]]
for label,rs in by.items():
 a=list(rs.values());tails=sorted(x['tail'] for x in a)
 z=dict(n=len(a),settled=sum(x['status']=='settled' for x in a),meanScore=statistics.mean(x['score'] for x in a),pass1p2=sum(x['score']>=1.2 for x in a),meanTail=statistics.mean(tails),p90Tail=tails[int(.9*(len(a)-1))],maxTail=max(tails),tailOver5=sum(t>5 for t in tails),tailOver1=sum(t>1 for t in tails),scratch=sum(x['scratch'] for x in a),cpuMS=statistics.mean(x['cpuMS'] for x in a),meanDuration=statistics.mean(x['duration'] for x in a),meanLastTranslation=statistics.mean(x['lastTranslation'] for x in a))
 if label!='repair':
  ids=sorted(rs.keys()&by['repair'].keys());diff={k:[rs[i][k]-by['repair'][i][k] for i in ids] for k in ['tail','score']}
  z['pairedVsRepair']={k:dict(n=len(v),mean=statistics.mean(v),ci95=ci(v)) for k,v in diff.items()}
 summary[label]=z
(O/'combined-summary.json').write_text(json.dumps(summary,indent=2))
for k,v in summary.items(): print(f"{k:21s} n={v['n']} tail={v['meanTail']:.4f}s >5={v['tailOver5']} score={v['meanScore']:.4f} scratch={v['scratch']} cpu={v['cpuMS']:.1f}ms")
