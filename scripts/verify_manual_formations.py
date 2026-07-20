#!/usr/bin/env python3
"""设计后验算脚本（人工球形质检）— 方案 B4。

坐标契约（geometry-spatial-reasoning 回显；口径照抄 scripts/b5_audit_drills.py）：
- Canvas 归一化 2D 系（真源 .kiro/steering/table-geometry.md）：
  原点=台面左上角（顶视图），X∈[0,1] 左→右，Y∈[0,0.5] 上→下，
  单位=台面内沿长度 2.540 m 的百分比，2:1 台面。
- 球半径 r = 0.028575/2.540 = 0.01125（归一化）。
- 切角双口径（与 b5_audit_drills.py 一致）：
  * 行进线切角 cutAngle / cut_travel = 白球→ghost 行进方向 与 进球线(目标球心→袋口) 的夹角；
  * 表观切角 cut_apparent = 白球心→目标球心连线 与 进球线 的夹角。
  ghost = target − 2r·normalize(pocket − target)。
- 入袋角 entryAngle = 进球线反向（袋口→目标）与袋口台内轴向的夹角；正入袋=0°。
- 近库 nearRail：白球距最近库边 < 0.06（归一化）。
- 侧别 side（B3 词典 / c053 profile）：L=左切、R=右切；
  映射自 b5 叉积：Y 向下系中 cross>0 → L，cross<0 → R；|cut|<2° → 0（直线）。

变量命名对齐 docs/research/20260720-球形设计变量词典.md（cutAngle/side/dtp/d/nearRail/entryAngle/pocket）。

用法：
  # 单 drill（读 sequences/ 全部球形 + drill JSON pocket 语境；写报告）
  python3 scripts/verify_manual_formations.py drill_c053

  # 全库扫描（所有在 sequences/ 下有球形的 drill）
  python3 scripts/verify_manual_formations.py --all

  # 仅跑 c053 A1–A8 金标准回归（对照 profile；切角误差 < 0.5°）
  python3 scripts/verify_manual_formations.py --gold

  # 组合：金标准 + 指定 drill 报告
  python3 scripts/verify_manual_formations.py --gold drill_c053

输出：
  build/manual-formation-report-<drillId>.txt
  （含逐球形取值表 + 目标/条件变量覆盖矩阵；空档以 ★EMPTY★ 高亮）
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
SEQUENCES = ROOT / "content" / "position_play" / "sequences"
PROFILES = ROOT / "content" / "drill_profiles"
DRILLS = ROOT / "QiuJi" / "Resources" / "Drills"
BUILD = ROOT / "build"

# ---- 几何常量：与 scripts/b5_audit_drills.py 逐字对齐（禁自创）----
R = 0.028575 / 2.540  # 球半径（归一化）= 0.01125
TABLE_LEN_M = 2.540
NEAR_RAIL_THRESH = 0.06
CUT_STRAIGHT_DEG = 2.0
GOLD_CUT_TOL_DEG = 0.5

POCKETS = {
    "topLeft": (-0.0165, -0.0165),
    "topRight": (+1.0165, -0.0165),
    "bottomLeft": (-0.0165, +0.5165),
    "bottomRight": (+1.0165, +0.5165),
    "topCenter": (0.5, -0.0268),
    "bottomCenter": (0.5, +0.5268),
}
POCKET_AXIS = {
    "topLeft": (math.cos(math.radians(45)), math.sin(math.radians(45))),
    "topRight": (-math.cos(math.radians(45)), math.sin(math.radians(45))),
    "bottomLeft": (math.cos(math.radians(45)), -math.sin(math.radians(45))),
    "bottomRight": (-math.cos(math.radians(45)), -math.sin(math.radians(45))),
    "topCenter": (0.0, 1.0),
    "bottomCenter": (0.0, -1.0),
}

# B3 词典常用档位（无 profile 时覆盖矩阵默认轴）
DEFAULT_TARGET_LEVELS = {
    "cutAngle": ["15", "30", "45", "60"],
    "side": ["L", "R"],
}
DEFAULT_CONDITION_LEVELS = {
    "dtp": ["0.12", "0.15", "0.20", "0.25"],
    "d": ["0.18", "0.22", "0.25", "0.28", "0.35", "0.38"],
    "nearRail": ["false", "true"],
}


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1])


def norm(v):
    return math.hypot(v[0], v[1])


def unit(v):
    n = norm(v)
    if n < 1e-15:
        raise ValueError("zero-length vector")
    return (v[0] / n, v[1] / n)


def ang_between(u, v):
    """两向量夹角（度，0–180）。与 b5_audit_drills.py 同实现。"""
    dot = u[0] * v[0] + u[1] * v[1]
    den = norm(u) * norm(v)
    if den < 1e-15:
        raise ValueError("zero-length vector in ang_between")
    dot = max(-1.0, min(1.0, dot / den))
    return math.degrees(math.acos(dot))


def rail_dist(p):
    """到最近库边的归一化距离（有效区边界按 0/1/0/0.5 台内沿）。"""
    return min(p[0], 1.0 - p[0], p[1], 0.5 - p[1])


def fmt_m(d: float) -> str:
    return f"{d:.4f} ({d * TABLE_LEN_M:.3f} m)"


def analyze_geometry(cue: tuple[float, float], tgt: tuple[float, float], pocket_name: str) -> dict[str, Any]:
    """按 b5 口径计算切角双口径 / d / dtp / nearRail / entryAngle / side。"""
    if pocket_name not in POCKETS:
        raise ValueError(f"unknown pocket: {pocket_name}")
    p = POCKETS[pocket_name]
    line_v = unit(sub(p, tgt))  # 进球线方向 T→P
    ghost = (tgt[0] - 2 * R * line_v[0], tgt[1] - 2 * R * line_v[1])
    travel_v = unit(sub(ghost, cue))
    cut_travel = ang_between(travel_v, line_v)
    cut_apparent = ang_between(unit(sub(tgt, cue)), line_v)
    d_cue_ghost = norm(sub(ghost, cue))
    dtp = norm(sub(p, tgt))
    # 入袋角：袋口→目标（= −进球线）与袋口台内轴向的夹角
    entry_angle = ang_between((-line_v[0], -line_v[1]), POCKET_AXIS[pocket_name])
    cross = line_v[0] * (cue[1] - tgt[1]) - line_v[1] * (cue[0] - tgt[0])
    if abs(cut_travel) < CUT_STRAIGHT_DEG:
        side = "0"
    elif cross > 0:
        side = "L"
    else:
        side = "R"
    cue_rail = rail_dist(cue)
    tgt_rail = rail_dist(tgt)
    near_rail = cue_rail < NEAR_RAIL_THRESH
    return {
        "pocket": pocket_name,
        "ghost": ghost,
        "cutAngle": cut_travel,  # B3 规范口径 = 行进线切角
        "cut_travel": cut_travel,
        "cut_apparent": cut_apparent,
        "d": d_cue_ghost,
        "dtp": dtp,
        "entryAngle": entry_angle,
        "side": side,
        "nearRail": near_rail,
        "cue_rail": cue_rail,
        "tgt_rail": tgt_rail,
        "line_v": line_v,
        "cross": cross,
    }


def _selftest() -> None:
    """内嵌金标准样例（照抄 b5_audit_drills._selftest 关键断言）。"""
    p = POCKETS["bottomCenter"]
    tgt = (0.5, 0.43)
    cue = (0.5, 0.25)
    g = analyze_geometry(cue, tgt, "bottomCenter")
    assert abs(g["cut_travel"]) < 1e-9
    assert abs(g["cut_apparent"]) < 1e-9
    assert abs(g["ghost"][1] - (tgt[1] - 2 * R)) < 1e-12

    tgt = (0.5, 0.4068)
    cue = (0.6980, 0.1863)
    g = analyze_geometry(cue, tgt, "bottomCenter")
    assert abs(g["cut_travel"] - 45.0) < 0.02, g["cut_travel"]
    assert abs(g["cut_apparent"] - 41.9224) < 0.01, g["cut_apparent"]
    assert g["side"] == "R"
    assert abs(g["entryAngle"]) < 1e-9


def find_drill_json(drill_id: str) -> Path | None:
    matches = list(DRILLS.glob(f"**/{drill_id}.json"))
    return matches[0] if matches else None


def load_drill(drill_id: str) -> dict[str, Any] | None:
    path = find_drill_json(drill_id)
    if not path:
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def resolve_pocket(drill: dict[str, Any] | None, seq: dict[str, Any]) -> str | None:
    """从 steps.shot / drill animation / shotIntent 解析袋口语境。"""
    for st in seq.get("steps") or []:
        pocket = (st.get("shot") or {}).get("pocket")
        if pocket:
            return pocket
    if not drill:
        return None
    anim = drill.get("animation") or {}
    if anim.get("pocket"):
        return anim["pocket"]
    shots = (drill.get("shotIntent") or {}).get("shots") or []
    if shots and shots[0].get("pocket"):
        return shots[0]["pocket"]
    return None


def pick_target_key(on_table: dict[str, Any]) -> str | None:
    keys = [k for k in on_table if k != "cueBall"]
    if not keys:
        return None
    # 优先常见目标球键
    for pref in ("_8", "8", "objectBall", "targetBall", "_1", "1"):
        if pref in on_table:
            return pref
    return sorted(keys)[0]


def parse_formation_token(filename: str, drill_id: str) -> str:
    """从 drill_c053__A1-… 或 drill_c006__manual01-… 解析 token。"""
    stem = Path(filename).stem
    prefix = f"{drill_id}__"
    if not stem.startswith(prefix):
        return stem
    rest = stem[len(prefix) :]
    # token 到第一个「-」之前（A1 / manual01 / Snipaste_…）
    # 人工/字母数字 token；截图 token 也可能含下划线
    m = re.match(r"^([^-]+)", rest)
    return m.group(1) if m else rest


def list_sequence_files(drill_id: str | None = None) -> list[Path]:
    if not SEQUENCES.exists():
        return []
    if drill_id:
        return sorted(SEQUENCES.glob(f"{drill_id}__*.json"))
    return sorted(SEQUENCES.glob("drill_*.json"))


def drills_with_sequences() -> list[str]:
    ids: set[str] = set()
    for p in list_sequence_files():
        m = re.match(r"^(drill_c\d+)__", p.name)
        if m:
            ids.add(m.group(1))
    return sorted(ids)


def load_profile(drill_id: str) -> dict[str, Any] | None:
    path = PROFILES / f"{drill_id}.profile.json"
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def bin_cut_angle(deg: float) -> str:
    """将实测切角归到最近常用档（15/30/45/60）；<7.5° 记 0。"""
    if deg < 7.5:
        return "0"
    for lvl in (15, 30, 45, 60):
        if abs(deg - lvl) <= 7.5:
            return str(lvl)
    return f"{deg:.0f}"


def nearest_level(value: float, levels: list[str], tol: float = 0.02) -> str | None:
    best = None
    best_d = tol
    for lv in levels:
        try:
            d = abs(float(lv) - value)
        except ValueError:
            continue
        if d <= best_d:
            best_d = d
            best = lv
    return best


def formation_record(path: Path, drill_id: str, drill: dict[str, Any] | None) -> dict[str, Any]:
    seq = json.loads(path.read_text(encoding="utf-8"))
    token = parse_formation_token(path.name, drill_id)
    on_table = (seq.get("initial") or {}).get("onTable") or {}
    cue_raw = on_table.get("cueBall")
    tgt_key = pick_target_key(on_table)
    tgt_raw = on_table.get(tgt_key) if tgt_key else None
    pocket = resolve_pocket(drill, seq)
    rec: dict[str, Any] = {
        "file": path.name,
        "token": token,
        "name": seq.get("name", ""),
        "steps": len(seq.get("steps") or []),
        "cue": None,
        "target": None,
        "targetKey": tgt_key,
        "pocket": pocket,
        "ok": False,
        "error": None,
        "geom": None,
    }
    if not cue_raw:
        rec["error"] = "missing cueBall in initial.onTable"
        return rec
    cue = (float(cue_raw["x"]), float(cue_raw["y"]))
    rec["cue"] = cue
    if not tgt_raw:
        rec["error"] = "missing target ball in initial.onTable"
        return rec
    tgt = (float(tgt_raw["x"]), float(tgt_raw["y"]))
    rec["target"] = tgt
    if not pocket:
        rec["error"] = "cannot resolve pocket (no steps.shot.pocket / drill animation|shotIntent)"
        return rec
    try:
        geom = analyze_geometry(cue, tgt, pocket)
    except Exception as e:  # noqa: BLE001 — 报告层捕获，禁止吞掉后伪造成功
        rec["error"] = f"geometry error: {e}"
        return rec
    rec["geom"] = geom
    rec["ok"] = True
    return rec


def levels_from_profile(profile: dict[str, Any] | None) -> tuple[dict[str, list[str]], dict[str, list[str]]]:
    target = {k: list(v) for k, v in DEFAULT_TARGET_LEVELS.items()}
    cond = {k: list(v) for k, v in DEFAULT_CONDITION_LEVELS.items()}
    if not profile:
        return target, cond
    for tv in profile.get("targetVariables") or []:
        name = tv.get("name")
        lv = tv.get("levels")
        if name and lv:
            target[name] = [str(x) for x in lv]
    for cv in profile.get("conditionVariables") or []:
        name = cv.get("name")
        lv = cv.get("levels")
        if name and lv:
            cond[name] = [str(x) for x in lv]
    return target, cond


def assigned_bins(rec: dict[str, Any], target_lv: dict[str, list[str]], cond_lv: dict[str, list[str]]) -> dict[str, str | None]:
    if not rec.get("ok") or not rec.get("geom"):
        return {k: None for k in list(target_lv) + list(cond_lv)}
    g = rec["geom"]
    out: dict[str, str | None] = {}
    # cutAngle：优先归到目标档位表
    cut_bins = target_lv.get("cutAngle", DEFAULT_TARGET_LEVELS["cutAngle"])
    cut_bin = None
    for lv in cut_bins:
        try:
            if abs(float(lv) - g["cutAngle"]) <= GOLD_CUT_TOL_DEG:
                cut_bin = lv
                break
        except ValueError:
            continue
    if cut_bin is None:
        cut_bin = bin_cut_angle(g["cutAngle"])
    out["cutAngle"] = cut_bin
    out["side"] = g["side"] if g["side"] in target_lv.get("side", ["L", "R"]) else g["side"]
    out["dtp"] = nearest_level(g["dtp"], cond_lv.get("dtp", DEFAULT_CONDITION_LEVELS["dtp"]), tol=0.02)
    out["d"] = nearest_level(g["d"], cond_lv.get("d", DEFAULT_CONDITION_LEVELS["d"]), tol=0.02)
    out["nearRail"] = "true" if g["nearRail"] else "false"
    return out


def render_value_table(recs: list[dict[str, Any]]) -> list[str]:
    lines = []
    lines.append("=" * 96)
    lines.append("逐球形取值表（B3 命名）")
    lines.append("=" * 96)
    hdr = (
        f"{'token':<10} {'cutAngle':>9} {'cut_app':>8} {'side':>4} "
        f"{'d':>8} {'dtp':>8} {'entry':>7} {'nearRail':>8} {'pocket':<14} cue / target"
    )
    lines.append(hdr)
    lines.append("-" * 96)
    for r in recs:
        if not r["ok"]:
            lines.append(f"{r['token']:<10} ⚠ {r['error']}")
            continue
        g = r["geom"]
        cue = r["cue"]
        tgt = r["target"]
        lines.append(
            f"{r['token']:<10} {g['cutAngle']:9.4f} {g['cut_apparent']:8.4f} {g['side']:>4} "
            f"{g['d']:8.4f} {g['dtp']:8.4f} {g['entryAngle']:7.2f} "
            f"{str(g['nearRail']).lower():>8} {g['pocket']:<14} "
            f"({cue[0]:.4f},{cue[1]:.4f}) / ({tgt[0]:.4f},{tgt[1]:.4f})"
        )
        lines.append(f"           file={r['file']}  name={r['name']}  targetKey={r['targetKey']}")
    return lines


def render_coverage_matrix(
    recs: list[dict[str, Any]],
    target_lv: dict[str, list[str]],
    cond_lv: dict[str, list[str]],
) -> list[str]:
    lines = []
    lines.append("")
    lines.append("=" * 96)
    lines.append("覆盖矩阵（目标/条件变量档位 × 球形；空档高亮 ★EMPTY★）")
    lines.append("=" * 96)

    bins_by_token: dict[str, dict[str, str | None]] = {}
    for r in recs:
        bins_by_token[r["token"]] = assigned_bins(r, target_lv, cond_lv)

    # 目标变量：cutAngle × side
    cut_levels = target_lv.get("cutAngle", DEFAULT_TARGET_LEVELS["cutAngle"])
    side_levels = target_lv.get("side", DEFAULT_TARGET_LEVELS["side"])
    lines.append("")
    lines.append("【目标变量】cutAngle × side")
    cell: dict[tuple[str, str], list[str]] = {(c, s): [] for c in cut_levels for s in side_levels}
    for tok, b in bins_by_token.items():
        key = (b.get("cutAngle"), b.get("side"))
        if key[0] in cut_levels and key[1] in side_levels:
            cell[(key[0], key[1])].append(tok)
    # 表头
    lines.append(f"{'cutAngle\\\\side':<14}" + "".join(f"{s:^12}" for s in side_levels))
    empty_cells = 0
    for c in cut_levels:
        row = f"{c:<14}"
        for s in side_levels:
            toks = cell[(c, s)]
            if toks:
                row += f"{','.join(toks):^12}"
            else:
                row += f"{'★EMPTY★':^12}"
                empty_cells += 1
        lines.append(row)
    lines.append(f"  空档数 cutAngle×side = {empty_cells}")

    # 条件变量单轴覆盖
    for name, levels in cond_lv.items():
        lines.append("")
        lines.append(f"【条件变量】{name}")
        cov: dict[str, list[str]] = {lv: [] for lv in levels}
        extra: dict[str, list[str]] = {}
        for tok, b in bins_by_token.items():
            val = b.get(name)
            if val is None:
                extra.setdefault("(unbinned)", []).append(tok)
            elif val in cov:
                cov[val].append(tok)
            else:
                extra.setdefault(val, []).append(tok)
        empty_n = 0
        for lv in levels:
            toks = cov[lv]
            mark = ", ".join(toks) if toks else "★EMPTY★"
            if not toks:
                empty_n += 1
            lines.append(f"  {lv:<10} → {mark}")
        for k, toks in sorted(extra.items()):
            lines.append(f"  {k:<10} → {', '.join(toks)}  (档外)")
        lines.append(f"  空档数 {name} = {empty_n}")

    return lines


def write_report(drill_id: str, recs: list[dict[str, Any]], profile: dict[str, Any] | None) -> Path:
    BUILD.mkdir(parents=True, exist_ok=True)
    out_path = BUILD / f"manual-formation-report-{drill_id}.txt"
    target_lv, cond_lv = levels_from_profile(profile)
    lines: list[str] = []
    lines.append(f"manual formation report — {drill_id}")
    lines.append(f"sequences_dir = {SEQUENCES}")
    lines.append(f"formations = {len(recs)}")
    lines.append(f"profile = {'yes' if profile else 'no (using B3 default bins)'}")
    if profile:
        fv = profile.get("fixedVariables") or {}
        lines.append(f"fixedVariables = {fv}")
    lines.append("")
    lines.extend(render_value_table(recs))
    lines.extend(render_coverage_matrix(recs, target_lv, cond_lv))
    lines.append("")
    lines.append("单位说明：cutAngle/cut_apparent/entryAngle = deg；d/dtp = 归一化（台长比例）。")
    lines.append("口径真源：scripts/b5_audit_drills.py；命名真源：20260720-球形设计变量词典.md")
    text = "\n".join(lines) + "\n"
    out_path.write_text(text, encoding="utf-8")
    return out_path


def run_gold_c053() -> tuple[bool, list[str]]:
    """c053 A1–A8 金标准回归：切角 vs profile.cutAngleDeg，误差 < 0.5°。"""
    lines: list[str] = []
    lines.append("=" * 96)
    lines.append("GOLD: drill_c053 A1–A8 vs content/drill_profiles/drill_c053.profile.json")
    lines.append(f"tolerance: |cut_travel − cutAngleDeg| < {GOLD_CUT_TOL_DEG}°")
    lines.append("=" * 96)
    profile = load_profile("drill_c053")
    if not profile:
        lines.append("FAIL: missing drill_c053.profile.json")
        return False, lines
    by_id = {f["id"]: f for f in profile.get("formations") or []}
    expected_ids = [f"A{i}" for i in range(1, 9)]
    all_ok = True
    for fid in expected_ids:
        pf = by_id.get(fid)
        if not pf:
            lines.append(f"FAIL {fid}: missing in profile")
            all_ok = False
            continue
        matches = list(SEQUENCES.glob(f"drill_c053__{fid}-*.json"))
        if not matches:
            lines.append(f"FAIL {fid}: missing sequence file under {SEQUENCES}")
            all_ok = False
            continue
        path = matches[0]
        seq = json.loads(path.read_text(encoding="utf-8"))
        on_table = (seq.get("initial") or {}).get("onTable") or {}
        cue_raw = on_table.get("cueBall")
        tgt_key = pick_target_key(on_table)
        tgt_raw = on_table.get(tgt_key) if tgt_key else None
        if not cue_raw or not tgt_raw:
            lines.append(f"FAIL {fid}: incomplete initial ({path.name})")
            all_ok = False
            continue
        cue = (float(cue_raw["x"]), float(cue_raw["y"]))
        tgt = (float(tgt_raw["x"]), float(tgt_raw["y"]))
        pocket = pf.get("pocket") or "bottomCenter"
        # 坐标 4 位小数对照（profile 标称值）
        pc, pt = pf["cue"], pf["target"]
        coord_ok = (
            abs(cue[0] - pc["x"]) < 5e-5
            and abs(cue[1] - pc["y"]) < 5e-5
            and abs(tgt[0] - pt["x"]) < 5e-5
            and abs(tgt[1] - pt["y"]) < 5e-5
        )
        g = analyze_geometry(cue, tgt, pocket)
        expect = float(pf["cutAngleDeg"])
        err = abs(g["cut_travel"] - expect)
        cut_ok = err < GOLD_CUT_TOL_DEG
        # 变量档位对照（报差异，不调参）
        vars_pf = pf.get("variables") or {}
        side_ok = g["side"] == vars_pf.get("side")
        near_ok = (str(g["nearRail"]).lower() == str(vars_pf.get("nearRail")).lower())
        d_ok = abs(g["d"] - float(vars_pf["d"])) < 0.005 if "d" in vars_pf else True
        dtp_ok = abs(g["dtp"] - float(vars_pf["dtp"])) < 0.005 if "dtp" in vars_pf else True
        status = "PASS" if (cut_ok and coord_ok) else "FAIL"
        if status == "FAIL":
            all_ok = False
        lines.append(
            f"{status} {fid}: cut_travel={g['cut_travel']:.4f}° expect={expect:.1f}° "
            f"err={err:.4f}° cut_app={g['cut_apparent']:.4f}° "
            f"side={g['side']}(pf={vars_pf.get('side')}) "
            f"d={g['d']:.4f}(pf={vars_pf.get('d')}) "
            f"dtp={g['dtp']:.4f}(pf={vars_pf.get('dtp')}) "
            f"nearRail={g['nearRail']}(pf={vars_pf.get('nearRail')}) "
            f"entry={g['entryAngle']:.2f}° "
            f"coord4={coord_ok} side_ok={side_ok} d_ok={d_ok} dtp_ok={dtp_ok} near_ok={near_ok}"
        )
        lines.append(
            f"       seq_cue=({cue[0]:.4f},{cue[1]:.4f}) pf_cue=({pc['x']:.4f},{pc['y']:.4f}) "
            f"seq_tgt=({tgt[0]:.4f},{tgt[1]:.4f}) pf_tgt=({pt['x']:.4f},{pt['y']:.4f}) "
            f"file={path.name}"
        )
        if not cut_ok:
            lines.append(
                f"       ⚠ 切角差异超阈：measured={g['cut_travel']:.4f} vs profile={expect} "
                f"(禁止调参；请核对序列坐标或 profile)"
            )
        if not coord_ok:
            lines.append("       ⚠ 坐标与 profile 4 位小数标称值不一致（报告差异，不改坐标）")
    lines.append("")
    lines.append("GOLD RESULT: " + ("ALL PASS" if all_ok else "FAILED"))
    return all_ok, lines


def process_drill(drill_id: str) -> tuple[Path, list[dict[str, Any]]]:
    files = list_sequence_files(drill_id)
    if not files:
        raise SystemExit(f"no sequence files for {drill_id} under {SEQUENCES}")
    drill = load_drill(drill_id)
    profile = load_profile(drill_id)
    recs = [formation_record(p, drill_id, drill) for p in files]
    out = write_report(drill_id, recs, profile)
    return out, recs


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Verify manual formations: geometry table + coverage matrix (B4)."
    )
    parser.add_argument(
        "drill_ids",
        nargs="*",
        help="drill id(s), e.g. drill_c053 (omit with --all / --gold)",
    )
    parser.add_argument("--all", action="store_true", help="scan all drills that have sequences/")
    parser.add_argument(
        "--gold",
        action="store_true",
        help="run c053 A1–A8 gold regression against profile (cut err < 0.5°)",
    )
    parser.add_argument(
        "--skip-selftest",
        action="store_true",
        help="skip embedded geometry selftest (not recommended)",
    )
    args = parser.parse_args(argv)

    if not args.skip_selftest:
        _selftest()

    log_lines: list[str] = []
    exit_code = 0

    if args.gold or (not args.all and not args.drill_ids):
        # 默认：无参数时跑金标准（便于 CI/手测）
        if not args.gold and not args.all and not args.drill_ids:
            args.gold = True
            args.drill_ids = ["drill_c053"]

    if args.gold:
        ok, glines = run_gold_c053()
        log_lines.extend(glines)
        for line in glines:
            print(line)
        if not ok:
            exit_code = 1
        # 金标准完整输出落盘
        BUILD.mkdir(parents=True, exist_ok=True)
        gold_path = BUILD / "manual-formation-report-drill_c053.gold.txt"
        gold_path.write_text("\n".join(glines) + "\n", encoding="utf-8")
        print(f"\n[wrote] {gold_path}")

    drill_ids = list(args.drill_ids)
    if args.all:
        drill_ids = drills_with_sequences()

    for did in drill_ids:
        out, recs = process_drill(did)
        summary = f"[report] {did}: formations={len(recs)} ok={sum(1 for r in recs if r['ok'])} → {out}"
        print(summary)
        log_lines.append(summary)
        # 同步打印覆盖矩阵摘要末几行
        text = out.read_text(encoding="utf-8")
        print(text)

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
