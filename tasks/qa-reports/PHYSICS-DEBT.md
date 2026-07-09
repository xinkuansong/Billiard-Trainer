# 物理引擎技术债台账 + 测试覆盖缺口报告

> 角色：iOS Architect + QA Reviewer ｜ 日期：2026-06-05
> 范围：`QiuJi/Core/Physics/`（21 文件 ~6315 行）+ `QiuJiTests/` 物理相关套件
> 性质：**只读审计**（audit-only，本轮不改任何代码）。本文件是债务登记 + 偿还建议，供后续按优先级排期。
> 关联：`tasks/qa-reports/PHYSICS-PROBE.md`（探针绿灯报告）、`tasks/PROGRESS.md`（P10/P11 返工记录）

---

## 0. 基线（钉死当前状态）

| 套件 | 用例数 | 结果 | 耗时 |
|------|-------|------|------|
| `PhysicsEngineTests` | 23 | ✅ 0 失败 | 2.6s |
| `PhysicsBenchmarkTests` | 14 | ✅ 0 失败 | （含在 30s 内） |
| `CushionDiagnosticsTests` | 5 | ✅ 0 失败 | （含在 30s 内） |
| **合计（本次跑测）** | **42** | ✅ **0 失败** | **~30s** |

> 跑测命令：
> ```
> xcodebuild -project QiuJi.xcodeproj -scheme QiuJi \
>   -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
>   -only-testing:QiuJiTests/PhysicsEngineTests \
>   -only-testing:QiuJiTests/PhysicsBenchmarkTests \
>   -only-testing:QiuJiTests/CushionDiagnosticsTests test
> ```
> `ShotScenarioRenderTests`（PNG 接触表）未纳入本次基线，因其以输出图片+扫描为主、断言极少（见 C-2）。

**总体判断**：内核物理（击打/碰撞/库边/走位）忠实移植自 pooltool 且探针绿灯，**可信**。技术债集中在 ①移植期遗留的死代码/重复，②`ShotPredictor` 显示层与物理真值的补丁式耦合，③测试以"事后诊断"为主、缺系统化不变量断言，④标定未用真实数据、几何残留 mismatch，⑤求解性能。

---

## 1. 债务台账

严重度：🔴 高（影响正确性/可维护性，应尽快）｜🟡 中（结构性债，择机偿还）｜🟢 低（清理项）

### A. 架构 / 代码结构

| ID | 严重度 | 标题 | 证据 | 影响 | 建议 |
|----|-------|------|------|------|------|
| **D-A1** | 🟡 ✅ | `EventDrivenEngine.swift` 巨型文件 1713 行 | 单文件含：事件队列+缓存（`PhysicsEventCache`）、主循环 `simulate`、`findNextEvent`、球-球/库边解算、`enforceTableBounds`、`resolvePocket`、`separateOverlappingBalls`、回退检测 `shouldRunFallbackBallBallCheck`/`fallbackBallBallCollisionTime` | 单一文件多职责，单测只能端到端打，改一处牵连全局，回退/分离重叠等"安全网"逻辑与主循环混杂 | **✅ 已拆分（2026-06-06，见 §5.5）**：抽出 `EngineNumerics`（纯数值/运动学，可脱离引擎单测）、`PhysicsEvent`（事件类型+`BallState`）、`EventCache`、`SceneKitBridge` 四个独立文件；`EventDrivenEngine` 由 1539→860 行，仅留事件调度/解算主循环 |
| **D-A2** | 🔴 ✅ | `CushionCollisionModel`（Mathavan 2010，636 行）是生产路径死代码 | `CollisionResolver.resolveCushionCollisionPure` 只调 `Han2005CushionModel.solve`（CollisionResolver.swift:150）；`CushionCollisionModel.solve` 全仓唯一调用点是 `CushionDiagnosticsTests.swift:226` | 636 行无人维护的复杂数值积分代码常驻仓库，误导后人以为在用；与 Han2005 两套库边模型并存制造混淆 | **✅ 已删除（2026-06-05，见 §5.4）**：删 `CushionCollisionModel.swift` + 移除唯一消费它的 print 对照测试 `test_cushion_HanVsMathavan`；Han2005 头注补「Mathavan 已删，需对照查 git」 |
| **D-A3** | 🔴 ◑ | `ShotPredictor` 显示闸门与物理真值耦合，patch-on-patch | ShotPredictor.swift 内 3 处"显示一致性闸门"：母球进袋闸门（L206-219）、目标球进袋闸门（L226-238）、`clampedRecorder` 穿库安全网（L443-545）。注释多处自陈为修 FL-018/FL-019 逐个补的 | 引擎"真值"与画面"显示值"判定不一致，需在门面层反复打补丁对齐；阈值（0.06/0.12/0.14m、0.004、0.07m/s）散落硬编码，脆弱、难推理 | 中期：把"画面=物理"下沉到引擎一处（落袋吸心已是一步），让 `ShotPredictor` 只读结果不再二次裁决；阈值集中为具名常量 |
| **D-A4** | 🟡 ✅ | 几何/常量双真源未完全统一 | `BTPhysicsConstants.TablePhysics` 袋口参数标注 `TODO(step3)` 仍取 CAD（BTPhysicsConstants.swift:9-10,45）；与 `AngleSceneCalculator` 的袋口/几何并存，靠注释声明"完全一致" | 同一物理量两处定义，改一处忘另一处即引入静默偏差；探针历史上的"17mm 双真源"正源于此类 | 收敛为单一真源（`AngleSceneCalculator` 或 `TableGeometry`），另一处改为引用 |
| **D-A5** | 🟢 ✅ | `CollisionResolver.vector4` 未使用的私有函数 | CollisionResolver.swift:231 `private static func vector4` 无调用点 | 死代码 | **✅ 已删除（2026-06-05，见 §5.4）** |

### B. 正确性 / 标定

