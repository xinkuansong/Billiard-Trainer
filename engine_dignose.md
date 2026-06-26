# Engine Diagnose

> 文档用途：汇总不同模型对物理引擎（尤其袋口 / jaw / 进袋判定）的审阅结论与证据。  
> 备注：本轮仅做审阅与测试，不修改代码。

## Codex5.3 medium

### 审阅范围

- 代码链路：`TableGeometry+QiuJi` -> `EventDrivenEngine` -> `ShotPredictor` -> 测试层
- 重点对象：
  - 袋口几何（`pocketDropRadius`、`pocketJaws`、喉口/嘴区）
  - jaw 接触与反弹
  - 进袋事件触发与最终落袋判定
  - “显示结果是否等于物理真值”

### 核心结论（本轮）

- **结论 1（高优先级）**：当前进袋判定在低速分支上有“方向无关吞袋”风险。  
  `resolvePocket` 采用 `threadsCore || slowSettle`，其中 `slowSettle` 只看速度阈值，不看速度方向（是否朝袋心），边界场景下可能出现“物理直觉不符”的吸袋体感。

- **结论 2（高优先级）**：袋口事件采用“先 quartic 触发 pocket 候选、后续再过滤”的两段式架构，jaw/喉口可达性不在触发层约束。  
  这会增加边界条件下的判定复杂度和参数耦合，容易出现“事件发生合理、结果体感不合理”。

- **结论 3（实测异常信号）**：针对“近/远 jaw 行为”的诊断结果显示，存在“近 jaw 进球”样本，不符合预期管道法。  
  这与用户反馈“撞 jaw 后像被吸进去”高度相关，建议优先深挖。

- **结论 4（实测异常信号）**：`test_C_powerRattle` 扫力度结果中，1.0~6.0 m/s 全部为“撞 jaw 进”，未观察到预期的高力度 rattle 弹出窗口。  
  这提示当前袋口接受逻辑对“带速擦 jaw”可能偏宽。

- **结论 5（正向）**：主干矩阵合约测试（solver contract）全绿，说明当前主路径在“稳定求解与一致性”层面是可用的，但不代表 jaw 边界物理已完全可信。

### 证据（代码与测试）

#### A. 代码证据

- `EventDrivenEngine.resolvePocket`：低速分支仅用 `speed <= pocketDropSpeed` 判定可落袋（无方向项）。
- `EventDrivenEngine` pocket 事件触发：先按袋口圆域 quartic 求根加入 `.pocket` 候选，再由 `resolvePocket` 决策。
- `EventDrivenEngine.enforceTableBounds`：袋口/jaw 边界通过多阈值放行与硬钳组合实现，依赖参数较多。
- `AngleSceneCalculator`：`pocketDropRadius` 与视觉标记半径解耦；`effectivePocketAimPoint` 负责管道法几何选点。

#### B. 本轮实际测试

- 执行命令：

```bash
xcodebuild test -scheme QiuJi -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:QiuJiTests/PhysicsMatrixTests/test_matrix_solverPottingContract \
  -only-testing:QiuJiTests/PocketBehaviorDiagTests/test_F_nearFarJaw \
  -only-testing:QiuJiTests/PocketBehaviorDiagTests/test_C_powerRattle
```

- 结果：`TEST SUCCEEDED`（3/3）
- 关键输出摘录：
  - `[矩阵1·求解器] 共 338 组，可行 338，进袋 338（进袋率 100%）`
  - `[C·力度→rattle] ... 1.0~6.0 m/s 全部“撞jaw进”`
  - `[F·近/远jaw验证]`
    - 距库 40mm：空心 1 / 远jaw进 0 / 近jaw进 3 / 弹出 12
    - 距库 90mm：空心 2 / 远jaw进 0 / 近jaw进 3 / 弹出 9
    - 距库 160mm：空心 5 / 远jaw进 0 / 近jaw进 2 / 弹出 5

