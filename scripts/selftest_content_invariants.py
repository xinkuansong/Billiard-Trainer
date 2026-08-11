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
    Path("QiuJi/Resources/Plans"),
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


def first_formation(data: dict, mode: str | None = None) -> dict:
    for item in data["sets"]["perFormation"]:
        if mode is None or item["mode"] == mode:
            return item
    raise SystemExit(f"该 drill 无 mode={mode} 的球形")


def plan_path(root: Path, plan_id: str) -> Path:
    return root / f"QiuJi/Resources/Plans/{plan_id}.json"


def first_ref(plan: dict, drill_id: str) -> dict:
    for week in plan["weeks"]:
        for session in week["sessions"]:
            for phase in session["phases"]:
                for ref in phase["drills"]:
                    if ref["drillId"] == drill_id:
                        return ref
    raise SystemExit(f"计划内找不到 {drill_id} 的条目")


def case_i6a_token_drift(root: Path) -> None:
    # 球形 token 是计划外键（契约 §6.6）：剂量块改到一个序列里不存在的 token 必须 FAIL。
    edit_json(drill_path(root, "drill_c013"),
              lambda data: first_formation(data).__setitem__("token", "manual99"))


def case_i6a_no_sequence_has_dose(root: Path) -> None:
    # 无序列 drill 按 §5.6.4 只写两个汇总值；硬塞 perFormation ⇒ token 无真源可校。
    def mutate(data: dict) -> None:
        data["sets"]["perFormation"] = [
            {"token": "manual01", "mode": "repetition", "ballsPerRound": 10, "defaultRounds": 4}
        ]
    edit_json(drill_path(root, "drill_c008"), mutate)


def case_i6b_shots_mismatch(root: Path) -> None:
    # sequence 型每轮球数锁死实测杆数（§5.6.2）；改成别的值必须 FAIL。
    # v34 W1 后 c001 已翻转为 repetition，改用仍为 sequence 型的 c039（实测 8 杆）。
    edit_json(drill_path(root, "drill_c039"),
              lambda data: first_formation(data, "sequence").__setitem__("ballsPerRound", 10))


def case_i6b_mode_flip_not_a_dodge(root: Path) -> None:
    # 非法 mode 不得被当成「不是 sequence 就放过」而静默通过。
    edit_json(drill_path(root, "drill_c039"),
              lambda data: first_formation(data, "sequence").__setitem__("mode", "freestyle"))


def _shape_mutate(balls: int, rounds: int, note: str | None):
    """把 drill_c010（repetition 型，序列实测 7 杆）的球形改成指定形状。"""
    def mutate(data: dict) -> None:
        item = first_formation(data, "repetition")
        item["ballsPerRound"] = balls
        item["defaultRounds"] = rounds
        item.pop("doseNote", None)
        if note is not None:
            item["doseNote"] = note
    return mutate


def case_i6b_repetition_band_violation(root: Path) -> None:
    # v34 R13 形状约束：bpr ∉ [8,15] 必须 FAIL（旧规则只 WARN，语义已反转）。
    edit_json(drill_path(root, "drill_c010"), _shape_mutate(7, 7, None))


def case_i6b_repetition_non15_no_note(root: Path) -> None:
    # 带内但非 15 且无 doseNote ⇒ FAIL（R3：例外必须留 note）。
    edit_json(drill_path(root, "drill_c010"), _shape_mutate(12, 7, None))


def case_i6b_repetition_rounds_drift(root: Path) -> None:
    # 轮 = 位置：defaultRounds ≠ 实测杆数且无 doseNote ⇒ FAIL。
    edit_json(drill_path(root, "drill_c010"), _shape_mutate(15, 4, None))


def case_i6b_repetition_note_exempted(root: Path) -> None:
    # 同样的非 15 剂量，但写了 doseNote ⇒ 该球形必须放行（门禁凭 note 豁免）。
    edit_json(drill_path(root, "drill_c010"),
              _shape_mutate(12, 7, "构造性用例：验证 doseNote 豁免"))


def case_i11_unknown_drill(root: Path) -> None:
    path = plan_path(root, "plan_accuracy")

    def mutate(plan: dict) -> None:
        plan["weeks"][0]["sessions"][0]["phases"][0]["drills"][0]["drillId"] = "drill_c900"
    edit_json(path, mutate)


def case_i11_bad_formation_token(root: Path) -> None:
    # 删/改球形 token 会打断按球形引用的计划条目（契约 §6 规则 2 的删除连带）。
    path = plan_path(root, "plan_advanced")
    edit_json(path, lambda plan: first_ref(plan, "drill_c075")["dose"]["formations"][0]
              .__setitem__("token", "manual99"))


def case_i11_dose_both_forms(root: Path) -> None:
    # `roundsPerFormation` 与 `formations` 必须恰好二选一。
    path = plan_path(root, "plan_advanced")
    edit_json(path, lambda plan: first_ref(plan, "drill_c075")["dose"]
              .__setitem__("roundsPerFormation", 3))


def case_i11_rounds_below_default(root: Path) -> None:
    # v34 R9：formations 逐球形轮数不得低于该球形内容 defaultRounds（位置全覆盖）。
    path = plan_path(root, "plan_advanced")
    edit_json(path, lambda plan: first_ref(plan, "drill_c075")["dose"]["formations"][0]
              .__setitem__("rounds", 1))


def case_i11_legacy_volume_keys(root: Path) -> None:
    # v31 W5 删掉 `PlanDrillRef.sets/ballsPerSet` 后，JSON 里再写这两个键
    # 只会被 `JSONDecoder` 静默忽略（哑数据）⇒ 契约 §6.6 要求 I11 阻塞。
    path = plan_path(root, "plan_accuracy")

    def mutate(plan: dict) -> None:
        ref = plan["weeks"][0]["sessions"][0]["phases"][0]["drills"][0]
        ref["sets"] = 3
        ref["ballsPerSet"] = 10
    edit_json(path, mutate)