| ID | 严重度 | 标题 | 证据 | 影响 | 建议 |
|----|-------|------|------|------|------|
| **D-B1** | 🔴 | 物理常量从未用真实数据标定 | `BTPhysicsConstants`：`restitution=0.95`、`cushionRestitution=0.85`、`cushionFriction=0.2`、`clothFriction=0.2` 全为 pooltool 默认值；PROGRESS 多处标注"常量标定需真实俯拍视频" | 轨迹/走位/吃库距离是否贴合真实中式八球台无实测背书，只对齐了"参考 band" | 用俯拍标准球视频拟合 e_b/库边/台呢系数，用 `PhysicsBenchmarkTests` band 钉死（依赖人工拍摄，属 H-item） |
| **D-B2** | 🟡 | 袋口几何残留 mismatch + drop radius 为"凑进球带"调参 | PROGRESS 记中袋 jaw mouth ±0.035 vs 实测 ±0.046；落袋孔半径被调成角 0.070/中 0.075"覆盖开口"，与视觉标记解耦（非几何真值） | 朴素瞄准 E-geom 仅 3-4/5；进球带宽度部分靠调 drop radius 而非真实几何 | 以 USDZ 实测为单一真源重导 jaw+洞心，使 drop radius 回归物理洞口尺寸 |
| **D-B3** | 🟡 | 5 条特殊球路求解器无法处理 | PROGRESS/H-11：c055 翻袋、c057 K球吃库、c058 贴库、c061 解球、c066 开球，单杆直瞄物理打不进 | 这些 Drill 退回手画轨迹或显示"近失"，与"画面=物理"目标不一致 | 求解器增强（翻袋/吃库瞄准）或显式标注为"非直瞄球路"并走专门呈现 |
| **D-B4** | 🟢 ✅ | `solveAimOffset` 评分权重为经验魔数 | ShotPredictor.swift:599-610：`-10` 基线、`0.3`/`0.05` scratch 惩罚、`1e-3` offset 正则；注释自陈历史上 scratch 惩罚用 1.0 会导致差解 | 评分函数行为强依赖手调魔数，回归风险高 | **✅ 已抽常量（2026-06-05，见 §5.4）**：全部权重 + miss 基线 + kick 惩罚（FL-020）抽入 `AimScoring` enum，逐条注明含义/量纲。评分序的行为断言已由矩阵 1/3（进袋合约 + 宏观确定性）覆盖，故未再抽 `score` 为独立纯函数单测 |

### C. 测试

| ID | 严重度 | 标题 | 证据 | 影响 | 建议 |
|----|-------|------|------|------|------|
| **D-C1** | 🔴 | 测试以"事后回归守卫/诊断"为主，缺系统化物理不变量断言 | 用例命名多为 `test_diag_*`/`scan*`/`*_report`；`PhysicsBenchmarkTests.test_D_rollDistance_report` 等是 report 型 | 没有"能量单调不增、动量守恒、不穿库、不重叠、确定性可复现"这类**不变量**护栏；重构时无法靠测试网兜底 | 新增 `PhysicsInvariantTests`：对随机化击球批量断言守恒律与边界不变量 |
| **D-C2** | 🔴 | `ShotScenarioRenderTests`（1103 行）靠肉眼看 PNG，几乎无断言 | 全文件 `print`/`XCTAssert` 合计仅 58 处命中且以 print 为主；产出 `build/shot_probe/*.png` 供人工复盘 | "进球带碎裂/翻袋坏解"等回归只能靠人看图发现，CI 无法守卫 | 把肉眼判据**量化为断言**：进球带连续性、无翻袋坏解（碰后方向误差）、母球不穿库——保留出图但加机器判定 |
| **D-C3** | 🟡 | 确定性未被测试 | 无"同输入两次 predict 输出一致"的测试；引擎用浮点 + 事件优先级排序 + Set 遍历（`framesByBallName` 字典序） | 浮点/容器遍历顺序若引入不确定性，烘焙结果可能漂移而无人察觉 | 加确定性测试：固定输入跑 N 次断言轨迹逐帧一致 |
| **D-C4** | 🟡 | 无性能回归门槛 | predict 150-200ms 仅在 PROGRESS 口头记录，无自动断言 | 后续改动若拖慢求解无 CI 告警 | 加性能基准断言（`measure` 或自定阈值），满台序列求解也纳入 |
| **D-C5** | 🟢 | 物理测试未纳入主回归命令 | `ShotScenarioRenderTests` 慢且少断言，未进基线套件 | 覆盖盲区 | 拆出"快速断言子集"进 CI，"出图诊断子集"手动跑 |

### D. 性能

| ID | 严重度 | 标题 | 证据 | 影响 | 建议 |
|----|-------|------|------|------|------|
| **D-D1** | 🟢 ◑ | 单次 predict 150-200ms；满台序列数百 ms | `solveAimOffset` 粗±12°/0.5°(49)+中(13)+细(13) ≈ 75 次短模拟，每次 500ev/15s（ShotPredictor.swift:626-629, 577-578） | 编辑模式跟手度差；P11 满台求解明显延迟 | **◑ 主体已偿（2026-07-08，见 §5.9）**：反解求解器路径经 B1–B4（scoring-only+早停 / 解析瞄准 / 单球解析 rollout / 斯诺克分层搜索）情形 A/B **−93%**、批量 **−94%**、斯诺克 **−80%**。残留：单杆 `predict` 全保真展示路径本身未动（中位 ~125ms，见 §5.6(3)，编辑跟手已够用）；斯诺克级联格仍需引擎裁决（≤500ms 未达） |
| **D-D2** | 🟢 ◑ | 搜索与最终模拟均 500/15，未分级 | ShotPredictor.swift:577（searchEvents=500/searchTime=15）注释自陈历史上为修"双景观错位"提到与最终同保真 | 搜索阶段保真度过剩 | **◑ 分级已在反解路径落地（2026-07-08，见 §5.9）**：搜索层 scoring-only（跳 polyline/extraBallPaths + 兴趣球早停 + 碰撞截断）+ 解析 rollout，代表解一律引擎**全保真复核后上屏**——即「搜索降成本、终验全保真」的安全分级。注意护栏结论：`highFidelityBounds` 在 scoring-only 中**不可关**（近库自适应子步在多球盘面改变轨迹，非纯展示量，`ScoringOnlyConsistencyTests` 打回一次）。`solveAimOffset` 的 500/15 本身未降（已被解析瞄准层旁路，仅袋口模式 predict 使用） |

---

## 2. 测试覆盖缺口矩阵

