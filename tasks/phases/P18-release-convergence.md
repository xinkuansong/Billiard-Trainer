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
| B3.5 | 品牌统一设计（2026-07-04）：线语言/重叠标注/HUD 仪表玻璃/瞄准力度交互重做/学练真台化/开球内置生成器下线 | B3+（设计真源 v4 已定稿） | 4–6 |
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
| T-P18-H5 ADR-P10-09 真机手感验收 | ⏳ | 分离角页+编排台过验收单（#1-d，v1.0 前必做）。**追加（T-P18-43/44）**：自由瞄准手指跟随灵敏度、刻度轮阻尼、力度柱档位手感一并验收 |

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
| T-P18-11 | 组件归位：`BTChipRow`/`ReflectionModeControl` 移 `Core/Components/`；Scene3D 自绘 64pt FAB 已在 T-P18-10 处理则跳过 | build 过、9 个引用文件不破 | ✅ 2026-07-04（`git mv` → `Core/Components/ReflectionModeControl.swift`；xcodegen 重生；`make build` ✅） |
| T-P18-12 | 单一真源清理（10-b/10-c）：`DrillSpinIndicator` 换 `BTSpinMiniIcon(trueScale:true)`；删死 API `StrokePhysics.velocity(forPower:)`（连带 L165–169 常量核对）；`DrillPowerBar` 量程 1.0/6.5→0.5/6.0；三处内联 `0.5...6.0` 抽 `ShotTuning.velocityRange` | 3–4 条带 spin drill 回放目验 | ✅ 2026-07-04（`DrillSpinIndicator` 整块删除换 `BTSpinMiniIcon(trueScale:true)`；死 API + maxVelocity/powerGamma/deadZone 三常量确认无他用后删；新增 `ShotTuning.velocityRange`（BTPhysicsConstants），4 处内联量程 + 导出 HUD powerFraction 全部改引用；`DrillPowerBar` vMin/vMax 改引 velocityRange（0.5/6.0）；c003/c004/c017 三条带塞 drill 详情+回放截图目验） |
| T-P18-13 | 明暗策略文档化 + 瞄准辅助显示策略表（10-d）：`UI-IMPLEMENTATION-SPEC.md` 写三档明暗策略 + 「8 场景页 × 6 辅助元素」矩阵；`GeometricAngleQuizView` 按场景页规范对齐 | SPEC 更新 + 逐页对齐 | ✅ 2026-07-04（SPEC 新增 §八：三档明暗策略（场景页黑底/常规页随系统/特例页三张列名）+ 8 场景页 × 6 辅助元素矩阵 + `showSeparationAngle` 覆盖范围声明（6 处）+ 无障碍基线；`GeometricAngleQuizView` 三处 `BTButtonStyle.primary` 换场景页品牌绿胶囊 `sceneCapsuleButton`） |
| T-P18-14 | BTIcon 迁移第一批（Top10 文件中取 3–5 个）+ 统一 symbol modifier 封装；其余批次容忍到 1.0.x | 迁移文件截图核验 | ✅ 2026-07-04（迁移 5 文件：ActiveTrainingView/DrillDetailView/ProfileView/TrainingHomeView/HistoryCalendarView 共 38 处裸 symbol → `BTIcon.*`；补常量 hammer/sliders；新增 `Image.btSymbol(size:weight:)` 统一渲染 modifier（U-I06）；训练/历史/我的三页截图核验无渲染异常） |
| ✅门 | **UI 美观性验收**：drill 回放/几何测验页/迁移图标页截图核验 | 截图结论记录 | ✅ 2026-07-04 通过：新增 `testB3StyleGate` 专项巡游 11 张（b3-00/01/02 三条带塞 drill 详情=trueScale 红斑+打滑虚线圈正确、playing 帧指示器随回放隐藏 / b3-04/05 几何测验输入+结果卡=品牌绿胶囊对齐场景语言 / b3-06/07/08 迁移图标三页正常）；TEST SUCCEEDED |

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
| T-P18-31 | **导航栏规范化**：`UI-IMPLEMENTATION-SPEC.md` 定义并逐页对齐——① 场景页标题颜色统一（「拍照建球形」当前为白，其余品牌绿，选一条统一）；② 右上角控件语义分工：设置=齿轮、帮助=(i)、文档操作=省略号，逐页核对现有齿轮/省略号内容归位 | 规范写入 SPEC；12 场景页导航栏截图对照一致 | ✅ 2026-07-04：SPEC §8.3 写入；`BallExtractionView` 加 principal 绿标题；思路/三杆/斯诺克三页省略号菜单拆出齿轮 settingsMenu（求解范围归设置、清空/重摆留省略号） |
| T-P18-32 | **顶部控制区「最多两行」硬规范**：`UI-IMPLEMENTATION-SPEC.md` 定「场景页顶部控制区 ≤2 行，超出收进抽屉/浮层」；翻袋/反射页常驻长说明文案（「真实物理引擎按发力模拟翻库…」）收进 (i) 或首次显示一次后收起，释放球桌面积 | 翻袋/反射球桌尺寸与分离角页趋于一致；截图核验 | ✅ 2026-07-04：SPEC §8.4 写入；`ReflectionModeControl` 压成单行内联滑条、长文案删除并入 (i) 原理页；翻袋/反射顶部收到 2 行、方案 pill 改浮层 |
| T-P18-33 | **入口副标题去歧义**：`AngleHomeView` 对冗余诊断表中「思路↔三杆」「分离角↔自由击球」「翻袋↔反射」的入口卡副标题重写，一眼看清各自用途差异 | 副标题单行可读、差异明确；截图核验 | ✅ 2026-07-04：五张卡副标题重写（思路=单杆走位反解、三杆=连续三杆规划、分离角=看懂分离角规则、自由击球=自由摆球任意打、翻袋=目标球翻库进袋、反射=母球绕库碰球）；b3p-01 截图核验 |
| T-P18-34 | **3D 瞄准页顶部黑带排查**：截图 3 顶部 toggle 与台面间大块纯黑（相机取景未铺满），确认是布局/相机 rig 问题并修复 | 顶部无异常黑带；2D/3D 切换后取景正常 | ✅ 2026-07-04：根因=地面 `ground_visual` 灰面在低角度相机下与纯黑背景硬切；改径向渐变纹理（中心深灰→边缘纯黑）平滑融入背景；b3p-05 截图核验无黑带 |
| T-P18-35 | **角度与打点轨迹文字朝向 bug**：截图 5「瞄准线」「进球线」标注疑似倒置/镜像，查 `AngleTrainingScene` 文字节点 billboard/朝向处理 | 先确认复现，修复后文字正向可读 | ✅ 2026-07-04：复现确认；`addInlineLineLabel` yaw 翻转逻辑对近竖直线（abs(dir.z)<0.15）改按 dir.x 判定，保证竖排中文自上而下；b3p-06 及放大裁图核验「瞄准线」「进球线」均正向可读 |
| T-P18-36 | **球形生成器「送入」收敛**：底部竖排四个全宽灰按钮（送入编排台/思路/打一走二想三/换一局）收成「送入…」菜单或一排胶囊，与全 App 胶囊语言对齐；释放面板高度 | 分发动作可达性不降、视觉统一；截图核验 | ✅ 2026-07-04：三个送入按钮收成「送入…」Menu（三目的地保留），并列「换一局」胶囊；b3p 截图核验 |
| T-P18-37 | **编排台默认标题去「未命名」**：首次进入导航栏标题不再直接暴露「未命名走位」；默认标题用「走位编排台」或默认文档名改「新走位 · M月D日」，文档名放次级位置 | 首次进入标题不显「未命名」；截图核验 | ✅ 2026-07-04：`navTitleText` 对「未命名走位」回退显示「走位编排台」；截图核验 |
| T-P18-38 | **2D/3D 瞄准合并为一卡**（冗余诊断）：`AngleHomeView` 合成一张「瞄准训练」卡（默认 2D 可切 3D）；`AngleRoute` 收敛；成绩 `quizTypeLabel` 按模式分记；同步 `ScreenshotTourUITests`/`P5_AngleTrainingUITests` | 两 UI 测试全绿；入口卡数减一无功能丢失 | ✅ 2026-07-04：`Scene3DAimingView`→`SceneAimingView`（默认 2D 可切 3D），`Scene2DAimingView` 删除；`AngleRoute.sceneAiming` 收敛；`quizTypeLabel` 按模式分记 scene2D/scene3D；两 UI 测试更新后全绿 |
| T-P18-39 | **色彩语义定义**：`UI-IMPLEMENTATION-SPEC.md` 明确 品牌绿=主操作 / 橙=次级操作（试打） / 黄=控件量值（发力滑条） / 状态色单列，消除橙同时表「次级/警示/进行中」的混用；逐页对齐 | 规范写入 SPEC；橙/黄用途逐页核对一致 | ✅ 2026-07-04：SPEC §8.5 写入（绿=主操作/品牌、橙=次级操作、金=量值与商业化、状态色单列）；逐页核对无新增混用 |
| T-P18-40 | **角色选择器统一组件**：做斯诺克（顶部 chip）与打一走二想三（右侧竖排卡片）给球指定角色是同一语义，收敛为同一视觉组件（选中态样式一致）；三杆页角色多可保留竖排布局但复用组件与配色 | 两页角色选择器视觉一致；截图核验 | ⏸ 降 v1.x（2026-07-04）：两处语义相近但结构差异大（横向 chip 行 vs 竖排卡含徽标/状态），强行统一成本超 S–M 预算且有布局回退风险；按任务行既定条款降级 |
| ✅门 | **UI 美观性验收**：导航栏/顶部区/角色选择器/送入菜单/2D3D 合并卡/编排台标题逐张截图核验（含 Dark Mode） | 截图结论记录 | ✅ 2026-07-04 通过：`testB3PlusGate` 13 张（b3p-01 副标题+合并卡 / 02-05 瞄准训练 2D 默认+3D 无黑带 / 06 轨迹文字正向 / 07-08 翻袋反射两行顶部+浮层 pill / 09 思路齿轮拆分 / 10 送入菜单 / 11-12 编排台标题 / 13 拍照建球形绿标题）；Dark Mode 复跑 `testB3StyleGate` 11 张（训练/记录/我的/详情/几何测验暗色正常）；均 TEST SUCCEEDED |

