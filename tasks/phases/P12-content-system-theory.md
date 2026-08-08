# P12 — 内容体系与理论挂接（Curriculum System & Theory Integration）

> 把"广度铺满的 72 条目录"升级为"有先修关系、挂接 16 理论、可证伪完备"的训练课程；打通 16↔13 的理论消费闭环；确立内容生产的标准 SOP（理论引用 / 社媒拿球形 / 理论配图）。
> 单一真源地图见 [`../curriculum-map.md`](../curriculum-map.md)。
> 背景讨论：2026-06-14 用户复盘"拖延=对现做法不满意"，根因坐实为"生产排在系统定型之前 + 完备无可证伪终点 + 理论与内容是两座孤岛"。

## 任务清单

| 任务 | 说明 | 状态 |
|------|------|------|
| T-P12-01 | 课程地图 `curriculum-map.md`：schema/双轴/理论绑定/72 条真实填充表/缺口读数 | ✅（2026-06-14）|
| T-P12-02 | 理论挂接 schema：`DrillContent.theoremIds/moduleIds?` + `TutorialSection.theoremRefs?`（可选、向后兼容）；vendor `16/contracts/*.json` 进 `Resources/Theory/` | 🔄 进行中（v30 W0 已完成 **vendor 部分**：`Resources/Theory/contracts/` 三文件 + README + folder ref 打包，`TheoryCatalogTests` 断言 Bundle 可解析；`theoremIds` / `theoremRefs` 字段留 **v30 W5**）|
| T-P12-03 | **c042 竖切**：c042 挂 T03/T01/T04 + 精讲三层披露；建 T01/T03 理论详情页（复用 `AngleTrainingScene` 标注图）；详情页可被 drill 深链 | 🔄 进行中（v30 W0 已建**路由骨架**：`AngleRoute.theoryIndex` / `.theoryPage(TheoryPageID)` + `MainTabView.theoryDestination` 注册表；T01/T03 详情页正文见 v30 W1/W2，c042 挂接与三层披露见 v30 W5）|
| T-P12-04 | 闭环记账：建 `THEORY-CONSUMPTION-LOG.md` + 翻 16 中枢卡 v1.0 final（≥1 drill 消费 contracts）| ⏳ |
| T-P12-05 | 锁定 `curriculum-map.md` §6 待定参数（每格配额 / L4 取舍 / 系统训练模式）后逐格展开 | ⏳（待用户拍板）|
| T-P12-06 | 理论"球理"中心（角度Tab 学习区升级为结构化索引）+ 参数扫描配图 + 战术布局图 | 🔄 进行中（**提前到 v30**）：W0 已落**索引页骨架**（四分组 + 12 条目全量 + 未上线置灰）+ 学区「球理」入口卡；12 篇正文 = W1–W4；现有 9 张学页归组混编 = W6；⛔ 参数扫描配图与战术布局图**不在 v30 范围**，仍留阶段 2 |
| T-P12-07 | 系统训练模式 Drill Type 5/6/7（Name-5-Shots / Random-2-Points / 18 类加塞）| ⏳（建议 v1.1）|

## DoD

- a. 课程地图为单一真源，72 条真实摆位 + 缺口可数。
- b. 理论 schema 字段可选、旧 72 条零回归（JSON 可解码）。
- c. c042 竖切：精讲以教练话叙述原理、可三层披露点进理论详情页并返回；`theoremIds` 已标。
- d. 16↔13 理论消费闭环达成（≥1 drill 实际消费 contracts），双方记账。
- e. 内容生产三 SOP 写入 content-engineering SKILL。
- f. `make build` 通过、`QiuJiTests` 全绿、lint 0（涉及代码改动的任务）。

---

## ADR 记录区

### ADR-P12-01 — 内容体系完备化 + 理论挂接（三层披露 / 理论之家 / 配图分类 / 社媒拿球形）

