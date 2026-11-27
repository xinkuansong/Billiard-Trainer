"""Self-contained five-column atlas and independent record audit, no browser claims."""
from pathlib import Path
import ast, gzip, hashlib, html, json, math, sys, struct
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'output/defense-constrained-20-20261104/r1'
read=lambda p:json.loads(p.read_text())
samples=read(OUT/'samples.json'); summary=read(OUT/'summary.json')
geo=read(ROOT/'output/defense-pocket-cleanup-20261104/geometry.json');R=geo['radius']
ns=dict(math=math,html=html,geo=geo,R=R,names=['左下角袋','左上角袋','右下角袋','右上角袋','左中袋','右中袋'],letters=['E','A','F','B','C','D'])
source=ROOT/'research/defense-reuse-20261104/build_page.py'
nodes=[n for n in ast.parse(source.read_text()).body if isinstance(n,ast.FunctionDef) and n.name in ['xy','pair','line','circle','svg']]
exec(compile(ast.Module(body=nodes,type_ignores=[]),str(source),'exec'),ns)
xy,pair,line,circle=[ns[k] for k in ['xy','pair','line','circle']]
source=ROOT/'research/defense-fast-shortlist-20261104/report.py'
nodes=[n for n in ast.parse(source.read_text()).body if isinstance(n,ast.FunctionDef) and n.name in ['ball','drawing']]
exec(compile(ast.Module(body=nodes,type_ignores=[]),str(source),'exec'),globals())
raw_drawing=drawing
def drawing(q,r):
 s=raw_drawing(q,r)
 start=s.index('aria-label="')+len('aria-label="');end=s.index('"',start)
 label=q['sampleID']+('，初始球位' if r is None else '，防守实际模拟轨迹及停稳球位')
 return s[:start]+html.escape(label,quote=True)+s[end:]
titles=dict(one='一颗黑八 · 双方打黑八',two_black='两颗球 · 我方打黑八',two_own='两颗球 · 对方打黑八',three='三颗球 · 双方各剩一颗加黑八')
labels={'block':'借球完整遮挡','distance':'拉长台','cue-rail':'母球靠库','target-rail':'目标球靠库','angle':'限制进袋角度','remove-threat':'踢离袋口威胁','pot-opponent':'合法传掉对方球'}
def passes(r):return sum(p.get('qualifies',False) for p in r['perturbations'])
def description(r):
 m=r['metrics'];sh=r['shot'];tag=' / '.join(labels[t] for t in r['tactics'])
 score_label='<p class="effect">防守效果：<strong>100分 · 完整直击遮挡</strong></p>' if m['fullBlock'] else '<p class="effect">防守效果：两个进攻指标均过门槛；总分映射待定</p>'
 if passes(r)<=1:score_label+='<p class="empty">参数敏感：四项小扰动仅'+str(passes(r))+'/4仍合格，先作讨论样例。</p>'
 if 'execution' in r:
  ex=r['execution'];score_label+=f'<p>执行复杂度：合计{ex["mainCushionCount"]}次主库；全桌球总行程{ex["totalTravelMeters"]:.2f} m。</p>'
 if 'firstContact' in r:
  fc=r['firstContact'];score_label+=f'<p>首碰几何切角：{fc["cutDegrees"]:.1f}°；投影击球厚度：{100*fc["projectedThicknessFraction"]:.1f}%。</p>'
 return f'''<p class="tag">防守思路：{tag}</p>{score_label}<div class="metrics"><span>对方容错角<b>{r['cueWidth']:.6f}°</b></span><span>对方舒适分<b>{r['comfort']:.2f}</b></span></div><dl><dt>直击完整遮挡</dt><dd>{'是' if m['fullBlock'] else '否'}</dd><dt>母球至对方球</dt><dd>{m['distance']:.2f} m</dd><dt>母球球面距库</dt><dd>{100*m['cueRailGap']:.1f} cm</dd><dt>对方球面距库</dt><dd>{100*m['enemyRailGap']:.1f} cm</dd><dt>杆速</dt><dd>{sh['speed']:.3f} m/s</dd><dt>高低杆</dt><dd>{sh['spinY']:+.2f}（无侧塞）</dd></dl><p class="probe">选解探针：{passes(r)}/4 个仍过预览门槛</p><p class="small">扰动：方向±0.1°、杆速±5%，分别测试；这些探针参与选解，尚非独立稳定性验收或成功率。</p>'''