| 物理维度 | 现有覆盖 | 类型 | 缺口 |
|---------|---------|------|------|
| 击打 CueBallStrike（squirt/高低杆/中心） | `PhysicsEngineTests` 5 + `Benchmark` A 2 | ✅ 断言 | 仰角 elevation>0、极限塞 miscue 边界已部分覆盖 |
| 球-球 CollisionResolver（90°/throw/传速/守恒） | `PhysicsEngineTests` 2 + `Benchmark` B 3 + `Invariant` 1 | ✅ 断言 | **新增**：80 次随机动量守恒+能量耗散断言；带塞 throw 已在 Scenario 覆盖。残：滑移/无滑移分支切换未针对性测 |
| 库边 Han2005（反弹角/速度保留/带塞变线） | `Benchmark` C 2 + `CushionDiagnostics` + `Scenario` 2 | ✅ 断言/对照 | **新增**：带塞吃库变线 + 连续多库（9 库不出界）已断言 |
| 走位（分离角/跟定缩杆/路程） | `Benchmark` D 4 + `Scenario` 2 | ✅ 断言 | **新增**：跟/定/缩杆落点次序 + 力度→路程单调已断言（不再仅 report）。残：走位终点绝对精度无断言（依赖标定 D-B1） |
| 进袋（求解器/朴素/假阳性/矩阵） | `Benchmark` E 3 + `PhysicsEngine` 多条 + `Scenario` 1（32/32 矩阵） | ✅ 断言 | 翻袋/吃库进袋路线（D-B3）；进球带连续性靠肉眼（D-C2 渲染层未做） |
| 多球障碍 / 组合球（P11） | `PhysicsEngine` 2 + `Scenario` 1 | ✅ 断言 | **新增**：组合球串入二库已断言。残：多目标连续走位链端到端 |
| **不变量（守恒/边界/确定性/减速/收敛）** | `PhysicsInvariantTests` 9 | ✅ 断言 | **已建护栏（2026-06-05，扩面）**：能量/动量/无重叠/不出界/减速/收敛/静止/确定性 |
| **性能门槛** | `PhysicsPerformanceTests` 3 | ✅ 断言 | **已建护栏（2026-06-05）**：单杆≤800ms/满台≤3s + measure 指标 |
| 穿库安全网 clampedRecorder | `CushionDiagnostics.scanForOutOfBounds` + `diag` | ✅ 扫描型 | 钳制逻辑本身（冻结时刻/化妆钳位）无单元测 |

---

## 3. 偿还优先级建议（供排期）

**第一梯队（先建测试网，零行为改动）**
1. D-C1 物理不变量测试 + D-C3 确定性测试 + D-C4 性能门槛 —— 这是后续任何重构的安全网，**最高杠杆**。
2. D-C2 把肉眼判据量化为断言。✅ 已由 `PhysicsMatrixTests`（2054 场景）实质收口（见 §5.3）。

**第二梯队（低风险清理）** ✅ 已完成（2026-06-05，见 §5.4）
3. D-A2 处置 Mathavan 死代码（删除或标注）；D-A5 删 `vector4`。✅ 均删除。
4. D-B4/D-D2 抽魔数为具名常量 + 注释量纲。✅ 抽入 `AimScoring`（D-D2 降保真未做，仅抽常量）。

**第三梯队（结构性重构，需测试网就绪后做）** ✅ 已完成（2026-06-06，见 §5.5）
5. D-A1 拆 `EventDrivenEngine`（✅ 四文件）；D-A3 下沉显示闸门到引擎（◑ 阈值集中为 `DisplayGate`，下沉留后续）；D-A4 收敛几何双真源（✅ 基元单一真源）；引擎遍历确定性化（✅ `ballOrder`，清除 FL-020 遗留根因）。

**第四梯队（依赖人工/外部输入）**
6. D-B1 常量真实标定（需俯拍视频，H-item）；D-B2 USDZ 重导几何；D-B3 特殊球路求解增强。

---

## 4. 结论

- 内核可信、探针绿灯、物理测试全绿。审计当时无阻塞 bug；**测试网扩面后由系统化矩阵抓出并修复一处求解器宏观非确定性 bug（FL-020：直球求解约 40% 概率选到母球绕 4 库的 kick 退化解、运行间随机翻转）**——印证「不变量/矩阵护栏」相对「事后诊断」的价值。
- 最值得投入的不是"再修一个 bug"，而是**把测试从'事后诊断'升级为'不变量护栏'**（D-C1/C2/C3/C4）——这能从根上遏制 P10/P11 那种"改一处崩一处、靠肉眼看图发现"的返工循环。
- 死代码（D-A2 Mathavan 636 行）与显示闸门耦合（D-A3）是两处最明确、ROI 最高的结构债。
- 标定类债（D-B1/B2）依赖真实视频，属人工 backlog，不阻塞上线。

> 本报告原为 audit-only 交付物；§5 起记录已落地的偿还进展（仅新增测试，零生产代码改动）。

---

## 5. 偿还进展（第一梯队 · 测试网）

### 5.1 已落地（2026-06-05；测试网 + 1 处求解器修复 FL-020）

按 §3 第一梯队第 1 项 + 用户两轮「考虑真实台球复杂度，用例量级要到几百上千」+ 第三轮「直球求解必须保证母球碰目标球前不吃库、目标球进袋前不吃库」的扩面要求，新建四套**断言型护栏**，全绿 **22 个 XCTest 方法 / 约 3800+ 个被断言场景**；并由矩阵护栏**抓出并修复一处求解器宏观非确定性 bug（FL-020，见 §5.2）**：

| 套件 | 方法 | 内部场景数 | 覆盖债务 | 性质 |
|------|------|-----------|---------|------|
| `QiuJiTests/PhysicsInvariantTests` | 9 | ~1700 随机 | D-C1 / D-C3 | 属性化随机批量（种子化，每方法跑数百场景） |
| `QiuJiTests/PhysicsScenarioTests` | 7 | ~50 | D-C1 / D-C2 扩面 | 针对性真实球理场景 |
| `QiuJiTests/PhysicsMatrixTests` | 3 | **2054 系统化** | D-C1 / D-C2 / D-C3 大规模 | 确定性组合矩阵，逐例断言 + 失败打印复现参数 |
| `QiuJiTests/PhysicsPerformanceTests` | 3 | — | D-C4 | 性能门槛 + measure 指标 |

