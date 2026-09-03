#!/usr/bin/env python3
"""Inventory test write behavior and capture a non-destructive v50 baseline."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


WRITE_PATTERNS = {
    "data_write": re.compile(r"\.write\s*\("),
    "create_directory": re.compile(r"FileManager\.default\.createDirectory"),
    "remove_item": re.compile(r"FileManager\.default\.removeItem"),
    "copy_item": re.compile(r"FileManager\.default\.copyItem"),
    "move_item": re.compile(r"FileManager\.default\.moveItem"),
}
ABSOLUTE_PATH = re.compile(r'"(/(?:Users|tmp|private/tmp)/[^"\\]*(?:\\.[^"\\]*)*)"')
TRACKED_DESTINATION_MARKERS = (
    "/QiuJi/Resources/",
    "/docs/",
    "/content/",
    "/tasks/",
)


def run(repo: Path, *command: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=repo,
        text=True,
        capture_output=True,
        check=check,
    )


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def classify_file(repo: Path, path: Path) -> dict[str, object] | None:
    text = path.read_text(encoding="utf-8", errors="replace")
    matched = [name for name, pattern in WRITE_PATTERNS.items() if pattern.search(text)]
    if not matched:
        return None

    absolute_paths = sorted(set(ABSOLUTE_PATH.findall(text)))
    has_gate = "BakeRunnerGate.skipUnlessEnabled" in text or "XCTSkipUnless" in text
    tracked_destination = any(
        marker in literal and "/build/" not in literal
        for literal in absolute_paths
        for marker in TRACKED_DESTINATION_MARKERS
    )
    legacy_worktree = any(
        "/Users/song/projects/13.billiard_trainer" in literal
        and not literal.startswith(str(repo / "build"))
        for literal in absolute_paths
    )
    build_or_tmp_only = bool(absolute_paths) and all(
        literal.startswith(str(repo / "build"))
        or literal.startswith("/tmp/")
        or literal.startswith("/private/tmp/")
        for literal in absolute_paths
    )

    if has_gate and tracked_destination:
        classification = "gated_tracked_resource_runner"
    elif has_gate:
        classification = "gated_writer_runner"
    elif tracked_destination:
        classification = "tracked_repository_destination"
    elif legacy_worktree:
        classification = "legacy_absolute_repository_path"
    elif build_or_tmp_only:
        classification = "build_or_tmp_artifact"
    elif absolute_paths:
        classification = "external_or_simulator_absolute_path"
    else:
        classification = "sandbox_or_app_container_write"

    return {
        "file": path.relative_to(repo).as_posix(),
        "target": "QiuJiUITests" if "QiuJiUITests" in path.parts else "QiuJiTests",
        "write_apis": matched,
        "absolute_paths": absolute_paths,
        "has_explicit_skip_gate": has_gate,
        "classification": classification,
        "safe_default_decision": (
            "gate_must_remain_closed"
            if classification.startswith("gated_")
            else "exclude_until_parameterized"
            if classification in {
                "tracked_repository_destination",
                "legacy_absolute_repository_path",
                "external_or_simulator_absolute_path",
            }
            else "isolated_artifact_or_container"
        ),
    }


def capture_baseline(repo: Path) -> dict[str, object]:
    status_lines = run(repo, "git", "status", "--porcelain=v1", "--untracked-files=all").stdout.splitlines()
    dirty_tracked = run(repo, "git", "diff", "--name-only").stdout.splitlines()
    staged = run(repo, "git", "diff", "--cached", "--name-only").stdout.splitlines()
    tracked_hashes = {
        relative: sha256(repo / relative)
        for relative in sorted(set(dirty_tracked + staged))
        if (repo / relative).is_file()
    }
    disk = shutil.disk_usage(repo)
    simulator = run(repo, "xcrun", "simctl", "list", "-j", "runtimes", "devices")
    return {
        "captured_at": datetime.now(timezone.utc).isoformat(),
        "repo": str(repo),
        "branch": run(repo, "git", "status", "--short", "--branch").stdout.splitlines()[0],
        "status": status_lines,
        "dirty_tracked_sha256": tracked_hashes,
        "xcode_version": run(repo, "xcodebuild", "-version").stdout.splitlines(),
        "simulator_inventory": json.loads(simulator.stdout),
        "disk_bytes": {"total": disk.total, "used": disk.used, "free": disk.free},
    }


def markdown_inventory(entries: list[dict[str, object]], scheme_targets: list[str]) -> str:
    counts = Counter(str(entry["classification"]) for entry in entries)
    lines = [
        "# v50 W0 写盘测试盘点",
        "",
        f"> 生成时间：{datetime.now(timezone.utc).isoformat()}；命中 Swift 文件：{len(entries)}。",
        f"> 默认 QiuJi scheme 测试目标：{', '.join(scheme_targets)}。",
        "",
        "## 分类汇总",
        "",
        "| 分类 | 文件数 | 默认决策 |",
        "|---|---:|---|",
    ]
    decisions = {
        "gated_tracked_resource_runner": "确认 gate 关闭后可随目标加载；不得执行 runner 本体",
        "gated_writer_runner": "确认 gate 关闭后可随目标加载；不得显式打开 runner",
        "tracked_repository_destination": "从常规回归排除，直到输出重定向到 build/tmp",
        "legacy_absolute_repository_path": "从矩阵回归排除，进入本轮时先参数化",
        "external_or_simulator_absolute_path": "逐项确认目标后才纳入",
        "build_or_tmp_artifact": "可纳入；每次使用独立叶子目录",
        "sandbox_or_app_container_write": "可纳入；依赖测试/模拟器容器隔离",
    }
    for classification in sorted(counts):
        lines.append(f"| `{classification}` | {counts[classification]} | {decisions[classification]} |")

    lines.extend(["", "## 全量文件", "", "| 文件 | Target | 分类 | Gate | 绝对路径数 |", "|---|---|---|---:|---:|"])
    for entry in entries:
        lines.append(
            f"| `{entry['file']}` | {entry['target']} | `{entry['classification']}` | "
            f"{'是' if entry['has_explicit_skip_gate'] else '否'} | {len(entry['absolute_paths'])} |"
        )
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    repo = Path(__file__).resolve().parents[1]
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)

    entries = []
    for root_name in ("QiuJiTests", "QiuJiUITests"):
        for path in sorted((repo / root_name).rglob("*.swift")):
            classified = classify_file(repo, path)
            if classified:
                entries.append(classified)

    scheme_text = (repo / "QiuJi.xcodeproj/xcshareddata/xcschemes/QiuJi.xcscheme").read_text()
    scheme_targets = [target for target in ("QiuJiTests", "QiuJiUITests") if target in scheme_text]
    inventory = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "scheme_targets": scheme_targets,
        "matched_files": len(entries),
        "classifications": dict(sorted(Counter(str(e["classification"]) for e in entries).items())),
        "entries": entries,
    }

    (output / "write-test-inventory.json").write_text(
        json.dumps(inventory, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    (output / "write-test-inventory.md").write_text(
        markdown_inventory(entries, scheme_targets),
        encoding="utf-8",
    )
    (output / "workspace-baseline.json").write_text(
        json.dumps(capture_baseline(repo), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps({"matched_files": len(entries), "classifications": inventory["classifications"]}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