- **日期**：2026-06-14
- **状态**：✅ 已采纳（用户多轮讨论后逐点确认）。命中 ADR 触发：**跨模块边界**（13 import 16 的 `contracts/`）+ **新内容/数据策略**（理论挂接字段 + 课程地图作内容真源）。
- **背景**：用户反思拖延根因——不是单个素材不专业，而是 ①生产排在系统定型之前（怕返工）②"更系统更完备"无可证伪终点（完美主义陷阱）③**理论与内容是两座孤岛**（核实：72 条 drill 无 `theoremIds`，工程未 import `contracts/`，16 中枢卡明示"13 实际 import → ≥1 Drill 闭环"至今未达成）。用户拍板方向：先挂理论、目标做系统完备课程、社媒拿球形避免闭门造车、理论自然引用且配图。

- **决策**：

  1. **完备 = 课程地图被填满（可证伪有限目标）**。新建 `curriculum-map.md`：纵轴能力树 Level × 横轴 8 大类，每格要求 ≥N 条 drill、每条满足"四件套"（挂定理 + 引擎可达 + 示范素材 + 精讲）。完备 = 所有目标格 `COMPLETE`。取代"凭感觉还不够全"。

  2. **理论挂接走"三层渐进式披露"，绝不用"根据定理X"教材腔**：
     - 层1 教练话：精讲正文用人话把原理说成"就是这样"（如"母球击球瞬间总先沿切线走，之后才被旋转拉弯"——即 T03，但不出现编号）。
     - 层2 一句话：轻触正文 → 弹定理 `statement_one_liner`（16 现成，≤60 字）。
     - 层3 完整页：再点 → 跳理论详情页（16 `doc_path` 内容）。
     - 数据层分工：`theoremIds`/`moduleIds` 是**给机器的标签**（导航/错题分析/筛选），不进正文措辞；正文用教练口吻；链接以"安静的可点标记/chip"出现。

  3. **理论之家 = 练习 Tab「理」区**（v32 修订，2026-08-08；非第 6 Tab、非动作库、**非学区**）。
     - **史实（原决策，v30 阶段）**：理论先落在「学」侧栏下的「球理」入口卡 + 索引页（ADR 原文「学习区升级为球理中心」）。
     - **现行（v32）**：侧栏五分类 **学 → 理 → 练 → 打 → 解**；「理」仅承载 16 体系（索引 + T/流程/速查）；现有交互学页留「学」。详见 `问题集合_v32.md`。
     - 决定性理由（仍成立）：深链正交——理论详情页用 `navigationDestination` 可从 drill 详情直接 push；视觉基建在练习 Tab；不单开第 6 Tab。

  4. **理论必须配图，由管线生成，但分三类（成本递增，不是白嫖 drill 出片）**：
     - 类型1 标注图/交互场景（T01–T03/T09）：**复用现有** `AngleTrainingScene`（假想球/切角弧/α°）或内嵌交互场景——近零成本。
     - 类型2 参数扫描演示（理论独有：T01"切角扫描偏折≈30°恒定"/T04"9 档速度走位线叠加"）：**需新增** sweep + 多轨迹叠加渲染模式——引擎原生但要写。
     - 类型3 战术/决策图（T05–T08/T10/M01–M06/5 步流程）：多杆走位用编排台；布局/流程/矩阵是**平面设计图、非引擎渲染**。

  5. **社媒/竞品做素材 = 拿"球形/教学点"的 idea，不拿视频片段**（规避版权/拒审；产品里不出现原视频）。流程：刷到好教学 → 提取球形+教学点 → 编排台复刻成击球序列 → 引擎生成干净示范+HUD。三角验证给每条 drill 出处：球形来自真人（解决"不是拍脑袋编的"）、正确性锚 16 理论（Tier1/2 源，比随机网红权威）、可达性引擎验证。采集**有界**（绑定地图待填格子，防囤积黑洞），接 16 已有"教学知识库"轨道不重复。

  6. **分阶段（防返工 + 防"理论栏永远建不完"的新拖延）**：
     - 阶段1（现在）：c042 竖切——挂 `theoremIds` + 三层披露 + 只建涉及的 T01/T03 详情页（复用现有标注图）+ 学习区一张"球理"入口卡。不重构 IA、不上参数扫描。
     - 阶段2（战术/综合类 drill 上线时）：学习区重构成结构化球理索引、现有瞄准页并入、补参数扫描配图 + 战术布局图、酌情改 Tab 名。
     - 阶段3（建议 v1.1）：系统训练模式 Drill Type 5/6/7。

