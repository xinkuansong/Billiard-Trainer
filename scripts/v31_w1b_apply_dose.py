#!/usr/bin/env python3
"""v31 W1b：把剂量口径（§5.6）与副分类（§3.3）写入本批 40 条 drill JSON。

**只动两处**：`sets`（整块重写）与 `secondaryCategories`（新增/删除）。其它字段一律原样。
JSON 以 `indent=2` + 尾换行序列化（尾换行随原文件），见 --check-roundtrip。

决策表 `DECISIONS`：每条 drill 给出**按序列文件排序顺序**的逐球形 (mode, ballsPerRound, rounds)。
- token 不在表里手抄，一律由脚本从 `content/position_play/sequences/*.json` 取（FL 红线）；
  表只按位置对齐，数量不符即报错退出。
- `mode == sequence` 时 `ballsPerRound` 必须写 None，由脚本填**实测杆数**（`len(steps)`，I6b 锁死）。
- 判定依据（R7 人工逐条）见 `REASONS`，与 build/v31-w1b-logs/form-evidence.md、
  cue-continuity-probe.log 一一对应。

用法：
  python3 scripts/v31_w1b_apply_dose.py --check-roundtrip
  python3 scripts/v31_w1b_apply_dose.py --dry-run
  python3 scripts/v31_w1b_apply_dose.py --apply
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DRILLS_DIR = REPO / "QiuJi" / "Resources" / "Drills"
SEQ_DIR = REPO / "content" / "position_play" / "sequences"

SEQ = "sequence"
REP = "repetition"

# drillId -> [(mode, ballsPerRound|None, defaultRounds), ...]（按序列文件名排序顺序）
DECISIONS: dict[str, list[tuple[str, int | None, int]]] = {
    # ---- separation（专项类，R2 基准 4~5×10）----
    "drill_c024": [(REP, 10, 1), (REP, 10, 4)],
    "drill_c025": [(REP, 10, 2), (REP, 10, 2)],
    "drill_c026": [(REP, 10, 2), (REP, 10, 1), (REP, 10, 1)],
    "drill_c027": [(REP, 10, 5)],
    "drill_c028": [(REP, 10, 5)],
    "drill_c029": [(REP, 10, 5)],
    "drill_c030": [(REP, 10, 5)],
    "drill_c031": [(REP, 13, 4)],
    "drill_c083": [(REP, 10, 5)],
    "drill_c084": [(REP, 10, 5)],
    # ---- positioning ----
    "drill_c005": [(REP, 10, 5)],
    "drill_c034": [(REP, 10, 5)],
    "drill_c035": [(REP, 10, 5)],
    "drill_c036": [(REP, 10, 5)],
    "drill_c037": [(REP, 10, 5)],
    "drill_c038": [(REP, 12, 4)],
    "drill_c039": [(SEQ, None, 7)],
    "drill_c040": [(REP, 10, 5)],
    "drill_c041": [(REP, 12, 4)],
    "drill_c042": [(REP, 10, 2), (SEQ, None, 5)],
    "drill_c079": [(SEQ, None, 10)],
    "drill_c080": [(REP, 10, 5)],
    "drill_c081": [(SEQ, None, 10)],
    "drill_c082": [(SEQ, None, 5)],
    # ---- specialShots ----
    "drill_c054": [(REP, 10, 5)],
    "drill_c055": [(REP, 10, 5)],
    "drill_c056": [(REP, 10, 2), (REP, 10, 1), (REP, 10, 1)],
    "drill_c057": [(REP, 10, 2), (REP, 10, 1), (REP, 10, 1)],
    "drill_c058": [(REP, 10, 2), (REP, 10, 2)],
    "drill_c059": [],  # 无序列，§5.6.4 豁免
    "drill_c060": [(REP, 10, 5)],
    "drill_c061": [],  # 无序列，§5.6.4 豁免
    # ---- combined（按局/按次，R2 单独评估、护栏可豁免）----
    "drill_c064": [(SEQ, None, 15)],
    "drill_c065": [],  # 无序列
    "drill_c066": [(REP, 10, 1)],  # 0 杆序列（仅摆球），按次计量
    "drill_c067": [],  # 无序列
    "drill_c068": [],  # 无序列
    "drill_c069": [(REP, 10, 2), (SEQ, None, 3)],
    "drill_c070": [],  # 无序列
    "drill_c071": [(REP, 10, 2), (SEQ, None, 2)],
}

# 无序列 drill 的人工定量（§5.6.4），(defaultSets, defaultBallsPerSet)
NO_SEQ_TOTALS: dict[str, tuple[int, int]] = {
    "drill_c059": (4, 10),
    "drill_c061": (5, 10),
    "drill_c065": (10, 8),
    "drill_c067": (10, 9),
    "drill_c068": (10, 5),
    "drill_c070": (10, 8),
}

# 总量护栏（40–60 球）豁免（§5.6.3：综合类按局/按次单独评估，逐条附理由）
GUARDRAIL_EXEMPT: dict[str, str] = {
    "drill_c065": "按**局**计量：10 局 × 每局 8 颗（己方 7 颗 + 黑八，2026-08-09 用户裁定与 c070 口径对齐）= 80，"
                  "单局本身即一盘完整清台，时长远超同球数的单杆练习",
    "drill_c066": "按**次**计量：开球 10 次为一轮；单次开球需重新架球堆，摆球成本远高于击球本身",
    "drill_c067": "按**局**计量：10 局 × 1–9 号 9 颗 = 90，单局为完整顺序清台",
    "drill_c070": "按**次**计量：10 次 × 己方 7 颗 + 黑八 = 80，单次为开球到黑八的完整流程",
}

# 副分类（R1 / §3.3，每条 ≤1 个；只影响浏览筛选）
SECONDARY: dict[str, str] = {
    "drill_c030": "positioning",
    "drill_c031": "positioning",
    "drill_c042": "combined",
    "drill_c069": "positioning",
    "drill_c071": "positioning",
    "drill_c082": "combined",
}

REASONS: dict[str, str] = {
    # ---- separation ----
    "drill_c024": "desc 明写「每杆独立重置，不是连续清台」+ cp3「不要当成连打走位链」→ 两球形均 repetition；球形1 为单杆概念示范给 1 轮，球形2 是 6 档主阶梯给 4 轮 = 50",
    "drill_c025": "criteria「球形1：6 档各进至少一次；球形2：7 档各进至少一次」→ 均 repetition；双球形各 2 轮×10 = 40",
    "drill_c026": "criteria 三球形分别为 5 档近直线 / 7 档力度 / 5 档杆法，cp3「球形3用来对照」→ 均 repetition；主球形 2 轮 + 两对照球形各 1 轮 = 40",
    "drill_c027": "desc「同一条约 13° 线路反复打…只把打点从中杆抬到纯高杆」+ criteria「4 档杆法各进至少一次」→ repetition；5×10=50",
    "drill_c028": "同 c027 对称（4 档低杆）→ repetition；5×10=50",
    "drill_c029": "criteria「6 档各进至少一次」+ cp3「每档独立重置」→ repetition；5×10=50",
    "drill_c030": "criteria「5 档各将 1 号打进至少一次」+ cp3「每档独立重置…不要连打清台」→ repetition；5×10=50",
    "drill_c031": "criteria「10球中4球进袋」；序列实测第 2–13 杆母球起点**完全相同**(0.535,0.153)（cue-continuity-probe.log）→ 13 档独立目录 repetition；13 档在 10–15 带内故 bpr 取 13（一轮走完一趟），4 轮 = 52",
    "drill_c083": "criteria「沿参考球列逐颗尝试，能连续三颗…碰到即达标」→ 8 档独立目录 repetition；5×10=50",
    "drill_c084": "criteria「沿参考球列逐档击打…命中过半」→ repetition；5×10=50",
    # ---- positioning ----
    "drill_c005": "⚠️ desc 称「四杆连续一库走位」，但序列实测四杆母球起点互不衔接（杆1后(0.414,0.070) vs 杆2前(0.157,0.357)，位移 0.385 等）→ 实为 4 档独立示范，按契约 §1.1 推论 4「与序列冲突以序列为准」判 repetition；5×10=50",
    "drill_c034": "desc 明写「五档独立重置」→ repetition；5×10=50",
    "drill_c035": "⚠️ desc 称「八杆高杆一库走位链」，但序列实测杆 4/5/6 起点完全相同(0.310,0.329)、杆 7/8 起点完全相同(0.457,0.298)，链上不可能出现重复起点 → 判 repetition（8 档变式目录）；5×10=50",
    "drill_c036": "⚠️ 同 c035：desc 称「九杆低杆一库走位链」，实测杆 4/5/6 起点相同(0.324,0.175)、杆 8/9 起点相同(0.464,0.417) → 判 repetition；5×10=50",
    "drill_c037": "desc 明写「三档独立重置」→ repetition；5×10=50",
    "drill_c038": "desc 明写「十二档独立两库走位目录」→ repetition；12 档在带内故 bpr 12（一轮一趟），4 轮 = 48",
    "drill_c039": "走位链：desc「八球直线组合走位链：1→2→…→8 依次进袋」+ criteria「按序完成八杆」；实测母球逐杆位移全 0.0000、台上球 8→1 递减 → sequence，每轮锁 8 杆；7 轮 = 56",
    "drill_c040": "desc 明写「十档独立三库走位阶梯」→ repetition；10 档 bpr 10，5 轮 = 50",
    "drill_c041": "desc 明写「十二档独立对角走位目录」→ repetition；bpr 12、4 轮 = 48",
    "drill_c042": "球形1「8 种母球起点」实测起点各异 → repetition（bpr 10，2 轮）；球形2 criteria「按序完成五杆连续进袋」+ 实测位移全 0.0000、台上球 5→1 → sequence 锁 5 杆、5 轮；合计 45",
    "drill_c079": "criteria「十组中至少五组按顺序把四颗球全部打进」+ 实测位移全 0.0000、台上球 4→1 → sequence 锁 4 杆；轮数取 criteria 明写的 10 组 = 40（落护栏下界，优先贴内容口径）",
    "drill_c080": "criteria「每条线路各打一组…能说出两条线路的落点差别」→ 线路变式目录 repetition。⚠️ 机械连续性显示位移 0.0000，但那是录制时母球未复位的残留（W1a 教训），语义为准；5×10=50",
    "drill_c081": "criteria「十组中至少五组把四颗球全部打进同一个袋」+ 实测位移全 0.0000、台上球 4→1 → sequence 锁 4 杆；10 轮 = 40",
    "drill_c082": "desc「六个来回十二杆为一组」+ criteria「五组中至少一组完成六个来回」+ 实测位移全 0.0000（8 号复位造成台上球数锯齿）→ sequence 锁 12 杆；轮数取 criteria 的 5 组 = 60",
    # ---- specialShots ----
    "drill_c054": "desc「五档母球起点…只扫一个变量」+ criteria「10 次翻袋中至少 4 次」→ repetition；5×10=50",
    "drill_c055": "同 c054（五档起点，翻中袋）→ repetition；5×10=50",
    "drill_c056": "desc「三形单杆」→ 三球形各为独立单杆变式，均 repetition；criteria「10 次中至少 4 次」故 bpr 10；主球形 2 轮 + 两变式各 1 轮 = 40",
    "drill_c057": "desc「三形单杆」→ 同 c056；bpr 10，2/1/1 轮 = 40",
    "drill_c058": "desc「两形单杆…两形只微调贴库球相对库边/袋口的位置」→ 均 repetition；bpr 10，各 2 轮 = 40",
    "drill_c059": "无序列（§8.5/§5.6.4 豁免，物理引擎不支持腾空）；criteria「10 次中至少 3 次」故每组 10 次；跳球对台布与手感消耗大，取 4 组 = 40（护栏下界）",
    "drill_c060": "⚠️ v33 新录 8 杆序列，但实测各杆盘面互不相同（台上球数 3,3,1,5,3,4,3,2）、母球起点跨半台跳变（最大位移 0.894）→ 是 8 个独立安全球场景而非走位链，判 repetition；criteria「10 次安全球」故 bpr 10，5 轮 = 50",
    "drill_c061": "无序列（§8.5/§5.6.4 豁免，成功判据非进袋）；criteria「10 次解球中至少 7 次」故每组 10 次；解球单杆耗时短，取 5 组 = 50",
    # ---- combined ----
    "drill_c064": "走位链：desc「练的是两步走位链」+ criteria「按示范顺序三球连续进袋」+ 实测位移全 0.0000、台上球 3→1 → sequence 锁 3 杆。criteria 的「10 组」只有 30 球，低于护栏下限，按 §5.6.3 上调到 15 轮 = 45",
    "drill_c065": "无序列（§8.5）；按**局**计量：criteria「连续 10 局 Ghost Game」→ 10 组，每组 target = 中式八球己方 7 颗 + 黑八 = 8 颗（2026-08-09 用户拍板，与 c070 口径对齐；criteria 明写「记录每局清台球数」，made 即该局清台球数）",
    "drill_c066": "0 杆序列（仅摆球，v33 遗留 L1）→ 无杆可锁，判 repetition；criteria「连续 10 次开球，至少 6 次…」按 §5.1「N 次中成功 M 次」记为 1 轮 × 10 次（bpr 10 落在 §5.6.2 带内）",
    "drill_c067": "无序列（§8.5）；按**局**计量：criteria「连续 10 局 9 球挑战」→ 10 组 × 9 颗（1–9 号），made 记该局清到第几颗。沿用现值",
    "drill_c068": "无序列（§8.5）；criteria「连续 10 组自摆五球挑战」→ 组数由现值 5 改为 **10**（贴 criteria），每组 5 球 = 50，落护栏内",
    "drill_c069": "球形1「8 种母球起点」实测起点各异（杆 3/4 起点相同 0.254,0.397）→ repetition（bpr 10，2 轮）；球形2 criteria「按序完成十杆连续进袋」+ 实测位移全 0.0000、台上球 10→1 → sequence 锁 10 杆、3 轮；合计 50",
    "drill_c070": "无序列（§8.5）；按**次**计量：criteria「连续 10 次全台挑战」→ 10 组 × 8 颗（己方 7 + 黑八）。沿用现值",
    "drill_c071": "球形1「8 种母球起点」→ repetition（bpr 10，2 轮）；球形2 criteria「按序完成十五杆连续进袋」+ 实测位移全 0.0000、台上球 15→1 → sequence 锁 15 杆、2 轮；合计 50",
}

SECONDARY_REASONS: dict[str, str] = {
    "drill_c030": "criteria「母球停在与该档示范相近、相对 8 号可用的落点区」+ cp1「先看 8 号需要的母球停点，再反推要收窄还是打开分离角」——母球落点是显式过关条件，走位内容显著（真源候选，采纳）",
    "drill_c031": "criteria「10 球中 4 球进袋**且母球停在 20 厘米目标区内**」——落点区是硬判据，与进袋并列（真源候选，采纳）",
    "drill_c042": "desc/criteria 为「蛇彩」连续清台形态，球形2「按序完成五杆连续进袋」；同族的 c069/c071 主分类即 combined（真源候选，采纳）",
    "drill_c069": "desc「训练首杆角度与高低杆/加塞控线」、cp3 讲进攻角管理，球形2 为十杆连续走位链——走位是主要训练内容（真源候选，采纳）",
    "drill_c071": "同 c069：球形1 练贴库首杆控线、球形2 十五杆满台走位链，cp1「全程角度管理——每一杆都要为下一杆留出可打的切入角」（真源候选，采纳）",
    "drill_c082": "⚠️ 超出真源候选清单，按内容增补：desc「六个来回十二杆为一组」是连续交替清台挑战，criteria 记「断在第几杆」，与 combined 的 c064 三球连打 / c068 五球连打同构",
}

# 明确评估后**不加**副分类的候选，留档备查
SECONDARY_REJECTED: dict[str, str] = {
    "drill_c005": "虽属走位主题但主分类已是 positioning，无需副分类；与 separation 无交集",
    "drill_c064": "desc「练的是两步走位链」走位内容确实存在，但 criteria 主判据是「三球连续进袋」，走位是手段而非独立判据；且 combined 已有 c069/c071 两条 +positioning，再加会使副分类预算失衡 → 不加",
    "drill_c083": "「吃库分离角」判据为「碰到指定参考球」，明确写着「进不进袋不是判据」，与 accuracy/positioning 均无交集 → 不加",
    "drill_c060": "安全球含停位精度，但 criteria 判据是「让对手没有直接舒服的进攻线」，属攻防判断而非走位落点 → 不加 positioning",
}


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


def drill_path(drill_id: str) -> Path:
    index = json.loads((DRILLS_DIR / "index.json").read_text(encoding="utf-8"))
    for group in index["categories"]:
        if drill_id in group["drills"]:
            return DRILLS_DIR / group["category"] / f"{drill_id}.json"
    raise SystemExit(f"{drill_id} 不在 index.json 中")


def serialize(data: dict, trailing_newline: bool = True) -> bytes:
    text = json.dumps(data, ensure_ascii=False, indent=2)
    if trailing_newline:
        text += "\n"
    return text.encode("utf-8")


def build_sets(drill_id: str, files: list[Path]) -> dict:
    spec = DECISIONS[drill_id]
    if not spec:
        sets_count, bps = NO_SEQ_TOTALS[drill_id]
        return {"defaultSets": sets_count, "defaultBallsPerSet": bps}
    if len(spec) != len(files):
        raise SystemExit(
            f"{drill_id}: 决策表 {len(spec)} 项 vs 实测球形 {len(files)} 个，拒绝写入"
        )
    per: list[dict] = []
    for (mode, bpr, rounds), path in zip(spec, files):
        shots = measured_shots(path)
        if mode == SEQ:
            if bpr is not None:
                raise SystemExit(f"{drill_id}: sequence 型的 ballsPerRound 必须由脚本取实测杆数")
            balls = shots
        else:
            if bpr is None:
                raise SystemExit(f"{drill_id}: repetition 型必须显式给 ballsPerRound")
            balls = bpr
        if balls <= 0:
            raise SystemExit(f"{drill_id}/{token_of(path, drill_id)}: ballsPerRound={balls} 非法")
        per.append(
            {
                "token": token_of(path, drill_id),
                "mode": mode,
                "ballsPerRound": balls,
                "defaultRounds": rounds,
            }
        )
    return {
        "defaultSets": sum(p["defaultRounds"] for p in per),
        "defaultBallsPerSet": per[0]["ballsPerRound"],
        "perFormation": per,
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--check-roundtrip", action="store_true")
    args = ap.parse_args()

    ids = list(DECISIONS)
    seqs = sequences_by_drill(set(ids))

    if args.check_roundtrip:
        bad = []
        for drill_id in ids:
            path = drill_path(drill_id)
            raw = path.read_bytes()
            if serialize(json.loads(raw), raw.endswith(b"\n")) != raw:
                bad.append(drill_id)
        print(f"往返保真检查：{len(ids) - len(bad)}/{len(ids)} 字节级一致")
        if bad:
            print("⚠️ 以下文件序列化后会有格式差异：" + "、".join(bad))
            sys.exit(1)
        return

    changed = 0
    for drill_id in ids:
        path = drill_path(drill_id)
        raw = path.read_bytes()
        data = json.loads(raw)
        new_sets = build_sets(drill_id, seqs.get(drill_id, []))
        out: dict = {}
        for key, value in data.items():
            if key == "sets":
                out["sets"] = new_sets
            else:
                out[key] = value
            if key == "category" and drill_id in SECONDARY:
                out["secondaryCategories"] = [SECONDARY[drill_id]]
        if drill_id not in SECONDARY:
            out.pop("secondaryCategories", None)
        new_raw = serialize(out, raw.endswith(b"\n"))
        total = sum(
            p["ballsPerRound"] * p["defaultRounds"] for p in new_sets.get("perFormation", [])
        ) or new_sets["defaultSets"] * new_sets["defaultBallsPerSet"]
        if 40 <= total <= 60:
            flag = ""
        elif drill_id in GUARDRAIL_EXEMPT:
            flag = "  ⚠️ 越界(已豁免)"
        else:
            flag = "  ⛔ 越界(未豁免)"
        print(
            f"{drill_id}: sets={json.dumps(new_sets, ensure_ascii=False)} "
            f"总量={total}{flag} secondary={SECONDARY.get(drill_id, '—')}"
        )
        if new_raw != raw:
            changed += 1
            if args.apply:
                path.write_bytes(new_raw)
    print(f"\n{'已写入' if args.apply else '待写入'} {changed}/{len(ids)} 条 drill")


if __name__ == "__main__":
    main()
