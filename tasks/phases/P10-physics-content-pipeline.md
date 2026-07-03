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

### ADR-P10-09 — 真实袋口重建：CAD 单一真源 + 「球心入孔圈即落袋」纯几何判据

- **日期**：2026-07-02
- **状态**：✅ 已采纳并实现（全量物理套件绿：`PhysicsMatrixTests` / `PhysicsEngineTests` / `PhysicsInvariantTests` / `PhysicsScenarioTests` / `CushionReflectionTests` / `PocketBehaviorDiagTests` / `PositionPlaySolverTests`）。
- **用户诉求**：①角袋会先吃库边再吃远端 jaw（不该吃库）；②中袋瞄准点不对、撞 jaw 后应按真实物理反弹；③整体有「球被吸进袋」的感觉。用户拍板根本判据：「袋心和球心的距离小于袋口半径即落袋，其他一切按真实物理」。
- **根因（CAD 对照 + 轨迹诊断坐实）**：① 旧两段式判据（`pocketCoreMissRadius` 22mm + `pocketDropSpeed` 1.05m/s）与 settle 收袋特判构成「吸球」——高动量球被判进、挂袋球被吸走；② 中袋几何实现成 10mm 窄缝，与 CAD（双切 R30 圆角 + 86mm 喉道）完全不符；③ 生产袋心相对 CAD 孔心偏移 12mm，jaw 尖与孔圈之间有缝；④ 喉腔隐形侧壁越过 jaw 平面伸入台面，先于 jaw 截击轨迹（「先吃库边」的直接原因）。
- **决策**：
  - **几何**：袋口全面回归 **CAD 单一真源**（`TablePhysics` 袋口常量）。孔心/孔半径：角袋 (±1.312, ±0.677) r=0.042、中袋 (0, ±0.688) r=0.043；中袋按 CAD 双切构造重建（直库端点 ±0.073、R30 弧心 (±0.073, ±0.665)、喉壁 x=±0.043）；角袋喉墙改为 jaw 面共线的**孪生墙**（外法向偏移 1mm 防事件排序病态）+ 切线延长式衬套段（低恢复 `pocketThroatRestitution=0.45`），不再越 jaw 平面。
  - **判据**：`resolvePocket` 只判「球心水平投影入孔圈」（dist ≤ 孔半径 +2mm 防陈旧事件容差），删两段式判据与 `jawSettlePocketSpeed` settle 特判；`enforceTableBounds` 袋口通道内（孔圈外）无条件放行——rattle 弹出、慢速滑向孔圈、合法挂袋全交给真实几何。
  - **瞄准/视觉分离**：`pocketPositions` 返回 CAD 孔心（物理/瞄准真源），新增 `pocketMarkerPositions` 返回 USDZ 视觉袋心（仅标记盘/点选用）；进球管道模型接入中袋 R30+喉壁复合 jaw。
- **过程中根治的两个潜伏引擎缺陷**（被旧「大捕获圆」掩盖多年，判据收紧后暴露）：
  - **QuarticSolver 近双二次塌缩**：弧碰撞四次方程 q 系数因浮点大项抵消变得极小但非零时，Ferrari 预解三次根选择失败 → 漏根 → 球穿弧。修复：`chosenU` 为空时回退双二次近似播种 + Newton-Raphson 抛光（与 numpy roots 全范围比对 0 失配）。
  - **弧 CCD 时间下限过大**：`ballCircularCushionTime` 的 `epsilon=1e-4`（直线库为 1e-6）会拒掉高保真近墙自适应子步渐进逼近后剩余 ~2e-5s 的真实碰撞根 → 球穿弧越界被硬钳（矩阵 4 例失败的根因）。修复：统一为 1e-6；重复检出由逼近方向检查 + `makeBallCushionKiss` 防护，无需时间护栏。
- **测试口径调整（判据变化的合法后果，均经诊断确证非引擎 bug）**：① 65° 大切角直进测试：v3.3 下母球弹库折返二次撞目标球（双吻）属真实物理（v2.0 直进 ✅），断言放宽为「进袋 或 ≥2 次球-球接触」；② fastPath/predict 停点一致性：重旋转大力度进袋窗口是刀锋景观（实测 ~2m/0.1°），加敏感度自测门——±0.02° 扰动即大幅移位时跳过停点比对，平缓景观仍强制 0.2m。
- **新增不变量护栏**（`PhysicsInvariantTests`）：① 入圈即袋双向（任一帧球心入孔圈 ⇒ 终态 pocketed；判 pocketed ⇒ 末段弹道真实抵达孔圈，禁远距吸入）；② 挂袋合法（耗尽动能未入圈的球留在袋口，不吸入不弹出）；③ 无隐形墙（沿袋口通道轴线冲袋，落袋前 0 吃库事件；角袋轴线 = 45° 对角线）。
- **影响**：`BTPhysicsConstants` / `TableGeometry` / `TableGeometry+QiuJi` / `EventDrivenEngine` / `EngineNumerics` / `QuarticSolver` / `CollisionDetector` / `AngleSceneCalculator` / `ShotPredictor` / `TrajectoryPlayback` / `AngleTrainingScene` / `AngleSceneView`；测试 `PhysicsEngineTests` / `PositionPlaySolverTests` / `PhysicsInvariantTests`（+3 不变量）/ 新增诊断 `PocketRefactorDiagTests`。删除常量：`sidePocketNotchWidth` / `pocketCoreMissRadius` / `pocketDropSpeed` / `jawSettlePocketSpeed`。

