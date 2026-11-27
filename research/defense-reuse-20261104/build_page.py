"""Select review candidates and render one self-contained, five-column HTML."""
from pathlib import Path
import hashlib, html, json, math, statistics, os
ROOT=Path(__file__).resolve().parents[2]; BASE=ROOT/'output/defense-reuse-20261104'; OUT=Path(os.environ.get('DEFENSE_REVIEW_OUTPUT',str(BASE)))
STRICT=os.environ.get('DEFENSE_REVIEW_STRICT')=='1'
rows=json.loads((BASE/'evaluated.json').read_text());geo=json.loads((OUT/'geometry.json').read_text())
R=geo['radius']; names=['左下角袋','左上角袋','右下角袋','右上角袋','左中袋','右中袋']; letters=['E','A','F','B','C','D']
groups=[('one','01','一颗球 · 双方打黑八','我方打8号，对方也打8号。'),('two_black','02','两颗球 · 我方打黑八','我方打8号，对方打9号。'),('two_own','03','两颗球 · 对方打黑八','我方打1号，对方打8号。'),('three','04','三颗球 · 双方各剩一颗','我方打1号，对方打9号，8号暂不能先碰。')]
def width(q):return q['ownAttack']['best']['cueWidth']
def signature(q):
 # Cluster mirror-equivalent cue/object constellations and all role permutations.
 return min(tuple(round(v,3) for p in [[q['cue'][0]*sx,q['cue'][1]*sz]]+sorted([[x*sx,z*sz] for x,z in q['positions']]) for v in p) for sx,sz in [(1,1),(-1,1),(1,-1),(-1,-1)])
if STRICT:
 selected=json.loads((OUT/'selected-input.json').read_text());summary=json.loads((OUT/'selection-input.json').read_text())
else:
 selected=[];used=set();summary={}
 for kind,tag,title,desc in groups:
  pool=sorted([q for q in rows if q['kind']==kind and width(q)>1e-6],key=width)
  # Deliberately broad lower fifth, NOT a calibrated hard/easy threshold.
  tail=pool[:max(5,math.ceil(len(pool)*.20))]
  chosen=[]
  for frac in [.10,.30,.50,.70,.90]:
   target=tail[min(len(tail)-1,int(frac*len(tail)))]
   choices=[q for q in tail if signature(q) not in used]
   def value(q):
    proximity=abs(math.log(width(q)/width(target)))
    diversity=min((math.dist(q['cue'],p['cue'])+math.dist(q['positions'][q['own']],p['positions'][p['own']]) for p in chosen),default=2)
    return proximity-.3*min(diversity,2)
   q=min(choices,key=value);used.add(signature(q));q=dict(q)
   q['sampleID']=f'{tag}-{len(chosen)+1}';q['positivePoolCount']=len(pool);q['percentile']=100*sum(width(p)<=width(q) for p in pool)/len(pool)
   chosen.append(q);selected.append(q)
  summary[kind]=dict(candidates=sum(q['kind']==kind for q in rows),positive=len(pool),tailUpper=width(tail[-1]),selected=[q['sampleID'] for q in chosen])
