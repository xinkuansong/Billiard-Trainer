"""Experimental continuous comfort components; no selection or simulation."""
from pathlib import Path
import sys,json,gzip,hashlib,math,shutil
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle,Rectangle,Polygon
from matplotlib.colors import LinearSegmentedColormap
from matplotlib.font_manager import fontManager
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/two-ball-comfort-heatmap-five-20261025';OUT.mkdir(exist_ok=True)
sys.path.insert(0,str(ROOT/'research/two-ball-middle-grid18-20261025'))
import pipeline as P
PRIOR=ROOT/'output/two-ball-comfort-five-20261025/data.json';prior=json.loads(PRIOR.read_text())
g=P.C.D['geometry'];R=g['radius'];hx=g['length']/2;hz=g['width']/2;anchors=P.C.G.anchors()
H=.004;x=np.arange(-hx,hx+H/2,H);z=np.arange(-hz,hz+H/2,H);X,Z=np.meshgrid(x,z)
fontManager.addfont('/Library/Fonts/Arial Unicode.ttf');plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
names=['左上角袋','右上角袋','左下角袋','右下角袋','上中袋','下中袋'];metrics=['distance','space','angle'];metricNames={'distance':'球距舒适度','space':'出杆空间评价（平面代理）','angle':'角度舒适度'}
cmap=LinearSegmentedColormap.from_list('comfort',['#b65d56','#e8b56b','#f5edbd','#a5c7a0','#347c68']);cmap.set_bad('#e5e7df')
def ray_box(cx,cz,dx,dz,bx=hx,bz=hz):
 """Distance to first rectangle edge along unit direction; near-zero axes ignored."""
 cx,cz,dx,dz=np.broadcast_arrays(cx,cz,dx,dz)
 tx=np.divide(np.where(dx>0,bx-cx,-bx-cx),dx,out=np.full(cx.shape,np.inf),where=np.abs(dx)>1e-12)
 tz=np.divide(np.where(dz>0,bz-cz,-bz-cz),dz,out=np.full(cx.shape,np.inf),where=np.abs(dz)>1e-12)
 return np.maximum(0,np.minimum(tx,tz))
assert abs(float(ray_box(0,0,1,0))-hx)<1e-12
assert abs(float(ray_box(0,0,0,-1))-hz)<1e-12
assert abs(float(ray_box(0,0,1/math.sqrt(2),1/math.sqrt(2)))-hz*math.sqrt(2))<1e-12
def fields(cx,cz,b,p):
 a=np.array(anchors[p]);b=np.array(b);n=(a-b)/np.linalg.norm(a-b);ghost=b-2*R*n
 # Maximum center-to-center separation on the backward central axis inside body bounds.
 depth=float(ray_box(b[0],b[1],-n[0],-n[1],hx-R,hz-R))
 scale=min(1.,max(.4,depth/.9));low=.5*scale;high=.8*scale
 vx=ghost[0]-cx;vz=ghost[1]-cz;norm=np.hypot(vx,vz);backx=-vx/np.maximum(norm,1e-12);backz=-vz/np.maximum(norm,1e-12)
 angle=np.degrees(np.arctan2(np.abs(vx*n[1]-vz*n[0]),vx*n[0]+vz*n[1]));distance=np.hypot(cx-b[0],cz-b[1])
 gap=np.minimum(hx-np.abs(cx),hz-np.abs(cz))-R
 rear=np.maximum(0,ray_box(cx,cz,backx,backz)-R)
 distanceScore=100*np.exp(-(np.maximum(low-distance,0)/(.4*low))**2-(np.maximum(distance-high,0)/.35)**2)
 spaceScore=100*(1-np.exp(-(rear/.25)**2))*(.75+.25*(1-np.exp(-(np.maximum(gap,0)/.08)**2)))
 angleScore=100*np.exp(-(np.maximum(angle-10,0)/18)**2)
 valid=(gap>=0)&(distance>=2*R)&(angle<90)&(norm>1e-9)
 return dict(distance=distance,angle=angle,gap=gap,rear=rear,backx=backx,backz=backz,distanceScore=distanceScore,spaceScore=spaceScore,angleScore=angleScore,valid=valid,depth=depth,preferred=[low,high])
def scalar(c,b,p):
 f=fields(float(c[0]),float(c[1]),b,p)
 return {k:(v if k=='preferred' else bool(v) if k=='valid' else float(v)) for k,v in f.items()}
