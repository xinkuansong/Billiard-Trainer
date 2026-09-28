#!/usr/bin/env python3
"""Reproduce a diagnostic sphere-shadow integration study using only the stdlib.

Reads the frozen 2026-09-21 ray-grid oracle; does not generate or install assets.
World metres: XZ horizontal, Y up. One opaque sphere, horizontal receiver normal.
The candidates are NOT the production filtered light-sample shader.
"""

import argparse
import hashlib
import json
import math
from pathlib import Path
import platform
import sys


ROOT = Path(__file__).resolve().parents[2]
RADIUS = 0.028575
LIGHT_Y = 3.0
LIGHT_HALF_X = 2.54
LIGHT_HALF_Z = 0.635
# Original sphere_panel_visibility.py oracle-convergence requirement, unchanged.
ORACLE_MAX_CONVERGENCE = 0.003
GAUSS_RULES = {
    4: (
        [-0.8611363115940526, -0.3399810435848563,
         0.3399810435848563, 0.8611363115940526],
        [0.3478548451374539, 0.6521451548625461,
         0.6521451548625461, 0.3478548451374539],
    ),
    8: (
        [-0.9602898564975363, -0.7966664774136267,
         -0.525532409916329, -0.1834346424956498,
         0.1834346424956498, 0.525532409916329,
         0.7966664774136267, 0.9602898564975363],
        [0.1012285362903763, 0.2223810344533745,
         0.3137066458778873, 0.362683783378362,
         0.362683783378362, 0.3137066458778873,
         0.2223810344533745, 0.1012285362903763],
    ),
}