- **理由**：所有约束（深链正交 / 理论横跨物理+战术 / 视觉基建在角度Tab / 不动 5 Tab / 完美主义防黑洞）共同把答案逼向"角度Tab 学习区作球理中心 + 分阶段 + 深链优先"。复用度最高、IA 扰动最小、概念站得住。

- **影响（命中 ADR 触发）**：
  - **跨模块边界**：13 首次 import 16 的 `contracts/*.json`（vendor 快照进 `Resources/Theory/`，版本锁 16 v1.0；离线优先承袭 ADR-002）。
  - **新内容/数据策略**：`DrillContent.theoremIds/moduleIds?` + `TutorialSection.theoremRefs?`（可选、向后兼容，承袭 `shotIntent` 模式）；课程地图 `curriculum-map.md` 作内容完备真源。
  - **跨项目闭环**：达成 16 中枢卡的 v1.0 final 条件（≥1 Drill 消费 contracts）；双方建 `*-CONSUMPTION/HANDOFF-LOG`。
  - 预计改/新增：`DrillContentService.swift`（DTO 扩字段）、`Resources/Drills/schema.md`、`Resources/Theory/`（vendor）、理论详情页视图（复用 `AngleTrainingScene`）、`AngleHomeView.swift`（学习区入口卡）、c042 JSON、`content-engineering/SKILL.md`（三 SOP）。

- **替代方案**：① 理论放动作库——库是"练什么"目录，混入"为什么"糊化且与角度学习区抢，未采纳；② 理论开第 6 Tab——违反固定 5 Tab，且独立栏诱发无限扩张黑洞，未采纳；③ 理论放角度学习区但作"最终归宿且立刻全量重构"——战术理论字面错配 + 现在做范围过大，改为分阶段（阶段1 仅竖切）；④ 社媒剪片段进 App——版权/拒审红线，未采纳，改为"拿球形 idea + 引擎复刻"。

- **遗留 / 待用户拍板**：课程地图 §6 三参数（每格配额 / L4 取舍 / 系统训练模式定位）；参数扫描渲染模式与战术布局图属阶段2；存量示范素材批量录制 ⏸ 暂停等用户编排台录制（沿用 2026-06-13 拍板）。

### ADR-P12-02 — 多球形精讲隔离 + 精讲全屏看图 + 配图 PNG/动态选用

- **日期**：2026-06-18
- **状态**：✅ 已采纳（用户多轮选项式拍板）。命中 ADR 触发：**新内容/数据策略**（`tutorial` schema 扩 `formations` + section 扩 `clip`）。
- **背景**：用户反馈精讲页面两个问题——①一个 drill 可能含**多个球形**（不同摆球布局），各自的精讲文字需要**隔离**（视频按序排/ gif 拼接即可，唯精讲不能混在一条连续滚动里）；②精讲配图嵌在卡片里太小，需要**点击全屏看**（弹出放大）。澄清确认现状：`DrillTutorial` 是扁平 `sections`，无球形分组；section 只有单张静态 PNG（`UIImage(contentsOfFile:)`，gif 不会动）；精讲图无任何点击/缩放；全仓库无看图组件。

