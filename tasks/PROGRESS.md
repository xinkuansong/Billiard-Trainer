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

- **P12 视频缩放（精讲 clip + 详情页示范视频）✅（2026-06-18，SwiftUI Developer，ADR-P12-02 后续）**：用户走查发现「视频示范点进去不支持放大缩小」。把图片缩放逻辑抽成**通用可复用** `ZoomableContainer<Content>`（捏合/双击放大 + 放大后平移 + 可选下滑关闭，内容类型无关），统一三处：精讲静态图、精讲 clip（`LoopingPlayerView`）、详情页示范视频（`DrillVideoPlayerSheet` 的 `VideoPlayer`，保留系统播放控件、缩放不拦截 scrubber、关闭走 sheet+关闭钮故不开 swipeToDismiss）。`ZoomableContainer` 设 internal 供 `DrillDetailView` 跨文件复用。验证：`make build` BUILD SUCCEEDED、lint 0。改：`QiuJi/Features/DrillLibrary/Views/{DrillTutorialView,DrillDetailView}.swift`、`tasks/phases/P12-content-system-theory.md`。**⏳ 待人工**：真机验证缩放与视频控件/翻页/下滑关闭共存无冲突。
- **P12 多球形精讲隔离 + 精讲全屏看图 + 配图 PNG/动态选用 ✅（2026-06-18，SwiftUI Developer，ADR-P12-02）**：用户反馈精讲页两问题——①一个 drill 可能含**多个球形**，各自精讲文字需隔离（视频按序排/gif 拼接即可，唯精讲不能混在一条滚动里）；②配图嵌卡片太小，要点击全屏看。选项式逐项拍板后落地（全部加法式、向后兼容，70+ 旧 drill 零改动）：①`DrillTutorial` 加可选 `formations:[{id,title,sections}]` 与 `sections` 二选一 + 新 `TutorialFormation`；`TutorialSection` 加 `clip`（mp4 动态片段）；`DrillContentService.tutorialClipURL`。②`DrillTutorialView` 多球形顶部**吸顶分段控件**（`Picker .segmented`+`LazyVStack` pinned header）切换、复用 `sectionCard`；单球形维持平铺。③配图=PNG 海报+可选 clip，有 clip 显**播放角标点击才播**（poster_tap）。④新增内置**全屏看图** `TutorialMediaViewer`（图集翻页 + 捏合/双击缩放 + 下滑关闭 + clip `AVPlayerLooper` 静音循环）——组件内置同文件避免改 pbxproj；`DrillTutorials/` folder ref 自动打包 mp4。⑤详情页球台预览只画第一球形（不改）。⑥**配图选用规则**写入 SOP：讲位置/几何/落点用 PNG，讲运动/走位/杆法效果加 clip（gif 先转静音循环 mp4）。**验证**：`make build` BUILD SUCCEEDED、lint 0。改：`QiuJi/Data/Services/DrillContentService.swift`、`QiuJi/Features/DrillLibrary/Views/DrillTutorialView.swift`、`QiuJi/Resources/Drills/schema.md`、`.cursor/skills/content-engineering/SKILL.md`、`tasks/phases/P12-content-system-theory.md`。**⏳ 待人工**：真机走查多球形切换 + 全屏缩放/翻页/下滑关闭 + clip 循环播放（需先有一条多球形/带 clip 示范内容）；gif→mp4 转码脚本与首条示范内容待排期。
- **出杆跟杆（follow-through）+ 停留收杆 ✅（2026-06-18，SwiftUI Developer）**：用户要更真实的收杆——「击球后球杆超过母球原中心一颗球的距离、减速、停 0.5s 再消失」。在单一权威 `CueStroke` 上加跟杆段：`followThroughPull = −3R`（杆头 `tipOffset=(R+0.001)+pullBack` ⇒ 落在母球原中心 +2R≈一颗球处）、`followThrough(at:)` ease-out 减速（触球瞬间最快→停）、`followThroughDuration=0.2s`、实时停留 `followThroughHold=1.5s`（球仍在滚动停稳）、导出短停 `exportFollowThroughHold=0.2s`。`runCueStroke` 改 `SCNAction.sequence`：出杆到触球→`onContact`（**仅发球**）→减速跟杆→停留→收杆（收杆改由本方法统一接管，**5 个调用点**`PositionPlay/Silu/Snooker/ShotSimulation/RackGenerator`删除触球处 `hideCueStick`，`completion`→`onContact`语义）。**收杆/复位竞态**：`AngleTrainingScene.updateCueStick`/`hideCueStick` 开头 `removeAction(forKey:"strokeAnim")`，显式重新摆杆即取消未结束的延迟收杆，避免击球后复位重瞄的杆被误隐藏；`runCueStroke` 逐帧直接驱动 `CueStick`（仰角恒定）绕开 `updateCueStick` 故不自取消。导出 `renderCueStroke` 同源追加跟杆帧 + 短停帧，并把「触球清预告线/收假想球」改在触球瞬间回调（保 ADR-P11-11 轨迹契约，跟杆期不再显示预告线）。**验证**：`make build` BUILD SUCCEEDED、lint 0；新增 `BallFogDiagTests.test_cue_follow_through_kinematics`（数值：`followThroughPull=−3R`、曲线 0→终点单调向前且每步位移非增=减速、杆头停点=中心+(2R−0.001)）**通过** + `test_render_cue_follow_through` 渲染触球/跟杆两帧（`build/ball_fog/cue_{contact,follow_through}.png`）**通过**，肉眼确认跟杆停点杆头越过母球中心约一颗球。改：`Core/Scene/{CueStroke,AngleTrainingScene}.swift`、`Core/Media/SequenceVideoExporter.swift`、`Features/{PositionPlay/ViewModels/PositionPlayViewModel,PositionPlay/ViewModels/SiluTrainerViewModel,SnookerTactics/ViewModels/SnookerTacticsViewModel,AngleTraining/ViewModels/ShotSimulationViewModel,RackGenerator/ViewModels/RackGeneratorViewModel}.swift`、`QiuJiTests/BallFogDiagTests.swift`。**⏳ 遗留**：已接入 App 的 `drill_c042/full_3d.mp4` 为本次改动前导出，跟杆口径同步需重新出片替换（待用户确认）。
- **出杆动画单一权威收口 + 全场景接入 + 背景统一黑 + 桌底接地 ✅（2026-06-18，SwiftUI Developer，PD-024）**：用户要把「那套严谨的出杆动画」**应用到所有有击球的地方**，并把 3D 背景统一黑、修桌腿。**出杆收口**：新增 `Core/Scene/CueStroke.swift`（单一权威运动学：回杆 `d=a+k·v` → smoothstep 回杆 → 蓄力停顿 → 匀加速出杆，触球杆速=v；`strikePosition` 含加塞偏移；以及 `AngleTrainingScene.runCueStroke(...)` 的 `SCNAction` 实时驱动）。删除 3 处**逐字节相同**的拷贝（`PositionPlayViewModel`/`SiluTrainerViewModel`/`SnookerTacticsViewModel` 各自的 `Stroke` 枚举+`runStrokeAnimation`+`strikePosition`）改调共享；`ShotSimulationViewModel` 把**简易版**（固定 pull/thrust 0.16/0.06s）换成完整 `runCueStroke`；`RackGeneratorViewModel` 开球**原来完全无出杆**，新增运杆→出杆→散开（沿 `aimAtApex` 方向、速度=power）；`SequenceVideoExporter.renderCueStroke` 逐帧改用 `CueStroke.pullBack(at:)` 并删本地常量/公式（产物逐帧等价）。**背景/接地**：`EnhancedEnvironment.apply` 可见背景由冷灰天空盒改 `UIColor.black`（**IBL 不变**，仅 `background.contents` 置黑）⇒ App 内 3D 与 2D 页、导出三者一致；`AngleTrainingScene.setupGround` 地板由近黑暗蓝提亮到中性深灰 (0.066) + 新增烘焙**接地阴影** `setupContactShadow`（径向软暗斑铺桌底）⇒ 黑底下球桌读作落地不悬空。**桌腿诊断（推翻原假设）**：实测 `legBottom(world)≈-0.0005`、地面板 `Y=0` ⇒ 腿**在地面板之上未被遮挡**（占用假设错误）；导出高斜视角看不到桌底腿是相机角度+暗腿压黑底所致，非 bug，故按用户选择走「加地板+接地阴影」让球桌落地。**验证**：`make build` BUILD SUCCEEDED、lint 0；`BallFogDiagTests` 数值诊断 + App 内 3D 渲染腿/袋网正常；`make position-export`（seq_d438b01c）端到端 94s 跑通，抽帧确认出杆杆体渲染正确 + 球桌接地（`build/legdiag/new_{stroke,steady}.png`）。改：`Core/Scene/{CueStroke,AngleTrainingScene,EnhancedEnvironment}.swift`、`Features/{PositionPlay/ViewModels/PositionPlayViewModel,PositionPlay/ViewModels/SiluTrainerViewModel,SnookerTactics/ViewModels/SnookerTacticsViewModel,AngleTraining/ViewModels/ShotSimulationViewModel,RackGenerator/ViewModels/RackGeneratorViewModel}.swift`、`QiuJiTests/BallFogDiagTests.swift`。

