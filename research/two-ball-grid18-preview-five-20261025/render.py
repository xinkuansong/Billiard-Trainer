"""Read-only sample of committed Stage B results. No physics execution."""
from pathlib import Path
import sys,json,gzip,hashlib,random,math,shutil,datetime,html
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle,Rectangle,Polygon
from matplotlib.font_manager import fontManager
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/two-ball-grid18-preview-five-20261025'; OUT.mkdir(exist_ok=True)
sys.path.insert(0,str(ROOT/'research/two-ball-middle-grid18-20261025'))
import pipeline as P
B=P.B; A=P.A
read=lambda p:json.loads(p.read_text())
sha=lambda raw:hashlib.sha256(raw).hexdigest()
seed=202610251518; rng=random.Random(seed)
snapshot=[read(p) for p in sorted((B/'receipts').glob('*.json'))]
if (OUT/'verification.json').exists():
 saved=read(OUT/'verification.json')['receiptSnapshot']; allowed={r['stem']:r for r in saved}
 snapshot=[r for r in snapshot if r['stem'] in allowed]
 assert len(snapshot)==len(saved)
 for rec in snapshot:
  for key in ('finalSHA256','proofsSHA256','layoutIDs'):assert rec[key]==allowed[rec['stem']][key]
population=[(r['stem'],i) for r in snapshot for i in r['layoutIDs']]
assert len({i for _,i in population})==len(population)
receipts={r['stem']:r for r in snapshot};sources={};cache={}
def load(stem):
 if stem in cache:return cache[stem]
 receipt=receipts[stem]; result=[]
 for directory,key in [(B/'parts','finalSHA256'),(B/'proofs','proofsSHA256'),(A/'parts','sourceSHA256')]:
  path=directory/f'{stem}.jsonl.gz'; raw=path.read_bytes(); digest=sha(raw)
  assert digest==receipt[key],(path,key)
  sources[str(path.relative_to(ROOT))]=digest
  result.append({v['id']:v for v in map(json.loads,gzip.decompress(raw).splitlines())})
 cache[stem]=result;return result
# Uniform layout sampling without replacement, then uniform nonempty B within each.
order=rng.sample(population,len(population)); samples=[];skipped=[]
for stem,id in order:
 final,proof,old=load(stem); f,t,o=final[id],proof[id],old[id]
 eligible=[c for c in f['candidates'] if c['top5']]
 if not eligible:skipped.append(id);continue
 c=rng.choice(eligible); oc=next(v for v in o['candidates'] if v['cellID']==c['cellID'])
 assert c['position']==oc['position'] and f['board']==o['board']
 routes={r['comboIndex']:r for r in f['routes']};roots={r['comboIndex']:r for r in t['roots']}
 oldrefs={q['comboIndex']:(i+1,q) for i,q in enumerate(oc['top5'])}
 pairs=[]
 for rank,q in enumerate(c['top5'],1):
  rootID=next(i for i in q['rootComboIndices'] if i in oldrefs)
  oldrank,oq=oldrefs[rootID];before=roots[rootID];after=routes[q['comboIndex']]
  assert before==P.compact(next(r for r in o['routes'] if r['comboIndex']==rootID))
  assert P.seq(before)==P.seq(after)
  assert q['angle']<=18+1e-6
  for route,ref in [(before,oq),(after,q)]:
   assert math.dist(route['trajectory2mm']['points'][-1][1:],route['cueStop'])<1e-6
   assert abs(P.C.independent_angle(route['cueStop'],c['position'],P.C.G.anchors()[ref['pocket']])-ref['angle'])<1e-4
  assert abs(after['velocity']-before['velocity'])<=.300001
  assert abs(after['spinX']-before['spinX'])<=.100001
  assert abs(after['spinY']-before['spinY'])<=.150001
  pairs.append(dict(rank=rank,oldRank=oldrank,before=before,after=after,beforeScore=oq,afterScore=q))
 samples.append(dict(id=id,stem=stem,board=f['board'],cellID=c['cellID'],position=c['position'],beforeCount=len(oc['top5']),afterCount=len(c['top5']),pairs=pairs))
 if len(samples)==5:break
g=P.C.D['geometry'];r=g['radius'];hx=g['length']/2;hz=g['width']/2;anchors=P.C.G.anchors()
fontManager.addfont('/Library/Fonts/Arial Unicode.ttf')
plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
names=['左上角袋','右上角袋','左下角袋','右下角袋','上中袋','下中袋']
colors=['#147cbd','#d87824','#268651','#965ac1','#c04572']
def table(ax,s):
 b=s['board'];ax.set_aspect('equal');ax.axis('off')
 ax.add_patch(Rectangle((-hx-.055,-hz-.055),2*hx+.11,2*hz+.11,color='#345d50'))
 ax.add_patch(Rectangle((-hx,-hz),2*hx,2*hz,color='#deebdc'))
 for p in g['pockets']:
  ax.add_patch(Polygon([(v['x'],v['z']) for v in p['lip']],color='#193c33'))
  ax.add_patch(Circle((p['center']['x'],p['center']['z']),p['radius'],color='#193c33'))
 p=g['pockets'][b['pocket']]['center'];ax.add_patch(Circle((p['x'],p['z']),.068,fill=False,ec='#ca9218',lw=2))
 ax.plot([b['object'][0],b['aim'][0]],[b['object'][1],b['aim'][1]],'--',color='#bd8719',lw=1.4)
 ax.set_xlim(-hx-.12,hx+.12);ax.set_ylim(hz+.15,-hz-.13)
