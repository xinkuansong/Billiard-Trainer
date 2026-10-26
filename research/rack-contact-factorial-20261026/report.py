from pathlib import Path
import json,gzip,math
import numpy as np
import matplotlib;matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties,fontManager
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-contact-factorial-20261026'
font='/System/Library/Fonts/Hiragino Sans GB.ttc';fontManager.addfont(font);plt.rcParams['font.family']=FontProperties(fname=font).get_name();plt.rcParams['axes.unicode_minus']=False
A=json.loads((OUT/'analysis.json').read_text());G=A['groups'];D=json.loads((OUT/'derived.json').read_text());V=json.loads((OUT/'verification.json').read_text())
labels=[f'{chr(65+r)}{c+1}' for r in range(5) for c in range(r+1)]
keys=['250um_1e-07_forward','250um_1e-07_reverse','1um_1e-12_forward'];energies={k:[] for k in keys}
for p in OUT.glob('raw-*.jsonl.gz'):
 with gzip.open(p,'rt') as f:
  for line in f:
   r=json.loads(line);i=r['input'];k=f"{i['contactEpsilon']*1e6:g}um_{i['tieEpsilon']:g}_{'reverse' if i['reverseRegistration'] else 'forward'}"
   if k in energies:
    e=np.array([sum(x*x for x in b['v']) for b in r['samples'][1]['states'][1:]]);energies[k].append(e/e.sum()*100)
fig,axs=plt.subplots(1,3,figsize=(15,5.7),facecolor='#f6f7fa')
titles=['当前容差 0.25mm · 原顺序','当前容差 0.25mm · 倒序','研究容差 0.001mm · 近严格时序']
for ax,k,title in zip(axs,keys,titles):
 ax.set_facecolor('#f6f7fa');e=np.mean(energies[k],axis=0);xs=[];ys=[]
 for r in range(5):
  for c in range(r+1):xs.append(c-r/2);ys.append(-r*.866)
 ax.scatter(xs,ys,c=e,cmap='YlOrRd',vmin=0,vmax=55,s=1900,edgecolor='#475569',linewidth=1.2)
 for j,(x,y) in enumerate(zip(xs,ys)):
  ax.text(x,y,f'{labels[j]}\n{e[j]:.2f}%',ha='center',va='center',fontsize=10.5,color='white' if e[j]>35 else '#1e293b')
 ax.set_title(title,fontsize=14,pad=18);ax.set_aspect('equal');ax.set_xlim(-2.6,2.6);ax.set_ylim(-4.4,.65);ax.axis('off')
 ax.text(0,-4.15,f"内部三球合计 {G[k]['interiorShare']*100:.3f}%",ha='center',fontsize=12,color='#334155')
fig.suptitle('能量更对称，但更集中到两个底角球',fontsize=20,y=1.02)
fig.text(.5,.01,'200副相同随机球形；颜色与百分比 = 首碰后5ms各球占目标球平动能量的平均比例。位置仅表示初始槽位。',ha='center',fontsize=11,color='#475569')
fig.savefig(OUT/'energy-map.png',dpi=150,bbox_inches='tight');plt.close(fig)
fig,axs=plt.subplots(1,2,figsize=(11,4.3));x=np.arange(3);width=.34
for j,(order,label,color) in enumerate([('forward','原顺序','#2563eb'),('reverse','倒序','#f59e0b')]):
 vals=[G[f'{e}um_1e-07_{order}']['passed']/2 for e in [250,10,1]]
 bars=axs[0].bar(x+(j-.5)*width,vals,width,label=label,color=color)
 for bar,v in zip(bars,vals):axs[0].text(bar.get_x()+bar.get_width()/2,v+.3,f'{v:.1f}%',ha='center')
 ts=[G[f'{e}um_1e-07_{order}']['wallMSMedian'] for e in [250,10,1]]
 bars=axs[1].bar(x+(j-.5)*width,ts,width,label=label,color=color)
 for bar,v in zip(bars,ts):axs[1].text(bar.get_x()+bar.get_width()/2,v+3,f'{v:.0f}',ha='center')
