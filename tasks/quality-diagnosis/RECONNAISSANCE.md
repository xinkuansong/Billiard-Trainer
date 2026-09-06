# App 质量诊断前期摸底

日期：2026-09-05。状态：首轮结构盘点与定向抽查完成；完整意图清单、环境盘点和正式测试方案仍待完善。

## 结论及证据边界

项目已有丰富规格、决策和测试资产，适合在现有基础上组织诊断。当前最先需要解决的是预期来源的新旧分层、测试可信度分级、运行副作用隔离，而不是直接全量跑测或重新建设测试体系。

本轮仅盘点路径、读取选定文档段落与代码，未运行 App、构建、自动化、后端接口或模拟器。下面的代码事实不是产品实测结论；未遍历全部函数，不给全 App 评分。

盘点时 HEAD：`31806b6ffd25b95b6402110b0e9f8c4c81e968c2`。工作区存在大量既有修改，因此 HEAD 不能单独代表所读代码。详见 [盘点快照](inventory-20260905.json) 与 [文件地图](file-map-20260905.txt)。快照中的哈希仅覆盖所列 Swift 和后端测试文件，不是完整构建指纹。此次记录不能作为之后测试的冻结基线。

## 1. 资料规模与阅读方式

| 实际枚举范围 | 数量 | 含义与限制 |
|---|---:|---|
| docs 下 Markdown | 138 | 路径盘点，未全文阅读 |
| tasks 下 Markdown | 97 | 含本专题原有两份文件；本报告新增前统计 |
| 根目录问题集合 Markdown | 57 | 后续按功能检索，不能只按版本顺序通读 |
| QiuJi 下 Swift | 318 | 不含其他独立目录/扩展，非全仓生产代码总量 |
| QiuJiTests 下 Swift | 165 | 文件数，含 helper/制作 runner，非测试用例数 |
| QiuJiUITests 下 Swift | 106 | 文件数，非有效覆盖或已运行次数 |
| content/position_play/sequences 下 JSON | 103 | 文件数，非可用球形数 |
| QiuJi/Resources/Drills 下 JSON | 75 | 含 index；不能把数量直接称为 75 个动作 |

资料来源分层：

1. `docs/01`–`docs/08`：定位、功能、交互、技术、范围与商业化。`docs/04` 已列到 F20，另有 v52/v54 增补；旧 F1–F11 索引不足以代表全域。
2. `docs/00-讨论记录.md`、根目录问题集合、`docs/research/`：追踪意图演变与后续裁定。
3. `.kiro/steering/content-data-contract.md`、`table-geometry.md`：数据与几何裁定入口；同一文档中的历史现状段落仍需核对。
4. `tasks/phases/`、`PROGRESS.md`、`HUMAN-REQUIRED.md`、失败记录：实现/验收声称及尚待人工事项，不代替当前实测。
5. `tasks/test-plans/`、`tasks/ui-reviews/`：P2–P8 人工计划、v54 专项及历次截图报告，作为候选场景来源；不把历史勾选直接迁移为本轮通过。

## 2. 功能地图初稿

当前 `QiuJi/App/AppRouter.swift` 的五 Tab 为训练、动作库、练习、记录、我的。

| 领域 | 实现/规格定位 | 正式诊断重点候选 |
|---|---|---|
| 训练与计划 | Features/Training；TodayTrainingScheduleService、PlanProgressService；v54 | 主线/模版/动作入队，开始/中断/保存，连续课程推进与幂等 |
| 动作库与教学资产 | Features/DrillLibrary；DrillContentService；Drills/DrillBoards/序列 | 全量可加载、引用完整、列表到详情、教学与几何独立验证 |
| 练习与球桌 | Features/AngleTraining、PositionPlay、SnookerTactics、BallExtraction | 认知测验和工具区分，几何/物理、复杂手势、权限入口 |
| 记录与统计 | Features/History；StatisticsViewModel | 已知数据独立核算、分类/时间范围、编辑删除、历史快照 |
| 我的与账号 | Features/Profile；AuthState、AccountDataCoordinator、OwnerTransferService | 匿名/账号数据归属、退出恢复、资料与偏好 |
| 同步与权益 | SyncQueueManager、BackendSyncService、SyncRestoreService、StoreKitService | 本地到后端、失败恢复、权限边界与购买恢复；环境待核实 |
| 每日清台与共享状态 | DailyClearanceStore；v52；MainTabView 训练浮层 | 草稿、跨日、完成去重、与普通训练统计分离 |
| 横向能力 | App 启动/路由、设计系统、构建配置 | 新安装、发布资源、外观/字号/设备、性能、隐私与可诊断性 |

这是测试分域地图，不是逐个入口已经确认可达。BatchDrillStudio 等工具目录是否属于用户可达功能，需要在后续路由盘点区分。

## 3. 三项定向抽查

### A. 训练完成到持久化与主线推进

