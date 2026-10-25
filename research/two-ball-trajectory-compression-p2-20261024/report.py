from pathlib import Path
import json, math, csv, shutil, hashlib
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name
read=lambda p:json.loads(p.read_text())
s=read(OUT/'summary.json');details=read(OUT/'point-details.json');representations=read(OUT/'representations.json');scores=read(OUT/'pair-scores.json')
font_manager.fontManager.addfont('/Library/Fonts/Arial Unicode.ttf');plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False,'font.size':11})
names=['full','cushion','key10mm','key5mm','key2mm'];labels=['完整轨迹','仅吃库点','补点·10毫米','补点·5毫米','补点·2毫米'];colors=['#8b969d','#d97538','#b28d30','#4d92ad','#148572']
fig,axs=plt.subplots(2,2,figsize=(15,9),layout='constrained');fig.suptitle('95条轨迹压缩对比 · 当前P2评分 · 75分去重',fontsize=23)
a=axs[0,0];means=[s['variants'][n]['points']['mean'] for n in names];a.bar(labels,means,color=colors);a.set_yscale('log');a.set_ylim(2,1600);a.set_ylabel('每条平均点数（对数轴）');a.set_title('补2毫米关键点：平均9.2点，减少98.69%')
for i,v in enumerate(means):a.text(i,v*1.15,f'{v:.1f}',ha='center',fontsize=13)
a=axs[0,1];x=np.arange(4);v=[s['variants'][n]['absoluteScoreError'] for n in names[1:]]
a.bar(x-.22,[r['mean'] for r in v],.22,label='平均绝对误差',color='#167c91');a.bar(x,[r['p95'] for r in v],.22,label='P95绝对误差',color='#e0ab51');a.bar(x+.22,[r['max'] for r in v],.22,label='最大绝对误差',color='#b65a4a');a.set_xticks(x,labels[1:]);a.set_ylabel('相似度误差（分）');a.legend(fontsize=10);a.set_title('全部4,465对：以完整轨迹的P2分数为基准')
for i,r in enumerate(v):a.text(i+.22,r['max']+.2,f"{r['max']:.3f}",ha='center',fontsize=10)
a=axs[1,0];vv=[s['variants'][n] for n in names];a.bar(labels,[v['thresholdFlipCount'] for v in vv],color=colors);a.set_ylabel('跨越75分阈值的轨迹对数');a.set_ylim(0,12);a.set_title('2毫米档：所有轨迹对的阈值判定一致')
for i,v in enumerate(vv):a.text(i,v['thresholdFlipCount']+.15,str(v['thresholdFlipCount']),ha='center')
a=axs[1,1];a.axis('off');a.set_title('B42实际可用93条：按第二杆难度升序贪心去重')
table=a.table(cellText=[[labels[i],str(v['dedupB42']['count']), '一致' if v['sameRepresentatives'] else '有变化',str(len(v['assignmentChanges']))] for i,v in enumerate(vv)],colLabels=['表示方式','保留数','代表名单','归属变化条数'],cellLoc='center',loc='center',colWidths=[.34,.16,.24,.26]);table.auto_set_font_size(False);table.set_fontsize(11);table.scale(1,2)
a.text(.02,.06,'各档前十均一致；保留数相同≠代表名单和合并归属相同。\n95条均参与评分；碰到B42的38/121沿用原筛除结果。',transform=a.transAxes,fontsize=10)
fig.savefig(OUT/'comparison.png',dpi=160);plt.close(fig)

by={n:{r['comboIndex']:np.array([[p['position']['x'],p['position']['z']] for p in r['points']])*100 for r in rows} for n,rows in representations.items()}
worst=s['variants']['cushion']['worstPairs'][0]
focus=[(worst['a'],worst['b']),(85,493)]
fig,axs=plt.subplots(2,3,figsize=(16,7),layout='constrained');fig.suptitle('相同两条路线：完整轨迹 / 仅吃库点 / 补2毫米关键点',fontsize=22)
mat={n:{(p['a'],p['b']):p['score'] for p in scores[n]['pairs']} for n in names}
for row,(ida,idb) in enumerate(focus):
 for col,n in enumerate(['full','cushion','key2mm']):
  ax=axs[row,col];ax.set_facecolor('#e5eee3');ax.set_xlim(-130,130);ax.set_ylim(66,-66);ax.set_aspect('equal');ax.set_xticks([]);ax.set_yticks([])
  ax.plot([-127,127,127,-127,-127],[-63.5,-63.5,63.5,63.5,-63.5],color='#355d50',lw=5)
  for id,color in [(ida,'#007ca6'),(idb,'#d8693a')]:
   p=by[n][id];full=by['full'][id]
   if n!='full':ax.plot(full[:,0],full[:,1],color=color,alpha=.23,lw=4)
   ax.plot(p[:,0],p[:,1],color=color,lw=1.7,label=f'组合{id} · {len(p)}点',marker='o' if n!='full' else None,markersize=3)
   ax.scatter(*p[-1],s=45,facecolor='white',edgecolor=color,zorder=5)
  ax.legend(loc='upper center',fontsize=9,framealpha=.8,ncol=2)
  score=mat[n][tuple(sorted((ida,idb)))];ax.set_title(f'{dict(zip(names,labels))[n]} · {score:.3f}分 · '+('相似' if score>=75 else '不同'),fontsize=12)
  if col==0:ax.set_ylabel('最大评分偏差案例' if row==0 else '75分临界案例',fontsize=12)