### ADR-P10-04 — 求解器评分：放宽分支①接受「擦 jaw 再进」（保留 hybrid，否决纯平滑代理目标）

- **日期**：2026-06-07
- **状态**：✅ 已采纳「放宽分支①」；❌ **否决**「删 hybrid、改纯平滑代理目标」（实测回归，见下「否决的替代方案」）。
- **用户诉求**：求解器应满足管道法——可空心进则取空心解，不可空心进则擦远端 jaw，实现 0–90° × 各贴库距离都能找到正确解；快速、准确、确定地找到解。
- **背景（截图 + 暴力对照诊断坐实）**：新增 `PocketBehaviorDiagTests`（A 角度梯度 / B 贴库容差 / C 力度→rattle / D 目标球旋转撞 jaw / E 求解器 vs 暴力扫 / F 近远 jaw 分类）。E 组用暴力扫遍瞄准偏移对照求解器，证实 **ADR-P10-03 v3.1 的旧分支①漏解**：分支①（`pottedSelected` 且 `objCushionsBeforePocket==0` = −10）只奖励"干净直接进"，把**贴库/强切角下合法的"擦 jaw 再进"**排斥进分支②（碰后方向指向 jaw → 方向误差大 → 被丢弃），导致 28° / 72° / 贴库 20mm「明明能进却报未进」。F 组显示引擎物理本身只允许"空心进 / 擦**远端** jaw 进"，擦**近端** jaw 必 rattle——与管道法（只许贴远 jaw）天然一致。
- **决策（放宽分支①，最小改动）**：`ShotPredictor.solveAimOffset` 分支① 的进袋接受条件由「`objCushionsBeforePocket==0`（干净空心进）」放宽为「**目标球落袋前撞库点都在袋口喉部** `objMaxPrepocketCushionDist ≤ jawNearPocketDist(0.18m)`」，从而接受"擦 jaw 再进"这类真实可进解；同时保留两道护栏：(a) 母球碰目标球前 0 吃库（反 kick，FL-020）；(b) 0.18m 喉部闸值挡掉"远库翻袋蹭进"坏解。干净空心进 vs 擦 jaw 进用极小 per-cushion 惩罚排序，最优区唯一极小、确定性不破。`RunResult` 新增 `objMaxPrepocketCushionDist` 字段。
- **效果**：`PocketBehaviorDiagTests` E 组角度轴 11/11 覆盖暴力可行域（含旧漏的 28°/72°）、贴库轴 100/180/300mm 全进（5/50mm 物理不可进、20mm 单点 knife-edge 窗 0.00° 属非稳健解）；F 组近 jaw 仍全 rattle、远 jaw/空心可进，符合管道法。`PhysicsMatrixTests` 矩阵1/2/3 全绿（0 出界 / 0 画面≠物理 / 0 母球碰前翻袋 / 0 远库翻袋；确定性 20/20）。
- **否决的替代方案（删 hybrid、改纯平滑代理目标）**：曾尝试把分支①/② 整体换成**不依赖 `pottedSelected` 的平滑代理目标**（方向项=碰后方向 vs 管道目标线夹角 + 抵达项=`objMinDist` + 远库翻袋平滑惩罚），目标是更强确定性与更平滑景观。**实测三轮均回归**：① 纯方向项 → 被"方向对但薄擦/力竭到不了袋"的退化解欺骗，A 组全 `进袋=N`、E 组全漏解；② 加 `objMinDist` 抵达项 → E 覆盖恢复，但矩阵1 出现 5 例远库翻袋坏解（高力度穿袋撞远库折返、`objMinDist≈0` 骗过抵达项）；③ 再加远库翻袋平滑惩罚(权重 50) → 矩阵1 进袋率暴跌至 60%（135 组本可进变"沿线停袋前"）、矩阵3 确定性 case0 0/20、并选到母球绕库 kick 解。**根因**：本引擎实际落袋行为与"几何代理 + objMinDist"对不齐，代理目标系统性弱于"直接奖励真进袋"的分支①。故**保留 hybrid 分支结构**，仅放宽分支① 的接受判据。
- **理由**：用户要"快速准确确定找到正确解"。实证表明，在当前引擎下，"直接奖励真进袋（分支①）" 才能稳定找到进袋解；把目标换成几何代理虽更平滑却显著漏解。放宽分支① 在不牺牲进袋率/确定性的前提下补齐了"擦远 jaw 进"覆盖，是收益/风险最优的最小改动。
- **影响（命中 ADR 触发：求解器评分判据变更）**：改动 `ShotPredictor.swift`（分支① 接受判据 + `RunResult.objMaxPrepocketCushionDist`、`AimScoring.jawNearPocketDist/jawPotPenaltyPerCushion`）。诊断新增 `PocketBehaviorDiagTests.swift`。袋口物理几何（ADR-P10-03 漏斗模型）不变。
- **遗留（→ Layer C，后续物理标定）**：① 求解器仍依赖 `pottedSelected`，knife-edge（72° 等）受引擎事件遍历浮点非确定性影响、运行间偶发翻转——属**引擎确定性**问题，须在引擎层（事件排序/容差）解决，非评分层；② drop/jaw 几何与库模型标定，使"擦远 jaw"更稳定落袋、并真实反映现象5（加塞旋转改变目标球撞 jaw 后走向）；③ `effectivePocketAimPoint` 的 far-jaw 偏置当前由"最近安全管道点"隐式给出，可显式强化。