(OUT/'samples.json').write_text(json.dumps(selected,ensure_ascii=False,indent=2))
(OUT/'selection.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
def xy(p):return (150+p[1]*185,276-p[0]*185)
def pair(p):return ','.join(f'{v:.3f}' for v in xy(p))
def line(a,b,color,width=1.2,dash='',cls='analysis-line'):
 x,y=xy(a);xx,yy=xy(b);return f'<line class="{cls}" x1="{x:.3f}" y1="{y:.3f}" x2="{xx:.3f}" y2="{yy:.3f}" stroke="{color}" stroke-width="{width}" stroke-dasharray="{dash}"/>'
def circle(p,r,fill,stroke='none',sw=1,extra=''):
 x,y=xy(p);return f'<circle cx="{x:.3f}" cy="{y:.3f}" r="{r*185:.3f}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" {extra}/>'
def svg(q):
 best=q['ownAttack']['best'];c=q['cue'];b=q['positions'][q['own']]
 s=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 552" role="img" aria-label="{q["sampleID"]}，{html.escape(names[best["pocket"]])}为当前母球瞄准窗口最大的进攻袋口">',
 '<rect x="16" y="26" width="268" height="500" rx="14" fill="#60564a"/>',
 '<rect x="32.525" y="41.05" width="234.95" height="469.9" fill="#146551"/>']
 # Source jaw arcs and finite straight cushions, not hand-drawn pocket cutouts.
 for g in geo['pockets']:
  for j in g['jaws']:
   a=j['angleA'];d=math.atan2(math.sin(j['angleB']-a),math.cos(j['angleB']-a))
   pts=[[j['center'][0]+j['radius']*math.cos(a+d*i/32),j['center'][1]+j['radius']*math.sin(a+d*i/32)] for i in range(33)]
   s.append('<polyline points="'+' '.join(pair(p) for p in pts)+'" fill="none" stroke="#9ab4a5" stroke-width="1.2"/>')
   s.append(line(j['lineA'],j['lineB'],'#9ab4a5',1.2,cls=''))
 for rail in geo['pockets'][0]['rails']:s.append(line(rail['a'],rail['b'],'#9ab4a5',1.4,cls=''))
 for p,g in enumerate(geo['pockets']):
  s.append(circle(g['center'],.042,'#102d27','#88a89b',.6))
  x,y=xy(g['center']);s.append(f'<text x="{x:.2f}" y="{y+3:.2f}" text-anchor="middle" fill="#c4d6cd" font-size="9">{letters[p]}</text>')
 s.append('<g class="analysis-line">')
 s.append('<polygon points="'+' '.join(pair(p) for p in [b,best['leftEnd'],best['rightEnd']])+'" fill="#f6cb73" fill-opacity=".35"/>')
 s.append(line(b,best['aim'],'#ffd384',1.4))
 s.append(line(c,best['ghost'],'#f7fbff',1.2,'4 3'))
 for g in [best['leftGhost'],best['rightGhost']]:s.append(line(c,g,'#88d8ff',.6))
 s.append(circle(best['ghost'],R,'none','#d9f3ff',.7,extra='stroke-dasharray="2 2"'))
 s.append('</g>')
 for pos,num in zip(q['positions'],q['numbers']):
  fill='#151819' if num==8 else '#e6ad29'
  s.append(circle(pos,R,fill,'#f4f2df',.6))
  if num==9:
   x,y=xy(pos);s.append(f'<path d="M {x-4.7:.2f} {y-2.2:.2f} h 9.4 v 4.4 h -9.4 Z" fill="#fff5d6"/>')
  s.append(circle(pos,R*.53,'#f9f8ed'))
  x,y=xy(pos);s.append(f'<text x="{x:.2f}" y="{y+2.5:.2f}" text-anchor="middle" font-size="7.5" font-weight="700" fill="#182820">{num}</text>')
 s.append(circle(c,R,'#fffdf5','#d8ddd5',.6));s.append(circle([c[0]+.007,c[1]-.006],.005,'#cf5949'))
 s.append('</svg>');return ''.join(s)
def fmt(v):return f'{v:.6f}'.rstrip('0') if 0<v<.001 else (f'{v:.3f}' if v<.1 else f'{v:.2f}')
def option_state(o):
 if o['status']=='open':return ('可直进 · '+format(o['comfort']['total'],'.2f')) if STRICT else '可直进'
 return '无干净窗口' if o['status']=='no_clean_window' else '当前不可达'
