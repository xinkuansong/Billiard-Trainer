from pathlib import Path
import json,math,shutil,html
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle,Rectangle,Polygon
from matplotlib.font_manager import fontManager
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output'/Path(__file__).resolve().parent.name
d=json.loads((OUT/'analysis.json').read_text());geo=d['geometry'];board=d['board'];r=geo['radius'];hx=geo['length']/2;hz=geo['width']/2
trials={q['comboIndex']:q for q in d['trials']};c42=next(c for c in d['candidates'] if c['cellID']==42)
colors=['#1676b8','#d46e17','#228653','#bb4165','#8254bd','#916d19','#08868a','#a54b90','#596e43','#394da7']
names=['左上角袋','右上角袋','左下角袋','右下角袋','上中袋','下中袋'];cats={'center':'中杆','vertical':'纯高低','horizontal':'纯左右','mixed':'混合'}
fontManager.addfont('/Library/Fonts/Arial Unicode.ttf');plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
def table(ax,c):
 ax.set_aspect('equal');ax.axis('off');ax.add_patch(Rectangle((-hx-.055,-hz-.055),2*hx+.11,2*hz+.11,color='#345d50'))
 ax.add_patch(Rectangle((-hx,-hz),2*hx,2*hz,color='#dbe9d9'))
 for p in geo['pockets']:
  ax.add_patch(Polygon([(v['x'],v['z']) for v in p['lip']],color='#193c33'))
  ax.add_patch(Circle((p['center']['x'],p['center']['z']),p['radius'],color='#193c33'))
 p=geo['pockets'][board['pocket']]['center'];ax.add_patch(Circle((p['x'],p['z']),.068,fill=False,ec='#b98516',lw=2.5))
 ax.plot([board['object'][0],board['aim'][0]],[board['object'][1],board['aim'][1]],ls='--',color='#ba8a2d',lw=1.5,zorder=4)
 ax.set_xlim(-hx-.15,hx+.15);ax.set_ylim(hz+.16,-hz-.16)
 for p,fc,ec,label in [(board['cue'],'white','#284438','C'),(board['object'],'#efbd49','#8a6222','A'),(c['position'],'#fff5d6','#a97517','B')]:
  ax.add_patch(Circle(p,r,fc=fc,ec=ec,lw=1.3,zorder=10));ax.text(*p,label,ha='center',va='center',fontsize=8,color=ec,zorder=11)
def route(ax,q,c,color):
 t=trials[q['comboIndex']];ps=t['trajectory2mm']['points'];xy=[p[1:] for p in ps]
 ax.plot([board['cue'][0],xy[0][0]],[board['cue'][1],xy[0][1]],color='#82908a',ls=':',lw=1.4,zorder=3)
 ax.plot([p[0] for p in xy],[p[1] for p in xy],color=color,lw=1.8,zorder=5)
 for a,b in zip(xy,xy[1:]):
  if math.dist(a,b)>.17:
   lo=[a[i]+.50*(b[i]-a[i]) for i in range(2)];hi=[a[i]+.62*(b[i]-a[i]) for i in range(2)]
   ax.annotate('',xy=hi,xytext=lo,arrowprops=dict(arrowstyle='->',color=color,lw=1),zorder=6)
 end=t['cueStop'];ax.add_patch(Circle(end,r,fc='white',ec=color,lw=1.6,zorder=8))
 ax.annotate(str(q['rank']),xy=end,xytext=(12,12),textcoords='offset points',color=color,fontsize=11,zorder=15,bbox=dict(fc='white',ec=color,boxstyle='round,pad=.16'),arrowprops=dict(arrowstyle='-',color=color,lw=.7))
