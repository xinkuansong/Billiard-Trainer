"""User-directed diagonal threshold calibration; no acceptance thresholds are set."""
from pathlib import Path
import ast,hashlib,html,json,math,shutil
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'output/defense-reuse-20261104';OUT=ROOT/'output/defense-threshold-ladder-20261104'
OUT.mkdir(exist_ok=True)
rows=json.loads((BASE/'evaluated.json').read_text());geo=json.loads((BASE/'geometry.json').read_text());R=geo['radius']
# Reuse the previously reviewed projection, balls, true jaws and rails without running its selection/export side effects.
renderer=ROOT/'research/defense-reuse-20261104/build_page.py'
ns=dict(math=math,html=html,geo=geo,R=R,names=['左下角袋','左上角袋','右下角袋','右上角袋','左中袋','右中袋'],letters=['E','A','F','B','C','D'])
tree=ast.parse(renderer.read_text());functions=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['xy','pair','line','circle','svg','fmt']]
assert len(functions)==6
exec(compile(ast.Module(body=functions,type_ignores=[]),str(renderer),'exec'),ns)
svg=ns['svg'];names=ns['names'];letters=ns['letters']
def width(q):return q['ownAttack']['best']['cueWidth']
def comfort(q):return max(o.get('comfort',{}).get('total',0) for o in q['ownAttack']['options'])
def signature(q):
 # Display diversity only: avoid nearby/mirror repeats, including role-only variants.
 return min(tuple(round(v,3) for p in [[q['cue'][0]*sx,q['cue'][1]*sz]]+sorted([[x*sx,z*sz] for x,z in q['positions']]) for v in p) for sx,sz in [(1,1),(-1,1),(1,-1),(-1,-1)])
def attack_signature(q):
 return min(tuple(round(v,3) for p in [q['cue'],q['positions'][q['own']]] for v in [p[0]*sx,p[1]*sz]) for sx,sz in [(1,1),(-1,1),(1,-1),(-1,-1)])
def valid(q):
 ps=[q['cue']]+q['positions']
 return all(abs(p[0])<=geo['length']/2-R+1e-6 and abs(p[1])<=geo['width']/2-R+1e-6 and all(math.dist(p,o)>=2*R-1e-6 for o in ps[i+1:]) for i,p in enumerate(ps))
bounds=[(0,.002,0,4),(.002,.008,4,10),(.008,.06,10,20),(.06,.10,20,30),(.10,.16,30,40),(.16,.30,40,55),(.30,.60,55,70),(.60,3,70,100)]
chosen=[];steps=[];used=set();used_attacks=set();kindcounts={k:0 for k in ['one','two_black','two_own','three']}
for i,(wl,wh,cl,ch) in enumerate(bounds):
 pool=[q for q in rows if max(wl,1e-6)<width(q)<=wh and cl<=comfort(q) and (comfort(q)<ch or i==7 and comfort(q)<=ch) and valid(q) and abs(comfort(q)-q['ownAttack']['best']['comfort']['total'])<1e-8]
 stage=[]
 for frac in [.2,.5,.8]:
  candidates=[q for q in pool if signature(q) not in used and attack_signature(q) not in used_attacks]
  def cost(q):
   a=(width(q)-wl)/(wh-wl);b=(comfort(q)-cl)/(ch-cl)
   repetition=sum(p['kind']==q['kind'] for p in stage)
   return (a-frac)**2+(b-frac)**2+1.0*repetition+.045*kindcounts[q['kind']]
  q=dict(min(candidates,key=cost));used.add(signature(q));used_attacks.add(attack_signature(q));stage.append(q);kindcounts[q['kind']]+=1
 stage.sort(key=width)
 for j,q in enumerate(stage):q.update(sampleID=f'T{i+1:02d}-{j+1}',stage=f'T{i+1:02d}',maxPocketComfort=comfort(q));chosen.append(q)
 steps.append(dict(id=f'T{i+1:02d}',widthLowerExclusive=wl,widthUpperInclusive=wh,comfortLowerInclusive=cl,comfortUpper=ch,comfortUpperInclusive=i==7,eligibleSourceRecords=len(pool),samples=[q['sampleID'] for q in stage]))
