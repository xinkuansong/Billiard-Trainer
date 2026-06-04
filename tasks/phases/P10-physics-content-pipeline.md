# P10 物理升级 — 动作库内容管线 + 物理标定

> 角色：iOS Architect ｜ 起始日期：2026-06-04
> 前置：2D 物理引擎探针 🟢 绿灯（`tasks/qa-reports/PHYSICS-PROBE.md`）。
> 本阶段把已验证可信的引擎「用起来」：先建内容管线（Track A，本任务），物理标定（Track B）排其后/并行。

---

## 背景与目标

探针绿灯证明：内核物理可信（A/B/C/D 全健康）、几何已统一（`chineseEightBallQiuJi` 补齐 jaw）、产品路径诚实进袋。
下一步是让动作库（Drill）的展示从「手画贝塞尔 + PNG 帧序列」升级为「引擎驱动的精确轨迹」，使内容**系统化、可复算、物理可信**。

当前动作库内容现状：
- 每个 Drill 的 `animation`（`DrillAnimation`）是**人工手画**的母球/目标球贝塞尔路径（`BTMiniTable` 渲染缩略图）。
- `BTDrillPreviewPlayer` 是 `drill_c005` 的 PNG 帧序列 SPIKE（8 帧 no-path/with-path），未成体系、包体不友好。
- 手画路径无法保证物理正确（角度/塞/吃库/throw 全凭手感），与 H-11 人工技术核查割裂。

**本阶段 Track A 目标**：
1. 设计 Drill「击球意图」（Shot Intent）schema——用**物理输入**（摆球坐标、选袋、塞、力度档、可选多球）描述一杆球，而非手画结果路径。
2. 建**离线烘焙管线**：意图 → `ShotPredictor`/`EventDrivenEngine` → 精确轨迹折线，**回填**到现有 `DrillAnimation`（渲染层零改动）。
3. 顺带产出**物理可达校验报告**（可行性/是否真进选定袋/切球角），对接 H-11。

---

## A. 击球意图（Shot Intent）Schema 设计

### A.1 设计原则

| 原则 | 落地 |
|------|------|
| **作者友好** | 作者只写「摆球 + 选袋 + 塞 + 力度档」，不写轨迹；坐标沿用现有归一化系（`x∈[0,1]`、`y∈[0,0.5]`），与 `BTMiniTable`/`schema.md` 完全一致，作者无需学新坐标系。 |
| **向后兼容** | `shotIntent` 为 `DrillContent` 的**可选**新字段；72 条旧 Drill 无此字段照常工作。烘焙结果回填到**现有** `animation`（`DrillAnimation`），渲染层（`BTMiniTable`/`DrillTutorialView`）零改动。 |
| **单一坐标桥** | 复用 `AngleSceneCalculator.normalizedToScene` / `sceneToNormalized`，意图（归一化）→ 引擎（米制场景）→ 烘焙折线（归一化回填）。不引入新坐标空间。 |
| **复用引擎语义** | 力度＝**连续杆头速度 `velocity`（m/s）**（用户要求：精准走位需连续值，不用 5 档枚举）；塞＝`spinX`(+左)/`spinY`(+高) ∈ −1..1（与 `ShotInput` 一致）；袋＝字符串 ID（与 `schema.md` Pocket IDs 一致），映射到 `pocketIndex` 0..5。 |
| **物理球桌为准** | 烘焙与运行时一致，采用引擎的 USDZ 对齐球桌 `TableGeometry.chineseEightBallQiuJi`（已补齐 jaw、与黄色袋口标记一致），经 `ShotPredictor.predict` 求解，不另起几何。 |
| **多球前向兼容** | schema 支持 `obstacles`（额外球）字段，但**雏形烘焙器 v1 仅处理母球 + 单目标球**（覆盖绝大多数 Drill）；多球摆位先存不烘焙，留后续。 |

### A.2 Schema 结构（新增 `shotIntent`，DrillContent 可选字段）

