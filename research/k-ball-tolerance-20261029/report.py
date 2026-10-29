"""Render a standalone, read-only review atlas from audited tolerance results."""
from pathlib import Path
import json,shutil,html,collections
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/k-ball-tolerance-20261029'
def read(n):return json.loads((OUT/n).read_text())
assert read('audit.json')['passed']
s=read('summary.json');ds=read('difficulty.json');samples={x['id']:x for x in read('samples.json')}
levels=['small','medium','large'];names={'small':'小偏差','medium':'中偏差','large':'大偏差'}
axes={'aim':'瞄准','speed':'杆速','sx':'左右打点','sy':'上下打点','joint':'四项组合'}
def pct(n,d):return f'{n/d:.1%}' if d else '—'
rows=''
for l in levels:
 rows+='<tr><th>'+names[l]+'</th>'+''.join(f'<td>{pct(s["overall"][l][a]["success"],s["overall"][l][a]["total"])}<small>{s["overall"][l][a]["success"]}/{s["overall"][l][a]["total"]}</small></td>' for a in axes)+'</tr>'
gradeCounts=''.join(f'<div class="metric"><strong>{s["grades"][g]}</strong><span>{g}</span></div>' for g in ['宽容','常规','敏感','极敏感'])
railRows=''.join(f'<tr><th>{k} 库</th><td>{v["samples"]}</td><td>{v["grades"].get("宽容",0)+v["grades"].get("常规",0)}</td><td>{pct(v["mediumJointPass"],v["mediumJointTotal"])}</td></tr>' for k,v in sorted(s['byRails'].items()))
failureNames={'A-not-in-specified-pocket':'A 未进指定袋','no-cue-B-contact':'未按顺序碰到 B','scratch':'母球落袋','inaccessible':'无法出杆','incomplete':'模拟未完成','wrong-first-ball':'首碰非 A'}
allFailures=collections.Counter()
for d in ds:allFailures.update(d['failures'])
failHtml=' · '.join(f'{failureNames[k]} {v:,} 次' for k,v in allFailures.most_common())
# Keep failure and success conditional counts separate: inaccessible probes have no events.
conditional=collections.Counter()
for line in (OUT/'results.jsonl').open():
 r=json.loads(line)
 if r['probeID']=='baseline':continue
 if r['potA']:
  conditional['potA']+=1
  conditional['laterB']+=r['laterB']
  conditional['success']+=r['success']
(OUT/'conditional.json').write_text(json.dumps(conditional,indent=2))
cards=[];(OUT/'images').mkdir(exist_ok=True)
gradeOrder=['宽容','常规','敏感','极敏感','基线失败']
for d in sorted(ds,key=lambda d:(gradeOrder.index(d['grade']),d['id'])):
 id=d['id'];r=samples[id];pocket='middle' if d['pocket'] in (4,5) else 'corner';timing='before' if d['axis']=='inAngle' else 'after'
 shutil.copy2(ROOT/f'output/k-ball-middle-rails-20261029/images/{id}.png',OUT/f'images/{id}.png')
 stats=''.join('<tr><th>'+names[l]+'</th>'+''.join(f'<td>{d["stats"][l]["axisPass"][a]}/2</td>' for a in ['aim','speed','sx','sy'])+f'<td>{d["stats"][l]["jointPass"]}/32</td></tr>' for l in levels)
 fails='；'.join(f'{failureNames[k]} {v}' for k,v in sorted(d['failures'].items(),key=lambda x:-x[1])) or ('原始杆法母球落袋，不进入扰动分级。' if d['grade']=='基线失败' else '120 次扰动全部成功。')
 card=f'''<article class="card" id="{id}" data-grade="{d['grade']}" data-pocket="{pocket}" data-timing="{timing}" data-rail="{d['railOrdinal']}">
 <header><div><h3>{id} · {d['regionID']}</h3><p>{'中袋' if pocket=='middle' else '角袋'} · 第 {d['railOrdinal']} 库{'前' if timing=='before' else '后'} K · 碰 B 前实际 {d['actualRails']} 库</p></div><b class="badge">{d['grade']}</b></header>
 <p>参考{'入' if timing=='before' else '出'}库角 {d['sourceAngle']:.1f}° · B 离库 {100*d['initialGap']:.1f} cm</p>
 <img src="images/{id}.png" alt="{id} 名义杆法三球完整轨迹" width="1500" height="1080" loading="lazy">
 {('<div class="scroll"><table><thead><tr><th>扰动档</th><th>瞄准</th><th>杆速</th><th>左右</th><th>上下</th><th>组合</th></tr></thead><tbody>'+stats+'</tbody></table></div>') if d['grade']!='基线失败' else ''}
 <p class="muted">失败计数（可重叠）：{fails}</p><p class="muted">成功但库序变化：{d['changedSuccessfulRoute']} 次。图为名义杆法，非扰动轨迹叠加。</p>
 <a href="http://127.0.0.1:8855/?pocket={pocket}&rail={d['railOrdinal']}#{d['regionID']}">回看原候选区域 ↗</a></article>'''
 cards.append(card)
