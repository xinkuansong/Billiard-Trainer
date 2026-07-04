# P18 — 发布收敛（Release Convergence）

> 来源：`docs/research/20260703-发布前系统优化方案.md`（v2 细化稿）。
> 拍板：2026-07-03 用户确认 **D1–D14 全部按建议执行**（详见方案 §4）。
> 范围：v1.0 发布线（方案 §3 v1.0 表 1–10 行）。v1.x 项（WP-B 翻袋解球引擎化、斯诺克 v2、反解加密、精讲批量迁移、OTA 通道等）**不在本 Phase**，发布后另立卡。

---

## 🔴 全局硬约束（每个任务 DoD 强制附加）

1. **UI 美观性验收（用户强调，不可跳过）**：任何 UI 相关修改，完成后必须
   a. `make build` 通过；
   b. 在模拟器实跑受影响页面（UI 测试截图或手动截屏），**逐张查看截图**核验布局/间距/配色/字号无退化且美观；
   c. 截图核验结论（通过/问题清单）写入本卡对应任务行；发现丑/破版当场修，不得带病标 ✅。
2. **回归纪律**（方案 §5）：物理类改动过 `PhysicsEngineTests`(23)+`PhysicsInvariantTests`(12)+`PositionPlaySolverTests`(13)+`SnookerSolverTests`(4)；IA/文案改动过 `ScreenshotTourUITests`+`P5_AngleTrainingUITests`；组件收口过 12 场景页截图对照。
3. **诚实交付**：声称完成必须附真实 build/test 输出；未验证如实说未验证。

---

## 执行编排（7 批，串行为主）

> 编排原则：先立结构（IA），再做最大工程块（交互统一），再收风格，观感/产品/内容随后，发布闸门收尾。每批结束 = 一次检查点（更新 PROGRESS + 截图核验记录）。人工项（H 系列）与代码批次**全程并行**。

| 批 | 内容 | 依赖 | 预估会话数 |
|---|---|---|---|
| B0 | 人工项立即启动（与代码并行，见下） | 无 | 🧑 |
| B1 | WP-D 结构层：角度 Tab IA 四分段重排（R1）+ 孤儿页清理 | 无 | 1 |
| B2 | WP-A 统一击球交互：手动瞄准 + 自由击球模式 + ShotControlBar | B1（新入口卡挂新 IA） | 2–3 |
| B3 | WP-D 风格收口：组件归位/单一真源/明暗策略/力度清理 | B2（ShotControlBar 先就位） | 1 |
| B3+ | 截图审查追加项（2026-07-04）：导航栏/顶部区规范 + 色彩语义 + 冗余合并 + 若干 bug | B3（先立 SPEC 规范再逐页对齐） | 1–2 |
| B4 | WP-C 观感反馈：落袋下沉 + 音效接线 + 贴近球放大镜 | 无强依赖，可与 B3 换序 | 1 |
| B5 | 合规与产品收口：占位链接/PIPL 弹窗/试一杆/通知/埋点/iPhone-only/权益审计 | P1「试一杆」依赖 B2 自由击球 | 1–2 |
| B6 | WP-E 内容：标注模板 v2 + 精选视频回填（含体积实测） | 无（重渲可后台跑） | 1 |
| B7 | 发布闸门：三态走查 + 包体积 + c042 回滚 + 人工项收尾核对 | B1–B6 全部 ✅ | 1 + 🧑 |

---

## B0 人工项（🧑 今天即可并行启动）

| 任务 | 状态 | 说明 |
|------|------|------|
| T-P18-H1 App 备案（ICP）启动 | ⏳ | **最高优先**——个人开发者备案周期 1–4 周，唯一可能卡死发布日期的外部流程；已挂 `HUMAN-REQUIRED.md` H-19 |
| T-P18-H2 音效素材下载（H-18） | ⏳ | Freesound CC0，4 类 7 文件，30–45min；B4 音效接线的前置 |
| T-P18-H3 隐私政策页面上线（H-09） | ⏳ | 与 B5 R1 占位链接修复联动 |
| T-P18-H4 TP-P7 订阅人工测试 | ⏳ | StoreKit sandbox，30min |
| T-P18-H5 ADR-P10-09 真机手感验收 | ⏳ | 分离角页+编排台过验收单（#1-d，v1.0 前必做） |

