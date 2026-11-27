"""Uniform seeded samples from the final four catalogs; self-contained five-column atlas."""
from pathlib import Path
import ast,gzip,hashlib,html,json,math,random,re

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'output/defense-approved-filter-20261104'
OUT=ROOT/'output/defense-random-review-20261104'
OUT.mkdir(exist_ok=True)
read=lambda p:json.loads(p.read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
seed=2026110401
groups=[('one','01','一颗黑八','我方打8号，对方也打8号'),('two_black','02','两颗球 · 我方打黑八','我方打8号，对方打9号'),('two_own','03','两颗球 · 对方打黑八','我方打1号，对方打8号'),('three','04','三颗球 · 双方各剩一颗','我方打1号，对方打9号，另有黑8')]
geo=read(BASE/'geometry.json')
names=['左下角袋','左上角袋','右下角袋','右上角袋','左中袋','右中袋']
letters=['E','A','F','B','C','D']
renderer=ROOT/'research/defense-reuse-20261104/build_page.py'
ns=dict(math=math,html=html,geo=geo,R=geo['radius'],names=names,letters=letters)
nodes=[n for n in ast.parse(renderer.read_text()).body if isinstance(n,ast.FunctionDef) and n.name in ['xy','pair','line','circle','svg']]
assert len(nodes)==5
exec(compile(ast.Module(body=nodes,type_ignores=[]),str(renderer),'exec'),ns)
svg=ns['svg']
def fmt(x):
    return f'{x:.6f}'.rstrip('0').rstrip('.') if x<.001 else f'{x:.4f}'.rstrip('0').rstrip('.')
def pocket(i):return letters[i]+' '+names[i]
def card(q):
    b=q['ownAttack']['best'];bestComfort=max((o for o in q['ownAttack']['options'] if o['cueWidth']>0),key=lambda o:o['comfort']['total'])
    drawing=svg(q);(OUT/f'{q["sampleID"]}.svg').write_text(drawing)
    comparisons=''.join(f'<tr><td>{pocket(o["pocket"])}</td><td>{fmt(o["cueWidth"])}°</td><td>{o["comfort"]["total"]:.2f}</td></tr>' if o['cueWidth']>0 else f'<tr><td>{pocket(o["pocket"])}</td><td colspan="2">无可达直进窗口</td></tr>' for o in q['ownAttack']['options'])
    different='两项最大值对应不同袋口，图中绘制容错角最大的路线。' if b['pocket']!=bestComfort['pocket'] else '两项最大值对应同一袋口。'
    return f'''<article class="card" id="{q['sampleID']}"><div class="card-head"><strong>{q['sampleID']}</strong><span>{ {'one':'准度球库','two_black':'两球走位库','two_own':'两球走位库','three':'三球走位库'}[q['kind']]}</span></div>{drawing}<div class="body">
<div class="route">图示进攻袋口 · {pocket(b['pocket'])}</div>
<div class="metric"><span>母球瞄准容错角</span><strong>{fmt(b['cueWidth'])}<small>°</small></strong></div>
<div class="metric comfort-score"><span>六袋最高舒适分</span><strong>{q['maxPocketComfort']:.2f}</strong></div>
<p class="note">最高舒适分袋口：{pocket(bestComfort['pocket'])}<br>{different}</p>
<dl><div><dt>图示袋干净进袋容错角</dt><dd>{fmt(b['objectWidth'])}°</dd></div><div><dt>图示路线切角</dt><dd>{b['cut']:.1f}°</dd></div><div><dt>母球→接触位置</dt><dd>{b['cueDistance']:.2f} m</dd></div><div><dt>目标球→捕获入口</dt><dd>{b['potDistance']:.2f} m</dd></div></dl>
<details><summary>六袋比较与来源</summary><table><tr><th>袋口</th><th>母球角</th><th>舒适分</th></tr>{comparisons}</table><p>图示路线舒适分 {b['comfort']['total']:.2f}。母球角为连续角域全宽，并非±值或命中率。</p><code>{html.escape(q['sourceID'])}</code><p>球位与球号取自已筛选库，未移动或重新分配。</p></details>
<label class="question-vote">你的判断<select class="vote" data-stage="{q['sampleID']}" aria-label="{q['sampleID']}是否适合防守"><option value="">未判断</option><option>适合做防守题</option><option>有点犹豫</option><option>进攻已不够难</option></select></label></div></article>'''

samples=[];sections=[];manifest={}
summary=read(BASE/'catalog-summary.json');assert summary['passed']
for index,(kind,tag,title,desc) in enumerate(groups):
    path=BASE/'catalogs'/f'{kind}.jsonl.gz'
    with gzip.open(path,'rt') as f:pool=[json.loads(line) for line in f]
    assert len(pool)==summary['uniqueRoleCounts'][kind]
    selected=random.Random(seed+index).sample(pool,20)
    assert len({q['formationID'] for q in selected})==20
    for i,q in enumerate(selected):
        q['sampleID']=f'R{tag}-{i+1:02}'
        assert 1e-6<q['ownAttack']['best']['cueWidth']<=.008 and q['maxPocketComfort']<10
    samples+=selected
    manifest[kind]=dict(catalogSHA256=sha(path),population=len(pool),seed=seed+index,selected=[q['formationID'] for q in selected])
    sections.append(f'<section id="group-{tag}"><div class="section-heading"><span>{tag}</span><div><h2>{title}</h2><p>{desc}。球数不含母球。随机20题 / 候选{len(pool):,}题</p></div></div><div class="grid">'+''.join(card(q) for q in selected)+'</div></section>')
css=re.search(r'<style>([\s\S]*?)</style>',(ROOT/'output/defense-reuse-20261104/review.html').read_text()).group(1)
css+='''
.grid{grid-template-columns:repeat(5,minmax(265px,1fr));min-width:1381px}.wrap{max-width:1920px}.metric{display:flex;flex-direction:column;gap:4px;padding:10px 0;border-bottom:1px solid #e5e8df}.metric span{font-size:12px}.metric strong{font-size:30px;line-height:1.15;font-variant-numeric:tabular-nums;color:#aa6630}.metric small{font-size:16px}.comfort-score strong{color:#345d49}.note{font-size:11px;color:#6a796e;line-height:1.7;min-height:56px}.question-vote{display:flex;flex-wrap:wrap;font-size:12px;gap:7px;border-top:1px solid #e5e8df;padding-top:12px}select{width:100%;min-height:38px;font:inherit;color:#20392e;background:#fffef9;border:1px solid #c8d3c2;border-radius:6px;padding:6px}nav{display:flex;gap:12px;flex-wrap:wrap;margin:18px 0}a{color:#356b50}nav a{background:#e5ebde;padding:8px 12px;border-radius:6px;text-decoration:none}.feedback{margin-top:26px}textarea{width:100%;min-height:160px;padding:12px;font:14px -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif;border:1px solid #bdcbbd;border-radius:8px}.card{scroll-margin-top:16px}section{scroll-margin-top:16px}@media print{.question-vote,nav,.feedback{display:none}.grid{min-width:0;grid-template-columns:repeat(5,1fr)}}
'''
old=(ROOT/'output/defense-t02-expand-20261104/review.html').read_text()
script=re.search(r'<script>([\s\S]*?)</script>',old).group(1).replace('T02扩展图册反馈','防守随机图册反馈').replace('哪些E题适合，哪些E题不合适','哪些题适合，哪些题不合适')
page='''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>防守候选随机图册 · 四类80题</title><style>'''+css+'''</style></head><body><main class="wrap"><header><div class="eyebrow">球迹 · 防守开局候选 / 随机复核</div><h1>四类球形，各随机看20题</h1><p>从刚筛出的候选库中，每类等概率、不放回抽取20题，共80题，每行5个。保持随机抽取顺序，没有按难度排序或另外挑选球形。</p><div class="notice"><b>筛选范围：</b>六袋最大母球瞄准容错角 ≤ 0.008°，六袋代表路线最高舒适分 &lt; 10；更难的球形也包含在内。两项都越小，越符合目前采用的“己方进攻困难”条件。</div><p>金色线为目标球进袋方向，浅蓝／白虚线为母球瞄准方向，均是<b>进攻评估线</b>。这里只评审防守开局，尚未验证具体防守打法。</p><p>直接报题号，例如 R03-07；也可在卡片下方选择判断，再复制页底汇总。</p></header><nav aria-label="图册分类">'''+''.join(f'<a href="#group-{tag}">{title}</a>' for _,tag,title,_ in groups)+'''<a href="#feedback">反馈汇总</a></nav><input id="show-lines" type="checkbox" checked><label for="show-lines">显示进攻评估线</label><div class="scroll">'''+''.join(sections)+'''</div><div class="feedback" id="feedback"><h2>反馈汇总</h2><p>选择不会自动提交；刷新页面后需重选。</p><label for="feedback-text">复制以下文字发给我</label><textarea id="feedback-text" readonly></textarea></div><footer>球数不含母球。竖图上+X、右+Z，球位和球号均保持候选库原值。固定每行5题，窄屏可横向滚动。随机种子2026110401–2026110404；重复打开是同一批球形。舒适分是已有代表路线中的最高值，并非连续瞄点最优值或命中率。</footer></main><script>'''+script+'''</script></body></html>'''
(OUT/'review.html').write_text(page)
(OUT/'samples.json').write_text(json.dumps(samples,ensure_ascii=False,indent=2))
(OUT/'sampling.json').write_text(json.dumps(dict(method='Uniform random.sample without replacement within each final catalog; independent deterministic seed per class; no extra visual or difficulty filters',count=80,perClass=20,columns=5,catalogs=manifest,rendererSHA256=sha(renderer),geometrySHA256=sha(BASE/'geometry.json'),builderSHA256=sha(Path(__file__))),indent=2))
print(OUT/'review.html')
