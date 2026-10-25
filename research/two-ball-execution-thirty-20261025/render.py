from pathlib import Path
import importlib.util,json,math,html
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/two-ball-execution-thirty-20261025'
spec=importlib.util.spec_from_file_location('formula_five',ROOT/'research/two-ball-execution-formula-five-20261025/render.py')
old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
base=old.base;INK=old.INK;MUTED=old.MUTED;BG=old.BG
DATA=json.loads((OUT/'data.json').read_text());SUMMARY=json.loads((OUT/'summary.json').read_text())
KEYS=['stroke','power','route','interaction'];LABELS=['杆法','力度','路线','组合']
SPECIAL={
26:'短线低杆排首位、中杆从首位降末位：重点看力度与路线是否压过杆法。',
27:'含10.74m长路线：速度、库数、路长同时增加，检查重复加罚。',
28:'最小相邻差仅0.000326分：数值能排先后，实际难度先后不宜据此断言。',
29:'存在低速大侧塞：本式会降低力度项，但没有单独评价软打精细控制。',
30:'同题覆盖0–3库和大范围杆速：观察库数、速度与打点如何相互补偿。'}
def focus(s):
 n=s['number'];f=s['features']
 if n<=5:return old.REVIEWS[n-1][1]
 if n in SPECIAL:return SPECIAL[n]
 if f['minGap']<2:return f'最小相邻差 {f["minGap"]:.3f} 分；相近名次应视作待判断，不是确定等级差。'
 return '检查简单杆法与长路线的取舍；本题未出现小于2分的相邻差。'
def change(s):
 f=s['features'];return f'{f["changed"]}/5条名次变化；'+('最易路线改变。' if f['winnerChanged'] else '最易路线不变。')
def note(s,q):
 parts=q['components'];keys=sorted(KEYS,key=lambda k:parts[k],reverse=True)[:2]
 labels=dict(zip(KEYS,LABELS));dominant='、'.join(f'{labels[k]}{parts[k]/q["effort"]*100:.0f}%' for k in keys)
 adj=[abs(q['difficulty']-other['difficulty']) for other in s['newRanking'] if abs(q['rank']-other['rank'])==1]
 return '主要贡献：'+dominant+f'；最近相邻差 {min(adj):.3f} 分。'
def draw(s):
 n=s['number'];fig=plt.figure(figsize=(16,20),facecolor=BG)
 fig.text(.04,.968,f'{n:02d}  {s["title"]}',fontsize=25,color=INK)
 fig.text(.04,.943,f'{s["selectionKind"]} · 第一球{base.NAMES[s["board"]["pocket"]]} · 生成角{s["board"]["angle"]}° · B{s["candidate"]["cellID"]}  |  '+change(s),fontsize=12,color=MUTED)
 fig.text(.04,.919,'新排 = 当前四项公式；旧排 = 原杆法公式；原路线 = 题库顺序。由易到难。',fontsize=12,color=MUTED)
 fig.text(.04,.898,focus(s),fontsize=11,color='#895C30')
 for i,q in enumerate(s['newRanking']):
  t=next(t for t in s['routes'] if t['comboIndex']==q['comboIndex']);original=next(t for t in s['candidate']['top5'] if t['comboIndex']==q['comboIndex'])
  color=base.COLORS[q['previousRank']-1];y=.714-i*.154
  fig.add_artist(Rectangle((.03,y-.003),.94,.148,transform=fig.transFigure,fc='white',ec='#DCE3DA',lw=.8,zorder=0))
  base.table(fig.add_axes([.035,y+.005,.425,.133]),s,t,original,color)
  fig.text(.48,y+.122,f'新 {q["rank"]}  ←  旧 {q["previousRank"]}     原路线 {q["originalRank"]}',fontsize=18,color=color)
  fig.text(.48,y+.099,f'{t["velocity"]:.3f} m/s   ·   {t["cueMainRailsAfterContact"]} 库   ·   路长 {q["lengthMeters"]:.2f} m',fontsize=12.5,color=INK)
  fig.text(.48,y+.078,base.stroke(t),fontsize=12,color=INK)
  fig.text(.48,y+.055,f'难度 D = {q["difficulty"]:.1f}    /    合计 E = {q["effort"]:.3f}',fontsize=15,color=INK)
  fig.text(.48,y+.033,'   '.join(f'{label} {q["components"][k]:.3f}' for k,label in zip(KEYS,LABELS)),fontsize=11,color=INK)
  fig.text(.48,y+.011,note(s,q),fontsize=10.2,color=MUTED)
  base.spin(fig.add_axes([.90,y+.077,.052,.056]),t)
 fig.text(.04,.067,'C初始母球 / A第一球 / B第二球；彩线是原首碰后母球轨迹，空心白球为停点。图示为原库数据。',fontsize=10,color=MUTED)
 fig.text(.04,.050,'四项相加为E；D=100E/(E+1)。分数越低越容易，不是失败概率；按未舍入E排序，同分沿原顺序。',fontsize=10,color=MUTED)
 fig.text(.04,.033,'E = 2.5s + 0.8h + 1.2d + 0.8u² + 0.12N + 0.06L + 0.6su + 0.15Ns；u=杆速/4.5。',fontsize=10,color=MUTED)
 fig.text(.04,.016,'L按原2mm关键点折线估算；打点单位R。第二杆舒适度独立；不跑扰动，不改全量题库。',fontsize=10,color=MUTED)
 fig.savefig(OUT/f'sample-{n}.png',dpi=135);plt.close(fig)