---

## B1 — WP-D 结构层（IA 重排）

| 任务 | 内容 | DoD | 状态 |
|------|------|-----|------|
| T-P18-01 | `AngleHomeView` 四分段重排（学/练/打/解，方案 #9 R1）：entry 数组重组 + 新「自由击球」占位卡（B2 落地前隐藏或直达编排台自由模式）+「球理」入口卡占位 + 卡片副标题文案重写 | 四分段渲染正确；副标题可读 | ✅ 2026-07-03（自由击球=直达 `PositionPlayComposerView(initialMode:.free)`；球理卡只留代码注释位不渲染，见 ADR-P18-01） |
| T-P18-02 | 孤儿页删除：`AngleTestView`(298行)/`SceneAnglePredictionView`(341行)/`AngleHistoryView` standalone wrapper（保留 `AngleHistorySection`）+ 死路由 `HistoryRoute.statistics→EmptyView` 处理 | 生产代码零引用确认后删除；build 过 | ✅ 2026-07-03（连带删 `AngleTestViewModel`/`BTAngleTestTable`/`BTBilliardTable`/`SceneAngleViewModel`/`AngleTestViewModelTests`；文件改名 `AngleHistorySection.swift`；`make build` ✅） |
| T-P18-03 | 路由与测试同步：`MainTabView.angleDestination` 增删 case；`ScreenshotTourUITests` 中文标题引用 + `P5_AngleTrainingUITests` 同步；截图导览重录 | 两 UI 测试全绿 | ✅ 2026-07-03（`P5_AngleTrainingUITests` 8/8 绿——重写为四分段冒烟；`ScreenshotTourUITests` 全类 14min 跑完全绿；`QiuJiTests` 437/437 绿 2 skip） |
| T-P18-04 | ADR：IA 重排（跨模块边界变更） | ADR 落本卡末尾 | ✅ 2026-07-03（ADR-P18-01） |
| ✅门 | **UI 美观性验收**：角度 Tab 首页四分段截图逐张核验（含 Dark Mode） | 截图结论记录 | ✅ 2026-07-03 通过：学/练/打/解 4 分段 × 明/暗 8 张逐张核验（tour u01/u02/u02b/u02c + dark 重跑）——分段 Tab 下划线正确、双列海报卡无破版、副标题单行可读、chip（物理/2D/走位/识别/SIM）位置正常；「批量出片台」SIM 卡仅模拟器可见符合预期；无问题清单 |

## B2 — WP-A 统一击球交互（v1.0 核心增量）

