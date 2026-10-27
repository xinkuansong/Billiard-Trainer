from study import *
import gzip,hashlib,collections

allrows=json.load(open(OUT/'scalars.json'));rows=[s for s in allrows if s['cohort']=='holdout']
selection=json.load(open(OUT/'selection.json'))['selected'];summary=aggregate(rows)
assert len(rows)==600 and all(v['n']==200 for v in summary.values())
by={(s['id'],s['policy']):s for s in rows};ids=sorted({s['id'] for s in rows})
rng=random.Random(202610270902);draws=[[rng.randrange(200) for _ in range(200)] for _ in range(3000)]
keys=['coreEnergy5','coreEnergy20','coreBalanced5','coreActive5','coreMinEnergy5','coreTravel20','coreNeighborGap20',
      'slot4Energy5','slot7Energy5','slot8Energy5','coreFirstMS','coreOutsidePositiveChanges','coreOutsideNegativeChanges','nEff5','active5','gap20','tail','scratch','score']
paired={}
for p in selection[1:]:
    paired[p]={}
    for k in keys:
        delta=[by[i,p][k]-by[i,'parent'][k] for i in ids];bs=sorted(sum(delta[j] for j in draw)/200 for draw in draws)
        paired[p][k]=dict(mean=st.mean(delta),ci95=[bs[75],bs[2924]],increased=sum(d>0 for d in delta),decreased=sum(d<0 for d in delta))
write('paired.json',paired)
distribution={}
for p in selection:
    a=[s for s in rows if s['policy']==p]
    distribution[p]={k:dict(mean=st.mean(s[k] for s in a),median=st.median(s[k] for s in a),max=max(s[k] for s in a)) for k in ['coreEnergy5','coreEnergy20','coreActive5','tail']}
    distribution[p].update(coreAllThreeAbove1=sum(s['coreActive5']==3 for s in a),coreAnyAbove1=sum(s['coreActive5']>0 for s in a),tailOver5=sum(s['tail']>5 for s in a),scratch=sum(s['scratch'] for s in a))
write('distributions.json',distribution)
layouts={r['input']['rackID']:r for line in gzip.open(OUT/'layouts.jsonl.gz','rt') if (r:=json.loads(line))['input']['cohort']=='holdout'}
examples={};perSlot={p:[[] for _ in range(15)] for p in selection};minGap=1.;maxRadiusDrift=0.;edgeFlows={p:collections.defaultdict(lambda:[0,0.,0.]) for p in selection}
perCorePeaks={p:{i:[] for i in CORE} for p in selection}
coreRoutes={p:collections.defaultdict(lambda:[0,0.,0.,0.,0.]) for p in selection}
for line in gzip.open(OUT/'raw.jsonl.gz','rt'):
    r=json.loads(line);inp=r['input'];p=inp['policy'];rid=inp['rackID']
    if inp['cohort']!='holdout':continue
    src=layouts[rid];pp=[[b['x'],b['z']] for b in r['rack']];original=[[b['x'],b['z']] for b in src['rack']]
    for i in range(15):
        maxRadiusDrift=max(maxRadiusDrift,abs(math.dist(pp[i],r['slots'][i])-math.dist(original[i],r['slots'][i])))
        for j in range(i):minGap=min(minGap,math.dist(pp[i],pp[j])-2*R)
    states=dict(zip(r['names'],r['samples'][1]['states']));names=r['canonicalNames']
    for i,n in enumerate(names):perSlot[p][i].append(.5*M*sum(v*v for v in states[n]['v']))
    if rid==60000:examples[p]=r
    peaks={i:0. for i in CORE}
    for ev in r['eventTrace']:
        if ev['kind']!='ball' or ev['t']-r['t0']>.005:continue
        for side,other in [('A','B'),('B','A')]:
            n=ev['pre'+side]['name'];partner=ev['pre'+other]['name']
            if n not in names or names.index(n) not in CORE:continue
            e=lambda k:.5*M*sum(v*v for v in ev[k]['v'])
            slot=names.index(n);before=e('pre'+side);after=e('post'+side);peaks[slot]=max(peaks[slot],before,after)
            loss=e('pre'+side)-e('post'+side)
            if loss>0:
                idx=names.index(partner) if partner in names else -1
                a,b=ev['pre'+side],ev['pre'+other];dp=[b['p'][k]-a['p'][k] for k in [0,2]];vv=[a['v'][k] for k in [0,2]]
                fraction=(sum(x*y for x,y in zip(dp,vv))**2/(sum(x*x for x in dp)*sum(x*x for x in vv))) if sum(x*x for x in vv)>0 else 0
                route=coreRoutes[p][f'{slot}->{idx}'];route[0]+=1;route[1]+=before;route[2]+=after;route[3]+=loss*fraction;route[4]+=loss
                if idx not in CORE:
                    v=edgeFlows[p][f'{slot}->{idx}'];v[0]+=1;v[1]+=loss;v[2]+=max(e('post'+other)-e('pre'+other),0)
    for i in CORE:perCorePeaks[p][i].append(peaks[i])