> **关键澄清**：「XCTest 方法数」≠「被断言场景数」。反映问题的是后者——本套件合计 **~3800+ 个不同球形/袋口/切角/力度/塞组合**被断言覆盖（属性化随机 ~1700 + 系统化矩阵 2054 + 针对性 ~50）。矩阵失败时打印精确复现 ID（如 `t3p1c40s+v4.2`），可定位到具体哪一格崩——FL-020 正是这样被定位的。

**D-C1/C3 不变量（`PhysicsInvariantTests` 9 项，种子化随机批量 ~1700 场景，可复现 SplitMix64）**：
- 能量耗散单调——250 杆，每帧总动能 ≤ 初始×1.02，**最坏 E/E0=1.0000**。
- 不重叠——200 杆多球，球心距 ≥ 2R−3mm，**最坏穿透 0.00mm**。
- 不出界——150 杆生产钳制轨迹全在可玩区/袋口嘴内，**最坏越界 0mm**（守 FL-018）。
- 自由球减速单调——200 杆中心球首库前速度严格非增，**最坏回升 0.000 m/s**。
- 模拟收敛无失控——150 杆多球终态全部停住/进袋，**最坏终速 0.000 m/s**。
- 球-球碰撞守恒——**600 次**随机切角+随机入射旋转：**线动量误差 0.0000 m/s**、**总动能比 ≤ 0.99**（守恒律硬护栏）。
- 静止球被触碰前不动——150 杆，首个涉及它的碰撞前**最坏漂移 0.00mm**（无幽灵碰撞）。
- 确定性——原始引擎 simulate 两次逐帧位置一致（<1e-5 m）；predict 重复调用位置稳定 <1e-5 m。

**D-C1/C2/C3 系统化组合矩阵（`PhysicsMatrixTests` 3 项，2054 个确定性网格场景，逐例断言 + 失败打印复现 ID）**：
- **矩阵 1 求解器进袋合约**（6 目标 × 6 袋 × 3 切角 × 2 方向 × 2 力度 = 338 可行 predict）：逐例断言「可行 ⇒ 显示轨迹不出界 + 进袋则末端落袋窗内（画面=物理）+ **母球碰目标球前 0 吃库** + **目标球不远处翻袋进**」——**0 出界、0 画面≠物理、0 母球绕库、0 远处翻袋**；进袋率 85%（288/338），目标球吃库进 3 组均为 ≤0.4m 贴库滚进角袋（benign）。**这条「线干净」断言是 FL-020 的发现入口**（修复前母球绕库 3 组）。
- **矩阵 2 裸引擎出射方向**（5×3 目标网格 × 6 袋 × 6 切角 × 力度 = **1716 组**中心球幽灵球直瞄）：逐例断言目标球出射方向沿进球线——**最坏方向误差仅 1.9°**（零翻袋坏解坐实）；同时统计穿库逃逸率 **1.1–1.3%**（优于审计估计 2.7%，回归阈 ≤6%）。
- **矩阵 3 直击非 kick + 宏观确定性**（FL-020 回归）：对历史会翻转的 t3p5/t3p4/t4p4 球形各连跑 20 次，断言母球接触前 0 吃库、进袋 20/20、**分离角运行间跨度 0.00°**。

**D-C1/C2 真实场景（`PhysicsScenarioTests` 7 项，把缺口矩阵里只 print/未覆盖的现象钉成断言）**：
- 跟/定/缩杆母球落点次序：缩杆 −1.030 < 定杆 −0.753 < 跟杆 +0.341（x，m）✓
- 力度→走位路程单调：1.6→5.41 / 2.4→7.29 / 3.3→8.85 / 4.4→10.48 / 5.8→12.52 m ✓
- 加塞改变目标球方向（squirt 移接触点 + throw 复合，仅守定性、幅值标定归 D-B1）✓
- 带塞吃库变线：反弹切向 0.714→0.402（侧旋改变出射）✓
- 连续多库：吃 9 库、最坏越界 0mm、8.46→0 减速 ✓
- 组合球：母球先碰一库、二库被串动 1125mm ✓
- 清晰球进袋矩阵：中心球→两角袋 × 切角 0/15/30/45 × 力度 2.4/3.3/4.4/5.8 = **32/32 进袋** ✓

**D-C4 性能门槛**：单杆 predict 中位 **101ms**（预算 800ms）；满台（母球+8 障碍）中位 **514ms**（预算 3000ms）；Xcode `measure` avg 97ms / RSD 0.66% 作真机基线。预算取宽以容忍 CI 抖动，目标捕获数量级回归。

> 跑测：`-only-testing:QiuJiTests/PhysicsInvariantTests -only-testing:QiuJiTests/PhysicsScenarioTests -only-testing:QiuJiTests/PhysicsMatrixTests -only-testing:QiuJiTests/PhysicsPerformanceTests`（合并 22 方法 / ~3800 场景，约 53s）

### 5.2 测试期间抓出并修复的真 bug — FL-020 求解器宏观非确定性

> **修正既往判断**：上一轮把 predict 的非确定性记为「~1e-4° 分离角微抖动、无害、不阻塞」。用户追加体检「直球应保证母球碰目标球前不吃库」后，矩阵 1 的「线干净」断言把它撕开成了**宏观 bug**——那只是冰山一角。

- **现象**：矩阵 1 逐例查「进袋解里母球碰目标球前的吃库数」，发现 3/285 例母球先吃了 **4 次库**。聚焦复现 `t3p5c10s+v2.8`：**同一精确输入连跑 30 次，`cueCushionsBeforeContact` 在 0（18 次）/4（12 次）间随机翻转，进袋 28/30（2 次打丢），分离角取 80.66°/82.23°/83.25° 三值**。即对该球形求解器约 40% 概率选「母球绕 4 库再歪打正着碰目标球」的 **kick 退化解**，运行间随机。
- **根因**：`solveAimOffset` 最优区（−10，压过一切方向解）只要求「目标球直接进袋 + 0 吃库」，**漏了母球接触前 0 吃库**。±12° 搜索偶捞到「打丢→绕库→歪打正着进袋」的 kick 解，与真直击解评分**并列**；并列 + 引擎 `Dictionary`/`Set` 事件遍历浮点求和顺序非确定性 → argmin 在两个**完全不同**的解间运行间翻转。**1e-4° 微抖动其实是这个并列的尾巴**，不是独立的无害现象。
- **修复**：① `RunResult`/`ShotPrediction` 新增权威字段 `cueCushionsBeforeContact`；② 最优区条件追加 `&& cueCushionsBeforeContact == 0`，钉死直击解唯一占 −10；③ 方向解支加 `cueCushionsBeforeContact * 0.3` 轻惩罚。
- **修复后**：矩阵 3 对 t3p5/t3p4/t4p4 各 20 次重跑 → cuePreBank max=0、进袋 20/20、**分离角跨度 0.00°**（连微抖动一并消除，因不再有评分并列的解可跳）；矩阵 1 进袋率维持 85%、母球绕库 0、远处翻袋 0；`PhysicsEngineTests` 23/23、Invariant 9/9、Scenario 7/7、`DrillShotReconstructionTests` 2/2 全过、lint 0。
- **遗留**：引擎 `Dictionary`/`Set` 无序遍历本身仍在（D-A 第三梯队），但**已无评分并列的不同解供其翻转**，故宏观确定性已恢复；将遍历改确定性有序容器仍建议做（彻底消除任何残留浮点路径差），不阻塞。

