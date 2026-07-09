# P13 — 思路训练器（走位反解器 / Position-Play Solver）

> 把现有「正向瞄准求解」(`ShotPredictor.predict`：给定塞/力度求瞄准让目标球进袋) 升级为「走位反解」：塞与力度变成自由变量，约束改为母球落点。新增独立工具「思路训练器」，与「走位编排台」同级，挂在角度 Tab「工具」分段。
> 需求澄清与决策见 2026-06-14 与用户的多轮交互式确认（算力/落区定义/无解降级/K 球语义/吃库策略/UI）。

## 任务清单

| 任务 | 说明 | 状态 |
|------|------|------|
| T-P13-01 | `SolveConstraint`/`SolveRegion` 瞬态模型（落区 rect/circle + 过点 + vMin，归一化系）| ✅（2026-06-14）|
| T-P13-02 | `ShotPredictor` 增补 `ShotPrediction.events: [ShotEvent]`（默认空，向后兼容），供情形 B 吃库/过点后碰撞分析 | ✅（2026-06-14）|
| T-P13-03 | `PositionPlaySolver` 情形 A（落区）：spin×velocity 网格 + 进袋硬约束 + 停点到落区有符号距离评分 + 吃库分档枚举 + 无解最接近降级 | ✅（2026-06-14）|
| T-P13-04 | `PositionPlaySolver` 情形 B（K 球过点）：velocity 密扫分段（过 P 且 v>vMin、到 P 前吃库分组），按过 P 后第一颗碰撞球离最近袋口最近的段取中值速度 | ✅（2026-06-14）|
| T-P13-05 | `PositionPlaySolverTests`：情形 A/B + 吃库分档排序 + 无解降级用例 | ✅（2026-06-14，5/5 过）|
| T-P13-06 | 入口：`AngleHomeView` 海报卡 + `AngleRoute.positionPlaySolver` + `MainTabView.angleDestination` | ✅（2026-06-14）|
| T-P13-07 | `SiluTrainerView` + `SiluTrainerViewModel`：复用编排台摆球/球台/回放；塞/力度只读显示当前解；落区/过点台面手势绘制 + 渲染；最优解 + 下一解切换 + 进球线/假想球/母球轨迹 + 文字说明；击打回放 + 导出送产线 | ✅（2026-06-14）|

> **完成记录（2026-06-14）**：`make xcodegen` + `make build` BUILD SUCCEEDED；`PositionPlaySolverTests` 5/5 全过（落区 SDF 金标准 + 情形 A 可落区/无解降级 + 情形 B 过点分段）；`PositionPlayFreeAimTests` 7/7 回归全过。`PhysicsEngineTests` 既有 3 个失败（`largeCutClearShot`/`objectPath_reachesPocket`/`withSideSpin_objectPots`）经核为**此前未提交工作遗留**（PHYSICS-DEBT.md §5.7 / PROGRESS 已记录），本次为纯增量改动（仅新增 `ShotEvent`/`events` 字段 + 只读事件收集），与之无关。

## DoD

- a. 角度 Tab 工具分段出现「思路训练器」入口，可进入独立页面。
- b. 摆放母球/目标球/袋口 + 画落区 → 求解器返回按吃库数分档、库少优先的解列表，默认显示最优解，可「下一解」切换。
- c. 每个解叠加渲染目标球进球线 + 假想球 + 母球轨迹，并显示该解的塞/力度/吃库数/margin 文字说明。
- d. 无可行解时仍展示最接近解并醒目标注「未进袋/不可行 + 原因」。
- e. K 球过点：求得速度分段且段中值速度下母球确经过 P（v>vMin）。
- f. 旧 72 条 drill / 编排台零回归（`ShotPrediction.events` 向后兼容、`ShotPredictor.predict` 行为不变）。
- g. `make build` 通过、`QiuJiTests` 全绿、lint 0。

---

## ADR 记录区

### ADR-P13-01 — 走位反解器（嵌套求解 / 吃库分档 / 独立工具）

- **日期**：2026-06-14
- **状态**：✅ 已采纳（用户多轮交互式确认）。命中 ADR 触发：**新增求解策略**（反解：约束从「瞄准进袋」扩展到「母球落点/过点」）+ **跨模块边界**（新页面消费 `ShotPredictor`/编排台组件，新增求解器复用物理引擎）。

- **背景**：现有 `ShotPredictor.predict` 是正向求解——固定塞/力度，一维搜瞄准偏移让目标球进袋。用户要把要求升级：放开塞与力度，固定母球落点。落点有两种语义：① 一个「对下一颗球有利的可行区域」（打一看二，落点是区域不是点）；② K 球——母球需在 v≠0 时经过某点（去碰另一颗球），解沿速度轴是开区间的并集（非闭集），需按速度分段找可行解。

- **决策**：

  1. **嵌套求解**：外层在 `(spinX, spinY, velocity)` 空间搜索；内层对每个组合复用 `ShotPredictor.predict` 求瞄准并以「目标球进选定袋」为**硬约束**（自动吸收 squirt/throw/swerve），全精度模拟读母球轨迹与事件流。塞对瞄准的影响留给内层，外层只管走位落点 → 职责干净，无需新造物理。

  2. **算力**：离线批处理（数秒~十几秒），放后台串行队列。用户拍板可接受非实时，以换取铺满网格 + 全精度内层瞄准的解质量。

  3. **落区由用户手画**（rect/circle，归一化系），不自动推导（用户拍板）。落区/过点是求解器的**瞬态输入约束**（`SolveConstraint`），**不改 `PlannedShot`、v1 不持久化**；求出的解就是标准 `PlannedShot`（含算好的 spin/velocity）。

  4. **吃库数按档枚举**（用户拍板）：母球到达同一落点/过点可走 0/1/2… 库，这些是拓扑分离的解族，目标函数跨库数跳变多峰。故按库数分桶，**每桶各自最优、库少优先排序**；**库数越多要求的 margin 越大**（`requiredMargin(k) = base + k·Δ`，脆弱多库解淘汰）。情形 A 按「碰球后母球吃库数」分类；情形 B 按「到达 P 前吃库数」分类（P 之后吃库属于 K 的结果，不参与路线分类）。

  5. **情形 A（落区）评分**：母球停点（`finalPositions[cueBall]`）到落区的**有符号距离**（区内为负=满足，区外为正距离）。可行集里取最鲁棒解（停点离区域边界最远）。**无可行解 → 返回最接近解 + margin**（用户拍板：不静默失败、不自动放宽、不直接报无解）。

  6. **情形 B（K 球过点）速度分段**：固定/小步进塞，对 velocity 密扫；每个采样判定「母球轨迹折线到 P 的最近距离 < 容差 ∧ 过 P 时 v > vMin」，连续命中聚成速度分段，并按「到达 P 前吃库数」分组。每段评估「母球过 P 后碰到的**下一颗在桌球**离最近袋口的距离」（用户拍板：第一颗 = 过 P 后母球碰到的下一颗任意在桌球，非 P 处指定球），选该距离最小的段，取**段中值速度**（远离段边界=远离过点失败临界，鲁棒）。

  7. **独立工具**：新增 `PositionPlaySolver`（区别于已有 `PositionPlayShotSolver` 的单杆前向求解），新页面 `SiluTrainerView`/`SiluTrainerViewModel` 复用 `AngleTrainingScene`/`AngleSceneView`/编排台摆球与回放逻辑。塞/力度控件保留但为**只读指示器**（展示当前解结果，用户拍板不改）。结果默认显示最优解、「下一解」翻档（用户拍板）；每个解叠加进球线/假想球/母球轨迹 + 文字说明。「击打」复用运杆 + `TrajectoryPlayback` 回放；「导出」把当前解组装为单步 `PositionPlaySequence` 经 `PositionPlaySequenceArchive` 送产线（沿用编排台 `#if targetEnvironment(simulator)` 策略）。

