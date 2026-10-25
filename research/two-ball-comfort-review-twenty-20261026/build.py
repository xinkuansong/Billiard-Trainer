"""Read-only, deterministic stratified review of completed comfort85 results."""
from pathlib import Path
import sys,json,gzip,hashlib,importlib.util,collections,html,shutil
ROOT=Path(__file__).resolve().parents[2]
def load(name,path):
 s=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
E=load('review_engine',ROOT/'research/two-ball-comfort-refine-full-20261025/engine.py')
sys.path.insert(0,str(ROOT/'research/two-ball-middle-geometry-comfort-20261025'))
V=load('review_visual',ROOT/'research/two-ball-middle-geometry-comfort-20261025/preview_below85.py')
import numpy as np
import matplotlib.pyplot as plt
from PIL import Image,ImageOps,ImageDraw
OUT=ROOT/'output/two-ball-comfort-review-twenty-20261026';OUT.mkdir(exist_ok=True)
SRC=E.OUT;OLD=E.SOURCE;SEED=20261026
SPECS=[('original','原版已合格',4),('optimized','微调后达标',4),('mixed','本路线未达标，但同题有合格路线',2),('failed','整题仍无85分路线',2),('rail','贴近库边（球面离库≤5cm）',3),('multi','多库路线（至少3库）',3),('angle','较大切角（至少25°）',2)]
STATUS={'originalQualified':'原版合格 · 原样保留','optimizedQualified':'微调达标','unqualifiedOriginalRetained':'未达标 · 保留原路线'}
FIELDS=V.FIELDS+['totalScore'];read=E.read;sha=E.sha;write=E.write

def rows(p):
 with gzip.open(p,'rt') as f:return [json.loads(l) for l in f]
def key(*v):return hashlib.sha256(json.dumps([SEED,*v],ensure_ascii=False).encode()).hexdigest()
def scan():
 summary=read(SRC/'summary.json');assert summary['state']=='complete' and summary['auditPassed']
 idx=read(SRC/'parts-index.json');pools={k:[] for k,_,_ in SPECS};counts=collections.Counter();ids=set();bs=0
 for num,part in enumerate(idx,1):
  p=SRC/'final'/f'{part["stem"]}.jsonl.gz';assert sha(p)==part['finalSHA256']
  data=rows(p);assert [x['id'] for x in data]==part['layoutIDs']
  for row in data:
   assert row['id'] not in ids;ids.add(row['id']);routes={r['comboIndex']:r for r in row['routes']}
   for c in row['candidates']:
    bs+=1;qs=c['top5'];best=max((q['comfort']['totalScore'] for q in qs),default=-1);matches=collections.defaultdict(list)
    for j,q in enumerate(qs):
     a=q['comfort'];st=q['refinementStatus'];r=routes[q['comboIndex']]
     if st=='originalQualified':matches['original'].append(j)
     if st=='optimizedQualified':matches['optimized'].append(j)
     if st=='unqualifiedOriginalRetained':matches['mixed' if best>=85 else 'failed'].append(j)
     if a['gapMeters']<=.05:matches['rail'].append(j)
     if len(E.P.seq(r))>=3:matches['multi'].append(j)
     if a['angleDegrees']>=25:matches['angle'].append(j)
    for group,js in matches.items():
     counts[group]+=1;focus=min(js,key=lambda j:key(group,row['id'],c['cellID'],qs[j]['comboIndex']))
     pools[group].append(dict(sort=key(group,row['id'],c['cellID']),stem=part['stem'],id=row['id'],cellID=c['cellID'],focus=focus))
  if num%200==0:print(f'Scanned {num}/{len(idx)} shards',flush=True)
 assert len(ids)==13570 and bs==173577
 selected=[];used=set()
 for group,label,n in SPECS:
  take=[s for s in sorted(pools[group],key=lambda x:x['sort']) if s['id'] not in used][:n]
  # Unique initial layouts, including within each stratum.
  take=[]
  for s in sorted(pools[group],key=lambda x:x['sort']):
   if s['id'] in used:continue
   take.append(s);used.add(s['id'])
   if len(take)==n:break
  assert len(take)==n
  selected.extend([dict(s,stratum=group,label=label) for s in take])
 for i,s in enumerate(selected,1):s['number']=i
 write(OUT/'selection.json',dict(seed=SEED,method='SHA256 deterministic question-level ranks within strata; exclude already selected initial layouts; strata overlap in population',eligibleQuestions=counts,specs=SPECS,samples=selected,summarySHA256=sha(SRC/'summary.json'),partsIndexSHA256=sha(SRC/'parts-index.json'),scannedLayouts=len(ids),scannedB=bs,allFinalShardSHA256Verified=True))

