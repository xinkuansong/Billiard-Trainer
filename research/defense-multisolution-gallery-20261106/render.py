"""Immutable snapshot atlas of audited routes. No solver changes or generated trajectories."""
from pathlib import Path
import sys,json,gzip,hashlib,html,math,datetime,collections
from zoneinfo import ZoneInfo
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
SRC=ROOT/'output/defense-multisolution-full-20261106';OUT=ROOT/'output/defense-multisolution-gallery-20261106'
OUT.mkdir(exist_ok=True);(OUT/'cases').mkdir(exist_ok=True)
sys.path.insert(0,str(ROOT/'research/defense-threshold-comparison-20261105'))
import geometric_table as g
plt=g.plt;np=g.np
BG='#f4f5f0';INK='#173b32';owncolors={1:'#f5c226',8:'#18211f'}
kindnames={'two_black':'两球 · 我方8 / 对方9','two_own':'两球 · 我方1 / 对方8','three':'三球 · 我方1 / 对方9 / 静止8'}
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
esc=lambda x:html.escape(str(x),quote=True)
def branch(e):
 if e.get('fullDirectBlock') or e.get('potContactsBlocked'):return '封锁'
 if e.get('estimateReason') or (e.get('pipeRoute') or {}).get('zeroWidthEstimate'):return '估算'
 return '公式'
def path(r):return '区域型' if r['baseScore']>=80 else '遮挡增益型'
def rank(r):return (r['effort'],r['shot']['speed'],sum(e['kind']=='cushion' for e in r['events']),r['id'])
def pieces(r,own):
 hit=next(e['time'] for e in r['events'] if e['kind']=='ballBall')
 cue=r['tracks']['cueBall'];obj=r['tracks']['_'+str(own)]
 before=[f[1:] for f in cue if f[0]<=hit+1e-5];after=[f[1:] for f in cue if f[0]>=hit-1e-5]
 assert before and after and math.dist(before[-1],after[0])<1e-4
 assert math.dist(cue[-1][1:],r['finalPositions']['cueBall'])<1e-5
 return [(before,'#ffffff',False),(after,'#ffffff',True),([f[1:] for f in obj],owncolors[own],True)]
def pstr(points):
 # Drop only exact repeated positions. Retain every moving frame, no schematic straightening.
 unique=[]
 for p in points:
  if not unique or p!=unique[-1]:unique.append(p)
 return ' '.join(f'{(p[0]+1.47)*300:.5f},{(p[1]+.83)*300:.5f}' for p in unique)
def at(p):return ((p[0]+1.47)*300,(p[1]+.83)*300)
def circle(p,r,fill,stroke,width=1):
 x,y=at(p);return f'<circle cx="{x:.5f}" cy="{y:.5f}" r="{r*300:.5f}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'
def svg_ball(p,n):
 fill='#18211f' if n==8 else '#f3c126' if n==1 else '#fffdf3'
 s=circle(p,g.R,fill,'#123e32')
 if n==9:
  x,y=at(p);s+=f'<path d="M {x-g.R*300*.8},{y-g.R*300*.5} H {x+g.R*300*.8} V {y+g.R*300*.5} H {x-g.R*300*.8} Z" fill="#eabb22"/>'
 if n:
  s+=circle(p,g.R*.56,'#fffdf3','none');x,y=at(p);s+=f'<text x="{x}" y="{y+.5}" font-size="9" fill="#142d25" text-anchor="middle" dominant-baseline="central" font-weight="bold">{n}</text>'
 else:s+=circle(p,g.R*.13,'#ea564d','none')
 return s
TABLE=f'<rect x="12" y="10.5" width="858" height="477" rx="20" fill="#293238" stroke="#152127" stroke-width="2"/><polygon points="{pstr(g.outline.tolist())}" fill="#087f58" stroke="#60b893" stroke-width="1.2"/>'
for p in g.geo['pockets']:
 rr=.042 if abs(p['center'][0])>.1 else .043
 TABLE+=circle(p['center'],rr+.007,'#cbb98b','none')+circle(p['center'],rr,'#101d1b','none')
for x in [-.9525,-.635,-.3175,.3175,.635,.9525]:
 for z in [-.745,.745]:TABLE+=circle((x,z),.004,'#ddd9cb','none')
for z in [-.3175,0,.3175]:
 for x in [-1.38,1.38]:TABLE+=circle((x,z),.004,'#ddd9cb','none')
