#!/usr/bin/env python3
"""Joint shot search under one frozen production rack distribution and physics version."""
from __future__ import annotations

import argparse
import base64
from collections import Counter
import hashlib
import html
import json
import math
import os
from pathlib import Path
import random
import statistics

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "build/break-potting-research-20261002"
OUT = BASE / "joint-v2"
REPORT = ROOT / "output/break-potting-research-20261002/joint-v2"
os.environ["BREAK_RESEARCH_OUTPUT"] = str(OUT)
import break_research as br
from analyze_break_research import summary, effective, write_csv
from sample_break_research import paired

BROAD_N, LOCAL_N, SCREEN_N, FINAL_N = 256, 256, 1000, 10000
SEEDS = dict(broad=300000, local=310000, screen=320000, holdout=400000)
CONTROL_KEYS = ("cueX", "cueZ", "aimTheta", "power", "spinX", "spinY", "theta", "fraction", "targetSlot")


def load(path):
    return json.loads(path.read_text())


def rows(batch):
    return load(OUT / f"{batch}-results.json")


def execute(batch, jobs, method="test_runConfiguredBatch"):
    compiled = load(OUT / "compiled-evidence.json")
    allowed = {compiled["testBinarySHA256"]: compiled["harnessSHA256"]}
    compatibility = OUT / "compatible-builds.json"
    if compatibility.exists():
        certificate = load(compatibility)
        if certificate["frozenProductionHashes"] != compiled["sourceHashes"]:
            raise RuntimeError("Scheduling certificate belongs to a different physics version")
        allowed.update(certificate["testBinaries"])
    path = OUT / f"{batch}-execution.json"
    if path.exists():
        m = load(path)
        expected = load(OUT / f"{batch}-config.json")["jobs"]
        if expected != jobs or not (m["exitCode"] == 0 and m["batchComplete"] and
                m["testExecuted"] and m["productionUnchanged"] and
                allowed.get(m["testBinarySHA256"]) == m["compiledHarnessSHA256"]):
            raise RuntimeError(f"Refusing incompatible or incomplete evidence: {batch}")
        return
    if br.run(batch, method, jobs) != 0:
        raise RuntimeError(f"Batch failed; original log preserved: {batch}")


def blueprint(identifier, **kw):
    values = dict(mode="design", rackKind="nominal", seed=0, spinX=0, targetSlot=0)
    values.update(kw)
    return br.job(identifier, **values)


def prepare():
    OUT.mkdir(parents=True, exist_ok=True)
    REPORT.mkdir(parents=True, exist_ok=True)
    plan = dict(version="joint-v2", simulationBudget=dict(maxTime=120,maxEvents=8000),
                budgetReason="Uniform extension before candidate selection: 30 seconds censored some high-side-spin outcomes. All controls rerun from original inputs; physics/rack unchanged.",
                rack=dict(gapM=0.00020, jitterRadiusM=0.00009,
                distribution="Unchanged production RackLayout.make; independent rack seeds, paired across shots"),
                bounds=dict(cueX=[0.64, 1.20], initialRayTheta=[-26, 26], nominalFraction=[-0.60, 0.60],
                            tipSpeed=[4, 10], spinDiskRadius=0.48, targetSlots=[0, 1, 2]),
                stages=dict(broad=dict(randomControls=64, n=BROAD_N, seedStart=SEEDS["broad"]),
                            local=dict(parents=4, controlsPerParent=8, n=LOCAL_N, seedStart=SEEDS["local"]),
                            screen=dict(candidates=8, plusBaseline=True, n=SCREEN_N, seedStart=SEEDS["screen"]),
                            holdout=dict(candidates=1, plusBaseline=True, n=FINAL_N, seedStart=SEEDS["holdout"])),
                selection="Broad top four diverse parents; eight local designs each. Broad top four and local top four advance to fresh paired screening; best nonbaseline is locked before holdout.",
                ranking="Effective ordinary pot proportion; lower scratch then higher ordinary pot count break ties. Unknown outcomes remain in denominator and have probability bounds.",
                primary="Settled, at least one non-eight object potted, cue not scratched; eight reported separately",
                limitations=["Finite bounded search, no global optimum claim", "Production planar model and insertion order fixed", "Known engine contact/order limitations retained", "No execution noise or per-rack recalibration"])
    path = OUT / "plan.json"
    if path.exists() and load(path) != plan:
        raise RuntimeError("Frozen study plan changed")
    br.write_json(path, plan)
    if (OUT / "broad-blueprints.json").exists():
        return
    designs = []
    rng = random.Random(2026100204)
    # A reproducible stratified six-dimensional pool per target; geometry rejection
    # is performed by Swift using production table/ball/rack constants.
    for slot in range(3):
        n = 1024
        columns = []
        for _ in range(6):
            values = [(i + rng.random()) / n for i in range(n)]
            rng.shuffle(values)
            columns.append(values)
        for i in range(n):
            q = [c[i] for c in columns]
            radius, phi = 0.48 * math.sqrt(q[4]), 2 * math.pi * q[5]
            designs.append(blueprint(f"J{slot}-{i:04}", cueX=.64+.56*q[0], theta=-26+52*q[1],
                fraction=-.6+1.2*q[2], power=4+6*q[3], spinX=radius*math.cos(phi),
                spinY=radius*math.sin(phi), targetSlot=slot))
    # Controlled anchors supplement the sparse joint pool; their exploratory
    # associations are not causal effects established by holdout.
    anchors = []
    for v in (4, 6, 8, 10): anchors.append(dict(power=v))
    for y in (-.45, -.25, 0, .25, .45): anchors.append(dict(spinY=y))
    for x in (-.4, -.2, .2, .4): anchors.append(dict(spinX=x, spinY=0))
    for x in (.64, 1.0, 1.2): anchors.append(dict(cueX=x))
    for t, f in ((-20,-.2),(-12,-.2),(-12,0),(12,0),(12,.2),(20,.2)):
        anchors.append(dict(theta=t, fraction=f))
    for i, a in enumerate(anchors):
        values = dict(cueX=.70, theta=0, fraction=0, power=6.667548656, spinY=-.0241663046)
        values.update(a)
        designs.append(blueprint(f"A{i:02}", **values))
    br.write_json(OUT / "broad-blueprints.json", dict(jobs=designs))
    print(f"Frozen plan; {len(designs)} nominal design requests", flush=True)