def draw(ax,s,pair,which):
 table(ax,s);b=s['board'];t=pair[which];q=pair[which+'Score'];color='#697a88' if which=='before' else colors[pair['rank']-1]
 xy=[p[1:] for p in t['trajectory2mm']['points']]
 ax.plot([b['cue'][0],xy[0][0]],[b['cue'][1],xy[0][1]],':',color='#8b9b91',lw=1.2)
 ax.plot([p[0] for p in xy],[p[1] for p in xy],color=color,lw=1.9)
 for a,v in zip(xy,xy[1:]):
  if math.dist(a,v)>.17:ax.annotate('',xy=[a[j]+.65*(v[j]-a[j]) for j in range(2)],xytext=[a[j]+.5*(v[j]-a[j]) for j in range(2)],arrowprops=dict(arrowstyle='->',color=color,lw=1))
 for ev in t['trajectory2mm']['cushions']:
  xyrail=xy[ev['pointIndex']];ax.plot(*xyrail,'o',ms=3,color=color)
 a=anchors[q['pocket']];pos=s['position'];stop=t['cueStop']
 ax.plot([stop[0],pos[0],a[0]],[stop[1],pos[1],a[1]],'--',color='#43816d',lw=1.15,alpha=.8)
 ax.add_patch(Circle(stop,r,fc='white',ec=color,lw=1.7,zorder=8));ax.annotate('停',stop,xytext=(9,10),textcoords='offset points',color=color,fontsize=9)
 for p,fc,ec,label in [(b['cue'],'white','#284438','C'),(b['object'],'#efbd49','#8a6222','A'),(pos,'#208eb7','#0a6286','B')]:
  ax.add_patch(Circle(p,r,fc=fc,ec=ec,lw=1.3,zorder=10));ax.text(*p,label,ha='center',va='center',fontsize=8,color='white' if label=='B' else ec,zorder=11)
 label=f'优化前 · 原第{pair["oldRank"]}名' if which=='before' else f'优化后 · 第{pair["rank"]}名'
 ax.set_title(f'{label}  |  切角 {q["angle"]:.2f}°  |  S {q["score"]:.4f}\n组合 {t["comboIndex"]} · 第二球→{names[q["pocket"]]}',loc='left',fontsize=11,color=color)
 ax.text(-hx,hz+.12,f'杆速 {t["velocity"]:.3f} m/s · 打点({t["spinX"]:+.3f}, {t["spinY"]:+.3f}) · {len(P.seq(t))}库',fontsize=9,color='#43594d')
fig,axs=plt.subplots(5,2,figsize=(16,23),facecolor='#f8faf6')
for n,s in enumerate(samples):
 for col,which in enumerate(['before','after']):draw(axs[n,col],s,s['pairs'][0],which)
 axs[n,0].set_title(f'样本{n+1} · B{s["cellID"]} · {s["id"]}\n'+axs[n,0].get_title(loc='left'),loc='left',fontsize=10,color='#53665b')
fig.suptitle('五道随机两球题 · 优化后第一名与其原路线对比',fontsize=20,y=.995)
fig.subplots_adjust(left=.025,right=.98,top=.965,bottom=.02,hspace=.30,wspace=.07)
fig.savefig(OUT/'overview.png',dpi=120);plt.close(fig)
sections=[];summary=[]
for n,s in enumerate(samples,1):
 rows=[]
 for pair in s['pairs']:
  fig,axes=plt.subplots(1,2,figsize=(16,4.9),facecolor='#f8faf6')
  for ax,which in zip(axes,['before','after']):draw(ax,s,pair,which)
  fig.subplots_adjust(left=.02,right=.98,top=.85,bottom=.03,wspace=.065)
  name=f'sample-{n}-rank-{pair["rank"]}.png';fig.savefig(OUT/name,dpi=140);plt.close(fig)
  a=pair['beforeScore'];z=pair['afterScore'];rails='→'.join(map(str,P.seq(pair['after']))) or '无'
  rows.append(f'<article><h3>优化后第{pair["rank"]}名 ← 原第{pair["oldRank"]}名</h3><p>第二杆切角 {a["angle"]:.2f}° → {z["angle"]:.2f}° · S {a["score"]:.4f} → {z["score"]:.4f} · 库序 {rails}（保持一致）</p><a href="{name}" target="_blank"><img src="{name}" alt="样本{n}第{pair["rank"]}条原路线与优化路线比较"></a></article>')
  summary.append({'sample':n,'id':s['id'],'cellID':s['cellID'],'rank':pair['rank'],'oldRank':pair['oldRank'],'beforeAngle':a['angle'],'afterAngle':z['angle'],'beforeScore':a['score'],'afterScore':z['score'],'rails':P.seq(pair['after'])})
 sections.append(f'<section id="sample-{n}"><h2>样本 {n} / 5 · B{s["cellID"]}</h2><p>{s["id"]} · 中袋过滤后原推荐 {s["beforeCount"]} 条 → 网格优化后 {s["afterCount"]} 条</p>'+''.join(rows)+'</section>')