- **决策（用户逐项选定）**：
  1. **多球形数据结构 = `tutorial.formations` 可选层（加法式）**。单球形继续用 `sections`，多球形用 `formations:[{id,title,sections}]`；二选一，70+ 旧 drill 零改动。
  2. **切换器 = 顶部吸顶分段控件**（`Picker .segmented` + `LazyVStack` pinned header）——长文纵向滚动不与横滑分页手势打架。
  3. **详情页球台预览 = 只画第一个/代表性球形**，多球形完整展示集中在精讲页（详情页不改）。
  4. **gif → 静音循环 mp4**，复用现有 `AVPlayer`（`AVPlayerLooper`/`AVQueuePlayer` + `AVPlayerLayer`，无控件、静音、循环）。
  5. **全屏看图 = 图集翻页 + 捏合/双击缩放 + 下滑关闭**（新增可复用 `TutorialMediaViewer` + `ZoomableImageView` + `LoopingPlayerView`）。
  6. **每节配图 = PNG 海报 + 可选 mp4 片段**：有 `clip` 时海报显**播放角标**，点击才播（决策 poster_tap，滚动页不分心/省电）；缺 `clip` 则海报本身可点开缩放。**选用规则**：讲位置/几何/落点用 `image`；讲运动/走位/杆法效果再加 `clip`。

- **实现**：`DrillContentService.swift`（`DrillTutorial.sections` 改可选 + 新增 `formations`/`TutorialFormation`；`TutorialSection` 加 `clip`；service 加 `tutorialClipURL(named:)`）；`DrillTutorialView.swift`（统一 `ResolvedFormation` 模型 + 吸顶 `formationPicker` + 复用 `sectionCard` + 图片点击/播放角标 + `TutorialMediaViewer`/`ZoomableImageView`/`LoopingPlayerView`，全部内置避免改 pbxproj）。`DrillTutorials/` 为 folder reference，新增 `.mp4` 自动打包。

- **影响**：schema/SOP 同步更新（`Resources/Drills/schema.md`、`content-engineering/SKILL.md` §「多球形精讲 + 配图选用」）。向后兼容：旧 drill 无 `formations`/`clip`，解码与渲染照旧。

- **验证**：`make build` BUILD SUCCEEDED、lint 0。**⏳ 待人工**：真机/模拟器走查多球形切换 + 全屏看图缩放/翻页/下滑关闭 + clip 循环播放（需先有一条多球形/带 clip 的示范内容）。

- **替代方案**：① 顶部整页横滑分页 TabView——与纵向滚动手势冲突、要求等高，未采纳；② schema 强制一节只能 PNG 或 mp4——不如「海报+可选 clip」自由且有兜底，未采纳；③ 多球形拆成多个独立 drill——不满足「一个 drill 多球形」诉求，未采纳。

- **遗留 / 非阻塞**：精讲 `clip` 的内容生产（gif→mp4 转码脚本）与首条多球形示范待排期；per-formation 视频归属标签（当前视频仍 drill 级顺序排）属后续增强。

- **后续（2026-06-18，同日）— 视频也支持缩放**：用户走查发现「视频示范点进去不支持放大缩小」。把 `ZoomableImageView` 的缩放逻辑抽成**通用可复用** `ZoomableContainer<Content>`（捏合/双击放大 + 放大后平移 + 可选纵向下滑关闭，内部不依赖内容类型），统一用于三处：①精讲静态图、②精讲 clip（`LoopingPlayerView`）、③详情页示范视频（`DrillVideoPlayerSheet` 的 `VideoPlayer`，保留系统播放控件、缩放只读不拦截控件/scrubber，关闭走 sheet 自身 + 关闭钮故不开 swipeToDismiss）。`ZoomableContainer` 设为 internal 以便 `DrillDetailView` 跨文件复用。验证：`make build` BUILD SUCCEEDED、lint 0。改：`DrillTutorialView.swift`（抽 `ZoomableContainer` + clip 包裹）、`DrillDetailView.swift`（示范视频包裹）。**⏳ 待人工**：真机验证三处缩放手势与视频控件/翻页/下滑关闭共存无冲突（`simultaneousGesture` 行为需真机确认）。

### ADR-P12-03 — 「一个 drill = N 个有覆盖依据的球形」承载方案（多球形沿既有 DrillBoards 线 + 变量档案 sidecar）