def plot(g,s,pair,j):
 n=s['number'];a=pair['before'];b=pair['after'];old=pair['oldRoute'];new=pair['route'];seq=pair['rails'];status=STATUS[pair['status']]
 fig=plt.figure(figsize=(17,9.6),facecolor=V.BG)
 fig.suptitle(f'样本 {n} · 推荐 {j+1} · {status}   |   {a["totalScore"]:.1f} → {b["totalScore"]:.1f} 分',fontsize=20,y=.98)
 fig.text(.04,.915,f'{s["label"]}  ·  B{s["cellID"]} → {V.NAMES[pair["pocket"]]}  ·  库序 {" → ".join(map(str,seq)) or "无库"}（前后一致）',fontsize=13)
 for x,r,q,title in [(.03,old,a,f'原版 · 原推荐第{pair["originalRank"]+1}条'),(.52,new,b,f'最终 · 推荐第{j+1}条')]:
  ax=fig.add_axes([x,.43,.45,.43]);V.table(ax,g,dict(score=q,position=s['position'],board=s['board'],route=r));ax.set_title(title,fontsize=14)
  fig.text(x+.01,.405,f'速度 {r["velocity"]:.3f} m/s   左右塞 {r["spinX"]:+.3f}   高低杆 {r["spinY"]:+.3f}',fontsize=12)
 ax=fig.add_axes([.04,.19,.92,.17]);ax.axis('off')
 cells=[]
 for label,q in [('原版',a),('最终',b)]:cells.append([label,*[f'{q[k]:.1f}' for k in FIELDS],f'{q["distanceMeters"]*100:.1f}',f'{q["gapMeters"]*100:.2f}',f'{q["angleDegrees"]:.2f}°'])
 tab=ax.table(cellText=cells,colLabels=['阶段','球距分','出杆空间分','角度分','总分','母球到B / cm','球面离库 / cm','第二杆切角'],cellLoc='center',loc='center');tab.auto_set_font_size(False);tab.set_fontsize(12);tab.scale(1,2)
 fig.text(.04,.15,f'同题最终 {len(s["pairs"])} 条路线，{s["qualified"]} 条≥85分；最高 {s["best"]:.1f} 分。布局 {s["id"]}',fontsize=11)
 fig.text(.04,.10,'蓝实线：保存的碰A后母球轨迹；红圈：停点；红虚线：第二杆瞄准方向；橙圈/虚线：B的目标袋与进球方向。',fontsize=11)
 fig.text(.04,.05,'C₀与A仅为初始位置参考，第二杆时A已入袋。总分为三项等权几何平均，不是进球概率。未达标展示保留原路线。',fontsize=11,color=V.GREEN)
 name=f'sample-{n}-route-{j+1}'
 fig.savefig(OUT/f'{name}.png',dpi=120);fig.savefig(OUT/f'{name}.svg');plt.close(fig)
 return name