for ax in axs:ax.set_xticks(x,['0.25mm 当前','0.01mm 研究','0.001mm 研究']);ax.spines[['top','right']].set_visible(False);ax.set_xlabel('接触容差；球与球的初始距离完全相同')
axs[0].set_title('开散评分 ≥1.20（每组200次）');axs[0].set_ylabel('达标率 %');axs[0].set_ylim(0,14);axs[0].legend(frameon=False)
axs[1].set_title('单次计算耗时中位数');axs[1].set_ylabel('毫秒');axs[1].set_ylim(0,210)
fig.tight_layout();fig.savefig(OUT/'outcome-and-time.png',dpi=150,bbox_inches='tight');plt.close(fig)
lines=['# 正中开球：接触与排序因素隔离研究','', '**结论：接触容差确实放大了注册顺序对传力的影响；但减弱这种影响，并没有让球更容易开散。单纯把容差调小不是本轮找到的优化方案。**','', '200副全新随机球形 × 12组配对设置，共2400次全部停稳。仍用现行球间距和每球独立圆盘随机偏移，母球居中瞄准实际顶球，杆头速度9.75m/s、零旋转；开散仍按既有剩余球数校准的平均最近邻指数≥1.20。进球允许，母球不计入散度。生产代码、摆球方式和标定数据均未修改。','', '## 直接结果','', '下面保留当前0.1µs事件排序容差，只改变研究副本的接触容差。每行是相同200副球形。','', '|接触容差|注册顺序|达标数/率|平均散度|5ms内部三球能量|计算中位/P95|','|---|---|---|---|---|---|']
for e in [250,10,1]:
 for o in ['forward','reverse']:
  g=G[f'{e}um_1e-07_{o}'];lines.append(f"|{e/1000:g}mm|{'原顺序' if o=='forward' else '倒序'}|{g['passed']}/200 · {g['passed']/2:.1f}%|{g['index']:.3f}|{g['interiorShare']*100:.3f}%|{g['wallMSMedian']:.1f}/{g['wallMSP95']:.1f}ms|")
