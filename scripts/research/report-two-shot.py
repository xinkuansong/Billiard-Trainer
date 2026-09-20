#!/usr/bin/env python3
"""Summarize sampled coverage; never infer continuous coverage or infeasibility."""
import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("run", type=Path)
    args = parser.parse_args()
    rows = json.loads((args.run / "coverage.json").read_text())
    config = json.loads((args.run / "run-config.json").read_text())
    legal = [r for r in rows if r["status"] != "invalidStart"]
    solved = [r for r in legal if r["status"] == "solved"]
    for row in solved:
        solution = row["solution"]
        a, b = solution["first"], solution["second"]
        assert a["end"] == b["start"], "Handoff changed the board"
        assert set(a["pots"]).isdisjoint(b["pots"])
        assert set(a["pots"] + b["pots"]) == {1, 2, 3, 4, 5, 8}
        assert a["pots"] and b["pots"]
        assert all(s["termination"] == "settled" and not s["rejected"] for s in (a, b))
        assert row["validationSimulations"] == 4
    lines = ["# 六球两杆物理搜索：本轮样本报告", "",
             f"固定 d={config['distanceMetres']:.9f} m，杆速上限 {config['cueSpeedCap']} m/s。",
             f"合法样本 {len(legal)}，已复验清台 {len(solved)}；搜索调用 "
             f"{sum(r['simulations'] for r in rows)}，验收调用 "
             f"{sum(r['validationSimulations'] for r in rows)}。", "",
             "这是离散样本结果；未找到不等于无解，不能外推任意起点。", "",
             "| 起点 X/Z (m) | 状态 | 最多合法两杆进球 | 搜索调用 | 秒 |", "|---|---|---:|---:|---:|"]
    for r in rows:
        p = r["start"]
        lines.append(f"| {p['x']:.6f}, {p['z']:.6f} | {r['status']} | "
                     f"{r['bestCleanTotal']} | {r['simulations']} | {r['seconds']:.2f} |")
    lines += ["", "验证：成功样本逐杆重复事件/终态，逐杆对拍生产 simulateFree，"
              "继承全部在桌球位置。未做视频渲染、真机或人手参数容差验收。", "",
              "搜索限制：有限进球子集/落位 beam，尚非完整拓扑枚举；第二杆库是见证样本，"
              "不是完整可解区域。未测起点仍待测。", ""]
    (args.run / "REPORT.md").write_text("\n".join(lines))
    print(f"{len(solved)}/{len(legal)} sampled starts solved; {args.run / 'REPORT.md'}")


if __name__ == "__main__":
    main()
