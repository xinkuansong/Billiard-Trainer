"""Review the verified pilot representatives and their robustness under the new score."""
import collections
import gzip
import hashlib
import json
import math
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"output"/Path(__file__).resolve().parent.name
sys.path.insert(0,str(ROOT/"research/defense-threshold-comparison-20261105"))
import geometric_table as table
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from matplotlib.patches import Circle

DATA = OUT/"parallel-limit-v1" if (OUT/"parallel-limit-v1/pilot/summary.json").exists() else OUT
ORIGINS=json.loads((DATA/"origins.json").read_text())
RAILS=["下左长","下右长","上左长","上右长","左短","右短"]
def sequence(numbers):
    return " → ".join(RAILS[n] for n in numbers) or "无"
def estimated(effect):
    return bool(effect.get("estimateReason") or (effect.get("pipeRoute") or {}).get("zeroWidthEstimate"))
def key(events, own):
    return [[event["index"] for event in events if event["kind"]=="cushion" and event["ball"]==ball]
            for ball in ("cueBall",f"_{own}")]
def exceeds_parallel_limit(events, own):
    sides = (0, 0, 1, 1, 2, 3)
    for rails in key(events, own):
        seq = [sides[r] for r in rails]
        if any(a == c and b == (a ^ 1) for a,b,c in zip(seq, seq[1:], seq[2:])):
            return True
    return False

def evidence(route, own):
    effects=[route["effect"]]+[p["effect"] for p in route["probes"]]
    nominal=key(route["events"],own)
    return dict(score=effects[0]["score"],lowest=min(e["score"] for e in effects),
                estimated=any(estimated(e) for e in effects),nominalEstimated=estimated(effects[0]),
                sameRails=sum(key(p["events"],own)==nominal for p in route["probes"]),
                rails=nominal)
def draw(ax, question, route):
    table.table(ax)
    own=question["ownBallNumber"]
    info=evidence(route,own)
    t=next(ev["time"] for ev in route["events"] if ev["kind"]=="ballBall")
    tracks=route["tracks"]
    cue=tracks["cueBall"]
    white="#ffffff"
    objectColor="#172020" if own==8 else "#ffcb22"
    def trace(frames,color,style):
        ax.plot([f[1] for f in frames],[f[2] for f in frames],color=color,linestyle=style,lw=1.5,zorder=6)
    before=[f for f in cue if f[0]<=t+1e-5]
    after=[f for f in cue if f[0]>=t-1e-5]
    assert before and after and math.dist(before[-1][1:],after[0][1:])<1e-4
    trace(before,white,"-")
    trace(after,white,"--")
    trace(tracks[f"_{own}"],objectColor,"--")
    table.ball(ax,question["cue"],0)
    for b in question["balls"]:
        pos,n=b["position"],b["number"]
        if n==1:
            ax.add_patch(Circle(pos,table.R,facecolor="#f5bd19",edgecolor="#153e32",lw=.7,zorder=8))
            ax.add_patch(Circle(pos,table.R*.57,facecolor="white",zorder=9))
            ax.text(*pos,"1",ha="center",va="center",fontsize=5.3,zorder=10)
        else:
            table.ball(ax,pos,n)
    for ball,color in [("cueBall",white),(f"_{own}",objectColor)]:
        pos=route["finalPositions"][ball]
        assert math.dist(pos,tracks[ball][-1][1:])<1e-5
        ax.add_patch(Circle(pos,table.R,fill=False,edgecolor=color,lw=1.8,zorder=13))
    marker=" · 含估算" if info["estimated"] else ""
    shot=route["shot"]
    ax.set_title(f'{question["id"]} / 线路 {route["id"]}   防守 {info["score"]:.1f} 分{marker}',loc="left",color="#153a32",fontsize=14)
    ax.text(.02,-.02,f'母球  {sequence(info["rails"][0])}     {own}号  {sequence(info["rails"][1])}',transform=ax.transAxes,va="top",fontsize=11,color="#234b42")
    ax.text(.02,-.14,f'切角 {shot["cutDegrees"]}°    杆速 {shot["speed"]:.2f}    打点 ({shot["spinX"]:+.1f}, {shot["spinY"]:+.1f})\n原杆与四次扰动最低 {info["lowest"]:.1f} 分    扰动库序一致 {info["sameRails"]}/4',transform=ax.transAxes,va="top",fontsize=10,color="#396159")
def sheet(q,routes):
    cols=2 if len(routes)>1 else 1
    rows=(len(routes)+cols-1)//cols
    fig,axs=plt.subplots(rows,cols,squeeze=False,figsize=(6.6*cols,4.55*rows+.75))
    fig.patch.set_facecolor("#f5f5ef")
    for ax,r in zip(axs.flat,routes):draw(ax,q,r)
    for ax in list(axs.flat)[len(routes):]:ax.axis("off")
    fig.suptitle(f'{q["id"]}  同一初始球形 · 我方 {q["ownBallNumber"]} 号 / 对方 {q["opponentBallNumber"]} 号',fontsize=16,color="#153a32")
    fig.subplots_adjust(top=1-.62/(4.55*rows+.75),bottom=.95/(4.55*rows+.75),left=.025,right=.975,wspace=.06,hspace=.64)
    return fig
