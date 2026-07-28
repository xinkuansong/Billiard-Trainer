#!/usr/bin/env python3
"""v21 W2 — 直球加塞坐标推导（c073/c074/c075）。

坐标契约（geometry-spatial-reasoning / W1 备忘 §0）：
  - 归一化 Canvas：X∈[0,1] 左→右；Y∈[0,0.5] 上→下
  - 袋口真源 = AngleSceneCalculator（W1 实测 pocket=(0.5000, 0.5209)）
    ⛔ 不用 table-geometry.md / b2 的 0.5268（与代码手性相反）
  - 直球：母-目-袋共线于 X=0.5；切角设计值 0°
  - ghost = target − 2R·v̂（v̂ 指向袋，本系 +Y）；cue = ghost − d·v̂
  - spinX 正=左塞 / 负=右塞；spinY=0（中杆）

输出：
  - stdout + build/v21-w2-logs/coord-derive.py.out.txt
  - build/v21-w2-evidence/formations.json
  - content/drill_profiles/drill_c07{3,4,5}.profile.json
  - content/position_play/sequences/drill_c0NN__A*-…-0杆.json
"""
from __future__ import annotations

import json
import math
import uuid
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOG_DIR = ROOT / "build/v21-w2-logs"
EV_DIR = ROOT / "build/v21-w2-evidence"
PROFILE_DIR = ROOT / "content/drill_profiles"
SEQ_DIR = ROOT / "content/position_play/sequences"

POCKET = (0.5000, 0.5209)  # AngleSceneCalculator code truth (W1)
R = 0.028575 / 2.540
TWO_R = 2 * R
Y_MIN, Y_MAX = 0.05, 0.45
X_MIN, X_MAX = 0.05, 0.95


def layout(dtp: float, d: float):
    px, py = POCKET
    tx, ty = px, py - dtp
    gx, gy = tx, ty - TWO_R
    cx, cy = gx, gy - d
    return (cx, cy), (tx, ty), (gx, gy)


def checks(cue, tgt):
    cx, cy = cue
    tx, ty = tgt
    oks = [
        ("cue_bounds", X_MIN <= cx <= X_MAX and Y_MIN <= cy <= Y_MAX),
        ("tgt_bounds", X_MIN <= tx <= X_MAX and Y_MIN <= ty <= Y_MAX),
        ("sep>2r", math.hypot(cx - tx, cy - ty) > TWO_R + 1e-9),
        ("colinear_x", abs(cx - tx) < 1e-12 and abs(tx - 0.5) < 1e-12),
    ]
    return oks, math.hypot(cx - tx, cy - ty)


# (id, side, spinLevel, spinX, dtp, d, v, rank, rep[, distanceBand])
DRILLS = {
    "c073": {
        "nameZh": "挤偏认知·直球近台",
        "nameEn": "Squirt Awareness · Near Straight",
        "subcategory": "sideSpinSquirt",
        "difficulty": 2,
        "isPremium": False,
        "description": (
            "直球近台练加塞后的挤偏感知：塞量固定中档（0.30R），左右塞各两档距离/"
            "力度散布。目标只有目标球进下中袋——学会「左塞挤右→瞄准向左让」的补偿方向。"
        ),
        # W1：d_cg=0.22 时中塞 v∈{1.5,2.0} 易洗袋；取 v≥3.0。近段用 d=0.18/0.22 两档。
        "formations": [
            ("A1", "L", "中", +0.30, 0.22, 0.18, 3.0, 1, True),
            ("A2", "R", "中", -0.30, 0.22, 0.18, 3.5, 2, False),
            ("A3", "L", "中", +0.30, 0.22, 0.22, 3.0, 3, False),
            ("A4", "R", "中", -0.30, 0.22, 0.22, 3.5, 4, False),
        ],
    },
    "c074": {
        "nameZh": "挤偏放大·直球长台",
        "nameEn": "Squirt Amplification · Long Straight",
        "subcategory": "sideSpinSquirtLong",
        "difficulty": 3,
        "isPremium": True,
        "description": (
            "直球中/长距放大挤偏横向误差：塞量固定中档，左右塞 × 距离档全覆盖。"
            "杠杆臂越长，同样挤偏角造成的横向偏差越大——仍只判定目标球进袋。"
        ),
        # 中距 d=0.22；长距 d=0.28 + dtp=0.15（保持 cue Y≥0.05；力度取高档防洗袋）
        "formations": [
            ("A1", "L", "中", +0.30, 0.22, 0.22, 3.5, 1, True, "中"),
            ("A2", "R", "中", -0.30, 0.22, 0.22, 3.5, 2, False, "中"),
            ("A3", "L", "中", +0.30, 0.15, 0.28, 5.0, 3, False, "长"),
            ("A4", "R", "中", -0.30, 0.15, 0.28, 5.0, 4, False, "长"),
        ],
    },
    "c075": {
        "nameZh": "塞量阶梯",
        "nameEn": "Side-Spin Levels",
        "subcategory": "sideSpinLevels",
        "difficulty": 3,
        "isPremium": True,
        "description": (
            "塞量轻/中/满（满=0.5R miscue 上限）× 左右塞共 6 档阶梯。"
            "塞量越大挤偏角越大，让点补偿量随之加大；中杆直球，只验目标球进袋。"
        ),
        # W1 d=0.22：轻/中 v≥3.0；满塞避开 2.0–2.5 洗袋带，取 3.5
        "formations": [
            ("A1", "L", "轻", +0.15, 0.22, 0.22, 3.0, 1, True),
            ("A2", "R", "轻", -0.15, 0.22, 0.22, 3.5, 2, False),
            ("A3", "L", "中", +0.30, 0.22, 0.22, 3.0, 3, False),
            ("A4", "R", "中", -0.30, 0.22, 0.22, 3.5, 4, False),
            ("A5", "L", "满", +0.50, 0.22, 0.22, 3.5, 5, False),
            ("A6", "R", "满", -0.50, 0.22, 0.22, 3.5, 6, False),
        ],
    },
}


