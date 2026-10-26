from pathlib import Path
import gzip,json,math,statistics,collections
OUT=Path('output/rack-spin-tail-20261026');alpha=5*(10*2/5/9)*9.81/2;R=.028574999421834946
rows=[]
for line in gzip.open(OUT/'raw.jsonl.gz','rt'):
 r=json.loads(line);fs=r['frames'];names=r['names'];t0=r['t0']
 # first instant after the final translating frame across all balls
 moving=[k for k in range(len(fs[0])) if any(f[k]['state'] in ('rolling','sliding') for f in fs)]
 k=min(max(moving)+1,len(fs[0])-1);stop=fs[0][k]['t']
 spinning=[]
 for i,f in enumerate(fs):
  if f[k]['state']!='spinning' or abs(f[k]['w'][1])<1e-4:continue
  end=next(x['t'] for x in f[k:] if x['state']=='stationary')
  changes=[]
  for pre,post in zip(f,f[1:]):
   dt=post['t']-pre['t'];wy=math.copysign(max(0,abs(pre['w'][1])-alpha*dt),pre['w'][1]);dw=post['w'][1]-wy
   if abs(dw)<.001:continue
   cs=[c for c in r['contacts'] if abs(c['t']+t0-post['t'])<2e-6 and (c['a']==names[i] or c['b']==names[i])]
   changes.append(dict(t=post['t'],preWy=wy,postWy=post['w'][1],dw=dw,contacts=cs,preV=pre['v'],postV=post['v']))
  peak=max(f,key=lambda x:abs(x['w'][1]))
  spinning.append(dict(name=names[i],slot=i-1,number=None if i==0 else r['rack'][i-1]['number'],wy=f[k]['w'][1],rps=abs(f[k]['w'][1])/(2*math.pi),tail=end-stop,end=end,peakWy=peak['w'][1],peakTime=peak['t'],changes=sorted(changes,key=lambda x:abs(x['dw']),reverse=True)[:5]))
 endNonzero=[x for x in r['playbackEnd'] if x['state']!='pocketed' and any(abs(v)>1e-4 for v in x['w']+x['v'])]
 rows.append(dict(id=r['input']['id'],seed=r['input']['seed'],duration=r['duration'],lastTranslation=stop,tail=max([x['tail'] for x in spinning],default=0),spinning=spinning,playbackEndNonzero=endNonzero))
def stats(a):
 s=sorted(a);return dict(mean=statistics.mean(a),median=statistics.median(a),max=max(a),p90=s[int(.9*(len(s)-1))])
s=dict(n=len(rows),duration=stats([r['duration'] for r in rows]),lastTranslation=stats([r['lastTranslation'] for r in rows]),tail=stats([r['tail'] for r in rows]),tailAbove={str(t):sum(r['tail']>t for r in rows) for t in [0,1,2,3,5]},spinnerCount=dict(collections.Counter(len(r['spinning']) for r in rows)),lastBall=dict(collections.Counter(max(r['spinning'],key=lambda s:s['end'])['name'] for r in rows if r['spinning'])),endNonzero=sum(bool(r['playbackEndNonzero']) for r in rows),alpha=alpha)
s['lastSlot']=dict(collections.Counter(max(r['spinning'],key=lambda x:x['end'])['slot'] for r in rows if r['spinning']))
s['largestSpinImpulseSurface']=dict(collections.Counter(max(r['spinning'],key=lambda x:x['end'])['changes'][0]['contacts'][0]['kind'] for r in rows if r['spinning']))
(OUT/'rows.json').write_text(json.dumps(rows,indent=2));(OUT/'summary.json').write_text(json.dumps(s,indent=2));print(json.dumps(s,indent=2));print('longest',max(rows,key=lambda r:r['tail'])['id'])