def export_designs(label, designs):
    execute(label, designs, "test_exportNominalSearchControls")
    exported = [r for r in rows(label) if r.get("kind") == "designControl"]
    return [dict(name=r["id"], **{k:r[k] for k in CONTROL_KEYS},
                 initialSpeed=r["initialSpeed"], initialTheta=r["initialTheta"]) for r in exported]


def controls():
    return load(OUT / "broad-controls.json")


def export():
    designs = load(OUT / "broad-blueprints.json")["jobs"]
    valid = export_designs("export-broad", designs)
    old = next(c for c in load(BASE / "fixed-controls.json")["controls"] if c["name"] == "C0")
    baseline = dict(name="B0", **{k:old[k] for k in CONTROL_KEYS if k in old}, spinX=0, targetSlot=0)
    result = [baseline] + [c for c in valid if c["name"].startswith("A")]
    rng = random.Random(2026100205)
    counts = {}
    for slot, n in ((0,48),(1,8),(2,8)):
        pool = [c for c in valid if c["name"].startswith(f"J{slot}-")]
        counts[slot] = len(pool)
        if len(pool) < n: raise RuntimeError(f"Too few legal controls for target {slot}: {len(pool)}")
        result.extend(rng.sample(pool, n))
    br.write_json(OUT / "broad-controls.json", result)
    br.write_json(OUT / "design-coverage.json", dict(requested=len(designs), legal=len(valid),
        legalPoolByTarget=counts, selected=len(result), nominalOnly=True,
        geometryRule="Legal cue center and earliest straight initial-velocity ray intersection at requested slot; actual contact measured later"))
    print(json.dumps(dict(selected=len(result), legalPoolByTarget=counts)), flush=True)


def make_jobs(c, stage, seed_list, trace=False):
    fields = {k:c[k] for k in CONTROL_KEYS}
    return [br.job(f"{stage}_{c['name']}_s{s}", mode="execute", seed=s,
                   trace=trace and i == 0, maxTime=120, **fields) for i, s in enumerate(seed_list)]


def preflight():
    chosen = [c for c in controls() if c["name"] in ("B0", "A03", "A04", "A08", "A09", "A12")]
    for slot in (1,2): chosen.append(next(c for c in controls() if c["targetSlot"] == slot))
    jobs = [make_jobs(c, "preflight", [290000+i], trace=True)[0] for i,c in enumerate(chosen)]
    execute("joint-parity", jobs, "test_jointSearchProductionParity")
    # Exact outcome compatibility against the previous zero-side-spin baseline.
    old_rows = load(BASE / "holdout-C0-01-results.json")
    baseline = controls()[0]
    execute("zero-spin-compatibility", make_jobs(baseline, "compat", [r["seed"] for r in old_rows[:16]]))
    new = [r for r in rows("zero-spin-compatibility") if "id" in r]
    keys = ("ordinaryPots", "scratch", "eight", "settled", "pocketedSlots", "finalBySlot")
    for a,b in zip(old_rows[:16],new):
        if any(a.get(k) != b.get(k) for k in keys):
            raise RuntimeError("Zero-spin baseline changed after research-entry extension")
    br.write_json(OUT / "preflight.json", dict(productionParity=len(jobs),
        zeroSideSpinExactCompatibility=16, compiled=load(OUT / "compiled-evidence.json")))
    print("Joint production parity and baseline compatibility passed", flush=True)


def rank(records):
    return sorted(records, key=lambda r:(-r["effectiveRate"],r["scratchRate"],-r["meanOrdinaryPots"],r["name"]))


