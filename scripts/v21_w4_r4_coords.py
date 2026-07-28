#!/usr/bin/env python3
"""v21 W4 — R4 重构坐标推导（c016 / c018 / c020 / c021；退役 c019）。

坐标契约（geometry-spatial-reasoning / W1 备忘 §0）：
  - 归一化 Canvas：X∈[0,1] 左→右；Y∈[0,0.5] 上→下
  - 袋口真源 = AngleSceneCalculator（bottomCenter=(0.5000, 0.5209)）
    ⛔ 不用 table-geometry.md 手性（与代码相反）
  - 角度球：v̂=normalize(P−T)；G=T−2R·v̂；t̂=R(±θ)·v̂；C=G−d·t̂
    cut_side=+1 → 右切（cue X>进球线）；−1 → 左切
  - spinX 正=左塞 / 负=右塞；满塞=0.5（miscueLimit）

本批主题（R4，与新 6 条可区分）：
  - c016 斯登角度停球：切角 20°–45°，spin≈0，criteria 含母球 90° 滑行区
  - c018 加塞一库变线：side×塞量，criteria 含母球碰库后半台落点
  - c020/c021：组合比例×切角，criteria 含母球走位区
  ⛔ 非让点准度主题（那是 c073–c078）

输出：
  - stdout + build/v21-w4-logs/coord-derive.py.out.txt
  - build/v21-w4-evidence/{formations.json,coverage-matrix.md,criteria-contrast.md}
  - content/drill_profiles/drill_c0{16,18,20,21}.profile.json
  - content/position_play/sequences/drill_c0NN__A*-…-0杆.json
  - QiuJi/Resources/Drills/cueAction/drill_c0{16,18,20,21}.json（draft，bake 回填 animation）
"""
from __future__ import annotations

import json
import math
import uuid
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOG_DIR = ROOT / "build/v21-w4-logs"
EV_DIR = ROOT / "build/v21-w4-evidence"
PROFILE_DIR = ROOT / "content/drill_profiles"
SEQ_DIR = ROOT / "content/position_play/sequences"
DRILL_DIR = ROOT / "QiuJi/Resources/Drills/cueAction"

POCKET = (0.5000, 0.5209)  # AngleSceneCalculator code truth
POCKET_NAME = "bottomCenter"
R = 0.028575 / 2.540
TWO_R = 2 * R
Y_MIN, Y_MAX = 0.05, 0.45
X_MIN, X_MAX = 0.05, 0.95


def norm(vx, vy):
    m = math.hypot(vx, vy)
    return vx / m, vy / m


def rot2(vx, vy, deg):
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
    hx, hy = rot2(vx, vy, theta_deg if cut_side > 0 else -theta_deg)
    cx, cy = gx - d_cue_ghost * hx, gy - d_cue_ghost * hy
    cut_travel = angle_between(gx - cx, gy - cy, vx, vy)
    side_check = "R" if cx > tx + 1e-12 else ("L" if cx < tx - 1e-12 else "0")
    return {
        "cue": (cx, cy),
        "ghost": (gx, gy),
        "cut_travel": cut_travel,
        "side_check": side_check,
        "vx": vx,
        "vy": vy,
    }


def checks(cue, target):
    cx, cy = cue
    tx, ty = target
    oks = [
        ("cue_bounds", X_MIN <= cx <= X_MAX and Y_MIN <= cy <= Y_MAX),
        ("tgt_bounds", X_MIN <= tx <= X_MAX and Y_MIN <= ty <= Y_MAX),
        ("sep>2r", math.hypot(cx - tx, cy - ty) > TWO_R + 1e-9),
    ]
    return oks


