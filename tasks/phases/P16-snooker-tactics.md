# P16 做斯诺克战术工具（安全球反解）

> 来源：用户 idea「现在又 K 球了，但还没有做斯诺克的工具——给定球形、选目标球与障碍球，
> 让母球与目标球最终落点之间被障碍球挡住」。独立成页（后续可扩展为更全的安全球/战术中心）。

## 目标

把走位反解器（P13 思路训练器）的能力扩展出第三类约束——**做斯诺克**（防守/安全球）：
摆球后选 1 颗**目标球**（这一杆要合法首触、且要困住对手的球）+ 1 颗**指定障碍球**，反解出
塞/力度/瞄准，使击球后母球**合法首触目标球、母球与目标球都不进袋、母球真停稳**，并停在
「从母球看向目标球终位的视线被障碍球**完全挡死**」的位置。

## MVP 范围（用户三项拍板，2026-06-17）

| 决策点 | 拍板 |
|--------|------|
| 被困球 vs 首触球 | **同一颗**（MVP）：碰一下目标球、母球缩到它背后障碍后面 |
| 是否进袋 | **纯安全球，不进袋**（目标球留台当诱饵；母球也不进袋） |
| 障碍球 | **手动指定**单颗（用户的原始心智，搜索更聚焦） |

不在本次范围：被困球≠首触球（真安全球语义）、多障碍并集、半斯诺克逃脱难度评分、贴库/贴球加成、
把球主动顶到位当障碍（v2+）。

## 实现（ADR-P16-01）

### 几何判定（`AngleSceneCalculator.snookerCoverage`）
判的不是「球心连线被挡」（那是 `isPathBlocked` 的保守自动选袋闸），而是**对手能否从母球看到被困球的
任意一点**：母球（半径 R）沿直线击出、球心扫过被困球（半径 R）即「看得见」，故可见方向是张角扇形，
半角 `α = asin(2R / d_被困)`；障碍球同样张开半角 `β = asin(2R / d_障碍)`、方向差 `Δθ`。

**完全斯诺克 ⟺ `coverage = β − α − |Δθ| ≥ 0` 且 `d_障碍 < d_被困`**（障碍更近才先拦截）。
`coverage` 转度 = 覆盖余量（正=多挡 N°、越大越难薄擦；负=仍露 N°）。
闭式经 Python 数值草稿 + XCTest 金标准双验证（S1 内挡→full / S2 越过→非 / S3 横偏→非 / S4 贴母→大余量）。

**坐标契约**：全程 SceneKit 世界系 X–Z 平面、Y 朝上、角度 `atan2(z, x)`；三球取**终位**
（`ShotPrediction.finalPositions`，`SCNVector3`），不经归一化转换——规避 canvasY↔sceneZ 符号双真源。

### 求解器（`PositionPlaySolver.solveSnooker`）
与 A/B 约束的关键差异：A/B 以「目标球进选定袋」为硬约束、靠袋口锚定瞄准（解 aim-to-pot）；
做斯诺克**不进袋**，无袋口锚点 ⇒ **瞄准是自由变量**。故不复用 `candidateMatrix`，改走 `simulateFree`：
- 候选 = 瞄准偏移（在「可接触目标球」张角内采样，端点收缩 0.92 防薄擦漏触）× 横塞 × 竖塞 × 力度（≤5.0，安全球多轻—中力）。
- 并行 `DispatchQueue.concurrentPerform` 逐候选 `simulateFree`（各自建引擎，无共享态）。
- 硬约束：①合法首触（母球首个 ballBall 另一方==目标球）②母球不进袋 ③目标球不进袋 ④母球真停稳
  （`cueFinalSpeed < restSpeedTolerance`）⑤`snookerCoverage(终位).isFullSnooker`。
- 排序：库少优先 → 覆盖余量大优先 → 加塞少 → 力度小；按吃库桶取代表。
- 降级：无完全斯诺克 ⇒ 返回覆盖余量最大（最接近挡死）的单个解，标半斯诺克。
- 复用 `applyCushionBudget`（maxCushions 预算「优先+兜底」）、`spinCombos`、`spinText`/`cushionText`。

`ShotPredictor.simulateFree` 增量：补 `cueFinalSpeed`（与 `predict` 对称，原仅 predict 填充——做斯诺克
真停点判定依赖它）。纯增量、向后兼容。