### 5.3 第一梯队剩余

- **D-C2 已实质收口**：核心三判据（无翻袋坏解 / 进球带方向连续 / 母球轨迹不穿库）已由 `PhysicsMatrixTests` 在 **2054 个系统化网格场景**上转为机器断言（矩阵 2 最坏方向误差 1.9°=零翻袋坏解；矩阵 1 零出界=不穿库 + 画面=物理）。
- **残留**：`ShotScenarioRenderTests`（1103 行）的 **PNG 出图诊断**仍保留肉眼用途（人工复核渲染对位），但其判定职责已被矩阵断言取代——无需再把出图判据逐条机器化。第一梯队至此完成。

### 5.4 第二梯队 · 低风险清理（2026-06-05）

有第一梯队测试网（22 方法 / ~3800 场景）兜底，安全执行 §3 第二梯队：

- **D-A2 ✅ 删除 Mathavan 死代码**：删 `QiuJi/Core/Physics/CushionCollisionModel.swift`（636 行 Mathavan 2010 冲量积分，生产路径只用 `Han2005CushionModel`）；其全仓唯一调用点是 `CushionDiagnosticsTests.test_cushion_HanVsMathavan`（纯 print 对照、零断言），一并移除（顺带删该测试类已无用的 `M` 常量）。`Han2005CushionModel.swift` 头注更新为「Mathavan 已于 2026-06-05 删除，需对照查 git 历史」。
- **D-A5 ✅ 删除死函数**：`CollisionResolver.vector4(from:)` 全仓无调用点 → 删除（`rotateY`/`surfaceVelocity` 在用，保留）。
- **D-B4 ✅ 评分魔数 → 具名常量**：`solveAimOffset` 内散落的 `-10`/`0.3`/`0.05`/`1e-3`/`100`（miss 基线）/`0.3`（FL-020 kick 惩罚）/三级网格半幅步长，全部抽入新私有 `enum AimScoring`，逐条注明含义/量纲/历史缘由。**数值零改动**。评分序的行为正确性由矩阵 1（进袋合约）+ 矩阵 3（宏观确定性）覆盖，故未再把 `score` 抽成独立纯函数单测。
- **D-D2 ◑ 仅抽常量**：搜索保真 `searchEvents=500`/`searchTime=15` 抽为 `AimScoring.searchMaxEvents/searchMaxTime`（值不变）。**降保真未做**——属行为/性能改动（与 D-D1 同源），有"双景观错位"回归风险，留待专门性能优化时在矩阵护栏下验证。

**回归**：`xcodegen` 重生（pbxproj 0 引用残留）；`PhysicsEngineTests` 23/23、`CushionDiagnosticsTests` 4/4（原 5，删 1 print 对照）、`PhysicsBenchmarkTests` 14/14、`PhysicsInvariantTests` 9/9、`PhysicsScenarioTests` 7/7、`PhysicsMatrixTests` 3/3（母球绕库 0、远处翻袋 0、确定性跨度 0.00°）全过、lint 0。**零行为回归**（求解器仅重构常量名，数值不变）。

> 第二梯队完成。剩第三梯队（D-A1 拆 `EventDrivenEngine`、D-A3 下沉显示闸门、D-A4 几何双真源收敛、引擎遍历确定性化）为结构性重构，现有测试网可兜底；第四梯队（D-B1/B2/B3）依赖真实俯拍视频/USDZ 重导，属人工 backlog。

### 5.5 第三梯队 · 结构性重构（2026-06-06）

有第一梯队测试网（65 方法 / ~3800 场景）兜底，安全执行 §3 第三梯队。**全程零行为改动**——只做位置迁移、命名空间化、常量集中、引用收敛与遍历确定性化，不动任何数值/逻辑。

- **引擎遍历确定性化 ✅**（FL-020 遗留根因清除）：`EventDrivenEngine` 新增 `ballOrder: [String]`（插入有序球名列表），`setBall` 维护、`getAllBalls()` 与所有 `for (name, ball) in balls` / `Array(balls.keys)` 改为遍历 `ballOrder`。彻底消除 Swift `Dictionary`/`Set` 哈希种子随机化导致的浮点求和顺序运行间差异（FL-020 §5.2 遗留项）。
- **死代码清理 ✅**：移除 `EventDrivenEngine` 中失效的诊断计数器（`kissCountBallBall`/`maxBallBallPenetration`/`separateOverlapTriggerCount`/`nudgeCount` 等）、其重置逻辑、`separateOverlappingBalls`/`makeBallBallKiss`/`makeBallCushionKiss` 中的 `print` 诊断语句，以及整个 `debugLogPostEvolveOverlaps`。
- **D-A1 ✅ 拆分巨型文件**：`EventDrivenEngine.swift` 1539→860 行，抽出四个独立文件：
  - `EngineNumerics.swift`（enum，纯数值/运动学）：`acceleration`/`determineMotionState`/`makeBallBallKiss`/`makeBallCushionKiss`/`closestPointOnSegmentXZ`/`isWithinLinearCushionSegment`/`isBallPairOverlappingOrTouching`/`shouldRunFallbackBallBallCheck`/`fallbackBallBallCollisionTime`/`smallestPositiveRoot`——**不持有引擎状态，可脱离引擎实例独立单测**（满足 D-A1「各自可独立单测」目标）。`makeBallCushionKiss` 改为显式传入 `geometry: TableGeometry` 参数（原读 `self.tableGeometry`）。
  - `PhysicsEvent.swift`：`PhysicsEventType` / `PhysicsEvent`（Comparable）/ `BallState`。
  - `EventCache.swift`：整数编码 key 的事件缓存类。
  - `SceneKitBridge.swift`：轨迹回放 SceneKit 桥接。
  - 引擎内 16 处调用点改为 `EngineNumerics.*`；`makeBallCushionKiss` 调用补 `geometry: tableGeometry`。
