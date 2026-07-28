#!/usr/bin/env python3
"""v21 W3 — 角度球加塞准度坐标推导（c076/c077/c078）。

坐标契约（geometry-spatial-reasoning / W1 备忘 §0）：
  - 归一化 Canvas：X∈[0,1] 左→右；Y∈[0,0.5] 上→下
  - 袋口真源 = AngleSceneCalculator（W1/W2 实测 pocket=(0.5000, 0.5209)）
    ⛔ 不用 table-geometry.md / b2 的 0.5268（与代码手性相反）
  - 角度球构造（同 b2 / c053）：
      v̂ = normalize(P−T)；G = T − 2R·v̂；t̂ = R(±θ)·v̂；C = G − d·t̂
      side=+1 → 右切（cue X>进球线）；side=-1 → 左切
  - spinX 正=左塞 / 负=右塞；spinY=0（中杆）

顺塞 / 反塞（真变量，备忘 §2/§3）：
  - 切侧 = 白球相对进球线的左右（L/R cut）
  - 顺塞(running) = 塞侧与切侧同侧：L切+左塞 / R切+右塞
  - 反塞(reverse) = 塞侧与切侧异侧：L切+右塞 / R切+左塞
  - 脚本对每球形断言：spinKind ↔ (cutSide, spinX) 一致

输出：
  - stdout + build/v21-w3-logs/coord-derive.py.out.txt
  - build/v21-w3-evidence/formations.json
  - content/drill_profiles/drill_c07{6,7,8}.profile.json
  - content/position_play/sequences/drill_c0NN__A*-…-0杆.json
  - QiuJi/Resources/Drills/accuracy/drill_c07{6,7,8}.json（draft，bake 后补 animation）
"""
from __future__ import annotations

import json
import math
import uuid
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOG_DIR = ROOT / "build/v21-w3-logs"
EV_DIR = ROOT / "build/v21-w3-evidence"
PROFILE_DIR = ROOT / "content/drill_profiles"
SEQ_DIR = ROOT / "content/position_play/sequences"
DRILL_DIR = ROOT / "QiuJi/Resources/Drills/accuracy"

POCKET = (0.5000, 0.5209)  # AngleSceneCalculator code truth
R = 0.028575 / 2.540
TWO_R = 2 * R
Y_MIN, Y_MAX = 0.05, 0.45
X_MIN, X_MAX = 0.05, 0.95
SPIN_MID = 0.30


def norm(vx, vy):
    m = math.hypot(vx, vy)
    return vx / m, vy / m


def rot(vx, vy, deg):
    a = math.radians(deg)
    return (
        vx * math.cos(a) - vy * math.sin(a),
        vx * math.sin(a) + vy * math.cos(a),
    )


def angle_between(ax, ay, bx, by):
    dot = ax * bx + ay * by
    na, nb = math.hypot(ax, ay), math.hypot(bx, by)
    c = max(-1.0, min(1.0, dot / (na * nb)))
    return math.degrees(math.acos(c))


def solve_formation(target, pocket, theta_deg, cut_side, d_cue_ghost):
    """cut_side: +1=R, -1=L。"""
    tx, ty = target
    px, py = pocket
    vx, vy = norm(px - tx, py - ty)
    gx, gy = tx - TWO_R * vx, ty - TWO_R * vy
    hx, hy = rot(vx, vy, theta_deg if cut_side > 0 else -theta_deg)
    cx, cy = gx - d_cue_ghost * hx, gy - d_cue_ghost * hy
    cut_travel = angle_between(gx - cx, gy - cy, vx, vy)
    cut_apparent = angle_between(tx - cx, ty - cy, vx, vy)
    side_check = "R" if cx > tx + 1e-12 else ("L" if cx < tx - 1e-12 else "0")
    return {
        "cue": (cx, cy),
        "ghost": (gx, gy),
        "cut_travel": cut_travel,
        "cut_apparent": cut_apparent,
        "side_check": side_check,
    }