page='''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>18度网格优化 · 随机五题前后对比</title><style>body{margin:0;background:#f2f5f1;color:#203a30;font:16px system-ui,sans-serif}header,main{max-width:1500px;margin:auto;padding:24px}h1{font-size:29px}p{line-height:1.65;color:#53665b}nav{position:sticky;top:0;background:#fffef8ef;padding:12px;display:flex;gap:12px;z-index:5;justify-content:center;border-bottom:1px solid #ccd7ca}nav a{padding:10px 22px;border-radius:8px;background:#e2ece3;color:#214d3e;text-decoration:none}section{scroll-margin-top:80px;padding-top:12px}article{background:#f8faf6;border:1px solid #d4ddd2;border-radius:12px;margin:22px 0;padding:18px}article h3{margin:0}img{width:100%;height:auto}a{color:#147cbd}.note{background:#e7eee2;padding:16px;border-radius:9px}footer{padding:30px}</style><header><h1>18度网格优化 · 随机五题前后对比</h1><p>从已提交分片随机抽取5个不同初始球形，再各随机取一个有推荐的第二球位置。这里只展示已处理样本，全量仍在运行。</p><p class="note">左：实际搜索中心的原路线；右：优化后按P2 60分去重的前五。按来源配对，不是原第N名与新第N名直接对齐；同一原路线可能产生多个入选变体。原路线使用中袋过滤后的版本。S越小越好，排名并不单独按切角。</p><p>C＝初始母球，A＝第一目标球，B＝第二目标球；实线＝碰A后母球的2mm折线，灰点线＝首碰前连线，金虚线＝A的目标袋方向，绿虚线＝第二杆几何方向（非第二杆模拟轨迹）。白圈为母球停点。所有图比例、方向一致，点图可放大。</p></header><nav>'''+''.join(f'<a href="#sample-{i}">样本{i}</a>' for i in range(1,6))+'''</nav><main>'''+''.join(sections)+'''</main><footer><a href="overview.png" target="_blank">五题第一名总览</a> · <a href="verification.json">抽样与核验记录</a> · <a href="data.json">本次样本数据</a></footer></html>'''
(OUT/'index.html').write_text(page)
data={'seed':seed,'geometry':g,'samples':samples};(OUT/'data.json').write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')))
verification={'createdAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'seed':seed,'snapshotReceiptCount':len(snapshot),'snapshotLayoutCount':len(population),'receiptSnapshot':[{'stem':r['stem'],'finalSHA256':r['finalSHA256'],'proofsSHA256':r['proofsSHA256'],'layoutIDs':r['layoutIDs']} for r in snapshot], 'sampling':'uniform distinct completed layouts, then uniform nonempty B per layout; skip layout only if all Bs empty','skippedEmptyLayouts':skipped,'sourceSHA256':sources,'pairs':summary,'checks':{'bothCommittedSHAsAndStageASource':True,'actualRootMatched':True,'sameBoardAndB':True,'cushionCountAndSequence':True,'secondAngle18':True,'independentAngleRecomputed':True,'gridBounds':True,'noSimulation':True},'fullRunComplete':False}
(OUT/'verification.json').write_text(json.dumps(verification,ensure_ascii=False,indent=2))
(OUT/'README.md').write_text('# 18度网格优化：已完成分片随机五题预览\n\n'+f'抽样快照：{len(snapshot)}个已提交分片、{len(population)}个唯一布局。种子{seed}。\n\n每个布局随机选择一个有推荐的B，展示其优化后前五与实际来源原推荐；相同原推荐可重复出现。该预览不代表全量审计完成。\n\n核验两类提交SHA及A输入SHA、同布局/B、真实来源、相同库序、第二杆≤18°、停点及参数扰动边界。未重新模拟，未修改原库或App。数据与核验见data.json、verification.json；打开index.html查看全部对比，overview.png为五题第一名总览。\n')
served=ROOT/'output/two-ball-multi-position-top10-20261024/grid18-preview-five';served.mkdir(exist_ok=True)
for p in OUT.iterdir():
 if p.is_file():shutil.copy2(p,served/p.name)
print(json.dumps({'snapshotLayouts':len(population),'samples':[{'id':s['id'],'B':s['cellID'],'pairs':len(s['pairs'])} for s in samples],'firstPairs':[x for x in summary if x['rank']==1],'out':str(OUT)},ensure_ascii=False,indent=2))
