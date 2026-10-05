#!/usr/bin/env python3
"""Build a model-only scientific report from recorded screening and holdout evidence."""
from __future__ import annotations
from collections import Counter
import base64
import json
import math
import statistics
from analyze_break_research import REPORT, read_rows, wilson, summary
from sample_break_research import selection
from break_research import OUT, ROOT, write_json, hashes


def percent(x):
    return f"{100*x:.2f}%"


def intervals(x):
    return "–".join(percent(v) for v in x)


def difference_interval(x):
    return f"{100*x[0]:+.2f} 至 {100*x[1]:+.2f} pp"


def path_statistics(rows):
    slots=Counter(); pockets=Counter(); sources=Counter(); histogram=Counter()
    contacts=[r["contact"] for r in rows if "contact" in r]
    for r in rows:
        histogram[r.get("ordinaryPots",0)]+=1
        for p in r.get("pocketPaths",[]):
            if p["ball"] in ("cue","_8") or p["slot"] < 0:
                continue
            slots[p["slot"]]+=1; pockets[p["pocket"]]+=1; sources[p.get("entrySource","unknown")]+=1
    return dict(n=len(rows),ordinaryPotHistogram=histogram,slotPots=slots,pocketPots=pockets,entrySources=sources,
                actualContact={k:dict(mean=statistics.mean(c[k] for c in contacts),min=min(c[k] for c in contacts),
                    max=max(c[k] for c in contacts)) for k in ("theta","fraction","speed")})


def screening_figure(screen):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig,ax=plt.subplots(figsize=(10,5),layout="constrained")
    for i,r in enumerate(screen["groups"]):
        y=r["effectiveRate"]*100; lo,hi=r["wilson95"]
        ax.bar(i,y,color="#1f4e79" if r["name"]=="C0" else "#168c83" if r["name"]==screen["selected"] else "#a9b8c8")
        ax.errorbar(i,y,yerr=[[y-lo*100],[hi*100-y]],fmt="none",color="#243449",capsize=5)
        ax.text(i,y+4,f"{y:.1f}%",ha="center")
    ax.set_xticks(range(len(screen["groups"])),[f"{r['name']}\n{r['theta']} deg; b/D={r['fraction']:g}" for r in screen["groups"]])
    ax.set_ylim(0,65);ax.set_ylabel("Ordinary pot without cue scratch (%)")
    ax.set_title("Screening: 1,000 independent production racks per fixed control\n95% Wilson intervals; candidate selection only")
    fig.savefig(REPORT/"screening-comparison.png",dpi=160);plt.close(fig)


def figures(screen, final):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    screening_figure(screen)
    fig,axes=plt.subplots(1,2,figsize=(11,5),layout="constrained")
    for i,r in enumerate(final["groups"]):
        for j,(metric,k_label) in enumerate([("effectiveRate","Effective pot"),("ordinaryPotRate","Ordinary pot"),("scratchRate","Cue scratch")]):
            rate=r[metric];lo,hi=wilson(round(rate*r["n"]),r["n"])
            x=j+(i-.5)*.32
            axes[0].bar(x,rate*100,width=.3,color=["#1f4e79","#168c83"][i],label=r["name"] if j==0 else None)
            axes[0].errorbar(x,rate*100,yerr=[[(rate-lo)*100],[(hi-rate)*100]],fmt="none",color="#243449",capsize=4)
            axes[0].text(x,rate*100+2,f"{rate*100:.2f}",ha="center",fontsize=8)
    axes[0].set_xticks([0,1,2],["Effective pot","Ordinary pot","Cue scratch"])
    axes[0].set_ylim(0,65);axes[0].set_ylabel("Probability (%)");axes[0].legend()
    p=final["paired"];d=p["meanDifference"]*100;lo,hi=[v*100 for v in p["pairedNormal95"]]
    axes[1].axvline(0,color="#778899",linestyle="--")
    axes[1].errorbar(d,0,xerr=[[d-lo],[hi-d]],fmt="o",color="#168c83",capsize=8)
    axes[1].set_yticks([0],["Candidate minus baseline"]);axes[1].set_ylim(-1,1)
    axes[1].set_xlim(min(-2,lo-2),max(2,hi+2));axes[1].set_xlabel("Difference (percentage points), paired 95% interval")
    axes[1].text(d,.2,f"{d:+.2f} pp [{lo:+.2f}, {hi:+.2f}]",ha="center",fontsize=10)
    fig.suptitle(f"Independent holdout: {p['n']:,} racks per control; current engine / current rack distribution")
    fig.savefig(REPORT/"holdout-comparison.png",dpi=170);fig.savefig(REPORT/"holdout-comparison.svg");plt.close(fig)
    geometry_controls()