- **D-A3 ◑ 显示闸门阈值集中**：`ShotPredictor` 三处显示一致性闸门（母球进袋闸门、目标球进袋闸门、`clampedRecorder` 穿库安全网）散落的硬编码阈值（`0.004`/`0.006`/`0.12`/`0.06`/`0.14`/`0.07`/`1/120`/`0.1`/`0.2`/`0.05`）全部抽入新私有 `enum DisplayGate`，逐条注明含义/量纲/历史缘由。**数值零改动**。「把画面=物理下沉到引擎一处」的中期目标未做（属行为改动，落袋吸心已是一步，留待专门做）——故标 ◑ 部分。
- **D-A4 ✅ 几何双真源收敛**：内框尺寸 `innerLength`/`innerWidth` 与球半径以 `BTPhysicsConstants`（`TablePhysics`/`BallPhysics`）为**唯一真源**，`AngleSceneCalculator.innerLength/innerWidth/ballRadius` 改为引用（原各自硬编码 `2.54`/`1.27`/`0.028575`，值相同但双写）。**值零改动**（`2.54`≡`2.540`）。袋口洞中心/jaw/落袋半径等 USDZ 实测几何仍以 `AngleSceneCalculator` 为单一真源（生产 `chineseEightBallQiuJi` 已消费它）；`TablePhysics` 的袋口 CAD 参数头注明确标注「非生产袋口真源，仅供库边 jaw 构建器 + 对照 CAD 几何」。

**架构决策（ADR）**：D-A4 选择「物理基元标量（内框/球半径）由 `BTPhysicsConstants` 单一定义，`AngleSceneCalculator` 引用」而非报告字面建议的反向。理由：① 这些基元是 `AngleSceneCalculator` 计算袋口位置（`pocketPositions` 用 `innerLength/2`）的**输入**，比袋口位置更底层；② 不引入循环依赖（`BTPhysicsConstants` 不反向引用 `AngleSceneCalculator`），而 USDZ 袋口高层布局仍由 Scene 拥有、被 Physics 的 `TableGeometry+QiuJi` 消费——分层清晰。

**回归**：`xcodegen` 重生；lint 0；全物理测试网 **65/65 全过、0 失败**（`iPhone 17 Pro`，~260s）：`PhysicsEngineTests` 23、`PhysicsBenchmarkTests` 14、`CushionDiagnosticsTests` 4、`PhysicsInvariantTests` 9（含确定性 <1e-5 m）、`PhysicsScenarioTests` 7、`PhysicsMatrixTests` 3（母球绕库 0、远处翻袋 0、宏观确定性跨度 0.00°）、`PhysicsPerformanceTests` 3、`DrillShotReconstructionTests` 2。**零行为回归**。

> 第三梯队完成。剩第四梯队（D-B1 常量真实标定 / D-B2 USDZ 重导几何 / D-B3 特殊球路求解增强）依赖真实俯拍视频/USDZ 重导，属人工 backlog；D-A3 中期「显示下沉到引擎」、D-D1/D-D2 降保真性能优化为后续可选项。

### 5.6 D-A3 终局 · 显示闸门彻底下沉 + 纯物理化（2026-06-06/07，ADR-P10-06/07）

> 用户拍板：「贴库与进袋判断逻辑里加了太多非物理规则……符合物理规律的就应该让它发生，而不是人为增加不合理的捕获规则」「把之前的 offset 拿掉，全都回归原始物理」「穿库安全网彻底去掉，轨迹完全用原始物理」「母球进袋也裸取引擎信号」「引擎仍会把 ~1% 球甩出台面几米 → 修引擎（最纯），让逃逸率≈0」。这是 D-A3 中期目标「画面=物理下沉到引擎一处」的**终局落地**。

**(1) ADR-P10-06 — 移除显示层，判定/轨迹裸取引擎**
- `ShotPredictor.predict` 删除全部显示闸门：`clampedRecorder` 穿库安全网（约 100 行 `playableContains`/`clampToPlayable`）、母球/目标球进袋一致性闸门（`captureWindow`/`objMinToPocket`）、整个 `enum DisplayGate`。
- `result.recorder`/`cuePath`/`objectPath` 直接取 `run.recorder`；`cuePocketed`/`objectPocketed`/`simObjectPotted` 直接取引擎信号（`run.cuePocketed` / `run.pottedSelected`）。
- 进/rattle 弹出/小力远jaw→近jaw→袋心进，全部由引擎真实喉腔几何（`TableGeometry+QiuJi.throatWalls`：jaw 库 + 喉腔侧壁/后壁 + 落袋孔）**自然涌现**，不再有任何显示层裁决。
- **后果（预期内）**：安全网移除后暴露引擎自身逃逸——`TrajectoryPlayback.stateAt` 在稀疏事件帧间沿旧速度解析外推穿墙，叠加 CCD 偶发漏检喉腔接缝碰撞，越界从 3285mm 起。用户选「修引擎」而非重新加显示层遮罩。

