"""Offline audit and five-column review of actual full-engine reference trajectories."""
from pathlib import Path
import ast,html,json,math,hashlib,sys,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'output/defense-fast-pilot-20261104/r2'
read=lambda p:json.loads(p.read_text())
summary=read(OUT/'summary.json');samples=read(OUT/'samples.json')
geo=read(ROOT/'output/defense-pocket-cleanup-20261104/geometry.json');R=geo['radius']
renderer=ROOT/'research/defense-reuse-20261104/build_page.py'
ns=dict(math=math,html=html,geo=geo,R=R,names=['左下角袋','左上角袋','右下角袋','右上角袋','左中袋','右中袋'],letters=['E','A','F','B','C','D'])
nodes=[n for n in ast.parse(renderer.read_text()).body if isinstance(n,ast.FunctionDef) and n.name in ['xy','pair','line','circle','svg']]
exec(compile(ast.Module(body=nodes,type_ignores=[]),str(renderer),'exec'),ns)
xy,pair,circle,line=map(ns.get,['xy','pair','circle','line'])

def ball(k,p,initial=False):
 fill='#fffdf5' if k=='cueBall' else '#151819' if k=='_8' else '#e6ad29'
 # Cue key is read from each trajectory's own keys; any non-number is cue.
 if not k.startswith('_'):fill='#fffdf5'
 if initial:return circle(p,R,'none','#f4f2df',.7,'stroke-dasharray="2 2" opacity=".65"')
 s=circle(p,R,fill,'#f4f2df',.7)
 if k.startswith('_') and k[1:].isdigit():
  x,y=xy(p);s+=circle(p,R*.53,'#fffdf5')+f'<text x="{x:.2f}" y="{y+2.5:.2f}" text-anchor="middle" font-size="7.5" fill="#182820">{k[1:]}</text>'
 return s

def drawing(q,r):
 source=ns['svg'](q)
 s=source.split('<g class="analysis-line">')[0]
 s=s.replace('为当前母球瞄准窗口最大的进攻袋口','；防守试验真实轨迹')
 if r is None:return source
 initial={f'_{n}':p for n,p in zip(q['numbers'],q['positions'])}
 cue=next(k for k in r['finalPositions'] if k not in initial)
 initial[cue]=q['cue']
 for k,path in r['paths'].items():
  color='#f8fcff' if k==cue else '#d0c79f' if k=='_8' else '#ffcb61'
  if len(path)>1:s+='<polyline points="'+' '.join(pair(p) for p in path)+'" fill="none" stroke="'+color+'" stroke-width="1" opacity=".8"/>'
 for k,p in initial.items():s+=ball(k,p,True)
 for k,p in r['finalPositions'].items():
  if k not in r['pocketed']:s+=ball(k,p)
 a=r['attack']['best']
 if a['cueWidth']>0:
  s+=line(r['finalPositions'][r['opponentKey']],a['aim'],'#ff9281',1,'3 3')
  s+=line(r['finalPositions'][cue],a['ghost'],'#ff9281',1,'3 3')
 s+='</svg>';ET.fromstring(s);return s

def description(r):
 m=r['metrics'];status='完整直击遮挡（保守证明）' if m['fullBlock'] else '未证明完整遮挡'
 if r['cornerWitnesses']:status+=' · 选袋疑点，隔离待复核'
 elif not r['cueWidth'] and not m['fullBlock']:status+=' · 无干净直进窗口，暂不评级'
 return f'''<p class="status">{status}</p><dl><dt>对方母球容错角</dt><dd>{r['cueWidth']:.6f}°</dd><dt>对方最高舒适分</dt><dd>{r['comfort']:.2f}</dd><dt>母球至对方球</dt><dd>{m['distance']:.2f} m</dd><dt>母球距库（球面）</dt><dd>{m['cueRailGap']*100:.1f} cm</dd><dt>对方球距库（球面）</dt><dd>{m['enemyRailGap']*100:.1f} cm</dd></dl><p>杆速 {r['shot']['speed']:.3f} m/s · 高低杆 {r['shot']['spinY']:+.2f} · 无侧塞</p>'''