- **影响**：
  - 新增文件：`QiuJi/Core/PositionPlay/PositionPlaySolver.swift`、`QiuJi/Features/PositionPlay/Views/SiluTrainerView.swift`、`QiuJi/Features/PositionPlay/ViewModels/SiluTrainerViewModel.swift`、`QiuJiTests/PositionPlaySolverTests.swift`。
  - 改动文件：`ShotPredictor.swift`（新增 `ShotEvent`/`events`，`runShot` 顺手收集）、`AngleHomeView.swift`（路由 + 海报卡）、`MainTabView.swift`（目的地 case）。
  - 向后兼容：`ShotPrediction.events` 默认空数组，`predict`/`simulateFree` 既有行为与字段不变；`PlannedShot` 不动。

- **遗留 / 不在本次范围**：
  - 多杆连续求解（v1 单杆）。
  - 落区/过点持久化与教学化呈现。
  - 求解器网格密度/内层精修的极致性能优化（先正确，再按实测调）。

### 后续微调（2026-06-15）— 并行加速 + 选中反馈

- **并行求解**：`ShotPredictor.predict` 为纯函数（每次自建引擎、只读静态常量、`EventDrivenEngine` 无 `static var` 可变态），故外层网格用 `DispatchQueue.concurrentPerform` 跨核并行。情形 A 并行全部 `(spinX,spinY,velocity)` 候选；情形 B 跨塞并行（每塞独立做 velocity 密扫 + 分段）。均用 `withUnsafeMutableBufferPointer` 写互不相交下标（安全并发写入模式）。
  - **实测墙钟**（`test_perf_productionParams_printsWallClock`，模拟器宿主）：情形 A `.standard`（~399 次模拟）= **12.67s**；情形 B `.passThrough`（~333 次模拟 + 过点采样）= **10.97s**。并行前同等网格约 30–40s。真机核数较少会略慢，仍落在 ADR「数秒~十几秒」离线预算内。
  - 6 项求解器测试全绿，并行未改变确定性结论（情形 A/B/分档排序/无解降级用例不变）。
- **目标球选中反馈**：原 `onBallTapped → selectTarget` 已接通，但选中后**无任何视觉提示**、求解前不画线，导致「点球像没反应」。新增 `refreshOverlays()`：① 选中目标球画亮绿选中环（常驻）；② 无解时即时叠加纯几何预览（假想球 + 母球→假想球瞄准线 + 目标球→袋口进球线），无需先求解即可确认「目标球 / 目标袋」选对。摆球模式 hint 改为「拖动摆球 · 点目标球选中（绿环）· 点袋口选袋，再选工具画约束」。
- **改动文件**：`PositionPlaySolver.swift`（并行）、`SiluTrainerViewModel.swift`（选中反馈 + hint）、`PositionPlaySolverTests.swift`（耗时测量用例）。

### 后续微调（2026-06-15）— 内层瞄准提速（共享核心 + 独立编排）+ 高速假停护栏 + 排序

> **背景**：实测瓶颈不在外层 `(spin,velocity)` 网格本身，而在**每个候选内层 `solveAimOffset` 的三级网格瞄准**（粗 49 + 中 13 + 细 13 = 75 次短模拟）。在不动 `predict`（其余 5 个场景 + 全部物理测试都走它）的前提下提速。

- **隔离策略（Option B：共享核心 + 独立编排，不复制物理）**：
  1. **行为不变重构** `ShotPredictor.predict` → 抽出 `prepareAim(input,into:)`（瞄准几何 + 可行性闸门，**与塞/力度无关**，返回 `AimContext`）与 `buildPrediction(finalAim:context:...)`（完整模拟 + 提取全部字段）。`predict` 改为「prepareAim → solveAimOffset → buildPrediction」，逐字节等价（物理回归已证，见下）。
  2. **走位反解快速路径**（同文件 `extension ShotPredictor`，可访问私有核心、无需放宽任何可见性）：
     - `positionAimOffset(input:context:)`：把内层瞄准从三级网格换成**黄金分割一维极小化**（评分函数与 `solveAimOffset` 同口径），**~15 次短模拟 vs 75 次（≈5×）**，精度 0.05°（进袋由全模拟硬校验，足够）。
     - `predictForPositionSolve(input,aimOffset:)`：可传**预解的记忆化瞄准**或现解；复用同一 `prepareAim`/`buildPrediction`，结果字段与 `predict` 同口径。
- **跨 spinY 记忆化 + 降维**：squirt（挤偏）只来自横塞 spinX、与高低杆 spinY 无关 ⇒ 瞄准只随 `(spinX,velocity)` 变。求解器 `SearchParams` 拆 `spinXValues`（±0.3 三档，0 优先降维）/ `spinYValues`（五档），`candidateMatrix` 对每个唯一 `(spinX,velocity)` 只解一次瞄准、跨 spinY 复用；两段都 `concurrentPerform` 并行。**完备性护栏**：复用 aim 没进、但该 spin 自解 aim 可能进 ⇒ 对漏进者单独重解一次。
- **高速假停护栏**（用户反馈「母球还有速度却停在区域内」）：`ShotPrediction.cueFinalSpeed`（母球末帧水平速度）；情形 A 落区解仅接受 `cueRestedInPlace`（未 scratch ∧ 末速 < 0.05 m/s = 真停点，剔除被 maxEvents/maxTime 截断的假停）。
- **排序（用户拍板「越少加塞越好、吃库越少越好」）**：情形 A：库少 → 加塞少 → 扎入更深；情形 B：库少 → 过点后 K 球离袋近 → 加塞少。
- **实测墙钟**（`test_perf_productionParams_printsWallClock`，模拟器宿主）：情形 A `.standard` **12.65s → 1.41s（~9×）**；情形 B `.passThrough` **11.08s → 1.64s（~6.8×）**。
- **正确性 / 零漂移验证（诚实交付）**：
  - `test_fastPath_matchesPredict_potOutcome`：黄金分割瞄准与 `predict` 网格瞄准在 28 组 `(spin,velocity)` 上**进袋判定逐一一致**、同库结构下母球停点差 < 0.2m。
  - 物理回归子集 **40 测全绿**（`PhysicsInvariantTests` 9/9 含确定性可复现 + 边界不越界；`PocketBehaviorDiagTests` 24 个进袋行为网格；`PositionPlayFreeAimTests` 7/7）→ `predict` 重构对其余场景**零漂移**。
  - `PositionPlaySolverTests` 7/7 全绿。
