"""Expand the user-accepted T02 band, keeping its three reference formations."""
from pathlib import Path
from collections import Counter
import ast,hashlib,html,json,math,re,shutil
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/defense-t02-expand-20261104';LADDER=ROOT/'output/defense-threshold-ladder-20261104'
read=lambda p:json.loads(p.read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
rows=read(OUT/'evaluated.json');geom=read(OUT/'geometry.json');controls=read(OUT/'controls.json');geo=geom;R=geo['radius'];summary=read(OUT/'summary.json')
assert summary['searchEdgeHits']==0 and summary['windowCoarseFineMax']<.001 and summary['mappingCoarseFineMax']<1e-7
lookup={q['id']:q for q in rows};maxdiff=0;maxscore=0
for q in controls:
 n=lookup[q['id']]
 for who in ['ownAttack','enemyAttack']:
  for a,b in zip(q[who]['options'],n[who]['options']):
   maxdiff=max(maxdiff,abs(a['cueWidth']-b['cueWidth']));maxscore=max(maxscore,abs(a.get('comfort',{}).get('total',0)-b.get('comfort',{}).get('total',0)))
assert maxdiff<1e-10 and maxscore<1e-8
(OUT/'controls-audit.json').write_text(json.dumps(dict(passed=True,cases=len(controls),maxWidthDifference=maxdiff,maxComfortDifference=maxscore),indent=2))
# Load only pure rendering/card helpers, preserving the prior table presentation.
renderer=ROOT/'research/defense-reuse-20261104/build_page.py';builder=ROOT/'research/defense-threshold-ladder-20261104/build.py'
ns=dict(math=math,html=html,geo=geo,R=R,OUT=OUT,names=['左下角袋','左上角袋','右下角袋','右上角袋','左中袋','右中袋'],letters=['E','A','F','B','C','D'])
for p,names in [(renderer,['xy','pair','line','circle','svg']),(builder,['width','comfort','signature','attack_signature','valid','f','cf','card'])]:
 tree=ast.parse(p.read_text());nodes=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in names];assert len(nodes)==len(names)
 exec(compile(ast.Module(body=nodes,type_ignores=[]),str(p),'exec'),ns)
ns['roles']={'one':'一颗黑八 · 我方打8，对方打8','two_black':'两颗球 · 我方打8，对方打9','two_own':'两颗球 · 我方打1，对方打8','three':'三颗球 · 我方打1，对方打9，另有黑8'}
width,comfort,signature,attack_signature,valid,card,f=[ns[k] for k in ['width','comfort','signature','attack_signature','valid','card','f']]
old=[dict(lookup[q['id']]) for q in controls if q['stage']=='T02']
assert len(old)==3
for q in old:q.update(stage='reference',maxPocketComfort=comfort(q),referenceLabel='原T02对照')
used={signature(q) for q in old};attacks={attack_signature(q) for q in old}
pool=[q for q in rows if not q.get('regressionControl') and valid(q) and .002<width(q)<=.008 and 4<=comfort(q)<10 and abs(comfort(q)-q['ownAttack']['best']['comfort']['total'])<1e-8]
def complete_boundaries(q):
 b=q['ownAttack']['best'];ball=q['positions'][q['own']]
 return all(math.dist(ball,b[k])>1e-8 for k in ['leftEnd','aim','rightEnd'])
quarantine=[dict(id=q['id'],sourceID=q['sourceID'],reason='A stored capture endpoint equals the target origin; endpoint data unresolved, not eligible for reviewed diagrams.') for q in pool if not complete_boundaries(q)]
(OUT/'boundary-quarantine.json').write_text(json.dumps(quarantine,ensure_ascii=False,indent=2))
pool=[q for q in pool if complete_boundaries(q)]
new=[];kinds=Counter(q['kind'] for q in old)
for i in range(21):
 candidates=[q for q in pool if signature(q) not in used and attack_signature(q) not in attacks]
 assert candidates,('Not enough varied T02 examples',len(new))
 # Cover metrics, ball counts and spatial arrangements; never broaden the band.
 fraction=(i%7+.5)/7
 def proposed_kind(q):return ('two_black' if kinds['two_black']<=kinds['two_own'] else 'two_own') if q['source']=='two' else q['kind']
 def cost(q):
  kind=proposed_kind(q);v=(width(q)-.002)/.006;c=(comfort(q)-4)/6
  diversity=min((math.dist(q['cue'],p['cue'])+math.dist(q['positions'][q['own']],p['positions'][p['own']]) for p in old+new),default=2)
  return .8*kinds[kind]+(v-fraction)**2+.2*(c-(i%3+.5)/3)**2-.2*min(diversity,2)
 q=dict(min(candidates,key=cost));q['kind']=proposed_kind(q)
 if q['source']=='two':
  q['numbers']=[9,9] if q['kind']=='two_black' else [8,8];q['numbers'][q['own']]=8 if q['kind']=='two_black' else 1
 kinds[q['kind']]+=1;used.add(signature(q));attacks.add(attack_signature(q));q['maxPocketComfort']=comfort(q);new.append(q)
