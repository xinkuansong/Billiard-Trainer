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

- **动作库筛选去掉「有精讲」✅（2026-08-09，SwiftUI Developer / DR-067）**：全库 83 条均有精讲，该筛选项无区分度；`DrillBadgeFilter` 移除 `hasTutorial`，菜单保留全部角标 / 单杆技术课 / 应用课 / 规则流程课 / 已完成。球种与三类精讲种仍有命中故保留。
- **动作详情页视觉层级重构 ✅（2026-08-09，SwiftUI Developer / DR-066，三次点验修订）**：共享 `DrillDetailView` 保留导航+正文标题；难度徽章移到正文标题 trailing，球种/分类留下一行，标题信息组以弱分隔线收尾而不加卡框/装饰图标；训练要求三子项统一图标语法，Dark 卡补语义描边。`DrillSceneView` HUD 仅回放时动态插入球桌下方；播放控制约 2 秒自动隐藏，轻点台面只唤出，空闲/暂停常显。横向顶视废除 `1.81 + 0.77` 固定裁切，改按 USDZ 实测外框与容器双轴自适应并留 1.2% 安全余量，六袋四库完整可见；全部 Drill 详情页与训练页复用球桌同步生效。证据：`make build` SUCCEEDED；ShotTableLayout/HUD 单测 11/0；Light/Dark 布局 UI 各 1/0；播放控制/HUD UI 1/0且不遮挡 frame 不变量通过；证据位于 `build/drill-detail-{before,controls-framing,controls-final}*`。
- **上下文瘦身 + 进度文档体积门禁 ✅（2026-08-09，Orchestrator）**：PROGRESS.md 353→33 KB、hub 状态卡 322→36 KB（历史零删除，移入 `tasks/archive/PROGRESS-当前状态-归档.md` 与 hub `projects/archive/13.billiard_trainer-历史.md`）；`00-orchestrator.mdc` / `00-project-hub-sync.mdc` 写入滚动归档纪律 + 轻量任务分流；新增 `scripts/verify_doc_size.py` + `make verify-doc-size` 并挂入 pre-push（>12 条或 >100 KB 拦 push，构造性用例验证过会真报错；钩子已重装实跑通过）。
- **H-23 审核·c082 ✅（2026-08-09，Content Engineer）**：用户裁定标题「横向色彩围 8」→**「横向蛇彩围 8」**；规则口径钉死为「打一颗彩球 → 打 8 号 → 8 号复位」交替（精讲正文本就正确）。已改 `nameZh` / `description` / `coachingPoints` / `standardCriteria` / `sets.defaultBallsPerSet` 7→12；序列与 DrillBoards 文件名同步（token 仍 `manual01`）。`make verify-gate` **总计 FAIL 0**。销账 v33 L6.1/L6.2。**下一步：继续 H-23 逐条审核。**
- **问题集合 v33 收官 ✅（2026-08-09，W0–W5 全部完成；Content Engineer / Tutorial Writer）**：7 条新录序列全部落地。**7 条 drill 状态**：`c079` 四球走位 ✅（animation 重标 + 4 逐杆节精讲，走位链）、`c080` 上下半台走位 ✅（4 逐杆节）、`c081` 四球同袋叫位 ✅（4 逐杆节）、`c082` 横向色彩围 8 ✅（**12** 逐杆节）、`c083` 吃库分离角 ✅（8 逐杆节，独立阶梯混合式）、`c084` 不吃库分离角 ✅（8 逐杆节，同上）、`c060` 安全球布置 ✅（**W5**：`tutorialKind` `singleShot`→`multiShot`，4 段 legacy 墙文重写为 **12 节 / 8 逐杆节**，`sections` 平铺不用 `formations`，标题按 D-v33-3 折中式 `第N杆：<场面名>`）。**W5 关键事实**：合并后 8 杆是**八个互不相干的防守场面**（台上球 1–5 颗逐杆换，母球起点在成对两杆间复用），⛔ 未写成走位链、⛔ 未指认胜负手；按 D-v33-2 如实说明**四杆有球落袋**（合并后第四/五/六/七杆）是顺带结果而非成功判据；⚠️ **口径更正（L11）**：§2.1「8 杆全 freeAim」不成立——第五杆 `targetKey=_1`/`pocket=topCenter`（左侧中袋），其余 7 杆才是自由瞄准。**验收证据**：`verify-gate` **C4 72→73 通过 / 待迁移 11→10 / 不一致 0**、I5 73、I10 84、**总计 FAIL 0**；`make build` **SUCCEEDED**；聚焦测试 `DrillContentValidationTests` + `DrillListViewModelTests` 38 项 6 处断言失败 = 既有 `pocket ''` 一条用例（c045/c049/c054/c059/**c060**/c061），对 W0 基线**零新增失败**，c060 该失败⛔按 §七 保留未修绿；日志 `build/v33-w5-logs/`。**⚠️ 未验证**：模拟器只取到启动首屏（`build/v33-screenshots/01-launch.png`），动作库 83 条列表与详情页精讲的**人工目视导航未完成**——`idb` 二进制环境损坏（pyexpat 符号缺失）、`osascript` 取不到 Simulator 窗口（无辅助功能权限）；替代证据为 `DrillListViewModelTests` 18/18 全绿（含 83 条计数断言）与 I10 解码通过 84。**变更文件**：`QiuJi/Resources/Drills/specialShots/drill_c060.json`（仅 `tutorial` 字段，其余 16 个顶层键 `repr()` 级未变）、`问题集合_v33.md`（W5 行 ✅ + §七 L2 结论 / 新增 L11 + §九 v33.1）、`tasks/IMPLEMENTATION-LOG.md`（**PD-029**）、`.cursor/skills/tutorial-authoring/SKILL.md`（§第1步 硬约束 + Changelog v1.1）、`tasks/PROGRESS.md`、hub 状态卡。**新增 PD-029**：`tutorial_digest.py` 的「开局布局 母球」读序列 `initial` 占位值（c079/c080/c060 皆为 `0.300/0.300`），与首杆 `before` 及 `initial.png` 三方不符；「形态判定」「击打顺序与袋口」在多杆 freeAim 序列上退化却照常给结论 ⇒ 派生字段必须交叉验证、冲突即上报（已回写技能）。**遗留待用户裁定**：**L2**（`新增训练动作.md` 5 条防守要点 vs 8 个场面覆盖不全——要点 2「母球藏在自己球后面」与要点 4「吃库踢死 + 留袋口 + 贴住自己球」**无法证实**，判定它们需要遮挡关系与吃库库数，事实清单两者皆无；第一/二/三/八杆四个场面未对应任何原始要点。精讲按实测写，⛔ 未反向编造情节 ⇒ 要么补录盘面、要么改写要点口径）、**L11** 口径更正、L1 c066 空序列、L6 / L9 / L10 元数据与实测不符、L3 中袋坐标文档笔误、L4 缩略图全量烘焙连带改动、L5 `shotIntent` 仍空、L8 逐杆库数仍未断言。**下一步：v31（`sets` / 副分类 / 训练量口径定稿，⚠️ 必须把 c079–c084 + c060 这 7 条纳入范围）；本轮改动已提交 `5771d04`（62 文件 / +8033 −40，工作区已清空）。**
- **问题集合 v33 立档 ✅（2026-08-09，纯文档，Orchestrator）**：新建 `问题集合_v33.md` v33.0——「7 条新录序列落地：出片回填 + animation 重标 + 精讲撰写」真源。用户已完成编排台录制，`content/position_play/sequences/` 新增 9 个未跟踪序列（c079/c080/c081 各 4 杆、c082 12 杆、c083/c084 各 8 杆、c060 两球形各 4 杆、c066 0 杆空序列）。**拍板 D-v33-1～3**：① c060 两球形**合并为一条 8 杆序列**（`manual02` 的 4 step 原样追加进 `manual01` 后改名 `-8杆`、删 `manual02`，token 保持 `manual01`）——依据是实测发现两序列**内部每一杆盘面各不相同**（球形1 第1杆 `_1/_8/_9`、第2杆 `_1/_2/_8`、第3杆仅 `_8`、第4杆 5 颗；全 8 杆 `targetKey`/`pocket` 皆空串 freeAim），本就是 8 个独立防守场面而非走位链，拼接属机械操作不产生新坐标；备选「留两序列 + 精讲写一个球形」会让 C4 FAIL（`verify_tutorial_sync.py:330` 直接比球形数/杆数）。② 4 杆有球进袋（原球形2 第1/2/3 杆、球形1 第4 杆）**保留**并在精讲如实说明「防守判据是留下什么局面、进球是顺带结果」（契约 §8.5 已认定安全球成功判据非进袋，故不触发 digest 红灯）。③ 8 场面节标题用**折中式 `第一杆：<场面名>`**，⛔ 本轮不改 `SHOT_SECTION_RE`（`verify_tutorial_sync.py:95` `^第.+杆`）与 `isShotStructureTitle`（`DrillTutorialView.swift:157-160`）——改成「场面一：…」会双向踩坑（C4 数出 0 杆 → FAIL 阻塞 push；App 主结构识别失效 → 丢编号图标与字号层级），横切统一另立批次；§8.6 已登记该标题歧义故不算新增偏差。**⚠️ 门禁基线实测更正（2026-08-09）**：`--only C4 I5 I8 I9 I10` **总计 FAIL 0**——**I9 已因录制自行转绿**（违规 0，此前记录的「I9 FAIL 6」已不成立），转而出现 2 条提示「c060/c066 豁免已可解除（已有序列）」⇒ 棘轮要求从 `i9_no_sequence_exempt` 删除（10→8，W0/E3）；I8 提示 9 条上游序列 Bundle 未同步 ⇒ 待 `make tryout-sync`（90→**98**，content 现 99 条 `drill_c*` 合并后 98）；C4 不一致 0，c060 落 warn「legacy 无逐杆节待迁移」，c079–c084 因无 `tutorial` 不进 C4——**一旦写带 `第N杆` 标题的精讲，C4 立刻按杆数强校验**。**批次**：`W0 合并+全管线出片回填+豁免收紧+测试基线实测（grok-4.5 快）→ W1 六条 animation 按序列重标+缩略图（opus 5.0，几何敏感必读 geometry-spatial-reasoning）→ W2 c079/c081 走位链精讲（opus，建语感基准）→ W3 c080/c082 → W4 c083/c084 独立阶梯混合式 → W5 c060 由 singleShot 重写为 8 逐杆节 + 收尾回写`（W3/W4 可并行，W5 压尾）。模型路由已按 `01-subagent-model-selection` 写入批次表，后续会话不再重复询问。**排期声明**：v33 **先行于 v31**——v31 的 R1 副分类 / R2 训练量上调 / I6 `sets` 口径会覆盖本轮 7 条 drill，v31 执行时**必须把 c079–c084 + c060 纳入范围**（现值已列入 v33 §2.2），v33 各批⛔不得自行改 `sets`。**遗留**：L1 c066 已录 0 杆空序列（渲不出片、无法写逐杆精讲），本轮不处理待用户裁定补录/只留盘面/恢复豁免；L2 原文档 5 条防守要点 → 合并后 8 场面非 1:1，W5 若语义有出入须如实上报。**已知失败基线（⛔ 不得修绿，FL-027）**：`test_allDrills_pocketValueIsValid`（c045/c049/c054/c059/c060/c061 `pocket ''`，契约 §8.16）+ c042 两条 `shotIntent` 存量债；完成标准一律「聚焦测试 + 基线对照」，⛔ 不写全量全绿，且⛔ 不照抄 v31 文件头「56 项」（W0 现场重测）。**下一步：开工 W0（c060 合并 → tryout-sync → position-export → import 回填 → I9 豁免 10→8 → 落测试基线）。**
- **新增训练动作骨架 6 条 ✅（2026-08-08，Content Engineer）**：按用户素材清单 `新增训练动作.md`（抖音截图，11 个盘面参考）建 drill 骨架——走位 4 条 `positioning`（**c079** 四球走位 `comboPosition` / **c080** 上下半台走位 `halfTable` 新 sub / **c081** 四球同袋叫位 `comboPosition` / **c082** 横向色彩围 8 `snakeDrill`）+ 分离角 2 条 `separation`（**c083** 吃库分离角 `cushionSeparation` 新 sub / **c084** 不吃库分离角 `directSeparation` 新 sub）。防守 5 条按用户裁定**并入既有 `drill_c060`「安全球布置」**（`specialShots`/`safety`）作 5 个 formation，本轮不动 c060，等用户录完序列一起改（届时可从 `i9_no_sequence_exempt` 摘掉 c060——棘轮正向收紧）。**⚠️ 骨架的诚实边界**：① 序列尚未录制，故 `animation` 是**统一的中性占位直球**（非按截图反推坐标），已用 `generator: "skeleton/pending-recording"` 打标可 grep；录制后必须按序列首杆重标（契约 §1.1 推论 4）。② **不写 `tutorial`、不写 `shotIntent`、不写任何 `image`**——无序列时写逐杆节等于编造内容；`image` 引用会顶破 C3 失效引用基线 0。③ **已按用户要求登记 `index.json`**（首轮曾因 I9 而不登记，用户反馈「动作库里没看到」后改判——**这是我的取舍失误：登记与否直接决定用户能否看到与能否在批量出片台录制，本该在动手前就问**）。登记的连带代价已实测并接受：**`verify-gate` 的 I9 现 FAIL 6**（6 条新 drill 无序列）⇒ **录完序列前 push 会被 pre-push 钩子拦住**（本地 build / run / 测试不受影响）；⛔ 未加 `i9_no_sequence_exempt` 豁免——该名单语义是「本质录不出序列」的永久豁免，塞待办进去等于污染棘轮。同步把写死计数 **77→83** 改到位（`DrillContentValidationTests` 2 处 + `DrillListViewModelTests` 4 处；曾误改成 84——把 I10 的 84 当成 drill 条数，那个数含 `index.json` 自己，实测 83 后修正）。**⚠️ 登记后的可见形态**：列表卡缩略图缺 `DrillThumbnails/*.png` → 台呢占位；详情台面演示会播占位直球；「查看精讲」自动隐藏（`tutorial == nil`）；「上手试打」回退占位 `animation`。**验收证据**：① `verify_tutorial_sync.py --gate` = **仅 I9 FAIL 6**，其余全绿（I10 通过 **84** = 83 drill + index，证 6 条新文件均可解码；C3 失效 0/基线 0；C4/I5/I7/I8 未变动）。② 聚焦测试 4 套 53 用例，**失败用例集合与 HEAD 净树 worktree 基线逐条相同**（`DrillBoardBuilder.test_c042…` / `DrillContentValidation.test_allDrills_pocketValueIsValid`〔c045/c049/c054/c059/c060/c061 `pocket ''`〕/ `DrillTryoutBoardStore.test_briefLines_withoutFormation_unchanged`，均为 c042 与 legacy `pocket ''` 既有债）⇒ **零新增失败**；其中 `test_allBundledDrills_produceValidBoards` 在含新 6 条下**通过**，`test_loadDrills_totalDrillCount` 断言 83 通过（证 6 条真进列表）。日志 `build/c079-logs/{tests-r2,baseline-tests,uitest}.log`。③ `make build` SUCCEEDED + `make run` 已装模拟器。**下一步（用户）**：录制 6 条序列 + c060 的 5 个防守形态 → 回填出片 + `make thumbnails` → 按序列重标 `animation`/写 `shotIntent` + 写精讲 → I9 转绿后方可 push。
- **问题集合 v32.2 ✅（2026-08-08）**：理区改为 **12 张详情卡直达**（`TheoryCatalog` 派生，无「球理」总卡）；分篇 glyph；UITest 点卡标题。证据 `build/v32-2-build.log` + `build/v32-2-logs/uitest-focus.log`（P5 + V30W0 **3/0**）。真源 v32.2 / DR-065 修订。
- **问题集合 v32 全部收官 ✅（2026-08-08，v32.1→v32.2）**：五分类学→理→练→打→解；学区去球理；理区 12 卡。**下一步：v30 W5 或目视复验理区。**
- **问题集合 v32 立档 ✅（2026-08-08，纯文档）**：真源 `问题集合_v32.md`。

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
