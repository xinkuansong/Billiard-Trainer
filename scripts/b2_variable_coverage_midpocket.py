#!/usr/bin/env python3
"""B2 变量覆盖方法论 — 中袋角度球样板数值验算脚本。

坐标契约（Canvas 归一化系，真源 .kiro/steering/table-geometry.md）：
  原点 = 台面左上角（顶视图），X∈[0,1] 左→右，Y∈[0,0.5] 上→下，
  单位 = 台面内沿长度 2.540 m 的百分比。下中袋中心 (0.5, +0.5268)。
  球半径 r = 0.028575/2.540 = 0.01125。

推导公式（ghost ball 构造）：
  进球线方向  v = normalize(P - T)          （T=目标球心, P=袋口中心）
  ghost 球位  G = T - 2r * v                （目标球心沿进球线反向退 2r）
  击球行进线  t̂ = R(±θ) · v                （把 v 旋转 ±θ，θ=设计切角）
  白球球位    C = G - d * t̂                 （d=白球心到 ghost 位距离）
  则 白球→ghost 行进方向与进球线夹角 = θ（构造保证，脚本复算验证）。
  另计「表观切角」= 白球→目标球心连线 与 进球线 的夹角（任务书定义），
  与 θ 的差异由 |CG| 与 |CT| 不共线（相差一个 2r 横向偏置）引起，一并输出。

侧别约定：白球 X > 进球线（X=0.5）为「右切 R」，X < 0.5 为「左切 L」。
"""
import math

R_BALL = 0.028575 / 2.540          # 0.011250
POCKET_BC = (0.5, 0.5268)          # 下中袋中心（table-geometry.md）
TWO_R = 2 * R_BALL

# 有效区（content-engineering 坐标自检严区）
X_MIN, X_MAX = 0.05, 0.95
Y_MIN, Y_MAX = 0.05, 0.45
MIN_DIST = 0.05                    # 母球-目标球最小距离（自检规则）


def norm(vx, vy):
    m = math.hypot(vx, vy)
    return vx / m, vy / m


def rot(vx, vy, deg):
    a = math.radians(deg)
    return (vx * math.cos(a) - vy * math.sin(a),
            vx * math.sin(a) + vy * math.cos(a))


def angle_between(ax, ay, bx, by):
    dot = ax * bx + ay * by
    na, nb = math.hypot(ax, ay), math.hypot(bx, by)
    c = max(-1.0, min(1.0, dot / (na * nb)))
    return math.degrees(math.acos(c))


def solve_formation(target, pocket, theta_deg, side, d_cue_ghost):
    """由 目标球位+袋口+切角+白球距离 反推白球位。side: +1=右切, -1=左切。"""
    tx, ty = target
    px, py = pocket
    vx, vy = norm(px - tx, py - ty)                 # 进球线方向 T→P
    gx, gy = tx - TWO_R * vx, ty - TWO_R * vy       # ghost ball
    # 对 v=(0,1)（垂直向下入袋）：R(+θ) 得 t̂=(-sinθ, cosθ) → C_x=G_x+d·sinθ（右侧）
    hx, hy = rot(vx, vy, theta_deg if side > 0 else -theta_deg)
    cx, cy = gx - d_cue_ghost * hx, gy - d_cue_ghost * hy
    # 复算：行进线切角（应=θ）与表观切角（白球→目标球心 vs 进球线）
    cut_travel = angle_between(gx - cx, gy - cy, vx, vy)
    cut_apparent = angle_between(tx - cx, ty - cy, vx, vy)
    return {
        "cue": (cx, cy), "ghost": (gx, gy),
        "cut_travel": cut_travel, "cut_apparent": cut_apparent,
        "side_check": "R" if cx > tx + 1e-12 else ("L" if cx < tx - 1e-12 else "0"),
    }


def checks(cue, target, pocket):
    cx, cy = cue
    tx, ty = target
    ok = []
    ok.append(("cue 在自检区", X_MIN <= cx <= X_MAX and Y_MIN <= cy <= Y_MAX))
    ok.append(("target 在自检区", X_MIN <= tx <= X_MAX and Y_MIN <= ty <= Y_MAX))
    d_ct = math.hypot(cx - tx, cy - ty)
    ok.append(("两球距离>0.05", d_ct > MIN_DIST))
    ok.append(("两球不重叠(>2r)", d_ct > TWO_R))
    # 进球线入袋角：与中袋袋口轴向（+Y，垂直入袋）的夹角 ≤ 30°（中袋接受角约束）
    vx, vy = norm(pocket[0] - tx, pocket[1] - ty)
    entry = angle_between(vx, vy, 0.0, 1.0)
    ok.append((f"入袋角≤30°（实测 {entry:.1f}°）", entry <= 30.0))
    return ok, d_ct, entry


