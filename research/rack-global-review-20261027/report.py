from pathlib import Path
import json,hashlib,math
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-global-review-20261027'
s=json.loads((OUT/'summary.json').read_text());paired=json.loads((OUT/'paired.json').read_text());rows=json.loads((OUT/'rows.json').read_text())
labels={'baseline':'生产摆法（研究引擎）','independent':'独立随机方向','inner_first':'内侧优先','template_09':'模板09','parent':'内侧优先（本批）','corerear_90':'方案A','late_60_0_90':'方案B','parentB':'方案B（本批）','exit_-30':'近期候选C（−30°）','exit_-60':'候选D（−60°）'}
lines=['# 回到整副球阵：已有数据的开散与速度均匀性比较','',
'结论：速度分配过度集中需要改善，但速度均匀不是充分条件。当前C在早期全阵传播上有配对改善，尚无证据证明停稳开散胜过B。以停稳开散为主，B继续作为主基线；若同时强调母球安全，A应并列保留。不能宣称已有唯一整体最优。','',
'## 数据与可比范围','',
'三轮各200副独立holdout，4＋3＋3组共2000次已有模拟，覆盖8种独立摆法（内侧优先和B各重复一批）。仅重算结果，没有新模拟。六份修复研究引擎SHA相同，全部物理参数相同，杆速10；每轮同种子实际母球初速度相同。生产摆法也放在同一修复研究引擎中运行，不代表生产引擎当前实测成绩。','',
'不同轮的随机种子不同，只在同轮计算配对差；A与C没有同种子直接比较。新指标是事后探索，4000次配对bootstrap区间未作多重检验校正，不能冒充全新确认实验。旧散度评分仅观察，不排名。','',
'## 指标定义','',
'- 速度大小以首次球球碰撞后5ms的15颗目标球计算，排除母球。CV=标准差/均值，越低越均匀；最慢5球均速检视低速尾部。最快2球占比只算平动能；有效参与数15代表能量均分，1代表集中于一球。',
'- 100ms离阵：球心在初始球心凸包之外至少一个球径。近邻对：原30对邻球仍然表面净距小于一个球径。三轮在100ms均无目标球落袋，不存在早期消失计数造成的改善。',
'- 最终最近球净距：每颗在台目标球到最近目标球的表面距离，再取均值。近邻球：至少有一个目标邻球表面净距<57.15mm。它是描述性几何阈值，不等于难打/不可清台；同时复核半球径与两球径。最大簇为上述邻接关系的连通分量，落袋另报。','',
'## 同轮比较','']
for batch,title in [(0,'第一轮：整体方向策略'),(1,'第二轮：阵心方案A/B'),(2,'第三轮：前阵心候选C/D')]:
    lines += ['### '+title,'','每行200副，同一表内为同种子配对。','',
    '| 摆法 | 5ms均速 m/s | 速度CV↓ | 最慢5球 m/s | 最快2球能量占比↓ | 100ms离阵球↑ | 100ms近邻对↓ |',
    '|---|---:|---:|---:|---:|---:|---:|']
    group=[(key,a)for key,a in s.items() if key.startswith(str(batch)+':')]
    for key,a in group:lines.append(f"|{labels[key.split(':')[1]]}|{a['meanSpeed']:.3f}|{a['speedCV']:.3f}|{a['bottom5Speed']:.3f}|{a['top2Share']:.1%}|{a['escape100']:.2f}|{a['closePairs100']:.2f}|")
    lines+=['','| 摆法 | 停稳最近球净距 cm↑ | 近邻球数↓ | 近邻球比例↓ | 最大簇球数↓ | 目标球落袋 | 母球落袋↓ | 自转尾段 s↓ |','|---|---:|---:|---:|---:|---:|---:|---:|']
    for key,a in group:lines.append(f"|{labels[key.split(':')[1]]}|{100*a['nearestGap']:.2f}|{a['crowded_one']:.2f}|{a['crowdedFraction_one']:.1%}|{a['largest_one']:.2f}|{a['potted']:.2f}|{a['scratch']:.1%}|{a['tail']:.3f}|")
    lines+=['']
