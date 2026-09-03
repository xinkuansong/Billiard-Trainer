# FAILURE LOG

> 记录所有返工/回退/QA 失败条目。格式：FL-NNN（三位数字递增）。
> 每条写入后须按 `00-orchestrator.mdc §⚡实施知识回写` 同步至对应规则文件。

---

## FL-001
- **任务**：QA-P2（人工测试）
- **现象**：Apple 登录请求 URL 为 `http://auth/login-apple`（API_BASE_URL 未正确注入），后端不可达
- **严重程度**：P1
- **关联检查项**：TP-P2 流程8-①
- **根因**：xcconfig 中 `//` 被当作注释，`http://106.54.3.210:3000` 被截断为 `http:`；`URL(string: "http:").appendingPathComponent("/auth/login-apple")` 产生畸形 URL
- **解决**：✅ 使用 `$()` 空变量打断双斜杠：`API_BASE_URL = http:/$()/106.54.3.210:3000`；构建后 Info.plist 验证正确
- **日期**：2026-04-10
- **规则改进建议**：xcconfig 中含 `://` 的 URL 值必须使用 `$()` 打断双斜杠（`http:/$()/...`），否则后半段被丢弃
- **已应用至**：✅ `60-devops-release.mdc` § 经验教训 / FL-001（2026-04-10）

## FL-002
- **任务**：QA-P2（人工测试）
- **现象**：Sign in with Apple 登录成功后未弹出数据迁移 Alert
- **严重程度**：P2
- **关联检查项**：TP-P2 流程6-⑤
- **根因**：(1) `AuthState.login()` 中 `wasAnonymous` 仅检查 `provider == .anonymous`，但首次用户 `currentUser` 为 `nil`，条件不满足；(2) `LoginView` 在 `authState.login()` 后立即 `dismiss()`，Sheet 动画中 ProfileView 无法弹 Alert
- **解决**：✅ 条件改为 `!isLoggedIn`（覆盖 nil 和 anonymous）；新增 `pendingMigration` 标志，在 Sheet `onDismiss` 回调中触发 Alert
- **日期**：2026-04-10
- **规则改进建议**：Sheet 中修改全局状态后需 Alert 时，应通过 pending 标志 + onDismiss 延迟触发，避免 SwiftUI 动画冲突
- **已应用至**：✅ `20-swiftui-developer.mdc` § 经验教训 / FL-002（2026-04-10）

## FL-003
- **任务**：QA-P3（人工测试 TP-P3）
- **现象**：付费 Drill（L2+）详情页中，训练要点（coachingPoints）内容对匿名/免费用户完整可见，`BTPremiumLock` 渐进遮罩未生效
- **严重程度**：P1（Freemium 核心付费墙失效，影响商业化）
- **关联检查项**：V-18、流程5-a
- **根因**：`BTPremiumLock.progressiveLock` 直接渲染 `content()`，`visibleItems` 参数完全未使用，无任何模糊/渐变遮罩
- **解决**：✅ 添加 `LinearGradient` mask（顶部 0%→25% 完整可见，65% 渐隐至透明）+ `allowsHitTesting(false)`（2026-04-11）
- **日期**：2026-04-11
- **规则改进建议**：Freemium 付费墙组件挂载须在 QA 阶段以匿名用户 + 免费状态专项验证，不能仅依赖代码审查
- **已应用至**：待路由

## FL-004
- **任务**：QA-P3（人工测试 TP-P3）
- **现象**：搜索「直线」时，全名不包含「直线」的 Drill 也出现在搜索结果中，且排在包含「直线」的结果前面
- **严重程度**：P2（搜索体验受损，用户无法准确找到目标 Drill）
- **关联检查项**：流程2-a
- **根因**：`applyFilters()` 搜索条件匹配了 `description` 字段，导致名字不含关键词但描述含关键词的 Drill 混入结果
- **解决**：✅ 移除 `$0.description.lowercased().contains(query)` 匹配，仅搜索 `nameZh` + `nameEn`（2026-04-11）
- **日期**：2026-04-11
- **规则改进建议**：搜索过滤须限定字段范围（`name` 优先），并在测试时验证结果集中无额外字段的误匹配
- **已应用至**：待路由

## FL-005
- **任务**：QA-P3（人工测试 TP-P3）
- **现象**：球种筛选 Chip「全部」始终处于选中（深色）状态，切换到「中式台球」或「9球」后无法通过点击「全部」恢复至全量列表；「全部」点击无响应
- **严重程度**：P2（筛选功能异常，用户无法重置球种筛选）
- **关联检查项**：流程3-c
- **根因**：`BallTypeFilter.allCases` 包含 4 个 case（含 `.universal = "通用"`），但规格要求只展示 3 个；多余的「通用」Chip 导致视觉混乱；Chip 切换无动画反馈使状态变化不明显
- **解决**：✅ 新增 `displayCases: [.all, .chinese8, .nineBall]` 仅展示 3 个 Chip；`withAnimation(.easeInOut)` 切换选中态（2026-04-11）
- **日期**：2026-04-11
- **规则改进建议**：筛选重置路径（选中态 → 全部）须作为独立检查项纳入 QA；展示用的 case 与逻辑用的 allCases 应分离
- **已应用至**：待路由

## FL-006
- **任务**：QA-P4（人工测试 TP-P4）
- **现象**：DrillRecordView 训练记录界面无成功率实时显示（缺少百分比数字和进度条）
- **严重程度**：P1
- **关联检查项**：V-16, Flow1-④
- **根因**：DrillRecordView 仅在 completedBanner（全部组完成后）显示成功率，训练过程中无实时反馈
- **解决**：✅ 新增 `successRateSection`：大字号百分比 + ProgressView 进度条 + 进球/目标统计，受 `showSuccessRate` 开关控制（2026-04-11）
- **日期**：2026-04-11
- **规则改进建议**：成功率实时反馈是训练核心指标，应作为 DrillRecordView 的必需 UI 元素加入 DoD
- **已应用至**：✅ DrillRecordView.swift successRateSection（2026-04-11）

## FL-007
- **任务**：QA-P4（人工测试 TP-P4）
- **现象**：一组训练结束后无休息倒计时弹出；缺少组间休息功能（休息时间设置 + 锁屏后显示倒计时）
- **严重程度**：P1（训练核心体验缺失，组间休息是实际训练刚需）
- **关联检查项**：TP-P4 新发现
- **根因**：ViewModel 已有 `startRestTimer()` 逻辑，但 UI 仅在顶栏用小字展示剩余秒数，无明显视觉反馈
- **解决**：✅ 新增 `restCountdownOverlay`：全屏半透明遮罩 + 圆环倒计时动画 + 大字号秒数 + 跳过/+30s 按钮 + 快速切换休息时长（30/45/60/90s）+ 倒计时结束触觉反馈 + 屏幕常亮（2026-04-11）
- **日期**：2026-04-11
- **规则改进建议**：组间休息是训练记录的核心交互环节，应作为 T-P4-05（Drill 记录界面）DoD 必需项
- **已应用至**：✅ ActiveTrainingView.swift restCountdownOverlay + ActiveTrainingViewModel.swift addRestTime/onRestComplete（2026-04-11）

## FL-008
- **任务**：QA-P4（人工测试 TP-P4）
- **现象**：CustomPlanBuilderView 中 Drill 行拖拽手柄不生效，迷你球台缩略图缺失（Light + Dark 均不可见）
- **严重程度**：P2
- **关联检查项**：V-24, D-11
- **根因**：(1) VStack + ForEach 不支持 `.onMove`，手柄仅为视觉图标；(2) 缩略图实际存在但使用静态绘制
- **解决**：✅ 改用 `List` + `ForEach` + `.onMove` + `editMode(.active)` 启用系统原生拖拽手柄；缩略图保留（2026-04-11）
- **日期**：2026-04-11
- **规则改进建议**：拖拽排序功能需在实现时同步验证 onMove 回调；缩略图组件集成须有视觉验收截图
- **已应用至**：✅ CustomPlanBuilderView.swift drillListSection（2026-04-11）

## FL-009
- **任务**：QA-P4（人工测试 TP-P4）
- **现象**：训练中 App 进入后台时计时器暂停，返回前台后才继续计时；训练数据不丢失
- **严重程度**：P3
- **关联检查项**：E-06
- **根因**：Timer 基于 `Timer.scheduledTimer` 或 SwiftUI `.onReceive`，App 进入后台后 RunLoop 暂停导致计时停止
- **解决**：⏳ 待评估（可记录 `backgroundDate` 在 `scenePhase` 变化时补偿差值；或接受当前行为作为 V1 已知限制）
- **日期**：2026-04-11
- **规则改进建议**：计时器类功能需考虑后台场景，使用 `Date` 差值而非累加间隔
- **已应用至**：⏳ 待回写

## FL-010
- **任务**：导入 ShootersPool 录屏到 App Bundle（动作库视频）
- **现象**：直接运行 `xcodegen generate` 后启动 App，动作库列表为空；`Bundle.main.url(forResource:withExtension:subdirectory:)` 全部返回 nil
- **严重程度**：P0（App 核心功能不可用）
- **关联检查项**：DrillContentService.loadFallbackDrills、Resources/Drills/index.json
- **根因**：`project.yml` 里 `Resources/{Drills,Plans,Videos}` 用 `type: folder` 声明，但 xcodegen 2.45.3 **不会**为这些 `type: folder` 的 resources 生成 Xcode 蓝色 folder reference。pbxproj 中只有同名 file reference（或干脆缺失），导致打包后 .app 根目录下没有 `Drills/`、`Plans/`、`Videos/` 子目录，Bundle 无法解析子目录路径。HEAD 上的 pbxproj 是被前人手工补过 folder ref 的，运行 `xcodegen generate` 会立即抹掉。
- **解决**：✅ 新增 `scripts/patch-pbxproj-folder-refs.py`：xcodegen 跑完后注入三个 folder reference（lastKnownFileType = folder），同时把 build file 加进**主 app target** 的 `PBXResourcesBuildPhase`（注意区分 LiveActivity 扩展那个 Resources 阶段，用 `TaiQiuZhuo.usdz` 作为锚点）。`scripts/Makefile` 新增 `make xcodegen` 串联两步；`project.yml` 顶部加注释禁止裸跑 `xcodegen generate`（2026-05-25）
- **日期**：2026-05-25
- **规则改进建议**：~~xcodegen 中所有 `type: folder` 的 resources 必须配套后处理补丁；禁止裸跑 xcodegen generate~~ **（已被 FL-017 取代：改用 `sources: {type: folder, buildPhase: resources}` 原生生成 folder reference，无需补丁，可裸跑 xcodegen）**
- **已应用至**：~~`scripts/patch-pbxproj-folder-refs.py`~~（2026-06-04 已删除，见 FL-017）；当前方案见 FL-017