| 任务 | 内容 | DoD | 状态 |
|------|------|-----|------|
| T-P18-05 | 组件下沉（3-1）：`BTAimWheel` 抽 `Core/Components/`（脱 sim-only）+ `ThicknessOverlapIcon` 抽出加 size 参数；原调用点改引用 | 批量出片台/角度与打点页行为不变 | ✅ 2026-07-03（新 `Core/Components/BTAimWheel.swift` 收 `BTAimWheel`+`ThicknessOverlapIcon`；批量出片台/角度与打点页改引用；`make build` ✅） |
| T-P18-06 | 瞄准射线拖动手势（3-2）：`AngleSceneView` 加 `onAimHandleDragged` + 手柄节点（44pt 命中，优先于拖球）；拖动中实时 ghost 贴目标球滑动 + 切角/厚度读数胶囊 | 分离角/编排台/球形生成器三页拖球回归不破 | ✅ 2026-07-03（`AngleSceneView` 手柄命中优先于拖球；`AngleTrainingScene.setupAimHandle/updateAimHandle`；纯几何 `freeAimFirstContact` 逐帧 ghost+切角读数；编排台+批量出片台接线；拖球回归见 tour 全绿） |
| T-P18-07 | 编排台自由模式接入：底栏 `BTAimWheel`（`aimMode==.free` 显示，接 `freeAimBearingDeg`/`nudgeFreeAim`）+ 场景手柄拖动 | 既有「点选定向」行为不回退 | ✅ 2026-07-03（`PositionPlayComposerView` 贴桌右缘齿轮 + 手柄拖动；点选定向保留；截图 b2-03 核验） |
| T-P18-08 | 自由击球模式（5.3，D2=编排台派生）：编排台自由模式补齐相对关系可视化（ghost/厚度重叠/切角读数/`extraBallPaths` 碰后方向预览）；角度 Tab「打」分段入口卡 → `PositionPlayComposerView(initialMode:.free)`；B 类页「试打」跳转带球局快照 | 手动转向时假想球/读数实时联动 | ✅ 2026-07-03（首碰胶囊=厚度重叠图示+切角+厚度名+碰球号；入口卡 B1 已落地；思路/打一走二想三/做斯诺克三页 `ShotTryFreePlayButton` 带 `currentSnapshot()` 跳 `PositionPlayComposerView(initialBoard:initialMode:.free)`；截图 b2-05/06/07-tryplay 验证球局快照正确带入） |
| T-P18-09 | 分离角页手动瞄准开关（D3）：`ShotSimulationView` 加「手动/自动」chip；`ShotSimulationViewModel` 加 freeAim 分支（~60 行，参照 `PositionPlayViewModel` L50–58） | 手动方向如实模拟、与自动解虚线对比 | ✅ 2026-07-03（`AimMode` chip + `recomputeManual`=`simulateFree` 如实模拟 + 自动解缓存虚线对照 + 齿轮/手柄/`bearingDeg·rotatedAim` 统一进 `AngleSceneCalculator`；截图 b2-02 核验） |
| T-P18-10 | `ShotControlBar` 统一组件（10-a）：新建 `Core/Components/ShotControlBar.swift`（打点入口/力度/瞄准模式 chip/主操作按钮组槽位）；A 类三页先换（纯重构）→ B 类三页换只读形态+「试打」入口 → Scene3D 自绘 FAB 换 `BTSceneFAB` | 换装后 12 场景页截图对照无布局回退；`ScreenshotTourUITests` 绿 | ✅ 2026-07-03（`ShotControlBar` editable/readOnly 两形态 + trailing 槽位 + `ShotTryFreePlayButton`；A 类：分离角/编排台/球形生成器；B 类：思路/打一走二想三/做斯诺克；Scene3D 自绘 64pt FAB 删除换 `BTSceneFAB`（辅助=neutral、答题/下一题=primary 与 Scene2D 一致）；`ScreenshotTourUITests` 10/10 + `P5_AngleTrainingUITests` 8/8 全绿 19min） |
| ✅门 | **UI 美观性验收**：编排台自由模式/自由击球/分离角/换装后 A+B 类页逐张截图核验 | 截图结论记录 | ✅ 2026-07-03 通过：新增 `testB2ShotControls` 专项巡游 10 张（b2-01 分离角自动 / b2-02 手动=齿轮+337° 读数+手柄+虚线对照 / b2-03 自由击球=齿轮+首碰胶囊「0°·全球·碰1」+碰后方向预览 / b2-04 球形生成器统一条 / b2-05–07 B 类三页只读条+橙色试打钮 / 三张 tryplay=快照正确带入自由模式）；底栏布局与换装前一致无回退；无问题清单 |

## B3 — WP-D 风格收口

