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
