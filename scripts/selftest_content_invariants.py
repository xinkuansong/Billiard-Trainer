#!/usr/bin/env python3
"""
selftest_content_invariants.py — 内容不变量检查的构造性用例（v29 W9）

每个用例在 `build/w9-fixtures/<case>/` 里搭一个**只读符号链接 + 小目录真副本**的
影子内容库，故意制造一处不一致，再跑 `verify_tutorial_sync.py --root <fixture>`，
断言它**确实报错**（而不是永远 PASS 的空壳）。真源目录全程只读，零污染。

用法：
  python3 scripts/selftest_content_invariants.py
  python3 scripts/selftest_content_invariants.py --case i5_new_bad_token --keep

退出码：全部用例符合预期为 0，任一不符为 1。
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "scripts" / "verify_tutorial_sync.py"
BASELINES = REPO_ROOT / "scripts" / "content_invariant_baselines.json"
FIXTURE_ROOT = REPO_ROOT / "build" / "w9-fixtures"

# 影子库里必须是真副本的目录（用例要改它们）与只能符号链接的目录（4.7G / 8.5G）。
COPY_DIRS = [
    Path("QiuJi/Resources/Drills"),
    Path("QiuJi/Resources/DrillBoards"),
    Path("content/position_play/sequences"),
    Path("content/drill_profiles"),
]
LINK_DIRS = [
    Path("QiuJi/Resources/DrillTutorials"),
    Path("build/position_play_export"),
]


def build_fixture(case: str) -> Path:
    root = FIXTURE_ROOT / case
    if root.exists():
        shutil.rmtree(root)
    for rel in COPY_DIRS:
        (root / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(REPO_ROOT / rel, root / rel)
    for rel in LINK_DIRS:
        (root / rel).parent.mkdir(parents=True, exist_ok=True)
        (root / rel).symlink_to(REPO_ROOT / rel)
    return root


def edit_json(path: Path, mutate) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))
    mutate(data)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def drill_path(root: Path, drill_id: str) -> Path:
    hits = [p for p in (root / "QiuJi/Resources/Drills").rglob(f"{drill_id}.json")]
    if not hits:
        raise SystemExit(f"fixture 内找不到 {drill_id}.json")
    return hits[0]


def retarget_first_image(root: Path, drill_id: str, new_stem: str) -> None:
    """把该 drill 第一处 image 引用改成 new_stem（用于制造坏 token / 失效引用）。"""

    def mutate(data: dict) -> None:
        tutorial = data["tutorial"]
        buckets = [tutorial.get("sections") or []]
        buckets += [form.get("sections") or [] for form in (tutorial.get("formations") or [])]
        for sections in buckets:
            for section in sections:
                if isinstance(section, dict) and section.get("image"):
                    section["image"] = new_stem
                    return
        raise SystemExit(f"{drill_id} 无 image 引用可改")

    edit_json(drill_path(root, drill_id), mutate)


# ── 用例 ────────────────────────────────────────────────────────────────
# 每个用例：(检查项, 变更说明, 变更函数, 期望退出码, 期望输出里出现的片段)

def case_i5_new_bad_token(root: Path) -> None:
    retarget_first_image(root, "drill_c001", "drill_c001_manual99_s01")


def case_i5_exempt_drift(root: Path) -> None:
    # 已豁免的 legacy drill 里出现清单之外的新坏 token：豁免不得变成通行证。
    retarget_first_image(root, "drill_c005", "drill_c005_f9_s01")


def case_i7_new_mismatch(root: Path) -> None:
    # v26 W0 后源 profile 已标 retired；本用例要验证「未退役的不一致」仍 FAIL，
    # 故显式摘掉 retired 再改 formation id。
    def mutate(data: dict) -> None:
        data.pop("retired", None)
        if str(data.get("status", "")).strip().lower() in {"retired", "deprecated"}:
            data.pop("status", None)
        for form in data["formations"]:
            form["id"] = form["id"].replace("A", "B")
    edit_json(root / "content/drill_profiles/drill_c073.profile.json", mutate)


def case_i7_retired_tolerated(root: Path) -> None:
    # 与上一例同样的不一致，但按契约 §1.1 标记退役 ⇒ 必须放行。
    def mutate(data: dict) -> None:
        for form in data["formations"]:
            form["id"] = form["id"].replace("A", "B")
        data["retired"] = True
    edit_json(root / "content/drill_profiles/drill_c073.profile.json", mutate)


def case_i8_orphan_board(root: Path) -> None:
    board = root / "QiuJi/Resources/DrillBoards/drill_c999__manual01-伪造球形-1杆.json"
    board.write_text('{"id":"fake"}\n', encoding="utf-8")


def case_i8_hand_edited_board(root: Path) -> None:
    board = next((root / "QiuJi/Resources/DrillBoards").glob("drill_c001__*.json"))
    edit_json(board, lambda data: data.__setitem__("name", "手改产物"))


def case_i9_unregistered_drill(root: Path) -> None:
    index = root / "QiuJi/Resources/Drills/index.json"
    edit_json(index, lambda data: data["categories"][0]["drills"].append("drill_c900"))


def case_i10_missing_required_field(root: Path) -> None:
    # 复刻 FL-029 的原始形态：formation 缺 `id` ⇒ Swift 侧 keyNotFound。
    def mutate(data: dict) -> None:
        data["tutorial"]["formations"][0].pop("id")
    edit_json(drill_path(root, "drill_c073"), mutate)


def case_i10_wrong_type(root: Path) -> None:
    # 类型不符同样会让 JSONDecoder 抛错，不只是缺键。
    edit_json(drill_path(root, "drill_c001"),
              lambda data: data.__setitem__("difficulty", "三星"))


def case_i10_optional_content_absent(root: Path) -> None:
    # v30 X-1 放宽后：纯 items 节省略 `content` 必须放行（防止把放宽又改回必填）。
    def mutate(data: dict) -> None:
        for section in data["tutorial"]["sections"]:
            section.pop("content", None)
    edit_json(drill_path(root, "drill_c001"), mutate)


def case_c3_dead_ratchet(root: Path) -> None:
    # 新增 1 处失效引用 ⇒ 失效数 35 > 基线 34，棘轮必须报警。
    retarget_first_image(root, "drill_c011", "drill_c011_不存在的图")


CASES = {
    "i5_new_bad_token": ("I5", "drill_c001 精讲 image 改指不存在的 token manual99",
                         case_i5_new_bad_token, 1, "✗ drill_c001"),
    "i5_exempt_drift": ("I5", "已豁免的 drill_c005 出现清单外新坏 token f9",
                        case_i5_exempt_drift, 1, "✗ drill_c005"),
    "i7_new_mismatch": ("I7", "drill_c073 profile formation id 改为 B1–B4（未标退役）",
                        case_i7_new_mismatch, 1, "✗ drill_c073"),
    "i7_retired_tolerated": ("I7", "同上不一致但加 retired:true ⇒ 应放行",
                             case_i7_retired_tolerated, 0, "已标记退役"),
    "i8_orphan_board": ("I8", "DrillBoards 里塞一个上游不存在的球形文件",
                        case_i8_orphan_board, 1, "Bundle 有、上游无"),
    "i8_hand_edited_board": ("I8", "手改一个 DrillBoards 产物内容",
                             case_i8_hand_edited_board, 1, "内容与上游序列不一致"),
    "i9_unregistered_drill": ("I9", "index.json 登记一个无序列的 drill_c900",
                              case_i9_unregistered_drill, 1, "✗ drill_c900"),
    "c3_dead_ratchet": ("C3", "新增 1 处失效 image 引用（34 → 35）",
                        case_c3_dead_ratchet, 1, "基线被突破"),
    "i10_missing_required_field": ("I10", "drill_c073 formation 去掉必填 id（复刻 FL-029）",
                                   case_i10_missing_required_field, 1, "keyNotFound 'id'"),
    "i10_wrong_type": ("I10", "drill_c001 difficulty 由 Int 改成字符串",
                       case_i10_wrong_type, 1, "typeMismatch 期望 int"),
    "i10_optional_content_absent": ("I10", "drill_c001 各节省略可选 content ⇒ 应放行",
                                    case_i10_optional_content_absent, 0, "总计 FAIL: 0"),
    "baseline_clean": ("I5 I7 I8 I9 I10", "未做任何改动的影子库（对照组）",
                       lambda root: None, 0, "总计 FAIL: 0"),
}


def run_case(name: str, keep: bool) -> bool:
    check, desc, mutate, want_code, want_text = CASES[name]
    root = build_fixture(name)
    mutate(root)
    cmd = [sys.executable, str(SCRIPT), "--root", str(root),
           "--baselines", str(BASELINES), "--only", *check.split()]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    output = proc.stdout + proc.stderr
    passed = proc.returncode == want_code and want_text in output

    print("=" * 72)
    print(f"用例 {name}  [{check}]  {desc}")
    print(f"命令：{' '.join(cmd)}")
    print(output.rstrip())
    print(f"期望：退出码 {want_code} 且输出含 {want_text!r}；实测退出码 {proc.returncode}")
    print(f"结果：{'PASS —— 检查确实报错/放行如预期' if passed else 'FAIL —— 检查行为不符预期'}")
    if not keep:
        shutil.rmtree(root, ignore_errors=True)
    return passed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--case", nargs="+", choices=sorted(CASES), help="只跑指定用例")
    parser.add_argument("--keep", action="store_true", help="保留 fixture 目录便于人工复核")
    args = parser.parse_args()

    FIXTURE_ROOT.mkdir(parents=True, exist_ok=True)
    names = args.case or sorted(CASES)
    outcomes = {name: run_case(name, args.keep) for name in names}
    bad = [name for name, ok in outcomes.items() if not ok]
    print("=" * 72)
    print(f"构造性用例：{len(outcomes) - len(bad)}/{len(outcomes)} 符合预期")
    for name in bad:
        print(f"  ✗ {name}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