- **回退说明（诚实记录）**：曾把 `maxTime` 提到 30s 试图压假停，导致测试观感「卡死」——实为**模拟器 Invalid device state 楔死**（非 maxTime），已回退，改由末速护栏处理截断假停。
- **改动文件**：`ShotPredictor.swift`（行为不变重构 + 快速路径 extension + `cueFinalSpeed`）、`PositionPlaySolver.swift`（spinX/spinY 拆分 + 记忆化矩阵 + 护栏 + 排序）、`PositionPlaySolverTests.swift`（一致性 + 耗时用例）。

### 后续微调（2026-06-15）— 局部精修（拓扑锁定模式搜索）+ 落点约束

> **背景**：用户反馈「粗网格有时得到偏差较大的解」，并希望新增「落点」（精确停位）功能。两件事一并做。

- **一期：情形 A 局部精修（`refineCandidate`，拓扑锁定的 Hooke-Jeeves 模式搜索）**
  - **动机**：粗网格只在离散 `(spinX,spinY,velocity)` 上采样，常**定位到对的 basin 却踩不准谷底**。精修在种子解附近连续邻域里最小化「停点有符号距离」objective，把停点推向落区/落点更深处。
  - **拓扑锁定（关键护栏，防取巧外推）**：objective **只接受**「进袋 ∧ 真停稳（`cueRestedInPlace`）∧ 碰球后吃库数 == 种子」的样本，其余记 `+∞`。故精修**永不跨越拓扑悬崖**（不会把解从「0 库」滑到「1 库」再谎称更优），只抛光已找到的 basin。治不了「basin 整个被跳过」——那靠加密 `spinXValues`，非本机制（已在文案/注释如实标注边界）。
  - **算法**：坐标式 6 邻居（±spinX、±spinY、±velocity），越界/越打滑极限（`miscueLimitFraction`）者剔除；每轮并行评估 6 邻居，贪心移动到最优改进者，无改进则步长减半；初始步长 ≈半网格步（0.15），终止步长 0.02，≤12 轮。确定性（固定探测顺序 + 物理无随机）。
  - **接入** `solveRestRegion`：每个吃库桶代表解 + 降级最接近解都过一遍精修，重打分后再排序；降级解精修后**可能反升级为满足约束**。
  - **不破坏既有调用**：`SearchParams` 新增 `refineEnabled/refineSpinStep/refineVelStep/refineMinStep/refineMaxIters`，**均带默认值** ⇒ memberwise init 对它们可选，旧调用点（含测试 `coarse`）零改动。
- **二期：落点约束（`SolveRegion.point`）**
  - **数据层**：新增 `case point(center, tolerance)`（归一化）。几何上等价于半径 = tolerance 的圆，**复用各向同性圆 SDF**（`horizontalDistance − tolerance·scale`；圆对称，归一化 Y↔Z 反向不影响半径）。新增 `isPoint`/`centerNormalized`。
  - **求解装配分叉**（`solveRestRegion` 按 `region.isPoint`）：落点语义是「**最小化到点距离**」——对**所有可进解**按吃库桶取「最近代表」（不要求命中也返回），库少 → 更近排序；**容差内（signed≤0）才标 `satisfiesConstraint`**。落区维持原「够稳余量 + 加塞最少代表」装配。两者都吃一期精修。
  - **文案**（`makeRegionSolution`）：落点展示「距目标约 Ncm」（= signed + 容差半径，真实到点距离），落区维持「余量/距落区 Ncm」。
  - **UI**：`SiluTrainerViewModel` 新增 `Tool.restPoint` + `Draft.restPoint` + `pointTolerance`（默认 0.02 归一化 ≈5cm）；`renderConstraint` 画**琥珀色十字（目标点）+ 容差环**，与青色落区/过点区分。`SiluTrainerView` 顶部工具行扩为「落区 / 落点 / 过点 / 摆球」。
- **坐标契约复核**：距离判定全在 SceneKit 世界系（X–Z 水平、Y 朝上），约束几何存归一化系经 `AngleSceneCalculator` 转换；落点只复用封装好的圆 SDF，未新写任何坐标转换/三角，几何风险低。
- **验证（诚实交付）**：`PositionPlaySolverTests` **10/10 全绿**，新增 ① 落点 SDF 金标准（中心/容差边界/区外，数值对齐）；② 精修不劣 + 锁拓扑 + 确定性（精修 vs 不精修，按桶比 margin 不减、cushion 不变，两跑一致）；③ 落点按桶返回最近代表、容差内判满足、停点确在容差内。**实测墙钟基本不变**（情形 A 2.30s / 情形 B 1.68s，精修只抛光少量桶代表）。`ShotPredictor`/物理本轮**未改动**，无物理回归风险。
- **改动文件**：`PositionPlaySolverModels.swift`（`.point` + `isPoint`/`centerNormalized`）、`PositionPlaySolver.swift`（`refineCandidate` + `SearchParams` 精修参数 + `isPoint` 分叉装配 + 文案）、`SiluTrainerViewModel.swift`（`restPoint` 工具/草稿/渲染/容差）、`SiluTrainerView.swift`（四工具切换）、`PositionPlaySolverTests.swift`（落点 SDF + 精修 + 落点装配用例）。

### 后续微调（2026-06-16）— 分水平求解开关（是否左右塞 / 走位复杂度预算）

> **背景**：不同水平玩家走位差异大——很多业余**不会/不用左右塞**，也走不了多库。给求解器加两个**可选收窄**开关,既贴合分水平训练,又能压搜索空间。多轮澄清后用户拍板：①只分「是否左右塞」（高低杆=走位入门核心技术，始终全开，不再细分）；②吃库分「基础 ≤1 库 / 不限」；③**默认 = 完整能力**（允许左右塞 + 不限），两收窄作为可选；④吃库走「**优先+兜底**」（预算内优先、无解才回退多库并标「进阶」），不做硬过滤以免「无解」；⑤难度轻提示本轮**不做**（选项 A，等做「可执行性评分」时整体做）。