| 任务 | 内容 | DoD | 状态 |
|------|------|-----|------|
| T-P18-11 | 组件归位：`BTChipRow`/`ReflectionModeControl` 移 `Core/Components/`；Scene3D 自绘 64pt FAB 已在 T-P18-10 处理则跳过 | build 过、9 个引用文件不破 | ⏳ |
| T-P18-12 | 单一真源清理（10-b/10-c）：`DrillSpinIndicator` 换 `BTSpinMiniIcon(trueScale:true)`；删死 API `StrokePhysics.velocity(forPower:)`（连带 L165–169 常量核对）；`DrillPowerBar` 量程 1.0/6.5→0.5/6.0；三处内联 `0.5...6.0` 抽 `ShotTuning.velocityRange` | 3–4 条带 spin drill 回放目验 | ⏳ |
| T-P18-13 | 明暗策略文档化 + 瞄准辅助显示策略表（10-d）：`UI-IMPLEMENTATION-SPEC.md` 写三档明暗策略 + 「8 场景页 × 6 辅助元素」矩阵；`GeometricAngleQuizView` 按场景页规范对齐 | SPEC 更新 + 逐页对齐 | ⏳ |
| T-P18-14 | BTIcon 迁移第一批（Top10 文件中取 3–5 个）+ 统一 symbol modifier 封装；其余批次容忍到 1.0.x | 迁移文件截图核验 | ⏳ |
| ✅门 | **UI 美观性验收**：drill 回放/几何测验页/迁移图标页截图核验 | 截图结论记录 | ⏳ |

## B3+ — 截图审查追加项（2026-07-04）

> 来源：2026-07-04 用户提供 13 张场景页截图 + UI Reviewer 逐张审查。结论：「不专业」观感主要来自**顶部控制区形态失控**与**色彩/控件语义混乱**两层，且这两条不在原 B3 任务里。本节承接这批增量，编号从 T-P18-31 起（不改动既有 01–30）。归属 v1.0 的进 B3+，两个 v1.x 项在末尾单列。
>
> **统一先立规范，再逐页对齐**：T-P18-31/32 是规范定义（写入 `UI-IMPLEMENTATION-SPEC.md`），其后各项按规范收口。

### 冗余诊断（先记录，处置见任务行）

| 冗余对 | 重叠证据 | v1.0 处置 |
|---|---|---|
| 翻袋解球器 ↔ 反射解球器 | 共享 `ReflectionModeControl` + `EngineCushionTracer` 底座 + 几乎同构 UI；用户心智同为「球被挡住怎么办」 | v1.0 仅改入口副标题说明差异；**合并为一页**随 v1.x #4（翻袋解球引擎化）一起做（见末尾 v1.x 项） |
| 2D 瞄准训练 ↔ 3D 瞄准训练 | `Scene3DAimingView` 注释自述「与 2D 页唯一差异是 2D/3D 分段」，且 3D 页内置 2D/3D toggle（3D 是 2D 超集） | T-P18-38：合并为一张「瞄准训练」卡，默认 2D 可切 3D |
| 思路训练器 ↔ 打一走二想三 | 打一走二想三 = 思路训练器三杆版，布局近同 | v1.0 仅入口副标题讲清差异（T-P18-33 内）；不合并 |
| 分离角与走位 ↔ 自由击球 | B2 给分离角加手动瞄准后能力重叠（摆球→手动定向→如实模拟），差异仅在教学定位、页面无文案表达 | 入口副标题写清差异（T-P18-33 内） |

### 任务