```jsonc
"shotIntent": {
  "version": 1,
  "shots": [
    {
      "cue":    { "x": 0.65, "y": 0.25 },   // 母球摆位（归一化，同 schema.md 坐标系）
      "target": { "x": 0.88, "y": 0.38 },   // 目标球摆位
      "pocket": "bottomRight",               // 选袋（schema.md Pocket IDs：topLeft..bottomCenter）
      "velocity": 3.3,                        // 连续杆头速度（m/s），推荐区间 ~0.8–6.5；精准走位用连续值
      "spin":   { "x": 0.0, "y": -0.30 },    // 可选；x:+左塞/−右塞，y:+高杆/−低杆，∈[-1,1]，缺省 {0,0}
      "elevation": 0.0,                        // 可选；球杆仰角（弧度），缺省 0
      "obstacles": [ { "x": 0.40, "y": 0.20 } ] // 可选；额外障碍/多球（v1 不烘焙，前向兼容）
    }
  ]
}
```

- 绝大多数 Drill 为单杆球，故 `shots` 通常长度 1；`combined`/`positioning` 类多杆球可列多个 shot（v1 逐杆独立烘焙）。
- `velocity` 为连续杆头速度（m/s）——**用户明确要求连续值以支持精准走位**，不用 `SpeedLevel` 5 档枚举。参考锚点（旧 5 档）：轻 1.6 / 中轻 2.4 / 中 3.3 / 中重 4.4 / 大力 5.8，作者可在其间任意取值。

### A.3 坐标 / 枚举映射（权威表）

**归一化 ↔ 场景**（既有 `AngleSceneCalculator`，本表仅复述，不新建）：
```
sceneX = nx * 2.54 − 1.27      (nx∈[0,1]  → [-1.27, 1.27])
sceneZ = ny * 2 * 1.27 − 0.635 (ny∈[0,0.5]→ [-0.635, 0.635])
```

**Pocket ID → pocketIndex**（`pocketPositions` 顺序 0..5，已核对与归一化 top-left/left 语义一致）：
| Pocket ID | index | 场景中心 (x, z) |
|-----------|-------|-----------------|
| `topLeft` | 0 | (−halfL−c, −halfW−c) |
| `topRight` | 1 | (+halfL+c, −halfW−c) |
| `bottomLeft` | 2 | (−halfL−c, +halfW+c) |
| `bottomRight` | 3 | (+halfL+c, +halfW+c) |
| `topCenter` | 4 | (0, −halfW−m) |
| `bottomCenter` | 5 | (0, +halfW+m) |

**velocity（连续，m/s）**：直接作为 `ShotInput.velocity`。参考锚点（非约束）：轻 1.6 / 中轻 2.4 / 中 3.3 / 中重 4.4 / 大力 5.8；作者按精准走位需要在 ~0.8–6.5 之间连续取值。

**球桌几何**：`ShotBaker` 复用 `ShotPredictor.predict`，其内部使用 `TableGeometry.chineseEightBallQiuJi(surfaceY:)`（USDZ 对齐、补齐 jaw），与运行时角度页/黄色袋口标记一致。

### A.4 烘焙输出（回填 `DrillAnimation`，向后兼容）

烘焙器把 `ShotPrediction` 转回归一化坐标写入**现有** `animation`：
- `animation.cueBall.path` ← `prediction.cuePath`（真实模拟，含走位/吃库；`sceneToNormalized` 折线，直线段、无 cp1/cp2）。
- `animation.targetBall.path` ← `prediction.objectPath`（目标球进球线）。
- `animation.pocket` ← 意图选袋字符串；`animation.cueDirection` ← `prediction.aimDirection` 投影到归一化。
- **新增可选元数据**（`DrillAnimation` 追加可选字段，旧 JSON 解码不受影响）：
  - `source`: `"baked"` | `"manual"`（缺省按 `"manual"`，保护 72 条旧件）。
  - `generator`: 例 `"ShotBaker/engine@v2-geom"`（可追溯、可重烘焙）。

渲染层（`BTMiniTable`）天然消费 `DrillAnimation`，故烘焙后**无需改任何 View**——这是向后兼容的关键。

### A.5 离线烘焙管线（命令行可引用）

- **载体**：XCTest 烘焙跑测 `DrillBakeRunnerTests`（复用既有 test host + app 模块，沿用 `PhysicsBenchmarkTests` 先例；命令行 `xcodebuild test -only-testing:QiuJiTests/DrillBakeRunnerTests`）。不新增 SPM 可执行 target（避免把 SceneKit 依赖单独打包）。
- **核心 `ShotBaker`**（纯函数门面，`Core/Physics/`）：`ShotIntent.Shot → ShotInput → ShotPredictor.predict → DrillAnimation`（含归一化回填）。
- **校验报告**：逐杆输出 `feasible / infeasibleReason / simObjectPotted / cutAngleDeg`，汇总成 `tasks/qa-reports/DRILL-BAKE-REPORT.md`，供 H-11 人工核查「该 Drill 是否物理可达」。
- **回写策略（v1 雏形）**：先对 1–2 条试点 Drill（如 `drill_c001` 直线、`drill_c005` 一库走位）烘焙并产出对比，验证 round-trip 正确后再扩面（扩面非本雏形范围）。

