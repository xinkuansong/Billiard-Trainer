"""Select reviewed formations without changing any simulated shot or tolerance record."""
from pathlib import Path
from itertools import combinations,product
from collections import defaultdict,Counter
import json,math,hashlib,shutil,re,html,argparse
ROOT=Path(__file__).resolve().parents[2]
args=argparse.ArgumentParser();args.add_argument('--center-limit',action='store_true');CENTER=args.parse_args().center_limit
SRC=ROOT/'output/k-ball-tolerance-20261029';OUT=ROOT/('output/k-ball-center10-20261029' if CENTER else 'output/k-ball-selected-20261029')
OUT.mkdir(exist_ok=True);(OUT/'images').mkdir(exist_ok=True)
def read(n):return json.loads((SRC/n).read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
ss=read('samples.json');dd={d['id']:d for d in read('difficulty.json')};D=2*read('geometry.json')['radius']
measurements={};angleAudit={}
if CENTER:
 from center_geometry import measure_all,render_center
 measurements,angleAudit=measure_all(ROOT,ss,read('geometry.json'))
 (OUT/'angle-audit.json').write_text(json.dumps(angleAudit,ensure_ascii=False,indent=2))
 (OUT/'measurements.json').write_text(json.dumps(measurements,ensure_ascii=False,indent=2))
assert read('audit.json')['passed'] and len(ss)==293
for n,h in read('audit.json')['sha256'].items():assert sha(SRC/n)==h,n
rank={'极敏感':0,'敏感':1,'常规':2,'宽容':3,'基线失败':-1}
def signature(s):return (s['seed']['pocket'],tuple(s['railsBeforeK']),s['axis'],s['railID'])
def dist(a,b):return math.dist(a['B'],b['B'])
def distinct(a,b):return signature(a)!=signature(b) or dist(a,b)>=D
def quality(s):
 d=dd[s['id']];return (rank[d['grade']],d['stats']['medium']['jointPass'],d['stats']['large']['jointPass'],d['stats']['small']['jointPass'])
def subset_score(combo):
 grades=[rank[dd[s['id']]['grade']] for s in combo]
 return (grades.count(3),grades.count(2),len(combo),sum(quality(s)[1] for s in combo),sum(quality(s)[2] for s in combo),len({signature(s) for s in combo}),min((dist(a,b) for a,b in combinations(combo,2)),default=0))
groups=defaultdict(list)
for s in ss:groups[tuple(s['seed']['cue']+s['seed']['object'])].append(s)
assert len(groups)==39
# Exact coordinate grouping, not route ID or source label. Check all reflected
# original formations within 1 mm so a mirror copy cannot escape the quota.
keys=list(groups);mirror_pairs=[]
for a,b in combinations(keys,2):
 for sx,sz in product([-1,1],repeat=2):
  transformed=(a[0]*sx,a[1]*sz,a[2]*sx,a[3]*sz)
  if max(math.dist(transformed[:2],b[:2]),math.dist(transformed[2:],b[2:]))<=.001:mirror_pairs.append([a,b,sx,sz])
assert not mirror_pairs,'Mirror-equivalent formation found; merge its quota before selecting.'
report=[];selected=[];rejections=[]
for gi,(_,rows) in enumerate(sorted(groups.items(),key=lambda kv:kv[1][0]['seed']['layout']),1):
 rows.sort(key=lambda s:s['id']);pool=[s for s in rows if s['success'] and rank[dd[s['id']]['grade']]>=1 and (not CENTER or measurements[s['id']]['centerRailDistance']<=.1)]
 options=[c for n in (1,2) for c in combinations(pool,n) if all(distinct(a,b) for a,b in combinations(c,2))]
 chosen=list(max(options,key=subset_score)) if options else []
 reason={s['id']:'优先容错，并与同组其余保留项有位置或打法差异。' for s in chosen}
 if len(chosen)==2:
  third=[s for s in pool if s not in chosen and rank[dd[s['id']]['grade']]>=min(rank[dd[c['id']]['grade']] for c in chosen) and all(distinct(s,c) for c in chosen) and (signature(s) not in {signature(c) for c in chosen} or all(dist(s,c)>=2*D for c in chosen))]
  if third:
   extra=max(third,key=lambda s:(quality(s),signature(s) not in {signature(c) for c in chosen},min(dist(s,c) for c in chosen)))
   chosen.append(extra);reason[extra['id']]='第三项增加不同打法，或与前两项均相距至少两个球直径；不降低本组最低容错档。'
 chosen.sort(key=lambda s:(-rank[dd[s['id']]['grade']],s['id']))
 gid=f'G{gi:02d}';ids=[s['id'] for s in chosen]
 for s in rows:
  if s in chosen:continue
  close=[c['id'] for c in chosen if not distinct(s,c)]
  why='球心距观察库边超过10cm' if CENTER and measurements[s['id']]['centerRailDistance']>.1 else '原始杆法失败' if not s['success'] else '极敏感，不纳入精选' if rank[dd[s['id']]['grade']]==0 else '与保留项近似重复' if close else '已有更优代表，或第三项未增加足够差异'
  rejections.append(dict(id=s['id'],groupID=gid,reason=why,nearSelected=close))
 status=('球心10cm内无容错合格候选' if CENTER else '仅极敏感／失败，暂不入选') if not chosen else '容错或位置差异不足，仅保留1项' if len(chosen)==1 else f'保留{len(chosen)}项'
 pairs=[dict(a=a['id'],b=b['id'],distanceCM=100*dist(a,b),differentMethod=signature(a)!=signature(b)) for a,b in combinations(chosen,2)]
 report.append(dict(id=gid,layout=rows[0]['seed']['layout'],originalCount=len(rows),eligibleCount=len(pool),selected=ids,status=status,pairs=pairs,sourceIDs=sorted({s['sourceID'] for s in rows}),grades=dict(Counter(dd[s['id']]['grade'] for s in chosen))))
 for s in chosen:selected.append(dict(sample=s,difficulty=dd[s['id']],groupID=gid,selectionReason=reason[s['id']]))
assert all(len(g['selected'])<=3 for g in report)
assert len({x['sample']['id'] for x in selected})==len(selected)
for g in report:
 for p in g['pairs']:assert p['differentMethod'] or p['distanceCM']>=100*D
summary=dict(sourceSamples=293,sourceFormations=39,selectedSamples=len(selected),selectedFormations=sum(bool(g['selected']) for g in report),groupSizes=dict(Counter(len(g['selected']) for g in report)),grades=dict(Counter(x['difficulty']['grade'] for x in selected)),byTiming=dict(Counter(x['sample']['axis'] for x in selected)),byObservedRail=dict(Counter(x['sample']['railOrdinal'] for x in selected)),byPocket=dict(Counter('中袋' if x['sample']['seed']['pocket'] in (4,5) else '角袋' for x in selected)))
protocol=dict(coordinates='world XZ meters; +X screen right, +Z screen down; Y up',formation='exact cue+A initial coordinates; all routes/pockets/timings share max3 quota',eligible='baseline succeeds and cumulative small level passes (敏感 or better); prefer 宽容/常规',nearDuplicate='same pocket, actual pre-K cushion sequence, entry/exit timing and observed rail; B separation less than one ball diameter',diameterMeters=D,third='does not reduce lowest selected grade; new method or >=2D from both first two; pairwise near-duplicate check still applies',selection='exhaustive distinct subsets size1/2; lexicographic number of 宽容, 常规, count, sum medium and large joint passes, method count, B separation; stable ID order tie break; add qualified third',mirrorCheck='all 39 original cue+A pairs under four XZ axis reflections within 1mm; no equivalent pairs found',limits='sample-level selection, not formal human difficulty calibration; historical audited simulation reused without changing parameters')
if CENTER:
 protocol['railDistance']='B center to finite observed cushion segment <=0.10m; not ball-surface gap; all other selection criteria unchanged'
 summary['withinCenterLimit']=sum(m['centerRailDistance']<=.1 for m in measurements.values())
 summary['angleDefinition']=angleAudit['definitions']['layoutAngle']
 summary['selectedAngleBins']=dict(Counter(measurements[x['sample']['id']]['angleBin'] for x in selected))
 summary['selectedFormationAngleBins']=dict(Counter(measurements[g['selected'][0]]['angleBin'] for g in report if g['selected']))
for n,v in [('selected.json',selected),('groups.json',report),('rejections.json',rejections),('selection-summary.json',summary),('selection-protocol.json',protocol)]:
 (OUT/n).write_text(json.dumps(v,ensure_ascii=False,indent=2))
(OUT/'selection-audit.json').write_text(json.dumps(dict(passed=True,sourceSHA256={n:sha(SRC/n) for n in ['samples.json','difficulty.json','results.jsonl','audit.json','geometry.json']},selectedUnmodified=True,uniqueIDs=len(selected),maxPerFormation=3,pairwiseDistinct=True,mirrorEquivalentPairs=0,summary=summary),ensure_ascii=False,indent=2))

# Reuse the exact existing full-trajectory cards and CSS; add formation grouping.
old=(SRC/'index.html').read_text();css=re.search(r'<style>(.*?)</style>',old,re.S).group(1)
oldcards={m.group(1):m.group(0) for m in re.finditer(r'<article class="card" id="([^"]+)".*?</article>',old,re.S)}
byID={x['sample']['id']:x for x in selected};sections=[]
displayGroups=sorted(report,key=lambda g:measurements[g['selected'][0]]['layoutAngle'] if g['selected'] else math.inf) if CENTER else report
for g in displayGroups:
 if not g['selected']:continue
 items=[]
 for id in g['selected']:
  x=byID[id];c=oldcards[id];tier='preferred' if rank[x['difficulty']['grade']]>=2 else 'advanced'
  c=c.replace('class="card"',f'class="card" data-tier="{tier}"')
  if CENTER:
   m=measurements[id];c=c.replace('class="card"',f'class="card" data-angle="{m["angleBin"]}"')
   c=c.replace(f"B 离库 {100*x['sample']['initialGap']:.1f} cm",f"B球心距库 {100*m['centerRailDistance']:.1f} cm · 球形夹角 {m['layoutAngle']:.1f}°")
  c=c.replace('</header>',f'</header><p class="note">{x["selectionReason"]}</p>',1)
  items.append(c)
  if CENTER:render_center(ROOT,OUT,x['sample'],measurements[id],read('geometry.json'))
  else:shutil.copy2(SRC/f'images/{id}.png',OUT/f'images/{id}.png')
 pairtext='；'.join(f'{p["a"]} ↔ {p["b"]}：B相距 {p["distanceCM"]:.1f}cm'+('，打法不同' if p['differentMethod'] else '，同打法不同位置') for p in g['pairs'])
 angleText=f" · 球形夹角 {measurements[g['selected'][0]]['layoutAngle']:.1f}°" if CENTER else ''
 sections.append(f'<section class="formation" id="{g["id"]}"><div class="panel"><h2>{g["id"]} · 同一母球＋A球形{angleText}</h2><p>{g["layout"]} · 原 {g["originalCount"]} 项 → 保留 {len(g["selected"])} 项</p><p>{g["status"]}</p><p class="muted">{pairtext}</p></div>'+''.join(items)+'</section>')
shortages=''.join(f'<tr><td>{g["id"]}</td><td>{g["layout"]}</td><td>{g["originalCount"]}</td><td>{len(g["selected"])}</td><td>{g["status"]}</td></tr>' for g in report if len(g['selected'])<2)
preferred=sum(summary['grades'].get(k,0) for k in ['宽容','常规'])
page='''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>K球 · 每球形精选2–3题</title><link rel="icon" href="data:,"><style>'''+css+'''.formation{border-top:2px solid #52736f;margin-top:42px;padding-top:12px}.formation>.panel{background:#203b3c}.card{margin-left:12px}.jump{display:flex;flex-wrap:wrap;gap:12px}.jump a{padding:6px 10px;background:#203b3c;border-radius:6px}</style></head><body><main><div class="eyebrow">K 球 / 10 cm · ≤45° / 去重精选</div><h1>同一球形，只留有区别的几题</h1>'''+f'''<p class="lead">从 {summary['sourceFormations']} 个原始球形的 293 个样本中，保留 <b>{summary['selectedSamples']} 个</b>，覆盖 <b>{summary['selectedFormations']} 个球形</b>。</p><div class="metrics"><div class="metric"><strong>{preferred}</strong><span>宽容／常规</span></div><div class="metric"><strong>{summary['grades'].get('敏感',0)}</strong><span>敏感 · 进阶候选</span></div><div class="metric"><strong>{summary['groupSizes'].get(2,0)+summary['groupSizes'].get(3,0)}</strong><span>球形保留2–3题</span></div><div class="metric"><strong>{summary['groupSizes'].get(1,0)}</strong><span>球形仅保留1题</span></div></div>'''+'''
<section class="panel"><h2>这次怎么选</h2><p>固定母球和 A，所有路线、袋口、库次及入出库片段合计最多 3 题。优先宽容／常规；敏感档标为进阶候选；极敏感与原失败样本不纳入。</p><p>同袋、同实际库序、同 K 时机和观察库，B 相距不足一个球直径（约 5.7cm）按近似重复处理。第三题需增加不同打法，或与前两题都至少相隔两个球直径，而且不降低本组最低容错档。</p><p class="note">完整图与容错记录沿用已审计样本，未改球位或重算。分级仍是模拟结果；不足2题的原因在页尾单列，不为凑数纳入极敏感题。不同打法依据实际库序、入出库时机、观察库和目标袋，单纯杆法编号不同不算区别。</p><p><a href="http://127.0.0.1:8856/">查看完整293项容错图册 ↗</a></p></section>
<section class="panel" id="browse"><h2>按球形对照</h2><div class="filters"><label for="tier">候选类型</label><select id="tier"><option value="">全部精选</option><option value="preferred">宽容／常规</option><option value="advanced">敏感 · 进阶</option></select><label for="pocket">A目标袋</label><select id="pocket"><option value="">全部袋口</option><option value="middle">中袋</option><option value="corner">角袋</option></select><label for="timing">K时机</label><select id="timing"><option value="">入库前与出库后</option><option value="before">入库前 K</option><option value="after">出库后 K</option></select><label for="rail">观察库</label><select id="rail"><option value="">全部库次</option><option value="1">第1库</option><option value="2">第2库</option><option value="3">第3库</option></select></div><p id="count" aria-live="polite"></p><p class="muted">同组题连续排列，完整轨迹默认展示。筛选仅改变显示，不重新分配每组配额；组头保留本轮完整选择数量。</p><nav class="jump">'''+''.join(f'<a href="#{g["id"]}">{g["id"]}</a>' for g in report if g['selected'])+'''</nav></section>'''+''.join(sections)+'''
<section class="panel"><h2>不足2题的球形</h2><div class="scroll"><table><thead><tr><th>组</th><th>原球形</th><th>原样本</th><th>保留</th><th>原因</th></tr></thead><tbody>'''+shortages+'''</tbody></table></div></section><p class="muted">证据：<a href="selection-summary.json">统计</a> · <a href="groups.json">每组选择与间距</a> · <a href="rejections.json">未选原因</a> · <a href="selection-protocol.json">筛选口径</a> · <a href="selection-audit.json">审计</a></p></main><script>
const ids=['tier','pocket','timing','rail'],inputs=Object.fromEntries(ids.map(id=>[id,document.getElementById(id)])),cards=[...document.querySelectorAll('.card')],groups=[...document.querySelectorAll('.formation')],params=new URLSearchParams(location.search);ids.forEach(id=>inputs[id].value=params.get(id)||'');function render(){cards.forEach(c=>c.hidden=!ids.every(id=>!inputs[id].value||c.dataset[id]===inputs[id].value));groups.forEach(g=>g.hidden=![...g.querySelectorAll('.card')].some(c=>!c.hidden));document.querySelectorAll('.jump a').forEach(a=>a.hidden=document.querySelector(a.getAttribute('href')).hidden);document.getElementById('count').textContent=`显示 ${cards.filter(c=>!c.hidden).length} 个样本 / ${groups.filter(g=>!g.hidden).length} 个球形`;let p=new URLSearchParams();ids.forEach(id=>{if(inputs[id].value)p.set(id,inputs[id].value)});history.replaceState(null,'','?'+p.toString()+location.hash)}ids.forEach(id=>inputs[id].addEventListener('change',render));render();</script></body></html>'''
if CENTER:
 page=page.replace('K球 · 每球形精选2–3题','K球 · 球心10cm与球形夹角').replace('K 球 / 10 cm · ≤45° / 去重精选','K 球 / B球心距库≤10cm / 入出库角≤45°').replace('同一球形，只留有区别的几题','先看球形夹角，再比较K球路线')
 page=page.replace('完整图与容错记录沿用已审计样本，未改球位或重算。','轨迹与容错记录沿用已审计样本，图中标签已改为球心距离；未改球位或重跑物理。')
 oldStats=angleAudit['previousSelectedFormations'];bins=summary['selectedFormationAngleBins']
 anglePanel=f'''<section class="panel"><h2>球心距离与球形夹角</h2><p><b>B球心到观察库边≤10cm</b>，对应球面净距约≤7.14cm。原293点中200点满足球心范围，重新去重后得到本页样本。</p><p>上一版35个球形中，26个球形夹角≥20°，其中17个≥30°，确实偏向较大角度。此次没有擅自收紧进A角度门槛，按小角度优先排列并增加筛选。</p><p><b>球形夹角</b>：母球→A的球心连线，与A→指定袋心的夹角；直球为0°。它不同于碰撞切角，也不同于母球轨迹的入／出库角（相对库边切线，仍≤45°）。</p><p>本页不同球形分布：10–20° {bins.get('10-20',0)} 个，20–30° {bins.get('20-30',0)} 个，30–45° {bins.get('30-45',0)} 个。所有分桶先用未四舍五入数值判断。</p><p class="muted">原始来源角只是球形生成字段；与袋心连线角、假想球几何切角不能互换。完整数值见<a href="angle-audit.json">角度核查</a>，低角度覆盖尚未专门补采。</p></section>'''
 page=page.replace('<section class="panel" id="browse">',anglePanel+'<section class="panel" id="browse">')
 page=page.replace('<label for="tier">','<label for="angle">球形夹角</label><select id="angle"><option value="">全部角度</option><option value="10-20">10–20°</option><option value="20-30">20–30°</option><option value="30-45">30–45°</option></select><label for="tier">',1)
 page=page.replace("const ids=['tier','pocket','timing','rail']","const ids=['tier','pocket','timing','rail','angle']")
 page=page.replace('同组题连续排列，完整轨迹默认展示。','球形按夹角从小到大排列；同组题连续展示，完整轨迹默认展开。')
 (OUT/'measurements.json').write_text(json.dumps(measurements,ensure_ascii=False,indent=2))
(OUT/'index.html').write_text(page)
print(json.dumps(summary,ensure_ascii=False,indent=2))
print('Shortages:',[(g['id'],g['selected'],g['status']) for g in report if len(g['selected'])<2])
