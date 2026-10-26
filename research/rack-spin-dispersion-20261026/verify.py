from pathlib import Path
import json,gzip,hashlib,math,struct,statistics,random
ROOT=Path(__file__).resolve().parents[2];O=ROOT/'output/rack-spin-dispersion-20261026/sweep'
rs=[json.loads(l) for l in gzip.open(O/'raw.jsonl.gz','rt')];assert len(rs)==1200 and all(r['status']=='settled' for r in rs)
c=json.loads((O/'closure.json').read_text());assert c['success'] and c['total']==1200 and c['shutdownExitCode']==0
assert json.loads((O/'worker-closure.json').read_text())['exitCode']==0
b=json.loads((O/'source-binding.json').read_text());assert all(hashlib.sha256((ROOT/x['path']).read_bytes()).hexdigest()==x['sha256'] for x in b['production'])
by={(r['input']['rackID'],r['input']['experiment']):r for r in rs}
f=lambda x:struct.unpack('f',struct.pack('f',x))[0]
def ulp(x):
 u=struct.unpack('I',struct.pack('f',abs(x)))[0]
 return struct.unpack('f',struct.pack('I',u+1))[0]-abs(x)
R=f(.028575);L=f(2.54);spacing=f(f(2*R)+f(.0002));ro=f(f(spacing*f(math.sqrt(3)))/2)
slots=[(f(f(-L/4)-f(f(row)*ro)),f(f(f(row)/2-f(col))*spacing)) for row in range(5) for col in range(row+1)]
minGap=math.inf;maxMagnitudeError=0
for r in rs:
 a=by[r['input']['rackID'],'independent__10.9'];assert r['canonicalNames']==a['canonicalNames'] and r['initialCueVelocity']==a['initialCueVelocity']
 assert [x['number'] for x in r['rack']]==[x['number'] for x in a['rack']]
 for i,(p,q,slot) in enumerate(zip(r['rack'],a['rack'],slots)):
  diff=abs(math.dist([p['x'],p['z']],slot)-math.dist([q['x'],q['z']],slot));maxMagnitudeError=max(maxMagnitudeError,diff)
  bound=math.hypot(ulp(p['x']),ulp(p['z']))
  assert diff<=bound,(i,diff,bound)
 for i,p in enumerate(r['rack']):
  for q in r['rack'][i+1:]:
   gap=math.dist([p['x'],p['z']],[q['x'],q['z']])-2*R;minGap=min(minGap,gap);assert gap>0
sc=json.loads((O/'scalars.json').read_text());groups={}
for x in sc:groups.setdefault(x['label'],{})[x['id']]=x
rng=random.Random(20261026);effects={}
for label,a in groups.items():
 base=groups['current__'+label.split('__')[1]];d=[a[i]['score']-base[i]['score'] for i in sorted(a)];samples=sorted(statistics.mean(rng.choices(d,k=100)) for _ in range(5000))
 # Ten non-control comparisons; also show Bonferroni familywise intervals.
 effects[label]=dict(n=100,mean=statistics.mean(d),ci95=[samples[125],samples[4874]],familywise95=[samples[12],samples[4987]])
energy={}
for label in groups:
 a=[r for r in rs if r['input']['experiment']==label];shares=[];counts=[];effective=[]
 for r in a:
  ss=dict(zip(r['names'],r['samples'][1]['states']));v=[sum(v*v for v in ss[n]['v']) for n in r['canonicalNames']];total=sum(v)
  shares.append((v[10]+v[14])/total);effective.append(total*total/sum(x*x for x in v));counts.append(sum(x>.1**2 for x in v))
 energy[label]=dict(cornerEnergyFraction=statistics.mean(shares),effectiveEnergyRecipients=statistics.mean(effective),ballsAbove0p1mps=statistics.mean(counts))
result=dict(n=1200,settled=1200,sourceUnchanged=True,minActualGapM=minGap,maxMagnitudeErrorM=maxMagnitudeError,scoreEffects=effects,early5ms=energy)
(O/'verification.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
