from pathlib import Path
import json,math,html,shutil
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle,Rectangle,Polygon
from matplotlib.font_manager import fontManager
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output'/Path(__file__).resolve().parent.name
read=lambda name:json.loads((OUT/name).read_text())
d=read('preview-five.json');s=read('summary.json');g=d['geometry'];r=g['radius'];hx=g['length']/2;hz=g['width']/2
fontManager.addfont('/Library/Fonts/Arial Unicode.ttf');plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
names=['左上角袋','右上角袋','左下角袋','右下角袋','上中袋','下中袋']
def panel(ax,p,i):
 b=p['board'];old=p['originalCandidates'];chosen=p['selectedCandidates'];ids={c[0] for c in chosen}
 ax.set_aspect('equal');ax.axis('off')
 ax.add_patch(Rectangle((-hx-.05,-hz-.05),2*hx+.1,2*hz+.1,color='#345d50'))
 ax.add_patch(Rectangle((-hx,-hz),2*hx,2*hz,color='#e0eddf'))
 # Cell grid is over the admissible ball-center rectangle, same source definition.
 for col in range(13):ax.plot([-hx+r+col*(2*hx-2*r)/12]*2,[-hz+r,hz-r],color='#b9cbb8',lw=.5,zorder=1)
 for row in range(7):ax.plot([-hx+r,hx-r],[-hz+r+row*(2*hz-2*r)/6]*2,color='#b9cbb8',lw=.5,zorder=1)
 for pk in g['pockets']:
  ax.add_patch(Polygon([(v['x'],v['z']) for v in pk['lip']],color='#193c33',zorder=3))
  ax.add_patch(Circle((pk['center']['x'],pk['center']['z']),pk['radius'],color='#193c33',zorder=3))
 pk=g['pockets'][b['pocket']]['center'];ax.add_patch(Circle((pk['x'],pk['z']),.067,fill=False,ec='#d4951d',lw=2.5,zorder=5))
 for cid,x,z,*_ in old:
  if cid not in ids:ax.add_patch(Circle((x,z),r,fill=False,ec='#9aaa9a',lw=.9,zorder=4))
 for cid,x,z,*_ in chosen:
  ax.add_patch(Circle((x,z),r,fc='#1683b6',ec='#075575',lw=1,zorder=6))
  ax.annotate(f'B{cid}',(x,z),xytext=(0,9),textcoords='offset points',ha='center',fontsize=8,color='#075575',zorder=8)
 ax.plot([b['cue'][0],b['object'][0]],[b['cue'][1],b['object'][1]],color='#748778',ls=':',lw=1,zorder=2)
 ax.plot([b['object'][0],b['aim'][0]],[b['object'][1],b['aim'][1]],color='#ba8519',ls='--',lw=1.3,zorder=4)
 for pos,fc,ec,label in [(b['cue'],'white','#304b3c','C'),(b['object'],'#f1ba3d','#8b6213','A')]:
  ax.add_patch(Circle(pos,r,fc=fc,ec=ec,lw=1.3,zorder=9));ax.text(*pos,label,ha='center',va='center',fontsize=8,color=ec,zorder=10)
 ax.set_xlim(-hx-.14,hx+.14);ax.set_ylim(hz+.10,-hz-.16)
 ax.set_title(f"样例{i} · {b['angle']}° · {names[b['pocket']]} · {len(old)} → {len(chosen)}个第二球位置",loc='left',fontsize=12,color='#203f32',pad=8)
 ax.text(-hx,hz+.085,b['id'],fontsize=8,color='#627366')
for i,p in enumerate(d['samples'],1):
 fig,ax=plt.subplots(figsize=(12,6.7),facecolor='#fafbf7');panel(ax,p,i);fig.tight_layout();fig.savefig(OUT/f'example-{i}.png',dpi=150);plt.close(fig)
