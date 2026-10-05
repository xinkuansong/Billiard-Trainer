#!/usr/bin/env python3
"""Post-hoc scratch analysis of the frozen joint-v2 study; no parameter retuning."""
from __future__ import annotations
import json, math, statistics, hashlib, html
from collections import Counter
from pathlib import Path
import joint_break_research as j
from analyze_break_research import wilson, write_csv

OUT=j.OUT
REPORT=j.REPORT/'scratch-20261003'
POCKETS={'pocket_0':(-1.312,-.677),'pocket_1':(1.312,-.677),'pocket_2':(-1.312,.677),
         'pocket_3':(1.312,.677),'pocket_4':(0,-.688),'pocket_5':(0,.688)}
NAMES={'pocket_0':'球架端角袋（图下）','pocket_1':'开球端角袋（图下）','pocket_2':'球架端角袋（图上）',
       'pocket_3':'开球端角袋（图上）','pocket_4':'图下中袋','pocket_5':'图上中袋'}

def data(phase,c):
    n={'broad':256,'local':256,'screen':1000,'holdout':10000}[phase]
    result=[]
    for offset in range(0,n,1000):
        batch=f"{phase}-{c['name']}-{offset//1000+1:02}"
        manifest=j.load(OUT/f'{batch}-execution.json')
        assert manifest['batchComplete'] and manifest['testExecuted'] and manifest['productionUnchanged'] and manifest['exitCode']==0
        result.extend(r for r in j.rows(batch) if 'id' in r)
    assert len(result)==n and len({r['seed'] for r in result})==n
    return result

def summarize(phase,c,rows):
    valid=[r for r in rows if r['settled']];unknown=len(rows)-len(valid)
    scratches=[r for r in valid if r['scratch']]
    paths=[]
    for r in scratches:
        cue=[v for v in r['pocketPaths'] if v['ball']=='cueBall']
        assert len(cue)==1 and r['contact'] and cue[0]['pocket'] in POCKETS
        paths.extend(cue)
    counts=Counter(p['pocket'] for p in paths);n=len(rows);k=len(paths)
    buckets=Counter(('cushion' if p['cushions'] else 'noCushion')+'_'+('multipleContactEvents' if p['ballContacts']>1 else 'oneContactEvent') for p in paths)
    return dict(**c,phase=phase,n=n,resolved=len(valid),unknown=unknown,scratches=k,
        scratchRate=k/n,scratchBounds=[k/n,(k+unknown)/n],scratchWilson95Envelope=[wilson(k,n)[0],wilson(k+unknown,n)[1]],
        pocketCounts={p:counts[p] for p in POCKETS},pocketAbsoluteRates={p:counts[p]/n for p in POCKETS},
        scratchPocketShares={p:counts[p]/k for p in POCKETS} if k else {},
        eventCountBuckets=dict(buckets),entrySources=dict(Counter(p['entrySource'] for p in paths)),
        ordinaryAndScratch=sum(r['ordinaryPots']>0 for r in scratches),
        meanScratchTime=statistics.mean(p['time'] for p in paths) if k else None,
        meanEntrySpeed=statistics.mean(p['entrySpeed'] for p in paths) if k else None)

def paired_scratch(a,b):
    aa={r['seed']:r for r in a};bb={r['seed']:r for r in b}
    assert aa.keys()==bb.keys() and len(aa)==len(a)==len(b)
    assert all(r['settled'] for r in a+b)
    d=[int(bb[s]['scratch'])-int(aa[s]['scratch']) for s in sorted(aa)]
    mean=statistics.mean(d);se=statistics.stdev(d)/math.sqrt(len(d))
    return dict(n=len(d),difference=mean,pairedNormal95=[mean-1.95996398454*se,mean+1.95996398454*se],
                candidateOnly=d.count(1),baselineOnly=d.count(-1),both=sum(aa[s]['scratch'] and bb[s]['scratch'] for s in aa))