- **关键性质：默认态 == 原行为，零回归**。两开关默认放开 ⇒ 求解走原 `.standard`/`.passThrough`，主路径一字未动；收窄是纯 opt-in。
- **是否左右塞**：开关只改 `SearchParams.spinXValues`——禁塞 ⇒ `[0]`（横塞是唯一影响内层瞄准的维度，禁掉后唯一瞄准解 3→1，是性能收益最大的一刀；竖塞 spinY 始终五档、跨档复用同一瞄准几乎不增成本）。**精修锁轴护栏（关键正确性点）**：`refineCandidate` 改为**只沿网格实际搜过的轴探测**（`spinXValues.count > 1` 才探 ±spinX、`spinYValues.count > 1` 才探 ±spinY）——否则精修第一步就会把被禁的横塞重新引回，违背约束。对既有配置（standard 3/5、passThrough 3/3、测试 coarse 3/3）count 均 >1，行为不变。
- **走位复杂度预算**：`SearchParams.maxCushions: Int?`（nil=不限，默认）。实现为**后处理 `applyCushionBudget`**（在 `solve` 分发器对最终解列表分组，不改搜索/装配）：优先返回吃库 ≤cap 的解；**仅当其为空**才回退返回全部解并逐个置 `PositionPlaySolution.beyondCushionBudget=true`。新增 `beyondCushionBudget`（默认 false，memberwise init 向后兼容）。VM `solutionStatus` / View `solutionSubtitle` 在该标记下加「进阶」前缀（用户拍板的兜底语义，非选项 A 推迟的难度提示）。
- **UI/VM**：`SiluTrainerViewModel` 加 `@Published allowSideSpin=true` / `basicPositionOnly=false`（didSet 失效重求解），新增 `searchParams(for:)` 由基底 + 两开关组装并传入 `solve()`；`SiluTrainerView` 在工具栏「⋯」菜单加「求解范围」分区两个 `Toggle`（不挤占顶部工具行）。
- **验证**：`make build` ✅、`PositionPlaySolverTests` **13/13**（新增 ① 禁塞 ⇒ 所有解 spinX==0 含精修不引回；② 基础预算内 ⇒ 解吃库 ≤1 且不标进阶；③ 不可满足预算 cap=-1 ⇒ 兜底返回全部解且全标进阶、不给无解）。墙钟不变（默认态走原路径）。
- **改动文件**：`PositionPlaySolverModels.swift`（`beyondCushionBudget`）、`PositionPlaySolver.swift`（`maxCushions` + `applyCushionBudget` + refine 锁轴）、`SiluTrainerViewModel.swift`（两开关 + `searchParams(for:)` + 进阶标注）、`SiluTrainerView.swift`（菜单两开关 + 子标题进阶）、`PositionPlaySolverTests.swift`（禁塞/预算优先/兜底三用例）。

### B0 — 反解求解器性能基线（2026-07-08，Test Engineer，方案：docs/research/20260708-反解求解器性能优化方案.md）

> 优化批次 B0（一切优化的前置）：四条路径独立墙钟 benchmark + 分段计时 + Instruments 占比确认。

- **新增** `QiuJiTests/SolverPerformanceTests.swift`（4 用例，断言只防卡死 <120s，非性能闸门）：
  - 情形 A 落区 `.standard` 带/不带精修、情形 B 过点 `.passThrough`、斯诺克 `solveSnooker .standard`（**此前无基线，本轮补**，盘面取 SnookerSolverTests 金标准球形）、批量出片等价盘面（8 球 + 落区，`BatchShotSolver.searchParams` 同参数）。
- **插桩**（DEBUG-only，Release 零开销）：`PerformanceProfiler` 新增 `recordSample`/`measureSample`（并发安全采样——旧 `begin`/`end` 共享挂起时刻，`concurrentPerform` 下互相覆盖不可用）+ `reportText()`；标签 `Solver.aimMemoization`/`Solver.candidateEval`/`Solver.refine`/`Solver.passInfo`/`Predictor.runShot`/`Predictor.postProcess`/`Predictor.simulateFree.engine`，插桩点：`PositionPlaySolver.candidateMatrix` ①② 段、`refined()`、`passInfo` 调用处；`ShotPredictor.runShot` 引擎段、`buildPrediction`/`simulateFree` 后处理段。
- **基线（模拟器 iPhone 17 Pro，4/4 TEST SUCCEEDED 真实输出）**：
  - 情形 A：**1.64s 无精修 / 2.28s 带精修**（1572/2436 次 runShot；分段：瞄准记忆化 0.40s、候选评估 1.30s、精修 0.58s、后处理 CPU 0.35s）。
  - 情形 B：**1.98s**（2174 次；瞄准记忆化 0.75s、候选评估 1.01s、passInfo 0.06s）。
  - 斯诺克：**36.56s**（3780 次全场 simulateFree，引擎段 CPU 356.6s、均值 94.3ms/次）——原推算 2.5–5s 严重低估。
  - 批量盘面（8 球）：**7.42s**（2100 次，单次均值 30.4ms ≈ 两球盘面 4×）。
- **Instruments Time Profiler（xctrace 附着 + time-profile 表导出聚合，两轮）**：引擎 simulate 内核占 CPU 样本 **97.3%（情形 A/B/批量窗口）/ 97.5%（斯诺克窗口）**，后处理 polyline/回放采样 2.0–2.3%，求解器装配 <0.1% ⇒ 优化主战场 = 减少模拟次数 / 降低单次模拟成本（与方案 §2 分层管线一致）。
- **真机基线未测**（诚实标注）：Mac 无可用真机连接（devicectl 列表仅 unavailable 项）⇒ 登记 `HUMAN-REQUIRED.md` H-20（非阻塞，B5 收尾补）。
- **改动文件**：`QiuJiTests/SolverPerformanceTests.swift`（新）、`QiuJi/Core/Physics/PerformanceProfiler.swift`、`QiuJi/Core/Physics/ShotPredictor.swift`（仅 DEBUG 插桩）、`QiuJi/Core/PositionPlay/PositionPlaySolver.swift`（仅插桩）、方案文件 §1 基线表回写。

### B1 — 打分与出片分离 + 引擎早停（2026-07-08，iOS Architect + Test Engineer，方案 §3 B1）

> 低风险热身批次：搜索候选 scoring-only + 三种早停/剪枝，物理与判定逐位不变；上屏代表解全保真重建。

- **scoring-only 分离**：`buildPrediction`/`simulateFree` 增 `includePresentation:Bool=true`——`false` 时跳过 polyline 120Hz 采样、共线简化、`extraBallPaths`、分离角/切线，只留求解器消费量（进袋/吃库/末位/末速/事件流/recorder）；`predictForPositionSolve` 透传并顺带把实际瞄准写入新增字段 `ShotPrediction.aimOffsetUsed`。
- **代表解全保真重建（画面=物理终验，比基线更严格）**：`PositionPlaySolver.finalizeCandidate`（情形 A 三条装配路径 + 情形 B 代表解）用候选的 `aimOffsetUsed` 以默认参数重跑完整 prediction；斯诺克 `finalizeSnooker` 用 `prediction.aimDirection` 同理。同物理同判定，只补展示量。
- **引擎早停两种**（`EventDrivenEngine.simulate` 新参数，展示用模拟保持 nil）：
  - `earlyStopBallNames`：兴趣球全部落袋/停稳（stationary/spinning），且其余运动球按**能量上界行程**（v²/2+R²ω²/5 → E/(μ_roll·g)，含链式接力松弛 = 球数·2R）不可能触及任何兴趣球 ⇒ 提前结束。保守判据 ⇒ 兴趣球终态逐位不变。
  - `stopAfterContactBetween`：**瞄准评分专用**——两具名球首次碰撞解算并记帧后立即截断。评分只消费「碰前事件 + 目标球碰后首帧方向 +（未碰时）cueGhostMinDist」⇒ 评分值与整程逐位一致。接入 `positionAimOffset`（黄金分割内层）：情形 A 瞄准记忆化 404ms→50ms、情形 B 805ms→97ms。
