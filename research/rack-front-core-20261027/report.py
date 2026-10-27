from study import *
import gzip,collections
allrows=json.load(open(OUT/'scalars.json'));rows=[s for s in allrows if s['cohort']=='holdout'];selection=json.load(open(OUT/'holdout-selection.json'))['selected'];summary=aggregate(rows)
assert len(rows)==600 and all(a['n']==200 for a in summary.values())
by={(s['id'],s['policy']):s for s in rows};ids=sorted({s['id'] for s in rows})
rng=random.Random(202610271101);draws=[[rng.randrange(200) for _ in range(200)] for _ in range(4000)]
keys=['frontObjective','frontSpeed5','frontSpeed20','frontTravel20','slot4Energy5','coreEnergy5','slot7Energy5','slot8Energy5','nEff5','active5','gap20','tail','scratch','score']
paired={}
for p in selection[1:]:
    paired[p]={}
    for k in keys:
        delta=[by[i,p][k]-by[i,'parentB'][k] for i in ids];bs=sorted(sum(delta[j] for j in draw)/200 for draw in draws)
        paired[p][k]=dict(mean=st.mean(delta),ci95=[bs[100],bs[3899]],increased=sum(d>0 for d in delta),decreased=sum(d<0 for d in delta))
write('paired.json',paired)
write('holdout-gates.json',{p:dict(eligible=eligible(summary,p),values={k:dict(actual=summary[p][k],required=f*summary['parentB'][k],passGate=summary[p][k]>=f*summary['parentB'][k]) for k,f in [('energy5',.95),('nEff5',.9),('active5',.9),('gap20',.9),('coreEnergy5',.9)]}) for p in selection[1:]})
distribution={}
for p in selection:
    a=[s for s in rows if s['policy']==p]
    distribution[p]={k:dict(mean=st.mean(s[k] for s in a),median=st.median(s[k] for s in a),min=min(s[k] for s in a),max=max(s[k] for s in a)) for k in ['frontObjective','frontSpeed5','frontSpeed20','frontTravel20','frontPeakJ','tail']}
    distribution[p].update(frontAbove1=sum(s['frontAbove1'] for s in a),frontAbove05=sum(s['frontAbove05'] for s in a),tailOver5=sum(s['tail']>5 for s in a),scratch=sum(s['scratch'] for s in a))