write('slot-energies.json',{p:[st.mean(v) for v in a] for p,a in perSlot.items()})
write('examples.json',examples)
write('energy-loss-edges.json',{p:{k:dict(count=v[0],coreLossPerRackJ=v[1]/200,partnerGainPerRackJ=v[2]/200) for k,v in sorted(a.items(),key=lambda kv:kv[1][1],reverse=True)} for p,a in edgeFlows.items()})
write('core-route-diagnosis.json',dict(meanIndividualPeakJ={p:{i:st.mean(v) for i,v in a.items()} for p,a in perCorePeaks.items()},
    lossRoutes={p:{k:dict(count=v[0],meanBeforeSumPerRackJ=v[1]/200,meanAfterSumPerRackJ=v[2]/200,retainedFraction=v[2]/v[1],lossWeightedNormalEnergyFraction=v[3]/v[4]) for k,v in a.items()} for p,a in coreRoutes.items()}))
audit=dict(runs=len(allrows),initialMinGapM=minGap,maxOffsetLengthDriftM=maxRadiusDrift,
           **{k:sum(s[k] for s in allrows) for k in ['contacts','nonApproaching','gapOutsideBudget','energyGain']},
           maxContactOverlapM=max(s['maxOverlap'] for s in allrows),maxMomentumResidual=max(s['maxMomentumResidual'] for s in allrows))
assert len(allrows)==1808 and minGap>.0000195 and maxRadiusDrift<1e-7
assert audit['nonApproaching']==audit['gapOutsideBudget']==audit['energyGain']==0
write('audit.json',audit)
policies=json.load(open(OUT/'policies.json'));lines=['# 阵心三球能量保持：局部摆球研究','',
    '父方案为上一轮inner_first；两组候选只旋转指定局部球位的微扰方向。物理参数、六份研究引擎、每球偏移长度/0.09mm上限、0.20mm名义间距、顶球和杆速10均冻结。生产代码未由本任务修改。',
    '', '49策略×24筛选种子=1176次；父方案及筛选前二候选×200全新种子=600次；2次旧样本精确对拍、30次倒序/排列/镜像终局检查，合计1808次物理模拟。另224次layoutOnly仅读取摆球，不混入模拟数量。候选先冻结再读新种子。',
    '', '## 新种子复验','',
    '| 策略 | 阵心能量5ms J | 阵心能量20ms J | 阵心份额5ms | 阵心≥1m/s球数5ms | 全阵有效参与球数5ms | 核心邻球净距20ms | 自转尾段s | 母球落袋 |',
    '|---|---:|---:|---:|---:|---:|---:|---:|---:|']
for p in selection:
    a=summary[p];lines.append(f"|{p}|{a['coreEnergy5']:.6f}|{a['coreEnergy20']:.6f}|{a['interiorShare5']:.3%}|{a['coreActive5']:.3f}|{a['nEff5']:.3f}|{a['coreNeighborGap20']*1000:.3f}mm|{a['tail']:.3f}|{a['scratch']:.1%}|")
lines+=['','阵心指初始几何槽4/7/8，不是固定球号。能量为三球同刻平动能之和，份额为各局比值再平均。有效参与球数N_eff=1/Σp²；自转尾段为全桌停止平移后剩余旋转时间。核心邻球净距只统计初始30条邻接边中至少一端属于阵心的边。','',
    '本批父候选均值与上轮不同，原因是200副种子全部更新；应使用本批配对差值，不跨种子直接比较。','',
    '## 逐颗结论','',
    '| 初始槽位 | 父候选5ms能量J | 仅调整后两球J | 配合前侧传入球J |',
    '|---|---:|---:|---:|']
for i in CORE:lines.append('|'+str(i)+'|'+'|'.join(f'{summary[p]["slot"+str(i)+"Energy5"]:.6f}' for p in selection)+'|')
lines+=['','A=corerear_90：只把槽7/8微扰方向相对父方案分别旋转+90°/−90°，保留长度；B=late_60_0_90：在A上，槽1/2/3/5的微扰方向分别按所在侧旋转±60°。旋转的是微小偏移向量，不是将球绕球阵移动60°/90°。',
    'A提高整体有效参与数（4.43→5.07）和阵心总能量，但槽4变化的95%配对区间跨零，未证明前球改善。B的阵心总能量更高（0.090→0.189J），三颗均值均升高；各槽位区间为探索性、未经多重比较修正，不能冒称每颗都稳定提升。',
    '200副中A有180副阵心能量上升、B有161副上升；B至少一颗阵心≥1m/s由21/200升到61/200，但三颗同时≥1m/s为0/200（父候选1/200）。因此仍未解决全阵心充分运动的问题。',
    'B阵心5ms总能量中位数0.00519→0.05663J，20ms总能量均值0.08581→0.18038J，改善不是仅靠一个瞬时尖峰。三球总份额仍只有约1.26%，绝对量仍低。',
    '## 调整定义','']