## FL-011
- **任务**：UI Review（全 App 浅色截图审查 UR-20260529）
- **现象**：角度 2D 瞄准 / 角度与打点页台呢呈高饱和荧光绿，与 3D 瞄准页（自然深绿）观感不一致
- **严重程度**：P1
- **关联页面**：角度 > 2D 瞄准训练 / 角度与打点
- **根因**：✅ 已定位。两层原因：(1) 2D/动态页走 plain 管线无 IBL/HDR tone-mapping，台呢（`TaiNi` 材质，烘焙贴图 `TaiNi_basecolor.png` 本身即高饱和 #36991F）直接显荧光；(2) **关键 bug**：`MaterialFactory.enhanceClothMaterials` 的 multiply 着色被一个 `if diffuse is UIColor || image != nil` 守卫包裹，而 USDZ 台呢 diffuse 是 `NSURL` 贴图 → 守卫为假 → multiply 从未应用（plain 与 studio 皆然，studio 仅靠光照/tone-mapping 补救）。
- **解决**：✅ 已修复（2026-05-29）。① 移除 multiply 守卫，cloth 材质无条件应用 multiply tint（写入即替换，幂等）；② 新增 `clothMultiplyPlain`(0.46,0.62,0.46) / `clothMultiplyStudio`(0.90,0.93,0.90)，plain 管线用更强的暗化去饱和 tint，studio 保持轻度；③ `isClothMaterial` 增加按 diffuse 贴图路径名（taini/cloth/felt…）识别；④ plain 光照下调（ambient 1000→450、directional 1400→820、fill 500→200）、相机 `exposureOffset -0.15→-0.45`。重跑截图：2D/动态台呢已为自然深绿，3D 仍正常。
- **日期**：2026-05-29
- **规则改进建议**：SceneKit USDZ 贴图材质的 diffuse 多为 `NSURL`，对其做着色/识别不能只判断 `UIColor`/`UIImage`；同一模型跨页面须保证光照/曝光/材质增强一致并截图比对。
- **已应用至**：✅ `MaterialFactory.swift` + `AngleTrainingScene.swift`（2026-05-29）；待回写 `20-swiftui-developer.mdc` § 经验教训

## FL-012
- **任务**：UI Review（全 App 浅色截图审查 UR-20260529）
- **现象**：计划详情顶部大号「01/第1期」标题与返回键与系统状态栏时钟重叠，hero 头部未尊重 Safe Area top inset
- **严重程度**：P1
- **关联页面**：训练 > 计划详情
- **根因**：✅ 全屏 hero（`.ignoresSafeArea(.top)`）下 `BTPlanCover` 左上「期号」标签落在状态栏区域；动态安全区 inset 在透明导航栏下解析为 0 不可靠。
- **解决**：✅ 已修复（2026-05-29）。`BTPlanCover` 增加 `showIssueLabel`，详情页 Hero 传 `false` 隐藏该装饰性期号标签（详情页本就有系列名+名称+副标题，期号冗余），彻底避免与状态栏/返回键重叠。
- **日期**：2026-05-29
- **规则改进建议**：全屏 hero 头部页面必须验证 Safe Area top inset，标题/返回键不得与状态栏重叠
- **已应用至**：✅ `BTPlanCover.swift` + `PlanDetailView.swift`（2026-05-29）

## FL-013
- **任务**：UI Review（全 App 浅色截图审查 UR-20260529）
- **现象**：记录-日历空状态文案（「去开始第一次练球吧」等）渲染在日历卡片/Tab 栏后方，与悬浮按钮、Tab 栏叠加，呈层级错乱
- **严重程度**：P1
- **关联页面**：记录 > 历史（日历）
- **根因**：✅ 空状态用了整屏 `BTEmptyState`（`frame(maxHeight:.infinity)` + 48pt padding），内嵌在长日历下方后其 CTA 落到半透明 Tab 栏之后；滚动底部 padding 不足。
- **解决**：✅ 已修复（2026-05-29）。改用紧凑内嵌空状态（图标+文案+文字按钮），并把 `historyContent` 底部 padding 提到 96 预留 Tab 栏高度。重跑截图：空状态居中显示在日历下方，不再被 Tab 栏遮挡。
- **日期**：2026-05-29
- **规则改进建议**：空状态提示须在内容层内并为底部 Tab 栏预留安全区；整屏 `BTEmptyState` 不应内嵌进 ScrollView 列表下方
- **已应用至**：✅ `HistoryCalendarView.swift`（2026-05-29）

## FL-014
- **任务**：UI Review（全 App 浅色截图审查 UR-20260529）
- **现象**：订阅 Paywall 价格区与购买 CTA 持续 loading 转圈（StoreKit 产品未加载），无超时/错误/重试兜底
- **严重程度**：P1（需结合真机/StoreKit 复检）
- **关联页面**：我的 > 解锁球迹 Pro
- **根因**：✅ `SubscriptionView` 已有错误/重试兜底 UI，但仅在 `!isLoading` 时显示；`SubscriptionManager.loadProducts()` 的 `Product.products` 在模拟器无 .storekit/无网络时长期挂起 → `isLoading` 永不归位 → 价格/CTA 永久转圈。
- **解决**：✅ 已修复（2026-05-29）。`loadProducts()` 用 `withThrowingTaskGroup` 给加载加 8s 超时；超时归入 `TimeoutError` → errorMessage「加载超时，请检查网络后重试」+ 既有「重试」按钮。重跑截图：8s 后转圈被替换为错误文案+重试，CTA 恢复「立即订阅」。
- **日期**：2026-05-29
- **规则改进建议**：付费 paywall 的产品加载须有超时 + 失败重试，不得停留在无限 loading；StoreKit `Product.products` 必须包超时
- **已应用至**：✅ `SubscriptionManager.swift`（2026-05-29）

## FL-015
- **任务**：UI Review（图标系统专项 UR-20260601）+ 阶段 A/B 修复
- **现象**：动作库「基础功」分类图标在侧栏选中态与 Section Header 渲染成一个实心橙（金）方块、看不到图形（其余 7 个分类正常）。另：Profile 列表图标彩虹圆底（红/蓝/紫/灰）色相失控、空状态用举杠铃健身小人/锤子等离题 SF Symbol。
- **严重程度**：P1
- **关联页面**：动作库（侧栏/Header）、我的（列表）、训练（空状态）
- **根因**：✅ 已定位。`BTDrillCategoryIcon.drawFundamentals` 写 `let r = env.ballRadius * s * 1.4`，而 `env.ballRadius` 在 `DrawEnv` 构造时**已是 `Tokens.ballRadius * s`**（含一次 scale）→ scale 被乘两次：s=22 时 r≈108px，母球与金色中心点远超 22px 画框、被裁成实心方块；金色中心点盖在最上层 → 整体呈橙方块。**只有 fundamentals 复现**，因其余 7 个分类直接用 `0.xx * s` 字面量、未触碰 `env.ballRadius`。Profile 彩虹与离题空状态为设计纪律缺失（无统一容器/配色收口）。
- **解决**：✅ 已修复（2026-06-01）。① 一行修复 `r = env.ballRadius * 1.4`；② 顺势把 `BTDrillCategoryIcon` 整体重写为统一系统（双线宽 + 标准 `ballR` + 单一金色强调）；③ 新增统一 `BTIconBadge`（淡色圆底 + 单色图形），Profile 收口到品牌绿、仅订阅保留金；④ 空状态换品牌 `BTLogoMark`/训练计划语义图标；⑤ `BTTrainingIcon` 加重对齐 SF Symbol。详见 UR-20260601-IconSystem 四/五节。
- **日期**：2026-06-01
- **规则改进建议**：① Canvas 绘制中凡"已含 scale 的派生量"（如 `env.ballRadius = token * s`）不得再乘 `s`，新增 draw 函数须复用 env 派生量、不混用裸 token×s 与 env 值；② 同一图标族强制共享线宽/半径 token，避免逐函数散落系数；③ 列表/入口图标统一走 `BTIconBadge`，颜色收口"品牌绿为主、金仅唯一强调"，禁止 system 彩色（红/蓝/紫）圆底；④ 空状态图标须符合台球语义，禁用 figure.*（健身）/hammer 等离题符号。
- **已应用至**：✅ `BTDrillCategoryIcon.swift` / `IconToken.swift`(BTIconBadge) / `ProfileView.swift` / `TrainingHomeView.swift` / `BTTrainingIcon.swift`（2026-06-01）；待回写 `20-swiftui-developer.mdc` 与 `57-ui-reviewer.mdc` § 经验教训

