from pathlib import Path
import json
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import fontManager
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/two-ball-strike-sampled100-20261024'
s=json.loads((OUT/'summary.json').read_text());assert s['state']=='complete' and s['auditPassed'] and s['completedLayouts']==135700 and s['completedAttempts']==13570000
hist={int(k):v for k,v in s['validCountHistogram'].items()};rails={int(k):v for k,v in s['mainRailsForValid'].items()};status=s['status']
valid=status.get('success',0);n=s['completedLayouts'];total=s['completedAttempts'];zero=hist.get(0,0)
def quantile(q):
 threshold=q*(n-1);running=0
 for count,freq in sorted(hist.items()):
  running+=freq
  if running>threshold:return count
metrics={'validAttempts':valid,'validPercent':100*valid/total,'layoutsWithValid':n-zero,'layoutsWithoutValid':zero,'meanValidPerLayout':valid/n,'medianValidPerLayout':quantile(.5),'p10Valid':quantile(.1),'p90Valid':quantile(.9),'minValid':min(hist),'maxValid':max(hist),'compressedGB':s['compressedBytes']/1e9,'elapsedHours':s['elapsedSeconds']/3600}
(OUT/'report-metrics.json').write_text(json.dumps(metrics,ensure_ascii=False,indent=2))
fontManager.addfont('/Library/Fonts/Arial Unicode.ttf');plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
fig,axes=plt.subplots(1,2,figsize=(14,5.5));groups=[(0,0),(1,20),(21,40),(41,60),(61,80),(81,100)];ys=[sum(v for k,v in hist.items() if a<=k<=b) for a,b in groups];labels=['0','1–20','21–40','41–60','61–80','81–100']
axes[0].bar(labels,ys,color='#247d8d');axes[0].set_title('每个球形的有效组合数量');axes[0].set_xlabel('100次尝试中的有效次数');axes[0].set_ylabel('球形数量')
for i,y in enumerate(ys):axes[0].text(i,y,f'{y:,}',ha='center',va='bottom',fontsize=10)
x=sorted(rails);axes[1].bar(x,[rails[i] for i in x],color='#b47a31');axes[1].set_title('有效组合的碰球后主库次数');axes[1].set_xlabel('主库碰撞次数（袋角单独记录）');axes[1].set_ylabel('有效组合数量');axes[1].set_xticks(x)
for ax in axes:ax.spines[['top','right']].set_visible(False);ax.grid(axis='y',alpha=.15);ax.set_axisbelow(True);ax.margins(y=.14)
fig.suptitle(f'135,700球形 × 随机100组 · 有效 {valid:,} / {total:,}',fontsize=18);fig.tight_layout(rect=[0,0,1,.93]);fig.savefig(OUT/'full-statistics.png',dpi=170);fig.savefig(OUT/'full-statistics.svg');plt.close(fig)
lines=['# 全量击球参数采样结果（2026-10-24）','',f'共135,700球形，每个球形独立从630组不放回随机取100组，共{total:,}条记录；8个原生计算进程。非法参数/失败均不补抽。原题库与第二球候选数组未覆盖。','', '| 结果 | 数量 |','|---|---:|']
cn={'success':'有效组合','illegal_parameters':'非法参数（无法出杆）','target_miss':'未进指定目标袋','scratch':'母球落袋','unresolved':'求解未完成/几何无解','no_valid_stop':'无有效停点'}
for k,v in status.items():lines.append(f'| {cn.get(k,k)} | {v:,} |')
lines += ['',f'有有效组合的球形：{n-zero:,}；无有效组合：{zero:,}。平均每球形{valid/n:.2f}个有效组合，中位数{quantile(.5)}，范围{min(hist)}–{max(hist)}。',f'结果分片压缩体积：{s["compressedBytes"]/1e9:.3f} GB；本轮运行与全量审计耗时{s["elapsedSeconds"]/3600:.2f}小时（不含首次构建及已归档的准备尝试）。','', '## 保存方式','', '`parts/*.jsonl.gz`共1,357片，每片100个球形，每行一个球形及其100条尝试。`layouts.json`与原ID对应；`receipts`保存各片SHA/统计。`run-manifest.json`、`producer-hashes.json`、`execution-identity.json`固定源题库、采样协议、构建与代码版本。','', '每次尝试保存原630格中的comboIndex、实际打点/杆速、实际瞄准方向与下球点、参数合法性、有效停点/末端观测、进球袋号/母球落袋、主库与袋角事件、终止状态和耗时。不保存轨迹帧/折线。','', '## 验证与边界','', '原生入口对拍上一轮630组，除计时外逐字段一致；所有135,700×100条记录重新解压审计：球形唯一、采样ID/Float输入一致、进袋与事件一致、吃库计数一致、分片SHA与统计一致；原库SHA未变。无效参数不计入有效走位。','', '沿用生产predictForPositionSolve、500事件/15秒限额、planarReference模型、原题库下球点覆盖与平面击球elevation=0。出杆姿态仰角另存，并非抬杆物理验证。有效组合没有新增袋角/多次碰球淘汰规则，相关事件均保留。此阶段尚未加入第二球B做轨迹干扰复验。','', '8进程的含义为8个独立原生物理进程，共用一台受管模拟器运行环境；没有启动8份完整App，也没有创建模拟器克隆。','', '![全量统计](full-statistics.png)','']
(OUT/'README.md').write_text('\n'.join(lines));print(json.dumps(metrics,ensure_ascii=False,indent=2))