write('distributions.json',distribution)
layouts={r['input']['rackID']:r for line in gzip.open(OUT/'layouts.jsonl.gz','rt') if (r:=json.loads(line))['input']['cohort']=='holdout'}
examples={};perSlot={p:[[] for _ in range(15)] for p in selection};minGap=1.;maxDrift=0.;maxInitialAngle=0.;routes={p:collections.defaultdict(lambda:[0,0.,0.,0.]) for p in selection};cases=[];geometry=[];mechanisms=[]
for line in gzip.open(OUT/'raw.jsonl.gz','rt'):
    r=json.loads(line);inp=r['input'];p=inp['policy'];rid=inp['rackID']
    if inp['cohort']!='holdout':continue
    src=layouts[rid];pp=[[b['x'],b['z']] for b in r['rack']];orig=[[b['x'],b['z']] for b in src['rack']]
    for i in range(15):
        maxDrift=max(maxDrift,abs(math.dist(pp[i],r['slots'][i])-math.dist(orig[i],r['slots'][i])))
        for j in range(i):minGap=min(minGap,math.dist(pp[i],pp[j])-2*R)
        for j in range(i):
            aa=[r['slots'][i][k]-r['slots'][j][k] for k in [0,1]]
            if math.hypot(*aa)>2*R+.001:continue
            bb=[pp[i][k]-pp[j][k] for k in [0,1]]
            angle=abs(math.atan2(aa[0]*bb[1]-aa[1]*bb[0],aa[0]*bb[0]+aa[1]*bb[1]))
            maxInitialAngle=max(maxInitialAngle,math.degrees(angle))
    geometry.append(dict(id=rid,policy=p,entryGapUm=st.mean(math.dist(pp[4],pp[j])-2*R for j in [1,2])*1e6,exitGapUm=st.mean(math.dist(pp[4],pp[j])-2*R for j in [7,8])*1e6))
    states=dict(zip(r['names'],r['samples'][1]['states']));names=r['canonicalNames'];front=names[4]
    for i,n in enumerate(names):perSlot[p][i].append(math.sqrt(sum(v*v for v in states[n]['v'])))
    events=[]
    for ev in r['eventTrace']:
        if ev['kind']!='ball' or ev['t']-r['t0']>.005:continue
        for side,other in [('A','B'),('B','A')]:
            a,b=ev['pre'+side],ev['pre'+other]
            if a['name']!=front:continue
            ee=lambda k:.5*M*sum(v*v for v in ev[k]['v'])
            before,after=ee('pre'+side),ee('post'+side);idx=names.index(b['name']) if b['name'] in names else -1
            dp=[b['p'][k]-a['p'][k] for k in [0,2]];vv=[a['v'][k] for k in [0,2]]
            fraction=(sum(x*y for x,y in zip(dp,vv))**2/(sum(x*x for x in dp)*sum(x*x for x in vv))) if sum(x*x for x in vv)>0 else 0
            events.append(dict(tMS=(ev['t']-r['t0'])*1000,partnerSlot=idx,preJ=before,postJ=after,partnerPreJ=ee('pre'+other),partnerPostJ=ee('post'+other),normalEnergyFraction=fraction))
            if after<before:
                loss=before-after;v=routes[p][str(idx)];v[0]+=1;v[1]+=before;v[2]+=after;v[3]+=loss*fraction
    cases.append(dict(id=rid,policy=p,frontSpeed5=by[rid,p]['frontSpeed5'],events=events))
    ss=by[rid,p];lastGain=bool(events and events[-1]['postJ']>events[-1]['preJ']);peak=ss['frontPeakJ']
    end=r['board'].get(front);finalDistance=math.hypot(end[0]*L-L/2-pp[4][0],end[1]*L-L/4-pp[4][1]) if end is not None else None
    mechanisms.append(dict(id=rid,policy=p,lastContactGain=lastGain,earlyPeakAbove1mps=peak>=.5*M,frontSpeed5=ss['frontSpeed5'],peakJ=peak,
        residualJ=ss['slot4Energy5'],residualRatio=ss['slot4Energy5']/peak if peak else 0,frontPocketed=end is None,finalDisplacementM=finalDistance))
    if rid==80000:examples[p]=r
write('slot-speeds.json',{p:[st.mean(v) for v in a] for p,a in perSlot.items()});write('examples.json',examples);write('front-events.json',cases);write('initial-gap-metrics.json',geometry)
write('front-loss-routes.json',{p:{k:dict(count=v[0],preSumPerRackJ=v[1]/200,postSumPerRackJ=v[2]/200,retainedFraction=v[2]/v[1],lossWeightedNormalFraction=v[3]/(v[1]-v[2])) for k,v in a.items()} for p,a in routes.items()})
write('mechanism-rows.json',mechanisms)
mechanismSummary={}
for p in selection:
    a=[s for s in mechanisms if s['policy']==p];big=[s for s in a if s['earlyPeakAbove1mps']];small=[s for s in a if not s['earlyPeakAbove1mps']]
    mechanismSummary[p]=dict(lastContactGain=sum(s['lastContactGain'] for s in a),earlyPeakAbove1mps=len(big),
        speed5IfLargeEarlyPeak=st.mean(s['frontSpeed5'] for s in big) if big else None,
        speed5IfSmallEarlyPeak=st.mean(s['frontSpeed5'] for s in small) if small else None,
        meanPeakJ=st.mean(s['peakJ'] for s in a),frontPocketed=sum(s['frontPocketed'] for s in a),
        onTableFinalMeanDisplacementM=st.mean(s['finalDisplacementM'] for s in a if s['finalDisplacementM'] is not None))
