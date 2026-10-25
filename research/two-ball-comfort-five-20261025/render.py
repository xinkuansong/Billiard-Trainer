"""Comfort-region preview only. Reads frozen Stage A originals, never simulates."""
from pathlib import Path
import sys,json,gzip,hashlib,math,html,shutil
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle,Rectangle,Polygon
from matplotlib.colors import ListedColormap
from matplotlib.font_manager import fontManager
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/two-ball-comfort-five-20261025';OUT.mkdir(exist_ok=True)
sys.path.insert(0,str(ROOT/'research/two-ball-middle-grid18-20261025'))
import pipeline as P
preview=ROOT/'output/two-ball-grid18-preview-five-20261025'
prior=json.loads((preview/'data.json').read_text());verified=json.loads((preview/'verification.json').read_text())
g=prior['geometry'];R=g['radius'];hx=g['length']/2;hz=g['width']/2;anchors=P.C.G.anchors()
H=.002; x=np.arange(-hx,hx+H/2,H);z=np.arange(-hz,hz+H/2,H);X,Z=np.meshgrid(x,z)
clearance=np.minimum(hx-np.abs(X),hz-np.abs(Z))-R
TIERS=[(.40,.08,'正常档：球距40–100cm / 离库≥8cm'),(.30,.08,'受限档1：球距30–100cm / 离库≥8cm'),(.20,.08,'受限档2：球距20–100cm / 离库≥8cm'),(.20,.05,'受限档3：球距20–100cm / 离库≥5cm')]
names=['左上角袋','右上角袋','左下角袋','右下角袋','上中袋','下中袋']
fontManager.addfont('/Library/Fonts/Arial Unicode.ttf');plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
def scalar(c,b,p):
 return dict(distance=math.dist(c,b),railClearance=min(hx-abs(c[0]),hz-abs(c[1]))-R,angle=P.C.independent_angle(c,b,anchors[p]))
assert abs(scalar([-1,0],[0,0],1)['distance']-1)<1e-12
assert abs((min(hx-abs(hx-R-.08),hz)-R)-.08)<1e-12
# Verify ghost-based angles with independently recomputed scalar values below.
def region(b,p):
 a=anchors[p];n=np.array(a)-b;n=n/np.linalg.norm(n);ghost=np.array(b)-2*R*n
 vx=ghost[0]-X;vz=ghost[1]-Z
 angles=np.degrees(np.arctan2(np.abs(vx*n[1]-vz*n[0]),vx*n[0]+vz*n[1]))
 angleMargin=(vx*n[0]+vz*n[1])*math.sin(math.radians(18))-np.abs(vx*n[1]-vz*n[0])*math.cos(math.radians(18))
 distances=np.hypot(X-b[0],Z-b[1]);base=(angles<=18)&(distances<=1.)
 trials=[];chosen=None
 for i,(minimum,rail,label) in enumerate(TIERS):
  mask=base&(distances>=minimum)&(clearance>=rail)
  # Exact clearance from each sampled center to circle/half-plane boundaries.
  # A disk fits iff its radius fits every constraint; no raster erosion needed.
  margins=np.minimum(np.minimum(distances-minimum,1.-distances),np.minimum(clearance-rail,angleMargin))
  maxRadius=max(0,float(margins.max()))
  trials.append(dict(tier=i,minimum=minimum,rail=rail,areaM2=float(mask.sum()*H*H),inscribedRadiusApproxM=maxRadius))
  if maxRadius>=.03:
   chosen=(i,mask);break
 if chosen is None:chosen=(None,np.zeros_like(base))
 tier,mask=chosen
 for iz,ix in [(40,100),(150,250),(300,500)]:
  assert abs(scalar([float(X[iz,ix]),float(Z[iz,ix])],b,p)['angle']-float(angles[iz,ix]))<1e-8
 return tier,mask,mask&(distances>=.5)&(distances<=.8),trials
