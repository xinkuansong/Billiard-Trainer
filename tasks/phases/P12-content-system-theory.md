# P12 — 内容体系与理论挂接（Curriculum System & Theory Integration）

> 把"广度铺满的 72 条目录"升级为"有先修关系、挂接 16 理论、可证伪完备"的训练课程；打通 16↔13 的理论消费闭环；确立内容生产的标准 SOP（理论引用 / 社媒拿球形 / 理论配图）。
> 单一真源地图见 [`../curriculum-map.md`](../curriculum-map.md)。
> 背景讨论：2026-06-14 用户复盘"拖延=对现做法不满意"，根因坐实为"生产排在系统定型之前 + 完备无可证伪终点 + 理论与内容是两座孤岛"。

## 任务清单

| 任务 | 说明 | 状态 |
|------|------|------|
| T-P12-01 | 课程地图 `curriculum-map.md`：schema/双轴/理论绑定/72 条真实填充表/缺口读数 | ✅（2026-06-14）|
| T-P12-02 | 理论挂接 schema：`DrillContent.theoremIds/moduleIds?` + `TutorialSection.theoremRefs?`（可选、向后兼容）；vendor `16/contracts/*.json` 进 `Resources/Theory/` | ⏳ |
| T-P12-03 | **c042 竖切**：c042 挂 T03/T01/T04 + 精讲三层披露；建 T01/T03 理论详情页（复用 `AngleTrainingScene` 标注图）；详情页可被 drill 深链 | ⏳ |
| T-P12-04 | 闭环记账：建 `THEORY-CONSUMPTION-LOG.md` + 翻 16 中枢卡 v1.0 final（≥1 drill 消费 contracts）| ⏳ |
| T-P12-05 | 锁定 `curriculum-map.md` §6 待定参数（每格配额 / L4 取舍 / 系统训练模式）后逐格展开 | ⏳（待用户拍板）|
| T-P12-06 | 理论"球理"中心（角度Tab 学习区升级为结构化索引）+ 参数扫描配图 + 战术布局图 | ⏳（阶段2，战术类 drill 上线时）|
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

  3. **理论之家 = 角度Tab「学习」区升级为"球理"中心**（非第 6 Tab、非动作库）。决定性理由：
     - 深链正交——理论详情页用 `navigationDestination` 可从 drill 详情直接 push，"家"放哪不影响引用（可先只建详情页、推迟首页）。
     - 角度Tab 事实上已是"懂球/学习/工具"中心（瞄准原理/球感/解球器/编排台均在此），且理论页的视觉基建（`AngleTrainingScene` 标注、编排台序列、`BTAimTableView`）**全在该 Tab 底下**。
     - 现有"瞄准原理/角度与打点/浅谈球感"页本质是 T01–T03 图解版 → 并入理论索引，消除"同一原理讲多遍"冗余。
     - 理论横跨物理+战术，"角度"字面装不下战术（T05–T10/M01–M06），故定位为该 Tab 的**知识中心**而非"角度子功能"；后续可考虑把 Tab 名改为「学习/球理」。

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