def main():
    summary=json.loads((DATA/"pilot/summary.json").read_text())
    qs=json.loads((DATA/"inputs.json").read_text())
    assert summary["complete"] and len(qs)==len(summary["questions"])==24
    ledger=[];by_q={};counts=collections.Counter()
    for q in qs:
        store=DATA/"pilot/records"
        data=(store/(q["id"]+".json.gz")).read_bytes()
        cp=json.loads((store/(q["id"]+".checkpoint.json")).read_text())
        assert cp["sha256"]==hashlib.sha256(data).hexdigest()
        result=json.loads(gzip.decompress(data))["record"]["result"]
        routes=[]
        rejected=[]
        for route in result["routes"]:
            attempts=[route, *route["probes"]]
            violating=[i for i,attempt in enumerate(attempts)
                       if exceeds_parallel_limit(attempt["events"],q["ownBallNumber"])]
            if violating:
                rejected.append(dict(route=route["id"], attempts=violating))
            else:
                routes.append(route)
        counts["parallelRejected"]+=len(rejected)
        by_q[q["id"]]=routes
        details=[evidence(r,q["ownBallNumber"]) for r in routes]
        for d in details:
            counts["estimated" if d["estimated"] else "confirmed"]+=1
            counts["robust85"]+=d["lowest"]>=85
            counts["sameRails4"]+=d["sameRails"]==4
        ledger.append(dict(id=q["id"],kind=q["kind"],source=ORIGINS[q["id"]],kept=len(routes),rejected=rejected,routes=details,
                           parameters=result["counts"].get("parameters",0),physics=result["counts"].get("physics",0)))
    counts["multi"]=sum(v["kept"]>=2 for v in ledger)
    counts["single"]=sum(v["kept"]==1 for v in ledger)
    counts["none"]=sum(v["kept"]==0 for v in ledger)
    counts["routes"]=sum(v["kept"] for v in ledger)
    assert counts["routes"]+counts["parallelRejected"]==summary["counts"]["routes"]
    strict_counts=[sum(not d["estimated"] and d["sameRails"]==4 for d in case["routes"]) for case in ledger]
    counts["strictRoutes"]=sum(strict_counts)
    counts["strictMulti"]=sum(n>=2 for n in strict_counts)
    counts["strictSingle"]=sum(n==1 for n in strict_counts)
    if counts["routes"]:
        with PdfPages(OUT/"routes.pdf") as pdf:
            for q in qs:
                if by_q[q["id"]]:
                    fig=sheet(q,by_q[q["id"]]);pdf.savefig(fig);plt.close(fig)
        # Show two distinct rail sequences from one board whenever available.
        def rank(route, own):
            info=evidence(route,own)
            return (info["estimated"], 4-info["sameRails"], sum(map(len,info["rails"])), route["effort"])
        def board_rank(q):
            rs=sorted(by_q[q["id"]],key=lambda r:rank(r,q["ownBallNumber"]))[:2]
            scores=[rank(r,q["ownBallNumber"]) for r in rs]
            return (len(rs)<2, *map(sum,zip(*scores)), q["id"])
        q=min((q for q in qs if by_q[q["id"]]),key=board_rank)
        routes=sorted(by_q[q["id"]],key=lambda r:rank(r,q["ownBallNumber"]))
        fig=sheet(q,routes[:2]);fig.savefig(OUT/"example.png",dpi=155);plt.close(fig)
        counts["example"]=q["id"]
    lines=["# 防守线路样本 · 起杆难度 70 分及六袋封闭", "",
           "从39,717条起杆候选中取24个不同局面。每种球权分别从直进困难和六袋封闭各取4个，按固定哈希顺序选择。以选样比较不同球形，全库产量需另算。","",
           f'对原杆及四次扰动逐球检查平行库。左短→右短→左短、下长→上长→下长及反向序列均淘汰；同一条长库的两段合计。原始重放中剔除{counts["parallelRejected"]}条。', "",
           f'试验终态门槛为80分。{counts["multi"]}题有多个库序、{counts["single"]}题只有一个库序、{counts["none"]}题当前无保留线路。共{counts["routes"]}条。每条均完成整杆重放、正式v9评分及四次独立扰动复核。',"",
           f'原杆和四次扰动全部达到85分的有{counts["robust85"]}条。原杆或扰动中至少一次评分含估算的有{counts["estimated"]}条，五次全部直接按确认路线或封闭评分的有{counts["confirmed"]}条。有{counts["sameRails4"]}条在四次扰动中仍保持原杆的两球库序。',"",
           f'若同时要求五次评分均有确认依据、四次扰动的两球库序也与原杆一致，共{counts["strictRoutes"]}条，{counts["strictMulti"]}题有多个库序代表，{counts["strictSingle"]}题有单个代表。', "",
           "找法沿用15°、30°、45°、60°左右切，杆速粗扫后细调，按需扩展打点。记录两颗球各自主库序列，同组只选一个代表。继续沿用30 cm母球与对方球的最低终态距离、我方球可用窗口为正且不低于初始值等研究条件。","",
           "|样本|球权|起杆类别|保留库序|","|---|---|---|---:|"]
    for v in ledger:
        role={"two_black":"我方8／对方9","two_own":"我方1／对方8","three":"我方1／对方9，静止8"}[v["kind"]]
        opening=v["source"]["openingDifficulty"]
        label=f"难度 {opening:.1f}" if opening is not None else "六袋封闭"
        lines.append(f'|{v["id"]}|{role}|{label}|{v["kept"]}|')
    if counts["routes"]:lines+=["","[全部实测线路图册](routes.pdf) · [库序对照样例](example.png)","", "白实线为首碰前母球轨迹，白虚线为首碰后母球轨迹，黑／黄虚线为我方球轨迹。实心球为起点，空心圈为终点。"]
    (OUT/"README.md").write_text("\n".join(lines)+"\n")
    (OUT/"review.json").write_text(json.dumps(dict(counts=counts,questions=ledger),ensure_ascii=False,indent=2))
    print(dict(counts))
if __name__=="__main__": main()
