"""Publication/export figures; run with uv run --with numpy --with matplotlib."""
from pathlib import Path
import csv,json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

P=Path(__file__).resolve().parent
rows=list(csv.DictReader((P/'results/metrics.csv').open()))
plt.rcParams.update({'font.family':'sans-serif','font.size':10,'axes.spines.top':False,'axes.spines.right':False,'figure.dpi':160})
fig,axs=plt.subplots(1,2,figsize=(11,4.6),constrained_layout=True)
methods=['alpha','dual_directions','ratio_exact_oracle','standard_direction','fraction5_oracle','first_order_mental']
names=['Shape angle only','Two direction table','Exact ratio (oracle)','Standard direction','Five fractions (oracle)','5° + first-order correction']
width=.24;x=np.arange(len(methods))
for j,noise in enumerate(['0','0.1','0.25']):
 vals=[float(next(r for r in rows if r['model']=='production' and r['noise_grid']==noise and r['method']==m and r['group']=='all')['p95_deg']) for m in methods]
 axs[0].barh(x+(j-1)*width,vals,height=width,label=f'±{noise} cell',color=['#256c53','#d9a044','#809ebc'][j])
axs[0].set_yticks(x,names);axs[0].invert_yaxis();axs[0].set_xlabel('95th-percentile absolute cut-angle error (degrees)');axs[0].set_title('120,000 production-geometry layouts');axs[0].legend(frameon=False,loc='upper center',bbox_to_anchor=(.5,-.18),ncol=3)
for t in [15,30,45,60,75,85]:
 r=np.linspace(.181,6,300);theta=np.deg2rad(t);D=.18
 L=-D*np.cos(theta)+np.sqrt(r*r-D*D*np.sin(theta)**2)
 alpha=np.arctan2(L*np.sin(theta),D+L*np.cos(theta))
 axs[1].plot(r,t-np.rad2deg(alpha),label=f'{t}° cut')
axs[1].set_ylim(0,30);axs[1].set_xlim(0,6);axs[1].set_xlabel('Center-to-center distance (cells; 1 cell = 317.5 mm)');axs[1].set_ylabel('Error from ignoring diameter (degrees)');axs[1].set_title('Ball diameter matters at short distances');axs[1].axhline(5,color='#888',lw=.8,ls='--');axs[1].legend(frameon=False,ncol=2)
fig.savefig(P/'results/errors.png');fig.savefig(P/'results/errors.svg');plt.close(fig)

fig,axs=plt.subplots(1,2,figsize=(12,4),constrained_layout=True)
fractions=[1,.75,.5,.25,.125];colors=['#56776a','#279a72','#c88a28','#5f8bbb','#9568aa'];D=.18
for ax,a in zip(axs,[1,2]):
 O=np.array([a,a]);u=-np.ones(2)/np.sqrt(2);G=O-D*u;n=np.array([-u[1],u[0]])
 ax.add_patch(plt.Rectangle((0,0),8,4,color='#edf4ee'))
 for f,color in zip(fractions,colors):
  t=np.arcsin(1-f)
  for sign in [-1,1] if t else [1]:
   d=-np.cos(t)*u+sign*np.sin(t)*n;ts=[]
   for i,b in [(0,0),(0,8),(1,0),(1,4)]:
    if abs(d[i])>1e-12 and (b-G[i])/d[i]>0:ts.append((b-G[i])/d[i])
   end=G+min(ts)*d
   ax.plot([G[0],end[0]],[G[1],end[1]],color=color,lw=2 if f==.5 else 1,label=f'{f:g}' if sign==1 else None)
 ax.plot([0,a],[0,a],color='#999',ls='--');ax.scatter(*O,s=35,color='#ce8e3e',zorder=4);ax.annotate(f'O=({a},{a})',O,xytext=(8,12),textcoords='offset points')
 ax.scatter([8],[3],color='#222',marker='D',s=20,zorder=5);ax.annotate('fixed rail point (8,3)',(8,3),xytext=(-130,-12),textcoords='offset points')
 ax.set_xlim(0,8);ax.set_ylim(4,0);ax.set_aspect('equal');ax.set_xticks(range(9));ax.set_yticks(range(5));ax.grid(alpha=.15);ax.set_xlabel('x / cells');ax.set_ylabel('y / cells');ax.set_title(f'Same pocket, changed target: a={a}')
axs[1].legend(title='Overlap fraction',frameon=False,fontsize=8,loc='upper right')
fig.savefig(P/'results/loci.png');fig.savefig(P/'results/loci.svg');plt.close(fig)
print('Saved errors/loci PNG + SVG')
