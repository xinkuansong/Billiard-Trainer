#!/usr/bin/env python3
from pathlib import Path
import json,math,csv,collections,hashlib
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle,Rectangle
OUT=Path(__file__).resolve().parent
read=lambda n:json.loads((OUT/n).read_text())
sample=read('sample.json');summary=read('summary.json');scan=read('scan-results.json');selected=read('selected.json');protocol=read('protocol.json')
trials={x['id']:x['rows'] for x in read('holdout-results.json')['results']};names=['左上角袋','右上角袋','左下角袋','右下角袋','上中袋','下中袋'];short=['左上','右上','左下','右下','上中','下中']
styles={x['id']:x['label'] for x in protocol['styles']};r=scan['radius'];figdir=OUT/'figures';figdir.mkdir(exist_ok=True)
plt.rcParams.update({'font.family':'sans-serif','font.sans-serif':['Arial Unicode MS','PingFang SC','DejaVu Sans'],'axes.unicode_minus':False,'font.size':11})
def board(ax):
 ax.set_aspect('equal');ax.set_xlim(-1.43,1.43);ax.set_ylim(.83,-.83);ax.axis('off')
 ax.add_patch(Rectangle((-1.27,-.635),2.54,1.27,facecolor='#eaf1eb',edgecolor='#34574e',linewidth=8,zorder=0))
 for i,p in enumerate(sample['geometry']['pockets']):
  x,z=p['center']['x'],p['center']['z'];ax.add_patch(Circle((x,z),p['radius'],color='#203d35',ec='white',lw=1,zorder=5))
  ax.text(x,z+(-.095 if z<0 else .095),names[i],ha='center',va='center',fontsize=10,color='#39574e')
def ball(ax,pos,label,color):
 ax.add_patch(Circle(pos,r,fc=color,ec='#203d35',lw=1.6,zorder=8));ax.annotate(label,pos,xytext=(0,-18),textcoords='offset points',ha='center',color='#172e27',fontsize=12,zorder=10)
def path(ax,points,color,ls='-',lw=1.5,label=None):
 if points:
  a=np.array(points);ax.plot(a[:,0],a[:,1],ls=ls,lw=lw,color=color,label=label,zorder=3)
def initial(ax):
 for p,l,c in [(sample['cue'],'C','#ffffff'),(sample['a'],'A','#c26067'),(sample['b'],'B','#e4a13b')]:ball(ax,p,l,c)
def export(fig,name):
 fig.savefig(figdir/name,dpi=155,facecolor='white');plt.close(fig)
fig,ax=plt.subplots(figsize=(9,5.5));board(ax);initial(ax);fig.subplots_adjust(left=.02,right=.98,top=.95,bottom=.05);export(fig,'layout.png')
def cause(row):
 if row.get('status')=='invalid_input':return '输入越界'
 if not row.get('access',False):return '出杆几何不可达'
 if row.get('otherHit',False) or row.get('otherUnchanged') is False:return '碰动另一颗球'
 if row.get('scratch',False):return '母球落袋'
 if not row.get('pot',False):return '未进指定袋'
 if row.get('objectRails',0):return '目标球碰库或袋嘴'
 if row.get('before',0):return '母球先碰库'
 if row.get('jaw',0):return '母球碰袋嘴'
 if row.get('contacts',0)!=1:return '球球接触次数不符'
 if not row.get('settled',False):return '未停稳'
 return '其他资格条件'