### A.6 与展示三件套（GIF/精讲/视频）的关系（方向，非本雏形实现）

- **GIF 动画**：由烘焙轨迹驱动（替代手画贝塞尔 + 废弃 `BTDrillPreviewPlayer` PNG 帧）。
- **精讲**：可基于同一意图做「对/错」参数化对比（如正确塞 vs 过塞）的物理对照。
- **视频**：降级为「仅真人身体动作」补充，物理路径以引擎为准。

---

## B. 物理标定（Track B，排内容管线之后/并行，详见 PHYSICS-PROBE）

1. **真实袋口物理（喉腔模型）/ 物理保真进球管线** ✅（2026-06-04，ADR-P10-02）：USDZ 网格实测**证伪了「jaw 放错 17mm」的预设**——库边/袋心/jaw 实测皆与解析自洽。用户复评后**拒绝"放宽捕获半径"的偷懒做法**，改建真实袋口结构：每袋口 = jaw 库 + **喉腔（实测 jaw 尖端挤出的侧壁+后壁，可反弹）+ 物理落袋孔**，rattle 由几何自然涌现（穿库飞出 8%→2.7%）。配套：稳健化闭环求解（采样寻优最优接触点，进袋优先评分 + scratch 轻罚 + 加密搜索）；目标球轨迹取自真实模拟、进袋判定改轨迹基（画面=物理）。结果：E-solver 角袋 5/5、中袋全力度进、c002 转 ✅、`QiuJiTests` 291/291。详见 `tasks/qa-reports/PHYSICS-PROBE.md` §USDZ 实测标定。
2. **目标球真实轨迹** ✅（随 B-1 一并完成）：`ShotPredictor.objectPath` 已改取自模拟（去固定直线）。
3. **常量标定**（待办，需真实视频）：俯拍真实球拟合 e_b/摩擦/恢复系数，用 `PhysicsBenchmarkTests` 钉死。
4. **遗留非阻塞**：中袋 jaw mouth 由 ±0.035 对齐实测 ±0.046；朴素瞄准 E-geom 3/5（窄喉口掠角 rattle 属真实物理，产品用求解器规避）。

---

## 任务卡（Track A 雏形）

| 任务 | 描述 | 状态 |
|------|------|------|
| T-P10-A1 | `ShotIntent` Codable 模型 + `DrillContent.shotIntent?` 可选字段 + `DrillAnimation` 追加可选 `source`/`generator` | ✅（2026-06-04，`ShotIntent.swift`）|
| T-P10-A2 | `ShotIntent.Shot → ShotInput` 转换器（归一化→场景、Pocket 映射、连续 velocity/spin 解析） | ✅（2026-06-04）|
| T-P10-A3 | `ShotBaker`：`predict` → 归一化回填 `DrillAnimation`（含 round-trip 坐标正确性） | ✅（2026-06-04，`ShotBaker.swift`）|
| T-P10-A4 | `DrillBakeRunnerTests` 烘焙跑测 + `DRILL-BAKE-REPORT.md` 可达校验报告 | ✅（2026-06-04）|
| T-P10-A5 | 多类别试点 Drill 标注 `shotIntent` + 烘焙 round-trip 回填（c001/c002/c005/c014/c024） | ✅（2026-06-04，5/5 feasible）|
| T-P10-A6 | 更新 `schema.md` + content-engineering SKILL：新增 `shotIntent` 字段说明与作者 SOP | ✅（2026-06-04）|

### DoD（Track A 雏形）
- a. `ShotIntent` 解码通过；旧 72 条 Drill（无 `shotIntent`）解码与渲染零回归。
- b. 试点 Drill 烘焙产出 `animation`，`BTMiniTable` 正常渲染（人工/截图核对）。
- c. 烘焙校验报告对试点 Drill 给出 feasible/进袋/切角，与几何直觉一致。
- d. `make build` 通过、`QiuJiTests` 全绿、lint 0。
- e. `schema.md` 与 SKILL 同步；本文件 ADR-P10-01 落定。