- **日期**：2026-07-16
- **状态**：✅ 已采纳（球形序列专业化方案 v1 批次 B3，iOS Architect）。命中 ADR 触发：**数据结构 / 内容承载策略决策**（多球形 + 变量档案元数据落位）。
- **背景**：B2（`docs/research/20260716-drill变量覆盖设计方法论.md`）确立「一个 drill = N 个有覆盖依据的球形」结构——样板中袋角度球 8 个球形，每球形含 cue/target/pocket/行进线切角 θ/变量取值（dtp、d、侧别、近库）/难度序号。需要决定这套结构在数据层与 App 内如何承载，且 B5 全库审计与后续批量重构（B6+）需要**机器可读**的每球形变量取值。
- **代码现状（2026-07-16 读码核实）**：
  - 运行时单球形假设集中在 `shotIntent.shots.first`：`DrillShotResolver.shotInput(for:)`（L18–23）、`DrillBoardBuilder.board(for:)` / `referenceShot(for:)`（L33–42）、`DrillSceneView.setup`（L66，经 resolver）。`ShotIntent.shots[]` 的语义是**一个球形内的多杆序列**（注释 L21–22「combined/positioning 等多杆球」，全库唯一多杆实例 `drill_c042` 3 shots），不是多球形。
  - **多球形承载线已存在且运行时已支持**（ADR-P12-02 + 试打模式 D4 + Q19.2④）：每球形一条 `PositionPlaySequence`（`content/position_play/sequences/drill_cNNN__<token>-<名称>-<N>杆.json` → `make tryout-sync`（Makefile L162–169）→ Bundle `DrillBoards/`），`DrillTryoutBoardStore.formations(for:)` 按文件名前缀聚合、试打页可选球形/逐杆播放；精讲侧 `tutorial.formations`（`DrillTutorialView` 吸顶分段控件）承载每球形隔离图文。现存 51 个 drill 有 `__<token>` 式样序列文件（共 87 个），其中 21 个 drill 已含 ≥2 个球形（如 c030 5 球形、c005/c010/c042 各 4 球形）——`ls DrillBoards/` 实测计数。
- **选项**：
  - **A. 沿用既有多球形线**：每球形一条 `PositionPlaySequence`（DrillBoards + tryout-sync）+ 精讲 `tutorial.formations` 分段；drill JSON 的 `shotIntent`/`animation` 保持**单代表性球形**（详情页演示/缩略图用）。
  - **B. 扩展 drill JSON 承载多球形**：新增结构化 `formations` 字段（每球形含 shotIntent 级摆球 + 变量元数据），改 `DrillShotResolver`/`DrillBoardBuilder`/`DrillSceneView`/缩略图的 first 假设，详情页与试打页 UI 增加球形切换。
  - 变量档案元数据落位子决策：**M1** drill JSON 新可选字段 / **M2** 仓库侧 sidecar JSON（不进 Bundle）/ **M3** 仅设计文档留档。
- **决策**：**选 A + M2**。多球形沿既有 DrillBoards 序列 + `tutorial.formations` 线；变量档案落**机器可读 sidecar** `content/drill_profiles/<drillId>.profile.json`（仓库真源，不进 App Bundle），schema 草案见 `Resources/Drills/schema.md` §「多球形承载与变量档案（B3 定稿、B4 首用）」。
- **原因**：
  1. **运行时已全线支持 A**：试打选球形、逐杆序列播放、精讲分段均已上线（Q19.2④ 验收 6/6 UI 测试），A 的增量仅是「按 B2 设计生产内容」，零代码改动、零回归面。
  2. **B 的改动面大且语义冲突**：`shotIntent.shots[]` 已被占用为「一球形内多杆」，再塞多球形会把两条正交轴（球形 × 杆）混进同一数组；如另开 `formations` 字段则与 DrillBoards 序列线形成**两套竞争的多球形表示**（同一球形在 drill JSON 与序列 JSON 各存一份坐标，必然漂移）。改动面覆盖 `DrillShotResolver` L18、`DrillBoardBuilder` L33/L41、`DrillSceneView` L66、`DrillThumbnailRenderer`、详情页/试打页 UI 与 `DrillContentValidationTests`——收益却只是把已有能力换个地方再实现一遍。
  3. **变量档案选 M2（sidecar）**：唯二消费方是 B5 审计与 B6+ 批量重构，均为**仓库侧离线工具**（Python/脚本读文件），App 运行时今天没有任何 feature 消费 θ/dtp/d 档位——进 drill JSON（M1）会白白扩大解码面与校验面；仅设计文档（M3）不满足「机器可读」硬需求。sidecar 与 `content/position_play/` 同层，天然进 git 可 review。
  4. **一致性**：延续 ADR-P12-02「多球形 = formations 加法式承载」与「内容真源在 `content/`、Bundle 是同步产物」的既有格局。
