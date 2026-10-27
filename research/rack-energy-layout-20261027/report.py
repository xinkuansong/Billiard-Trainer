from study import *
import gzip,collections

scalars=json.load(open(OUT/'scalars.json'))
selection=json.load(open(OUT/'selection.json'))['selected']
rows=[s for s in scalars if s['cohort']=='holdout']
summary=aggregate(rows)
by={(s['id'],s['policy']):s for s in rows}
ids=sorted({s['id'] for s in rows})
assert len(ids)==200 and len(rows)==800
rng=random.Random(202610270703)
draws=[[rng.randrange(200) for _ in range(200)] for _ in range(3000)]
keys=['nEff5','active5','cornerShare5','interiorShare5','sep20','gap20','rate20','energy5','score','tail','peakSpin','scratch']
paired={}
for p in selection[1:]:
    paired[p]={}
    for key in keys:
        delta=[by[i,p][key]-by[i,'baseline'][key] for i in ids]
        bs=sorted(sum(delta[j] for j in draw)/200 for draw in draws)
        paired[p][key]=dict(mean=st.mean(delta),ci95=[bs[75],bs[2924]],betterCount=sum(d>0 for d in delta))
write('paired.json',paired)
extras=[];examples={};minimumGap=1.;maxRadiusDrift=0.;samplePolicy=selection[2]
# The displayed rack is the first predeclared holdout, not the best result.
for line in gzip.open(OUT/'raw.jsonl.gz','rt'):
    row=json.loads(line);inp=row['input'];cohort=inp['cohort'];p=inp['policy'];rid=inp['rackID']
    if cohort!='holdout':continue
    slots=row['slots'];names=row['canonicalNames'];pp=[[b['x'],b['z']] for b in row['rack']]
    for i in range(15):
        for j in range(i):minimumGap=min(minimumGap,math.dist(pp[i],pp[j])-2*R)
    if p=='baseline':basePositions=pp
    else:
        for i in range(15):maxRadiusDrift=max(maxRadiusDrift,abs(math.dist(pp[i],slots[i])-math.dist(basePositions[i],slots[i])))
    neighbors=[(i,j) for i in range(15) for j in range(i) if math.dist(slots[i],slots[j])<2*R+.001]
    x=dict(id=rid,policy=p)
    incoming={'edge':[],'inside':[]}
    for i,j in neighbors:
        ri,ci=SLOTS[i];rj,cj=SLOTS[j]
        if ri==rj:continue
        target=i if ri>rj else j
        rr,cc=SLOTS[target]
        incoming['edge' if cc in (0,rr) else 'inside'].append(math.dist(pp[i],pp[j])-2*R)
    x.update({k+'IncomingGapUm':st.mean(v)*1e6 for k,v in incoming.items()})
    for sample in row['samples']:
        ms=round(sample['delay']*1000);states=dict(zip(row['names'],sample['states']));a=[states[n] for n in names];rates=[];gaps=[]
        for i,j in neighbors:
            dp=[a[i]['p'][k]-a[j]['p'][k] for k in [0,2]];dv=[a[i]['v'][k]-a[j]['v'][k] for k in [0,2]];dist=math.hypot(*dp)
            rates.append(sum(q*v for q,v in zip(dp,dv))/dist);gaps.append(dist-2*R)
        x[f'sepAbove01_{ms}']=sum(v>.1 for v in rates)/30
        x[f'gapAbove1mm_{ms}']=sum(g>.001 for g in gaps)/30
    first={};edges=[]
    for e in row['eventTrace']:
        if e['kind']!='ball':continue
        a,b=e['preA']['name'],e['preB']['name'];t=e['t']-row['t0']
        for n in [a,b]:
            if n in names:first.setdefault(n,t)
        if t<.005:edges.append([a,b,t])
    x['firstInteriorMS']=st.mean(first.get(names[i],30)*1000 for i in [4,7,8])
    x['firstCornerMS']=st.mean(first.get(names[i],30)*1000 for i in [10,14])
    x['earlyContacts']=len(edges)
    extras.append(x)
    if rid==40000 and p in ['baseline',samplePolicy]:examples[p]=row
write('additional-metrics.json',extras)
extraSummary={p:{k:st.mean(s[k] for s in extras if s['policy']==p) for k in extras[0] if k not in ['id','policy']} for p in selection}
write('additional-summary.json',extraSummary)
audit=dict(runs=len(scalars),holdoutRuns=len(rows),minimumInitialGapM=minimumGap,maxPairedOffsetRadiusDriftM=maxRadiusDrift,
           **{k:sum(s[k] for s in scalars) for k in ['contacts','nonApproaching','gapOutsideBudget','energyGain']},
           maxMomentumResidual=max(s['maxMomentumResidual'] for s in scalars),maxContactOverlapM=max(s['maxOverlap'] for s in scalars))
assert audit['nonApproaching']==audit['gapOutsideBudget']==audit['energyGain']==0
assert minimumGap>0 and maxRadiusDrift<1e-7
write('audit.json',audit)
write('examples.json',examples)
text=['# 修复引擎下的摆球能量分配研究','',
      '物理引擎冻结为上一轮研究修复版，全部物理参数、名义球距0.20mm、偏移范围0.09mm、每颗球偏移长度与杆头速度10保持。仅调整偏移方向；同种子顶球、母球实际速度、球号完全配对。生产代码未由本任务修改。','',
      f'32方向策略×24筛选种子=768局；按预定能量/邻球目标选出{selection[2:]}，加旧摆法及独立随机，共4组×200全新种子=800局。另2次旧轨迹对拍、30次顺序/镜像检查；总计{len(scalars)}局。开散分未参与选优。','',
      '| 策略 | 能量有效参与球数5ms | ≥1m/s球数5ms | 两角能量占比5ms | 内部三球能量占比5ms | 邻球远离比例20ms | 邻球平均净距20ms | 开散均分 | 平均自转尾段s | 母球落袋 |',
      '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|']
