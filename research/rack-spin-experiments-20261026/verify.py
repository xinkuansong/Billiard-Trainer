from pathlib import Path
import gzip,json,math,hashlib,statistics,collections,random
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-spin-experiments-20261026';L=2.5399999618530273;R=.028574999421834946;M=.17000000178813934
allrows=[];audit={};oldrows={}
for phase in ['pilot-r2','holdout']:
 for l in gzip.open(ROOT/'output/rack-solver-repair-20261026'/phase/'raw.jsonl.gz','rt'):
  r=json.loads(l)
  if r['input']['condition']=='original' and r['input']['mode'] in [0,2]:oldrows[r['input']['rackID'],r['input']['mode']]=r
for phase,expected in [('sweep-r2',900),('holdout',1380)]:
 D=OUT/phase;closure=json.loads((D/'closure.json').read_text());assert closure['success'] and closure['total']==expected and closure['shutdownExitCode']==0
 assert json.loads((D/'worker-closure.json').read_text())['exitCode']==0
 assert json.loads((D/'probe-parity.json').read_text())['maxDelta']<1e-9
 binding=json.loads((D/'source-binding.json').read_text());assert all(hashlib.sha256((ROOT/r['path']).read_bytes()).hexdigest()==r['sha256'] for r in binding['production'])
 rs=[json.loads(l) for l in gzip.open(D/'raw.jsonl.gz','rt')];assert len(rs)==expected
 assert all(r['status']=='settled' for r in rs)
 counts=collections.Counter((r['input']['experiment'],r['input']['condition']) for r in rs)
 baselineMatches=0
 for r in rs:
  if r['input']['experiment'] in ['production','repair']:
   prev=oldrows[r['input']['rackID'],r['input']['mode']]
   for key in ['board','samples','contacts','spinTail','duration','status']:assert r[key]==prev[key]
   baselineMatches+=1
 allrows += rs;audit[phase]=dict(n=len(rs),baselineReplays=baselineMatches,settled=len(rs),counts={str(k):v for k,v in counts.items()},sourceUnchanged=True)
# Strict canonical comparison of 80 mirrored/reversed complete shots; axial angular reflection.
orig={(r['input']['rackID'],r['input']['experiment']):r for r in allrows if r['input']['condition']=='original'}
checks=[]
for r in allrows:
 c=r['input']['condition']
 if c=='original':continue
 a=orig[r['input']['rackID'],r['input']['experiment']];dp=dv=dw=0
 for sa,sb in zip(a['samples'],r['samples']):
  bm=dict(zip(r['names'],sb['states']))
  for n,x in zip(a['names'],sa['states']):
   p=x['p'][:];v=x['v'][:];w=x['w'][:]
   if c=='mirror':p[2]*=-1;v[2]*=-1;w[0]*=-1;w[1]*=-1
   y=bm[n];dp=max(dp,math.dist(p,y['p']));dv=max(dv,math.dist(v,y['v']));dw=max(dw,math.dist(w,y['w']))
 assert dp==dv==dw==0,(r['input'],dp,dv,dw)
 assert a['board'].keys()==r['board'].keys();delta=0
 for n,p0 in a['board'].items():
  p=p0[:]
  if c=='mirror':p[1]=.5-p[1]
  delta=max(delta,math.dist(p,r['board'][n])*L)
 assert delta<=1e-6 and a['pocketed']==r['pocketed'] and a['duration']==r['duration'],(r['input'],delta)
 checks.append(dict(id=r['input']['rackID'],label=r['input']['experiment'],condition=c,maxBoardDeltaM=delta))
assert len(checks)==80;audit['invariance']=dict(n=80,exactEarly=80,maxBoardDeltaM=max(x['maxBoardDeltaM'] for x in checks))
# All actual cushion impacts, both translated and rotated kinetic energy.
events=[]
for r in allrows:
 if r['input']['condition']!='original':continue
 for e in r['cushionTrace']:
  def energy(s):return .5*M*(sum(v*v for v in s['v'])+.4*R*R*sum(v*v for v in s['w']))
  pre=e['pre'];post=e['post'];gain=energy(post)-energy(pre)
  norm=math.sqrt(sum(x*x for x in e['normal']));vn=abs(sum(x*y for x,y in zip(pre['v'],e['normal'])))/norm
  assert all(math.isfinite(x) for s in [pre,post] for k in ['p','v','w'] for x in s[k])
  events.append(dict(label=r['input']['experiment'],id=r['input']['rackID'],ball=pre['name'],time=e['time'],gain=gain,vn=vn,dw=post['w'][1]-pre['w'][1]))
assert not any(e['gain']>1e-6 for e in events)
audit['cushions']=dict(n=len(events),energyIncreaseAbove1microJ=0,maxEnergyGainJ=max(e['gain'] for e in events),normalSpeedAbove2p5=sum(e['vn']>2.5 for e in events))
(OUT/'verification.json').write_text(json.dumps(audit,indent=2));(OUT/'invariance.json').write_text(json.dumps(checks,indent=2));(OUT/'cushion-audit.json').write_text(json.dumps(events,separators=(',',':')))
print(json.dumps({k:v for k,v in audit.items() if k in ['invariance','cushions']},indent=2))
