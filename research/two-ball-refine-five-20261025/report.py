from pathlib import Path
import json,math,gzip,shutil,collections
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle,Rectangle,Polygon
from matplotlib.font_manager import fontManager
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name
d=json.loads((OUT/'data.json').read_text());summary=json.loads((OUT/'summary.json').read_text());g=d['geometry'];r=g['radius'];hx=g['length']/2;hz=g['width']/2
fontManager.addfont('/Library/Fonts/Arial Unicode.ttf');plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
colors=['#147cbd','#d87824','#268651','#965ac1','#c04572'];names=['左上角袋','右上角袋','左下角袋','右下角袋','上中袋','下中袋'];cats={'center':'中杆','vertical':'纯高低','horizontal':'纯左右','mixed':'混合'}
anchors=[[-hx+r,-hz+r],[hx-r,-hz+r],[-hx+r,hz-r],[hx-r,hz-r],[0,-hz],[0,hz]]
# Reuse the preceding atlas's exact table geometry and ball rendering.
s=(ROOT/'research/two-ball-top5-random-five-20261025/render.py').read_text();exec(s[s.index('def table('):s.index('for no,rec in enumerate')])
for i,(before,after) in enumerate(zip(d['before'],d['boards']),1):
 raw=json.loads(gzip.decompress((ROOT/before['simulationSource']['part']).read_bytes()).splitlines()[before['simulationSource']['rowInPart']]);allrows={q['comboIndex']:q for q in raw['rows']};allrows.update({q['comboIndex']:q for q in json.loads((OUT/f'generated-{i}.json').read_text())['rows']})
 after['parentRoutes']=[]
 parentIDs={q['origin']['parentComboIndex'] for q in after['routes'] if 'origin' in q}
 for pid in sorted(parentIDs):
  p=allrows[pid]
  if 'trajectory2mm' in p:after['parentRoutes'].append(p)
 cid=after['defaultCellID'];fig,axs=plt.subplots(5,2,figsize=(16,21),facecolor='#f8faf6')
 for col,rec in enumerate([before,after]):
  c=next(c for c in rec['candidates'] if c['cellID']==cid);lookup={q['comboIndex']:q for q in rec['routes']};b=rec['board']
  for rank in range(5):
   ax=axs[rank,col];table(ax,b);balls(ax,b,c)
   if rank>=len(c['top5']):ax.set_title('本轮无更多合格路线',loc='left');continue
   q=c['top5'][rank];t=lookup[q['comboIndex']];xy=[v[1:] for v in t['trajectory2mm']['points']];color=colors[rank]
   ax.plot([b['cue'][0],xy[0][0]],[b['cue'][1],xy[0][1]],':',color='#8b9b91',lw=1)
   ax.plot([p[0] for p in xy],[p[1] for p in xy],color=color,lw=1.7)
   for a,v in zip(xy,xy[1:]):
    if math.dist(a,v)>.17:ax.annotate('',xy=[a[j]+.65*(v[j]-a[j]) for j in range(2)],xytext=[a[j]+.5*(v[j]-a[j]) for j in range(2)],arrowprops=dict(arrowstyle='->',color=color,lw=1))
   anchor=anchors[q['pocket']];ax.plot([c['position'][0],anchor[0]],[c['position'][1],anchor[1]],'--',color='#648966',lw=1)
   ax.add_patch(Circle(t['cueStop'],r,fc='white',ec=color,lw=1.5));ax.annotate('停',t['cueStop'],xytext=(7,7),textcoords='offset points',fontsize=8,color=color)
   warning=' · 超25°' if q['angle']>25 else ''
   label='修改前' if col==0 else '修改后'
   ax.set_title(f'{label} 第{rank+1}名 · 组合{q["comboIndex"]} · {q["angle"]:.1f}°{warning}\nS={q["score"]:.4f} · {names[q["pocket"]]}',loc='left',fontsize=12,color=color)
   origin=t.get('origin');tag=f' · 由{origin["parentComboIndex"]}微调' if origin else ' · 原参数'
   ax.text(-hx,hz+.12,f'{t["velocity"]:.3f}m/s · 打点({t["spinX"]:+.3f},{t["spinY"]:+.3f}) · {t["cueMainRailsAfterContact"]}库{tag}',fontsize=9,color='#51685d')
 fig.suptitle(f'球形{i} · B{cid} · 修改前后前五路线对比',fontsize=22,y=.994)
 fig.text(.04,.974,f'{after["id"]} · 左：原结果；右：无袋角 / 无库无左右塞 / 第二杆≤25° / P2 60分去重',fontsize=11,color='#51685d')
 fig.subplots_adjust(left=.025,right=.98,top=.947,bottom=.025,hspace=.26,wspace=.06);fig.savefig(OUT/f'compare-{i}-B{cid}.png',dpi=135);plt.close(fig)