for p in selection:
    a=summary[p]
    text.append(f"|{p}|{a['nEff5']:.3f}|{a['active5']:.3f}|{a['cornerShare5']:.2%}|{a['interiorShare5']:.2%}|{a['sep20']:.2%}|{1000*a['gap20']:.2f}mm|{a['score']:.4f}|{a['tail']:.3f}|{a['scratch']:.1%}|")
text+=['','N_eff=1/Σp²，p为各目标球平动能份额；它是集中度的等效球数，不是实际运动球数。内部三球为排内槽4/7/8（0基槽号），不包括底排内部三球。远离比例使用30对初始邻居，瞬间距离导数>1e−5m/s。自转尾段为全桌停止平移后的剩余旋转时间。','',
       '## 配对差值（候选减旧摆法，95% bootstrap区间）','']
for p in selection[1:]:
    text.append(f'### {p}')
    for k in ['nEff5','active5','cornerShare5','gap20','tail']:
        v=paired[p][k];text.append(f"- {k}: {v['mean']:.6f} [{v['ci95'][0]:.6f}, {v['ci95'][1]:.6f}]")
text+=['','## 具体规律与限制','',
       '第一候选inner_first：顶球不动，两条斜边上的球偏移以远离母球的−X方向为主，每排内部球以朝向顶球的+X方向为主，叠加朝中线的方向分量与原种子驱动的±30°相位。每颗球原偏移长度保持，不是把球整体拉开。准确方向生成式见study.py/positions。',
       '200副中，跨排内侧通道平均净距由171.94µm降到148.75µm，外侧通道由183.54µm升到200.05µm。阵心三球首次参与碰撞平均时间由0.501ms提前到0.190ms；两角首次参与由0.081ms延后到0.099ms。观察支持“接触先后改变”的机制，但不代表每副、每一对都满足同一顺序。',
       '5ms目标球总平动能15.056→15.094J，基本相同；最大球速均值11.60→8.80m/s。收益主要体现为重新分配，而非调低整体能量。',
       '原先相邻的球几乎全部已经在远离（99.80%→99.58%，略降），不能声称远离比例提升。实际改善是远离速度1.411→2.104m/s、20ms平均净距26.71→38.81mm；净距超过1mm的邻球比例81.05%→88.78%，远离速度>0.1m/s比例72.18%→77.52%。后两项为事后解释指标。',
       '候选186/200副提高能量有效参与球数，176/200副提高≥1m/s球数，188/200副增大20ms邻球平均净距。阵心三球5ms能量占比仅0.66%（原0.05%），仍是明显短板；不能宣称所有球已均匀分能。',
       '自转尾段>5秒由124/200降到43/200，最长仍9.71秒。模板09尾段更短（平均1.57秒）但母球落袋10.5%，因此不是无代价替代。',
       '固定首副示例40000恰为反例：inner_first开散分0.517低于旧摆法0.779，尾段7.88秒长于4.40秒。保留并展示它，不用挑最好的一副冒充稳定保证。',
       '', '## 验证及边界','',f'- 全程{audit["contacts"]}次球球响应：非接近响应0，超数值包络0，能量增加>1µJ为0。',
       f'- 初始最小球面净距{minimumGap*1000:.6f}mm；配对偏移长度最大Float舍入差{maxRadiusDrift*1e6:.6f}µm。',
       '- 原两副修复轨迹的球阵/终局/逐次碰撞/早期采样/自转/实际初速度完全对拍。候选10副×倒序/打乱/镜像共30次，终局≤1µm、时长一致；这30次仅验终局与时长，不冒充全程逐位验证，见invariance.json。',
       '- 全1600局原预算内停稳，native worker退出0、模拟器shutdown退出0；受管工作目录已reclaimed，设备租约释放，原始日志保留。全部监控生产Swift源哈希无变，冻结六份研究引擎哈希无变。',
       '- 按预定目标选出的两份策略为探索性候选；200新种子支持本分布内复现，不能称全局最优或真实球桌已校准。',
       '- 邻球“正在远离”可能很快饱和，附加报告>0.1m/s远离比例和>1mm净距比例；这些为事后解释指标，未参与候选选优。',
       '- 峰值自转、长尾、落袋及耗时只是观察。CPU含日志与逐帧检查，仅为模拟器研究工作量，非真机性能。',
       '- 原始数据raw.jsonl.gz、标量scalars.json、预定设计design.json、全部策略policies.json、筛选screen-summary.json、候选冻结selection.json、复验summary.json、配对paired.json、源绑定及closure.json均保留。',
       '', '## 固定首副新种子示例（非择优展示）','', '![实际初始偏移、早期速度与终局](comparison.png)','',
       '微扰箭头放大500倍；5ms速度箭头表示按该瞬间速度前进5ms的位移，非额外模拟轨迹。终局直接来自同次模拟；其他图中槽号标识几何位置，不是球号。']
(OUT/'README.md').write_text('\n'.join(text)+'\n')
print(json.dumps(dict(summary=summary,extra=extraSummary,audit=audit),ensure_ascii=False,indent=2))