def case_i10_plan_wrong_type(root: Path) -> None:
    # 计划侧模型也在 I10 覆盖内：解码失败会让整份计划从列表里消失。
    edit_json(plan_path(root, "plan_beginner"),
              lambda plan: plan.__setitem__("minutesPerSession", "60 分钟"))


def case_i10_per_formation_wrong_type(root: Path) -> None:
    # v31 W4 之前 `perFormation` 不在 MODEL_SPEC 里，检查器忽略未知键 ⇒ 这是盲区。
    edit_json(drill_path(root, "drill_c001"),
              lambda data: first_formation(data).__setitem__("ballsPerRound", "五"))


def case_i10_secondary_categories_wrong_type(root: Path) -> None:
    edit_json(drill_path(root, "drill_c020"),
              lambda data: data.__setitem__("secondaryCategories", "positioning"))


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
    "i10_per_formation_wrong_type": ("I10", "drill_c001 perFormation.ballsPerRound 改成字符串",
                                     case_i10_per_formation_wrong_type, 1,
                                     "typeMismatch 期望 int"),
    "i10_secondary_categories_wrong_type": ("I10", "drill_c020 secondaryCategories 由数组改成字符串",
                                            case_i10_secondary_categories_wrong_type, 1,
                                            "typeMismatch 期望数组"),
    "i10_plan_wrong_type": ("I10", "plan_beginner minutesPerSession 由 Int 改成字符串",
                            case_i10_plan_wrong_type, 1, "typeMismatch 期望 int"),
    "i6a_token_drift": ("I6a", "drill_c013 剂量 token 改成序列里没有的 manual99",
                        case_i6a_token_drift, 1, "✗ drill_c013"),
    "i6a_no_sequence_has_dose": ("I6a", "无序列的 drill_c008 硬塞 perFormation",
                                 case_i6a_no_sequence_has_dose, 1, "无序列却写了 perFormation"),
    "i6b_shots_mismatch": ("I6b", "drill_c039 sequence 型 ballsPerRound 8 → 10（实测 8 杆）",
                           case_i6b_shots_mismatch, 1, "✗ drill_c039/manual01"),
    "i6b_mode_flip_not_a_dodge": ("I6b", "drill_c039 mode 改成非法值 freestyle",
                                  case_i6b_mode_flip_not_a_dodge, 1, "非法 mode"),
    "i6b_repetition_band_violation": ("I6b", "drill_c010 repetition 型 bpr 改 7（带外，v34 R13）",
                                      case_i6b_repetition_band_violation, 1,
                                      "ballsPerRound=7 超出形状约束 8–15"),
    "i6b_repetition_non15_no_note": ("I6b", "drill_c010 repetition 型 bpr 改 12 且无 doseNote",
                                     case_i6b_repetition_non15_no_note, 1,
                                     "ballsPerRound=12 ≠ 15 且无 doseNote"),
    "i6b_repetition_rounds_drift": ("I6b", "drill_c010 repetition 型 defaultRounds 改 4（实测 7 杆）",
                                    case_i6b_repetition_rounds_drift, 1,
                                    "defaultRounds=4 ≠ 实测杆数 7"),
    "i6b_repetition_note_exempted": ("I6b", "同 bpr=12 但写 doseNote ⇒ 该球形应放行",
                                     case_i6b_repetition_note_exempted, None,
                                     "!✗ drill_c010/manual01"),
    "i11_unknown_drill": ("I11", "plan_accuracy 首条目 drillId 改成未登记的 drill_c900",
                          case_i11_unknown_drill, 1, "不在 index.json"),
    "i11_bad_formation_token": ("I11", "plan_advanced 的 c075 按球形引用改指 manual99",
                                case_i11_bad_formation_token, 1, "manual99"),
    "i11_dose_both_forms": ("I11", "plan_advanced 的 c075 同时写 roundsPerFormation 与 formations",
                            case_i11_dose_both_forms, 1, "未恰好二选一"),
    "i11_legacy_volume_keys": ("I11", "plan_accuracy 首条目补写已删除的旧格式 sets/ballsPerSet",
                               case_i11_legacy_volume_keys, 1, "仍残留旧格式 sets/ballsPerSet"),
    "i11_rounds_below_default": ("I11", "plan_advanced 的 c075 逐球形轮数改 1（低于内容 defaultRounds）",
                                 case_i11_rounds_below_default, 1, "低于内容 defaultRounds"),
    "baseline_clean": ("I5 I6a I6b I7 I8 I9 I10 I11", "未做任何改动的影子库（对照组）",
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
    # want_code 为 None = 不校验退出码（用于「该目标不得再报错」的负向用例，
    # 全库其他 drill 的状态不影响判定）；want_text 以 "!" 开头 = 断言片段**不出现**。
    code_ok = want_code is None or proc.returncode == want_code
    text_ok = (want_text[1:] not in output) if want_text.startswith("!") \
        else (want_text in output)
    passed = code_ok and text_ok

    print("=" * 72)
    print(f"用例 {name}  [{check}]  {desc}")
    print(f"命令：{' '.join(cmd)}")
    print(output.rstrip())
    code_desc = "退出码不限" if want_code is None else f"退出码 {want_code}"
    text_desc = (f"输出不含 {want_text[1:]!r}" if want_text.startswith("!")
                 else f"输出含 {want_text!r}")
    print(f"期望：{code_desc} 且 {text_desc}；实测退出码 {proc.returncode}")
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