# ---------------- 金标准样例（geometry-spatial-reasoning 强制回归） ----------------
print("=== 金标准样例回归 ===")
# 样例1：0° 直球——cue/ghost/target/pocket 应共线，ghost 在 target 正后方 2r
f = solve_formation((0.5, 0.30), POCKET_BC, 0.0, +1, 0.20)
cx, cy = f["cue"]
gx, gy = f["ghost"]
col = abs(cx - 0.5) < 1e-12 and abs(gx - 0.5) < 1e-12
print(f"直球: cue=({cx:.4f},{cy:.4f}) ghost=({gx:.4f},{gy:.4f}) 共线={col} "
      f"ghost-target 距={math.hypot(gx-0.5, gy-0.30):.6f} (期望 {TWO_R:.6f}) "
      f"cut_travel={f['cut_travel']:.4f}° (期望 0)")
assert col and abs(f["cut_travel"]) < 1e-9
assert abs(math.hypot(gx - 0.5, gy - 0.30) - TWO_R) < 1e-12

# 样例2：45° 切角——行进线与进球线夹角应精确 45°；右切白球应在 X>0.5
f = solve_formation((0.5, 0.30), POCKET_BC, 45.0, +1, 0.20)
print(f"45°右切: cue=({f['cue'][0]:.4f},{f['cue'][1]:.4f}) "
      f"cut_travel={f['cut_travel']:.4f}° side={f['side_check']}")
assert abs(f["cut_travel"] - 45.0) < 1e-9 and f["side_check"] == "R"

# 样例3：左右镜像对称——同参数左右切的白球 X 关于进球线镜像
fr = solve_formation((0.5, 0.30), POCKET_BC, 30.0, +1, 0.25)
fl = solve_formation((0.5, 0.30), POCKET_BC, 30.0, -1, 0.25)
sym = abs((fr["cue"][0] - 0.5) + (fl["cue"][0] - 0.5)) < 1e-12 and \
      abs(fr["cue"][1] - fl["cue"][1]) < 1e-12
print(f"30°镜像: R_x={fr['cue'][0]:.4f} L_x={fl['cue'][0]:.4f} 对称={sym}")
assert sym
print("金标准全部通过 ✓\n")

# ---------------- 样板球形（8 个）：中袋角度球 ----------------
# 目标变量：切角 θ ∈ {15,30,45,60}° × 左/右切
# 条件变量：dtp=目标球心→袋口中心距离 ∈ {0.12,0.15,0.20,0.25}（散布采样）
#           d=白球心→ghost 距离 ∈ {0.18,0.22,0.25,0.28,0.35,0.38}（散布采样）
# 固定变量：袋口=下中袋；目标球在 X=0.5 进球线上（入袋角=0°，隔离切角变量）
FORMATIONS = [
    # (编号, θ, side(+R/-L), dtp, d, 难度序号)
    ("A1", 15, +1, 0.15, 0.25, 1),
    ("A2", 15, -1, 0.25, 0.18, 2),
    ("A3", 30, -1, 0.12, 0.18, 3),
    ("A4", 30, +1, 0.25, 0.22, 4),
    ("A5", 45, +1, 0.12, 0.28, 5),
    ("A6", 45, -1, 0.20, 0.35, 6),
    ("A7", 60, +1, 0.20, 0.28, 7),
    ("A8", 60, -1, 0.12, 0.38, 8),
]

print("=== 样板球形推导与自检 ===")
all_pass = True
rows = []
for fid, theta, side, dtp, d, rank in FORMATIONS:
    target = (0.5, POCKET_BC[1] - dtp)     # 目标球在袋口正上方 dtp 处（进球线 X=0.5）
    f = solve_formation(target, POCKET_BC, theta, side, d)
    ok, d_ct, entry = checks(f["cue"], target, POCKET_BC)
    passed = all(v for _, v in ok)
    all_pass &= passed
    side_lbl = "右切R" if side > 0 else "左切L"
    print(f"[{fid}] θ={theta}°({side_lbl}) dtp={dtp} d={d} 难度#{rank}")
    print(f"  target=({target[0]:.4f},{target[1]:.4f})  "
          f"cue=({f['cue'][0]:.4f},{f['cue'][1]:.4f})  ghost=({f['ghost'][0]:.4f},{f['ghost'][1]:.4f})")
    print(f"  行进线切角={f['cut_travel']:.4f}°  表观切角(白→目标球心)={f['cut_apparent']:.4f}°  "
          f"|CT|={d_ct:.4f}  侧别复核={f['side_check']}")
    for name, v in ok:
        print(f"  {'✓' if v else '✗'} {name}")
    assert abs(f["cut_travel"] - theta) < 1e-9
    assert (f["side_check"] == "R") == (side > 0)
    rows.append((fid, theta, side_lbl, dtp, d, target, f["cue"], f["cut_apparent"], rank, passed))
