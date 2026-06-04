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

- **当前 Phase**：**P10 物理升级**（Track A 内容管线雏形 ✅ 2026-06-04，ADR-P10-01；**Track B-1 物理保真进球管线 ✅ 2026-06-04，ADR-P10-02**；Track B #3 常量标定需真实视频待办）+ **P9** ✅（2026-06-02）+ **P8** 🔄（仅剩人工：H-17 / TestFlight / App Store）
- **当前激活角色**：iOS Architect（物理几何标定 + 进球点算法 + ADR）
- **P10 Track B-1 — 物理保真进球管线 ✅（2026-06-04，iOS Architect，ADR-P10-02）**：聚焦用户要的"完整、物理保真的进球点/进球判定算法"。用**程序化 USDZ 网格实测**（`TableGeometryProbeTests`，用户选定测量法）**证伪探针的「jaw 放错 17mm」预设**——库边（±0.635/±1.27）、袋心、jaw（与库边精确相切）实测皆自洽，几何无需重导。真正问题＝旧引擎**袋口只是袋心一个判定圆**（13.4mm 甜点 / 后改 0.055 仍是放大的圈），无真实袋口内部结构，球要么命中甜点要么穿库飞出；闭环求解又在窄口偶落坏局部最优。**用户复评后明确反对"放宽捕获半径"为偷懒、要真实袋口物理。修复**：(a) **真实袋口物理 = 喉腔模型**（`TableGeometry.chineseEightBallQiuJi` + `throatCushions`）：每袋口 = jaw 库（偏转切球）+ **喉腔**（实测 jaw 尖端 `pocketJaws` 沿喉轴挤出的两条侧壁 + 一道后壁，可反弹）+ 喉腔内**物理落袋孔** P（`pocketDropRadius`，球心进孔即落袋）；rattle 由几何自然涌现（穿库飞出 8%→2.7%），落袋孔半径仅表物理洞口、与视觉标记半径解耦。(b) **两逻辑分清**：(A) 袋口判定＝球来时由喉腔真实几何决定进/rattle；(B) 瞄准求解 `solveAimOffset` 固定力度+塞采样寻优最优接触点、在 A 下让目标球落袋（直接/借 jaw），打不进如实报。(c) 稳健化求解（进选定袋优先 −10 基线 + scratch 仅 mm 量级轻罚〔禁 1.0 大值〕 + 粗扫加密 ±16°/0.5° 两级细化）。(d) **画面=物理**：`ShotPredictor.objectPath` 取真实模拟折线（含穿喉腔反弹）、`objectPocketed/simObjectPotted` 改**轨迹基**判定（消除穿库假阳性），`ShotSimulationViewModel` 诚实显示进/未进。**结果**：E-solver 角袋 cut0–45 全力度进、cut55（薄）个别力度敏感、中袋全力度进、c002 由 ⚠️ 转 ✅、5 条试点 Drill 真实模拟 5/5。`QiuJiTests` **291/291**、`make build` 通过、lint 0。新增 `QiuJiTests/TableGeometryProbeTests.swift`（USDZ 实测+进球覆盖诊断）+ `PhysicsEngineTests` 3 条保真断言；报告 `PHYSICS-PROBE.md` §USDZ 实测标定、`DRILL-BAKE-REPORT.md`（c002→✅）。**遗留非阻塞**：中袋 jaw mouth ±0.035→实测 ±0.046；朴素瞄准 E-geom 3/5（窄喉口掠角 rattle 真实物理，求解器规避）；Track B #3 常量标定需真实俯拍视频。
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

- **✅ 动作库内容管线 + 击球意图 schema 雏形（2026-06-04 完成）**：见上方 P10 Track A 条目 + `tasks/phases/P10-physics-content-pipeline.md`（ADR-P10-01）。**下一步（扩面，非雏形）**：① 把 `shotIntent` 推广到全量 72 条 Drill（逐批烘焙+H-11 核查）；② 废弃 `BTDrillPreviewPlayer` 的 PNG 帧序列、动画统一由烘焙轨迹驱动；③ 展示三件套（GIF 烘焙轨迹 / 精讲参数化对错对比 / 视频降级为真人身体动作）统一重构；④ 多杆球（`obstacles`/多 shot）烘焙支持。
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