- 诊断图产物：
  - `build/pocket_diag/C_power_rattle.png`
  - `build/pocket_diag/F_near_far_jaw.png`

### 风险分级

- **P0（需优先复核）**
  - 近 jaw 进球样本是否属于误分类/误判定（与管道法目标冲突）
  - 低速分支吞袋是否需要加入“朝袋心分量”约束

- **P1（中短期）**
  - pocket 事件触发层是否需要更强几何先验（减少后置过滤负担）
  - jaw/mouth/drop 参数联动灵敏度扫描（避免单点调参副作用）

- **P2（持续改进）**
  - 诊断类测试里大量 `XCTAssertTrue(true)` 仅出图不拦回归，建议逐步补硬断言

### 给后续模型的复核建议（可直接接着写）

- 用相同球形复跑以下测试并对比口径：
  - `QiuJiTests/PocketBehaviorDiagTests/test_F_nearFarJaw`
  - `QiuJiTests/PocketBehaviorDiagTests/test_C_powerRattle`
  - `QiuJiTests/PhysicsMatrixTests/test_matrix_solverPottingContract`
- 重点回答三个问题：
  - 近 jaw 进球在该模型判断里是“物理合理”还是“实现偏差”？
  - 低速吞袋是否应加入方向约束？
  - 触发层与判定层是否应进一步收敛为单层可解释规则？

## GPT-5.5 medium

### 审阅范围与坐标契约

- 本轮重点审阅物理引擎中与袋口、jaw、喉口、进袋判定相关的链路：`BTPhysicsConstants`、`TableGeometry`、`TableGeometry+QiuJi`、`CollisionDetector`、`EventDrivenEngine`、`EngineNumerics`、`ShotPredictor`、`AngleSceneCalculator`、`TrajectoryRecorder`、`TrajectoryPlayback`，并交叉查看现有物理测试与诊断报告。
- 坐标契约：物理与场景均在 X-Z 平面建模，Y 为竖直方向；单位为米；球心坐标用于运动与碰撞；球半径来自 `BallPhysics.radius`；袋口、jaw、库边几何应与 `.kiro/steering/table-geometry.md` 中的球桌真源保持一致。
- 本轮未修改代码；仅运行已有测试，并将输出作为诊断证据写入本文档。

### 核心结论

- **结论 1（高优先级）**：袋口“视觉/瞄准半径”与物理引擎“事件触发半径”存在语义分裂。  
  `AngleSceneCalculator.pocketDropRadius` 给出的角袋/中袋落袋半径约为 70/75mm，用于瞄准与显示；而 `EventDrivenEngine.findNextEvent` 的 pocket 事件按 `pocket.radius - BallPhysics.radius` 求球心进入圆域的时间，等效球心捕获半径更小。若上层认为某条线已进入 drop radius，但底层事件没有触发，用户会看到“瞄准/预期可进”和“物理结果不进”的不一致。

- **结论 2（高优先级）**：当前存在多套进袋入口，解释性和一致性偏弱。  
  主路径是 `findNextEvent` 产生 `.pocket` 事件，再由 `resolvePocket` 二次判定；并行路径是 `enforceTableBounds` 在边界/深袋/低速场景下直接追加 `.pocket`。这两条路径使用的几何语义、时间点和阈值并不完全统一，边界球可能在不同入口下得到不同体感。

- **结论 3（高优先级）**：`resolvePocket` 的二段式判定容易产生“低速吸袋”体感。  
  该函数使用 `threadsCore || slowSettle` 判断是否落袋；`threadsCore` 更接近“穿过袋心核心区域”，但 `slowSettle` 主要依赖速度阈值，缺少“速度方向是否朝袋心/喉口内侧”的约束。边界情况下，低速擦 jaw 或在袋口附近横向运动的球可能被接受为落袋。