### 页面（独立 Feature 模块 `QiuJi/Features/SnookerTactics/`）
布局 1:1 参考思路训练器：黑底 + dark 工具栏 + `navStatus` 双行 + 三段式（顶部工具行→球桌→底部条）。
- 工具行 `BTChipRow`：`[目标球 | 障碍球 | 摆球]`，目标=青环、障碍=红环、摆球=拖动/球库增删。
- 去掉思路训练器的手画约束层（斯诺克靠点选球，不手画）。
- 叠加渲染：有解时画三球**终位**遮挡视线（完全挡死=灰、半斯诺克=红）+ 障碍终位红环 + 母球终位白环；
  编辑态画当前摆位角色环。
- 底部条复用：只读解指示（打点图标+力度+覆盖余量摘要）+ 球库双行 + 操作列（求解/下一解/击球/导出模拟器限定）。
- `moreMenu`：允许左右塞 / 仅基础走位（≤1库）/ 清空 / 恢复默认（同思路训练器口径）。
- 入口：角度 Tab「工具」海报墙加卡「斯」（深红配色，chip「物理」）+ `AngleRoute.snookerTactics` + `MainTabView.angleDestination`。

## 验证

- `make xcodegen` + `make build` **BUILD SUCCEEDED**、lint 0。
- `SnookerSolverTests` **4/4**：①`snookerCoverage` 金标准（S1–S4）②非法输入返空③satisfying 解全复核
  （首触/不进袋/真停/几何重算完全斯诺克 + 必找到 ≥1 完全解，探针 60 布局确证）④无解降级半斯诺克。
- 回归：`PositionPlayFreeAimTests` 7/7、`PositionPlaySolverTests` 13/13（simulateFree 增量零回归）。
- **探针实测**：60 个障碍布局扫描，几乎全部产出多个完全斯诺克解（最大余量 71°），证实回弹做杆机制成立。

## 为后续扩展留的接缝（现未实现）

- 工具行 `BTChipRow` + `Tool` 枚举：加角色/约束即加 chip + 分支。
- 页面命名 `SnookerTactics`（战术/安全球）而非 Maker：后续可装「解斯诺克逃脱」「炸球堆」「做杆留球」。
- `moreMenu` 是未来开关（全/半斯诺克阈值、合法性强校验）的现成位置。
- 求解器 `SnookerParams` 已分离，可独立调密度/加精修（v1 未做局部精修，注为后续）。

## 遗留 / 后续

- v1 无局部精修（A 情形那套 Hooke-Jeeves），靠瞄准 21 档密扫覆盖；若覆盖余量稳定性不足再加精修。
- 被困球≠首触球（真安全球）、多障碍并集、逃脱难度评分、贴库加成 → v2。
- 真机走查：三角色点选 / 遮挡可视化 / 回放 / 导出（模拟器）。
- 合法性边界（必须有球到库等球种完整规则）v1 不强求，作提示而非硬闸（范围纪律）。

---

## ADR-P16-01：做斯诺克独立工具 + 第三类反解约束

- **状态**：已采纳（2026-06-17）。
- **背景**：用户提出做斯诺克 idea；走位反解器（P13）已有「放开塞/力度作自由变量、约束改为母球落点」
  的引擎与 UI 骨架，做斯诺克本质是同一台反解引擎的第三类约束。
- **决策**：
  1. **独立成页**（`Features/SnookerTactics/`），不塞进思路训练器——语义不同（防守 vs 走位），且用户明确要后续扩展。
  2. **求解器复用但走 simulateFree 而非 candidateMatrix**：做斯诺克不进袋、无袋口锚定瞄准 ⇒ 瞄准是自由变量，
     扫瞄准方向 × 塞 × 力度，不做 aim-to-pot 求解。新增 `solveSnooker` 独立入口（不强行塞 `pocket` 参数），
     A/B 路径零改动（零回归）。
  3. **未加 `SolveConstraint.snooker` 枚举 case**：避免在两个 `solve` 重载里铺设无意义的 `pocket` 管线；
     做斯诺克用独立入口更干净。
  4. **几何判定用张角覆盖**而非中心线遮挡（`isPathBlocked`）——后者会把「能薄擦解掉」误判为成功。
- **影响**：跨模块新增独立 Feature；`ShotPredictor.simulateFree` 增 `cueFinalSpeed`（向后兼容）；
  `AngleSceneCalculator` 增几何 API；`AngleRoute`/`MainTabView`/`AngleHomeView` 各加一处。
- **未选**：①塞进思路训练器（交互角色打架）②复用 candidateMatrix（无袋口锚点，不适用）
  ③复用中心线遮挡（判不出薄擦）。