def qualified(r):return not r['cornerWitnesses'] and (r['metrics']['fullBlock'] or 1e-6<r['cueWidth']<=.008 and r['comfort']<10)

f32=lambda x:struct.unpack('f',struct.pack('f',x))[0]
def contact_check(q,shot,stored=None):
 c=list(map(f32,q['cue']));t=list(map(f32,q['positions'][q['own']]))
 u=shot.get('direction',[f32(math.cos(shot['angle'])),f32(math.sin(shot['angle']))]);n=math.hypot(*u);u=[v/n for v in u]
 dx,dz=t[0]-c[0],t[1]-c[1];assert dx*u[0]+dz*u[1]>0
 ratio=abs(dx*u[1]-dz*u[0])/(2*f32(R));assert ratio<1
 cut=math.degrees(math.asin(ratio));assert cut<=60
 if stored:
  assert abs(cut-stored['cutDegrees'])<1e-8
  assert abs(1-ratio-stored['projectedThicknessFraction'])<1e-10

old=read(ROOT/'output/defense-tactics-20-20261104/r5-thickness/summary.json')
old_ids={r['sampleID'] for r in old['questions'] if r['referenceCount']}
new_ids=set();eligible_total=0;route_rejected=0;prior_replayed=0;all_probe_count=0

counts={k:0 for k in titles};coverage={k:{t:0 for t in labels} for k in titles};cards={k:[] for k in titles}
primary=[];allrefs=0;withrefs=0;probes=0;stable=0;rayrefs=0;totalCandidates=0
for q in samples:
 d=read(OUT/'questions'/f"{q['sampleID']}.json");assert d['input']==q
 st=d['summary'];refs=d['references'];ledger=d['ledger'];counts[q['kind']]+=1
 assert len(ledger)==st['candidateCount'];assert sum(x['reason']=='legal' for x in ledger)==st['legalCount'];totalCandidates+=len(ledger)
 assert st['attemptedParameters']==len(ledger)+st['accessRejected']+st['thicknessRejected']
 eligible=[x for x in ledger if x['reason']=='legal' and x['routeConstraint']=='pass']
 assert len(eligible)==st['eligibleCount']
 assert st['routeRejected']==st['legalCount']-len(eligible)
 assert sum(qualified(x['assessment']) for x in eligible)==st['qualifiedCount']
 for x in ledger:
  contact_check(q,x['shot'],x['firstContact'])
  assert ('assessment' in x)==(x['reason']=='legal' and x['routeConstraint']=='pass')
 for x in d['probeLedger']:
  for probe in x['probes']:
   all_probe_count+=1
   if probe.get('status')=='legal':
    shot=dict(x['shot']);shot.pop('direction',None);shot['angle']+=math.radians(probe['angleDeltaDegrees'])
    contact_check(q,shot)
    assert probe['qualifies']==qualified(probe['assessment'])
 eligible_total+=len(eligible);route_rejected+=st['routeRejected']
 prior_replayed+=sum(x['stage']=='prior-reference-replay' for x in ledger)
 if refs:new_ids.add(q['sampleID'])
 own=f"_{q['numbers'][q['own']]}"
 for r in refs:
  assert qualified(r)
  match=next(x for x in ledger if x['shot']==r['shot']);assert match['reason']=='legal'
  assert abs(match['assessment']['cueWidth']-r['cueWidth'])<1e-8
  assert own not in r['pocketed'] and '_8' not in r['pocketed']
  positions=r['finalPositions'];cue=next(k for k in positions if not k.startswith('_'));assert cue not in r['pocketed']
  first=next(e for e in r['events'] if e['kind']=='ballBall');assert set(first['balls'])=={own,cue}
  contact_check(q,r['shot'],r['firstContact'])
  banks={}
  for e in r['events']:
   if e['kind']=='cushion':
    assert e['time']>=first['time']
    if e.get('index') in range(6):
     key=e['ball'];banks[key]=banks.get(key,0)+1
  assert all(n<=1 for n in banks.values()) and sum(banks.values())<=2
  assert banks==r['execution']['mainCushionsByBall']
  assert sum(banks.values())==r['execution']['mainCushionCount']
  assert any(e['time']>first['time'] and e['kind'] in ['cushion','pocket'] for e in r['events'])
  for i,(k,p) in enumerate(positions.items()):
   if k in r['pocketed']:continue
   for kk,pp in list(positions.items())[i+1:]:
    if kk not in r['pocketed']:assert math.dist(p,pp)>=2*R-1e-5
  if r['metrics']['fullBlock']:
   c=positions[cue];target=positions[r['opponentKey']];bs=[v for k,v in positions.items() if k not in [cue,r['opponentKey']] and k not in r['pocketed']]
   delta=[target[i]-c[i] for i in range(2)];dist=math.hypot(*delta);theta=math.atan2(delta[1],delta[0]);half=math.asin(2*R/dist)
   def entry(p,u):
    v=[p[i]-c[i] for i in range(2)];dot=sum(v[i]*u[i] for i in range(2));disc=(2*R)**2-(sum(z*z for z in v)-dot*dot)
    return dot-math.sqrt(max(0,disc)) if disc>=-1e-12 and dot>0 else math.inf
   for j in range(1025):
    a=theta-half+2*half*j/1024;u=[math.cos(a),math.sin(a)]
    assert min(entry(p,u) for p in bs)<entry(target,u)
   rayrefs+=1
  probes+=len(r['perturbations']);stable+=passes(r)==4
  s=drawing(q,r);ET.fromstring(s)
 allrefs+=len(refs);withrefs+=bool(refs)
 for row in st['coverage']:
  coverage[q['kind']][row['tactic']]+=row['status']=='found'
 ordered=sorted(refs,key=lambda r:(-passes(r),-r['metrics']['fullBlock'],r.get('execution',{}).get('totalTravelMeters',0),sum(e['kind']=='cushion' for e in r['events']),r['cueWidth']))
 r=ordered[0] if ordered else None
 svg=drawing(q,r);ET.fromstring(svg);(OUT/f"{q['sampleID']}.svg").write_text(svg)
 primary.append(dict(sampleID=q['sampleID'],reference=r))
 body=description(r) if r else '<p class="empty">本轮未找到达到预览门槛的参考解。</p><p class="small">这里只显示原始球形，不代表无解，也不换题补位。</p>'
 if not refs and st['candidateCount']==0:body='<p class="empty">当前平杆可达条件下，没有可测试的候选出杆。</p><p class="small">这里只显示原始球形；并未证明这道题无解。</p>'
 elif not refs and (d.get('referenceSelection') or d.get('thicknessSelection')):body='<p class="empty">已有参考方案未通过本轮可执行性筛选。</p><p class="small">这里只显示初始球位；尚未重新搜索替代解，不代表无解。</p>'
 alternatives=''.join(f'<details><summary>{" / ".join(labels[t] for t in x["tactics"])}</summary>{drawing(q,x)}{description(x)}</details>' for x in ordered[1:])
 missing='、'.join(labels[x['tactic']] for x in st['coverage'] if x['status']=='not-found')
 card=f'''<article><h3>{q['sampleID']}</h3><p class="roles">我方{q['numbers'][q['own']]}号 · 对方{q['numbers'][q['enemy']]}号</p>{svg}{body}{alternatives}<details><summary>查看初始球位</summary>{drawing(q,None)}</details><details><summary>本题搜索情况</summary><p>模拟 {st['candidateCount']} 杆；合法 {st['legalCount']} 杆；合法且符合执行约束 {st['eligibleCount']} 杆；过预览门槛 {st['qualifiedCount']} 杆。</p><p>未找到：{missing or '无'}</p><p>平杆可达检查排除 {st['accessRejected']} 组参数。有限搜索不证明无解。</p></details></article>'''
 cards[q['kind']].append(card)