def svg(q,r):
 own=q['ownBallNumber'];s=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 882 498" role="img"><title>{esc(kindnames[q["kind"]])}，路线{r["id"]}，防守{r["effect"]["score"]:.1f}分</title>'+TABLE
 for points,col,dash in pieces(r,own):
  pts=pstr(points)
  if len(points)<2:continue
  ds=' stroke-dasharray="7 5"' if dash else ''
  halo='#d3e3d9' if own==8 and col==owncolors[8] else '#184f3d'
  s+=f'<polyline points="{pts}" fill="none" stroke="{halo}" stroke-width="3.4"{ds}/><polyline points="{pts}" fill="none" stroke="{col}" stroke-width="1.9"{ds}/>'
 # Initial physical balls and final rings are separate. Static objects are rendered once.
 s+=svg_ball(q['cue'],0)
 for b in q['balls']:s+=svg_ball(b['position'],b['number'])
 for key,col,label in [('cueBall','#fffdf3','母终'),('_'+str(own),owncolors[own],str(own)+'终')]:
  end=r['finalPositions'][key];s+=circle(end,g.R,'none','#b7d4c8',4)+circle(end,g.R,'none',col,2)
  x,y=at(end);offset=16 if end[1]<.5 else -17
  s+=f'<text x="{x}" y="{y+offset}" text-anchor="middle" font-size="10" fill="{col}" stroke="#087f58" stroke-width="3" paint-order="stroke">{label}</text>'
 return s+'</svg>'
def angletext(v):return "未知" if v is None else f"{v:.3f}°"
def desc(q,r):
 s=r['shot'];n=q['ownBallNumber'];c=sum(e['kind']=='cushion' for e in r['events']);worst=min(p['score'] for p in r['probes'])
 return f'切角 {r["measuredCutDegrees"]:.1f}° · 杆速 {s["speed"]:.3f} · 打点 ({s["spinX"]:+.2f}, {s["spinY"]:+.2f}) · 合计 {c} 库',f'四次扰动最低 {worst:.1f} 分 · {n}号窗口 {angletext(r["ownBefore"]["bestClearDegrees"])} → {angletext(r["ownAfter"]["bestClearDegrees"])}'
CSS='''body{font:16px/1.6 system-ui,-apple-system,sans-serif;background:#f4f5f0;color:#173b32;margin:0 auto;padding:24px;max-width:1600px}h1{font-size:28px}h2{font-size:20px}a{color:#126659}header,p{max-width:1100px}.cards{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px}.route,.card{padding:16px;background:white;border:1px solid #d8e1d8;border-radius:14px}.route p{font-size:14px;margin:8px 0}svg,img{width:100%;height:auto;display:block}.muted{color:#5b7065}.tag{font-size:13px;background:#e2eee6;border-radius:8px;padding:4px 9px;display:inline-block;margin:4px}.list{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px}.list img{border-radius:8px}input,select{font:inherit;max-width:100%;padding:10px;margin:8px;border:1px solid #96ac9f;border-radius:8px;min-height:44px;box-sizing:border-box}nav a{display:inline-block;margin:8px;padding:8px}summary{cursor:pointer;padding:8px}details{overflow-wrap:anywhere}a:focus-visible,input:focus-visible,select:focus-visible{outline:3px solid #b77816}@media(max-width:850px){.cards,.list{grid-template-columns:1fr}body{padding:14px}h1{font-size:23px}}'''
def page(title,body):return f'<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{esc(title)}</title><style>{CSS}</style></head><body>{body}</body></html>'
# Freeze the set at invocation; ongoing producer is never modified or re-read for totals.
if not (OUT/'snapshot.json').exists():
 checkpoints=[]
 for cp in sorted((SRC/'full/records').glob('*.checkpoint.json')):
  c=json.loads(cp.read_bytes())
  if c['summary']['retained']>0:checkpoints.append({'file':str(cp.with_name(cp.name.replace('.checkpoint.json','.json.gz'))),'sha256':c['sha256'],'summary':c['summary'],'identity':c['identity']})
 (OUT/'snapshot.json').write_text(json.dumps({'time':datetime.datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(),'sourceStatus':json.loads((SRC/'status.json').read_bytes()),'records':checkpoints},ensure_ascii=False,indent=2))