- **决策后果与迁移路径**：
  - drill JSON 的 `shotIntent`/`animation` 语义**收窄为「代表性球形」**（profile 中 `representative: true` 的那条，缺省难度#1）；schema.md 已注明。
  - 球形与序列文件的对应靠文件名 token（`drill_cNNN__<token>-…`）↔ profile `formations[].sequenceToken` 关联；token 约定用 B2 球形 ID（如 `A1`…`A8`，不得含「-」，`DrillTryoutBoardStore.token(fromFileName:)` 解析约束）。
  - **若未来 App 内要展示变量标签**（如试打选球形列表显示「θ=30° 右切」）：走加法式迁移——把 profile 的最小子集（标签串或结构化档位）提升为 drill JSON 可选字段，旧内容零改动，与 `shotIntent`/`formations` 先例同构；届时另立 ADR。
  - B5 审计脚本读 `content/drill_profiles/`（存量 drill 无 profile = 审计输出「无变量档案」缺口行，正是审计要暴露的现状）。
  - ⛔ 红线兼容：本承载不依赖也不允许「从存量 shotIntent 批量反推生成序列」——新球形的序列文件由 B2/审计设计**正向生成初始摆球**（initial-only 序列合法，`DrillTryoutBoardStore` 只要求 `initial.onTable` 非空，无 steps 时序列模式自动降级），示范击打 steps 仍由编排台人工录制（H-xx）。
- **验证**：本批**零代码改动**（决策 + 文档），`DrillContentValidationTests` 无需重跑；schema.md 草案节已落。
- **替代方案弃选理由汇总**：B（扩 drill JSON 多球形）——语义冲突 + 双真源漂移 + 改动面大，未采纳；M1（变量档案进 drill JSON）——运行时无消费方，扩大解码/校验面，未采纳（保留为未来加法式迁移路径）；M3（仅文档留档）——不满足 B5/B6 机器可读需求，未采纳。
- **遗留**：B4 按本 ADR 落地中袋角度样板（见方案 v1 批次表）；profile 的 jsonschema 校验脚本可在 B5 建审计工具时顺手补（非本批范围）。

### ADR-P12-04 — 首次 vendor 16 contracts + 理论正文硬编码 SwiftUI（球理索引骨架）

- **日期**：2026-08-07
- **状态**：✅ 已采纳（`问题集合_v30.md` D-v30-1 用户拍板 + W0 落地）。命中 ADR 触发：**跨模块边界**（13 首次把 16.billiard_theory 的 `contracts/*.json` 快照进本仓并打进 App Bundle）+ **数据策略**（理论正文形态：硬编码 SwiftUI 而非 JSON + 渲染器）。
- **背景**：ADR-P12-01 已定「理论之家 = 练习 Tab 学区」，但一直卡在「理论内容以什么形态进 App」。v30 首版 W0 曾按「JSON schema + `TheoryContentService` + 渲染器」设计；2026-08-07 用户拍板改为**硬编码 SwiftUI 页**（沿现有 9 张学页的 `LearnDocChrome` 模式）。第一批范围 = 10 条定理 + 5 步流程 + 速查表共 12 篇。

