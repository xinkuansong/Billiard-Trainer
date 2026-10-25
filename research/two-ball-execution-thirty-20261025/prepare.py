"""Expand to thirty distinct layouts without modifying the bank or scoring formula."""
from pathlib import Path
import copy,gzip,hashlib,json,math,random,collections
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'output/two-ball-middle-geometry-comfort-20261025'
PRIOR=ROOT/'output/two-ball-execution-formula-five-20261025/data.json'
OUT=ROOT/'output/two-ball-execution-thirty-20261025'
SEED=2026102530
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def evaluate(s):
 original={q['comboIndex']:i for i,q in enumerate(s['candidate']['top5'],1)}
 old=sorted(s['routes'],key=lambda t:(2.5*abs(t['spinX'])+abs(t['spinY'])+.25*max(0,t['velocity']-4),original[t['comboIndex']]))
 s['ranking']=[dict(rank=i,comboIndex=t['comboIndex'],originalRank=original[t['comboIndex']],effort=2.5*abs(t['spinX'])+abs(t['spinY'])+.25*max(0,t['velocity']-4)) for i,t in enumerate(old,1)]
 previous={q['comboIndex']:q for q in s['ranking']}; new=[]
 for t in s['routes']:
  x=abs(t['spinX']);h=max(t['spinY'],0);d=max(-t['spinY'],0);u=t['velocity']/4.5;n=t['cueMainRailsAfterContact']
  xy=[p[1:] for p in t['trajectory2mm']['points']];length=sum(math.dist(a,b) for a,b in zip(xy,xy[1:]))
  parts=dict(stroke=2.5*x+.8*h+1.2*d,power=.8*u*u,route=.12*n+.06*length,interaction=.6*x*u+.15*n*x)
  e=sum(parts.values());q=previous[t['comboIndex']]
  new.append(dict(comboIndex=t['comboIndex'],originalRank=q['originalRank'],previousRank=q['rank'],previousEffort=q['effort'],lengthMeters=length,components=parts,effort=e,difficulty=100*e/(e+1)))
 new.sort(key=lambda q:(q['effort'],q['originalRank']))
 for i,q in enumerate(new,1):q.update(rank=i,rankChange=q['previousRank']-i)
 s['newRanking']=new
 return s
def features(s):
 ts={t['comboIndex']:t for t in s['routes']};qs=s['newRanking'];win=ts[qs[0]['comboIndex']]
 center=[q for q in qs if abs(ts[q['comboIndex']]['spinX'])<.02 and abs(ts[q['comboIndex']]['spinY'])<.02]
 return dict(changed=sum(q['rankChange']!=0 for q in qs),winnerChanged=qs[0]['previousRank']!=1,
  minGap=min(qs[i+1]['difficulty']-qs[i]['difficulty'] for i in range(4)),
  shortDrawWinner=win['cueMainRailsAfterContact']==0 and win['spinY']<-.25 and bool(center),
  lowSpeedLargeSide=any(t['velocity']<1.2 and abs(t['spinX'])>.35 for t in ts.values()),
  maxLength=max(q['lengthMeters'] for q in qs),maxRails=max(t['cueMainRailsAfterContact'] for t in ts.values()),
  minRails=min(t['cueMainRailsAfterContact'] for t in ts.values()),
  speedRange=max(t['velocity'] for t in ts.values())-min(t['velocity'] for t in ts.values()),
  maxDrop=max(-q['rankChange'] for q in qs),
  longDrop=max((q['lengthMeters'] for q in qs if q['rankChange']<=-2),default=0))
def group(s):
 a=s['board']['angle'];p=s['board']['pocket']
 if p<4:return 0 if a<=15 else (1 if a<=30 else 2)
 return 3 if a<=20 else 4
