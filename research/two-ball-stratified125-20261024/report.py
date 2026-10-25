from pathlib import Path
import json,html
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties, fontManager
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name
s=json.loads((OUT/'summary.json').read_text());cats=['center','vertical','horizontal','mixed'];names=['中杆','纯高低杆','纯左右塞','混合杆法'];cols=['#238a71','#217fba','#b37c30','#9853af'];fontManager.addfont('/Library/Fonts/Arial Unicode.ttf');font=FontProperties(fname='/Library/Fonts/Arial Unicode.ttf');plt.rcParams['font.family']=font.get_name();plt.rcParams['axes.unicode_minus']=False
fig,ax=plt.subplots(2,2,figsize=(13,10));fig.suptitle('125组分类采样 · 同一批1,000球形 · 16进程',fontsize=22)
v=[s['categories'][c] for c in cats]
for a,key,title,unit in [(ax[0,0],'success','各类有效组合数量','个'),(ax[0,1],'successRate','各类有效率','%'),(ax[1,0],'meanAttemptMilliseconds','单组合平均计算耗时','毫秒')]:
 vals=[r[key]*(100 if key=='successRate' else 1) for r in v];a.bar(names,vals,color=cols,width=.55);a.set_title(title,fontsize=15);a.set_ylabel(unit);a.spines[['top','right']].set_visible(False);a.set_ylim(0,max(vals)*1.19)
 for i,x in enumerate(vals):a.text(i,x+max(vals)*.02,f'{x:,.0f}' if key=='success' else f'{x:.2f}',ha='center',fontsize=12)
a=ax[1,1];cs=json.loads((OUT/'sampling-preview.json').read_text());circle=plt.Circle((0,0),.5,fill=False,color='#7c8793');a.add_patch(circle)
for cat,name,col in zip(cats,names,cols):
 ps={r['tipID']:(r['spinX'],r['spinY']) for r in cs if r['strokeCategory']==cat};a.scatter([p[0] for p in ps.values()],[p[1] for p in ps.values()],label=name,color=col,s=32)
a.axhline(0,color='#ccc',lw=.7);a.axvline(0,color='#ccc',lw=.7);a.set_aspect('equal');a.set_xlim(-.55,.55);a.set_ylim(-.55,.55);a.set_title('首个球形的45个打点（轴向锁零）');a.set_xlabel('spinX：左右');a.set_ylabel('spinY：高低');a.legend(fontsize=9,loc='upper left',bbox_to_anchor=(1.02,1))
fig.text(.05,.03,f"总有效 {s['status']['success']:,} / 125,000 · 计算与写入 {s['elapsedComputeAndWriteSeconds']:.2f}秒 · 成功关键点平均 {s['keypointsPerSuccess']['mean']:.2f}个\n各类耗时是组合内墙钟计时的平均值；并行累计耗时不能当作整轮耗时。失败不补抽，零方向重试。",fontsize=12,color='#56616b');fig.tight_layout(rect=[0,.08,1,.94]);fig.savefig(OUT/'statistics.png',dpi=170);plt.close(fig)
rows=[]
for cat,name in zip(cats,names):
 r=s['categories'][cat];rows.append(f"| {name} | {r['attempts']:,} | {r['success']:,} | {r['successRate']:.2%} | {r['validPerLayout']['mean']:.2f} | {r['meanAttemptMilliseconds']:.3f} ms |")