| 任务 | 内容 | DoD | 状态 |
|------|------|-----|------|
| T-P18-31 | **导航栏规范化**：`UI-IMPLEMENTATION-SPEC.md` 定义并逐页对齐——① 场景页标题颜色统一（「拍照建球形」当前为白，其余品牌绿，选一条统一）；② 右上角控件语义分工：设置=齿轮、帮助=(i)、文档操作=省略号，逐页核对现有齿轮/省略号内容归位 | 规范写入 SPEC；12 场景页导航栏截图对照一致 | ⏳ |
| T-P18-32 | **顶部控制区「最多两行」硬规范**：`UI-IMPLEMENTATION-SPEC.md` 定「场景页顶部控制区 ≤2 行，超出收进抽屉/浮层」；翻袋/反射页常驻长说明文案（「真实物理引擎按发力模拟翻库…」）收进 (i) 或首次显示一次后收起，释放球桌面积 | 翻袋/反射球桌尺寸与分离角页趋于一致；截图核验 | ⏳ |
| T-P18-33 | **入口副标题去歧义**：`AngleHomeView` 对冗余诊断表中「思路↔三杆」「分离角↔自由击球」「翻袋↔反射」的入口卡副标题重写，一眼看清各自用途差异 | 副标题单行可读、差异明确；截图核验 | ⏳ |
| T-P18-34 | **3D 瞄准页顶部黑带排查**：截图 3 顶部 toggle 与台面间大块纯黑（相机取景未铺满），确认是布局/相机 rig 问题并修复 | 顶部无异常黑带；2D/3D 切换后取景正常 | ⏳ |
| T-P18-35 | **角度与打点轨迹文字朝向 bug**：截图 5「瞄准线」「进球线」标注疑似倒置/镜像，查 `AngleTrainingScene` 文字节点 billboard/朝向处理 | 先确认复现，修复后文字正向可读 | ⏳ |
| T-P18-36 | **球形生成器「送入」收敛**：底部竖排四个全宽灰按钮（送入编排台/思路/打一走二想三/换一局）收成「送入…」菜单或一排胶囊，与全 App 胶囊语言对齐；释放面板高度 | 分发动作可达性不降、视觉统一；截图核验 | ⏳ |
| T-P18-37 | **编排台默认标题去「未命名」**：首次进入导航栏标题不再直接暴露「未命名走位」；默认标题用「走位编排台」或默认文档名改「新走位 · M月D日」，文档名放次级位置 | 首次进入标题不显「未命名」；截图核验 | ⏳ |
| T-P18-38 | **2D/3D 瞄准合并为一卡**（冗余诊断）：`AngleHomeView` 合成一张「瞄准训练」卡（默认 2D 可切 3D）；`AngleRoute` 收敛；成绩 `quizTypeLabel` 按模式分记；同步 `ScreenshotTourUITests`/`P5_AngleTrainingUITests` | 两 UI 测试全绿；入口卡数减一无功能丢失 | ⏳ |
| T-P18-39 | **色彩语义定义**：`UI-IMPLEMENTATION-SPEC.md` 明确 品牌绿=主操作 / 橙=次级操作（试打） / 黄=控件量值（发力滑条） / 状态色单列，消除橙同时表「次级/警示/进行中」的混用；逐页对齐 | 规范写入 SPEC；橙/黄用途逐页核对一致 | ⏳ |
| T-P18-40 | **角色选择器统一组件**：做斯诺克（顶部 chip）与打一走二想三（右侧竖排卡片）给球指定角色是同一语义，收敛为同一视觉组件（选中态样式一致）；三杆页角色多可保留竖排布局但复用组件与配色 | 两页角色选择器视觉一致；截图核验 | ⏳（S–M，若成本超预算可降 v1.x） |
| ✅门 | **UI 美观性验收**：导航栏/顶部区/角色选择器/送入菜单/2D3D 合并卡/编排台标题逐张截图核验（含 Dark Mode） | 截图结论记录 | ⏳ |

### 转 v1.x（不在本 Phase，另立卡）

| 项 | 理由 | 归属 |
|---|---|---|
| 翻袋解球器 + 反射解球器合并为一页「解球计算器」（顶部切「翻袋进袋/绕库碰球」模式） | 合并成本与 #4 引擎化高度耦合，一起做减半；v1.0 先靠 T-P18-33 入口文案区分 | 随 v1.x #4（翻袋解球引擎化） |
| 拍照建球形空态加示例入口（「用示例照片试试」+ 示例球形） | 当前纯空态，无照片时页面为死路；非发布硬闸门 | v1.x |

