# 动作库烘焙 — 物理可达校验报告（DRILL-BAKE-REPORT）

> 角色：iOS Architect ｜ 日期：2026-06-04 ｜ ADR-P10-01（内容管线雏形）
> 生成方式：`xcodebuild test -scheme QiuJi -only-testing:QiuJiTests/DrillBakeRunnerTests`
> 烘焙器：`ShotBaker/engine@v2-geom`（`ShotPredictor` + USDZ 对齐球桌 `chineseEightBallQiuJi`）
> 对接：H-11 人工技术核查（动作描述/达标标准/坐标合理性）。

## 字段说明

| 列 | 含义 |
|----|------|
| feasible | 选定袋口几何上是否可进（切球角 < 89° 且母球不挡路）。烘焙断言此列必须 ✅。 |
| sim 进选定袋 | **真实模拟**中目标球是否进了选定袋（测量真值，不参与显示）。⚠️ = 真实模拟未落袋（多为 jaw↔洞心残留错位，属 P10 标定，不阻断显示）。 |
| 切球角° | 瞄准线与进球线夹角 α。 |
| 母球进袋 | 母球是否落袋（通常视为失误）。 |

## 试点结果（5 条，多类别）

| Drill | 类别 | shot | feasible | sim进选定袋 | 切球角° | 母球进袋 |
|-------|------|------|----------|-------------|---------|----------|
| drill_c001 | accuracy · 直线 | 0 | ✅ | ✅ | 0.0 | 否 |
| drill_c002 | accuracy · 斜角 | 0 | ✅ | ✅ | 4.2 | 否 |
| drill_c005 | positioning · 一库走位 | 0 | ✅ | ✅ | 16.9 | 否 |
| drill_c014 | cueAction · 定杆 | 0 | ✅ | ✅ | 0.0 | 否 |
| drill_c024 | separation · 90°规则 | 0 | ✅ | ✅ | 0.8 | 否 |

**结论**：5/5 几何可进，烘焙成功并回填各 Drill `animation`（`source: "baked"`）。**5/5 真实模拟诚实进袋**（P10 Track B-1 物理保真后 c002 由 ⚠️ 转 ✅）。

## 备注

- **drill_c002（已转 ✅）**：切球角 4.2°（近直线）。先前 sim ⚠️ 的根因并非「jaw 放错 17mm」，而是旧引擎袋口只是**袋心一个判定圆**（13.4mm 甜点）、无真实内部结构 + 闭环求解器在窄口偶落坏局部最优。**P10 Track B-1 物理保真**（见 `PHYSICS-PROBE.md` 与 ADR-P10-02）改建**真实袋口物理（喉腔模型）**：jaw 库 + 实测 jaw 尖端挤出的喉腔侧壁/后壁（可反弹）+ 物理落袋孔（rattle 由几何涌现，非放大判定圆），并稳健化闭环求解（采样寻优最优接触点 + scratch 轻罚 + 加密搜索）后，c002 真实模拟诚实落袋。
- **drill_c005（走位，切球角 16.9°）**：连续力度 `velocity=3.0` + 微低杆 `spin.y=-0.2`，母球烘焙轨迹含吃底库后回到左半台（走位主体由真实模拟驱动），展示「连续力度→精准走位」的价值——这是改用连续值而非 5 档枚举的目标场景。
- **目标球轨迹现取自真实模拟**（P10 Track B-1）：`prediction.objectPath` 不再是固定理想直线，而是事件驱动模拟的真实折线（含碰撞 throw / 走位 / rattle）。烘焙回填的 `animation.targetBall.path` 因此为多点真实轨迹，「画面=物理」。

## 复跑

```bash
xcodebuild -project QiuJi.xcodeproj -scheme QiuJi -configuration Debug \
  -derivedDataPath build/DerivedData \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:QiuJiTests/DrillBakeRunnerTests test
```

控制台在 `===BAKE <drillId> shot=<i>===` … `===END <drillId>===` 标记间打印回填用的 `DrillAnimation` JSON；`===BAKE-REPORT===` … `===END-REPORT===` 间打印本表。