def render():
 selection=read(OUT/'selection.json');idx={p['stem']:p for p in read(SRC/'parts-index.json')};g=read(OLD/'geometry.json');samples=[];hashes={};checks=0
 assert sha(SRC/'summary.json')==selection['summarySHA256'] and sha(SRC/'parts-index.json')==selection['partsIndexSHA256']
 for pick in selection['samples']:
  part=idx[pick['stem']];loaded={}
  for tag,base,folder,h in [('new',SRC,'final','finalSHA256'),('old',OLD,'final','sourceSHA256'),('scores',OLD,'scores','scoresSHA256')]:
   p=base/folder/f'{pick["stem"]}.jsonl.gz';digest=sha(p);assert digest==part[h];hashes[str(p)]=digest;loaded[tag]=next(r for r in rows(p) if r['id']==pick['id'])
  new,old,sc=[loaded[k] for k in ['new','old','scores']];assert new['board']==old['board']
  c=next(c for c in new['candidates'] if c['cellID']==pick['cellID']);oc=next(c for c in old['candidates'] if c['cellID']==pick['cellID']);ss=next(c for c in sc['candidates'] if c['cellID']==pick['cellID']);assert c['position']==oc['position']==ss['position']
  rr={r['comboIndex']:r for r in new['routes']};oo={r['comboIndex']:r for r in old['routes']};pairs=[]
  for q in c['top5']:
   root=q['rootComboIndex'];pocket=q['pocket'];a=next(z for z in ss['recommendations'] if z['comboIndex']==root and z['pocket']==pocket);ref=oc['top5'][q['originalRank']];assert ref['comboIndex']==root and ref['pocket']==pocket
   o=oo[root];r=rr[q['comboIndex']];b=dict(q['comfort'],stop=r['cueStop'],pocket=pocket);assert a['stop']==o['cueStop'];assert E.P.seq(o)==E.P.seq(r)
   for route,score in [(o,a),(r,b)]:
    assert np.max(np.abs(np.array(route['trajectory2mm']['points'])[-1,1:3]-score['stop']))<1e-6
    values=E.audit.recompute(g,np.array([score['stop']]),np.array([c['position']]),np.array([pocket]))[0]
    assert np.max(np.abs(values-np.array([score[k] for k in FIELDS])))<1e-8
   st=q['refinementStatus']
   if st=='optimizedQualified':
    assert a['totalScore']<85<=b['totalScore'];assert abs(r['velocity']-o['velocity'])<=.300001 and abs(r['spinX']-o['spinX'])<=.100001 and abs(r['spinY']-o['spinY'])<=.150001
   else:
    assert all(r[k]==o[k] for k in ['velocity','spinX','spinY','cueStop','trajectory2mm']);assert (a['totalScore']>=85)==(st=='originalQualified')
   pairs.append(dict(before=a,after=b,oldRoute=o,route=r,status=st,pocket=pocket,originalRank=q['originalRank'],rails=list(E.P.seq(r))));checks+=1
  s=dict(pick,position=c['position'],board=new['board'],pairs=pairs,qualified=sum(p['after']['totalScore']>=85 for p in pairs),best=max(p['after']['totalScore'] for p in pairs))
  for j,pair in enumerate(pairs):pair['image']=plot(g,s,pair,j)
  samples.append(s);print(f'Rendered sample {s["number"]}: {len(pairs)} routes',flush=True)
 write(OUT/'data.json',dict(samples=samples,geometry=g));write(OUT/'verification.json',dict(passed=True,questions=len(samples),uniqueLayouts=len({s['id'] for s in samples}),routePairs=checks,sourceHashes=hashes,allFinalRecommendationsShown=True,independentScores=True,sameRailOrder=True,originalPreservation=True,endpointMatches=True,newPhysicsRuns=0,corpusChanged=False))
 build_html(samples)
 for start in range(0,20,5):
  canvas=Image.new('RGB',(1020,5*590),'#f6f8f1')
  for off,s in enumerate(samples[start:start+5]):
   im=Image.open(OUT/(s['pairs'][s['focus']]['image']+'.png'));im.thumbnail((1020,590));canvas.paste(im,(0,off*590))
  canvas.save(OUT/f'overview-{start//5+1}.png')
 (OUT/'README.md').write_text('# 舒适度85分全量结果 · 20题分层抽检\n\n固定种子20261026，20个不同初始布局，每题展示全部最终推荐与对应原路线。分层覆盖见selection.json；分层有重叠，样本比例不代表总体比例。\n\n全部'+str(checks)+'对轨迹通过来源SHA、身份、库序、停点与独立分项复算核对。沿用全量深度审计，不新增物理模拟；未改原库、最终库及App。\n\n在线预览：http://127.0.0.1:51240/comfort-review-twenty/\n')
 served=ROOT/'output/two-ball-multi-position-top10-20261024/comfort-review-twenty';served.mkdir(exist_ok=True)
 for p in OUT.iterdir():
  if p.is_file():shutil.copy2(p,served/p.name)
 print('DONE',checks,flush=True)