def spin_for(cut_side_lbl: str, spin_kind: str, magnitude: float = SPIN_MID) -> float:
    """顺塞=同侧，反塞=异侧；none→0。"""
    if spin_kind in ("none", "无", "无塞"):
        return 0.0
    same = spin_kind in ("running", "顺", "顺塞")
    if cut_side_lbl == "L":
        # 同侧左塞 +, 异侧右塞 -
        return +magnitude if same else -magnitude
    if cut_side_lbl == "R":
        # 同侧右塞 -, 异侧左塞 +
        return -magnitude if same else +magnitude
    raise ValueError(cut_side_lbl)


def classify_spin(cut_side_lbl: str, spin_x: float) -> str:
    if abs(spin_x) < 1e-9:
        return "none"
    left = spin_x > 0
    if cut_side_lbl == "L":
        return "running" if left else "reverse"
    if cut_side_lbl == "R":
        return "running" if not left else "reverse"
    raise ValueError(cut_side_lbl)


def checks(cue, target, pocket, theta):
    cx, cy = cue
    tx, ty = target
    oks = [
        ("cue_bounds", X_MIN <= cx <= X_MAX and Y_MIN <= cy <= Y_MAX),
        ("tgt_bounds", X_MIN <= tx <= X_MAX and Y_MIN <= ty <= Y_MAX),
        ("sep>2r", math.hypot(cx - tx, cy - ty) > TWO_R + 1e-9),
        ("sep>0.05", math.hypot(cx - tx, cy - ty) > 0.05),
    ]
    vx, vy = norm(pocket[0] - tx, pocket[1] - ty)
    entry = angle_between(vx, vy, 0.0, 1.0)
    oks.append((f"entry<=30({entry:.1f})", entry <= 30.0 + 1e-9))
    return oks, math.hypot(cx - tx, cy - ty), entry


# formations tuples:
# (id, theta, cutSide L/R, spinKind running|reverse|none, dtp, d, v, rank, rep[, extra...])
# c078 extras: distanceBand
DRILLS = {
    "c076": {
        "nameZh": "小角度带塞进袋",
        "nameEn": "Small-Angle Spin Potting",
        "subcategory": "spinAngle",
        "level": "L2",
        "difficulty": 3,
        "isPremium": True,
        "description": (
            "小切角（15°/30°）下练顺塞与反塞进袋：真变量是塞相对切向同侧/异侧，"
            "不是绝对左右。塞量固定中档；左塞挤右→瞄准向左让（W1）。只验目标球进袋。"
        ),
        "formations": [
            # θ×顺/反全覆盖 4 + 条件加样 2（距/切侧散布）
            ("A1", 15, "R", "running", 0.20, 0.22, 3.0, 1, True),
            ("A2", 15, "R", "reverse", 0.20, 0.22, 3.0, 2, False),
            ("A3", 15, "L", "running", 0.20, 0.22, 3.5, 3, False),  # d≤0.22 保 cueY≥0.05
            ("A4", 30, "L", "running", 0.18, 0.22, 3.0, 4, False),
            ("A5", 30, "L", "reverse", 0.18, 0.22, 3.0, 5, False),
            ("A6", 30, "R", "reverse", 0.20, 0.25, 3.5, 6, False),
        ],
    },
    "c077": {
        "nameZh": "中大角度带塞进袋",
        "nameEn": "Wide-Angle Spin Potting",
        "subcategory": "spinWideAngle",
        "level": "L3",
        "difficulty": 4,
        "isPremium": True,
        "description": (
            "45° 切角下对比无塞 / 顺塞 / 反塞进袋，隔离投掷与挤偏对厚薄的影响。"
            "中杆中档塞；让点方向引 W1（左塞→向左让）。判定只看目标球进袋。"
        ),
        "formations": [
            # 无塞→顺→反 × 两档距离/切侧
            ("A1", 45, "R", "none", 0.18, 0.25, 3.0, 1, True),
            ("A2", 45, "R", "running", 0.18, 0.25, 3.0, 2, False),
            ("A3", 45, "R", "reverse", 0.18, 0.25, 3.0, 3, False),
            ("A4", 45, "L", "none", 0.22, 0.28, 3.5, 4, False),
            ("A5", 45, "L", "running", 0.22, 0.28, 3.5, 5, False),
            ("A6", 45, "L", "reverse", 0.15, 0.28, 3.5, 6, False),
        ],
    },
    "c078": {
        "nameZh": "远台带塞准度",
        "nameEn": "Long-Table Spin Accuracy",
        "subcategory": "spinLong",
        "level": "L3",
        "difficulty": 4,
        "isPremium": True,
        "description": (
            "小切角远距放大挤偏杠杆：距离档（中/远）× 塞侧（左/右）全覆盖。"
            "中杆中档塞；瞄准让点引 W1。只验目标球进袋，不计母球落点。"
        ),
        # θ=15° 小切角；cutSide 固定 R 以便 塞侧→顺/反可验；distanceBand × side
        "formations": [
            ("A1", 15, "R", "running", 0.20, 0.25, 3.5, 1, True, "中"),   # R切+右塞=顺
            ("A2", 15, "R", "reverse", 0.20, 0.25, 3.5, 2, False, "中"),  # R切+左塞=反
            # 远距：d=0.28/dtp=0.17 保 cueY≥0.05；反塞易洗袋→力度略降
            ("A3", 15, "R", "running", 0.17, 0.28, 3.5, 3, False, "远"),
            ("A4", 15, "R", "reverse", 0.17, 0.28, 3.0, 4, False, "远"),
        ],
    },
}


