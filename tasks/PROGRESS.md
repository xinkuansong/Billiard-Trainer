# 开发进度（PROGRESS）

> Orchestrator 每次会话开始时读取本文件，结束时更新。
> 另须读取 `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（若存在）。

---

## 任务状态（四态）

| 符号 | 含义 | 使用说明 |
|------|------|----------|
| ⏳ | 待开始 | 尚未开工 |
| 🔄 | 进行中 | 附 DoD 进度，例：`🔄 进行中（DoD 2/5）`；会话可能中断时**必须**写入，便于恢复 |
| ⚠️ | 返工 | 附 `见 FL-xxx`，对应 [`tasks/IMPLEMENTATION-LOG.md`](IMPLEMENTATION-LOG.md) 条目；修复后改回 ⏳ 或 🔄 |
| ✅ | 已完成 | Phase 任务卡 DoD 全部满足 |

---

## 当前状态

> **滚动归档纪律（强制）**：本区只保留**最近 10 条以内**（或最近 3 天）条目；更早条目移入 [`tasks/archive/PROGRESS-当前状态-归档.md`](archive/PROGRESS-当前状态-归档.md)（新条目插到归档文件说明块之后的顶部，保持时间倒序）。每次追加新条目时顺手检查：超过 10 条即归档最旧的。历史检索一律去归档文件，勿在本区堆积。

- **问题集合 v34 全案收官 ✅（2026-08-11，plan-delegated-execution，主控 = Orchestrator；W0–W6 七批全过，返工 0 轮）**：用户睡前授权全程委派 + 拍板代决。**主控亲做** W0（契约 v2.3：D16 剂量重定 15 颗/位置 + `doseNote`、D17 `roundsPerFormation` 倍数语义 + formations 下限入 I11、D18 形状约束入 I6b 取代 D13/D15；门禁/自测/Swift 镜像同步；ADR-006 落 P2；附带修 xcpretty 缺失挂死）、W1（6 处 mode 翻转 + c024 首球形删除，D-v34-3 代拍板，Snipaste 引用全库归零）、W6（回归收官）。**委派 grok-4.5 + 主控独立复算验收** W2（剂量写回 ×83：自写脚本比对填写表 ↔ JSON **105/105 一致**、I6b 归零）、W3（计划重排 ×10：D-v34-2 代拍板映射 id 全沿用、83/83 覆盖 + 完整剂量 ≥3（特殊球 ≥4）、75 条零 `roundsPerFormation`、课时档 ±20% 全落带、gate 首次归零 + 自测 28/28）、W4（Resolver 倍数语义 + 下限钳制 + 动作页逐球形 R10，主控亲跑 40/40 + 截图亲验）、W5（计划页 R11 + 训练页三级指示/分节/走位链只报轮/添加一组复制位置 R12 + `volumeText` 统一，主控亲跑 85/85，补 1 处修正：异构用例被 XCTSkip 改锚 c069 恢复覆盖）。**W6 收官证据**（`build/v34-w6-logs/`）：`verify-gate` **FAIL 0**、自测 **28/28**、`make build` SUCCEEDED、全量回归（基线设备 17 Pro）**失败恰为 W0 基线 8 条零新增**、截图走查 4 页面齐（含今日安排激活态新口径上屏）。**主控改写 10 条 V21/V22 旧货架规格测试**（钉死重排前计划细节，前提已废）为 v34 规格 11/11 过。**遗留**（详见 `问题集合_v34.md` §五 W6）：bank shot 设备相关可解性（17 失败/17 Pro 过，非 v34 回归）、X-v31-1 扩容、c024 烘焙遗留、c075 锚点硬编码、计划页窄列截断。**全部批次验收记录在 `问题集合_v34.md` §五。**
- **问题集合 v34 立档 ✅（2026-08-11，纯文档，Orchestrator）**：新建 `问题集合_v34.md` v34.0——「训练量全库重定（15 颗/位置）+ 计划重排 + 三页剂量透出」真源。剂量数值真源 = `tasks/训练量填写表.md`（2026-08-11 03:03 定稿，用户逐球形手填：83 drill / 105 球形 / 总 **9493** 球，旧口径 ≈4150）。**用户拍板 R1–R13**：重复型 = 每位置 15 颗 × 轮数=杆数（轮=位置，例外 c002/c022 带 `doseNote`）；走位链 = 杆数/轮 × N 轮；c024 首球形整体删除（清单先确认）；mode 修正 6 处（c001/c062/c063/c072→repetition、c046/c080→sequence，⚠️ 与 v31 W1 语义判定相反，本轮以用户对照形态逐条填数为人工裁定）；计划重排 10 个各 2–5 周（准度/杆法各拆两段）、每动作完整剂量 ×3、每周 3 次；配速固定 2.5 球/分钟不做设置、课时档 75/90/120/150 min、超容不硬卡；**`roundsPerFormation` 走 B 方案**（留列改语义为「整套遍数倍率」，⛔ 不做 Schema V4 迁移，官方计划不写该字段）；D13 总量护栏作废改形状约束（重复型 bpr∈[8,15]）、D15 被取代（c020/c078 16→15）；动作页/计划页/训练页三处透出逐球形剂量，训练页「组=位置」三级指示「球形 x/y · 位置 m/n · 第 k 颗」（走位链只报轮）。**批次 W0 契约门禁（主控）→ W1 mode+c024（主控）→ W2 剂量写回 ×83 → W3 计划重排 ×10 → W4 Resolver+动作页 → W5 计划页+训练页（W2–W5 = cursor-grok-4.5-high-fast，用户拍板）→ W6 回归（主控）**。锚点全部读码核实（`verify_tutorial_sync.py:531` VOLUME_GUARD、`TrainingDoseResolver.swift:136–162`、`PlanContentService.swift:70–88`、`QiuJiSchemaV3`、`DrillDetailView.swift:390`、`ActiveTrainingViewModel.swift` plannedSets 已带 token 结构无需重做）。**拍板项遗留**：D-v34-1 fullskill 归宿（默认改精选计划）、D-v34-2 计划文件 id 映射（W3 提案）、D-v34-3 c024 删除清单（W1 出示）。**排期前置**：工作区停有 T01/FL-030 未提交改动 ⇒ 各批独立 worktree；完成标准聚焦测试 + W0 现场基线。**下一步：开工 W0（契约 v2.3 + 门禁形状约束 + ADR + 封存填写表）。**
- **T01「30° 法则」配图返工 ✅（2026-08-10，SwiftUI Developer + 几何自检 / FL-030）**：用户实机反馈「瞄准线没有，而且调整角度，30 度角那条线也不动，其他类似的也有问题」，逐条落实为三个真 bug。**根因**：滚动线取「旋转与加塞」页相对**进球方向 n** 固定 60° 的教学折线，而 T01 的命题基准是**原瞄准线**——60° = θ + 30° 只在半球 θ=30° 成立 ⇒ 屏上钉死不随滑杆动，非半球档角度也不对；角标还是写死的「约 30°」，与页内表「半球约 34°」自相矛盾。瞄准线则根本没画到母球（只在假想球两侧留 0.08/0.18 m 一小截 + `opacity 0.55` hint 线宽），T02/T03 画法正确但 `opacity 0.35` 同样近乎不可见。**修法**：`SpinAndEnglishGeometry` 加法式新增 `rollingDeflectionDegrees / rollingFollowDir / rollingFollowEnd`（真源 = `theorem-tags.json` T01 `key_formula` `tan δ = sinφcosφ/(sin²φ+2/5)`，随切角连续解），⛔ `departureDir` 教学折线一行未动故「旋转与加塞」页读数不受影响；T01 图改画「母球→假想球主线宽白实线 + 过假想球白虚线延长（量角基准）」，角标与滑杆说明由 δ 实测格式化，角标锚点改角平分线外推 + 朝滚动线侧让位（小切角时会压目标球）；T02/T03 瞄准线提到主线宽 `opacity 0.75`，T02 补标签。**实证**：数值草稿 `build/t01-fix/draft.txt` 与 contract `key_data` 逐档对齐（27.65@14.5° / 33.75@28.1° / 27.05@49°，极值 33.7°@28.1°），且 `rotate(aimDir, s·δ)` 与「5/7 切线 + 2/7 瞄准线」向量法误差 ≤3e-15（正负 θ 双侧）；`make build` **SUCCEEDED**；`TheoryFigureGeometryTests` + `SpinAndEnglishGeometryTests` **13/13 TEST SUCCEEDED**（新增 4 项：contract 对账 / 向量法对拍 / 方向随 θ 变 / θ 全域取景不出框）；模拟器实机 θ=5/30/45/75 四档逐档目视核验（偏 12°/33°/27°/11°，线随 θ 转、标签不互叠）+ T02/T03 瞄准线可读性截图。**全量 `QiuJiTests` 14 项失败经 stash 前置基线实跑证明与本批无关**（同一批 14 项既有 drill 内容/重放/特写红项，⛔ 未修绿）。**回写**：FL-030（实施日志）→ `geometry-spatial-reasoning/SKILL.md` § 经验教训（教学示意角基准不得跨页盲借 / 交互图数值标签必须实测格式化 / 注释承诺的不变量必须有扫描断言）；SPEC § Changelog；v30 转写模板 T01 真源行更正。**本轮改动尚未 commit。**
- **问题集合 v31 全案收官 + X-v31-3 补做 ✅（2026-08-10，Orchestrator 委派执行，返工 0 轮）**：**P2 副分类清单经用户确认照单通过**（15 条无增删）⇒ 真源 §六 P1–P4 全部裁定完毕、v31 无待办，真源升 **v31.8**。v31 全部改动按内容 / 计划 / 应用代码 / 测试 / 脚本门禁 / 文档六组分批提交（`de2a16c` → `3aaae85`）。**X-v31-3 修复**（`e837723`）：`SubscriptionManager` 加 DEBUG-only `-forcePremium`，在 `init` 与 `checkEntitlements()` 两处生效故所有依赖 `isPremium` 的门禁看到同一状态，与 `-forceNonPremium` 同传时后者优先；新增 `QiuJiUITests/XV313PremiumPlanWalkthroughUITests.swift` 4 例（两份付费计划走查 + 反向锁定断言 + 双开关优先级），⛔ 未改任何计划/内容 JSON、未动 StoreKit 校验。**主控独立验收**：亲读 `build/x-v31-3-logs/` 原始日志——UI 4 例 0 失败（另在擦除后干净模拟器复跑 3 例 0 失败）、P7 订阅 6/6、V28 3/3、单测 49 例 6 失败全为既知 `pocket ''` 基线（**新增失败 0**）、`verify-gate` FAIL 0、Release 二进制中开关符号/字面量为 0 而 Debug 为 3/3/4（对照串两侧都在，证明探针有效）；亲验三张截图并与计划真源逐条复算量值（走位 0/4 = c010 2×15 / c034 6×10 / c037 4×10 次；全能 0/5 含 c001 12 轮×5 杆 sequence）；主控自跑合并后 `make build` **SUCCEEDED**。**遗留**：反向用例首轮在擦除后冷启动出现「点卡片被丢弃 / 详情页被弹回」，判据已改为周列表渐进锁 + 点击重试（⛔ 未弱化断言），但该偶发根因未查到底；X-v31-1 与 6 条 `pocket ''` 仍待另立批次。
- **问题集合 v31 全部批次收官 ✅（2026-08-09，W3a / W3b / W4 / W5 一气推完，四批均返工 0 轮；全程子智能体执行 + 主控独立验收）**：**W3a/W3b 官方计划重写**——10 份 `Resources/Plans/plan_*.json` 全量切到 dose 格式（1222 条目，`PlanDrillRef` 零残留 `sets`/`ballsPerSet`），未引用 drill **37 → 16（W3a）→ 0（W3b）**，全库 83 条**全部**进计划 ⇒ 真源 §六 P4 豁免清单消解；164 个 session 预算全部落带内。两处主控采纳的判断：c079–c082 落 `plan_positioning` 而非真源写的 `plan_accuracy`（这四条主分类是 positioning、副分类不含 accuracy，进 accuracy 的 focused 段直接违反主题周对齐）；`plan_fullskill` W5–W12 周主题由占位文案「本周重复 Week N 主题（循环）」改为点名分类的主题（原文案无法推导分类集合，且该计划重写前 12 周只用 c001–c013 共 10 条 drill，与「全能」名实不符），W1–W4 主题原样保留。**W4 门禁**——I6a（`perFormation` token 集合 == 序列 token 集合）/ I6b（sequence 型 `ballsPerRound` == 实测杆数）/ I11（计划 drillId·dose·token 可解析）三项接入 `make verify-gate`，**阻塞项 9 → 12**，构造性用例 +8；**I10 盲区消除用对照实证**（同一注入下 HEAD 版检查器 FAIL 0、W4 版 FAIL 1，FL-029 第 3 条）；门禁拦截实证（裸仓 push exit=1 → 还原 exit=0）；**D15 阶梯型口径放宽**（repetition 型档数 > 15 时 `ballsPerRound` 取档数，全库仅 c020/c078 命中，各 15→16；⚠️ 真源原写「c076 也改到 14」有误，c076 本就 14 档且现值即 14，未动）；repetition 豁免做成**规则性判定而非棘轮清单**（两个基线键均为空字典，零条 FAIL 被塞进基线），可观察性由「门禁常驻打印规则豁免 N」+「非法 mode 直接 FAIL」保住。**W5 收尾**——`PlanDrillRef` 旧格式一次切净、`TrainingDoseResolver` 三路径降为两路径（drill 侧 `defaultSets`/`defaultBallsPerSet` 按契约 §5.6 保留未误删）；`plan_cueball` W5D3 热身 c001 减 1 轮清账 W4 的 1.5 球预算副作用（⛔ 未改阈值/分钟数/drill JSON）；构造性用例 23 → 24（新增守护「I11 旧格式残留 WARN→FAIL」）。**契约 v2.0 → v2.2**（§5.6.2 D15、§6.6 切净说明、§7 表 I6a/I6b/I11 状态、`MODEL_SPEC` 补新字段）。**验收证据**（`build/v31-w3a-logs/`、`v31-w3b-logs/`、`v31-w4-logs/`、`v31-w5-logs/`、`v31-w5-screenshots/`）：`make build` SUCCEEDED、`make verify-gate` **FAIL 0**、`invariant-selftest` **24/24**、两份计划校验脚本 FAIL 0、聚焦 13 套 **146 例 6 失败 = 既有 `pocket ''` 基线原样，新增失败 0**（⛔ FL-027 不修绿）、9 张模拟器截图 + 常驻 UI 走查 `V31W5WalkthroughUITests`。**主控独立验收**（不采信子智能体自述）：四批全部亲读落盘原始日志行；**自写脚本独立复算全 10 份计划**——按 `TrainingDoseResolver` 语义重算 164 session 派生球数越界 **0**、未引用集合 = **空集**（83/83），抽验 plan_positioning W5D1 = 174 球与日志逐字一致；亲验两张截图（今日安排「7 轮 × 5 杆」证 sequence 型单位、c042 录入 7 组 = 10/10/5×5 证异构展开与逐组 token）；核 git 边界确认 `content/` 与产物目录零改动。**遗留**：§六 **P2 副分类 15 条待用户确认**（这是 v31 唯一未闭环项）；新增 **X-v31-3**（付费计划 `isPremium: true` 未订阅态走 `isPremiumLocked` 无法激活 ⇒ 今日安排走查只能用免费计划，需先做订阅态注入手段）；X-v31-1（四条 drill 元数据自称走位链被证伪）与 6 条 `pocket ''` 按判定不在 v31 范围，另立批次。**下一步：用户确认 P2 副分类清单；本轮改动尚未 commit。**
- **问题集合 v31 W2 运行时绑定与多球形展开 ✅（2026-08-09）**：剂量解析收敛为**唯一入口** `QiuJi/Data/Services/TrainingDoseResolver.swift`（新增），输出 `ResolvedDose`（球形组列表）+ `plannedSets`（展开后的组序列），落 **ADR-005（ADR-v31-02）** 于 `tasks/phases/P2-data-layer.md`（命中「跨模块边界」触发项）。**三条解析路径**：旧格式计划条目（`sets`/`ballsPerSet` 非 nil）走同构兼容、不做球形展开（W3 前 10 份官方计划仍是此格式）；有 `perFormation` 逐球形展开，顺序 = 内容声明序（球形 1 轮 1 → … → 球形 N 轮 M），逐组 `targetBalls` = 该球形 `ballsPerRound`；8 条无序列 drill 回落 `defaultSets`/`defaultBallsPerSet`。**单球形一律不带 token**（契约 §4.1，`formationOptions` 仍只在 >1 球形返回非空）。`TodayDrillItem`/`ActiveDrill`/`CustomDrillItem` 均改为携带 `[PlannedTrainingSet]`，原 `sets`/`ballsPerSet` 退为派生只读；展示文案统一由 `volumeText`/`compactVolumeText` 产出（同构「N 轮 × N 球/杆」、异构「N 球形 · N 轮 · 共 N 球」），`DrillDetailView` 加副分类次徽章，`DrillListViewModel` 筛选命中主+副、**分组仍只按主分类**，`CustomPlanBuilderView` 双 stepper 改单「轮数」stepper + 球数只读。`StatisticsViewModel` **零改动**（统计只记主分类，已核对）。**验收证据**（全部落 `build/v31-w2-logs/` 与 `build/v31-w2-screenshots/`）：`make build` **SUCCEEDED**；聚焦 4 套 **88 例 0 失败**（含新增 `TrainingHomeViewModelTests` 9 例）；`make verify-gate` **FAIL 0**（内容未动）；模拟器实跑自由训练 + sqlite 直查 `DrillSet` 证展开顺序与逐组 `formationToken`/`targetBalls`；`QiuJi/Resources/` 与 `content/` 无本批 diff。⚠️ **真源事实更正**：§二 记 c013 逐球形杆数 (8,9)，但 W1b 落进 JSON 的两球形均为 `repetition` / `ballsPerRound: 10`（repetition 型球数是人工定量，非序列杆数），故 c013 只能证顺序与 token、**证不了异构球数**；同次实跑追加 `drill_c042`（10 / 5 异构）补齐。全库球数异构的多球形 drill 仅 c042/c053/c071 三条。**X-v31-2 已修复（返工 1 轮，主控打回「不接受该归因、不接受留到批外」）**：录入表格球形列把「球形2」显示成「…」。首轮归因「`lineLimit(1)` + 列宽」**被证伪**——同宽文本只有部分行截断，说明不是静态列宽。**真根因（UI 层级 dump 实测）**：球形列是行内唯一可变宽文本列却与纯数字列平分弹性空间，只多分到 1–2 pt；**SF Pro 比例数字「2」比「1」宽**，「球形1」固有 31.3 pt 放得下、「球形2」固有 **33.0 pt** 放不下 ⇒ 截为「…」（实测截断态文本宽 22.3 pt = 省略号宽），而 Menu 按钮框两种情况都是 46 pt，证明与行状态无关。**修法**：`BTFormationMenu` label 加 `.fixedSize(horizontal: true, vertical: false)` 取固有宽度，弹性数字列让出这 1–2 pt；⛔ 未调宽度常数 / 未改 `lineLimit` / 未缩字号。**证据**：`build/v31-w2-logs/build-x-v31-2-fix.log`（SUCCEEDED）、`focused-tests-x-v31-2-fix.log`（88 例 0 失败）、`ui-run-x-v31-2-fix.log`（实跑 passed）、截图 `build/v31-w2-screenshots/09-record-c042-formation-after-fix.png` 与 `08-record-c013-formation-after-fix.png`（修复前对照留 `x-v31-2-before/`）。**下一步：W3a / W3b 官方计划重写（10 份 `plan_*.json` 改存 dose，可并行）。**
- **问题集合 v31 W1a + W1b 内容批收官 ✅（2026-08-09，Content Engineer ×2，均返工 0 轮）**：全库 **83 条 drill 剂量标注 + 副分类**落地（W1a 43 条 fundamentals/accuracy/cueAction/forceControl；W1b 40 条 separation/positioning/specialShots/combined，含 v33 新增 c079–c084 与重写的 c060）。**每条只动 `sets` 与 `secondaryCategories`**，`git diff` 键统计证无第三处改动。**主控独立复算（不采信子智能体结论）**：83 条的 I6a（token 集合相等）/ I6b（sequence 型 `ballsPerRound` == 序列实测杆数）/ `defaultSets == Σ defaultRounds` **FAIL 0**；无 `perFormation` 的 8 条正好等于无序列清单（c008/c043/c059/c061/c065/c067/c068/c070）；护栏越界仅 4 条（c065=80、c067=90、c070=80 按局；c066=10 按次）均逐条附豁免理由。**mode 判定 12 个球形为 `sequence`**（c001/c062/c063/c072/c039/c042-manual02/c064/c069-manual02/c071-manual02/c079/c081/c082），其余 `repetition`。⚠️ **机械连续性指标不可信**（PD-029 同源）：录制时母球被人工搬动会把真链压成 0.00，而距离阶梯题（标记球逐档移除）反而显示 1.00 ⇒ mode 一律以 `description`/`standardCriteria` 语义为准，机械指标只作旁证。**副分类全库定稿 15 条**（c018/c020/c021/c030/c031/c042/c046/c050/c051/c069/c071/c076/c077/c078/c082），据内容剔除真源候选 c003/c004、增补 c050/c082（P2 待用户 W5 前终确认）。**P3 已拍板并落地**：c065 每局球数 7→**8**（己方 7 + 黑八，与 c070 对齐）；按局条目维持「每局一行」。**验收证据**：`make build` **SUCCEEDED**、`make verify-gate` **总计 FAIL 0**、聚焦测试 38 例 6 失败 = W0 基线原样（`pocket ''` ⛔ 未修绿），日志 `build/v31-w1a-logs/`、`build/v31-w1b-logs/`。**新增遗留 X-v31-1**：c005/c031/c035/c036 的 `description`/`criteria` 自称「走位链」被序列证伪——主控用「第 i 杆 `before.cueBall` == 第 i−1 杆 `after.cueBall`（阈 0.005）」实测衔接率 0/3、0/12、0/7、0/8，对照组 c079 为 3/3；判 `repetition` 正确但**错误元数据仍在内容里**，⛔ 不在 v31 范围（内容批只动 `sets`），另立批次修，⛔ 不得反改序列迁就文案。**W4 追加三项**：I10→**I11** 编号更正（契约 §7 为准）、必补门禁 `MODEL_SPEC` 的 `perFormation`/`secondaryCategories`（现为 I10 盲区，FL-029 第 3 条）、`repetition` 10–15 球与 16 档阶梯（c020/c078）的口径张力。**下一步：W2 运行时绑定（dose 解析 + 多球形组展开 + 录入/展示/构建器 UI），本方案最大批，建议新会话开工。**
- **问题集合 v31 W0 横切基建 ✅（2026-08-09，Data Engineer + iOS Architect）**：文档 + 数据结构一次到位，⛔ 未动任何 drill/plan JSON 内容值（那是 W1x/W3x）。**契约升 v2.0**（非真源写的 v1.8——1.8 已被 v30 X-1 占用、最新 1.9，故进位并在版本记录注明）：新增 §3.3 多分类口径（主分类单值 + 副分类 ≤1、**统计只记主分类**故统计层零改动、不改目录不二次登记 index）、§5.6 剂量口径（`perFormation` 球形级、`sequence`/`repetition` 二分、sequence 型每轮球数**锁死 = 序列实测杆数**、总量护栏 40–60 球轮数向下取下限 1、无序列 drill 人工定量豁免）、§6.6 绑定模型（计划只存强度系数、激活时解析、落 `DrillSet` 快照，**token 升级为计划外键**⇒ §6 规则 2 删除连带扩范围）；§7 **I6 定稿**拆 I6a/I6b（实现落 W4）+ 新增 **I11 官方计划可解析**（⚠️ 真源 W4 称其「I10」与既有 I10 模型可解码性**编号冲突**，契约顺延为 I11）；§9 记 **D10–D14**。**代码**：`DrillContent.secondaryCategories`、`DrillSetsConfig.perFormation`（均可选，旧 JSON 照常解码）、`PlanDrillRef.dose`（W3 前与旧 `sets`/`ballsPerSet` **并存**，W5 删旧分支）、`DrillContentService.decodeDrillFromBundle`/`formationCount` 同步入口；顺手修 `PlanContentService` 两处 `try?` 吞解码错误（FL-029）。**SwiftData V3**（`CustomPlanDrill.sets/ballsPerSet → roundsPerFormation`）走**自定义**迁移阶段（轻量迁移读不到已删除的旧列），折算 `rounds = max(1, sets/球形数)`，`CustomPlan(Drill)` 旧形状下沉为 `QiuJiSchemaV2` 嵌套历史快照 ⇒ **ADR-004（ADR-v31-01）** 落 `tasks/phases/P2-data-layer.md` 末尾。**验收证据**（全部落 `build/v31-w0-logs/`）：`make build` **BUILD SUCCEEDED**；`make verify-gate` **总计 FAIL 0**；聚焦测试 50 例失败 6 条断言 = 改动前实测基线原样（全为 `pocket ''`，⛔ FL-027 不得修绿），另 41 例计划/训练回归全绿；V2→V3 **零丢失实证** 2 例（落盘 V2 库 → 当前容器打开，6/1=6、6/2=3、2/3→1 三分支命中，`PRAGMA table_info` 证就地改列非删库重建）。**底账重取**（`scripts/v31_w0_baseline_stats.py`）：drill **72→83** 条、多球形 **18→19**、无序列 **10→8**（与门禁豁免名单一致）、从未被计划引用 **31→37**（c079–c084 全在内），已回写真源 §二与排期前置失败基线。**下一步：W1a / W1b 内容批（剂量标注 + 副分类，可并行）。**
- **动作库筛选去掉「有精讲」✅（2026-08-09，SwiftUI Developer / DR-067）**：全库 83 条均有精讲，该筛选项无区分度；`DrillBadgeFilter` 移除 `hasTutorial`，菜单保留全部角标 / 单杆技术课 / 应用课 / 规则流程课 / 已完成。球种与三类精讲种仍有命中故保留。
- **动作详情页视觉层级重构 ✅（2026-08-09，SwiftUI Developer / DR-066，三次点验修订）**：共享 `DrillDetailView` 保留导航+正文标题；难度徽章移到正文标题 trailing，球种/分类留下一行，标题信息组以弱分隔线收尾而不加卡框/装饰图标；训练要求三子项统一图标语法，Dark 卡补语义描边。`DrillSceneView` HUD 仅回放时动态插入球桌下方；播放控制约 2 秒自动隐藏，轻点台面只唤出，空闲/暂停常显。横向顶视废除 `1.81 + 0.77` 固定裁切，改按 USDZ 实测外框与容器双轴自适应并留 1.2% 安全余量，六袋四库完整可见；全部 Drill 详情页与训练页复用球桌同步生效。证据：`make build` SUCCEEDED；ShotTableLayout/HUD 单测 11/0；Light/Dark 布局 UI 各 1/0；播放控制/HUD UI 1/0且不遮挡 frame 不变量通过；证据位于 `build/drill-detail-{before,controls-framing,controls-final}*`。
## R0 Design System Upgrade — ✅ 已完成

> **前置**：UI 设计全部完成。P4 暂停于 T-P4-04。详见 `tasks/phases/R0-design-system.md`。

| 任务 | 状态 |
|------|------|
| T-R0-01 创建 UI-IMPLEMENTATION-SPEC.md | ✅ 已完成（2026-04-05）|
| T-R0-02 Token 值审计 | ✅ 已完成（2026-04-05）|
| T-R0-03 BTButton 补全 7 种样式 | ✅ 已完成（2026-04-05）|
| T-R0-04 新建组件 Batch 1（导航/布局） | ✅ 已完成（2026-04-05）|
| T-R0-05 新建组件 Batch 2（训练） | ✅ 已完成（2026-04-05）|
| T-R0-06 新建组件 Batch 3（反馈/分享） | ✅ 已完成（2026-04-05）|
| T-R0-07 校验与更新已有组件 | ✅ 已完成（2026-04-05）|
| QA-R0 Phase R0 验收 | ✅ 附条件通过（2026-04-05）— 3 项 P2 改进记入下一迭代 |

---

## P1 Foundation — 部分完成（阻塞项已推迟）

| 任务 | 状态 |
|------|------|
| T-P1-01 Xcode 项目初始化 | ✅ 已完成 |
| T-P1-02 SPM 依赖初始配置 | ✅ 已完成（ADR-001）|
| T-P1-03 Design System Token | ✅ 已完成 |
| T-P1-04 5 Tab 导航骨架 | ✅ 已完成 |
| T-P1-05 登录流程 UI | ✅ 已完成 |
| T-P1-06 Sign in with Apple | ✅ 已完成 |
| T-P1-07 REST API + 手机验证码登录 | ⏳ 待开始（H-15 推迟） |
| T-P1-08 微信登录集成 | ⏳ 待开始（H-05 推迟） |
| T-P1-09 AppConfig + .gitignore | ✅ 已完成 |
| QA-P1 P1 验收 | ⏳ 待开始 |

---

## P2 Data Layer — 功能完成，待人工验收

| 任务 | 状态 |
|------|------|
| T-P2-01 SwiftData Schema | ✅ 已完成（2026-03-29）|
| T-P2-02 Local Repository | ✅ 已完成（自动化测试 42/42）|
| T-P2-03 ~~CloudKit~~ | ✅ 已取消（ADR-002）|
| T-P2-04 Bundle Fallback JSON | ✅ 已完成（2026-03-29）|
| T-P2-05 后端用户数据同步 | ✅ 已完成（2026-03-29）|
| T-P2-06 匿名用户本地模式 | ✅ 已完成（2026-03-29）|
| T-P2-07 SyncQueue | ✅ 已完成（2026-03-29）|
| QA-P2 验收 | ✅ 附条件通过（2026-04-10）— 235/235 自动化 + 31/31 人工测试；3 issue（FL-001/FL-002/B-03）已修复 + Code Review 确认；条件：用户重建后确认修复生效 |

---

## P3 Drill Library — ✅ 附条件通过

| 任务 | 状态 |
|------|------|
| T-P3-01 ~ T-P3-11 | ✅ 全部已完成（2026-03-29，自动化测试 47/47）|
| QA-P3 验收 | ✅ 附条件通过（2026-04-11）— 自动化 47/47；人工 TP-P3 50/53 执行，3 项失败（FL-003/FL-004/FL-005）已修复并验证；设备矩阵/可访问性/性能待补测 |

---

## P4 Training Log — ✅ 附条件通过

| 任务 | 状态 |
|------|------|
| T-P4-01 官方训练计划 JSON | ✅ 已完成（2026-03-29）|
| T-P4-02 训练 Tab 今日计划视图 | ✅ 已完成（2026-03-29）|
| T-P4-03 官方计划列表与详情页 | ✅ 已完成（2026-03-29）|
| T-P4-04 开始训练流程 | ✅ 已完成（2026-03-29）|
| T-P4-05 训练中 Drill 记录界面 | ✅ 已完成（2026-04-05，使用 BTSetInputGrid + BTExerciseRow）|
| T-P4-06 心得备注输入 | ✅ 已完成（2026-04-05，匹配 code.html 设计，DR-004）|
| T-P4-07 训练完成总结页 | ✅ 已完成（2026-04-05，匹配 code.html 设计，使用 BTLevelBadge 等 R0 组件）|
| T-P4-08 TrainingSession 持久化 | ✅ 已完成（2026-04-05，saveTraining 已在 T-P4-04 实现并测试通过 30/30）|
| T-P4-09 自定义训练计划 | ✅ 已完成（2026-04-05，匹配 code.html 设计，DR-007）|
| T-P4-10 TrainingShareView（新增） | ✅ 已完成（2026-04-05，BTShareCard 升级匹配 code.html + 定制面板 + 分享入口）|
| QA-P4 验收 | ✅ 附条件通过（2026-04-11）— 自动化 235/235 + 人工 TP-P4 92/98；FL-006/FL-007/FL-008 已修复，FL-009 P3 延后 |

---

## P5 Angle Training — ✅ 已完成

| Phase | 状态 | 备注 |
|-------|------|------|
| P5 Angle Training | ✅ 已完成（2026-04-05） | 代码审查 + 设计对齐 + 22 测试通过 |

---

## P6 History + Statistics — ✅ 已完成

| 任务 | 状态 |
|------|------|
| T-P6-01 历史 Tab 日历视图 | ✅ 已完成（2026-04-05）— BTSegmentedTab + 6 行日历 + 训练分类标签 + 设计对齐 |
| T-P6-02 训练详情页 | ✅ 已完成（2026-04-05）— Sheet 模态 + 统计横滚 + Drill 组明细 + 底栏操作 |
| T-P6-03 统计视图 | ✅ 已完成（2026-04-05）— BTTogglePillGroup + 三张统计卡片 + 左侧绿线装饰 |
| T-P6-04 训练频率柱状图 + 趋势线 | ✅ 已完成（2026-04-05）— Swift Charts BarMark + RuleMark，琥珀+品牌绿双色 |
| T-P6-05 各类别成功率对比 | ✅ 已完成（2026-04-05）— 2 列网格替代雷达图，环比变化 + 迷你柱状图 |
| T-P6-06 Freemium 历史查看限制 | ✅ 已完成（2026-04-05）— HistoryAccessController 60 天限制 + 锁定提示 |
| QA-P6 验收 | ✅ 附条件通过（2026-04-12）— 人工 TP-P6 日历/详情/动画/边界/性能全通过；统计 Pro paywall 正确生效（符合规格）；Pro 统计 UI + 60 天限制 e2e 待 TestFlight 补测 |

---

## P7 Subscription — ✅ 已完成

| 任务 | 状态 |
|------|------|
| T-P7-01 StoreKit 2 集成 | ✅ 已完成 — StoreKitService + Products.storekit 3 个 IAP |
| T-P7-02 订阅状态管理 | ✅ 已完成 — SubscriptionManager isPremium + Transaction.updates 监听 |
| T-P7-03 订阅页 UI | ✅ 已完成（2026-04-05）— 深色 #111111 全屏 + 金色编号功能列表 + 3 列方案卡 + 年订绿框推荐 |
| T-P7-04 恢复购买 | ✅ 已完成 — AppStore.sync() + 成功/失败 Alert |
| T-P7-05 Freemium 边界整合 | ✅ 已完成（2026-04-05）— 修复 AngleTestView limiter isPremium 同步 bug |
| QA-P7 验收 | ✅ 通过（2026-04-05）— 代码审查 + 234/234 自动化测试通过 |

---

## R-UI Existing Page Alignment — ✅ 附条件通过

> 详见 `tasks/phases/R-UI-alignment.md`

| 任务 | 状态 |
|------|------|
| T-RUI-01 TrainingHomeView 对齐 | ✅ 已完成（2026-04-05）— 今日安排卡片 + BTSegmentedTab 计划浏览 + 筛选 Chip + 固定底部按钮 + 空状态 |
| T-RUI-02 DrillListView + DrillDetailView 对齐 | ✅ 已完成（2026-04-05）— 灰色操作图标行 + 标签行 + darkPill/primary 固定底栏 + Pro 金色底栏 |
| T-RUI-03 ActiveTrainingView 对齐 | ✅ 已完成（2026-04-05）— 毛玻璃顶栏 4 图标 + 计划名进度条 + 5 键底栏带文字标签 + 橙色热身标记 |
| T-RUI-04 ProfileView + LoginView 对齐 | ✅ 已完成（2026-04-05）— 彩色圆底图标菜单 + 月度概览 + 游客警告/Pro 推广卡 + 三按钮登录 + 药丸验证码输入 |
| T-RUI-05 OnboardingView 对齐 | ✅ 已完成（2026-04-05）— 品牌绿圆底图标 + QJ Logo + 强制浅色 + 3 FeatureRow |
| QA-RUI 验收 | ✅ 附条件通过（2026-04-05）— D-1 已修复；8 项 P2 改进记入 P8 |

---

## P8 Polish & Release — 🔄 进行中

| 任务 | 状态 |
|------|------|
| T-P8-01 Privacy Manifest | ✅ 已完成（2026-04-05）— PrivacyInfo.xcprivacy 创建 + Xcode Target 添加 |
| T-P8-02 性能优化 | ✅ 代码审计通过（2026-04-06）— LazyVStack/Canvas/debounce 等已优化；4 项 Instruments 指标待人工验证 |
| T-P8-03 空状态与加载态全覆盖 | ✅ 已完成（2026-04-05）— BTShimmer 骨架屏 + 6 场景空状态/加载态全覆盖 |
| T-P8-04 首次引导流程完整版 | ✅ 已完成（2026-04-06）— 3 页 TabView + Capsule 页指示器 + 跳过/登录分页按钮 |
| T-P8-05 个人设置页 | ✅ 已完成（2026-04-06）— SettingsView（球种+周目标）+ 账号注销 + 隐私政策链接 |
| T-P8-06 账号注销与数据删除 | ✅ 已完成（2026-04-06）— 在 T-P8-05 中一并实现（二次确认 + DELETE API + 失败重试）|
| T-P8-07 XCTest 核心流程测试 | ✅ 已完成（2026-04-06）— 235/235 通过（+1 CRUD update 测试）|
| T-P8-08 TestFlight 内部测试 | ⏳ 待开始 |
| T-P8-09 App Store 资产准备 | ⏳ 待开始 |
| T-P8-10 App Store 提交审核 | ⏳ 待开始 |
| T-P8-11 Dark Mode 全面通刷 | ✅ 已完成（2026-04-05）— 21 Token 双值验证 + 14 文件修复 + D-1~D-7 全部确认 |
| T-P8-12 人工测试计划更新与执行 | ✅ 已完成（2026-04-06）— TP-P2/P3/P4 更新 + TP-P5/P6/P7 新建 + H-17 人工执行项 |
| T-P8-13 R-UI QA P2 改进项 | ✅ 已完成（2026-04-05）— 8 项全部处理（P8-A~H，详见下方） |
| QA-P8 最终验收 | ⏳ 待开始 |

---

## 阻塞项

| 阻塞 ID | 影响任务 | 描述 | 负责方 |
|---------|---------|------|--------|
| H-05 | T-P1-08 | 微信开放平台资质 — 🔜 推迟至 App 主体开发完成后 | 人工 |
| H-15 | T-P1-07 | 腾讯云短信服务 — 🔜 推迟至 App 主体开发完成后 | 人工 |

---

## Phase 完成记录

| Phase | 完成日期 | 备注 |
|-------|---------|------|
| R0 Design System | 2026-04-05 | 附条件通过（3 项 P2 改进记入 P8 Polish）|
| P1 Foundation | — | 部分阻塞（H-05, H-15 推迟）|
| P2 Data Layer | 2026-04-10 | 附条件通过（FL-001/FL-002/B-03 已修复，待用户重建确认）|
| P3 Drill Library | 2026-04-11 | 附条件通过（FL-003/FL-004/FL-005 已修复；设备矩阵/可访问性/性能待补测）|
| P4 Training Log | 2026-04-11 | 附条件通过（人工 92/98 + FL-006/007/008 已修复；FL-009 P3 延后）|
| P5 Angle Training | 2026-04-05 | 代码审查 + 设计对齐 + 22 测试通过 |
| P6 History | 2026-04-12 | ✅ 附条件通过（人工 TP-P6 + 234/234 自动化；Pro 统计 UI + 60 天限制 e2e 待 TestFlight 补测）|
| P7 Subscription | 2026-04-05 | 5 任务完成 + SubscriptionView 设计对齐 + Freemium 全整合 + 234/234 测试 |
| R-UI Alignment | 2026-04-05 | 附条件通过（D-1 已修复；8 项 P2 改进记入 P8-13）|
| R1 UI 逐页审查 | 2026-04-06 | 11 份报告完成，145 项偏差（P0:0 / P1:33 / P2:112）|
| P9 Aiming Expansion | 2026-06-02 | QA-P9 通过；241/241 自动化 + 人工功能验收；FL-016 + PD-007 修复；T-P9-D-REVIEW/T-P9-00 收尾 |
| P8 Polish & Release | — | 仅剩人工：H-17 人工测试 / TestFlight / App Store 资产与提交 |

---

## R1 UI 逐页审查 — ✅ 已完成

> 详见 `tasks/phases/R1-ui-review.md` + `tasks/ui-reviews/UR-20260406-*.md`（11 份）

| 任务 | 状态 |
|------|------|
| T-R1-01 TrainingHomeView 审查 | ✅ 已完成（2026-04-06）— 10 项（P1:3 / P2:7）|
| T-R1-02 ActiveTrainingView 审查 | ✅ 已完成（2026-04-06）— 16 项（P1:3 / P2:13）|
| T-R1-03 TrainingSummary + ShareView 审查 | ✅ 已完成（2026-04-06）— 17 项（P1:3 / P2:14）|
| T-R1-04 Plans（List+Detail+Builder）审查 | ✅ 已完成（2026-04-06）— 18 项（P1:7 / P2:11）|
| T-R1-05 DrillLibrary 审查 | ✅ 已完成（2026-04-06）— 13 项（P1:6 / P2:7）|
| T-R1-06 AngleTraining 审查 | ✅ 已完成（2026-04-06）— 16 项（P1:1 / P2:15）|
| T-R1-07 History + Statistics 审查 | ✅ 已完成（2026-04-06）— 13 项（P1:2 / P2:11）|
| T-R1-08 Profile + Settings 审查 | ✅ 已完成（2026-04-06）— 13 项（P1:4 / P2:9）|
| T-R1-09 Onboarding + Login 审查 | ✅ 已完成（2026-04-06）— 7 项（P1:1 / P2:6）|
| T-R1-10 SubscriptionView 审查 | ✅ 已完成（2026-04-06）— 11 项（P2:11）|
| T-R1-11 全局 + 组件审查 | ✅ 已完成（2026-04-06）— 11 项（P1:3 / P2:8）|

**汇总**：全部 11 个审查任务完成，共发现 **145 项偏差**（P0: 0 / P1: 33 / P2: 112）。

---

## P9 Aiming Feature Expansion — ✅ 已完成（QA-P9 通过 2026-06-02）

> 详见 `tasks/phases/P9-aiming.md`

| 任务 | 状态 |
|------|------|
| T-P9-00 UI 设计交付文档更新 | ✅ 已完成（2026-06-02）— `09-UI设计交付文档.md` §3.3 补 5 页 + AngleHome 分组 + 对照表增强 + 导航树 + §7.5 |
| T-P9-D-01~06 UI 设计出图 | ✅ 已完成（2026-04-14，6/7 APPROVED） |
| T-P9-D-REVIEW 设计一致性审查 | ✅ 已完成（2026-06-02）— `ui_design/tasks/P9-REVIEW/consistency-review.md`，无 P1 偏差 |
| T-P9-01 SceneKit 场景基础设施 | ✅ 已完成（2026-04-14）— ADR-P9-01 |
| T-P9-02 数据层扩展 | ✅ 已完成（2026-04-14） |
| T-P9-03 AngleHomeView 导航重构 | ✅ 已完成（2026-04-14） |
| T-P9-04 瞄准原理页 | ✅ 已完成（2026-04-14） |
| T-P9-05 角度与打点动态关系页 | ✅ 已完成（2026-04-14） |
| T-P9-06 几何角度预测训练 | ✅ 已完成（2026-04-14） |
| T-P9-07 SceneKit 角度预测页（2D/3D） | ✅ 已完成（2026-04-14） |
| T-P9-08 SceneKit 角度预测增强 | ✅ 已完成（2026-04-14） |
| T-P9-09 进球点对照表增强 | ✅ 已完成（2026-04-14） |
| T-P9-10 浅淡球感页 | ✅ 已完成（2026-04-14） |
| T-P9-11 AngleHistoryView 增强 | ✅ 已完成（2026-04-14） |
| QA-P9 验收 | ✅ 通过（2026-06-02）— `tasks/qa-reports/QA-P9.md`；241/241 自动化 + 人工功能验收（用户确认）；修复 FL-016（几何训练 Freemium 闸门）+ PD-007（测试宿主/模块名，恢复命令行测试） |

---

## 执行顺序

```
R0 ✅ → P4 ✅ → P5 ✅ → P6 ✅ → P7 ✅ → R-UI ✅ → R1 ✅ → P9 ✅ → P8 🔄（仅人工）
```

---

## 下一步

- **【P18 发布收敛 — 当前主线】（2026-07-03 立卡）**：按 `tasks/phases/P18-release-convergence.md` 七批执行，**B1 ✅（2026-07-03）**，当前批 **B2**（T-P18-05 组件下沉 → T-P18-10 ShotControlBar，预估 2–3 会话）。人工并行项：**H-19 App 备案今天启动**、H-18 音效素材、H-09 隐私政策、TP-P7、ADR-P10-09 手感验收。
- **【P12 内容体系与理论挂接 — 规划已立，待执行】（2026-06-14，ADR-P12-01）**：单一真源 [`curriculum-map.md`](curriculum-map.md) + phase 卡 `tasks/phases/P12-content-system-theory.md`。**待用户拍板**：地图 §6 三参数（每格配额 / L4 是否进 v1.0 / 系统训练模式定位）。**第一刀（建议新会话）**：c042 竖切——扩 `DrillContent.theoremIds/moduleIds?` + `TutorialSection.theoremRefs?`（可选向后兼容）、vendor `16/contracts/*.json` 进 `Resources/Theory/`、c042 精讲三层披露 + 建 T01/T03 理论详情页（复用 `AngleTrainingScene` 标注图）+ 学习区"球理"入口卡、建 `THEORY-CONSUMPTION-LOG.md` 翻 16 中枢卡 v1.0 final（达成 16↔13 闭环）。
- **✅ 动作库内容管线 + 击球意图 schema 雏形（2026-06-04 完成）**：见上方 P10 Track A 条目 + `tasks/phases/P10-physics-content-pipeline.md`（ADR-P10-01）。**下一步**：~~① 把 `shotIntent` 推广到全量 72 条~~ ✅（见下）；② 废弃 `BTDrillPreviewPlayer` 的 PNG 帧序列、动画统一由烘焙轨迹驱动；③ 展示三件套（GIF 烘焙轨迹 / 精讲参数化对错对比 / 视频降级为真人身体动作）统一重构；④ 多杆球（`obstacles`/多 shot）+ **翻袋/吃库瞄准**烘焙支持（当前 v1 直瞄无法表达 c055/c057 等特殊球路）。
- **✅ shotIntent 全量补齐（2026-06-04，iOS Architect 调度 8×content-engineer 并行，DR-017 后续）**：为剩余 67 条 Drill 并行补 `shotIntent`（8 子智能体各管一 category，按描述/杆法推断 velocity+spin），+5 试点 = **72/72 全有 shotIntent**、JSON 全合法。新增可行性扫描 `test_scanFeasibility`：**67/72 引擎干净落袋**；修 2 条几何颠倒（c039/c062）+ 6 条 follow 误推乱弹（改中心球）。**5 条特殊球路**（c055 翻袋/c057 K球吃库/c058 贴库/c061 解球/c066 开球）单杆直瞄无法干净进 → c055 退回手画、余渲染真实物理近失（v1 烘焙器不支持翻袋/吃库瞄准，记 H-11）。72 缩略图全量重烘焙。详见 H-11 § shotIntent 全量补齐 待物理核查。
- **✅ P10 Track B-1 物理保真进球管线（2026-06-04 完成，ADR-P10-02）**：见上方 Track B-1 条目。USDZ 实测证伪「jaw 放错 17mm」预设（几何自洽）。用户复评后拒绝"放宽捕获半径"偷懒做法，改建**真实袋口物理（喉腔模型）**：jaw 库 + 实测 jaw 尖端挤出的喉腔侧壁/后壁（可反弹）+ 物理落袋孔，rattle 由几何涌现；配套稳健化闭环求解（采样寻优最优接触点）+ 画面=物理（objectPath 真实模拟、轨迹基进袋判定）。E-solver/中袋/c002 全绿，291/291。详见 `tasks/qa-reports/PHYSICS-PROBE.md` §USDZ 实测标定。
- **【P10 物理标定 — 剩余】**：① 中袋 jaw mouth ±0.035→对齐实测 ±0.046（非阻塞微调）；② **常量标定**（e_b/台呢库边摩擦/恢复系数，**需真实球俯拍视频**，用 `PhysicsBenchmarkTests` 钉死）；③ 朴素瞄准 E-geom 3/5 属窄喉口掠角真实物理（产品用求解器规避，非闸门）。

0. **全局字体密度优化已完成**（2026-05-26，DR-014 / PD-006）：
   - Typography Token 全局下调（btDisplay 48→44 / btDisplaySmall 36→30 / btLargeTitle 34→32 / btChapterNumber 32→26 / btTitle 22→20 / btTitle2 20→18 / btTitleMedium 19→17 / btStatNumber 28→24）
   - 页面级局部修正：TrainingHomeView 今日 Drill 卡标题降级 + 序号轻量化 + issueThumbnail 硬编码改 Token；PlanDetailView statCell 数字 + 描述 lead 句降权
   - SKILL.md 与 UI-IMPLEMENTATION-SPEC.md 字体规范同步更新，新增「使用原则」四条避坑指引
   - 实施日志新增 DR-014 + PD-006（双层修法模式）
   - 构建验证：`make build` 通过；ReadLints 无错误
   - **待人工复核截图**：训练首页、动作库、计划列表、计划详情、角度首页、我的、训练总结

1. **P9 实现任务全部完成**（2026-04-14）：
   - Wave 1：SceneKit 基础设施 + 数据层 quizType + 导航重构（7 功能分组）
   - Wave 2：5 独立页面（瞄准原理 / 角度与打点 / 几何训练 / 对照表增强 / 浅淡球感）
   - Wave 3-4：SceneKit 2D/3D 角度预测 + 增强（训练类型/自由练习/幽灵球/瞄准线）
   - Wave 5：AngleHistoryView quizType 筛选增强
   - **待人工验收**：模拟器运行验证 SceneKit 加载 / 2D↔3D 切换 / 角度计算 / Dark Mode
   - **ADR-P9-01**：SceneKit 引入决策已记录
2. **R1 审查 + 修复 + DrillLibrary 改造已完成**（2026-04-06）：
   - 11 份审查报告 → 145 项偏差 → 10 组并行修复 → 235/235 测试通过
   - **DrillLibrary 参照训记全面改造**（DR-011）：
     - 新建 `BTMiniTable.swift`（缩略图 Canvas：球径 3x + 路径 2x + 袋口高亮 + 无库边）
     - `BTDrillGridCard` 使用 BTMiniTable + 等级徽章/PRO/收藏叠加层 + 底部渐变
     - `DrillListView` 改为训记风格：左侧分类侧边栏（72pt）+ 右侧 2 列网格
     - `DrillDetailView` 新增：备注输入卡、训练维度 5 进度条、查看精讲按钮、真人示范占位
     - `BTDrillListSkeleton` 更新为 2 列网格骨架
   - **延后项**：TrainingHome「即将到来」Section、DrillRecordView 休息设置行、BTShareCard 备注 toggle、History 新增功能按钮
   - **下一步**：人工测试（H-17）→ TestFlight
2. **P8 待执行**：
   - **H-17 人工测试执行**：🔄 5/6 已执行（TP-P2/P3/P4/P5/P6 ✅），**仅剩 TP-P7 订阅**（需 StoreKit sandbox/真账号 — [HUMAN]，约 30 分钟）
   - T-P8-08（TestFlight 发布 — [HUMAN]）
   - T-P8-09（App Store 资产准备 — [HUMAN]）
   - T-P8-10（App Store 提交 — [HUMAN]）
   - QA-P8 最终验收
3. **人工测试**：6 份测试计划已就绪（TP-P2~P7），待人工在模拟器/真机上执行（见 H-17）。
4. **后端部署** ✅（2026-03-29）：已部署至 106.54.3.210:3000，72 条 Drill 已 seed。
5. **知识累积机制**：`tasks/IMPLEMENTATION-LOG.md`（FL/DR/PD 三类条目）+ `UI-IMPLEMENTATION-SPEC.md` Changelog 节跨会话保持实施知识。

---

## 已完成 Phase 归档

当某一 Phase **全部任务**均为 ✅ 后：

1. 将任务明细表剪切至 `tasks/archive/Pn-completed.md`。
2. 在「Phase 完成记录」表中填写完成日期。
3. 从下一会话起仅读当前 Phase 任务卡。
