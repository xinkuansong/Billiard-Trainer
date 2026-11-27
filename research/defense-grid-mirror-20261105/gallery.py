"""Read-only seeded review of the published fixed-orientation free bank."""
from pathlib import Path
import gzip,json,hashlib,random,html,math
from prepare import ROOT,OUT,cell
DEST=OUT/'gallery';DEST.mkdir(exist_ok=True)
seed=2026110501
source=ROOT/'QiuJi/Resources/defense-free-bank.json.gz'
raw=source.read_bytes();rows=json.loads(gzip.decompress(raw))
publication=json.loads((OUT/'publication.json').read_text())
assert hashlib.sha256(raw).hexdigest()==publication['outputSHA256'][source.name]
trajectory=json.loads(gzip.decompress((ROOT/'QiuJi/Resources/defense-practice-bank.json.gz').read_bytes()))['questions']
refs={q['id']:len(q['references']) for q in trajectory}
ledger={q['newID']:q for q in json.loads((OUT/'mirror-and-dedup-ledger.json').read_text()) if q['kept']}
groups=[('one','01','一颗黑八','我方打8号 · 对方打8号'),('two_black','02','两颗球 · 我方打黑八','我方打8号 · 对方打9号'),('two_own','03','两颗球 · 对方打黑八','我方打1号 · 对方打8号'),('three','04','三颗球 · 双方各剩一颗','我方打1号 · 对方打9号 · 另有黑八')]
geo=json.loads((OUT/'native-geometry.json').read_text())
R=.028575
# SceneKit XZ metres -> portrait: screen up = +X, screen right = +Z.
def xy(p):return (150+p[1]*185,276-p[0]*185)
def line(a,b,color='#a6b8a9',width=.8):
 x,y=xy(a);u,v=xy(b);return f'<line x1="{x:.4f}" y1="{y:.4f}" x2="{u:.4f}" y2="{v:.4f}" stroke="{color}" stroke-width="{width}"/>'
def ball(p,n):
 x,y=xy(p);r=R*185;fill='#fffdf5' if n==0 else '#171b1b' if n==8 else '#ecb22b'
 s=f'<g data-ball="{n}" data-x="{p[0]}" data-z="{p[1]}"><circle cx="{x:.5f}" cy="{y:.5f}" r="{r}" fill="{fill}" stroke="#f6f4df" stroke-width=".65"/>'
 if n==9:s+=f'<path d="M{x-r*.9},{y-r*.4} h{r*1.8} v{r*.8} h{-r*1.8} Z" fill="#fffbed"/>'
 if n:
  s+=f'<circle cx="{x}" cy="{y}" r="{r*.56}" fill="#fffbed"/><text x="{x}" y="{y+2.6}" text-anchor="middle" font-size="7.5" font-weight="700" fill="#182820">{n}</text>'
 return s+'</g>'
def svg(q,label):
 s=[f'<svg viewBox="0 0 300 552" role="img" aria-label="{label}，母球及{len(q["balls"])}颗目标球的初始摆位">','<rect x="16" y="26" width="268" height="500" rx="14" fill="#60564a"/>','<rect x="32.525" y="41.05" width="234.95" height="469.9" fill="#146551"/>','<g class="gridlines" opacity=".26">']
 for i in range(21):
  x=-1.27+i*2.54/20;z=-.635+i*1.27/20
  s.extend([line([x,-.635],[x,.635],'#deeadb',.45),line([-1.27,z],[1.27,z],'#deeadb',.45)])
 s.append('</g>')
 for rail in geo['linear']:s.append(line(rail['start'],rail['end']))
 for arc in geo['circular']:
  a=arc['startAngle'];d=math.atan2(math.sin(arc['endAngle']-a),math.cos(arc['endAngle']-a));pts=[]
  for i in range(33):
   t=a+d*i/32;p=[arc['center'][0]+arc['radius']*math.cos(t),arc['center'][1]+arc['radius']*math.sin(t)];pts.append(','.join(map(str,xy(p))))
  s.append('<polyline points="'+' '.join(pts)+'" fill="none" stroke="#a6b8a9" stroke-width=".8"/>')
 for p,letter in zip(geo['pockets'],['E','A','F','B','C','D']):
  x,y=xy(p);s.append(f'<circle cx="{x}" cy="{y}" r="7.5" fill="#102d27" stroke="#88a89b" stroke-width=".6"/><text x="{x}" y="{y+3}" text-anchor="middle" fill="#d5e2d7" font-size="9">{letter}</text>')
 s.append(ball(q['cue'],0));s.extend(ball(b['position'],b['number']) for b in q['balls']);s.append('</svg>');return ''.join(s)