def parse_formation(f):
    if len(f) == 9:
        fid, theta, cut, kind, dtp, d, v, rank, rep = f
        dist_band = None
    else:
        fid, theta, cut, kind, dtp, d, v, rank, rep, dist_band = f
    cut_sign = +1 if cut == "R" else -1
    spin_x = spin_for(cut, kind)
    target = (0.5, POCKET[1] - dtp)
    sol = solve_formation(target, POCKET, theta, cut_sign, d)
    oks, dct, entry = checks(sol["cue"], target, POCKET, theta)
    classified = classify_spin(cut, spin_x)
    # none 映射
    expect_kind = "none" if kind in ("none", "无", "无塞") else (
        "running" if kind in ("running", "顺", "顺塞") else "reverse"
    )
    spin_ok = classified == expect_kind
    travel_ok = abs(sol["cut_travel"] - theta) < 1e-6
    side_ok = sol["side_check"] == cut
    row = {
        "id": fid,
        "theta": theta,
        "cutSide": cut,
        "spinKind": expect_kind,
        "spinKindZh": {"running": "顺塞", "reverse": "反塞", "none": "无塞"}[expect_kind],
        "spinX": spin_x,
        "spinY": 0.0,
        "dtp": dtp,
        "d": d,
        "velocity": v,
        "difficultyRank": rank,
        "representative": rep,
        "cue": {"x": round(sol["cue"][0], 4), "y": round(sol["cue"][1], 4)},
        "target": {"x": round(target[0], 4), "y": round(target[1], 4)},
        "ghost": {"x": round(sol["ghost"][0], 4), "y": round(sol["ghost"][1], 4)},
        "cutAngleDeg": float(theta),
        "cut_travel": round(sol["cut_travel"], 4),
        "cut_apparent": round(sol["cut_apparent"], 4),
        "entryAngle": round(entry, 4),
        "pocket": "bottomCenter",
        "checks_ok": all(b for _, b in oks) and spin_ok and travel_ok and side_ok,
        "spin_ok": spin_ok,
        "travel_ok": travel_ok,
        "side_ok": side_ok,
        "d_ct": round(dct, 4),
        "sideAbs": "L" if spin_x > 1e-9 else ("R" if spin_x < -1e-9 else "0"),
    }
    if dist_band:
        row["distanceBand"] = dist_band
    return row, oks