GROUPS=['角袋 · 0–15°','角袋 · 16–30°','角袋 · 大于30°','中袋 · 0–20°','中袋 · 大于20°']
def main():
 OUT.mkdir(exist_ok=True);prior=json.loads(PRIOR.read_text());samples=copy.deepcopy(prior['samples']);used={s['id'] for s in samples}
 for s in samples:s.update(selectionKind='原5题',features=features(s))
 pool=[];scope=[];count=0
 for item in json.loads((SRC/'parts-index.json').read_text())[::10]:
  p=SRC/'final'/f'{item["stem"]}.jsonl.gz';assert sha(p)==item['finalSHA256'];scope.append(dict(path=str(p.relative_to(ROOT)),sha256=sha(p)))
  for line in gzip.decompress(p.read_bytes()).splitlines():
   row=json.loads(line);count+=1
   if row['id'] in used:continue
   routes={t['comboIndex']:t for t in row['routes']}
   for c in row['candidates']:
    if len(c['top5'])!=5:continue
    s=evaluate(dict(id=row['id'],board=row['board'],candidate=c,routes=[routes[q['comboIndex']] for q in c['top5']],source=str(p.relative_to(ROOT)),sourceSHA256=item['finalSHA256']))
    s['features']=features(s);pool.append(s)
 rng=random.Random(SEED)
 # Twenty balance cases: uniform layouts within each stratum, then a uniform B.
 for k,title in enumerate(GROUPS):
  for _ in range(4):
   groups=collections.defaultdict(list)
   for s in pool:
    if s['id'] not in used and group(s)==k:groups[s['id']].append(s)
   layout=rng.choice(sorted(groups));s=copy.deepcopy(rng.choice(sorted(groups[layout],key=lambda x:x['candidate']['cellID'])))
   s.update(number=len(samples)+1,title=title,selectionKind='分层抽样');samples.append(s);used.add(s['id'])
 # Five deliberately chosen diagnostic cases, kept separate from balanced samples.
 specs=[('短线低杆与中杆',lambda f:f['shortDrawWinner'],lambda f:(f['changed'],f['maxDrop'])),
        ('长路线明显后移',lambda f:f['longDrop']>4,lambda f:(f['longDrop'],f['changed'])),
        ('相近分数换位',lambda f:f['changed']>=3,lambda f:(-f['minGap'],f['changed'])),
        ('小力度与大侧塞',lambda f:f['lowSpeedLargeSide'],lambda f:(f['changed'],f['speedRange'])),
        ('零库到多库的取舍',lambda f:f['minRails']==0 and f['maxRails']>=3,lambda f:(f['speedRange'],f['changed']))]
 for title,condition,key in specs:
  eligible=[s for s in pool if s['id'] not in used and condition(s['features'])];assert eligible,title
  selected=max(eligible,key=lambda s:(key(s['features']),s['id'],-s['candidate']['cellID']))
  s=copy.deepcopy(selected);s.update(number=len(samples)+1,title=title,selectionKind='定向诊断');samples.append(s);used.add(s['id'])
 assert len(samples)==len(used)==30
 data=dict(schema='thirty-execution-comparison-v1',model=prior['model'],previousModel=prior['previousModel'],geometry=prior['geometry'],source=prior['source'],previousPreview=dict(path=str(PRIOR.relative_to(ROOT)),sha256=sha(PRIOR)),selection=dict(seed=SEED,scannedLayouts=count,scannedShards=len(scope),scope=scope,method='keep original five; add twenty (four per pocket/angle stratum; uniform eligible layout then B); add five targeted diagnostic cases; all distinct layouts; only five-route questions'),samples=samples)
 (OUT/'data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2))
 def stats(ss):
  return dict(questions=len(ss),routes=5*len(ss),orderChanged=sum(s['features']['changed']>0 for s in ss),winnerChanged=sum(s['features']['winnerChanged'] for s in ss),rankChanged=sum(s['features']['changed'] for s in ss),adjacentGapUnderTwo=sum(s['features']['minGap']<2 for s in ss),noRailDrawBeatsCenter=sum(s['features']['shortDrawWinner'] for s in ss))
 summary=dict(all=stats(samples),original=stats(samples[:5]),balanced=stats(samples[5:25]),diagnostic=stats(samples[25:]),angleRange=[min(s['board']['angle'] for s in samples),max(s['board']['angle'] for s in samples)],pocketTypes=dict(collections.Counter('角袋' if s['board']['pocket']<4 else '中袋' for s in samples)),speedRange=[min(t['velocity'] for s in samples for t in s['routes']),max(t['velocity'] for s in samples for t in s['routes'])],maxRails=max(t['cueMainRailsAfterContact'] for s in samples for t in s['routes']))
 (OUT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2));print(json.dumps(summary,ensure_ascii=False))
 for s in samples:
  print(s['number'],s['title'],s['id'],s['candidate']['cellID'],'angle',s['board']['angle'],'order',[q['originalRank'] for q in s['ranking']],'->',[q['originalRank'] for q in s['newRanking']],s['features'])
if __name__=='__main__':main()