# Direction-sensitive sanity check: at equal wall gap, parallel has greater rear room.
c=[0,hz-R-.05]
assert float(ray_box(*c,1,0)-R)>float(ray_box(*c,0,1)-R)
# Smooth curves keep small angles equally rated and have no 18-degree score jump.
assert 100*np.exp(-(max(10-10,0)/18)**2)==100
assert abs(100*np.exp(-((18.001-10)/18)**2)-100*np.exp(-((17.999-10)/18)**2))<.02
data=[];sources={};panels=[]
for s in prior['samples']:
 # Re-read the original committed record; do not import previous pass/fail judgments.
 src=next(k for k in prior['sourceSHA256'] if k.endswith('/'+next(v['stem'] for v in json.loads((ROOT/'output/two-ball-grid18-preview-five-20261025/data.json').read_text())['samples'] if v['id']==s['id'])+'.jsonl.gz'))
 raw=(ROOT/src).read_bytes();digest=hashlib.sha256(raw).hexdigest();assert digest==prior['sourceSHA256'][src];sources[src]=digest
 old=next(r for r in map(json.loads,gzip.decompress(raw).splitlines()) if r['id']==s['id']);cand=next(v for v in old['candidates'] if v['cellID']==s['cellID']);routes={r['comboIndex']:r for r in old['routes']}
 record={k:s[k] for k in ['number','id','board','cellID','position']};record['routes']=[];record['pockets']={}
 for rank,q in enumerate(cand['top5'],1):
  stop=routes[q['comboIndex']]['cueStop'];f=scalar(stop,cand['position'],q['pocket'])
  assert abs(f['angle']-q['angle'])<1e-6
  assert all(0<=f[k]<=100 for k in ('distanceScore','spaceScore','angleScore'))
  record['routes'].append(dict(rank=rank,comboIndex=q['comboIndex'],pocket=q['pocket'],stop=stop,**f))
 assert len(record['routes'])==len(cand['top5'])
 for p in sorted({q['pocket'] for q in cand['top5']}):
  f=fields(X,Z,cand['position'],p);record['pockets'][p]={'depth':f['depth'],'preferred':f['preferred']}
  # Scalar/vector formula agreement, source angles also independently checked above.
  for iz,ix in [(100,100),(180,300),(250,400)]:
   check=scalar([X[iz,ix],Z[iz,ix]],cand['position'],p)
   for key in ('distance','angle','gap','rear','distanceScore','spaceScore','angleScore'):assert abs(check[key]-float(f[key][iz,ix]))<1e-8
  panels.append((record,p,f))
 data.append(record)