assert counts=={k:5 for k in titles}
# Every drawn layout must belong to the selected 5698 pool, with unmodified fields.
for kind in titles:
 with gzip.open(ROOT/'output/defense-selected-5698-20261104'/f'{kind}.jsonl.gz','rt') as f:pool={x['formationID']:x for x in map(json.loads,f)}
 for q in samples:
  if q['kind']==kind:assert {k:v for k,v in q.items() if k!='sampleID'}==pool[q['formationID']]
sections=''.join(f'<section><h2>{titles[k]}</h2><div class="grid">'+''.join(cards[k])+'</div></section>' for k in titles)
table='<table><thead><tr><th>类别</th>'+''.join(f'<th>{v}</th>' for v in labels.values())+'</tr></thead><tbody>'+''.join('<tr><td>'+titles[k]+'</td>'+''.join('<td>'+str(coverage[k][t])+'</td>' for t in labels)+'</tr>' for k in titles)+'</tbody></table>'
page=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>防守参考解 · 四类20题</title><style>body{{margin:0;background:#f3f4ee;color:#20392e;font:15px -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif}}main{{max-width:1920px;margin:auto;padding:28px}}h1{{font-size:32px}}p{{line-height:1.7}}.scroll{{overflow:auto}}.grid{{display:grid;grid-template-columns:repeat(5,minmax(265px,1fr));gap:16px;min-width:1381px}}article{{background:#fffef9;border:1px solid #d9e0d1;border-radius:16px;padding:14px;min-width:0}}svg{{width:100%;height:auto}}h3{{margin:0}}article p,dl{{font-size:12px}}.roles,.small{{color:#657765}}.metrics{{display:flex;justify-content:space-between;gap:10px}}.metrics span{{font-size:12px}}b{{display:block;font-size:25px;margin-top:6px;color:#a56530;font-variant-numeric:tabular-nums}}dl{{display:grid;grid-template-columns:1fr auto;gap:7px}}dd{{margin:0;font-variant-numeric:tabular-nums}}.tag{{color:#25694c;font-weight:600;min-height:42px}}details{{border-top:1px solid #d9e0d1;margin-top:12px}}summary{{padding:12px 0;cursor:pointer;font-size:12px}}section{{margin:30px 0}}.notice{{background:#e5eadf;padding:16px;border-radius:12px}}.probe,.empty{{color:#965c2f}}table{{border-collapse:collapse;font-size:13px}}td,th{{padding:10px;text-align:left;border-bottom:1px solid #cbd5c4;white-space:nowrap}}</style><main><h1>防守参考解 · 每类5题</h1><p>从5,698道候选中固定随机抽取20个球形，球位与球号保持不变。每列是一道题；同题的其他防守方案可展开查看。</p><div class="notice">本轮 {withrefs}/20 道题找到达到预览门槛的方案，共保留 {allrefs} 个不同出杆参考。合计完整模拟 {totalCandidates:,} 个搜索候选。各思路先比较多个候选的探针表现；主图优先选择探针表现较好、碰库较少的方案；不是唯一答案或最优解证明。</div><p>空心球为起点，实心球为终点；白线为母球轨迹，金／灰线为其他球轨迹，红色虚线为对方下一杆最大容错路线。无参考解的卡片只显示初始球形。</p><p>本轮预览筛选：完整直击遮挡，或对方最大母球容错角≤0.008°且最高代表舒适分&lt;10；选袋存疑和未证明遮挡的零窗口方案不作为参考。这是保守样例门槛，尚未确定正式防守评分。</p><p>完整直击遮挡按本次约定记100分，仅表示不能直接碰到目标球，不表示不能解球；非遮挡方案暂并列显示两个进攻指标，尚未映射总分。长台、靠库和进袋角度仅作思路标签，不独立加分。</p><p>拉长台标签：球心距离≥1.27 m；靠库标签：球面距有限主库段≤一个球半径（约2.86 cm），不等于严格贴库。标签还必须同时通过上述防守效果筛选，不能只凭距离判断难度。</p><div class="scroll">{table}{sections}</div><p class="small">表中为找到该思路的题数，同题可计入多项。搜索范围为有限直击厚薄、力度和高低杆网格及局部细化，无侧塞、无系统化先库解球；未找到不等于无解。所有参考均由完整物理重放核对，少量方向/力度探针仅供比较。离线图册尚未做浏览器交互、App或实桌验证。</p></main></html>'''
if (OUT/'reference-policy.json').exists():
 policy=read(OUT/'reference-policy.json')
 source_count=policy.get('sourceReferenceCount',52)
 notice=f'<div class="notice"><strong>本轮修订：先筛可执行性，再看防守效果。</strong><p>每颗球最多1次主库、全杆合计最多2次主库；这只是当前图册的保守筛选范围，不是所有防守的永久上限。球的行程另行展示，同等条件优先较短方案。完整遮挡仍是效果100分，但不自动成为适合练习的参考解。</p><p>从旧版52个参考中移出{len(policy["removed"])}个复杂方案；保留同一批20个球形，没有重跑物理或重新搜索替代解。完整旧结果与删除依据保留。此筛选不等于已完成实桌难度或独立稳定性验收。</p></div>'
 page=page.replace('<div class="scroll">',notice+'<div class="scroll">',1).replace(f'本轮 {withrefs}/20 道题找到达到预览门槛的方案',f'本轮 {withrefs}/20 道题保留简单路线参考')
 if 'maximumFirstContactCutDegrees' in policy:
  page=page.replace('从旧版52个参考中移出',f'从上一版{source_count}个简单路线参考中移出').replace(f'{len(policy["removed"])}个复杂方案',f'{len(policy["removed"])}个过薄方案')
  page=page.replace('每颗球最多1次主库、全杆合计最多2次主库；','首碰几何切角≤60°，投影击球厚度至少约13.4%；每颗球最多1次主库、全杆合计最多2次主库；')
  page=page.replace('球的行程另行展示，','投影厚度指沿入射方向两球投影重叠宽度占球直径的比例，不是球体交叠面积，也不是命中概率。球的行程另行展示，')
assert old_ids<=new_ids,'Previously covered layout lost all references'
assert prior_replayed==19
filled=sorted(new_ids-old_ids)
notice=f'<div class="notice"><strong>约束已直接加入求解，20题重新搜索。</strong><p>首碰几何切角≤60°（投影厚度至少约13.4%）；每颗球最多1次主库，全杆合计最多2次主库。搜索、局部细化及选解探针都执行同样条件。相近效果下优先选择短路线。主库不含袋角jaw碰撞；投影厚度不是命中概率。</p><p>重新模拟上一版19个参考作为搜索起点，并扩展厚薄、力度和局部参数。原先10题有参考，本轮{withrefs}题有参考，新补到{len(filled)}题：{html.escape("、".join(filled)) or "无"}。全部20个球形不换题、不挪球。</p><p>搜索候选中有{eligible_total:,}个合法且符合执行约束，逐个评估对方六袋进攻；另有{route_rejected:,}个合法但路线过于复杂的候选已排除。完整遮挡的效果仍为100分，但参考方案还要满足执行约束。</p></div>'
page=page.replace('<div class="scroll">',notice+'<div class="scroll">',1)
page=page.replace('主图优先选择探针表现较好、碰库较少的方案','主图优先探针表现，同等条件优先完整遮挡及较短路线')
page=page.replace('本轮未找到达到预览门槛的参考解。','本轮未找到同时满足执行约束和防守效果门槛的参考解。')
(OUT/'review.html').write_text(page)
(OUT/'primary.json').write_text(json.dumps(primary,ensure_ascii=False))
audit=dict(passed=True,counts=counts,layoutsWithReferences=withrefs,references=allrefs,coverage=coverage,candidates=totalCandidates,perturbationProbes=probes,referencesPassingAllFour=stable,blockReferencesRayChecked=rayrefs,htmlSHA256=hashlib.sha256(page.encode()).hexdigest(),scope='Input subset equality; full replay records; legal events; exact-score consistency; independent 1025-ray corroboration of each full block; XML validation. Not browser or device UI acceptance.')
(OUT/'audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2));print(json.dumps(audit,ensure_ascii=False,indent=2))
constraint_audit=dict(passed=True,maximumFirstContactCutDegrees=60,maxMainCushionsPerBall=1,maxMainCushionsTotal=2,eligibleCandidates=eligible_total,legalButComplexRejected=route_rejected,priorReferencesReplayed=prior_replayed,previousCoveredLayouts=sorted(old_ids),newlyCoveredLayouts=filled,currentCoveredLayouts=sorted(new_ids),allSelectionProbes=all_probe_count,scope='Independent Float32 ray cut calculation on all simulated candidates and legal probes; final reference event-level cushion counts; eligibility and ledger accounting. Probe route enforcement is in the solver; no independent probe event replay audit.')
(OUT/'constraint-audit.json').write_text(json.dumps(constraint_audit,ensure_ascii=False,indent=2));print(json.dumps(constraint_audit,ensure_ascii=False,indent=2))