---

## ADR 记录区

### ADR-P10-02 — 物理保真进球管线（USDZ 实测捕获半径 + 稳健闭环求解 + 画面=物理）

- **日期**：2026-06-04
- **状态**：✅ 已采纳并实现（用户评审：本轮聚焦"完整、物理保真的进球点/进球判定算法"，跳过细分范围授权由实现侧据数据决策）。
- **背景（Track B-1 重新定性）**：探针报告把贴角球 rattle 归因为「jaw 圆弧取 CAD 坐标、与 USDZ 洞心残留 ~17mm 错位」。本轮以**程序化 USDZ 网格实测**（`TableGeometryProbeTests`，用户选定的测量法）求证后**证伪该预设**：库边（±0.635/±1.27）、袋心、jaw（与库边精确相切）实测皆自洽，几何无需重导。真正根因为：① 引擎进袋**捕获窗过窄**（捕获半径 0.042 → 球心需进袋心 13.4mm 窄甜点，而真实袋口是「球进两 jaw 尖端之间的喉口即落袋」，实测 jaw 尖端距袋心 ~58.6mm）；② 闭环瞄准求解在窄喉口多峰景观下偶落坏局部最优（scratch / 穿库假阳性），跨力度进球不稳定。
- **决策（用户复评后修订：拒绝"放宽捕获半径"的偷懒做法，改建真实袋口结构）**：
  1. **真实袋口物理 = 喉腔模型**（`TableGeometry.chineseEightBallQiuJi`）：每个袋口由 ① 现有 jaw 库（偏转切球）+ ② **喉腔**——由实测 jaw 尖端（`pocketJaws`）沿喉轴 `n=单位(P−M)` 挤出的**两条侧壁 + 一道后壁**（均为可反弹线性库，法线朝腔内）+ ③ 喉腔内的**物理落袋孔** `P`（`pocketDropRadius`，球心进孔即落袋）。**rattle 由几何自然涌现**：被 jaw/侧壁偏转或过力度的球撞后壁弹回、可能从 mouth 逃出 = 未进；对准的球抵达落袋孔 = 进。喉壁还把袋口「穿库飞出」从 ~8% 降到 ~2.7%。落袋孔半径仅表示物理洞口、不承担"放大强行进球"，与**视觉标记半径** `*PocketRadius` 解耦（标记零变化）。
  2. **两种逻辑分清**：**(A) 袋口判定（正向）**＝球沿某方向来、由喉腔真实几何决定进/rattle（与球怎么来无关）；**(B) 瞄准求解（最优接触点）**＝固定力度+塞，`solveAimOffset` **采样/寻优母球-目标球接触点（发射偏移）**，在 (A) 真实袋口下让目标球落袋（直接进 或 借 jaw/壁导进），打不进则如实报"打不进"。B 的评分调用 A（真实模拟），不另算一套。
  3. **稳健化闭环求解** `solveAimOffset`：以「短模拟真进选定袋」为首要评分（−10 基线压过一切未进解）；scratch 仅 mm 量级轻罚（**禁用 1.0 大值**——会压过 objMinDist 把求解逼到"不进也不刮"差解）；粗扫加密 ±16°/0.5° + 两级细化。
  4. **画面=物理** `ShotPredictor.predict`：`objectPath` 取真实模拟折线（含穿喉腔反弹）；`objectPocketed/simObjectPotted` 改**轨迹基**判定（显示轨迹最近点进落袋孔窗），与画面一致、消除穿库假阳性。`ShotSimulationViewModel` 诚实显示进/未进与提示。
