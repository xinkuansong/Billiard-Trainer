from common import *
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle
from matplotlib.font_manager import FontProperties
FONT=FontProperties(fname='/System/Library/Fonts/Hiragino Sans GB.ttc',weight=300);plt.rcParams['axes.unicode_minus']=False
C=json.loads((OUT/'confirmation/summary.json').read_text());P=json.loads((OUT/'confirmation/protocol.json').read_text());F=json.loads((OUT/'confirmation/final-outcomes.json').read_text());vs=P['variants'];colors=['#7c8996','#d09960','#278e9c','#ae638e']
fig,axs=plt.subplots(1,3,figsize=(13,4.4))
for ax,key,title in zip(axs,['mean','passRate','wallMeanMS'],['平均散开分','达到 1.20 的比例','平均物理计算耗时 / 毫秒']):
 vals=[C['variants'][v][key]*(100 if key=='passRate' else 1) for v in vs];ax.bar(range(4),vals,color=colors);ax.set_xticks(range(4),[label(v) for v in vs],rotation=20,ha='right',fontproperties=FONT);ax.set_title(title,fontproperties=FONT);ax.set_ylim(0,max(vals)*1.2)
 for i,a in enumerate(vals):ax.text(i,a,f'{a:.4f}' if key=='mean' else f'{a:.1f}'+('%' if key=='passRate' else ''),ha='center',va='bottom')
fig.suptitle('最后一轮独立 1,000 副球阵：共同向内与独立向内的对照',fontproperties=FONT,fontsize=14);fig.tight_layout();fig.savefig(OUT/'confirmation.png',dpi=180,bbox_inches='tight');plt.close(fig)
raw=json.loads((OUT/'confirmation/preflight/pilot.json').read_text());seed=min(r['input']['rackID'] for r in raw);compare=['baseline','radial_independent','radial_contract'];fig,axs=plt.subplots(1,3,figsize=(13,5.3))
for ax,v,col in zip(axs,compare,['#7c8996','#ae638e','#278e9c']):
 rr=next(r for r in raw if r['input']['rackID']==seed and r['input']['variant']==v);p=np.array([[b['x'],b['z']] for b in rr['rack']]);d=p-NOM
 for i in range(15):
  ax.add_patch(Circle(NOM[i],R,facecolor='#edf3f6',edgecolor='#a5bac5',lw=.7));ax.annotate('',xy=NOM[i]+300*d[i],xytext=NOM[i],arrowprops=dict(arrowstyle='->',lw=1.7,color=col));ax.text(NOM[i,0],NOM[i,1]+R*.6,NAMES[i],fontsize=7,ha='center',va='center',color='#495761')
 center=NOM.mean(0);ax.plot(*center,'x',color='#333',markersize=6);ax.set_xlim(-.88,-.58);ax.set_ylim(-.15,.15);ax.set_aspect('equal');ax.axis('off')
 gap=np.mean(C['variants'][v]['edgeGapMeanMM']);ax.set_title(label(v)+f'\n全样本平均间隙 {gap:.4f} 毫米',fontproperties=FONT,fontsize=11)
fig.suptitle('同一随机输入的偏移方向（箭头放大 300 倍；× 为球阵中心）',fontproperties=FONT,fontsize=14);fig.tight_layout();fig.savefig(OUT/'inward-patterns.png',dpi=180,bbox_inches='tight');plt.close(fig)
fig,axs=plt.subplots(1,3,figsize=(12,4))
for ax,v in zip(axs,compare):
 im=ax.imshow(C['variants'][v]['edgeGapCorrelation'],vmin=-1,vmax=1,cmap='coolwarm');ax.set_title(label(v),fontproperties=FONT);ax.set_xlabel('邻接边编号',fontproperties=FONT);ax.set_ylabel('邻接边编号',fontproperties=FONT)
fig.colorbar(im,ax=axs,shrink=.8,pad=.02);fig.suptitle('30 条初始邻接间隙的相关系数（跨 1,000 副球阵）',fontproperties=FONT,fontsize=14);fig.savefig(OUT/'gap-correlation.png',dpi=180,bbox_inches='tight');plt.close(fig)
intro=['# 全阵随机方向关联与碰撞先后研究','','**找到新的研究候选：共同向内偏移。** 固定正中开球下，最后独立1000副配对确认相对生产平均分提高6.03%，相对旧三球方案提高5.06%，相对各球独立向内提高3.94%；四项预定比较的家族95%区间均为正。达到1.20的比例仍只有14.2%，尚未达到“大多数开球都很散”。','','本轮共17,400次正式实验：5,400次筛选、8,000次独立复验、4,000次条件触发确认，另有基线和确定性重放。全部停稳，生产代码未改。','','## 最后一轮独立确认','','确认计划在读取2000副复验结果前冻结；只有“收缩组配对改善区间为正，展开减收缩区间为负”同时成立才执行。满足条件后，对1000个额外新seed比较生产、旧三球、共同向内、各球独立向内。不是在同批数据中挑高分球架。','','|摆法|平均分|≥1.20|平均物理耗时 ms|平均初始相邻间隙 mm|','|---|---:|---:|---:|---:|']
for v in vs:
 s=C['variants'][v];intro.append(f"|{label(v)}|{s['mean']:.6f}|{s['passRate']:.1%}|{s['wallMeanMS']:.2f}|{np.mean(s['edgeGapMeanMM']):.6f}|")