- 有效预期候选：契约 §9.2 明确冻结来源、只有连续 completed + advanceEligible 推进、重放幂等、昨日不自动顺延。
- `ActiveTrainingViewModel.saveTraining`（约 1021–1128 行）可见保存成功防重复、保存课程完成/主线效果、同一保存前插入同步项、失败 rollback。
- `PlanProgressService.settleCompletedScheduleItem`（205 行起）已有主线/角色检查及连续课程规则调用。
- `V54TrainingTransactionTests` 已对会话、编排项、游标、同步队列进行断言，覆盖注入保存失败及重试，具有可复用价值。
- 限制：该测试使用内存容器。其中名为 restart 的用例在同一容器中重新 fetch 并新建 VM，不能单独证明杀进程后的磁盘恢复。正式诊断应补正常 UI 入口与真正进程重启证据；暂不认定其他测试未覆盖。

### B. 内容源到 Bundle 加载

- 契约 §2.2 说明当前内容 Bundle 读取、OTA 未落地；`DrillContentService`（489 行起）抽查与此一致。不能仅因后端 package 描述带 OTA 就安排已上线 OTA 验收。
- `loadFallbackDrills` 使用索引再 compactMap 加载，部分失败可能返回子集；当前已有可定位日志。这是测试需要关注的行为，不直接登记为产品 Bug。
- 早期 `DrillContentServiceTests` 只检查非空及单条资源，不足以证明完整性。
- 但 `DrillContentValidationTests.test_allIndexedDrills_loadSuccessfully` 已对所有索引 ID 求差集并输出解码原因。后续应复用这层测试，而不是因只看到早期文件就误判整个项目缺少完整性检查。
- 仍需验证实际发布 Bundle、图像/球形引用与教学正确性，当前未运行。

### C. 历史页面 UI 测试可信度

- `P6_HistoryStatsUITests.testCalendarMonthNavigation`（约 46 行起）：按钮不存在时不失败；存在时点击后没有月份变化断言。
- `testCalendarWeekdayHeaders`：缺失标签时也没有失败断言。
- `testSwitchToStatistics`：找不到统计入口时直接 return。
- 可确认结论：这些方法本身不能可靠证明其名称对应行为；这是测试资产缺口，不是历史页实际故障。
- 后续：列为需替代断言/独立验证的用例，在诊断期间不修改旧测试让它“变绿”；新辅助测试是否必要在批次设计时确定。

## 4. 发现的方案约束

| 编号 | 事实 | 对方案的影响 |
|---|---|---|
| R-01 | 契约 §8.8 仍记“官方计划无法推进”；当前服务存在推进实现，§9.2 已有新规则 | 历史缺陷不能直接复制成当前问题；需要标记旧描述被后续实现替代或待验证 |
| R-02 | 测试规则描述 Jest/supertest；backend/package.json 实际 `node --test test/*.test.js`，抽查使用 node:test | 用实际入口盘点测试，旧规范不代表当前工具；本轮不修改规范 |
| R-03 | BakeRunnerGate 明确部分 Tests 是制作任务，会写资源；由环境或新鲜 flag 开启 | 默认禁止整 target 盲跑；先审核选择器和副作用，不清理用户既有 flag |
| R-04 | scripts/Makefile 的 verify-gate 主要组合内容、同步 schema 和 UI 静态基线等检查 | “总门禁通过”不能等同用户旅程或发布验收通过 |
| R-05 | 早期 UI 用例存在无断言/条件返回；新事务测试较具体 | 为每类关键行为分级证据，不能统一继承所有旧测试可信度 |
| R-06 | 工作区包含未提交产品改动，V54ScheduleUITests 内已有 V57 用例 | 文件名/HEAD/版本标题都不足以锁定行为；运行前记录实际源码与选择器 |
| R-07 | backend 的 provenance 抽查仅检查 Mongoose 字段保留 | 不等同 HTTP、鉴权、数据库持久化或在线部署验证 |

## 5. 下一批工作与执行优化

下一批仍以只读准备为主：

1. 建立预期清单首批：训练保存/计划推进、三类会话统计、内容完整性，各条标明来源、替代关系和待确认点。
2. 读取正常路由及测试启动 helper，区分正常入口、深链、fixture、权限预置和生成任务；给可复用测试列选择器，不启动制作 runner。
3. 只读核实 Xcode/runtime/设备、正在占用的测试进程、后端测试依赖及外部服务前提；不安装、不登录、不触碰真实数据。
4. 形成首轮小批次方案：一条训练完整链路 + 一条内容链路 + 少量基础巡查，按环境条件再定具体样本与执行量。

运行批次预期顺序：环境/基线 → 训练与记录 → 内容与练习 → 账号/同步/权益 → 代表设备与异常专项 → 证据复核汇总。该顺序是候选，尚非全部范围已盘点完毕。

当前无需新建技能或启动子智能体。地图稳定后，可把独立资料追踪交给子任务，主控继续核实运行环境；UI 执行统一调度，避免共享模拟器焦点。正式委派前按项目角色与模型规则执行。

## 6. 本轮交付与未验证项

- 交付：路径/规模快照、初步功能地图、三个抽查样本、七项方法约束与下一步。
- 未验证：当前构建能否通过、测试是否可执行、页面实际表现、数据磁盘恢复、线上/测试后端、真机与权益。
- 未完成：所有用户意图还原、完整可达入口清单、正式测试方案与测试诊断报告。
- 本轮无产品修复，无新测试、无提交；仅新增/更新诊断记录和进度入口。