page='''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>K球 · 首轮容错图册</title><style>
 :root{color-scheme:dark;font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif;background:#0e1b23;color:#e8f0f2}*{box-sizing:border-box}body{margin:0}main{max-width:1120px;margin:auto;padding:36px 24px 80px}h1{font-size:36px;margin:10px 0}h2{font-size:25px;margin-top:0}h3{margin:0;font-size:23px}p{line-height:1.75;margin:10px 0}a{color:#72cfe6}small{display:block;color:#9eb5bd;font-weight:400;margin-top:6px;font-size:12px}.eyebrow{color:#7cdbbc;letter-spacing:2px;font-size:14px}.muted{color:#abc0c7;font-size:14px}.lead{font-size:20px;max-width:900px}.metrics{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin:26px 0}.metric,.panel,.card{background:#162830;border:1px solid #29424c;border-radius:16px}.metric{padding:20px}.metric strong{display:block;font-size:36px;color:#85e1bf}.metric span{display:block;margin-top:5px}.panel{padding:24px;margin:20px 0}.scroll{overflow:auto}table{width:100%;border-collapse:collapse;white-space:nowrap;font-variant-numeric:tabular-nums}th,td{padding:13px 12px;text-align:left;border-bottom:1px solid #324951}th{color:#b6cbd2}td{font-size:17px}li{line-height:1.9;margin:8px 0}.filters{display:flex;flex-wrap:wrap;gap:14px;align-items:end}.filters label{display:grid;gap:6px;color:#adc4ca;font-size:14px}select,input,button{font:inherit;background:#10202a;color:#eaf4f6;border:1px solid #45606b;border-radius:8px;padding:10px 13px}button{cursor:pointer}button:disabled{opacity:.35;cursor:default}.card{padding:24px;margin:24px 0}.card header{display:flex;justify-content:space-between;align-items:start;gap:12px}.card header p{color:#b2c8cf}.badge{padding:9px 16px;background:#20473e;color:#9be3c7;border-radius:30px;white-space:nowrap}.card img{width:100%;height:auto;border-radius:10px;display:block;margin:14px 0}.pager{display:flex;gap:20px;justify-content:center;align-items:center;padding:12px}.note{border-left:3px solid #e9bb5e;padding-left:15px;color:#e3cf9b}[hidden]{display:none!important}@media(max-width:640px){main{padding:22px 14px}.panel,.card{padding:16px}h1{font-size:28px}.lead{font-size:17px}.metrics{grid-template-columns:repeat(2,1fr)}th,td{padding:10px 8px}.filters label{flex:1;min-width:130px}.card header{display:block}.badge{display:inline-block;margin-top:5px}}
 </style></head><body><main><div class="eyebrow">K 球题库 / 10 cm · ≤45° / 首轮容错</div><h1>能 K 到，还要看容许多少偏差</h1><p class="lead">292 个成功样本，各做 120 次扰动；加上 293 次基线重放，共 <b>35,333 次</b>生产物理模拟。</p><p class="muted">另保留 1 个基线母球落袋反例。基线事件复现、实际输入与逐条判题审计通过。2026-10-29 · 模拟分级待评阅</p>
 '''+f'<div class="metrics">{gradeCounts}</div>'+'''
 <section class="panel"><h2>本轮最明显的区别</h2><p>当前样本对<b>瞄准和左右打点</b>更敏感，杆速相对宽容。中档单轴扰动下，瞄准通过 51.5%，左右打点通过 55.8%，杆速通过 98.1%。很多失败源于 A 未进指定袋，因此难度同时包含进 A 和 K 到 B。</p><p>宽容与常规共 <b>80 个</b>，可作为首批优先候选；敏感 115 个可留作进阶；极敏感 97 个先保留研究。此处是模拟筛选建议，尚未做真人难度标定，也没有开始批量生成或去重。</p><p class="note">通过率只对应本轮设定的扰动点，不是真人成功率，也不是连续误差范围的保证。同一原球形有多个 B 点，统计按 B 样本计，尚未去重，不能当作全题库分布。</p></section>
 <section class="panel"><h2>分别改变哪一项，会更容易失败？</h2><p class="muted">单项为正、负两个端点 ×292 题；组合为四项共同变化的 32 点 ×292 题。</p><div class="scroll"><table><thead><tr><th>扰动档</th><th>瞄准</th><th>杆速</th><th>左右打点</th><th>上下打点</th><th>四项组合</th></tr></thead><tbody>'''+rows+'''</tbody></table></div>
 <p>小：±0.05° / ±1.5% / 左右与上下各 ±0.01R<br>中：±0.10° / ±3% / 左右与上下各 ±0.02R<br>大：±0.20° / ±6% / 左右与上下各 ±0.04R</p><p class="muted">R 为球半径；0.01R 约 0.286 mm。杆速变化不是实际施力或击球能量百分比。侧塞变化时不重新补偿瞄准。</p></section>
 <section class="panel"><h2>暂定分级怎么判</h2><p>每档都要求 <b>8 个单轴端点全部成功，且组合至少 26/32 成功</b>。同时满足所有更小档：通过大档为宽容，通过中档为常规，通过小档为敏感，小档未通过为极敏感。</p><p>始终只判首碰 A、A 进指定袋、之后碰 B、母球不落袋。允许扰动后改变库序，不限制 B 的后续效果。</p><p class="muted">'''+f'{s["changedSuccessfulRoute"]:,} 次扰动成功但库序变化，仍计成功；{s["nonmonotoneJointSamples"]} 个样本出现组合通过数随档位变大而局部上升，分级仍要求逐档连续通过。'+'''</p></section>
 <section class="panel"><h2>库数不直接等于难度</h2><div class="scroll"><table><thead><tr><th>碰 B 前实际库数</th><th>样本数</th><th>宽容＋常规</th><th>中档组合通过率</th></tr></thead><tbody>'''+railRows+'''</tbody></table></div><p>本批中袋样本中档组合通过率 86.7%，角袋 40.7%；入库前 62.7%，出库后 62.9%。这是当前选样结果，受原球形与 B 点重复影响，不宜推成普遍规律。</p></section>
 <section class="panel"><h2>失败发生在哪里</h2><p>'''+failHtml+'''</p><p class="muted">上述原因可同时发生，不能相加当失败总数。不可出杆没有碰撞事件，不再归因为未进 A 或未碰 B。</p><p>'''+f'在 A 确实进袋的 {conditional["potA"]:,} 次扰动中，按顺序碰到 B 的为 {conditional["laterB"]:,} 次（{pct(conditional["laterB"],conditional["potA"])}），最终三项全部成功 {conditional["success"]:,} 次。'+'''</p></section>
 <section class="panel" id="browse"><h2>逐球对照完整轨迹</h2><div class="filters">
 <label>难度<select id="grade"><option value="">全部难度</option><option>宽容</option><option>常规</option><option>敏感</option><option>极敏感</option><option>基线失败</option></select></label>
 <label>A 目标袋<select id="pocket"><option value="">全部袋口</option><option value="middle">中袋</option><option value="corner">角袋</option></select></label>
 <label>K 时机<select id="timing"><option value="">入库前与出库后</option><option value="before">入库前 K</option><option value="after">出库后 K</option></select></label>
 <label>观察库<select id="rail"><option value="">第 1–3 库</option><option value="1">第 1 库</option><option value="2">第 2 库</option><option value="3">第 3 库</option></select></label>
 <label>样本编号<input id="search" type="search" placeholder="如 C001 / M17"></label></div><p id="count" aria-live="polite"></p><p class="muted">按宽容→常规→敏感→极敏感排列；每页 8 个，完整轨迹默认展示。观察第 n 库前 K 通常实际吃 n−1 库。</p></section>
 <div id="cards">'''+''.join(cards)+'''</div><div class="pager"><button id="prev">上一页</button><span id="page"></span><button id="next">下一页</button></div>
 <p class="muted">证据：<a href="protocol.json">采样协议</a> · <a href="summary.json">统计</a> · <a href="difficulty.json">逐题分级</a> · <a href="audit.json">独立审计</a> · <a href="report.md">文字报告</a></p>
 </main><script>
 const ids=['grade','pocket','timing','rail','search'],inputs=Object.fromEntries(ids.map(id=>[id,document.getElementById(id)])),cards=[...document.querySelectorAll('.card')];let page=0;const pageSize=8;
 const params=new URLSearchParams(location.search);ids.forEach(id=>inputs[id].value=params.get(id)||'');
 function render(){const filtered=cards.filter(c=>ids.every(id=>id==='search'?c.textContent.toLowerCase().includes(inputs[id].value.toLowerCase()):!inputs[id].value||c.dataset[id]===inputs[id].value));const pages=Math.max(1,Math.ceil(filtered.length/pageSize));page=Math.min(page,pages-1);cards.forEach(c=>c.hidden=true);filtered.slice(page*pageSize,(page+1)*pageSize).forEach(c=>c.hidden=false);document.getElementById('count').textContent=`匹配 ${filtered.length} 个样本 / 共 ${cards.length} 个`;document.getElementById('page').textContent=`${page+1} / ${pages}`;document.getElementById('prev').disabled=page===0;document.getElementById('next').disabled=page===pages-1;const p=new URLSearchParams();ids.forEach(id=>{if(inputs[id].value)p.set(id,inputs[id].value)});history.replaceState(null,'','?'+p.toString());}
 ids.forEach(id=>inputs[id].addEventListener(id==='search'?'input':'change',()=>{page=0;render()}));['prev','next'].forEach(id=>document.getElementById(id).addEventListener('click',()=>{page+=id==='next'?1:-1;render();document.getElementById('browse').scrollIntoView()}));render();
 </script></body></html>'''
