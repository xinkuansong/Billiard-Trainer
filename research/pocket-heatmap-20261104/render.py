from pathlib import Path
import json,math,hashlib,html,base64
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap,BoundaryNorm,PowerNorm
from matplotlib.patches import Rectangle,Circle,Patch
from matplotlib import font_manager
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/pocket-heatmap-20261104/r2'
font='/System/Library/Fonts/STHeiti Medium.ttc';font_manager.fontManager.addfont(font)
plt.rcParams.update({'font.family':font_manager.FontProperties(fname=font).get_name(),'axes.unicode_minus':False,'font.size':11,'svg.fonttype':'none'})
d=json.loads((OUT/'grid.json').read_text());nx,nz=d['nx'],d['nz'];xs=np.array(d['x']);zs=np.array(d['z'])
values=np.full((nx,nz),np.nan);regions=np.full((nx,nz),-3);ties=np.zeros((nx,nz),bool)
for c in d['cells']:
 if c['valid']:
  ix,iz=c['ix'],c['iz'];values[ix,iz]=c['maxDegrees'];regions[ix,iz]=c['bestPocket'];ties[ix,iz]=len(c['ties'])>1
colors=['#dd8740','#3778c7','#b56cbc','#2c9b64','#c85361','#35a6aa']
letters=['E','A','F','B','C','D'];names=['左下角袋','左上角袋','右下角袋','右上角袋','左中袋','右中袋']
maxv=float(np.nanmax(values));vmax=math.ceil(maxv/5)*5
cmap=plt.get_cmap('viridis').copy();cmap.set_bad('#d4d8d5');cmap.set_under('#bfc5c1');norm=PowerNorm(.5,vmin=0,vmax=vmax)
regioncmap=ListedColormap(['#bfc5c1']+colors);regionnorm=BoundaryNorm(np.arange(-1.5,6.5,1),7)
def edges(a):return np.r_[a[0],(a[:-1]+a[1:])/2,a[-1]]
def table(ax,title):
 ax.set_title(title,loc='left',fontsize=17,pad=18,fontweight='bold');ax.set_aspect('equal');ax.set_facecolor('#f4f2ec')
 ax.add_patch(Rectangle((-.635,-1.27),1.27,2.54,fill=False,edgecolor='#6e6656',linewidth=10,zorder=2))
 for p in d['pockets']:
  idx=p['index'];x,z=p['center'];ax.add_patch(Circle((z,x),.042,facecolor='#233a32',edgecolor='white',linewidth=1,zorder=4));ax.annotate(letters[idx],(z,x),ha='center',va='center',color='white',fontsize=10,fontweight='bold',zorder=5)
 ax.set_xlim(-.76,.76);ax.set_ylim(-1.40,1.40);ax.set_xticks([]);ax.set_yticks([])
 for spine in ax.spines.values():spine.set_visible(False)
fig=plt.figure(figsize=(13,10),facecolor='#f7f8f4');gs=fig.add_gridspec(1,2,left=.065,right=.94,bottom=.22,top=.83,wspace=.30)
ax=fig.add_subplot(gs[0,0]);table(ax,'最大干净进袋容错角')
heat=ax.pcolormesh(edges(zs),edges(xs),np.ma.masked_where(values==0,values),cmap=cmap,norm=norm,shading='flat',rasterized=True)
cax=fig.add_axes([.105,.148,.31,.018]);bar=fig.colorbar(heat,cax=cax,orientation='horizontal');ticks=[x for x in [0,1,2,5,10,20,40,60,90] if x<=vmax];bar.set_ticks(ticks);bar.set_label('容错角（°） · 越亮，允许的出射方向偏差越大',labelpad=7)
ax2=fig.add_subplot(gs[0,1]);table(ax2,'最佳袋口分区')
ax2.pcolormesh(edges(zs),edges(xs),regions,cmap=regioncmap,norm=regionnorm,shading='flat',rasterized=True)
ti,tj=np.where(ties);ax2.scatter(zs[tj],xs[ti],s=2,c='#f5f7f2',marker='.',linewidths=0,zorder=3)
legend=[Patch(facecolor=colors[i],label=f'{letters[i]} {names[i]}') for i in [1,3,4,5,0,2]]
ax2.legend(handles=legend,loc='upper center',bbox_to_anchor=(.5,-.005),ncol=2,frameon=False,fontsize=10)
fig.text(.065,.944,'目标球放在哪里，哪个袋口最宽容？',fontsize=23,fontweight='bold',color='#173e35')
fig.text(.065,.903,'逐位置计算六袋 → 选最大连续容错角 → 同步绘制热值与选袋分区',fontsize=13,color='#64756b')
fig.text(.065,.067,'101 × 51 个位置 · 约 2.5 cm 网格 · 白点表示近似并列 · 灰色表示未找到非零干净窗口',fontsize=11,color='#52645b')
fig.text(.065,.034,'只看目标球与球桌几何；未加入母球、其它球和碰袋角入袋。角度不是进球概率。',fontsize=11,color='#52645b')
fig.savefig(OUT/'heatmap.png',dpi=180,facecolor=fig.get_facecolor());fig.savefig(OUT/'heatmap.svg',facecolor=fig.get_facecolor());plt.close(fig)
# Per-pocket maps share one fixed scale, for inspection of the max operation.
fig,axes=plt.subplots(2,3,figsize=(12,15),facecolor='#f7f8f4');fig.subplots_adjust(top=.93,bottom=.09,wspace=.12,hspace=.12)
for ax,pocket in zip(axes.flat,[1,3,4,5,0,2]):
 arr=np.full((nx,nz),np.nan)
 for c in d['cells']:
  if c['valid']:arr[c['ix'],c['iz']]=c['widths'][pocket]
 table(ax,f'{letters[pocket]} · {names[pocket]}');ax.pcolormesh(edges(zs),edges(xs),np.ma.masked_where(arr==0,arr),cmap=cmap,norm=norm,shading='flat',rasterized=True)
fig.suptitle('六袋单独计算 · 统一色标',fontsize=22,fontweight='bold');cax=fig.add_axes([.20,.045,.60,.013]);bar=fig.colorbar(matplotlib.cm.ScalarMappable(norm=norm,cmap=cmap),cax=cax,orientation='horizontal');bar.set_ticks(ticks);bar.set_label('干净进袋容错角（°）');fig.savefig(OUT/'six-pockets.png',dpi=130,facecolor=fig.get_facecolor());plt.close(fig)
# Native-resolution color raster for a no-dependency canvas inspector.
rgba=cmap(norm(np.nan_to_num(values)));rgba[values==0]=[.75,.77,.76,1];rgba[np.isnan(values)]=[.96,.95,.92,1]
plt.imsave(OUT/'heat-raster.png',np.flipud(rgba))
rc=regioncmap(regionnorm(regions));rc[np.isnan(values)]=[.96,.95,.92,1];plt.imsave(OUT/'regions-raster.png',np.flipud(rc))
summary={'maxDegrees':maxv,'minPositiveDegrees':float(values[values>0].min()),'medianDegrees':float(np.nanmedian(values)),'zeroCells':int(np.sum(values==0)),'tiedCells':int(ties.sum()),'vmax':vmax}
(OUT/'plot-summary.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary))