def geometry_controls():
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    reference=next(r for r in read_rows("geometry") if r["rackKind"]=="nominal" and r["theta"]==0 and abs(r["fraction"])<1e-5)
    positions=reference["rackPositions"];radius=.028575
    # Plot coordinates and radius are taken from the recorded nominal rack and verified production constants.
    diameter=math.dist(positions[0],positions[1])-.00020;assert abs(diameter/2-radius)<1e-6
    fig,axes=plt.subplots(2,1,figsize=(11,10),layout="constrained")
    for ax,c in zip(axes,selection()):
        ax.plot([-1.27,1.27,1.27,-1.27,-1.27],[-.635,-.635,.635,.635,-.635],color="#64748b")
        for p in positions:
            ax.add_patch(plt.Circle((p[0],p[2]),radius,fc="#cf7961",ec="#333333",lw=.5))
        ax.add_patch(plt.Circle((c["cueX"],c["cueZ"]),radius,fc="white",ec="#333333"))
        u=(-math.cos(math.radians(c["aimTheta"])),math.sin(math.radians(c["aimTheta"])))
        # n = u*cos(beta)+p*sin(beta), with p=(sin(theta),cos(theta)).
        beta=math.asin(c["fraction"]);theta=math.radians(c["theta"])
        n=(-math.cos(theta)*math.cos(beta)+math.sin(theta)*math.sin(beta),math.sin(theta)*math.cos(beta)+math.cos(theta)*math.sin(beta))
        k=(positions[0][0]-diameter*n[0],positions[0][2]-diameter*n[1])
        assert abs((k[0]-c["cueX"])*u[1]-(k[1]-c["cueZ"])*u[0])<1e-6
        ax.annotate("",xy=k,xytext=(c["cueX"],c["cueZ"]),arrowprops=dict(arrowstyle="->",color="#168c83",lw=2))
        ax.plot([positions[0][0],.5],[positions[0][2],0],ls="--",color="#b1bbc5",lw=1)
        ax.axvline(.635,ls=":",color="#64748b",lw=.8)
        ax.text(c["cueX"]+.06,c["cueZ"],f"Cue Z={100*c['cueZ']:+.2f} cm",fontsize=9)
        ax.set_aspect("equal");ax.set_xlim(-1.4,1.5);ax.set_ylim(-.73,.73)
        ax.set_title(f"{c['name']}: incoming angle={c['theta']} deg; signed offset b/D={c['fraction']:g}\nCue X=0.70 m; reference impact 10 m/s, zero spin at impact",fontsize=11)
        ax.set_xlabel("SceneKit X (m)");ax.set_ylabel("SceneKit Z (m)")
        inset=ax.inset_axes([.02,.045,.23,.29])
        relative=(k[0]-positions[0][0],k[1]-positions[0][2])
        inset.add_patch(plt.Circle((0,0),radius,fc="#cf7961",ec="#333333",lw=.7))
        inset.add_patch(plt.Circle(relative,radius,fc="white",ec="#333333",lw=.7))
        tail=(relative[0]-u[0]*.065,relative[1]-u[1]*.065)
        inset.annotate("",xy=relative,xytext=tail,arrowprops=dict(arrowstyle="->",color="#168c83",lw=1.3))
        inset.plot([relative[0],0],[relative[1],0],ls="--",color="#c16c31",lw=1)
        foot=(relative[0]+(-relative[0]*u[0]-relative[1]*u[1])*u[0],
              relative[1]+(-relative[0]*u[0]-relative[1]*u[1])*u[1])
        inset.plot([0,foot[0]],[0,foot[1]],color="#1f4e79",lw=1)
        assert abs(math.hypot(*foot)-abs(c['fraction'])*diameter)<1e-8
        inset.set_aspect("equal");inset.set_xlim(-.038,.15);inset.set_ylim(-.046,.079)
        inset.set_xticks([]);inset.set_yticks([])
        inset.set_title(f"Contact detail: beta={math.degrees(beta):+.2f} deg",fontsize=7)
    fig.suptitle("Frozen break controls on the nominal rack; X-Z plane, rack points toward -X")
    fig.savefig(REPORT/"controls-geometry.png",dpi=160);plt.close(fig)