def provenance(path):
    raw = path.read_bytes()
    try:
        name = str(path.relative_to(ROOT))
    except ValueError:
        name = str(path)
    return {"path": name, "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw)}


def roots(a, b, c):
    """The frozen exploratory root policy; not a production error-bound proof."""
    if abs(a) < 1e-12:
        return [] if abs(b) < 1e-12 else [-c / b]
    discriminant = b * b - 4 * a * c
    if discriminant < 0:
        return []
    q = -0.5 * (b + math.copysign(math.sqrt(discriminant), b))
    return [q / a, c / q] if q else [-b / (2 * a)]


def primitive(z, x, height):
    a = x * x + height * height
    return height * height * (
        z / (2 * a * (a + z * z))
        + math.atan(z / math.sqrt(a)) / (2 * a ** 1.5)
    )


def panel_total(point, panel_z):
    """Exact unoccluded horizontal irradiance from a rectangular solid angle."""
    x0, x1 = -LIGHT_HALF_X - point[0], LIGHT_HALF_X - point[0]
    z0, z1 = panel_z - LIGHT_HALF_Z - point[2], panel_z + LIGHT_HALF_Z - point[2]
    height = LIGHT_Y - point[1]
    vertices = [(x0, height, z0), (x0, height, z1),
                (x1, height, z1), (x1, height, z0)]
    directions = [tuple(v / math.sqrt(sum(c * c for c in p)) for v in p)
                  for p in vertices]
    total = 0.0
    for a, b in zip(directions, directions[1:] + directions[:1]):
        cross = (a[1] * b[2] - a[2] * b[1],
                 a[2] * b[0] - a[0] * b[2],
                 a[0] * b[1] - a[1] * b[0])
        size = math.sqrt(sum(c * c for c in cross))
        total += math.atan2(size, sum(x * y for x, y in zip(a, b))) * cross[1] / size
    return abs(total) * 0.5


def segmented(case, count, include_discriminant):
    point, center, panel = case["point"], case["center"], case["panel"]
    dx, height, dz = [center[i] - point[i] for i in range(3)]
    light_height = LIGHT_Y - point[1]
    radius2 = RADIUS * RADIUS
    sphere = dx * dx + height * height + dz * dz - radius2
    if sphere <= 1e-10:
        return {"value": 1.0, "evaluations": 0, "intervals": 0}
    x0, x1 = -LIGHT_HALF_X - point[0], LIGHT_HALF_X - point[0]
    z0, z1 = panel - LIGHT_HALF_Z - point[2], panel + LIGHT_HALF_Z - point[2]
    # Preserve the first draft as a distinct candidate, including its omissions.
    if not include_discriminant:
        denominator = height * height - radius2
        if denominator > 1e-10:
            extent = RADIUS * math.sqrt(dx * dx + denominator)
            x0 = max(x0, light_height * (height * dx - extent) / denominator)
            x1 = min(x1, light_height * (height * dx + extent) / denominator)
        if x1 <= x0:
            return {"value": 0.0, "evaluations": 0, "intervals": 0}
    cuts = [x0, x1]
    for z in (z0, z1):
        term = height * light_height + dz * z
        cuts.extend(x for x in roots(dx * dx - sphere, 2 * dx * term,
                                     term * term - sphere * (light_height ** 2 + z * z))
                    if x0 < x < x1)
    if include_discriminant:
        cuts.extend(x for x in roots(radius2 - height * height,
                                     2 * dx * height * light_height,
                                     (radius2 - dx * dx) * light_height ** 2)
                    if x0 < x < x1)
    cuts = sorted(set(cuts))
    nodes, weights = GAUSS_RULES[count]
    blocked, evaluations, intervals = 0.0, 0, 0
    for lower_x, upper_x in zip(cuts, cuts[1:]):
        midpoint = (lower_x + upper_x) * 0.5
        a = dz * dz - sphere
        b = 2 * dz * (dx * midpoint + height * light_height)
        c = (dx * midpoint + height * light_height) ** 2 - sphere * (midpoint ** 2 + light_height ** 2)
        if include_discriminant and b * b - 4 * a * c < 0:
            continue
        intervals += 1
        for node, weight in zip(nodes, weights):
            evaluations += 1
            x = midpoint + node * (upper_x - lower_x) * 0.5
            b = 2 * dz * (dx * x + height * light_height)
            c = (dx * x + height * light_height) ** 2 - sphere * (x * x + light_height ** 2)
            lower, upper = z0, z1
            if abs(a) < 1e-10:
                if abs(b) < 1e-10:
                    if c < 0:
                        continue
                elif b > 0:
                    lower = max(lower, -c / b)
                else:
                    upper = min(upper, -c / b)
            elif a < 0:
                discriminant = b * b - 4 * a * c
                if discriminant <= 0:
                    continue
                root = math.sqrt(discriminant)
                lower = max(lower, (-b + root) / (2 * a))
                upper = min(upper, (-b - root) / (2 * a))
            else:
                raise ValueError("Receiver is outside the validated below-sphere domain")
            if upper > lower:
                blocked += weight * (upper_x - lower_x) * 0.5 * (
                    primitive(upper, x, light_height) - primitive(lower, x, light_height)
                )
    return {"value": min(1.0, max(0.0, blocked / panel_total(point, panel))),
            "evaluations": evaluations, "intervals": intervals}


def percentile(values, percent):
    values = sorted(values)
    position = (len(values) - 1) * percent / 100
    lower = int(position)
    upper = min(lower + 1, len(values) - 1)
    return values[lower] + (position - lower) * (values[upper] - values[lower])


def statistics(errors):
    return {"rmse": math.sqrt(sum(e * e for e in errors) / len(errors)),
            "p95": percentile(errors, 95), "max": max(errors),
            "draftP95BySortedIndex": sorted(errors)[int(len(errors) * 0.95)]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--oracle", type=Path,
                        default=ROOT / "build/daily-specialized-20260921/shadow-oracle.json")
    parser.add_argument("--output", type=Path,
                        default=ROOT / "build/daily-3d-20260927/shadow-research")
    args = parser.parse_args()
    oracle_path = args.oracle.resolve()
    original = json.loads(oracle_path.read_text())
    cases = original["cases"]
    if not cases:
        raise ValueError("The historical oracle has no cases")
    for case in cases:
        numbers = case["point"] + case["center"] + [case["panel"], case["oracle128"], case["oracle256"]]
        if not all(math.isfinite(v) for v in numbers):
            raise ValueError("Nonfinite oracle input")
        if abs(case["point"][1] - 0.8) > 1e-12 or case["panel"] not in (-0.635, 0.635):
            raise ValueError("Oracle geometry does not match the frozen planar rig")
        if case["center"][1] - case["point"][1] < RADIUS - 1e-12 or case["center"][1] + RADIUS >= LIGHT_Y:
            raise ValueError("Oracle sphere is outside the validated height domain")
    convergence = statistics([abs(c["oracle128"] - c["oracle256"]) for c in cases])
    variants = {}
    rows = [{"caseIndex": i, "point": c["point"], "center": c["center"],
             "panelZ": c["panel"], "oracle128": c["oracle128"],
             "oracle256": c["oracle256"], "candidates": {}} for i, c in enumerate(cases)]
    for count in (4, 8, 12):
        variants[f"historical_unsplit_{count}"] = statistics([abs(c[str(count)] - c["oracle256"]) for c in cases])
    for split_discriminant in (False, True):
        for count in (4, 8):
            name = f"{'boundary_and_discriminant' if split_discriminant else 'boundary_only'}_{count}"
            results = [segmented(c, count, split_discriminant) for c in cases]
            errors = [abs(v["value"] - c["oracle256"]) for v, c in zip(results, cases)]
            stats = statistics(errors)
            stats.update(meanEvaluations=sum(v["evaluations"] for v in results) / len(results),
                         maxEvaluations=max(v["evaluations"] for v in results),
                         maxIntervals=max(v["intervals"] for v in results),
                         worstCaseIndices=sorted(range(len(cases)), key=lambda i: errors[i], reverse=True)[:8])
            variants[name] = stats
            for row, result, error in zip(rows, results, errors):
                row["candidates"][name] = dict(result, absoluteError=error)
    failures = []
    if convergence["max"] >= ORACLE_MAX_CONVERGENCE:
        failures.append("Historical oracle fails its original max convergence < 0.003 requirement")
    summary = {
        "schemaVersion": 1, "diagnosticOnly": True, "productionAccepted": False,
        "coordinateSystem": "World metres; XZ horizontal; Y up; receiver normal (0,1,0)",
        "python": platform.python_version(), "caseCount": len(cases),
        "sources": [provenance(oracle_path), provenance(Path(__file__).resolve()),
                    provenance(ROOT / "scripts/research/sphere_panel_visibility.py"),
                    provenance(ROOT / "scripts/research/bake_local_sphere_shadow.py")],
        "reproduce": "python3 scripts/research/evaluate_segmented_sphere_shadow.py",
        "parameters": {"radius": RADIUS, "lightY": LIGHT_Y, "panelHalfX": LIGHT_HALF_X,
                       "panelHalfZ": LIGHT_HALF_Z, "panelCentersZ": [-0.635, 0.635],
                       "gaussRules": GAUSS_RULES, "rootCoefficientThreshold": 1e-12,
                       "legacyDegenerateThreshold": 1e-10,
                       "percentileMethod": "linear interpolation; the original draft index statistic is also preserved"},
        "formulas": {"cone": "F(x,z)=(dx*x+h*H+dz*z)^2-K*(x^2+H^2+z^2); K=dx^2+h^2+dz^2-R^2",
                     "panelEdgeCuts": "Roots of F(x,z0)=0 and F(x,z1)=0",
                     "silhouetteCuts": "Roots of (R^2-h^2)*x^2+2*dx*h*H*x+(R^2-dx^2)*H^2=0",
                     "normalization": "Exact unoccluded rectangular solid-angle integral at normal (0,1,0)"},
        "thresholds": {"oracleMaxConvergenceExclusive": ORACLE_MAX_CONVERGENCE,
                       "candidateAcceptance": None,
                       "reason": "No segmented-candidate acceptance gate was frozen; do not transfer the old local-LUT thresholds or declare acceptance from these results"},
        "oracleConvergence": convergence, "historicalReportedStats": original.get("stats"),
        "variants": variants, "validationFailures": failures,
        "retainedLimitations": [
            "Reuses the old 2880 receiver cases and finite 256x256 ray-grid oracle; not new independent sampling or exact ground truth.",
            "Single opaque sphere and horizontal planar receiver normal only; no micro-normal, horizon clipping, multiple-ball union, opacity, pocket or motion proof.",
            "The production reference includes finite light-cell smoothstep filtering, which differs from this binary sphere-cone oracle.",
            "The old S average-visibility product and diffuse-visibility modulation of specular remain separate approximations.",
            "Boundary-only variants retain the failed >0.014 maximum errors; complete-split 4-point variant retains the >0.010 fully occluded-panel integration error.",
            "Fixed exploratory root tolerances have not been validated for Metal Float32; no claim of robust production root classification.",
            "The 8-point result approaches or undercuts the finite oracle's convergence error; finer independent validation is still needed.",
            "Evaluation counts omit root solving, sorting, full-panel normalization and GPU divergence; they are not a speedup measurement.",
            "No production shader/profile changes, render, build, device run or thermal validation performed by this script.",
        ],
        "cases": rows,
    }
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    report = ["# 分段球影积分数值研究", "", "研究候选；未接生产，未获得视觉或性能验收。", "",
              "## 复现与真源", "", f"运行 `{summary['reproduce']}`，仅使用 Python 标准库。",
              f"旧 oracle：`{summary['sources'][0]['path']}`，SHA256 `{summary['sources'][0]['sha256']}`。",
              "脚本、旧生成器及局部 LUT 脚本哈希、固定 Gauss 节点、全部逐例误差见 summary.json。",
              "", "## 方法", "", "X–Z 水平、Y 向上，单位米；接收点法线固定 (0,1,0)。",
              "`F(x,z)=(dx*x+h*H+dz*z)^2-K*(x^2+H^2+z^2)`，`K=|d|^2-R^2`。",
              "先在 `F(x,z0)=0`、`F(x,z1)=0` 处分段；完整候选另加入",
              "`(R^2-h^2)x^2+2dx*hH*x+(R^2-dx^2)H^2=0` 的根，处理 `h=R` 的线性退化。",
              "保留原 Z 原函数，各平滑区间做 4 或 8 点 Gauss；以解析矩形照度归一化。",
              "", "## 结果", "", "误差为 0–1 遮挡量绝对差；p95 使用线性插值。", "",
              "| 方案 | RMSE | p95 | 最大 | 平均/最多积分点 |",
              "|---|---:|---:|---:|---:|"]
    for name, stats in variants.items():
        cost = f"{stats['meanEvaluations']:.3f}/{stats['maxEvaluations']}" if "meanEvaluations" in stats else "历史整段"
        report.append(f"| {name} | {stats['rmse']:.8f} | {stats['p95']:.8f} | {stats['max']:.8f} | {cost} |")
    report.extend(["", f"旧 oracle 128²/256² 最大差 `{convergence['max']:.9f}`；沿用原 `<0.003` 门槛，结果：{'失败' if failures else '通过'}。",
                   "未为候选新增或调整验收阈值。边界切点遗漏阶段及 4 点残余误差全部保留；8 点结果只证明此样本集的数值改善。",
                   "", "## 限制与下一步", ""])
    report.extend(f"- {line}" for line in summary["retainedLimitations"])
    report.extend(["", "先独立增加密集接触区和连续位移样本、检验 Float32 根分类，再研究法线跨地平线与多球遮挡；暂不改 S profile。"])
    (args.output / "REPORT.md").write_text("\n".join(report) + "\n")
    print(json.dumps({"output": str(args.output.resolve()), "caseCount": len(cases),
                      "variants": variants, "validationFailures": failures}, ensure_ascii=False, indent=2))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