def stage(stage_name, chosen, n):
    records = []
    for index, c in enumerate(chosen):
        samples = []
        for offset in range(0,n,1000):
            batch = f"{stage_name}-{c['name']}-{offset//1000+1:02}"
            execute(batch, make_jobs(c,stage_name,range(SEEDS[stage_name]+offset,
                SEEDS[stage_name]+min(offset+1000,n)), trace=stage_name in ("screen","holdout") and offset==0))
            samples.extend(r for r in rows(batch) if "id" in r)
        if len(samples) != n: raise RuntimeError("Sample count mismatch")
        records.append(dict(**c, **summary(samples)))
        br.write_json(OUT / f"{stage_name}-summary.json", dict(complete=index+1==len(chosen),
            plannedControls=len(chosen), nPerControl=n, groups=records))
        status=dict(stage=stage_name, controlsDone=index+1, plannedControls=len(chosen),
                    trialsCompleted=(index+1)*n, nPerControl=n, latest=c["name"])
        br.write_json(OUT / "progress.json", status)
        report(False)
        print(json.dumps(status), flush=True)
    return records


def broad():
    stage("broad", controls(), BROAD_N)


def diverse(records, n):
    chosen = []
    for r in rank(records):
        if r["name"] == "B0": continue
        if any(abs(r["theta"]-q["theta"])<2 and abs(r["fraction"]-q["fraction"])<.08
            and abs(r["power"]-q["power"])<.8 and math.hypot(r["spinX"]-q["spinX"],r["spinY"]-q["spinY"])<.12
            and abs(r["cueX"]-q["cueX"])<.10 for q in chosen): continue
        chosen.append(r)
        if len(chosen)==n: break
    if len(chosen)!=n: raise RuntimeError("Not enough distinct candidates")
    return chosen


def local():
    path = OUT / "local-controls.json"
    if path.exists():
        chosen = load(path)
    else:
        parents = diverse(load(OUT / "broad-summary.json")["groups"], 4)
        rng = random.Random(2026100206)
        designs=[]
        for i,p in enumerate(parents):
            for j in range(64):
                sx=p["spinX"]+rng.uniform(-.10,.10)
                sy=p["spinY"]+rng.uniform(-.10,.10)
                if math.hypot(sx,sy)>.48: continue
                values=dict(cueX=p["cueX"]+rng.uniform(-.07,.07), theta=p["theta"]+rng.uniform(-2,2),
                    fraction=p["fraction"]+rng.uniform(-.08,.08), power=p["power"]+rng.uniform(-.7,.7),
                    spinX=sx,spinY=sy,targetSlot=p["targetSlot"])
                if not (.64<=values["cueX"]<=1.20 and abs(values["theta"])<=26
                    and abs(values["fraction"])<=.6 and 4<=values["power"]<=10): continue
                designs.append(blueprint(f"L{i}-{j:02}", **values))
        valid=export_designs("export-local", designs)
        chosen=[]
        for i in range(4):
            group=[c for c in valid if c["name"].startswith(f"L{i}-")]
            if len(group)<8: raise RuntimeError("Local geometry has fewer than eight admissible controls")
            chosen.extend(group[:8])
        br.write_json(path,chosen)
        br.write_json(OUT / "local-parents.json", parents)
    stage("local",chosen,LOCAL_N)


def screen():
    path = OUT / "screen-controls.json"
    if path.exists(): chosen=load(path)
    else:
        chosen = [controls()[0]]
        for name in ("broad","local"):
            chosen.extend(diverse(load(OUT/f"{name}-summary.json")["groups"],4))
        chosen=[{k:r[k] for k in ("name",)+CONTROL_KEYS} for r in chosen]
        br.write_json(path,chosen)
    results=stage("screen",chosen,SCREEN_N)
    best=next(r for r in rank(results) if r["name"]!="B0")
    unresolved=[r for r in results if r["unknown"]]
    if unresolved:
        # Preserve every unknown outcome. Lock only when every possible binary
        # completion gives the same empirical winner, without inspecting holdout.
        if best["unknown"] or any(r["unknownBounds"][1]>=best["unknownBounds"][0]
                for r in results if r["name"] not in ("B0",best["name"])):
            raise RuntimeError("Unknown outcome bounds can change screening winner; diagnose before locking")
        diagnostic=load(OUT / "screen-failure-diagnostic.json")
        if not diagnostic["exactReplay"] or not diagnostic["heldoutDataNotStarted"]:
            raise RuntimeError("Screening failure diagnosis is incomplete")
        amendment=dict(reason="One reproducible engine penetration guard failure; not a time cutoff. All unknowns retained. Candidate rank is invariant to either binary completion.",
            beforeHoldout=True, winner=best["name"],winnerBounds=best["unknownBounds"],
            rivals=[dict(name=r["name"],unknown=r["unknown"],bounds=r["unknownBounds"]) for r in results if r["name"]!=best["name"]],
            rule="Lock only a resolved empirical winner whose lower bound exceeds every nonbaseline rival upper bound; otherwise stop.")
        path=OUT / "selection-amendment.json"
        if path.exists() and load(path)!=amendment: raise RuntimeError("Selection amendment changed")
        if not path.exists(): br.write_json(path,amendment)
    selected=[chosen[0],next(c for c in chosen if c["name"]==best["name"])]
    locked=dict(names=[c["name"] for c in selected],
        holdoutSeedRange=[400000,409999], finalN=FINAL_N,
        rule="Locked after fresh screening and before any holdout data; one comparison",
        unknownRankInvariant=bool(unresolved))
    for name,value in (("holdout-controls.json",selected),("holdout-lock.json",locked)):
        path=OUT/name
        if path.exists():
            if load(path)!=value: raise RuntimeError(f"Frozen candidate lock changed: {name}")
        else: br.write_json(path,value)
    print(f"Locked holdout candidate {best['name']}, screening rate={best['effectiveRate']:.4f}",flush=True)