print(f"\n全部球形自检: {'✓ 通过' if all_pass else '✗ 存在失败'}")

# 球形间两两坐标去重（无重复球形）
print("\n=== 球形去重检查 ===")
dup = False
for i in range(len(rows)):
    for j in range(i + 1, len(rows)):
        dc = math.hypot(rows[i][6][0] - rows[j][6][0], rows[i][6][1] - rows[j][6][1])
        dt = math.hypot(rows[i][5][0] - rows[j][5][0], rows[i][5][1] - rows[j][5][1])
        if dc < 0.02 and dt < 0.02:
            dup = True
            print(f"  ⚠ {rows[i][0]} 与 {rows[j][0]} 球形过近")
print("无重复球形 ✓" if not dup else "存在过近球形 ✗")

# ---------------- 覆盖矩阵 ----------------
print("\n=== 覆盖矩阵（目标变量 θ×侧别） ===")
grid = {}
for fid, theta, side_lbl, dtp, d, *_ in rows:
    grid.setdefault((theta, side_lbl[-1]), []).append(fid)
for theta in (15, 30, 45, 60):
    l = ",".join(grid.get((theta, "L"), ["空档!"]))
    r = ",".join(grid.get((theta, "R"), ["空档!"]))
    print(f"  θ={theta:2d}°  左切: {l:6s}  右切: {r}")
gap = any(not grid.get((t, s)) for t in (15, 30, 45, 60) for s in ("L", "R"))
print(f"目标变量空档: {'存在 ✗' if gap else '无 ✓'}")
print("条件变量散布: dtp 取值 =", sorted({r[3] for r in rows}),
      "| d 取值 =", sorted({r[4] for r in rows}))

# ---------------- B1 交叉验证 1：BU F1 各档位隐含切角 ----------------
# B1: 白球档 k=(1-0.125k, 0.25)，目标球≈(0.94,0.44)[推测]，右下角袋 (1.0165,0.5165)
print("\n=== 交叉验证：BU F1 递进切角（B1 §一，目标球坐标为图纸估读[推测]） ===")
T_F1, P_F1 = (0.94, 0.44), (1.0165, 0.5165)
for k in range(1, 8):
    cue = (1 - 0.125 * k, 0.25)
    vx, vy = norm(P_F1[0] - T_F1[0], P_F1[1] - T_F1[1])
    gx, gy = T_F1[0] - TWO_R * vx, T_F1[1] - TWO_R * vy
    cut = angle_between(gx - cue[0], gy - cue[1], vx, vy)
    dist = math.hypot(cue[0] - T_F1[0], cue[1] - T_F1[1])
    print(f"  档{k}: cue=({cue[0]:.3f},0.250)  切角={cut:5.1f}°  |CT|={dist:.3f}")

# ---------------- B1 交叉验证 2：PAT-S#3 角度球球排几何 ----------------
# B1: 5 球沿 X=0.8125 竖线、球心距 0.045[推测：排布方向由图判断]，打对应角袋
print("\n=== 交叉验证：PAT-S#3 角度球（球排 X=0.8125，Y 分布为[推测]估读） ===")
P_RB, P_RT = (1.0165, 0.5165), (1.0165, -0.0165)   # 右下/右上角袋
ys = [0.25 + i * 0.045 for i in range(-2, 3)]
for i, y in enumerate(ys, 1):
    pocket = P_RB if y >= 0.25 else P_RT
    dist = math.hypot(pocket[0] - 0.8125, pocket[1] - y)
    lbl = "右下角袋" if pocket is P_RB else "右上角袋"
    print(f"  球{i}: ({0.8125:.4f},{y:.4f}) → {lbl}  进球距离={dist:.3f}")
print("\n脚本执行完毕。")
