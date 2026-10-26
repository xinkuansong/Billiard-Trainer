from common import *
rows={};group={v:[] for v in json.loads((OUT/'confirmation/protocol.json').read_text())['variants']}
for raw in readraw(OUT/'confirmation'):
 p=np.array([[a[0]*L-L/2,a[1]*L-W/2] for k,a in raw['board'].items() if k!='cueBall']);n=len(p)
 d=np.linalg.norm(p[:,None]-p[None,:],axis=2);np.fill_diagonal(d,np.inf);adj=d<4*R;close=int(np.any(adj,axis=1).sum());seen=set();components=[]
 for i in range(n):
  if i in seen:continue
  todo=[i];seen.add(i);size=0
  while todo:
   j=todo.pop();size+=1
   for k in np.flatnonzero(adj[j]):
    if int(k) not in seen:seen.add(int(k));todo.append(int(k))
  components.append(size)
 a=dict(id=raw['input']['rackID'],variant=raw['input']['variant'],remaining=n,closeBalls=close,closeFraction=close/n,largestGroup=max(components),cueScratched=int(raw['cueScratched']))
 group[a['variant']].append(a)
summary={v:{k:float(np.mean([r[k] for r in rr])) for k in ['remaining','closeBalls','closeFraction','largestGroup','cueScratched']} for v,rr in group.items()}
write(OUT/'confirmation/final-outcomes.json',dict(note='Descriptive secondary diagnostic: adjacency threshold center distance <4R (surface gap < one diameter). Not a replacement score or pre-registered primary test.',variants=summary));print(json.dumps(summary,indent=2))