**(2) ADR-P10-07 — 引擎物理层根治逃逸（让逃逸率≈0）**
- **固定步长上限**：`EngineNumerics.maxEvolveStep=0.05`；`simulate` 主循环中 `dt > stepCap` 时只推进一个安全步、记一帧、作废事件缓存后从新位置重检测（不直接跨大步到事件）→ 帧密 + 捕回漏检碰撞。3285→57.5mm。
- **几何封缝**：`TableGeometry+QiuJi.throatFrontExtend=0.045` 把喉腔侧壁前端向台内延伸，封死「库段↔jaw」对角接缝逃逸路径。57.5→38.1mm。
- **近库自适应子步**：`EngineNumerics.adaptiveEvolveCap(balls:…)` —— 仅当某球正朝某边界/袋口逼近（整步内会触墙）时把步长收紧到位移级（`nearWallSafeStep=0.35R / 速度`），否则保持 `maxEvolveStep`。根治高速窄喉壁隧穿。
- **方向性袋口收容**：`enforceTableBounds` 重构——越界球落在袋嘴通道（`pocket.radius + 2R`）内时按**运动方向**区分：朝袋心去（进袋/入喉 rattle）→ 放行交 CCD；背离袋心（库段↔jaw 接缝漏出）→ 落硬钳兜回。低速 settle（`jawSettlePocketSpeed=0.35`）→ 收袋并补记真实落袋事件（下游 `pottedSelected` 与画面一致）。**该兜底廉价、始终生效**。
- **结果**：`PhysicsInvariantTests.test_invariant_productionPathsStayInBounds` 展示路径**最坏越界 0.0mm**；`PhysicsMatrixTests` 矩阵1 求解器 **0 越界违规 / 96% 进袋**、矩阵2 裸引擎逃逸率 **0.1%**（1/1716，裸引擎直连测试，不经 predict/高保真，阈值内）。

**(3) 性能门控 — 求解器粗步 / 最终模拟高保真（解 D-D1 同源回归）**
- 自适应子步全局启用曾致 6–10× 回归（单杆 1312ms / 满台 5336ms，远超 800/3000ms 预算），因求解器单次 predict 内 ~76 次短模拟都跑了密帧自适应。
- `EventDrivenEngine.simulate` 新增 `highFidelityBounds: Bool=false`：
  - **高保真**（仅 `predict` 的展示用最终模拟，`runShot(…, highFidelity: true)`）→ 启用 `adaptiveEvolveCap`，贴墙帧密、回放不外推穿墙。
  - **非高保真**（求解器 `solveAimOffset` 的数十次短模拟）→ **完全不切步**（`stepCap = +∞`），恢复 ADR-P10-06 前速度。求解器只取结果量（进/方向/吃库），`cueGhostMinDist` 已做段内线段-点采样、`enforceTableBounds` 每步兜底，无需密帧即可正确判结果。
- **结果**：单杆 predict 中位 **125ms**（预算 800）、满台 **663ms**（预算 3000），均远低于预算且精度不变（越界 0.0mm、进袋 96% 维持）。

**回归**：`PhysicsPerformanceTests` 2/2（125ms/663ms）、`PhysicsInvariantTests` 越界不变量 0.0mm、`PhysicsMatrixTests` 3/3（求解器 96% / 0 越界、裸引擎逃逸 0.1%）全过。

**新增/改动文件**：`EngineNumerics.swift`（+`maxEvolveStep`/`nearWallSafeStep`/`jawSettlePocketSpeed`/`adaptiveEvolveCap`）、`EventDrivenEngine.swift`（`simulate` 步长门控 + `enforceTableBounds` 方向收容）、`TableGeometry+QiuJi.swift`（`throatFrontExtend`）、`ShotPredictor.swift`（删显示层 + `highFidelity` 线程）、`AngleSceneCalculator.swift`（保留 `clampAwayFromPockets` 防摆球入袋，不改轨迹）。

> **D-A3 至此完成**（中期「下沉到引擎」目标达成）。`AngleSceneCalculator.clampAwayFromPockets` 按用户决定**保留**——它是球**摆放**约束（防用户把球摆进袋口），非轨迹修饰，不影响贴库轨迹纯度。残留 0.1% 裸引擎逃逸仅存在于绕过 predict 的直连测试，用户可见路径（恒经 predict→高保真）越界 0.0mm。

### 5.7 幽灵反弹根治 · enforceTableBounds 几何感知豁免（2026-06-12）

> 用户截图报告：母球吃左长库后反弹轨迹明显不合理（贴库平行滑出 + 末端小钩），偶发。先分析测试、确证根因后修复。

**根因（逐帧确证，`PocketBehaviorDiagTests.test_S3_frameLevelConfirm`）**：
- 角袋 jaw 弧的**合法球心接触圆**（r_arc + R = 133.6mm）**伸出矩形可玩框**（`safeMinX = ±(innerL/2 − R)`）——弧面 352° 接触点比 safe 线深 ~1.3mm，沿弧向袋心方向最多深 ~4cm。
- ADR-P10-07 的方向性袋口收容豁免圈（`pocket.radius + 2R = 127.2mm`）**差 0.9mm 没罩住**事发接触带（事发点距袋心 128.0mm）。
- 于是 CCD **已正确检出并调度**的弧碰撞事件（dt=0.0083s）被 `evolveAllBounds` 内每子步运行的矩形硬钳**抢先触发**：vx 取反减半、vz 保留、不记事件、不作废缓存 → 屏幕上即「幽灵反弹」。陈旧缓存事件随后接力开火，叠加出钩状伪迹。
- 另排除一个嫌疑：S2 疑似「入29°→反131°超宽反射」实为采样帧错位误报，实际反射 29°→27°、e≈0.73，物理正常。**（⚠️ 此判断错误，被用户打回：131° 是真实的引擎输出，见 §5.8 / FL-022——本节修复只治了袋口弧接触带分支，未触及主库线上的同类竞态。）**

**修复（`EventDrivenEngine.enforceTableBounds`，三处）**：
1. **jaw 弧接触带豁免 + 径向速度门控**：球在任一圆弧库角度扇区内、距弧心 ≤ r+R+12mm、且**径向速度 |vr| > 0.02 m/s**（正撞向弧面或刚反弹离开）→ 不硬钳，交弧 CCD 解析。门控防研磨：沿弧切向蹭行（|vr|≈0，贴长库滚过中袋 fillet）若豁免会触发 zero-time 弧事件风暴把求解器拖垮（实测 `test_solveDrillC005` 无门控版 signal kill，门控后 115s ≈ 基线 123s）。
2. **袋嘴圈内带速球无条件放行**（删 `towardCenter` 方向门）：rattle 弹出段（背离袋心）同样合法；速度 < `jawSettlePocketSpeed`(0.35) 的球仍被 ② settle 收袋，无研磨风险。
3. **硬钳后作废该球事件缓存**：硬钳是事件流之外的状态突变，不作废缓存会让按钳前轨迹预测的陈旧事件接力触发二次非物理反射。