- **结论 4（高优先级）**：瞄准求解器与最终物理模拟的 fidelity 不一致。  
  `ShotPredictor.solveAimOffset` 为性能使用 `highFidelityBounds=false` 做搜索，最终 `predict` 再用 `highFidelityBounds=true` 生成展示/结果。搜索阶段看到的是简化边界，最终阶段看到的是高保真喉口/边界，这会让“求解器选中的角度”和“最终仿真是否进袋”处在两套不同地形上。

- **结论 5（中优先级）**：jaw/喉口几何在不同层有重复表达，存在“双真源”风险。  
  `TableGeometry+QiuJi` 中构建了高保真喉腔壁、jaw 与库边几何；`AngleSceneCalculator` 又维护 `pocketPositions`、`pocketJaws`、`pocketDropRadius`、`effectivePocketAimPoint` 等瞄准几何。两边目的不同可以接受，但当前缺少强约束测试证明“瞄准管道可达区域”和“物理喉口可达区域”一致。

- **结论 6（正向）**：主干求解器矩阵仍然稳定。  
  现有 `PhysicsMatrixTests.test_matrix_solverPottingContract` 显示 338 组可行样本全部进袋，说明普通干净球形下的求解与引擎闭环是可用的。问题主要集中在 jaw、浅角、带速擦边、低速边界与喉口过渡，而不是普通直观入袋路径。

### 代码证据

- `BTPhysicsConstants`：定义球半径、球桌尺寸、`pocketCoreMissRadius`、`pocketDropSpeed` 等关键阈值；这些阈值参与“是否接受落袋”的最终判断。
- `TableGeometry+QiuJi`：构建项目专用的中式八球袋口、jaw、圆弧库边与喉腔 wall；其中 `throatBackOffset`、`throatFrontExtend`、`throatWidthMargin`、`throatRestitution` 说明物理层已经不只是一个简单圆形袋口。
- `EventDrivenEngine.findNextEvent`：pocket 事件按球心进入 `pocket.radius - BallPhysics.radius` 的圆域触发；该触发层不直接验证 jaw 管道是否可达。
- `EventDrivenEngine.resolvePocket`：落袋接受规则依赖 `threadsCore || slowSettle`。其中 `slowSettle` 偏速度阈值，未显式要求速度方向继续朝袋心或喉口内侧。
- `EventDrivenEngine.enforceTableBounds`：除事件系统外，还会在深袋/边界/settle 场景下直接产生 `.pocket`；这使落袋结果不只由 `resolvePocket` 决定。
- `AngleSceneCalculator.effectivePocketAimPoint`：使用管道法和 jaw clearance 计算有效瞄点，但并不完整模拟 `TableGeometry+QiuJi` 的喉腔 wall、低 restitution 反弹与最终 `resolvePocket` 筛选。
- `ShotPredictor.solveAimOffset`：搜索阶段与最终阶段的边界 fidelity 不一致，可能导致候选角度在搜索中表现好、在最终高保真模拟中表现不同。
- `TrajectoryPlayback.solvePocketEntry`：进袋后播放会根据最近袋口生成动画入口；这保证视觉连续性，但也可能掩盖“物理落袋判定本身是否合理”的细节，需要诊断测试直接看事件序列。

### 本轮实际测试

- 执行命令：

```bash
xcodebuild test -scheme QiuJi -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:QiuJiTests/PhysicsMatrixTests/test_matrix_solverPottingContract \
  -only-testing:QiuJiTests/PocketBehaviorDiagTests/test_F_nearFarJaw \
  -only-testing:QiuJiTests/PocketBehaviorDiagTests/test_C_powerRattle
```