- **P11 教学素材 3D 斜视角视频（短边沿长轴 + 透视自动取景 + 双分辨率档）✅（2026-06-18，SwiftUI Developer，ADR-P11-15）**：用户要在现有「2D 视频」（其实是 3D 场景顶视正交拍的）之外**并存**出 3D 斜视角视频供 App 内竖屏播放。四点拍板：①主用途竖屏、默认短边后方沿长轴静态斜视角（+X 端看向 −X，俯角 30°/竖直 FOV 46°）；②2D 与 3D 并存（2D 静帧/cover/preview/gif/full.mp4 全保留，3D 只新增视频）；③双分辨率：手机档 720×1280（OTA）+ 高分档 **1440×2560**（外站备用不进 Bundle）；④高分档仅整段不出 per-shot。**实现**：`SequenceVideoExporter` 加 `CameraMode`/`Perspective3DConfig` + `solvePerspectiveCamera`（固定俯角+FOV，二分推距离使球桌**外框 8 角点**全入框 6% 余量 ⇒「全台可见」不变量，禁 magic number，FOV 锁竖直方向）；`RenderContext` 按模式分叉，3D 走 `enhancedRendering`（studio 光照+IBL+接地阴影，同 `Scene3DAimingView`）；**进袋球到达袋心沿 Y 下沉 7cm 再淡出**（仅导出层，防平面凭空淡掉穿帮）；轨迹线 `lineRadiusScale=1.3` 补远端变细；HUD 条高竖版随宽等比（720→80、1440→160）。Runner 追加 `full_3d.mp4`/`sNN_3d.mp4`/`full_3d@1440.mp4`。**验证**：`make build` BUILD SUCCEEDED；新增 `SequencePerspectiveFitTests` **5/5**（8 角点投影全入框 + 取景最小可行 maxRatio>0.97 + 近库不遮挡近端球 + 端点镜像，5 俯角×3 FOV 批量不变量）；`make position-export` 4 序列端到端跑通；抽帧核验（seq_f4ded688）全台可见/近库不挡球/studio 阴影立体/轨迹线+假想球+球杆+HUD 正常/进袋球沉入侧袋（t=8.7 蓝球入袋、t=9.0 已没）。改：`Core/Media/SequenceVideoExporter.swift`、`QiuJiTests/{PositionPlaySequenceExportRunnerTests,SequencePerspectiveFitTests}.swift`、`content/position_play/README.md`、content-engineering SKILL、`tasks/phases/P11-position-play-composer.md`。**物理边界（诚实标注）**：仍是 2D 平面物理，3D 只换相机——跳球/扎杆腾空出不来。**接入 demo（同日）**：手机档 `full_3d.mp4` 拷入 `Resources/Videos/drill_c042/`，`drill_c042.json` `videos` 追加 `full3d` 与 2D `full` 并存；`make build` ✅ + bundle 含两 mp4；`testDrillC042TutorialDemo` 通过，截图确认详情页「视频示范 2 段」（第1段2D顶视/第2段3D斜视角），3D 缩略图由真实文件 AVAsset 解码 ⇒ 可播。注：`scripts/import-videos-to-app.py` 仅服务项目 15 真机录屏且会重写 videos，不适用合成渲染视频，c042 走手工接入。**遗留**：其余 drill 的 3D 视频接入待批量出片后排期 + OTA 通道（依赖 H-14）；详情页缩略图无 2D/3D 文字标签（视觉可辨）；动态镜头（跟拍/环绕）为后续增强。
- **P17 球形生成器 🔄 阶段 2.2 开球缝隙 1mm→0.2mm（治「球开不开」根因）✅（2026-06-17，iOS Architect）**：用户真机走查满力开球**经常散不开**（球堆只裂几颗、母球带大半能量跑远），疑球间距过大。**测量优先**：新增诊断 `BreakRackPhysicsTests.test_break15Ball_gapSweep`（母球对准顶角全砸 v=7、5 个瞄准偏角取均值，扫 gap 0.1/0.2/0.3/0.5/1/2mm）——均散开>30cm：0.1mm=10.2/15、0.2mm=9.6/15、0.3mm=5.8/15、**1mm（旧）=5.2/15**、2mm=3.6/15，单调且 0.2↔0.3mm 有拐点，全程停稳/不互穿。坐实**1mm 缝隙过大是根因**（动量逐颗传递被缝隙+摩擦耗散、母球留太多能量）。**修复** `RackLayout.gap 0.001→0.0002`（同步 `BreakRackPhysicsTests.gap`；取 0.2mm 留数值余量）。验证 14/14：`diagnoseSpread` v=6 散开>30cm **2/15→12/15**、铺开包围盒 X **108→246cm**（近满台），仍 settled/不互穿/确定性。改：`QiuJi/Core/Rack/RackLayout.swift`、`QiuJiTests/BreakRackPhysicsTests.swift`。**⏳ 待人工**：真机复看满力/中力是否稳定炸开。
- **P17 球形生成器 🔄 阶段 2.1 开球随机性 + 9 球少球摆法 + 力度上调 ✅（2026-06-17，iOS Architect）**：用户走查四点反馈落地。①**随机性根因**：`seed` 仅贴号码、slot 几何写死、引擎里球物理全等 ⇒ 同开球点/力度/打点散开**逐毫米一致**，「换一局」只换号不换形。修复=在 `RackGeneratorViewModel.breakNow` 注入 **seed 驱动的「一点点」扰动**（`breakJitter`，绑定 rack seed ⇒ 同局可复现/换一局即变）：上下塞 ±0.15、左右塞 ±0.10（叠加用户打点后 `clampSpin` 钳 miscue 0.5）。〔注：原撞顶球偏摆 ±1.5° 已于同日移除——用户拍板不要，且阶段 2.2 gap 修复后无需靠偏摆破对称，`breakShot(aimJitter:)` 参数已删〕。②「部分球不动」由阶段 2.2 gap 修复解决。③**力度上调** `powerRange 3–8→4–9`、默认 `6→7`（母球出射≈1.54×杆头）。④**改名+摆法**：UI「追分」→「9 球」；`RackLayout.zhuifen` 改**显式布局+9 球系编号**（删旧三角前缀，新 `makeSlots`）——4 球小菱形 `[1,2,1]`(底=9)、5 球菱形+共线尾球(尾=9)、6 球三角 `[1,2,3]`(底排中点=9)、9 球钻石不动；号码集非连续(4={1,2,3,9}/5={1,2,3,4,9}/6={1,2,3,4,5,9})。**验证**：`make build` BUILD SUCCEEDED、lint 0、`RackGeneratorTests` **8/8**（改断言新编号+9 号锚点；`aimJitter` 默认 0 ⇒ 既有路径不变）。改：`QiuJi/Core/Rack/{RackLayout,BreakSimulator}.swift`、`QiuJi/Features/RackGenerator/{ViewModels/RackGeneratorViewModel,Views/RackGeneratorView}.swift`、`QiuJi/Features/AngleTraining/Views/AngleHomeView.swift`、`QiuJiTests/RackGeneratorTests.swift`。**⏳ 待人工**：真机走查换一局是否真换形/4·5·6 摆法/加力后散开停稳/随机量级是否「一点点」合适。
- **P17 球形生成器（开球/追分开球）🔄 阶段 1 Core ✅ + 阶段 2 UI/接入 ✅（2026-06-17，iOS Architect，ADR-P17-01；阶段 3 真实感对标/分离角适配待续）**：**阶段 2（本次）**：新增 `QiuJi/Features/RackGenerator/`——`RackGeneratorViewModel`（状态机 racked/computing/breaking/settled，复用 `AngleTrainingScene`+`AngleSceneView`；玩法分段 中八/追分[4/5/6/9]、**母球钳开球区+方案 a 锁顶球瞄准**随拖动更新瞄准线、力度滑杆 3–8m/s+`BTSpinPadCard` 打点、后台 `BreakSimulator` 开球→`TrajectoryPlayback` 回放散开→收尾钉终点+刮杆补母球、「换一局」换 seed、废局只提示不筛选、`deliveredBoard()` 交付）+ `RackGeneratorView`（黑底+玩法分段+2D 真台+底部条，停稳后路由 `PositionPlayComposerView/SiluTrainerView(initialBoard:)`）；接线 `AngleRoute.rackGenerator`+海报卡「开」+`MainTabView`。`BreakSimulator.breakShot` 由 `lateral` 改 `cuePosition`+`aimAtApex`（母球位置即开球角度）。验证 `make build` BUILD SUCCEEDED、lint 0、`RackGeneratorTests` **8/8**（签名改后回归仍 settled/合法/确定性）。**⏳ 待人工**：真机走查开球角度感/各玩法散开/废局提示/交付。 |原阶段 1 摘要见下| 用户 idea「给走位编排台/思路训练器加中式八球开球 + 追分开球（4/5/6/9 球）的球形生成入口」。多轮拍板：**livesim 端上真实物理**（非参数化/预烘焙）、玩法全做但**中八 15 球先行**、**WYSIWYG 不筛选**（不满意手动「换一局」）、消费端=走位编排台+思路训练器、**斯诺克不加**（用户复盘排除）、分离角后续适配层。**前置去风险 ✅**：`BreakRackPhysicsTests` 移植 01 三角阵（gap=1mm）跑 3–8m/s 多档，确证 P13 引擎能把 15 球开球跑到**完全停稳/不出界/不互穿/确定性**（事件数仅 ~80–140，maxEvents=8000 头寸充裕），散布非哑火（铺开 ~1m×0.8m，母球行程 ~1–1.5m），真实感对标留后续。**阶段 1（本次）Core 生成器**：新增 `QiuJi/Core/Rack/`——`RackLayout`（`RackGame{中八/9球/追分(N)}`，SceneKit 世界系摆架，中八 8 号居中+底角一花一色、9 球钻石三锚点、追分 1 号最前其余随机；**追分末排取整三角点阵前 N slot 而非重新居中**——等数相邻排会在 z 对齐致排间距退化 0.866·2R 互穿，本轮测试一次抓出修正；`SeededGenerator`/SplitMix64 确定性随机）+ `BreakSimulator`（球架→`EventDrivenEngine` 开球→散开归一化 `BoardSnapshot` + `recorder` 供动画 + `cueScratched`/`eightOnBreak`/`settled` 废局/截断 flag；引擎球名直接用在桌键，回放映射零转换）。**验证**：`RackGeneratorTests` **8/8**（摆架规则/不互穿在界/同 seed 同架/异 seed 异架/中八+9 球开球 settled 合法/同输入两次开球逐球一致 ≤1e-4），`make build` 编译通过、lint 0。详见 `tasks/phases/P17-rack-generator.md`。**下一步（阶段 2）**：生成器入口页（选玩法→摆架预览→开球动画→散开板→路由编排台/思路 + 「换一局」+ 废局兜底）+ 角度 Tab「工具」海报卡入口。**阶段 3（非阻塞）**：开球真实感与 pooltool 跨引擎校准、分离角适配层。
- **P16 做斯诺克战术工具（安全球反解）✅（2026-06-17，iOS Architect，ADR-P16-01）**：用户 idea「做斯诺克的工具——选目标球+障碍球，让母球与目标球落点间被障碍挡住」。多轮澄清独立成页（后续扩展为安全球/战术中心）+ 三项拍板（被困球==首触球 / 纯安全球不进袋 / 手动指定单障碍）。**几何**：新 `AngleSceneCalculator.snookerCoverage`——判「对手能否从母球看到被困球任一点」（球心扫过即可见的张角扇形），闭式 `coverage = β−α−|Δθ|`、完全斯诺克 ⟺ `coverage≥0 ∧ d_障碍<d_被困`；全程 SceneKit 世界系 X–Z、取三球**终位**、规避归一化符号双真源；Python 数值草稿 + XCTest 金标准双验证。**求解器**：新 `PositionPlaySolver.solveSnooker`——与 A/B 关键差异是不进袋无袋口锚定瞄准 ⇒ **瞄准为自由变量**，故走 `simulateFree`（非 candidateMatrix）扫「瞄准偏移×塞×力度」并行求解；硬约束=合法首触目标球∧母球不进袋∧目标不进袋∧母球真停稳∧终位完全挡死；排序库少→覆盖余量大→加塞少；无完全解降级半斯诺克；复用 `applyCushionBudget`/`spinCombos`。`ShotPredictor.simulateFree` 补 `cueFinalSpeed`（与 predict 对称，向后兼容）。**页面**：独立 `Features/SnookerTactics/`，布局 1:1 照搬思路训练器（黑底+三段式+球库+操作列），工具行改「目标球/障碍球/摆球」点选、叠加渲染终位遮挡视线（完全=灰/半=红）+ 角色环；入口角度 Tab「工具」海报卡「斯」+ `AngleRoute.snookerTactics`。**验证**：`make build` BUILD SUCCEEDED、lint 0；`SnookerSolverTests` **4/4**（张角金标准 + 非法输入空 + satisfying 解全复核含必找到完全解 + 降级半斯诺克）；回归 `PositionPlayFreeAimTests` 7/7 + `PositionPlaySolverTests` 13/13；探针 60 布局确证回弹做杆机制（最大余量 71°）。详见 `tasks/phases/P16-snooker-tactics.md`。**遗留（v2）**：被困球≠首触球真安全球、多障碍并集、逃脱难度评分、局部精修、真机走查。
- **P15 拍照建球形（阶段 1 几何竖切）✅（2026-06-16，iOS Architect，ADR-P15-01）**：用户要从任意角度球桌照片提取所有球号+位置。多轮澄清拍板**非 DL 方案 + 人工确认一等公民**（几何用解析单应、感知后续才上 DL 且优先「检测」一环；号码背对相机信息论不可知 → 人工确认既是安全网又是 DL 数据回收口）。阶段 1 零感知竖切：拍照 → 手动拖 4 角标定 → Heckbert square→quad **闭式解单应**（无 SVD，`Homography.swift`）→ 照片上点标每颗球+选号（经 H 映射，球底接触点过 H，禁经验 offset）→ **2D 真台人工确认**（复用 `AngleTrainingScene`/`AngleSceneView`：拖动改位/点选+球库改号/球库拖入增球/拖回球库删球，布局对齐编排台）→ 产出 `BoardSnapshot` → 送编排台（`PositionPlayComposerView(initialBoard:)` + `PositionPlayViewModel.loadBoard(_:)`，默认参数向后兼容）。入口：角度 Tab「工具」加海报卡「拍」(chip「识别」)。**验证**：`make xcodegen`+`make build` BUILD SUCCEEDED、lint 0、`HomographyTests` **5/5**（恒等/四角精确/往返<1e-9/内点在界/退化返回 nil）。**坐标契约**（ADR-P15-01）：图像归一化 uv→归一化台面系（CanvasPoint）。新增 `Core/Geometry/Homography.swift`、`Features/BallExtraction/{ViewModels,Views}`、`HomographyTests.swift`、`tasks/phases/P15-photo-ball-extraction.md`。**⏳ 后续（非阻塞）**：阶段 2 自动球检测（自适应台呢色斑块）、阶段 3 号码归类（中八固定配色+白占比+OCR 兜底+冲突消解）；阶段 2/3 才按需引入 DL。**待人工**：真机/模拟器走查四步流程与几何精度。
- **当前 Phase**：**P10 物理升级**（Track A 内容管线雏形 ✅ 2026-06-04，ADR-P10-01；Track B-1 ✅ 2026-06-04，ADR-P10-02；**Track B-2 漏斗袋口模型 v3 ✅ 2026-06-04，ADR-P10-03**；Track B #3 常量标定需真实视频待办）+ **P9** ✅（2026-06-02）+ **P8** 🔄（仅剩人工：H-17 / TestFlight / App Store）
- **当前激活角色**：iOS Architect（显示闸门下沉 + 纯物理化 ADR-P10-06/07）
- **P14 击球回放音效 + 回放原速化 🔄（2026-06-16，iOS Architect，ADR-P14-01）**：用户要给物理回放加**真实**音效（非游戏/合成）并要求所有回放/视频**原速**。**(1) 原速化** ✅：4 处物理回放（角度 `ShotSimulationViewModel`、Drill `DrillSceneView`、走位编排 `PositionPlayViewModel`、思路 `SiluTrainerViewModel`）`speed 1.4→1.0` + `SequenceVideoExporter.gif` `1.3→1.0`。**(2) 音效基础设施** ✅：新增 `Core/Audio`——`ShotSoundBank`（`AVAudioEngine`+12 player 池，统一画布格式 `AVAudioConverter` 转换，`.ambient+.mixWithOthers` 尊重静音键、与休息计时器后台音频共存，缺资源 no-op）+ `ShotAudioScheduler`（消费 `ShotPrediction.events`，按真实时刻 `DispatchWorkItem` 排程、可取消；力度由 recorder 球速近似；**刻意不变调**，力度差异靠多样本池避免游戏味）；4 条回放路径起播挂调度、复位/结束 `cancel()`；设置加「声音·击球音效」开关（`UserPreferences.soundEffectsEnabled` 默认开）。**(3) 资产管线** ✅：`Resources/Audio/` folder reference（drop-in，放入 `sfx_*.caf` 重新构建即生效）+ `CREDITS.md` 命名约定/转码示例/来源登记。**验证**：`xcodegen`+`make build` BUILD SUCCEEDED、lint 0、缺音频文件回放正常无声不崩。**⏳ 阻塞收尾（H-18，非阻塞）**：真实 CC0 录音需人工下载（Freesound 下载要登录账号；免登录站疑似 AI 合成不满足「真实」）——放入文件后真机听感验收即闭环。详见 `tasks/phases/P14-shot-audio.md`。
- **P13 思路训练器（走位反解器）✅（2026-06-14，iOS Architect，ADR-P13-01）**：把正向瞄准求解升级为**走位反解**——放开塞与力度作自由变量，约束改为母球落点。两情形：A 母球停在手画**可行落区**（rect/circle）；B 母球 v>vMin 时**经过指定点**去 K 球。架构：新增独立 `PositionPlaySolver`（区别于前向 `PositionPlayShotSolver`），外层搜 `(spinX,spinY,velocity)` 网格、内层复用 `ShotPredictor.predict` 解瞄准并以「目标球进选定袋」为硬约束；按吃库数分档枚举、库少优先；多库要求更大 margin（情形 A）。`ShotPredictor` 最小增量：新增 `ShotEvent`/`ShotPrediction.events`（默认空数组，向后兼容，纯只读事件收集）供情形 B 过点后碰撞/到点前吃库分析。新页面 `SiluTrainerView`+`SiluTrainerViewModel` 复用 `AngleTrainingScene`/编排台摆球与回放：塞/力度转**只读指示器**显示当前解、落区/过点台面手势绘制 + SceneKit 叠加渲染、最优解 + 「下一解」翻档、进球线/假想球/母球轨迹 + 文字说明、无解醒目降级、击打回放、导出单步序列经 `PositionPlaySequenceArchive` 送产线（模拟器限定）。入口：角度 Tab「工具」加海报卡「思」+ `AngleRoute.positionPlaySolver`。**验证**：`make xcodegen`+`make build` BUILD SUCCEEDED；`PositionPlaySolverTests` 5/5 全过（SDF 金标准 + 情形 A 可落区/无解降级 + 情形 B 过点分段）；`PositionPlayFreeAimTests` 7/7 回归全过；`PhysicsEngineTests` 既有 3 个失败（largeCutClearShot/objectPath_reachesPocket/withSideSpin_objectPots）经核为此前未提交工作遗留（PHYSICS-DEBT §5.7），本次纯增量无关。关键文件：`PositionPlaySolver(.swift/Models)`、`SiluTrainerView(Model)`、`ShotPredictor.swift`、`AngleHomeView/MainTabView`、`tasks/phases/P13-position-play-solver.md`。**不在本次范围**：多杆连续求解、落区/过点持久化。**后续微调（2026-06-15）**：①内层瞄准提速「共享核心 + 独立编排」——行为不变重构 `predict`→`prepareAim`+`buildPrediction`，新增同文件 `ShotPredictor.predictForPositionSolve`/`positionAimOffset`（黄金分割瞄准 ~15 次模拟 vs 75 次）；求解器拆 spinX/spinY + 跨 spinY 记忆化瞄准（squirt 只随 spinX）+ 漏进重解护栏 + 并行 ⇒ **情形 A 12.65s→1.41s（~9×）、情形 B 11.08s→1.64s（~6.8×）**。②高速假停护栏 `cueFinalSpeed`（情形 A 落区解仅接受末速<0.05m/s 真停点）。③排序「加塞少/吃库少优先」。**零漂移验证**：`test_fastPath_matchesPredict_potOutcome`（28 组进袋判定一致）+ 物理回归 40 测全绿（`PhysicsInvariant` 9/9 含确定性 + `PocketBehaviorDiag` 24 + `PositionPlayFreeAim` 7）+ `PositionPlaySolverTests` 7/7。详见 P13 文件「后续微调（2026-06-15）」。**再后续微调（2026-06-15）**：①**情形 A 局部精修** `refineCandidate`（拓扑锁定 Hooke-Jeeves 模式搜索）——粗网格定位 basin、精修在连续邻域抛光停点，objective 只接受「进袋∧真停稳∧吃库数==种子」样本（永不跨拓扑悬崖），治「basin 对但采样粗」；接入每桶代表解 + 降级解（降级精修后可反升级满足）；`SearchParams` 精修参数全带默认值不破坏旧调用。②**落点约束** `SolveRegion.point`（精确停位 + 容差，复用各向同性圆 SDF）——`solveRestRegion` 按 `isPoint` 分叉「最小化到点距离」装配（所有可进解按桶取最近代表、容差内才判满足）；新增 UI 工具「落点」（琥珀十字 + 容差环），顶部工具行扩为落区/落点/过点/摆球。**验证**：`PositionPlaySolverTests` **10/10**（新增落点 SDF 金标准 + 精修不劣/锁拓扑/确定性 + 落点最近代表分桶），墙钟基本不变（A 2.30s/B 1.68s），`ShotPredictor`/物理本轮未改动无回归风险。**第四轮微调（2026-06-16）— 分水平求解开关**：加两个**可选收窄**开关(默认=完整能力,零回归)。①**是否左右塞**(默认允许,关→`spinXValues=[0]`;横塞是唯一影响瞄准的维度,禁后唯一瞄准 3→1;高低杆始终全开):精修加**锁轴护栏**——`refineCandidate` 只沿网格搜过的轴探测(`spinXValues.count>1` 才探 ±spinX),否则会把被禁横塞引回(关键正确性点)。②**走位复杂度预算** `maxCushions:Int?`(nil 不限默认,基础=1):后处理 `applyCushionBudget` 走「优先+兜底」——优先 ≤cap 解,无解才回退全部解并标 `beyondCushionBudget`(新增字段,UI 加「进阶」前缀;绝不因预算给无解)。UI 在「⋯」菜单加「求解范围」两 Toggle。**验证**:`make build` ✅、`PositionPlaySolverTests` **13/13**(新增禁塞⇒spinX==0含精修不引回 / 基础预算内⇒吃库≤1不标进阶 / 不可满足预算⇒兜底全标进阶不给无解),默认态走原路径墙钟不变。改:`PositionPlaySolver(.swift/Models)`、`SiluTrainerView(Model).swift`、`PositionPlaySolverTests.swift`、P13 文件。
- **P12 内容体系与理论挂接 🔄 规划已立（2026-06-14，ADR-P12-01）**：用户复盘"拖延=对现做法不满意"，根因坐实为 ①生产排在系统定型之前（怕返工）②"更系统更完备"无可证伪终点 ③**理论(项目16)与内容(72 drill)是两座孤岛**（已核实：drill 无 `theoremIds`、工程未 import `contracts/`、16 中枢卡的"≥1 Drill 消费 contracts"闭环至今未达成）。决策：①**完备=课程地图被填满**（新建 [`curriculum-map.md`](curriculum-map.md)：能力树Level×8大类，每格四件套〔挂定理+引擎可达+示范+精讲〕，72 条真实分布=橄榄球形、L1-accuracy 台阶断裂、系统训练模式 0 条）；②理论挂接走**三层渐进式披露**（教练话→one-liner→详情页，禁"根据定理X"教材腔；`theoremIds` 仅作机器标签）；③**理论之家=角度Tab「学习」区升级为"球理"中心**（非第6Tab/非动作库，深链正交+视觉基建都在该Tab）；④理论配图三类（标注图复用 `AngleTrainingScene`/参数扫描待建/战术布局图非引擎）；⑤社媒**拿球形idea不拿片段**（引擎复刻、理论当锚、有界采集）；⑥**分阶段**：阶段1 仅 c042 竖切验证，阶段2 才重构IA+参数扫描，系统训练模式 v1.1。三 SOP 已回写 content-engineering SKILL。详见 `tasks/phases/P12-content-system-theory.md`。**下一步**：用户拍板地图 §6 三参数（每格配额/L4取舍/系统训练模式）+ 执行 c042 竖切（T-P12-02/03）。**示范素材批量录制仍 ⏸ 暂停等编排台录制。**
- **P11 图文精讲结构化渲染升级 ✅（2026-06-13，SwiftUI Developer，DR-019）**：用户反馈精讲文本「太干巴巴」——应用课模板的结构化信息被压扁成字墙。`TutorialSection` 新增可选 `items`（{label,text} 条目行）/`params`（{spinX,spinY,velocity} 击球参数）/`caption`（图注），向后兼容；`DrillTutorialView` 渲染升级：彩色标签胶囊行（为什么=blue/怎么打=btPrimary/自检=orange/其余中性）、参数行复用 `BTSpinMiniIcon`(trueScale)+`SpinDisplay`+`PowerDisplay` 与导出 HUD 同口径图文互证、content 分段+inline markdown、图注。c042 内容已迁移（逐杆节 items+params，常见错误转结构化列表）。**验证**：UI 测试截图 8 张逐张核验 Passed、lint 0。**模板已定稿并回写** `.cursor/skills/content-engineering/SKILL.md` §「图文精讲应用课模板」（接入清单/媒体落位表/红线）。**⏸ 后续暂停（2026-06-13 用户拍板）**：等用户在编排台录完全部示范素材后再继续——按 SKILL 清单逐条接入 + 存量 72 drill「常见错误 1.2.3.」批量转 items + 回滚 c042 临时解锁。
- **P11 序列出片首次接入动作库 demo + 精讲「应用课」模板 ✅（2026-06-13，Content Engineer，ADR-P11-14）**：3 杆序列 `seq_f4ded688` 整链路落进 `drill_c042` 初级蛇彩走位（用户拍板：存量 drill 视频后续整体替换；存量 `shotIntent` 数据精度不可靠，示范击球以编排台**人工录制**为准，不做批量转换）——`shotIntent` 换序列真实 3 杆（含 obstacles）、`videos` 5 条旧 take → `full.mp4`（720p@60 带 HUD）、新增 `DrillTutorials/drill_c042_{initial,s01,s02,s03}.png`。精讲按「应用课」模板重写（多杆走位类适用，技术类四段结构不动）：技术原理 → 开局与击球顺序（布局图）→ 逐杆精讲（为什么/怎么打/自检 + 带 HUD 静帧）→ 常见错误 → 进阶练习。**工程修正**：`DrillTutorials` 改 folder reference（原普通 group，`subdirectory:` 查找解析不到）。**验证**：全量缩略图重烘焙 Passed；UI 测试 `testDrillC042TutorialDemo` 截图核验详情页/视频区/精讲全部正常。**临时项（发布前回滚）**：c042 `isPremium` true→false 供无订阅验收；临时 UI 测试待验收后处理。**下一步**：用户确认模板后回写 content-engineering SKILL SOP + 其余 drill 示范击球录制排期。
- **P11 教学素材击球参数 HUD + 导出暗色背景 ✅（2026-06-13，iOS Architect，ADR-P11-13）**：teaching 档画面底部追加 80px HUD 条（输出 1280×720，16:9）——打点球面（无背景，**真实比例**：`BTSpinMiniIcon` 新增 `trueScale` 模式与打点盘同几何——红斑=皮头中心位置+真实斑径+打滑极限虚线圈，教学素材可照搬到真球；App 内小按钮保持归一化）+ 百分比读数 + 力度条（档名 + m/s），每杆常驻换杆更新；经 `ImageRenderer` 直接复用 App 组件（样式单一真源）；导出场景背景改黑与 App 一致（方案 1，解决白底白字不可读）。瞄准点/接触点用户拍板不做。`Options.showShotHUD`（gif/card 关）；sNN_still 带 HUD、initial/final 纯布局。**验证**：实跑 3 序列 Passed、ffprobe/sips 规格全对、抽帧核验 HUD 数值与 JSON 一致。坑：ImageRenderer 下 HStack 文本竖排折行需 `.fixedSize()`。
- **P11 轨迹线样式真源 + 假想球补全 + 教学视频 60fps ✅（2026-06-12，iOS Architect，ADR-P11-12）**：首版产物评审三项反馈落地——①新增 `TrajectoryStyle` 真源（`PoolBallFace.swift`：aim 0.0025 / pot 0.0030 / compact 0.0045；`potColor(for:)` 进球线随目标球球色、黑 8 例外亮灰），编排台/导出器/分离角/动作库详情/缩略图全部接入（翻袋/颗星/角度测验只统一线宽不跟球色——路线教学色非进球线语义）；②假想球补回编排台预览与导出产物（设置帧/静帧/封面显示、出杆随线清除）；③教学视频卡顿根因=30fps×1.3 倍速帧间步长 43ms（非模拟器性能），preset 改 60fps×原速（GIF 保留 12fps×1.3 控体积）。**验证**：`make position-export` 实跑 3 条序列 xcresult Passed(1/1)、ffprobe 1280×640@60、抽帧核验球色线/假想球/运动帧无线。lint 0。**遗留**：动作库旧烘焙缩略图（橙线）待批量重烘焙统一。
- **P11 教学素材渲染矩阵管线 ✅（2026-06-12，iOS Architect，ADR-P11-11）**：与用户澄清两点契约后落地——①「分辨率」（输出像素尺寸）与「球放大」（`ballScale=1.6`）是两个参数，后者仅限卡片素材，其余产物真实比例；②轨迹线=**击球前预告、出杆即清**（与编排台 App 内一致），非全程挂线。交付：`SequenceVideoExporter` 重写（`Options` preset 三档 teaching 1280×640/card 球放大/gif 480×240 + `showTrajectories` + `RenderContext` 收口 USDZ 装载 + `renderStills`/`renderCover`/`renderPreviewFrames`/`subSequence` 四出口）；runner 按**默认配方**出片到 `build/position_play_export/seq_<id8>/`（cover + 12 预览帧〔卡片风格〕 + initial/final/sNN_still 静帧 + full/sNN.mp4 + full.gif〔真实风格〕）。**验证**：`make build` ✅；`make position-export` 实跑 3 条实录序列全出齐，ffprobe 规格全对，抽帧核验设置帧有预告线/运动帧无线/cover 球径 1.6×。lint 0。**遗留**：一致性校验门 + `engineVersion` 版本戳 + meta sidecar（clean 变体按需）+ 发布回填。ADR-P11-11 见 phase 文件。
- **P11 教学素材管线落点 — 录制直写内容库 + 入口模拟器限定 + 视频 OTA 拍板 ✅（2026-06-12，iOS Architect，ADR-P11-10）**：基于击打序列 JSON 规划图片/GIF/视频生产管线，先确认数据充分性：序列 JSON（意图+前后快照，不存轨迹）几何充分，缺口=引擎版本戳/一致性校验门/教学文案 sidecar/资产命名关联（记入 ADR 遗留）。用户三项拍板落地：①**录制直写**——新建 `content/position_play/sequences/`（真相源进 git，附 README；命名 `seq_<id8>-<名称>-<N>杆.json` 与 `drill_pp_<id8>` 对齐），新增 `PositionPlaySequenceArchive`（整体 `#if targetEnvironment(simulator)`，模拟器进程直写 Mac 文件系统），录制结束 JSON 直落内容库 + banner 提示，删 share sheet 流程与已无使用方的 `ShareSheet.swift`；②**录制入口仅模拟器构建可见**（编译闸即产品开关，真机/发布版无入口）；③**生成视频走 OTA**（ADR-002 通道、被 H-14 阻塞；Bundle 只进静帧/帧序列/封面小资产——`Resources/Videos/` 已 257MB 为前车之鉴）。`make position-export` 渲染前自动同步内容库→收件箱。**验证**：`make xcodegen` + `make build` ✅（BUILD SUCCEEDED）、lint 0；**直写链路同日实录走通**（3 条序列落盘）。**同日补修**：「先录完→再命名」已写盘文件不随重命名更新——`archive` 改同 `seq_<id8>` 旧文件先清再写（一条序列只留一份），重命名保存后已录序列自动重新归档（录制中不处理，结束时按最新名字归档）。**下一步（管线主体）**：渲染矩阵（整段/单杆 × 有/无轨迹 × mp4/帧序列/静帧）、`Options` 分辨率 preset + `showTrajectories`、重模拟 vs `after` 一致性校验门、`engineVersion` 版本戳、`meta/` sidecar schema。ADR-P11-10 见 phase 文件。
- **P10 贴库滑行真根因根治 — 库线吃库×边界安全网浮点竞态 ✅（2026-06-12，iOS Architect，FL-022）**：下一条「幽灵反弹根治」被用户打回（贴库滑行仍在 + 求解轨迹出现「吃库→远端 jaw 弧→假进袋」），属 ⚠️ 返工（见 FL-022）。复盘：下一条只治了袋口弧接触带分支，且把 S2 实测「入29°→反131°」误判为采样误报。**真根因（`test_S4_replicateS2EventChain` 数值确证）**：库线吃库时球心接触位置**恰好等于** safe 边界（零余量），CCD 演进到接触点的浮点噪声偶尔越界 → 零容差硬钳抢在吃库事件前法向减半反向 → Han 解析按已退离速度**自动翻转接触系**把球二次反射**回库内**（vz +3.276→−1.638→+1.101）→ 子步反复钳制成 ~2 折出射角贴库滑出；滑行沿库入角袋 = 假进袋；噪声逐杆不同 = 偶发。**修复（两处物理约束，无 magic offset）**：①`enforceTableBounds` 触发加 `boundsEpsilon=0.5mm`（接触线上=合法吃库态非出界）；②吃库解析「只推不拉」护栏（v·n<0 才施冲量，过时事件跳过不记）。**验证**：S4 引擎出射==手动复算（27°/30°）；S2 全部反射恢复物理（131°→27°、114°→50°）、渲染无贴库段；扫描 1197 次吃库贴库幽灵 0/平行出射 0；`test_solveDrillC005` 117s 无回退；`PhysicsInvariant/Matrix/Scenario/CushionDiagnostics/PositionPlayFreeAim` 全过；3 个 `PhysicsEngineTests` 预存失败与修复前完全同集（⚠️ 待排查）。详见 `PHYSICS-DEBT.md §5.8`、FL-022（已回写 `geometry-spatial-reasoning` SKILL § 经验教训）。
- **P10 幽灵反弹根治 — enforceTableBounds 几何感知豁免 ✅（2026-06-12，iOS Architect；⚠️ 部分结论被 FL-022 推翻，见上条）**：用户截图报告「母球吃左长库后反弹轨迹明显不合理（贴库平行滑出+末端小钩），偶发」，要求先分析测试、确证根因再修。**根因（逐帧确证）**：角袋 jaw 弧合法接触圆（r+R=133.6mm）伸出矩形可玩框 1.3mm~4cm；ADR-P10-07 袋口豁免圈（pocket.radius+2R=127.2mm）差 0.9mm 没罩住接触带 → CCD **已正确检出并调度**的弧碰撞被每子步运行的矩形硬钳抢先（vx 取反减半、vz 保留、无事件、不作废缓存）→ 幽灵反弹 + 陈旧缓存事件接力出钩状伪迹。**修复（`enforceTableBounds` 三处）**：①jaw 弧接触带豁免（角度扇区内、距弧心 ≤ r+R+12mm）+ **径向速度门控 |vr|>0.02**（防切向蹭行研磨——无门控版曾把 `test_solveDrillC005` 拖到 signal kill，门控后 115s≈基线 123s）；②袋嘴圈内带速球无条件放行（删 towardCenter 方向门，rattle 弹出段合法；<0.35m/s 仍被 settle 收袋无研磨风险）；③硬钳后作废该球事件缓存。**验证**：300 杆扫描贴库线幽灵反弹 **4→0**（trial19 现正确产出弧#33 Han 反射 e≈0.68）；S2 疑似 131° 超宽反射排除（实为帧采样误报，真实 29°→27° e≈0.73 正常）；全量单测 372 过，3 个 `PhysicsEngineTests` 失败经基线对照**确认与本修复无关**（此前未提交工作遗留：largeCutClearShot/objectPath_reachesPocket/withSideSpin_objectPots，⚠️ 待排查）。详见 `PHYSICS-DEBT.md §5.7`。新增诊断 `PocketBehaviorDiagTests.test_S_cueRailReboundScan / test_S2 / test_S3`。
- **P10 显示闸门彻底下沉 + 引擎纯物理化 ✅（2026-06-07，iOS Architect，ADR-P10-06/07）**：用户拍板「贴库/进袋判定加了太多非物理规则……符合物理就该让它发生」「offset 全拿掉回归原始物理」「穿库安全网彻底去掉、母球进袋裸取引擎信号」「~1% 球甩出台面几米 → 修引擎让逃逸率≈0」。**(1) ADR-P10-06 移除显示层**：`ShotPredictor.predict` 删全部显示闸门（`clampedRecorder` 穿库安全网 ~100 行 + 母球/目标球进袋一致性闸门 + 整个 `enum DisplayGate`）；`recorder`/`cuePath`/`objectPath`/`cuePocketed`/`objectPocketed` 全裸取引擎信号；进/rattle/小力远jaw→近jaw→袋心进由喉腔几何自然涌现。**(2) ADR-P10-07 引擎根治逃逸**：固定步长上限 `maxEvolveStep=0.05`（dt 超限只推一安全步+记帧+作废缓存重检测，3285→57.5mm）；喉腔侧壁前延 `throatFrontExtend=0.045` 封库段↔jaw 对角接缝（→38.1mm）；近库自适应子步 `adaptiveEvolveCap`（仅逼近边界时收紧到位移级 `nearWallSafeStep=0.35R/速度`，根治高速窄喉隧穿）；`enforceTableBounds` 方向性收容（朝袋心放行/背离硬钳，低速 `jawSettlePocketSpeed=0.35` settle 收袋并补记落袋事件）。**(3) 性能门控**（解全局自适应致 6–10× 回归）：`simulate` 加 `highFidelityBounds`——仅 predict 最终展示模拟启用自适应子步（贴墙密帧、回放不外推穿墙），求解器 ~76 次短模拟完全不切步（恢复 ADR 前速度，结果量由段内采样+enforceTableBounds 兜底保证正确）。**验证**：单杆 predict 中位 **125ms**（曾回归 1114ms，预算 800）、满台 **663ms**（曾 4418ms，预算 3000）；越界不变量展示路径 **0.0mm**；`PhysicsMatrixTests` 矩阵1 求解器 **0 越界/96% 进袋**、矩阵2 裸引擎逃逸 **0.1%**（裸连测试，绕过 predict，用户可见路径恒经高保真 0.0mm）。`clampAwayFromPockets` 按用户决定**保留**（球摆放约束防摆进袋口，非轨迹修饰）。改 `EngineNumerics`/`EventDrivenEngine`/`TableGeometry+QiuJi`/`ShotPredictor`/`PHYSICS-DEBT.md §5.6`。**D-A3「下沉到引擎」终局达成**。
- **P10 求解器评分 — 放宽分支①接受「擦 jaw 再进」+ 否决纯平滑代理目标 ✅（2026-06-07，iOS Architect，ADR-P10-04）**：用户要「求解器满足管道法——可空心进取空心解、不可则擦远端 jaw，0–90°×各贴库距离都找到正确解，快速准确确定」。新增诊断 `PocketBehaviorDiagTests`（A 角度梯度/B 贴库容差/C 力度→rattle/D 目标球旋转撞 jaw/E 求解器vs暴力扫/F 近远 jaw 分类，输出 `build/pocket_diag/*.png`）。**采纳**：`solveAimOffset` 分支① 进袋接受判据由「干净空心进 `objCushionsBeforePocket==0`」放宽为「落袋前撞库点都在喉部 `objMaxPrepocketCushionDist≤0.18m`」→ 接受真实「擦 jaw 再进」解（保留母球碰前 0 吃库反 kick + 0.18m 喉部闸挡远库翻袋）。**否决**：曾试把 hybrid 分支①/② 整体换成不依赖 `pottedSelected` 的纯平滑代理目标（方向项+`objMinDist` 抵达项+远库翻袋平滑惩罚），实测三轮均回归——①纯方向被薄擦退化解骗（A 全未进）；②加抵达项→矩阵1 出 5 例远库翻袋；③加翻袋惩罚→进袋率暴跌 60%、确定性 case0 0/20、选到 kick 解。根因：本引擎实际落袋与几何代理对不齐，代理目标系统性弱于「直接奖励真进袋」。**验证全绿**：E 角度轴 11/11（含旧漏 28°/72°）、贴库轴 100/180/300mm 全进；F 近 jaw 全 rattle 符合管道法；`PhysicsMatrixTests` 矩阵1 进袋 88% + 0 翻袋/0 出界/0 母球碰前翻袋、矩阵3 确定性 20/20。**遗留→Layer C**：① 求解器仍依赖 `pottedSelected`，72° 等 knife-edge 受引擎事件遍历浮点非确定性偶发翻转（引擎层问题）；② drop/jaw 几何与库模型标定（擦远 jaw 更稳、现象5 加塞旋转真实化）；③ `effectivePocketAimPoint` far-jaw 偏置可显式强化。ADR-P10-04 见 `tasks/phases/P10-physics-content-pipeline.md`。
- **物理引擎技术债第三梯队 · 结构性重构 ✅（2026-06-06，iOS Architect）**：有第一梯队测试网（65 方法/~3800 场景）兜底，**全程零行为改动**（仅位置迁移/命名空间化/常量集中/引用收敛/遍历确定性化，数值与逻辑不动）。**引擎遍历确定性化**：`EventDrivenEngine` 加 `ballOrder`（插入有序球名列表），所有 `Dictionary`/`Set` 遍历改走它，清除 FL-020 §5.2 遗留的哈希种子随机化根因。**死代码清理**：移除失效诊断计数器/print/`debugLogPostEvolveOverlaps`。**D-A1** 拆 `EventDrivenEngine.swift` 1539→860 行，抽出 `EngineNumerics`（纯数值/运动学，可脱离引擎单测）+ `PhysicsEvent`（事件类型+`BallState`）+ `EventCache` + `SceneKitBridge` 四独立文件，16 处调用点改 `EngineNumerics.*`。**D-A3 ◑** `ShotPredictor` 三处显示闸门散落阈值（0.004/0.006/0.12/0.06/0.14/0.07/120Hz/0.1/0.2/0.05）抽入新 `enum DisplayGate` 逐条注明量纲（数值零改；中期「下沉到引擎」留待专门做）。**D-A4 ✅** 几何双真源收敛：内框尺寸/球半径以 `BTPhysicsConstants` 为唯一真源，`AngleSceneCalculator` 改引用（值 2.54≡2.540 等同，零改）；USDZ 袋口几何仍以 `AngleSceneCalculator` 为单一真源（ADR 见 PHYSICS-DEBT §5.5）。`xcodegen` 重生、lint 0、**全物理网 65/65 全过 0 失败**（含确定性 <1e-5m、矩阵母球绕库 0/远处翻袋 0/确定性跨度 0.00°）。改 `PHYSICS-DEBT.md` §5.5 + 标 D-A1/A4 ✅、D-A3 ◑。**剩第四梯队**（B1/B2/B3 依赖真实俯拍视频/USDZ 重导，人工 backlog）。
- **物理引擎技术债第二梯队 · 低风险清理 ✅（2026-06-05，iOS Architect）**：有第一梯队测试网（22 方法/~3800 场景）兜底，安全清理。**D-A2** 删 `CushionCollisionModel.swift`（636 行 Mathavan 2010 死代码，生产只用 Han2005）+ 移除唯一消费它的 print 对照测试 `test_cushion_HanVsMathavan`（零断言）+ Han2005 头注更新；**D-A5** 删死函数 `CollisionResolver.vector4`；**D-B4** `solveAimOffset` 评分魔数（−10 基线/0.3/0.05 scratch/1e-3 正则/100 miss/0.3 kick 惩罚/三级网格半幅步长）全抽入新 `enum AimScoring` 逐条注明量纲（数值零改动，评分序行为由矩阵 1/3 覆盖故未抽 score 纯函数单测）；**D-D2** 搜索保真 500/15 抽具名常量（降保真未做——行为/性能改动有"双景观错位"回归风险，留待专门优化）。`xcodegen` 重生（pbxproj 0 残留）、`PhysicsEngineTests` 23/23、`CushionDiagnosticsTests` 4/4（原 5）、`Benchmark` 14/14、`Invariant` 9/9、`Scenario` 7/7、`Matrix` 3/3（母球绕库 0/远处翻袋 0/确定性跨度 0.00°）全过、lint 0、**零行为回归**。改 `PHYSICS-DEBT.md` §5.4 + 标记 D-A2/A5/B4 ✅、D-D2 ◑。**剩第三梯队**（拆 EventDrivenEngine/下沉显示闸门/几何双真源/引擎遍历确定性化，结构性重构有网兜底）+ 第四梯队（B1/B2/B3 依赖真实视频，人工 backlog）。
- **物理引擎技术债审计 + 第一梯队测试网 ✅（2026-06-05，iOS Architect + QA Reviewer）**：用户要「全面审查物理引擎、避免技术债」，澄清为**只读审计**→产出 `tasks/qa-reports/PHYSICS-DEBT.md`（21 文件 ~6315 行，17 项债务分 架构/正确性/测试/性能 四类 + 测试覆盖缺口矩阵 + 四梯队偿还建议；基线 42 项物理测试全绿）。**核心判断**：内核忠实移植 pooltool、探针绿灯、无阻塞 bug；债集中在 ①移植期死代码（D-A2 `CushionCollisionModel` 636 行 Mathavan 仅测试调用、生产用 Han2005）②`ShotPredictor` 显示闸门 patch-on-patch 耦合（D-A3）③测试以事后诊断为主、缺不变量护栏（D-C1/C3/C4）④常量未真实标定（D-B1）。随后按用户「1和2一起做」+ 两轮「考虑真实台球复杂度、用例量级要到几百上千」执行**第一梯队（第 1+2 项）全扩面**（零生产代码改动）：新建 4 套护栏 `PhysicsInvariantTests`(9)+`PhysicsScenarioTests`(7)+`PhysicsMatrixTests`(2)+`PhysicsPerformanceTests`(3)，全绿 **21 方法 / 约 3800+ 个被断言场景**（XCTest 方法数≠被断言场景数，后者才反映问题）。(a) **属性化随机不变量 ~1700 场景**（种子化 SplitMix64，trial 提到几百）：能量耗散单调（最坏 E/E0=1.0000）、无重叠（0mm）、生产轨迹不出界（0mm，守 FL-018）、自由球减速单调（0 回升）、模拟收敛无失控（终速 0）、**球-球碰撞动量守恒 600 次（误差 0.0000）+ 能量耗散（≤0.99）**、静止球被触碰前不动（0 漂移，重写为「触碰前不动」真不变量——高速母球会绕库飞回撞身后球，旧「身后=永不碰」假设错误）、确定性（引擎逐帧一致/predict 位置 <1e-5m）；(b) **系统化组合矩阵 2054 场景**（确定性网格，逐例断言 + 失败打印复现 ID）：矩阵 1 求解器进袋合约 338 可行 predict（0 出界、0 画面≠物理、进袋率 85%、52 组沿正确线停袋前）；矩阵 2 裸引擎出射方向 1716 组（**最坏方向误差仅 1.9°=零翻袋坏解**、穿库逃逸率 1.1–1.3% 优于审计估计 2.7%）；(c) **真实球理场景 ~50**：跟/定/缩杆落点次序、力度→走位路程单调（5.41→12.52m）、加塞改目标球方向、带塞吃库变线、连续多库 9 库不出界、组合球串二库 1125mm、清晰球进袋矩阵 32/32；(d) **性能门槛**：单杆中位 101ms（预算 800）、满台+8 障碍 514ms（预算 3000）+ measure 基线。**测试期发现（强化 D-C3）**：predict 分离角等派生标量带 ~6.6e-5° 运行间微抖动，定位为求解器 ~75 次短模拟评分择优时浮点求和顺序（引擎字典/Set 遍历）所致——非混沌发散，护栏锁 0.02°；根治＝引擎遍历改确定性有序容器（归第三梯队，不阻塞）。`xcodegen` 收纳 4 文件、lint 0。**第一梯队完成**：D-C2 已由矩阵 2054 场景实质收口（无翻袋坏解/方向连续/不穿库均转机器断言），`ShotScenarioRenderTests` PNG 出图保留为人工复核用途。**进一步按用户「直球求解必须保证母球碰目标球前不吃库、目标球进袋前不吃库」加体检 → 矩阵 1 抓出真 bug FL-020**：3/285 进袋解母球先吃 4 库，聚焦 `t3p5c10s+v2.8` 同输入连跑 30 次 `cueCushionsBeforeContact` 在 0/4 随机翻转、进袋 28/30、分离角取 3 值（求解器约 40% 概率选「母球绕 4 库歪打正着」kick 退化解 + 引擎无序遍历致宏观翻转）。**修复**：`ShotPrediction` 加权威字段 `cueCushionsBeforeContact`，`solveAimOffset` 最优区追加 `&& cueCushionsBeforeContact==0`（钉死直击解唯一占 −10）+ 方向解支轻惩罚。修复后矩阵 3（t3p5/t3p4/t4p4 各 20 次重跑）cuePreBank 恒 0、进袋 20/20、分离角跨度 0.00°（连旧记的 1e-4° 微抖动一并消除——那其实是评分并列的尾巴）；矩阵 1 进袋率维持 85%、母球绕库 0、远处翻袋 0；`PhysicsEngineTests` 23/23、Invariant 9/9、Scenario 7/7、Reconstruction 2/2 全过、lint 0。新增 FL-020 + 回写 `10-ios-architect.mdc` v0.6。本轮**含 1 处生产求解器修复**（非零生产改动）。
- **P11 走位编排器与击打序列 ✅（2026-06-05，iOS Architect + SwiftUI/Data，ADR-P11-01）**：用户要「类似分离角的页面，桌上自由摆母球 + 任意目标球，逐杆选目标+袋口、调连续力度/打点控制母球落点，串成击打序列」，用途＝教学视频制作 + 走位训练。复用 N 球物理引擎（`EventDrivenEngine`）+ USDZ 现成 16 颗球（`AngleTrainingScene.allBallNodes`）+ 单杆交互（`AngleSceneView`），改动集中在新模型/新页面 + `ShotInput` 小扩展。**交付**：①`ShotInput.obstacles`+`ShotPrediction.finalPositions/pocketedBalls`（每杆只对「选中目标+指定袋口」求解，其余在桌球作障碍真实碰撞，瞄准评分零改动）；②内容模型 `PositionPlayModels`（BoardSnapshot/PlannedShot/SequenceStep/PositionPlaySequence，进袋离场回库 + 中途改摆截断重录 + 球号无规则语义）；③`PositionPlayViewModel` + `PositionPlayComposerView`（球库面板/拖球/点选目标/选袋/连续力度滑杆+打点盘/序列时间轴）；④SwiftData `PositionPlaySequenceEntity`（JSON blob）+ `PositionPlaySequenceStore` + 注册 `ModelContainerFactory`；⑤`PositionPlayDrillExporter`（序列→符合 schema 的 Drill JSON，`shotIntent.shots[]` 逐 Step）；⑥`Core/Media`：`SequenceVideoExporter`（SceneKit 真台逐帧 `SCNRenderer.snapshot`）+ `VideoWriter`(AVAssetWriter mp4) + `GIFEncoder`(CGImageDestination) + `ShareSheet`；⑦多杆 `PositionPlaySequencePlayer` + `PositionPlaySequencePlayerView` + `PositionPlayTrainingView`（@Query 列已存序列）。**IA**：编排台→角度 Tab 进阶、走位训练→角度 Tab 训练（仅扩 `AngleRoute`+`angleDestination`，不进球库、不动 5 Tab）。`xcodegen` 收纳 14 个新文件、`make build` ✅、`PhysicsEngineTests` **23/23**（含 2 条多球障碍用例：远处障碍不挡仍进 / 进球线被挡不进）、lint 0。新增 `tasks/phases/P11-position-play-composer.md`（ADR-P11-01）。**遗留非阻塞**：满台单杆求解 ~数百 ms（编辑模式可接受，跟手度后续优化）；序列云端 OTA；训练形态评分细化。
- **P11 编排台交互/布局重构 ✅（2026-06-05，SwiftUI Developer，ADR-P11-02）**：用户逐条反馈首版编排台问题（击打后自动复位、重置全清、球库单行数字、顶部状态栏冗余、球库压桌等）。**交付**：①**击球状态机（保留击球/记录两键）**——`play` 改 `finishStrike`：击球后球停在 `finalPositions` 终局、进袋离场，不再复位；编辑入口（拖球/选目标/换袋/调参）若 `hasStruck` 先 `restorePendingBefore()` 软回退再算；「记录」以 `pendingBefore` 为 before；「重打」`replayCurrent` 只退本杆不动已记录的杆；「清空并重来」`resetAll` 移入更多菜单。②**完整拖拽**——球库球拖到桌面任意点落位（新 `TableProjector.unproject` 反投影 + `clampMultiBall`），桌上球拖回球库区松手即移除（新 `AngleSceneView.onDragEndedAt` 带结束坐标；旧 `onDragEnded` 签名不变，其它页零改动）。③**真实球面球库**——新 `Core/Scene/BallFaceRenderer` 进编排台离屏烘焙 USDZ 球面圆图缓存，双行 `LazyHGrid` 替代数字 token。④**夹角浮标贴目标球**——移除顶部状态栏，夹角+选中环用 SwiftUI overlay 经 `TableProjector.project` 跟随目标球屏幕投影；可行性=环色、母球进袋=红点（去整条文字）。⑤**布局不挡桌**——球库实心底栏在 `VStack` 流内、球桌独占上方铺满。⑥按钮：播放→击球（自绘 `CueStickShape` 图标）、重置→重打。`make build` ✅、lint 0。改 `AngleSceneView.swift`/`PositionPlayViewModel.swift`/`PositionPlayComposerView.swift`，新增 `BallFaceRenderer.swift`；ADR-P11-02 见 `tasks/phases/P11-position-play-composer.md`。
- **P11 分离角页底部控制条对齐编排台 ✅（2026-06-12，SwiftUI Developer，ADR-P11-09）**：用户三点要求（分离角打点/速度位置样式参考编排台；打点弹层底材用分离角的半透明材质更舒服；功能按键全移最下方与编排台同款）。①分离角页删右侧 FAB 列 + 「击球设置」HUD（连 `HUDHeightKey` 机制），改编排台同款底部条：`BTSpinMiniIcon` 打点入口 + 连续力度滑条(0.5–6.0) + 档名读数 + 重置圆钮 + 击球胶囊；`speedLevel` 5 档枚举→连续 `velocity`（默认 3.3）。②打点盘改共享浮层卡片 `BTSpinPadCard`（「打点」标题+✕+`BTSpinPad`+读数+回中，`ultraThinMaterial` 圆角卡浮在球桌底缘）——**两轮坑**：系统 sheet 方案 a) `environment(\.colorScheme,.dark)` 不影响 presentationBackground 材质解析（白底）；b) `preferredColorScheme(.dark)` 后 sheet 底下纯黑+压暗层使材质过深被用户打回——半透明材质要透出球桌绿色必须浮在球桌上方（与旧「击球设置」HUD 同位）。③编排台私有组件下沉共享：`BTSpinPadCard`/`BTSpinMiniIcon`/`CueStickShape`/`PowerDisplay.name`/`SpinDisplay.readout` 迁入 `Core/Components/BTSpinPad.swift`，删两处重复实现与 spinPadSheet。**验证**：`make build` ✅、`testScenePopups` 三轮截图核验 ✅（底部条与编排台一致、两页浮层卡透出桌面绿色）、lint 0。ADR-P11-09 见 phase 文件。
- **P11 2D 球桌统一自适应取景 + 角度首页海报墙 ✅（2026-06-12，SwiftUI Developer + UI Reviewer，ADR-P11-08）**：用户两点打回（角度首页仍简陋需一直下滑；2D 球桌页位置/占比/居中/按钮风格不统一）。①**统一取景根因修复**：装桌后实测球桌世界包围盒回填 `CameraRig`，新 `fitRotatedTable(viewSize:)` 按视口宽高比算正交 scale（双轴约束取大 + 1.2% 余量），`AngleSceneView.autoFitsRotatedTable` 渲染循环逐帧适配；分离角/反射/翻袋/2D瞄准/角度与打点/编排台 6 页启用，删 `composerTopDownScale` 等全部硬编码 scale——任何视口球桌完整可见、双轴居中。②编排台去 60pt 左栏：信息上移顶部单行（模式 chips+切角胶囊+警示/录制 pill），球桌占满全宽真居中。③新 `BTSceneFAB`（56pt 圆形 FAB，primary 绿渐变/neutral 半透明）替换 4 页自绘按钮。④角度首页重写为 `BTSegmentedTab`（学习/训练/工具）+ 双列 `AnglePosterCard` 海报墙（渐变封面+大字水印+chip，与训练页 `BTPlanCover` 同语言），每分段单屏放完。⑤打点盘 sheet 加右上 ✕ 关闭钮（原仅可下滑且手势被打点盘吞掉）。**验证**：`testScenePopups` ✅（4 弹层截图核验）+ `testUnifiedDesignPages` ✅（8 帧逐张核验）+ `PositionPlayFreeAimTests` 7/7 ✅、lint 0。**测试基建教训**：UI 测试反复假失败根因=同机另一会话并行对同名模拟器跑 xcodebuild（重装杀进程），UI 截图测试改独立设备（iPhone 17）隔离 + `launchClean` 改进程态校验。ADR-P11-08 见 phase 文件。
- **P11 进袋入洞段 v2 + 场景页统一设计语言 ✅（2026-06-12，SwiftUI Developer + UI Reviewer，ADR-P11-07）**：①进袋消失重做（用户两次打回后根因坐实）：引擎深入/jaw-settle 落袋**不吸心**（pocketed 帧=捕获点，实测距袋心 0.069–0.079m），旧沉入 move 目标取 pocketed 帧位置 ⇒ 零位移原地淡出；新 `solvePocketEntry`——以进袋时真实速度**匀速**冲洞（不提前减速）→ 速度射线与袋口圆求远交点=**远端袋弧碰撞** → 0.12s 回落袋心 → 停顿淡出；袋心按 `nearestPocket` 查找不信任帧位置；回放 SCNAction 与导出器逐帧求值同源（30fps 抽帧核验）。②统一设计语言（黑底+品牌绿标题+指标胶囊+胶囊分段 `BTChipRow`+右下 FAB）：反射/翻袋系统 segmented→胶囊分段、分离角大结果卡→单行指标胶囊、编排台标题改绿、**角度预测页整页暗色重做**（统计下沉顶部胶囊+换题/参考胶囊行）、**角度Tab首页卡片化**（学习/工具整行渐变图标卡、训练/进阶双列彩色封面卡，对齐训练/动作库语言）。`make build` ✅、入洞数值探针 ✅、`make position-export` ✅、新增 `testUnifiedDesignPages` 截图回归 6 帧全核验、lint 0。ADR-P11-07 见 phase 文件。
- **P11 零遮挡布局 + 重打全量恢复 + 进袋沉入 ✅（2026-06-11，SwiftUI Developer，ADR-P11-06）**：用户 5 项体验问题。①重打恢复目标球/袋口/速度/打点/瞄准模式（`lastShot:(before,shot)` 上下文）；②删全部球桌叠层：左侧 56pt 信息栏（进袋/自由+角度厚薄+母球进袋+录制指示）、状态行上移导航栏 principal、击球/录制/重打移右下操作列；③实测 USDZ 外框半长 1.4055（新增实测契约测试），`composerTopDownScale=1.416` 上下木框完整可见、球桌像素尺寸基本不变；④启用 `pocketSinkDuration` 0.22s：进袋改「easeOut 沉入袋心→停顿 0.35→淡出 0.25」，回放/离线导出同源（抽帧核验球肉眼进入袋口圆）；⑤击球后打点自动回中、打点盘 sheet 紧凑化（detent 290→204）。`make build` ✅、FreeAim 7/7、`make position-export` ✅、新增 `testPositionPlayComposerOnly` UI 截图三连核验（布局/击球后/重打恢复与击打前一致）、lint 0。恢复被 xcodegen 删的 `QiuJiUITour.xcscheme`。
- **P11 孤岛移除 + 自动选袋遮挡闸 ✅（2026-06-11，iOS Architect，ADR-P11-05）**：收口 ADR-P11-04 两项遗留（用户拍板「移除，加上障碍球遮挡判定」）。①删「走位训练/我的序列」整条孤岛链路 5 文件（TrainingView/SequencePlayerView/SequencePlayer/SequenceStore/`PositionPlaySequenceEntity`），SwiftData schema 纯减实体（无需 MigrationPlan）、`AngleRoute` 删 `.positionPlayTraining`；序列消费唯一路径=录制分享 JSON→`make position-export`。②`AngleSceneCalculator.isPathBlocked`（X–Z 点到线段距离<2R，投影钳 [0,1]）接入 `selectBestPocket`：障碍球挡「母球→假想球」或「目标球→进球点」即不可行，全不可行退最近袋（可手选）。`make build` ✅、`PositionPlayFreeAimTests` 6/6（含金标准 5 例）、lint 0。ADR-P11-05 见 phase 文件。
- **P11 编排台操作简化轮 ✅（2026-06-11，SwiftUI Developer + iOS Architect，ADR-P11-04）**：用户 11 项需求 + 3 分叉拍板（录制只分享 JSON / 离线脚本本轮做 / 时间轴拿掉）。**(1) 连续击打状态机**：废除 `hasStruck`/`pendingBefore` 软回退与只读预览，击球后桌面前进为新真相（进袋回库、母球停走位终点），自动选下一杆=距母球最近目标球+距目标球最近可进袋袋口（由最小切角改最近距离），「重打」才回退上一杆击打前。**(2) 录制开关**：删逐杆记录/时间轴/保存/MP4/GIF/Drill 导出菜单/退出草稿；「录制」开→每次击球自动记一杆（重打撤回）、停→分享序列 JSON（iso8601）；离线复现=新 `PositionPlaySequenceExportRunnerTests` + `make position-export`（读 `build/position_play_sequences/*.json`→物理引擎复现→`build/position_play_export/*.mp4+.gif`，端到端 ✅ 抽帧核验）。**(3) 球库微边框**：固定两行序（母+1–7 / 8–15）、只显在库球按序补位、32pt 球、删说明文案，栏高减半以上。**(4) 控制行**：力度滑条移球桌/球库之间，左侧 `SpinMiniIcon` 点击弹打点盘；删「设置」「随机」按钮与随机球形。**(5) 进球观感**：`extendPathToPocketRim` 进球线延伸到袋口圆边缘（jaw 碰撞由真实轨迹自带）；`TrajectoryPlayback` 进袋停顿 0.35s 再淡出 0.25s（编排台/导出同源）。**(6) 运杆动画**：回杆 `d=a+k·v`（0.05+0.035v）smoothstep 0.5s→停顿→匀加速出杆（`a=v²/2d`，触球杆速=v），`CueStick.update(pullBack:)` 逐帧驱动。`make build` ✅、`PositionPlayFreeAimTests` 5/5、runner 1/1；`PhysicsEngineTests` 20/23（3 失败与 ADR-P11-03 记录的在途库边物理整合同组既有失败，本轮未触引擎求解路径）。ADR-P11-04 见 `tasks/phases/P11-position-play-composer.md`。遗留：「我的序列」页成孤岛待定夺；自动选袋未含障碍遮挡。
- **P11 编排台系统性整改 ✅（2026-06-10，iOS Architect + SwiftUI Developer，ADR-P11-03）**：系统性审查发现 15 项问题（P0 状态机/数据完整性 ×2、P1 链一致性/竞态/退出丢失、P2 反馈缺失、能力边界 #11/#12、球面图 #15），用户确认后一次性整改。**交付**：①**求解上下文打包** `SolvedShot(before+shot+prediction)`——「击球/记录」只消费它，修「目标球进袋后记录静默失效」（P0）与记录竞态（+`!isComputing` 闸、`invalidatePendingPredict` generation 作废）；②**只读预览模式**——时间轴点按预览（黄横幅+返回编排，编辑入口全 guard），长按=回退（确认对话框）/逐杆备注（播放器展示）；③**自由瞄准模式（#11）**——`AimMode.pocket/.free` 切换，自由杆不选目标/袋口、点桌面/球/袋设方向（`AngleSceneView.onTableTapped`），引擎新增 `ShotPredictor.simulateFree`（直瞄真实模拟+`extraBallPaths`），模型 `PlannedShot.freeAim`（旧数据兼容），新增 `PositionPlayShotSolver` 统一编排台/播放器/视频导出三处求解，自由杆禁导出 Drill JSON（`canExport`）；④**球面图真根因修复（#15）**——USDZ pivot≠球心 → 按 `boundingSphere` 取景 + 无光照直出贴图（修 PBR 过曝白月牙）+ 姿态矩阵出图选 `(π,0,π/2)` + 号码徽标兜底；⑤**状态反馈**——`statusText` 上屏状态行（求解中菊花）、已击球=「记录」绿描边高亮、障碍挡线启发式提示（球心距线<2R）；⑥**破坏性纪律**——随机/清空在有步时=新序列（新 id）+确认、工具栏分享/更多菜单分离、退出自动存草稿；⑦**力度（#12）**——0.5–6.0 m/s（支持轻推）+ 场景区常驻内联滑条 + 档名（轻推/轻/中/中大/大力）。**验证**：`make build` ✅；新增 `PositionPlayFreeAimTests` 5/5（坐标契约金标准+直瞄不变量+Codable 兼容）、`BallFaceRenderDiagTests` ✅（PNG 出图+覆盖率断言）；`PhysicsEngineTests` 20/23——3 失败经 git stash 在 HEAD 复跑全过，**确认源自工作区在途库边物理整合**（与本轮无关，本轮对 ShotPredictor 纯新增）。⚠️ 发现 `table-geometry.md` canvasY↔sceneZ 符号与代码真源相反（双真源矛盾，待文档修正）。ADR-P11-03 见 `tasks/phases/P11-position-play-composer.md`。
- **P10 Track B-2.5 — 打点盘真实化（DR-018）✅（2026-06-05，iOS Architect）**：用户要「按真实母球/皮头尺寸/皮头弧度同比例，不同加塞对应真实加塞点」。①**统一参数源** `CuePhysics`：`tipDiameter=11mm`(中八)、`tipContactRadius`、`tipCurvatureRadius=10.5mm`(nickel)、`miscueLimitFraction=0.5`（打滑极限，满塞≈半个半径），删旧无用且撞名的 `tipRadius`，`CueStick.tipRadius` 改引用单一来源。②**SpinPadView 真实比例重做**：盘=母球正面，加**打滑极限虚线圈(0.5R)**，红色皮头接触斑直径=皮头/母球真实比例(11/57.15≈0.19)取代固定 18pt，拖动**钳到 0.5R**（之前到球边缘 1.0R，物理打不出必 miscue）；读数改「占满塞百分比」。③语义不变（spinX/spinY=接触点偏移/R）但收到真实区间——满塞 squirt≈1.9°（旧版到 1.0R 偏大不可达）。④**皮头曲率精确换算**（用户「两个都做更严谨」）：两球相切几何 `tipContactPullFactor=R/(R+ρ)≈0.731`，打点盘以「皮头中心摆放」为操作量、真实接触点=中心偏移×系数（曲率拉向球心），红点画皮头中心、打滑圈在中心可达边界 0.5R/系数≈0.684R。⑤**shotIntent miscue 体检+守门**：扫全部 Drill，4 条 |spin|幅值>0.5R（c004/c017/c020/c021）按方向钳回 0.5R 改 JSON + 在内容入口 `shotInput()` 加 `clampToMiscueLimit` 守门，4 条缩略图重烘焙。`make build` ✅、`PhysicsEngineTests` **21/21**、lint 0。改 `BTPhysicsConstants.swift`/`CueStick.swift`/`ShotSimulationView.swift`/`ShotIntent.swift`/`PhysicsEngineTests.swift`/`Drills/cueAction/c004|c017|c020|c021.json`/对应缩略图。〔`CueBallStrike` 保持 pooltool 忠实不钳制；钳制只在意图层。〕
- **P10 Track B-2.4 — 母球进袋（失误）误判修复（FL-019）✅（2026-06-05，iOS Architect）**：用户反馈「分离角与走位」页 cut9° 带塞母球**走位弧线擦过中袋嘴后继续走到台面中下部、根本没进袋**，状态栏却报「母球进袋（失误）」。根因＝目标球进袋判定早已用「显示用钳制轨迹最近点 ≤ 捕获窗」做一致性闸门，但**母球 `cuePocketed` 直接取裸引擎信号、无同源闸门**；带塞母球是曲线(squirt+swerve)，袋口 CCD 用直线/抛物线模型排程进袋事件、`resolvePocket` 接受阈值又宽(`pocket.radius+R*1.5`≈中袋117.8mm) → 预测会进漏斗、实际只擦到 54–65mm 却被裸引擎判落袋。**修复**：给 `cuePocketed` 加与目标球**同源的显示一致性闸门**（要求母球钳制轨迹真正落入某袋捕获窗、落袋吸球心后最近点≈0）。诊断 `test_diag_cueScratch`（180 含塞场景）：假阳性 4→**0**（上报进袋 11→6，余 6 为白线真到袋心的诚实 scratch）；`PhysicsEngineTests` 18/18、lint 0。引擎宽松接受阈值留物理标定 backlog。改 `QiuJi/Core/Physics/ShotPredictor.swift` + `QiuJiTests/ShotScenarioRenderTests.swift`（诊断/扫描）。
- **P10 Track B-2.3 — 吃库后立即停住 bug 修复（FL-018）✅（2026-06-05，iOS Architect）**：用户反馈母球**吃库瞬间速度还很快却定格在库边**。根因＝`ShotPredictor.clampedRecorder` 的「穿库安全网」按**回放重采样的解析外推位置**（容差 6mm）判飞出，而 `TrajectoryPlayback` 在「撞库事件帧→下一帧」间用事件帧速度外推、撞库帧仍带朝库入射速度 → 采样位置被外推到库线内侧 7~9mm（吃库越快冲越远，v5.8>6cm）瞬时越界 → 被误判穿库冻结 + `allDone` 截断后续全部轨迹（原始物理其实仍在多次吃库走位）。**修复**：飞出判定改为**基于引擎记录帧（物理真值）**——正常反弹记录帧绝不越线、只有真飞出才会记录帧越界≥6cm 且远离袋口嘴 14cm，预扫每球记录帧求首次飞出时刻才冻结+截断；事件帧间瞬时外推过冲改为**仅化妆性钳位、保持运动不截断**。回归 `test_diag_cushionFreeze` 误冻结 **0/60**、`PhysicsEngineTests` 18/18、`make build` 通过、lint 0。改 `QiuJi/Core/Physics/ShotPredictor.swift` + `QiuJiTests/ShotScenarioRenderTests.swift`（回归守卫）。
- **P10 Track B-2.2 — 目标球"消失"bug 修复 + 360 组合矩阵验证 ✅（2026-06-05，iOS Architect/SwiftUI）**：①**修复目标球消失**：用户反馈「击球后重置/移动目标球时目标球消失」。根因＝`TrajectoryPlayback.action` 在球进袋后追加 `.removeFromParentNode()`，与 `finishPlayback` 复位**竞态**把目标球移出父节点；且 `applyBallLayout`（reset 调用）只设 `isHidden=false`/`position` **不重新挂回父节点** → 一旦被移除，reset/拖动都救不回。修复：(a) `action` 加 `removeOnPocket` 参数，分离角页传 `false`（只淡出、保留节点）；(b) `applyBallLayout` 防御性 `if node.parent==nil { rootNode.addChildNode(node) }` + 复位 opacity。②**360 组合矩阵**（`test_diag_combinatorialMatrix`：目标球开阔/近长库/近短库/近角袋/近中袋/半台 × 多袋口 × 切角 20/45/65 × 力度 1.6/3.3/5.8 × 塞 无/高/低/左/右）：**进袋221 / 方向对未进139 / 刮杆5 / ⚠️方向错翻袋 0**——零翻袋坏解，每个可行球都「进袋或沿正确进球线未进」，坐实 v3.1 修复。新增渲染 `06_cushion_pocket_proximity`/`07_spin_near_cushion`（贴库/近袋/塞×力度接触表，肉眼确认进球线方向 + 杆法走位 follow/draw/squirt 正确）。`make build` ✅、PhysicsEngine 18 全绿、lint 0。③**回放复位迟滞修复**：用户反馈「母球停下后迟迟不复位、像在等目标球」。根因＝之前为修「缓行入袋被截断」把 `clampedRecorder` 的有效时长 `lastActive` 改成「任何运动态都延长」（去掉速度阈值）→ 低滚动摩擦下球会以肉眼几乎静止的速度蠕行很久才转 stationary，有效时长被拖长、复位迟迟不触发。改为：`lastActive` 用 `stopSpeed=0.07m/s` 阈值（蠕停不计），**但单独记录进袋时刻 `lastPocket`** 保证缓行入袋的落袋帧仍被纳入（不回退 cut15/v3.3 截断 bug）。有效时长 = max(可感知运动末+0.1, 落袋+0.2)。验证：cut15 全力度仍 om0 进袋、cut 扫描不变、PhysicsEngine 18 全绿。
- **P10 Track B-2.1 — 求解器目标改为「进球线方向正确」而非强制进袋 ✅（2026-06-04，iOS Architect，ADR-P10-03 v3.1）**：用户洞察「大切角+小力度目标球动能不足进不去可接受，但进球线方向一定要对」。截图诊断坐实旧 bug：求解器**未进时退化为最小化到袋心最近距离**→挑到**绕库擦袋的多库翻袋解**（碰后初始方向错），正是用户看到的"大角度变翻袋"。改 `solveAimOffset` 为 **hybrid 评分**：①能直接进袋(0 撞库)=−10 基线；②否则按**目标球碰后方向 vs 进球线(target→袋心)夹角误差**（平滑单峰、自动补偿 squirt+swerve+throw、天然排斥 banking）。效果：可进的球干净直进；进不去的薄/弱球**沿正确进球线停袋前**（如实未进、不绕库）；左上角袋(idx0)对称恢复；用户截图球形不再翻袋。方向景观平滑 ⇒ 粗扫 0.2°→**0.5°**（~75 次短模拟，predict 提速）。新增 `PhysicsEngineTests.test_predictor_largeCutClearShot_directPotBothCorners`（守护大切角清晰球直接进、不退化翻袋）。物理套件全绿（PhysicsEngine 18、Benchmark 14 E-solver 5/5、DrillBake 5/5）。注：本轮顺带 `xcodegen` 收纳用户新增的 `DrillShotResolver.swift`（缩略图物理烘焙，原未在 target 致构建失败）。
- **P10 Track B-2 — 截图诊断驱动的漏斗袋口模型 v3 ✅（2026-06-04，iOS Architect，ADR-P10-03，PD-010）**：用户"对分离角与走位页生成多袋口/角度/塞/力度的击球，分析轨迹与进袋，用**截图**看真实情况后优化物理引擎及袋口进袋"。新建 `ShotScenarioRenderTests`——纯 CoreGraphics **2D 顶视接触表 PNG** 渲染器（库边/jaw/落袋孔/标记/幽灵球/瞄准点/母球+目标球真实轨迹/进袋判定一并可见，输出 `build/shot_probe/*.png`），对多袋口×切角×塞×力度矩阵出图肉眼复盘。**截图证伪 ADR-P10-02「喉腔模型」已解决**：进袋呈**斑点状非单调闪烁**（角袋 cut15 v3.3 偏不进、瞄准偏移每 0.1° 翻转）。**根因坐实**：①喉腔「弹珠箱」高恢复系数侧/后壁把对准球反复弹射致进袋带碎裂；②求解短模拟与上报全模拟进袋带错位；③粗扫 0.5° 跨过 0.2–0.4° 窄带漏检；④缓行入袋被显示钳制器 0.02m/s 阈值截断；⑤求解 scratch 避让把直接进球推到绕库别扭解。**修复（漏斗袋口模型 = 真实袋口几何）**：(a) 去喉腔弹珠箱、保留 jaw 闸口；(b) 落袋捕获覆盖 jaw mouth（角 0.052→0.070、中→0.075，干净进开口必落袋、jaw 仍拦坏球）；(c) 落袋吸心（`resolvePocket` 球心吸到袋心，画面=物理）；(d) 求解 sim 改 500/15 与上报同保真度 + 粗扫 0.2°；(e) 直接进袋优先（`objCushionsBeforePocket`，评分 −10+撞库数×1.0+scratch×0.3，近全直球如实报母球进袋）；(f) 慢进袋不截断（钳制器按运动态判定）。**结果**：4 张接触表肉眼全部物理自洽——干净直进、~90° 切线走位、follow/draw/squirt 杆法可见、无穿库/碎裂/判进画面不进；仅近全直球如实报 scratch。`QiuJiTests` 物理套件全绿（PhysicsEngine 含新增非单调回归断言、Benchmark 14/14 E-solver 5/5 E-geom 3→4/5、穿库扫描、DrillBake 5/5）、`make build` 通过、lint 0。新增 `QiuJiTests/ShotScenarioRenderTests.swift`。**性能权衡**：单次 predict ~150–200ms（求解提保真度+0.2° 粗扫），后台线程+防抖+取消下可用，取正确性优先。**遗留非阻塞**：薄切 55° 窄口个别力度敏感（真实）；中袋 mouth ±0.035→±0.046；Track B #3 常量标定需真实俯拍视频；predict 跟手度优化。
- **P10 Track B-1 — 物理保真进球管线 ✅（2026-06-04，iOS Architect，ADR-P10-02）**：聚焦用户要的"完整、物理保真的进球点/进球判定算法"。用**程序化 USDZ 网格实测**（`TableGeometryProbeTests`，用户选定测量法）**证伪探针的「jaw 放错 17mm」预设**——库边（±0.635/±1.27）、袋心、jaw（与库边精确相切）实测皆自洽，几何无需重导。真正问题＝旧引擎**袋口只是袋心一个判定圆**（13.4mm 甜点 / 后改 0.055 仍是放大的圈），无真实袋口内部结构，球要么命中甜点要么穿库飞出；闭环求解又在窄口偶落坏局部最优。**用户复评后明确反对"放宽捕获半径"为偷懒、要真实袋口物理。修复**：(a) **真实袋口物理 = 喉腔模型**（`TableGeometry.chineseEightBallQiuJi` + `throatCushions`）：每袋口 = jaw 库（偏转切球）+ **喉腔**（实测 jaw 尖端 `pocketJaws` 沿喉轴挤出的两条侧壁 + 一道后壁，可反弹）+ 喉腔内**物理落袋孔** P（`pocketDropRadius`，球心进孔即落袋）；rattle 由几何自然涌现（穿库飞出 8%→2.7%），落袋孔半径仅表物理洞口、与视觉标记半径解耦。(b) **两逻辑分清**：(A) 袋口判定＝球来时由喉腔真实几何决定进/rattle；(B) 瞄准求解 `solveAimOffset` 固定力度+塞采样寻优最优接触点、在 A 下让目标球落袋（直接/借 jaw），打不进如实报。(c) 稳健化求解（进选定袋优先 −10 基线 + scratch 仅 mm 量级轻罚〔禁 1.0 大值〕 + 粗扫加密 ±16°/0.5° 两级细化）。(d) **画面=物理**：`ShotPredictor.objectPath` 取真实模拟折线（含穿喉腔反弹）、`objectPocketed/simObjectPotted` 改**轨迹基**判定（消除穿库假阳性），`ShotSimulationViewModel` 诚实显示进/未进。**结果**：E-solver 角袋 cut0–45 全力度进、cut55（薄）个别力度敏感、中袋全力度进、c002 由 ⚠️ 转 ✅、5 条试点 Drill 真实模拟 5/5。`QiuJiTests` **291/291**、`make build` 通过、lint 0。新增 `QiuJiTests/TableGeometryProbeTests.swift`（USDZ 实测+进球覆盖诊断）+ `PhysicsEngineTests` 3 条保真断言；报告 `PHYSICS-PROBE.md` §USDZ 实测标定、`DRILL-BAKE-REPORT.md`（c002→✅）。**遗留非阻塞**：中袋 jaw mouth ±0.035→实测 ±0.046；朴素瞄准 E-geom 3/5（窄喉口掠角 rattle 真实物理，求解器规避）；Track B #3 常量标定需真实俯拍视频。
- **动作库轨迹/走位改由物理引擎真算 — ✅（2026-06-04，iOS Architect，DR-017）**：用户"现在球的运动轨迹，看起来不是通过物理引擎计算出来的，而是画出来的线，请修正"。根因：DR-016 渲染层消费 `DrillAnimation.path`（72 条里仅 5 条试点物理烘焙，其余 67 条仍是手画贝塞尔）。修复：轨迹来源前移到 `ShotPredictor`——新增 `DrillShotResolver`（Drill→`ShotInput`，优先 `shotIntent` 否则按摆球+选袋反推中等力度 3.3m/s 无塞）；`DrillThumbnailRenderer.render(drill:)` 画 `prediction.cuePath/objectPath` 真实折线（不可行退回手画）、**72/72 物理重烘焙**；详情页 `DrillSceneController` 后台 `predict` + `TrajectoryPlayback` 按真实模拟逐帧回放（与分离角页同源，含减速/吃库/走位）。`make build` ✅、lint 0、烘焙 72/72 ✅（c001 直线进底中袋、c040 切球分离+目标进右底袋几何自洽）。遗留：67 条无 `shotIntent` 用默认力度反推＝真物理但非原走位意图，补 `shotIntent` 即精确还原。
- **动作库 2D 球桌 → USDZ 真台 2D 顶视那套 — ✅（2026-06-04，DR-016，取代 DR-015）**：用户"不要用这种，要用角度页面里的 2D 视角的 usdz 球桌那一套"。改用 `AngleTrainingScene`（`TaiQiuZhuo.usdz` 真台 + plain 光照）正交顶视真渲染。**缩略图离线烘焙 PNG**：新增 `DrillThumbnailRenderer`（`SCNRenderer` 离屏快照）+ `DrillThumbnailBakeRunnerTests` 烘焙 **72/72** → `Resources/DrillThumbnails/<id>.png`；运行时 `BTBakedDrillTable`+`DrillThumbnailStore`(NSCache) 秒加载、零 SceneKit 成本（不能把 N 个 USDZ 场景塞进滚动网格）。**详情页 live 场景**：`DrillSceneView`+`DrillSceneController` 复用 `AngleSceneView` 顶视 + 摆球 + 烘焙轨迹 + 回放走位。记录页改轻量烘焙图。删除 `BTDrillTableView.swift`、移除 `BTBilliardTable` 视图（仅留 `TableRender`）。`patch-pbxproj-folder-refs.py` 加 `DrillThumbnails` folder ref。`make build` ✅、lint 0、`testDrillLibraryOnly` 截图确认（网格烘焙 PNG + 详情 live USDZ 2D 顶视）。
- **动作库 2D 球桌渲染统一 — ✅（2026-06-04，SwiftUI Developer，DR-015）**：用户反馈"我没看到动作库里改了哪里 / 废弃 BTMiniTable，用现在真实的 2D 球桌"。新建统一拟真渲染器 `BTDrillTableView`（`BTAimTableView` feltOnly 拟真台呢 + `BTRealisticBall` 高光球 + 烘焙/手画轨迹虚线 + 袋口标记 + 目标袋光环），**双模式**：`animationProgress=nil` 静态缩略图（球停起点+全画轨迹）/ `!=nil` 动画回放（轨迹逐段+球随相位移动）。删除 `BTMiniTable.swift`；`BTBilliardTable` 退化为薄封装委托新组件（保留 `animationProgress` API + `TableRender` 常量供 `BTAngleTestTable`）。替换网格卡/`BTDrillThumbnail`/计划迷你台/详情页/记录页共 5 处；去掉 `BTDrillCard` 的 `BTDrillPreviewPlayer` PNG 帧短路（此前 c005 烘焙轨迹被旧 PNG 盖住）。`make build` ✅、lint 0、新增 `testDrillLibraryOnly` UI 截图测试通过（网格+详情拟真渲染确认）。
- **P10 Track A — 动作库内容管线 + 击球意图 schema 雏形 ✅（2026-06-04，iOS Architect，ADR-P10-01）**：探针绿灯后把引擎"用起来"的第一步。设计 Drill「击球意图」schema（归一化摆球+选袋+**连续 velocity(m/s)**+塞，用户改连续值以支持精准走位）→ 离线烘焙（`ShotBaker` 调 `ShotPredictor`+USDZ 对齐球桌 `chineseEightBallQiuJi`，把精确轨迹**回填**现有 `DrillAnimation`，渲染层零改动）→ 物理可达校验报告对接 H-11。新增 `ShotIntent.swift`/`ShotBaker.swift`/`DrillBakeRunnerTests.swift`；`DrillContent.shotIntent?` + `DrillAnimation.source/generator` 均为**可选**（旧 72 条零回归）。5 条多类别试点（c001 直线 / c002 斜角 / c005 一库走位 / c014 定杆 / c024 分离角）烘焙 **5/5 feasible** 并 round-trip 回填（`source:"baked"`）；`QiuJiTests` **203/203**、lint 0、JSON 校验通过。命中 ADR 触发（内容/数据策略 + 引擎抽成离线管线=跨模块边界）→ ADR-P10-01 已采纳。报告 `tasks/qa-reports/DRILL-BAKE-REPORT.md`；schema.md + content-engineering SKILL 同步（PD-008）。遗留：c002 真实模拟未落袋（4.2° 贴 jaw，属 P10 jaw↔洞标定，不阻断显示）。
- **2D 物理引擎探针 — 🟢 绿灯（2026-06-04）**：为"物理升级（动作库 GIF/精讲/视频统一由引擎驱动 + 暑假 Tier 1 上线）"做 go/no-go 探针。新建 `QiuJiTests/PhysicsBenchmarkTests.swift`（14 项体检：A 击打/B 球-球/C 库边/D 走位/E 进袋，带 Dr.Dave/Alciatore 参考 band）。**核心物理 A/B/C/D 全健康**；**根因坐实在几何**：双真源（CAD 模拟 vs USDZ 标记差 ~17mm）靠 `ShotPredictor` 60mm 容差糊合。修复：抽共享 `TableGeometry.chineseEightBallCushions(y:)`，给 `chineseEightBallQiuJi` 补齐 jaw 圆弧（v1 无→v2 全），`ShotPredictor` 改用它 + **删 60mm 容差改按 pocketId 精确判进袋** + 加只读 `simObjectPotted`。**产品路径 E-solver 修后 5/5 诚实进袋**；回归 `QiuJiTests` **278/278**。遗留 1 项 **P10 标定**：jaw 圆弧仍取 CAD 坐标、与 USDZ 洞心残留 ~17mm 错位 → 朴素瞄准贴角球 rattle（产品用求解器规避，不阻断）。报告 `tasks/qa-reports/PHYSICS-PROBE.md`。**结论**：探针绿灯，可推进物理升级；P10（jaw↔洞对齐 / 目标球真实轨迹 / 真实视频标定常量）排在绿灯之后。
- **整体进度**：9 / 11 Phases 完成（R0 ✅ | P2 ✅ 附条件 | P4 ✅ 附条件 | P5 ✅ | P6 ✅ | P7 ✅ | R-UI ✅ 附条件 | R1 ✅ | P9 ✅）+ P8 🔄
- **UI 设计交付物**：44/44 任务完成，40 帧 Light + 5 帧 Dark + 3 份标注已就绪（见 `ui_design/final-report.md`）
- **最近 UI 审查 + 修复**：2026-05-29 全 App 浅色巡游审查（`tasks/ui-reviews/UR-20260529-FullApp-Light.md`）发现 9 项（P1×4 / P2×5），**同日已修复并回归 U-01~U-07**（7 项代码问题，FL-011~014 标 ✅），剩 U-08（视频/数据导出占位）/U-09（图标）为内容/设计轨道。关键修复：角度台呢荧光绿（根因＝`enhanceClothMaterials` 的 multiply 守卫漏掉 USDZ NSURL 贴图，改为无条件着色 + plain 专用暗化 tint + 光照/曝光下调）、计划详情期号标签与状态栏重叠、日历空状态被 Tab 栏遮挡、Paywall 无限 loading（加 8s 超时兜底）、错别字「浅淡球感」、动作详情顶栏穿透。**下一步**：角度交互态（`现有问题.md`：小角度文字挤压/左下 HUD 上移常驻/自动选袋 85°）仍需动态复检。
  - 新增巡游工具：`QiuJiUITests/ScreenshotTourUITests.swift` + 专用 scheme `QiuJiUITour`（仅构建 App+UITests，绕开 QiuJiTests 的 TEST_HOST 误配 QiuJi.app↔球迹.app）。