def panels(rows,path,title):
 fig,axs=plt.subplots(math.ceil(len(rows)/2),2,figsize=(15,4.45*math.ceil(len(rows)/2)),facecolor='#fafbf8',squeeze=False)
 for ax,q,color in zip(axs.flat,rows,colors):
  table(ax,c42);route(ax,q,c42,color);t=trials[q['comboIndex']];m=q['best']
  ax.set_title(f"第{q['rank']}名 · 组合{q['comboIndex']} · S={m['score']:.4f} · {names[m['pocket']]}",loc='left',fontsize=12,color=color)
  ax.text(-hx,hz+.145,f"{cats[t['strokeCategory']]} · {t['velocity']:.3f} m/s · 打点({t['spinX']:+.3f}, {t['spinY']:+.3f}) · {t['cueMainRailsAfterContact']}库",fontsize=9,color='#465d51')
 for ax in list(axs.flat)[len(rows):]:ax.axis('off')
 fig.suptitle(title,fontsize=20,y=.992,color='#213e34');fig.text(.04,.967,'C 起始母球 / A 第一球 / B 第二球；彩线：2mm关键点折线；灰点线：首碰前连线；金虚线：原进袋方向',fontsize=10,color='#52675d')
 fig.subplots_adjust(left=.025,right=.98,top=.94,bottom=.02,wspace=.06,hspace=.15);fig.savefig(OUT/path,dpi=150);plt.close(fig)