def contact_sheet(samples,page):
 fig=plt.figure(figsize=(20,13.5),facecolor=BG)
 fig.text(.02,.976,f'球形 {samples[0]["number"]}–{samples[-1]["number"]} · 每行从易到难',fontsize=21,color=INK)
 fig.text(.02,.949,'标题：题号 / 原路线 / 旧→新名次 / 杆速 / 库数 / D。这里只对比路径形态；四项与打点详见单题大图。',fontsize=11,color=MUTED)
 for row,s in enumerate(samples):
  for col,q in enumerate(s['newRanking']):
   t=next(t for t in s['routes'] if t['comboIndex']==q['comboIndex']);orig=next(t for t in s['candidate']['top5'] if t['comboIndex']==q['comboIndex'])
   ax=fig.add_axes([.012+col*.198,.735-row*.174,.19,.140])
   base.table(ax,s,t,orig,base.COLORS[q['previousRank']-1],labels=False)
   ax.set_title(f'{s["number"]:02d}/R{q["originalRank"]}  旧{q["previousRank"]}→新{q["rank"]}\n{t["velocity"]:.2f}m/s  {t["cueMainRailsAfterContact"]}库  D{q["difficulty"]:.1f}',fontsize=9,pad=3,color=INK)
 fig.text(.02,.018,'1–5为原样本；6–25为分层抽样；26–30为定向诊断。只比较同一行，不能用D跨球形评判进球难度。',fontsize=11,color=MUTED)
 fig.savefig(OUT/f'contact-{page}.png',dpi=135);plt.close(fig)
def overview():
 fig=plt.figure(figsize=(16,17),facecolor=BG)
 fig.text(.04,.965,'30题 / 150条原轨迹 · 难度公式扩大对比',fontsize=23,color=INK)
 fig.text(.04,.936,'原5题保留 + 20题分层抽样 + 5题定向诊断；公式及权重保持不变。',fontsize=13,color=MUTED)
 fig.text(.04,.907,'23题顺序改变 · 16题最易路线改变 · 20题存在相邻差<2分（仅本样本）',fontsize=14,color='#895C30')
 ax=fig.add_axes([.04,.10,.92,.77]);ax.axis('off')
 rows=[]
 for s in DATA['samples']:
  rows.append([f'{s["number"]:02d}',s['selectionKind'],f'{"角" if s["board"]["pocket"]<4 else "中"}/{s["board"]["angle"]}°',' '.join(str(q['originalRank']) for q in s['ranking']),' '.join(str(q['originalRank']) for q in s['newRanking']),str(s['features']['changed']),f'{s["features"]["minGap"]:.3f}'])
 table=ax.table(cellText=rows,colLabels=['题','来源','袋型/生成角','旧顺序（原路线）','新顺序（原路线）','变动条数','最小邻差D'],cellLoc='center',loc='center',colWidths=[.05,.13,.13,.22,.22,.12,.13])
 table.auto_set_font_size(False);table.set_fontsize(11);table.scale(1,2.4)
 for (row,col),cell in table.get_celld().items():
  cell.set_edgecolor('#D7E0D6');cell.set_facecolor('#DBE6DB' if row==0 else ('#FFF8EA' if row>25 else ('#EEF3EF' if row<=5 else 'white')))
 fig.text(.04,.061,'20道分层题单列：15题排序改变，11题最易路线改变，13题存在相邻差<2分。',fontsize=12,color=INK)
 fig.text(.04,.039,'小于2分只是提示复核的观察线，不是已校准的并列阈值；定向诊断例不能用于推断全库比例。',fontsize=11,color=MUTED)
 fig.text(.04,.017,'尚未建模低速精细控力、低杆到达碰撞时的状态及出杆空间；图解不证明容错或真人成功率。',fontsize=11,color=MUTED)
 fig.savefig(OUT/'overview.png',dpi=135);plt.close(fig)