### 转 v1.x（不在本 Phase，另立卡）

| 项 | 理由 | 归属 |
|---|---|---|
| 翻袋解球器 + 反射解球器合并为一页「解球计算器」（顶部切「翻袋进袋/绕库碰球」模式） | 合并成本与 #4 引擎化高度耦合，一起做减半；v1.0 先靠 T-P18-33 入口文案区分 | 随 v1.x #4（翻袋解球引擎化） |
| 拍照建球形空态加示例入口（「用示例照片试试」+ 示例球形） | 当前纯空态，无照片时页面为死路；非发布硬闸门 | v1.x |

## B3.5 — 品牌统一设计（2026-07-04 立批）

> 来源：用户驱动「练习 Tab 整体重新统一设计，形成有品牌风格的东西」+ screenshot-v5 十六张实拍逐张审查 + 用户 13 条设计裁决。设计真源：`docs/research/20260704-练习Tab功能契约梳理.md`（v4，含设计语言「教练仪表盘」/ 线语言 7 token / 重叠标注三档 / HUD 仪表玻璃 / 交互重做 / HUD 七分区 / 15 页逐页砍增改 / 结论 12 条）。**排序**：语言地基（41/45/42）→ 交互重做（43/44）→ 页面重构（46/47/48）→ 收口（49/50/51）→ SPEC 定稿（52）。每 2–3 个任务挂一次截图验收门（含 Dark Mode）；渲染管线改动需抽 2–3 条序列重新出片核验。