- 结果：`TEST SUCCEEDED`，共执行 3 个测试，0 failures，耗时约 46.989s。
- 构建/测试期间出现一个既有 warning：`CFBundleShortVersionString` of extension `1.0.0` must match parent app `1.0`。该 warning 与本轮物理诊断无关。
- 关键输出：
  - `[矩阵1·求解器] 共 338 组，可行 338，进袋 338（进袋率 100%）`
  - `[线干净诊断] 母球接触前先吃库：0 组；目标球落袋前吃库：0 组（其中远处真翻袋坏解 0 组）`
  - `[C·力度→rattle] 贴库50mm 瞄点偏jaw +55mm 扫力度 1→6 m/s`
  - `1.0~6.0 m/s` 全部输出为 `撞jaw进`，每档均记录 `吃jaw1`，最近袋心约 `55~57mm`
  - `[F·近/远jaw验证] 目标球浅角approach右上角袋 v=1.6 横扫瞄点 ±90mm`
  - 距库 40mm：`空心1 远jaw进0 近jaw进3 弹出12`
  - 距库 90mm：`空心2 远jaw进0 近jaw进3 弹出9`
  - 距库 160mm：`空心5 远jaw进0 近jaw进2 弹出5`
- 诊断图产物：
  - `build/pocket_diag/C_power_rattle.png`
  - `build/pocket_diag/F_near_far_jaw.png`

### 测试结果解读

- 矩阵测试全绿不能证明 jaw 边界物理正确。它证明的是求解器在 338 组主干可行球形中能稳定找到并完成进袋，不覆盖“擦 jaw 高速 rattle 是否应弹出”“低速是否被方向无关接受”“喉腔壁反弹后是否被二次吞袋”等边界。
- `test_C_powerRattle` 的异常信号较强：1.0 到 6.0 m/s 全部“撞 jaw 进”，没有出现随速度升高而 rattle 弹出的窗口。真实球桌中，带速擦 jaw 的接受率通常不应如此单调宽松，除非该测试瞄点仍处在足够深的合理管道内。需要用图像与事件序列确认它是测试设计问题，还是引擎接受逻辑过宽。
- `test_F_nearFarJaw` 显示存在“近 jaw 进”样本。若当前管道法假设近 jaw 命中应更容易弹出，这些样本就是重点复核对象；如果几何上确实进入了喉口，则需要把测试分类名从“异常”改为更精确的事件分类。

### 风险分级

- **P0：统一落袋语义**  
  明确一个“球心何时算进入袋口/喉口/落袋”的单一契约，并让 `pocketDropRadius`、`pocket.radius - BallPhysics.radius`、`pocketCoreMissRadius`、`resolvePocket`、`enforceTableBounds` 对齐。否则调一个阈值可能修好某个样本，却破坏另一个入口。

- **P0：给 slow settle 增加物理方向证据**  
  如果保留低速 settle 分支，建议至少验证球的速度分量是否朝袋心、喉口内侧或可接受通道推进；否则低速横向擦边、回弹后减速、边界钳制后的球都有被误吞的风险。

- **P1：让求解搜索与最终模拟使用同一套高保真口径，或显式双阶段验证**  
  若搜索阶段必须低保真，应在选出候选角后立即用高保真模拟复核，并将失败样本纳入角度再搜索或降级策略。

- **P1：把 jaw/喉口诊断从“出图测试”升级为回归测试**  
  现有诊断测试能产出图和日志，但更多是在观察现象。建议为已确认的物理契约补硬断言，例如“高速擦 jaw 的某些窗口必须弹出”“低速背离袋心不得落袋”“近 jaw 命中分类必须与事件序列一致”。

- **P2：收敛几何真源**  
  保留 `AngleSceneCalculator` 的上层瞄准模型可以，但需要增加一致性测试，证明它输出的有效瞄点不会穿越物理层不可达的 jaw/喉腔区域。

### 建议补充的测试