fig.savefig(OUT/'trajectory-examples.png',dpi=170);plt.close(fig)

with (OUT/'point-counts.csv').open('w') as f:
 w=csv.writer(f);w.writerow(['comboIndex']+[n+'_points' for n in names]+[n+'_maxDeviationMM' for n in names])
 for d in details:w.writerow([d['comboIndex']]+[d['variants'][n]['points'] for n in names]+[d['variants'][n]['maxDeviationMM'] for n in names])
rows=[]
for i,n in enumerate(names):
 v=s['variants'][n];p=v['points'];e=v['absoluteScoreError']
 rows.append(f"|{labels[i]}|{p['mean']:.2f}（{p['min']}–{p['max']}）|{e['mean']:.4f}|{e['p95']:.4f}|{e['max']:.4f}|{v['thresholdFlipCount']}|{v['dedupB42']['count']}|{'一致' if v['sameRepresentatives'] else '变化'}|{len(v['assignmentChanges'])}|")
md='''# 95条轨迹压缩与P2评分对比

本批建议采用**起点＋吃库点/顺序＋终点＋2毫米曲线关键点**。平均9.22点（3–23），较完整轨迹减少98.69%；4,465对没有75分阈值翻转，B42全部去重代表、合并归属和前十完全一致。这是本球形的实测结论，尚未覆盖其他球形。

![统计](comparison.png)

|表示|平均点数（范围）|平均绝对误差/分|P95误差|最大误差|跨75分对数|B42代表数|代表名单对比|归属变化条数|
|---|---:|---:|---:|---:|---:|---:|---|---:|
'''+ '\n'.join(rows)+'''

- 所有表示都保留**碰第一颗球时的母球球心、按时间排列的每次母球吃库球心、最终停点**。库ID/事件顺序单独保留，不能只存不带顺序的坐标集合。
- 仅吃库点：10对阈值判定改变，其中9对误合并、1对误分开；B42保留46代表，较完整P2多85、少270/612，10条归属改变。它丢失了两次碰撞之间的弯曲，个别对评分误差明显。
- 5毫米与10毫米档：都是47代表、前十相同，但85/493跨阈值，使代表从270换成85，并连带改变7条归属。5毫米该对为75.094942→74.928581分；不能仅用“代表数量不变”判定等价。
- 2毫米档：代表名单和所有合并归属均一致，最大评分误差0.247079分。未承诺对任何球形或所有75分临界对都完全等价。
- 当前P2完整轨迹保留47代表；历史DTW/Fréchet图册是57代表。这10个差异是**评分算法升级**产生的，不能算成压缩影响。
- 当前P2前十（所有压缩档本轮相同）：398、334、405、61、237、447、286、525、496、106。

![路线例子](trajectory-examples.png)

## 数据与方法

- 原球形`grid-v3:1512:68:1`，95条有效组合均为已验证的原物理参数。95条全两两比较=4,465对；实际B42排名沿用原路径碰撞筛除，组合38/121不参与，剩93条。没有让近似路径重新决定碰撞，以免混淆两个变量。
- 基准为`SeparationTrajectory.extract`原生产提取的完整碰后母球折线，至最终停点；不是逐步物理解析真值。93条来自既有native-result；38/121补跑冻结原生物理，除计时/trialID外所有旧字段精确相同，当前与冻结extractor源码字节相同。新补跑文件的旧评分未用于本次分析。
- 使用当前生产`SeparationTrajectoryScore.swift`的原样快照，算法`arc1cm-rms-p2-t20-potgate-v3`，每1厘米弧长单元、保序动态规划均方根距离，`100×2^(−距离厘米/20)`。适配器按原Float精度还原坐标后转厘米；没有使用上一版70%DTW/30%Fréchet。
- 保存点使用X/Z物理米，横图右=+X、下=+Z；评分时转厘米，无平移、缩放或旋转配准。
- 补点采用**按事件分段的RDP简化，加保序折返保护**，分别限制原折线点到对应压缩线段的偏差≤2/5/10毫米。这是曲线近似精度，不是P2允许误差或75分门槛；保留点数自适应，不能给每条硬限9点。
- 组合330在相同Float事件时刻有相距约1微米的两个事件标记；吃库表示取对应事件的首个最近点，核验其余标记在2微米内。完整表示保留原点。
- 贪心去重：按既有第二杆S升序，同分按组合ID；与任何已保留代表≥75就归入第一个相符代表。不是传递聚类。第一杆难度权重本轮未改。

## 存储估算

'''
for n in ['full','cushion','key2mm','key5mm']:
 v=s['variants'][n];md+=f"- {dict(zip(names,labels))[n]}：X/Z各Float32时，坐标平均{v['coordinateBytesPerTrajectory']:.1f}字节/条；95条纯坐标JSON {v['coordinateJSONBytes']:,}字节，gzip {v['coordinateGzipBytes']:,}字节。\n"