- **passInfo 事件段扫描**：替换 dt=0.01 全程回放采样——按母球事件帧段扫描，滚动/静止段解析演进为直线 ⇒ 弦线段-点距离即精确下界；滑动段可能带塞弯曲 ⇒ 减 aT²/8（a=10 保守）曲率松弛；只有下界 < min(bestDist, tol) 的段才做段内 dt=0.01 局部加密。
- **精修邻居瞄准复用**：±spinY 邻居直接复用种子 `aimOffsetUsed`（squirt 只随 spinX，与主网格记忆化同一物理事实；漏进重解护栏兜底）；±spinX/±velocity 邻居以种子为中心 ±2° 窄括号热启动黄金分割。精修段 505ms→327ms。
- **实测（`SolverPerformanceTests` 复测，真实输出）**：情形 A 无精修 1.64→**1.24s**（−24%）、带精修 2.28→**1.56s**（**−32%，达标 ≥30%**）、情形 B 1.98→**1.17s**（−41%）、批量 8 球盘面 7.42→**4.90s**（−34%）、斯诺克 36.56→36.46s（~0%，预期内——postProcess CPU 8.4s→0.3s 但引擎段占绝对主导，候选主体收益在 B4）。解数逐条持平（3/6/8/2）。
- **验证（真实输出）**：`PositionPlaySolverTests` 13/13 ✅ + `SnookerSolverTests` 4/4 ✅ + `PhysicsBenchmarkTests` ✅ + `PhysicsInvariantTests` ✅；新增 `QiuJiTests/ScoringOnlyConsistencyTests` 2/2 ✅——多球盘面 54 组 scoring-only vs 全保真、斯诺克 20 组早停 vs 整程，aimOffset/进袋/吃库/末速/兴趣球终位/首触**逐条一致**（Float 1e-5 容差）。
- **改动文件**：`EventDrivenEngine.swift`（两种早停）、`ShotPredictor.swift`（scoring-only + aimOffsetUsed + stopAfterContact + 窄括号 positionAimOffset）、`PositionPlaySolver.swift`（predictScoring/finalizeCandidate/finalizeSnooker + passInfo 段扫描 + 精修瞄准复用）、`QiuJiTests/ScoringOnlyConsistencyTests.swift`（新，pbxproj 注册）、方案文件 §3 B1 回写。

### B2 — 解析瞄准层（2026-07-08，iOS Architect + Test Engineer，方案 §3 B2）

> 反解轻量瞄准的评分函数从「引擎短模拟」换成「闭式解析推演」——引擎组件全部复用零重写；
> 对拍验证先行（改线上路径前先证物理保真），旧路径保留可回退，上屏解全保真终验不动。

- **解析模型** `QiuJi/Core/Physics/AnalyticAimModel.swift`（`AnalyticAim.outcome`）：给定 (aimDir, velocity, spinX/Y, elevation) 推演到首次母-目碰撞并返回目标球碰后方向。忠实性契约（逐组件复用）：
  - 击杆含 squirt：`CueBallStrike.executeStrike`（与 `runShot` 同一调用）。
  - 弹道 = 至多「滑动→滚动」两段**常加速度段**（滑动段 û 恒定是闭式解成立前提，与引擎事件间演进同一 `AnalyticalMotion` 公式；swerve 自然包含）。段长 = `slideToRollTime`/`rollToSpinTime`。
  - 段内首事件检测与引擎 `findNextEvent` 同一批求根器：球-球四次方程（+ 引擎同款 quartic 漏检离散回退）、直线库二次方程 + 有限段过滤、jaw 圆弧四次方程、袋口 XZ 四次方程。先解目标球再以 `min(horizon, tTarget)` 收窄其余检测窗 + 可达半径粗筛（`|v|t+½|a|t²` 上界，保守只省计算）。
  - 碰撞解算：`EngineNumerics.makeBallBallKiss` + `CollisionResolver.resolveBallBallPure`（与引擎 `resolveBallBallCollision` 同序同参，collision throw 同源）。
- **评分接线**（`ShotPredictor.swift`）：`positionAimScore`（模拟口径）/`positionAimScoreAnalytic`（解析口径）抽成对等函数；`positionAimOffset` 经编译期开关 `useAnalyticPositionAim = true` 走解析评分，搜索器仍黄金分割同括号同容差（对拍偏差 ⇒ 纯物理保真差）；旧路径保留为 `positionAimOffsetSimulated`（回退 = 开关改 false 重编译；不用可变全局避免 `concurrentPerform` 数据竞态）。
- **第 0 层几何早筛** `AnalyticAim.straightFanBlocked`：障碍球到「母球→幽灵球」基线的垂距 + 沿线投影，判「即使把瞄准偏到扇区边缘（±12°）也让不开」⇒ 整轮一维搜索直接跳过（返回 center，下游全保真终验语义不变）。判据保守（swerve 5mm 余量），宁可漏筛不误杀。
- **对拍验证（先行，`QiuJiTests/AnalyticAimParityTests.swift` 2/2，种子化可复现）**：
  - 评分层（25 随机盘面 × 11 offset 网格 = 275 点，131 点双方有效）：有效性判定不一致 **0**；角误差偏差 P50 **0.000°**、P95 **0.013°**、max **0.053°**（唯一略超 0.05° 案例：近库 4 障碍盘面 off=4°，评分差 0.0009 rad，无害）。
  - 求解层（40 随机盘面全幅力度/塞）：Δoffset P50/P95/max 全 **0.000°**；丢解 **0**；「模拟评分交叉裁判」真失真 **0**。
  - **归因记录（唯一一次红灯 → 根因修复）**：首轮 1 例慢速长台丢解（offAna 漂到 +12° 括号边缘）。根因 = 解析层对「碰前吃库」支返回恒值 100（模拟只对「吃库后仍击中目标球」给恒值，「吃库后打不中」给 100+ghost 距离梯度；解析不追库后路径无法区分）⇒ 两侧无效高原全平，黄金分割在平地漂移。修复 = 解析无效支统一叠加 `cueGhostMinDist` 梯度（同判无效 >99 且保住回谷梯度）。修复后求解层零偏差。