def gap_figure(gap_results):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    examples=next(r["pairs"] for r in gap_results if r["kind"]=="gapPredicateExamples")
    fig,ax=plt.subplots(figsize=(9,4),layout="constrained")
    x=[r["gapM"]*1000 for r in examples]
    y=[r["ccdTimeS"]*1e6 for r in examples]
    actual=[0 if r["immediatePredicate"] else r["ccdTimeS"]*1e6 for r in examples]
    ax.plot(x,y,"o-",color="#168c83",label="CCD time to geometric contact")
    ax.plot(x,actual,"s",color="#bf6355",label="Current immediate-contact branch, otherwise CCD")
    ax.hlines(0,min(x),.25,color="#bf6355",linestyle="--",linewidth=1)
    ax.axvline(.25,ls=":",color="#64748b",label="Immediate-contact tolerance: 0.25 mm")
    ax.set_xlabel("Positive surface gap (mm)");ax.set_ylabel("Time until contact (microseconds)")
    ax.set_title("Separated balls approaching at 10 m/s: current predicate erases small flight times")
    ax.legend(fontsize=9);fig.savefig(REPORT/"gap-trigger-audit.png",dpi=160);plt.close(fig)


def main():
    screen=json.loads((REPORT/"screening.json").read_text());final=json.loads((REPORT/"holdout.json").read_text())
    if not final["complete"]:raise RuntimeError("Report requires the predeclared 10,000 samples per control")
    audit=json.loads((REPORT/"order-ensemble-audit.json").read_text())
    gap_results=json.loads((OUT/"gap-audit-results.json").read_text())
    gap=next(r for r in gap_results if r["kind"]=="rackGapAudit")
    if any(r["unknown"] for r in final["groups"]):raise RuntimeError("Report must explicitly account for unresolved outcomes")
    fingerprints=json.loads((OUT/"production-hashes-before.json").read_text())
    unchanged=hashes()==fingerprints
    if not unchanged:raise RuntimeError("Production source drift: retain evidence and diagnose before reporting")
    paths={}
    for c in selection():
        rows=[r for i in range(1,11) for r in read_rows(f"holdout-{c['name']}-{i:02}")]
        paths[c["name"]]=path_statistics(rows)
    write_json(REPORT/"path-and-contact-statistics.json",paths)
    figures(screen,final)
    gap_figure(gap_results)
    write_json(REPORT/"gap-audit.json",gap_results)
    p=final["paired"];lo,hi=p["pairedNormal95"]
    verdict="候选在本模型中优于基准" if lo>0 else "候选在本模型中低于基准" if hi<0 else "尚未证实候选与基准有明确差异"
    table="".join(f"<tr><td>{r['name']}</td><td>{r['theta']}°</td><td>{r['fraction']:g}</td><td>{100*r['cueZ']:+.2f} cm</td><td>{r['n']:,}</td><td>{percent(r['ordinaryPotRate'])}</td><td>{percent(r['scratchRate'])}</td><td>{percent(r['eightRate'])}</td><td>{percent(r['effectiveRate'])}</td><td>{intervals(r['wilson95'])}</td></tr>" for r in final["groups"])
    audits="".join(f"<tr><td>{r['candidate']}</td><td>{r['outcomeChanged']}/{r['n']}</td><td>{percent(r['original']['effectiveRate'])}</td><td>{percent(r['reversed']['effectiveRate'])}</td><td>{100*r['meanDifference']:+.2f} pp</td><td>{difference_interval(r['pairedNormal95'])}</td></tr>" for r in audit)
    state=dict(totalProbabilityTrials=28000,screening=6000,holdout=20000,orderAudit=2000,
               productionUnchanged=unchanged,testSourceRestored=json.loads((OUT/"restoration.json").read_text())["testSourceIdentical"],
               verdict=verdict,modelOnly=True,modelPassedOrderRobustness=False,rackGapAuditRacks=10000,
               expectedFailure="Separated approaching pair with a positive 0.20 mm gap triggers current t=0 predicate",
               holdoutSelection=json.loads((OUT/"holdout-selection.json").read_text()))
    write_json(REPORT/"final-evidence.json",state)
    joint_path=REPORT/"joint-v2/final.json"
    joint_note=""
    if joint_path.exists():
        joint=json.loads(joint_path.read_text())
        if joint.get("complete") and len(joint["groups"])==2 and all(g["n"]==10000 for g in joint["groups"]):
            baseline,candidate=joint["groups"]
            joint_note=(f'<div class="card verdict"><h2>联合参数搜索已完成</h2><p>固定摆球随机模型，搜索位置、方向/厚薄、力度与旋转，'
                f'独立复验各10,000架：基准有效普通下球{percent(baseline["effectiveRate"])}，'
                f'锁定候选{percent(candidate["effectiveRate"])}。这是当前模型内的结果，保留以下引擎审计限制。</p>'
                '<p><a href="joint-v2/report.html">查看最新联合搜索、候选参数与配对区间</a></p></div>')
    document=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>中八开球下球研究 · 首轮</title><style>