## FL-016
- **任务**：QA-P9 验收（角度功能扩展）— 代码侧逐条复核
- **现象**：几何角度训练页（`GeometricAngleQuizView` / `GeometricAngleViewModel`）注入了 `AngleUsageLimiter` 并在 `submitAnswer` 调 `recordQuestion()` 计数，但**没有任何 UI 阻断**：`submitAnswer`/`nextQuestion`/"生成随机角度" 均无 `isLimitReached` 守卫，免费用户可无限刷题，违反 T-P9-06 DoD「免费 20 题/天」与 `docs/08` Freemium 边界。SceneKit 角度预测页（`SceneAnglePredictionView`）则已正确阻断 → 两条同类训练路径行为不一致。
- **严重程度**：P1（商业化边界漏洞）
- **关联页面**：角度 > 几何角度训练
- **根因**：✅ 实现时只接了"计数"未接"阻断"；limiter 的 `isLimitReached` / `remainingToday` 在该 View 全文无引用。计数对，闸门缺。
- **解决**：✅ 已修复（2026-06-02）。对齐 `SceneAnglePredictionView` 既有范式：① 输入区显示「今日剩余 N 题」；② `limiter.isLimitReached` 时 body 改显 `limitReachedCard`（皇冠 + 文案 + 解锁按钮），结果区「下一题」替换为「解锁全部内容」；③ "生成随机角度" 按钮 `.disabled(isLimitReached)`；④ 新增 `.sheet` 弹 `SubscriptionView`。`make build` 通过；`AngleUsageLimiterTests` 7/7 通过。
- **日期**：2026-06-02
- **规则改进建议**：凡复用 `AngleUsageLimiter`（或任何 Freemium 限额器）的页面，"计数 `recordQuestion()`" 与 "阻断 `isLimitReached` 守卫 + 升级入口" 必须成对出现；新增同类训练页时以已生效页（`SceneAnglePredictionView`）为范式做对照清单，QA 须逐页核验闸门而非仅看计数。
- **已应用至**：✅ `GeometricAngleQuizView.swift`（2026-06-02）；待回写 `20-swiftui-developer.mdc` § 经验教训

## FL-017
- **任务**：动作库缩略图改 USDZ（DR-016）后，用户反馈「计划页面和动作库的内容都看不到了」
- **现象**：计划页 + 动作库列表内容全空（两页都靠 `Bundle.main` 读 `Drills/`、`Plans/` 子目录）。AI 自测（`make xcodegen` + 截图）一切正常，但用户侧空白。
- **严重程度**：P0（核心内容不可见）
- **关联检查项**：DrillContentService.loadFallbackDrills / Plans / DrillThumbnails folder reference
- **根因**：沿用 FL-010 的「xcodegen 后跑 `patch-pbxproj-folder-refs.py` 注入 folder ref」方案本身**脆弱**——任何一次裸跑 `xcodegen generate`（或在 Xcode 直接 build、或 AI/人忘记走 `make xcodegen`）都会把 folder ref 抹掉，导致 `Drills/Plans/Videos` 不进 bundle、内容全空。复现已确认：裸跑 `xcodegen generate` 后 pbxproj 中 `lastKnownFileType = folder; path = Drills` 计数为 0。
- **解决**：✅ 根治——把 `Resources/{Drills,Plans,Videos,DrillThumbnails}` 从 `resources:` 移到 `sources:` 下用 `type: folder` + `buildPhase: resources` 声明，xcodegen **原生**生成 folder reference（裸跑 `xcodegen generate` 即可，pbxproj 出现 `lastKnownFileType = folder; ... path = QiuJi/Resources/Drills` 且进主 app `PBXResourcesBuildPhase`）。**删除** `scripts/patch-pbxproj-folder-refs.py`，`make xcodegen` 去掉补丁步骤，`project.yml` 顶部告警改写。裸跑 `xcodegen generate` + clean build + 截图验证：计划页/动作库内容均正常显示。
- **日期**：2026-06-04
- **规则改进建议**：**推翻 FL-010 的「必须配后处理补丁 + 禁止裸跑 xcodegen」**。xcodegen 中需保留子目录结构的资源，一律用 `sources: { type: folder, buildPhase: resources }` 原生生成 folder reference，**不要**用 `resources: type: folder`（不被认）也不要事后 patch pbxproj。新增此类资源目录时同步加 `sources` folder 条目 + 主 glob 的 `excludes`。
- **已应用至**：✅ `project.yml`（sources folder refs）、`scripts/Makefile`（去补丁）、删除 `scripts/patch-pbxproj-folder-refs.py`（2026-06-04）；FL-010 规则标记为已被本条取代；待回写 `60-devops-release.mdc` § 经验教训

## FL-018
- **任务**：P10 Track B-2，用户反馈「分离角与走位」页母球**吃库后立即停下**（截图：吃库瞬间速度明显还很快却定格在库边）。
- **现象**：母球（或目标球）碰到库边的一瞬间整条轨迹被截断、球冻结在库线上，肉眼看上去「撞库即死」；原始物理其实仍在继续多次吃库、走位（rawDuration≈9s）。
- **严重程度**：P1（核心可视化失真，违背「画面=物理」）
- **关联页面**：分离角与走位（`ShotSimulationView` / `ShotPredictor`）；同源影响动作详情 live 台（`DrillSceneController`）。
- **根因**：✅ 已定位。`ShotPredictor.clampedRecorder` 的「穿库安全网」按**固定步长重采样的解析外推位置**判定是否飞出台面，容差仅 6mm。但 `TrajectoryPlayback` 在「撞库事件帧 → 下一帧」之间用事件帧速度做解析外推，而撞库事件帧仍带「朝向库」的入射速度（实测：t=1.266 记录帧 vel.z=+0.34 朝库，反弹后的负向速度要到下一帧 t=1.312 才出现）。于是相邻两帧之间的采样位置被外推到库线内侧 7~9mm（吃库越快冲得越远，v5.8 可达 >6cm），瞬时越过 6mm 容差 → 被误判为穿库 → 冻结在库边 + `allDone` 提前退出截断其后全部轨迹。诊断：`ShotScenarioRenderTests.test_diag_cushionFreeze_detail` 打印记录帧确证；60 场景扫描 5/60 在 v5.8 大力吃库时复现误冻结。
- **解决**：✅ 已修复（2026-06-05）。把「真飞出」判定从**重采样外推位置**改为**原始事件帧（物理真值）**：引擎吃库在库线处反弹并 `enforceTableBounds` 钳回，正常反弹的记录帧绝不越线，只有真飞出才会出现「记录帧本身越界 ≥6cm 且远离所有袋口嘴 14cm」。据此预扫每个球记录帧求首次飞出时刻；仅到该时刻才冻结+截断。事件帧之间的瞬时外推过冲改为**仅化妆性钳位**（球心拉回库线）但保持速度/运动态、不截断，球继续按真实轨迹运动。回归：`test_diag_cushionFreeze` 误冻结 0/60；`PhysicsEngineTests` 18/18 全过；`make build` 通过、lint 0。
- **日期**：2026-06-05
- **规则改进建议**：穿库/越界安全网必须基于**引擎记录帧的物理真位置**判定，禁止用回放重采样（事件帧间解析外推）的瞬时位置——后者在吃库接触帧会朝库外推、产生与速度成正比的假性越界。安全网应「冻结仅用于真飞出，瞬时过冲只钳位不截断」，且容差需大于最快吃库的接触外推量级。
- **已应用至**：✅ `QiuJi/Core/Physics/ShotPredictor.swift`（`clampedRecorder` 基于记录帧判定 + 化妆性钳位）、`QiuJiTests/ShotScenarioRenderTests.swift`（`test_diag_cushionFreeze` 回归守卫 0/60）（2026-06-05）；待回写 `10-ios-architect.mdc` § 经验教训

## FL-019
- **任务**：P10 Track B-2，用户反馈「分离角与走位」页**母球进袋（失误）判定错误**（截图：cut 9° 母球带塞走位弧线，状态栏报「母球进袋（失误）」，但白色母球轨迹明显擦过中袋嘴后继续走到台面中下部、根本没落进任何袋）。
- **现象**：状态栏「母球进袋（失误）」与画面不符——母球钳制轨迹（=所绘白线）最近只到某中袋心 54–65mm（> 捕获窗 50.4mm），从未真正落入漏斗，却被上报为进袋。
- **严重程度**：P1（进袋判定与画面不一致，违背「画面=物理」；误导用户、并污染求解器 scratch 评分）。
- **关联页面**：分离角与走位（`ShotSimulationView` / `ShotPredictor`）。
- **根因**：✅ 已定位。目标球进袋判定（`objectPocketed`）早已用**显示用钳制轨迹最近点**做一致性闸门（袋心 ±(dropRadius−R+4mm)），但**母球进袋 `cuePocketed` 直接取裸引擎信号 `run.cuePocketed`、无同源闸门**。母球带塞走位是曲线（squirt+swerve），而袋口 CCD 用「定加速度直线/抛物线」模型排程进袋事件——曲线母球被预测会进入漏斗(中袋 dropRadius−R=46.5mm)，实际只擦到 54–65mm；`EventDrivenEngine.resolvePocket` 的接受阈值又过宽（`pocket.radius + R*1.5`≈117.8mm 中袋），于是裸引擎仍判落袋 → 上报进袋但白线未到袋心。诊断：`ShotScenarioRenderTests.test_diag_cueScratch`（180 含塞场景扫描）抓到 11 例上报进袋中 **4 例假阳性**（钳制轨迹最近袋心 54–65mm > 窗 50.4mm），0 例「中袋吞快球」。
- **解决**：✅ 已修复（2026-06-05）。给 `cuePocketed` 加与目标球**同源的显示一致性闸门**：以裸引擎 `run.cuePocketed` 为权威，但要求母球**钳制轨迹**确实落入**某个袋**的捕获窗（落袋后引擎吸球心 → 最近点≈0；曲线擦袋未真正落入 → 最近点 >窗 → 判未进）。回归：`test_diag_cueScratch` 假阳性 4→**0**（上报进袋 11→6，余 6 为白线真到袋心的诚实 scratch）；`PhysicsEngineTests` 18/18 全过、lint 0。〔深层成因「resolvePocket 接受阈值 R*1.5 过宽 + CCD 直线模型对曲线母球预测偏差」属引擎层，改之有回归风险，本次以显示同源闸门治本于上报/画面一致，引擎宽松阈值留作后续物理标定 backlog。〕
- **日期**：2026-06-05
- **规则改进建议**：**所有球（含母球）的进袋判定都必须与画面（钳制轨迹）同源**——禁止任一球的进袋状态直接取裸引擎信号而不过显示一致性闸门。曲线走位（带塞 squirt+swerve）+ 袋口 CCD 直线预测 + resolvePocket 宽松接受阈值 三者叠加会产生「判进画面不进」假阳性，闸门按「钳制轨迹是否真落入某袋捕获窗」统一甄别。
- **已应用至**：✅ `QiuJi/Core/Physics/ShotPredictor.swift`（`cuePocketed` 加显示一致性闸门）、`QiuJiTests/ShotScenarioRenderTests.swift`（`test_diag_cueScratch` 诊断/扫描）（2026-06-05）；待回写 `10-ios-architect.mdc` § 经验教训