assert len(data)==5 and sum(len(s['routes']) for s in data)==22
def draw(ax,s,p,f,metric):
 b=s['board'];ax.set_aspect('equal');ax.axis('off')
 ax.add_patch(Rectangle((-hx-.055,-hz-.055),2*hx+.11,2*hz+.11,color='#355e52',zorder=0))
 heat=np.ma.array(f[metric+'Score'],mask=~f['valid'])
 im=ax.pcolormesh(X,Z,heat,cmap=cmap,vmin=0,vmax=100,shading='nearest',rasterized=True,zorder=1)
 for pocket in g['pockets']:
  ax.add_patch(Polygon([(v['x'],v['z']) for v in pocket['lip']],color='#183c33',zorder=3));ax.add_patch(Circle((pocket['center']['x'],pocket['center']['z']),pocket['radius'],color='#183c33',zorder=3))
 # 18 degrees is a labelled reference only, not a mask/filter.
 ax.contour(X,Z,np.ma.array(f['angle'],mask=~f['valid']),levels=[18],colors=['#5a5566'],linestyles='--',linewidths=.8,zorder=2)
 a=anchors[p];ax.plot([s['position'][0],a[0]],[s['position'][1],a[1]],'--',color='#235b71',lw=1.5,zorder=3)
 q=g['pockets'][p]['center'];ax.add_patch(Circle((q['x'],q['z']),.07,fill=False,ec='#24788d',lw=2.5,zorder=4))
 q=g['pockets'][b['pocket']]['center'];ax.add_patch(Circle((q['x'],q['z']),.064,fill=False,ec='#bd8c20',lw=1.5,zorder=4))
 for pos,fc,ec,label in [(b['cue'],'#fff','#7b8f80','C'),(b['object'],'#f4df9e','#b29764','A'),(s['position'],'#208eb7','#0a6286','B')]:
  ax.add_patch(Circle(pos,R,fc=fc,ec=ec,lw=1.2,zorder=6));ax.text(*pos,label,ha='center',va='center',fontsize=9,color='white' if label=='B' else ec,zorder=7)
 rows=[q for q in s['routes'] if q['pocket']==p];rows=sorted(rows,key=lambda q:q['stop'][1]);zs=np.clip(np.mean([q['stop'][1] for q in rows])+np.linspace(-.18,.18,len(rows)) if len(rows)>1 else [rows[0]['stop'][1]],-hz+.06,hz-.06)
 for q in s['routes']:
  if q['pocket']!=p:ax.plot(*q['stop'],'o',mfc='none',mec='#8d9392',ms=7,zorder=5)
 for q,lz in zip(rows,zs):
  pt=q['stop'];ax.plot(*pt,'o',mfc='white',mec='#253e4b',ms=8,mew=1.5,zorder=9)
  lx=float(np.clip(pt[0]+(.22 if pt[0]<0 else -.22),-hx+.08,hx-.08))
  ax.annotate(f'{q["rank"]} · {q[metric+"Score"]:.0f}',pt,xytext=(lx,float(lz)),fontsize=9,ha='center',va='center',color='#253e4b',bbox=dict(boxstyle='round,pad=.22',fc='white',ec='#4d626d',lw=.8),arrowprops=dict(arrowstyle='-',color='#374e5b',lw=.8),zorder=10)
  if metric=='space':
   length=min(.25,q['rear']);end=[pt[0]+q['backx']*length,pt[1]+q['backz']*length]
   ax.annotate('',xy=end,xytext=pt,arrowprops=dict(arrowstyle='->',color='#704b90',lw=1.4),zorder=8)
 ax.set_xlim(-hx-.12,hx+.12);ax.set_ylim(hz+.16,-hz-.14)
 subtitle=f'偏好球距 {f["preferred"][0]*100:.0f}–{f["preferred"][1]*100:.0f}cm · 中轴后方深度 {f["depth"]*100:.0f}cm' if metric=='distance' else ('紫箭头＝第二杆杆尾方向（最长示意25cm）' if metric=='space' else '0–10°同为100分，随后连续下降；虚线仅标18°')
 ax.set_title(f'样本{s["number"]} · B{s["cellID"]} → {names[p]} · {metricNames[metric]}\n{subtitle}',loc='left',fontsize=12,color='#264b3c')
 ax.text(-hx,hz+.12,'白点标签：原排名 · 分项分数；灰空圈为其他袋口停点。灰底为重叠/桌外/切角≥90°的几何无效位置。',fontsize=8,color='#53655c')
 return im
for s,p,f in panels:
 for metric in metrics:
  fig,ax=plt.subplots(figsize=(12,7.4),facecolor='#f8faf5');im=draw(ax,s,p,f,metric)
  fig.subplots_adjust(left=.025,right=.975,top=.87,bottom=.10)
  cb=fig.colorbar(im,ax=ax,orientation='horizontal',fraction=.035,pad=.035,aspect=65);cb.set_ticks([0,25,50,75,100]);cb.set_label('试验分项评价：低 ← → 高（非成功概率，无及格线）',fontsize=9)
  fig.savefig(OUT/f'sample-{s["number"]}-pocket-{p}-{metric}.png',dpi=140);plt.close(fig)
