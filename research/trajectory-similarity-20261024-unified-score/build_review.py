"""Build a read-only trajectory score review from frozen research evidence."""
import ast
import bisect
import ctypes
import hashlib
import json
import math
import random
from collections import defaultdict
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / 'output/trajectory-score-review-20261024'
OUT.mkdir(exist_ok=True)
SOURCE = ROOT / 'output/two-ball-b42-dedup75-20261024/native-result.json'
native = json.loads(SOURCE.read_text())
source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
old_research = json.loads((HERE/'results.json').read_text())
assert source_hash == old_research['sourceSHA256']
methods = [('old','原评分','70% DTW + 30% Fréchet'),
           ('dtwOnly','纯 DTW','原平均 DTW 单独映射'),
           ('meanIntegral','p = 1','弧长加权平均'),
           ('p15','p = 1.5','弧长加权 1.5 阶平均'),
           ('p2','p = 2','弧长加权均方根')]
result_files = [('meanIntegral','mean-integral-results.json'),('p15','p15-results.json'),('p2','p2-results.json')]
results = {key:json.loads((HERE/f).read_text()) for key,f in result_files}
def pair_key(a,b): return '-'.join(map(str,sorted([a,b])))
pairs = {pair_key(p['a'],p['b']):dict(a=p['a'],b=p['b'],old=p['score'],
    dtwOnly=100*2**(-p['meanDTWCM']/20),dtwCM=p['meanDTWCM'],frechetCM=p['frechetCM']) for p in native['pairs']}
for key,data in results.items():
    assert len(data['allPairs'])==4278
    for p in data['allPairs']:
        q=pairs[pair_key(p['a'],p['b'])]
        assert abs(q['old']-p['old'])<1e-9
        q[key]=p[key]
for p in pairs.values():
    assert all(math.isfinite(p[k]) and 0<=p[k]<=100 for k,_,_ in methods)

def length(points): return sum(math.dist(a,b) for a,b in zip(points,points[1:]))
rows = {}
for r in native['rows']:
    points=[[p['position']['x']*100,p['position']['z']*100] for p in r['comparisonLine']]
    rows[str(r['comboIndex'])] = dict(id=r['comboIndex'],points=points,length=length(points),
        speed=r['velocity'],spinX=r['spinX'],spinY=r['spinY'],rails=r['cueMainRailsAfterContact'])
    assert math.dist(points[-1],[v*100 for v in r['comparisonFullStop']])<.0002

# Existing research implementation of the production mean-DTW / Frechet definitions.
subprocess.run(['xcrun','clang++','-O2','-std=c++17','-dynamiclib',str(ROOT/'research/trajectory-similarity-20261022/metrics.cpp'),'-o',str(OUT/'legacy-metrics.dylib')],check=True)
lib=ctypes.CDLL(str(OUT/'legacy-metrics.dylib'))
fn=lib.metrics
fn.argtypes=[ctypes.POINTER(ctypes.c_double),ctypes.c_int,ctypes.POINTER(ctypes.c_double),ctypes.c_int,ctypes.POINTER(ctypes.c_double)]
def resample(points,anchors=None):
    lengths=[0.]
    for a,b in zip(points,points[1:]): lengths.append(lengths[-1]+math.dist(a,b))
    total=lengths[-1]
    if total==0: return [points[0]]
    anchors=range(len(points)) if anchors is None else anchors
    samples=sorted(set([total*i/511 for i in range(512)]+[lengths[i] for i in anchors]))
    out=[]
    for s in samples:
        i=bisect.bisect_right(lengths,s)-1
        if i==len(points)-1: out.append(points[-1]);continue
        u=(s-lengths[i])/(lengths[i+1]-lengths[i])
        out.append([points[i][k]+u*(points[i+1][k]-points[i][k]) for k in [0,1]])
    return out
def legacy(a,b):
    aa=(ctypes.c_double*(2*len(a)))(*[v for p in a for v in p])
    bb=(ctypes.c_double*(2*len(b)))(*[v for p in b for v in p])
    out=(ctypes.c_double*6)();fn(aa,len(a),bb,len(b),out)
    return dict(old=100*2**(-(.7*out[1]+.3*out[0])/20),dtwOnly=100*2**(-out[1]/20),dtwCM=out[1],frechetCM=out[0])