## B4 — WP-C 观感反馈

| 任务 | 内容 | DoD | 状态 |
|------|------|-----|------|
| T-P18-15 | 落袋下沉观感（D1=方案 A）：`TrajectoryPlayback` 追加与导出器同参数 Y 下沉（常量抽单一真源，导出器 L416–421 改引用）；2D 顶视叠加「缩放 0.85+阴影淡出」 | 6 条回放路径落袋帧目验无退化 | ⏳ |
| T-P18-16 | 音效接线：`RackGeneratorViewModel` 开球回放补 `ShotAudioScheduler.play/cancel`（~10 行）；素材到位（H-18）后真机听感验收 | 素材缺失时静默 no-op 不破 | ⏳ |
| T-P18-17 | 贴近球放大镜（D9，10-e）：loupe 从 `BallExtractionView` L644–664 抽 `Core/Components/BTLoupe.swift`（参数化）；拖球球心距<3R 自动浮现；接入编排台/自由击球/分离角 | 拖球流畅无遮挡冲突 | ⏳ |
| ✅门 | **UI 美观性验收**：落袋帧/放大镜浮现截图核验 | 截图结论记录 | ⏳ |

## B5 — 合规与产品收口

| 任务 | 内容 | DoD | 状态 |
|------|------|-----|------|
| T-P18-18 | R1 占位链接：`SubscriptionView` L352/L356 `example.com` 统一换 `qiuji.app`（与 H-09 联动） | 链接可打开（H-09 上线后复验） | ⏳ |
| T-P18-19 | R2 PIPL 首启隐私同意：Onboarding 首步加政策摘要+同意/退出；`compliance-checklist.md` §2.1 勾选 | 首启流程截图核验 | ⏳ |
| T-P18-20 | P1「试一杆」引导（D14）：Onboarding 末步直达预置球形的自由击球场景 | 新用户路径截图核验 | ⏳ |
| T-P18-21 | P2 训练提醒本地通知（D13）：设置页开关 + 每日固定时间本地通知（UserNotifications 首次引入） | 权限请求时机合理、通知实测触达 | ⏳ |
| T-P18-22 | P3 轻量事件埋点（D12）：后端事件表 + App 侧 `EventLogger`（批量/匿名 ID/仅功能事件）+ Privacy Manifest 增量申报；核心漏斗：啊哈到达/付费墙曝光→打开→购买/功能使用 | 事件落库验证 | ⏳ |
| T-P18-23 | U1 iPhone-only（D11）：`TARGETED_DEVICE_FAMILY` 1,2→1 | Archive 配置确认 | ⏳ |
| T-P18-24 | P4 权益页文案审计：`SubscriptionView` 承诺 ↔ 实际内容量对照（精讲 1/72、引擎视频精选、isPremium 分布），措辞按真实量改写 | 审计表 + 文案修改截图核验 | ⏳ |
| ✅门 | **UI 美观性验收**：Onboarding 全流程/订阅页/设置页截图核验 | 截图结论记录 | ⏳ |

## B6 — WP-E 内容（v1.0 部分）

| 任务 | 内容 | DoD | 状态 |
|------|------|-----|------|
| T-P18-25 | 标注模板 v2（D5）：`ShotHUDView` 加切角读数列（`cutAngleDeg`，第 2 拍起）+ `SequenceStep.note` 字幕条（`composeWithHUD` 扩展）；改一处全管线生效 | 单序列试渲抽帧核验 | ⏳ |
| T-P18-26 | 精选视频回填（D6）：先实测单条 2D/3D 体积 → 定精选条数（8–12）→ `videos` 字段挂接 + mp4 进 Bundle；超预算只进 2D | 详情页播放验证 + 体积记录回填 D6 | ⏳ |
| ✅门 | **UI 美观性验收**：新 HUD/字幕视频抽帧核验 + 详情页视频区截图 | 截图结论记录 | ⏳ |