write('mechanism-summary.json',mechanismSummary)
audit=dict(runs=len(allrows),initialMinimumGapM=minGap,maxOffsetLengthDriftM=maxDrift,maxInitialNeighborDirectionDeviationDeg=maxInitialAngle,
    **{k:sum(s[k] for s in allrows) for k in ['contacts','nonApproaching','gapOutsideBudget','energyGain']},maxContactOverlapM=max(s['maxOverlap'] for s in allrows),maxMomentumResidual=max(s['maxMomentumResidual'] for s in allrows))
assert len(allrows)==2678 and minGap>.0000195 and maxDrift<1e-7
assert audit['nonApproaching']==audit['gapOutsideBudget']==audit['energyGain']==0
write('audit.json',audit)
policies=json.load(open(OUT/'policies.json'))
lines=['# 前阵心球持续速度：方案B局部摆球研究','',
    '父方案为late_60_0_90（上一轮B）。仅改变槽1/2/4/7/8的微小偏移方向，其余球逐位保留B；原偏移长度、0.09mm范围、0.20mm名义间距、顶球、杆速10和配对实际初速度保持。六份研究引擎与物理参数冻结，未改生产代码。',
    '', '99×16初筛1584次；前八＋父版×48独立确认432次；确认前二＋父版×200全新复验600次；2次旧轨迹对拍、两候选各30次顺序/镜像检查，总计2678次。另264次layoutOnly读取不计物理模拟。200副历史B球阵构造逐位对拍，见parent-constructor-replay.json。',
    '', '主目标是5/20ms速度较小值的平均，避免瞬间峰值。按预定整体能量/全阵参与/阵心能量等门槛筛选，散度与自转不参与排序。每次选择先冻结再读取下一阶段种子。','',
    '## 200副新球阵对照','',
    '| 策略 | 前球5ms速度m/s | 前球20ms速度m/s | 前球20ms位移mm | 两时刻均≥0.5m/s | 两时刻均≥1m/s | 全阵有效参与球数5ms | 自转尾段s | 母球落袋 |',
    '|---|---:|---:|---:|---:|---:|---:|---:|---:|']
for p in selection:
    a=summary[p];d=distribution[p];lines.append(f"|{p}|{a['frontSpeed5']:.4f}|{a['frontSpeed20']:.4f}|{1000*a['frontTravel20']:.3f}|{d['frontAbove05']}/200|{d['frontAbove1']}/200|{a['nEff5']:.3f}|{a['tail']:.3f}|{a['scratch']:.1%}|")
lines+=['','速度为速度大小的算术平均；时刻从首次球球接触计。前球指几何槽4，不固定球号。位移为相对初始位置的直线距离，非路径长度。父版使用本批相同种子，不与上轮均值直接相减。','', '## 具体方向规则','']
for p in selection:lines.append(f'- {p}: {policies[p]}。')
lines+=['','rotate按[1,2,4,7,8]列出相对B的角度，Z负侧反号；旋转的是微扰方向，不是整副球阵。gate规则的几何向量和相位见study.py，随机偏移长度保持。','', '## 配对差值（候选减B，95% bootstrap区间）','']
for p in selection[1:]:
    lines.append('### '+p)
    for k in ['frontObjective','frontSpeed5','frontSpeed20','frontTravel20','coreEnergy5','nEff5','tail']:
        a=paired[p][k];lines.append(f"- {k}: {a['mean']:.6f} [{a['ci95'][0]:.6f}, {a['ci95'][1]:.6f}]；增加{a['increased']}/200，减少{a['decreased']}/200。")
    d=distribution[p];lines.append(f"- 5ms速度中位数{d['frontSpeed5']['median']:.4f}m/s，最大{d['frontSpeed5']['max']:.4f}m/s。")