def parse_formation(f):
    if len(f) == 9:
        fid, side, lvl, sx, dtp, d, v, rank, rep = f
        dist = None
    else:
        fid, side, lvl, sx, dtp, d, v, rank, rep, dist = f
    cue, tgt, ghost = layout(dtp, d)
    oks, dct = checks(cue, tgt)
    row = {
        "id": fid,
        "side": side,
        "spinLevel": lvl,
        "spinX": sx,
        "spinY": 0.0,
        "dtp": dtp,
        "d": d,
        "velocity": v,
        "difficultyRank": rank,
        "representative": rep,
        "cue": {"x": round(cue[0], 4), "y": round(cue[1], 4)},
        "target": {"x": round(tgt[0], 4), "y": round(tgt[1], 4)},
        "ghost": {"x": round(ghost[0], 4), "y": round(ghost[1], 4)},
        "cutAngleDeg": 0.0,
        "pocket": "bottomCenter",
        "checks_ok": all(b for _, b in oks),
        "d_ct": round(dct, 4),
    }
    if dist:
        row["distanceBand"] = dist
    return row, oks


def side_zh(side: str) -> str:
    return "左塞" if side == "L" else "右塞"


def aim_hint(side: str) -> str:
    # W1 [事实]：左塞挤右 → 瞄准向左让；右塞对称
    if side == "L":
        return "左塞使母球出射偏向右侧（挤偏），瞄准须向左让点补偿"
    return "右塞使母球出射偏向左侧（挤偏），瞄准须向右让点补偿"