def holdout():
    chosen=load(OUT / "holdout-controls.json")
    stage("holdout",chosen,FINAL_N)
    samples=[]
    for c in chosen:
        data=[]
        for i in range(1,11): data.extend(r for r in rows(f"holdout-{c['name']}-{i:02}") if "id" in r)
        samples.append(data)
    comparison=paired(*samples)
    if comparison.get("unknown"):
        raise RuntimeError("Holdout has unresolved outcomes; retain all samples and diagnose before final inference")
    details=[]
    for c,data in zip(chosen,samples):
        contacts=[r["contact"] for r in data if r.get("contact")]
        details.append(dict(name=c["name"], firstSlots=dict(Counter(r["firstSlot"] for r in contacts)),
            meanContactTheta=statistics.mean(r["theta"] for r in contacts),
            meanContactFraction=statistics.mean(r["fraction"] for r in contacts),
            meanContactSpeed=statistics.mean(r["speed"] for r in contacts),
            meanContactOmega=[statistics.mean(r["omega"][i] for r in contacts) for i in range(3)],
            noContact=sum(not r.get("contact") for r in data),
            effectiveExcludingEight=sum(effective(r) and not r["eight"] for r in data)/len(data)))
    result=dict(complete=True, comparison=comparison, contactDetails=details,
                groups=load(OUT / "holdout-summary.json")["groups"], modelOnly=True)
    br.write_json(OUT / "final.json",result)
    br.write_json(REPORT / "final.json",result)
    report(True)
    print(json.dumps(result),flush=True)