## FL-020
- **任务**：物理引擎技术债第一梯队测试网扩面（系统化矩阵 `PhysicsMatrixTests`）期间，用户提出「直球求解必须保证母球碰目标球前不吃库、目标球进袋前不吃库才合理」，据此加机器断言体检。
- **现象**：矩阵给「进袋」解逐例体检母球接触前吃库数，发现 3/285 例母球在碰目标球前先吃了 **4 次库**。聚焦复现 `t3p5c10s+v2.8`（目标球 (0.3,0.3) → 下中袋，10° 切，45cm 直瞄）：**同一精确输入连跑 30 次，`cueCushionsBeforeContact` 在 0（18 次）与 4（12 次）间随机翻转，进袋 28/30（2 次直接打丢），分离角取 80.66°/82.23°/83.25° 三值（跨度 >2°）**。即对该球形，求解器约 40% 概率选中「母球绕 4 库再歪打正着碰目标球」的 kick 退化解，60% 干净直击，运行间随机。
- **严重程度**：P1（求解器宏观非确定性 + 选到退化 kick 解；同一杆每次预测轨迹/分离角不同，违背确定性与「直球应直击」直觉，且偶发打丢）。注：远超既往记录的 1e-4° 派生标量微抖动（那是无害的），此为 0↔4 库的宏观翻转。
- **关联页面**：分离角与走位、走位编排器（`ShotPredictor.solveAimOffset`）。
- **根因**：✅ 已定位。`solveAimOffset` 评分最优区（−10，压过一切方向解）只要求「目标球直接进袋且落袋前 0 吃库」，**未要求母球碰目标球前 0 吃库**。搜索在 ±12°/0.5° 扫 49 个偏移，偶有大偏移让母球「打丢→绕 4 库→歪打正着碰目标球→目标球恰好干净落袋」，该 kick 解同样拿 −10，与真直击解打平；最优区出现并列后，叠加引擎 `Dictionary`/`Set` 事件遍历的浮点求和顺序非确定性，`bestOf` 的 argmin 在两个**完全不同**的解之间运行间随机翻转。
- **解决**：✅ 已修复（2026-06-05）。①生产层给 `RunResult`/`ShotPrediction` 新增权威字段 `cueCushionsBeforeContact`（引擎事件序列中首次 ballBall 前的 cue ballCushion 计数）；②`solveAimOffset` 最优区条件追加 `&& run.cueCushionsBeforeContact == 0`，钉死「直击解」唯一占据 −10，kick 解降到方向解支（acos 误差 >−10，永不胜出）；③方向解支加 `+ cueCushionsBeforeContact * 0.3` 轻惩罚兜底。回归：`PhysicsMatrixTests.test_matrix_solverPicksDirectNotKick_deterministic` 对 t3p5/t3p4/t4p4 各连跑 20 次 → cuePreBank max=0、进袋 20/20、分离角跨度 **0.00°**；矩阵 1 进袋率维持 85%（288/338）、母球接触前吃库 0 组、远处真翻袋 0 组；`PhysicsEngineTests` 23/23、`PhysicsInvariantTests` 9/9、`PhysicsScenarioTests` 7/7、`DrillShotReconstructionTests` 2/2 全过、lint 0。
- **日期**：2026-06-05
- **规则改进建议**：求解器「最优解」的判定必须包含**进攻路线纯净性**约束——直球求解中「母球碰目标球前 0 吃库 + 目标球落袋前 0 吃库」是 clean 解的硬条件，缺一会让「歪打正着的 kick/翻袋」退化解与真直击解在评分上并列；一旦最优区出现并列，引擎无序容器遍历的浮点非确定性就会被放大成**宏观解翻转**。新增/调整求解器评分时，必须用大规模系统化矩阵（数百球形）逐例断言进攻路线纯净性 + 同一输入多次重跑断言宏观确定性，不能只看单次结果或派生标量微抖动。
- **已应用至**：✅ `QiuJi/Core/Physics/ShotPredictor.swift`（`cueCushionsBeforeContact` 字段 + `solveAimOffset` 最优区/方向解约束）、`QiuJiTests/PhysicsMatrixTests.swift`（矩阵 1 线干净断言 + 矩阵 3 确定性回归）（2026-06-05）；待回写 `10-ios-architect.mdc` § 经验教训

## FL-021
- **任务**：ADR-P11-08 UI 截图回归（`QiuJiUITour` scheme，`testScenePopups`/`testUnifiedDesignPages`）。
- **现象**：UI 测试连续 5+ 轮以不同方式假失败：app not running / No matches for TabBar / kAXError -25218 / Test crashed with signal term；录屏显示 App 启动后中途整个退到桌面（runningboard 报 voluntary exit）。期间多次误改测试代码（加超时、加 AX 兜底重启）均无效甚至帮倒忙——AX 查询超时误判健康 App「未启动」反把它 terminate。
- **严重程度**：P1（阻塞全部 UI 验证流程；浪费多轮排查与重试）。
- **根因**：✅ 已定位。**同机另一并行会话在对同名模拟器（`name=iPhone 17 Pro`）反复跑 `xcodebuild test`（单元测试）**——xcodebuild 每次启测都重装 App（installcoordinationd "Acquired termination assertion … proceeding with install"），把 UI 测试会话中的 App 进程与 test runner 一起杀掉。日志特征：`installcoordinationd proceeding with install` + App `Process exited: voluntary` + xctrunner 同退。
- **解决**：✅ 已修复（2026-06-12）。①UI 截图测试改用**独立模拟器设备**（iPhone 17，`-destination id=16F181F1-...`），与并行单元测试会话（iPhone 17 Pro）物理隔离，立即转绿；②`launchClean` 兜底从 AX 查询（`tabBars.waitForExistence`，主线程繁忙时必假阴性）改为**进程状态**（`app.state == .runningForeground`）；③打点盘 sheet 增 ✕ 关闭钮（坐标拖动收 sheet 会被打点盘吞手势误设杆法）。
- **日期**：2026-06-12
- **规则改进建议**：①跑 UI 测试前先 `ps aux | grep xcodebuild` 查同机并行构建，多会话并行时**各会话用独立模拟器设备（按 udid 指定）**，禁止共享 `name=` 目标；②XCUITest 健康检查用进程态 `app.state`，禁止用 AX 查询结果反推「App 没起来」并据此 terminate；③连续假失败时先取证（xcresult 录屏抽帧 + simctl 日志查 install/terminate 事件），不要盲改测试超时。
- **已应用至**：`QiuJiUITests/Helpers/XCUIApplication+Extensions.swift`（进程态校验）、`QiuJiUITests/ScreenshotTourUITests.swift`（关闭钮路径）（2026-06-12）；回写 `55-test-engineer.mdc` § 经验教训（2026-06-12）

## FL-022
- **任务**：用户报告「母球吃左长库后反弹轨迹明显不合理（贴库滑行），偶发」的根因修复（接 PHYSICS-DEBT §5.7）。
- **现象**：上一轮修复（§5.7 三处 `enforceTableBounds` 改动）后用户打回：贴库滑行仍在，且求解轨迹出现「先吃库→撞远端 jaw 弧→进袋」的非物理假进袋。复盘发现上一轮把 S2 实测的「入29°→反131°」**误判为采样帧错位误报**（PHYSICS-DEBT §5.7 第 250 行），未复刻用户真实调用路径（ShotPredictor 补偿瞄向）做验证——S3 直瞄跑不复现、S2 求解器路径每次都复现。
- **严重程度**：P1（核心物理可信度；用户可见非物理轨迹 + 假进袋）。
- **根因**：✅ 已定位（S4 `test_S4_replicateS2EventChain` 数值确证）。**边界安全网与吃库事件的竞态**：库线吃库时球心接触位置恰好等于 `enforceTableBounds` 的 safe 边界（contact = 库线 ∓ R，零余量），CCD 把球精确演进到接触点时浮点噪声（~1e-6 m）偶尔落在边界外 → 零容差硬钳抢在已排定的吃库事件前触发（法向减半反向）→ 紧接着 Han 解析器按**已退离**的速度自动翻转接触系，把球再次反射**回库内**（实测 vz +3.276 → 硬钳 −1.638 → Han 二次反射 +1.101）→ 后续子步反复钳制（每次 ×0.5），球以 ~2 折出射角贴库滑出。浮点噪声逐杆不同 ⇒ 「偶尔出现」。下游假进袋 = 贴库滑行把球沿库送进角袋口。
- **解决**：✅ 已修复（2026-06-12）。两处物理正确性约束（无 magic offset）：①`enforceTableBounds` 触发加 0.5mm 余量（球心在接触线上是「正在吃库」的合法状态，非出界；真实接缝漏出每子步推进 mm 级，安全网不受影响）；②吃库解析加「库边只能推不能拉」护栏（解析前检查 v·n < 0 确在逼近，退离中的过时事件跳过且不记事件）。验证：S4 引擎实际出射 = 手动复算（27°/30°）；S2 全部反射恢复物理（131°→27°、114°→50°）；扫描贴库幽灵 0、平行出射 0；`test_solveDrillC005` 117s 无性能回退；`PhysicsInvariant/Matrix/Scenario/CushionDiagnostics/PositionPlayFreeAim` 全过；仅 3 个 `PhysicsEngineTests` 预存失败（与修复前完全同集，断言详情为袋口毫米级距离，另行处理）。
- **日期**：2026-06-12
- **规则改进建议**：①**数值安全网与物理事件共享同一几何线时必须留触发余量**——「合法接触位置 == 安全网边界」的零容差设计必然产生浮点竞态，且表现为偶发、难复现；②**碰撞解析器的方向自适应（按速度翻转接触系）必须配「只推不拉」护栏**，否则任何事件流外的状态突变都会让过时事件把球反射回障碍物内；③**修复验证必须复刻用户真实调用路径**（含求解器补偿瞄向），同参数直瞄不复现 ≠ 修好；把可疑测量归类为「测量误报」前必须用逐帧 dump + 手动复算双向确证。
- **已应用至**：`QiuJi/Core/Physics/EventDrivenEngine.swift`（`boundsEpsilon` + 只推不拉护栏）、`QiuJiTests/PocketBehaviorDiagTests.swift`（S4 复刻测试）（2026-06-12）；回写 `.cursor/skills/geometry-spatial-reasoning/SKILL.md` § 经验教训（2026-06-12）