assert xy([1,0])[1]<xy([0,0])[1] and xy([0,1])[0]>xy([0,0])[0]
samples=[];sections=[];manifest=[]
for index,(kind,tag,title,desc) in enumerate(groups):
 pool=sorted((q for q in rows if q['kind']==kind),key=lambda q:q['id']);chosen=random.Random(seed+index).sample(pool,20);cards=[]
 for i,q in enumerate(chosen,1):
  label=f'M{tag}-{i:02}';samples.append(dict(q,reviewID=label));meta=ledger[q['id']];sx,sz=meta['sx'],meta['sz']
  direction={(1,1):'保留原方向',(-1,1):'上下镜像',(1,-1):'左右镜像',(-1,-1):'上下＋左右镜像'}[(sx,sz)]
  locations=[('母球',q['cue'])]+[(f'{b["number"]}号',b['position']) for b in sorted(q['balls'],key=lambda b:b['number'])]
  cells=' · '.join(f'{name} {cell(p)[0]+1},{cell(p)[1]+1}' for name,p in locations)
  coordinates=''.join(f'<tr><td>{name}</td><td>{p[0]:.5f}</td><td>{p[1]:.5f}</td></tr>' for name,p in locations)
  drawing=svg(q,label)
  cards.append(f'<article id="{label}"><div class="cardhead"><b>{label}</b><span>{direction}</span></div>{drawing}<div class="info"><p>我方 {q["ownBallNumber"]}号 · 对方 {q["opponentBallNumber"]}号</p><small>{"另有轨迹参考解 "+str(refs[q["id"]])+" 个" if q["id"] in refs else "自由模式球形"}</small><details><summary>球位与网格</summary><p>网格（X列，Z行，1–20）：{cells}</p><table><tr><th>球</th><th>X / m</th><th>Z / m</th></tr>{coordinates}</table><p class="code">{html.escape(q["id"])}</p><p>原题号：{html.escape(q["sampleID"])}</p></details></div></article>')
 sections.append(f'<section id="group-{tag}"><h2><span>{tag}</span>{title}</h2><p class="sub">{desc}。随机20题 / 本类{len(pool):,}题，球数不含母球。</p><div class="scroll"><div class="grid">'+''.join(cards)+'</div></div></section>')
 manifest.append(dict(kind=kind,population=len(pool),seed=seed+index,selected=[q['id'] for q in chosen]))
style='''*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:#f3f4ee;color:#20392e;font:15px -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif}main{max-width:1700px;margin:auto;padding:32px 24px}h1{font-size:32px;margin:8px 0 14px}header p,.sub{color:#617264;line-height:1.8}nav{display:flex;gap:10px;flex-wrap:wrap;margin:18px 0}a{color:#285e46;text-decoration:none}nav a{background:#e5ebde;padding:10px 14px;border-radius:8px}label{display:inline-flex;align-items:center;gap:8px;min-height:44px;cursor:pointer}input{width:18px;height:18px}section{padding-top:20px;scroll-margin-top:12px}h2{font-size:24px;margin-bottom:4px}h2 span{color:#92a18a;margin-right:12px;font-weight:400}.scroll{overflow-x:auto}.grid{display:grid;grid-template-columns:repeat(5,minmax(230px,1fr));min-width:1220px;gap:16px}article{background:#fffef9;border:1px solid #d9e0d2;border-radius:14px;overflow:hidden}.cardhead{display:flex;align-items:center;justify-content:space-between;padding:16px 14px 0;gap:6px}.cardhead b{font-size:17px}.cardhead span{font-size:11px;color:#75826f}svg{display:block;width:100%;height:auto}.info{padding:0 15px 16px}.info p{margin:4px 0 8px}.info small{color:#6a796e;font-size:12px}details{border-top:1px solid #e1e5da;margin-top:12px;padding-top:10px;font-size:12px;line-height:1.7}summary{cursor:pointer;color:#427257;min-height:28px}table{width:100%;text-align:left;font-size:11px}td,th{padding:3px 1px}.code{overflow-wrap:anywhere;font-size:10px;color:#7b887a}body:not(.show-grid) .gridlines{display:none}footer{margin-top:24px;color:#748270;font-size:12px;line-height:1.8}@media print{nav,label{display:none}main{padding:8px}.grid{min-width:0;gap:8px}.cardhead{padding:7px;font-size:9px}.cardhead span{display:none}h2{break-before:page}article{break-inside:avoid}details{display:none}}'''
page='<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>镜像与去重后 · 四类80题</title><style>'+style+'</style></head><body><main><header><small>球迹 · 防守题库复核</small><h1>镜像与去重后 · 随机80题</h1><p>从正式自由题库58,470题中，每类等概率、不放回抽20道。保持抽取顺序；图中球位与题库完全一致，不再次镜像。</p><p>白球为母球；1号为我方球，9号为对方球，8号为黑八。卡片标明双方当前目标球。这里只展示初始摆位，便于检查分布与相似度。</p></header><nav>'+''.join(f'<a href="#group-{tag}">{title}</a>' for _,tag,title,_ in groups)+'</nav><label><input id="grid-toggle" type="checkbox">显示20×20去重网格</label>'+''.join(sections)+'<footer>固定一行5题，窄屏可横向滚动。可直接反馈题号，例如 M03-07。<br>竖图：上方 +X，右方 +Z；球位单位为米。网格按2.54×1.27米内框等分，不移动球位。每次打开均为本批80题。</footer></main><script>document.getElementById("grid-toggle").addEventListener("change",function(){document.body.classList.toggle("show-grid",this.checked)});</script></body></html>'
(DEST/'review.html').write_text(page)
(DEST/'samples.json').write_text(json.dumps(samples,ensure_ascii=False,indent=2))
(DEST/'sampling.json').write_text(json.dumps(dict(source=str(source),sourceSHA256=hashlib.sha256(raw).hexdigest(),method='uniform random.sample without replacement per kind; published orientation unchanged',columns=5,count=80,groups=manifest),ensure_ascii=False,indent=2))
assert len(samples)==80 and len({q['id'] for q in samples})==80
print(DEST/'review.html')
