from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output'/Path(__file__).resolve().parent.name
s=json.loads((OUT/'summary.json').read_text());assert s['state']=='complete' and s['auditPassed'];t=s['stats'];assert t['layouts']==13570 and t['BPositions']==173577
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
font=FontProperties(fname='/System/Library/Fonts/PingFang.ttc');plt.rcParams['axes.unicode_minus']=False
fig,axes=plt.subplots(2,2,figsize=(14,9));fig.suptitle('两球走位：25°微调全量结果',fontproperties=font,fontsize=24)
def bars(ax,labels,values,title):
 bars=ax.bar(range(len(values)),values,color='#167b92');ax.set_xticks(range(len(values)),labels,fontproperties=font,fontsize=10);ax.set_title(title,fontproperties=font,fontsize=16);ax.grid(axis='y',alpha=.2);ax.set_axisbelow(True)
 for b,v in zip(bars,values):ax.text(b.get_x()+b.get_width()/2,b.get_height(),f'{v:,}',ha='center',va='bottom',fontsize=9)
 ax.set_ylim(0,max(values,default=1)*1.16 or 1)
bars(axes[0,0],[str(i)+'条' for i in range(6)],[t['topCountHistogram'].get(str(i),0) for i in range(6)],'每个第二球位置的推荐条数')
bars(axes[0,1],['微调前','微调后'],[t['baseEligible25'],t['afterEligible']],'符合新规则的第二球×组合数量')
rails=sorted(t['railHistogram'],key=int);bars(axes[1,0],rails,[t['railHistogram'][k] for k in rails],'推荐路线吃库次数（按题目引用计）')
cats=['center','vertical','horizontal','mixed'];bars(axes[1,1],['中杆','纯高低','纯左右','混合'],[t['categoryHistogram'].get(k,0) for k in cats],'推荐路线杆法（按题目引用计）')
fig.tight_layout(rect=[0,0,1,.95]);fig.savefig(OUT/'statistics.png',dpi=170);plt.close(fig)
base=(OUT/'README.md').read_text(); marker='## 全量统计\n'
if marker in base:base=base.split(marker)[0]
base=base.replace('# 两球25°微调全量（准备中，不能作为完整题库）','# 两球25°微调全量（审计通过）')
base=base.replace('13,570初始球形，173,577第二球候选位置，16原生计算进程。只有 summary.json 的 state=complete 且 auditPassed=true 后才可切换为全量结果。','13,570唯一初始球形、173,577第二球位置已全量核验；summary.json为complete、auditPassed=true。采用16个原生计算进程。')
stats=f'''{marker}

- 新规则微调前有效组合对：{t['baseEligible25']:,}；微调后：{t['afterEligible']:,}；增加：{t['addedByTune']:,}。
- 推荐路线引用：{t['afterTop']:,}；每初始球形共享路线合计：{t['uniqueFinalRoutes']:,}。
- 每B推荐数量分布：{json.dumps(t['topCountHistogram'],ensure_ascii=False)}。空B保持存档，不强补。
- 新增模拟：{t['newSimulations']:,}；结果：{json.dumps(t['newStatus'],ensure_ascii=False)}。模拟成功仅表示首杆成功，仍可能不满足新规则。
- 原参数回放核验：{t['unchangedReplays']:,}球形。五题试跑对拍：{t['checks']['pilotParity']}；完整贪心对拍：{t['checks']['fullGreedyParity']}；最终成对P2验证：{t['checks']['verifiedTopPairs']:,}。
- 本次计算写盘：{s['computeAndWriteSeconds']:.2f}秒；末尾审计：{s['auditSeconds']:.2f}秒；本次启动至审计完成：{s['startupThroughAuditSeconds']:.2f}秒。若有续跑，详sessions目录累计耗时。
- 最终分片压缩总大小：{s['finalGzipBytes']:,} bytes（{s['finalGzipBytes']/1e6:.2f} MB）；微调过程独立压缩：{s['refinementGzipBytes']:,} bytes（{s['refinementGzipBytes']/1e9:.3f} GB）。不含原始125组源文件。

![统计图](statistics.png)

进程/设备收尾见cleanup.json；外层设备租约释放在运行器退出后核对。完整分片清单与SHA见parts-index.json，冻结代码/源索引及规则见manifest.json。本报告为研究题库结果，未作App上线或真机验收声明。
'''
(OUT/'README.md').write_text(base+stats)
print('REPORT',OUT/'README.md')