def build_html(samples):
 cards=[]
 for s in samples:
  n=s['number'];focus=s['focus'];panels=[];opts=[];trs=[]
  for j,p in enumerate(s['pairs']):
   a=p['before'];b=p['after'];status=STATUS[p['status']];im=p['image'];opts.append(f'<option value="{j}" {"selected" if j==focus else ""}>推荐{j+1} · {status} · {a["totalScore"]:.1f} → {b["totalScore"]:.1f}</option>')
   panels.append(f'<div class="route" data-route="{j}" {"hidden" if j!=focus else ""}><a href="{im}.svg" target="_blank"><img loading="lazy" src="{im}.png" alt="样本{n}推荐{j+1}原版与最终路线及分项对比"></a></div>')
   vals=''.join(f'<td>{a[k]:.1f} → {b[k]:.1f}</td>' for k in FIELDS)
   trs.append(f'<tr><td>{j+1}</td><td>{status}</td>{vals}<td>{V.NAMES[p["pocket"]]}</td><td>{" → ".join(map(str,p["rails"])) or "无库"}</td></tr>')
  result=f'{s["qualified"]}/{len(s["pairs"])} 条路线≥85分；同题最高 {s["best"]:.1f}分'
  cards.append(f'<section id="sample-{n}"><h2>{n:02} · {s["label"]}</h2><p class="result">{result}</p><label>查看本题路线 <select aria-label="样本{n}的推荐路线" onchange="choose(this)">{"".join(opts)}</select></label>{"".join(panels)}<div class="scroll"><table><thead><tr><th>推荐</th><th>处理结果</th><th>球距分</th><th>空间分</th><th>角度分</th><th>总分</th><th>B目标袋</th><th>库序</th></tr></thead><tbody>{"".join(trs)}</tbody></table></div><small>布局 {html.escape(s["id"])} · B{s["cellID"]} · 原版合格优先；推荐序号沿用最终库顺序，未按舒适度重新排序。</small></section>')
 page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>20题分层抽检 · 舒适度85分</title><style>*{box-sizing:border-box}body{margin:0;background:#f6f8f1;color:#243f32;font:17px/1.7 system-ui}main{max-width:1550px;margin:auto;padding:24px}header{max-width:1000px}h1{font-size:34px;line-height:1.3}nav{position:sticky;top:0;background:#f6f8f1f5;z-index:10;padding:10px 24px;display:flex;flex-wrap:wrap;gap:8px;border-bottom:1px solid #cad7c6}nav a{padding:2px 8px}a{color:#276b55}section{scroll-margin-top:115px;background:white;margin:28px 0;padding:22px;border:1px solid #ccd8c9;border-radius:14px}h2{margin:0}img{display:block;width:100%;height:auto}.result{font-weight:600}select{padding:10px;font:inherit;max-width:100%;border:1px solid #aebfac;border-radius:8px;background:#f6f8f1;color:#243f32}table{border-collapse:collapse;width:100%;font-size:14px;white-space:nowrap}td,th{padding:10px;border:1px solid #ccd8c9;text-align:center}th{background:#eff4eb}td:nth-child(6){font-weight:bold}.scroll{overflow:auto}small{color:#5a7060}label{display:block;margin:12px 0}a:focus-visible,select:focus-visible{outline:3px solid #df9b23} @media(max-width:650px){main,section{padding:10px}h1{font-size:27px}h2{font-size:21px}nav{padding:8px;gap:2px}}</style><nav>'''+''.join(f'<a href="#sample-{s["number"]}">{s["number"]:02}</a>' for s in samples)+'''</nav><main><header><h1>20题分层抽检</h1><p>查看全量微调后的真实轨迹，判断是否舒服、是否保留了原走位意图。每题可切换全部最终推荐，左右对照它各自对应的原路线。</p><p><b>8题常规对照：</b>原版合格4题、微调达标4题。<b>12题重点边界：</b>单条未达标但同题有合格2题、整题无合格2题、贴库3题、多库3题、大切角2题。</p><p>蓝线为已保存轨迹，红圈为停点。三项等权几何平均；角度≤15°满分，无18°硬门槛。未达标路线展示保留的原版。分层种子20261026，20个不同初始布局；样本比例不代表总体比例。本次仅抽检，不筛选、不改题库。</p></header>'''+''.join(cards)+'''<p><a href="selection.json">抽样记录</a> · <a href="verification.json">核验记录</a> · <a href="data.json">完整对比数据</a></p></main><script>function choose(el){const section=el.closest('section');section.querySelectorAll('.route').forEach(p=>p.hidden=p.dataset.route!==el.value)}</script></html>'''
 (OUT/'index.html').write_text(page)

if __name__=='__main__':
 if '--render' not in sys.argv:scan()
 render()
