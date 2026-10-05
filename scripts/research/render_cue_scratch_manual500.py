#!/usr/bin/env python3
import json,shutil,collections
from cue_scratch_manual500 import DEST,BASE
rows=json.loads((DEST/'cards.json').read_text());stats=json.loads((DEST/'summary.json').read_text());mapping=json.loads((DEST/'historical-map.json').read_text())
shutil.copy2(__file__.replace('render_cue_scratch_manual500.py','cue_scratch_manual500.js'),DEST/'app.js')
options='<option value="">全部袋口</option>'+''.join(f'<option value="{i}">{i}号袋</option>' for i in range(6))
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>母球掉袋 · 500例手选合集</title><style>
*{box-sizing:border-box}body{margin:0;background:#edf2ed;color:#19372c;font:16px/1.6 -apple-system,"PingFang SC",sans-serif}main{max-width:1500px;margin:auto;padding:24px}header{background:#f8d647;border-radius:20px;padding:24px}h1{font-size:32px;line-height:1.3;margin:0 0 8px}p{margin:10px 0}.toolbar,.selection{background:#fff;border-radius:14px;padding:16px;margin:16px 0}.filter-grid{display:flex;gap:12px;flex-wrap:wrap}.filter-grid label{display:flex;flex-direction:column;font-size:13px;color:#4c665a}select,input,button,textarea{font:inherit}select,input[type=search]{padding:9px;border:1px solid #bccfc3;border-radius:8px;max-width:100%}button{border:0;border-radius:8px;padding:10px 16px;background:#1e5140;color:#fff;cursor:pointer}button:disabled{opacity:.35;cursor:default}.actions{display:flex;gap:10px;flex-wrap:wrap;align-items:center;margin-top:14px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,430px),1fr));gap:18px}article{background:white;border:3px solid transparent;border-radius:15px;padding:15px}article.chosen{border-color:#d6a91a;background:#fffdf1}.choose{display:flex;align-items:center;gap:10px;cursor:pointer;font-size:22px}.choose input{width:24px;height:24px;accent-color:#27634c}.metrics{font-size:15px}article img{width:100%;aspect-ratio:800/420;cursor:zoom-in}small,.notes{color:#54695e;font-size:13px}details{margin-top:12px}pre{white-space:pre-wrap;font-size:12px}a{color:#246447}.selection textarea{display:block;width:100%;height:80px;margin-top:10px;border:1px solid #bfd0c5;border-radius:8px;padding:10px}.pager{display:flex;gap:12px;align-items:center;padding:14px 0}dialog{width:min(1200px,96vw);border:0;border-radius:14px;padding:16px;background:#f3f6f2}dialog::backdrop{background:#071c16b8}dialog img{width:100%}#results{scroll-margin-top:10px}table{border-collapse:collapse}td,th{text-align:left;padding:6px 14px;border-bottom:1px solid #ccdad0}@media(max-width:600px){main{padding:12px}h1{font-size:26px}.filter-grid label{flex:1 1 42%}.filter-grid select{width:100%}article{padding:10px}}</style><main>
<header><h1>母球掉袋 · 500例手选合集</h1><p>0库 200例 · 1库 100例 · 2库 100例 · 3库 100例</p><b>主合集球心距全部 ≥60厘米 · 逐例生产求解与固定方向复验</b><p>先看球形，勾选喜欢的；选完导出清单或把编号发给我。</p></header>
<p>白线＝母球，黄线＝目标球，橙色数字＝碰库顺序，红圈＝母球落袋。轨迹来自引擎记录；点击图片可放大。</p>
<p class="notes">本版按距离、角度、袋口/库序和力度档位分层重筛，不按力度稳定性挑前500名。60–90cm 150例、90–120cm 150例、≥120cm 200例。1°–5°小角度单独标注；旧版近球放入独立对照区。所有主候选为中杆无塞、目标球直接进推荐袋、碰球前不吃库。该合集用于人工选材，不代表已穷尽常见球形；实体出杆空间、原生画面待验。</p>
<section class="selection"><strong id="chosen-count">已选0个</strong><div class="actions"><button id="download">导出手选清单</button><button id="copy">复制编号</button><span id="copy-status" role="status"></span></div><textarea id="chosen-ids" readonly aria-label="已选编号"></textarea><small id="storage-note"></small></section>
<section class="toolbar"><div class="filter-grid">
<label>查看范围<select id="scope"><option value="main">主合集500例</option><option value="history">历史0库对照</option><option value="selected">仅看已选</option></select></label>
<label>母球库数<select id="rail"><option value="">全部</option><option value="0">0库</option><option value="1">1库</option><option value="2">2库</option><option value="3">3库</option></select></label>
<label>两球距离<select id="distance"><option value="">全部距离</option><option value="60-90">60–90cm</option><option value="90-120">90–120cm</option><option value="120+">≥120cm</option></select></label>
<label>切角<select id="angle"><option value="">全部角度</option><option value="small">小角度 &lt;5°</option><option value="normal">≥5°</option><option value="thin">薄球 ≥60°</option></select></label>
<label>目标球袋<select id="target">OPTIONS</select></label><label>母球袋<select id="scratch">OPTIONS</select></label>
<label>编号<input id="query" type="search" placeholder="例如 M001 / R001"></label></div><div class="actions"><button id="reset">重置筛选</button><span id="result-count" role="status"></span></div></section>
<section id="results"><div class="pager"><button data-page="prev">上一页</button><button data-page="next">下一页</button><span>每页30例</span></div><p id="empty" hidden>没有符合条件的球形，请调整筛选。</p><div id="grid" class="grid"></div><div class="pager"><button data-page="prev">上一页</button><button data-page="next">下一页</button></div></section>
<details><summary>之前的0库案例去了哪里？</summary><p>满足60cm条件的旧案例保留原始输入进入主合集；不足60cm的保留为R编号对照，不计入500例。</p><table><tr><th>旧案例</th><th>当前编号</th><th>球心距</th></tr>MAP</table></details>
<footer><p><a href="cases.json">500例轨迹与参数</a> · <a href="summary.json">本轮复验统计</a> · <a href="REPORT.md">筛选说明</a> · <a href="../index.html">旧100例图册</a></p></footer>
<dialog id="image-dialog"><div class="actions"><b id="large-label"></b><button id="close-image">关闭</button></div><img id="large-image" alt="放大的实测球形"></dialog>
<script id="case-data" type="application/json">DATA</script><script src="app.js"></script></main></html>'''
page=page.replace('OPTIONS',options).replace('MAP',''.join(f'<tr><td>{x["old"]}</td><td><a href="#{x["current"]}">{x["current"]}</a></td><td>{x["distanceM"]*100:.1f} cm</td></tr>' for x in mapping)).replace('DATA',json.dumps(rows,ensure_ascii=False).replace('</','<\\/'))
eligible=[x for x in rows if not x['archive'] and x['speed']<=4.5]
active=[x for x in eligible if not x.get('duplicateOf')]
counts=collections.Counter(x['rails'] for x in active)
page=page.replace('母球掉袋 · 500例手选合集',f'母球掉袋 · {len(active)}例手选合集')
page=page.replace('0库 200例 · 1库 100例 · 2库 100例 · 3库 100例',' · '.join(f'{n}库 {counts[n]}例' for n in range(4)))
page=page.replace('主合集球心距全部 ≥60厘米',f'杆速 ≤4.5 m/s · 从原500例保留{len(active)}例 · 球心距 ≥60厘米')
page=page.replace('主合集500例',f'主合集{len(active)}例')
page=page.replace('<option value="history">',f'<option value="all">去重前{len(eligible)}例</option><option value="history">',1)
page=page.replace('60–90cm 150例、90–120cm 150例、≥120cm 200例。','当前已过滤杆速大于4.5 m/s的案例；原编号和勾选记录保留。')
page=page.replace('<a href="cases.json">500例轨迹与参数</a>','<a href="active-cases.json">当前候选轨迹与参数</a> · <a href="cases.json">原500例数据归档</a>')
page=page.replace('<script src="app.js">','<script src="app.js?v=dedup1">')
full=json.loads((DEST/'cases.json').read_text())
active_ids={x['id'] for x in active}
(DEST/'active-cases.json').write_text(json.dumps([x for x in full if x['galleryID'] in active_ids],ensure_ascii=False,indent=2))
speed_filter=dict(maxCueSpeed=4.5,originalMainCases=500,kept=len(eligible),removed=500-len(eligible),byRail=dict(collections.Counter(x['rails'] for x in eligible)),preserveOriginalIDs=True)
(DEST/'speed-filter.json').write_text(json.dumps(speed_filter,ensure_ascii=False,indent=2))
stats['currentDisplay']=dict(speed_filter,kept=len(active),byRail=dict(counts),deduplicated=len(eligible)-len(active))
if (DEST/'deduplication.json').exists():
 dedup=json.loads((DEST/'deduplication.json').read_text())
 groups=''.join('<p><a href="#'+g['representative']+'"><b>'+g['representative']+'</b></a> ← '+', '.join('<a href="#'+i+'">'+i+'</a>' for i in g['members'][1:])+'</p>' for g in dedup['groups'] if len(g['members'])>1)
 page=page.replace('<footer>',f'<details><summary>对称/相似合并对应表（{dedup["removed"]}例）</summary><p>按袋口和库序镜像对齐，再比较起始球位、碰库点与实测轨迹。被合并案例仍可查看、勾选；已有勾选不替换。<a href="deduplication.json">合并依据</a></p>{groups}</details><footer>',1)
 page=page.replace('</header>',f'</header><p><b>对称/相似去重：{len(eligible)} → {len(active)}例。</b> 选择“去重前{len(eligible)}例”可对照；已有勾选仍按原编号保留，可在“仅看已选”查看并导出。</p>',1)
(DEST/'summary.json').write_text(json.dumps(stats,ensure_ascii=False,indent=2))
(DEST/'index.html').write_text(page)
print(DEST/'index.html')