def aim_hint(spin_x: float) -> str:
    if abs(spin_x) < 1e-9:
        return "本球形无塞对照：瞄准接触点本身，感受纯切角进袋"
    if spin_x > 0:
        return "左塞使母球出射偏向右侧（挤偏），瞄准须向左让点补偿（W1）"
    return "右塞使母球出射偏向左侧（挤偏），瞄准须向右让点补偿（W1）"


def write_profile(did: str, forms: list) -> Path:
    if did == "c076":
        fixed = {
            "pocket": "bottomCenter（代码真源 y=0.5209）",
            "spinY": "0（中杆）",
            "spinLevel": "中(0.30)固定",
            "criteria": "仅目标球进袋",
        }
        target_vars = [
            {
                "name": "cutAngle",
                "levels": ["15", "30"],
                "rationale": "小角度两档",
            },
            {
                "name": "spinKind",
                "levels": ["running", "reverse"],
                "rationale": "真变量=顺/反塞（相对切向同侧/异侧），非绝对左右",
            },
        ]
        cond_vars = [
            {
                "name": "cutSide",
                "levels": ["L", "R"],
                "rationale": "切侧散布；与 spin 组合决定顺/反",
                "sampling": "pairwise",
            },
            {
                "name": "dtp",
                "levels": ["0.18", "0.20", "0.22"],
                "rationale": "距袋散布（洗袋安全区附近）",
                "sampling": "条件加样",
            },
            {
                "name": "d",
                "levels": ["0.22", "0.25"],
                "rationale": "母-ghost 距离散布（受 cueY≥0.05 约束）",
                "sampling": "条件加样",
            },
        ]
    elif did == "c077":
        fixed = {
            "pocket": "bottomCenter",
            "cutAngle": "45°固定",
            "spinY": "0",
            "spinLevel": "中(0.30)；无塞对照 spin=0",
            "criteria": "仅目标球进袋",
        }
        target_vars = [
            {
                "name": "spinKind",
                "levels": ["none", "running", "reverse"],
                "rationale": "无塞对照隔离投掷/挤偏；顺/反=切向同侧/异侧",
            }
        ]
        cond_vars = [
            {
                "name": "cutSide",
                "levels": ["L", "R"],
                "rationale": "左右切散布",
                "sampling": "各 3 档 spinKind",
            },
            {
                "name": "dtp",
                "levels": ["0.15", "0.18", "0.22"],
                "rationale": "目标距袋散布",
                "sampling": "随切侧",
            },
            {
                "name": "d",
                "levels": ["0.25", "0.28"],
                "rationale": "母-ghost 中距",
                "sampling": "随切侧",
            },
        ]
    else:
        fixed = {
            "pocket": "bottomCenter",
            "cutAngle": "15°小切角（远距以免洗袋）",
            "cutSide": "R固定（便于塞侧→顺/反可验）",
            "spinY": "0",
            "spinLevel": "中(0.30)",
            "criteria": "仅目标球进袋",
        }
        target_vars = [
            {
                "name": "distanceBand",
                "levels": ["中", "远"],
                "rationale": "距离档放大挤偏杠杆",
            },
            {
                "name": "side",
                "levels": ["L", "R"],
                "rationale": "塞侧绝对左右；variables 同时标 spinKind running/reverse",
            },
        ]
        cond_vars = [
            {
                "name": "spinKind",
                "levels": ["running", "reverse"],
                "rationale": "R切下：右塞=顺、左塞=反（脚本可验）",
                "sampling": "由 side 派生",
            },
            {
                "name": "d",
                "levels": ["0.25", "0.28"],
                "rationale": "中距/远距（远档受 cueY≥0.05 与反塞洗袋约束）",
                "sampling": "每档 × L/R",
            },
        ]

    formations = []
    for row in forms:
        vars_ = {
            "cutAngle": str(int(row["theta"])),
            "cutSide": row["cutSide"],
            "spinKind": row["spinKind"],
            "spinKindZh": row["spinKindZh"],
            "side": row["sideAbs"],
            "spinLevel": "中" if abs(row["spinX"]) > 1e-9 else "无",
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
            "cutAngleDeg": row["cutAngleDeg"],
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
            "v21 W3：坐标由 scripts/v21_w3_angle_spin_coords.py 推导；"
            "袋口 AngleSceneCalculator (0.5,0.5209)；"
            "顺塞=切向同侧塞、反塞=异侧塞；让点引 W1：左塞→向左让。"
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
        token = row["id"]
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


def tutorial_formation(row: dict) -> dict:
    title = f"{row['id']} · {int(row['theta'])}°·{row['spinKindZh']}"
    if "distanceBand" in row:
        title += f"·{row['distanceBand']}距"
    title += f"·{row['cutSide']}切"
    spin_txt = (
        "无塞"
        if abs(row["spinX"]) < 1e-9
        else f"{'左塞' if row['spinX'] > 0 else '右塞'}（|spinX|={abs(row['spinX']):.2f}R）"
    )
    kind_explain = {
        "running": "顺塞：塞侧与切侧同侧，投掷通常让目标球变厚",
        "reverse": "反塞：塞侧与切侧异侧，投掷通常让目标球变薄",
        "none": "无塞对照：只有切角，无侧旋投掷",
    }[row["spinKind"]]
    return {
        "id": row["id"],
        "title": title,
        "sections": [
            {
                "title": "技术原理",
                "content": (
                    f"本球形切角 {int(row['theta'])}°、{row['cutSide']}切、{spin_txt}、中杆。"
                    f"{kind_explain}。{aim_hint(row['spinX'])}。"
                    "挤偏与力度无关——力度只影响走位与洗袋风险，不改变让点方向。"
                ),
            },
            {
                "title": "怎么打",
                "content": (
                    (
                        "中心击球，瞄准正确接触点出杆；先建立无塞基准手感。"
                        if abs(row["spinX"]) < 1e-9
                        else (
                            f"按档位加{'左' if row['spinX'] > 0 else '右'}塞，"
                            f"瞄准时{'向左' if row['spinX'] > 0 else '向右'}让开一点再出杆；"
                        )
                    )
                    + f"力度约 {row['velocity']:.1f} m/s。"
                    "目标只有 8 号进下中袋，不必管母球停哪。"
                ),
            },
            {
                "title": "自检",
                "content": (
                    "达标：本球形 10 球进 6 球（仅计目标球进袋）。"
                    "若目标球系统性偏一侧，先分清是让点方向反了，还是顺/反塞搞反；"
                    "若母球跟进落袋，略减力或确认目标球距袋不要过近。"
                ),
            },
        ],
    }


def write_draft_drill(did: str, spec: dict, forms: list) -> Path:
    rep = next(r for r in forms if r["representative"])
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
        "category": "accuracy",
        "subcategory": spec["subcategory"],
        "ballType": ["chinese8"],
        "level": spec["level"],
        "difficulty": spec["difficulty"],
        "isPremium": spec["isPremium"],
        "description": spec["description"],
        "coachingPoints": [
            "真变量是顺塞/反塞（塞相对切向同侧/异侧），不是绝对左右",
            "左塞挤右→瞄准向左让；右塞对称（W1 引擎实测）",
            "挤偏与力度无关——力度只改走位/洗袋风险，不改变让点方向",
            "本课判定只看目标球进袋，不计母球落点",
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
        "tutorial": {"formations": [tutorial_formation(r) for r in forms]},
        "videos": [],
    }
    out = DRILL_DIR / f"drill_{did}.json"
    out.write_text(json.dumps(drill, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return out


def main():
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    EV_DIR.mkdir(parents=True, exist_ok=True)
    PROFILE_DIR.mkdir(parents=True, exist_ok=True)
    SEQ_DIR.mkdir(parents=True, exist_ok=True)
    DRILL_DIR.mkdir(parents=True, exist_ok=True)

    # Gold standards
    f0 = solve_formation((0.5, 0.30), POCKET, 0.0, +1, 0.20)
    assert abs(f0["cue"][0] - 0.5) < 1e-12
    assert abs(f0["cut_travel"]) < 1e-9
    f45 = solve_formation((0.5, 0.30), POCKET, 45.0, +1, 0.20)
    assert abs(f45["cut_travel"] - 45.0) < 1e-9 and f45["side_check"] == "R"
    # 顺/反映射金标准
    assert abs(spin_for("R", "running") - (-SPIN_MID)) < 1e-12
    assert abs(spin_for("R", "reverse") - (+SPIN_MID)) < 1e-12
    assert abs(spin_for("L", "running") - (+SPIN_MID)) < 1e-12
    assert abs(spin_for("L", "reverse") - (-SPIN_MID)) < 1e-12
    assert classify_spin("R", -0.30) == "running"
    assert classify_spin("R", +0.30) == "reverse"
    assert classify_spin("L", +0.30) == "running"
    assert classify_spin("L", -0.30) == "reverse"

    lines = [
        "=== v21 W3 coordinate derivation ===",
        f"pocket_code_truth={POCKET}  # AngleSceneCalculator，NOT table-geometry 0.5268",
        f"r_norm={R:.5f}",
        "running = same-side spin as cut; reverse = opposite-side",
        "spinX>0=左塞; spinX<0=右塞",
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
                f"{row['id']} θ={row['theta']} cut={row['cutSide']} kind={row['spinKind']} "
                f"spinX={row['spinX']:+.2f} sideAbs={row['sideAbs']} "
                f"dtp={row['dtp']} d={row['d']} v={row['velocity']} "
                f"cue=({row['cue']['x']},{row['cue']['y']}) "
                f"tgt=({row['target']['x']},{row['target']['y']}) "
                f"travel={row['cut_travel']} ok={row['checks_ok']} "
                f"spin_ok={row['spin_ok']} travel_ok={row['travel_ok']} side_ok={row['side_ok']}"
            )
        computed[did] = forms
        write_profile(did, forms)
        write_sequences(did, spec["nameZh"], forms)
        write_draft_drill(did, spec, forms)
        lines.append("")

    # Coverage checks
    lines.append("--- coverage ---")
    c076_kinds = {(int(r["theta"]), r["spinKind"]) for r in computed["c076"]}
    need076 = {(15, "running"), (15, "reverse"), (30, "running"), (30, "reverse")}
    lines.append(f"c076 θ×spinKind cover={need076 <= c076_kinds} got={sorted(c076_kinds)}")
    c077_kinds = {r["spinKind"] for r in computed["c077"]}
    lines.append(f"c077 spinKind cover={c077_kinds} ok={c077_kinds == {'none','running','reverse'}}")
    c078_cov = {(r.get("distanceBand"), r["sideAbs"]) for r in computed["c078"]}
    need078 = {("中", "L"), ("中", "R"), ("远", "L"), ("远", "R")}
    # sideAbs: running on R cut → R spin → sideAbs R; reverse → L
    lines.append(f"c078 dist×side cover={need078 <= c078_cov} got={sorted(c078_cov)}")
    all_ok = all_ok and need076 <= c076_kinds and c077_kinds == {"none", "running", "reverse"} and need078 <= c078_cov

    lines.append(f"ALL_BOUNDS_OK={all_ok}")
    text = "\n".join(lines) + "\n"
    print(text)
    (LOG_DIR / "coord-derive.py.out.txt").write_text(text, encoding="utf-8")
    (EV_DIR / "coverage-matrix.md").write_text(text, encoding="utf-8")
    (EV_DIR / "formations.json").write_text(
        json.dumps(computed, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    assert all_ok, "bounds/coverage check failed"


if __name__ == "__main__":
    main()