# Browser data retains every B candidate and all top routes, with parent routes for optional overlay.
write=lambda p,v:p.write_text(json.dumps(v,ensure_ascii=False,separators=(',',':')))
write(OUT/'view-data.json',d)
old=(ROOT/'research/two-ball-top5-random-five-20261025/index.template.html').read_text()
page=old[:old.index('let sample=document.getElementById')]
page=page.replace('随机5个球形 · 前五走位路线','5个球形 · 优化前后对比').replace('从13,570个初始球形中随机抽取。沿用全量结果：2mm路径过滤 → 第二杆难度排序 → P2相似度60分去重 → 前5。','同一批5题、68个第二球位置。去掉母球袋角碰撞；无库路线去左右塞重算；有限微调至第二杆≤25°，再按P2 60分去重取前五。')
page=page.replace('<section id="cards" class="cards"></section>','<label><input id="showParent" type="checkbox"> 在修改后路线中叠加微调前的来源轨迹（灰虚线）</label><p class="sub">左右按各自的新旧排名对比，同一行不一定是同一条路线；修改后卡片注明来源组合。</p><section id="cards" class="cards"></section>')
start=page.index('<details>');end=page.index('</footer>')+len('</footer>')
page=page[:start]+'''<details><summary>本轮规则与统计口径</summary><p>第二杆先限制切角≤25°，再从符合的袋口中取最小S。S=目标球到下球点距离÷cos(切角)，不含首杆杆法难度惩罚。</p><p>先删母球袋角/圆弧/喉壁碰撞；无库左右塞归零，重新补偿瞄准、模拟。最多8条种子/第二球位置；杆速±0.2m/s，高低±0.06，吃库路线左右±0.03，保持主库顺序；失败不重试方向。</p><p>有效数量指“第二球位置×击球组合”，同一击球组合可以服务多个第二球位置。轨迹为2mm关键点；原生重算的是第一杆两球，第二球碰撞仍用几何过滤，第二杆没有模拟验证进袋。</p><a href="README.md">完整统计与记录</a> · <a href="summary.json">统计数据</a></details><footer>独立试跑结果 · 2026-10-25 · 原始数据及原图册保留</footer>'''+page[end:]
page=page.replace('查看当前球形默认位置的整张图','查看默认位置前后对比长图')
page+='''
let sample=document.getElementById('sample'),candidate=document.getElementById('candidate');DATA.boards.forEach((r,i)=>sample.add(new Option(`球形 ${i+1} · ${r.board.angle}° · ${r.candidates.length}个第二球位置`,i)));
function selectBoard(cell){let r=DATA.boards[Number(sample.value)];candidate.replaceChildren();r.candidates.forEach(c=>candidate.add(new Option(`B${c.cellID} · 修改后${c.top5.length}条`,c.cellID)));candidate.value=cell!==undefined&&r.candidates.some(c=>c.cellID===cell)?cell:r.defaultCellID;render()}
function card(rec,c,rank,after){let q=c.top5[rank],label=after?'修改后':'修改前';if(!q)return `<article class="card"><h2>${label} · 第${rank+1}名</h2><p class="empty">没有更多合格路线，未补足五条。</p></article>`;
let t=rec.routes.find(v=>v.comboIndex===q.comboIndex),origin=t.origin,parent=origin&&rec.parentRoutes?.find(p=>p.comboIndex===origin.parentComboIndex),image=routeSVG(rec,c,q,rank),warnings=[];
if(q.angle>25)warnings.push('角度超过25°');if(t.cueJawsAfterContact||t.cueOtherCushionsAfterContact)warnings.push('有袋口碰撞');if(!t.cueMainRailsAfterContact&&t.spinX!==0)warnings.push('无库有左右塞');
if(after&&parent&&document.getElementById('showParent').checked)image=image.replace('</svg>',line(parent.trajectory2mm.points.map(p=>p.slice(1)),'#7d7d7d',2,'6 7')+'</svg>');
let change=origin?`来源组合${origin.parentComboIndex} · ${origin.stage==='removeSideSpin'?'去左右塞重算':origin.stage==='speed'?'杆速微调':origin.stage==='vertical'?'高低/杆速微调':'左右/杆速微调'}`:'沿用原参数';
return `<article class="card"><h2 style="color:${colors[rank]}">${label} 第${rank+1}名 · 组合${q.comboIndex}</h2><p><b>第二杆 ${q.angle.toFixed(2)}°</b> · S=${q.score.toFixed(4)} · ${names[q.pocket]}</p>${image}<p>${cats[t.strokeCategory]} · ${t.velocity.toFixed(3)}m/s · 打点(${t.spinX.toFixed(3)}, ${t.spinY.toFixed(3)}) · ${t.cueMainRailsAfterContact}库</p><p class="sub">${after?change:warnings.length?warnings.join(' / '):'原规则保留'} · 目标球到袋口 ${(q.distance*100).toFixed(1)}cm</p>${after&&parent?`<p class="sub">微调前参数：${parent.velocity.toFixed(3)}m/s · (${parent.spinX.toFixed(3)}, ${parent.spinY.toFixed(3)})</p>`:''}</article>`}
function render(){let i=Number(sample.value),r=DATA.boards[i],before=DATA.before[i],c=r.candidates.find(v=>v.cellID===Number(candidate.value)),old=before.candidates.find(v=>v.cellID===c.cellID);document.getElementById('prev').disabled=i===0;document.getElementById('next').disabled=i===4;history.replaceState(null,'',`#sample-${i+1}-B${c.cellID}`);document.getElementById('summary').textContent=`球形 ${i+1}/5 · ${r.id} · B${c.cellID}：旧规则有效${old.eligibleCount}组 → 新规则微调前${c.baseEligible25}组 → 微调后${c.eligibleCount}组（新增${c.newQualified}组）；去重取前五 ${old.top5.length} → ${c.top5.length}条。`;document.getElementById('map').innerHTML=mapSVG(r,c);document.getElementById('png').href=`compare-${i+1}-B${r.defaultCellID}.png`;document.getElementById('cards').innerHTML=Array.from({length:5},(_,j)=>card(before,old,j,false)+card(r,c,j,true)).join('');document.querySelectorAll('.candidate').forEach(el=>{let act=()=>{candidate.value=el.dataset.cell;render()};el.onclick=act;el.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();act()}}})}
sample.onchange=()=>selectBoard();candidate.onchange=render;document.getElementById('showParent').onchange=render;document.getElementById('prev').onclick=()=>{sample.value=Number(sample.value)-1;selectBoard()};document.getElementById('next').onclick=()=>{sample.value=Number(sample.value)+1;selectBoard()};let match=location.hash.match(/^#sample-([1-5])-B(\\d+)$/);sample.value=match?Number(match[1])-1:0;selectBoard(match?Number(match[2]):undefined);
</script></html>
'''
page=page.replace('__DATA__',json.dumps(d,ensure_ascii=False,separators=(',',':')).replace('</','<\\/'));(OUT/'index.html').write_text(page)
rows=[]
for i,s in enumerate(summary['byLayout'],1):
 cs=s['candidates'];rows.append(f'|{i}|{len(cs)}|{sum(c["beforeEligible"] for c in cs)}|{sum(c["baseEligible25"] for c in cs)}|{sum(c["afterEligible"] for c in cs)}|{sum(c["afterTop"] for c in cs)}|{s["elapsedSeconds"]:.2f}s|')