lines+=['','![达标率与耗时](outcome-and-time.png)','', '原顺序0.01mm比当前少10个百分点，配对bootstrap的多重比较调整区间约[-16.5,-4.0]个百分点；0.001mm少9个百分点，约[-16.0,-3.0]。反转注册顺序的21→23次差异没有可靠改善证据。统计单位为200副球形，不把2400次视作2400个独立样本。','', '## 碰撞先后与能量传递','', '1. **当前0.25mm容差是明显的顺序放大因素。** 原顺序首碰同刻平均发生19.765次两球冲量；倒序25.45次。缩小到0.01/0.001mm后均为1次（母球撞顶球）。在当前参数下，只倒转注册顺序，200/200副终局改变，38/200副跨过1.20判据。','2. **只缩小事件排序的时间容差基本无效。** 在0.25mm接触容差下，把近同时判断从0.1µs收紧到1ps，两种注册顺序各200副的5ms状态全部一致；终局原顺序200/200一致、倒序199/200一致，达标数不变。主要矛盾不是这0.1µs本身。','3. **更接近按到达先后处理后，能量集中到两侧底角。** 1µm接触/1ps排序下，E1/E5约45.01%/43.47%，合计88.48%；C2+D2+D3仅0.052%。当前原顺序则为53.89%/11.30%，内部三球1.32%。内部三球的平均最近邻表面间隙也从1.50mm变为0.233mm，5ms仍很拥挤。','4. **总能量并未明显不足。** 当前及小容差设置中，全部目标球的5ms平动能均约为首碰前来球平动能的76%。差异主要体现在能量分给了哪些球：有效能量参与球数从3.48降至约2.01。该指标为(sum E)²/sum(E²)，不是实际运动球数量。','', '![5ms能量槽位图](energy-map.png)','', '这给出一个有数据支持的方向：开散需要更多内部球获得足够的、彼此不同的速度；仅让两个外侧底角更有力或让左右更对称，不能满足目标。这里的能量比例是本模型的观察，不等同真实球架的实测定律，也尚未验证某种局部摆球调整可以达到该目的。','', '## 尚未隔离完的因素','', '小容差＋1ps排序时，倒序引起的E1能量占比平均绝对变化已从42.32个百分点降至约0.00014个百分点；但终局仍未达到顺序不变，两组共有在台球的平均终局位置差约11.1cm。该指标只统计两次都未进袋的同号目标球，进袋差异另计（35/200副）。早期近似一致不代表后续完整轨迹已一致；残余差异也可能包含浮点误差的后续放大，本轮未定位第一处分歧。','', '首碰后20ms内还记录到61次“沿两球连线已在分离，却仍施加冲量”的事件（跨设置重复同一球架会重复计数）。最显著的2037号球架，母球与顶球在约7.905µs时已有0.1215mm间隙、分离速度14.10m/s，却再次出现冲量；多个小容差设置也存在。需继续检查碰撞预测/缓存与执行时接近条件，不能用缩小容差宣称已修复。所有异常原样保留，主分析没有剔除球架。另做全设置配对剔除的敏感性检查：去除任一设置出现上述冲量的13副后，保留187副，当前原顺序达标20次，小容差各组0～3次，结论方向未变。','', '速度跳变核对中无超过两球的事件；最大两球速度增量和残差2.84e-6m/s，所有已提取两球事件的平动＋转动总能量变化均为负。守恒检查通过并不能证明上述碰撞时机正确。','', '## 对摆球优化的实际含义','', '- 当前范围内的微小球缝，与0.25mm接触判定处于同一量级。仅按终局挑选“某些球要更靠近”的规律，可能同时学到注册顺序的影响。','- 本轮没有找到可直接采用的新摆法；也没有证明把容差收紧能提高开散率，结果相反。','- 后续局部球位研究的可检验假设应是：在原有间隙/偏移范围内，哪些组合能改变向两侧底角集中传力的路径，使C2、D2、D3在前几毫秒获得更大的相对速度。需要同球架配对扰动、前后注册顺序对照及独立新样本验证；该假设目前未得到干预验证。','- 若继续追究计算偏差，优先追踪2037号母球—顶球的第二次冲量，以及小容差下正倒序的第一处分歧，而不是依据高散度反向调参数。','', '## 完整矩阵与验证','', '|接触µm|时间容差|顺序|达标/200|5ms E1/E5 %|内部三球 %|分离冲量所在局数|','|---|---|---|---|---|---|---|']
for e in [250,10,1]:
 for t in ['1e-07','1e-12']:
  for o in ['forward','reverse']:
   g=G[f'{e}um_{t}_{o}'];lines.append(f"|{e}|{'0.1µs' if t=='1e-07' else '1ps'}|{'原' if o=='forward' else '倒'}|{g['passed']}|{g['E1']*100:.2f}/{g['E5']*100:.2f}|{g['interiorShare']*100:.3f}|{g['separatingRacks']}|")
lines+=['','- 在观察新样本结果前固定矩阵、种子和比较指标。新200种子与旧2000种子无重合；无按结果选样。','- 24次当前参数重放与上一轮终局、5ms及碰撞记录完全一致；12次新设置重复运行一致。2400份散度、能量比例及内部间隙均用独立标量算法复算。','- 最早非球碰撞发生于41.63ms，1/5/20ms分析不受吃库干扰。','- 达标差使用20000次配对bootstrap，11组对基线比较与6组顺序比较分别Bonferroni调整；有限样本区间是近似估计，不代替真实球台验证。','- 耗时仅为同批4进程交错运行、同设备原生计算的墙钟数据，不包含诊断序列化；小容差组约134ms、当前166ms，伴随事件数约182→157。初始球间距未变，不能据此推断“球越靠近一定算得越慢”。','- Worker全部正常退出，compact-pad已Shutdown、租约归还，受管临时工作目录已reclaimed。研究改动仅在research/output/tasks；生产物理和摆球文件SHA复核无变化。','', '证据：[协议](protocol.json) · [完整统计](analysis.json) · [独立核验](verification.json) · [碰撞异常账本](impulse-audit.json) · [源码差异](EngineNumerics.swift.diff) · [资源收尾](closure.json)。']
(OUT/'REPORT.md').write_text('\n'.join(lines)+'\n')