- **实测（`SolverPerformanceTests` 复测，真实输出）**：瞄准记忆化段——情形 A 50→**7.6ms**（−85%；vs B0 基线 404ms **−98%**，完成标准 ≥70% 达标）、情形 B 97→**14.6ms**（−85%）、批量 8 球盘面 **9.9ms**。墙钟：情形 A 带精修 1.56→1.48s、情形 B 1.17→1.08s、批量 4.90→4.75s、斯诺克 ~39s 持平（预期内：B1 后瞄准段占比已小，候选评估主体是 B3/B4 的战场；本批的单球解析 rollout 组件是 B3 地基）。解数逐条持平（3/6/8/2）。
- **验证（真实输出）**：金标准全绿——`PositionPlaySolverTests` 13/13 + `SnookerSolverTests` 4/4 + `PhysicsBenchmarkTests` 14/14 + `PhysicsInvariantTests` 12/12 + `ScoringOnlyConsistencyTests` 2/2 + `AnalyticAimParityTests` 2/2（TEST SUCCEEDED）。每个上屏解仍经第 3 层全保真终验（B1 `finalizeCandidate`/`finalizeSnooker` 链路零改动）。
- **改动文件**：`QiuJi/Core/Physics/AnalyticAimModel.swift`（新）、`ShotPredictor.swift`（评分函数抽出 + 解析接线 + 早筛入口 + 开关）、`QiuJiTests/AnalyticAimParityTests.swift`（新）、pbxproj 注册 ×2、方案文件 §3 B2 回写。

### ADR-P13-02 — 解析瞄准层替换反解轻量瞄准的评分内核（B2）

- **日期**：2026-07-08
- **状态**：✅ 已采纳。命中 ADR 触发：**替换求解架构**（`positionAimOffset` 评分内核从引擎短模拟换为闭式解析推演）。
- **背景**：B0 定位反解耗时 97%+ 在引擎 `simulate`；瞄准记忆化每次黄金分割需 ~15 次短模拟（B1 截断后仍 3–7ms/次）。方案 §2 分层管线要求第 1 层「解析瞄准」脱离事件循环。
- **决策**：
  1. **复用而非重写**：解析层的击杆/弹道/CCD 求根/碰撞解算全部直接调用引擎自己的组件（`CueBallStrike`/`AnalyticalMotion`/`CollisionDetector`/`EngineNumerics`/`CollisionResolver`），物理常数零复制。物理模型只有一份，引擎升级解析层自动跟随。
  2. **对拍先行**：改线上路径前先落 `AnalyticAimParityTests`（评分逐点 + 求解结果 + 模拟评分交叉裁判三重口径），偏差 >0.05° 逐案归因。
  3. **保留回退**：旧模拟评分路径 `positionAimOffsetSimulated` + 编译期开关 `useAnalyticPositionAim`（编译期常量而非运行时可变全局——`candidateMatrix` 在 `concurrentPerform` 里调用，可变全局有数据竞态）。
  4. **搜索器不换（偏离方案的「牛顿/割线」提法，理由记录在案）**：解析评分下黄金分割 ~15 次评估 <1ms，已远低于该段占比阈值；换牛顿/割线会让对拍偏差混入「搜索方法差」，归因不再纯净；且无效高原（未命中/障碍）对导数法需要额外括号保护，复杂度收益比为负。若 B3 需要更快内层可再议。
  5. **语义边界（已知差异，写进模型头注）**：解析层不追「碰前吃库后的库后路径」——该支与「未命中」统一映射为 `100 + ghost 距离`（模拟对「吃库后仍击中」给恒值 100）。两者同判无效（>99），带梯度版本反而修复了恒值平台上黄金分割漂移的丢解案例（对拍归因 #24）。**上屏语义零变化**：解析层只服务搜索排序，每个代表解仍经全保真模拟终验。
- **后果**：瞄准记忆化段 −85%（vs B0 −98%）；B3 获得现成的「单球解析 rollout + 段内事件检测」组件（停点曲线求根直接建立在 `AnalyticAim` 的两段常加速度推演上）；维护面增加一处「引擎语义变更需同步检查解析层假设」的耦合点（缓解：对拍测试常驻金标准回归，引擎改动会立刻红灯）。

### B3 — 单球解析 rollout 替换扫描层引擎模拟 + 速度曲线求精（2026-07-08，iOS Architect + Test Engineer，方案 §3 B3）

> 走位反解扫描层（情形 A 落区/落点 + 情形 B 过点）的每格引擎全模拟换成单球解析 rollout 快评，
> 覆盖不了的格子如实回退引擎；Hooke-Jeeves 精修删除，换为拓扑锁定的速度曲线求精；
> 每桶代表解新增引擎复核物化——扫描加速，上屏判定与数值全部引擎口径（比基线更严格）。

- **单球 rollout** `QiuJi/Core/Physics/AnalyticShotRollout.swift`：碰后母球/目标球各自「常加速度段 + 库边反弹 + 落袋 + 状态迁移」闭式推演至停稳/落袋/撞球/超限——引擎事件循环在单球下的特化，组件全复用（`AnalyticalMotion` 闭式解 / `CollisionDetector` 同批求根器 / `AnalyticAim.ballPocketTime`、`ballBallTime` / 事件并列 tie-break 同引擎优先级）。
  - **库边解算单一真源**：`EventDrivenEngine.resolveBallCushionCollision` 的完整编排（分段恢复系数选择 / 只推不拉护栏 / make-kiss 贴合 / Han 纯解算 / 状态机更新）原样抽出为 `EngineNumerics.resolveCushionImpact`，引擎与 rollout 同吃这一份（方案红线 2 零平行物理）。
  - **忠实性契约（升级全模拟边界）**：撞任何静止球（级联）、kiss 风险（碰后两球先分离后再逼近 1mm 接触带的保守采样检测，误报只损性能不损正确性）、碰前吃库/未命中、超时/超吃库截断——一律 `needsFullSim` 如实上报，绝不猜测。
