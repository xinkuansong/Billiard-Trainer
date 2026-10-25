from pathlib import Path
import json,hashlib,shutil
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name
read=lambda p:json.loads(p.read_text());s=read(OUT/'summary.json');ls=read(OUT/'layout-statistics.json');base=read(OUT/'baseline.json');run=read(OUT/'run-complete.json')
assert s['state']=='complete' and s['auditPassed']
font_manager.fontManager.addfont('/Library/Fonts/Arial Unicode.ttf');plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False,'font.size':12})
fig,axes=plt.subplots(1,2,figsize=(15,5.8),layout='constrained');fig.suptitle('1,000个球形 × 125组 · 不重试方向 · 成功保存2毫米关键点',fontsize=22)
a=axes[0];counts,bins=np.histogram([r['valid'] for r in ls],bins=np.arange(0,131,10));a.bar(bins[:-1]+5,counts,width=8,color='#147f8e');a.set_xticks(bins[:-1]+5,[f'{i}–{i+9}' for i in bins[:-1]],rotation=45);a.set_xlabel('每球形有效组合数');a.set_ylabel('球形数量');a.set_title('平均100.06 · 中位105 · 684个球形≥100组')
for x,y in zip(bins[:-1]+5,counts):
 if y:a.text(x,y+2,str(y),ha='center',fontsize=10)
