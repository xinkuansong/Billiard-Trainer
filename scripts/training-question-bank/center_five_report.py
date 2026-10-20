#!/usr/bin/env python3
"""Audit the center-only, five-attempt experiment; no continuous-solvability claims."""
import collections
import hashlib
import json
import math
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/accuracy-center-five-20261021"


def timing(values):
    ordered = sorted(values)
    return {
        "meanMs": statistics.mean(ordered) * 1000,
        "medianMs": statistics.median(ordered) * 1000,
        "p95Ms": ordered[math.ceil(len(ordered) * .95) - 1] * 1000,
        "maxMs": max(ordered) * 1000,
    }


def main():
    data = json.loads((OUT / "results.json").read_text())
    manifest = json.loads((OUT / "source-manifest.json").read_text())
    assert data["sourceFingerprint"] == manifest["fingerprint"]
    for name, digest in manifest["files"].items():
        assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest, name
    inputs = ROOT / "output/accuracy-grid-anchor-v2-20261021"
    for name, key in [("render-samples.json", "gallerySHA256"), ("inventory.json", "inventorySHA256")]:
        assert hashlib.sha256((inputs / name).read_bytes()).hexdigest() == data[key]
    samples = json.loads((inputs / "render-samples.json").read_text())["samples"]
    results = data["results"]
    assert len(results) == 30 and {r["sampleIndex"] for r in results} == set(range(30))
    for result in results:
        sample = samples[result["sampleIndex"]]
        assert (result["cellID"], result["pocket"]) == (sample["cellID"], sample["pocket"])
        assert 1 <= len(result["trials"]) <= 5
        a, b = .5, 8
        for i, trial in enumerate(result["trials"]):
            speed = trial["speed"]
            assert abs(speed - (a + b) / 2) < 1e-6
            assert trial["seconds"] >= 0
            feedback = trial["feedback"]
            if feedback in ("mouth-miss-decrease", "deflection-probe-lower"):
                b = speed
                assert trial["settled"] and not trial["targetPotted"]
            elif feedback == "short-increase":
                a = speed
                assert trial["settled"] and not trial["targetPotted"]
                assert trial["targetCushions"] == 0
            elif feedback == "incomplete-stop":
                assert not trial["settled"] and not trial["targetPotted"]
                assert i == len(result["trials"]) - 1
            else:
                assert feedback == "pot" and trial["targetPotted"]
                assert i == len(result["trials"]) - 1
        assert bool(result.get("proof")) == any(t["targetPotted"] for t in result["trials"])
        if proof := result.get("proof"):
            assert proof["spinX"] == proof["spinY"] == 0
            dx = sample["ghost"]["x"] - sample["cue"]["x"]
            dz = sample["ghost"]["z"] - sample["cue"]["z"]
            length = math.hypot(dx, dz)
            assert abs(proof["direction"]["x"] - dx / length) < 1e-6
            assert abs(proof["direction"]["z"] - dz / length) < 1e-6
            assert any(e["kind"] == "pocket" and e.get("ball") == "object"
                       and e.get("pocketID") == f"pocket_{sample['pocket']}" for e in proof["events"])
            assert proof["speed"] == result["trials"][-1]["speed"]
    passed = [r for r in results if r.get("proof")]
    trials = [t for r in results for t in r["trials"]]
    summary = {
        "layouts": len(results), "passed": len(passed), "passRate": len(passed) / len(results),
        "simulations": len(trials), "meanAttempts": len(trials) / len(results),
        "wallSeconds": data["wallSeconds"], "workers": data["workers"],
        "layoutTiming": timing([r["elapsedSeconds"] for r in results]),
        "simulationTiming": timing([t["seconds"] for t in trials]),
        "amortizedWallMs": data["wallSeconds"] / len(results) * 1000,
        "incompleteMisses": sum(r["trials"][-1]["feedback"] == "incomplete-stop" for r in results),
        "scratchPasses": sum(r["trials"][-1]["cuePocketed"] for r in passed),
        "feedbackCounts": dict(collections.Counter(t["feedback"] for t in trials)),
        "successByAttempt": dict(collections.Counter(len(r["trials"]) for r in passed)),
    }
    # The old finite grid is an independent historical comparison. Verify every
    # non-experiment source is identical before comparing the exact same inputs.
    old_dir = ROOT / "output/accuracy-speed-screening-20261021"
    old_manifest = json.loads((old_dir / "source-manifest.json").read_text())
    assert all(manifest["files"][k] == v for k, v in old_manifest["files"].items()
               if k != "QiuJiTests/TrainingSpeedScreeningTests.swift")
    old = json.loads((old_dir / "results.json").read_text())
    assert old["gallerySHA256"] == data["gallerySHA256"]
    reference = next(p for p in old["phases"] if p["method"] == "reference-uniform-0.1")
    ref_set = {r["sampleIndex"] for r in reference["results"] if r["tip"] == "center" and r.get("proof")}
    current_set = {r["sampleIndex"] for r in passed}
    summary["referenceComparison"] = {
        "referencePassed": len(ref_set), "common": len(current_set & ref_set),
        "missedReferenceSampleNumbers": [i + 1 for i in sorted(ref_set - current_set)],
        "additionalSampleNumbers": [i + 1 for i in sorted(current_set - ref_set)],
    }
    (OUT / "audit.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    tm = summary["layoutTiming"]
    lines = [
        "# 中杆、最多五次力度：试跑报告", "",
        "沿用审图30例（5角度×2袋型×3库距）；不是全库随机样本，不能将通过率外推到730.6万球形。",
        "固定C→G、中杆spinX=spinY=0、力度0.5–8m/s，首次4.25m/s。每题最多5次，进指定袋即停，母球落袋不否决。",
        "原生完整物理simulateFree；四路OperationQueue，Debug -O、iOS26.3模拟器。预热及编译启动不计入批次计时。", "",
        "| 指标 | 实测 |", "|---|---:|",
        f"| 通过 | {len(passed)}/30（{len(passed)/30:.1%}） |",
        f"| 单球形平均／中位 | {tm['meanMs']:.2f}／{tm['medianMs']:.2f} ms |",
        f"| 单球形P95／最大 | {tm['p95Ms']:.2f}／{tm['maxMs']:.2f} ms |",
        f"| 四路批次墙钟 | {data['wallSeconds']:.3f} s |",
        f"| 四路摊销墙钟／球形 | {summary['amortizedWallMs']:.2f} ms |",
        f"| 模拟次数／平均尝试 | {len(trials)}／{len(trials)/30:.2f} |",
        f"| 通过且母球落袋 | {summary['scratchPasses']} |",
        f"| 技术未完成、未判结果 | {summary['incompleteMisses']} |", "",
        "单球形耗时为任务开始后至结束的实际经过时间，不含排队；并行摊销时间不可冒充单任务延迟。", "",
        "## 反馈判据与边界", "",
        "- 目标球轨迹到P的XZ最近距离≤一球直径：视为到袋口附近，未进则降低力度上界。",
        "- 未靠近P但发生目标球碰库、或沿OP投影越过P：原因不确定，本版试探减力，单独记deflection-probe-lower。",
        "- 无上述情况且完整停稳：尚未到袋口，提高力度下界。",
        "- 仅已发生的指定袋落袋事件算通过；母球状态不参与。未进且模拟未完成则记技术未决，不把截断轨迹当作力小。",
        "- 到袋口附近并不证明必然力大；该规则是本次被测试的搜索启发式。5次未找到不等于无解。",
        "- 解保存方向、力度、零打点、事件；不保存轨迹。", "",
        "## 与上次中杆0.1m/s网格对照", "",
        f"对照{len(ref_set)}/30有解；本轮共同找到{len(ref_set & current_set)}。"
        f"漏掉对照样本号：{summary['referenceComparison']['missedReferenceSampleNumbers']}；"
        f"额外找到：{summary['referenceComparison']['additionalSampleNumbers']}。有限网格也不是完整可解集合。", "",
        "## 分组", "", "| 维度 | 样本／通过 |", "|---|---|",
    ]
    for key, labels in [
        ("angleIndex", ["0–10°", "11–30°", "31–50°", "51–70°", "71–85°"]),
        ("pocketType", ["角袋", "中袋"]), ("railIndex", ["非近库", "半贴库", "贴库"]),
    ]:
        for index, label in enumerate(labels):
            group = [r for r in results if samples[r["sampleIndex"]]["cell"][key] == index]
            lines.append(f"| {label} | {len(group)}／{sum(bool(r.get('proof')) for r in group)} |")
    lines += ["", "## 逐题尝试", "", "| 图册编号 | 组合 | 力度序列m/s | 结果 | 耗时ms |", "|---|---|---|---|---:|"]
    for r in results:
        strengths = " → ".join(f"{t['speed']:.4g}" for t in r["trials"])
        outcome = "通过" if r.get("proof") else "本轮未找到"
        lines.append(f"| {r['sampleIndex']+1:02} | {r['cellID']} | {strengths} | {outcome} | {r['elapsedSeconds']*1000:.2f} |")
    (OUT / "试跑报告.md").write_text("\n".join(lines) + "\n")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