counts={};cards={};audits=[];primary=[];quarantined=0;blocked=0;layoutNoRefs=0
for q in samples:
 d=read(OUT/'questions'/f"{q['sampleID']}.json");assert d['input']==q
 stats=d['summary'];ledger=d['ledger'];refs=d['references']
 assert len(ledger)==stats['candidateCount']
 assert sum(x['baselineReason']=='legal' for x in ledger)==stats['legalBaseline']
 assert sum(x['baselineReason']=='legal' and not x['hybridLegal'] for x in ledger)==stats['missedLegal']
 assert len({json.dumps(x['shot'],sort_keys=True) for x in ledger})==len(ledger)
 for r in refs:
  matched=next(x for x in ledger if x['shot']==r['shot'])
  assert matched['baselineReason']=='legal'
  for key,value in r['metrics'].items():assert abs(value-matched['metrics'][key])<1e-6,(q['sampleID'],key)
  own=f"_{q['numbers'][q['own']]}";assert own not in r['pocketed'] and '_8' not in r['pocketed']
  events=r['events'];first=next(e for e in events if e['kind']=='ballBall')
  assert own in first['balls']
  assert any(e['time']>first['time'] and e['kind'] in ['cushion','pocket'] for e in events)
  quarantined+=bool(r['cornerWitnesses'])
 ordered=sorted(refs,key=lambda r:(bool(r['cornerWitnesses']),-r['metrics']['fullBlock'],r['cueWidth']==0 and not r['metrics']['fullBlock'],r['cueWidth'],r['comfort']))
 r=ordered[0] if ordered else None
 blocked+=bool(r and r['metrics']['fullBlock']);layoutNoRefs+=r is None
 svg=drawing(q,r);(OUT/f"{q['sampleID']}.svg").write_text(svg)
 primary.append(dict(sampleID=q['sampleID'],reference=r))
 details=''.join('<details><summary>另一个候选 '+str(i+1)+'</summary>'+drawing(q,x)+description(x)+'</details>' for i,x in enumerate(ordered[1:]))
 body=description(r) if r else '<p>本轮搜索未找到合法纯防守候选；不代表无解。</p>'
 card=f'''<article class="card"><h3>{q['sampleID']}</h3><p>我方 {q['numbers'][q['own']]} 号 · 对方 {q['numbers'][q['enemy']]} 号</p>{svg}{body}<p class="small">合法候选 {stats['legalBaseline']}；快速筛选漏掉 {stats['missedLegal']}。图示为待评审候选，未做扰动稳定性验收。</p>{details}</article>'''
 cards.setdefault(q['kind'],[]).append(card);counts[q['kind']]=counts.get(q['kind'],0)+1
 assert stats['baselineSeconds']>=0 and stats['hybridSeconds']>=0
 if stats['candidateCount']:
  assert stats['baselineSeconds']>0 and stats['hybridSeconds']>0
 audits.append(dict(sampleID=q['sampleID'],references=len(refs),missedLegal=stats['missedLegal'],shortlistsEqual=stats['shortlistsEqual']))
assert counts==dict(one=20,two_black=20,two_own=20,three=20)
assert sum(x['missedLegal'] for x in audits)==summary['missedLegal']
titles=dict(one='一颗黑八',two_black='两颗球 · 我方打黑八',two_own='两颗球 · 对方打黑八',three='三颗球 · 双方各剩一颗')
sections=''.join(f'<section><h2>{titles[k]}</h2><div class="grid">'+''.join(v)+'</div></section>' for k,v in cards.items())
page=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>防守求解加速试验 · 80题</title><style>body{{margin:0;background:#f3f4ee;color:#20392e;font:15px -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif}}main{{padding:28px;max-width:1920px;margin:auto}}h1{{font-size:32px}}p{{line-height:1.7}}.scroll{{overflow-x:auto}}.grid{{display:grid;grid-template-columns:repeat(5,minmax(265px,1fr));gap:16px;min-width:1381px}}.card{{background:#fffef9;border:1px solid #d9e0d1;border-radius:16px;padding:14px;min-width:0}}svg{{width:100%;height:auto}}h3{{margin:0}}.card p,dl{{font-size:12px}}dl{{display:grid;grid-template-columns:1fr auto;gap:7px}}dd{{margin:0;font-variant-numeric:tabular-nums}}.status{{color:#9b5c2b}}.small{{color:#657765}}details{{border-top:1px solid #d9e0d1;margin-top:10px}}summary{{padding:12px 0;cursor:pointer;font-size:12px}}section{{margin:28px 0}}.notice{{background:#e5eadf;padding:16px;border-radius:12px}}</style><main><h1>防守求解 · 第一轮加速试验</h1><p>同一批80题、同一批出杆参数：完整模拟与快速预筛＋完整确认对照。球位和球权保持原值。</p><div class="notice">完整模拟累计 {summary['baselineSeconds']:.1f} 秒；快速路径累计 {summary['hybridSeconds']:.1f} 秒；候选计算比值 {summary['kernelSpeedup']:.2f}×。共 {summary['candidates']:,} 个实际出杆候选，快速预筛漏掉 {summary['missedLegal']} 个基线合法候选。以上为单轮交替计时，未包含下方候选的进攻评分及绘图，不代表全流程加速倍数。</div><p>空心球：初始位置；实心球：停稳位置。白线：母球真实轨迹；金／灰线：其他球真实轨迹；红色虚线：对方下一杆最大容错路线。每卡默认展示一个完整物理复核的候选，可展开其他候选；“合法”不等于防守效果已达标。</p><p>本轮检验快速预筛与力度局部细化。尚未覆盖侧塞、系统化踢球/传球搜索、完整区域反解及扰动稳定性，未接入App。</p><div class="scroll">{sections}</div></main></html>'''
(OUT/'review.html').write_text(page)
(OUT/'primary.json').write_text(json.dumps(primary,ensure_ascii=False))
(OUT/'audit.json').write_text(json.dumps(dict(passed=True,layouts=80,counts=counts,quarantinedReferenceCount=quarantined,primaryFullBlock=blocked,noReferenceLayouts=layoutNoRefs,questions=audits,htmlSHA256=hashlib.sha256(page.encode()).hexdigest(),scope='offline records and SVG, not browser or physical-table validation'),indent=2))
print(json.dumps(dict(layouts=80,primaryFullBlock=blocked,quarantinedReferenceCount=quarantined,noReferenceLayouts=layoutNoRefs)))