lines+=['','## 验证和边界','',
    f"- {audit['runs']}次原预算内全部停稳；{audit['contacts']}次球球响应，非接近响应/超误差包络/增能>1µJ均0。",
    f"- 最小初始净距{minGap*1e6:.4f}µm；偏移长度Float舍入差最大{maxDrift*1e6:.4f}µm。",
    '- 两个历史样本逐字段回放一致；两候选各10副×倒序/打乱/镜像终局≤1µm、时长一致。没有将终局验证说成所有中间帧完全一致。',
    '- 方向搜索不是全局最优证明；置信区间跨零的指标不能声称稳定改善。是否达到“动起来”应同时看持续速度、发生比例和位移，而非仅峰值或一张图。',
    '- 原始数据、三阶段选择、进程退出与源码哈希见同目录JSON。本轮无生产接入、真机或真实球桌校准。',
    '', '## 图','', '![五槽微扰与前球速度](front-comparison.png)','',
    '上图为200副各几何槽的平均5ms速度；下图为固定首副新种子80000的偏移，箭头放大500倍。']
lines += ['', '## 结论与逐次碰撞解释', '',
    '本轮找到小幅均值改善，未解决前阵心球普遍接到能量后迅速传走的问题。优先保留exit_-30：只转动后侧槽7/8的微扰方向，相对B回转30°（Z负侧反号），前球自身和来球侧不动。5ms均速提高23.4%，配对均值差95%区间为+0.0276至+0.0673m/s；但中位数仅0.1563→0.1582m/s，112/200提高、88/200降低，配对差中位数仅+0.000091m/s。收益集中于部分球阵，不能称为普遍改善。',
    '5/20ms均≥0.5m/s由10/200增至21/200，均≥1m/s仍为1/200。自转尾段0.787→0.839s，配对差区间跨零，没有证据认为自转改善。散度仅观察，不用于选择。',
    '逐次证据一：首个预定留出样本80000，父版前球在0.02252ms接到3.26643J，在0.06782ms撞后侧槽7后只剩0.0023345J。候选仍接到同样能量，槽7接触提前至0.06239ms，碰后仅0.0023355J；5ms速度0.08550→0.08538m/s。仅把相同的近正碰提前或延后，不足以保住能量。',
    '逐次证据二：样本80179是事后选出的最大收益例，不代表典型球阵。两版前球先接槽2，再接槽1，约0.2426ms均达到0.04725J。父版随后0.6724ms撞槽8降至0.00494J、1.1200ms撞槽7降至0.000693J；候选5ms内没有这两次后续接触，5ms速度0.0827→0.7362m/s。该例支持：改变后球的位置关系，使前球接能后避免后续出球接触，可以保留运动；不是增加瞬时注入。仅凭本例不推断全部收益来自同一机制。',
    '全样本早期峰值能量均值1.16754→1.16668J，几乎未变。按是否出现过≥1m/s早期峰值事后分组，高峰值组5ms均速约0.162→0.161m/s，低峰值组0.225→0.305m/s；组成员可能变化，此分组只提示收益集中位置，不构成配对因果证明。',
    '在保留0.09mm微扰范围与原幅度的条件下，本批初始相邻连心方向相对理想格点偏差最大仅0.1734°。微扰容易改变事件先后，却未必改变强脉冲后的近正碰路径。这是当前方向搜索收益有限的解释，不是不存在其他摆法的证明。若下一轮扩大局部间距或改变球阵骨架，应作为单独变量和新实验边界，不能混进本轮结论。',
    '模拟仅证明当前逐对刚体研究模型下的行为，未验证真实球桌或持续多接触模型。研究worker正常退出，受管运行及模拟器租约已收尾；详见closure.json和verification.json。']
(OUT/'README.md').write_text('\n'.join(lines)+'\n')
print(json.dumps(dict(summary=summary,paired=paired,distributions=distribution,audit=audit),ensure_ascii=False,indent=2))