items=[]
for i,c in enumerate(selected):
 cid=c['id'];h=dict(summary['holdout'][cid]);h['firstPotSafe']=sum(t['first'].get('pot',False) and not t['first'].get('scratch',False) for t in trials[cid]);h['secondPotSafe']=sum(t['second'].get('pot',False) and not t['second'].get('scratch',False) for t in trials[cid] if 'second' in t);d=summary['design'][cid];nom=c['nominal'];sn=c['secondNominal'];order=c['order'];p1,p2=c['p1'],c['p2'];sctl=c['secondControl'];slug=f'strategy-{i+1:02d}'
 fig,ax=plt.subplots(figsize=(9,6.3));board(ax);initial(ax)
 path(ax,nom['cuePath'],'#20838a',label='第一杆母球');path(ax,nom['objectPath'],'#c26067' if order=='AB' else '#d28c21',label='第一颗目标球')
 path(ax,sn['cuePath'],'#7462a9',ls='--',label='第二杆母球');path(ax,sn['objectPath'],'#d28c21' if order=='AB' else '#c26067',ls='--',label='第二颗目标球')
 ball(ax,nom['stop'],'C₁','#b8e0df')
 for pk in sorted({p1,p2}):
  tag='①②' if p1==p2 else '①' if pk==p1 else '②'
  p=sample['geometry']['pockets'][pk]['center'];ax.annotate(tag,(p['x'],p['z']),xytext=(16 if p['x']<0 else -16,0),textcoords='offset points',ha='center',va='center',fontsize=16,color='#a35f13',zorder=20)
 fig.suptitle(f"{order[0]} → {order[1]}  |  {names[p1]} → {names[p2]}\n{styles[c['style']]} · {c['v']:g} m/s",fontsize=14,y=.98)
 fig.legend(loc='lower center',ncol=2,frameon=False,bbox_to_anchor=(.5,.065),fontsize=10)
 fig.text(.5,.025,'零误差两杆实际轨迹；C₁为首杆停点。图线未混入收球动画。',ha='center',fontsize=10,color='#53665c')
 fig.subplots_adjust(left=.02,right=.98,top=.84,bottom=.19);export(fig,slug+'-route.png')
 fig,ax=plt.subplots(figsize=(9,5.8));board(ax);initial(ax)
 groups=[('complete','#30845e','两杆完成'),('second_geometry_excluded','#d39a27','第二杆几何超出范围'),('second_execution_failed','#af5c8a','第二杆执行失败')]
 for status,color,label in groups:
  ps=[x['first']['stop'] for x in trials[cid] if x['status']==status and x['first']['accepted']]
  if ps:
   pts=np.array(ps);ax.scatter(pts[:,0],pts[:,1],s=24,alpha=.65,c=color,label=f'{label} {len(ps)}',edgecolors='white',linewidths=.35,zorder=7)
 ax.scatter(*nom['stop'],s=85,marker='*',color='#172e27',label='名义停点',zorder=12)
 fig.suptitle(f"留出停点与接续结果 | 两杆完成 {h['complete']}/{h['n']}\n首杆有效 {h['firstPass']}/{h['n']}；其余首杆失败不画成接续停点",fontsize=13,y=.98)
 fig.legend(loc='lower center',ncol=2,frameon=False,bbox_to_anchor=(.5,.005),fontsize=10);fig.subplots_adjust(left=.02,right=.98,top=.82,bottom=.17);export(fig,slug+'-stops.png')
 best=next(x for x in c['secondOptions'] if x['control']==c['secondControl'])
 data={'id':cid,'order':order,'p1':p1,'p2':p2,'style':c['style'],'styleLabel':styles[c['style']],'v':c['v'],'sx':c['sx'],'sy':c['sy'],'secondControl':sctl,'firstControl':c['firstControl'],'firstRails':nom['rails'],'design':d,'holdout':h,'routeImage':'figures/'+slug+'-route.png','stopsImage':'figures/'+slug+'-stops.png','firstAxes':[x['accepted'] for x in c['axisTrials']],'secondAxes':[x['accepted'] for x in best['axisTrials']],'firstElevation':nom.get('elevationDegrees'),'secondElevation':sn.get('elevationDegrees')}
 data['firstReasons']=dict(collections.Counter(cause(t['first']) for t in trials[cid] if not t['first']['accepted']))
 data['secondReasons']=dict(collections.Counter(cause(t['second']) for t in trials[cid] if 'second' in t and not t['second']['accepted']))
 items.append(data)
items.sort(key=lambda x:summary['ranking'].index(x['id']))
matrix=[]
for order in ['AB','BA']:
 for p1 in range(6):
  f=[x for x in scan['firstRows'] if x['order']==order and x['p1']==p1]
  for p2 in range(6):
   pool=[x for x in scan['candidates'] if x['order']==order and x['p1']==p1 and x['p2']==p2];good=[x for x in pool if x['status']=='nominal_both_passed'];assessed=[x for x in items if x['order']==order and x['p1']==p1 and x['p2']==p2]
   status='已复验' if assessed else '未入留出' if good else '未找到接续' if any(x['status']=='nominal_first_passed' for x in f) else '名义首杆失败' if any(x['eligible'] for x in f) else '首杆几何排除'
   matrix.append({'order':order,'p1':p1,'p2':p2,'status':status,'firstSlots':len(f),'firstNominalPass':sum(x['status']=='nominal_first_passed' for x in f),'nominalStrategies':len(good),'assessed':len(assessed),'id':assessed[0]['id'] if assessed else None,'cutDegrees':f[0]['cutDegrees']})
paired=None
wa,wb=summary['winnerByOrder'].get('AB'),summary['winnerByOrder'].get('BA')
if wa and wb:
 delta=np.array([int(a['complete'])-int(b['complete']) for a,b in zip(trials[wa],trials[wb])])
 rng=np.random.default_rng(2026102304)
 boot=delta[rng.integers(0,len(delta),size=(10000,len(delta)))].mean(axis=1)
 paired={'a':wa,'b':wb,'differenceABminusBA':float(delta.mean()),'bootstrap95':np.quantile(boot,[.025,.975]).tolist(),'ABonly':int((delta==1).sum()),'BAonly':int((delta==-1).sum()),'both':sum(a['complete'] and b['complete'] for a,b in zip(trials[wa],trials[wb])),'seed':2026102304,'replicates':10000}
(OUT/'paired-comparison.json').write_text(json.dumps(paired,ensure_ascii=False,indent=2))
payload={'items':items,'matrix':matrix,'names':names,'short':short,'winners':summary['winnerByOrder'],'styles':styles,'paired':paired,'layout':{k:sample[k] for k in ['cue','a','b']}}
(OUT/'viewer-data.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2))
with (OUT/'comparison.csv').open('w') as f:
 writer=csv.writer(f);writer.writerow(['id','order','firstPocket','secondPocket','firstTipX','firstTipY','firstSpeed','secondTipX','secondTipY','secondSpeed','designComplete','designN','holdoutComplete','holdoutN','firstPass','secondExecuted','conditionalSecondRate','wilsonLow','wilsonHigh'])
 for x in items:
  h=x['holdout'];d=x['design'];s=x['secondControl'];writer.writerow([x['id'],x['order'],names[x['p1']],names[x['p2']],x['sx'],x['sy'],x['v'],s['sx'],s['sy'],s['v'],d['complete'],d['n'],h['complete'],h['n'],h['firstPass'],h['secondExecuted'],h['secondConditionalRate'],*h['wilson95']])
html=(OUT/'viewer-template.html').read_text().replace('__DATA__',json.dumps(payload,ensure_ascii=False).replace('</','<\\/'))
(OUT/'report.html').write_text(html)
print('Published',len(items),'strategies,',len(items)*2+1,'figures, 72 matrix cells',flush=True)