## B7 — 发布闸门

| 任务 | 内容 | DoD | 状态 |
|------|------|-----|------|
| T-P18-27 | 三 Tab 三态走查（P5/U3）：训练/记录/我的 × 首启空/少量数据/正常 × 小屏+大屏；问题按 UR 工作流记录并修复 | 走查记录归档 `tasks/ui-reviews/` | ⏳ |
| T-P18-28 | 包体积实测（S1）：Archive + App Thinning 后交付体积；回填 D6/D10 预算 | 体积数字记录 | ⏳ |
| T-P18-29 | c042 `isPremium` 回滚 true（`drill_c042.json` L12，提交前最后一步） | JSON diff 确认 | ⏳ |
| T-P18-30 | 人工项收尾核对：H-19 备案进度 / TP-P7 / H-09 / ADR-P10-09 手感 / TestFlight / App Store 资产 | HUMAN-REQUIRED 全 ✅ | ⏳ |
| QA-P18 | QA Reviewer 对照本卡全 DoD 验收 | 验收报告 | ⏳ |

---

## ADR 记录区

（B1 IA 重排 ADR、B5 埋点若涉架构决策，追加于此）

### ADR-P18-01 — 角度 Tab IA 四分段重排（学/练/打/解）+ 孤儿页清理

- **日期**：2026-07-03
- **状态**：已采纳（P18 B1 落地）
- **背景**：`AngleHomeView` 原三分段（学习/训练/工具）中「工具」堆积 10 张卡，沙盘类（摆球试打）与教练类（引擎反解）混排，用户目的不清晰；同时存量代码含三个生产零引用的孤儿页（`AngleTestView` 298 行、`SceneAnglePredictionView` 341 行、`AngleHistoryView` standalone wrapper）与死路由 `HistoryRoute.statistics`。方案来源：`docs/research/20260703-发布前系统优化方案.md` §9 R1，用户拍板 D1–D14 全按建议执行。
- **决策**：
  1. `HomeTab` 改四分段，按**用户目的**划分：**学**（球理与瞄准知识）/ **练**（角度直觉测验）/ **打**（真实物理沙盘：自由击球、分离角、编排台、球形生成、拍照建球形）/ **解**（引擎当教练的反解工具：思路、三方案、斯诺克、翻袋、反射）。标签取单字，分段 Tab 一屏可达。
  2. 新增 `AngleRoute.freePlay`：「自由击球」入口卡（打分段首位）直达 `PositionPlayComposerView(initialMode: .free)`（B2 补齐手动瞄准 UI 后成完整形态），而非空占位页——避免占位卡点进去无内容的坏体验。
  3. 「球理」入口卡**只留代码注释位不渲染**，P12 阶段 1 理论详情页落地后追加，理由同上。
  4. 删除孤儿页及其级联专属依赖：`AngleTestView`+`AngleTestViewModel`+`BTAngleTestTable`+`BTBilliardTable`（仅被前者引用）、`SceneAnglePredictionView`+`SceneAngleViewModel`、`AngleTestViewModelTests`；`AngleHistoryView.swift` 去 wrapper 后改名 `AngleHistorySection.swift`（保留被 `GeometricAngleQuizView` 复用的 section）。共享依赖 `AngleQuestion`/`AdaptiveQuestionEngine`/`AngleUsageLimiter` 仍被在用页面引用，**保留**。删除死路由 `HistoryRoute.statistics`（「统计」实为 `HistoryViewModel` 内分段，非导航路由）。