def table(ax,s,p):
 b=s['board'];ax.set_aspect('equal');ax.axis('off')
 ax.add_patch(Rectangle((-hx-.055,-hz-.055),2*hx+.11,2*hz+.11,color='#345d50',zorder=0))
 ax.add_patch(Rectangle((-hx,-hz),2*hx,2*hz,color='#eef2e6',zorder=1))
 for pocket in g['pockets']:
  ax.add_patch(Polygon([(v['x'],v['z']) for v in pocket['lip']],color='#193c33',zorder=3))
  ax.add_patch(Circle((pocket['center']['x'],pocket['center']['z']),pocket['radius'],color='#193c33',zorder=3))
 a=anchors[p];ax.plot([s['position'][0],a[0]],[s['position'][1],a[1]],'--',color='#267c69',lw=1.8,zorder=4)
 q=g['pockets'][p]['center'];ax.add_patch(Circle((q['x'],q['z']),.072,fill=False,ec='#24846d',lw=2.5,zorder=4))
 q=g['pockets'][b['pocket']]['center'];ax.add_patch(Circle((q['x'],q['z']),.063,fill=False,ec='#d5a334',lw=1.8,zorder=4))
 ax.plot([b['object'][0],b['aim'][0]],[b['object'][1],b['aim'][1]],':',color='#c49c47',lw=1,zorder=4)
 # Inset rectangle is deliberately conservative across pocket openings too.
 rail=TIERS[s['regions'][p]['tier']][1] if s['regions'][p]['tier'] is not None else .05
 inset=R+rail
 ax.add_patch(Rectangle((-hx+inset,-hz+inset),2*(hx-inset),2*(hz-inset),fill=False,ec='#aa8260',lw=1,ls='--',zorder=3))
 for pos,fc,ec,label in [(b['cue'],'#fff','#879b8e','C'),(b['object'],'#f7df9a','#bba16a','A'),(s['position'],'#208eb7','#0a6286','B')]:
  ax.add_patch(Circle(pos,R,fc=fc,ec=ec,lw=1.2,zorder=8));ax.text(*pos,label,ha='center',va='center',fontsize=10,color='white' if label=='B' else ec,zorder=9)
 ax.set_xlim(-hx-.12,hx+.12);ax.set_ylim(hz+.21,-hz-.14)
def plot(ax,s,p):
 table(ax,s,p);reg=s['regions'][p];mask,preferred=reg['mask'],reg['preferred']
 vals=np.where(preferred,2,np.where(mask,1,0)); ax.contourf(X,Z,vals,levels=[.5,1.5,2.5],colors=['#b6deaa','#6db887'],alpha=.85,zorder=2)
 if mask.any():ax.contour(X,Z,mask.astype(float),levels=[.5],colors=['#4a8863'],linewidths=.8,zorder=3)
 points=[q for q in s['routes'] if q['pocket']==p]
 for q in s['routes']:
  if q['pocket']!=p:ax.plot(*q['stop'],'o',mfc='none',mec='#aab1a9',ms=7,zorder=5)
 # Spread numbered labels vertically on a side of the stop cluster.
 sortedPoints=sorted(points,key=lambda q:q['stop'][1]);labels=np.linspace(-.16,.16,len(points)) if len(points)>1 else [0]
 meanZ=np.mean([q['stop'][1] for q in points]);labelZ=np.clip(meanZ+labels,-hz+.05,hz-.05)
 for q,lz in zip(sortedPoints,labelZ):
  c='#207a43' if q['accepted'] else '#bf493e';pt=q['stop']
  ax.plot(*pt,'o' if q['accepted'] else 'X',ms=9,mfc=c,mec='white',mew=1,zorder=10)
  lx=float(np.clip(pt[0]+(.23 if pt[0]<0 else -.23),-hx+.1,hx-.1))
  ax.annotate(str(q['rank']),pt,xytext=(lx,float(lz)),ha='center',va='center',fontsize=10,color=c,bbox=dict(boxstyle='round,pad=.20',fc='white',ec=c,lw=1),arrowprops=dict(arrowstyle='-',color=c,lw=.8),zorder=11)
 label=TIERS[reg['tier']][2] if reg['tier'] is not None else '所有放宽档均无足够区域'
 ax.set_title(f'B{s["cellID"]} → {names[p]}\n{label}',loc='left',fontsize=12,color='#264b3c')
 ax.text(-hx,hz+.18,'实心绿点＝已满足  红叉＝需调整  灰空圈＝选择其他袋的原停点',fontsize=9,color='#576c5c')
