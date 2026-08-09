#!/usr/bin/env python3
"""进度文档体积门禁（2026-08-09 上下文瘦身后加装）。

背景：tasks/PROGRESS.md 曾膨胀到 353 KB、hub 状态卡 322 KB，每次会话启动
必读它们导致上下文开销失控。2026-08-09 已归档瘦身并在
.cursor/rules/00-orchestrator.mdc / 00-project-hub-sync.mdc 写入滚动归档纪律
（滚动区只留最近 10 条，超出移入归档文件）。本脚本把该纪律变成机器门禁，
防止再次失守。

检查项（任一不过即退出码 1）：
  S1  tasks/PROGRESS.md 总体积 ≤ SIZE_LIMIT，且「## 当前状态」区顶级条目 ≤ ENTRY_LIMIT
  S2  hub 状态卡（另一仓库，路径不存在时跳过并提示）总体积 ≤ SIZE_LIMIT，
      且「## 最近完成」区顶级条目 ≤ ENTRY_LIMIT

超限处置：把滚动区最旧条目移入对应归档文件（见各文件区头说明），
⛔ 禁止直接上调本脚本阈值来放行。

用法：python3 scripts/verify_doc_size.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

SIZE_LIMIT = 100 * 1024  # bytes
ENTRY_LIMIT = 12  # 纪律是 10 条，留 2 条缓冲避免每次追加都报警

# (标签, 文件路径, 滚动区标题, 归档文件提示)
TARGETS = [
    (
        "S1 PROGRESS",
        REPO_ROOT / "tasks" / "PROGRESS.md",
        "## 当前状态",
        "tasks/archive/PROGRESS-当前状态-归档.md",
    ),
    (
        "S2 hub状态卡",
        Path("/Users/song/projects/project-hub/projects/13.billiard_trainer.md"),
        "## 最近完成",
        "project-hub/projects/archive/13.billiard_trainer-历史.md",
    ),
]


def count_section_entries(text: str, section_title: str) -> int | None:
    """统计指定二级标题区内的顶级列表条目数；找不到该区返回 None。"""
    lines = text.splitlines()
    start = None
    for i, line in enumerate(lines):
        if line.strip() == section_title:
            start = i + 1
            break
    if start is None:
        return None
    count = 0
    for line in lines[start:]:
        if line.startswith("## "):
            break
        if re.match(r"^- ", line):
            count += 1
    return count


def main() -> int:
    failures = []
    for label, path, section, archive_hint in TARGETS:
        if not path.exists():
            print(f"  ⚠ {label}: 文件不存在，跳过（{path}）")
            continue
        size = path.stat().st_size
        text = path.read_text(encoding="utf-8")
        entries = count_section_entries(text, section)

        problems = []
        if size > SIZE_LIMIT:
            problems.append(f"体积 {size / 1024:.0f} KB > 上限 {SIZE_LIMIT // 1024} KB")
        if entries is None:
            problems.append(f"找不到滚动区标题「{section}」（区名被改动？同步更新本脚本）")
        elif entries > ENTRY_LIMIT:
            problems.append(f"「{section}」区 {entries} 条 > 上限 {ENTRY_LIMIT} 条")

        if problems:
            failures.append(label)
            print(f"  ✗ {label}: {'；'.join(problems)}")
            print(f"      → 把最旧条目移入 {archive_hint}（禁止上调阈值放行）")
        else:
            print(
                f"  ✓ {label}: {size / 1024:.0f} KB / "
                f"「{section.lstrip('# ')}」{entries} 条"
            )

    if failures:
        print(f"\n⛔ 进度文档体积门禁未通过：{', '.join(failures)}")
        return 1
    print("✅ 进度文档体积门禁通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