snap=json.loads((OUT/'snapshot.json').read_bytes());records=[];routecount=0
for i,item in enumerate(snap['records'],1):
 f=Path(item['file']);assert sha(f)==item['sha256'];payload=json.loads(gzip.decompress(f.read_bytes()));record=payload['record'];q=record['question'];routes=record['result']['routes'];assert q['id']==item['summary']['id'] and len(routes)==item['summary']['retained']
 label=f'G{i:04}';routes=sorted(routes,key=rank);folder=OUT/'cases'/label;folder.mkdir(exist_ok=True)
 links=[];body=f'<nav><a href="../../index.html">← 完整目录</a><a href="../../selected.html">精选对照</a></nav><h1>{label} · {kindnames[q["kind"]]}</h1><p>{len(routes)}条已验证路线'+(' · 多解入选' if len(routes)>=2 else ' · 仅一条解，未达到多解入选要求')+'</p><p>实体球为起点，空心圈为终点；白实线为母球碰球前，白虚线为碰球后；我方球按球色画虚线。固定对方球不移动。三球的基础区域分包含静止8号遮挡。没有中杆中力参考线。</p><div class="cards">'
 for r in routes:
  assert r['probePasses']==4 and r['replayVerified'] and r['effect']['score']>=80
  plot=svg(q,r);name=f'route-{r["id"]:02}.svg';(folder/name).write_text(plot)
  a,b=desc(q,r);body+=f'<article class="route"><h2>路线{r["id"]} · 防守 {r["effect"]["score"]:.1f} 分</h2><span class="tag">{path(r)} · {branch(r["effect"])}</span><a href="{name}" aria-label="放大路线{r["id"]}">{plot}</a><p>{a}</p><p>{b}</p><p class="muted">无移动我方球遮挡的基础分 {r["baseScore"]:.1f} → 终态分 {r["effect"]["score"]:.1f}</p></article>'
 body+='</div><p>四次扰动为瞄准±0.1°、杆速±5%，不等于实战成功率。我方窗口不下降仍是暂用保护条件；“估算”沿用模型标记。</p>'
 body+=f'<details><summary>原始题目与数据</summary><p>{esc(q["id"])}</p><a href="routes.json">完整参数、评分、事件和轨迹</a></details>'
 (folder/'index.html').write_text(page(label,body));(folder/'routes.json').write_text(json.dumps({'question':q,'result':record['result']},separators=(',',':')))
 records.append({'label':label,'question':q,'routes':routes,'folder':str(folder),'maximum':record['scan']['maximumSampled']});routecount+=len(routes)
 if i%200==0:print('Rendered',i,'layouts',flush=True)
# Review sampling only; it does not alter generated-bank selection or weights.
selected=[]
for kind,typ,count in [('two_black','区域型',4),('two_black','遮挡增益型',4),('two_own',None,2),('three',None,2)]:
 candidates=[c for c in records if c['question']['kind']==kind and len(c['routes'])>=2 and c not in selected and (typ is None or any(path(r)==typ for r in c['routes']))]
 candidates.sort(key=lambda c:min(rank(r) for r in c['routes'] if typ is None or path(r)==typ))
 selected.extend(candidates[:count])
assert len(selected)==12
# PNG cards use the same original samples and CAD geometry as SVGs.
def draw(ax,c,r):
 g.table(ax);q=c['question'];own=q['ownBallNumber']
 for p,col,dash in pieces(r,own):
  a=np.array(p);ls='--' if dash else '-';halo='#c8dfd2' if col==owncolors[8] else '#194f3d'
  ax.plot(a[:,0],a[:,1],color=halo,lw=3.2,ls=ls,zorder=5);ax.plot(a[:,0],a[:,1],color=col,lw=1.8,ls=ls,zorder=6)
 g.ball(ax,q['cue'],0)
 for b in q['balls']:
  if b['number']!=1:g.ball(ax,b['position'],b['number'])
  else:
   ax.add_patch(g.Circle(b['position'],g.R,fc=owncolors[1],ec='#123e32',lw=.6,zorder=8));ax.add_patch(g.Circle(b['position'],g.R*.56,fc='#fffdf3',zorder=9));ax.text(*b['position'],'1',ha='center',va='center',fontsize=7,color=INK,zorder=10)
 for key,col,label in [('cueBall','white','母终'),('_'+str(own),owncolors[own],f'{own}终')]:
  p=r['finalPositions'][key];ax.add_patch(g.Circle(p,g.R,fill=False,ec='#bfd5cc',lw=3.5,zorder=12));ax.add_patch(g.Circle(p,g.R,fill=False,ec=col,lw=1.8,zorder=13))
  ax.annotate(label,xy=p,xytext=(0,-15 if p[1]<.45 else 15),textcoords='offset points',ha='center',fontsize=8,color=col,zorder=14)