body{{font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif;color:#203047;background:#f6f8fb;margin:0;line-height:1.75}}main{{max-width:1080px;margin:auto;padding:36px}}h1{{font-size:30px}}h2{{margin-top:36px;font-size:21px}}.card{{background:white;padding:24px;border-radius:12px;margin:20px 0}}.verdict{{border-left:5px solid #168c83}}table{{border-collapse:collapse;width:100%;font-size:14px}}th,td{{padding:9px;border-bottom:1px solid #e2e8f0;text-align:left}}img{{width:100%;background:white}}small{{color:#64748b}}code{{font-size:13px}}a{{color:#126775}}.scroll{{overflow-x:auto}}</style><main>
<h1>中八开球下球研究：固定摆球随机模型，搜索开球参数</h1><small>2026-10-02 · 首轮实测 · 现有生产物理引擎 · 模型概率</small>
<p><a href="joint-v2/report.html">查看联合参数搜索：位置、角度/厚薄、力度、高低杆和左右塞</a>（统一120秒模拟预算，阶段进度与独立复验另页保留）</p>
{joint_note}
<div class="card"><h2>实验约束与搜索范围</h2><p><b>固定：</b>生产名义间距0.20mm、随机扰动半径0.09mm及其抽样分布、球号规则、球桌和物理版本。每局换种子是从同一个摆球模型抽样，不是在搜索摆球参数；不同开球条件使用相同球架作配对比较。</p><p><b>搜索：</b>白球位置、相对球架方向与撞击厚薄、杆头速度、高低杆及左右塞。每组操作参数在整批随机球架中保持固定，不按具体球架重新瞄准。本页保留首轮：仅比较顶球首碰、一个纵向位置及一个参考碰撞状态下的角度/厚薄候选。位置、速度、左右塞与第二排首碰的联合研究见上方报告。</p></div>
<div class="card verdict"><h2>概率基线已测量，但模型未通过球序鲁棒性审计</h2><p>候选在同一批1,000架中，仅反转内部计算顺序，有效普通下球率便从40.8%降至26.0%。差−14.8个百分点，配对95%区间[−18.88,−10.72]个百分点。球间立即碰撞容差0.25mm大于名义间距0.20mm，会提前处理许多尚有间隙的接近球对。这个机制已定位，但不宣称它解释全部球序偏差。</p><p>因此本轮不能据此给出实物开球推荐。下列10,000架结果只描述当前引擎、当前生产顺序与当前摆球分布；增加抽样不能修复这一模型误差。</p><p>在上述条件下，<b>{verdict}</b>：候选相对基准差 <b>{100*p['meanDifference']:+.2f} 个百分点</b>，配对95%区间 <b>{100*lo:+.2f} 至 {100*hi:+.2f} 个百分点</b>。</p></div>
<h2>10,000架独立复验</h2><div class="card scroll"><table><tr><th>组</th><th>入射角θ</th><th>b/D</th><th>白球Z</th><th>架数</th><th>普通下球</th><th>白球落袋</th><th>黑八落袋</th><th>有效普通下球</th><th>有效率95%区间</th></tr>{table}</table><p><small>有效普通下球＝至少一颗非黑八目标球落袋、白球未落袋且完整停稳。黑八单列，不按实物/比赛规则混算。全部样本进入分母，异常终止不作为正常失败悄悄删除。</small></p></div><img src="holdout-comparison.png" alt="独立复验概率与配对差">
<h2>白球位置、入射角和撞击厚薄</h2><p>θ相对于球架−X轴；b/D是白球中心轨迹相对顶球中心的有符号横向偏移，β=asin(b/D)是入射方向与接触法线之间的角。b/D=0表示正碰。白球X固定0.70m，Z由θ和b/D共同决定；位置、角度、厚薄受几何约束，不能当成三个任意独立的量。</p><img src="controls-geometry.png" alt="冻结开球参数几何图">
<p>所有候选只在名义对称架上反算一次，参考碰撞前速度10m/s、角速度0；之后冻结控制，不对每个随机架重新瞄准或重新校准。负spinY约−0.024是为抵消接近过程中的滑动旋转而反算的打点。power约6.67m/s表示杆头速度，不能当作App百分比力度。</p>
<h2>从探索到复验</h2><p>先扫207种θ/b组合，每组1个名义架及4个随机架，共1,035局，只用来找候选。再对6组固定控制各跑1,000个独立生产架，共6,000局；筛选种子10000–10999。锁定基准与筛选最高的非基准候选后，使用100000–109999全新种子，各跑10,000局。筛选集中的排序不当作最终结论。</p><img src="screening-comparison.png" alt="六组一千架筛选">
<h2>已有摆球随机性是什么</h2><p>生产名义间距0.20mm，每颗球在半径0.09mm的圆盘内按面积均匀抽样；最近邻间距有0.02–0.38mm的解析界。各间距并非独立均匀随机，共用球的间距相关。同seed重复同一架；新seed生成新微扰架并洗球号。相同的一批架用于不同开球方式，配对差能减少球架难易造成的比较噪声。</p>
<p>额外生成10,000个生产架，测量每架30条最近邻间隙，并分别给每个球对设定10m/s的接近速度：平均每架 <b>{percent(gap['meanPerRackTriggeredFraction'])}</b> 的正间隙被判为立即接触，按独立球架聚类计算的95%区间为 {intervals(gap['rackClusterNormal95'])}。这不是实际开球中提前碰撞的次数统计，300,000条邻边也不能当作300,000个独立样本。</p><p>0.20mm正间隙的二球例子，CCD给出约20微秒后的接触，而立即碰撞谓词返回true。专项XCTest明确保留这一已知物理不变量的预期失败；测试运行完成不代表模型物理正确。</p><img src="gap-trigger-audit.png" alt="正间隙球对的真实接触时间与立即触发判据">
<h2>计算顺序的概率审计</h2><p>同输入重复结果一致。少量案例中反转内部目标球插入顺序会改变单局结局，所以在两组控制上补跑同架1,000次球序配对，共2,000局。这个干预不改变物理球位或开球控制，不混入主概率。</p><div class="card scroll"><table><tr><th>组</th><th>结局组合改变</th><th>生产顺序有效率</th><th>反序有效率</th><th>反序−原序</th><th>配对95%差区间</th></tr>{audits}</table></div>
<p>二球A/B交换675个案例的最大速度差约2.04×10⁻⁶m/s；生产引擎按插入顺序遍历，在近同时事件的优先级并列和逐对重叠分离中存在顺序敏感路径。单局变化不等同于总体概率偏差；审计也不能证明所有排序都等价。生产物理和默认摆球保持原状。</p>
<h2>统计口径与下一轮</h2><p>10,000个独立二项样本在最坏比例50%时，95%区间近似半宽0.98个百分点；1,000个约3.1个百分点。比例使用Wilson区间；两组差使用同架配对渐近区间。固定样本量，不因中间结果提前停止。这些区间只量化抽样误差，不覆盖引擎、真实摆球分布、台呢与袋口误差。</p>
<p>联合研究现已覆盖白球位置、方向/厚薄、杆头速度、高低杆、左右塞与第二排首碰，仍固定当前摆球随机参数、生产物理与球序；最新完成进度和各10,000架独立复验见联合报告。位置、方向和厚薄满足几何约束，所有名义首碰均经生产常量检查。引擎审计作为模型限制单列；物理修复另作任务，若版本改变须重新评估排名。本任务不搜索间距、扰动半径或更宽的摆球分布。当前平面模型不能评估跳球与飞球。</p>
<h2>复现与证据</h2><p>概率实验共28,000局：筛选6,000、独立复验20,000、球序审计2,000；另有探索1,035局、几何预飞与生产入口对拍、重复/镜像诊断。每批保留配置、逐局数据、完整日志、xcresult和执行清单。</p><p>生产源码哈希核对一致；临时测试注入已完整撤回。研究脚本保存在 <code>scripts/research/</code>；原始证据保存在 <code>build/break-potting-research-20261002/</code>，摘要与图保存在本目录。</p>
<p><a href="holdout.json">独立复验 JSON</a> · <a href="holdout.csv">复验表</a> · <a href="screening.csv">筛选表</a> · <a href="order-ensemble-audit.json">球序审计</a> · <a href="path-and-contact-statistics.json">进袋路径与实际碰撞状态</a> · <a href="final-evidence.json">最终证据清单</a></p></main></html>'''
    for filename in ("holdout-comparison.png","controls-geometry.png","screening-comparison.png","gap-trigger-audit.png"):
        encoded=base64.b64encode((REPORT/filename).read_bytes()).decode("ascii")
        document=document.replace(f'src="{filename}"',f'src="data:image/png;base64,{encoded}"')
    (REPORT/"report.html").write_text(document)
    print(json.dumps(state,ensure_ascii=False,indent=2))


if __name__=="__main__":main()
