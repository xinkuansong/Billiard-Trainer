from pathlib import Path
import json, math, csv, html
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle,Rectangle
from matplotlib import font_manager
OUT=Path(__file__).resolve().parent
def read(n):return json.loads((OUT/n).read_text())
def save(n,d):(OUT/n).write_text(json.dumps(d,ensure_ascii=False,indent=2))
def fmt(v,n=2):return '—' if v is None else f'{v:.{n}f}'
def generate():
    from analyze import shape,angle_values
    summary=read('summary.json');groups=summary['groups'];selected=[g for g in groups if g['id'] in summary['selected']]
    scan=read('evaluated-scan.json')['rows'];byid={r['id']:r for r in scan};validation=read('validate-results.json')['rows'];protocol=read('protocol.json');sample=read('sample.json')
    points=np.array(summary['points']);radius=summary['radius'];grid=read('grid.json');aims=np.array([x['aims'][1] for x in grid])
    checks=[]
    for g in groups:
        rs=[r for r in scan if (r['route'],r['nominalV'],r['tier'])==(g['route'],g['v'],g['tier']) and r['offset'][1]==0]
        good=[r for r in rs if r.get('accepted')]
        nominal=byid[g['nominalID']]
        g['solverNoWitness']=sum(r.get('inputFailure')=='solver_no_pot_witness' for r in rs)
        g['incomplete']=sum('settled' in r and not r['settled'] for r in rs)
        g['jawSamples']=sum(r.get('jaw',0)>0 for r in rs)
        g['firstAccessFailures']=sum(r.get('firstAccess') is False for r in rs)
        g['comfortableStops']=sum(r.get('clearance',-1)>.1 for r in good)
        g['maxGeometryCoverage']=max(g['coverage'])
        g['nominalMiscueMargin']=nominal.get('miscueMargin')
        g['nominalSecondCandidates']=len(nominal.get('geometricCandidates',[]))
        g['nominalStop']=nominal.get('stop')
        for name in ['postContactLength','duration','firstElevationDegrees','miscueMargin','minPocketCenterDistance']:
            vals=[r[name] for r in good if name in r]
            g[name+'Range']=[min(vals),max(vals)] if vals else None
    for g in selected:
        vs=[r for r in validation if r['group']==g['id']]
        ids=summary['pointsByGroup'][g['id']];physical=[];comfort=[];details=[]
        assert len(vs)==len(ids)*27
        for i in ids:
            rs=[r for r in vs if r['pointIndex']==i];assert len(rs)==27
            passed=[r for r in rs if r.get('secondPass')]
            if len(passed)==27:physical.append(i)
            if len(passed)==27 and all(r.get('clearance',-1)>.1 for r in rs):comfort.append(i)
            angles=[];elevations=[];d1=[];d2=[]
            for r in passed:
                angle=float(angle_values(np.array(r['stop']),points[i:i+1],aims[i:i+1],radius)[0]);assert abs(angle)<=20.0001
                assert abs(abs(angle)-abs(r['secondGeometricAngle']))<.001
                angles.append(angle);elevations.append(r['secondWitness']['elevationDegrees']);d1.append(r['cueToSecond']);d2.append(r['secondToAim'])
            details.append({'pointIndex':i,'point':points[i].tolist(),'pass':len(passed),'samples':27,'attempts':sum(r.get('secondAttempts',0) for r in rs),'angleRange':[min(angles),max(angles)] if angles else None,'maxElevation':max(elevations) if elevations else None,'cueDistanceRange':[min(d1),max(d1)] if d1 else None,'objectDistance':d2[0] if d2 else None})
        g['physicalCommon']=physical;g['physicalComfortCommon']=comfort;g['physicalShape']=shape(physical,points);g['physicalComfortShape']=shape(comfort,points);g['pointResults']=details
        choose=comfort or physical
        best_id=shape(choose,points)['bestIndex'] if choose else max(details,key=lambda d:d['pass'])['pointIndex']
        g['representative']=next(d for d in details if d['pointIndex']==best_id)
        checks.append({'group':g['id'],'validationRows':len(vs),'verifiedCommonPoints':len(physical),'comfortablePoints':len(comfort)})
    save('final-results.json',summary)
    save('audit.json',{'scanRows':len(scan),'mainRows':sum(r['offset'][1]==0 for r in scan),'auxiliaryDirectionRows':sum(r['offset'][1]!=0 for r in scan),'validationRows':len(validation),'secondAttempts':sum(r.get('secondAttempts',0) for r in validation),'checks':checks,'angleRecalculation':True,'sourcePointCount':len(points)})
    # Export all original speed bins; no replacement of the 13-bin input grid.
    fields=['id','route','v','tier','samples','inputValid','accepted','pot','scratch','incomplete','solverNoWitness','jawSamples','firstAccessFailures','comfortableStops','sameOriginalRoute','nominalRails','nominalStop','nominalClearance','minimumClearance','nominalLength','scatterMax','nominalMiscueMargin','maxGeometryCoverage','nominalSecondCandidates','postContactLengthRange','durationRange','firstElevationDegreesRange','miscueMarginRange','minPocketCenterDistanceRange']
    with (OUT/'all-13-speed-results.csv').open('w') as f:
        w=csv.DictWriter(f,fieldnames=fields+['commonCount','comfortCount','coverage90Count']);w.writeheader()
        for g in groups:w.writerow({**{k:g.get(k) for k in fields},'commonCount':len(g['common']),'comfortCount':len(g['comfortableCommon']),'coverage90Count':len(g['coverage90'])})
    fonts=font_manager.findSystemFonts()
    candidates=[x for x in fonts if 'PingFang' in x or 'STHeiti' in x or 'Heiti' in x]
    if candidates:
        font_manager.fontManager.addfont(candidates[0]);plt.rcParams['font.family']=font_manager.FontProperties(fname=candidates[0]).get_name()
    plt.rcParams.update({'axes.unicode_minus':False,'font.size':10,'figure.facecolor':'#f5f6f3','savefig.facecolor':'#f5f6f3'})
    cue=np.array([sample['cue']['x'],sample['cue']['z']]);target=np.array([sample['target']['x'],sample['target']['z']])
    pockets=np.array([[p['center']['x'],p['center']['z']] for p in sample['geometry']['pockets']])
    def table(ax):
        ax.add_patch(Rectangle((-1.27,-.635),2.54,1.27,facecolor='#173f3b',edgecolor='#7b6952',lw=7,zorder=0))
        for i,p in enumerate(pockets):
            ax.add_patch(Circle(p,.043,color='#111e20',zorder=2));ax.text(p[0],p[1]-.05,str(i),fontsize=8,color='#46504b',ha='center',clip_on=True)
        for p,color,label in [(cue,'#ffffff','母'),(target,'#eeae61','1')]:
            ax.add_patch(Circle(p,radius,facecolor=color,edgecolor='#172522',zorder=8));ax.text(*p,label,ha='center',va='center',fontsize=7,zorder=9,clip_on=True)
        ax.set(xlim=(-1.39,1.39),ylim=(.77,-.77),aspect='equal');ax.set_xlabel('X（m，向右）');ax.set_ylabel('Z（m，向下）');ax.grid(False)
    def panel(ax,g,zoom=False):
        table(ax)
        rs=[r for r in scan if r['route']==g['route'] and r['nominalV']==g['v'] and r['tier']==g['tier'] and r['offset'][1]==0]
        for r in rs:
            if r.get('accepted'):
                p=np.array(r['cuePath']);ax.plot(p[:,0],p[:,1],color='#e8eeea',alpha=.12,lw=.8,zorder=3)
        nominal=byid[g['nominalID']]
        if 'cuePath' in nominal:
            p=np.array(nominal['cuePath']);ax.plot(p[:,0],p[:,1],color='#ffffff',lw=1.3,zorder=4)
            p=np.array(nominal['objectPath']);ax.plot(p[:,0],p[:,1],color='#f7b66b',lw=1.1,zorder=4)
        # Points remain discrete: no convex hull or unsupported filled feasible polygon.
        for ids,color,label,marker,size in [(g['conditionalCommon'],'#eebc62','首杆成功条件下交集','.',22),(g['coverage90'],'#75a7f2','≥90%几何覆盖','s',18),(g['common'],'#96dfd3','27/27几何候选','s',22),(g['physicalCommon'],'#64e08b','27/27两杆验证点','o',12)]:
            if ids:ax.scatter(points[ids,0],points[ids,1],c=color,s=size,marker=marker,label=label,zorder=5)
        stops=np.array([r['stop'] for r in rs if r.get('accepted')])
        if len(stops):ax.scatter(stops[:,0],stops[:,1],s=12,c='#fa82ad',marker='x',label='母球停点',zorder=6)
        rep=g['representative'];b=np.array(rep['point']);ax.scatter(*b,s=70,facecolors='none',edgecolors='#ffe26b',linewidths=1.5,zorder=7,label='复验第二球')
        name='原四库' if g['route']=='four' else '原两库'
        actual='→'.join(map(str,g['nominalRails']))
        ax.set_title(f"{name}｜{g['v']:.4f} m/s｜扰动 {g['tier']}\n首杆 {g['accepted']}/27；最佳球位几何覆盖 {g['maxGeometryCoverage']}/27；共同点 {len(g['physicalCommon'])}",fontsize=11,pad=12)
        if zoom:
            use=set(g['conditionalCommon']+g['common']+[rep['pointIndex']]);a=points[list(use)]
            xmin,xmax=a[:,0].min()-.08,a[:,0].max()+.08;zmin,zmax=a[:,1].min()-.08,a[:,1].max()+.08
            span=max(xmax-xmin,zmax-zmin,.20);cx=(xmin+xmax)/2;cz=(zmin+zmax)/2
            ax.set(xlim=(cx-span*.6,cx+span*.6),ylim=(cz+span*.6,cz-span*.6))
        if not g['common']:
            ax.text(.02,.04,'27/27 严格共同区：空',transform=ax.transAxes,color='#ffffff',fontsize=10,bbox={'facecolor':'#173f3b','alpha':.85,'edgecolor':'none'},zorder=20)
        return actual
    selected_order=sorted(selected,key=lambda g:(g['tier'],g['route'],g['v']))
    # One pair per research tier uses the best preserved original topology, with 4.5 baseline separately.
    display=[]
    for tier in ['A','B']:
        for route in ['four','two']:
            available=[g for g in selected if g['route']==route and g['tier']==tier]
            display.append(min(available,key=lambda g:g['v']))
    fig,axs=plt.subplots(2,2,figsize=(14,8.8),layout='constrained')
    for ax,g in zip(axs.flat,display):panel(ax,g)
    handles,labels=[],[]
    for ax in axs.flat:
        h,l=ax.get_legend_handles_labels()
        for a,b in zip(h,l):
            if b not in labels:handles.append(a);labels.append(b)
    fig.legend(handles,labels,loc='outside lower center',ncol=3,frameon=False)
    fig.suptitle('综合扰动对照：逐组求解瞄准后，比较母球走位\n主样本为杆速 × 横打点 × 纵打点；所有区域固定第二袋 1（右上角袋）',fontsize=15)
    fig.savefig(OUT/'comparison.png',dpi=180);fig.savefig(OUT/'comparison.pdf');plt.close(fig)
    fig,axs=plt.subplots(2,2,figsize=(12,10),layout='constrained')
    for ax,g in zip(axs.flat,display):panel(ax,g,True)
    fig.legend(handles,labels,loc='outside lower center',ncol=3,frameon=False)
    fig.suptitle('第二球区域放大：每个标记是 3 cm 网格采样点\n黄色条件交集不代表全部扰动成功；绿色仅标已完成两杆验证的共同点',fontsize=13)
    fig.savefig(OUT/'regions.png',dpi=160);plt.close(fig)
    fig,axs=plt.subplots(2,2,figsize=(13,7),layout='constrained')
    for route,color in [('four','#c2762d'),('two','#287b6b')]:
      for tier,style in [('A','-'),('B','--')]:
        gs=sorted([g for g in groups if g['route']==route and g['tier']==tier],key=lambda g:g['v']);x=[g['v'] for g in gs];label=f"{'原四库' if route=='four' else '原两库'} / {tier}"
        axs[0,0].plot(x,[g['accepted']/27*100 for g in gs],style,color=color,marker='.',label=label)
        axs[0,1].plot(x,[len(g['common'])*9 for g in gs],style,color=color,marker='.')
        axs[1,0].plot(x,[(g['minimumClearance'] or 0)*100 for g in gs],style,color=color,marker='.')
        axs[1,1].plot(x,[g['sameOriginalRoute']/27*100 for g in gs],style,color=color,marker='.')
    for ax,title in zip(axs.flat,['首杆有效设计样本占比（%）','严格共同几何候选面积估计（cm²）','有效样本中最小离库净距（cm）','保持原库序且首杆有效的占比（%）']):
        ax.set_title(title);ax.set_xlabel('原有 13 档杆速（m/s）');ax.grid(alpha=.2)
    axs[1,0].axhline(10,color='#aa5555',lw=1,ls=':');axs[0,0].legend(fontsize=9)
    fig.suptitle('原有 13 档完整结果：低速处库数会变化，不能继续称作原四库／两库',fontsize=13)
    fig.savefig(OUT/'speed-sweep.png',dpi=160);plt.close(fig)
    headers=['线路 / 研究档','参考速度','实际库序','首杆有效','输入越界','最小离库 cm','最大停点偏移 cm','共同几何点','共同两杆点','其中全样本离库>10cm','代表第二球通过','第二球切角范围','第二杆最大抬杆°']
    table_rows=[]
    for g in selected_order:
        rep=g['representative'];ar=rep['angleRange']
        table_rows.append([('原四库' if g['route']=='four' else '原两库')+' / '+g['tier'],fmt(g['v'],4),'→'.join(map(str,g['nominalRails'])),f"{g['accepted']}/27",str(27-g['inputValid']),fmt(None if g['minimumClearance'] is None else g['minimumClearance']*100),fmt(None if g['scatterMax'] is None else g['scatterMax']*100),str(len(g['common'])),str(len(g['physicalCommon'])),str(len(g['physicalComfortCommon'])),f"{rep['pass']}/27",'—' if ar is None else f'{ar[0]:.2f}°～{ar[1]:.2f}°',fmt(rep['maxElevation'])])
    md='| '+' | '.join(headers)+' |\n|'+'|'.join(['---']*len(headers))+'|\n'+'\n'.join('| '+' | '.join(r)+' |' for r in table_rows)
    axis_rows=[]
    for g in display:
        axis_rows.append([g['id']]+[f"{g['axis'][k]['accepted']}/3，交集{g['axis'][k]['commonCount']}点" for k in ['speed','horizontalTip','verticalTip','direction']])
    axis_md='|线路|仅力度|仅横打点|仅纵打点|方向附加测试|\n|---|---|---|---|---|\n'+'\n'.join('| '+' | '.join(r)+' |' for r in axis_rows)
    metric_headers=['组别','基准母球行程 m','基准离库 cm','离库>10cm样本','原库序保持','袋嘴接触样本','首杆无法出杆','最小打点余量 R','基准第二球候选点','最佳球位几何覆盖']
    metric_rows=[]
    for g in selected_order:
        margin=g['miscueMarginRange']
        metric_rows.append([g['id'],fmt(g['nominalLength']),fmt((g['nominalClearance'] or 0)*100),f"{g['comfortableStops']}/27",f"{g['sameOriginalRoute']}/27",str(g['jawSamples']),str(g['firstAccessFailures']),fmt(margin[0] if margin else None,3),str(g['nominalSecondCandidates']),f"{g['maxGeometryCoverage']}/27"])
    metric_md='| '+' | '.join(metric_headers)+' |\n|'+'|'.join(['---']*len(metric_headers))+'|\n'+'\n'.join('| '+' | '.join(r)+' |' for r in metric_rows)
    audit=read('audit.json')
    text=f'''# 两条线路综合扰动实验

2026-10-22。主实验按用户确认，对每组杆速和打点重新调用生产求解器寻找第一球进指定袋的瞄准方向，再正向复验母球轨迹。不是固定瞄准的真人执行成功率。App 源码和原有 13 档未改。

## 条件

- 两条参考线路来自原研究 r2/38（侧打点 -0.25，纵打点 0，原库序 4→2→1→5）和 original/99（侧打点 0，纵打点 +0.25，原库序 4→5）。原始参考杆速均为 4.5 m/s。
- 原 13 档为 0.75 至 4.5，步长 0.3125 m/s。未新增初筛档；选择参考速度也只从这 13 档中取。
- A 档：杆速 ±4%，横纵打点各 ±0.025R；B 档：±8%、各 ±0.05R。每个维度取负、零、正，共 27 个组合。打点归一化量沿现有输入口径，R={radius*1000:.3f} mm。
- 附加方向试验：在各组合已求解方向上加 ±0.25° / ±0.5°。这些方向误差样本不混进主共同区域。
- 总计 {audit['scanRows']} 个设计输入，其中主实验 {audit['mainRows']} 个，方向附加 {audit['auxiliaryDirectionRows']} 个。越过 4.5 上限的输入不执行、不裁回边界，保留在分母并标为越界。统计是设计样本覆盖，不是随机概率。
- 第一袋为 pocket_2（横图左下），第二袋为 pocket_1（横图右上）。X–Z 平面、米，图中右 +X、下 +Z。

## 对照结果

本轮在两条原参考线路及保留原库序的替代档位上，均未找到满足全部27组扰动的共同网格点。两库2.9375 m/s在A档达到27/27首杆有效、最小离库20.22cm，但固定右上袋的最佳球位仅覆盖25/27，说明离库舒服不等于能稳定接续。四库4.5 m/s另有9组速度越界，合法18组中4组触袋嘴；不能把删掉这些输入后的区域当作完整容错区。

{md}

说明：表中保留 4.5 原参考，并列出按 A 档几何筛选选出的同原库序参考速度。选择规则依次比较全样本离库达标的共同点数、共同点数、首杆有效数、最小净距；没有找到原库序且合格的速度时不改名、不换线路。B 档沿用同一个已选速度，没有按 B 档另挑赢家。

![综合对比](comparison.png)

![第二球区域放大](regions.png)

## 线路与出杆指标

{metric_md}

“首杆有效”同时要求第一目标球进指定袋、母球不落袋、无袋嘴/意外碰撞、仿真停稳且首杆姿态可达；不强制库序不变。原库序保持单列。打点余量为生产滑杆边界减打点径向量；不是已标定的真人难度。行程是碰撞第一球后的母球记录折线长度。

评价按“硬失败→共同区→离库与第二杆可达性→敏感性和库序”分层阅读，本轮不拼凑一个缺少真人标定的总分。共同区的点数、估计面积、连通性和内部余量保存在final-results.json；本次选定组严格共同区均为0。第二杆距离、切角和姿态仅对找到见证的样本报告，空值不代表难度为零。

## 单项与联合扰动

{axis_md}

单项每组只含中心和两端 3 个点，用于定位敏感项；主结果来自 27 个联合点。不能用三点通过推定连续区间全部通过。

![13档结果](speed-sweep.png)

## 共同区域与物理复验

- 先用本次生产 effectivePocketAimPoint 和真实母球停点生成 ±20° 几何候选，排除第一杆母球/目标球原始物理折线通道（2R+5mm）和末态重叠。折线是筛选近似，最终候选放回开局物理复验。
- 对选定对照组的全部严格共同粗网格候选，以及原第二球位置，逐一把第二球从开局放入，重新执行首杆；要求第二球未动，再从真实状态验证第二杆。
- 第二杆使用现有求解器，预算为无侧塞、纵打点 0/+0.25/-0.25、杆速 1/1.5/2/2.5，记录找到的第一个合格见证。没找到只记“预算内未找到”；见证的抬杆角度不是所有可选第二杆中的最小值。
- 本轮共复验 {audit['validationRows']} 个“球位×扰动”组合，第二杆求解尝试 {audit['secondAttempts']} 次。切角独立按实际停点与生产有效入袋点复算；所报切角是几何切角，不冒称瞬时碰撞切角。
- 绿色点在该组全部 27 个主设计输入下均完成两杆。黄色仅为首杆成功条件下的几何交集，不能与严格共同区混同。蓝色为至少 90% 主设计输入覆盖的几何候选，不是 90% 真人成功率。
- 3cm 网格面积以点数×9cm²估计，内接半径按网格估计；不把离散点连成已证明的连续可行面，也不把空网格证明为连续空间绝对无解。

## 统一评价表的解释边界

- 杆速、打点、首杆可达性、库数/库序、行程、停点散布和净距已记录。完整 52 组见 all-13-speed-results.csv；逐样本见 evaluated-scan.json。
- 轨迹到袋口中心的最近距离作为辅助诊断保存在逐样本数据中，不当成真实捕获边界的安全余量。袋嘴接触、白球落袋与意外碰撞单列；有这些情况不通过本轮基础线路条件。
- 第二杆出杆用生产 CueStrikeAccess 的几何可达性/姿态判断；人体伸展、架杆需要和真实舒适感未标定。仿真仍沿用现有平杆模型，不能把显示所需抬杆角度当作已模拟抬杆物理。
- 同样的母球终点可能由不同库序达到。原库序保持与接续可用分开统计，13档低速结果按实际库数解释。
- 这轮两图对比固定原第二袋1；其他袋口的共同区尚未评估。空共同网格不等于该线路对所有袋口都不能生成题目。原13档内的低库数变体有非空几何候选，但未纳入本轮两杆复验，不能直接入题库。
- 参考速度从本轮网格筛选；两杆复验提供同一设计样本下的物理见证，没有独立随机保留集，也未作真人验证或唯一最优声明。

## 复现与证据

协议 protocol.json；输入 request-scan.json / request-validate.json；原始 scan-results.json / validate-results.json；汇总 final-results.json；核查 audit.json / geometry-checks.json；研究代码 Research.swift / analyze.py / report.py / run.py；构建与原始 XCTest 日志路径见 run-paths.json。

初始快照遗漏 QiuJiLiveActivity 导致首轮构建失败，未执行实验。用户确认逐组合重新求解后，研究测试重新编译；旧固定方向请求仅存为 superseded 文件，未用于本轮结果。App 源码快照和原目录的哈希分别留档。
'''
    (OUT/'REPORT.md').write_text(text)
    def htable(headers,rs):return '<div class="scroll"><table><thead><tr>'+''.join('<th>'+html.escape(x)+'</th>' for x in headers)+'</tr></thead><tbody>'+''.join('<tr>'+''.join('<td>'+html.escape(x)+'</td>' for x in r)+'</tr>' for r in rs)+'</tbody></table></div>'
    page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>两条线路综合扰动对照</title><style>body{margin:0;background:#f5f6f3;color:#203630;font:16px/1.65 -apple-system,BlinkMacSystemFont,sans-serif}main{max-width:1300px;margin:auto;padding:28px}h1{font-size:28px}h2{font-size:21px;margin-top:38px}.note{background:#e5ede6;padding:16px;border-radius:10px}img{display:block;width:100%;height:auto;margin:20px 0}.scroll{overflow:auto}table{border-collapse:collapse;min-width:900px;width:100%;font-size:13px}td,th{border-bottom:1px solid #ccd5cf;padding:10px;text-align:left}th{background:#e5ede6}a{color:#226f63}small{color:#5b6c63}@media(max-width:600px){main{padding:16px}h1{font-size:23px}}</style><main><h1>两条线路综合扰动对照</h1><p class="note">每组力度与打点重新求解瞄准，主看母球走位。每档27个组合；方向偏差另测。4.5 m/s上限及原13档保持。这里的占比是设计样本覆盖，不是真人成功率。</p>'''
    page+='<h2>母球轨迹与第二球区域</h2><img src="comparison.png" alt="两条线路和两档综合扰动的轨迹、停点、共同区域对比"><p>绿色为全部27个主样本两杆通过的离散球位；黄色仅在首杆成功条件下求交。原4.5参考的向上力度扰动越界，不能称作完整双侧容错。</p><h2>各项结果</h2>'+htable(headers,table_rows)
    page+='<h2>第二球区域放大</h2><img src="regions.png" alt="第二球共同候选区及两杆复验点放大"><h2>单项扰动诊断</h2>'+htable(['组别','力度','横打点','纵打点','方向附加'],axis_rows)
    page+='<h2>线路与出杆指标</h2>'+htable(metric_headers,metric_rows)+'<p>两库2.9375 m/s在A档27/27首杆有效、最小离库20.22cm，但最佳第二球位仅满足25/27组几何条件。严格共同区为空。固定第二袋1，其他袋口尚未评估。</p>'
    page+='<h2>原13档完整比较</h2><img src="speed-sweep.png" alt="13档速度的通过覆盖、区域、离库与库序对照"><p>低速处库数可能变化。序列按实际记录，不把所有低速轨迹继续叫四库。</p><p><a href="REPORT.md">完整口径与实验报告</a> · <a href="all-13-speed-results.csv">52组原始指标表</a> · <a href="final-results.json">汇总数据</a></p><small>平杆物理；出杆角度仅几何评估。离散网格不证明连续区域；未作真人难度标定。</small></main></html>'
    (OUT/'report.html').write_text(page)
    print(json.dumps(audit,ensure_ascii=False));print('REPORT_READY',flush=True)
