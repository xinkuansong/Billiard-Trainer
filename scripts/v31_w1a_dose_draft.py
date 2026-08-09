#!/usr/bin/env python3
"""v31 W1a 剂量底稿表生成（只读脚本）。

口径真源：`.kiro/steering/content-data-contract.md` §5.6（剂量口径）、§3.2（序列归属判定）。

- drill 清单取 `QiuJi/Resources/Drills/index.json`，仅本批 4 分类；
- 球形 token 与**实测杆数**一律从 `content/position_play/sequences/*.json` 取：
  杆数 = `len(steps)`（内容实测），并与文件名 `-N杆` 声明值交叉核对，不一致时报 MISMATCH；
  ⛔ 禁止手抄/目测（geometry-spatial-reasoning 铁律）。
- 建议量按 §5.6.3：`rounds = max(1, 60 // ballsPerRound)`，总量 = Σ ballsPerRound × rounds。

输出：build/v31-dose-draft.csv（+ 控制台摘要）。不写任何内容文件。
"""

from __future__ import annotations

import csv
import json
import re
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DRILLS_DIR = REPO / "QiuJi" / "Resources" / "Drills"
SEQ_DIR = REPO / "content" / "position_play" / "sequences"
OUT_CSV = REPO / "build" / "v31-dose-draft.csv"

BATCH_CATEGORIES = ["fundamentals", "accuracy", "cueAction", "forceControl"]
SHOT_COUNT_RE = re.compile(r"-(\d+)杆\.json$")


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
    data = json.loads(path.read_text(encoding="utf-8"))
    return len(data.get("steps", []))


def declared_shots(path: Path) -> int | None:
    m = SHOT_COUNT_RE.search(path.name)
    return int(m.group(1)) if m else None


def suggest(balls_per_round: int) -> tuple[int, int]:
    """§5.6.3：轮数向下取整、最少 1 轮；返回 (rounds, total)。"""
    if balls_per_round <= 0:
        return 0, 0
    rounds = max(1, 60 // balls_per_round)
    return rounds, rounds * balls_per_round


def main() -> None:
    index = load_index()
    batch_ids: list[tuple[str, str]] = [
        (cat, did) for cat in BATCH_CATEGORIES for did in index[cat]
    ]
    seqs = sequences_by_drill({d for _, d in batch_ids})

    rows: list[dict] = []
    mismatches: list[str] = []
    for cat, drill_id in batch_ids:
        drill = json.loads(
            (DRILLS_DIR / cat / f"{drill_id}.json").read_text(encoding="utf-8")
        )
        cur = drill.get("sets", {})
        cur_desc = f"{cur.get('defaultSets')}x{cur.get('defaultBallsPerSet')}"
        per = cur.get("perFormation")
        files = seqs.get(drill_id, [])
        if not files:
            rows.append(
                {
                    "drillId": drill_id,
                    "category": cat,
                    "nameZh": drill.get("nameZh", ""),
                    "token": "(无序列)",
                    "seqFile": "",
                    "measuredShots": "",
                    "declaredShots": "",
                    "currentSets": cur_desc,
                    "hasPerFormation": "yes" if per else "no",
                    "suggestMode": "n/a(豁免)",
                    "suggestBallsPerRound": "",
                    "suggestRounds": "",
                    "suggestTotal": "",
                }
            )
            continue
        for path in files:
            measured = measured_shots(path)
            decl = declared_shots(path)
            if decl is not None and decl != measured:
                mismatches.append(f"{path.name}: 文件名声明 {decl} 杆 / 实测 {measured} 杆")
            # 底稿默认按 sequence 型给建议（mode 由人工逐条判定后覆盖）
            rounds, total = suggest(measured)
            rows.append(
                {
                    "drillId": drill_id,
                    "category": cat,
                    "nameZh": drill.get("nameZh", ""),
                    "token": token_of(path, drill_id),
                    "seqFile": path.name,
                    "measuredShots": measured,
                    "declaredShots": decl if decl is not None else "",
                    "currentSets": cur_desc,
                    "hasPerFormation": "yes" if per else "no",
                    "suggestMode": "sequence" if measured > 0 else "repetition(0杆)",
                    "suggestBallsPerRound": measured,
                    "suggestRounds": rounds,
                    "suggestTotal": total,
                }
            )

    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    with OUT_CSV.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    print(f"本批 drill 数：{len(batch_ids)}（{', '.join(BATCH_CATEGORIES)}）")
    print(f"底稿行数（球形级）：{len(rows)} → {OUT_CSV}")
    per_drill = defaultdict(int)
    for r in rows:
        if r["measuredShots"] != "":
            per_drill[r["drillId"]] += 1
    multi = {d: n for d, n in per_drill.items() if n >= 2}
    print(f"多球形 drill：{len(multi)} 条 → {multi}")
    no_seq = [d for _, d in batch_ids if d not in per_drill]
    print(f"无序列 drill：{len(no_seq)} 条 → {no_seq}")
    zero = [(r['drillId'], r['token']) for r in rows if r["measuredShots"] == 0]
    print(f"0 杆球形：{len(zero)} → {zero}")
    if mismatches:
        print(f"⚠️ 文件名声明杆数 vs 实测杆数不一致 {len(mismatches)} 条：")
        for m in mismatches:
            print("  " + m)
    else:
        print("✅ 全部序列：文件名声明杆数 == 实测 len(steps)")
    print("\n--- 按 drill 汇总（实测杆数 / 现量 / 建议） ---")
    for cat, drill_id in batch_ids:
        rs = [r for r in rows if r["drillId"] == drill_id]
        shots = "、".join(
            f"{r['token']}={r['measuredShots']}杆" for r in rs if r["measuredShots"] != ""
        ) or "(无序列)"
        total = sum(r["suggestTotal"] for r in rs if r["suggestTotal"] != "")
        print(f"{drill_id} [{cat}] 现 {rs[0]['currentSets']} | {shots} | 建议总量 {total}")


if __name__ == "__main__":
    main()
