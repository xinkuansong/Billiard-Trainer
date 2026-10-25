from pathlib import Path
import json
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager,ticker
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output'/Path(__file__).resolve().parent.name
s=json.loads((OUT/'summary.json').read_text());assert s['state']=='complete' and s['auditPassed']
t=s['totals'];hist={int(k):v for k,v in s['topCountHistogram'].items()}
font_manager.fontManager.addfont('/Library/Fonts/Arial Unicode.ttf')
plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False,'font.size':12})
fig,axes=plt.subplots(1,2,figsize=(14,5.4),layout='constrained')
fig.suptitle('两球走位：P2相似度60分去重，保留前5条',fontsize=21)
ax=axes[0];xs=list(range(6));ys=[hist.get(i,0) for i in xs]
ax.bar(xs,ys,color=['#9aa7aa']*5+['#177f97'])
for x,y in zip(xs,ys):ax.annotate(f'{y:,}',(x,y),xytext=(0,5),textcoords='offset points',ha='center',fontsize=11)
ax.set(xlabel='每个第二球位置保留的路线数',ylabel='第二球位置数量',title=f'{t["candidates"]:,}个第二球位置 · 5条占{hist[5]/t["candidates"]:.2%}')
ax.set_ylim(0,max(ys)*1.17);ax.set_xticks(xs);ax.yaxis.set_major_formatter(ticker.StrMethodFormatter('{x:,.0f}'))
rails={int(k):v for k,v in s['topRouteRailHistogram'].items()};ax=axes[1]
ax.bar(list(rails),list(rails.values()),color='#b27a30')
for x,y in rails.items():ax.annotate(f'{y:,}',(x,y),xytext=(0,5),textcoords='offset points',ha='center',fontsize=10)
ax.set(xlabel='碰第一球后母球主库次数',ylabel='入选路线引用次数',title=f'{t["routeReferences"]:,}条入选路线引用（跨B允许共用）')
ax.set_ylim(0,max(rails.values())*1.17);ax.set_xticks(list(rails));ax.yaxis.set_major_formatter(ticker.StrMethodFormatter('{x:,.0f}'))
for ax in axes:
 ax.spines[['top','right']].set_visible(False);ax.grid(axis='y',alpha=.18);ax.set_axisbelow(True)