def replay_details():
    provenance=j.load(OUT/'scratch-replay-20261003-input-provenance.json')
    review=j.load(OUT/'scratch-replay-20261003-review.json');assert review['complete'] and review['exactOriginalOutcomeAndPathMetadata']
    details=[]
    replays=[r for r in j.rows('scratch-replay-20261003') if 'id' in r]
    for m,r in zip(provenance,replays):
        events=[e for e in r['eventTimeline'] if (e['kind']=='ballBall' and -1 in e.get('slots',[])) or (e.get('slot')==-1 and e['kind'] in ('cushion','pocket'))]
        first=r['contact']['time'];firstslot=r['contact']['firstSlot']
        late=[e for e in events if e['kind']=='ballBall' and e['time']>first+.001 and any(s not in (-1,firstslot) for s in e['slots'])]
        same_first=sum(e['kind']=='ballBall' and e['slots']==[-1,firstslot] and abs(e['time']-first)<=.0001 for e in events)
        details.append(dict(**m,id=r['id'],cueTimeline=events,lateDifferentBallContacts=late,firstContactEventsWithin100us=same_first,
            scratchPath=next(p for p in r['pocketPaths'] if p['ball']=='cueBall')))
    return details,replays

def plots(records,replays):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.patches import Circle,Rectangle
    from matplotlib.font_manager import FontProperties
    font=FontProperties(fname='/System/Library/Fonts/STHeiti Medium.ttc');plt.rcParams['font.family']=font.get_name();plt.rcParams['axes.unicode_minus']=False
    chosen=[('J0-0507',300001,'首碰后直冲角袋'),('J0-0970',300001,'碰库后进中袋'),('B0',400063,'较晚与散球接触后进袋'),('J0-0758',300001,'较强侧旋＋高杆，厚撞也有危险路径')]
    fig,axes=plt.subplots(2,2,figsize=(15,10),constrained_layout=True,facecolor='#f7f9fb')
    for ax,(name,seed,title) in zip(axes.flat,chosen):
        r=next(r for r in replays if r['id']==f'scratchDiag_{name}_s{seed}')
        p=next(p for p in r['pocketPaths'] if p['ball']=='cueBall')
        frames=next(t['frames'] for t in r['trajectories'] if t['slot']==-1)
        frames=[f for f in frames if f[0]<=p['time']+1e-6]
        ax.add_patch(Rectangle((-1.27,-.635),2.54,1.27,facecolor='#edf5ef',edgecolor='#276752',linewidth=2.5))
        for q in POCKETS.values():ax.add_patch(Circle(q,.039,color='#34483f'))
        for q in r['rackPositions']:ax.add_patch(Circle((q[0],q[2]),.028575,facecolor='#d4b66f',alpha=.65))
        before=[f for f in frames if f[0]<=r['contact']['time']+1e-6]
        after=[f for f in frames if f[0]>=r['contact']['time']-1e-6]
        ax.plot([f[1] for f in before],[f[2] for f in before],color='#2874af',lw=2,ls='--',label='首碰前')
        ax.plot([f[1] for f in after],[f[2] for f in after],color='#df5a42',lw=2,label='首碰后采样轨迹')
        c=r['cuePosition'];ax.add_patch(Circle((c[0],c[2]),.028575,facecolor='white',edgecolor='#33485d',lw=1.5,zorder=6))
        target=POCKETS[p['pocket']];ax.add_patch(Circle(target,.054,fill=False,edgecolor='#bf2f25',lw=2.5))
        marked=None
        if name=='B0':
            marked=next(e for e in r['eventTimeline'] if e['kind']=='ballBall' and e.get('slots')==[-1,1])
            label='0.611s 与散球再接触';text=(-.08,.32)
        elif name=='J0-0970':
            marked=next(e for e in r['eventTimeline'] if e['kind']=='cushion' and e.get('slot')==-1)
            label='先碰库，再折向中袋';text=(.03,-.35)
        if marked:
            point=min(frames,key=lambda f:abs(f[0]-marked['time']))
            assert abs(point[0]-marked['time'])<1e-6
            ax.plot(point[1],point[2],'*',color='#774c9e',markersize=10,zorder=7)
            ax.annotate(label,xy=(point[1],point[2]),xytext=text,fontproperties=font,fontsize=10,color='#774c9e',
                arrowprops=dict(arrowstyle='->',color='#774c9e'))
        ax.set_title(f'{title}\n{name} · seed {seed} · {p["time"]:.3f}s 落袋',fontproperties=font,fontsize=13)
        ax.set_xlim(-1.45,1.45);ax.set_ylim(-.91,.86);ax.set_aspect('equal');ax.axis('off')
        label=f'射线角 {r["theta"]:+.2f}°｜实测 b/D {r["contact"]["fraction"]:+.3f}\n杆速 {r["power"]:.2f}m/s｜左右打点 {r["spinX"]:+.3f}R｜高低打点 {r["spinY"]:+.3f}R'
        ax.text(0,-.87,label,ha='center',fontproperties=font,fontsize=10,color='#43576b')
        ax.legend(prop=FontProperties(fname=font.get_file(),size=9),loc='upper right')
    fig.suptitle('白球掉袋的四条模型实测路径',fontproperties=font,fontsize=20)
    fig.savefig(REPORT/'scratch-paths.png',dpi=180);fig.savefig(REPORT/'scratch-paths.svg');plt.close(fig)
    hold=[r for r in records if r['phase']=='holdout'];screen=[r for r in records if r['phase']=='screen']
    fig,axes=plt.subplots(1,2,figsize=(14,5),constrained_layout=True)
    for ax,groups,title in ((axes[0],hold,'独立复验：各 10,000 架'),(axes[1],screen,'新种子筛选：各 1,000 架')):
        for i,r in enumerate(groups):
            lo,hi=r['scratchWilson95Envelope'];v=r['scratchRate']
            ax.errorbar(i,100*v,yerr=[[100*(v-lo)],[100*(hi-v)]],fmt='o',capsize=5)
        ax.set_xticks(range(len(groups)),[r['name'] for r in groups],rotation=35 if len(groups)>2 else 0)
        ax.set_ylabel('白球落袋率（%）',fontproperties=font);ax.set_title(title,fontproperties=font);ax.grid(alpha=.2)
    fig.savefig(REPORT/'scratch-rates.png',dpi=180);fig.savefig(REPORT/'scratch-rates.svg');plt.close(fig)

