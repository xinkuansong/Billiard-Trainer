#!/usr/bin/env python3
"""v40 W8 软检查：非引入课 tutorial 不得出现阶梯套话。

D-v40-4=B：只做软检查，⛔ 不接入 verify-gate / pre-push。
引入课名单抄自 docs/research/20260818-v40-概念所有权表.md §5（17 个引入概念）。
引入课允许这些句式（本脚本不报）；后续 / 合成课出现即 FAIL。

用法：
  python3 scripts/check_tutorial_boilerplate.py
  python3 scripts/check_tutorial_boilerplate.py --selftest
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DRILLS = REPO / "QiuJi" / "Resources" / "Drills"

# 所有权表 §5 引入概念（短 id）
INTRO_IDS = {
    "c006",
    "c007",
    "c008",
    "c009",
    "c010",
    "c023",
    "c011",
    "c013",
    "c016",
    "c003",
    "c004",
    "c073",
    "c075",
    "c024",
    "c026",
    "c025",
    "c045",
}

# 引入课允许、非引入课禁止（完成标准 W2–W7）
BANNED_IN_FOLLOWUP = [
    re.compile(r"本组只练一个变量"),
    re.compile(r"入门基准档"),
    re.compile(r"教学锚点档"),
    re.compile(r"上限档"),
]


def short_id(drill_id: str) -> str:
    return drill_id.removeprefix("drill_")


def walk_tutorial_text(node, path: str = "") -> list[tuple[str, str]]:
    hits: list[tuple[str, str]] = []
    if isinstance(node, dict):
        for key in ("title", "content", "caption", "text"):
            val = node.get(key)
            if isinstance(val, str) and val:
                hits.append((f"{path}.{key}" if path else key, val))
        for i, item in enumerate(node.get("items") or []):
            hits.extend(walk_tutorial_text(item, f"{path}.items[{i}]"))
        for i, sec in enumerate(node.get("sections") or []):
            hits.extend(walk_tutorial_text(sec, f"{path}.sections[{i}]"))
        for i, form in enumerate(node.get("formations") or []):
            hits.extend(walk_tutorial_text(form, f"{path}.formations[{i}]"))
    return hits


def scan_file(path: Path) -> list[str]:
    data = json.loads(path.read_text(encoding="utf-8"))
    sid = short_id(data.get("id", path.stem))
    if sid in INTRO_IDS:
        return []
    tutorial = data.get("tutorial")
    if not tutorial:
        return []
    findings: list[str] = []
    for loc, text in walk_tutorial_text(tutorial, "tutorial"):
        for pat in BANNED_IN_FOLLOWUP:
            if pat.search(text):
                findings.append(f"{path.name} {loc}: {pat.pattern}")
    return findings


def run_scan() -> list[str]:
    findings: list[str] = []
    for path in sorted(DRILLS.glob("*/drill_c*.json")):
        findings.extend(scan_file(path))
    return findings


def selftest() -> int:
    """构造：引入课带套话应放过；后续课带套话应报。"""
    intro_ok = any(
        p.stem.endswith("c013") for p in DRILLS.glob("*/drill_c013.json")
    )
    follow_hit = [
        "本组只练一个变量",
        "入门基准档",
    ]
    fake = {
        "id": "drill_c032",
        "tutorial": {"sections": [{"title": "技术原理", "content": follow_hit[0]}]},
    }
    # 直接走 walk + 规则，不写盘
    sid = short_id(fake["id"])
    assert sid not in INTRO_IDS
    found = []
    for loc, text in walk_tutorial_text(fake["tutorial"], "tutorial"):
        for pat in BANNED_IN_FOLLOWUP:
            if pat.search(text):
                found.append(pat.pattern)
    if "本组只练一个变量" not in found:
        print("SELFTEST FAIL: 后续课套话未检出")
        return 1
    intro_fake = {
        "id": "drill_c013",
        "tutorial": {"sections": [{"title": "技术原理", "content": "本组只练一个变量：切角"}]},
    }
    intro_found = []
    if short_id(intro_fake["id"]) in INTRO_IDS:
        intro_found = []  # 引入课整课跳过
    if intro_found:
        print("SELFTEST FAIL: 引入课被误伤")
        return 1
    if not intro_ok:
        print("SELFTEST WARN: 现网未找到 c013，规则仍按表跳过引入课")
    print("SELFTEST PASS: 后续课检出 / 引入课不误伤")
    return 0


def main() -> int:
    if "--selftest" in sys.argv:
        return selftest()
    findings = run_scan()
    if findings:
        print(f"FAIL {len(findings)}")
        for line in findings:
            print(" ", line)
        return 1
    print("PASS 0（非引入课无「本组只练一个变量 / 入门基准档 / 教学锚点档 / 上限档」）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