fig,axs=plt.subplots(3,2,figsize=(18,16),facecolor='#fafbf7')
for i,(ax,p) in enumerate(zip(axs.flat,d['samples']),1):panel(ax,p,i)
axs.flat[-1].axis('off');axs.flat[-1].text(.03,.8,f"初始球形：135,700 → 13,570\n第二球位置：{s['selectedInitialCandidatesBeforeQuarter']:,} → {s['sampledSecondCandidates']:,}\n每个初始球形平均 {s['meanCandidatesPerInitial']:.2f} 个\n\n蓝色实心：本次抽中\n灰色空心：原有候选，本次未抽中\n白球C：初始母球；黄球A：第一球\n金圈：第一球目标袋\n\n每个B都是独立的第二球摆放选择，\n不是同时把这些球放上桌。",transform=axs.flat[-1].transAxes,va='top',fontsize=16,linespacing=1.8,color='#294c3c')
fig.suptitle('13,570个初始球形 · 第二球候选抽四分之一 · 随机5例',fontsize=22,color='#203f32',y=.99);fig.tight_layout(rect=(0,0,1,.97));fig.savefig(OUT/'preview-five.png',dpi=140);plt.close(fig)
cells=read('cell-distribution.json');fig,axs=plt.subplots(1,2,figsize=(15,5));
for ax,key,title in zip(axs,['before','after'],['抽第二球前（入选13,570个球形）','抽第二球后']):
 matrix=[[cells[row*12+col][key] for col in range(12)] for row in range(6)]
 im=ax.imshow(matrix,cmap='YlGnBu',aspect='equal');ax.set_title(title);ax.set_xticks(range(12),range(1,13));ax.set_yticks(range(6),range(1,7));ax.set_xlabel('网格列（左→右）');ax.set_ylabel('网格行（上→下）');fig.colorbar(im,ax=ax,shrink=.7,label='候选位置数量')
fig.tight_layout();fig.savefig(OUT/'cell-distribution.png',dpi=150);plt.close(fig)
intro=f"初始球形135,700 → 13,570；这些球形的第二球候选 {s['selectedInitialCandidatesBeforeQuarter']:,} → {s['sampledSecondCandidates']:,}，平均 {s['meanCandidatesPerInitial']:.2f} 个/球形。"
page='''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>第二球四分之一采样 · 随机5例</title><style>body{margin:0;background:#f5f7f2;color:#244334;font:17px system-ui,sans-serif}main{max-width:1100px;margin:auto;padding:24px}h1{font-size:27px}p{line-height:1.7}img{display:block;width:100%;height:auto}article{background:#fff;border:1px solid #d2ded0;border-radius:12px;padding:12px;margin:22px 0}a{color:#12668e}nav{display:flex;gap:20px;flex-wrap:wrap}.note{background:#e5eee0;padding:15px;border-radius:8px}small{color:#5e7566}</style><main><h1>第二球位置抽四分之一 · 随机5例</h1>'''
page+=f'<p>{intro}</p><p class="note">蓝色实心＝抽中；灰色空心＝原有候选、此次未抽中。白球C＝母球，黄球A＝第一球，金圈＝第一球目标袋。<br>每个B是一个独立摆放位置，不是同时摆放。图中连线是几何参考线，不是模拟轨迹。</p><nav>'
page+=''.join(f'<a href="#example-{i}">样例{i}</a>' for i in range(1,6))+'</nav>'
for i,p in enumerate(d['samples'],1):
 page+=f'<article id="example-{i}"><img src="example-{i}.png" alt="样例{i}：切角{p["board"]["angle"]}度，第二球位置{len(p["originalCandidates"])}个抽至{len(p["selectedCandidates"])}个"><small>编号：{html.escape(p["board"]["id"])}</small></article>'
page+='<article><h2>全部入选球形的网格数量分布</h2><p>左右色阶各自标明数量，用于观察位置分布；并非可行率。</p><img src="cell-distribution.png" alt="所有入选球形抽取前后的12×6网格候选数量"></article><p>初始球形按原270类组合比例分层，最大余数法分配13,570个名额；各层不放回随机抽取。第二球逐球形四舍五入取原数量的1/4，有候选至少保留1个，空数组保持。没有重新生成或移动球位，也未增加路径、难度或P2筛选。</p><p>5例按独立随机种子顺序选取，没有按图形好看程度挑选。</p><p><a href="README.md">抽样与数据说明</a> · <a href="preview-five.json">5例原始坐标</a></p></main></html>'
(OUT/'index.html').write_text(page)
gallery=ROOT/'output/two-ball-multi-position-top10-20261024/downsample13570-quarter';gallery.mkdir(exist_ok=True)
for name in ['index.html','preview-five.json','cell-distribution.png']+[f'example-{i}.png' for i in range(1,6)]:shutil.copy2(OUT/name,gallery/name)
print(intro);print('PREVIEW',s['preview'])