- **方向约束测试**：构造球心已在 pocket candidate 圆域附近、速度方向远离袋心或横切袋口的样本，断言不能仅因低速而落袋。
- **高速 rattle 扫描测试**：固定擦 jaw 偏移，扫描 1~8 m/s 或更宽速度区间，要求存在符合预期的弹出窗口；若真实目标是“该偏移必进”，则反向把测试名和文档改清楚。
- **触发层/判定层一致性测试**：记录同一球在 `.pocket` event、`resolvePocket` reject/accept、`enforceTableBounds` 直接 pocket 三类路径下的事件序列，确保不会出现同一几何状态被不同入口判成不同结果。
- **瞄准模型 vs 高保真物理测试**：对 `effectivePocketAimPoint` 产出的边界瞄点进行 `highFidelityBounds=true` 复核，统计失败样本并输出 PNG/JSON，避免 UI 给出“可进”但物理层打不进。
- **喉腔 wall 反弹测试**：构造球以不同速度撞击 throat wall，验证低 restitution 后不会因速度下降被 `slowSettle` 无方向吞袋。
- **事件时间测试**：对 `enforceTableBounds` 直接追加 `.pocket` 的样本检查事件时间与轨迹时间一致性，避免音效、回放和事件分析出现落袋时刻偏移。

### 推荐修复顺序

1. 先冻结一组最小复现样本：从 `C_power_rattle` 与 `F_nearFarJaw` 中各挑 2~3 个有争议样本，记录初始位置、速度、瞄点、事件序列和 PNG。
2. 定义“物理上应进/应弹/应停”的判定契约，不先调阈值。
3. 统一落袋入口：优先让 `resolvePocket` 与 `enforceTableBounds` 共享同一套可解释的 accept/reject helper。
4. 再处理 `ShotPredictor` 搜索 fidelity：候选角必须经过最终同口径验证。
5. 最后把诊断输出转成硬断言回归测试，防止后续内容或参数调整再次改变 jaw 行为。

## Opus4.8 High

> 方法：先静态通读袋口/jaw/进袋全链路（`TableGeometry`、`TableGeometry+QiuJi`、`AngleSceneCalculator`、`CollisionDetector`、`EventDrivenEngine`、`EngineNumerics`、`ShotPredictor`、`TrajectoryPlayback` 及历史 `PHYSICS-PROBE.md` / `PHYSICS-DEBT.md`），再用 **Python 对几何关系做可复现数值核验**，最后跑现有诊断测试取实测证据。**未修改任何代码。**
> 置信度标注：几何类结论已被数值核验**坐实**；控制流类结论为静态分析的**强假设**，并尽量用实测交叉验证。

### 与前两节的关系

- 我**独立复核并同意** Codex5.3 / GPT-5.5 关于「`slowSettle` 方向无关」「多套进袋入口语义不统一」「搜索 vs 最终 fidelity 不一致」的判断。
- 本节的**新增贡献**有两点（前两节均未指出）：
  1. **发现 2（角袋喉腔轴向取错，确定性几何 bug）**——已数值坐实。
  2. **发现 1 的机理量化 + 实测坐实**：把「多入口」具体定位为 `enforceTableBounds` 的 **70mm 无条件 `pocketDeep` 真空抢先架空了 `resolvePocket` 的 41.4mm 两段闸门**，并用 `test_C` 的「最近袋心 57mm」直接证明球未进 41.4mm 捕获圈却落袋。

### 核心结论