controls=[]
for sid,idx,label in [('R01',1355,'原03-1 · 你认可适合防守'),('R02',581,'原03-2 · 你认为仍不够难'),('R03',1361,'原03-3 · 你认为仍不够难')]:
 q=dict(next(q for q in rows if q['id']==idx));q.update(sampleID=sid,stage='reference',maxPocketComfort=comfort(q),referenceLabel=label);controls.append(q)
for old,new in [('geometry.json','geometry.json'),('bank-provenance.json','bank-provenance.json')]:shutil.copy2(BASE/old,OUT/new)
allqs=chosen+controls
(OUT/'samples.json').write_text(json.dumps(allqs,ensure_ascii=False,indent=2))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
protocol=dict(status='awaiting_user_calibration',formalThresholdsApproved=False,layout='eight ascending diagonal bands, three examples per band, then three historical references',steps=steps,referenceIDs=[q['id'] for q in controls],sourceEvaluationSHA256=sha(BASE/'evaluated.json'),rendererSHA256=sha(renderer),metrics='Six-pocket max continuous cue-angle full width; max comfort among each pocket representative route. Selected examples have both maxima on the drawn route.',diversity='Avoid repeated or mirrored nearby coordinates rounded to 1mm for display diversity only; no production bank deduplication.',limitations='Diagonal examples cannot independently determine two cutoffs or cover cross-combinations. Not calibrated pot probability or validated safety strokes.')
(OUT/'protocol.json').write_text(json.dumps(protocol,ensure_ascii=False,indent=2))
def f(v):return f'{v:.6f}'.rstrip('0').rstrip('.')
def cf(v):return f'{v:.4f}'.rstrip('0').rstrip('.') if 0<v<.01 else f'{v:.2f}'
roles={'one':'一颗黑八 · 我方打8，对方打8','two_black':'两颗球 · 我方打8，对方打9','two_own':'两颗球 · 我方打1，对方打8','three':'三颗球 · 我方打1，对方打9，另有黑8'}
def card(q):
 b=q['ownAttack']['best'];drawing=svg(q);(OUT/(q['sampleID']+'.svg')).write_text(drawing)
 comparisons=''.join(f'<tr><td>{letters[o["pocket"]]}</td><td>{f(o["cueWidth"])}°</td><td>{cf(o["comfort"]["total"]) if "comfort" in o else "—"}</td></tr>' for o in q['ownAttack']['options'])
 label=q.get('referenceLabel','')
 return f'''<article id="{q['sampleID']}" class="card"><div class="card-head"><strong>{q['sampleID']}</strong><span>{label}</span></div><p class="role">{roles[q['kind']]}</p>
 <div class="metrics"><div><span>母球瞄准容错角</span><b>{f(width(q))}<small>°</small></b></div><div><span>舒适分</span><b>{cf(comfort(q))}</b></div></div>{drawing}<div class="body"><p class="route">图示 {letters[b['pocket']]} {names[b['pocket']]} · 我方打{q['numbers'][q['own']]}号</p>
 <dl><div><dt>切角</dt><dd>{b['cut']:.1f}°</dd></div><div><dt>母球 → 接触位置</dt><dd>{b['cueDistance']:.2f} m</dd></div><div><dt>目标球 → 入袋</dt><dd>{b['potDistance']:.2f} m</dd></div><div><dt>该袋干净进袋容错角</dt><dd>{f(b['objectWidth'])}°</dd></div></dl>
 <details><summary>六袋比较与来源</summary><table><thead><tr><th>袋口</th><th>母球容错角</th><th>代表舒适分</th></tr></thead><tbody>{comparisons}</tbody></table><p>母球容错角取六袋中最大连续角域的全宽。舒适分取六袋代表路线中的最高值。本题两者均对应图示路线。</p><p>来源：{html.escape(q['sourceID'])}</p><p>旧舒适分分项：角度 {b['comfort']['angle']:.2f} · 距离 {b['comfort']['distance']:.2f} · 空间 {b['comfort']['space']:.2f}</p></details></div></article>'''