def layout_row(theta, cut_lbl, dtp, d, spin_x, spin_y, velocity, fid, rank, rep, **extra):
    tx, ty = 0.5, POCKET[1] - dtp
    cut_side = 1 if cut_lbl == "R" else -1
    sol = solve_formation((tx, ty), POCKET, theta, cut_side, d)
    cue, ghost = sol["cue"], sol["ghost"]
    oks = checks(cue, (tx, ty))
    row = {
        "id": fid,
        "theta": theta,
        "cutSide": cut_lbl,
        "dtp": dtp,
        "d": d,
        "spinX": spin_x,
        "spinY": spin_y,
        "velocity": velocity,
        "difficultyRank": rank,
        "representative": rep,
        "cue": {"x": round(cue[0], 4), "y": round(cue[1], 4)},
        "target": {"x": round(tx, 4), "y": round(ty, 4)},
        "ghost": {"x": round(ghost[0], 4), "y": round(ghost[1], 4)},
        "cutAngleDeg": round(sol["cut_travel"], 2),
        "pocket": POCKET_NAME,
        "side_check": sol["side_check"],
        "checks_ok": all(b for _, b in oks) and abs(sol["cut_travel"] - theta) < 1.5,
        "checks": oks,
        **extra,
    }
    return row


# ── Drill specs ──────────────────────────────────────────────
# c016: 切角档 20/30/40/45；斯登 spin≈0
# c018: side×塞量(轻/中/满)=6；主题一库变线
# c020: 组合比例×切角 = 4（高杆+左塞）
# c021: 组合比例×切角 = 4（低杆+右塞）

def build_c016():
    specs = [
        # (fid, θ, cut, dtp, d, v, rank, rep)
        ("A1", 20, "R", 0.18, 0.22, 3.0, 1, True),
        ("A2", 30, "L", 0.18, 0.24, 3.0, 2, False),
        ("A3", 40, "R", 0.16, 0.24, 3.2, 3, False),
        ("A4", 45, "L", 0.15, 0.26, 3.2, 4, False),
    ]
    forms = []
    for fid, th, cut, dtp, d, v, rank, rep in specs:
        forms.append(
            layout_row(th, cut, dtp, d, 0.0, 0.0, v, fid, rank, rep, spinLevel="斯登", side="-")
        )
    return forms


def build_c018():
    # side × 轻/中/满；切角钉 28°（有效角度球，避开旧 1.1° 近直）
    # 左塞用右切、右塞用左切：切线方向与塞侧配合，利于碰长库后走对应半台（教学意图；
    # bake 闸门只验进袋+不洗袋，落点由 criteria 约束用户练习）
    levels = [
        ("轻", 0.15, 3.0),
        ("中", 0.30, 3.3),
        ("满", 0.50, 3.5),
    ]
    forms = []
    rank = 1
    for i, (lvl, mag, v) in enumerate(levels):
        for side, sx_sign, cut in (("L", +1, "R"), ("R", -1, "L")):
            fid = f"A{rank}"
            forms.append(
                layout_row(
                    28,
                    cut,
                    0.18,
                    0.22,
                    sx_sign * mag,
                    0.0,
                    v,
                    fid,
                    rank,
                    rank == 1,
                    side=side,
                    spinLevel=lvl,
                )
            )
            rank += 1
    return forms


def build_c020():
    # 组合比例 × 切角：跟进偏重 vs 塞偏重 × 22°/36°
    # 固定左塞家族（+spinX）
    # 大切角+塞偏重易跟进洗袋 → dtp 抬到 0.20、力度 3.0（bake 实测 A4 洗袋后改）
    combos = [
        ("跟进偏重", 0.25, 0.40),
        ("塞偏重", 0.40, 0.25),
    ]
    # (θ, dtp, d, v)
    cut_layouts = [
        (22, 0.18, 0.24, 3.2),
        (36, 0.20, 0.24, 3.0),
    ]
    forms = []
    rank = 1
    for th, dtp, d, v in cut_layouts:
        for name, sx, sy in combos:
            fid = f"A{rank}"
            forms.append(
                layout_row(
                    th,
                    "R",
                    dtp,
                    d,
                    sx,
                    sy,
                    v,
                    fid,
                    rank,
                    rank == 1,
                    combo=name,
                    side="L",
                )
            )
            rank += 1
    return forms