- **扫描层接线**（`PositionPlaySolver.swift`）：`candidateMatrix` → `scanMatrix`（结构/瞄准记忆化/漏进重解护栏逐位同语义，每格 rollout 快评，`needsFullSim` 格并行段内就地引擎回退）；情形 A `upgradeOnCueBallHit=true`（母球碰后撞第三球=级联⇒引擎），情形 B `=false`（撞球是 K 球语义）。
- **情形 B 解析过点查询** `passInfoFast`：对 rollout 闭式段做引擎版 `passInfo` 同款「弦距下界剪枝 + 段内 dt=0.01 局部加密」（滑动段同一 aT²/8 曲率松弛）；**歧义三态**——过点=快评结论、未过点且母球完整走到停稳/落袋=快评结论、撞球/截断处中止且未过点=`.ambiguous` 回退引擎裁决（级联后仍可能过点，宁可多跑一次引擎不可漏解）。
- **精修换代**：删除 Hooke-Jeeves `refineCandidate`（含 `SearchParams` 四个步长参数）；新 `polishVelocityCurve`——固定塞、种子速度 ±半格括号内两轮 9 点确定性密采（快评打分 + 引擎格回退），只接受「同吃库桶 + 进袋 + 真停稳」样本（拓扑锁定语义与旧精修一致）。`test_refine_notWorse_andDeterministic` **零改动通过**（不劣 + 锁拓扑 + 确定性原语义成立，无需改写）。
- **代表解引擎复核物化** `materializeRegion`/`settle`：每桶按偏好保留前 3 候选，代表解（含求精点）经引擎 scoring-only 复核——进袋/停稳/signed/吃库桶不符自动试备选，桶漂移不迁桶（桶语义以引擎为准）⇒ 上屏数值全部引擎口径 + `finalizeCandidate` 全保真重建链路不动（第 3 层终验，B1 起未变）。
- **对拍**（新增 `QiuJiTests/AnalyticRolloutParityTests.swift`，120 随机盘面 vs `predictForPositionSolve`）：进袋不一致 **0**/96 有效、停稳不一致 ≤1、吃库桶不一致 ≤2（均引擎复核兜底消化）；停点偏差**按吃库分层归因**——0–1 库 P95 **<0.5mm**（模型保真）、2–3 库 P95 <1.2cm、≥4 库大偏差为**混沌放大**（多库敏感依赖，非系统性模型差；margin 递增门槛天然抑制此类解 + 代表解引擎复核双保险）。
- **解质量对比落档（基线 worktree 同盘面逐解 dump）**：A 落点 5 桶、B 过点 6 解、批量 2 桶 margin **至 1e-4 逐条一致**；A 落区 1/2 库桶一致（0.6851/0.3433），0 库代表 0.758（低杆右塞）→0.688（**中心球**）——新求精锁塞轴，代表更贴「越少加塞越好」产品偏好，不劣。
- **实测（`SolverPerformanceTests` 复测，真实输出）**：情形 A 无精修 0.12s / 带精修 **0.15s**（B2 后 1.48s，vs B0 2.28s **−93%**，完成标准 ≤300ms 达标）、情形 B **0.13s**（vs B0 1.98s −93%，达标）、批量 8 球盘面 **0.48s**（vs B0 7.42s −94%）、斯诺克 36.68s 持平（预期内，B4 战场）。
- **验证（真实输出）**：金标准全绿——`PositionPlaySolverTests` 13/13 + `SnookerSolverTests` 4/4 + `PhysicsBenchmarkTests` + `PhysicsInvariantTests` + `ScoringOnlyConsistencyTests` + `AnalyticAimParityTests` + `AnalyticRolloutParityTests`（TEST SUCCEEDED）；解数逐条持平（3/6/8/2）。
- **改动文件**：`AnalyticShotRollout.swift`（新）、`AnalyticAimModel.swift`（Outcome 增碰后状态/路径段收集 + 求根器共享化）、`EngineNumerics.swift`（`resolveCushionImpact` 抽出）、`EventDrivenEngine.swift`（库边解算改调共享函数）、`PositionPlaySolver.swift`（scanMatrix/passInfoFast/polishVelocityCurve/materializeRegion，删 refineCandidate 与 candidateMatrix）、`AnalyticRolloutParityTests.swift`（新）、pbxproj 注册、方案文件 §3 B3 回写。

### ADR-P13-03 — 扫描层单球解析 rollout + 代表解引擎复核（B3）

- **日期**：2026-07-08
- **状态**：✅ 已采纳。命中 ADR 触发：**替换求解架构**（扫描层评估内核从引擎全模拟换为单球解析 rollout，精修从 Hooke-Jeeves 模式搜索换为速度曲线求精）。
- **背景**：B2 后候选评估段仍占情形 A/B 墙钟 ~90%（每格一次引擎全模拟 3–8ms × 数百格）。方案 §2 第 2 层要求母球走位段走单球解析推演、多球情形升级全模拟。
- **决策**：
  1. **单球 rollout 复用引擎组件**（同 ADR-P13-02 原则）：弹道/CCD/库边/袋口/状态迁移全部同源；库边完整解算专门抽 `EngineNumerics.resolveCushionImpact` 使引擎与 rollout 物理只有一份。
  2. **忠实性契约优先于覆盖率**：rollout 只声称覆盖「除自身外全场静止」的情形；级联/kiss/碰前吃库/截断一律如实 `needsFullSim` 回退引擎——快评只加速，判定不降级。kiss 检测取保守侧（误报仅损性能）。
  3. **代表解引擎复核**（比方案要求更严）：扫描层允许近似 ⇒ 每桶代表解上屏前经引擎 scoring-only 复核（signed/吃库/进袋/停稳），不符自动试桶内备选；数值全为引擎口径，再经既有全保真终验。对 D-D2「双景观错位」的完整回应。
  4. **速度曲线求精替换 Hooke-Jeeves**：旧精修沿塞轴探索会引入「更深但更多塞」的代表，与「越少加塞越好」的产品排序偏好相拄；新求精锁塞、只在速度维两轮 9 点确定性密采（拓扑锁定语义保留）。`test_refine_notWorse_andDeterministic` 零改动通过。
  5. **多库停点混沌放大如实落档不掩盖**：≥4 库停点偏差可达分米级（敏感依赖），归因为混沌而非模型差（0–1 库 P95 <0.5mm 佐证）；不调阈值假装一致，靠 margin 递增门槛 + 引擎复核双保险兜底。
- **后果**：情形 A/B 墙钟 −93%（2.28→0.15s / 1.98→0.13s），批量 −94%；扫描吞吐提升为 B5 批量出片直接收益；新增耦合点「引擎事件语义变更需同步 rollout」（缓解：`AnalyticRolloutParityTests` 常驻回归）；斯诺克路径未受益（自由瞄准无解析瞄准层可用，B4 处理）。

### B4 — 斯诺克分层搜索（2026-07-08，iOS Architect + Test Engineer，方案 §3 B4）

> 斯诺克反解的 3780 次全场 `simulateFree` 换成「全网格 rollout 快评 + 歧义格粗细两阶段引擎评估 +
> 代表解引擎全保真复核」三层：**36.56s（B0）→ 7.0–7.2s（−80%，第一阶段 ≥60% 达标）**，解数 8 持平。

- **自由球快评** `AnalyticShotRollout.evaluateFreeShot`（B4）：击杆（squirt 同源）→ 母球单球 rollout 至首触/停稳/落袋 → make-kiss + Han 解算 → 母球与被撞球各自 rollout → kiss 检测。与斯诺克硬约束消费面对齐：首触球名、母球停位/进袋、被撞球停位/进袋、全程吃库数。级联（任一球撞第三球）/kiss/截断如实 `needsFullSim`。
- **三层搜索**（`solveSnooker`）：
  1. 全网格（21 aim × 15 塞 × 12 力度）rollout 快评并行扫描——65% 格（2470/3780）就地下结论：合法格产出覆盖余量（blocker 未扰动 ⇒ 终位 = 初始位），空杆/首触非目标/进袋/未停稳 = 必败格直接排除。
  2. 歧义格（级联 1065 + kiss 245）粗细两阶段引擎评估：aim 步 3 × vel 步 2 粗网格（scoring-only + 三兴趣球早停，B1 语义保留）→ 可行粗格邻域（aim±2 × vel±1，同塞行）加密至全分辨率，必败区域整片跳过。级联解（目标球二次撞 blocker 后的停位构型）只能引擎裁决——这正是斯诺克与情形 A/B 的本质差异。
  3. 代表解引擎复核落地 `settle`：每桶按覆盖余量前 3 备选，依次**全保真**重建 + `evaluateSnooker` 重验（硬约束/覆盖/吃库桶），不符试备选——上屏数值全引擎口径（基线是 scoring 数值直接上屏 + 仅展示重建，本轮更严格）。降级解同机制（前 8 备选，全败如实返回空）。