def report(with_plots=False):
    REPORT.mkdir(parents=True,exist_ok=True)
    plan=load(OUT/"plan.json")
    sections=[]
    total=0
    for phase in ("broad","local","screen","holdout"):
        path=OUT/f"{phase}-summary.json"
        if not path.exists(): continue
        data=load(path); group=data["groups"]; total+=sum(r["n"] for r in group)
        write_csv(REPORT/f"{phase}.csv",group)
        top=rank(group)[:12]
        table="".join(f"<tr><td>{html.escape(r['name'])}</td><td>{r['targetSlot']}</td>"
            f"<td>{r['cueX']:.3f}, {r['cueZ']:+.3f}</td><td>{r['theta']:+.2f}°</td>"
            f"<td>{r['fraction']:+.3f}</td><td>{r['aimTheta']:+.2f}°</td><td>{r['power']:.3f}</td>"
            f"<td>{r['spinX']:+.3f}, {r['spinY']:+.3f}</td><td>{r['n']}</td>"
            f"<td>{100*r['effectiveRate']:.2f}%</td><td>{100*r['scratchRate']:.2f}%</td>"
            f"<td>{100*r['eightRate']:.2f}%</td><td>{r['unknown']}</td></tr>" for r in top)
        label=dict(broad="广泛联合搜索",local="候选邻域细化",screen="新种子筛选",holdout="10,000架独立复验")[phase]
        sections.append(f"<h2>{label} · {len(group)}/{data['plannedControls']}组完成</h2>"
            f"<p>每组{data['nPerControl']:,}架。{'探索排序，仅用于选择后续候选。' if phase!='holdout' else '最终锁定比较。'}</p>"
            f"<div class='scroll'><table><tr><th>组</th><th>名义目标slot</th><th>白球X,Z (m)</th><th>初始射线θ</th>"
            f"<th>名义b/D</th><th>杆瞄准角</th><th>杆速m/s</th><th>左右/高低打点</th><th>N</th><th>有效率</th>"
            f"<th>白球落袋</th><th>黑八</th><th>未知</th></tr>{table}</table></div><p><a href='{phase}.csv'>完整参数与统计CSV</a></p>")
    completed_trials=0
    batches_by_stage={name:0 for name in ("broad","local","screen","holdout")}
    for phase,n in (("broad",BROAD_N),("local",LOCAL_N),("screen",SCREEN_N),("holdout",FINAL_N)):
        control_file=OUT/f"{phase}-controls.json"
        if not control_file.exists(): continue
        # Count only planned parameter-evaluation batches. Diagnostic replays
        # can share a stage prefix and must not inflate the study sample count.
        for c in load(control_file):
            for offset in range(0,n,1000):
                path=OUT/f"{phase}-{c['name']}-{offset//1000+1:02}-execution.json"
                if not path.exists(): continue
                manifest=load(path)
                if manifest["exitCode"]==0 and manifest["batchComplete"] and manifest["testExecuted"] and manifest["productionUnchanged"]:
                    completed_trials+=manifest["rows"]
                    batches_by_stage[phase]+=1
    final=load(OUT/"final.json") if (OUT/"final.json").exists() else None
    scratch_note=("<p><a href='scratch-20261003/report.html'>白球掉袋专项分析：概率、袋口分布与代表轨迹（2026-10-03）</a></p>"
        if (REPORT/'scratch-20261003/report.html').exists() else "")
    amendment=load(OUT/"selection-amendment.json") if (OUT/"selection-amendment.json").exists() else None
    selection_note=("<p>筛选保留1局未知：L3-09触发库边穿透保护，原输入重复运行得到相同失败。"
        "该组有效率上下界51.6%–51.7%，均低于最终入选组的筛选估计57.8%。"
        "在使用保留集前补充边界锁定规则：经验赢家必须完整停稳，且下界严格超过所有其他非基准候选上界。"
        "未知局不剔除，不按999局重新归一化；无论其结局如何补全，经验排名不变。"
        "此判断不证明筛选候选之间存在统计显著差异。含未知组的Wilson列仅针对已知成功数/全部请求数，不能单独解释为完整概率区间。</p>" if amendment else "")
    message=f"已完成 {completed_trials:,} 局参数评估。" if not final else f"已完成预先规定的联合搜索、邻域细化、筛选与独立复验，共{completed_trials:,}局。"
    interpretation=""
    if final:
        p=final["comparison"];lo,hi=p["pairedNormal95"]
        verdict="候选在当前模型内有效率更高" if lo>0 else "候选在当前模型内有效率更低" if hi<0 else "尚未证实候选与基准有明确差异"
        message+=f" {verdict}：配对差{100*p['meanDifference']:+.2f}个百分点，95%区间[{100*lo:+.2f}, {100*hi:+.2f}]。"
        winner=final['groups'][1]
        actual=final['contactDetails'][1]
        interpretation=(f"<h2>锁定候选的输入与实际首碰</h2><div class='card'><p>候选{html.escape(winner['name'])}："
            f"白球球心X={winner['cueX']:.4f}m，Z={winner['cueZ']:+.4f}m；距底库线{100*(1.27-winner['cueX']):.2f}cm，"
            f"沿开球线后的纵向距离{100*(winner['cueX']-.635):.2f}cm。杆瞄准角{winner['aimTheta']:+.3f}°，"
            f"白球到顶球球心的方位角{math.degrees(math.atan2(-winner['cueZ'],winner['cueX']+.635)):+.3f}°。"
            f"挤偏补偿后初始射线角{winner['theta']:+.3f}°，名义b/D={winner['fraction']:+.4f}；"
            f"对应速度射线与接触球心连线的名义切角β={math.degrees(math.asin(winner['fraction'])):+.3f}°。"
            f"杆头速度{winner['power']:.4f}m/s，左右打点{winner['spinX']:+.4f}R、高低打点{winner['spinY']:+.4f}R。</p>"
            f"<p>10,000架实测平均首碰入射角{actual['meanContactTheta']:+.3f}°、b/D={actual['meanContactFraction']:+.4f}、"
            f"白球速度{actual['meanContactSpeed']:.3f}m/s；首碰slot计数{html.escape(str(actual['firstSlots']))}，"
            f"未发生球球碰撞{actual['noContact']}局。实际接触角速度向量{html.escape(str([round(v,3) for v in actual['meanContactOmega']]))}rad/s。</p>"
            f"<p>同时排除黑八落袋时，有效下球率{100*actual['effectiveExcludingEight']:.2f}%。"
            "本轮参数比较不能单独证明某个旋转或位置是提升原因；因果分解需要保持其他参数相同的独立对照。"
            "θ描述进入球架的方向；β描述相对首碰球的厚薄，两者不是同一个角。"
            "候选附近的256架细化只用于选择参数，尚未证明对实际出杆误差宽容。</p></div>")
    plots=""
    if with_plots and final:
        make_plots(final)
        plots="<img src='holdout.png' alt='独立保留集概率比较'><img src='search.png' alt='搜索参数与探索结果'><img src='geometry.png' alt='最终开球参数几何'>"
    elif (REPORT/"holdout.png").exists():
        plots="<img src='holdout.png'><img src='search.png'><img src='geometry.png'>"
    document=f"""<!doctype html><html lang='zh-CN'><meta charset='utf-8'><title>中八开球联合搜索</title>
    <style>body{{font-family:-apple-system,'PingFang SC',sans-serif;background:#f6f8fb;color:#203047;line-height:1.7}}main{{max-width:1200px;margin:auto;padding:28px}}.card{{padding:22px;background:white;border-radius:12px}}table{{border-collapse:collapse;font-size:12px;width:100%}}td,th{{padding:7px;border-bottom:1px solid #ddd;text-align:left;white-space:nowrap}}.scroll{{overflow-x:auto}}img{{max-width:100%}}a{{color:#126775}}</style><main>
    <h1>中八开球：固定摆球模型下的联合参数搜索</h1><div class='card'><b>{message}</b>
    {scratch_note}
    <p>摆球固定：名义间距0.20mm、随机扰动半径0.09mm及生产分布。物理版本和内部球序固定。每组开球参数固定，跨参数配对复用同一批随机球架；各阶段种子互不重叠。</p>
    <p>统一模拟预算120秒/8,000事件。原30秒探索中，部分较强侧旋方案的自旋可能未结束，存在结局截断；在候选选择前改用统一120秒，从原始输入重跑全部方案。<a href='../joint-v1/report.html'>原30秒探索与诊断</a>保留，未与本轮概率混用。</p>
    {selection_note}
    <p>搜索：白球纵向位置、初始速度射线θ、名义撞击偏移b/D、杆头速度、左右塞、高低杆；横向位置由几何约束导出。名义目标覆盖顶球及第二排两侧球。θ是挤偏补偿后的初始速度方向，实际首碰角度/厚薄/对象另外测量。侧旋与摩擦可使实际路径偏离名义直线，未对随机球架重新瞄准。</p>
    <p>广泛搜索每组256架、邻域细化每组256架，均为探索（最坏95%半宽约6.1个百分点）；新种子筛选每组1,000架，最终基准和锁定候选各10,000架（最坏约±0.98个百分点）。候选仅在筛选阶段选择，最终集只做一次预先锁定比较。</p>
    <p>有效普通下球＝完整停稳、至少一颗非黑八目标球落袋且白球未落袋。黑八单列。有限范围搜索不证明全域最优；抽样区间不覆盖已知引擎接触/球序偏差，结论仅适用于当前模型。<a href='../report.html'>首轮证据与引擎审计</a></p>
    <p>本研究按几何与当前模型区分首碰对象。可查的<a href='https://cbsa.cssf.net.cn/annoucement/2017/0120/142126.html'>中国台球协会2017版总则 §5.1</a>允许开球首先碰触任一目标球；具体赛事规则仍须另核，不把本研究当作所有赛事的规则验收。</p></div>
    {interpretation}{plots}{''.join(sections)}<h2>范围与证据</h2><p>白球X：0.64–1.20m；初始射线θ：±26°；名义b/D：±0.60；杆头速度4–10m/s；打点圆盘半径0.48R（生产极限0.5R）。所有候选使用生产常量验证起点与名义首碰几何，左右塞用生产击杆模型补偿挤偏。没有研究仰杆、跳球、出杆误差、跨桌差异或更宽摆球分布。</p>
    <p>完成批次：广泛{batches_by_stage['broad']}，邻域{batches_by_stage['local']}，筛选{batches_by_stage['screen']}，独立复验{batches_by_stage['holdout']}/20。参数表仅展示已完成整组的统计，正在执行的复验批次不用于调整候选或提前停止。</p>
    <p>原始配置、日志、xcresult、逐局结果及源码/二进制指纹：build/break-potting-research-20261002/joint-v2/。正式物理与摆球源码未修改。最多3个独立球局同时计算，44组参数三次复测的状态与事件路径逐字一致；每局耗时受CPU争用影响。<a href='plan.json'>预先规定的方案</a> · <a href='final.json'>独立复验结果（完成后）</a> · <a href='final-integrity.json'>完整性验收</a> · <a href='holdout-lock.json'>候选锁定</a> · <a href='selection-amendment.json'>边界选择规则</a> · <a href='screen-failure-diagnostic.json'>未知局重放诊断</a></p></main></html>"""
    for name in ('holdout.png','search.png','geometry.png'):
        path=REPORT/name
        if path.exists():
            encoded=base64.b64encode(path.read_bytes()).decode('ascii')
            document=document.replace(f"src='{name}'",f"src='data:image/png;base64,{encoded}'")
    (REPORT/"report.html").write_text(document)
    br.write_json(REPORT/"plan.json",plan)
    for name in ('selection-amendment.json','screen-failure-diagnostic.json','holdout-lock.json','final-integrity.json'):
        path=OUT/name
        if path.exists(): br.write_json(REPORT/name,load(path))