lines += ['## 关键配对证据','',
'下面均为新方案减参照的平均差和95%区间。速度/离阵/净距越高通常越好；CV/近邻球/自转越低通常越好，但不将它们加权捏成单一总分。','']
for name,title in [('0:inner_first-baseline','内侧优先 − 生产摆法'),('0:template_09-inner_first','模板09 − 内侧优先'),('1:late_60_0_90-corerear_90','B − A'),('2:exit_-30-parentB','C − B'),('2:exit_-60-parentB','D − B')]:
    lines+=['### '+title,'']
    for k,label,scale in [('speedCV','速度CV',1),('top2Share','最快2球能量占比百分点',100),('nEff','有效能量参与数',1),('escape100','100ms离阵球数',1),('closePairs100','100ms近邻对',1),('nearestGap','停稳最近球净距cm',100),('crowded_one','停稳近邻球数',1),('largest_one','最大簇球数',1),('scratch','母球落袋百分点',100),('tail','自转尾段秒',1)]:
        d=paired[name][k];lines.append(f"- {label}：{scale*d['mean']:+.3f} [{scale*d['ci95'][0]:+.3f}, {scale*d['ci95'][1]:+.3f}]。")
    lines+=['']
lines+=['## 怎么看“所有球速度比较均匀”','',
'这个方向有依据：从生产摆法到内侧优先，最快两球能量占比95.5%→63.0%，100ms近邻对21.98→12.67，最终近邻球6.95→4.80，改善同时发生。不能由此推出所有后续策略越均匀越好。','',
'明确的反例：A有效能量参与数5.07，比B的4.49更均匀，最快两球占比也更低；B却有更大的最终净距、更少的近邻球和更小的最大簇。两者总平动能15.10/15.02J接近，差异不能简单归结为多加了力度。B同时有母球落袋1%→4.5%的代价，不能省略。','',
'最近C也不是完全没有全局收益：同批B→C的全阵均速2.415→2.487m/s、最慢5球均速0.351→0.415m/s、CV1.028→0.965、100ms离阵8.405→8.900、残留近邻对9.310→8.005，配对区间均支持这些早期改变。但最终净距只增加0.126cm，区间[−0.776,+0.999]cm，近邻球仅少0.11颗，区间[−0.48,+0.26]，自转亦未明确改变。早期收益没有被证明延续到停稳。','',
'D较B在半球径阈值的贴近球数反而多0.385颗，区间[+0.060,+0.710]；C在半/一/两球径阈值的差值区间均跨零。这再次说明不能用早期速度均匀度替代停稳几何。','',
'逐方案内部相关性：B在两批中的速度CV与最终平均最近球净距的Spearman约−0.17/−0.11；控制总平动能与最终剩球数的秩残差后约−0.13/−0.07。C约−0.33，调整后−0.22。它们提示方向，但解释力有限；观察相关不证明因果。完整数据见associations.json。','',
'相同总平动能下，平均速率与CV数学上相关：mean(v)^2×(1+CV^2)=mean(v²)。因此“均速提高”和“CV下降”不是两份独立证据。均匀速度也不规定方向；邻球同向同速仍然相伴移动，不能自动分开。','',
'## 保留与下一步','',
'- B：继续作为以停稳开散为主的参照，不声称唯一最优；A/B停稳几何比较支持B，但B母球落袋更高。',
'- A：保留为母球安全/早期能量分配的另一端取舍。本批母球落袋2/200，对B为9/200；仍需更大样本确认概率。',
'- C：保留为改善早期全阵传播的候选，尚未证明最终开散胜过B，不再冠以“整体最优”。',
'- D：没有显示超过C的整体优势，并出现更紧贴近邻的信号，暂不优先。',
'- 下一步若继续研究，应使用同批种子直接比较A/B/C，最终近邻/簇与母球安全共同验收；早期均匀度、慢球速度、原邻球相对分离速度只用于解释与筛选，不以单球速度或所有速度相等为终点。此次只完成已有数据回顾，不启动新模拟或改生产。','',
'证据：rows.json（2000条重算记录）、summary.json、paired.json、associations.json、source-audit.json、verification.json。物理模型没有变更；未作真实球桌验证。']
(OUT/'README.md').write_text('\n'.join(lines)+'\n')
# Independent identities and threshold monotonicity.
cal=json.loads((ROOT/'output/rack-center-mechanism-20261026/calibration.json').read_text())
err=0
for r in rows:
    expected=r['score']*cal['reference'][str(r['finalN'])]['expectedMeanM']
    err=max(err,abs(r['nearestGap']+2*.028574999421834946-expected))
    assert r['crowded_half']<=r['crowded_one']<=r['crowded_two']<=r['finalN']
    assert r['largest_half']<=r['largest_one']<=r['largest_two']<=r['finalN']
    assert 0<=r['closePairs100']<=30 and 0<=r['escape100']<=15
assert err<1e-12,err
(OUT/'metric-check.json').write_text(json.dumps(dict(rows=len(rows),scoreGeometryIdentityMaxErrorM=err,thresholdMonotonicity=True,energyCVIdentity=True),indent=2)+'\n')
print('Report written; independent score/geometry identity error',err)