## FL-023
- **任务**：3D 导出视频 / App 内 3D 模式「球桌没有腿」根因诊断与修复（承接 2026-06-18 PD-024 轮「桌腿诊断」与 2026-07-02 早间诊断会话）。
- **现象**：3D 斜视角下球桌只有深裙板 + 极短「脚桩」，无参考图中完整的铜雕花腿。前两轮诊断先后归因「相机角度+暗腿压黑底（非 bug）」「黑底+近垂直顶光藏腿（主因）+30° 俯角透视压缩（次因）」，均被用户直觉推翻（"之前在项目 01 某次操作后腿就没了，应该有更根本的原因"）。
- **严重程度**：P1（3D 视觉核心资产缺陷 + 两轮误诊）。
- **根因**：✅ 已定位（双层）。**资产层**：2026-02-27 项目 01 一次「多部件合并为单网格」的 Blender 重导出（commit `a2eccf9` 2026-03-02 提交，usdc 内部文件名 `TaiQiuZhuo2.usdc`）把 9 个部件合成单 Mesh `Plane_001`，腿子集（MG_Gold，56,944 面）的三角形被合并/dissolve 成**巨型 n-gon**（面顶点数出现 29/43/56/128/**256**）。**导入层**：SceneKit 的 USDZ 导入器对**含 ≥256 顶点面的 GeomSubset 整个静默丢弃**（最小复现实测：255 边形可导入、256 边形所在子集整体消失）→ 9 个材质子集只剩 8 个，腿完全不渲染。**误导链**：合并网格的 177,346 个顶点全保留（与旧版 9 部件之和分毫不差），腿顶点成为无面片引用的孤立顶点 → 包围盒仍显示「几何到达地面 Y≈0」→ 前两轮据此排除几何缺失、往灯光/相机方向找。USD 层数据其实完整（usdview/Windows 3D 查看器等能正常显示腿），纯 SceneKit 导入行为。
- **解决**：✅ 已修复（2026-07-02）。用 USD 工具链做**外科手术**（venv + usd-core）：`Sdf.CopySpec` 把 01_backup 旧版（2026-02-20，未合并）的纯三角腿网格 prim `/root/TaiQiuZhuo_007`（Plane_007，64,180 顶点/125,984 三角、MG_Gold）复制进当前模型层，`UsdUtils.CreateNewUsdzPackage` 重打包，替换 `QiuJi/Resources/TaiQiuZhuo.usdz`（89.7→98.3MB）。**刻意不走 SceneKit `write(to:)` 导出往返**——实测它会把线性色空间材质纯色二次伽马编码（MG_Gold diffuse 0.801→0.957、Black 0.25→0.537），腿色/黑件全漂白。新白球（BaiQiu 网格+专用贴图+红点 UV）与其余部件零改动；坐标天然对齐（两版部件同坐标系，嫁接前后腿 bbox 逐位一致）。**验证**（真实输出）：`TableLegGeometryDiagTests` 真实管线渲染 TEST SUCCEEDED——侧视立面三条铜腿完整落地、导出相机（黑底+studio 灯+pitch 30°）下铜腿清晰可见；回读包 `Plane_007` 材质 rgb(0.801,0.338,0.207) 与旧版逐位一致。
- **日期**：2026-07-02
- **规则改进建议**：①判断「几何是否存在/可渲染」**禁止用包围盒或顶点数**——孤立顶点撑出假象；必须数被索引/面片引用的顶点，或把目标材质替换成高亮色渲染直接验证。②SceneKit USDZ 导入红线：GeomSubset 含 ≥256 顶点的面 → 整个子集静默丢弃；Blender 合并/limited dissolve 后导出必须先三角化（或校验 max n-gon < 256）。③修复/嫁接 USDZ 资产用 USD 工具链（`Sdf.CopySpec`+`UsdUtils.CreateNewUsdzPackage`），禁经 SceneKit `write(to:)` 往返——线性空间纯色会被二次伽马漂移。④连续两轮诊断结论被用户直觉质疑时，回到资产/数据源头做新旧版本二进制对比，而非在渲染参数层继续迭代。
- **已应用至**：`QiuJi/Resources/TaiQiuZhuo.usdz`（修复版资产）；回写 `20-swiftui-developer.mdc` § 经验教训 / FL-023（2026-07-02）

## FL-024
- **任务**：T-P18-42 重叠标注三档验收（`testB2ShotControls` 截图门）时发现分离角手动模式主线程死循环。
- **现象**：截图门连跑 3 次失败于「Timed out while evaluating UI query」；录屏显示切「手动」后页面冻结（求解 spinner 由渲染服务器驱动仍在转、chip 选中态未刷新），App 对辅助功能查询无响应。
- **严重程度**：P0（主线程死循环，手动模式必现挂死；潜伏自 T-P18-09/B2，T-P18-41 改虚线常量后在该测试场景下成为确定性触发）。
- **根因**：✅ 已定位（`sample` 进程采样直接抓到主线程栈顶）。`ShotSimulationViewModel.addDashedPath` 用**浮点相位累积推进**铺虚线：`step = min(dash - phase, len - t); t += step`。Float32 精度下当 `arc + t` 较大时 `truncatingRemainder` 量化使 `phase` 逼近 `dash`，`step` 下溢到小于 `t` 的 ULP → `t += step` 不再改变 `t` → `while t < len` 死循环。触发依赖轨迹弧长与虚线周期的具体组合，故此前未爆。
- **解决**：✅ 已修复（2026-07-05）。重写为**整数周期索引**算法：第 k 个 on 段覆盖全局弧长 `[k·period, k·period+dash)`，对每折线段求 `firstK...lastK` 交集落段——循环以整数计数有界，必然终止；另加 `dash/gap > 1e-4` 入参护栏。验证：`testB2ShotControls` 复跑 TEST SUCCEEDED（10 张截图全出），手动模式对照虚线视觉不变。
- **日期**：2026-07-05
- **规则改进建议**：**浮点增量推进的 while 循环（`t += step` 型）一律禁止**——`step` 由减法/取余导出时必然存在下溢为 0 的参数组合，表现为偶发整机挂死；铺设周期性几何（虚线/刻度/网格）必须用整数索引推导区间再求交。UI 测试出现「Timed out while evaluating UI query」先怀疑主线程死循环，用 `sample <pid>` 采样直取栈顶，不要猜。
- **已应用至**：`QiuJi/Features/AngleTraining/ViewModels/ShotSimulationViewModel.swift`（整数周期重写）；回写 `.cursor/skills/geometry-spatial-reasoning/SKILL.md` § 经验教训 / FL-024（2026-07-05）

## FL-025
- **任务**：问题集合 v9 W1「训练分享保存相册卡死/闪退」首轮收官后用户真机复测仍秒闪退（返工第 1 轮）。
- **现象**：真机点「保存相册」立即闪退；首轮模拟器单测 + UI 冒烟全绿、已判 ✅。
- **严重程度**：P0（真机必现崩溃 + 首轮误收官）。
- **根因**：✅ 已定位（双重）。**配置层**：主 target 显式 `INFOPLIST_FILE = QiuJi/Resources/Info.plist`（`GENERATE_INFOPLIST_FILE = NO`），pbxproj / project.yml 中的 `INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription` 等 `INFOPLIST_KEY_*` 设置**全部被 Xcode 静默忽略**，构建产物 Info.plist 无权限文案 → 首次 `PHPhotoLibrary.requestAuthorization` 需弹框时被 TCC 直接强杀。v9 方案 §二把「pbxproj 里有这行」误判为「权限文案已配置」。**测试层**：首轮 UI 冒烟用 `simctl privacy grant photos-add` 预授权限，跳过了弹框路径，恰好掩盖了唯一会崩的分支。
- **解决**：✅ 已修复（2026-07-17，返工 1 轮）。三权限键（相册添加/相册读取/相机）直写 `QiuJi/Resources/Info.plist` + `project.yml` info.properties（留「INFOPLIST_KEY 不生效」警告注释防 xcodegen 回退）；PlistBuddy 实证 iphoneos + sim 两产物键在包内；新增 `PhotoPermissionInfoPlistTests`（断言 `Bundle.main` 含权限文案）；UI 冒烟改为 `privacy reset` 后走真实弹框（拦截器点「允许」）通过。产物 `build/w1r1-logs/`。
- **日期**：2026-07-17
- **规则改进建议**：①判断 Info.plist 键是否生效**只认构建产物**（PlistBuddy 查 built .app），禁止以 pbxproj/project.yml 里存在设置行为据；显式 INFOPLIST_FILE 的 target 中 `INFOPLIST_KEY_*` 一律无效。②涉及隐私权限的 UI 测试**必须至少覆盖一次真实弹框路径**（`simctl privacy reset` + 拦截器），`grant` 预授只能作为补充场景——预授会掩盖 TCC 强杀崩溃。
- **已应用至**：`.cursor/rules/60-devops-release.mdc` § 经验教训 / FL-025（2026-07-17）；`.cursor/rules/55-test-engineer.mdc` § 经验教训 / FL-025（2026-07-17）

## FL-026
- **任务**：问题集合 v11 批次 Y1「瞄准方法」学页首轮交付后，用户指出三种瞄准法的定义与其原意不符（返工第 1 轮）。
- **现象**：Y1 按真源 §2.1 调研口径实现：管道法=单管道（仅瞄准线体积化）、「撞击点瞄准法」映射为重合比例/厚薄法、平行线法=Mosconi（过球心作**进球线**平行线）。用户原意：管道法=**瞄准线与进球线各成一条管道、两管道相切处即两球接触点**；接触点法=**点对点**（标出目标球接触点 Pt 与母球对应接触点 Pc，将两点碰到一起）；平行线法=**过母球心作两接触点连线的平行线即瞄准线**（碰撞瞬间两球心关于接触点点对称）。
- **严重程度**：P1（内容语义偏差，整批正文与三张插图需返工；构建/测试均绿，非技术故障）。
- **根因**：✅ 已定位（流程层）。需求回显时用户已注明「名字可能不准确」，立项调研把这些口语名**单方面映射到网络通行方法**（管道→隧道瞄准、撞击点→重合比例、平行线→Mosconi）后写入 §2.1 并据此派发，**映射结果从未回给用户确认**。拍板项 D-v11-1~4 只问了组织/归属/交互，没有把「方法定义映射」列为拍板项——最该确认的语义环节恰好绕过了确认。
- **几何佐证（数值草稿，2026-07-17）**：用户三定义自洽且可从角度瞄准法推出——Pc→Pt ≡ G−C（同向等长，θ 5°–70° 扫描误差 <1e-14）；碰撞瞬间 G 与 T 关于接触点 Q 点对称；管道半径取 R（管宽=球径）时两管道恰外切于 Q（取球径 2R 则互相穿越 0.057m，不成立）。证据：`build/y1-evidence/y1r1-user-definitions-draft.txt`。
- **解决**：✅ 已修复（2026-07-17，返工 1 轮）。真源 §2.1 勘误升 v11.2；resume 原执行子智能体按用户定义重做三节并交互化（θ 滑杆 + 管道试瞄三态 + Pt/Pc 碰合动画 + 平行线联动），几何提为可测真源 `AimingMethodsGeometry` + 不变量单测 5/5；主控独立验收通过（diff 逐文件、r1 日志/截图亲验、主树 build 亲跑 SUCCEEDED）。
- **日期**：2026-07-17
- **规则改进建议**：用户对术语标注「名字可能不准确」时，调研映射到通行方法后**必须把「你说的 X = 通行的 Y（定义一句话）」列入拍板项回给用户确认**，禁止映射后直接当事实写入真源口径；含定义映射的批次开工前，委派提示词中的方法定义必须逐条附「用户原话 → 采用定义」对照。
- **已应用至**：`.cursor/skills/issue-collection-restructure/SKILL.md` § 经验教训 / FL-026（2026-07-17）

## FL-027
- **任务**：翻袋贴库预反射（扎自库弹出）首轮交付后，用户反馈效果不行；主控代码复查 + 诊断矩阵实证返工（返工第 1 轮）。
- **现象**：贴库盘面解列表出现假解与重复解：「左库 1库」标签实为直击拓扑；同一杆物理解（瞄准/塞完全相同）被不同种子库序标成两条解（库数不同致 K9 去重失效）；扎库解库数少计自库一次（chip/画面/文案不一致）。
- **严重程度**：P1（解语义错误上屏；构建/测试首轮全绿，属误收官）。
- **根因**：✅ 已定位（双重）。**流程层**：首轮实现中 `solveSequence` 的「贴库时把袋外孔心钳到台内」兜底，是为让新增单测「预反射至少激活一次」变绿而加的特例分支——未先质疑该断言的物理前提（部分库序对贴库盘面本就无解），属 reward-hack 型修复，并顺带制造了退化种子假解族。**架构层**：解的库序/库数/标签全部取**种子声明**，而 ±8° 精修后真实轨迹可能属另一拓扑族；终验只查「进袋 + 母球不先吃库」不查拓扑，去重又以「库数相同」为前置——种子元数据与真实轨迹脱节时全链失真。另实测发现：贴库球被打扎向自库时首弹发生在 t≈0 既有接触上，引擎不产生 ballCushion 事件（事件流看不见的真实吃库）。
- **解决**：✅ 已修复（2026-07-21，返工 1 轮）。①删 clamp 兜底（假解族根源）；②展示改**实测重标**：`RunResult`/`ShotPrediction` 新增 `objectRailContacts`（主库线性段 0–5 分类、连续同库合并、jaw/喉壁不计）+ `objectDepartureDir`，`BankShotCalculator.reconstructedRailContacts` 依碰后出发方向补回贴库首弹（>sin3° 扎向自库才补，排除沿库直滚直击冒充）；`BankEngineSolution.rails/cushions/usedFrozenRailSeed` 全部由实测派生，实测空库序（直击）淘汰，`seedRails` 单列供微调重算锚定；③K9 去重去掉「库数相同」前置；④扎库文案改「扎库(自库名)」，微调草稿去粘性 OR。证据：`BankKickDifficultyTests` 18/0、全量 QiuJiTests 656/2skipped/0（`build/frozen-rail-logs/full-suite3.log`）、诊断矩阵标签一致性 17/17（`build/frozen-rail-logs/`）。
- **日期**：2026-07-21
- **规则改进建议**：①新增单测断言失败时，先用数值/物理草稿验证断言前提成立，禁止改生产代码「喂绿」测试（尤其禁止为特定盘面加几何特例分支）；②求解器上屏解的用户可见元数据（库序/库数/标签）必须取自引擎实测轨迹或经实测校验，种子/声明值只可作搜索锚。
- **已应用至**：`.cursor/rules/00-orchestrator.mdc` § 经验教训 / FL-027（2026-07-21）

## FL-028
- **任务**：问题集合 v23 W1/W1b 瞄准特写 HUD，用户两轮点验后仍报「位置、颜色不对」（返工第 2 轮）。
- **现象**：①放大镜落在目标球所在的那一半（贴着球，且落在左侧刻度轮/拖动拇指那一列）；②镜内绿色比台呢明显偏蓝偏灰，观感像贴在台面上的贴纸。
- **严重程度**：P2（功能可用但两条核心验收语义 E3「位置相对焦点球避让」「台呢色底」不达标）。
- **根因**：✅ 已定位（双重）。
  1. **定位**：`AimCloseupPlacement.corner` 的滞回写成**半平面**而不是「中线模糊带」——`previous` 为上方时判据是 `focusNorm.y < 0.5 + h`，恰好等价于「焦点在上半就保持在上半」，与本函数自身的「取焦点对角」不变量矛盾；且**已有单测把这个错误语义写死**（`test_corner_hysteresis` 用 prev=topTrailing + focus y=0.3 断言保持 top），例式测试因此全绿，缺口是没有对「previous × 焦点位置」全状态空间断言不变量。横向另有一层：左右镜像焦点时会主动选到 leading 列，而该列正是刻度轮 + 拖动拇指所在，属需求未显式声明的遮挡约束。
  2. **颜色**：底色靠「挑一个看起来像台呢的值」定（先 `btTableFelt` UI token，再手调亮绿），从未与**实际渲染出来的台呢**比对。实测 plain 管线台呢 ≈ (25,111,18)，`btTableFelt` = (27,107,58) 蓝通道高约 40/255 ⇒ 必然偏青。此类「要和 X 看起来一样」的值没有任何自动化守门。
- **解决**：✅ 已修复（2026-07-28；v23.7 半步 + **v23.8 收口**）。①滞回改中线模糊带 + `blockedSide`；②定位升级为相对焦点偏移 `center`（间距 **0.92×直径**，旧 0.58×d 边隙仅 ~10pt 仍显贴球）；③底色改扁平实测台呢 RGB(25,111,18)，去径向变暗。**证据**：轴向契约测试；`AimCloseupFeltParityTests` 现逐通道一致 0.098/0.435/0.071；`test_center_clearsFocusAndLeadingWheel` + UR 截图用例；合成图 `build/v23-evidence/w1-position-color/composite.png`；`build/v23-w1b-v238-test3.log` 14/0。
- **日期**：2026-07-28
- **规则改进建议**：①「避让 / 对角 / 不遮挡」类布局规则必须以**不变量测试**覆盖（遍历所有 previous 状态 × 焦点区间），例式用例不足；滞回一律写成「中线模糊带内保持」，禁止写成半平面。②要求「和某处看起来一样」的颜色/尺寸，取值必须**测量真实渲染**（离屏渲染采样）并用像素比对测试锁住，禁止凭 UI token 或手调值交付。③写新测试前先检查是否与被测函数自身的不变量冲突——已有绿测试可能正在守护一个 bug。④放大镜类浮层的「离开焦点」须断言**圆心距 ≥ 半径 + 被遮物半径 + 间隙**（或等价边隙），禁止只断言象限/角落不同——象限对了仍可能边贴边。
- **已应用至**：`.cursor/rules/20-swiftui-developer.mdc` § 经验教训 / FL-028（2026-07-28；v0.8 补圆心距断言）

## FL-029b
> 编号说明：`FL-029` 已被 `00-orchestrator.mdc` 占用（`try?` 吞解码错误），本条另编 `029b` 以免撞号。

- **任务**：问题集合 v36 W4b — 把仓库 `backend/` 部署到 `106.54.3.210`（AI 直接经 root SSH 执行）。
- **现象**：部署后约 12 分钟用户报「现在用苹果 id 登陆不了」。部署前可登录。
- **严重程度**：**P0（线上回归，由本次操作直接造成）**——登录是同步链路总入口，挂了则 v36 全部功能不可用。
- **根因**：✅ 已定位。`rsync -av --delete src/` 用**仓库版本**覆盖了服务器版本，而两者在 `auth.js` 上早已分叉：
  - 服务器实际运行：`audience: "com.xinkuan.qiuji"`（**正确**，等于真实 Bundle ID；系某次直接改服务器文件所致，未回写仓库）。
  - 仓库 `backend/src/routes/auth.js`：`audience: "com.qiuji.app"`（**错误**，从 2026-03-29 建库起从未改过；`git log -S` 证实零次修改）。
  - ⇒ 部署即把线上正确值替换成仓库错误值，`appleSignIn.verifyIdToken` 抛 `jwt audience invalid. expected: com.qiuji.app`。
  - **证据链**：部署前的备份 `/root/qiuji-backend-backup-20260812-094734.tar.gz` 内 `auth.js:17` 为 `com.xinkuan.qiuji`；4 月 error.log 里那条 `audience invalid` 是仓库值曾短暂上线过的残留。
- **本可拦住却没拦住的三点**：
  1. 部署前**只 diff 了「服务器有没有新功能」（by-client 路由、9 字段），没有反向 diff「服务器有没有仓库缺失的修改」**。`--delete` 是单向覆盖，反向差异必须先看。
  2. 服务器上 `/opt/qiuji-backend` **不是 git 仓库**，手改无版本记录、无告警，分叉可以无限期潜伏。
  3. 部署后自检覆盖了 W1/W2/W3 三条链路，**唯独没测登录**——因为自检用的是服务端直签 token，恰好绕过了 `login-apple`。「用直签 token 绕过认证」既是当时的便利，也正是漏检的原因。
- **解决**：✅ 已修复（2026-08-12）。`audience` 改为 `config.appleBundleId`（`APPLE_BUNDLE_ID` env 可覆盖，默认 `com.xinkuan.qiuji`），仓库即真源；`.env.example` 登记该键并注明必须等于 `PRODUCT_BUNDLE_IDENTIFIER`。已部署并实测生效值 = `com.xinkuan.qiuji`，`pm2` online。
- **日期**：2026-08-12
- **规则改进建议**：
  ① **`rsync --delete` 类单向部署前，必须先做反向 diff**（`rsync -n --delete` 或先把远端拉下来 `diff -r`），确认服务器上没有仓库缺失的修改；发现分叉先回流进仓库再部署，⛔ 禁止「我方较新」的默认假设。
  ② **非 git 管理的部署目录视为高危**：分叉不可见。后续应把 `/opt/qiuji-backend` 纳入 git 或改为从仓库 checkout 部署。
  ③ **部署自检必须覆盖认证入口**，且⛔ 不得用绕过认证的手段（直签 token）代替——被绕过的那一段恰恰是最容易漏检的。
  ④ **配置中的外部标识符（Bundle ID / audience / redirect URI 等）禁止写死臆想值**，一律走 env + 注明其真源字段位置；本例中 `com.qiuji.app` 是凭空臆想的产物，真实值从建库第一天起就是 `com.xinkuan.qiuji`。
- **已应用至**：⏳ 待回写（建议目标：`.cursor/rules/30-data-engineer.mdc` 或新增 `60-devops-release.mdc` § 经验教训）

## FL-030
- **任务**：排查 FL-029b（Apple 登录不可用）时**顺带发现**的既有缺陷，与本次部署无关。
- **现象**：`QiuJi.entitlements` 声明了 `com.apple.developer.applesignin`，但该文件**从未被接到 target 上**——`CODE_SIGN_ENTITLEMENTS` 在 `project.yml` 与 `project.pbxproj` 中均不存在。无此 entitlement 时 `ASAuthorizationController` 直接失败，客户端走 `didCompleteWithError` 抛「Apple 登录失败，请重试」。
- **严重程度**：P0（Apple 登录为唯一登录方式），**潜伏近 4 个月未被发现**。
- **根因**：✅ 已定位，**与 FL-029b 同构**——手改生成物、未回写真源：
  - `b52dc6f`（2026-04-10「fix: resolve 3 issues from TP-P2 manual testing」）**直接在 pbxproj 里**加了 `CODE_SIGN_ENTITLEMENTS`（Debug/Release 两处），未同步 `project.yml`。
  - `fca79ff`（2026-04-17「feat: add P9 aiming training expansion」）某次 `xcodegen generate` 重新生成 pbxproj，**把这两行冲掉**。
  - `git log -S'entitlements' -- project.yml` **零结果**，证实真源里从来就没有过。
  - pbxproj 是 XcodeGen 的**生成物**，手改必被覆盖——这与「手改服务器部署目录必被 rsync 覆盖」是同一个错误的两种形态。
- **旁证（时间线自洽）**：后端 `users` 集合里唯一一条真 Apple 用户创建于 2026-04-09、末次更新 2026-04-12，**恰好落在 entitlement 存在的窗口内**（4/10 提交 ~ 4/17 冲掉）；此后再无新用户。
- **解决**：✅ 已修复（2026-08-12）。`CODE_SIGN_ENTITLEMENTS: QiuJi/QiuJi.entitlements` 写入 `project.yml` 的 QiuJi target settings（附注释说明为何必须写在真源），`make xcodegen` 重生成。**证据**：pbxproj 内该键出现 2 次（Debug + Release）；`make build` **BUILD SUCCEEDED**；构建产物 `球迹.app-Simulated.xcent` 实测含 `"com.apple.developer.applesignin" => ["Default"]`（此前该键不存在）。
  - ⚠️ 排查中一次自身误判：首次 `find build -name "球迹.app"` 命中的是 `build/Build/`（**2026-04-05 的陈旧遗留目录**），其 xcent 无 applesignin，一度误判为修复无效。真产物在 `build/DerivedData/Build/Products/`（Makefile `DERIVED_DATA` 指向此处）。教训：验证构建产物前先核对时间戳与 Makefile 的输出路径，⛔ 别拿 `find` 的第一个命中当结论。
- **顺带修正**：本次重生成还把 `QiuJiTests/TutorialFiguresBundleTests.swift` 补进了 pbxproj——该文件已被 git 跟踪，但上次提交的 pbxproj 是**未重跑 xcodegen 的过时生成物**，测试实际未进 target。
- **日期**：2026-08-12
- **规则改进建议**：
  ① ⛔ **禁止手改 `project.pbxproj`**（含在 Xcode UI 里加 capability / 拖文件）。任何 target 配置一律改 `project.yml` 后 `make xcodegen`；已手改的必须当轮回写真源。
  ② **提交 pbxproj 前先跑一次 `make xcodegen`**，确保提交的是最新生成物而非过时副本（本次即抓到一处）。
  ③ **entitlement / capability 类配置需有构建产物级断言**：仅检查 `.entitlements` 文件存在是无效的（本例文件一直在，只是没接上），须验 `*.xcent` 实际内容。建议接入 `make verify-gate`。
- **已应用至**：⏳ 待回写（建议目标：`.cursor/rules/10-ios-architect.mdc` 或 `60-devops-release.mdc` § 经验教训）

## FL-031
- **任务**：问题集合 v50 W1 多设备矩阵，A5（iPad mini 第 6 代 / iOS 17.0）进入 2D 角度训练。
- **现象**：A3（iPhone 17 Pro / iOS 26.2）长期正常，但 A5 每次进入球桌后 App 均以 `EXC_BAD_ACCESS` 退出；崩溃栈落在 SceneKit renderer 的 `C3DMeshElementGetType`，早期另一次落在运行中修改 `SCNMaterial` 的 `_setupMaterialProperty`。
- **严重程度**：P1（最低 Runtime 的核心训练场景稳定必崩）。
- **根因**：✅ 已定位。`TaiQiuZhuo.usdz` 的 `Plane_001` 含 4 个**恰好 256 顶点**的面（face indices 111157 / 124732 / 138307 / 151882）。iOS 17 SceneKit 把 256 边面解释为无效 edge count，日志出现 `Invalid polygon edge count (0)` 与 null `renderableElement`，随后渲染线程解引用崩溃；iOS 26 容忍了同一资产，因此单一最新设备测试未暴露。运行中切换袋口高亮材质和 SCNView 提前接入半成品 scene 又放大了竞态风险。
- **解决**：✅ 已修复（2026-09-02）。新增 `scripts/repair_usdz_polygon_limit.py`，用 Apple USD 工具链把所有 ≥256 顶点面拆为 `<256` 的合法面，同时同步 remap face-varying normals、UV 与 GeomSubset face indices，重打包并替换 `QiuJi/Resources/TaiQiuZhuo.usdz`；修复后 `Plane_001` 为 167,955 面、max face=255、0 个超限面，`usdchecker` 通过。袋口材质改为 renderer 接管前一次性配置，交互仅切 `node.isHidden`；`SceneAimingView` 在 scene 完成装载后才创建 `SCNView`。
- **验证**：`PocketMarkerHighlightTests` 2/0（含最低 Runtime 的 `SCNRenderer` 真正渲染一帧）；A5 Light `DeviceMatrixUITests` 3/0、3 张截图图像门禁通过；A3 Light 同套回归 3/0；A5 相同源码指纹 `--resume` 1.7 秒复用已验证结果。证据位于 `build/v50/matrix/ios-17.0/A5-iPad-mini-6th-generation/light/standard/contract/` 与 `build/v50/matrix/ios-26.2/A3-iPhone-17-Pro/light/standard/contract/`。
- **日期**：2026-09-02
- **规则改进建议**：① USDZ 门禁必须遍历所有 Mesh 并拒绝 max face vertices ≥256；② `usdchecker` 不能替代最低 Runtime 的真实 `SCNRenderer` 单帧渲染；③ SceneKit live scene 上避免高频改材质对象，优先预建材质后切节点状态；④ 最新 Runtime 通过不得外推最低 Runtime。
- **已应用至**：`.cursor/rules/20-swiftui-developer.mdc` § FL-023（2026-09-02）。

## FL-032
- **任务**：问题集合 v50 W7，最低 Runtime 完整安全单测与 SwiftData V2→V3 迁移复验。
- **现象**：iOS 17 上旧版自定义计划迁移后，部分多球形动作的原总组数被直接当成新版“每球形轮数”，训练剂量被放大；依赖当前 Bundle 推导旧数据含义时还会因测试/迁移进程拿不到历史内容而回退为 1。
- **严重程度**：P1（升级后用户自定义训练剂量会被静默改写，属于持久数据语义损坏）。
- **根因**：✅ 已定位。V2→V3 自定义 migration callback 同时依赖当前 `DrillContentService` Bundle 内容并在迁移阶段直接写目标对象；历史数据解释随 App 内容版本漂移，且 iOS 17 的自定义迁移阶段写入不稳定。
- **解决**：✅ 已修复（2026-09-02）。`roundsPerFormation` 使用 `@Attribute(originalName: "sets")` 走轻量字段迁移；V2→V3 改为 lightweight；打开持久 store 前通过 SQLite schema 判断是否仍是旧列，打开成功后再在正常 `ModelContext` 中按不可变 v31 球形数快照归一化。快照覆盖 19 个多球形动作并保留已下架 c006，迁移不再读取 Bundle。
- **验证**：新增“formation count snapshot 不依赖当前 Bundle”守卫；A1/iOS 17 与 A3/iOS 26.2 的 migration 聚焦回归通过，随后两套 Runtime 的 152 类安全单测分片全部零退出。首轮失败保存在 `build/v50/diagnostics/w7-safe-unit-initial/`，最终证据在 `build/v50/matrix/.../safe-unit-{1,2,3,4}/`。
- **日期**：2026-09-02
- **规则改进建议**：版本迁移解释旧数据时禁止读取会随版本变化的 Bundle 内容；优先使用字段原名轻量迁移、不可变历史快照与 store 结构探测，并把归一化放在正常打开后的 ModelContext 中执行。
- **已应用至**：`.cursor/skills/simulator-matrix-qa/SKILL.md`（2026-09-02）。

## FL-033
- **任务**：问题集合 v50 W7，iOS 17 安全单测对训练保存、历史 DTO 与下行恢复链路扩面。
- **现象**：iOS 26 既有测试长期通过；iOS 17 在保存训练、读取未托管历史关系以及恢复含 DrillEntry/DrillSet 的远端记录时稳定卡住，约 20 秒后测试宿主以 `signal trap` 重启。分片与聚焦测试仍可复现，排除单纯长套件噪声。
- **严重程度**：P1（最低支持系统上训练保存/恢复可能挂起或崩溃，核心记录链路不可依赖）。
- **根因**：✅ 已定位。生产保存与恢复代码、以及部分测试夹具，均先把未托管的 `TrainingSession → DrillEntry → DrillSet` 拼成关系树，再只插入根对象；iOS 26 容忍该隐式级联，iOS 17 的 SwiftData 在部分关系遍历/持久化路径会 trap。测试中同时保留多个内存容器还会产生 model configuration 不兼容。
- **解决**：✅ 已修复（2026-09-02）。`ActiveTrainingViewModel.saveTraining` 与 `SyncRestoreService` 先把每个节点插入同一 `ModelContext`，再设置 inverse 关系；DTO/History/Restore 测试夹具采用同一路径，远端源数据在同一 context 完成实体→DTO 后显式清理，不再并存第二个容器。删除仓储继续显式按 DrillSet→DrillEntry→TrainingSession 删除，规避 iOS 17 cascade 残留。
- **验证**：A1/iOS 17 `w7-active-training`、`w7-history-data`（35/35）、`w7-restore-sync`（11/11）、SwiftData model 与 local repository 聚焦测试均通过；最终 A1/A3 的 152 类安全分片全绿。原始 trap 与 xcresult 保存在 `build/v50/diagnostics/w7-safe-unit-final/`。
- **日期**：2026-09-02
- **规则改进建议**：最低 Runtime 必须单独验证 SwiftData 关系写入、迁移与删除；不要以最新 Runtime 对未托管关系图的宽容行为外推最低线，测试夹具也必须遵守生产对象生命周期。
- **已应用至**：`.cursor/skills/simulator-matrix-qa/SKILL.md`（2026-09-02）。

## FL-034
- **任务**：问题集合 v50 W7/W8，A1–A8 同名 66 页截图的跨设备视觉比较。
- **现象**：A1/A3 的 `00-launch`、训练首页与统计页继承了模拟器以前留下的激活计划和训练记录，A2 却是空数据；三台都能生成 66 张 PNG，XCTest、manifest、尺寸和解码门禁仍全部通过。同一 `standard` 分组实际混入不同产品状态，数量门禁形成假绿。
- **严重程度**：P1（测试可靠性；会让跨尺寸视觉结论失去共同基线，但不是生产 App 在真实用户数据下的功能缺陷）。
- **根因**：✅ 已定位。`testDesignerPageDump` 只固定 Pro/语言并清空截图目录，仍使用各模拟器的磁盘 SwiftData；巡游内部为 SceneKit/球理稳定性做的多次软重启也只保留 `-forcePremium`，没有固定数据 fixture。截图完整性门禁只能检查文件名和图像健康，无法判断同名页面是否处于同一数据状态。
- **解决**：✅ 已修复（2026-09-02）。设计巡游启用 `usesDeterministicInMemoryStore`，经统一 `launchPremium()` 在首启及所有软重启持续传入 `-v50.inMemoryStore`；其他持久化测试和生产启动仍使用磁盘容器。联系表审查新增“跨设备同名页状态语义横向比较”，并回写 `simulator-matrix-qa` 技能。
- **验证**：最终源码指纹 `58881e93ff31c40c63cbbee26ae2e9e64c9d5efe76a940b2660a14e5beb97a8f` 下，A1–A8 × Light/Dark 16/16 个巡游均为 66/66，合计 1,056/1,056；`00-launch` 均为“未激活计划”基线、历史页均为空数据，代表球桌的轨迹/网格偏好一致。16/16 张最终联系表逐页横向审查未再出现状态漂移。
- **日期**：2026-09-02
- **规则改进建议**：跨设备视觉回归必须同时固定数据库与可见偏好；所有软重启继承同一 fixture。manifest/哈希/解码只证明“图片存在且可读”，联系表还必须比较同名页面的数据状态语义。
- **已应用至**：✅ `.cursor/skills/simulator-matrix-qa/SKILL.md`（2026-09-02）。

## FL-035
- **任务**：问题集合 v53 W7，账号资料跨端契约完成审计。
- **现象**：iOS 昵称校验允许 1–40 字符而服务端只接受 1–20；iOS 球龄写入 `oneToThree/threeToFive/fivePlus`，服务端却只接受 `oneTo3/threeTo5/moreThan5`。前者让 21–40 字符昵称产生客户端可提交、服务端必拒绝，后者让三个常用球龄选项更新失败，并使已写入旧值在恢复时回落默认值。
- **严重程度**：P0（用户资料无法可靠写入和恢复，直接违反本轮“真实资料而非假成功”目标）。
- **根因**：✅ 已定位。客户端和服务端分别维护字符串枚举与长度范围，初始定向测试只各测本端合法/非法，没有用同一组 canonical fixture 做双端闭环。
- **解决**：✅ 已修复（2026-09-03）。昵称统一为 1–20 字符；球龄统一使用 iOS/DTO 既有 canonical 值，服务端 serializer 继续兼容三个早期旧别名，避免已有数据恢复失真。
- **验证**：backend 8/8、v53 iOS 定向单测 37/37、P8 Profile/Settings UI 17/17；新增 20/21 字符边界、canonical 写入、旧别名归一化与登录资料恢复用例。
- **日期**：2026-09-03
- **规则改进建议**：共享 DTO 的字符串枚举和长度边界必须以一组 canonical fixture 同时驱动两端测试；单端“合法值通过”不能替代跨端契约验证。
- **已应用至**：`问题集合_v53.md` P53-22/P53-23、W0/W7 与 v53.3 执行证据。

## FL-036
- **任务**：问题集合 v53 W7，头像与账号注销隐私一致性复审。
- **现象**：`DELETE /user/account` 删除用户、训练记录和角度测试后直接返回“账号及所有数据已删除”，但 `AVATAR_STORAGE_DIR` 中的头像文件仍保留。
- **严重程度**：P0（可关联账号的用户图片在注销后成为孤儿文件，产品文案与实际删除范围不一致）。
- **根因**：✅ 已定位。头像是在 v53 新增的文件存储面，而既有注销路由只枚举 Mongo 模型；删除清单没有随新增数据面同步扩展，也没有针对文件存储失败设计可重试顺序。
- **解决**：✅ 已修复（2026-09-03）。新增 `accountDeletion` 服务：先读取用户头像 revision 并删除对应文件，成功后再并行删除训练、角度和用户记录；头像存储失败时保留账号/revision，使后续重试仍能定位文件。
- **验证**：backend 13/13；新增正常删除顺序与头像存储失败时数据库零删除两项测试。
- **日期**：2026-09-03
- **规则改进建议**：新增任何账号关联存储面时，必须同步更新注销数据面清单、隐私政策和删除失败重试测试；接口成功文案不得超出实际删除集合。
- **已应用至**：`问题集合_v53.md` P53-25、W0/W7 与 v53.5 执行证据。

## FL-037
- **任务**：问题集合 v53 W7，客户端注销与跨账号异步状态完成审计。
- **现象**：云端注销成功后，iOS 仍保留账号昵称/偏好和多个头像 revision 缓存；若随后 account→guest 本地迁移失败，界面会继续停在已被服务端删除的登录态。与此同时，账号 A 的迟到资料/头像响应及头像请求 `defer` 可在已切换到 B 后改写 B 的显示或 loading phase；“清除所有缓存”也没有覆盖头像 JPEG。
- **严重程度**：P0（账号删除真实性、数据可恢复性与 A/B 隔离）；缓存按钮漏清本身为 P2。
- **根因**：✅ 已定位。删号流程把服务端删除、本地 owner 迁移、账号展示缓存清理绑在一个不可补偿的 `do/catch` 中；资料/头像异步写回只校验请求发起身份，头像 store 又以全局 phase 和非版本化回滚收尾；自建文件缓存未登记到 Settings 缓存边界。
- **解决**：✅ 已修复（2026-09-03）。删号后清账号级 UserDefaults 与全部头像 revision；服务端成功后先落持久补偿标记，本地迁移失败也清会话，并在下次 `AccountDataCoordinator.configure` 幂等重试 account→guest，同时用删除专用策略丢弃旧 account 同步队列；认证资料写回核对当前 user id；头像 load/upload/delete 使用 operation generation，旧请求不能覆盖新图、错误或 phase；Settings 缓存体积与清理均纳入头像目录。
- **验证**：v53 iOS 专项 43/43；其中新增删号资料缓存、全 revision 头像缓存、启动补偿迁移及旧队列丢弃、A 迟到头像响应不覆盖 B 且不提前结束 B loading 等回归。P8 Profile/Settings UI 17/17；标准 Debug build、PrivacyInfo/Info.plist lint 与 v47 route/write-surface 129 门禁通过。
- **日期**：2026-09-03
- **规则改进建议**：账号删除应按“不可逆远端提交 + 可恢复本地补偿”设计 saga；任何共享异步 UI store 都必须以当前 owner 和 operation generation 双重校验写回，新增缓存目录时同步更新清理入口与写盘台账。
- **已应用至**：`问题集合_v53.md` P53-26–P53-29、W3/W4/W7 与 v53.6 执行证据；`docs/design/v47/write-surface-audit.md`。
