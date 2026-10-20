#!/usr/bin/env python3
"""Prepare reproducible uniform middle-pocket samples and audit concurrency trials."""
import argparse
import collections
import hashlib
import json
import math
import random
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/accuracy-middle-benchmark-20261021"
INVENTORY = ROOT / "output/accuracy-grid-anchor-v2-20261021/inventory.json"
SEED = 2026102105000


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare():
    import grid_inventory_report as geometry
    import numpy as np
    data = json.loads(INVENTORY.read_text())
    total = sum(int(m).bit_count() for t in data["targets"] if t["pocket"] >= 4 for m in t["masks"])
    assert total == 2375112
    ranks = sorted(random.Random(SEED).sample(range(total), 5000))
    wanted = iter(ranks)
    rank = next(wanted)
    offset, samples = 0, []
    for ti, target in enumerate(data["targets"]):
        if target["pocket"] < 4:
            continue
        o, g, anchor = (geometry.point(target[k]) for k in ("object", "ghost", "aim"))
        base = (g-o)/np.linalg.norm(g-o)
        gap = geometry.rail_gap(o, data["geometry"])
        for j, mask in enumerate(target["masks"]):
            bits = [bit for bit in range(16) if int(mask) & (1 << bit)]
            while rank is not None and offset <= rank < offset+len(bits):
                bit = bits[rank-offset]
                beta, gc = j-85, (bit+3)/10
                a = math.radians(beta)
                direction = np.array([base[0]*math.cos(a)-base[1]*math.sin(a),
                                      base[0]*math.sin(a)+base[1]*math.cos(a)])
                cue = g+direction*gc
                co, op = float(np.linalg.norm(cue-o)), float(np.linalg.norm(anchor-o))
                ai = next(i for i, limit in enumerate([10,30,50,70,85]) if abs(beta) <= limit)
                ri = 2 if abs(gap) <= geometry.EPSILON else 1 if gap <= .1+geometry.EPSILON else 0
                cell = dict(angleIndex=ai,pocketType=1,cueIndex=int(geometry.band(co)),
                            objectIndex=int(geometry.band(op)),railIndex=ri)
                samples.append(dict(sampleRank=rank,targetIndex=ti,maskIndex=j,distanceBit=bit,
                    cellID=geometry.cell_id(cell),cell=cell,pocket=target["pocket"],signedAngle=beta,
                    cue=dict(x=float(cue[0]),z=float(cue[1])),target=target["object"],
                    ghost=target["ghost"],aim=target["aim"],gap=gap,source=target["source"]))
                assert abs(float(np.linalg.norm(cue-g))-gc) < 1e-9
                assert .3-1e-6 <= co <= 1.8+1e-6
                rank = next(wanted, None)
            offset += len(bits)
    assert offset == total and len(samples) == 5000
    assert [s["sampleRank"] for s in samples] == ranks
    random.Random(SEED+1).shuffle(samples)  # Same schedule for each worker count.
    OUT.mkdir(exist_ok=True)
    (OUT/"samples.json").write_text(json.dumps(dict(sourceFingerprint=data["sourceFingerprint"],
        seed=SEED,selection="Uniform without replacement over all middle-pocket mask placements",
        population=total,samples=samples),ensure_ascii=False))
    previous = json.loads((ROOT/"output/accuracy-center-five-20261021/source-manifest.json").read_text())
    files = {p:sha(ROOT/p) for p in previous["files"]}
    files["scripts/training-question-bank/middle_benchmark.py"] = sha(Path(__file__))
    manifest = dict(fingerprint=hashlib.sha256(json.dumps(files,sort_keys=True).encode()).hexdigest(),files=files)
    (OUT/"source-manifest.json").write_text(json.dumps(manifest,indent=2))
    (OUT/"request.json").write_text(json.dumps(dict(sourceFingerprint=manifest["fingerprint"],
        gallerySHA256=sha(OUT/"samples.json"),inventorySHA256=sha(INVENTORY)),indent=2))
    (OUT/"TrainingSpeedScreeningTests.swift").write_bytes((ROOT/"QiuJiTests/TrainingSpeedScreeningTests.swift").read_bytes())
    print(json.dumps(dict(population=total,count=len(samples),
        pockets=dict(collections.Counter(s["pocket"] for s in samples)),
        rails=dict(collections.Counter(s["cell"]["railIndex"] for s in samples)),
        cells=len({s["cellID"] for s in samples})),indent=2))


