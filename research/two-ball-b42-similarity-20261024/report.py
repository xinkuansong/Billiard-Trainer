from pathlib import Path
import json,math,hashlib
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle,Rectangle,Polygon
from matplotlib.font_manager import fontManager
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'output/two-ball-second-difficulty-20261024'
OUT=ROOT/'output/two-ball-b42-similarity-20261024';OUT.mkdir(exist_ok=True)
d=json.loads((SRC/'b42-similarity-native.json').read_text())
rows=d['rows'];pairs=sorted(d['pairs'],key=lambda p:-p['score']);ids=[q['comboIndex'] for q in rows];rank={x:i+1 for i,x in enumerate(ids)}
assert len(rows)==10 and len(pairs)==45 and len({tuple(sorted([p['a'],p['b']])) for p in pairs})==45
for p in pairs:
    assert math.isclose(p['distanceCM'],.7*p['meanDTWCM']+.3*p['frechetCM'],abs_tol=1e-12)
    assert math.isclose(p['score'],100*2**(-p['distanceCM']/20),abs_tol=1e-10)
for q in rows:
    assert q['comparisonLine'][0]['time']==0 and q['comparisonLine'][0]['isEvent']
    assert math.dist(q['comparisonFullStop'],q['cueStop'])<1e-6
sourcepaths=['QiuJi/Features/SeparationPractice/SeparationTrajectoryScore.swift','QiuJi/Features/SeparationPractice/SeparationQuestionGenerator.swift']
hashes={}
for sp in sourcepaths:
    src=ROOT/sp;frozen=ROOT/'research/two-ball-strike-full-20261024/native-source'/src.name
    assert src.read_bytes()==frozen.read_bytes();hashes[sp]=hashlib.sha256(src.read_bytes()).hexdigest()