readme=f'''# 5题去塞、袋角过滤、25°微调对照

[交互图册](http://127.0.0.1:51240/refine-five/) · 同一批5题全部68个B，默认B46/B23/B17/B24/B37。

|球形|B位置数|旧规则有效组合对|新规则微调前|微调后|去重前五合计|计算耗时|
|---|---:|---:|---:|---:|---:|---:|
'''+ '\n'.join(rows)+f'''

共{summary['originalSuccess']}条原始成功组合，删除{summary['jawOrOtherRemoved']}条母球袋口碰撞路线，{summary['zeroSideRequests']}条无库有左右塞路线尝试归零重算。原有纯杆参数相同的组合会合并。

新增{summary['newSimulations']}组参数模拟：{summary['newStatus']}。另有5次原参数复跑，与原落点和2mm关键点逐字段一致。新增模拟成功不等于符合第二球新规则；还须检验碰球、袋角、角度与库序。

旧规则有效组合对{summary['beforeEligible']} → 新规则微调前{summary['baseEligible25']} → 微调后{summary['afterEligible']}，微调增加{summary['addedByTune']}。这里按B×组合计数，同一组合对多个B可重复计数；前后候选池大小也不同。

原前五总{summary['beforeTop']}条，其中{summary['beforeTopWithin25']}条角度≤25°；新前五总{summary['afterTop']}条，全符合新规则。各B保留数分布{summary['topHistogram']}，不强凑5条。

单原生进程计算/评分/去重/写盘{summary['computeSeconds']:.2f}秒，含启动{summary['startupAndComputeSeconds']:.2f}秒；绘图时间不计入计算。

规则：先删除所有母球非主库碰撞（含圆弧jaw、liner、unknown），无库归零侧塞后必须重算且仍为无库。第二杆在各袋切角≤25°的集合中取最小OP/cos(cut)。每B最多8个种子，按最低切角接近25°、先覆盖库序后补齐；杆速±0.1/0.2，高低±0.03/0.06及速度±0.1组合，最后仅吃库路线侧塞±0.03及速度±0.1。每种子某阶段有合格解即停止后续阶段，保持原主库顺序。去塞后变为吃库的也可按原空库序尝试修复。按参数Float32去重缓存；不重试方向；成功存2mm关键点；不加入首杆难度代价。

第一杆重新调用冻结的原生求解器，自动按新打点求一次初始补偿瞄准，进袋失败即跳过。第二球与路径的检查仍是2mm近似几何过滤（直径+2mm余量）；没有三球完整重放、第二杆进袋模拟或微扰容错验证，25°是原生成下球点几何角。

源数据与本轮结果独立保存；r1-before-zero-rail-repair目录保留首次试跑证据。代码、输入、生成参数及失败行均在本任务目录。数据核验和浏览器核对见audit.json及任务记录。
'''
(OUT/'README.md').write_text(readme)
served=ROOT/'output/two-ball-multi-position-top10-20261024/refine-five';served.mkdir(exist_ok=True)
for f in OUT.iterdir():
 if f.is_file() and f.suffix in ('.html','.png','.md','.json'):shutil.copy2(f,served/f.name)
print('Report created',summary['computeSeconds'],summary['afterTop'])
