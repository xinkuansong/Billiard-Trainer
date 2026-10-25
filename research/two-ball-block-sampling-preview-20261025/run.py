from pathlib import Path
import json,hashlib,random,math,shutil
from collections import defaultdict
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle,Rectangle,Polygon
from matplotlib.font_manager import fontManager
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output'/Path(__file__).resolve().parent.name
SOURCE=ROOT/'output/two-ball-downsample-13570-quarter-20261025/preview-five.json'
raw=SOURCE.read_bytes();source_sha=hashlib.sha256(raw).hexdigest();d=json.loads(raw)
OUT.mkdir(parents=True,exist_ok=False)
SEED='second-nonempty-2x2-preview-20261025-v1'
def block(cid):return (cid//12//2)*6+(cid%12//2)
# Verify non-overlapping, complete 2x2 tiling, not sliding windows.
assert set(block(cid) for cid in range(72))==set(range(18))
assert all(sum(block(cid)==b for cid in range(72))==4 for b in range(18))
comparisons=[]
for p in d['samples']:
 groups=defaultdict(list)
 for c in p['originalCandidates']:groups[block(c[0])].append(c)
 chosen=[];draws=[]
 for bid,candidates in sorted(groups.items()):
  seed=hashlib.sha256((SEED+'\0'+p['board']['id']+'\0'+str(bid)).encode()).digest()
  pick=random.Random(int.from_bytes(seed,'big')).choice(sorted(candidates,key=lambda c:c[0]))
  chosen.append(pick);draws.append({'blockID':bid,'availableCellIDs':[c[0] for c in candidates],'chosenCellID':pick[0]})
 chosen.sort(key=lambda c:c[0]);new=dict(p,selectedCandidates=chosen)
 assert len(chosen)==len(groups)<=18 and len({block(c[0]) for c in chosen})==len(chosen)
 assert all(c in p['originalCandidates'] for c in chosen)
 assert all(v[0] in chosen for v in groups.values() if len(v)==1)
 for c in chosen:
  col=int((c[1]+d['geometry']['length']/2-d['geometry']['radius'])/((d['geometry']['length']-2*d['geometry']['radius'])/12))
  row=int((c[2]+d['geometry']['width']/2-d['geometry']['radius'])/((d['geometry']['width']-2*d['geometry']['radius'])/6))
  assert row*12+col==c[0]
 comparisons.append({'old':p,'new':new,'draws':draws,'summary':{'id':p['board']['id'],'angle':p['board']['angle'],'sourceCount':len(p['originalCandidates']),'oldCount':len(p['selectedCandidates']),'newCount':len(chosen),'availableBlocks':len(groups),'oldCoveredBlocks':len({block(c[0]) for c in p['selectedCandidates']}),'newCoveredBlocks':len(groups)}})
g=d['geometry'];r=g['radius'];hx=g['length']/2;hz=g['width']/2
fontManager.addfont('/Library/Fonts/Arial Unicode.ttf');plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
names=['左上角袋','右上角袋','左下角袋','右下角袋','上中袋','下中袋']
def panel(ax,p,i,method):
 b=p['board'];old=p['originalCandidates'];chosen=p['selectedCandidates'];ids={c[0] for c in chosen}
 ax.set_aspect('equal');ax.axis('off')
 ax.add_patch(Rectangle((-hx-.05,-hz-.05),2*hx+.1,2*hz+.1,color='#345d50'))
 ax.add_patch(Rectangle((-hx,-hz),2*hx,2*hz,color='#e0eddf'))
 # Cell grid is over the admissible ball-center rectangle, same source definition.
 for col in range(13):ax.plot([-hx+r+col*(2*hx-2*r)/12]*2,[-hz+r,hz-r],color='#b9cbb8',lw=.5,zorder=1)
 for row in range(7):ax.plot([-hx+r,hx-r],[-hz+r+row*(2*hz-2*r)/6]*2,color='#b9cbb8',lw=.5,zorder=1)
 for col in range(0,13,2):ax.plot([-hx+r+col*(2*hx-2*r)/12]*2,[-hz+r,hz-r],color='#6c8d6a',lw=1.3,zorder=2)
 for row in range(0,7,2):ax.plot([-hx+r,hx-r],[-hz+r+row*(2*hz-2*r)/6]*2,color='#6c8d6a',lw=1.3,zorder=2)
 for pk in g['pockets']:
  ax.add_patch(Polygon([(v['x'],v['z']) for v in pk['lip']],color='#193c33',zorder=3))
  ax.add_patch(Circle((pk['center']['x'],pk['center']['z']),pk['radius'],color='#193c33',zorder=3))
 pk=g['pockets'][b['pocket']]['center'];ax.add_patch(Circle((pk['x'],pk['z']),.067,fill=False,ec='#d4951d',lw=2.5,zorder=5))
 for cid,x,z,*_ in old:
  if cid not in ids:ax.add_patch(Circle((x,z),r,fill=False,ec='#9aaa9a',lw=.9,zorder=4))
 for cid,x,z,*_ in chosen:
  ax.add_patch(Circle((x,z),r,fc=('#1683b6' if method=='旧：随机四分之一' else '#cb6d26'),ec='#75451f',lw=1,zorder=6))
  ax.annotate(f'B{cid}',(x,z),xytext=(0,9),textcoords='offset points',ha='center',fontsize=8,color=('#075575' if method=='旧：随机四分之一' else '#8c4a19'),zorder=8)
 ax.plot([b['cue'][0],b['object'][0]],[b['cue'][1],b['object'][1]],color='#748778',ls=':',lw=1,zorder=2)
 ax.plot([b['object'][0],b['aim'][0]],[b['object'][1],b['aim'][1]],color='#ba8519',ls='--',lw=1.3,zorder=4)
 for pos,fc,ec,label in [(b['cue'],'white','#304b3c','C'),(b['object'],'#f1ba3d','#8b6213','A')]:
  ax.add_patch(Circle(pos,r,fc=fc,ec=ec,lw=1.3,zorder=9));ax.text(*pos,label,ha='center',va='center',fontsize=8,color=ec,zorder=10)
 ax.set_xlim(-hx-.14,hx+.14);ax.set_ylim(hz+.10,-hz-.16)
 ax.set_title(f"{method} · {len(old)} → {len(chosen)}个 · 覆盖{len({block(c[0]) for c in chosen})}/{len({block(c[0]) for c in old})}个非空大格",loc='left',fontsize=12,color='#203f32',pad=8)
 ax.text(-hx,hz+.085,b['id'],fontsize=8,color='#627366')

for i,c in enumerate(comparisons,1):
 fig,axs=plt.subplots(1,2,figsize=(18,6),facecolor='#fafbf7')
 panel(axs[0],c['old'],i,'旧：随机四分之一');panel(axs[1],c['new'],i,'新：每个非空大格留1个')
 fig.suptitle(f"样例{i} · {c['summary']['angle']}° · {names[c['old']['board']['pocket']]}",fontsize=21,color='#203f32')
 fig.tight_layout(rect=(0,0,1,.94));fig.savefig(OUT/f'comparison-{i}.png',dpi=160);plt.close(fig)
fig,axs=plt.subplots(5,2,figsize=(18,25),facecolor='#fafbf7')
for i,c in enumerate(comparisons):
 panel(axs[i,0],c['old'],i+1,'旧：随机四分之一');panel(axs[i,1],c['new'],i+1,'新：每个非空大格留1个')
fig.suptitle('相同5个初始球形 · 左：旧抽样 / 右：2×2大格内随机留1个',fontsize=22,color='#203f32',y=.995)
fig.tight_layout(rect=(0,0,1,.98),h_pad=3);fig.savefig(OUT/'comparison-five.png',dpi=140);plt.close(fig)
summary=[c['summary'] for c in comparisons]
(OUT/'comparison-data.json').write_text(json.dumps({'seed':SEED,'sourceSHA256':source_sha,'geometry':g,'comparisons':comparisons},ensure_ascii=False,indent=2))
(OUT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==source_sha
(OUT/'verification.json').write_text(json.dumps({'passed':True,'scope':'same five layouts only','all72CellsPartitionInto18NonoverlappingBlocks':True,'onePerNonemptyBlock':True,'singleCandidateBlocksRetained':True,'coordinatesAndCandidateFieldsUnchanged':True,'coordinateCellIDsCrossChecked':True,'oldSamplesUnchanged':True,'sourceSHA256':source_sha,'sourceUnchanged':True},indent=2))
page='<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>第二球抽样：同5例左右对比</title><style>body{margin:0;background:#f5f7f2;color:#244334;font:17px system-ui}main{max-width:1700px;margin:auto;padding:22px}h1{font-size:27px}p{line-height:1.7}img{width:100%;height:auto;display:block}article{background:white;padding:12px;border:1px solid #d0dccd;border-radius:10px;margin:20px 0}a{color:#12668e}nav{display:flex;gap:18px;flex-wrap:wrap}table{border-collapse:collapse}td,th{padding:8px 14px;border-bottom:1px solid #cad8c7;text-align:left}.note{background:#e5eee0;padding:14px}</style><main><h1>第二球抽样 · 同样5个球形左右对比</h1><p class="note">左侧蓝球：原来的四分之一随机抽样。右侧橙球：每个非空2×2大格，在现存候选中随机留1个。<br>深色网格线划出18个大格；灰色空心是原候选中未选的位置。单候选大格必留，空大格留空。<br>每个B独立摆放；C是母球、A是第一球、金圈是目标袋。仅比较这5例，没有替换13,570个球形的全量第二球数据。</p><nav>'
page+=''.join(f'<a href="#sample-{i}">样例{i}</a>' for i in range(1,6))+'</nav><table><tr><th>样例</th><th>原候选</th><th>旧数量 / 覆盖大格</th><th>新数量 / 覆盖大格</th></tr>'
for i,s in enumerate(summary,1):page+=f"<tr><td>{i} · {s['angle']}°</td><td>{s['sourceCount']}</td><td>{s['oldCount']} / {s['oldCoveredBlocks']}</td><td>{s['newCount']} / {s['newCoveredBlocks']}</td></tr>"
page+='</table>'
for i,s in enumerate(summary,1):page+=f'<article id="sample-{i}"><h2>样例{i} · {s["angle"]}°</h2><a href="comparison-{i}.png" target="_blank">打开大图</a><img src="comparison-{i}.png" alt="样例{i}抽样左右对比：原随机{s["oldCount"]}个，新大格抽样{s["newCount"]}个"></article>'
page+='<p>两侧数量不强制相同：新方案以非空大格数量决定保留数；区域覆盖改善不等于同等数量下优于旧方案，也不保证最小球间距。</p><p><a href="comparison-data.json">完整抽样与坐标</a> · <a href="README.md">规则和验证</a></p></main></html>'
(OUT/'index.html').write_text(page)
rows='\n'.join(f"|{i}|{s['angle']}°|{s['sourceCount']}|{s['oldCount']}|{s['oldCoveredBlocks']}|{s['newCount']}|" for i,s in enumerate(summary,1))
(OUT/'README.md').write_text(f"""# 第二球2×2非空大格抽样：同5例对照

只使用上轮preview-five.json的原候选与旧入选位置，五例身份/顺序不变。

12×6小格从左上角开始每2列×2行合并，形成6×3个不重叠大格。blockID=(cellID//12//2)*6+(cellID%12//2)。每个非空大格内对现存候选等概率随机选1个，只有1个必留，无候选留空。固定seed={SEED}，按layoutID/blockID独立派生Python Random；不重放物理、不改变坐标、不加难度或路径过滤。

|例|切角|原候选|旧入选|旧覆盖大格|新入选/覆盖大格|
|---|---|---:|---:|---:|---:|
{rows}

深色线为大格边界，两侧坐标、比例、候选相同；左蓝右橙，灰色空心为各自未选候选。每个B独立摆放。新数量等于非空大格数，最多18；新旧数量不匹配，不能据图宣称同样数量下更优。相邻大格边缘的球仍可能接近。

72小格完整分区、每非空组恰好一项、单候选保留、坐标/全部五字段不变、坐标网格归属与ID交叉检查、源SHA不变均通过，verification.json为证据。comparison-data.json保存每个大格候选及选择，允许复核。

本轮仅5例预览，原13,570球形和112,437个第二球位置文件未改。全量采用新规则尚未执行。
""")
gallery=ROOT/'output/two-ball-multi-position-top10-20261024/block-sampling-five';gallery.mkdir(exist_ok=False)
for name in ['index.html','comparison-data.json','README.md']+[f'comparison-{i}.png' for i in range(1,6)]:shutil.copy2(OUT/name,gallery/name)
print(json.dumps(summary,ensure_ascii=False,indent=2))