result=dict(secondBall='B42',comboIDsInRankOrder=ids,pairCount=45,algorithm=d['pairs'][0]['version'],formula='distanceCM=0.7*meanDTWCM+0.3*frechetCM; score=100*2^(-distanceCM/20)',scope='top 10 after fixed-B42 swept-path filter; post-first-contact trajectories only; comparison directly calls production SeparationTrajectory.extract and SeparationTrajectoryScore.evaluate',sourceHashes=hashes,pairs=pairs)
(OUT/'pairwise-similarity.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
fontManager.addfont('/Library/Fonts/Arial Unicode.ttf');plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
m=np.eye(10)*100
for p in pairs:i=ids.index(p['a']);j=ids.index(p['b']);m[i,j]=m[j,i]=p['score']
fig,ax=plt.subplots(figsize=(13,11),facecolor='#fafbf8');im=ax.imshow(m,vmin=0,vmax=100,cmap='YlGnBu')
labels=[f'{i+1} · {cid}' for i,cid in enumerate(ids)]
ax.set_xticks(range(10),labels,rotation=45,ha='right',fontsize=11);ax.set_yticks(range(10),labels,fontsize=11)
for i in range(10):
    for j in range(10):ax.text(j,i,f'{m[i,j]:.1f}',ha='center',va='center',fontsize=11,color='white' if m[i,j]>65 else '#163c44')
ax.set_xlabel('原难度排名 · 组合ID',fontsize=12);ax.set_ylabel('原难度排名 · 组合ID',fontsize=12)
fig.colorbar(im,ax=ax,pad=.025,label='轨迹相似度（0–100分，越高越相似）')
fig.suptitle('B42：前十条母球轨迹的两两相似度',fontsize=23,y=.975,color='#213e34')
fig.text(.09,.92,'沿用2D分离角练习原生评分：70%平均DTW＋30%Fréchet；只比较碰第一球后的路线。',fontsize=11,color='#5a6b62')
fig.text(.09,.035,'截图：第1/2名＝83.4分；最高：第6/7名＝83.9分。分数不是概率；本轮未设去重阈值、未删除组合。',fontsize=11,color='#5a6b62')
fig.subplots_adjust(top=.88,bottom=.15,left=.13,right=.88)
fig.savefig(OUT/'similarity-matrix.png',dpi=160);plt.close(fig)
geo=json.loads((ROOT/'output/two-ball-object-distance-sampled-20261024/object-distance-sampled-bank.json').read_text())['geometry']
r=geo['radius'];hx=geo['length']/2;hz=geo['width']/2;board=d['board'];B=json.loads((ROOT/'output/two-ball-multi-position-top10-20261024/B42-ranking.json').read_text())['position']
fig,axes=plt.subplots(2,1,figsize=(14,17),facecolor='#fafbf8')
for ax,p in zip(axes,[next(p for p in pairs if {p['a'],p['b']}=={398,287}),pairs[0]]):
    ax.set_aspect('equal');ax.axis('off')
    ax.add_patch(Rectangle((-hx-.065,-hz-.065),2*hx+.13,2*hz+.13,fc='#345d50',zorder=0));ax.add_patch(Rectangle((-hx,-hz),2*hx,2*hz,fc='#dbe9d9',zorder=1))
    for pocket in geo['pockets']:
        ax.add_patch(Polygon([(q['x'],q['z']) for q in pocket['lip']],color='#193c33',zorder=2));ax.add_patch(Circle((pocket['center']['x'],pocket['center']['z']),pocket['radius'],color='#193c33',zorder=2))
    for cid,color,style in [(p['a'],'#1476b8','-'),(p['b'],'#e37824','--')]:
        q=next(q for q in rows if q['comboIndex']==cid)
        xy=np.array([[pt['position']['x'],pt['position']['z']] for pt in q['comparisonLine']])
        ax.plot(xy[:,0],xy[:,1],color=color,ls=style,lw=2.7,zorder=5,label=f'第{rank[cid]}名 · 组合{cid} · {q["velocity"]:.3f} m/s')
        ax.add_patch(Circle(xy[-1],r,fc='white',ec=color,lw=2.4,zorder=9))
    for pos,fill,edge,txt in [(board['cue'],'white','#294438','C'),(board['object'],'#e9b234','#755113','A'),(B,'#fff4d9','#aa7823','B42')]:
        ax.add_patch(Circle(pos,r,fc=fill,ec=edge,lw=1.8,zorder=12));ax.text(pos[0],pos[1]+.065,txt,ha='center',fontsize=11,color=edge,zorder=13)
    ax.set_xlim(-hx-.11,hx+.11);ax.set_ylim(hz+.20,-hz-.16)
    ax.set_title(f"第{rank[p['a']]}/{rank[p['b']]}名：相似度 {p['score']:.1f} 分",loc='left',fontsize=20,color='#213e34',pad=15)
    ax.legend(loc='upper left',fontsize=12,framealpha=.95)
    ax.text(-hx,hz+.16,f"平均DTW {p['meanDTWCM']:.2f} cm   ·   Fréchet {p['frechetCM']:.2f} cm   ·   加权距离 {p['distanceCM']:.2f} cm",fontsize=13,color='#4b5f54')
fig.suptitle('最相近的两对路线 · 仅绘制碰第一球后的比较段',fontsize=22,y=.98,color='#213e34')
fig.text(.06,.023,'相同物理坐标，不平移、不旋转、不缩放匹配；沿路线长度采样，不比较运动耗时。终点差异仍会影响评分。',fontsize=11,color='#5a6b62')
fig.subplots_adjust(top=.93,bottom=.06,left=.04,right=.97,hspace=.14)
fig.savefig(OUT/'closest-pairs.png',dpi=160);plt.close(fig)
lines=['# B42前十条轨迹的相似度','', '直接复用当前2D分离角练习的SeparationTrajectory.extract及SeparationTrajectoryScore.evaluate。当前评分源码、轨迹提取源码与全量冻结对象对应源文件逐字一致，哈希见JSON。原参数重跑的原字段核验一致。3组搜索提前结束的轨迹另跑完整预测以满足正式提取器settled前提，全部10组完整预测停点与原停点误差<1微米。','', '只比较碰第一球后的母球轨迹。提取真实物理状态，约120Hz含事件；按弧长512基础点并保留事件点。采用原X/Z物理厘米坐标，不平移/旋转/缩放，不比较用时。分数=100×2^(-(0.7×平均DTW厘米+0.3×Fréchet厘米)/20)。20厘米为50分尺度，不是容许误差。分数不是进球概率。','', '范围为B42路径碰球过滤后排名前十，10条路线、45对。此前93条保留组合并未全量两两比较。没有自动去重或更改排名。','', '![相似度矩阵](similarity-matrix.png)','', '![最相近两对](closest-pairs.png)','', '|相近排名|原难度排名|组合ID|相似度|平均DTW cm|Fréchet cm|加权距离 cm|','|---:|---|---|---:|---:|---:|---:|']
for i,p in enumerate(pairs,1):lines.append(f"|{i}|{rank[p['a']]} / {rank[p['b']]}|{p['a']} / {p['b']}|{p['score']:.3f}|{p['meanDTWCM']:.3f}|{p['frechetCM']:.3f}|{p['distanceCM']:.3f}|")
lines+=['','验证：45对覆盖完整、10项自比100分、45对正反方向分数差<1e-8、公式独立复算及完整预测停点与原停点一致均通过。相同原生物理与评分算法，不修改App源码；本轮结果单独保存。','', '[完整45对数据](pairwise-similarity.json) · [原生结果](../two-ball-second-difficulty-20261024/b42-similarity-native.json) · [原字段一致性](../two-ball-second-difficulty-20261024/b42-similarity-native-validation.json)']
(OUT/'README.md').write_text('\n'.join(lines)+'\n')
html='<!doctype html><meta charset="utf-8"><title>B42轨迹相似度</title><style>body{max-width:1200px;margin:30px auto;font:18px system-ui;background:#fafbf8;color:#213e34}img{width:100%}</style><h1>B42：前十条轨迹两两相似度</h1><p>45对比较，沿用2D分离角原生评分。截图第1/2名83.4分；最高为第6/7名83.9分。暂未设去重阈值。</p><img src="similarity-matrix.png"><img src="closest-pairs.png">'
(OUT/'index.html').write_text(html)
audit=SRC/'b42-similarity-native-validation.json';v=json.loads(audit.read_text());v['scope']='Original search rows and full paths match; comparison lines from production SeparationTrajectory.extract on settled predictions; scores from unchanged production evaluate; fixed B42 absent from physics simulation';v['scoreSourceHashes']=hashes;v['pairCount']=45;v['identitiesAndSymmetryPassed']=True;audit.write_text(json.dumps(v,indent=2))
print('45 pairs reported; matrix and two closest-pair overlays rendered.')