native_rows={r['comboIndex']:r for r in native['rows']}
legacy_checks=[]
for a,b in [(237,235),(398,287),(237,236),(287,525),(493,507)]:
    def from_native(i):
        line=native_rows[i]['comparisonLine']
        return resample(rows[str(i)]['points'],[j for j,p in enumerate(line) if p.get('isEvent')])
    computed=legacy(from_native(a),from_native(b))
    delta=abs(computed['old']-pairs[pair_key(a,b)]['old'])
    assert delta<.0001,(a,b,delta)
    legacy_checks.append(dict(a=a,b=b,scoreDifference=delta))

tree=ast.parse((HERE/'p2.py').read_text())
cases=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='cases' for t in n.targets))
labels={
 'identical':('完全相同','两条 200 cm 直线重合。'),
 'half_missing':('同路，只走完一半','路线① 200 cm；路线②沿相同方向走 100 cm。'),
 'ten_percent_extension':('沿原方向多走 10%','路线① 200 cm；路线② 220 cm。'),
 'parallel_offset_20cm':('整条路线横向相隔 20 cm','两条均长 200 cm，方向相同。'),
 'reverse_200cm':('同一路径，行进方向相反','空间位置重合，起点与终点交换。'),
 'same_start_opposite':('同起点，向相反方向走','两条均长 200 cm，分别向两侧延伸。'),
 'mid_detour_100cm':('中途多走 100 cm 往返','在 200 cm 直线中点，垂直走出 50 cm，再返回原路继续。'),
 'return_same_endpoint':('终点相同，额外往返一次','路线①走 200 cm；路线②走到终点、回起点、再走到终点，共 600 cm。'),
 'same_shape_insert_20cm_excursion':('中途增加 20 cm 小往返','在 400 cm 直线的 100 cm 处，垂直走出 10 cm 再返回。'),
 'stationary_same':('同点静止','两条轨迹均为同一个静止点。'),
 'stationary_offset_20cm':('静止点相隔 20 cm','两条轨迹均不移动，位置相隔 20 cm。'),
 'stationary_vs_200cm':('静止与走出 200 cm','起点相同，路线①静止，路线②走出 200 cm。')}
synthetic=[]
for name,(a,b) in cases.items():
    score=legacy(resample(a),resample(b))
    score.update({key:d['synthetic'][name] for key,d in results.items()})
    synthetic.append(dict(id=name,title=labels[name][0],description=labels[name][1],
       first=dict(id='①',points=a,length=length(a)),second=dict(id='②',points=b,length=length(b)),scores=score))
presets=[(237,235,'你指出的尾段差异'),(398,287,'前十中的第一组'),(237,236,'相同打点的另一组'),
 (287,525,'另一组路线对照'),(493,507,'短行程对照'),(263,261,'p=2 与原评分差值较大'),
 (70,143,'p=2 比原评分低'),(398,183,'另一组长短路线')]
# Keep the original review cases; cover every trajectory, then sample diverse
# score/length/disagreement strata. This is a review set, not a population sample.
rng=random.Random(20261024)
selected={pair_key(a,b) for a,b,_ in presets}
covered={i for a,b,_ in presets for i in (a,b)}
pool=sorted(pairs.values(),key=lambda p:(p['a'],p['b']))
rng.shuffle(pool)
def add_preset(p):
    a,b=p['a'],p['b']
    ra,rb=rows[str(a)],rows[str(b)]
    presets.append((a,b,f"{ra['length']/100:.2f} / {rb['length']/100:.2f} m · {ra['rails']} / {rb['rails']} 库"))
    selected.add(pair_key(a,b));covered.update((a,b))
while len(covered)<len(rows):
    p=max((p for p in pool if pair_key(p['a'],p['b']) not in selected),
          key=lambda p:len({p['a'],p['b']}-covered))
    add_preset(p)
