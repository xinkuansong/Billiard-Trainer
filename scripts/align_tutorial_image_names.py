#!/usr/bin/env python3
"""
align_tutorial_image_names.py — 存量 DrillTutorials 文件名对齐 JSON `image`（D-v25-6 / W2）

与 `import-engine-export-to-app.py` 的分工：
  - import-engine-export-to-app.py：管**新导出**回填时的落位命名（引擎 `sNN_still`
    → 磁盘 `<drillId>_sNN.png`；`manual01` 额外写无前缀别名）。
  - 本脚本：管**存量磁盘文件**的一次性对齐——把已经以错误约定落盘的 PNG
    重命名为 JSON `image` 引用的形式。JSON 引用本身不动。

红线（FL-027）：
  - 只做「文件名对齐」：源文件必须是该 drill 该杆的明确产物候选。
  - ⛔ 不得把失效引用改指不相干已存在图；⛔ 不得让多球形共用一张图冒充修复。
  - 素材套数不足（多球形缺 fN）留给 W3，本脚本不处理。

规则（与 W2 盘点一致）：
  1. strip_still：`<stem>_still.png` 存在且 JSON 引用 `<stem>` → 去掉 `_still`
  2. manual01_default：JSON 无 token，磁盘有 `manual01` 变体 → 默认取 manual01
     （含 `…_manual01_sNN_still.png` → `…_sNN.png`）
  3. snipaste_earliest：JSON 为 `…_fN_<rest>`，磁盘为 `…_Snipaste_<ts>_<rest>[_still].png`
     → 取时间戳字典序最早的一套，重命名为 JSON 形式

用法：
  python3 scripts/align_tutorial_image_names.py --dry-run
  python3 scripts/align_tutorial_image_names.py
  # 幂等：第二次应打印 renamed=0 并以 exit 0 结束（脚本内自检）
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
DRILLS_DIR = REPO_ROOT / "QiuJi" / "Resources" / "Drills"
TUTORIALS_ROOT = REPO_ROOT / "QiuJi" / "Resources" / "DrillTutorials"

DRILL_ID_RE = re.compile(r"^(drill_c\d{3})")


def collect_image_refs() -> list[tuple[str, str]]:
    """Return [(drill_id, image_stem), ...] from tutorial sections/formations."""
    refs: list[tuple[str, str]] = []
    for path in sorted(DRILLS_DIR.rglob("*.json")):
        if path.name == "index.json":
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        drill_id = data.get("id") or path.stem
        tutorial = data.get("tutorial")
        if not isinstance(tutorial, dict):
            continue

        def add_sections(sections: object) -> None:
            if not isinstance(sections, list):
                return
            for section in sections:
                if not isinstance(section, dict):
                    continue
                image = section.get("image")
                if isinstance(image, str) and image.strip():
                    refs.append((drill_id, image.strip()))

        add_sections(tutorial.get("sections"))
        for form in tutorial.get("formations") or []:
            if isinstance(form, dict):
                add_sections(form.get("sections"))
    return refs


def pick_source(drill: str, stem: str, files: set[str]) -> tuple[str, str] | None:
    """Return (reason, source_filename) for a missing JSON image stem, or None."""
    still = f"{stem}_still.png"
    if still in files:
        return ("strip_still", still)

    if not stem.startswith(f"{drill}_"):
        return None
    rest = stem[len(drill) + 1 :]

    for src in (
        f"{drill}_manual01_{rest}.png",
        f"{drill}_manual01_{rest}_still.png",
    ):
        if src in files:
            return ("manual01_default", src)

    m = re.fullmatch(rf"{re.escape(drill)}_f(\d+)_(.+)", stem)
    if m:
        trailing = m.group(2)  # initial / s01 / …
        snips: list[str] = []
        prefix = f"{drill}_Snipaste_"
        for name in files:
            if not name.startswith(prefix):
                continue
            if name.endswith(f"_{trailing}.png") or name.endswith(f"_{trailing}_still.png"):
                snips.append(name)
        snips.sort()  # timestamp token is lexicographic == chronological here
        if snips:
            return ("snipaste_earliest", snips[0])

    return None


def plan_renames() -> list[tuple[str, str, str, str]]:
    """Return [(reason, src_name, dst_name, drill_id), ...] for missing refs only."""
    files = {p.name for p in TUTORIALS_ROOT.glob("*.png")} if TUTORIALS_ROOT.is_dir() else set()
    refs = collect_image_refs()
    missing = [(d, s) for d, s in refs if f"{s}.png" not in files]

    plan: list[tuple[str, str, str, str]] = []
    dests: dict[str, str] = {}
    for drill, stem in missing:
        picked = pick_source(drill, stem, files)
        if not picked:
            continue
        reason, src = picked
        dst = f"{stem}.png"
        if src == dst:
            continue
        if dst in dests and dests[dst] != src:
            raise SystemExit(f"dest collision: {dst} <- {dests[dst]} and {src}")
        if dst in files:
            # Already present as a different file — refuse (no overwrite / no sharing)
            raise SystemExit(f"refuse overwrite existing dest: {dst} (src would be {src})")
        dests[dst] = src
        plan.append((reason, src, dst, drill))
        # pretend src is consumed so later picks don't reuse the same file
        files.discard(src)
        files.add(dst)
    return plan


def apply_plan(
    plan: list[tuple[str, str, str, str]],
    *,
    dry_run: bool,
) -> int:
    for reason, src, dst, _drill in plan:
        src_path = TUTORIALS_ROOT / src
        dst_path = TUTORIALS_ROOT / dst
        print(f"{reason}: {src} → {dst}")
        if dry_run:
            continue
        if not src_path.is_file():
            raise SystemExit(f"missing source: {src}")
        if dst_path.exists():
            raise SystemExit(f"dest already exists: {dst}")
        os.rename(src_path, dst_path)
    return len(plan)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true", help="Print plan only, do not rename")
    args = ap.parse_args()

    if not TUTORIALS_ROOT.is_dir():
        print(f"missing tutorials dir: {TUTORIALS_ROOT}", file=sys.stderr)
        return 2

    plan = plan_renames()
    by_reason = Counter(r for r, *_ in plan)
    print(f"planned_renames={len(plan)} dry_run={args.dry_run}")
    if by_reason:
        print("by reason:", dict(by_reason))

    n = apply_plan(plan, dry_run=args.dry_run)

    if args.dry_run:
        print(f"DRY-RUN done planned={n}")
        return 0

    # Idempotency self-check: re-plan after apply must be empty
    plan2 = plan_renames()
    print(f"renamed={n}")
    print(f"idempotent_replan={len(plan2)}")
    if plan2:
        print("ERROR: not idempotent; second plan still has:", file=sys.stderr)
        for reason, src, dst, drill in plan2:
            print(f"  {reason}: {src} → {dst} ({drill})", file=sys.stderr)
        return 1
    if n == 0:
        print("OK: already aligned (0 renames)")
    else:
        print(f"OK: aligned {n} files; replan empty")
    return 0


if __name__ == "__main__":
    sys.exit(main())
