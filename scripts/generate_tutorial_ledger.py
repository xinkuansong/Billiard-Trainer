#!/usr/bin/env python3
"""
generate_tutorial_ledger.py — 精讲资产台账（由校验数据自动生成，禁止手改）

输出：docs/research/精讲资产台账.md
数据来源：content/position_play/sequences、build/position_play_export、
         QiuJi/Resources/DrillTutorials、QiuJi/Resources/Drills/**/*.json

用法：
  python3 scripts/generate_tutorial_ledger.py
  python3 scripts/generate_tutorial_ledger.py --out path.md

序列更新后：make position-export → 回填 → make verify-tutorials →
再跑本脚本，台账自动刷新。本文件不是真源，丢了可随时重生成。
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from verify_tutorial_images import collect_image_refs  # noqa: E402
from verify_tutorial_sync import (  # noqa: E402
    EXPORT_DIR,
    SEQUENCES_DIR,
    TUTORIALS_ROOT,
    check_backfill,
    check_export_freshness,
    check_refs,
    check_structure,
    load_sequences,
    load_tutorials,
)

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = REPO_ROOT / "docs" / "research" / "精讲资产台账.md"

SHOT_SECTION_RE = re.compile(r"^第.+杆")


def status_icon(ok: bool) -> str:
    return "✅" if ok else "❌"


def tutorial_kind(drill_id: str, tutorials: dict, sequences: dict) -> str:
    tut = tutorials.get(drill_id)
    if tut is None:
        return "无精讲"
    shots = tut["shots"]
    if sum(shots) == 0:
        seq = sequences.get(drill_id) or []
        if not seq:
            return "legacy·无序列"
        return "legacy"
    if tut["has_formations"]:
        return f"多球形({len(shots)})"
    return "多杆应用课"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    sequences = load_sequences()
    tutorials = load_tutorials()
    all_refs = collect_image_refs()
    referenced = {image for _, image, _ in all_refs}
    drills_with_refs = {d for d, _, _ in all_refs}

    c1 = check_export_freshness(sequences)
    c2 = check_backfill(referenced)
    c3 = check_refs()
    c4 = check_structure(sequences, tutorials)

    # index failures by drill
    c1_fail = {d for d, _ in c1["fail"]}
    c1_warn = {d for d, _ in c1["warn"]}
    c2_fail = set()
    for name, _ in c2["fail"]:
        m = re.match(r"(drill_c\d+)_", name)
        if m:
            c2_fail.add(m.group(1))
    for name, _ in c2.get("collision", []):
        m = re.match(r"(drill_c\d+)_", name)
        if m:
            c2_fail.add(m.group(1))
    c3_stale = {d for d, _, _ in c3["fail"]}
    c3_dead = defaultdict(int)
    for d, _, _ in c3["warn"]:
        c3_dead[d] += 1
    c4_fail = {d: (a, e) for d, a, e in c4["fail"]}
    c4_warn = {d: note for d, note, _ in c4["warn"]}

    all_ids = sorted(set(tutorials) | set(sequences))

    lines: list[str] = []
    lines.append("# 精讲资产台账")
    lines.append("")
    lines.append("> **自动生成，禁止手改。** 重生成：`python3 scripts/generate_tutorial_ledger.py`")
    lines.append(f">")
    lines.append(f"> 生成时间：{datetime.now().strftime('%Y-%m-%d %H:%M')}")
    lines.append(">")
    lines.append("> 链路：序列 JSON → 出片产物 → 回填图 → 精讲引用 → 精讲结构")
    lines.append("> 校验：`make verify-tutorials`（详见 `scripts/verify_tutorial_sync.py`）")
    lines.append("")
    lines.append("## 汇总")
    lines.append("")
    lines.append(f"| 检查 | 通过 | 失败 | 提示 |")
    lines.append(f"|---|---:|---:|---:|")
    lines.append(f"| C1 出片新鲜度 | {c1['ok']} | {len(c1['fail'])} | {len(c1['warn'])} |")
    lines.append(f"| C2 回填一致性 | {c2['ok']} | {len(c2['fail'])+len(c2.get('collision',[]))} | {len(c2.get('collision_idle',[]))} |")
    lines.append(f"| C3 引用指向 | {c3['ok']} | {len(c3['fail'])} | {len(c3['warn'])} |")
    lines.append(f"| C4 结构对齐 | {c4['ok']} | {len(c4['fail'])} | {len(c4['warn'])} |")
    lines.append("")
    lines.append("## 逐条台账")
    lines.append("")
    lines.append("| drill | 精讲形态 | 最新序列 | 出片 | 回填 | 引用 | 结构 | 备注 |")
    lines.append("|---|---|---|:---:|:---:|:---:|:---:|---|")

    for did in all_ids:
        seq = sequences.get(did) or []
        active = [s for s in seq if s["shots"] > 0]
        seq_desc = "/".join(f"{s['shots']}杆" for s in active) if active else (
            "0杆" if seq else "—"
        )
        kind = tutorial_kind(did, tutorials, sequences)

        # C1
        if did in c1_fail:
            s1 = "❌"
        elif did in c1_warn and not active:
            s1 = "—"
        elif did in c1_warn:
            s1 = "⚠️"
        elif not active:
            s1 = "—"
        else:
            s1 = "✅"

        # C2
        s2 = "❌" if did in c2_fail else ("✅" if active else "—")

        # C3
        if did in c3_stale:
            s3 = "❌旧图"
        elif c3_dead.get(did):
            s3 = f"❌缺{c3_dead[did]}"
        elif did in drills_with_refs:
            s3 = "✅"
        else:
            s3 = "—"

        # C4
        if did in c4_fail:
            a, e = c4_fail[did]
            s4 = "❌"
            note = f"精讲{a}杆≠序列{e}杆"
        elif did in c4_warn:
            s4 = "—"
            note = c4_warn[did]
        else:
            s4 = "✅"
            note = ""

        lines.append(
            f"| {did} | {kind} | {seq_desc} | {s1} | {s2} | {s3} | {s4} | {note} |"
        )

    lines.append("")
    lines.append("## 操作约定")
    lines.append("")
    lines.append("1. **序列有改动** → `make position-export` 重出片 → 回填 → `make verify-tutorials` → 重跑本脚本。")
    lines.append("2. **精讲重写完成** → 重跑本脚本，对应行应变绿。")
    lines.append("3. **禁止手改本表**；要改的是序列 / 出片 / 精讲 JSON，表只是投影。")
    lines.append("")

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"已写入 {args.out}")
    print(f"C1 fail={len(c1['fail'])}  C2 fail={len(c2['fail'])+len(c2.get('collision',[]))}  "
          f"C3 fail={len(c3['fail'])}  C4 fail={len(c4['fail'])}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
