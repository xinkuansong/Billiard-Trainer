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

- **问题集合 v36 W1–W4a 收官 🔄（2026-08-12，plan-delegated-execution，主控 = Orchestrator；四批返工 0 轮）**：用户数据同步链路收口。**W1 上行字段对齐**：`TrainingSessionDTO` 的 `DrillSetDTO` +6 / `DrillEntryDTO` +3（编码直传、解码 `decodeIfPresent`+默认值，防旧后端回包解码失败→队列卡死），后端 `TrainingSession.js` 子 schema 同步登记 9 字段（给 default、不加 required，⛔ mongoose `strict:true` 不登记即静默丢）；ADR-007 + 契约 §4.1 落地状态表 / §8.13 闭环。**W2 删除同步 + 队列健壮性**：后端新增 `DELETE /training-sessions/by-client/:clientId`（幂等硬删，**不存在也返 200**——返 404 会被客户端判 4xx 永久失败，出队结果相同却白打错误日志）；`SyncQueueManager` 按 `(entityType, operation)` 分发、delete 项**不回查实体**、两处删除入口入队；失败分类 4xx 出队 / 5xx·网络保留，**例外 401/408/429 保留**（会自愈，丢弃等于真丢数据）；`try?` save 全改 `do/catch`（FL-029）。测试缝选**窄协议 `SyncBackend`** 注入而非改 `APIClient` 单例，顺带把 `@Model` 传进 actor 的隐患改成 MainActor 上先做 DTO 快照。⛔ **未加 `SyncPendingItem` 重试计数**，守住「不做 Schema V4」红线。**W3 下行恢复**：新增 `SyncRestoreService`（`SyncedRecord` 信封 + 协议缝 + 实体重建 + clientId 幂等），**冲突策略 = insert-if-absent，本地永不被远端覆盖**（本地无 `updatedAt` 即无可信「谁更新」判据，覆盖可能用旧副本盖掉刚写的心得）；锚点取**服务端 `updatedAt`** 存 UserDefaults 按 userId 分键（用客户端时钟会因漂移静默漏数据；不分键换号后新账号历史永远拉不到）；删除竞态两道防线（顺序固定「先推后拉」+ 合并前跳过队列中仍挂 delete 项的 clientId，读队列失败则整轮放弃而非盲插）。**范围外必要修复**：`JSONDecoder .iso8601` 不认后端 `res.json()` 的带毫秒日期 ⇒ 每个含日期的响应都会整条解码失败（下行根本跑不通、现有 POST 响应解码一直被误判成上传失败），改为兼容含/不含小数秒。ADR-008。**W4a 双端对齐门禁**：新增 `scripts/verify_sync_schema_alignment.py` 进 `make verify-gate` 与 pre-push——后端侧 `node -e` require 真 mongoose 模型读 `schema.paths`（线上 `strict` 用的同一份数据结构），D0 解析失败 / D1「Swift 有后端未登记」= FAIL，D2/D3 = WARN，白名单仅 5 个服务端专属 path 且只豁免 WARN。**验收证据**（主控亲读落盘原始产物，非采信自述）：`build/w{1,2,3,4}-logs/` — build 均 SUCCEEDED；W1 22/0、W2 聚焦 37/0 + 相关 147/0、W3 聚焦 48/0（含往返真走「实体→DTO→JSON→解码→重建」且断言 `nil` 不被写成 `""`/`0`）；后端 `node --check` PASS + 路由顺序探针实证 `by-client index=3 < :id index=5`；**主控亲自复跑 `make verify-gate`（FAIL 0）并独立注入 `orchestratorProbeField` 实证门禁 exit 1、还原后 md5 一致**。全量单测 18 处失败经接触面核验全落在内容/几何域（⚠️ 按接触面归因，非基线 worktree 对照；期间工作区有并行 TutorialFigures 内容线）。**遗留**：W3 完成标准 4（端到端实跑）与 W4b（部署 + 清空 Mongo）顺延 ⇒ 新增 **H-24**；后端 `deleteOne` 与下行真实 HTTP 往返**至今未经任何实测**；后端 GET `limit(500)` 未分页；`scripts/publish_tutorial_figures.py` 是 git 未跟踪文件却被 `verify-gate` 依赖（属并行内容线，待裁定）。**改动未 commit。**
- **精讲配图 HEIC 化 + 包体 5.43 GB → 285 MB ✅（2026-08-12，Content/iOS，v25 W4 补做 / DR-070 / D-v25-14）**：起于用户问「当前 app 为什么会 5.43G」。走查定位到构建产物 5.1 GiB 中 **4.9 GB 是 `Resources/DrillTutorials` 的 1343 张无损 PNG**，其余全部加起来不到 200 MB。翻 `.gitignore` 发现**这件事早有拍板从未执行**——v25 **W4** 批次（D-v25-2 压 HEIC 后进 git、D-v25-10 孤儿帧不进包不进 git），立档时 591 张 / 2.14 GiB，执行时已涨到 1343 张 / 4.90 GB。**两条根因均为实测非推断**：① 格式错配——配图是 3D 渲染图不是照片，alpha 恒 255、球布区 83% 相邻像素不同（均差 4.3/255 的渲染噪点），PNG 行内预测失效（14.9 MB 原始 → 3.76 MB，压缩比仅 4:1）；② 打包集错配——1343 张里仅 **710 张（2.60 GB）被精讲引用**，**633 张（2.30 GB）是孤儿**（`_still` 旧命名 387 张 + `_final`/`_initial` 等）。**架构增补 D-v25-14**：folder reference 整目录打包、无法挑文件 ⇒ 母版与发布图同处一室时 D-v25-10 物理上无法执行，故拆两目录——`DrillTutorials`＝PNG 母版（回填目标，不进包不进 git，**C2 字节比对对象不变**）、新增 `TutorialFigures`＝发布目录（仅被引用者、HEIC q70、进包进 git）。**落地**：新增 `scripts/publish_tutorial_figures.py`（`make tutorial-figures`：按 JSON 引用筛选 → sips 转 HEIC → 写 `content/tutorial-figures-manifest.json` 记源 md5 → 清理失引用产物），`import-engine-export-to-app.py` 回填后自动串接；`TutorialAssets` 统一 Bundle 子目录与扩展名回退（heic→png→jpg），`DrillTutorialImageStore` 与 `tutorialClipURL` 同步。**q70 定档靠实测不靠默认值**：q45/60/75 = 64/115/198 KB，HEIC 回转 PNG 逐像素 PSNR 41.7/42.7/43.4 dB（底部小字带 41.8–42.9），q45→q75 体积翻三倍 PSNR 仅 +1.7 dB ⇒ 码率增量几乎全花在复现不可见噪点上；保持原始 1440×2720 不降分辨率。**门禁没有被换格式换没**（本条关键）：转 HEIC 后源与产物不可能字节相等，若让 C2 直接指向发布目录会 710 项全降级为 warn（`BYTEWISE_SUFFIXES={".png"}`）；母版保持 PNG 使 **C2 原样有效**，发布链路另设 `--check`（发布集/新鲜度/孤儿入包三查）接进 `make verify-gate`。**验收证据**：`make build` **SUCCEEDED**；`TutorialFiguresBundleTests` **4/4 TEST SUCCEEDED**（在构建产物上验 710 张全部可解码、包内无 PNG、数量对齐、解码宽 1440）；构造性门禁实证——混入 `__stray.heic` → FAIL 1「多余产物」、篡改清单 src_md5 → FAIL 1「过期」、`make verify-gate` 退出码非 0，还原后 FAIL 0；`make verify-tutorials` 改动前后均 **FAIL 0**（C2 925 / C3 710 未退化）。**包体实测 5.1 GiB → 285 MB**，发布目录 112.5 MB ≤ W4 DoD 150 MB。**遗留**：① 710 张 HEIC（112 MB）按 D-v25-2 应入 git，**本次未 `git add`**（未获提交授权）；② `TaiQiuZhuo.usdz` 94 MB 现为包内第二大项、占 33%，未评估（可并入 P18 T-P18-28）；③ 633 张孤儿母版按 D-v25-10 保留磁盘未删。**改动未 commit。**
- **训练分享图改长图 ✅（2026-08-11，SwiftUI Developer / DR-069）**：用户反馈「分享图太简陋，期望和训练详情差不多并带统计数据，可以是长图」。**根因两条**：① `BTShareCard` 被钉死在 361×480pt——那个死高本是「根部 `Spacer(minLength: 0)` 让 width-only 渲染失控」的止血手段（`ShareCardImageRendererRootCauseDiagTests` 记录在案），代价是长内容压扁、短内容留白；② `TrainingSessionSummary` 是纯聚合口径，没有逐组 / 心得 / 缩略图可展示。**改法**：删 Spacer，尺寸契约由「定宽定高」改「定宽 375pt + 高度随内容」（`cardHeight` → `maxCardHeight = 3000`，**只断上界不裁切**——真超了是折叠规则错了，裁切等于静默丢内容）；卡片重写为六段（品牌头含时段 → Hero 四大数字 → 成绩概览：逐项对比条 + 最佳一组 + 组间波动 → 训练明细：缩略图 + 逐组网格，底色深浅表达该组成功率 → 训练心得 → 页脚）；分享图改用**独立字阶 `ShareType`**（写死 pt，⛔ 不复用 `.bt*` token，导出图不得随系统动态字体变形）；`TrainingSessionSummary` 扩 `note` / `drillId` / `sets`（`TrainingDetailView` 与 `ActiveTrainingView` 两个构造点同步）。**顺带修的正确性问题**：全部 target = 0 时成功率原样显示「0%」，改为「—」（未定义 ≠ 0）；逐组全 0/0 的项不画网格（17 个「0/0」格子是纯噪声）；`hideSuccessRate` 打开时格子底色一并中性化（深浅本身就是成功率读数）；不足一分钟由「0 分钟」改「<1 分钟」（F-TS-11）；空会话不再留空的「训练明细」标题。**高度封顶靠折叠规则**：`maxDrillCards=8` / `setGridBudget=36`+`foldedSetsPerDrill=12` / `noteLineLimit=8`——首版取 12 张卡时极端用例实测 **3175pt > 3000**，**收紧折叠而非抬阈值**。**验收证据**：`make build` SUCCEEDED（最终版）；聚焦单测 **13/13**（像素高断言换成「宽度精确 = cardWidth × scale + 高度随 drill 数/心得单调增长 + 极端用例 < maxCardHeight」，另新增 5 例统计口径用例锁「未登记 ≠ 0%」/ 最佳组按成功率取 / 总体标准差公式）；`W1_ShareSavePhotosUITests` 真机权限路径 **passed**；两张导出样图（含 `hideSuccessRate` 对照）与实机分享页截图亲验。**全量 `make test` 已跑完（3h47m）：单测 8 处失败、UI 54 处失败，全部落在内容 / 几何 / 计划走查等与本批无关的套件，且分享相关三处（`W1_ShareSavePhotos`、`V29W2a` 的分享段断言、`ShareCard*`）全过；⚠️ 未跑改动前的全量基线对照（该工作区停有 v34/v35 大量未提交改动），故只声明「无分享相关失败」，不声明「零新增失败」。** 改动未 commit。
- **问题集合 v36 立档 ✅（2026-08-11，纯文档，Orchestrator/Data Engineer）**：新建 `问题集合_v36.md` v36.0——「用户数据同步链路收口（上行字段 / 删除同步 / 下行恢复）」真源。起因：用户问「用户数据存服务器有什么变化吗」→ 全链路走查发现后端自 v29 W5（`c1588e2`）后未动，客户端 V2/V3 演进后产生缺口，定性 Q1–Q5：① **上行字段缺口**——SwiftData V2 起的 9 个成绩字段（`DrillSet.formationToken/formationName/unitLabel/passMade/passTotal/durationSeconds`、`DrillEntry.orderIndex/note/criteriaText`）从未进 `TrainingSessionDTO` 与后端 Mongoose schema，服务器副本有损（`unitLabel` 丢失会让恢复数据把「局/次」当「球」）；② **删除不同步**——两处删除入口只删本地，`SyncQueueManager.uploadItem` 忽略 `operation` 且实体缺失时 `return true` 出队，后端 DELETE 只认 Mongo `_id` 客户端调不了；③ **下行恢复缺失**——`fetchSessionsAfter` 全仓库零调用方，服务器纯写入端备份；④ 队列无失败分类（4xx 无限重试）+ `processQueue` 的 `try?` save（FL-029）；⑤ 双端对齐无门禁。AngleTest 链路 v29 W5 已双端对齐不动；CustomPlan 等纯本地实体不在范围。**用户拍板前提：App 未上线、现有 Mongo 数据可全部清空** ⇒ 后端 schema 可破坏性改、无存量重推/兼容负担。批次 **W1 上行字段对齐（含 ADR + 契约 §4.1/§8.13 回写）→ W2 删除同步 + 队列健壮性 → W3 下行恢复（依 D-v36-1）→ W4 对齐门禁 + 部署清库**（纯串行）。锚点全部读码核实（2026-08-11，含 `V29W5CognitiveToolSessionTests` L334–368 现成 DTO 测试、后端无测试框架故验收用 `node --check` + schema paths 打印）。**范围红线**：不做 SwiftData V4、不动 v34/v35 剂量与计划语义。**拍板已全清（同日，真源升 v36.1）**：D-v36-1=A（W3 下行恢复本轮做）/ D-v36-2=A（硬删 by clientId）/ D-v36-3=A（对齐门禁进 verify-gate）/ D-v36-4=`plan-delegated-execution` 委派，**全批模型 `claude-opus-5-thinking-medium`**（已写入批次表，后续会话不再询问）。**排期前置同 v35：等用户提交现有改动。下一步：等用户提交 → 开工 W1（上行字段对齐）。**
- **问题集合 v35 立档 ✅（2026-08-11，纯文档，Orchestrator）**：新建 `问题集合_v35.md` v35.0——「自定义训练计划全链路体验修复」真源。起因：用户实机反馈「新建训练计划逻辑有问题」「我的计划好像只能添加一个」。全链路走查定性问题 Q1–Q11，两大根因：① `sessionsPerWeek` 是假配置（自定义计划每天同一张动作表，字段仅作周进位计数，`TrainingHomeViewModel.loadCustomPlan` L265 / `PlanSchedule.custom` L43–45）；② 「只能一个」实为入口设计——「创建计划」按钮仅空态显示（`TrainingHomeView` L517–527），非空后唯一可点的卡片直达编辑器，且首页卡片无激活入口。另确认：编辑器无未保存拦截、保存置灰不解释、仅保存无反馈、两条新建路径规则分裂（动作详情 sheet 名称兜底 + 激活默认开无确认 vs 编辑器名称必填 + 激活弹确认）、`DrillPickerSheet` 无 premium gate 无分类筛选。**批次 W1 入口发现性 ∥ W2 编辑器保存/离开语义 → W3 两路径统一；W4 sessionsPerWeek 文案收敛（依赖 D-v35-1）；W5 Picker premium+筛选（依赖 D-v35-2）**。锚点全部读码核实（2026-08-11）。**范围红线**：不动 v34 剂量语义、不做 Schema 迁移。**拍板已全清（同日，真源升 v35.1）**：D-v35-1=A 文案降级 / D-v35-2=A premium 拦截 / D-v35-3=A（用户原话「加练」经回确认 = 追加进当前激活计划走现有「加入今日训练」，⛔ 不做多计划叠加合并今日清单）/ D-v35-4 遍数粒度不做 / D-v35-5 确认入口发现性；执行方式 = `plan-delegated-execution` 委派，**全批模型 `claude-opus-5-thinking-medium`**（已写入批次表，后续会话不再询问）。**排期前置**：工作区停有 v34 等未提交改动且与 W3/W5 改动面重叠（`ActiveTrainingView.swift` / `DrillDetailView.swift`）⇒ **用户自行提交后再开工**（用户已选定此路径）。**下一步：等用户提交现有改动 → 开工 W1（入口与发现性）。**
- **v34 后续·训练页四修（进度点换行 / 球形锁定 / 结构化加组 / 示意图切球形）✅（2026-08-11，SwiftUI Developer）**：用户实机走查训练页反馈四条，逐条落地：① `BTExerciseRow` 进度点**按可用宽度换行、最多两行**——一杆=一组后组数可达 20+，原单行点阵撑出屏幕；新增 `DotRowsLayout`（自定义 `Layout`，超两行容量的点放裁剪边界外不画，精确组数由旁边「N组」文本承担），卡片 `frame(height:80)` 改 `minHeight`。⚠️ 首版 `Int(∞)` 崩溃（SwiftUI 理想尺寸探测给无限宽）被 UI 测试当场抓到，补 `width.isFinite` 守卫后过——教训：自定义 Layout 必须处理 `proposal.width == nil/∞`。② **计划/预设自带组的球形锁定不可改选**——`DrillSetData` 加 `isFormationLocked`（`makeSetData` 对带 token 的组置 true），`SetRow` 球形列锁定时渲染静态短标签（球形信息并入行辅助功能标签，因行级 `.accessibilityLabel` 覆盖会吞静态子文本）；仅手动加组仍出 `BTFormationMenu`。③ **「添加一组」结构化选择**——新增 `DrillAddSetChoice`（球形×模式×序列杆数×默认球数，`addSetChoices(at:)` 按计划组序列聚合）；重复型出「杆1…杆N」菜单（多球形套球形子菜单、单球形平铺），**走位链一组=整链一遍无杆数维度**直接加；`DrillSetData` 加 `shotIndex`（重复型真实杆位，展示层不落库；`makeSetData` 按序列长度循环赋值），行标签「杆N」优先取 shotIndex，新组**插到同球形分节末尾**而非整表末尾（`modeForSet` 因此改为读行自带 mode，禁按下标映射回 plannedSets）。④ **球台示意支持球形切换**——`DrillSceneController` 加 `availableFormations`/`currentToken`/`switchFormation(token:)`（停演示→重摆盘面→后台重解算，token 守卫防在途结果串台），`DrillSceneView` 右下角出短标签胶囊组（≥2 球形才出，识别符 `formationSwitchChip_<token>`），训练页「球台示意」与动作详情页共用一处生效。**改动面**：`BTExerciseRow` / `BTSetInputGrid` / `ActiveTrainingViewModel` / `DrillRecordView` / `ActiveTrainingView` / `DrillSceneView`。**验收证据**：`make build` SUCCEEDED；单测新增 3 例（结构化加组插位 / addSetChoices 聚合 c026=[5,7,5] 杆 / makeSetData shotIndex+锁定）`ActiveTrainingViewModelTests` **47/47**、`QiuJiTests` 聚焦两套 **59/59**；UI 测试 `V34W5ScreenshotUITests` ②③④+新增⑥球形切换全过（④改断言为「加组菜单出杆号→选杆2→末尾插入杆2 行」，⑥胶囊点击后选中态迁移+盘面重摆，截图亲验 `build/v34-w5-logs/`）、`V31W2`/`V31W5` 多球形展开走查改「球形：」口径后全过；全量 `QiuJiTests` 4 处失败经孤立重跑证明为套件资源 kill（孤立全过）+ 既有「特写红项」基线（T01 轮已记录），**新增失败 0**。**改动未 commit。**
- **练习页三小修（搜索框高度 / 主题筛选 / 解球器打点盘）✅（2026-08-11，SwiftUI Developer）**：① `BTLibrarySearchBar` 输入框固定 44pt 高（原随内容 ~36pt，动作库因右侧 44pt 筛选按钮被撑高 ⇒ 两页搜索框高度不一致，改后统一）；② 练习页（`AngleHomeView`）搜索框旁新增与动作库同视觉的主题筛选 Menu——标签 准度/加塞/走位/吃库/防守，`AngleEntry` 加 `topics` 集合（学/练/打/解逐条标注、理区按 `TheoryPageID` 逐页映射，流程/速查与自由击球等综合条目不挂主题、仅在未选主题时出现），空态支持一键清筛选；③ 翻袋/反射解球器击球中打点盘消失修复——根因是 `SolverStageChrome.canOpenSpinPad` 把 `!isPlaying` 揉进「是否渲染打点位」，而 `BTShotInstrumentColumn` 在 `onSpinTap == nil` 时整个不画打点迷你图；改为结构性条件 `showsSpinSlot`（自由 / 求解有解）+ `spinTapEnabled: !isPlaying`，击球中与力度条一起禁用灰化而非消失（其余页面本就走 `isDisabled`，仅此壳有该问题）。**证据**：`make build` SUCCEEDED；lint 0；grep 确认无 UI 测试依赖旧行为。变更：`BTLibrarySearchBar.swift` / `AngleHomeView.swift` / `SolverStageChrome.swift`。
- **v34 后续·剂量展示收敛（紧凑口径）✅（2026-08-11，SwiftUI Developer，用户逐条拍板）**：用户实机走查计划页反馈剂量文案冗余（同一球数一条目出现 2–3 次、长句窄列截断、分钟散数）。定稿七条并一次落地：① 计划页条目行去球数——单球形内联「动作名 · 5 × 15」、多球形只报「动作名 · N 球形」（`ResolvedDose.planEntrySummaryText` 重写）；② 明细行改「球形短标签 + 模式标签 + m×n」（repetition「逐位重复 8 × 15」= 位置×每位置颗数；sequence「整链走位 10 × 8」= 链杆数×遍数），删「合计 N 球」行，球形标题取「·」后短段避免复读动作名；③ 计划页周章节与多球形明细**默认全展开**（单球形已内联故不再有展开层；原 `-uitest.expandPlanWeek1/-uitest.expandPlanDrill` launch arg 路径删除）；④ 分钟一律**向上取 5 的整数倍**（`estimatedMinutes` 阶段级取整，天/周合计 = 各阶段之和仍是 5 的倍数、与屏上分项加总一致）；⑤ 动作页「建议训练量」同紧凑口径 + 模式标签，末行「合计：N 杆」**改为一律返回**（紧凑行不再含总量，此处成唯一总量出处，单位按用户拍板用「杆」）；⑥ 训练页三级进度改杆位口径——repetition「球形 x/y · 第 m/n 杆 · 第 k 颗」（原「位置 m/n」）、sequence 补链内杆位「球形 x/y · 第 r 遍 · 第 k/n 杆」（原只报「第 N 轮」，「轮」统一为「遍」）；⑦ 录入表格行标签模式感知——`DrillSetData` 加 `mode` 字段（`makeSetData` 自 `plannedSets` 带入、手动加组承袭 source），分节内编号 repetition「杆N」/ sequence「遍N」，无模式信息（自由记录/历史编辑）回落纯组号。**改动面**：`TrainingDoseResolver`（`SuggestedDoseLine` 加 `modeLabel`、`suggestedDoseLines()` 去 unitLabel 参）、`PlanDetailView`、`DrillDetailView`、`ActiveTrainingViewModel`、`BTSetInputGrid`；测试同步 `TrainingHomeViewModelTests`（含分钟取整边界 1→5、135→55）、`ActiveTrainingViewModelTests` 3 条进度断言、`V34W5ScreenshotUITests` ②③、`XV313PremiumPlanWalkthroughUITests` 剂量正则。**验收证据**：`make build` SUCCEEDED；聚焦单测 4 套 **85/85 全过**；UI 截图测试 7 条全过，亲验三页截图符合定稿口径（计划页默认展开 + 25/105/135 分钟全为 5 倍数、动作页「逐位重复 5 × 15 / 合计：75 杆」与「整链走位 8 × 8 / 合计：64 杆」、训练页「球形 1/3 · 第 1/5 杆 · 第 1 颗」+ 表格「杆1…/遍1…」分节，`build/v34-w4-logs/`、`build/v34-w5-logs/` 已覆盖更新）。**改动未 commit。**
- **问题集合 v34 全案收官 ✅（2026-08-11，plan-delegated-execution，主控 = Orchestrator；W0–W6 七批全过，返工 0 轮）**：用户睡前授权全程委派 + 拍板代决。**主控亲做** W0（契约 v2.3：D16 剂量重定 15 颗/位置 + `doseNote`、D17 `roundsPerFormation` 倍数语义 + formations 下限入 I11、D18 形状约束入 I6b 取代 D13/D15；门禁/自测/Swift 镜像同步；ADR-006 落 P2；附带修 xcpretty 缺失挂死）、W1（6 处 mode 翻转 + c024 首球形删除，D-v34-3 代拍板，Snipaste 引用全库归零）、W6（回归收官）。**委派 grok-4.5 + 主控独立复算验收** W2（剂量写回 ×83：自写脚本比对填写表 ↔ JSON **105/105 一致**、I6b 归零）、W3（计划重排 ×10：D-v34-2 代拍板映射 id 全沿用、83/83 覆盖 + 完整剂量 ≥3（特殊球 ≥4）、75 条零 `roundsPerFormation`、课时档 ±20% 全落带、gate 首次归零 + 自测 28/28）、W4（Resolver 倍数语义 + 下限钳制 + 动作页逐球形 R10，主控亲跑 40/40 + 截图亲验）、W5（计划页 R11 + 训练页三级指示/分节/走位链只报轮/添加一组复制位置 R12 + `volumeText` 统一，主控亲跑 85/85，补 1 处修正：异构用例被 XCTSkip 改锚 c069 恢复覆盖）。**W6 收官证据**（`build/v34-w6-logs/`）：`verify-gate` **FAIL 0**、自测 **28/28**、`make build` SUCCEEDED、全量回归（基线设备 17 Pro）**失败恰为 W0 基线 8 条零新增**、截图走查 4 页面齐（含今日安排激活态新口径上屏）。**主控改写 10 条 V21/V22 旧货架规格测试**（钉死重排前计划细节，前提已废）为 v34 规格 11/11 过。**遗留**（详见 `问题集合_v34.md` §五 W6）：bank shot 设备相关可解性（17 失败/17 Pro 过，非 v34 回归）、X-v31-1 扩容、c024 烘焙遗留、c075 锚点硬编码、计划页窄列截断。**全部批次验收记录在 `问题集合_v34.md` §五。**
- **问题集合 v34 立档 ✅（2026-08-11，纯文档，Orchestrator）**：新建 `问题集合_v34.md` v34.0——「训练量全库重定（15 颗/位置）+ 计划重排 + 三页剂量透出」真源。剂量数值真源 = `tasks/训练量填写表.md`（2026-08-11 03:03 定稿，用户逐球形手填：83 drill / 105 球形 / 总 **9493** 球，旧口径 ≈4150）。**用户拍板 R1–R13**：重复型 = 每位置 15 颗 × 轮数=杆数（轮=位置，例外 c002/c022 带 `doseNote`）；走位链 = 杆数/轮 × N 轮；c024 首球形整体删除（清单先确认）；mode 修正 6 处（c001/c062/c063/c072→repetition、c046/c080→sequence，⚠️ 与 v31 W1 语义判定相反，本轮以用户对照形态逐条填数为人工裁定）；计划重排 10 个各 2–5 周（准度/杆法各拆两段）、每动作完整剂量 ×3、每周 3 次；配速固定 2.5 球/分钟不做设置、课时档 75/90/120/150 min、超容不硬卡；**`roundsPerFormation` 走 B 方案**（留列改语义为「整套遍数倍率」，⛔ 不做 Schema V4 迁移，官方计划不写该字段）；D13 总量护栏作废改形状约束（重复型 bpr∈[8,15]）、D15 被取代（c020/c078 16→15）；动作页/计划页/训练页三处透出逐球形剂量，训练页「组=位置」三级指示「球形 x/y · 位置 m/n · 第 k 颗」（走位链只报轮）。**批次 W0 契约门禁（主控）→ W1 mode+c024（主控）→ W2 剂量写回 ×83 → W3 计划重排 ×10 → W4 Resolver+动作页 → W5 计划页+训练页（W2–W5 = cursor-grok-4.5-high-fast，用户拍板）→ W6 回归（主控）**。锚点全部读码核实（`verify_tutorial_sync.py:531` VOLUME_GUARD、`TrainingDoseResolver.swift:136–162`、`PlanContentService.swift:70–88`、`QiuJiSchemaV3`、`DrillDetailView.swift:390`、`ActiveTrainingViewModel.swift` plannedSets 已带 token 结构无需重做）。**拍板项遗留**：D-v34-1 fullskill 归宿（默认改精选计划）、D-v34-2 计划文件 id 映射（W3 提案）、D-v34-3 c024 删除清单（W1 出示）。**排期前置**：工作区停有 T01/FL-030 未提交改动 ⇒ 各批独立 worktree；完成标准聚焦测试 + W0 现场基线。**下一步：开工 W0（契约 v2.3 + 门禁形状约束 + ADR + 封存填写表）。**
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
