#!/usr/bin/env python3
"""v31 W1a：把剂量口径（§5.6）与副分类（§3.3）写入本批 43 条 drill JSON。

**只动两处**：`sets`（整块重写）与 `secondaryCategories`（新增/删除）。其它字段一律原样。
JSON 以 `indent=2` + 尾换行序列化，已实测与现有文件字节级往返一致（见 --check-roundtrip）。

决策表 `DECISIONS`：每条 drill 给出**按序列文件排序顺序**的逐球形 (mode, ballsPerRound, rounds)。
- token 不在表里手抄，一律由脚本从 `content/position_play/sequences/*.json` 取（FL 红线）；
  表只按位置对齐，数量不符即报错退出。
- `mode == sequence` 时 `ballsPerRound` 必须写 None，由脚本填**实测杆数**（`len(steps)`，I6b 锁死）。
- 判定依据（R7 人工逐条）见 `REASONS`，与 build/v31-w1a-logs/form-evidence.md 一一对应。

用法：
  python3 scripts/v31_w1a_apply_dose.py --check-roundtrip   # 只验证序列化保真，不写盘
  python3 scripts/v31_w1a_apply_dose.py --dry-run           # 打印将要写入的 sets
  python3 scripts/v31_w1a_apply_dose.py --apply             # 实际写盘
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
# None 表示由脚本填实测杆数（仅 sequence 型允许）
DECISIONS: dict[str, list[tuple[str, int | None, int]]] = {
    # ---- fundamentals（R2：基础功维持 3×15）----
    "drill_c006": [(REP, 15, 2), (REP, 15, 2)],
    "drill_c007": [(REP, 15, 3)],
    "drill_c008": [],  # 无序列，§5.6.4 豁免
    "drill_c009": [(REP, 15, 3)],
    "drill_c010": [(REP, 15, 3)],
    "drill_c022": [(REP, 15, 2), (REP, 15, 1)],
    "drill_c023": [(REP, 15, 3)],
    "drill_c043": [],  # 无序列，§5.6.4 豁免
    # ---- accuracy（R2：专项 4~5×10）----
    "drill_c001": [(SEQ, None, 10)],
    "drill_c002": [(REP, 10, 5)],
    "drill_c011": [(REP, 10, 5)],
    "drill_c012": [(REP, 10, 5)],
    "drill_c013": [(REP, 10, 2), (REP, 10, 2)],
    "drill_c032": [(REP, 10, 5)],
    "drill_c033": [(REP, 10, 5)],
    "drill_c052": [(REP, 10, 5)],
    "drill_c053": [(REP, 10, 2), (REP, 13, 2)],
    "drill_c062": [(SEQ, None, 12)],
    "drill_c063": [(SEQ, None, 25)],
    "drill_c072": [(SEQ, None, 25)],
    "drill_c076": [(REP, 14, 2), (REP, 14, 2)],
    "drill_c077": [(REP, 10, 5)],
    "drill_c078": [(REP, 15, 3)],
    # ---- cueAction ----
    "drill_c003": [(REP, 10, 2), (REP, 10, 2)],
    "drill_c004": [(REP, 10, 2), (REP, 10, 2)],
    "drill_c014": [(REP, 10, 5)],
    "drill_c015": [(REP, 10, 5)],
    "drill_c016": [(REP, 10, 5)],
    "drill_c017": [(REP, 10, 5)],
    "drill_c018": [(REP, 10, 5)],
    "drill_c020": [(REP, 15, 3)],
    "drill_c021": [(REP, 12, 4)],
    "drill_c073": [(REP, 10, 2), (REP, 10, 2)],
    "drill_c074": [(REP, 10, 2), (REP, 10, 2)],
    "drill_c075": [(REP, 10, 2), (REP, 10, 1), (REP, 10, 1)],
    # ---- forceControl ----
    "drill_c044": [(REP, 10, 5)],
    "drill_c045": [(REP, 10, 5)],
    "drill_c046": [(REP, 10, 5)],
    "drill_c047": [(REP, 12, 4)],
    "drill_c048": [(REP, 12, 4)],
    "drill_c049": [(REP, 10, 5)],
    "drill_c050": [(REP, 10, 5)],
    "drill_c051": [(REP, 10, 5)],
}

# 无序列 drill 的人工定量（§5.6.4），(defaultSets, defaultBallsPerSet)
NO_SEQ_TOTALS: dict[str, tuple[int, int]] = {
    "drill_c008": (3, 15),
    "drill_c043": (3, 15),
}

# 副分类（R1 / §3.3，每条 ≤1 个；只影响浏览筛选）
SECONDARY: dict[str, str] = {
    "drill_c018": "positioning",
    "drill_c020": "positioning",
    "drill_c021": "positioning",
    "drill_c046": "positioning",
    "drill_c050": "positioning",
    "drill_c051": "positioning",
    "drill_c076": "cueAction",
    "drill_c077": "cueAction",
    "drill_c078": "cueAction",
}

REASONS: dict[str, str] = {
    "drill_c006": "0 杆静态握法示范×2 球形，无杆可锁 → repetition；基础功 15 球/组，两球形各 2 组 = 60（护栏上界，六组 3×15 会到 90 故向下取）",
    "drill_c007": "v26 W10 判独立阶梯；criteria「四档各多次」=打点目录 → repetition；基础功 3×15=45",
    "drill_c008": "无序列（§8.5/§5.6.4 豁免）；criteria「每组 15 杆：开放式与封闭式各半」直接对应 3×15=45",
    "drill_c009": "v26 W10 判独立阶梯（T-v26-9 覆写 digest 误标走位链）；criteria「7 个距离档…同档连续 3 次不丢即该档过关」→ repetition；3×15=45",
    "drill_c010": "v26 W10 判独立阶梯；criteria「7 档距离…同档连续 3 次合格」→ repetition；3×15=45",
    "drill_c022": "v26 W10 判双形阶梯 → repetition；criteria 球形A 明写「15 次」故给 2 组，球形B「两档力度各多次」给 1 组 = 45（=基础功 3×15）",
    "drill_c023": "v26 W10 判独立阶梯；criteria「八档各多次」+ 连续性全「重摆」→ repetition；3×15=45",
    "drill_c043": "无序列（§8.5/§5.6.4 豁免）；criteria「三种手架各 15 杆」直接对应 3×15=45",
    "drill_c001": "走位链：desc「依次打进…完成连续清台」+ coachingPoint「按 1→8→2→3→4 顺序清台：每一杆落点要给下一颗球留下可打的直线角度」+ 精讲 5 个逐杆节 + 台上球逐杆递减 5→1 → sequence，每轮锁 5 杆；10 轮 = 50 球（R2 专项基准）",
    "drill_c002": "criteria「9 档切角…同档连续 3 次不丢即该档过关」+ 连续性全「换形」→ 切角目录 repetition；5×10=50",
    "drill_c011": "criteria「5 档近台近直线…同档连续 3 次不丢」→ repetition；5×10=50",
    "drill_c012": "criteria「8 个距离档…同档连续 3 次不丢」（彩球只作距离标记）→ repetition；5×10=50",
    "drill_c013": "双球形切角阶梯（8 档 / 9 档），criteria「同档连续 3 次不丢」→ 两球形均 repetition；各 2 轮×10 = 40（双球形按护栏向下取，落下界）",
    "drill_c032": "criteria「7 档切角…同档连续 3 次不丢」→ repetition；5×10=50",
    "drill_c033": "criteria「8 档切角…同档连续 3 次不丢」→ repetition；5×10=50",
    "drill_c052": "criteria「7 档切角…同档连续 3 次不丢」→ repetition；5×10=50",
    "drill_c053": "双球形中袋切角阶梯（10 档 / 13 档）→ repetition；球形1 bpr 10、球形2 bpr 13（贴档数，仍在 10–15 带内）各 2 轮 = 46",
    "drill_c062": "走位链：desc 明写「四球走位链」+ coachingPoint「按 1→2→3→4 顺序规划，第3杆是关键球，停位决定收尾难度」→ sequence，每轮锁 4 杆；12 轮 = 48",
    "drill_c063": "走位链：desc 明写「两杆走位链」+「第1杆停位直接决定收尾难度」→ sequence，每轮锁 2 杆；25 轮 = 50",
    "drill_c072": "走位链：coachingPoint「第1杆是关键球：缩杆量要够，才能接到对面 2 号」→ sequence，每轮锁 2 杆；25 轮 = 50",
    "drill_c076": "coachingPoint 明写「每档独立重置；先打完球形1再进球形2」→ 两球形均 repetition；bpr 14 = 一轮走完 14 档，各 2 轮 = 56",
    "drill_c077": "coachingPoint 明写「每档独立重置，只计 8 号进袋」→ repetition；5×10=50",
    "drill_c078": "coachingPoint 明写「每档独立重置」→ repetition；16 档超 10–15 带上界，bpr 取 15、3 轮 = 45",
    "drill_c003": "双球形（距离阶梯 / 打点阶梯），criteria「同档连续 3 次合格即该档过关」→ 均 repetition；各 2 轮×10 = 40",
    "drill_c004": "双球形（力度阶梯 / 距离阶梯），同上 → 均 repetition；各 2 轮×10 = 40",
    "drill_c014": "desc 明写「直线定杆距离阶梯」→ repetition；5×10=50",
    "drill_c015": "desc 明写「距离阶梯」+「同档连续 3 次合格」→ repetition；5×10=50",
    "drill_c016": "desc 明写「打点阶梯…六档几何不变，只改打点高低」→ repetition；5×10=50",
    "drill_c017": "desc 明写「力度阶梯」→ repetition；5×10=50",
    "drill_c018": "coachingPoint 明写「每一档独立重置：进袋后摆回开局位」→ repetition；5×10=50",
    "drill_c020": "coachingPoint 明写「每一档独立重置…不要连打清台」→ repetition；16 档超带上界，bpr 15、3 轮 = 45",
    "drill_c021": "coachingPoint 明写「每一档独立重置」→ repetition；12 档正好在带内，bpr 12 = 一轮一趟，4 轮 = 48",
    "drill_c073": "双球形塞量/力度目录，criteria 按档计 → 均 repetition；各 2 轮×10 = 40",
    "drill_c074": "双球形塞量/力度目录 → 均 repetition；各 2 轮×10 = 40",
    "drill_c075": "三球形塞量阶梯（R6 明确其为难度阶梯，计划可按球形引用）→ 均 repetition；主球形（7 档）2 轮 + 两个进阶球形各 1 轮 = 40",
    "drill_c044": "desc 明写「六次独立重置」→ repetition；5×10=50",
    "drill_c045": "v26 W9 判独立阶梯；desc「同一起点推出三次，力度分别为…」无目标球 → repetition；5×10=50（口径按推杆次数计）",
    "drill_c046": "连续性全「重摆」+ coachingPoint「同一球位反复练习，每次微调力度」→ repetition；5×10=50",
    "drill_c047": "v26 W9 判独立阶梯（4 位×3 力目录）→ repetition；12 档在带内，bpr 12 = 一轮一趟，4 轮 = 48",
    "drill_c048": "v26 W9 判独立阶梯（同 c047 对称）→ repetition；bpr 12、4 轮 = 48",
    "drill_c049": "v26 W9 判独立阶梯（五档力度）；criteria「不以进袋为条件」→ repetition；5×10=50（按推杆次数计）",
    "drill_c050": "desc 明写「五次独立重置」→ repetition；5×10=50",
    "drill_c051": "coachingPoint 明写「每档独立重置到同一点…不要连打」→ repetition；5×10=50",
}

SECONDARY_REASONS: dict[str, str] = {
    "drill_c018": "criteria 要求「能口头指出左塞档与右塞档母球停区的左右差异」，desc「对照…如何把母球送到不同半台」——母球落点是显式训练目标",
    "drill_c020": "criteria「同一切角能指出左塞档与右塞档母球停区差异」——落点对照是本课判据之一",
    "drill_c021": "criteria「能指出左塞与右塞回位停区差异」——同上",
    "drill_c046": "criteria「母球停在目标区域30厘米内」——落点区域是硬判据",
    "drill_c050": "desc「让母球停在很近的控位区…练的是软力度下的停点」+ criteria「母球停在示范所示的近距控位带内」——落点带是硬判据（⚠️ 超出真源候选清单，按内容加入）",
    "drill_c051": "criteria「母球停点随档位落在不同区域；同档连续 2 次落在目标带内即过关」——落点带是过关条件",
    "drill_c076": "主判据只计目标球进袋（accuracy），但唯一变量是左右塞打点（「真变量是顺塞/反塞」）——杆法内容显著",
    "drill_c077": "同上：切角递进为主，杆法锁「半颗皮头右塞」贯穿全课",
    "drill_c078": "同上：每档对比高杆/低杆两种打法，杆法组合是第二主轴",
}

# 明确评估后**不加**副分类的候选（真源 §四 建议清单里的），留档备查
SECONDARY_REJECTED: dict[str, str] = {
    "drill_c003": "名为「高杆跟进走位」，但 coachingPoint 明写「直线球没有切角：跟进只能沿击球线向前，别指望横向走位」，合格判据仅「8 号进袋且母球留台」，无落点区域要求 → 不属走位训练",
    "drill_c004": "名为「低杆缩杆回位」，判据同为「目标球进袋且母球留台」，停点只作观察量而非过关条件 → 不加",
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
    """按现有文件风格序列化（indent=2）。尾换行随原文件——c008/c032/c053 原本无尾换行，
    补上会产生本批意图外的 1 字节 diff。"""
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
        # 重建 dict 以把 secondaryCategories 插到 category 之后（贴 DTO 文档顺序）
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
        flag = "" if 40 <= total <= 60 else "  ⚠️ 越界"
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