- **结论 1（P0，已实测坐实）：三套捕获机制阈值不一致，`enforceTableBounds` 的无条件 `pocketDeep` 真空（角 70mm / 中 75mm）抢先并架空 `resolvePocket` 两段闸门。**
  - `resolvePocket` 的 CCD 捕获圈半径 = `pocket.radius − R` = **41.4mm**（角袋），且要求「正对 ≤22mm 或慢速 ≤1.05」。
  - `enforceTableBounds` 的 `pocketDeep = dist <= pocket.radius` = **70mm**，**不看速度、不看方向**；且 `evolveAllBalls`（含 `enforceTableBounds`）执行**早于** `resolveEvent → resolvePocket`。
  - 因 `41.4mm < 70mm` 且捕获圈几乎与可玩区角点（42.4mm）重合：球一越过角点进入 jaw 区，就满足「出框 + dist<70mm」被无条件吸入，两段闸门**根本到不了**。喉腔后壁（球心接触距袋心仅 11.4mm）几乎永远到不了 → 喉腔三片墙基本是死几何。
  - **实测铁证**（`test_C_powerRattle`）：贴库 50mm、瞄点偏 jaw +55mm 的球，力度 **1→6 m/s 全部「撞 jaw 进」，最近袋心 55–57mm**。`57mm` 介于「捕获圈 41.4mm」与「pocketDeep 70mm」之间——球**从未进入 41.4mm 捕获圈**（`resolvePocket` 的 CCD 进袋事件不会触发），却依然落袋，**只能由 70mm 的 `pocketDeep` 真空解释**。这正是「带速擦 jaw 该 rattle 却被吸进去」的根因。

- **结论 2（P0，已数值坐实）：角袋喉腔轴向取错——用「台心→袋心」(27.1°) 而非真实袋口对称轴 (45°)，导致喉腔腔体被扭转 ~18°、左右不对称。**
  - `TableGeometry+QiuJi.throatWalls` 用 `n = unit(袋心)` 当袋轴。对中袋恰好正确（`unit(袋心)=90°`＝对称轴），但对**4 个角袋**：`unit(袋心)=27.1°`，而真实对称轴（两 jaw 尖中点→袋心，亦即两 jaw 连线法线）=**45.0°**，**偏差 17.9°**。
  - 数值核验后果：后壁中点偏移 **12.5mm**；两侧壁本应关于 45° 轴镜像等长，实际为 **137mm vs 112mm**（同偏 ~12°、不镜像）。两 jaw 尖到袋心都是 58.6mm（袋口本身对称）→ 故畸形纯由轴向取错引入。
  - 后果：进入角袋喉腔的球（rattle 情形）撞到偏斜、不对称的腔体，反弹方向系统性偏向长库侧，左右 jaw 行为不一致 = 不符合物理逻辑。
  - 当前因结论 1 的真空抢先，喉腔多数时候到不了，此 bug 被**部分掩盖**；一旦修复结论 1 让球真正进喉腔，此 bug 会显性化，故应**一并修**。

- **结论 3（P1）：两条 settle 收袋路径均方向无关、且双阈值。** `resolvePocket.slowSettle` 用 `speed ≤ 1.05`，`enforceTableBounds.settledInJaw` 用 `speed < 0.35`，都不看方向。一个撞后壁后背离袋心逃逸、减速到阈值以下的球会被「settle」吸回（应 rattle 出）。两阈值哪个生效取决于球此刻在「捕获圈内」还是「框外袋嘴圈内」，难以推理（与 `PHYSICS-DEBT` D-A3 同源）。`1.05 m/s` 偏宽松、是 magic number。

- **结论 4（P1）：落袋孔半径 70/75mm 是「凑开口」的调参、非真实洞口（已自认 D-B2）。** USDZ 实测 jaw 尖距袋心仅 58.6mm，而 `cornerPocketDropRadius=0.070` 与视觉标记半径解耦、为覆盖 mouth 调出。它配合结论 1 的无条件 `pocketDeep`＝给每个角袋套了一个 70mm 半径真空圈，比真实袋口有效捕获窗大。

- **结论 5（P2）：中袋 fillet 弧与喉腔侧壁几何重合。** 数值核验：中袋 side fillet 弧心 `(±0.035, 0.635)` 与 `throatWalls` 的侧壁竖线 `x=±0.035` 完全重合，同处既有圆弧库又有线性侧壁、法线方向不一致 → 双弹/抖动风险。另中袋 mouth 建模 `±0.035` 比 USDZ 实测 `±0.046` 窄 ~11mm（D-B2），中袋偏易 rattle。