def make_plots(final):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.patches import Circle, Rectangle
    fig,axes=plt.subplots(1,2,figsize=(12,4),constrained_layout=True)
    for i,r in enumerate(final["groups"]):
        lo,hi=r["wilson95"]
        axes[0].errorbar(i,100*r["effectiveRate"],yerr=[[100*(r["effectiveRate"]-lo)],[100*(hi-r["effectiveRate"])]],fmt='o',capsize=6)
    axes[0].set_xticks(range(2),[r["name"] for r in final["groups"]]);axes[0].set_ylabel('Effective ordinary pot (%)')
    axes[0].set_title('Independent holdout: 10,000 racks each (Wilson 95%)')
    p=final["comparison"];lo,hi=p["pairedNormal95"];d=100*p["meanDifference"]
    axes[1].errorbar(d,0,xerr=[[d-100*lo],[100*hi-d]],fmt='o',capsize=6)
    axes[1].axvline(0,color='gray',ls='--');axes[1].set_yticks([]);axes[1].set_xlabel('Candidate minus baseline (percentage points)')
    axes[1].set_title('Paired difference, 95% interval')
    for ax in axes: ax.grid(alpha=.2)
    fig.savefig(REPORT/'holdout.png',dpi=180);fig.savefig(REPORT/'holdout.svg');plt.close(fig)
    records=load(OUT/'broad-summary.json')["groups"]+load(OUT/'local-summary.json')["groups"]
    fig,axes=plt.subplots(1,3,figsize=(15,4),constrained_layout=True)
    for ax,(x,y,xlabel,ylabel) in zip(axes,[("theta","fraction","Initial ray theta (deg)","Nominal b/D"),
        ("power","cueX","Tip speed (m/s)","Cue X (m)"),("spinX","spinY","Side-spin contact offset/R","Vertical contact offset/R")]):
        sc=ax.scatter([r[x] for r in records],[r[y] for r in records],c=[r['effectiveRate'] for r in records],cmap='viridis',vmin=0,vmax=1,s=25)
        ax.set_xlabel(xlabel);ax.set_ylabel(ylabel);ax.grid(alpha=.2)
    axes[2].add_patch(Circle((0,0),.5,fill=False,color='gray',ls='--'))
    axes[2].set_aspect('equal')
    fig.colorbar(sc,ax=axes,label='Exploratory fraction (256 racks/control)')
    fig.savefig(REPORT/'search.png',dpi=180);fig.savefig(REPORT/'search.svg');plt.close(fig)
    # Geometry is illustrative from production constants, not an alternative physics model.
    length,width,radius=2.540,1.270,.028575
    fig,axes=plt.subplots(2,2,figsize=(13,7),constrained_layout=True)
    for ax,c in zip(axes[0],final['groups']):
        ax.add_patch(Rectangle((-length/2,-width/2),length,width,fill=False,color='#24736b'))
        step=(2*radius+.00020)*math.sqrt(3)/2
        centers=[]
        for row in range(5):
            for col in range(row+1):
                point=(-length/4-row*step,(row/2-col)*(2*radius+.00020));centers.append(point)
                ax.add_patch(Circle(point,radius,facecolor='#dd9c30',alpha=.8))
        ax.add_patch(Circle((c['cueX'],c['cueZ']),radius,facecolor='white',edgecolor='#25364b'))
        target=centers[c['targetSlot']]
        t=math.radians(c['theta']);b=math.asin(c['fraction'])
        ux,uz=-math.cos(t),math.sin(t);px,pz=math.sin(t),math.cos(t)
        k=(target[0]-2*radius*(ux*math.cos(b)+px*math.sin(b)),target[1]-2*radius*(uz*math.cos(b)+pz*math.sin(b)))
        ax.plot([c['cueX'],k[0]],[c['cueZ'],k[1]],'--',color='#237ea8',label='Nominal initial-velocity ray')
        ax.set_aspect('equal');ax.set_xlim(-1.35,1.35);ax.set_ylim(-.72,.72)
        ax.set_title(f"{c['name']}: ray {c['theta']:+.2f} deg, b/D {c['fraction']:+.3f}")
        ax.set_xlabel('SceneKit X (m)');ax.set_ylabel('SceneKit Z (m)');ax.legend(fontsize=8)
    for ax,c in zip(axes[1],final['groups']):
        t=math.radians(c['theta']);beta=math.asin(c['fraction'])
        ux,uz=-math.cos(t),math.sin(t);px,pz=math.sin(t),math.cos(t)
        nx,nz=ux*math.cos(beta)+px*math.sin(beta),uz*math.cos(beta)+pz*math.sin(beta)
        k=(-2*radius*nx,-2*radius*nz)
        foot=(-2*radius*px*c['fraction'],-2*radius*pz*c['fraction'])
        ax.add_patch(Circle((0,0),radius,facecolor='#dd9c30',alpha=.8))
        ax.add_patch(Circle(k,radius,facecolor='white',edgecolor='#25364b'))
        ax.plot([k[0]-.07*ux,k[0]+.035*ux],[k[1]-.07*uz,k[1]+.035*uz],
            '--',color='#237ea8',label='Initial-velocity ray')
        ax.plot([k[0],0],[k[1],0],color='#bd4440',label='Contact normal (center line)')
        ax.plot([0,foot[0]],[0,foot[1]],color='#1d8c63',linewidth=3,label='Perpendicular offset b')
        ax.set_xlim(-.065,.14);ax.set_ylim(-.075,.075);ax.set_aspect('equal');ax.grid(alpha=.2)
        ax.set_xticks([-.05,0,.05,.10])
        ax.set_title(f"Nominal contact zoom: beta={math.degrees(beta):+.3f} deg, |b|={2000*radius*abs(c['fraction']):.3f} mm")
        ax.set_xlabel('X relative to intended target (m)');ax.set_ylabel('Z relative to intended target (m)')
        ax.legend(fontsize=8,loc='upper right')
    fig.savefig(REPORT/'geometry.png',dpi=180);fig.savefig(REPORT/'geometry.svg');plt.close(fig)