### ADR-P10-03 — 漏斗袋口模型 v3（截图诊断驱动，取代喉腔弹珠箱）

- **日期**：2026-06-04
- **状态**：✅ 已采纳并实现（用户诉求："对分离角与走位页生成多袋口/角度/塞/力度的击球，分析轨迹与进袋，用截图看真实情况后优化物理引擎及袋口进袋"）。
- **背景**：新增 `ShotScenarioRenderTests`——纯 CoreGraphics **2D 顶视接触表 PNG** 渲染器（库边/jaw/落袋孔/标记/幽灵球/瞄准点/母球+目标球真实轨迹/进袋判定一并可见），对多袋口×切角×塞×力度矩阵出图肉眼复盘。截图证伪 ADR-P10-02「喉腔模型」已解决问题：实测进袋呈**斑点状非单调闪烁**（角袋 cut15：v2.4/4.4/5.8 进、v3.3 不进；瞄准偏移每 0.1° 在进/不进间翻转）。
- **根因（截图 + 偏移扫描坐实）**：① **喉腔「弹珠箱」**——高恢复系数（e_c=0.85）侧/后壁把对准的球在腔内反复弹射，只有恰好穿 23.4mm 小孔才落袋 → 进袋带被打成碎片（真实袋口是导球漏斗、非弹珠台）；② **求解-上报双景观错位**——求解短模拟(140ev/7s) 与上报全模拟(500ev/15s) 进袋带不重合；③ **粗扫 0.5° 跨过 0.2–0.4° 窄带**漏检；④ **缓行入袋被显示钳制器 0.02m/s 阈值截断**成"未进"；⑤ 求解 scratch 避让把直接进球解推到绕库别扭解。
- **决策（漏斗袋口模型 v3 = 真实袋口几何）**：
  1. **去喉腔弹珠箱**（`TableGeometry+QiuJi`）：删侧/后壁；保留 jaw 直线段+圆弧作**闸口**（撞鼻 = rattle/未进）。
  2. **落袋捕获覆盖 jaw mouth**（`AngleSceneCalculator.*PocketDropRadius` 角 0.052→**0.070**、中→**0.075**）：干净进入开口的球必落袋，jaw 仍拦截偏离/过力度球 → 进袋带连续而宽（真实袋口的导球行为）。与视觉标记半径仍解耦。
  3. **落袋吸心**（`EventDrivenEngine.resolvePocket`）：落袋即把球心吸到袋心 → 轨迹明确进洞、进袋判定与画面一致。
  4. **求解=上报同保真度**（`ShotPredictor.solveAimOffset` 搜索 sim 改 500ev/15s）+ **粗扫 0.2°**（≤ 进袋带宽，不漏检）。
  5. **直接进袋优先 + 诚实 scratch**（`RunResult.objCushionsBeforePocket`；评分 −10 + 撞库数×1.0 + scratch×0.3）：选直接进球路线，不为躲 scratch 选绕库解；近全直球母球必跟进时如实上报「母球进袋（失误）」。
  6. **慢进袋不截断**（`clampedRecorder` 有效时长按运动态判定、去 0.02m/s 阈值）。