- **决策**：
  1. **理论正文 = 硬编码 SwiftUI 视图**（每篇一个 `TheoryT??View.swift`），运行时**不做** JSON → 正文渲染，不建 `TheoryContentService`、不定理论内容 schema。
  2. **仍 vendor contracts**：`theorem-tags.json` / `module-tags.json` / `run-out-flow.json` 逐字节快照进 `QiuJi/Resources/Theory/contracts/`，以 folder reference 打进 Bundle（`project.yml` `sources` 下 `type: folder` + `buildPhase: resources`，沿 `Drills`/`DrillBoards` 先例）。用途收窄为三项：**W5 层 2 一句话弹层数据源**、**`theoremIds`/`theoremRefs` 合法性校验真源**、**索引页副标题取材源**。
  3. **路由参数化**：`AngleRoute` 只加两个 case——`.theoryIndex` 与 `.theoryPage(TheoryPageID)`（`TheoryPageID` = t01…t10 / flow / quickRef），⛔ 不塞 12 个裸 case。详情页在 `MainTabView.theoryDestination(for:)` 的 switch 里逐页注册（W1–W4）。
  4. **索引页全量列 12 条，未注册项置灰 + 标「即将上线」+ 不可点**（主控裁定）；未注册 id 若被深链命中，落 `TheoryPagePlaceholderView` 兜底，⛔ 不出现空白页/崩溃。上线状态由 `TheoryCatalog.entries[].isPublished` 与 `theoryDestination` switch **成对维护**。
  5. **索引页副标题：语义等价的限定改写**（🔄 **2026-08-07 W1 修订，来源 X-v30-2**；原条为「只准截断」）：
     - **原口径**（W0）：副标题必须是 vendored `statement_one_liner` / `run-out-flow.description` 的**连续子串**，`TheoryCatalogTests` 以「子串包含」断言固化。
     - **修订原因**：只截断导致 12 条用户可见文案残留英文术语（`OB` / `cut 14°–49°` / `stun` / `squirt + swerve + throw` / `key ball` / `Capelle 9 档 Spectrum` 等），与 `问题集合_v30.md` §一.4 转写纪律「剔除英文引文、禁教材腔」直接冲突（登记为 X-v30-2，主控裁定归 W1）。
     - **新口径**：来源仍限 vendored contracts 与 16 原文，但**允许语义等价的限定改写**——可换成中文人话（术语按 `UI-IMPLEMENTATION-SPEC.md` §8.8 规范译名），⛔ 不得新增断言、不得改变适用条件、不得改动数值 / 单位 / 关键限定词；每条改写须在 `docs/research/20260807-v30理论转写模板.md` §六 留「原文 → 改写 → 依据」记录。这不构成对红线 2（转写不造理论）的放松——放宽的只是**表述形式**。
     - **测试替代（不是删断言）**：`TheoryCatalogTests` 的「连续子串」断言被四道仍有约束力的断言替代——`testSubtitleNumbersAndUnitsComeFromContracts`（副标题里每个「数值 + 单位」必须在来源串逐字出现，禁改数 / 换单位 / 造数）、`testSubtitlesKeepSemanticAnchors`（逐条钉死语义锚词，禁把适用条件写丢）、`testSubtitlesUseNoLatinLetters`（英文术语不得回流）、`testRewriteInventoryMatchesDocumentedDecision`（「逐字 / 改写」条目集合必须与文档清单完全一致，逐字条目被偷改或改写条目被回退都会红）。逐字取材的 t05 / t07 仍保留原「连续子串」断言（`testVerbatimSubtitlesRemainVerbatimSubstrings`）。
     - 详情页正文口径不变：允许口语化转写，禁造新断言。
     - **成对维护面扩到三处**：`theoryDestination` switch / `TheoryCatalog.isPublished` / 测试侧上线清单（`TheoryCatalogTests.registeredPageIDs` + `V30W0TheoryIndexUITests.publishedPageIDs`），由 `testPublishedEntriesMatchRegisteredDestinations` 守。