panels(c42['top10'],'B42-top10.png','B42 · 新125组结果 · 碰球过滤 → P2 ≥ 75去重 → 难度前十')
panels(c42['top10'][:4],'B42-top4.png','B42 · 前四名路线（完整前十见图册）')
# Self-contained responsive atlas, all 55 B candidates from this single layout.
jsdata={'board':board,'geometry':geo,'trials':d['trials'],'names':names,'cats':cats,'colors':colors,'candidates':[{'cellID':c['cellID'],'position':c['position'],'initial':c['initial'],'eligibleCount':c['eligibleCount'],'removedCount':c['removedCount'],'representativeCount':c['representativeCount'],'mergedCount':c['mergedCount'],'marginBandCount':c['marginBandCount'],'top10':c['top10'],'removed':c['removed']} for c in d['candidates']]}
page='''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>2mm轨迹 · P2去重后前十</title><style>
*{box-sizing:border-box}body{margin:0;background:#f6f8f4;color:#203d32;font:16px system-ui,sans-serif}main{max-width:1480px;margin:auto;padding:24px}h1{font-size:28px;margin:0 0 12px}p{line-height:1.7}nav{position:sticky;top:0;background:#f6f8f4f5;z-index:5;padding:12px 0;display:flex;gap:14px;align-items:center;flex-wrap:wrap}select,button{font:inherit;padding:8px;border:1px solid #8ca293;border-radius:6px;background:white;color:inherit}button{cursor:pointer}.stats{padding:14px 18px;background:#e5eee4;border-radius:8px;line-height:1.8}.cards{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-top:20px}.card{background:#fff;border:1px solid #d6dfd5;border-radius:10px;padding:16px}.card h2{font-size:18px;margin:0 0 8px}.card p{margin:5px 0;font-size:14px}.card svg{display:block;width:100%;height:auto}.meta{color:#56695f}details{margin:18px 0;padding:12px;background:white}table{border-collapse:collapse;width:100%;font-size:14px}td,th{padding:8px;text-align:left;border-bottom:1px solid #ddd}a{color:#167295}footer{padding:20px 0;color:#61766a}@media(max-width:850px){.cards{grid-template-columns:1fr}main{padding:14px}h1{font-size:22px}}
</style><main><h1>第一杆走位 · 2mm轨迹筛选与P2去重</h1><p>同一个初始球形：125组中117组有效。每个B位置独立摆放；比较停点的第二杆难度，优先保留更容易的路线。</p><nav><label for="candidate">第二球位置</label><select id="candidate"></select><button id="prev">上一个</button><button id="next">下一个</button><a href="keypoint-top10-data.json">完整计算数据</a></nav><div class="stats" id="stats"></div><p class="meta">C＝起始母球，A＝第一球，B＝第二球。金圈/金虚线是第一球目标袋与几何进袋方向；彩线是母球碰A后的2mm折线；灰点线是首碰前连线；绿虚线是第二杆推荐进袋方向。</p><div class="cards" id="cards"></div><details><summary>查看剔除组合及距离</summary><div id="removed"></div></details><details><summary>筛选与排序口径</summary><p>原B候选已排除遮挡初始C→假想球及A→下球点的球位，并满足S(A原袋)≤S(B六袋最小值)，允许相等。S＝目标球到生成下球点的距离÷cos(切角)，越低越容易；不是进球概率。初始无正向袋的B也可能保留，视为暂不可直接打。</p><p>遍历母球碰球后关键点的全部有限线段，距B球心≤球直径+2mm（约59.15mm）即排除；临界带单列。补查初始母球到首碰点的连线。关键点不包含第一球完整路径，原A→袋通道沿用候选库预筛；这不是三球物理重放。2mm误差相对完整采样折线，非连续碰撞保证。</p><p>按第二杆六袋最低S由低到高遍历全部保留组合，与已有代表中任意一条P2相似度≥75即合并，保留先出现、难度更低者；遍历完再取前十。算法arc1cm-rms-p2-t20-potgate-v3，直接编译现行Swift评分源码。未添加第一杆力度/杆法惩罚，未验证第二杆实际进袋。</p></details><footer>单球形研究结果 · 独立打点v2 · 2026-10-25 · 原库不变</footer></main><script>
const DATA=__DATA__;const byID=Object.fromEntries(DATA.trials.map(r=>[r.comboIndex,r]));const sel=document.getElementById('candidate');const ns=DATA.names;const xs=x=>60+(x+DATA.geometry.length/2)*320;const zs=z=>50+(z+DATA.geometry.width/2)*320;const radius=DATA.geometry.radius*320;
const line=(points,color,width=2,dash='')=>`<polyline points="${points.map(p=>`${xs(p[0])},${zs(p[1])}`).join(' ')}" fill="none" stroke="${color}" stroke-width="${width}" ${dash?`stroke-dasharray="${dash}"`:''}/>`;
const circle=(p,fill,stroke,rad=radius)=>`<circle cx="${xs(p[0])}" cy="${zs(p[1])}" r="${rad}" fill="${fill}" stroke="${stroke}" stroke-width="2"/>`;
function svg(c,q,color){const t=byID[q.comboIndex],b=DATA.board,g=DATA.geometry,xy=t.trajectory2mm.points.map(p=>p.slice(1)),end=t.cueStop;let s=`<svg role="img" aria-label="B${c.cellID}第${q.rank}名组合${q.comboIndex}的母球轨迹" viewBox="0 0 933 520"><rect x="42" y="32" width="849" height="443" rx="12" fill="#345d50"/><rect x="60" y="50" width="812.8" height="406.4" fill="#dbe9d9"/>`;
for(const p of g.pockets){s+=`<polygon points="${p.lip.map(v=>`${xs(v.x)},${zs(v.z)}`).join(' ')}" fill="#193c33"/>`;s+=circle([p.center.x,p.center.z],'#193c33','#193c33',p.radius*320)}
const pk=g.pockets[b.pocket].center;s+=circle([pk.x,pk.z],'none','#bb891c',22);s+=line([b.object,b.aim],'#bb891c',2,'6 5');s+=line([b.cue,xy[0]],'#80958b',1.8,'3 5');s+=line(xy,color,2.6);
for(let i=1;i<xy.length;i++){let a=xy[i-1],z=xy[i],dx=xs(z[0])-xs(a[0]),dy=zs(z[1])-zs(a[1]),len=Math.hypot(dx,dy);if(len<45)continue;let px=xs(a[0])+dx*.58,py=zs(a[1])+dy*.58,ux=dx/len,uy=dy/len;s+=`<path d="M${px-ux*7-uy*3},${py-uy*7+ux*3} L${px},${py} L${px-ux*7+uy*3},${py-uy*7-ux*3}" fill="none" stroke="${color}" stroke-width="2"/>`}
const pid=q.best.pocket,anchors=[[-g.length/2+g.radius,-g.width/2+g.radius],[g.length/2-g.radius,-g.width/2+g.radius],[-g.length/2+g.radius,g.width/2-g.radius],[g.length/2-g.radius,g.width/2-g.radius],[0,-g.width/2],[0,g.width/2]];
s+=line([c.position,anchors[pid]],'#5c886a',1.7,'5 6');s+=circle(end,'white',color);s+=`<text x="${xs(end[0])+13}" y="${zs(end[1])-12}" font-size="17" font-weight="bold" fill="${color}" stroke="white" stroke-width="3" paint-order="stroke">停${q.rank}</text>`;
for(const [p,f,e,l] of [[b.cue,'white','#294438','C'],[b.object,'#efbd49','#936b21','A'],[c.position,'#fff4d2','#a47520','B']]){s+=circle(p,f,e);s+=`<text x="${xs(p[0])}" y="${zs(p[1])+4}" text-anchor="middle" font-size="12" fill="${e}">${l}</text>`}return s+'</svg>'}
for(const c of DATA.candidates){const o=document.createElement('option');o.value=c.cellID;o.textContent=`B${c.cellID} · ${c.representativeCount}条代表`;sel.append(o)}
function render(){const c=DATA.candidates.find(c=>c.cellID==sel.value);location.hash='B'+c.cellID;const initial=c.initial.bestSecond;document.getElementById('stats').textContent=`B${c.cellID}：117有效 → 剔除${c.removedCount} → 剩${c.eligibleCount} → 合并${c.mergedCount} → ${c.representativeCount}条代表 → 展示${c.top10.length}条。初始第一球 S=${c.initial.first.score.toFixed(4)}；直接打B S=${initial?initial.score.toFixed(4):'无正向袋'}。压缩误差临界带：${c.marginBandCount}组。`;
document.getElementById('cards').innerHTML=c.top10.map((q,i)=>{let t=byID[q.comboIndex],m=q.best,color=DATA.colors[i];return `<article class="card"><h2 style="color:${color}">第${q.rank}名 · 组合${q.comboIndex} · S=${m.score.toFixed(4)} · ${ns[m.pocket]}</h2>${svg(c,q,color)}<p>${DATA.cats[t.strokeCategory]} · 杆速 ${t.velocity.toFixed(3)} m/s · 打点 (${t.spinX.toFixed(3)}, ${t.spinY.toFixed(3)}) · ${t.cueMainRailsAfterContact}库</p><p class="meta">第二杆切角 ${m.angle.toFixed(1)}° · 球到下球点 ${(m.distance*100).toFixed(1)} cm · 母球到B ${(Math.hypot(t.cueStop[0]-c.position[0],t.cueStop[1]-c.position[1])*100).toFixed(1)} cm</p></article>`}).join('');
document.getElementById('removed').innerHTML='<table><tr><th>组合</th><th>碰球后路径距B球心</th><th>判定</th></tr>'+c.removed.map(q=>`<tr><td>${q.comboIndex}</td><td>${(q.postContactCheck.distance*1000).toFixed(2)} mm</td><td>${q.inCompressionMarginBand?'2mm临界带，保守剔除':q.reasons.includes('post_contact_possible_collision')?'碰球后路径过近':q.reasons.includes('pre_contact_chord_intersection')?'首碰前连线过近':'停点不可评分'}</td></tr>`).join('')+'</table>'}
sel.value=DATA.candidates.some(c=>'#B'+c.cellID===location.hash)?location.hash.slice(2):'42';sel.onchange=render;document.getElementById('prev').onclick=()=>{sel.selectedIndex=Math.max(0,sel.selectedIndex-1);render()};document.getElementById('next').onclick=()=>{sel.selectedIndex=Math.min(sel.options.length-1,sel.selectedIndex+1);render()};render();
</script></html>'''
page=page.replace('__DATA__',json.dumps(jsdata,ensure_ascii=False).replace('</','<\\/'))
(OUT/'index.html').write_text(page.replace('href="keypoint-top10-data.json"', 'href="analysis.json"'))
gallery=ROOT/'output/two-ball-multi-position-top10-20261024';(gallery/'keypoint-top10.html').write_text(page);shutil.copy2(OUT/'analysis.json',gallery/'keypoint-top10-data.json')
rows=['| 排名 | 组合 | 杆法 | 杆速m/s | 左右/高低 | 第二杆S | 推荐袋 | 库数 |','|---|---:|---|---:|---|---:|---|---:|']
for q in c42['top10']:
 t=trials[q['comboIndex']];rows.append(f"| {q['rank']} | {q['comboIndex']} | {cats[t['strokeCategory']]} | {t['velocity']:.3f} | {t['spinX']:+.3f}/{t['spinY']:+.3f} | {q['best']['score']:.4f} | {names[q['best']['pocket']]} | {t['cueMainRailsAfterContact']} |")