- **QA-P9 收尾 + 测试基建修复（2026-06-02，QA Reviewer）**：用户确认 P9 人工功能验收通过，遂闭环 AI 侧验收。逐条代码复核发现 2 项缺口并当场修复：① **FL-016** 几何角度训练 `GeometricAngleQuizView` 只计数不阻断 Freemium（Scene 页已生效、几何页漏），按既有范式补「今日剩余 N + 限额卡 + 解锁入口 + 按钮禁用」；② 补 `AngleSceneCalculator` 往返 XCTest（T-P9-02 DoD，精度<0.001，6 条全过）。另发现对照表「球种切换」与 **P9-05 设计 APPROVED（移除球种切换、固定中八）冲突** → 撤销我误加的切换、回归设计（仅保留曲线标记点 `.red→.btAccent` token 合规）。**PD-007**：修复让整套 `QiuJiTests` 命令行从未跑通的根因——`TEST_HOST` 指向 `QiuJi.app` 而产物是 `球迹.app` + 缺 `PRODUCT_MODULE_NAME` 致 `@testable import QiuJi` 失败；在 `project.yml`+`pbxproj` 双向钉死后 **241/241 全通过**。交付物：`tasks/qa-reports/QA-P9.md`、`ui_design/tasks/P9-REVIEW/consistency-review.md`、`09-UI设计交付文档.md` §3.3 补齐。`make build` 通过、lint 0。**P9 归档，整体 9/11 Phase；主线仅剩 P8 人工事项（H-17 / TestFlight / App Store）。**
- **图标系统优化（2026-06-01，UI Reviewer + SwiftUI Developer）**：用户反馈"图标乱/丑、Logo 不动"。专项审查 `tasks/ui-reviews/UR-20260601-IconSystem.md`（6 项：P1×3/P2×3），分两阶段修复并截图回归。**阶段 A**：新增统一 `BTIconBadge`（淡色圆底+单色图形），Profile 列表彩虹圆底（红/蓝/紫/灰）→ 收口品牌绿（仅订阅留金）；空状态举杠铃健身小人→品牌 `BTLogoMark`、锤子→训练计划语义图标。**阶段 B**：`BTDrillCategoryIcon` 整体重写为统一系统（双线宽+标准球半径+单一金色强调，8 分类构图统一），`BTTrainingIcon` 加重对齐 SF Symbol。**关键 bug**：drawFundamentals `r = env.ballRadius * s * 1.4` 重复乘 scale（env.ballRadius 已含 s）→「基础功」爆框成橙方块，登记 **FL-015**。`make build` 通过、巡游 0 失败、`screenshot-v4/` 26 帧刷新、lint 0。剩余 backlog（非阻塞）：~180 处裸 `systemName` 增量迁移到 `BTIcon`（U-I05/06）。
- **翻袋/反射解球器「真实反射模式」（2026-06-03，iOS Architect + SwiftUI Developer，ADR-P9-02）**：用户要求在原「入射角=反射角」理想模型外，增加真实模式（反射角相对法线略小于入射角）+ 两个控件（理想/真实开关 + 缩小因子滑块 0.50–1.00），让用户几次试打拟合自己的球台/发力。**物理模型**：碰库时法向分量翻转、切向分量×factor（`tan θ_out = factor·tan θ_in`，factor=1 即理想）。**算法**：镜像展开仅 factor=1 成立 → 新建共享 `Features/AngleTraining/ReflectionSolverCore.swift`（`CushionReflectionSolver`：正向射线追迹 + 射击法扫描发射角→变号区间→二分求根 + 每次反弹校验命中库），并提供 `CushionReflectionSettings`（UserDefaults，两页共享 factor/模式）。**混合策略**：`factor=1` 两个求解器沿用原镜像展开（零回归）；`factor<1` 对每条理想解库序射击得真实解，理想解作蓝色虚线对照。改动：`BankShotCalculator`/`DiamondSystemCalculator.solveAll` 加 `factor` 参数 + `Solution` 加理想对照路径；两页 VM/View 接入 `ReflectionModeControl`（分段开关+滑块）+ 双路线绘制；`AngleTrainingScene` 加 `addDashedLine`。**测试**：新增 `CushionReflectionTests`（反射缩放/单库等价镜像/真实模式发散随因子单调），`make build` 通过、`QiuJiTests` **256/256** 全通、lint 0。
- **「分离角与走位」进袋几何切换（2026-06-03）**：用户反馈"目标球还是进不了袋"并指向项目一的进袋判定/袋口参数。诊断：进袋判定（EventDrivenEngine + enforceTableBounds）本就是项目一移植件、与项目一一致；差距在**球台几何**——我初版用简化"6 直库+6 圆袋无 jaw"，球易擦过窄捕获窗(13mm)进不去。改为 `ShotPredictor` 直接用项目一完整 `TableGeometry.chineseEightBall()`（**角袋 jaw 圆弧 + jaw 直线段 + 中袋圆角 + CAD 袋口**，喇叭口导球入袋）。进选定袋判定：以 `AngleSceneCalculator` 袋口中心（=屏幕标记）为目标 + 最近距离 60mm 阈值甄别（两套中心差 ~17mm）。新增单测 `easyCornerPot`/`defaultLayoutPots` 验证近距小角度 & 默认球形开箱即进，`PhysicsEngineTests` **12/12**。**仍存**：极薄+远袋因能量不足到不了袋（物理事实，提示"此角度/力度难进袋"）；落袋点在 CAD 中心、与标记盘差 ~17mm（在盘内，可接受）。
- **「分离角与走位」页 UX/性能修复轮（2026-06-03，SwiftUI Developer）**：用户真机反馈四点并修复——①**播放卡顿**根因＝`recompute()` 把闭环求解(~26 次模拟)放主线程同步跑，遇加塞乱飞球单次模拟可达数百 ms → 累积卡死；改为**后台串行队列预测 + 代次(generation)守卫丢弃过期结果**，主线程只画线，UI 不再卡。②**播放结束复位**：`finishPlayback` 把两球复位到击球前位置（进袋球重新加回场景+恢复 opacity）并**瞬时重画原轨迹**（不重新求解）。③**"力度不足"误导**（力度 90 仍提示不足）：实为薄球+远袋能量不足，文案改为"此角度/力度难进袋，试试加大力度或换袋口"。④**UI 重做**：顶部结果卡（分离角大字+状态+后台计算转圈）、底部控制卡（打点盘带"击球点"标签+径向高光、力度滑杆+高低/左右塞量读数、重置+播放双按钮）。另默认摆一个清晰可进的中等角度球。播放速度 1.4×。`make build` 通过、`PhysicsEngineTests` 10/10。**注**：仍未本地真机复测此轮 UI（用户侧验证）。
- **「分离角与走位」物理演示页 + pooltool 物理引擎移植（2026-06-03，iOS Architect + SwiftUI Developer，ADR-P9-03）**：用户要求角度页新增「分离角 + 母球/目标球轨迹」动态演示，可调击打袋口/力度/上下左右塞——现有都是纯几何模型（无旋转/力度/库边/throw），故**完整移植项目一(`01.billiard_app`)的事件驱动物理引擎**（即 **pooltool** 的 Swift 移植）到 `QiuJi/Core/Physics/`（15 文件：`EventDrivenEngine`/`AnalyticalMotion`/`CollisionResolver`/`CushionCollisionModel`/`CueBallStrike`/`CollisionDetector`/`QuarticSolver`/`TrajectoryRecorder`/`TrajectoryPlayback`/`SimulationWorker`/`TableGeometry`/`BallMotionState`/`BTPhysicsConstants`/`SCNVector3+Physics`/`PerformanceProfiler`）。**以 pooltool 为准校正**（用户明确要求）：①`CueBallStrike` 修复角速度偏大 ~35×（缺 R 因子）的 bug + 帧/符号，重写为 pooltool z-up 求解后映射到 SceneKit y-up；②`resolveBallBallPure` 弃用自写冲量、改用 pooltool `_resolve_ball_ball`（滑移 `u_b·|Δvₙ|·(−v̂)` + 无滑移 1/7、5/14 + Alciatore 摩擦曲线）；③Mathavan 库边逐式核对一致；④常量全对齐 pooltool 默认值。新建 `TableGeometry.chineseEightBallQiuJi`（袋口/库段取自 `AngleSceneCalculator`，对齐 USDZ，v1 仅 6 直库+6 圆袋，暂无角袋 jaw 圆弧）；门面 `ShotPredictor`（摆球+袋口+力度+塞→两球轨迹/分离角/切线/进袋，轨迹用 `TrajectoryPlayback` 解析采样捕捉塞曲线）；**进袋逻辑**：选定袋口先过可行性闸门（切球角≥89°/母球挡路→「当前角度无法进袋」不画轨迹），几何可进则用**闭环瞄准求解**（粗扫±8°+细化±1°，每候选短时模拟评分）找到真正落袋的发射方向——一次性纳入 squirt+碰撞 throw+swerve（开环只补 squirt 在加塞时仍漏袋），单次 predict ~30–40ms；`ShotSimulationViewModel`/`ShotSimulationView`（复用 `AngleSceneView` 拖球+点袋、力度滑杆+打点盘，实时画轨迹，「播放」用 `recorder.action` 让球沿轨迹跑+进袋淡出+复位）。接线 `AngleRoute.shotSimulation`（角度页「进阶」）。去重 `CameraRig` 的 file-private `SCNVector3` 扩展避免歧义。新增 `QiuJiTests/PhysicsEngineTests.swift`（90°法则/高低杆/squirt/端到端，8 例全过）。`make build` 通过。**后续 TODO**：角袋 jaw 圆弧、力度标定、真机 UI 截图验证（本轮仅编译+单测）。
- **角度训练视觉拟真化（2026-06-01，SwiftUI Developer）**：新增可复用 `Core/Components/BTRealisticBall.swift`（拟真球：球面明暗+高光+接触阴影，矢量无版权风险）与 `BTAimTableView.swift`（拟真 2D 台面插图：木纹库边/皮革袋口/颗星/台呢光影，暴露台呢矩形供叠加）。改造 `AimingPrincipleView` / `BallFeelView`（学习文档插图）与 `GeometricAngleQuizView`（几何角度训练页）。**修正**：用户反馈拟真"球桌"装饰（木纹库边/袋口/颗星）显廉价且抢焦点、不如之前简洁——已改为干净路线：`BTAimTableView` 统一 `feltOnly`（近平台呢）+ 新增 `BTPocketMark`（干净袋口点）+ 加粗瞄准线/角度弧 + 几何页黄色扇形高亮夹角，让"角度/线/假想球"成为主角，保留有质感的球。新增轻量 `testAngleLearningPages` 仅截角度三页（完整巡游在本机偶发模拟器 server died，已规避）。`make build` 通过，回归截图 build/v2-09/11/12。注：`make xcodegen` 会清掉自建 `QiuJiUITour.xcscheme`，已用确定性 blueprint id 原样重建。

---

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