- **结论 6（正向）：内核物理（击打/球-球/Han2005 库边/走位）忠实移植 pooltool 且历史探针绿灯，问题集中在「袋口捕获判据」这一层，而非碰撞内核。**

### 代码证据

- 无条件真空（结论 1）：
  - `EventDrivenEngine.swift:686-696` `pocketDeep = dist <= pocket.radius`（70/75mm），`if pocketDeep || settledInJaw { state=.pocketed; resolvedEvents.append(.pocket(...)) }`，无速度/方向项。
  - `EventDrivenEngine.swift:580` `enforceTableBounds` 在 `evolveAllBalls` 内、`EventDrivenEngine.swift:176` `resolveEvent` 之前执行。
  - `EventDrivenEngine.swift:495` CCD 捕获 `r = max(pocket.radius - BallPhysics.radius, 0)` = 41.4mm（角）。
  - `EventDrivenEngine.swift:937-941` `resolvePocket` 两段闸门 `threadsCore(≤22mm) || slowSettle(≤1.05)`。
- 喉腔轴向取错（结论 2）：`TableGeometry+QiuJi.swift:92-95` `let nlen = sqrtf(cx*cx+cz*cz); nx = cx/nlen, nz = cz/nlen`（应改为 `unit(两 jaw 尖中点 → 袋心)`）。
- 双阈值（结论 3）：`pocketDropSpeed=1.05`（`BTPhysicsConstants.swift:86`）、`jawSettlePocketSpeed=0.35`（`EngineNumerics.swift:46`）。
- drop 半径调参（结论 4）：`AngleSceneCalculator.swift:82-83` `cornerPocketDropRadius=0.070 / middlePocketDropRadius=0.075`。
- 中袋几何重合（结论 5）：`TableGeometry.swift:319-330` side fillet 弧心 `±(sideNotchHalf+sideFilletRadius)=±0.035`；`TableGeometry+QiuJi.swift` `throatWalls` 侧壁起自 `pocketJaws` 的 `±0.035`。

### 几何数值核验（可复现）

口径常量：`R=0.028575`、内框 `2.540×1.270`、角袋 offset `0.042−0.012=0.030`、中袋 offset `0.053−0.009=0.044`、`drop` 角 0.070 / 中 0.075。

| 量 | 数值 | 含义 |
|---|---|---|
| 角袋袋心 | (1.300, 0.665) | RU |
| CCD 捕获半径 = drop−R | **41.4mm** | `resolvePocket` 触发圈 |
| `pocketDeep` 阈值 = drop | **70mm** | `enforceTableBounds` 无条件吸入半径 |
| jaw 尖距袋心 | 58.6mm | 真实喉口 |
| 可玩区角点距袋心 | 42.4mm | ≈ 捕获圈，故越角即出框 |
| 后壁球心接触距袋心 | 11.4mm | 深在捕获圈内 → 真空抢先 |
| **角袋喉腔轴：代码 vs 真实** | **27.1° vs 45.0°（偏差 17.9°）** | 结论 2 |
| 后壁中点偏移 | 12.5mm | 喉腔被扭转 |
| 两侧壁长（应等长） | 137mm vs 112mm | 喉腔不对称 |
| 中袋 fillet 弧心 / 喉腔侧壁 | 同为 x=±0.035 | 几何重合 |

> 复现脚本（纯 stdout，无文件写入）：用上述常量计算 `unit(袋心)` 与 `unit(jaw中点→袋心)` 的角度差、后壁/侧壁坐标即可，已在本轮 Python 中核验。

### 本轮实际测试

执行命令：

```bash
xcodebuild test -scheme QiuJi -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:QiuJiTests/PocketBehaviorDiagTests/test_B_railToleranceGradient \
  -only-testing:QiuJiTests/PocketBehaviorDiagTests/test_C_powerRattle \
  -only-testing:QiuJiTests/PocketBehaviorDiagTests/test_F_nearFarJaw
```