sections=[]
for s in steps:
 wl,wh,cl,ch=s['widthLowerExclusive'],s['widthUpperInclusive'],s['comfortLowerInclusive'],s['comfortUpper']
 caption=f"容错角 ({f(wl)}, {f(wh)}]°　×　舒适分 [{f(cl)}, {f(ch)}{']' if s['comfortUpperInclusive'] else ')'}"
 sections.append(f'''<section id="stage-{s['id']}"><div class="stage-head"><div><span class="step">{s['id']}</span><h2>{caption}</h2></div><label>这一档<select class="vote" data-stage="{s['id']}" aria-label="{s['id']}这一档是否适合防守"><option value="">未判断</option><option>适合做防守题</option><option>处于边界，有些可以</option><option>进攻已不够难</option></select></label></div><div class="grid">{''.join(card(q) for q in chosen if q['stage']==s['id'])}</div></section>''')
sections.append('<section id="references"><div class="stage-head"><div><span class="step">对照</span><h2>你此前判断过的3个例子</h2><p>这行用于回看，不属于上面的递增阶梯。</p></div></div><div class="grid">'+''.join(map(card,controls))+'</div></section>')
css='''*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:#f3f4ee;color:#20392e;font:15px -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif}.wrap{max-width:1220px;padding:32px 24px;margin:auto}header{max-width:960px}h1{font-size:32px;letter-spacing:-.5px;margin:8px 0 14px}p{line-height:1.75;color:#617264}header p{margin:9px 0}.eyebrow{font-size:12px;letter-spacing:2px;color:#65816c}.notice{background:#e5ebde;padding:14px 18px;border-left:3px solid #6d8961;border-radius:0 8px 8px 0;line-height:1.8}nav{display:flex;gap:10px;flex-wrap:wrap;margin:20px 0}a{color:#35654b}nav a{padding:7px 12px;border:1px solid #cbd6c6;border-radius:7px;text-decoration:none;background:#fffef9}.controls{display:flex;align-items:center;gap:18px;margin:20px 0}.controls label{cursor:pointer}input{accent-color:#3f7254}.scroll{overflow-x:auto;padding-bottom:12px}section{margin-bottom:36px;scroll-margin-top:12px;min-width:900px}.stage-head{display:flex;align-items:center;justify-content:space-between;gap:20px;margin:14px 0}.stage-head>div{display:flex;align-items:center;gap:14px;flex-wrap:wrap}.stage-head h2{font-size:17px;font-weight:600;margin:0}.stage-head p{margin:0}.step{font-size:28px;color:#87977d;font-weight:500}.stage-head label{font-size:13px;white-space:nowrap;color:#5d705f}select{font:inherit;margin-left:8px;padding:10px;border:1px solid #bcccbb;border-radius:7px;background:#fffef9;color:#294535;max-width:200px}.grid{display:grid;grid-template-columns:repeat(3,minmax(280px,1fr));gap:18px}.card{background:#fffef9;border:1px solid #dce1d5;border-radius:12px;overflow:hidden;align-self:start}.card-head{display:flex;align-items:center;justify-content:space-between;padding:17px 18px 0;gap:10px}.card-head strong{font-size:19px}.card-head span{font-size:12px;color:#67795f}.role{font-size:13px;margin:9px 18px 15px}.metrics{display:grid;grid-template-columns:1.4fr 1fr;gap:10px;margin:0 18px;padding:12px 0;border-top:1px solid #e4e8df;border-bottom:1px solid #e4e8df}.metrics span{display:block;color:#62745f;font-size:12px;margin-bottom:5px}.metrics b{font-size:26px;font-variant-numeric:tabular-nums;font-weight:650;color:#aa6630}.metrics small{font-size:15px;margin-left:3px}.card svg{display:block;width:100%;height:auto}.body{padding:0 18px 18px}.route{font-size:13px;margin:0 0 12px}dl{margin:0;font-size:13px}dl div{display:flex;justify-content:space-between;gap:10px;margin:8px 0}dt{color:#6e7b6a}dd{margin:0;font-variant-numeric:tabular-nums}details{border-top:1px solid #e5e8df;margin-top:15px;padding-top:8px;font-size:12px;line-height:1.65}summary{cursor:pointer;padding:5px 0;color:#376c50}details p{overflow-wrap:anywhere}table{border-collapse:collapse;width:100%;font-size:12px}th,td{text-align:left;border-bottom:1px solid #e5e8df;padding:7px 3px}#show-lines:not(:checked)~.scroll .analysis-line{display:none}.feedback{padding:20px;background:#e9eee2;border-radius:10px;margin-top:10px}.feedback h2{font-size:20px;margin:0}.feedback p{font-size:13px}textarea{display:block;width:100%;min-height:130px;border:1px solid #c6d1bd;border-radius:6px;padding:12px;font:14px -apple-system,sans-serif;background:#fffef9;color:#264332;line-height:1.8}footer{font-size:12px;color:#798575;line-height:1.8;padding:25px 0}@media(max-width:700px){.wrap{padding:24px 14px}h1{font-size:26px}}@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}}@media print{.wrap{max-width:none;padding:0}.scroll{overflow:visible}section{min-width:0;break-before:page}.grid{grid-template-columns:repeat(3,1fr)}.card{break-inside:avoid}.stage-head label,.feedback,.controls,nav{display:none}}'''
script="""const votes=[...document.querySelectorAll('.vote')];const feedback=document.getElementById('feedback-text');function updateFeedback(){const lines=votes.filter(v=>v.value).map(v=>`${v.dataset.stage}：${v.value}`);feedback.value=lines.length?'防守阈值图册反馈\\n'+lines.join('\\n'):'尚未选择。也可以直接在聊天里告诉我：从T几开始不合适，或具体哪一题。';}votes.forEach(v=>v.addEventListener('change',updateFeedback));updateFeedback();"""
page='''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>防守阈值标定 · 递增8档</title><style>'''+css+'''</style></head><body><main class="wrap"><header><div class="eyebrow">球迹 · 防守开局阈值标定 / 2026.11.04</div><h1>往下看，哪一档开始不够难？</h1><p>两项一起递增，8档，每档3个不同球形。每张图先看我方当前进攻，再判断是否适合作为防守题的开局。</p><div class="notice"><b>这次只标定范围，不作入库判定。</b>先从T01往下看；遇到“不值得刻意做防守”的一档，就记下档号。若同档3题感觉不同，可以直接告诉我题号。</div><p>区间写在每行标题；卡片展示实际数值。母球瞄准容错角与舒适分都逐档增大。区间不是累计上限，后面的行不会混回前面的难球。</p><p>金色是目标球进袋方向，浅蓝与白虚线是母球瞄准方向。所有线均为进攻评估线。球数不含母球。</p></header><nav aria-label="档位导航">'''+''.join(f'<a href="#stage-{s["id"]}">{s["id"]}</a>' for s in steps)+'''<a href="#references">旧图对照</a><a href="#feedback">反馈汇总</a></nav><input id="show-lines" type="checkbox" checked><label for="show-lines">显示进攻评估线</label><div class="scroll">'''+''.join(sections)+'''</div><div class="feedback" id="feedback"><h2>你的判断</h2><p>可在每档右侧选择，再复制下方文字发给我。选择只在当前页面保留，刷新后需重选；不会自动提交。</p><label for="feedback-text">反馈汇总</label><textarea id="feedback-text" readonly></textarea></div><footer>母球容错角为六袋中最大连续角域的全宽（不是±值）；舒适分为六袋已有代表路线中的最高值，不是命中率。这批专门挑选两项最大值都对应图示路线的球形，方便直接比较。原库球位不动，XZ米制，竖图上+X、右+Z，台面2.54×1.27m。<br>这是两个指标一起变化的阶梯，不能据此分别证明两个独立阈值；选出边界后再细化附近范围。球形未验证具体防守打法、力度容错或旋转偏移，不代表全库分布。</footer></main><script>'''+script+'''</script></body></html>'''
(OUT/'review.html').write_text(page)
print(json.dumps({'stages':len(steps),'examples':len(chosen),'references':len(controls),'kinds':kindcounts,'steps':[(s['id'],s['samples']) for s in steps]},ensure_ascii=False,indent=2))