(OUT/'index.html').write_text(page)
md=f'''# K球首轮容错结果

首版规则为B球面离观察库边0–10cm，参考入／出库角≤45°，只判首碰A、进指定A袋、随后碰B且母球不落袋。

已完成35333次生产物理模拟：293个基线全部复现，292个成功样本各120次扰动，另1个原始母球落袋反例。实际输入、全量事件与源码绑定独立审计通过。

## 暂定分级

宽容8，常规72，敏感115，极敏感97。每档要求8个单轴端点全通过、组合≥26/32通过并且所有更小档通过；大／中／小／未通过小档对应四级。建议宽容和常规80个优先候选，敏感115个保留进阶，极敏感97个暂不批量入库。门槛待评阅，不是真人等级。

|档位|瞄准|杆速|左右打点|上下打点|四项组合|
|---|---|---|---|---|---|
'''
for l in levels:md+='|'+names[l]+'|'+ '|'.join(pct(s['overall'][l][a]['success'],s['overall'][l][a]['total']) for a in axes)+'|\n'
md+='''
小档：±0.05°、±1.5%杆速、左右和上下打点各±0.01R；中档分别为±0.10°／±3%／±0.02R；大档为±0.20°／±6%／±0.04R。组合为32个共同扰动点；单项各2个正负端点。侧塞变化不重新补偿瞄准。

瞄准和左右打点是本批的主要敏感项，杆速相对宽容。大量失败来自进A，不能仅按最后一段K轨迹判断整题难度。库数也不能直接作为难度等级。

## 失败与边界

'''+failHtml+f'''。

原因可重叠，不可相加。A进袋的{conditional['potA']}次中，{conditional['laterB']}次按顺序碰B，最终{conditional['success']}次成功。成功但库序变化{s['changedSuccessfulRoute']}次全部保留成功；{s['nonmonotoneJointSamples']}个样本组合通过数非单调，仍保守要求逐档通过。

这是设定扰动下的模拟通过比例，不是真人成功率，也不保证整个连续偏差区间。当前是选出的B位置样本，同一母球/A来源会重复，尚未去重，不能推广为完整题库分布。只运行原生独立物理程序，未做App UI或实台难度验收。

## 后续生成与去重建议

采用本轮已冻结的几何与判题规则，批量候选先真实重放再套用同一容错协议。优先生成宽容、常规题，分袋口、实际库数和入库前／出库后检查覆盖；敏感作为进阶候选；极敏感先隔离。不要为填满某个分类强行保留极敏感题。

去重分两层：精确题目与杆法相同的直接合并；相同母球/A与目标袋、同一路径上的相邻B位置归为题族。镜像时同步映射球、袋、库及打点方向；不同K时机、不同路线及明显不同容错机制保留差异。相邻B距离阈值及每题族保留数量待覆盖统计后定，避免提前丢失有教学差异的题。正式导出应留来源、名义杆法、种子、物理源码SHA和容错记录。

本轮批量生成与去重未执行，先交付当前样本容错分级供评阅。图册：http://127.0.0.1:8856/ 。
'''
(OUT/'report.md').write_text(md)
print(f'Rendered {len(cards)} cards, 293 complete-route images; conditional={dict(conditional)}')