for p in selection:lines.append(f'- {p}: {policies[p]["rotations"]} 度；相对父候选偏移旋转，Z负侧反向旋转，Z=0按正向旋转。')
lines+=['','组槽位：'+str(GROUPS)+'。其余球保留父候选坐标；精确布局与原始偏移长度见layouts.jsonl.gz和raw.jsonl.gz。','',
    '## 配对差值与分布','']
for p in selection[1:]:
    lines.append('### '+p)
    for k in ['coreEnergy5','coreEnergy20','coreActive5','coreNeighborGap20','nEff5','tail']:
        a=paired[p][k];lines.append(f'- {k}: Δ={a["mean"]:.6f}, 95%CI [{a["ci95"][0]:.6f}, {a["ci95"][1]:.6f}], 增加{a["increased"]}/200。')
    d=distribution[p];lines.append(f'- 阵心能量5ms中位数{d["coreEnergy5"]["median"]:.6f}J，至少一颗阵心≥1m/s {d["coreAnyAbove1"]}/200，三颗均≥1m/s {d["coreAllThreeAbove1"]}/200；自转尾段>5秒 {d["tailOver5"]}/200。')
lines+=['','## 机制与证据边界','',
    '父方案并非总是没把能量送到阵心。此前200副逐碰撞中三球各自峰值之和平均4.314J，逐碰撞增加/减少量合计4.394/4.294J，5ms同时剩余0.099J。峰值之和不是同刻峰值，增加量可能重复计算内部传递，不能当净注入能量。多数对外减少发生在阵心后两球撞底排11/12/13时，见parent-diagnosis.json。',
    '本轮前阵心槽4的单球能量峰值均值为：父版2.221J、A2.221J、B1.287J；5ms剩余却仅0.00271/0.00300/0.00492J。父版槽4向槽7/8减能碰撞中，按能量减少量加权的速度法向能量比例为99.94%/99.91%，碰后平动能合计/碰前合计只有0.20%/0.36%。这支持“近正碰继续传走”的解释，不能将低剩余能量一概解释为没有接到。',
    'A/B中后两颗向底排侧邻球的部分减能碰撞保留比例提高；详core-route-diagnosis.json的每条路径，不能把不同次数碰撞的能量变化总和当作无重复净流。B并未把更多能量峰值堆在前球，却提高了后续剩余量，研究目标应包含能量保持与空间分离。',
    '本轮主目标为5ms与20ms各三球sqrt(平动能)之和的平均，避免只优化一个瞬间或一颗球；先约束整体能量和有效参与数/运动球数/邻球间距，再按目标排序。开散和自转未参与选择。',
    '新种子统计是本分布内的证据，不是全局最优、任意球阵或真实球桌物理校准结论。若置信区间跨零，应将对应改善视为未证实。分组名称仅表达设计意图，不能替代逐碰撞证据。',
    '', '## 验证','',f'- {audit["runs"]}次全部原30秒/8000事件预算内停稳；全程{audit["contacts"]}次球球响应，非接近/超数值包络/增能>1µJ均0。',
    f'- 初始最小净距{minGap*1e6:.4f}µm，偏移长度舍入差最大{maxRadiusDrift*1e6:.4f}µm。',
    '- 两副旧父方案轨迹逐字段精确对拍；第一候选10副×倒序/打乱/镜像共30次终局误差≤1µm且时长一致，未把这30次宣称为全程逐位一致。',
    '- 全部监控生产Swift源码和研究引擎哈希未变，worker及shutdown退出0，受管工作目录已reclaimed，设备租约已释放。证据见source-review.json、engine-freeze.json、closure.json及local-test-runs/c22d3d78c29f4548a8ba4a895ee4fb9f。',
    '', '## 图','', '![三策略各槽位能量与局部方向](core-comparison.png)','',
    '能量图为200副每个几何槽的平均5ms平动能；偏移图展示固定首副新种子60000，箭头放大500倍，不是择优球阵。']
(OUT/'README.md').write_text('\n'.join(lines)+'\n')
print(json.dumps(dict(summary=summary,paired=paired,distribution=distribution,audit=audit),ensure_ascii=False,indent=2))