# A compact three-component example for the chat.
s,p,f=next(t for t in panels if t[0]['number']==5 and t[1]==4)
fig,axs=plt.subplots(3,1,figsize=(12,21),facecolor='#f8faf5')
for ax,metric in zip(axs,metrics):im=draw(ax,s,p,f,metric)
fig.subplots_adjust(left=.03,right=.97,top=.97,bottom=.07,hspace=.20)
cax=fig.add_axes([.20,.025,.60,.012]);fig.colorbar(im,cax=cax,orientation='horizontal',ticks=[0,25,50,75,100]).set_label('分项评价低 → 高；不合成总分，不筛选')
fig.savefig(OUT/'sample-5-three-components.png',dpi=115);plt.close(fig)
sections=[]
for s in data:
 cards=[]
 for p,info in s['pockets'].items():
  images=''.join(f'<a class="metric-image {"active" if m=="distance" else ""}" data-metric="{m}" href="sample-{s["number"]}-pocket-{p}-{m}.png" target="_blank"><img src="sample-{s["number"]}-pocket-{p}-{m}.png" alt="样本{s["number"]}到{names[p]}的{metricNames[m]}热力图"></a>' for m in metrics)
  cards.append(f'<article><h3>B{s["cellID"]} → {names[p]}</h3>{images}</article>')
 rows=[]
 for q in s['routes']:
  low,high=q['preferred'];distNote='偏近' if q['distance']<low else '偏远' if q['distance']>high else '宽缓高分区'
  angleNote='小角度同分区' if q['angle']<=10 else '超过18°参考线' if q['angle']>18 else '小角度过渡区'
  rows.append(f'<tr><td>{q["rank"]} / {q["comboIndex"]}</td><td>{names[q["pocket"]]}</td><td><b>{q["distanceScore"]:.1f}</b><br>{q["distance"]*100:.1f}cm · {distNote}<br><small>本袋偏好 {low*100:.0f}–{high*100:.0f}cm</small></td><td><b>{q["spaceScore"]:.1f}</b><br>杆后净空 {q["rear"]*100:.1f}cm<br><small>最近离库净距 {q["gap"]*100:.1f}cm</small></td><td><b>{q["angleScore"]:.1f}</b><br>{q["angle"]:.2f}° · {angleNote}</td></tr>')
 sections.append(f'<section id="sample-{s["number"]}"><h2>样本{s["number"]} · B{s["cellID"]}</h2><p>{s["id"]} · 原推荐{len(s["routes"])}条，全部保留展示</p>'+''.join(cards)+'<div class="table"><table><thead><tr><th>原排名 / 组合</th><th>第二球袋口</th><th>球距评价 /100</th><th>出杆空间评价 /100</th><th>角度评价 /100</th></tr></thead><tbody>'+''.join(rows)+'</tbody></table></div></section>')