buckets=defaultdict(list)
for p in pool:
    if pair_key(p['a'],p['b']) in selected:continue
    longest=max(rows[str(p['a'])]['length'],rows[str(p['b'])]['length'])
    spread=max(p[k] for k,_,_ in methods)-min(p[k] for k,_,_ in methods)
    bucket=(min(9,int(p['old']//10)),0 if longest<100 else 1 if longest<300 else 2,
            0 if spread<10 else 1 if spread<25 else 2)
    buckets[bucket].append(p)
bucket_keys=sorted(buckets);rng.shuffle(bucket_keys)
while len(presets)<200:
    for k in bucket_keys:
        if buckets[k]:add_preset(buckets[k].pop())
        if len(presets)==200:break
assert len(selected)==len(presets)==200
assert covered=={int(i) for i in rows}
geo=json.loads((ROOT/'output/two-ball-object-distance-sampled-20261024/object-distance-sampled-bank.json').read_text())['geometry']
board=native['board'];board_cm={k:([v*100 for v in value] if k in ['cue','object','aim'] else value) for k,value in board.items()}
dedup=json.loads((ROOT/'output/two-ball-b42-dedup75-20261024/dedup-result.json').read_text())
geometry=dict(length=geo['length']*100,width=geo['width']*100,radius=geo['radius']*100,
 pockets=[dict(center=[p['center']['x']*100,p['center']['z']*100],radius=p['radius']*100,
 lip=[[q['x']*100,q['z']*100] for q in p['lip']]) for p in geo['pockets']])
payload=dict(methods=methods,rows=rows,pairs=pairs,presets=[dict(a=a,b=b,title=t) for a,b,t in presets],
 synthetic=synthetic,board=board_cm,secondBall=[v*100 for v in dedup['position']],geometry=geometry,
 sourceHash=source_hash,scope='B42 · 同一初始球形 · 93 条真实轨迹 / 4,278 对比较',
 sampling='真实案例：候选公式为 1 cm 网格；构造对照为 0.25 cm 网格。统一 20 cm 评分尺度。')
(OUT/'data.json').write_text(json.dumps(payload,ensure_ascii=False,separators=(',',':')))
template=(HERE/'review-template.html').read_text()
(OUT/'index.html').write_text(template.replace('__DATA__',json.dumps(payload,ensure_ascii=False,separators=(',',':')).replace('</','<\\/')))

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle,Rectangle,Polygon
from matplotlib.font_manager import fontManager
fontManager.addfont('/Library/Fonts/Arial Unicode.ttf')
plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
COLORS=['#146b9a','#bf5928'];BG='#f7f8f5';INK='#243d35'
def table(ax):
    hx=geometry['length']/2;hz=geometry['width']/2
    ax.add_patch(Rectangle((-hx-6,-hz-6),2*hx+12,2*hz+12,color='#375f50'))
    ax.add_patch(Rectangle((-hx,-hz),2*hx,2*hz,color='#dfebd9'))
    for p in geometry['pockets']:
        ax.add_patch(Polygon(p['lip'],color='#173e33'));ax.add_patch(Circle(p['center'],p['radius'],color='#173e33'))
    ax.add_patch(Circle(geometry['pockets'][board['pocket']]['center'],6.5,fill=False,ec='#b07c20',lw=1.8))
    for pt,text,fc,ec in [(board_cm['cue'],'C','#fff','#65796c'),(board_cm['object'],'A','#e9c166','#977329'),(payload['secondBall'],'B42','#fff6df','#a18b55')]:
        ax.add_patch(Circle(pt,geometry['radius'],fc=fc,ec=ec,lw=.9,zorder=5));ax.text(*pt,text,ha='center',va='center',fontsize=6,color=ec,zorder=6)
    ax.set_xlim(-143,143);ax.set_ylim(80,-80);ax.set_aspect('equal');ax.axis('off')
def trajectory(ax,row,index):
    p=row['points'];color=COLORS[index]
    ax.plot(*zip(*p),color=color,lw=2.0,ls='-' if index==0 else (0,(5,3)),zorder=7)
    lengths=[0.]
    for a,b in zip(p,p[1:]):lengths.append(lengths[-1]+math.dist(a,b))
    for frac in [.25,.55,.8]:
        i=max(0,bisect.bisect_left(lengths,max(0,lengths[-1]*frac-2)))
        j=min(len(p)-1,bisect.bisect_left(lengths,min(lengths[-1],lengths[-1]*frac+2)))
        if j>i:ax.annotate('',xy=p[j],xytext=p[i],arrowprops=dict(arrowstyle='->',color=color,lw=1.3),zorder=8)
    ax.plot(*p[0],marker='o',ms=4,color=color,zorder=9)
    ax.plot(*p[-1],marker='o' if index==0 else 's',ms=8,mfc='white',mec=color,mew=1.6,zorder=10)
def score_strip(fig,y,score):
    for i,(key,label,_) in enumerate(methods):
        x=.07+i*.187
        fig.text(x,y,label,fontsize=12,color='#62736b')
        fig.text(x,y-.045,f'{score[key]:.1f}',fontsize=26,color=INK,weight='bold')
def feature(a,b):
    first,second=rows[str(a)],rows[str(b)];score=pairs[pair_key(a,b)]
    fig=plt.figure(figsize=(13,11),facecolor=BG)
    fig.text(.055,.958,f'轨迹评分对照  ·  {a} / {b}',fontsize=24,color=INK,weight='bold')
    fig.text(.055,.919,'蓝色实线 / 圆形终点 = ①    橙色虚线 / 方形终点 = ②    只比较碰第一球后的母球轨迹',fontsize=11,color='#5d7166')
    ax=fig.add_axes([.04,.43,.92,.47]);table(ax);trajectory(ax,first,0);trajectory(ax,second,1)
    score_strip(fig,.415,score)
    for i,r in enumerate([first,second]):
        ax=fig.add_axes([.04+i*.48,.105,.44,.23]);table(ax);trajectory(ax,r,i)
        fig.text(.065+i*.48,.322,f"{['①','②'][i]} 组合 {r['id']} · 长 {r['length']/100:.2f} m · {r['rails']} 库",fontsize=12,color=COLORS[i])
        fig.text(.065+i*.48,.09,f"杆速 {r['speed']:.3f} m/s  ·  打点 ({r['spinX']:+.3f}, {r['spinY']:+.3f})",fontsize=10,color='#5d7166')
    fig.text(.055,.045,'同一组轨迹，五种评分；越高越相似。候选为离线研究结果，App 评分未改。',fontsize=10,color='#5d7166')
    fig.savefig(OUT/'focus-237-235.png',dpi=150);plt.close(fig)
feature(237,235)
fig=plt.figure(figsize=(14,17),facecolor=BG)
fig.text(.05,.974,'五组真实轨迹 · 同图对比分值',fontsize=24,color=INK,weight='bold')
fig.text(.05,.949,'蓝色实线 / 圆形终点 = ①    橙色虚线 / 方形终点 = ②    各球桌比例一致',fontsize=11,color='#5d7166')
for row,(a,b,label) in enumerate(presets[:5]):
    y=.74-row*.177
    ax=fig.add_axes([.035,y,.53,.17]);table(ax);trajectory(ax,rows[str(a)],0);trajectory(ax,rows[str(b)],1)
    ax=fig.add_axes([.62,y+.014,.33,.139]);p=pairs[pair_key(a,b)]
    ax.barh(range(5),[p[k] for k,_,_ in methods],color=['#7d8d84','#9bb0a3','#8fa6b0','#608a9b','#386879'],height=.58)
    ax.set_yticks(range(5),[v for _,v,_ in methods],fontsize=10);ax.invert_yaxis();ax.set_xlim(0,110);ax.set_xticks([]);ax.tick_params(axis='y',length=0)
    for i,(k,_,_) in enumerate(methods):ax.text(p[k]+1.5,i,f'{p[k]:.1f}',va='center',fontsize=11,color=INK)
    for spine in ax.spines.values():spine.set_visible(False)
    ax.set_facecolor(BG)
    fig.text(.055,y+.165,f'{row+1:02}   {a} / {b} · {label}',fontsize=13,color=INK)
fig.text(.05,.024,'全部比较使用碰球后原始轨迹；候选为数值近似，统一 20 cm 尺度。完整图册支持 93 条轨迹任意两两对比。',fontsize=10,color='#5d7166')
fig.savefig(OUT/'five-pairs.png',dpi=145);plt.close(fig)
validation=dict(realTrajectories=len(rows),realPairs=len(pairs),syntheticCases=len(synthetic),
    reviewCases=len(presets),uniqueReviewPairs=len(selected),reviewTrajectoryCoverage=len(covered),
    reviewSelection='Original 8 retained; all 93 trajectories covered; round-robin score/length/score-spread strata, seed 20261024. Not a random population sample.',
    scoreFields=[k for k,_,_ in methods],sourceSHA256=source_hash,sourceUnchanged=hashlib.sha256(SOURCE.read_bytes()).hexdigest()==source_hash,
    sourceToDisplay='Full comparisonLine points preserved without simplification, independent shifts, rotation or scale normalization',legacyCrossChecks=legacy_checks)
(OUT/'validation.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2))
print(json.dumps(validation,ensure_ascii=False))