for idx,c in enumerate(selected,1):
 for prefix,routes in [('comparison',c['routes']),('preview',c['routes'][:2])]:
  rows=math.ceil(len(routes)/2);fig,axs=plt.subplots(rows,2,figsize=(16,rows*5.2+1.6),squeeze=False);fig.patch.set_facecolor(BG);fig.subplots_adjust(top=1-.8/(rows*5.2+1.6),bottom=.65/(rows*5.2+1.6),left=.025,right=.975,hspace=.35,wspace=.05)
  for ax,r in zip(axs.flat,routes):
   draw(ax,c,r);a,b=desc(c['question'],r)
   ax.set_title(f'路线{r["id"]} · 防守 {r["effect"]["score"]:.1f} · {path(r)}（{branch(r["effect"])}）',loc='left',fontsize=13,color=INK)
   ax.text(.01,-.06,a+'\n'+b,transform=ax.transAxes,va='top',fontsize=10,color=INK)
  for ax in list(axs.flat)[len(routes):]:ax.axis('off')
  fig.text(.035,.96,f'{c["label"]}  {kindnames[c["question"]["kind"]]}  ·  同一球形{len(c["routes"])}条解{('（预览前2条）' if prefix=='preview' and len(c['routes'])>2 else '')}',fontsize=20,color=INK,va='top')
  fig.text(.035,.025,'实体球＝起点；空心圈＝终点。白实线：母球碰球前；白虚线：母球碰球后；黑／黄虚线：我方球。\n真实物理轨迹；四次扰动均通过，非实战成功率。',fontsize=11,color='#476457')
  fig.savefig(OUT/f'{prefix}-{idx:02}.png',dpi=130,facecolor=BG);plt.close(fig)
# Complete static directory, thumbnails lazy loaded; all routes reachable without JS.
body=f'<h1>防守多解 · 轨迹图册</h1><p>快照时间 {esc(snap["time"][:19].replace("T"," "))}（北京时间）。当前已找到解的 {len(records)} 个球形、{routecount} 条路线。后续生成继续运行，本页不会自动变化。</p><nav><a href="selected.html">先看12组多解对照 →</a></nav><p>每题点进去可看全部解。单解也保留展示，但尚未达到多解入选条件。实体球是起点，空心圈是终点；无中杆中力参考线。</p><label>筛选 <select id="filter"><option value="multi">多解球形</option><option value="all">全部已找到解</option><option value="single">仅单解</option><option value="two_black">我方8 / 对方9</option><option value="two_own">我方1 / 对方8</option><option value="three">三球</option></select></label><label>查找 <input id="search" placeholder="图号或原始题号"></label><p id="count" aria-live="polite"></p><div class="list">'
for c in records:
 q=c['question'];r=c['routes'][0];count=len(c['routes']);label=c['label'];body+=f'<article class="card" data-kind="{q["kind"]}" data-n="{count}" data-search="{esc(label+" "+q["id"]+" "+q["sampleID"])}"><a href="cases/{label}/index.html"><img loading="lazy" src="cases/{label}/route-{r["id"]:02}.svg" alt="{label} 初始球形与一条防守轨迹"><h2>{label} · {count}条解</h2></a><p>{kindnames[q["kind"]]}</p><span class="tag">'+('多解入选' if count>=2 else '单解保留')+'</span></article>'
body+='''</div><script>const filter=document.getElementById('filter'),search=document.getElementById('search'),cards=[...document.querySelectorAll('.card')];function update(){let n=0;for(const c of cards){const f=filter.value,k=c.dataset.kind,m=+c.dataset.n;const ok=(f==='all'||f==='multi'&&m>=2||f==='single'&&m===1||f===k)&&c.dataset.search.toLowerCase().includes(search.value.toLowerCase());c.hidden=!ok;if(ok)n++;}document.getElementById('count').textContent=`显示 ${n} 个球形`;}filter.addEventListener('change',update);search.addEventListener('input',update);update();</script>'''
(OUT/'index.html').write_text(page('防守多解轨迹图册',body))
body='<nav><a href="index.html">← 全部已找到解</a></nav><h1>先看这12组多解对照</h1><p>覆盖区域型、遮挡增益型和三种球权；仅作人工看图的覆盖抽样，不代表题库比例。每组展示已保存的全部解，均使用原始球位和物理轨迹。</p>'
for i,c in enumerate(selected,1):body+=f'<section><h2>{i:02} · <a href="cases/{c["label"]}/index.html">{c["label"]} · {kindnames[c["question"]["kind"]]}</a></h2><a href="comparison-{i:02}.png"><img loading="lazy" src="comparison-{i:02}.png" alt="{c["label"]}全部路线对照"></a></section>'
(OUT/'selected.html').write_text(page('12组防守多解对照',body))
manifest={'snapshotTime':snap['time'],'layouts':len(records),'multi':sum(len(c['routes'])>=2 for c in records),'single':sum(len(c['routes'])==1 for c in records),'routes':routecount,'kinds':dict(collections.Counter(c['question']['kind'] for c in records)),'selected':[{'label':c['label'],'id':c['question']['id'],'routes':len(c['routes'])} for c in selected],'geometrySourceChecks':g.checked,'rendererSHA256':sha(Path(__file__)),'coordinates':'original SceneKit XZ metres; screen right +X, down +Z; no mirroring','sampling':'Complete found-solution snapshot plus twelve review samples; no bank resampling','nativeUIAcceptance':False}
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2));print(json.dumps({k:manifest[k] for k in ['layouts','multi','single','routes','kinds']},ensure_ascii=False))