style='''body{margin:0;background:#f1f4ed;color:#243f32;font:16px system-ui,sans-serif}header,main,footer{max-width:1350px;margin:auto;padding:24px}h1{font-size:30px}p,li{line-height:1.7;color:#526859}.note{padding:16px;background:#e2ebd9;border-radius:10px}.sticky{position:sticky;top:0;background:#fffff5f5;z-index:12;padding:10px}nav,.metric-buttons{display:flex;flex-wrap:wrap;gap:10px;justify-content:center;margin:5px}nav a,button{padding:10px 20px;border:1px solid #bdcebc;background:#deeadb;border-radius:8px;color:#30523d;text-decoration:none;font:inherit;cursor:pointer}button[aria-pressed=true]{background:#2e6859;color:white}section{scroll-margin-top:150px;padding:22px 0;border-bottom:1px solid #cbd5c6}article{margin:15px 0;background:#f8faf5;padding:16px;border-radius:12px}img{width:100%;height:auto}.metric-image{display:none}.metric-image.active{display:block}.table{overflow:auto}table{width:100%;border-collapse:collapse;background:white;margin:20px 0}th,td{padding:14px;border-bottom:1px solid #dae3d4;text-align:left;white-space:nowrap;line-height:1.6}b{font-size:21px}small{color:#6a776c}a{color:#26765d}code{white-space:normal}'''
page='''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>舒适度热力图 · 五题原停点</title><style>'''+style+'''</style><header><h1>舒适度热力图 · 五题原停点</h1><p class="note">同一批5题，全部22条原推荐。三个分项独立展示，不计算总分、不设及格线、不筛选、不改原路线。分数是待评阅的试验映射，不是成功概率或已验证的人体工学标准。</p><p>先选球距、出杆空间或角度，所有图同步切换；每题下方表格始终列出三个评价和实际测量值。红→黄→绿表示该分项从低到高，白点编号为原推荐排名。点图可打开高清图。</p><p>每个目标袋独立评估；灰空圈为选择其他袋口的原停点。C/A只作初始球位参考，第一球A已进袋，不计作第二杆障碍。虚线18°只作参考，超过18°的原点也完整显示。</p><details><summary>本次曲线怎么设定？哪些还只是近似？</summary><ul><li>球距：正常50–80cm为100分平台，近端和远端平滑衰减。针对B及该袋口，测反向中轴到母球可摆边界的深度L；L不足90cm时，平台按s=clamp(L/90cm,0.4,1)缩短为50s–80s cm。它是本次连续放宽的试验假设，尚未考虑整个扇形面积。</li><li>球距分数：100×exp(−[max(a−d,0)/(0.4a)]²−[max(d−b,0)/35cm]²)，a/b为本袋平台边界。40cm、100cm不再触发突变。</li><li>出杆空间：沿“假想球→母球”的杆尾方向，到矩形库线的距离减球半径，得到杆后净空h；最近库边净距为g。评分=100×(1−exp[−(h/25cm)²])×(0.75+0.25×(1−exp[−(g/8cm)²]))。主要看杆后空间，对侧向贴库轻度降分。</li><li>这不是完整球杆碰撞测试：尚不含杆径、架杆、仰角、桌外站位；袋口开口也按矩形边界保守处理。紫箭头表示杆尾方向，显示长度最多25cm。</li><li>角度：0–10°同为100分；超过10°后按100×exp(−[(角度−10°)/18°]²)连续下降，18°约82分、25°约50分。18°仍是旧方案参考线，本页不据此筛选。</li><li>灰底仅遮蔽母球球体越界、与B重叠、切角≥90°的位置；无按舒适度得分的遮蔽。绿色不代表已做入袋验证，全部热图仅为几何评价。</li></ul></details></header><div class="sticky"><nav>'''+''.join(f'<a href="#sample-{n}">样本{n}</a>' for n in range(1,6))+'''</nav><div class="metric-buttons">'''+''.join(f'<button type="button" data-choice="{m}" aria-pressed="{"true" if m=="distance" else "false"}">{metricNames[m]}</button>' for m in metrics)+'''</div></div><main>'''+''.join(sections)+'''</main><footer><a href="data.json">原停点与分项数据</a> · <a href="README.md">实验规则</a></footer><script>document.querySelectorAll('[data-choice]').forEach(b=>b.addEventListener('click',()=>{const m=b.dataset.choice;document.querySelectorAll('[data-choice]').forEach(x=>x.setAttribute('aria-pressed',String(x===b)));document.querySelectorAll('[data-metric]').forEach(x=>x.classList.toggle('active',x.dataset.metric===m));}));</script></html>'''
(OUT/'index.html').write_text(page)
result=dict(schema='comfort-components-preview-v1',sourceSHA256=sources,sourcePreviewSHA256=hashlib.sha256(PRIOR.read_bytes()).hexdigest(),coordinates='world XZ meters, +X right +Z down in landscape; Y up',geometry=g,policy={'samplingGridMeters':H,'distanceBasePlateau':[.5,.8],'depthScaleDenominator':.9,'depthScaleMin':.4,'distanceNearWidthFactor':.4,'distanceFarWidth':.35,'rearRoomScale':.25,'sideGapScale':.08,'sideGapWeight':.25,'anglePlateauDegrees':10,'angleDecayScaleDegrees':18,'angle18IsReferenceOnly':True,'aggregateScore':None,'selectionApplied':False},samples=data,totalOriginalRecommendations=22)
(OUT/'data.json').write_text(json.dumps(result,ensure_ascii=False,indent=2,allow_nan=False))
(OUT/'README.md').write_text('# 舒适度三分项热力图（试验）\n\n同五题阶段A原版推荐22条全部展示，按8个实际目标袋组合分别绘球距/出杆空间/角度，共24张热力图。无总分、无筛选、无模拟、无题库改写。\n\n曲线完整公式见index.html可展开说明与data.json policy。正常球距50–80cm宽缓平台，空间小按中轴后方可摆深度连续缩短；出杆空间采用杆尾方向至矩形边界净空，辅以侧向离库平滑惩罚；角度0–10°同分，之后连续衰减。18°只画参考线，不删除原推荐。以上系数都是本轮可视化试验值，非用户已确认的生产规则或实测成功率。\n\n只屏蔽球体越界/重叠/切角≥90°几何无效位置；所有原停点按来源完整保存。杆径、仰角、架杆和桌外站位未建模，袋口开口按矩形边界保守处理，绿色不证明物理入袋。\n\n来源SHA、全部原角度独立复算、标量/网格一致性、射线矩形轴向/对角标准样例、18°附近无分数跳变已验证。\n')
served=ROOT/'output/two-ball-multi-position-top10-20261024/comfort-heatmap-five';served.mkdir(exist_ok=True)
for p in OUT.iterdir():
 if p.is_file():shutil.copy2(p,served/p.name)
print('Rendered 5 samples, 8 pocket groups, 24 maps, all 22 original recommendations; no selection')
for s in data:
 print(json.dumps({'sample':s['number'],'rows':[{k:q[k] for k in ['rank','pocket','distance','gap','rear','angle','distanceScore','spaceScore','angleScore']} for q in s['routes']]},ensure_ascii=False))