md+='''
上述不含组合ID、库ID、点数索引、时间、对象开销；不能直接视为Swift运行时内存。P2仍会把折线展开为1厘米弧长网格，主要节省长期保存的数据量，并不会把评分运算量同比减少。压缩轨迹适用于相似度与概览；仅凭此实验不能认定可无误差替代精确碰撞筛查或动画回放。

## 验证与复现

- 5种表示各4,465对真实生产P2计算；95条自比均为100分。每种抽样对拍生产evaluate入口误差0，正反向距离最大差<1e-8厘米。
- 全95条事件坐标/顺序/首尾保留、终点一致、合法索引、简化偏差上限断言通过；直线、弯曲、共线折返夹具通过。完整旧字段重放一致。
- 原库和App代码未改；冻结生产源码SHA见[provenance.json](provenance.json)。纯研究macOS Swift -O计算，无需重跑135,700球形。
- 补两条用受管notch-phone，任务`trajectory-compression-p2-missing2`成功退出，已Shutdown并释放租约（1792846964.56877）。
- [完整统计及所有去重代表/归属](summary.json) · [4,465对评分CSV](pair-comparison.csv) · [每条点数CSV](point-counts.csv) · [全部压缩点](representations.json) · [点索引/库事件/偏差](point-details.json) · [补跑一致性](native-validation.json)
- 脚本位于`research/two-ball-trajectory-compression-p2-20261024/`：prepare.py → Swift compare → analyze.py → report.py。先运行原生补两条runner仅在缺数据时需要；不要重复启动。

下一步建议跨多个不同切角/杆法/距离球形检验2毫米档，再决定全量数据格式。75分附近的决策对如需严格保持，可保留复跑精确轨迹的入口。
'''
(OUT/'README.md').write_text(md)
# Static report page in the existing review gallery; retain all old pages.
gallery=ROOT/'output/two-ball-multi-position-top10-20261024'
for file in ['comparison.png','trajectory-examples.png']:shutil.copy2(OUT/file,gallery/('p2-compression-'+file))
html='''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>95条轨迹压缩 · P2</title><style>body{font:17px system-ui;background:#f6f8f7;color:#243a34;margin:28px auto;max-width:1500px;padding:0 18px}img{width:100%;display:block;margin:20px 0;background:white}table{border-collapse:collapse;width:100%;background:white}td,th{padding:12px;border-bottom:1px solid #dbe2df;text-align:right}td:first-child,th:first-child{text-align:left}p{line-height:1.7}a{color:#147c91}</style><h1>95条轨迹压缩对比 · P2评分</h1><p><b>建议补2毫米关键点：平均9.22点，减少98.69%。</b>全部4,465对75分判定一致，B42保留47代表，代表和合并归属一致。本结果只覆盖当前球形。</p><p>评分算法：arc1cm-rms-p2-t20-potgate-v3。95条用于评分；排除会碰到B42的38/121，93条用于B42去重。所有方式都保留起点、吃库点和终点。</p><img src="p2-compression-comparison.png"><h2>路线差异</h2><p>浅色粗线为完整轨迹，实线与圆点为实际保存的折线。完整与压缩表示均从第一次碰目标球后开始。</p><img src="p2-compression-trajectory-examples.png"><p>5毫米档虽然同样保留47条，但85/493从75.095降到74.929，引起代表更换及7条合并归属变化。各档前十相同不代表完整去重结果相同。</p><p><a href="B42-dedup75.html">返回旧算法75分图册（历史结果57代表）</a></p></html>'''
(gallery/'trajectory-compression-p2.html').write_text(html)
print('Report and two charts generated',OUT)