**验证**：300 杆随机扫描（`test_S_cueRailReboundScan`）贴库线幽灵反弹 **4→0**（残余 12 例均为远库慢速强塞 massé 曲线的检测器误报，非反弹）；trial19 复现杆现正确产出 `弧#33` 碰撞事件（Han 反射 e≈0.68）；全量单测 372 过，仅 3 个 `PhysicsEngineTests` 既有失败（**基线对照确认与本修复无关**，属此前未提交工作遗留：`largeCutClearShot`/`objectPath_reachesPocket`/`withSideSpin_objectPots`，待另行处理）。

### 5.8 贴库滑行真根因 · 库线吃库与边界安全网的浮点竞态（2026-06-12，FL-022）

> §5.7 修复后用户打回：贴库滑行仍偶发，且求解轨迹出现「先吃库→撞远端 jaw 弧→进袋」假进袋。§5.7 只治了**袋口弧接触带**分支，主库线上的同类竞态未触及，且其第 4 条「131° 为采样误报」的排除判断是错的。

**根因（`PocketBehaviorDiagTests.test_S4_replicateS2EventChain` 数值确证）**：
- 库线吃库时球心接触位置**恰好等于** `enforceTableBounds` 的 safe 边界（contact z = 库线 ∓ R = safeMaxZ，**零余量**）。CCD 把球精确演进到接触点时，Float32 噪声（~1e-6 m）偶尔落在边界外。
- 此时零容差硬钳抢在已排定的吃库事件前触发：法向速度减半反向（vz +3.276 → −1.638），无自旋耦合、非物理。
- 紧接着吃库事件照常解析，但球已在退离。`resolveCushionCollisionPure` 按速度方向**自动翻转接触系**，把退离球当作从反方向来撞，再次反射**回库内**（→ vz +1.101，即 S2 实测「入29°→反131°」）。
- 球贴库线被后续子步反复钳制（实测下一帧 vz = −0.548 = +1.101×0.5，0.5 恢复系数钳指纹），最终以 ~23° 贴库角滑出（物理应为 63°）→「贴库滑行」；滑行沿库送进角袋口 →「吃库→远弧→假进袋」。
- **偶发性解释**：触发与否取决于接触点浮点噪声落在边界哪一侧。S3 直瞄跑不复现、S2 求解器补偿瞄向路径复现，差异仅为瞄向微调。Han 模型本身无辜：同帧状态手动复算输出干净的 27° 反射。

**修复（两处物理正确性约束，无 magic offset）**：
1. `enforceTableBounds` 触发加 `boundsEpsilon = 0.5mm` 余量：球心在接触线上是「正在吃库」的合法状态而非出界（≫ 浮点噪声 1e-6，≪ 真实接缝漏出 mm 级/子步，安全网兜底不受影响）。
2. 吃库解析加「**库边只能推不能拉**」护栏：解析前检查 v·n < 0（确在逼近库面）；退离中的过时事件跳过、不施冲量、不记事件（与 `.pocket` 的条件记录同模式）。

**验证（2026-06-12）**：
- S4：引擎实际出射 == 手动复算（spinY0: 27°；spinY0.45: 30°），131° 消失；轨迹变为正常多库走位。
- S2 六面板全部反射恢复物理（131°→27°、114°→50°、入79° 贴库再撞消失），渲染图无贴库段。
- `test_S_cueRailReboundScan`：贴库线幽灵反弹 0、平行出射 0（1197 次吃库）。
- `test_solveDrillC005` 117s（基线 123s，无性能回退）；`PhysicsInvariant`/`PhysicsMatrix`/`PhysicsScenario`/`CushionDiagnostics`/`PositionPlayFreeAim` 全过。
- 仅 3 个 `PhysicsEngineTests` 预存失败（与修复前**完全同集**，断言为袋口毫米级距离偏差，属其他未提交工作遗留，另行处理）。

### 5.9 D-D1/D-D2 主体偿还 · 反解求解器分层提速 B0–B5（2026-07-08）

> 方案真源：`docs/research/20260708-反解求解器性能优化方案.md`；实施记录与 ADR-P13-01…04 见 `tasks/phases/P13-position-play-solver.md`。此处只登记债务台账口径的结论。

- **D-D1（求解慢）主体偿还**：反解四条路径（思路训练情形 A / 三杆规划情形 B / 批量出片 / 做斯诺克）经 B1–B4 分层改造——B1 scoring-only + 引擎早停、B2 解析瞄准层（`AnalyticAimModel`，黄金分割评分换闭式推演）、B3 单球解析 rollout（`AnalyticShotRollout`，扫描层替代全量引擎模拟）、B4 斯诺克三层搜索（rollout 快评 → 歧义格粗细两阶段引擎评估 → 代表解全保真复核）。**实测（模拟器 `SolverPerformanceTests`）**：情形 A 2.28→0.15s、情形 B 1.98→0.13s、批量 7.42→0.47s、斯诺克 36.56→7.2s。
- **D-D2（保真分级）以更安全的形式落地**：不是降低搜索模拟的 `maxEvents/maxTime`（原风险：双景观错位），而是「搜索层解析/scoring-only + 每个上屏解引擎全保真复核」——搜索与终验分级、物理真值单一来源不变。**护栏结论**：`highFidelityBounds` 对 scoring-only 也不可关（近库自适应子步在多球盘面改变轨迹，非纯展示量），`ScoringOnlyConsistencyTests` 常驻守卫。
- **残留（如实）**：① 单杆 `predict` 展示路径未动（~125ms 中位，够用）；② 斯诺克级联歧义格只能引擎裁决，≤500ms 目标未达（穿透级联递归解析经 B5 复评**暂不做**——需在解析层重建多球事件循环，等于第二个引擎，维护/对拍成本远超 7s→0.5s 的收益，且斯诺克为低频功能）；③ 真机基线仍欠 H-20（设备未连接）。
- **回归网**：`AnalyticAimParityTests` + `AnalyticRolloutParityTests` + `ScoringOnlyConsistencyTests` 常驻对拍；`BatchSequenceReplayRegressionTests` 重放 `content/position_play/sequences/` 全部 91 条 drill 序列（171 杆，覆盖 62 drill 成品内容）与 HEAD 基线 worktree 对拍 **dump 逐字节一致**（优化零改变展示物理）。