- **理由**：袋口该不该吃球应由**真实结构**（jaw + 喉腔侧壁/后壁 + 落袋孔）自然涌现，而非一个调大的判定圆（用户明确反对后者为偷懒）。喉腔几何源自既有单一真源 `pocketJaws`/`pocketPositions` 实测，物理可解释。
- **影响（命中 ADR 触发）**：跨模块行为变更（进袋判定：几何理想化 → 真实喉腔几何 + 轨迹基）；几何新增（喉腔线性库 + 落袋孔半径，单一真源 `AngleSceneCalculator`/`TableGeometry+QiuJi`）。改动文件：`TableGeometry+QiuJi.swift`（喉腔挤出 + 落袋孔）、`AngleSceneCalculator.swift`（`pocketDropRadius` 解耦）、`ShotPredictor.swift`（求解评分 + 轨迹基判定 + objectPath 真实化）、`ShotSimulationViewModel.swift`（诚实状态）；新增 `TableGeometryProbeTests.swift`（USDZ 实测 + 进球覆盖诊断）、`PhysicsEngineTests` +3 保真断言。
- **替代方案**：① 按 17mm 平移 jaw 重导几何——USDZ 实测证伪前提（几何自洽），且平移破坏库边相切，未采纳；② **仅放大捕获半径到 0.055**——用户判定为偷懒、非真实袋口物理，未采纳（改为喉腔结构 + 物理落袋孔）；③ 移动袋心/标记到喉口——视觉回归，未采纳。
- **遗留 TODO**：薄切角（如 55°）在窄喉腔下个别力度仍敏感（真实物理但偶现非单调）；中袋 jaw mouth ±0.035→实测 ±0.046；Track B #3 常量标定（需真实俯拍视频）；朴素瞄准 E-geom 3/5（窄喉口掠角真实 rattle，非阻塞）。

### ADR-P10-01 — 击球意图（Shot Intent）Schema + 离线烘焙管线（草案）

- **日期**：2026-06-04
- **状态**：✅ 已采纳（用户评审 2026-06-04，含两处修正：① 力度改**连续 velocity(m/s)**，不用 5 档枚举；② 烘焙用**引擎 USDZ 对齐球桌** `chineseEightBallQiuJi`）。雏形 v1 已实现并验证（5 条试点 5/5 feasible，`QiuJiTests` 203/203）。
- **背景**：动作库 `DrillAnimation` 为人工手画贝塞尔，物理不可信、与 H-11 割裂；`BTDrillPreviewPlayer` 的 PNG 帧序列方案未成体系且包体不友好。探针绿灯后，引擎可作为内容的「物理事实源」。
- **决策**：
  1. 新增 `DrillContent.shotIntent?`（可选）——以**物理输入**（归一化摆球 + 选袋 + 塞 + **连续力度 velocity(m/s)** + 可选多球）描述一杆球；坐标系沿用 `schema.md` 现有归一化系（零作者迁移成本）。力度用连续值（不用 5 档枚举），以支持精准走位。烘焙用引擎 USDZ 对齐球桌 `chineseEightBallQiuJi`。
  2. **离线烘焙**：`ShotBaker` 把意图喂给 `ShotPredictor`/`EventDrivenEngine`，把精确轨迹**回填**到现有 `DrillAnimation`（`source:"baked"`）；渲染层零改动（向后兼容）。
  3. 烘焙器以 **XCTest 跑测**为命令行载体（复用 test host，不新增 SPM 可执行 target），并产出**物理可达校验报告**对接 H-11。
  4. 雏形 v1 范围：单母球 + 单目标球；多球（`obstacles`）字段前向兼容、暂不烘焙。
- **理由**：
  - 把内容从「手画结果」变为「物理意图」，使动作库可复算、可校验、可与物理升级同步演进。
  - 复用既有坐标桥与引擎语义，改动面小、风险低；回填现有字段保证渲染层零回归。
  - XCTest 载体复用已验证的测试宿主，避免单独打包 SceneKit 依赖。
- **影响（命中 ADR 触发）**：
  - **内容/数据策略变更**：Drill 内容生产方式由手画转为引擎烘焙（`schema.md` + content-engineering SKILL 需同步）。
  - **跨模块边界**：物理引擎从「仅运行时角度页消费」扩展为「离线内容管线可引用」（`ShotBaker` 门面 + 烘焙跑测）。
  - 新增文件：`Core/Physics/ShotIntent.swift`、`Core/Physics/ShotBaker.swift`、`QiuJiTests/DrillBakeRunnerTests.swift`；`DrillContent`/`DrillAnimation` 追加可选字段。
- **替代方案**：
  - 继续手画 + 扩 PNG 帧序列——物理不可信、不可复算、包体差，未采纳。
  - 运行时实时烘焙（App 内每次打开 Drill 现算）——耗电/耗时、首屏慢，且无离线校验产物，未采纳（离线烘焙一次、回填静态结果更优）。
  - 新建独立坐标空间给作者——增加迁移成本且与现有 72 条不一致，未采纳。
- **后续 TODO**：扩面烘焙全量 Drill；目标球真实轨迹（依赖 Track B #2）；GIF/精讲/视频统一重构。
