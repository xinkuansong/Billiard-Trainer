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
| **D-A1** | 🟡 | `EventDrivenEngine.swift` 巨型文件 1713 行 | 单文件含：事件队列+缓存（`PhysicsEventCache`）、主循环 `simulate`、`findNextEvent`、球-球/库边解算、`enforceTableBounds`、`resolvePocket`、`separateOverlappingBalls`、回退检测 `shouldRunFallbackBallBallCheck`/`fallbackBallBallCollisionTime` | 单一文件多职责，单测只能端到端打，改一处牵连全局，回退/分离重叠等"安全网"逻辑与主循环混杂 | 拆分：事件调度器 / 碰撞解算 / 边界&落袋 / 数值安全网 四块，各自可独立单测 |
| **D-A2** | 🔴 ✅ | `CushionCollisionModel`（Mathavan 2010，636 行）是生产路径死代码 | `CollisionResolver.resolveCushionCollisionPure` 只调 `Han2005CushionModel.solve`（CollisionResolver.swift:150）；`CushionCollisionModel.solve` 全仓唯一调用点是 `CushionDiagnosticsTests.swift:226` | 636 行无人维护的复杂数值积分代码常驻仓库，误导后人以为在用；与 Han2005 两套库边模型并存制造混淆 | **✅ 已删除（2026-06-05，见 §5.4）**：删 `CushionCollisionModel.swift` + 移除唯一消费它的 print 对照测试 `test_cushion_HanVsMathavan`；Han2005 头注补「Mathavan 已删，需对照查 git」 |
| **D-A3** | 🔴 | `ShotPredictor` 显示闸门与物理真值耦合，patch-on-patch | ShotPredictor.swift 内 3 处"显示一致性闸门"：母球进袋闸门（L206-219）、目标球进袋闸门（L226-238）、`clampedRecorder` 穿库安全网（L443-545）。注释多处自陈为修 FL-018/FL-019 逐个补的 | 引擎"真值"与画面"显示值"判定不一致，需在门面层反复打补丁对齐；阈值（0.06/0.12/0.14m、0.004、0.07m/s）散落硬编码，脆弱、难推理 | 中期：把"画面=物理"下沉到引擎一处（落袋吸心已是一步），让 `ShotPredictor` 只读结果不再二次裁决；阈值集中为具名常量 |
| **D-A4** | 🟡 | 几何/常量双真源未完全统一 | `BTPhysicsConstants.TablePhysics` 袋口参数标注 `TODO(step3)` 仍取 CAD（BTPhysicsConstants.swift:9-10,45）；与 `AngleSceneCalculator` 的袋口/几何并存，靠注释声明"完全一致" | 同一物理量两处定义，改一处忘另一处即引入静默偏差；探针历史上的"17mm 双真源"正源于此类 | 收敛为单一真源（`AngleSceneCalculator` 或 `TableGeometry`），另一处改为引用 |
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
| **D-D1** | 🟡 | 单次 predict 150-200ms；满台序列数百 ms | `solveAimOffset` 粗±12°/0.5°(49)+中(13)+细(13) ≈ 75 次短模拟，每次 500ev/15s（ShotPredictor.swift:626-629, 577-578） | 编辑模式跟手度差；P11 满台求解明显延迟 | 求解 sim 用更短 maxTime/事件数搜索、最终再全保真；或缓存/增量；评估 Han 闭式解外是否可解析剪枝 |
| **D-D2** | 🟢 ◑ | 搜索与最终模拟均 500/15，未分级 | ShotPredictor.swift:577（searchEvents=500/searchTime=15）注释自陈历史上为修"双景观错位"提到与最终同保真 | 搜索阶段保真度过剩 | **◑ 部分（2026-06-05，见 §5.4）**：500/15 已抽为 `AimScoring.searchMaxEvents/searchMaxTime` 具名常量（值不变）。**降保真本身未做**——属行为/性能改动（D-D1 同源），有"双景观错位"回归风险，留待专门做性能优化时在矩阵护栏下验证 |

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

**第三梯队（结构性重构，需测试网就绪后做）**
5. D-A1 拆 `EventDrivenEngine`；D-A3 下沉显示闸门到引擎；D-A4 收敛几何双真源。

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