body=f'''# 125组分类打点试跑

同一批1,000球形，16进程，每球形中杆14、纯高低42、纯左右18、混合51。采样版本：`{s['samplingVersion']}`。每组仅模拟一次，失败或非法不补抽，不微调方向。所有成功组合保存2mm关键点。

| 杆法 | 尝试 | 有效 | 有效率 | 每球形平均有效 | 单组合平均计算耗时 |
|---|---:|---:|---:|---:|---:|
{chr(10).join(rows)}

- 合计有效 **{s['status']['success']:,} / 125,000（{s['successRate']:.2%}）**；每球形平均{s['validPerLayout']['mean']:.2f}，中位{s['validPerLayout']['median']}，范围{s['validPerLayout']['min']}–{s['validPerLayout']['max']}；{s['layoutsAtLeast100']}球形至少100有效，{s['layoutsZero']}球形无有效。
- 16进程计算＋2mm提取＋JSON/gzip写入 **{s['elapsedComputeAndWriteSeconds']:.2f}秒**；含设备/worker启动{s['elapsedIncludingStartupSeconds']:.2f}秒。不含之后的事件元数据归一化与审计。
- 任务进程RSS合计采样峰值{s['memory']['peakTotalRSSBytes']/2**30:.2f}GiB，约0.1秒采样。共享页可能重复计数；不含共享模拟器服务和其他App，不等于整机物理增量。
- 成功轨迹平均{s['keypointsPerSuccess']['mean']:.2f}关键点，中位{s['keypointsPerSuccess']['median']}，最多{s['keypointsPerSuccess']['max']}；最大报告误差{s['maxDeviationMeters']*1000:.6f}mm。独立复算{s['independentCompressionFixtures']}条完整原始轨迹，最大误差{s['independentMaxDeviationMeters']*1000:.6f}mm。
- 压缩结果{s['compressedResultBytes']/1e6:.2f}MB，另存于parts/，原试跑与全库未改。仅1,000球形，没有启动全量。

## 四类完整结局

```json
{json.dumps({names[i]:s['categories'][c]['status'] for i,c in enumerate(cats)},ensure_ascii=False,indent=2)}
```

## 采样与保存契约

保持旧随机序列先抽圆内打点和14档杆速，再把中杆两轴锁为0、纯高低spinX锁0、纯左右spinY锁0；混合点和各档杆速保持原始随机值。45点区域保持原tipID，630候选索引保留，但轴向打点值已变化，必须同时引用新的samplingVersion，不能把comboIndex当跨版本相同参数。每条输出增加strokeCategory；本轮输入SHA与同一1,000球形一致。

中杆覆盖全部14杆速；纯高低6区域各取7组（14档相邻两档选一）；纯左右6区域各从前5/中5/后4档中各选1；混合32区域全部覆盖，额外补19个不重复组合，14速度档各3或4组。组合类别只指打点位置，是否出杆合法仍由原引擎判定。

## 验证与范围

全125,000条重新生成输入对拍、逐球形配额、轴向精确零、组合不重复、圆内范围、速档覆盖、成功状态、关键点终点/时间/事件顺序与最大误差、gzip SHA、16进程正常退出均通过。逐文件及统计见summary.json、audit.log、manifest.json。{s['eventOrderNormalization']}条同时间戳吃库事件按原始事件顺序修正仅元数据，原件保留在event-order-originals/。物理和采样标准未放宽。

单组合平均耗时是wallMilliseconds的算术平均，包含瞄向、物理和成功压缩；各类在同一批次交错并行，不能把各类累计时间相加当整轮墙钟。与之前125组策略的成功数量变化同时受配额和轴向锁零影响，不视作单一因素的因果实验。未做第二球干扰过滤或P2去重。

![分类统计](statistics.png)
'''
(OUT/'README.md').write_text(body)
page=f'''<!doctype html><meta charset="utf-8"><title>125组分类采样结果</title><style>body{{font:18px -apple-system,sans-serif;max-width:1180px;margin:35px auto;padding:20px;background:#f6f8fa;color:#243441}}img{{width:100%}}p{{line-height:1.8}}</style><h1>中杆14 · 纯高低42 · 纯左右18 · 混合51</h1><p>同一批1,000球形 / 16进程 / 125,000次尝试。有效{s['status']['success']:,}（{s['successRate']:.2%}），计算与写入{s['elapsedComputeAndWriteSeconds']:.2f}秒。零方向重试，成功保存2mm关键点。</p><img src="stratified125-statistics.png"><p>整轮耗时不含设备启动和事后审计；图中分类耗时为单组合平均。已通过全记录审计，尚未启动全量。</p>'''
(OUT/'index.html').write_text(page.replace('stratified125-statistics.png','statistics.png'))
import shutil
gallery=ROOT/'output/two-ball-multi-position-top10-20261024';(gallery/'stratified125.html').write_text(page);shutil.copy2(OUT/'statistics.png',gallery/'stratified125-statistics.png')
print(body[:3000])
