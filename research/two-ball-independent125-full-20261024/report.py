from pathlib import Path
import json,time
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name
s=json.loads((OUT/'summary.json').read_text());assert s['state']=='complete' and s['auditPassed'] and s['attempts']==16962500 and s['layoutCount']==135700
font_manager.fontManager.addfont('/Library/Fonts/Arial Unicode.ttf');plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False,'font.size':12})
cats=['center','vertical','horizontal','mixed'];names=['中杆','纯高低杆','纯左右塞','混合杆法'];colors=['#238a71','#217fba','#b37c30','#9853af'];v=[s['categories'][c] for c in cats]
fig,ax=plt.subplots(2,2,figsize=(14,10),layout='constrained');fig.suptitle('135,700球形 × 125组 · 独立随机打点 · 全量结果',fontsize=21)
for a,vals,title in [(ax[0,0],[r['success'] for r in v],'各类有效组合数量'),(ax[0,1],[r['successRate']*100 for r in v],'各类有效率（%）')]:
 a.bar(names,vals,color=colors);a.set_title(title);a.set_ylim(0,max(vals)*1.2)
 for i,x in enumerate(vals):a.text(i,x+max(vals)*.02,f'{x:,.0f}' if max(vals)>100 else f'{x:.2f}',ha='center')
for a,key,title in [(ax[1,0],'validPerLayoutHistogram','每球形有效组合数量分布'),(ax[1,1],'cueRailsForSuccess','成功组合的母球碰球后主库数量')]:
 p=sorted((int(k),v) for k,v in s[key].items());a.bar([k for k,v in p],[v for k,v in p],color='#217fba');a.set_title(title)
fig.savefig(OUT/'statistics.png',dpi=160);plt.close(fig)
rows=[]
for c,n in zip(cats,names):
 r=s['categories'][c];rows.append(f"| {n} | {r['attempts']:,} | {r['success']:,} | {r['successRate']:.2%} | {r['meanAttemptMilliseconds']:.3f}毫秒 |")
body=f'''# 两球走位：独立随机打点125组全量结果

已完成并通过全量审计：135,700球形、16,962,500尝试、16进程。每球形配额14/42/18/51，失败不补抽，零方向重试；全部成功组合保存2mm关键点。

| 杆法 | 尝试数 | 有效数 | 有效率 | 单组合平均耗时 |
|---|---:|---:|---:|---:|
{chr(10).join(rows)}

- 有效{s['status']['success']:,}（{s['successRate']:.2%}）；每球形平均{s['validPerLayout']['mean']:.2f}，中位{s['validPerLayout']['median']}；无有效球形{s['validPerLayoutHistogram'].get('0',0):,}。
- 计算写入{s['elapsedComputeAndWriteSeconds']/3600:.3f}小时，审计{s['elapsedAuditSeconds']/60:.2f}分钟；压缩结果{s['compressedResultBytes']/1e9:.3f}GB。
- 成功轨迹平均{s['keypointsPerSuccess']['mean']:.2f}点，最大压缩误差{s['maxDeviationMeters']*1000:.6f}mm；{s['independentCompressionFixtures']}条完整原始轨迹独立复核通过。
- 计算进程组RSS采样峰值{s['memory']['peakTotalRSSBytes']/2**30:.2f}GiB；共享页可能重复计数，不含共享模拟器服务和其他应用。

## 状态明细

```json
{json.dumps(s['status'],ensure_ascii=False,indent=2)}
```

## 存储与复现

parts/下1357个gzip JSONL分片，每片100球形，每行一个球形及其125次尝试；receipts/包含SHA256、布局索引和统计。manifest.json冻结输入/代码/二进制指纹，samplingVersion={s['samplingVersion']}。失败也留记录，只有成功带trajectory2mm；每点为相对首碰时间、X、Z（米），包含吃库顺序、事件点索引和压缩误差。excludedPreContactCushionMetadata保留同刻事件归属修正证据，原始events顺序始终保留。

模拟方案见[任务文档](../../tasks/TWO-BALL-INDEPENDENT125-FULL-20261024.md)。完整统计summary.json；逐球形有效数layout-statistics.jsonl。仅首杆独立模拟，不含第二球干扰过滤、第二杆难度和P2去重。

![统计图](statistics.png)
'''
(OUT/'README.md').write_text(body);(OUT/'report-complete.json').write_text(json.dumps(dict(createdAt=time.time(),summaryState=s['state'])))
print('REPORT_COMPLETE')