new.sort(key=width)
for i,q in enumerate(new):q.update(sampleID=f'E{i+1:02}',stage=f'G{i//3+1:02}')
qs=old+new
(OUT/'samples.json').write_text(json.dumps(qs,ensure_ascii=False,indent=2))
protocol=dict(status='T02 accepted in initial ladder, expanded set awaiting user review',formalGlobalCutoffsApproved=False,widthLowerExclusive=.002,widthUpperInclusive=.008,comfortLowerInclusive=4,comfortUpperExclusive=10,retained=3,added=21,total=24,passingCandidateRecords=len(pool),kinds=kinds,sourceEvaluationSHA256=sha(OUT/'evaluated.json'),rendererSHA256=sha(renderer),cardBuilderSHA256=sha(builder),scope='T02 only. Max six-pocket cue window and max representative comfort on same shown route. Limited sample, not full-bank filtering. No safety strokes validated.')
(OUT/'protocol.json').write_text(json.dumps(protocol,ensure_ascii=False,indent=2))
sections=[]
sections.append('<section id="reference"><div class="stage-head"><div><span class="step">对照</span><h2>原T02的3个球形</h2></div></div><div class="grid">'+''.join(map(card,old))+'</div></section>')
for i in range(7):
 group=new[i*3:(i+1)*3];tag=f'G{i+1:02}'
 sections.append(f'<section id="{tag}"><div class="stage-head"><div><span class="step">{i+1:02}</span><h2>新增 {group[0]["sampleID"]}–{group[-1]["sampleID"]}</h2></div><span>本行容错角 {f(min(map(width,group)))}–{f(max(map(width,group)))}°</span></div><div class="grid">'+''.join(map(card,group))+'</div></section>')
# Inherit the tested three-column CSS, with per-question native selects.
base=(LADDER/'review.html').read_text();css=re.search(r'<style>([\s\S]*?)</style>',base).group(1)
css+=' .question-vote{display:block;margin-top:16px;padding-top:12px;border-top:1px solid #e5e8df;font-size:13px}.question-vote select{max-width:100%;margin-left:8px}.stage-head>span{font-size:12px;color:#64775f}'
content=''.join(sections)
for q in qs:
 needle=f'<article id="{q["sampleID"]}"';pos=content.index(needle);end=content.index('</article>',pos)
 vote=f'<label class="question-vote">{q["sampleID"]}判断<select class="vote" data-stage="{q["sampleID"]}" aria-label="{q["sampleID"]}是否适合防守"><option value="">未判断</option><option>适合做防守题</option><option>有点犹豫</option><option>进攻已不够难</option></select></label>'
 # Insert inside body, before its closing div.
 insert=content.rfind('</div>',pos,end);content=content[:insert]+vote+content[insert:]
script=re.search(r'<script>([\s\S]*?)</script>',base).group(1).replace('防守阈值图册反馈','T02扩展图册反馈').replace('从T几开始不合适，或具体哪一题','哪些E题适合，哪些E题不合适')
page='''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>T02扩展 · 24个球形</title><style>'''+css+'''</style></head><body><main class="wrap"><header><div class="eyebrow">球迹 · T02范围复核 / 2026.11.04</div><h1>都在T02里，这些球形也合适吗？</h1><p>原3题保留，新增21题，共24题，每行3个。新增题按容错角从小到大排列，舒适分均保持在4–10。</p><div class="notice"><b>范围保持不变：</b>母球瞄准容错角 &gt; 0.002° 且 ≤ 0.008°；六袋代表路线最高舒适分 ≥ 4 且 &lt; 10。所有卡片都满足这两个条件。</div><p>先看原T02，再往下比较E01–E21。若同范围仍有不适合的球形，请直接告诉我题号，或在卡片下方标记。金色为进袋方向，浅蓝／白虚线为母球瞄准方向，均是进攻评估线。</p></header><nav aria-label="图册导航"><a href="#reference">原3题</a>'''+''.join(f'<a href="#G{i+1:02}">E{i*3+1:02}–E{i*3+3:02}</a>' for i in range(7))+'''<a href="#feedback">反馈汇总</a></nav><input id="show-lines" type="checkbox" checked><label for="show-lines">显示进攻评估线</label><div class="scroll">'''+content+'''</div><div class="feedback" id="feedback"><h2>你的判断</h2><p>各卡片可分别选择；复制下面的汇总发给我即可。不会自动提交，刷新后需重选。</p><label for="feedback-text">反馈汇总</label><textarea id="feedback-text" readonly></textarea></div><footer>母球角为六袋最大连续瞄准角域的全宽；舒适分为各袋代表路线中的最高值。这批两项最大值均对应图示路线。不是命中率，也尚未验证具体防守打法。球位来自原库，球权按每题说明；球数不含母球。<br>这是T02范围内的扩大看图样本，不是完整球库筛选。球桌XZ米制、竖图上+X/右+Z；无需根据原库生成角度判断当前切角。</footer></main><script>'''+script+'''</script></body></html>'''
(OUT/'review.html').write_text(page)
print(json.dumps(protocol,ensure_ascii=False,indent=2))