def audit():
    data = json.loads((OUT/"benchmark.json").read_text())
    manifest = json.loads((OUT/"source-manifest.json").read_text())
    assert data["sourceFingerprint"] == manifest["fingerprint"]
    for p,h in manifest["files"].items():
        assert sha(ROOT/p) == h,p
    assert sha(OUT/"samples.json") == data["gallerySHA256"]
    assert sha(INVENTORY) == data["inventorySHA256"]
    samples = json.loads((OUT/"samples.json").read_text())
    assert [p["workers"] for p in data["phases"]] == [4,6,8,12,18]
    baseline = None
    summaries = []
    for phase in data["phases"]:
        results = json.loads((OUT/f"results-{phase['workers']}.json").read_text())
        assert len(results) == 5000
        for i,r in enumerate(results):
            s = samples["samples"][i]
            assert r["sampleIndex"] == i and r["cellID"] == s["cellID"] and r["pocket"] == s["pocket"]
            assert 1 <= len(r["trials"]) <= 5
            assert bool(r.get("proof")) == any(t["targetPotted"] for t in r["trials"])
            lo,hi = .5,8
            for t in r["trials"]:
                assert abs(t["speed"]-(lo+hi)/2) < 1e-6
                if t["feedback"] == "short-increase": lo=t["speed"]
                elif t["feedback"] in ("mouth-miss-decrease","deflection-probe-lower"): hi=t["speed"]
            if proof := r.get("proof"):
                assert proof["spinX"] == proof["spinY"] == 0
                dx,dz = s["ghost"]["x"]-s["cue"]["x"],s["ghost"]["z"]-s["cue"]["z"]
                norm = math.hypot(dx,dz)
                assert abs(proof["direction"]["x"]-dx/norm)<1e-6 and abs(proof["direction"]["z"]-dz/norm)<1e-6
                assert any(e["kind"]=="pocket" and e.get("ball")=="object" and
                           e.get("pocketID")==f"pocket_{s['pocket']}" for e in proof["events"])
        durations = [r["elapsedSeconds"] for r in results]
        # Exact all-trial/proof comparison, including failure feedback and events.
        for r in results:
            r["elapsedSeconds"] = 0
            for t in r["trials"]: t["seconds"] = 0
        if baseline is None: baseline = results
        else: assert results == baseline, f"nondeterminism at {phase['workers']}"
        summaries.append(dict(**phase,rate=5000/phase["wallSeconds"],
            meanLayoutMs=statistics.mean(durations)*1000,
            medianLayoutMs=statistics.median(durations)*1000,
            fullMiddleHours=phase["wallSeconds"]*samples["population"]/5000/3600,
            incomplete=sum(r["trials"][-1]["feedback"]=="incomplete-stop" for r in results),
            scratchPasses=sum(bool(r.get("proof")) and r["trials"][-1]["cuePocketed"] for r in results)))
    fastest = min(summaries,key=lambda p:p["wallSeconds"])
    report = dict(population=samples["population"],samples=5000,phases=summaries,
                  fastestWorkers=fastest["workers"],estimatedMiddleHours=fastest["fullMiddleHours"])
    (OUT/"audit.json").write_text(json.dumps(report,ensure_ascii=False,indent=2))
    lines = ["# 5000个中袋球形：并行度实测","",
        "同一批5000个球形，从两只中袋的2,375,112个库存球形均匀无放回抽样；固定随机种子2026102105000，镜像保留。顺序打乱后五档复用完全相同的输入和次序。",
        "统一中杆、固定C→G、每题最多5次力度，目标进指定袋即停；母球落袋不否决。复用上一轮搜索函数，计时外先对拍旧30例。",
        "一个原生测试进程依次运行4、6、8、12、18路OperationQueue。优化Debug／iOS模拟器，预热及构建启动不计时，JSON写盘另计。每档各跑一次，顺序与后台负载可能影响接近的成绩。","",
        "| 并行路数 | 5000题耗时 | 球形/秒 | 单题平均耗时 | 通过 | 两只中袋全量估算 |",
        "|---:|---:|---:|---:|---:|---:|"]
    for p in summaries:
        lines.append(f"| {p['workers']} | {p['wallSeconds']:.2f}s | {p['rate']:.1f} | {p['meanLayoutMs']:.1f}ms | {p['passed']}/5000 | {p['fullMiddleHours']:.2f}小时 |")
    lines += ["",f"本轮最快：{fastest['workers']}路。估算是当前采样吞吐量线性外推，不包含全量额外存储、任务调度、长时间热负载及系统争用波动。",
        "五档逐题的所有力度、结果、反馈、解和事件均完全一致（计时字段除外），不是仅通过数量一致。",
        "全量估算仅针对两只中袋；角袋没有本轮抽样，不能用此值当作全桌可靠估计。未找到解不等于无解，模拟未完成单独标记。",
        "", "## 原始证据","",
        "`samples.json`保存库存targetIndex、maskIndex、distanceBit、全局采样序号；`results-N.json`保存各档逐题记录，`benchmark.json`记录墙钟／写盘时间／热状态。未存轨迹。"]
    (OUT/"并行试跑报告.md").write_text("\n".join(lines)+"\n")
    print(json.dumps(report,ensure_ascii=False,indent=2))


if __name__ == "__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("action",choices=["prepare","audit"])
    args=parser.parse_args()
    prepare() if args.action=="prepare" else audit()