def audit():
    final=load(OUT/'final.json')
    certificate=load(OUT/'compatible-builds.json')
    if br.hashes()!=certificate['frozenProductionHashes']:
        raise RuntimeError('Production physics/rack snapshot changed')
    if not load(OUT/'restoration.json')['testSourceIdentical']:
        raise RuntimeError('Temporary harness restoration failed')
    if br.BEGIN in br.TARGET.read_text():
        raise RuntimeError('Research harness remains in registered test source')
    phases={'broad':(controls(),BROAD_N),'local':(load(OUT/'local-controls.json'),LOCAL_N),
        'screen':(load(OUT/'screen-controls.json'),SCREEN_N),'holdout':(load(OUT/'holdout-controls.json'),FINAL_N)}
    total=0; batches=0; independent=set(); seed_sets={}; unknown=0
    for phase,(chosen,n) in phases.items():
        expected_seeds=set(range(SEEDS[phase],SEEDS[phase]+n))
        if independent & expected_seeds: raise RuntimeError('Stage seed leakage')
        independent|=expected_seeds;seed_sets[phase]=[min(expected_seeds),max(expected_seeds)]
        saved=load(OUT/f'{phase}-summary.json')
        if not saved['complete'] or len(saved['groups'])!=len(chosen): raise RuntimeError('Incomplete phase summary')
        for c in chosen:
            seen=[];samples=[]
            for offset in range(0,n,1000):
                batch=f"{phase}-{c['name']}-{offset//1000+1:02}"
                m=load(OUT/f'{batch}-execution.json')
                expected=make_jobs(c,phase,range(SEEDS[phase]+offset,SEEDS[phase]+min(offset+1000,n)),
                    trace=phase in ('screen','holdout') and offset==0)
                if load(OUT/f'{batch}-config.json')['jobs']!=expected: raise RuntimeError(f'Controls or seeds changed: {batch}')
                if not (m['exitCode']==0 and m['batchComplete'] and m['testExecuted'] and m['productionUnchanged']
                    and m['rows']==len(expected) and certificate['testBinaries'].get(m['testBinarySHA256'])==m['compiledHarnessSHA256']):
                    raise RuntimeError(f'Invalid execution evidence: {batch}')
                data=[r for r in rows(batch) if 'id' in r]
                if len(data)!=len(expected): raise RuntimeError(f'Missing rows: {batch}')
                for job,r in zip(expected,data):
                    if job['id']!=r['id'] or job['seed']!=r['seed'] or r['mode']!='execute' or r['rackKind']!='production':
                        raise RuntimeError(f'Row identity mismatch: {batch}')
                    if 'inputError' not in r:
                        for key in ('power','spinX','spinY'):
                            if abs(job[key]-r[key])>1e-5: raise RuntimeError(f'Frozen strike changed: {batch}')
                        if max(abs(job['cueX']-r['cuePosition'][0]),abs(job['cueZ']-r['cuePosition'][2]))>1e-6:
                            raise RuntimeError(f'Frozen cue position changed: {batch}')
                seen.extend(r['seed'] for r in data);samples.extend(data);total+=len(data);batches+=1
            if len(seen)!=n or set(seen)!=expected_seeds: raise RuntimeError(f'Wrong independent seeds: {phase}/{c["name"]}')
            actual=summary(samples);unknown+=actual['unknown']
            recorded=next(r for r in saved['groups'] if r['name']==c['name'])
            for key in ('n','successes','unknown','effectiveRate','scratchRate','eightRate','wilson95'):
                if actual[key]!=recorded[key]: raise RuntimeError(f'Statistical summary mismatch: {phase}/{c["name"]}/{key}')
    lock=load(OUT/'holdout-lock.json')
    if lock['names']!=[c['name'] for c in phases['holdout'][0]] or not final['complete']:
        raise RuntimeError('Candidate lock changed')
    if (OUT/'holdout-lock.json').stat().st_mtime>min(p.stat().st_mtime for p in OUT.glob('holdout-*-config.json')):
        raise RuntimeError('Candidate was not locked before holdout execution')
    if lock.get('unknownRankInvariant'):
        amendment=load(OUT/'selection-amendment.json')
        winner=next(r for r in load(OUT/'screen-summary.json')['groups'] if r['name']==amendment['winner'])
        if winner['unknown'] or any(r['bounds'][1]>=winner['unknownBounds'][0]
                for r in amendment['rivals'] if r['name']!='B0'):
            raise RuntimeError('Unknown screening outcome can change winner')
        if (OUT/'selection-amendment.json').stat().st_mtime>(OUT/'holdout-lock.json').stat().st_mtime:
            raise RuntimeError('Selection amendment was not saved before locking')
    result=dict(complete=True,totalTrials=total,fullBatches=batches,independentRackSeeds=len(independent),
        stageSeedRanges=seed_sets,allInputsAndSampleCountsVerified=True,unknownOutcomes=unknown,
        productionSnapshotUnchanged=True,testInjectionRemoved=True,candidateLockedBeforeHoldout=True,
        schedulingCompatibilityVerified=True)
    br.write_json(OUT/'final-integrity.json',result);br.write_json(REPORT/'final-integrity.json',result)
    print(json.dumps(result),flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase',choices=['prepare','export','preflight','broad','local','screen','holdout','report','audit','all'])
    phase=parser.parse_args().phase
    if phase=='all':
        for fn in (prepare,export,preflight,broad,local,screen,holdout,audit): fn()
    else: globals()[phase]()


if __name__=='__main__': main()