fig.savefig(OUT/'statistics.png',dpi=160);plt.close(fig)
reason_names={'postContactCollision':'碰第一球后的母球路径可能碰B','preContactChord':'击打第一球前的直线补查碰B','endpointOverlap':'母球停点与B重叠','noForwardPocket':'没有正向第二杆袋口','preContactPathUnavailable':'碰第一球前有更早吃库，路径不可核验'}
reasons='\n'.join(f'| {reason_names.get(k,k)} | {v:,} |' for k,v in s['rejectedPairs'].items())
hist_table='\n'.join(f'| {i} | {hist.get(i,0):,} | {hist.get(i,0)/t["candidates"]:.2%} |' for i in range(6))
minutes,seconds=divmod(round(s['elapsedSeconds']),60)
text=f'''# 两球走位全量结果：P2 60分 / 前5

状态：**全量完成，auditPassed=true**。执行日期2026-10-25（Asia/Shanghai），16计算任务，独立输出，原输入数据未修改。

## 全量统计

- 初始球形：**{t['layouts']:,}**；第二球位置：**{t['candidates']:,}**。
- 至少一条入选路线的位置：**{t['nonemptyCandidates']:,}**；无入选路线：**{hist.get(0,0):,}**。全部位置均保存，空结果保留空数组。
- 入选路线引用：**{t['routeReferences']:,}**；按初始球形共用的独立路线条目：**{t['uniqueRoutes']:,}**。同一轨迹用于多个B时，关键点只存一次。
- 有入选路线的初始球形：{t['layoutsWithRoutes']:,}；原始无B候选的初始球形：{t['emptyInputLayouts']:,}。
- 实际处理及审计：**{minutes}分{seconds:02d}秒**（计算、写盘{s['computeAndWriteSeconds']:.2f}秒；读盘审计{s['auditSeconds']:.2f}秒；不含代码准备和绘图）。
- 结果分片压缩体积：**{s['resultGzipBytes']/1e6:.2f}MB**；解压JSONL {s['resultRawBytes']/1e6:.2f}MB；{s['parts']:,}个gzip分片。MB采用十进制。

| 每个B入选路线数 | B位置数 | 占比 |
|---:|---:|---:|
{hist_table}

## 过滤口径

成功第一杆与B的配对共{t['candidateAttemptPairs']:,}项，路径/重叠/几何袋口过滤后{t['eligiblePairs']:,}项。以下拒绝原因按检查顺序互斥计数（不是独立风险的重复计数）：

| 首个拒绝原因 | 配对数 |
|---|---:|
{reasons}

2mm母球关键点折线采用球直径+2mm的碰撞阈值；首次接触前补查母球初始位置到接触位置的直线。第二杆取六个原生成下球点的最低S=目标球到袋口距离/cos(切角)，按S、组合ID排序；未加入第一杆力度/杆法执行成本。

P2直接使用生产`arc1cm-rms-p2-t20-potgate-v3`。与已保留代表相似度≥60则合并，前5代表互相均<60。找到5条后停止，与完整贪心去重的前5等价；不足5条不补抽。未保存未遍历部分的完整去重代表数，不应把eligibleCount−top5长度全部称为相似路线。

首次接触前库碰标记共{t['precontactMarkedCombinations']:,}条成功组合，真正更早且缺少前段路径的组合{t['unavailablePrecontactCombinations']:,}条；诊断随各初始球形保存。此类路径若不可核验则明确排除，不能当作清路。2mm是对原采样折线的压缩误差，不是独立的连续时间物理保证。本轮未做三球重放、第一目标球运动路径干扰检查或第二杆实际进袋确认。

## 保存结构

- `parts/*.jsonl.gz`：一行一个初始球形，含id、board、模拟源索引、第一杆状态统计、candidates及routes。
- 每个`candidate`保存cellID、原坐标、原始最优袋口/分数、过滤计数、top5。top5各项为comboIndex、目标袋口pocket、切角angle、OP距离distance、难度score。
- 同行`routes`按comboIndex关联，保存打点spinX/spinY、杆速velocity、strikeDirection/aimOffsetRadians、母球落点cueStop、主库/袋角/其他库次数及完整原2mm关键点包（含时间、库点/顺序、mandatoryPointIndices）。参数和关键点未降精度。
- `parts-index.json`：结果分片、SHA、对应旧模拟分片SHA、字节与核验统计。
- `candidate-statistics.jsonl.gz`：全量B的位置ID及可用数/入选数摘要。
- `manifest.json`：规则、源文件及执行代码SHA；`summary.json`：最终计数；`statistics.png`：统计图。
- 原模拟源：`output/two-ball-independent125-full-20261024/`；初始球形和B源：`output/two-ball-block-sampled-13570-20261025/`。

## 验证证据

- {t['layouts']:,}唯一初始ID及{t['candidates']:,}个B与输入逐项对齐，原坐标/标识/初始分数保持；全量125配额和源模拟分片SHA核验。
- 全部候选分区计数平衡；{s['checks']['scoreChecks']:,}项独立第二杆公式对拍；所有入选路线读盘后再次核验路径距离和最低分数。
- 原生P2验证{s['checks']['verifiedTopPairs']:,}对入选路线相似度<60；{s['checks']['pilotParity']}个初始球形与冻结试跑前5一致；{s['checks']['fullGreedyParity']}个初始球形与完整贪心去重前5一致。
- 所有输出分片解压、SHA和引用完整性通过；输入与执行源码SHA未改变。计算池已join退出，无模拟器或设备租约。

![统计](statistics.png)
'''
(OUT/'README.md').write_text(text)
print(json.dumps({'report':'complete','image':str(OUT/'statistics.png'),'README':str(OUT/'README.md')},ensure_ascii=False))
