#!/usr/bin/env python3
from pathlib import Path
import json,hashlib,math,sys,collections
OUT=Path(__file__).resolve().parent
read=lambda n:json.loads((OUT/n).read_text())
def save(n,v):(OUT/n).write_text(json.dumps(v,ensure_ascii=False,indent=2))
def digest(n):return hashlib.sha256((OUT/n).read_bytes()).hexdigest()
def scan():
 data=read('scan-results.json');good=[x for x in data['candidates'] if x['status']=='nominal_both_passed'];selected=[]
 for order in ['AB','BA']:
  pool=sorted([x for x in good if x['order']==order],key=lambda c:(-c['proxy'],-c['axisPass'],-c['secondAxisPass'],c['id']))
  choices=[]
  def add(c):
   if c and c['id'] not in [x['id'] for x in choices] and len(choices)<12:choices.append(c)
  for style in read('protocol.json')['styles']:
   g=[x for x in pool if x['style']==style['id']]
   if g:add(g[0])
  for pair in sorted({(x['p1'],x['p2']) for x in pool}):add(next(x for x in pool if (x['p1'],x['p2'])==pair))
  for style in read('protocol.json')['styles']:
   g=[x for x in pool if x['style']==style['id']]
   if len(g)>1:add(g[1])
  for x in pool:add(x)
  selected+=choices
 assert selected,'No nominal two-shot strategy found; preserve outputs and inspect, do not relax criteria.'
 save('selected.json',selected);save('selection-identity.json',{'sha256':digest('selected.json'),'holdoutUsed':False})
 print('nominal candidates',len(good),'selected',len(selected),collections.Counter(x['order'] for x in selected),flush=True)
def stats(rows):
 n=len(rows);k=sum(x['complete'] for x in rows);f=sum(x['first']['accepted'] for x in rows);s=sum('second' in x for x in rows)
 z=1.96;d=1+z*z/n;c=(k/n+z*z/(2*n))/d;w=z*math.sqrt((k/n)*(1-k/n)/n+z*z/(4*n*n))/d
 return {'n':n,'complete':k,'rate':k/n,'firstPass':f,'secondExecuted':s,'secondConditionalRate':k/f if f else None,'wilson95':[c-w,c+w],'failures':dict(collections.Counter(x['status'] for x in rows)),'zeroErrorSecondPass':sum(x.get('secondBaselinePass',False) for x in rows),'noiseRescued':sum(x['complete'] and not x.get('secondBaselinePass',False) for x in rows)}
def audit(mode):
 assert digest('selected.json')==read('selection-identity.json')['sha256']
 data=read(mode+'-results.json');sel={x['id']:x for x in read('selected.json')};protocol=read('protocol.json');expected=protocol[mode+'Offsets'];assert {x['id'] for x in data['results']}==set(sel)
 for result in data['results']:
  rows=result['rows'];assert len(rows)==len(expected)
  for i,row in enumerate(rows):
   assert row['sampleIndex']==i and row['offset']==expected[i]
   first=row['first'];control=sel[result['id']]['firstControl'];off=row['offset'];theta=off[1]*.25*math.pi/180;dx,dz=control['direction']
   assert max(abs(x-y) for x,y in zip(first['direction'],[dx*math.cos(theta)-dz*math.sin(theta),dx*math.sin(theta)+dz*math.cos(theta)]))<2e-6
   assert abs(first['v']-control['v']*(1+.04*off[0]))<2e-6
   if first['accepted']:assert first['otherUnchanged'] and first['physicsPass']
   if 'second' in row:
    assert first['accepted'];second=row['second'];ctrl=row['secondControl'];fixed=sel[result['id']]['secondControl']
    assert all(abs(ctrl[k]-fixed[k])<1e-7 for k in ['v','sx','sy'])
    dx,dz=ctrl['direction'];theta=off[5]*.25*math.pi/180
    assert max(abs(x-y) for x,y in zip(second['direction'],[dx*math.cos(theta)-dz*math.sin(theta),dx*math.sin(theta)+dz*math.cos(theta)]))<2e-6
    assert abs(second['v']-ctrl['v']*(1+.04*off[4]))<2e-6
    assert abs(second['sx']-(ctrl['sx']+.025*off[6]))<2e-6 and abs(second['sy']-(ctrl['sy']+.025*off[7]))<2e-6
   if row['complete']:assert first['accepted'] and row['second']['accepted'] and row['second']['physicsPass'] and not row['second']['scratch']
 return {x['id']:stats(x['rows']) for x in data['results']}
def design():
 m=audit('design');choices=read('selected.json');order=sorted(m,key=lambda k:(-m[k]['rate'],-m[k]['firstPass'],k))
 winner={o:next((x for x in order if next(c for c in choices if c['id']==x)['order']==o),None) for o in ['AB','BA']}
 save('design-ranking.json',{'metrics':m,'order':order,'winnerByOrder':winner});save('ranking-identity.json',{'sha256':digest('design-ranking.json'),'holdoutUsed':False});print('Design winner',winner,flush=True)
def holdout():
 assert digest('design-ranking.json')==read('ranking-identity.json')['sha256'];m=audit('holdout');d=read('design-ranking.json');save('summary.json',{'holdout':m,'design':d['metrics'],'ranking':d['order'],'winnerByOrder':d['winnerByOrder'],'note':'Rankings and controls fixed before holdout; independent 8D noise per complete sequence. Conditional rate includes second geometry rejections. No calibrated human probability.'})
 print('Holdout predefined winners', {o:m[k] if k else None for o,k in d['winnerByOrder'].items()},flush=True)
if __name__=='__main__':{'scan':scan,'design':design,'holdout':holdout}[sys.argv[1]]()