| 任务 | 内容 | DoD | 状态 |
|------|------|-----|------|
| T-P18-41 | **线语言 token 落 DesignSystem** + 8 场景页收编（瞄准线白固定 / 进球线绑目标球本色·深色球高明度变体 / 球迹线金 / 对照线白虚线弃蓝 / 90° 分离角白短虚线 / 两档线宽 lineMain·lineHint）+ `SequenceVideoExporter` 同源换装 | 逐页截图核验线色线宽一致；抽 2 条序列重出片核验 | ✅ 2026-07-04：`TrajectoryStyle` 扩展为线语言唯一真源（lineMain=0.0028/lineHint=0.0020/traceColor 金/hintColor 白虚/separationColor 白短虚/contactColor 绿/hintDash·hintGap；aimRadius·potRadius 并轨 lineMain 保兼容）。设计裁决落地：**线色=球的身份**（白=母球路径、目标球本色=该球路径）+ **线型=信息性质**（实线=真实/解，虚线=对照，短虚线=释义）；金退出轨迹专属方案标记。收编：`AngleTrainingScene` 静态可视化（进球线+标签绑球色〔新增 `currentTargetNumber`〕、接触点绿弃黄、90° 垂线白短虚弃黄实线〔定长虚段一次建成拖动零重建〕、角度弧绿+白读数弃蓝、分离角线白短虚弃暖黄）；分离角页（对照白虚弃浅蓝、90° 线弃青）；翻袋（解路线绑球色弃黄、反弹点金弃红、法线白细弃青、对照白虚、接触点绿）；反射（母球路径白弃黄、碰库点金弃红、对照白虚）。导出器经 token 同源自动生效。**验证（真实输出）**：build ✅；`testB3PlusGate` 复跑 Passed，b3p-06（29° 白读数/白短虚垂线/8 号亮灰进球线/绿接触点）b3p-08/09（翻袋反射新线色）核验；drill_c001+c018 两序列重出片 TEST SUCCEEDED，静帧核验母球白弧线+1 号黄进球线+线宽统一。**后续修正（DR-021，2026-07-05）**：90° 释义线锚点目标球心→**假想球球心**（90° 法则讲母球去向）、白→**品牌绿**短虚线（定杆时白线与母球白轨迹共线不可辨），token 单点换色全消费方生效，两道截图门复跑核验 |
| T-P18-42 | **重叠标注三档组件化**（L0 假想球圈+接触点常驻 / L1 +切角小数值 / L2 全指标仅角度与打点页）+ 逐页配档表落 SPEC | 全瞄准场景 L0 可见；配档表+理由入 SPEC | ✅ 2026-07-05：**L0 组件化在场景层单点完成**——`AngleTrainingScene.ghostBallNode` 由黄色实心球重建为**品牌绿虚线圈**（16 段贴台呢平放，contactColor+lineHint，节点 API 不变 ⇒ 静态可视化/自由瞄准/解叠加/导出器全部自动换装）+ 新增 `updateContactDot(ghostCenter:targetCenter:)`/`hideContactDot()` 共享助手。接线补齐「圈+点成对」：分离角手动、编排台自由瞄准/袋口解、思路（解+几何预览）、三杆（①球预览+解）、**斯诺克解出后首次显示 L0**（`firstContact`=首碰瞬间母球球心摆圈）、导出器 `drawAimLines`。配档表+理由落 SPEC §8.7（L0-L2 定义/12 行逐页档位/显隐原则），§8.2 ghost 列指向 §8.7。**过程中揪出 P0**：`testB2ShotControls` 三连挂「Timed out while evaluating UI query」，`sample` 采样定位 `addDashedPath` 浮点相位推进死循环（潜伏自 B2，41 改虚线常量后必现）→ 重写为整数周期索引算法（FL-024，已回写 geometry SKILL）。**验证（真实输出）**：build ✅；`testB3PlusGate` Passed（b3p-06 裁剪核验绿虚圈+绿点+29° 弧）、`testB2ShotControls` Passed 10 张（手动模式圈+点、思路/三杆/斯诺克解预览）；两序列重出片 TEST SUCCEEDED，s01_still 核验导出侧绿虚圈+接触点同源 |
| T-P18-43 | **自由瞄准重做**：台面手指跟随粗调（球上起手仍移球）+ 刻度轮去数值只留三级刻度 + 删瞄准线手柄圆环（编排台/分离角手动） | 真机/模拟器手感走查；截图核验 | ✅ 2026-07-05：**粗调=手指跟随**——`AngleSceneView` 手柄 44pt 命中判定删除，pan 起手未命中球即进入瞄准跟随分支（`onAimDragged`，.began 起逐帧回调台面世界坐标，指哪打哪；球命中优先移球不变）；**手柄圆环删净**——`AngleTrainingScene.setupAimHandle/updateAimHandle/aimHandleNode` 整体删除，两 VM（编排台/分离角）删 `freeAimHandleDist` 与手柄摆位段，`handleAimHandleDrag`→`handleAimDrag`（纯方向设定），死几何 API `rayDistanceToCushion` 连带删除；**刻度轮去数值**——`BTAimWheel` 删角度数值胶囊与整十度数字标签，只留 1°/5°/10° 三级刻度（`HUDStyle.tickColor` 新助手，白 40/25/15%）+ 金色当前位置线，刻度居中横排；批量出片台经共享组件自动生效。**验证（真实输出）**：`make build` ✅；`testB2ShotControls` TEST SUCCEEDED 10 张——b2-01/02 分离角瞄准线无圆环、刻度轮无数值、金指示线正常，b2-03 编排台自由模式同落位，b2-04–07 无回退。⚠️ 待真机：手指跟随灵敏度/刻度轮阻尼手感（挂 H 项随 ADR-P10-09 手感验收一并过） |
| T-P18-44 | **ShotControlBar v2**：右缘竖直力度柱（离散档+暗调渐变+BTReadout 读数）+ 打点盘置顶成仪表柱 + 底部条简化，6 页换装 | 6 页截图核验；量程仍 `ShotTuning.velocityRange` 单一真源 | ✅ 2026-07-05：新建 `BTShotInstrumentColumn`（Z3a 右缘仪表柱：打点盘迷你图示置顶点开打点盘 + 竖直力度柱〔三级刻度与瞄准轮同族、`HUDStyle.powerGradient` 暗绿→暗金→暗橙水位渐变、金档位线、0.1 步进 detent 轻触感〕+ `BTReadout` 金读数 fixedSize 防折行）；瞄准刻度轮移**左**缘，与力度柱分居两侧（§1.5）。换装：分离角/编排台/批量出片台（editable 底部控制行删除）+ 球形生成器（开球量程仍 `RackGeneratorViewModel.powerRange` 专用）；场景页力度量程一律 `ShotTuning.velocityRange` 单一真源。`ShotControlBar` v2：**删 editable 形态**（签名平铺 velocity/subtitle/subtitleTint），B 类三页（思路/三杆/斯诺克）底栏只留解读数+试打。**验证（真实输出）**：`make xcodegen`+`make build` ✅；`testB2ShotControls` 浅色+Dark Mode 各 TEST SUCCEEDED 10 张——b2-01/02 左轮右柱落位、渐变水位+金读数「中 3.3」、底部条只剩重置/击球；b2-03 编排台同款、球库+击球正常；b2-04 生成器「大力 7.0」不折行；b2-05–07 B 类解读数行无回退；Dark 与浅色一致（场景页黑底常量） |
| T-P18-45 | **HUD 风格 token**（仪表玻璃配方/三种形状/文字三级/状态语法/刻度语法）+ **`BTReadout` 组件化** + 读数换装 + 等宽数字扫齐 + 导出 HUD 同款 | 逐页 HUD 截图「裁掉台面仍认得出球迹」；违例清零 | ✅ 2026-07-04：新建 `HUDStyle.swift`（DesignSystem 唯一真源：glassTint 黑 60%/hairline 白 12% 0.5pt/文字三级 label·value·title/value 三通道白测量·金可调·红失误/chip 状态语法/刻度三级 40·25·15%+金指示）+ `View.btHudGlass(in:)` 修饰器（暗玻璃+模糊+发丝描边，**无阴影**）；新建 `BTReadout`（label+value 仪表窗，regular/compact 两档，等宽圆体数字）。换装：角度与打点指标条（5 读数）、分离角夹角、翻袋/反射三态 pill（库数金・切球读数化・序号 compact）、瞄准训练进度 pill/答题 HUD/总结卡、角度预测统计条、编排台瞄准胶囊——**全部弃 ultraThinMaterial+shadow 改 hudGlass**。组件收编：`BTChipRow` 未选态玻璃底+白 75% 字、`BTSceneFAB` 去阴影、`BTAimWheel` 刻度三级 40/25/15%+金数字弃金底、`BTSpinPadCard` 玻璃底+绿 title+金读数、`ShotControlBar` 力度读数金（可调/解量值）+ subtitle 等宽。导出 `ShotHUDView`：打点/力度读数金 + 力度水位金填充。**验证（真实输出）**：build ✅；`testB3PlusGate`+`testScenePopups` Passed，b3p-06（指标条仪表窗）/b3p-08（解 pill 金库数）/b3p-04（进度 pill）/p01（打点盘）/p04（统计条）核验；两序列重出片 TEST SUCCEEDED，静帧核验 HUD 条金量值同款 |
| T-P18-46 | **学练四页真台化**：瞄准原理插图 / 球感锚点卡 / 进球点对照表（俯视重设计：同时见瞄准点+接触点）/ 角度预测题面（补 90° 参考线、修 75° 标签裁切） | 四页截图核验风格与场景页同源 | ✅ 2026-07-05：新建共享基建 `TableFigureRenderer`（真实 USDZ 空台离屏渲一次缓存成底图，全台/特写两种取景，正交映射钉死坐标契约：landscape 屏右=+X 屏上=−Z / portrait 屏上=+X；世界米→视图点线性换算）+ `BTTableFigure`（SwiftUI 容器，`TableFigureProjection` 暴露世界坐标摆球画线、`ballDiameter`/线宽同场景物理粗细）+ `FigureLine`（SwiftUI 侧从 `TrajectoryStyle` 同源取色零私设）+ `BTFigureBall`（`PoolBallFace` 真球面+接地影）/`BTGhostCircle`（品牌绿虚线圈）/`BTContactDot`/`BTFigureTag`。四页换装：①瞄准原理——切角全景换半台特写真台（真实右上角袋，进球线绑 1 号黄实线/瞄准线白实线/α 弧品牌绿+白读数/假想球绿圈+接触点），公式 30° 示例与厚薄四卡换台呢特写+真球面（d 标尺金=量值），术语扫替（切球角→切角、幽灵球→假想球）；②球感——四档锚点卡真台特写、2D 对比图整台真台+§1.2 线语言、30° 标签黄→白；③进球点对照表——抽象圆盘重设计为俯视真台交互图（瞄准方向竖直白实线为基准，拖滑条进球线转 α、假想球绕目标球转，瞄准点/接触点/横移 d 金标尺同见），术语扫替；④角度预测——题面台呢特写真台化（球按真实球径）、参考线补 90°、标签钳入画布治 75° 裁切、角度线/参考线/量角弧走 §1.2（白实线/白虚线/品牌绿）、确认钮禁用态走 §1.7（玻璃底+文字 30%）。**验证（真实输出）**：build ✅；`testAngleLearningPages`（扩至四页+滚动帧+参考线帧）TEST SUCCEEDED，10 张截图逐张核验：真台底图与场景页同源、线语言/重叠标注同款、90° 参考线齐全无裁切、禁用态可辨 |
| T-P18-47 | **开球内置**编排台/思路/三杆（Z7 玩法选择+摆架+开球区拖白球+就地散局，复用 RackLayout/BreakSimulator）+ **球形生成器页下线**（入口卡/路由删除，core 保留）+ 测试同步 | 三页开球流程走通；生成器入口消失无死链；UI 测试全绿 | ✅ 2026-07-05：新建 `Core/Rack/BreakFlowRunner`（生成器 VM 的「摆架→开球区拖母球→BreakSimulator 真实散局→就地落座」闭环下沉为可嵌入 runner：seed 换局+塞扰动、刮杆补回开球区、`onSettled(board)` 交付宿主；同文件出共享 UI `BreakGamePickerSheet` 暗材质玩法选择〔中八/9/6/5/4，斯诺克不加——用户拍板〕、`BreakControlBar` 取消/换一局/开球、`BreakEntryTile` 球库行首入口块）。三宿主接入（编排台/思路/三杆 VM 各 +`startBreakFlow/cancelBreakFlow`）：进开球模式自存 `currentSnapshot()`、挂起求解/约束/角色/可视化（含 `hideAllVisualization` 清假想球残留），拖拽只路由 runner 母球（限开球区），散局落座为新真相（编排台自动选下一杆、思路/三杆清角色重选），取消恢复进场前球形；顶行开球 pill、导航副标 runner 状态。生成器页下线：`AngleRoute.rackGenerator`/入口卡/`MainTabView` case/两个页面文件删除，pbxproj 同步；`ScreenshotTourUITests` 生成器段改为编排台内置开球三连拍 + 思路/三杆摆架帧。**验证（真实输出）**：build ✅；`testB2ShotControls` TEST SUCCEEDED（b2-04a 玩法 sheet / b2-04b 摆架+瞄准线+开球条 / b2-04c 散局落座自动进编排、b2-05/06-break-racked 思路与三杆同款、取消后试打正常=恢复验证）；`RackGeneratorTests`+`BreakRackPhysicsTests`（core 不动）TEST SUCCEEDED |
| T-P18-48 | **2D/3D 拆两卡**（隐藏页内 toggle、成绩分记、标题「2D/3D 瞄准训练」）+ 瞄准训练入口先弹完整训练设置再开始（训练中可换）+ 辅助线统一接线 | 两 UI 测试全绿；截图核验 | ✅ 2026-07-05：**拆两卡**——`AngleRoute.sceneAiming` → `sceneAiming2D/3D` 两 route，`SceneAimingView(initialCameraMode:)` 参数化（视角固定常量、页内 2D⇄3D toggle 删除、标题「2D/3D 瞄准训练」），练分段入口卡×2（瞄 2D 青绿 / 临 3D 深蓝）；**成绩分记**——`quizTypeLabel` 按 route 固定 scene2D/scene3D（历史口径沿用），`AngleQuizTypeFilter` 标签对齐新卡名（场景 2D/3D→2D/3D 瞄准）；**入口流程**——`setupScene` 新增 `autoStart:false`，进页先弹完整训练设置 sheet（练习模式+训练类型，`preferredColorScheme(.dark)` 治浮出层浅色违例〔§1.6，environment 方式压不暗 presentation 背景已踩坑〕，「开始训练/重新开始」金主钮），滑关兜底按当前默认开题不留死端；训练中齿轮可换=重开一轮；**辅助线统一接线**——`updateVisualization` 拆 `showOverlapMarkers`（接触点+90° 品牌绿短虚线，§1.2/§1.3 L1）与 `showAngleAnnotations`（数值角弧）两独立开关，辅助档改为保留重叠标注+90° 短虚线、仅隐藏数值弧（数值即答案）。**验证（真实输出）**：build ✅；`testB3PlusGate`（b3p-04 2D / b3p-04b 辅助档 90° 绿短虚+接触点 / b3p-05 3D 站位）+ `testUnifiedDesignPages`（u03b-settings 暗材质 sheet + u03b-2d）均 TEST SUCCEEDED，截图逐张核验 |
| T-P18-49 | 三杆角色下移 Z6 底部横排（台面恢复全宽）+ 求解三态（思路/三杆/斯诺克：就绪/求解中/尚无解）+ 编排台失误态去重 + 设置 sheet 暗材质 + 统计 chip 加字前缀 | 逐项截图核验 | ✅ 2026-07-05：**三杆角色下移**——`PlanThreeView` 右侧 70pt 竖排 `roleRail` 删除，台面恢复全宽；Z6 新增 `roleRow`（解读数行下、球库行上：①球→①袋→②球→②袋→③球 横排 chip + 清空钮，armed/filled 视觉语法不变），VM 提示文案「右侧」→「下方」四处同步；**求解三态**——核验三解页（思路/三杆/斯诺克）B2 期已具备完整三态：就绪 hint（「已就绪，点求解…」）→「求解中…」（Z1 副标题+mini spinner）→ 有解 `解 n/N · 进阶/最接近解` / 尚无解（「未找到解（试着…）」），本任务零改动仅确认与契约 §3.4 一致；**编排台失误去重**——`makeStatus` 删两处「母球进袋（失误）」早退，scratch 状态由 Z2 红 pill 唯一承担、Z1 副标题回中性（自由球/进袋/未进袋事实描述）；**sheet 暗材质收尾**——翻袋/反射两个原理 sheet 加 `preferredColorScheme(.dark)`（练习 Tab 浅色 sheet 清零；info 按钮补 AX label「原理」）；**统计 chip 加字**——瞄准训练进度 pill 三个 SF 图标换单字 label（题/袋/差/剩），与几何角度训练指标条同 `BTReadout` 语法。**验证（真实输出）**：build ✅；`testB2ShotControls` TEST SUCCEEDED（b2-06 三杆全宽台面+底部角色横排核验、开球模式无回归）；`testScenePopups` TEST SUCCEEDED（p03b 反射原理 sheet 暗材质核验） |
| T-P18-50 | 翻袋顶部重排（袋口台面直点+两行无截断）+ 多解则补「下一解」对齐反射 + 术语扫替（切角/假想球/力度）+ 页名=卡名（角度预测/翻袋解球器）+ 词表落 SPEC | 截图核验；全 Tab 术语 grep 清零 | ✅ 2026-07-05：袋口 chip 行删除改台面直点选定（高亮圈），顶部两行无截断（§8.4）；「下一解」FAB 对齐反射页；用户可见字符串扫替清零（切角/假想球/力度，含 `ShotPredictor`/`AngleDynamicViewModel` 不可行文案）；页名=卡名（角度预测/翻袋解球器，历史筛选同步）；词表落 SPEC §8.8（11 条规范术语+禁用别名）。验证：build ✅；`testB3PlusGate`+P5 全套 TEST SUCCEEDED（两处过期断言随台词更新），翻袋理想/真实两帧截图核验（解 pill「切角 14°/15°」） |
| T-P18-51 | 学→练 CTA 导流三条 + 答错回原理 + 拍照送入三目的地/步骤指示 + 角度与打点首拖提示 | 链路点击走通；截图核验 | ✅ 2026-07-05：新增 `PracticeCTA` 学页导流卡（`NavigationLink(value: AngleRoute)`）——原理→角度预测、球感→2D 瞄准训练、角度预测结果卡「去真台练」常驻+偏差较大补「回看原理」；拍照建球形送入收成「送入…」菜单三目的地（编排台/思路/**三杆**）+ 步骤指示「第 n 步 / 共 4 步 · 步骤名」；角度与打点首拖提示（`@AppStorage` 一次性，拖动后让位袋口提示）。验证：build ✅；新增 `testLearnPracticeFlow` TEST SUCCEEDED，lp01–06 六帧截图核验（CTA 卡/到达页/结果卡双链/首拖 banner/步骤指示） |
| T-P18-52 | 设计稿定稿入 SPEC §9（9.1 设计语言/9.2 HUD 分区/9.3 每页契约/9.4 重叠标注配档表）+ Changelog | SPEC 更新；Changelog 记录 | ✅ 2026-07-05：SPEC 新增「九、练习体验品牌设计定稿」——§9.1 设计语言（五签名元素 + 代码唯一真源索引表：TrajectoryStyle/场景层重叠标注/BTReadout/BTAimWheel·BTShotInstrumentColumn/HUDStyle，信号色四通道封闭）、§9.2 HUD 七分区（含铁律三条，Z6 补开球入口、Z7 注明 preferredColorScheme(.dark)）、§9.3 逐页契约（16 页现行形态表 + 全局项，含生成器已下线注记）、§9.4 指向 §8.7 不重复维护；Changelog 记录。**B3.5 批 12 任务全部 ✅ 收官** |
| ✅门 | **UI 美观性验收**：分段验收（41/45/42 后一次、43/44 后一次、46/47/48 后一次、49/50/51 后一次），每次含 Dark Mode | 截图结论记录 | 🔄 **第一段（41/45/42）✅ 2026-07-05**：浅色 `testB3PlusGate` 13 张 + `testB2ShotControls` 10 张 + `testScenePopups` 5 张逐张核验（线语言/仪表玻璃读数/绿虚圈+接触点三件套全落位，裁剪放大核验 b3p-06 与 b2-02 细节）；**Dark Mode 复跑 `testB3PlusGate` 13 张 TEST SUCCEEDED**（场景页黑底设计常量不变、练习首页暗色网格正常）。产物 `build/b42gate*`、`build/b42dark`、`build/b45hud`。**第二段（43/44）✅ 2026-07-05**：`testB2ShotControls` 浅色 + Dark Mode 各 10 张 TEST SUCCEEDED 逐张核验——瞄准线无手柄圆环、左轮（无数值三级刻度+金指示）右柱（渐变水位+金读数）两根尺子对称落位、底部条简化后无破版、B 类三页无回退、生成器读数不折行；产物 `build/b43gate`、`build/b44gate`、`build/b44dark`。余两段随 46/47/48、49/50/51 | 

## B3.6 — 练习 Tab 问题集合批（2026-07-06/07 立批并收官）

> 来源：用户《问题集合.md》25 条（需求真源，与 SPEC §9 冲突处以问题集合为准）+ 4 项关键决策确认（拆两页/完整规则引擎/袋口鼻尖标定/地基优先）。计划真源：`~/.cursor/plans/练习tab问题集合落地_9ed76669.plan.md`。执行方式：每任务单独 todo list、逐任务 build + 截图/测试验收。

| 任务 | 内容 | 状态 |
|------|------|------|
| A1 | 线语言 v2：进球线/母球击后轨迹改虚线（本色绑定保留）、所有被带动球轨迹画出、假想球心红点（瞄准点）、去球选中圆圈 | ✅ |
| A2 | `BTTrajectoryDetailChip` 三档标注（全部球轨迹/母球+目标球/仅瞄准线+假想球）接入全部击打页，自由模式未碰球瞄准线延伸至库边 | ✅ |
| A3 | 控件瘦身：`BTAimWheel` 纯相对微调去数值；力度柱量程 0.5–8.0 + 非线性 γ=1.8 + 两行读数 + 默认 1.5；`BTSpinPadOverlay` 紧凑近透明点外关闭 | ✅ |
| A4 | 布局规范 v2（条 18，最高优先）：仪表柱底部与下角袋齐平、右侧 `BTShotActionColumn`（击球/上一杆/回放文字钮竖排）、左侧 `BTBreakSideButton`（无开球页禁用态常驻）、球库两排居中放大 | ✅ |
| A5 | 4×8 台面网格 `BTTableGridMenuToggle`（`UserPreferences.showTableGrid`）入各球桌页设置 | ✅ |
| A6 | 渲染统一：地面中心纯黑；2D/3D 瞄准页发灰白根因（enhanced 管线）收敛到 plain 观感 | ✅ |
| A7 | 袋口容错：`pocketNoseRestitution` 0.60→**0.70**（`PocketBehaviorDiagTests` 力度扫描标定：低中力沿库进袋、≥2.4 m/s 冲袋被鼻尖拒绝） | ✅ |
| A8 | 全局用户可见文案 α→θ（θ=切角入 SPEC §8.8 术语表） | ✅ |
| B1–B3 | 瞄准原理（名词系统/θ 标注位/d=2R·sinθ 推导）、浅谈球感（定义重写+视角差异图重做）、瞄准点对照表（改名/标注对调修正/估角误差交互演示） | ✅ |
| C1–C4 | 角度与打点加球库+目标球可选；角度预测键盘遮挡修复+交互对齐；2D/3D 瞄准训练改名「2D/3D 角度训练」+随机球号+进球线颜色修复+渲染修正 | ✅ |
| D1–D3 | 新页三张：瞄准点训练（拖假想球+mm 误差、`AngleTestResult` 扩展）/2D 瞄准点训练（瞄准线微调+辅助线交点误差+自动击球）/3D 瞄准点训练 | ✅ |
| E1 | 编排台改名「自由走位」：去开球去录制、进袋/自由合并为 `BTAimModeToggleButton` 单钮切换（保留进袋瞄准点） | ✅ |
| E2 | 「自由击球」新页 `FreePlayView`：开球状态机（开球→开球中→重开/完成，`BreakFlowRunner` 增 `.settled` 相位 + `autoDeliverOnSettle`） | ✅ |
| E3 | 中八/追分规则调研文档（`docs/research/`）+ `BilliardRulesEngine`（`ChineseEightBallRules`/`ZhuifenRules`：开球定边/花色分边/犯规自由球/8 号胜负/追分计分轮转）接入自由击球；`BilliardRulesEngineTests` 全绿 | ✅ |
| E4 | 分离角与走位：换 `PositionPlayViewModel` 底座、进袋/自由切换、球库限 2 目标球（`maxTargetBalls`）、默认教学球形、布局对齐 A4 | ✅ |
| E5 | 批量出片台：布局按 A4、「点换」（选球与母球换位）、「辅助线」（两步确认+±10° 轴吸附+线上球自动均分+不进 JSON+击球隐藏，`BatchGuideLine`） | ✅ |
| E6 | 思路训练器改名「思路训练」+ 三解页（思路/三杆/斯诺克）同规范：落区只留矩形、「求解/下一解」文字钮左侧竖排、右侧仪表柱+击球/上一杆/回放（VM 新增 `adjustCurrentSolution`〔求解后微调力度/打点即重预测〕、`undoLastShot`/`replayLastShot`）、删导出删试打、齿轮并入省略号菜单标题居中；入口卡/拍照送入/UI 测试同步改名 | ✅ 2026-07-07（build ✅；`testB2ShotControls` TEST SUCCEEDED，b2-05/06/07 截图核验三页新布局；`QiuJiTests` 454/454 绿 2 skip） |
| ✅门 | 总验收：问题集合 1–25 逐条核验 + 全量单测 + SPEC/PROGRESS/Hub 回写 | ✅ 2026-07-07（见下验收清单；`QiuJiTests` 454 tests 0 failures TEST SUCCEEDED） |

### 问题集合 1–25 验收清单（2026-07-07）

| 条 | 内容摘要 | 落地任务 | 状态 |
|----|---------|---------|------|
| 1 | 瞄准原理页重组（名词系统/标注/公式推导） | B1 | ✅ |
| 2 | 角度与打点加球库、目标球可选 | C1 | ✅ |
| 3 | 浅谈球感重写 + 视角差异图重做 | B2 | ✅ |
| 4 | 瞄准点对照表改名/标注修正/红点/估角演示（4.4 α→θ） | B3 + A8 | ✅ |
| 5 | 角度预测键盘遮挡 + 交互对齐 | C2 | ✅ |
| 6 | 2D 角度训练改名/随机球号/进球线颜色/渲染（6.3 发灰白） | C3 + A6 | ✅ |
| 7 | 3D 角度训练同步 | C4 | ✅ |
| 8 | 新页·瞄准点训练（拖假想球 + mm 误差） | D1 | ✅ |
| 9 | 新页·2D 瞄准点训练（微调 + 交点误差 + 自动击球） | D2 | ✅ |
| 10 | 新页·3D 瞄准点训练 | D3 | ✅ |
| 11 | 地面纯黑渲染统一 | A6 | ✅ |
| 12 | 线语言 v2 + 三档标注（12.5） | A1 + A2 | ✅ |
| 13 | 控件瘦身（刻度轮/力度条/打点盘/默认 1.5） | A3 | ✅ |
| 14 | 袋口容错（鼻尖恢复系数标定 0.70） | A7 | ✅ |
| 15 | 自由击球新页 + 开球状态机 + 规则引擎（15.10） | E2 + E3 | ✅ |
| 16 | 4×8 网格入设置 | A5 | ✅ |
| 17 | 分离角与走位（进袋/自由、限 2 目标球） | E4 | ✅ |
| 18 | 布局规范 v2（最高优先级） | A4（全页收编） | ✅ |
| 19 | 编排台→自由走位（去开球去录制、单钮切换） | E1 | ✅ |
| 20 | 批量出片台（点换 + 辅助线） | E5 | ✅ |
| 21 | 思路训练（改名/按钮重排/微调/菜单合并/删导出试打） | E6 | ✅ |
| 22 | 打一走二想三同规范 | E6 | ✅ |
| 23 | 做斯诺克同规范 | E6 | ✅ |
| 24 | 翻袋/反射解球器**不动** | —（未触碰） | ✅ |
| 25 | 元规则：与既有 SPEC 冲突以问题集合为准，落地后回写 | final（SPEC §10 + Changelog） | ✅ |

## B3.8 — 问题集合 v5（2026-07-13 收官）

> 来源：用户《问题集合_v4.md》20 条，经 `/issue-collection-restructure` 重组为 `问题集合_v5.md`（本轮需求真源，与 SPEC 冲突以其为准，落地后回写）。执行方式：`plan-delegated-execution` / 执行智能体分 V1–V11 批次，逐批 build + 单测 + 截图/UI 测试验收，主控独立复跑关键批。全局规范定稿回写 SPEC §8.9（见 Changelog 2026-07-13 行）。

### 批次结果（V1–V11）

| 批 | 内容 | 结果 |
|---|---|---|
| V1 | 瞄准交互地基 G13（选中+相对调整，绕母球公转增益封顶 0.6 度/pt `aimNudgeDegrees`）+ G14（0.5s idle 求解去抖 `SolveDebounceScheduler`） | ✅ 0 轮返工（🔬 真机手感待验） |
| V2 | 全局小件 G15（删 `perceptibleSettleTime` + 14 消费点，播满自然静止）+ G16（`BTSpinPad` inset 5→2）+ G19（齿轮→三点，ProfileView 徽标行豁免） | ✅ 0 轮返工 |
| V3 | G17 上一杆完整快照（共享 `SolveShotSnapshot`+`SolveConstraintDraft`，思路/打三先行全量恢复不重解） | ✅ 0 轮返工 |
| V4 | 学习/训练页轻修 Q1（卡片字号统一 `.btHeadline`）+ Q2（角度与打点→角度与瞄准）+ Q3（对照表标签换位·全角度不遮挡）+ Q4（角度预测垂直居中）+ Q6（瞄准点训练线宽/红点调小） | ✅ 0 轮返工 |
| V5 | 场景页 Q5（3D 角度训练默认最高机位）+ Q7（2D 瞄准点训练：线/红点规则重做 `AimLineGeometry`、`ShotStageProxy` 布局、3s→1.5s、验证回放加球杆）+ Q9（3D 滑屏改相机+默认最高） | ✅ 0 轮返工 |
| V6 | 开球通用规范 G18（`BreakFlowRunner` 去随机塞·开放瞄准·力度默认 6 m/s·`FreePlayBreakBar` 收敛·完成/重开互换）+ Q14（思路开球）+ Q15.4（打三开球） | ✅ 0 轮返工 |
| V7 | 打一走二想三 Q15.1（`SolveRegion.sector` 环形扇区 SDF·默认选区状态机·禁外接矩形）+ Q15.2（<3 球降级求解与清台终局）+ Q15.3（`BTEraserButton` 移「摆球」右侧） | ✅ 返工 1 轮（仅 UI 测试取证层，产品代码零改动） |
| V8 | 防守（Q16：改名·中八规则推断对方球组·8 号目标拦截·完全/高难度可行/诚实无解谱系）+ G17/Q15.3 本页落地 | ✅ 0 轮返工（评分权重 0.6/0.4 待实测调优） |
| V9 | 翻袋/反射页统一（Q17/Q18 九项：标题/解描述上移·按钮列重排·下一解左移·演示不可中断·球库补白黑·三点设置+网格）+ G17（页面原生 `SolveUndoContext`） | ✅ 0 轮返工 |
| V10 | 动作库与试打（Q19.1 侧栏回顶·Q19.2 球数不含白球/标题居中/i 并三点/**序列模式默认**；Q19.2.5 半句用户未补明确跳过留档） | ✅ 0 轮返工 |
| V11 | 总验收（主控独立实测） | ✅ 2026-07-13 |

### V11 总验收结论（主控独立实测）

- 全量 `QiuJiTests`：**Executed 560 tests, 2 skipped, 0 failures**（903s）。
- 关键 UI 套件：S1 / S2(6) / S5(5) / S5-AimPoint(2) / S6 / S7(5) / S8(4) / ScreenshotTour（bank+reflection）/ DrillTryout(6) **全部 passed**。
- 期间 3 例（S1/S6/S5-3D）失败为**陈旧增量构建产物**导致的 SwiftUI `_ConditionalContent` 析构 SIGSEGV，`xcodebuild clean` 全量重建后全部通过——**非代码回归**。
- 文档回写：SPEC §8.9 + §8.8 + Changelog；本节；`问题集合_v5.md` v5.1；PROGRESS 顶部条目。

### 遗留项清单（v5 收官后待办）

1. **真机冒烟**（自动化无法代验的体感项）：G13 增益 0.6 度/pt 手感、V6 开球拖屏调瞄准手感、V7/V8 击打→上一杆动画链路、V10 序列杆间 0.7s 节奏、Q9 3D 点击+刻度轮瞄准手感。
2. **V8 防守评分权重 0.6/0.4 待实测调优**（对手进球难度 `0.6·切角 + 0.4·球距`，常量集中在 `AngleSceneCalculator` 单点可调）。
3. **Q19.2.5 半句待用户补充**：v4 原文「在进袋模式下，默认使用」未写完，V10 明确跳过并留档（进袋模式保持现状），待补充后另起小批实现。
4. **V6 Composer 开球入口是否放开**（产品决策）：自由走位编排台开球入口现为禁用态，已接好共享条/叠加/路由，是否放开待用户/主控确认。
5. **UI 测试对模拟器环境的隐式依赖**（V10 发现）：onboarding 持久标记 + 无 StoreKit Pro 授权，`simctl erase` 会重置需 `defaults write … hasCompletedOnboarding YES` 恢复；跑 UI 测试前须确保环境干净。

## B4 — WP-C 观感反馈

| 任务 | 内容 | DoD | 状态 |
|------|------|-----|------|
| T-P18-15 | 落袋下沉观感（D1=方案 A）：`TrajectoryPlayback` 追加与导出器同参数 Y 下沉（常量抽单一真源，导出器 L416–421 改引用）；2D 顶视叠加「缩放 0.85+阴影淡出」 | 6 条回放路径落袋帧目验无退化 | ⏳ |
| T-P18-16 | 音效接线：`BreakFlowRunner` 开球回放补 `ShotAudioScheduler.play/cancel`（~10 行；原生成器页已下线，T-P18-47 后开球闭环在此）；素材到位（H-18）后真机听感验收 | 素材缺失时静默 no-op 不破 | ⏳ |
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

#### 修订注记 — 五分类「理」区（v32，2026-08-08）

- **状态**：已采纳（见 `问题集合_v32.md`；用户拍板理与学平级、序在学下、仅 16 体系、学区去球理卡）。
- **变更**：`PracticeSection` 由学/练/打/解升为 **学/理/练/打/解**。原决策 1 中「学 = 球理与瞄准知识」拆为：学 = 交互/文档学页；理 = 16 理论索引入口。四分段史实保留；现行 IA 以 v32 为准。
- **不影响**：打/解分段目的划分、孤儿页清理结论、自由击球路由。

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

### ADR-P18-03 — 翻袋引擎反解（`ShotInput.bankRails` + 四层管线，W1）

- **日期**：2026-07-09
- **状态**：已采纳（翻袋反射页重构方案 W1 落地；真源 `docs/research/20260709-翻袋反射页重构方案.md` v2 §2）
- **背景**：翻袋/反射解球器现为「几何幽灵球反推 + 单球追迹」混合口径，演示线与真实物理（squirt / 两球碰撞 throw / 传旋 / 速度衰减）不一致。用户拍板「严格教学 App，求解必须基于真实物理」，WP-B 4-a 由 v1.x 提前并入。这是把已有引擎能力（B1 scoring-only / B2 `AnalyticAim` / B3 `AnalyticShotRollout`）接完整，非新增物理，不违反 2026-06-18 物理封版纪律。
- **决策**：
  1. **求解语义进 `ShotPredictor`**：`ShotInput` 增 `bankRails: [BankShotCalculator.Rail]?`（nil = 直击，现行为逐位不变）。非空时 `predict` 走 bank 分支：反解「母球直击目标球（碰前吃库 == 0 硬判据），目标球经指定库序真实翻库进选定袋」。
  2. **四层管线**：第 0 层镜像展开种子（`BankShotCalculator.solveSequence` 降级为种子生成器，经内部 API `bankSeedPath` 暴露）；第 1 层解析目标函数（`AnalyticAim` 母球段闭式 + `AnalyticShotRollout.rollout` 目标球段单球多库闭式，miss = 目标球路径到袋心最近距离 + 吃库数偏离惩罚）；第 2 层歧义回退（目标球段截断 / kiss 风险的候选就地换引擎 scoring-only 评估，粗扫/精修各限额 8 次引擎评估，预算耗尽按无效跳过 = 宁可少解）；第 3 层代表解引擎全保真终验物化（scoring-only 验证 → 通过者同 offset 全保真重建 `ShotPrediction`，失败自动试备选 ≤3）。
  3. **搜索**：种子附近 ±8° 中心向外粗扫（0.4° 步长，进袋候选出现后再看 4 点即早停）→ 谷底黄金分割精修（tol 0.02°）。方案原文「secant 求根」改为黄金分割极小化同一目标（miss→0），语义等价、对非单调段更稳。
  4. **诚实口径**：目标球撞障碍 = 候选淘汰（真实碰撞体语义，方案 §4.3）；jaw 截断 / 终验不进 = 该库序如实返回 `simObjectPotted=false`，绝不回退几何解；力度是求解输入，力不足如实报未进。
  5. **边界决策**：`bankRails` 元素类型直接用 `BankShotCalculator.Rail`（Features 层枚举）——同 target 无编译边界，避免在 Core 复制库枚举造成双真源；`Core/Physics` 对 `Features/AngleTraining` 的这一处类型依赖以本 ADR 记录在案，W3 接线时若引入 SPM 模块化再行下沉。
- **影响**：`ShotPredictor.swift`（bank 分支 ~250 行，直击管线零改动）；`BankShotCalculator` 增 `bankSeedPath` / `candidateRailSequences` 内部 API；UI 零改动（W3 接线）。
- **备选与否决**：几何避障过滤（v1 方案，否决：障碍球作真实碰撞体进反解更正确）；每候选全程引擎搜索（否决：28 库序 × 45 点 × ~15ms 超秒级预算，解析层单点 µs 级）；在 Core 新建 `BankRail` 枚举（否决：双真源）。
- **验证（真实输出）**：`PhysicsEngineTests` 新增 5 条翻袋用例全绿（典型盘面有解 + 直击不变量 + nil 兼容 + 障碍无穿球假解 + 低力度诚实未进）；`AnalyticRolloutParityTests.test_bankObjective_parityWithEngine` 对拍 30 盘面 × 210 点：假阳性 0、漏解 0；benchmark `[PERF-W1]` 单袋全枚举（28 库序）典型盘面 0.222s（目标 ≤0.5s ✅）、最坏侧（近库 + 4 障碍）0.684s（目标 ≤1s ✅）；回归面 `PhysicsEngineTests`+`PhysicsInvariantTests`+`ScoringOnlyConsistencyTests`+`PositionPlaySolverTests`+`SnookerSolverTests`+`AnalyticAimParityTests`+`DifficultySolverTests` 全绿；B0 既有 benchmark 同轮对比在噪声内（情形 A 0.15s / B 0.13s / 斯诺克 7.16s / 批量 0.47s）。全量 `QiuJiTests` 改前基线 491/491（2 skip）绿，改后全量回归另附。