samples=[];sources={};allrows=[]
for n,oldsample in enumerate(prior['samples'],1):
 path=P.A/'parts'/f'{oldsample["stem"]}.jsonl.gz';raw=path.read_bytes();key=str(path.relative_to(ROOT));digest=hashlib.sha256(raw).hexdigest()
 assert digest==verified['sourceSHA256'][key];sources[key]=digest
 old=next(v for v in map(json.loads,gzip.decompress(raw).splitlines()) if v['id']==oldsample['id'])
 c=next(v for v in old['candidates'] if v['cellID']==oldsample['cellID']);routes={r['comboIndex']:r for r in old['routes']}
 s=dict(number=n,id=old['id'],board=old['board'],cellID=c['cellID'],position=c['position'],regions={},routes=[])
 for p in sorted({q['pocket'] for q in c['top5']}):
  tier,mask,pref,trials=region(c['position'],p);s['regions'][p]=dict(tier=tier,mask=mask,preferred=pref,trials=trials)
 for rank,q in enumerate(c['top5'],1):
  r=routes[q['comboIndex']];m=scalar(r['cueStop'],c['position'],q['pocket']);assert abs(m['angle']-q['angle'])<1e-6
  tier=s['regions'][q['pocket']]['tier'];minimum,rail=TIERS[tier][:2] if tier is not None else (.2,.05);reasons=[]
  if tier is None:reasons.append('该袋无足够区域')
  if m['angle']>18:reasons.append('切角超过18°')
  if m['distance']<minimum:reasons.append(f'球距小于{minimum*100:.0f}cm')
  if m['distance']>1:reasons.append('球距超过100cm')
  if m['railClearance']<rail:reasons.append(f'离库不足{rail*100:.0f}cm')
  row=dict(sample=n,rank=rank,comboIndex=q['comboIndex'],pocket=q['pocket'],stop=r['cueStop'],**m,tier=tier,accepted=not reasons,reasons=reasons)
  s['routes'].append(row);allrows.append(row)
 samples.append(s)
sections=[]
for s in samples:
 n=s['number'];panels=[]
 for p in s['regions']:
  fig,ax=plt.subplots(figsize=(12,7),facecolor='#f8faf5');plot(ax,s,p)
  fig.subplots_adjust(left=.025,right=.98,top=.88,bottom=.03);name=f'sample-{n}-pocket-{p}.png';fig.savefig(OUT/name,dpi=145);plt.close(fig)
  panels.append(f'<a href="{name}" target="_blank"><img src="{name}" alt="样本{n}第二球到{names[p]}的舒服区域及原停点"></a>')
 rows=[]
 for q in s['routes']:
  result='已满足，保留原路线' if q['accepted'] else '需优化：'+'；'.join(q['reasons'])
  rows.append(f'<tr><td>{q["rank"]}</td><td>{q["comboIndex"]}</td><td>{names[q["pocket"]]}</td><td>{q["angle"]:.2f}°</td><td>{q["distance"]*100:.1f}cm</td><td>{q["railClearance"]*100:.1f}cm</td><td class="{"yes" if q["accepted"] else "no"}">{result}</td></tr>')
 sections.append(f'<section id="sample-{n}"><h2>样本{n} · B{s["cellID"]}</h2><p>{s["id"]} · {sum(q["accepted"] for q in s["routes"])} / {len(s["routes"])} 条已满足</p><div class="plots">'+''.join(panels)+'</div><div class="table"><table><thead><tr><th>原排名</th><th>组合</th><th>第二球目标袋</th><th>切角</th><th>两球心距离</th><th>母球离库净距</th><th>判定</th></tr></thead><tbody>'+''.join(rows)+'</tbody></table></div></section>')
