#!/usr/bin/env python3
"""Validate saved physical results against the unchanged base sample and plan."""
from collections import Counter, defaultdict
import gzip
import json
from pathlib import Path

import one_solution_plan as plan
import run_one_solution as run


def main():
    current = json.loads((run.HERE / "one-solution-current-run.json").read_text())
    evidence = Path(current["evidence"])
    plans = {item["sampleIndex"]: item for item in plan.read_plans()}
    inputs = {item["sampleIndex"]: item for item in plan.read_plan_rows()}
    assert len(plans) == len(inputs) == 10000
    assert len({(p["sourceTargetIndex"], p["maskIndex"], p["distanceBit"]) for p in plans.values()}) == 10000
    fields = ("sourceTargetIndex", "maskIndex", "distanceBit", "cue", "target", "ghost", "pocket")
    for index, item in plans.items():
        assert all(item[field] == inputs[index][field] for field in fields), "base sample changed"
        chosen = item["obstacle"]
        assert chosen in plan.obstacle_candidates(item), "invalid obstacle selection"
        assert not chosen["failures"]
    jobs = {index: run.candidates(item) for index, item in plans.items()}
    summary = run.summarize(evidence, jobs, current["runIdentity"])
    counters = defaultdict(lambda: defaultdict(Counter))
    cause_flags = Counter()
    incomplete_terms = Counter()
    solved_indexes, all_incomplete, mixed_incomplete = [], [], []
    excluded_pots = 0
    max_target_height = 0.0
    rejected = defaultdict(list)
    for file in sorted((evidence / "shapes").glob("*.json.gz")):
        with gzip.open(file, "rt") as stream:
            result = json.load(stream)
        index = result["sampleIndex"]
        item = plans[index]
        rows = result["rows"]
        failed = sum(not row.get("settled") for row in rows)
        state = "solved" if result["status"] == "solved" else "unconfirmed" if failed else "noSolutionInCandidates"
        if state == "solved":
            solved_indexes.append(index)
            max_target_height = max(max_target_height, rows[-1]["targetMaximumHeightMetres"])
        elif failed == len(rows):
            all_incomplete.append(index)
        elif failed:
            mixed_incomplete.append(index)
        if state != "solved":
            rejected[state].append({
                **item, "searchStatus": state, "attemptedCandidates": len(rows),
                "incompleteCandidates": failed,
                "terminationCounts": dict(Counter(row.get("termination", "unknown") for row in rows)),
                "evidence": str(file),
            })
        for field in ("distanceBit", "pocket", "angleIndex", "railIndex"):
            counters[field][str(item[field])][state] += 1
        s, q = item["obstacle"]["s"], item["obstacle"]["q"]
        counters["obstacleCell"][f"s{s:.2f}-q{q:.2f}"][state] += 1
        metres = item["cueTargetDistanceMetres"]
        bin_start = int(metres * 5) / 5
        counters["actualCueTargetDistanceMetres"][f"{bin_start:.1f}–{bin_start + .2:.1f}"][state] += 1
        for row in rows:
            excluded_pots += bool(row["objectPotted"] and not row["basePotted"])
            for flag in ("cueEscaped", "targetEscaped", "obstacleContact", "cueLeftTable", "targetBeforeLanding"):
                cause_flags[flag] += bool(row.get(flag))
            if not row.get("settled"):
                termination = row.get("termination", "unknown")
                reason = "penetration" if "penetration(" in termination else termination
                incomplete_terms[reason] += 1
    assert len(solved_indexes) == len(set(solved_indexes)) == summary["solvedBaseShapes"]
    audit = {
        "schema": "cb01-one-solution-audit-v1", "runIdentity": current["runIdentity"],
        "status": summary["status"], "unchangedBaseShapes": 10000,
        "validatedLegalBlockedLayouts": 10000, "summary": str(evidence / "summary.json"),
        "completedBaseShapes": summary["completedBaseShapes"], "solvedBaseShapes": len(solved_indexes),
        "noSolutionInCompleteCandidateSet": summary["searchExhaustedBaseShapes"] - len(all_incomplete) - len(mixed_incomplete),
        "allCandidatesIncompleteSampleIndexes": all_incomplete,
        "mixedIncompleteSampleIndexes": mixed_incomplete,
        "groupedShapeOutcomes": {field: dict(sorted(groups.items())) for field, groups in counters.items()},
        "excludedUnsafeOrNonQualifyingPots": excluded_pots,
        "attemptCauseFlagsOverlapping": dict(cause_flags),
        "incompleteTerminations": dict(incomplete_terms),
        "maximumTargetHeightAmongSolutionsMetres": max_target_height,
        "earlyStopSavedSimulations": 17 * summary["completedBaseShapes"] - summary["actualSimulations"],
        "sourceSampleSHA256": run.sha(plan.INPUT),
    }
    output = run.HERE / "one-solution-audit-20261124.json"
    run.atomic_json(output, audit)
    for state, name in (("noSolutionInCandidates", "no-solution-in-candidates.jsonl.gz"),
                        ("unconfirmed", "unconfirmed-simulation.jsonl.gz")):
        path = evidence / name
        with path.open("wb") as raw, gzip.GzipFile(fileobj=raw, mode="wb", mtime=0) as stream:
            for row in rejected[state]:
                stream.write((json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n").encode())
    lines = ["# 单障碍单解搜索分布", "", f"状态：{summary['status']}；已处理 {summary['completedBaseShapes']:,} / 10,000 个基础球形。", "",
             f"- 合格解：{len(solved_indexes):,} 个，每个基础球形一个障碍位置、一条解。",
             f"- 所有候选均正常模拟但未找到合格解：{audit['noSolutionInCompleteCandidateSet']:,} 个。",
             f"- 未找到合格解且含不完整模拟：{len(all_incomplete)+len(mixed_incomplete):,} 个，其中全部候选均不完整 {len(all_incomplete):,} 个。",
             f"- 实际模拟：{summary['actualSimulations']:,} 次；首解早停省去 {audit['earlyStopSavedSimulations']:,} 次后续候选。", "",
             f"这不是物理可解率或最低仰角的证明，只统计本轮固定障碍、有限参数搜索。成功解技术分布：跳球 {summary['techniques'].get('jump', 0):,}，扎杆 {summary['techniques'].get('masse', 0):,}。扎杆未包含瞄准角补偿搜索。", "",
             "## 保留解的仰角", "", "| 仰角 | 解数 |", "|---:|---:|"]
    lines += [f"| {angle}° | {count:,} |" for angle, count in sorted(summary["elevationDegrees"].items(), key=lambda item: float(item[0]))]
    titles = {"actualCueTargetDistanceMetres": "母球与目标球实际距离（米）", "obstacleCell": "障碍位置与遮挡档位", "pocket": "袋口编号", "distanceBit": "来源距离位元", "angleIndex": "来源角度位元", "railIndex": "来源贴库位元"}
    for field, title in titles.items():
        lines += ["", "## " + title, "", "| 分组 | 已处理 | 合格解 | 候选未找到 | 模拟未确认 |", "|---|---:|---:|---:|---:|"]
        for group, values in sorted(counters[field].items()):
            lines.append(f"| {group} | {sum(values.values()):,} | {values['solved']:,} | {values['noSolutionInCandidates']:,} | {values['unconfirmed']:,} |")
    lines += ["", "## 下载与复现", "",
              f"- [成功解]({evidence / 'solutions.jsonl.gz'})",
              f"- [本轮候选未找到解]({evidence / 'no-solution-in-candidates.jsonl.gz'})",
              f"- [模拟未确认]({evidence / 'unconfirmed-simulation.jsonl.gz'})",
              f"- [逐参数尝试与执行日志]({evidence})", "",
              "输入基础球形保持不变，10,000 个位置均通过实际直线路径遮挡检查；不做扰动试验。参数与安全标准见[执行记录](one-solution-results-20261124.md)。"]
    (run.HERE / "one-solution-distribution-20261124.md").write_text("\n".join(lines) + "\n")
    print(json.dumps({k: audit[k] for k in ("status", "completedBaseShapes", "solvedBaseShapes", "noSolutionInCompleteCandidateSet", "earlyStopSavedSimulations")}, ensure_ascii=False))


if __name__ == "__main__":
    main()
