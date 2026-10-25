import argparse
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties, fontManager
import pipeline as P
ap=argparse.ArgumentParser();ap.add_argument('stage',choices=['a','b']);a=ap.parse_args();out=P.A if a.stage=='a' else P.B;s=P.read(out/'summary.json');assert s['state']=='complete' and s['auditPassed'];st=s['stats']
fontManager.addfont('/Library/Fonts/Arial Unicode.ttf')
font=FontProperties(fname='/Library/Fonts/Arial Unicode.ttf');plt.rcParams.update({'font.family':font.get_name(),'axes.unicode_minus':False})
fig,axes=plt.subplots(1,2,figsize=(14,5.4))
if a.stage=='a':
 labels=['原推荐','中袋验证删除','保留'];values=[st['beforeTop'],st['deleted'],st['afterTop']];title='第二杆中袋验证 · 全量结果'
else:
 labels=['中袋筛选后','18°网格优化后'];values=[st['beforeTop'],st['afterTop']];title='18°网格微调 · 吃库次数和顺序保持不变'
axes[0].bar(labels,values,color=['#7a8992','#bd6639','#168498'][:len(values)])
for i,n in enumerate(values):axes[0].text(i,n,f'{n:,}',ha='center',va='bottom')
h=st['topCountHistogram'];vals=[h.get(str(i),0) for i in range(6)];axes[1].bar(range(6),vals,color='#168498');axes[1].set_xlabel('每个第二球位置的推荐条数');axes[1].set_ylabel('第二球位置数量')
for i,n in enumerate(vals):axes[1].text(i,n,f'{n:,}',ha='center',va='bottom')
for ax in axes:ax.spines[['top','right']].set_visible(False);ax.margins(y=.15)
fig.suptitle(title,fontsize=19);fig.tight_layout();fig.savefig(out/'statistics.png',dpi=160);plt.close(fig)
text=f'''# {title}

全量审计通过。{st['layouts']:,}初始布局，{st['BPositions']:,}第二球位置。

- 输入推荐：{st['beforeTop']:,}
- 输出推荐：{st['afterTop']:,}
- 有推荐的第二球位置：{st['BPositions']-h.get('0',0):,}；空位置：{h.get('0',0):,}
- 16进程计算写盘：{s['computeAndWriteSeconds']:.2f}秒；审计：{s['auditSeconds']:.2f}秒。
- 推荐数据gzip：{s['finalGzipBytes']/1e6:.2f}MB；验证/搜索证据gzip：{s['proofGzipBytes']/1e6:.2f}MB。

![统计](statistics.png)

推荐数据在parts/，同名proofs/为独立压缩证据，receipts/为每分片SHA。
按layout.id→candidates[].cellID定位两球题；top5[].comboIndex引用本行routes[]。
位置和2mm轨迹坐标为世界XZ米制。中袋推荐的middleProofKey引用物理验证证据。
原25°题库与App消费端均未替换。
'''
if a.stage=='a':text+=f"\n本轮验证中袋{st['middleChecked']:,}条，删除{st['deleted']:,}条，保留中袋{st['middlePassed']:,}条；角袋{st['unchangedCorner']:,}条原样保留。固定中杆方向，至多5个速度；失败表示未通过此有界验证，不是全参数无解证明。\n"
else:text+=f"\n中袋验证可复用阶段A已通过的证据；若middleProofKey不在当前proofs分片，按manifest.schedule中同分片的proofs路径及SHA读取阶段A证据。\n新首杆模拟{st['newSimulations']:,}组，状态门槛在评分前执行；第二杆≤18°，所有网格合格项排序，P2≥60去重取前5。中袋新结果也已验证。最优限于记录的固定网格，非连续空间全局最优。\n\n库数分布：{st['railHistogram']}\n\n杆法分布：{st['categoryHistogram']}\n"
(out/'README.md').write_text(text)
print(out/'README.md')