def write_profile(did: str, spec: dict, forms: list) -> Path:
    if did == "c073":
        target_vars = [
            {
                "name": "side",
                "levels": ["L", "R"],
                "rationale": "塞侧全覆盖；左塞挤右、右塞挤左（W1 S1）",
            }
        ]
        cond_vars = [
            {
                "name": "dtp",
                "levels": ["0.22"],
                "rationale": "目标距袋钉在洗袋安全区中段（W1 dtp∈[0.12,0.25]）",
                "sampling": "全档案固定；距离变量走 d",
            },
            {
                "name": "d",
                "levels": ["0.18", "0.22"],
                "rationale": "母-ghost 近段两档",
                "sampling": "每档 × L/R",
            },
            {
                "name": "velocity",
                "levels": ["3.0", "3.5"],
                "rationale": "避开 W1 中塞洗袋带(≈1.5–2.0)；挤偏与力度无关",
                "sampling": "同距内散布",
            },
        ]
        fixed = {
            "pocket": "bottomCenter（中袋主题钉死，代码真源 y=0.5209）",
            "cutAngle": "0°（直球隔离挤偏）",
            "spinY": "0（中杆）",
            "spinLevel": "中(0.30)固定",
            "criteria": "仅目标球进袋",
        }
    elif did == "c074":
        target_vars = [
            {
                "name": "side",
                "levels": ["L", "R"],
                "rationale": "塞侧全覆盖",
            },
            {
                "name": "distanceBand",
                "levels": ["中", "长"],
                "rationale": "距离档放大挤偏横向误差",
            },
        ]
        cond_vars = [
            {
                "name": "velocity",
                "levels": ["3.5", "4.0"],
                "rationale": "长距取偏大力度避开跟进洗袋带",
                "sampling": "中距 3.5；长距 3.5/4.0",
            },
            {
                "name": "spinLevel",
                "levels": ["中"],
                "rationale": "塞量固定中档",
                "sampling": "全档案固定",
            },
        ]
        fixed = {
            "pocket": "bottomCenter",
            "cutAngle": "0°",
            "spinY": "0",
            "spinLevel": "中(0.30)固定",
            "criteria": "仅目标球进袋",
        }
    else:
        target_vars = [
            {
                "name": "spinLevel",
                "levels": ["轻", "中", "满"],
                "rationale": "塞量阶梯；满=0.5R=miscueLimit",
            },
            {
                "name": "side",
                "levels": ["L", "R"],
                "rationale": "每档塞量左右全覆盖",
            },
        ]
        cond_vars = [
            {
                "name": "dtp",
                "levels": ["0.22"],
                "rationale": "钉在 W1 安全区中段",
                "sampling": "全档案固定",
            },
            {
                "name": "velocity",
                "levels": ["3.0", "3.5"],
                "rationale": "避开中低速洗袋带（W1：满塞 2.0–2.5 易跟进）",
                "sampling": "轻/中 3.0–3.5；满 3.5",
            },
        ]
        fixed = {
            "pocket": "bottomCenter",
            "cutAngle": "0°",
            "spinY": "0",
            "criteria": "仅目标球进袋",
        }

    formations = []
    for row in forms:
        vars_ = {
            "side": row["side"],
            "spinLevel": row["spinLevel"],
            "dtp": f"{row['dtp']:.2f}",
            "d": f"{row['d']:.2f}",
            "velocity": f"{row['velocity']:.1f}",
        }
        if "distanceBand" in row:
            vars_["distanceBand"] = row["distanceBand"]
        entry = {
            "id": row["id"],
            "difficultyRank": row["difficultyRank"],
            "cue": row["cue"],
            "target": row["target"],
            "pocket": "bottomCenter",
            "cutAngleDeg": 0.0,
            "spin": {"x": row["spinX"], "y": 0.0},
            "variables": vars_,
        }
        if row["representative"]:
            entry["representative"] = True
        formations.append(entry)

    profile = {
        "drillId": f"drill_{did}",
        "version": 1,
        "methodology": "docs/research/20260716-drill变量覆盖设计方法论.md",
        "_note": (
            "v21 W2：坐标由 scripts/v21_w2_straight_spin_coords.py 推导；"
            "袋口取 AngleSceneCalculator 代码真源 (0.5,0.5209)；"
            "spin 结构化字段见 schema D-v21-4；让点方向引 W1：左塞→向左让。"
        ),
        "fixedVariables": fixed,
        "targetVariables": target_vars,
        "conditionVariables": cond_vars,
        "formations": formations,
    }
    path = PROFILE_DIR / f"drill_{did}.profile.json"
    path.write_text(json.dumps(profile, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return path


def write_sequences(did: str, name_zh: str, forms: list) -> list[Path]:
    paths = []
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    for i, row in enumerate(forms, start=1):
        token = row["id"]  # A1.. 不含 -
        fname = f"drill_{did}__{token}-{name_zh} · 球形{i}-0杆.json"
        body = {
            "createdAt": now,
            "id": str(uuid.uuid4()).upper(),
            "initial": {
                "onTable": {
                    "_8": {"x": row["target"]["x"], "y": row["target"]["y"]},
                    "cueBall": {"x": row["cue"]["x"], "y": row["cue"]["y"]},
                }
            },
            "name": f"{name_zh} · 球形{i}",
            "steps": [],
            "updatedAt": now,
        }
        path = SEQ_DIR / fname
        path.write_text(json.dumps(body, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        paths.append(path)
    return paths


def tutorial_formation(row: dict, name_zh: str) -> dict:
    side = row["side"]
    lvl = row["spinLevel"]
    title = f"{row['id']} · {side_zh(side)}·{lvl}档"
    if "distanceBand" in row:
        title += f"·{row['distanceBand']}距"
    return {
        "id": row["id"],
        "title": title,
        "sections": [
            {
                "title": "技术原理",
                "content": (
                    f"本球形练{side_zh(side)}、塞量{lvl}档（|spinX|={abs(row['spinX']):.2f}R），"
                    f"直球切角 0°、中杆。{aim_hint(side)}。"
                    "挤偏角由打点横向偏移决定，与出杆力度无关——力度只影响走位与洗袋风险，不改变让点方向。"
                ),
            },
            {
                "title": "怎么打",
                "content": (
                    f"按档位加{side_zh(side)}，瞄准时{('向左' if side == 'L' else '向右')}让开一点再出杆；"
                    f"力度约 {row['velocity']:.1f} m/s。目标只有 8 号进下中袋，不必管母球停哪。"
                    "先建立「塞侧→让点方向」的对应，再谈塞量大小。"
                ),
            },
            {
                "title": "自检",
                "content": (
                    "达标：本球形 10 球进 6 球（仅计目标球进袋）。"
                    "若目标球系统性偏一侧，先检查让点方向是否反了；"
                    "若母球跟进落袋，略减力或确认目标球距袋不要过近。"
                ),
            },
        ],
    }


def write_draft_drill(did: str, spec: dict, forms: list) -> Path:
    rep = next(r for r in forms if r["representative"])
    # Placeholder animation (start points only) — replaced by bake
    animation = {
        "cueBall": {"start": rep["cue"], "path": [rep["target"]]},
        "targetBall": {"start": rep["target"], "path": [{"x": 0.5, "y": 0.5209}]},
        "pocket": "bottomCenter",
        "cueDirection": {"x": 0.5, "y": 0.5},
        "source": "pending_bake",
    }
    drill = {
        "id": f"drill_{did}",
        "nameZh": spec["nameZh"],
        "nameEn": spec["nameEn"],
        "category": "cueAction",
        "subcategory": spec["subcategory"],
        "ballType": ["chinese8"],
        "level": "L2",
        "difficulty": spec["difficulty"],
        "isPremium": spec["isPremium"],
        "description": spec["description"],
        "coachingPoints": [
            "左塞挤右→瞄准向左让；右塞对称（W1 引擎实测，非旧 c018 文案）",
            "挤偏与力度无关——力度只改走位/洗袋风险，不改变让点方向",
            "本课判定只看目标球进袋，不计母球落点",
            "满塞上限 0.5R（miscueLimit），不是球的边缘",
        ],
        "standardCriteria": "每个球形10球进6球（只计目标球进袋，不计母球落点）",
        "sets": {"defaultSets": len(forms), "defaultBallsPerSet": 10},
        "animation": animation,
        "shotIntent": {
            "version": 1,
            "shots": [
                {
                    "cue": rep["cue"],
                    "target": rep["target"],
                    "pocket": "bottomCenter",
                    "velocity": rep["velocity"],
                    "spin": {"x": rep["spinX"], "y": 0.0},
                }
            ],
        },
        "tutorial": {"formations": [tutorial_formation(r, spec["nameZh"]) for r in forms]},
        "videos": [],
    }
    out = ROOT / f"QiuJi/Resources/Drills/cueAction/drill_{did}.json"
    out.write_text(json.dumps(drill, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return out


def main():
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    EV_DIR.mkdir(parents=True, exist_ok=True)
    PROFILE_DIR.mkdir(parents=True, exist_ok=True)
    SEQ_DIR.mkdir(parents=True, exist_ok=True)

    # Gold standard
    c, t, g = layout(0.20, 0.22)
    assert abs(c[0] - 0.5) < 1e-12
    assert abs(g[1] - (t[1] - TWO_R)) < 1e-12

    lines = [
        "=== v21 W2 coordinate derivation ===",
        f"pocket_code_truth={POCKET}  # AngleSceneCalculator / W1，NOT table-geometry 0.5268",
        f"r_norm={R:.5f}",
        "",
    ]
    computed = {}
    all_ok = True
    for did, spec in DRILLS.items():
        lines.append(f"--- drill_{did} ---")
        forms = []
        for f in spec["formations"]:
            row, oks = parse_formation(f)
            forms.append(row)
            all_ok = all_ok and row["checks_ok"]
            lines.append(
                f"{row['id']} side={row['side']} lvl={row['spinLevel']} "
                f"spinX={row['spinX']:+.2f} dtp={row['dtp']} d={row['d']} v={row['velocity']} "
                f"cue=({row['cue']['x']},{row['cue']['y']}) "
                f"tgt=({row['target']['x']},{row['target']['y']}) ok={row['checks_ok']} {oks}"
            )
        computed[did] = forms
        write_profile(did, spec, forms)
        write_sequences(did, spec["nameZh"], forms)
        write_draft_drill(did, spec, forms)
        lines.append("")

    lines.append(f"ALL_BOUNDS_OK={all_ok}")
    text = "\n".join(lines) + "\n"
    print(text)
    (LOG_DIR / "coord-derive.py.out.txt").write_text(text, encoding="utf-8")
    (EV_DIR / "coverage-matrix.md").write_text(text, encoding="utf-8")
    (EV_DIR / "formations.json").write_text(
        json.dumps(computed, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    assert all_ok, "bounds check failed"


if __name__ == "__main__":
    main()