def build_c021():
    # 组合比例 × 切角：缩杆偏重 vs 塞偏重 × 25°/40°
    # 固定右塞家族（−spinX）+ 低杆（−spinY）
    combos = [
        ("缩杆偏重", -0.25, -0.40),
        ("塞偏重", -0.40, -0.25),
    ]
    cuts = [25, 40]
    forms = []
    rank = 1
    for th in cuts:
        for name, sx, sy in combos:
            fid = f"A{rank}"
            forms.append(
                layout_row(
                    th,
                    "L",
                    0.16,
                    0.25,
                    sx,
                    sy,
                    3.8,
                    fid,
                    rank,
                    rank == 1,
                    combo=name,
                    side="R",
                )
            )
            rank += 1
    return forms


DRILL_META = {
    "c016": {
        "nameZh": "斯登角度停球",
        "nameEn": "Stun Shot at Angle",
        "subcategory": "stun",
        "level": "L1",
        "difficulty": 3,
        "isPremium": False,
        "description": (
            "用斯登（中心击点）击打 20°–45° 有效切角球，让母球沿约 90° 切线滑行至预定区域。"
            "切角足够大时切向滑行才可见——本课练的是停球+切线方向，不是让点准度。"
        ),
        "coachingPoints": [
            "击球点在母球中心或略偏下，确保接触时接近纯滑行",
            "切角 20°–45°：切向分量足够，才能观察到母球沿 90° 方向滑行",
            "进袋后先看母球滑行方向是否落在分离角目标区，再谈力度微调",
        ],
        "standardCriteria": "10球中6球进袋且母球滑向90度方向区域",
        "builder": build_c016,
    },
    "c018": {
        "nameZh": "加塞一库变线",
        "nameEn": "Side-Spin One-Cushion",
        "subcategory": "sideSpin",
        "level": "L2",
        "difficulty": 3,
        "isPremium": True,
        "description": (
            "在有效切角球上加左/右塞（轻/中/满三档），目标球进下中袋后，母球碰库变线走到对应半台。"
            "主题是加塞碰库反弹，不是让点准度课——但瞄准时仍须按挤偏方向让点。"
        ),
        "coachingPoints": [
            "左塞使母球出射偏向右侧（挤偏）→ 瞄准须向左让点；右塞对称（W1 引擎实测）",
            "塞量越大，碰库后反弹角变化越明显——先固定切角，再对比轻/中/满",
            "判定含母球碰库后半台落点：左塞练左半台、右塞练右半台",
        ],
        "standardCriteria": "10球中5球进袋且母球碰库后走到对应半台（左塞→左半台 / 右塞→右半台）",
        "builder": build_c018,
    },
    "c020": {
        "nameZh": "高杆加塞走位",
        "nameEn": "Follow with Side Spin Position",
        "subcategory": "followSpin",
        "level": "L2",
        "difficulty": 4,
        "isPremium": True,
        "description": (
            "高杆+左塞组合走位：按「组合比例 × 切角」双档对照。"
            "跟进偏重与塞偏重在相同切角下落点不同；大切角改变切线基准方向。"
        ),
        "coachingPoints": [
            "击点同时偏高与偏左——前旋跟进 + 左塞变线",
            "先对比同一切角下「跟进偏重 / 塞偏重」落点差，再换大切角",
            "左塞挤右→瞄准向左让（W1）；本课判定含母球走位区",
        ],
        "standardCriteria": "10球中4球进袋且母球走位到左侧上半台目标区域",
        "builder": build_c020,
    },
    "c021": {
        "nameZh": "低杆加塞回位",
        "nameEn": "Draw with Side Spin Return",
        "subcategory": "drawSpin",
        "level": "L3",
        "difficulty": 4,
        "isPremium": True,
        "description": (
            "低杆+右塞组合回位：按「组合比例 × 切角」双档对照。"
            "缩杆偏重与塞偏重决定回拉弧线；大切角改变切线基准，落点差异更明显。"
        ),
        "coachingPoints": [
            "击点同时偏低与偏右——后旋缩杆 + 右塞修正弧线",
            "先对比同一切角下「缩杆偏重 / 塞偏重」，再换大切角看回位差",
            "右塞挤左→瞄准向右让（W1）；本课判定含母球回位到台面中心区域",
        ],
        "standardCriteria": "10球中3球进袋且母球走位到台面中心区域",
        "builder": build_c021,
    },
}