- **v3.1 修订（2026-06-04，用户洞察：不要强制进袋，但进球线方向必须对）**：用户指出大切角 + 小力度时目标球袋向动能不足、进不去是**可接受**的，关键是**进球线方向要对**。旧求解器「未进时退化为最小化 objMinDist（到袋心最近距离）」会挑到**绕库擦袋的多库翻袋解**（碰后初始方向错、只是反弹后蹭到袋附近）——正是用户看到的「大角度变翻袋」。**改为 hybrid 评分**（`solveAimOffset`）：① 能**直接进袋**（`objCushionsBeforePocket==0`）= −10 基线（穿 jaw 开口落袋的瞄点常略偏几何袋心，故必须用真实进袋而非"瞄死袋心"认定，否则擦 jaw 出来）；② 否则按**目标球碰后方向 vs 进球线(target→袋心)夹角误差**评分——该误差对偏移**平滑单峰**、自动补偿 squirt+swerve+throw、天然排斥 banking（绕库解碰后初始方向指向库 → 误差大）。效果：可进的球直接干净进；进不去的（薄/弱）目标球**沿正确进球线停在袋前**（如实未进，不再绕库）。方向景观平滑 ⇒ 粗扫由 0.2° 放回 **0.5°/0.1°/0.02°**（~75 次短模拟，predict 提速）。改动：`ShotPredictor.solveAimOffset`（方向误差 hybrid 评分 + 搜索步长）；`PhysicsEngineTests` +`test_predictor_largeCutClearShot_directPotBothCorners`（守护大切角清晰球直接进、不退化翻袋，左右两角袋测镜像对称）。验证：中台→角袋 cut0–65° 直接进、薄切/过力度个别力度如实未进（进球线方向正确）；左上(idx0) 切角对称恢复正常；用户截图球形（选左上袋）转为「沿正确方向停袋前/直接进」而非多库翻袋。
- **理由**：真实袋口 = jaw 闸口 + 导球漏斗，不是弹珠箱。弹珠箱（ADR-P10-02）虽阻穿库但把对准球弹散、致进袋带碎裂混沌，物理不真实。漏斗模型让进袋带连续宽、对参数微扰稳定，同时 jaw 仍诚实拦截坏球；穿库由捕获覆盖开口 + `clampedRecorder` 安全网双保险。
- **影响（命中 ADR 触发）**：跨模块进袋行为变更（喉腔反弹 → 漏斗捕获 + 落袋吸心）；几何变更（删喉腔线性库、增大落袋孔半径，单一真源不变）。改动：`TableGeometry+QiuJi.swift`（删 throatCushions）、`AngleSceneCalculator.swift`（dropRadius）、`EventDrivenEngine.swift`（resolvePocket 吸心）、`ShotPredictor.swift`（求解保真度/步长/直接进袋优先/慢进袋钳制）；新增 `ShotScenarioRenderTests.swift`（2D 诊断渲染）、`PhysicsEngineTests` +1 非单调回归断言。
- **验证**：4 张接触表（角袋 20 格 / 中袋 20 格 / 塞×力度 15 格 / 典型球形）肉眼全部物理自洽——干净直进、~90° 切线走位、follow/draw/squirt 杆法可见、无穿库/碎裂/判进画面不进；仅近全直球如实报 scratch。`QiuJiTests` 物理套件全绿（PhysicsEngine、Benchmark 14/14 E-solver 5/5、穿库扫描、DrillBake 5/5）、`make build` 通过、lint 0。
- **性能权衡**：单次 `predict` ~150–200ms（求解 sim 提保真度 + 0.2° 粗扫），后台线程 + 防抖 + 取消下可用；取「求解=上报一致 + 进袋带稳定」优先，跟手度为后续优化项。
- **替代方案**：① 仅在求解器层修补窄/碎带——景观本身碎裂，治标不治本；② 喉腔壁改低恢复系数——引擎库恢复系数为全局常量，需按袋口分材质，侵入大，未采纳；③ 保留喉腔箱并放大孔——仍弹射、未采纳。
- **遗留**：薄切（55°）窄口个别力度仍敏感（真实）；中袋 jaw mouth ±0.035→实测 ±0.046；Track B #3 常量标定（需真实俯拍视频）；`predict` 跟手度优化。

### ADR-P10-02 — 物理保真进球管线（USDZ 实测捕获半径 + 稳健闭环求解 + 画面=物理）

- **日期**：2026-06-04
- **状态**：⚠️ 部分被 ADR-P10-03 取代——「闭环求解 + 画面=物理 + USDZ 实测自洽」结论保留；其「喉腔弹珠箱」袋口实现已被 ADR-P10-03「漏斗袋口模型」替换（截图诊断发现喉腔反弹致进袋带碎裂）。
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