def web():
 source=(ROOT/'output/two-ball-execution-formula-five-20261025/index.html').read_text();style=source.split('<style>',1)[1].split('</style>',1)[0]
 style+='select{font:inherit;padding:10px;max-width:100%;background:white;color:#203d38;border:1px solid #bdcfc3;border-radius:8px}.controls{display:flex;gap:10px;flex-wrap:wrap;align-items:center;margin:20px 0}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:8px}.grid a{padding:8px;background:white;border-radius:5px}.small{font-size:14px}.stats{padding:18px;background:#e4ede4;border-radius:8px}'
 options=''.join(f'<option value="{s["number"]}">{s["number"]:02d} · {s["title"]} · {s["selectionKind"]}</option>' for s in DATA['samples'])
 contact=''.join(f'<a href="contact-{i+1}.png" target="_blank">{i*5+1}–{i*5+5}题路径总览</a>' for i in range(6))
 catalog=''.join(f'<a href="#'+str(s['number'])+'">'+f'{s["number"]:02d} · {s["title"]}</a>' for s in DATA['samples'])
 jsdata=[dict(number=s['number'],title=s['title'],kind=s['selectionKind'],focus=focus(s),change=change(s),rows=[dict(new=q['rank'],old=q['previousRank'],route=q['originalRank'],D=q['difficulty'],E=q['effort'],parts=q['components']) for q in s['newRanking']]) for s in DATA['samples']]
 page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>30题轨迹难度对比</title><style>'''+style+'''</style><main><h1>30题，继续检验这套难度公式</h1><p>原5题保留，新增20题分层抽样和5题定向诊断；150条既有路线，统一公式不变。</p><div class="stats">本样本：23题顺序改变，16题最易路线改变，20题存在相邻差&lt;2分。<br><span class="small">新增20道分层题：15题顺序改变、11题最易改变、13题存在近分。定向诊断单独展示，不把这些比例推广到全库。</span></div><p><a href="overview.png" target="_blank">30题排名总表</a> · <a href="../execution-formula-five/" target="_blank">上轮5题</a> · <a href="README.md">分析记录</a></p><details><summary>选择目录 / 6张路径总览</summary><div class="grid">'''+contact+'</div><hr><div class="grid">'+catalog+'''</div></details><div class="controls"><button id="prev">上一题</button><label>球形 <select id="select">'''+options+'''</select></label><button id="next">下一题</button></div><h2 id="title"></h2><p class="focus" id="focus"></p><a id="full" target="_blank"><img id="image" alt="当前球形五条路线及难度分项"></a><details><summary>展开分数与新旧排名表</summary><div class="scroll"><table><thead><tr><th>新排</th><th>旧排</th><th>原路线</th><th>D</th><th>杆法</th><th>力度</th><th>路线</th><th>组合</th><th>E</th></tr></thead><tbody id="rows"></tbody></table></div></details><details><summary>公式与判断边界</summary><p>E=2.5s+0.8h+1.2d+0.8u²+0.12N+0.06L+0.6su+0.15Ns；D=100E/(E+1)。s为左右塞量，h/d为高/低杆量，u=杆速/4.5，N为首碰后库数，L为原2mm关键点折线路长（米）。</p><p>分项是E的可加贡献。旧排是旧杆法公式在同题的排序，原路线是当前过滤库的编号。分数只用于同题路线比较，没有纳入不同初始球形的基础进球难度。</p><p>小于2分只是提示复核的观察线，尚未设定并列分档。路线长、力度大、库数多存在相关性；低速精细控力和实际低杆效果未建模。全程没有跑扰动模拟或改动全量题库。</p></details></main><script>const samples='''+json.dumps(jsdata,ensure_ascii=False).replace('<','\\u003c')+''';let current=1;const sel=document.getElementById('select');function show(n){if(n<1||n>30)return;current=n;const s=samples[n-1];sel.value=String(n);document.getElementById('title').textContent=String(n).padStart(2,'0')+' · '+s.title+' / '+s.kind;document.getElementById('focus').textContent=s.change+' '+s.focus;document.getElementById('image').src='sample-'+n+'.png';document.getElementById('image').alt='第'+n+'题：五条原轨迹、新旧排名和四项难度';document.getElementById('full').href='sample-'+n+'.png';document.getElementById('prev').disabled=n===1;document.getElementById('next').disabled=n===30;document.getElementById('rows').innerHTML=s.rows.map(q=>'<tr>'+[q.new,q.old,q.route,q.D.toFixed(3),...['stroke','power','route','interaction'].map(k=>q.parts[k].toFixed(4)),q.E.toFixed(4)].map(v=>'<td>'+v+'</td>').join('')+'</tr>').join('')}function navigate(n){location.hash=String(n)}sel.addEventListener('change',()=>navigate(Number(sel.value)));document.getElementById('prev').addEventListener('click',()=>navigate(current-1));document.getElementById('next').addEventListener('click',()=>navigate(current+1));window.addEventListener('hashchange',()=>show(Number(location.hash.slice(1))||1));show(Number(location.hash.slice(1))||1);</script></html>'''
 (OUT/'index.html').write_text(page)
def main():
 for s in DATA['samples']:draw(s)
 for i in range(6):contact_sheet(DATA['samples'][i*5:i*5+5],i+1)
 overview();web();print('30 route sheets, 6 path overviews, summary table and HTML generated')
if __name__=='__main__':main()