- **实测**：全场模拟 3780 → **526 次**（−86%）、墙钟 36.56 → **7.0–7.2s（−80%）**。**≤500ms 未达（如实记录）**：剩余 526 次级联格全场模拟均值 ~113ms（引擎 CPU 占 96%）；斯诺克解族本质依赖多球级联，单球 rollout 声称不了。进一步方向（B5 复评收益/风险）：rollout 穿透级联（递归多球解析）或降全场模拟均次成本。
- **解质量对比（基线 worktree 同盘面逐解 dump）**：金标准形 8 桶 margin **全部逐位一致**（含 finalize 链路）；降级形 3/4/5 库桶一致，2 库桶代表 21.7°→12.5°（基线该格为级联歧义格且落在粗细采样之外——分层搜索已知折衷，仍为合法完全斯诺克解）。
- **一次打回记录（诚实交付）**：曾试将 `simulateFree` scoring-only 的 `highFidelityBounds` 关掉换性能（近库自适应子步以为纯展示量），被 `ScoringOnlyConsistencyTests` 打回——多球盘面切步序列改变 evolve 浮点轨迹（停位差 >1e-5，个别高速格改变碰撞拓扑）。已还原为恒 `true` 并在代码注释落档。
- **验证（真实输出）**：`SnookerSolverTests` 4/4 + 金标准全绿（`PositionPlaySolverTests` 13/13 + `PhysicsBenchmarkTests` + `PhysicsInvariantTests` + `ScoringOnlyConsistencyTests` + `AnalyticAimParityTests` + `AnalyticRolloutParityTests`）；四条 benchmark 复测：情形 A 0.15s / 情形 B 0.12s / 批量 0.47s / 斯诺克 7.2s。
- **改动文件**：`AnalyticShotRollout.swift`（`FreeShotOutcome`/`evaluateFreeShot`）、`PositionPlaySolver.swift`（solveSnooker 三层搜索 + settle 复核，删 `finalizeSnooker`）、`ShotPredictor.swift`（`simulateFree` 保真语义注释落档）、方案文件 §3 B4 回写。

### ADR-P13-04 — 斯诺克分层搜索：rollout 快评 + 歧义格粗细两阶段（B4）

- **日期**：2026-07-08
- **状态**：✅ 已采纳。命中 ADR 触发：**替换求解架构**（斯诺克候选评估从全网格引擎模拟换为三层分层搜索）。
- **背景**：B0 实测斯诺克 36.56s（3780 次全场 simulateFree，均值 94ms），B1–B3 对其无效（候选主体不走瞄准层/走位扫描）。
- **决策**：
  1. **快评优先于几何早筛**：方案原列「合法首触张角 / blocker 视线几何早筛」——单球 rollout 快评本身就是**更强的早筛**（不仅判首触合法性，还直接给出停位覆盖判定），几何早筛被吸收，无需单独实现。
  2. **歧义格不硬闯**：级联/kiss 格的物理只能引擎裁决（红线 2 禁止平行多球物理）；用粗细两阶段控制引擎调用量（−86%），漏窄可行带的风险由金标准回归 + 降级形解质量对比护栏。
  3. **代表解引擎全保真复核**（对齐 B3 `materializeRegion` 语义）：快评/scoring 数值不直接上屏，settle 全模拟重验后才落地，失败试桶内备选。
  4. **性能目标如实降级**：≤500ms 不达（级联格全场模拟不可省），第一阶段 ≥60% 达标（实测 −80%）；差距与原因落档，穿透级联的递归解析留 B5 复评。
- **后果**：斯诺克 36.56→7.2s；`evaluateFreeShot` 组件可复用于任何自由球反解（未来安全球变体）；新增采样折衷——歧义区域内基线可见的个别代表解可能被粗细网格跳过（降级形 2 库桶 21.7°→12.5° 实例已落档）。

### B5 — 收尾：批量出片回归 + 文档回写（2026-07-08，Test Engineer + QA Reviewer，方案 §3 B5；真机项待 H-20）

> B0–B4 收官验收。批量出片全流程回归**基线对拍逐字节一致**；文档终值回写完成；真机 benchmark 因设备
> unavailable 如实挂 H-20（唯一遗留项，非阻塞）。

- **批量出片全流程回归**：新增 `QiuJiTests/BatchSequenceReplayRegressionTests`——重放 `content/position_play/sequences/` 全部 **91 条 drill 序列 / 171 杆**（62 个 drill 的成品出片内容），逐杆走「保存后重进」同一链路（`PositionPlayShotSolver.solve` → `finalPositions`/`pocketedBalls` → after 快照重建，语义与 `PositionPlayViewModel` 重放一致），写确定性 dump（键排序 + 定点格式）。**方法**：HEAD 基线 worktree（7cc294a，即 B1–B4 全部改动之前）与优化后工作树各跑一次，`diff` 两份 dump —— **逐字节一致（IDENTICAL）**，171 杆全部可解且 feasible。结论：B1–B4 对展示物理（出片消费的轨迹/停位/进袋）**零改变**。测试常驻回归网（TEST SUCCEEDED，43s）。
  - 信息项（不断言）：重放 vs **存档** after 有 1 杆结果不一致 + 个别停点漂移（基线 worktree 重放结果与优化后完全相同）——系存档早于 2026-07-06 `pocketNoseRestitution` 0.60→0.70 修订的既有漂移，与本轮优化无关，出片时以重放物理为准。
- **穿透级联复评（B4 遗留决定）**：**暂不做**。递归解析多球级联 = 在解析层重建引擎事件循环（红线 2 禁止平行物理的边界情形），对拍/维护成本远超收益（仅斯诺克 7.2→~0.5s，低频功能）；若未来需要，优先做「级联格降均次成本」（更激进早停 + 兴趣球裁剪）。
- **文档回写**：方案文件 §1 终值表（A 0.15s / B 0.12s / 批量 0.47s / 斯诺克 7.2s + 达标标注）+ §3 B5 完成情况；`PHYSICS-DEBT.md` §5.9（D-D1 🟡→🟢◑ 主体偿还、D-D2 分级以「搜索 scoring-only + 终验全保真」形式落地 + `highFidelityBounds` 护栏结论）；H-20 状态注记；PROGRESS + Hub 状态卡。
- **真机 benchmark（⏳ H-20）**：`xcrun devicectl list devices` 实测 iPhone 状态 unavailable，无法跑真机——不编造数字，完成标准「真机 A/B <0.5s、斯诺克 <1s」留待设备连接后按 H-20 步骤补测（15 分钟）。
- **改动文件**：`QiuJiTests/BatchSequenceReplayRegressionTests.swift`（新增）、`QiuJi.xcodeproj/project.pbxproj`、方案文件、`tasks/qa-reports/PHYSICS-DEBT.md`、`tasks/HUMAN-REQUIRED.md`、`tasks/PROGRESS.md`、Hub 状态卡。