intro+=['','![最终确认](confirmation.png)','','|比较|配对平均差|相对均分变化|四项校正95%区间|前/后500平均差|','|---|---:|---:|---|---|']
for key,c in C['comparisons'].items():
 a,b=key.split('--');intro.append(f"|{label(a)} 对 {label(b)}|{c['mean']:+.6f}|{c['relativeMeanChange']:+.2%}|[{c['family95'][0]:+.6f}, {c['family95'][1]:+.6f}]|{c['halfMeans'][0]:+.5f}/{c['halfMeans'][1]:+.5f}|")
intro+=['','## 支持的摆球规律','','保持每颗球原来的随机偏移长度，将方向换算到“相对于球阵中心”的坐标，使用共同的随机方向并保证其有向内分量，再转回每颗球的位置。由此产生协调的微量收紧和切向偏移；每次随机输入直接生成一次球阵，无需先模拟多次挑选。','', '这一确认版本会偏向内侧，改变单球方向分布。与它对照的“各球独立向内”也有相同理论方向边际分布和偏移长度分布，但各球方向彼此独立。两者实际平均间隙0.176209/0.176754毫米，非常接近；共同向内仍显著领先，支持方向关联具有额外贡献。名义理想球位间隙仍0.20毫米，单球偏移上限仍0.09毫米，没有零间隙或重叠。','','![向内的两种方式](inward-patterns.png)','','两种向内方式去均值后的相邻球方向相关系数均值分别为0.658和-0.00045，符合预期关联差异；不共享球的邻接间隙相关系数均值分别为0.131和0.00096。相关性是输入结构检查，不单独充当因果机制证明。','','![间隙相关](gap-correlation.png)','','## 散开、耗时与其他结果','','共同向内的平均物理计算耗时171.95→177.56毫秒，约增加3.26%，P95为204.38→206.85毫秒；仅本机四进程模拟器、同批随机交错，不是iPhone性能或完整生成耗时。','','|摆法|停球后近邻球数均值|近邻球占剩球比例|剩余目标球数均值|母球落袋率|','|---|---:|---:|---:|---:|']
for v in vs:
 s=F['variants'][v];intro.append(f"|{label(v)}|{s['closeBalls']:.3f}|{s['closeFraction']:.2%}|{s['remaining']:.3f}|{s['cueScratched']:.1%}|")
intro+=['','这里近邻定义为球心距小于两个球直径，仅作事后辅助诊断。共同向内留下的目标球更多，但近邻球更少，均分收益未伴随“靠多进球减少密集球”的现象。母球落袋本批5.4%→7.2%，属于需要继续核验的潜在代价；这些次要指标未做主分析同等的预先多重比较控制。','','早期能量均匀化不能作为唯一目标：最终确认中，共同向内在5毫秒的内部三球能量/入射母球能量为0.368%，低于生产1.023%，最终平均分却更好。球位关联确实改变碰撞先后，但这次尚未完成后续多次碰撞到终局的完整因果分解。','','## 验证范围','','17,400条终局分独立标量重算，最大差6.7e-16；3,300个新seed互不重复且与此前4,400副不同。逐球方向变换由Python独立复算，偏移长度仅有Float舍入变化，全部105球对无初始重叠。33项生产源绑定无漂移；三轮各12条历史基线对拍和12条新结果重放。12个worker退出0、设备Shutdown并释放租约，三处独占构建工作区已回收。','','结论适用于当前生产引擎与固定正中开球。未跨碰撞模型、不同开球位置/杆速或真机性能验证；没有接入生产。','','---','','以下保留前两阶段的详细协议、候选筛选与独立复验，避免混合不同样本批次的基线。','']
core=(OUT/'REPORT-validation.md').read_text();(OUT/'REPORT.md').write_text('\n'.join(intro)+core)
print('Final report and three confirmation figures generated.')