- **影响**：跨模块边界变更——`AngleRoute` 枚举增删、`MainTabView.angleDestination`/`historyDestination` 同步、`PositionPlayComposerView` 新增 `initialMode` 参数；`ScreenshotTourUITests`/`P5_AngleTrainingUITests` 分段标识与用例全面同步（P5 从旧三卡断言重写为四分段冒烟）。
- **备选与否决**：保持三分段仅改文案（否决：不解决工具堆积与目的混淆）；自由击球独立新页（否决：与编排台自由模式重复实现，B2 增量在编排台上做）。
- **验证**：`make build` ✅；`build-for-testing` 全目标编译 ✅；`QiuJiTests` 437 tests, 0 failures（2 skipped）✅；UI 测试与截图核验见 B1 任务行。

### ADR-P18-02 — 统一击球交互（手动瞄准 + ShotControlBar + B 类「试打」通路）

- **日期**：2026-07-03
- **状态**：已采纳（P18 B2 落地）
- **背景**：方案 §5.1 盘点出 6 个场景页 5 种底栏控制形态；手动瞄准能力（自由方向 + 如实模拟）只在编排台自由分支存在，分离角页只能看引擎解；B 类反解页（思路/打一走二想三/做斯诺克）给出解后用户无法「顺手试打验证」。来源：`docs/research/20260703-发布前系统优化方案.md` #3/#5/#10-a，D2=编排台派生、D3=分离角加手动开关。
- **决策**：
  1. **几何单一真源**：瞄准方向 ↔ 屏幕罗盘角换算（`bearingDeg(of:)`）与方向旋转（`rotatedAim(_:byDegrees:)`）收进 `AngleSceneCalculator` 静态方法，`PositionPlayViewModel` / `ShotSimulationViewModel` 一律委托，禁止各 VM 自算。首碰预览用纯几何 `freeAimFirstContact`（逐帧、不等物理模拟）。
  2. **手动瞄准三件套下沉复用**：`BTAimWheel`（角度齿轮）+ 场景手柄拖动（`onAimHandleDragged`，命中优先于拖球）+ 首碰读数胶囊（`ThicknessOverlapIcon`+切角+厚度名+碰球号），编排台自由模式 / 分离角手动模式 / 批量出片台三处同一交互。
  3. **分离角手动分支**：`recomputeManual()` 对手动方向跑 `simulateFree` 如实模拟（进不进袋如实展示），同时跑一次自动解（按球局 key 缓存）画虚线对照——教学定位是「拿自己的方向跟引擎解比」。
  4. **`ShotControlBar` 两形态**：`editable`（打点可点开 + 力度滑条，A 类：分离角/编排台/球形生成器）与 `readOnly`（打点指示 + 解读数 + 解摘要，B 类三页）；主操作按钮经 `trailing` 槽位注入，背景与外边距由调用方持有——换装不动各页版式。
  5. **B 类「试打」通路**：三页底栏加 `ShotTryFreePlayButton`，`currentSnapshot()` → `navigationDestination` 推 `PositionPlayComposerView(initialBoard:initialMode:.free)`，形成「反解看思路 → 带球局进沙盘亲手试」闭环。新的 Feature→Feature 导航通路（SnookerTactics/PositionPlay 解页 → 编排台）。
- **影响**：新组件 `Core/Components/ShotControlBar.swift`；`Scene3DAimingView` 自绘 64pt FAB 删除、统一 `BTSceneFAB`（T-P18-11 对应项已完成）；`ScreenshotTourUITests` 新增 `testB2ShotControls` 专项巡游作为该交互的截图回归锚点。
- **备选与否决**：自由击球独立第 13 个场景页（否决，见 ADR-P18-01）；ShotControlBar 吞并背景/边距/球库（否决：各页版式差异大，强并会造成布局回退，只统一「打点+力度」行为语义）；B 类试打放 toolbar 菜单（否决：可发现性差，解出来就该一眼看到试打）。
- **验证**：`make build` ✅；`ScreenshotTourUITests` 10/10 + `P5_AngleTrainingUITests` 8/8 全绿（19min）；b2-01…07 十张截图逐张核验通过（见 B2 验收门）；`QiuJiTests` 437/437 绿（2 skip，0 failures，3006s，TEST SUCCEEDED）。
