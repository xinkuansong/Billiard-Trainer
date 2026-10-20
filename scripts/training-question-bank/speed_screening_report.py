#!/usr/bin/env python3
"""Audit fixed-direction speed-only experiment and report measured timings."""
import hashlib
import json
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DIRECTORY = ROOT/"output/accuracy-speed-screening-20261021"
NAMES = {
    "single-branch-increase-on-miss": "单侧二分（未进则增力）",
    "two-sided-midpoint-subdivision": "双侧区间二分细分",
    "reference-uniform-0.1": "0.1 m/s等距采样对照",
}


def timing(values):
    values = sorted(values)
    assert values and min(values) >= 0
    return dict(meanMs=statistics.mean(values)*1000, medianMs=statistics.median(values)*1000,
                p95Ms=values[min(len(values)-1, int((len(values)-1)*.95))]*1000, maxMs=max(values)*1000)


def key(result):
    return result["sampleIndex"], result["tip"]


def main():
    data = json.loads((DIRECTORY/"results.json").read_text())
    manifest = json.loads((DIRECTORY/"source-manifest.json").read_text())
    assert data["sourceFingerprint"] == manifest["fingerprint"]
    for file, digest in manifest["files"].items():
        assert hashlib.sha256((ROOT/file).read_bytes()).hexdigest() == digest, file
    inventory_dir = ROOT/"output/accuracy-grid-anchor-v2-20261021"
    for name, field in [("inventory.json", "inventorySHA256"), ("render-samples.json", "gallerySHA256")]:
        assert hashlib.sha256((inventory_dir/name).read_bytes()).hexdigest() == data[field]
    gallery = json.loads((inventory_dir/"render-samples.json").read_text())
    assert data["inventorySourceFingerprint"] == gallery["sourceFingerprint"]
    assert data["workers"] == 4
    assert {p["method"] for p in data["phases"]} == set(NAMES)
    assert all(len(p["results"]) == 270 for p in data["phases"])
    summaries, lookup = [], {}
    for phase in data["phases"]:
        cases = phase["results"]
        assert len({key(c) for c in cases}) == 270
        eligible = [c for c in cases if c["accessible"]]
        trials = [t for c in cases for t in c["trials"]]
        for case in cases:
            assert bool(case.get("proof")) == any(t["targetPotted"] for t in case["trials"])
            assert all(.5 <= t["speed"] <= 8 and (t["settled"] or not t["targetPotted"]) for t in case["trials"])
            if not case["accessible"]:
                assert not case["trials"]
            proof = case.get("proof")
            if proof:
                sample = gallery["samples"][case["sampleIndex"]]
                dx, dz = sample["ghost"]["x"]-sample["cue"]["x"], sample["ghost"]["z"]-sample["cue"]["z"]
                length = (dx*dx+dz*dz)**.5
                assert abs(proof["direction"]["x"]-dx/length) < 1e-6
                assert abs(proof["direction"]["z"]-dz/length) < 1e-6
                assert proof["settled"]
                assert any(e.get("kind") == "pocket" and e.get("ball") == "object"
                           and e.get("pocketID") == f"pocket_{case['pocket']}" for e in proof["events"]), proof
                assert not any(k in proof for k in ("frames", "trajectory", "cuePath", "targetPath"))
        summary = dict(method=phase["method"], wallSeconds=phase["wallSeconds"],
                       fixedTipCases=len(cases), accessible=len(eligible),
                       casesWithPot=sum(bool(c.get("proof")) for c in cases),
                       boardsWithAnyTip=len({c["sampleIndex"] for c in cases if c.get("proof")}),
                       nominalAccuracySuccess=sum(c.get("proof", {}).get("accuracyOutcome") == "success" for c in cases),
                       firstTrialSuccesses=sum(bool(c["trials"]) and c["trials"][0]["targetPotted"] for c in cases),
                       unfinishedSimulations=sum(not t["settled"] for t in trials),
                       simulations=len(trials), jobTiming=timing([c["elapsedSeconds"] for c in eligible]),
                       simulationTiming=timing([t["seconds"] for t in trials]),
                       accessibleCasesPerSecond=len(eligible)/phase["wallSeconds"])
        center = [c for c in eligible if c["tip"] == "center"]
        summary["centerOnly"] = dict(cases=len(center), passed=sum(bool(c.get("proof")) for c in center),
                                    jobTiming=timing([c["elapsedSeconds"] for c in center]))
        summaries.append(summary)
        lookup[phase["method"]] = {key(c): c for c in cases}
    reference = lookup["reference-uniform-0.1"]
    counterexamples = []
    for k, result in reference.items():
        ts = result["trials"]
        if not ts:
            continue
        assert len(ts) == 76
        observed = [t for t in ts if t["settled"]]
        transitions = sum(t["targetPotted"] and (i == 0 or not observed[i-1]["targetPotted"])
                          for i, t in enumerate(observed))
        seen_success = False
        falls = False
        for trial in observed:
            if seen_success and not trial["targetPotted"]:
                falls = True
            seen_success |= trial["targetPotted"]
        single_miss = bool(result.get("proof")) and not lookup["single-branch-increase-on-miss"][k].get("proof")
        subdivision_miss = bool(result.get("proof")) and not lookup["two-sided-midpoint-subdivision"][k].get("proof")
        if falls or single_miss or subdivision_miss:
            counterexamples.append(dict(sampleIndex=k[0], tip=k[1], cellID=result["cellID"],
                successThenFailure=falls, successfulIslands=transitions, singleBranchMissed=single_miss,
                subdivisionMissed=subdivision_miss,
                successfulSpeeds=[round(t["speed"], 3) for t in ts if t["targetPotted"]],
                trials=ts))
    comparisons = {}
    reference_positive = {k for k, c in reference.items() if c.get("proof")}
    for name in NAMES:
        positives = {k for k, c in lookup[name].items() if c.get("proof")}
        comparisons[name] = dict(referencePositiveCases=len(reference_positive),
                                 missedReferencePositive=len(reference_positive-positives),
                                 additionalPositivesOutsideReferenceGrid=len(positives-reference_positive))
    audit = dict(sourceFingerprint=data["sourceFingerprint"], workers=data["workers"],
                 scope=data["directionPolicy"], successPolicy=data["successPolicy"],
                 phases=summaries, comparisons=comparisons,
                 nonMonotonicCases=sum(c["successThenFailure"] for c in counterexamples),
                 disconnectedSuccessCases=sum(c["successfulIslands"] > 1 for c in counterexamples))
    (DIRECTORY/"audit.json").write_text(json.dumps(audit, ensure_ascii=False, indent=2))
    (DIRECTORY/"counterexamples.json").write_text(json.dumps(counterexamples, ensure_ascii=False, indent=2))
    md = ["# 固定方向、固定打点，仅搜索力度：实测", "",
          "30个v2网格球形 × 9种独立固定打点，共270个候选任务；4路并行。"
          "范围0.5–8m/s，出杆方向始终为C→G；没有方向反解、打点搜索或九点容差验证。",
          "", "筛选成功只表示完整停稳且目标球进入指定袋；白球落袋／间接进袋另记，不能据此发布为准度练习合格题。"
          "真实球杆不可达的固定打点单列，不消耗模拟。",
          "", "| 方法 | 总墙钟秒 | 实际模拟次数 | 找到进球的固定打点任务 | 至少一个打点进球的球形 | 单任务中位数 / P95 ms |",
          "|---|---:|---:|---:|---:|---:|"]
    for s in summaries:
        md.append(f"| {NAMES[s['method']]} | {s['wallSeconds']:.3f} | {s['simulations']} | {s['casesWithPot']} | {s['boardsWithAnyTip']} | {s['jobTiming']['medianMs']:.2f} / {s['jobTiming']['p95Ms']:.2f} |")
    md += ["", "单任务耗时为该固定球形、固定打点在工作线程内执行搜索的实际时间，不含排队；模拟耗时另存audit.json。"
           "所有时间来自本机优化Debug模拟器，不能当作其他设备或全库承诺。",
           "", "单侧二分的实验假设是“未进就提高力度下界”，最多7次；它没有经证明的单调判据。"
           "双侧细分按层访问区间中点，最多15个内部点加2端点，找到即停；不是只保留一半的对数复杂度二分。"
           "0.1m/s对照遍历76点，用于发现漏解和非单调，仍不证明连续空间无解。",
           "", f"采样中存在 {audit['nonMonotonicCases']} 个随力度增加出现“进→不进”的固定打点任务；"
           f"{audit['disconnectedSuccessCases']} 个有多个分离的进球采样区段。",
           "", "| 搜索方法 | 漏掉等距对照已找到的任务 | 找到对照网格之外的任务 |", "|---|---:|---:|"]
    for name in list(NAMES)[:2]:
        c = comparisons[name]
        md.append(f"| {NAMES[name]} | {c['missedReferencePositive']} | {c['additionalPositivesOutsideReferenceGrid']} |")
    md += ["", "反例速度与每次模拟耗时：counterexamples.json；紧凑正例输入、事件、打点及速度：results.json。未保存轨迹。",
           "", "未运行旧完整反解器的同样本对照，不能将旧15球试跑与本轮直接计算加速倍数。正式大批筛选和Bundle接入尚未启动。"]
    (DIRECTORY/"试跑报告.md").write_text("\n".join(md)+"\n")
    print(json.dumps(audit, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