cards=[]
for kind,tag,title,desc in groups:
 items=[]
 for q in [q for q in selected if q['kind']==kind]:
  best=q['ownAttack']['best'];score=best['comfort'];enemy=q['enemyAttack']['best'];drawing=svg(q)
  (OUT/(q['sampleID']+'.svg')).write_text(drawing)
  comparisons=''.join(f'<tr class="{"best" if o["pocket"]==best["pocket"] else ""}"><td>{letters[o["pocket"]]} {names[o["pocket"]]}</td><td>{fmt(o["objectWidth"])}°</td><td>{fmt(o["cueWidth"])}°</td><td>{option_state(o)}</td></tr>' for o in q['ownAttack']['options'])
  source={'accuracy':'准度球库','two':'两球走位库','three':'三球走位库'}[q['source']]
  reason='' if STRICT else f'六袋中最宽的母球瞄准窗口仍只有 {fmt(best["cueWidth"])}°；本次同类可直进候选中位于较窄的 {q["percentile"]:.1f}%。'
  if STRICT:
   reason=f'双条件通过：六袋最大母球角 {fmt(best["cueWidth"])}°；六袋代表路线最高舒适分 {q["maxPocketComfort"]:.2f}。'+(' 原03-1，保留为本轮基准。' if q['isAcceptedReference'] else '')
  items.append(f'''<article class="card" id="q-{q['sampleID']}"><div class="card-head"><strong>{q['sampleID']}</strong><span>{source}</span></div>{drawing}
<div class="body"><div class="route">我方最佳直进 · {letters[best['pocket']]} {names[best['pocket']]}</div>
<div class="primary"><small>母球瞄准容错角</small><strong>{fmt(best['cueWidth'])}<em>°</em></strong></div>
<dl><div><dt>该袋干净进袋容错角</dt><dd>{fmt(best['objectWidth'])}°</dd></div><div><dt>代表路线切角</dt><dd>{best['cut']:.1f}°</dd></div><div><dt>母球→接触位置</dt><dd>{best['cueDistance']:.2f} m</dd></div><div><dt>目标球→捕获入口</dt><dd>{best['potDistance']:.2f} m</dd></div></dl>
<div class="comfort"><span>旧舒适分（同一路线）</span><b>{score['total']:.1f}</b><small>角度 {score['angle']:.1f} · 距离 {score['distance']:.1f} · 空间 {score['space']:.1f}</small></div>
<p class="reason">{reason}</p>
<details><summary>六袋比较与来源</summary><table><thead><tr><th>袋口</th><th>袋口角</th><th>母球角</th><th>状态</th></tr></thead><tbody>{comparisons}</tbody></table>
<p>所选路线经接触侧、球体遮挡等条件裁剪后，目标球可用出射角域宽度为 {fmt(best['objectUsedWidth'])}°。表中的袋口角仅描述该目标球与球桌几何。</p><p>对方若在当前母球位置出杆，最佳母球瞄准窗口：{fmt(enemy['cueWidth'])}°。这是开局对照，非防守后的效果。</p>
<p>角色按原球位顺序：{' / '.join(str(n)+'号' for n in q['numbers'])}。原库生成角度 {q['originalAngle']}°，不作为本题实际切角。</p><code>{html.escape(q['sourceID'])}</code>
<p>先尝试合法防守，限制对方下一杆进攻。防守参考打法及执行稳定性尚未验证。</p></details></div></article>''')
 if STRICT and len(items)<5:
  items += ['<div class="card empty"><div class="body"><h3>本轮缺额</h3><p>当前抽样中未找到足够满足双条件的球形，保留空位。</p></div></div>']*(5-len(items))
 cards.append(f'<section><div class="section-heading"><span>{tag}</span><div><h2>{title}</h2><p>{desc} 球数不含母球。</p></div></div><div class="grid">'+''.join(items)+'</div></section>')
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>防守候选样题 · 四类20题</title><style>
*{box-sizing:border-box}body{margin:0;background:#f3f4ee;color:#20392e;font:14px -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif}.wrap{max-width:1800px;margin:auto;padding:36px 24px}header{max-width:1100px;margin-bottom:26px}h1{font-size:30px;margin:6px 0 12px;letter-spacing:-.6px}header p{line-height:1.8;color:#596b60;margin:8px 0}.eyebrow{font-size:12px;letter-spacing:2px;color:#4d7a63}.notice{padding:14px 18px;background:#e5ebde;border-left:3px solid #6e8c5c;line-height:1.8;border-radius:0 8px 8px 0}.legend{display:flex;gap:24px;flex-wrap:wrap;margin-top:16px;font-size:13px}.legend span:before{content:"";display:inline-block;width:21px;height:3px;margin-right:7px;vertical-align:middle;background:#d1a24f}.legend span:nth-child(2):before{background:#4592ad}.section-heading{display:flex;align-items:center;gap:14px;margin:32px 0 16px}.section-heading>span{font-size:30px;color:#97a48d;font-weight:300}.section-heading h2{font-size:20px;margin:0 0 6px}.section-heading p{margin:0;color:#65736a;font-size:13px}.scroll{overflow-x:auto;padding-bottom:14px}.grid{display:grid;grid-template-columns:repeat(5,minmax(245px,1fr));gap:14px;min-width:1280px}.card{background:#fffef9;border:1px solid #dce1d5;border-radius:12px;overflow:hidden;align-self:start}.card-head{display:flex;justify-content:space-between;padding:14px 14px 0;font-size:12px}.card-head strong{font-size:16px}.card-head span{color:#7a877b}.card svg{display:block;width:100%;height:auto}.body{padding:0 15px 16px}.route{font-size:12px;color:#617563;margin:0 0 12px}.primary{display:flex;align-items:center;justify-content:space-between;gap:8px;margin-bottom:12px}.primary small{font-size:12px}.primary strong{font-size:28px;font-variant-numeric:tabular-nums;color:#aa6630}.primary em{font-size:15px;font-style:normal;margin-left:3px}dl{font-size:12px;margin:0}dl div{display:flex;justify-content:space-between;gap:6px;margin:7px 0}dt{color:#687769}dd{margin:0;font-variant-numeric:tabular-nums}.comfort{border-top:1px solid #e5e8df;border-bottom:1px solid #e5e8df;padding:10px 0;margin:12px 0;font-size:12px;display:flex;flex-wrap:wrap;justify-content:space-between}.comfort b{font-size:15px;color:#5a6e62}.comfort small{width:100%;margin-top:6px;color:#798478;font-size:11px}.reason{font-size:12px;line-height:1.75;color:#5a6f60}details{font-size:11px;line-height:1.7}summary{cursor:pointer;padding:7px 0;color:#356b50;font-size:12px}details p{margin:10px 0}code{overflow-wrap:anywhere;color:#6c786e}table{border-collapse:collapse;width:100%;font-size:10px}th,td{text-align:left;padding:5px 2px;border-bottom:1px solid #e4e8df}.best{background:#edf2e6}footer{padding:24px 0;color:#718074;font-size:12px;line-height:1.8}label{display:inline-flex;gap:8px;align-items:center;cursor:pointer;margin:18px 0 0}input{accent-color:#427459}#show-lines:not(:checked)~.scroll .analysis-line{display:none}button{border:1px solid #bdcbbd;border-radius:6px;background:#fffef9;color:#355f47;padding:7px 12px;cursor:pointer;margin-left:16px}@media(max-width:700px){.wrap{padding:24px 16px}h1{font-size:25px}}@media print{.wrap{padding:0}.grid{min-width:0;grid-template-columns:repeat(5,1fr)}.card{break-inside:avoid}.scroll{overflow:visible}.body{padding:0 8px 10px}section{break-before:page}section:first-child{break-before:auto}button,label,input{display:none}}
</style><div class="wrap"><header><div class="eyebrow">球迹 · 现有球库复用实验 / 2026.11.04</div><h1>从进攻球形中，挑出值得考虑防守的开局</h1>
<p>四种残局，各5道。原库球位不动，只重新分配球号与球权；每题重新检查我方目标球的六个袋口。</p>
<div class="notice"><b>这是选题评审稿，合成总分待定。</b>本批按「当前母球瞄准窗口较窄」选题，旧舒适分仅并列比较；尚未验证具体防守解，不能据此认定防守一定优于进攻。</div>
<p><b>两个角度的区别：</b>袋口角是目标球出射方向的干净进袋范围；母球角是将可行出射范围反求为接触位置后，当前母球允许的瞄准方向范围，并扣除球体遮挡。都取最大连续区间的<b>全宽</b>，不是±值；越小，对方向误差越敏感。</p>
<div class="legend"><span>金色：我方最佳直进方向与实际宽度窗口</span><span>浅蓝／白虚线：母球瞄准范围与代表路线</span></div>
<p>1号为我方球，9号为对方球，8号按每行球权说明。竖桌上方为+X、右方为+Z。线条是进攻几何评估线，不是防守答案。</p></header>
<input id="show-lines" type="checkbox" checked><label for="show-lines">显示进攻评估线</label><button type="button" id="expand">展开全部六袋对比</button><div class="scroll">'''+''.join(cards)+'''</div><footer>计算采用此前热力图同版真实球半径、有限主库、袋角圆弧与捕获边界。这里使用无侧旋、忽略碰撞摩擦偏移的直接碰撞几何；未合入力度容错、真实球杆避让、翻袋／组合球和防守后的局面。旧舒适分为当前共享公式在所展示路线上的分项，不是进球概率。小窗口尾部排名仅针对本次抽样候选，不代表全库分位或球员难度等级。固定每行5题，窄屏可横向滚动。</footer></div><script>document.getElementById('expand').addEventListener('click',function(){const ds=[...document.querySelectorAll('details')];const open=ds.some(d=>!d.open);ds.forEach(d=>d.open=open);this.textContent=open?'收起全部六袋对比':'展开全部六袋对比'});</script></html>'''
if STRICT:
 policy=json.loads((OUT/'protocol.json').read_text())
 page=page.replace('四类20题','四类严格筛选 · 16题').replace('四种残局，各5道。','四种残局，本轮共16道：一颗黑八1道，其余三类各5道。')
 page=page.replace('从进攻球形中，挑出值得考虑防守的开局','按03-1的双条件，重新筛选防守开局')
 page=page.replace('本批按「当前母球瞄准窗口较窄」选题，旧舒适分仅并列比较；',f'本批同时要求：六袋最大母球瞄准容错角 ≤ {policy["cueWidthLimitDegrees"]:.8f}°，六袋代表路线最高舒适分 ≤ {policy["maxRepresentativeComfortLimit"]:.6f}。采用原03-1的未舍入数值作为本轮保守上限，尚非正式难度标准；')
 page=page.replace('小窗口尾部排名仅针对本次抽样候选，不代表全库分位或球员难度等级。','原03-2与03-3均未通过双条件，未纳入本轮。舒适分核对六袋已有代表路线，未穷举每个袋口角域内全部瞄点。')
 page=page.replace('.card-head{','.empty{min-height:260px;padding:30px 12px;color:#7b897b;border-style:dashed;background:transparent}.card-head{')
 page=page.replace('<th>状态</th>','<th>状态／舒适分</th>')
 page=page.replace('.primary small{','.primary{flex-direction:column;align-items:flex-start;gap:4px}.primary small{')
(OUT/'review.html').write_text(page)
print(json.dumps(summary,ensure_ascii=False,indent=2))