def report(result):
    rows=result['groups'];hold=[r for r in rows if r['phase']=='holdout'];screen=[r for r in rows if r['phase']=='screen']
    select=['J0-0507','J0-0970','J0-0758','J1-0459']
    risky=[r for r in rows if r['phase']=='broad' and r['name'] in select]
    def table(groups):
        cells=[]
        for r in groups:
            bounds=r['scratchBounds'];v=f'{100*bounds[0]:.2f}%' if not r['unknown'] else f'{100*bounds[0]:.2f}–{100*bounds[1]:.2f}%'
            lo,hi=r['scratchWilson95Envelope']
            cells.append(f'<tr><td>{r["name"]}</td><td>{r["n"]:,}</td><td>{v}</td><td>{100*lo:.2f}–{100*hi:.2f}%</td><td>{r["theta"]:+.2f}°</td><td>{r["fraction"]:+.3f}</td><td>{r["power"]:.2f}</td><td>{r["spinX"]:+.3f}, {r["spinY"]:+.3f}</td><td>{r["unknown"]}</td></tr>')
        return '<div class="scroll"><table><tr><th>方案</th><th>N</th><th>白球落袋</th><th>Wilson 95%/未知包络</th><th>初始射线θ</th><th>名义b/D</th><th>杆速m/s</th><th>左右/高低打点R</th><th>未知</th></tr>'+''.join(cells)+'</table></div>'
    p=result['holdoutPairedScratch'];lo,hi=p['pairedNormal95']
    pocketrows=''.join(f'<tr><td>{name}</td>'+''.join(f'<td>{r["pocketCounts"][key]} / {r["scratches"]}（每次开球{100*r["pocketAbsoluteRates"][key]:.2f}%）</td>' for r in hold)+'</tr>' for key,name in NAMES.items())
    sections=''.join('<h3>'+html.escape(d['control'])+' / seed '+str(d['seed'])+'</h3><pre>'+html.escape(json.dumps(d['cueTimeline'],ensure_ascii=False,indent=2))+'</pre>' for d in result['diagnosticCases'])
    doc=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>开球白球落袋分析</title><style>body{{font-family:-apple-system,"PingFang SC",sans-serif;line-height:1.75;background:#f6f8fb;color:#203047}}main{{max-width:1200px;margin:auto;padding:28px}}.card{{background:white;border-radius:12px;padding:20px;margin:18px 0}}table{{border-collapse:collapse;white-space:nowrap;font-size:13px}}td,th{{padding:8px;border-bottom:1px solid #ddd}}.scroll{{overflow-x:auto}}img{{width:100%}}a{{color:#126775}}pre{{font-size:12px;overflow-x:auto}}</style><main>
    <h1>开球怎样让白球掉袋：冻结模型的事后分析</h1><p>2026-10-03 · 复用原研究数据；8条诊断重放不增加概率样本，也不重新选参数。</p>
    <div class="card"><b>主要发现：危险的是首碰后的整条白球路径与袋口相交；力度、旋转、厚薄和入射方向共同决定路径。</b><p>模型内已出现首碰后直进角袋、先碰库再进中袋、较晚与散球接触后进袋。没有“越大力越容易掉袋”或“某种杆法一定安全”的单变量结论。正式物理、摆球分布和内部球序均未修改。</p></div>
    <h2>已完成独立复验的白球落袋概率</h2>{table(hold)}<p>L2-01−B0：+{100*p['difference']:.2f}个百分点，配对渐近95%区间[{100*lo:+.2f},{100*hi:+.2f}]个百分点。本分析是事后追加指标，未做所有探索比较的多重检验校正。两组复用同10,000架，正式复验均停稳。</p>
    <p>基准有170/10,000局同时下普通球与白球；第二排候选有326/10,000局。白球风险更高，但候选主要有效下球仍为55.25%，基准41.11%。不能把“不下任何球”的低白球落袋率当成好开球。</p>
    <h2>白球主要掉进哪里</h2><div class="scroll"><table><tr><th>袋口</th><th>B0：429局白球掉袋</th><th>L2-01：574局白球掉袋</th></tr>{pocketrows}</table></div>
    <p>正面基准226/429（52.68%）落入中袋；第二排候选464/574（80.84%）落入角袋。L2-01的574局白球落袋均记录至少一次白球碰库事件，不能概括为一碰就直接掉袋。图采用X向右、Z向上，Y竖直，不沿用App屏幕上下方位；球架在−X端、白球在+X端，单位米。</p>
    <h2>四条代表路径</h2><img src="scratch-paths.png"><p>初始球架用淡黄色显示，其他球运动未绘制；红线是白球首碰后的采样折线，不是完整连续解。袋口红圈来自原落袋事件。8局重放的接触、终态、持续时间、事件数、下球和路径元数据均与原记录精确一致。</p>
    <div class="card"><p><b>直进角袋：</b>J0-0507在256架中138次白球落袋（53.91%），其中129次只有一次球球接触、无碰库，全部落入球架端图下角袋。代表局首碰0.205s、落袋0.531s。斜入射和撞击厚薄组合把白球首碰后的方向送向角袋。</p>
    <p><b>碰库后进中袋：</b>J0-0970在256架中151次（58.98%）落袋，全部有碰库记录，143次落入图上中袋。代表局首碰0.192s、碰库0.407s、落袋1.190s。只检查首碰后的直线方向会漏掉这类风险。</p>
    <p><b>散球再接触：</b>B0种子400063在0.126s首碰顶球，0.611s与slot1再次接触，1.188s进入中袋；因此即便起始近乎正碰，也可能在球群散开后改变白球走向。L0-01种子320011在1.090s碰库、2.678s与slot5接触、4.862s落袋。</p>
    <p><b>厚撞与旋转：</b>J0-0758名义首碰近正碰，但左右打点+0.319R、高低打点+0.287R；256架中198次（77.34%）落袋，均为球架端图上角袋。实际首碰平均b/D约−0.060，不能把初始名义几何代替实际接触。另一组J1-0459将强低杆−0.447R、斜入射和第二排薄撞结合，128/256（50.00%）掉袋，说明“低杆拉回来”也不是通用安全条件。</p></div>
    <h2>筛选中的较成熟对照</h2>{table(screen)}<img src="scratch-rates.png"><p>顶球候选L0-01白球落袋49/1,000（4.9%），尚未独立1万架复验；高有效率方案L1-16白球落袋125/1,000（12.5%）。L3-09保留1局未知，白球概率上下界9.8%–9.9%，未按999局重新归一化。</p>
    <h2>能否单独归因于力度或杆法</h2><p>同白球位置/初始射线/名义厚薄/打点，A00–A03仅改变杆速4、6、8、10m/s，白球落袋率为3.52%、6.25%、4.69%、4.30%，每组256架。没有呈现单调增加，但样本不足以证明力道不影响风险。其他联合候选同时变化多个变量，不能从其排名断言“加左塞导致77%掉袋”或“高杆更安全”。速度和打点还会改变实际首碰速度与旋转，这也是固定操作比较的一部分。</p>
    <h2>事件与模型限制</h2><p>诊断发现同一球对在同一时刻或100微秒内出现重复首碰事件。例如J0-0970与J0-0758的前两次cue/slot0接触都在完全相同的时刻。因此pocketPaths.ballContacts仅是引擎接触事件数，不能把“≥2”直接解释为较晚被另一颗散球撞到。只有完整时间线且对象/时刻符合条件的代表局，才按散球再接触解释；没有把少量轨迹类别推广成所有球局的精确比例。</p>
    <p>B0的211/429、L2-01的275/574次白球落袋由boundsFallback记录，其余由event记录。兜底仍调用同一containsCapture捕获区域检查，并非把这些局全部判为虚假掉袋；但捕获时序与真实袋口效果还没有实物验证。原研究已知的正间隙提前碰撞、球序敏感、平面运动与无出杆误差限制仍然有效。</p>
    <p>高风险探索组均为256架且事后挑选，只用于识别当前模型中的危险组合，不是经独立1万架确认的概率，也不是全域危险阈值。不能据此给出通用“夹角超过某值必掉袋”的口诀。下一步有意义的验证是冻结危险与安全方案，用新球架和明确出杆误差配对验证，并在共同起点下分别改变打点/杆速/名义厚薄；本次未运行这些新增大样本实验。</p>
    <p><a href="summary.json">全部汇总与配对差</a> · <a href="groups.csv">完整各组表</a> · <a href="../best-apex-layout.png">顶球候选摆位图</a> · <a href="../report.html">原联合搜索报告</a></p><details><summary>8条代表局的白球事件时间线</summary>{sections}</details></main></html>'''
    (REPORT/'report.html').write_text(doc)

def main():
    REPORT.mkdir(parents=True,exist_ok=True)
    assert j.br.hashes()==j.load(OUT/'compiled-evidence.json')['sourceHashes']
    groups=[];all_data={}
    for phase in ('broad','local','screen','holdout'):
        for c in j.load(OUT/f'{phase}-controls.json'):
            rows=data(phase,c);all_data[phase,c['name']]=rows;groups.append(summarize(phase,c,rows))
    details,replays=replay_details()
    paired=paired_scratch(all_data['holdout','B0'],all_data['holdout','L2-01'])
    assert paired['n']==10000 and paired['candidateOnly']==551 and paired['baselineOnly']==406 and paired['both']==23
    result=dict(complete=True,date='2026-10-03',modelOnly=True,postHoc=True,originalProbabilityEvaluations=sum(r['n'] for r in groups),
        addedProbabilityEvaluations=0,diagnosticReplays=8,groups=groups,holdoutPairedScratch=paired,diagnosticCases=details,
        contactEventCountIsNotPhysicalRecollisionCount=True,sourceSHA256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
    assert result['originalProbabilityEvaluations']==59464
    j.br.write_json(REPORT/'summary.json',result);write_csv(REPORT/'groups.csv',groups)
    plots(groups,replays);report(result)
    print(json.dumps(dict(groups=len(groups),total=result['originalProbabilityEvaluations'],addedTrials=0,paired=paired,report=str(REPORT/'report.html')),ensure_ascii=False))

if __name__=='__main__':main()