- **权衡（选硬编码的已知代价，须记账）**：
  - ⚠️ **16 修订理论表述 → 必须改 Swift 代码并重新发版**。正文不在 JSON 里，无法 OTA、无法随 contracts 自动更新。升级通道写在 `QiuJi/Resources/Theory/README.md`：重新 vendor → 逐字段 diff → **人工**修订受影响的硬编码页。
  - ⚠️ 12 篇正文与 contracts 之间是**弱一致**：只有副标题与 id 合法性有测试兜底，正文措辞的漂移靠人工 diff 发现。
  - ✅ 换来的是：零新增解码/服务层、与现有 9 张学页同一套组件与视觉、富排版（矩阵/步骤卡/标注图/深链）不受 JSON 结构束缚、W1–W4 可并行推进。
  - ✅ 若未来正文确需数据驱动（如多语言、OTA 修订）：走加法式迁移——先把「一句话陈述 + 误区条目」等结构化部分抽成 JSON，视图改读 service，届时另立 ADR。

- **实现（v30 W0 实际改动）**：新增 `QiuJi/Features/AngleTraining/Theory/TheoryCatalog.swift`（`TheoryPageID` / `TheoryGroup` / `TheoryIndexEntry` / 12 条静态目录）、`TheoryIndexView.swift`（四分组索引页 + `TheoryPagePlaceholderView`）、`QiuJi/Resources/Theory/{README.md,contracts/*.json}`、`QiuJiTests/TheoryCatalogTests.swift`、`QiuJiUITests/V30W0TheoryIndexUITests.swift`；改 `AngleHomeView.swift`（两个 route case + glyph/palette + `learnEntries` 置首「球理」卡）、`MainTabView.swift`（`theoryDestination` 注册表）、`CoverPalette.swift`（`PracticeMulticolor.theoryIndex` 靛蓝对）、`PracticeCoverVisual.swift`（legacy 封面目录 switch 穷尽性，非生产封面）、`project.yml`（Theory folder ref + excludes）。组件规范落 `docs/research/20260807-v30理论页组件规范.md`。

- **验证（真实输出，产物落盘 `build/v30-w0-logs/` 与 `build/v30-w0-screenshots/`）**：clean `xcodebuild ... build` **BUILD SUCCEEDED**（`build-clean.log` L4289；新文件编译于 L882–891；`CpResource … 球迹.app/Theory` L4144）；`TheoryCatalogTests` + `CoverPaletteContrastTests` + `PracticeCoverCatalogTests` **TEST SUCCEEDED**（`tests.log`，22 用例全过，含 Bundle 内 contracts 解析与副标题子串断言）；`V30W0TheoryIndexUITests` Light/Dark 各 **TEST SUCCEEDED**（12 条目全量呈现 + 全部不可点 + 点击不导航）；vendor 三文件与 16 源 `shasum` 三方（16 源 / 13 仓库 / App Bundle）完全一致（`vendor-verify.log`）。

- **登记事实**：16 仓库主线已 v1.0-rc4（2026-05-07），但其 `contracts/*.json` 自 rc3 起未重生成，文件内 `theory_version` = `v1.0-rc3`（`generated_on` 2026-05-05/06）。本快照与 16 磁盘逐字节一致；README 已如实注明，并作为批外事项回传主控（建议请 16 侧在 v1.0 final 前重生成 contracts）。

- **替代方案**：① JSON + 渲染器（v30 首版设计）——正文可 OTA、与 16 强一致，但需新建 schema/service/渲染器，且矩阵/步骤/标注图这类富排版难以 JSON 化，用户拍板未采纳（保留为未来加法式迁移路径）；② 直接引用 16 仓库路径而不 vendor——离线优先与可重复构建被破坏（ADR-002），未采纳；③ 索引页只列已上线项——用户看不到全貌、W1–W4 每批都改索引结构，主控裁定改为全量 + 置灰。

- **遗留**：W1（T03/T08 试点 + 转写模板）→ W2/W3/W4（10 篇正文）→ W5（`theoremIds`/`theoremRefs` + c042 挂接 + 闭环记账）→ W6（9 张学页归组混编 + 全链路复验）。参数扫描配图与战术布局图不在 v30 范围。