结果：`** TEST SUCCEEDED **`（3/3，0 failures，~0.54s 测试体）。关键输出：

- `test_C_powerRattle`（贴库 50mm，瞄点偏 jaw +55mm，扫力度 1→6 m/s）：
  - **力度 1.0~6.0 全部「撞 jaw 进」，每档「吃 jaw 1」，最近袋心 55~57mm**，无高力度 rattle 弹出窗口。
  - **关键解读**：最近袋心 57mm > CCD 捕获圈 41.4mm，球**从未进 `resolvePocket` 捕获圈**却落袋 → 由 `enforceTableBounds` 70mm `pocketDeep` 吸入。**直接坐实结论 1**。
- `test_F_nearFarJaw`（目标球浅角 approach 右上角袋，v=1.6，横扫瞄点 ±90mm）：
  - 距库 40mm：空心 1 / 远 jaw 进 0 / **近 jaw 进 3** / 弹出 12
  - 距库 90mm：空心 2 / 远 jaw 进 0 / **近 jaw 进 3** / 弹出 9
  - 距库 160mm：空心 5 / 远 jaw 进 0 / 近 jaw 进 2 / 弹出 5
  - 「近 jaw 进」样本与 Codex5.3 观察一致；在结论 1/2 框架下，这是「球擦近侧 jaw 后进入 70mm 真空被吸入 + 喉腔不对称偏置」的联合表现。
- `test_B_railToleranceGradient`（直接发射目标球 v=1.8，扫瞄准横移 ±90mm）：
  - 进袋窗随贴库间隙变化：间隙 5mm→22mm，20mm→15mm，50mm→22mm，100mm→45mm，180mm→**60mm**。窗口随离库变宽，与「70mm 真空 + 浅角越容差越宽」一致；非单调（20mm 窗反而最窄）提示喉腔/jaw 几何在贴库段有畸变（与结论 2/5 呼应）。
- 诊断图产物：`build/pocket_diag/B_rail_tolerance.png`、`C_power_rattle.png`、`F_near_far_jaw.png`。

### 风险分级

- **P0**
  1. **统一落袋语义**：`pocketDeep(70/75mm)`、`drop−R(41.4mm 捕获圈)`、`pocketCoreMissRadius(22mm)`、`pocketDropSpeed/jawSettlePocketSpeed`、`resolvePocket`、`enforceTableBounds` 必须收敛到**单一可解释契约**；当前 `enforceTableBounds` 的 70mm 无条件吸入应降级或加方向/速度门，避免架空两段闸门。
  2. **修角袋喉腔轴向**：`throatWalls` 的 `n` 改为 `unit(两 jaw 尖中点 → 袋心)`（或两 jaw 连线法线），消除 17.9° 偏斜与左右不对称。
- **P1**
  3. settle 分支加「速度朝袋心/喉口内侧」方向证据；合并 1.05 / 0.35 双阈值。
  4. drop 半径回归真实洞口尺寸（依赖 USDZ 重导，D-B2）。
- **P2**
  5. 中袋 fillet 弧与喉腔侧壁去重；mouth 宽度按实测 ±0.046 校正。
  6. 把上述契约转成硬断言回归（如「最近袋心 > 捕获圈半径则不得判进」「角袋喉腔两侧壁等长」「带速擦 jaw 在某速度窗必须弹出」）。

### 给后续模型的复核建议

- 复跑 `test_C_powerRattle`，确认「最近袋心 57mm < 70mm 即落袋」是否仍成立——这是判断 `enforceTableBounds` 真空是否被收敛的最快指标。
- 修 `throatWalls` 轴向后，对 4 个角袋出 PNG，肉眼核对喉腔是否左右对称。
- 回答：进袋应由「单一捕获契约」决定，还是保留事件层 + 兜底层两道？若保留，两道的几何半径与门控必须一致。