def write_profile(did: str, meta: dict, forms: list) -> Path:
    if did == "c016":
        fixed = {
            "pocket": "bottomCenter（代码真源 y=0.5209）",
            "spin": "斯登 (0,0)",
            "criteria": "进袋 + 母球滑向90°方向区域",
        }
        target_vars = [
            {
                "name": "cutAngle",
                "levels": ["20", "30", "40", "45"],
                "rationale": "有效切角档；sinθ 足够大才可见切线滑行（审计 R4）",
            }
        ]
        cond_vars = [
            {
                "name": "cutSide",
                "levels": ["L", "R"],
                "rationale": "左右切散布",
                "sampling": "档内交替",
            },
            {
                "name": "velocity",
                "levels": ["3.0", "3.2"],
                "rationale": "中力；过大易冲过目标区",
                "sampling": "小切角 3.0；大切角 3.2",
            },
        ]
    elif did == "c018":
        fixed = {
            "pocket": "bottomCenter",
            "cutAngle": "28°（有效角度球，避开旧 1.1° 近直）",
            "spinY": "0（中杆；主题是侧旋碰库）",
            "criteria": "进袋 + 母球碰库后对应半台",
        }
        target_vars = [
            {
                "name": "side",
                "levels": ["L", "R"],
                "rationale": "吸收原 c019；左右塞同 drill 内两档",
            },
            {
                "name": "spinLevel",
                "levels": ["轻", "中", "满"],
                "rationale": "塞量阶梯；满=0.5R",
            },
        ]
        cond_vars = [
            {
                "name": "velocity",
                "levels": ["3.0", "3.3", "3.5"],
                "rationale": "随塞量略升，保证碰库动能",
                "sampling": "轻/中/满对应",
            }
        ]
    elif did == "c020":
        fixed = {
            "pocket": "bottomCenter",
            "side": "L（左塞家族）",
            "criteria": "进袋 + 母球左侧上半台",
        }
        target_vars = [
            {
                "name": "combo",
                "levels": ["跟进偏重", "塞偏重"],
                "rationale": "spinY:spinX 比例对照",
            },
            {
                "name": "cutAngle",
                "levels": ["22", "36"],
                "rationale": "切角改变切线基准方向",
            },
        ]
        cond_vars = [
            {
                "name": "velocity",
                "levels": ["3.3"],
                "rationale": "中力跟送",
                "sampling": "全档案固定",
            }
        ]
    else:
        fixed = {
            "pocket": "bottomCenter",
            "side": "R（右塞家族）",
            "criteria": "进袋 + 母球台面中心区域",
        }
        target_vars = [
            {
                "name": "combo",
                "levels": ["缩杆偏重", "塞偏重"],
                "rationale": "|spinY|:|spinX| 比例对照",
            },
            {
                "name": "cutAngle",
                "levels": ["25", "40"],
                "rationale": "大切角放大回位路线差",
            },
        ]
        cond_vars = [
            {
                "name": "velocity",
                "levels": ["3.8"],
                "rationale": "缩杆需穿透力",
                "sampling": "全档案固定",
            }
        ]

    formations = []
    for row in forms:
        vars_ = {
            "cutAngle": str(int(row["theta"])),
            "cutSide": row["cutSide"],
            "dtp": f"{row['dtp']:.2f}",
            "d": f"{row['d']:.2f}",
            "velocity": f"{row['velocity']:.1f}",
        }
        if "side" in row and row["side"] != "-":
            vars_["side"] = row["side"]
        if "spinLevel" in row:
            vars_["spinLevel"] = row["spinLevel"]
        if "combo" in row:
            vars_["combo"] = row["combo"]
        entry = {
            "id": row["id"],
            "difficultyRank": row["difficultyRank"],
            "cue": row["cue"],
            "target": row["target"],
            "pocket": POCKET_NAME,
            "cutAngleDeg": row["cutAngleDeg"],
            "spin": {"x": row["spinX"], "y": row["spinY"]},
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
            "v21 W4 R4：坐标由 scripts/v21_w4_r4_coords.py 推导；"
            "袋口 AngleSceneCalculator (0.5,0.5209)；"
            "让点方向引 W1：左塞→向左让。主题=碰库/走位，非让点准度。"
        ),
        "fixedVariables": fixed,
        "targetVariables": target_vars,
        "conditionVariables": cond_vars,
        "formations": formations,
    }
    path = PROFILE_DIR / f"drill_{did}.profile.json"
    path.write_text(json.dumps(profile, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return path


def clear_old_sequences(did: str):
    for p in SEQ_DIR.glob(f"drill_{did}__*.json"):
        p.unlink()
        print(f"removed old seq {p.name}")


def write_sequences(did: str, name_zh: str, forms: list) -> list[Path]:
    clear_old_sequences(did)
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


def tutorial_formation(did: str, row: dict, name_zh: str) -> dict:
    if did == "c016":
        title = f"{row['id']} · 切角{int(row['theta'])}°·{row['cutSide']}切"
        content_why = (
            f"切角设计 {int(row['theta'])}°（实测≈{row['cutAngleDeg']}°），斯登中心击点。"
            "切向分量 ∝ sin(θ)，本档足够观察母球沿约 90° 切线滑行。"
        )
        content_how = (
            f"中心或略偏下击点，力度约 {row['velocity']:.1f} m/s。"
            "先预判分离方向，再出杆；目标球进下中袋，母球滑入 90° 方向区。"
        )
    elif did == "c018":
        side = row["side"]
        lvl = row["spinLevel"]
        aim = "向左" if side == "L" else "向右"
        title = f"{row['id']} · {'左塞' if side == 'L' else '右塞'}·{lvl}档"
        content_why = (
            f"{'左' if side == 'L' else '右'}塞 {lvl}档（|spinX|={abs(row['spinX']):.2f}R），"
            f"切角 28°。主题是碰库变线走到{'左' if side == 'L' else '右'}半台。"
            f"瞄准时须{aim}让点（W1：{'左塞挤右' if side == 'L' else '右塞挤左'}）。"
        )
        content_how = (
            f"按档位加{'左' if side == 'L' else '右'}塞，瞄准{aim}让开再出杆；"
            f"力度约 {row['velocity']:.1f} m/s。进袋后确认母球碰库并停在对应半台。"
        )
    elif did == "c020":
        title = f"{row['id']} · {row['combo']}·切角{int(row['theta'])}°"
        content_why = (
            f"高杆+左塞，组合「{row['combo']}」(spin=({row['spinX']:+.2f},{row['spinY']:+.2f}))，"
            f"切角 {int(row['theta'])}°。对照另一组合/切角看落点差。"
        )
        content_how = (
            f"打点偏高偏左，力度约 {row['velocity']:.1f} m/s；左塞→瞄准向左让。"
            "目标：进袋且母球走到左侧上半台。"
        )
    else:
        title = f"{row['id']} · {row['combo']}·切角{int(row['theta'])}°"
        content_why = (
            f"低杆+右塞，组合「{row['combo']}」(spin=({row['spinX']:+.2f},{row['spinY']:+.2f}))，"
            f"切角 {int(row['theta'])}°。对照另一组合/切角看回位差。"
        )
        content_how = (
            f"打点偏低偏右，力度约 {row['velocity']:.1f} m/s；右塞→瞄准向右让。"
            "目标：进袋且母球回位到台面中心区域。"
        )
    return {
        "id": row["id"],
        "title": title,
        "sections": [
            {"title": "技术原理", "content": content_why},
            {"title": "怎么打", "content": content_how},
            {
                "title": "自检",
                "content": (
                    f"对照 standardCriteria：进袋 + 母球落点区。"
                    f"切角设计 {int(row['theta'])}° / 实测≈{row['cutAngleDeg']}°。"
                ),
            },
        ],
    }


def write_draft_drill(did: str, meta: dict, forms: list) -> Path:
    rep = next(r for r in forms if r["representative"])
    animation = {
        "cueBall": {"start": rep["cue"], "path": [rep["target"]]},
        "targetBall": {"start": rep["target"], "path": [{"x": 0.5, "y": 0.5209}]},
        "pocket": POCKET_NAME,
        "cueDirection": {"x": 0.5, "y": 0.5},
        "source": "pending_bake",
    }
    drill = {
        "id": f"drill_{did}",
        "nameZh": meta["nameZh"],
        "nameEn": meta["nameEn"],
        "category": "cueAction",
        "subcategory": meta["subcategory"],
        "ballType": ["chinese8"],
        "level": meta["level"],
        "difficulty": meta["difficulty"],
        "isPremium": meta["isPremium"],
        "description": meta["description"],
        "coachingPoints": meta["coachingPoints"],
        "standardCriteria": meta["standardCriteria"],
        "sets": {"defaultSets": len(forms), "defaultBallsPerSet": 10},
        "animation": animation,
        "shotIntent": {
            "version": 1,
            "shots": [
                {
                    "cue": rep["cue"],
                    "target": rep["target"],
                    "pocket": POCKET_NAME,
                    "velocity": rep["velocity"],
                    "spin": {"x": rep["spinX"], "y": rep["spinY"]},
                }
            ],
        },
        "tutorial": {
            "formations": [tutorial_formation(did, r, meta["nameZh"]) for r in forms]
        },
        "videos": [],
    }
    out = DRILL_DIR / f"drill_{did}.json"
    out.write_text(json.dumps(drill, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return out


def write_criteria_contrast():
    md = """# v21 W4 — standardCriteria 对照表（R4 vs 新 6 条）

| id | 名称 | standardCriteria | 含母球落点？ | 主题 |
|---|---|---|---|---|
| c016 | 斯登角度停球 | 10球中6球进袋且母球滑向90度方向区域 | ✅ | R4 斯登切线滑行 |
| c018 | 加塞一库变线 | 10球中5球进袋且母球碰库后走到对应半台 | ✅ | R4 加塞碰库变线 |
| c020 | 高杆加塞走位 | 10球中4球进袋且母球走位到左侧上半台目标区域 | ✅ | R4 组合走位 |
| c021 | 低杆加塞回位 | 10球中3球进袋且母球走位到台面中心区域 | ✅ | R4 组合回位 |
| c073 | 挤偏认知·直球近台 | 每个球形10球进6球（只计目标球进袋，不计母球落点） | ❌ | 新·让点准度 |
| c074 | 挤偏放大·直球长台 | 同上（仅进袋） | ❌ | 新·让点准度 |
| c075 | 塞量阶梯 | 同上（仅进袋） | ❌ | 新·让点准度 |
| c076 | 小角度带塞进袋 | 同上（仅进袋） | ❌ | 新·让点准度 |
| c077 | 中大角度带塞进袋 | 同上（仅进袋） | ❌ | 新·让点准度 |
| c078 | 远台带塞准度 | 同上（仅进袋） | ❌ | 新·让点准度 |

**边界红线**：R4 四条必须含母球落点/走位；新 6 条只有进袋率。⛔ 未在 R4 塞入让点准度主题。
"""
    (EV_DIR / "criteria-contrast.md").write_text(md, encoding="utf-8")


def retire_c019():
    """删除 c019 drill JSON + 序列 + boards 由 tryout-sync 清理；缩略图可选删。"""
    removed = []
    for p in [
        DRILL_DIR / "drill_c019.json",
        ROOT / "QiuJi/Resources/DrillThumbnails/drill_c019.png",
    ]:
        if p.exists():
            p.unlink()
            removed.append(str(p))
    for p in SEQ_DIR.glob("drill_c019__*.json"):
        p.unlink()
        removed.append(str(p))
    return removed


def patch_index():
    idx_path = ROOT / "QiuJi/Resources/Drills/index.json"
    data = json.loads(idx_path.read_text(encoding="utf-8"))
    for cat in data["categories"]:
        if cat["category"] == "cueAction":
            before = list(cat["drills"])
            cat["drills"] = [d for d in cat["drills"] if d != "drill_c019"]
            after = cat["drills"]
            break
    else:
        raise RuntimeError("cueAction category missing")
    idx_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    total = sum(len(c["drills"]) for c in data["categories"])
    return before, after, total


def main():
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    EV_DIR.mkdir(parents=True, exist_ok=True)
    PROFILE_DIR.mkdir(parents=True, exist_ok=True)
    SEQ_DIR.mkdir(parents=True, exist_ok=True)

    # Gold: 45° R cut should place cue to the right of target
    gold = solve_formation((0.5, POCKET[1] - 0.18), POCKET, 45, +1, 0.22)
    assert gold["side_check"] == "R", gold
    assert abs(gold["cut_travel"] - 45) < 0.5, gold["cut_travel"]

    lines = [
        "=== v21 W4 R4 coordinate derivation ===",
        f"pocket_code_truth={POCKET}  # AngleSceneCalculator，NOT table-geometry",
        f"r_norm={R:.5f} twoR={TWO_R:.5f}",
        "spinX+ = left english; full=0.5",
        "",
    ]
    computed = {}
    all_ok = True
    for did, meta in DRILL_META.items():
        lines.append(f"--- drill_{did} {meta['nameZh']} ---")
        forms = meta["builder"]()
        for row in forms:
            all_ok = all_ok and row["checks_ok"]
            extra = ""
            if "side" in row:
                extra += f" side={row['side']}"
            if "spinLevel" in row:
                extra += f" lvl={row['spinLevel']}"
            if "combo" in row:
                extra += f" combo={row['combo']}"
            lines.append(
                f"{row['id']} θ={row['theta']} cut={row['cutSide']} "
                f"spin=({row['spinX']:+.2f},{row['spinY']:+.2f}) v={row['velocity']} "
                f"cue=({row['cue']['x']},{row['cue']['y']}) "
                f"tgt=({row['target']['x']},{row['target']['y']}) "
                f"cutMeas={row['cutAngleDeg']} sideChk={row['side_check']} "
                f"ok={row['checks_ok']}{extra}"
            )
        computed[did] = forms
        write_profile(did, meta, forms)
        write_sequences(did, meta["nameZh"], forms)
        write_draft_drill(did, meta, forms)
        lines.append("")

    removed = retire_c019()
    before, after, total = patch_index()
    write_criteria_contrast()

    lines.append(f"c019_retired_files={removed}")
    lines.append(f"cueAction_before={before}")
    lines.append(f"cueAction_after={after}")
    lines.append(f"index_total_drills={total}")
    lines.append(f"ALL_BOUNDS_OK={all_ok}")
    lines.append(f"formation_counts=" + ", ".join(f"{k}:{len(v)}" for k, v in computed.items()))
    text = "\n".join(lines) + "\n"
    print(text)
    (LOG_DIR / "coord-derive.py.out.txt").write_text(text, encoding="utf-8")
    (EV_DIR / "coverage-matrix.md").write_text(text, encoding="utf-8")
    (EV_DIR / "formations.json").write_text(
        json.dumps(computed, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    assert all_ok, "bounds / cut-angle check failed"
    assert total == 77, f"expected index total 77, got {total}"
    assert "drill_c019" not in after


if __name__ == "__main__":
    main()