names=['成功','未进指定袋','母球落袋','非法参数','未完成'];keys=['success','target_miss','scratch','illegal_parameters','unresolved'];a=axes[1];v=[s['status'].get(k,0) for k in keys];a.barh(names[::-1],v[::-1],color=['#999','#b08d59','#b66d53','#d0904a','#147f8e']);a.set_xlim(0,118000);a.set_xlabel('尝试次数');a.set_title('125,000次尝试 · 有效率80.05%')
for i,c in enumerate(v[::-1]):a.text(c+1200,i,f'{c:,}',va='center')
fig.savefig(OUT/'statistics.png',dpi=160);plt.close(fig)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
provenance=dict(files={str(p.relative_to(ROOT)):sha(p) for p in [HERE/'main.swift',HERE/'sampling.py',HERE/'build.py',HERE/'run.py',HERE/'normalize_events.py',HERE/'audit_report.py',HERE.parent/'two-ball-strike-full-20261024/source-hashes.json']},binarySHA256=read(OUT/'workers.json')['binarySHA256'],lifecycle='8 worker exit codes0; simulator Shutdown; released success at1792849265.858558',originals='event-order-originals retains original affected output and receipts; source/events/positions/status/timing untouched')
(OUT/'provenance.json').write_text(json.dumps(provenance,indent=2))
old=base['status']['success'];newcommon=s['pairedOriginal100']['both_success'];elapsed=s['elapsedComputeAndWriteSeconds'];ratio=s['historicalSame1000SummedBatchSeconds']/s['summedWorkerBatchSeconds']
md=f'''# 1,000球形×125组：单次方向模拟＋2毫米关键点

**已完成并通过结果审计。** 125,000次尝试，100,061组有效（80.0488%）；平均每球形100.061组，成功结果全部保存2毫米关键点。8个原生进程计算＋压缩写盘 **{elapsed:.2f}秒**，含设备/worker启动为 **{run['elapsedIncludingStartupSeconds']:.2f}秒**；不含构建、后续独立审计和事件元数据修正。

![数量分布](statistics.png)

|结果|数量|
|---|---:|
|有效|100,061|
|未进指定袋|17,273|
|母球落袋|6,672|
|非法参数|906|
|未完成（15秒物理时限）|88|

- 每球形：平均100.06、中位105、P10=82、P90=116、最少0、最多122。
- ≥100组的球形684个；0组的3个。125次尝试不保证每个球形凑足100个，未补抽。
- 每条成功轨迹平均 **9.01点**，中位8，范围2–32；未压缩平均799.17点，点数减少98.87%。全部保留起点/事件点/停点，压缩误差≤2毫米（相对原生产提取折线）。不是相邻点相距2毫米，也不是解析物理精度承诺。
- 100个gzip结果分片合计 **{s['compressedResultBytes']:,}字节（56.56 MB）**，含所有尝试的审计字段及成功轨迹；不含原始审计路径、日志和修正前备份。关键点只为成功组合保存。

## 与旧100组的配对比较

采用原冻结随机排列中分散的10个分片，共1,000个不同球形。仍使用原630格随机参数和原seed，不放回sample125；逐球形验证其包含原sample100，新增25组，不改原100组取值。

|同一批1,000球形|旧100组策略|新125组策略|
|---|---:|---:|
|总尝试|100,000|125,000|
|成功|{old:,}|100,061|
|平均成功/球形|{old/1000:.3f}|100.061|
|累计worker批内墙钟|{s['historicalSame1000SummedBatchSeconds']:.2f}秒|{s['summedWorkerBatchSeconds']:.2f}秒|

共有的原100,000组中，旧成功{old:,}、新成功{newcommon:,}，减少546（0.546个百分点）；461变未进袋、12变母球落袋、73变完整终态超时。**不能把546全部归因于取消方向重试**：为提取完整轨迹，新流程还关闭了原求解的interestResolved早停，15秒时限不变。80,017个新旧共同成功且offset相同的组合，母球终点逐值一致（最大差0）。新增25,000组带来20,044个成功组合。

累计worker批内耗时约降为旧值的1/{ratio:.2f}，而尝试增加25%且新增关键点保存。不过旧时间来自历史运行，机器负载不同；这不是同一时段严格A/B，也不能把历史累计墙钟直接与本次70秒端到端相比。8进程总吞吐约{125000/elapsed:.0f}次尝试/秒；不直接承诺全量ETA。

## 执行标准

- 保留冻结原物理对象、原下球点、杆速0.6–4.5m/s、打点圆盘随机协议、500事件/15秒限额、平面参考物理模型、原出杆许可检查。
- 每组调用一次prepareAim/positionAimOffset（正常解析求瞄准），然后直接buildPrediction一次；没有调用会执行邻近方向回退的外层predictForPositionSolve。共125,000次完整候选模拟、directionRetries=0。
- includePresentation=false，不生成无用展示折线；searchEarlyStop=false，以完整终态提取轨迹。失败/非法不补抽。未加入第二球的碰撞过滤或P2去重，它们仍是下一阶段。
- 成功才从内存recorder提取碰后母球线，并在Swift中完成保事件、保折返的2毫米RDP压缩，再跨进程传输/gzip写盘。
- 本轮全是1,000球形试验，未覆盖原135,700库，未改App代码或原结果。

## 保存字段

`parts/*.jsonl.gz`每片10球形、每行一个球形，保留layoutID、board和125条尝试。成功行新增`trajectory2mm`：

- `points`：按顺序的 `[碰第一球后的相对时间秒, x米, z米]`；物理X–Z，横图右+X/下+Z。
- `mandatoryPointIndices`、`sourcePointIndices`：事件/首尾锚点与原折线索引。
- `cushions`：碰第一球之后的库ID、事件绝对时间、对应关键点索引；必须按引擎事件顺序读取，不能只用相同时间戳排序。
- `sourcePointCount`、`maxDeviationMeters`：全轨迹点数与最大压缩误差，误差不超过0.002米。
- 原`events`仍保存完整前后事件；`cueStop`、实际aimOffset、打点/杆速均保留。

## 审计与修正记录

1. 逐行核验1,000球形唯一、125组唯一/固定Float参数、原100组包含、状态和有效性、零方向重试、事件索引/顺序/点数、终点一致与2毫米上限。
2. 全100,061条成功轨迹在原生端对完整折线计算最大偏差；另抽存100条完整折线，在Python独立复算，每点坐标/锚点/段内偏差一致，最大1.995131毫米。
3. 初次事件归属审计发现61条：吃库在引擎序列中发生于首次球球碰撞之前，但Float时间戳相同。原生的时间筛选误把它放进碰后库序。已用完整事件流顺序规范化，仅移除碰后`cushions`列表中该前置事件；它仍保留在原`events`里。**不改轨迹点、物理、状态或耗时**。原始分片和回执保存在`event-order-originals/`，明细见[event-order-normalization.json](event-order-normalization.json)。这一规范化步骤是本研究导出流程必经步骤，不能省略。
4. 所有最终分片SHA和全统计核验通过；8worker退出码0，设备Shutdown，租约success释放。构建与脚本哈希见[provenance.json](provenance.json)。

## 文件与复现

[全部统计](summary.json) · [每球形数量CSV](layout-statistics.csv) · [结果分片](parts/) · [原始轨迹审计样本](audit-paths/) · [试跑输入](manifest.json)

研究代码：`research/two-ball-sample125-once-20261024/`。流程prepare.py → build.py → 受管run.py → normalize_events.py → audit_report.py → report.py。已有parts时runner拒绝重复启动；不要覆盖旧试跑或跳过事件归属修正。
'''
(OUT/'README.md').write_text(md)
gallery=ROOT/'output/two-ball-multi-position-top10-20261024';shutil.copy2(OUT/'statistics.png',gallery/'sample125-statistics.png')
(gallery/'sample125-once.html').write_text('''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>1000球形×125组试跑</title><style>body{font:18px system-ui;max-width:1450px;margin:30px auto;padding:0 20px;color:#243e37;background:#f6f8f6}p{line-height:1.7}img{width:100%}</style><h1>1,000球形 × 125组 · 单次方向模拟</h1><p><b>成功100,061组，平均每球形100.06组；8进程计算与写盘70.08秒。</b><br>684个球形≥100组，3个无有效组合。成功轨迹平均9.01个关键点，全部通过2毫米偏差检查。</p><img src="sample125-statistics.png"><p>共有原10万组参数：旧80,563成功，新80,017成功，减少546；其中73为关闭早停后完整终态超时，其余461未进袋、12母球落袋。新增2.5万次尝试增加20,044个成功组合。</p><p>完整物理时限仍为15秒；没有邻近方向重试。结果单独保存，未跑全库或进行第二球碰撞过滤/P2去重。61条同时间戳事件已按引擎顺序修正归属，原始输出保留。设备已归还。</p><p><a href="trajectory-compression-p2.html">查看此前2毫米压缩对比</a></p></html>''')
print('Report and chart saved.')