ok=sum(q['accepted'] for q in allrows)
page='''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>舒服区域 · 五题原停点检查</title><style>body{margin:0;background:#f1f4ed;color:#243f32;font:16px system-ui,sans-serif}header,main,footer{max-width:1500px;margin:auto;padding:24px}h1{font-size:30px}p,li{line-height:1.7}p{color:#526859}.note{padding:16px;background:#e2ebd9;border-radius:10px}nav{position:sticky;top:0;background:#fffff4f2;display:flex;gap:10px;padding:12px;justify-content:center;z-index:5}nav a{padding:10px 20px;background:#deeadb;border-radius:8px;color:#30523d;text-decoration:none}section{scroll-margin-top:80px;padding:24px 0;border-bottom:1px solid #cbd5c6}.plots{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(600px,100%),1fr));gap:15px}img{width:100%;height:auto;border-radius:10px}.table{overflow:auto}table{width:100%;border-collapse:collapse;background:white;margin:20px 0}th,td{padding:12px;border-bottom:1px solid #dae3d4;text-align:left;white-space:nowrap}.yes{color:#207a43;font-weight:650}.no{color:#b1463b}a{color:#26765d}</style><header><h1>舒服区域 · 五题原停点检查</h1>'''+f'<p class="note">同一批5题，共{len(allrows)}条原推荐：<strong>{ok}条已满足，{len(allrows)-ok}条需要优化。</strong> 原版＝已完成中袋过滤、尚未做18°网格优化的阶段A。按每条原推荐自己的目标袋判定，不自动换袋。</p>'+'''<p>浅绿＝合格区域；深绿＝其中球距50–80cm的优先区域。已在浅绿范围内的原路线也直接保留。绿点＝已满足；红叉＝需调整；数字＝原推荐排名。灰空圈属于本题其他袋口，不能按当前绿色区域判定。</p><p>C、A为首杆初始球位参考；A在第二杆前已进袋，不作为区域障碍。B为第二目标球；金圈为第一球袋口，绿圈和绿虚线为当前第二球袋口方向。棕色虚框为本档母球球心离库边界。</p><details><summary>距离口径、放宽规则与验证范围</summary><ul><li>正常球心距40–100cm，母球表面离库≥8cm，真实假想球切角≤18°；50–80cm只作偏好，不强迫优化。</li><li>放宽顺序：40cm/8cm → 30cm/8cm → 20cm/8cm → 20cm/5cm。只由B和指定袋口的空间决定，与某条路线能否到达无关。</li><li>沿用讨论中的3cm落点余量试验值：区域需容纳半径3cm小圆才视为有可用空间；以2mm空间网格保守检查。它用于选放宽档，不给原停点额外添加3cm硬门槛。</li><li>离库采用四边内缩的保守口径，袋口开口处也不放宽；尚未按球杆方向计算后方出杆净空。</li><li>绿色区域仅为几何候选区，不代表每一点都已通过中袋入袋验证。原推荐沿用阶段A已通过的验证；后续新落点仍须逐点验证中袋、第一杆途中碰B及库序等条件。</li><li>此页仅检查原停点，不执行新的物理模拟、不修改任何题库。</li></ul></details></header><nav>'''+''.join(f'<a href="#sample-{n}">样本{n}</a>' for n in range(1,6))+'''</nav><main>'''+''.join(sections)+'''</main><footer><a href="data.json">判定数据</a> · <a href="README.md">规则与记录</a></footer></html>'''
(OUT/'index.html').write_text(page)
serial=[]
for s in samples:
 serial.append({**{k:v for k,v in s.items() if k!='regions'},'regions':{p:{k:v for k,v in reg.items() if k not in ('mask','preferred')} for p,reg in s['regions'].items()}})
result=dict(policy=dict(angleMax=18,maxBallDistance=1,preferredDistance=[.5,.8],tiers=[{'minBallDistance':a,'railGap':b} for a,b,_ in TIERS],gridMeters=H,minRegionInradius=.03,pointMarginRequired=False,railMetric='conservative rectangular edge gap minus ball radius'),sourceSHA256=sources,samples=serial,total=len(allrows),accepted=ok,needsOptimization=len(allrows)-ok)
(OUT/'data.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
(OUT/'README.md').write_text('# 舒服区域五题预览\n\n'+f'原推荐{len(allrows)}条，几何已满足{ok}条，需优化{len(allrows)-ok}条。五题与此前随机预览相同，读取阶段A完整top5集合，不使用新版排名的来源子集。\n\n正常球心距40–100cm，优先50–80cm；母球表面至矩形库线净距≥8cm（袋口处亦保守内缩）；真实假想球切角≤18°。区域无足够空间时依序30cm/8cm、20cm/8cm、20cm/5cm。区域可用空间沿用讨论的半径3cm试验圆，2mm网格保守判定；不对原停点增加该余量硬门槛。\n\n每条原推荐按自身目标袋检查。原输入SHA与上轮核验记录一致，独立切角复算与原值一致；只读出图、无模拟、无题库修改。绿色区域是几何候选，不声称每点已通过物理入袋验证。库后球杆空间尚未验证。\n')
served=ROOT/'output/two-ball-multi-position-top10-20261024/comfort-five';served.mkdir(exist_ok=True)
for p in OUT.iterdir():
 if p.is_file():shutil.copy2(p,served/p.name)
print(json.dumps({k:v for k,v in result.items() if k not in ('samples','sourceSHA256')},ensure_ascii=False))
for s in serial:print(json.dumps({'sample':s['number'],'regions':s['regions'],'routes':s['routes']},ensure_ascii=False))
