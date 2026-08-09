#!/usr/bin/env python3
"""v31 W1a 复验（只读）：对已写盘的 43 条 drill 做 I6a/I6b 预演 + 护栏 + 「只动两处」证明。

检查项：
- V1（I6b 预演）：每个 `mode == sequence` 的球形满足 `ballsPerRound == 序列实测杆数`（`len(steps)`）；
- V2（I6a 预演）：有序列 drill 的 `perFormation` token 集合 == 该 drill 序列 token 集合；
  无序列 drill 允许无 `perFormation`（§5.6.4）；
- V3（汇总兜底一致）：`defaultSets == Σ defaultRounds`、`defaultBallsPerSet == 主球形 ballsPerRound`；
- V4（护栏 §5.6.3）：总量 Σ(ballsPerRound × defaultRounds) ∈ [40, 60]；
- V5（mode 取值合法）：∈ {sequence, repetition}；repetition 型 ballsPerRound ∈ [10, 15]；
- V6（副分类 §3.3）：≤1 个、属 8 类、≠ 主分类；
- V7（只动两处）：与 git HEAD 版本逐键比对，除 `sets` / `secondaryCategories` 外所有顶层键必须原样。

退出码非 0 表示有 FAIL。
"""

from __future__ import annotations

import json
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DRILLS_DIR = REPO / "QiuJi" / "Resources" / "Drills"
SEQ_DIR = REPO / "content" / "position_play" / "sequences"

BATCH_CATEGORIES = ["fundamentals", "accuracy", "cueAction", "forceControl"]
VALID_CATEGORIES = {
    "fundamentals", "accuracy", "cueAction", "separation",
    "positioning", "forceControl", "specialShots", "combined",
}


def load_index() -> dict[str, list[str]]:
    data = json.loads((DRILLS_DIR / "index.json").read_text(encoding="utf-8"))
    return {g["category"]: list(g["drills"]) for g in data["categories"]}


def sequences_by_drill(drill_ids: set[str]) -> dict[str, list[Path]]:
    buckets: dict[str, list[Path]] = defaultdict(list)
    for path in sorted(SEQ_DIR.glob("*.json")):
        for drill_id in drill_ids:
            if path.name.startswith(drill_id + "__") or path.name.startswith(drill_id + "-"):
                buckets[drill_id].append(path)
                break
    return buckets


def token_of(path: Path, drill_id: str) -> str:
    marker = drill_id + "__"
    if not path.name.startswith(marker):
        return ""
    return path.name[len(marker):].split("-", 1)[0]


def measured_shots(path: Path) -> int:
    return len(json.loads(path.read_text(encoding="utf-8")).get("steps", []))


def head_version(rel_path: str) -> dict | None:
    try:
        out = subprocess.run(
            ["git", "show", f"HEAD:{rel_path}"],
            cwd=REPO, capture_output=True, check=True,
        ).stdout
    except subprocess.CalledProcessError:
        return None
    return json.loads(out)


def main() -> None:
    index = load_index()
    batch = [(c, d) for c in BATCH_CATEGORIES for d in index[c]]
    seqs = sequences_by_drill({d for _, d in batch})

    fails: list[str] = []
    checked = {f"V{i}": 0 for i in range(1, 8)}
    print(f"复验范围：{len(batch)} 条 drill（{', '.join(BATCH_CATEGORIES)}）\n")

    for cat, drill_id in batch:
        rel = f"QiuJi/Resources/Drills/{cat}/{drill_id}.json"
        data = json.loads((REPO / rel).read_text(encoding="utf-8"))
        sets = data["sets"]
        per = sets.get("perFormation") or []
        files = seqs.get(drill_id, [])
        seq_tokens = {token_of(p, drill_id) for p in files}
        shots_by_token = {token_of(p, drill_id): measured_shots(p) for p in files}

        # V1 / V5
        for dose in per:
            checked["V5"] += 1
            if dose["mode"] not in {"sequence", "repetition"}:
                fails.append(f"V5 {drill_id}/{dose['token']}: 非法 mode {dose['mode']}")
            if dose["mode"] == "sequence":
                checked["V1"] += 1
                expected = shots_by_token.get(dose["token"])
                if expected is None:
                    fails.append(f"V1 {drill_id}/{dose['token']}: token 无对应序列文件")
                elif dose["ballsPerRound"] != expected:
                    fails.append(
                        f"V1 {drill_id}/{dose['token']}: ballsPerRound="
                        f"{dose['ballsPerRound']} != 实测杆数 {expected}"
                    )
            elif not 10 <= dose["ballsPerRound"] <= 15:
                fails.append(
                    f"V5 {drill_id}/{dose['token']}: repetition 型 ballsPerRound="
                    f"{dose['ballsPerRound']} 超出 10–15 带"
                )

        # V2
        checked["V2"] += 1
        if files:
            if {d["token"] for d in per} != seq_tokens:
                fails.append(
                    f"V2 {drill_id}: perFormation token {sorted(d['token'] for d in per)} "
                    f"!= 序列 token {sorted(seq_tokens)}"
                )
        elif per:
            fails.append(f"V2 {drill_id}: 无序列却写了 perFormation")

        # V3
        checked["V3"] += 1
        if per:
            if sets["defaultSets"] != sum(d["defaultRounds"] for d in per):
                fails.append(f"V3 {drill_id}: defaultSets != Σ defaultRounds")
            if sets["defaultBallsPerSet"] != per[0]["ballsPerRound"]:
                fails.append(f"V3 {drill_id}: defaultBallsPerSet != 主球形 ballsPerRound")

        # V4
        checked["V4"] += 1
        total = (
            sum(d["ballsPerRound"] * d["defaultRounds"] for d in per)
            if per
            else sets["defaultSets"] * sets["defaultBallsPerSet"]
        )
        guard = "OK" if 40 <= total <= 60 else "越界"
        if guard != "OK":
            fails.append(f"V4 {drill_id}: 总量 {total} 不在 40–60")

        # V6
        checked["V6"] += 1
        sec = data.get("secondaryCategories")
        if sec is not None:
            if len(sec) > 1:
                fails.append(f"V6 {drill_id}: 副分类 {len(sec)} 个 > 1")
            for value in sec:
                if value not in VALID_CATEGORIES:
                    fails.append(f"V6 {drill_id}: 副分类 {value} 不属 8 类")
                if value == data["category"]:
                    fails.append(f"V6 {drill_id}: 副分类与主分类同值")

        # V7
        checked["V7"] += 1
        old = head_version(rel)
        if old is None:
            fails.append(f"V7 {drill_id}: 无 HEAD 版本可比")
        else:
            for key in set(old) | set(data):
                if key in {"sets", "secondaryCategories"}:
                    continue
                if old.get(key) != data.get(key):
                    fails.append(f"V7 {drill_id}: 顶层键 `{key}` 被意外改动")

        modes = "/".join(f"{d['token']}:{d['mode'][:3]}×{d['ballsPerRound']}×{d['defaultRounds']}"
                         for d in per) or "(无 perFormation·豁免)"
        print(f"{drill_id} [{cat}] 总量 {total} {guard} | {modes} | 副分类 {sec or '—'}")

    print("\n--- 检查计数 ---")
    for name, count in checked.items():
        print(f"{name}: {count} 次")
    print(f"\nFAIL {len(fails)}")
    for f in fails:
        print("  ⛔ " + f)
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
