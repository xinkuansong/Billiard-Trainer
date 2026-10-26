"""Standalone scientific diagrams from audited native results and geometric envelope."""
from pathlib import Path
import json,math
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle,Arc,Polygon,Rectangle
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/middle-pocket-angle-20261026'
g=json.loads((OUT/'tangent-check/geometry.json').read_text())
meta=json.loads((OUT/'tangent-check/metadata.json').read_text())
summary=json.loads((OUT/'tangent-check/summary.json').read_text())
plt.rcParams.update({'font.family':'Heiti SC','axes.unicode_minus':False,'font.size':12,'savefig.facecolor':'#f4f7f5'})
theta=math.radians(g['theta']);slope=1/math.tan(theta);inset=g['inset'];hx=meta['length']/2;hz=meta['width']/2

fig=plt.figure(figsize=(13.5,9),facecolor='#f4f7f5')
fig.text(.055,.945,'中袋直进可行区域',fontsize=25,weight='bold',color='#163e32')
fig.text(.055,.902,f'边界线与长库约 {90-g["theta"]:.1f}°   ·   与正面法线约 {g["theta"]:.1f}°',fontsize=18,color='#254f41')
ax=fig.add_axes([.055,.25,.70,.59]);ax.set_aspect('equal');ax.set_facecolor('#176047')
ax.add_patch(Rectangle((-hx,-hz),2*hx,2*hz,facecolor='#176047',edgecolor='#527565',lw=1,zorder=-10))
xs=np.linspace(-hx,hx,700)
top=-hz+inset+slope*np.abs(xs);bottom=hz-inset-slope*np.abs(xs)
ax.fill_between(xs,-hz,top,color='#e3a281',alpha=.55)
ax.fill_between(xs,bottom,hz,color='#e3a281',alpha=.55)
ax.plot(xs,top,color='#ffe1be',lw=2.8);ax.plot(xs,bottom,color='#ffe1be',lw=2.8)
for z in [-hz,hz]:
    ax.add_patch(Circle((0,z),.043,color='#131d19',zorder=8))
    ax.plot([0,0],[z,z+(.29 if z<0 else -.29)],'--',color='white',lw=1.2)
for x in [-hx,hx]:
    for z in [-hz,hz]:ax.add_patch(Circle((x,z),.042,color='#131d19',zorder=8))
for side in [-1,1]:
    for hand in [-1,1]:
        for b in summary:
            if b['distance']>1.2:continue
            d=b['distance'];a=math.radians(b['boundaryBeta'])
            x=hand*d*math.sin(a);z=side*(hz-d*math.cos(a))
            ax.scatter([x],[z],s=17,c='#ffe9d0',edgecolors='#163e32',linewidths=.5,zorder=9)
ax.text(0,-.27,'上中袋：边界线下方为候选区域',ha='center',color='white',fontsize=13)
ax.text(0,.27,'下中袋：边界线上方为候选区域',ha='center',color='white',fontsize=13)
ax.text(0,0,'先筛区域，再按 W 排序',ha='center',color='#c9f5df',fontsize=18,weight='bold')
ax.set_xlim(-hx-.035,hx+.035);ax.set_ylim(hz+.06,-hz-.06);ax.axis('off')
tab=fig.add_axes([.79,.32,.19,.45]);tab.axis('off')
tab.text(0,1.05,'从库线中点量角',weight='bold',fontsize=14,color='#163e32')
tab.text(0,.94,'球到中点距离     外沿角度',fontsize=11,color='#52655d')
for i,b in enumerate(summary):
    if b['distance']>1.2:continue
    tab.text(0,.81-i*.13,f'{b["distance"]*100:>3.0f} cm                 {b["boundaryBeta"]:.1f}°',fontsize=13,color='#163e32')
fig.text(.055,.18,f'两条边界的交点约在库线内侧 {inset*1000:.1f} mm，所以近袋角度略收窄。',fontsize=13,color='#264c3c')
fig.text(.055,.125,'这是“存在可进瞄准方向”的外沿；贴边时瞄准容差很小，不表示容易进。',fontsize=13,color='#264c3c')
fig.text(.055,.077,'当前 App 物理研究 · 单目标球 · 无遮挡 · 未接入推荐或评分',fontsize=11,color='#61776b')
fig.savefig(OUT/'feasible-region.png',dpi=170);fig.savefig(OUT/'feasible-region.svg');plt.close(fig)

# At +/- .02 degree around the predicted positional boundary: actual native paths.
examples=json.loads((OUT/'tangent-check/examples.json').read_text())
fig,axes=plt.subplots(1,2,figsize=(12,6),facecolor='#f4f7f5')
for ax,delta in zip(axes,[-.02,.02]):
    row=next(r for r in examples if r['input']['distance']==.6 and r['input']['delta']==delta)
    result=row['results'][0];start=row['start']
    ax.set_facecolor('#e8f1eb')
    for seg in meta['linear']:
        if seg['start'][2]<0 and seg['end'][2]<0:
            ax.plot([seg['start'][0]*1000,seg['end'][0]*1000],[(seg['start'][2]+hz)*1000,(seg['end'][2]+hz)*1000],color='#344a3c',lw=2)
    for c in meta['circular']:
        if c['center'][2]<0 and abs(c['center'][0])<.2:
            ts=np.linspace(c['startAngle'],c['endAngle'],160)
            ax.plot((c['center'][0]+c['radius']*np.cos(ts))*1000,(c['center'][2]+hz+c['radius']*np.sin(ts))*1000,color='#344a3c',lw=3)
    lip=np.array(meta['pockets'][4]['lip']);ax.add_patch(Polygon(np.c_[lip[:,0]*1000,(lip[:,1]+hz)*1000],color='#9db9ab',alpha=.6))
    frames=result['frames'];end=next((e['time'] for e in result['events'] if e['kind']=='pocket'),float('inf'))
    pts=[f['p'] for f in frames if f['t']<=end and f['state']!='pocketed']
    ax.plot([p[0]*1000 for p in pts],[(p[2]+hz)*1000 for p in pts],color='#16835c' if result['direct'] else '#d46938',lw=2)
    contacts=[e for e in result['events'] if e['kind']!='pocket']
    if contacts:
        p=contacts[0]['position'];ax.scatter([p[0]*1000],[(p[2]+hz)*1000],marker='x',s=60,color='#b33a26',zorder=10)
    ax.set_title(f'{row["input"]["angle"]:.3f}°：'+('进袋' if result['direct'] else '袋角弹回'),fontsize=16)
    ax.set_xlim(-110,190);ax.set_ylim(115,-65);ax.set_aspect('equal');ax.set_xlabel('横向 / mm');ax.set_ylabel('距库线向台内 / mm');ax.grid(alpha=.2)
fig.suptitle('60 cm 球位：仅改变 0.04°，跨过实测边界',fontsize=19)
fig.text(.5,.02,'实线为原始物理球心轨迹；未把进袋后的收球动画当作轨迹。',ha='center',fontsize=11,color='#52655d')
fig.tight_layout(rect=[0,.05,1,.93]);fig.savefig(OUT/'boundary-trajectories.png',dpi=180);plt.close(fig)
print(OUT/'feasible-region.png')