(OUT/'README.md').write_text(f'''# 单球形：2mm轨迹过滤、第二杆难度、P2去重前十

球形`{d['layoutID']}`，来自独立打点v2全量结果，125次中117成功、7未进、1母球落袋。55个B位置均从已审计的第二球候选库直接读取、坐标不变，全部候选原筛选规则逐一重算通过。

B42：117 → 剔除11（其中1条2mm临界带）→ 保留106 → 按P2≥75合并47 → 59条代表 → 前十。初始第一球S=0.567654，直接打B42的最佳袋S=0.875858。原候选条件是第一球难度不高于第二球（S_A≤min S_B），允许相等；无正向袋也保留，不代表严格可打或模拟进袋确认。

{chr(10).join(rows)}

## 方法和边界

米制世界X–Z；图上右=+X、下=+Z，Y向上。沿用冻结几何、半径约28.575mm；每条母球碰球后折线全部有限线段取最近距离，≤2R+0.002m就剔除。额外检查起始母球至首碰点连线（本样本所有成功组首碰前无吃库、模拟仰角为0）；未保存首碰前完整曲线与第一球完整轨迹，A→袋通道沿用原候选库几何预筛。图中金虚线只是原进袋方向，不伪称第一球真实路径。误差界相对于原始采样折线，不是连续三球碰撞验证。

第二杆逐停点重算六个原生成下球点，S=OP/cos(cut)，角度≥90°无正向袋；分数越小越容易。母球到B距离单独展示，不额外作为S乘项；未加杆法/力度惩罚，未做第二杆实际进袋验证。

按S升序（同分comboIndex）遍历全部几何保留组，相似度≥75时归入首个已有代表，保留更容易者；处理完所有组再取前十。不采用相似关系的传递闭包，也不先截十再去重。P2由本轮复制并编译现行生产SeparationTrajectoryScore.swift，算法`{d['algorithm']}`；输入仅首次碰A至停点的关键点，117条共6786对，抽样正式API对拍误差0。

验证：55候选全部复算；线段投影与独立分支/叉积距离一致；六袋分数与点积公式一致；组合分类数量闭合；每位置全部代表两两相似度<75；源分片与评分源码哈希未变。只处理一个初始球形，未筛全库，未改App。

- [交互图册](index.html)：55个第二球位置切换，默认B42。
- [完整数据](analysis.json) / [摘要](summary.json) / [P2分数](p2-scores.json)
- [B42完整前十图](B42-top10.png)

![B42前四](B42-top4.png)
''')
print('REPORT',OUT,'B42 PNGs and 55-position atlas')
