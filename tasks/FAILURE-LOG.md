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

## FL-038
- **任务**：问题集合 v51 W5，最终 Light/Dark 全页矩阵与长时间并发证据收口。
- **现象**：首轮目录名和 `simctl` 回读均为 Light，但代表截图实际仍是 Dark；长矩阵期间其他在途工作修改源码后，已有绿单元仍留在当前叶子；两个 runner 并发更新全局摘要时还可能互相覆盖。设备同时 Boot 过多时另出现 AX 空树、tap 未投递或 App 被系统清退。
- **严重程度**：P1（测试可靠性；会让错误外观或陈旧源码证据被当成最终绿，但不是生产布局本身的新缺陷）。
- **根因**：App 的持久化 `appearanceMode` 优先于系统外观，测试只设置/回读 `simctl` 而未控制 App 偏好；源码指纹未包含 suite 的 selector 文件，旧叶子默认被删除重建；全局 `summary.json` 为无锁读改写。资源侧则把多个高分辨率 Simulator 与 XCUITest Runner 同时留在 Booted 状态。
- **解决**：✅ 已修复（2026-09-04）。全巡游首启与软重启统一传 `-v51.followSystemAppearance`，由 `RootView` 返回 `nil` 直接跟随系统；最终八台首页做 Light/Dark 灰度交叉验证。矩阵指纹纳入 selector 文件；同叶子旧证据移动至 `build/v51/matrix/failures/`；总摘要加 `flock` 并从有效叶子重建。最终执行保持最多两台 Booted、每设备单 worker；原失败保留后同设备同外观复跑。
- **验证**：最终指纹 `b504b985de5f44161d85872c75866f793637f406a68803be807d4d7c71b24406` 下，A 级 16/16、1,056/1,056；B 级 12/12、36/36；聚焦 Light/Dark 16/16、AX5 4/4。八台 `01-training-home` 的 Light 灰度均值 178.68–238.07，Dark 为 16.76–43.43；双 Runtime 安全单测 2,270 项失败 0。
- **日期**：2026-09-04
- **规则改进建议**：系统状态必须同时验证“设置回读”和“最终渲染”；矩阵 resume 只复用完全相同的源码+测试范围指纹；并发摘要用锁，历史失败用归档；资源异常先降低 Booted 数量再判断产品。
- **已应用至**：✅ `.cursor/skills/simulator-matrix-qa/SKILL.md`、`scripts/run_simulator_matrix.py`、`QiuJiUITests/ScreenshotTourUITests.swift`、`QiuJi/App/RootView.swift`（2026-09-04）。

## FL-040
- **任务**：问题集合 v57 W2 — 标准手机矩阵证据隔离。
- **现象**：标准手机浅色 6 项中 1 项失败；动作选择页已出现且按钮存在，点击前面板被关闭，随后找不到动作按钮。
- **根因/边界**：同一时段主控用 Computer Use 尝试切换到空闲 iPad；Simulator 前台却被 Xcode 切换到手机，随后还发送了 Escape 和窗口快捷键。录像证明面板消失，AX 树仍为正常空训练页。共享焦点干扰是强嫌疑，尚未做事件级因果复现，不能称为已确定的产品缺陷。
- **解决**：停止所有 Simulator UI 手动操作，关闭补验 iPad；相同源码下原失败测试隔离复跑通过（1 项、0 失败、56.813 秒、exit 0，`output/v57/W2/phone-free-isolated.log`）。完整标准手机单元及其后矩阵继续复验，未加 sleep/重试或改生产逻辑。
- **证据**：`output/v57/W2/matrix/ios26-phone-light` 保留命令、原失败、AX 树与 `failure-strip.jpg`；复验输出单列，不覆盖原运行。
- **日期**：2026-09-05
- **回写目标**：`.cursor/rules/55-test-engineer.mdc` §经验教训 / Changelog。
- **已应用至**：✅ `.cursor/rules/55-test-engineer.mdc` v0.5 与 UI 规格 Changelog。

## FL-039
- **任务**：问题集合 v57 W2 — iPad 自由训练动作选择。
- **现象**：iPad 的动作选择行点击中间留白时不切换选择，完成按钮一直无数量；标准手机同一流程通过。
- **严重程度**：P2
- **根因**：`DrillPickerSheet` 使用 `.plain` Button，标签 HStack 的透明 Spacer 未声明矩形命中区。iPad 行为 580pt 宽，中心 x=516pt 落在标题结束 x=453.5pt 右侧的留白；默认命中不覆盖该处。初次测试的宽泛“添加”前缀还可能匹配弹窗外操作，改为明确动作名后仍复现，因而没有把产品缺陷归咎于测试。
- **解决**：在标签完整行上增加 `.contentShape(Rectangle())`，保留行中心点击与选择数量断言。失败 iPad 上“添加→保存→再次开始”和“最小化→恢复原选择”两项均通过，日志 `output/v57/W2/ipad-picker-fix.log`；相邻尺寸与完整矩阵正在复验。
- **证据**：`output/v57/W2/matrix/ios26-ipad-light-r2` 的 AX 树/录像；`output/v57/W2/ipad-picker-before.png`；修复后 8 张流程图在 `output/v57/W2/ipad-picker-fix/attachments`。
- **日期**：2026-09-05
- **回写目标**：`.cursor/rules/20-swiftui-developer.mdc` §经验教训 / Changelog。
- **已应用至**：✅ `.cursor/rules/20-swiftui-developer.mdc` v1.7、`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog（2026-09-05）。

## FL-041 — 位置测试混入 XCTest 自动揭露滚动
- **任务**：v57 W2 低位筛选补验。
- **现象**：SE 初始官方标题 Y=507pt，切到空模版后 Y=444.5pt，原 ≤2pt 断言失败。
- **根因证据**：点击前截图 83D4DEB1-E10C-42A9-8513-52369E65A343.png 显示“我的模版”被悬浮自由训练按钮遮挡；test.log 9.15s 明确 `Scroll element to visible`，随后才点击。入门/全部均保持原 Y。此失败不能证明内容切换自身漂移。
- **修正**：测试准备阶段先让官方、入门、模版三个完整控件位于悬浮按钮上方，再记录低位锚点。原 ≤2pt 断言及少/多/空/返回步骤均保留。生产源码未改；三尺寸补验正在重新运行。
- **证据**：`output/v57/W2/matrix/ios26-se-light-supplement` 原失败完整保留；复跑独立目录 r2。
- **日期**：2026-09-05
- **已应用至**：`.cursor/rules/55-test-engineer.mdc` v0.6 位置测试起点检查与 UI 规格 Changelog。

## FL-042 — 测试根页不一定存在 NavigationBar
- **任务**：v57 W3 首轮导航测试。
- **根因/证据**：深链 PlanDetail 是 NavigationStack 根页，无导航标题/返回项；reveal helper 无条件取 navigationBars.firstMatch.frame，两个测试在点击前即快照查询失败。`output/v57/W3/matrix/phone-light-first/test.log` 保留原失败，未对产品导航作推断。
- **修正**：先判断 bar.exists，存在时用其下缘，否则用 window.minY；仍检查目标 isHittable/底部 CTA 边界，原返回 Y 与折叠断言不变。复跑待验证。
- **已应用至**：`.cursor/rules/55-test-engineer.mdc` v0.7 与 UI 规格 Changelog（2026-09-05）。

- **FL-042 同批补充**：完整五方法首轮 4/5 通过，锁态启动检查错误地只查普通 CTA，未进入动作详情；实际 Pro 计划为“解锁此计划”。测试改为等待日序内容，并按真实 CTA 分支测量底部边界。原四条通过结果和锁态失败保留于 phone-light-full，完整复跑另存 phone-light-full-r2。原权限与返回断言未删减。

## FL-043 — XCTest 环境变量前缀导致深色取证误标
- **任务**：v57 W3 导航矩阵。
- **根因**：新测试只读 TEST_RUNNER_V54_APPEARANCE；Xcode 注入测试进程时使用去前缀 V54_APPEARANCE，因此 dark 运行仍传 -v54.forceLight。旧 W2 helper 已兼容两名，新 helper 未复用这一约定。
- **证据**：phone-dark 5/5 行为测试通过，但 14 张实际截图均为浅色；左侧空白边缘灰度均值 243。图片视觉核对发现后，停止后续调度，让当前 AX5 子测试正常结束，再终止暂停的驱动（exit 143），未打断 XCTest 或改产品。
- **修正**：读取 V54_APPEARANCE 并兼容 TEST_RUNNER 前缀；图像门禁增加实际背景灰度的外观检查。旧错误深色目录在新增检查下 14/14 明确失败，保留原绿色图像门禁为 image-gate-before-appearance-check.json，证明新检查会抓出原失误。
- **状态**：七单元同源码矩阵重跑待验收，不将旧 phone-dark 计为深色通过。
- **已应用至**：.cursor/rules/55-test-engineer.mdc v0.8、UI 规格 Changelog、review_navigation.py（2026-09-05）。

## FL-039 补充 — W3 阶段标题宽屏留白命中（2026-09-05）

W3 ipad-light 五项回归中四项通过，阶段折叠在首次行中心点击后仍为已展开。原日志、点击事件、截图保留于 output/v57/W3/matrix/ipad-light。chapterHeader 含 Spacer，标签未声明完整 contentShape，iPad 行中心为透明留白；与 FL-039 同类。已在 Button 标签完整 chapterHeader 上声明 Rectangle 命中区，保持原中心点击和折叠断言不变。待 iPad 原失败及相邻尺寸复验。已应用至既有 .cursor/rules/20-swiftui-developer.mdc § FL-039 规则；本次是该规则补充实例。

## FL-044 — SwiftUI 测试宿主的容器生命周期
- **任务**：v57 W4，保存条目刷新 UI。
- **证据**：se-light-first 原日志/诊断保留；StandardOutputAndStandardError-com.xinkuan.qiuji.txt 明确 SwiftData BackingData fatal：model instance was destroyed by calling ModelContext.reset。菜单和加入今日安排2项通过，首次保存entry时退出。
- **根因**：DEBUG宿主以普通let创建ModelContainer，视图重新构造可换容器，而@State session保留旧容器模型，旧context释放后对象不可用。不是计数算法异常。
- **修正**：容器改为@State绑定宿主身份，与session同生命周期；保留真实SwiftData保存删除、原0→1→2→1→0断言。复跑待验证。
- **已应用至**：.cursor/rules/55-test-engineer.mdc v0.9 与UI规格Changelog（2026-09-05）。

## FL-045 — 元数据增高压缩网格卡标题
- **任务**：v57 W4，类型与次数同行。
- **证据**：31单测通过，但render-contact.jpg小屏有次数卡的同一动作标题被压成一行省略，0次卡仍为两行；不能仅据单测绿交付。
- **根因假设**：新增胶囊提高meta固有高度，网格对卡片的纵向提议压缩标题；titleMinHeight只保留框高，没有要求完整卡片采用固有纵向尺寸。
- **修正**：仅BTDrillGridCard声明fixedSize(horizontal:false,vertical:true)，保持实际列宽、两行标题约束及其他卡片不变；待同一12图渲染和真实界面复验确认假设。
- **已应用至**：.cursor/rules/20-swiftui-developer.mdc v1.9 与UI规格Changelog（2026-09-05）。

## FL-046 — 旧球库测试未声明付费页面的会员前置
- v57 W5改前取证复用W4_BallPaletteUITests，拍照建球形现为Pro入口，旧测试未forcePremium。AX树明确位于“解锁球迹 Pro”，随后找不到paletteBall__1，不能解释为球库故障。
- 修正：仅提球测试增加既有-forcePremium与隔离内存store参数；产品权限未改。原日志/AX/截图保留output/v57/W5/extraction-before-failure-*，复跑独立r2。
- 已应用至：.cursor/rules/55-test-engineer.mdc §FL-046；UI规格Changelog（2026-09-05）。

## FL-047 — 为收紧球库放大球体并增高底栏，造成主次比例失衡
- **用户反馈**：球库占比过大，球桌占比明显不对（2026-09-05）。
- **原因**：将“球更集中”实施为40pt视觉球/44pt槽，并在提球窄屏增加横排操作行；只验证间隙、命中和可见性，未守住球桌主要面积和球库辅助占比。
- **处置**：撤回6个视觉/布局测试文件到W4最终指纹，保留被否决补丁/截图/测试事实于output/v57/W5/rejected-density；旧通过不得用于R07验收。恢复后重新分析；当前未称修复完成。
- **已应用至**：.cursor/rules/20-swiftui-developer.mdc §FL-047、UI规格Changelog；用户修正已进入问题集合_v57.md R07。

## FL-048 — 虚拟账号界面测试触发真实云同步并被401退出

- **任务**：v57 W6，内存空库的Pro账号卡测试。
- **证据**：output/v57/W6/profile-r2-process.log，进程41221在21:34:19–20收到401；附件AX显示游客。AuthState虚拟身份完成登录后，AccountDataCoordinator在无游客数据时发起同步，APIClient认证失效通知清除该身份。
- **修正**：APIClient仅DEBUG且显式-v53.authenticatedProfileFixture时抛离线错误；虚拟身份不访问真实服务，正常401/刷新逻辑保留。R3原失败UI通过，截图已目视；真实认证仍由独立测试验收。
- **已应用至**：.cursor/rules/55-test-engineer.mdc §FL-048、UI-IMPLEMENTATION-SPEC Changelog。

## FL-049 — Live Activity 时间文本挤压锁屏其他文字
- **任务**：v57 W7；用户真机指出锁屏进度已变化但其他文字消失。
- **根因**：日期区间 Text 的布局提议与水平 fixedSize 不兼容；仅取消水平 fixedSize 恢复标题/数字后，动态文本仍会占用右侧空间。
- **修复**：普通等宽时间模板决定宽度，动态 Text 置于 overlay；紧凑岛不再固定40pt。新增标题/品牌可见性断言。
- **验证**：system-display-test-r4-raw.log exit0，四张系统截图已目视，锁屏2:49→2:07且动作名/品牌完整，紧凑岛收窄、展开单行。仅此iOS26.2模拟器；真机新版本仍待复测。
- **已应用至**：.cursor/rules/20-swiftui-developer.mdc § FL-049（v2.1）。

## FL-050 — 离屏 SceneKit 投影诊断缺少视口与姿态同步校验
- **任务**：v57 W5 诊断工具；未修改生产相机。
- **原因**：零frame创建的SCNView离屏投影使用1×1视口；变更相机/anchor后未flush时投影缓存仍为旧姿态。仅检查测试exit0会产生错误noFit统计。
- **修正**：非零frame初始化、显式layout、每次姿态及anchor后flush，前后光轴中心断言；r8 1例/36组完成，前轮统计全部撤销。
- **证据**：output/v57/W5/CAMERA-DIAGNOSTIC-REPORT.md；r6中断不算完成。
- **已应用至**：geometry-spatial-reasoning/SKILL.md FL-050。

## FL-051 — 自动取景替换姿态曲线，漏验纵向升降
- **任务**：v57 W5，用户指出默认视角更低、纵向滑动只剩缩放。
- **根因**：framedAimingPose 固定 pitch、radius/height 同比缩放；求解器采用0.30m高度下限，低于既有0.45m瞄准配置。原测试只验横向环绕，未验纵向姿态变化。
- **修正**：用户再次打回额外叠加角度方案，撤销。恢复原22°–45°俯仰曲线与40°–50°FOV；自动取景只在原45°观察端求距离/居中，空间行程按取景结果缩放，最低观察高度沿用1.5m配置。首次/换题落观察端，手动仍沿原曲线升降。
- **证据**：vertical-before-raw.log，新增纵向测试1例1失败，pitch在滑动后仍为-40°；第一次改后3/4单测通过，持续渲染测试未等动画落定失败，且方案已被用户否决；最终 original-curve-tests-raw.log：4单测+1 UI通过（TEST SUCCEEDED）；包含215几何场景、18姿态、原曲线五档对拍、升降往返和生产renderUpdate持续帧保留手动状态。3张场景原图与6张真实训练页图已目视；仅iPhone SE/iOS26模拟器，真机手感待复验。
- **已应用至**：.cursor/skills/geometry-spatial-reasoning/SKILL.md §FL-051；UI规格Changelog。

## 2026-09-06 用户最终裁定：撤销自动取景
- 用户明确要求自动取景也恢复，效果不接受。已撤回DR-092相机方案及FL-051两轮后续方案。
- CameraRig、AngleSceneView恢复HEAD原文；SceneAiming恢复原enterAiming、锚定及键盘结构，保留球库宽度/辅助答题按钮修改。
- 新求解器和专用诊断测试移出编译目录并归档到output/v57/W5/withdrawn-camera；重新生成工程。此前自动取景测试是已撤销方案的历史证据，不代表最终交付。
- 回退验证完成：原相机3项单测通过；最终重新编译并运行3题真实训练页UI通过，6截图已核对。CameraRig/AngleSceneView与修改前HEAD逐字一致，证据camera-rollback-source.json、camera-rollback-tests-raw.log、camera-rollback-final-ui-raw.log。恢复旧视角与键盘覆盖行为，不再保证三目标自动入镜。 不再继续设计新取景方案。


## FL-052 — 心得sheet键盘工具栏缺失
- 证据：output/training-input-flow/ui-raw.log，trainingNote.dismissKeyboard不存在；failure/note-end.png显示正文/键盘已呈现但无收起入口。
- 修复：TrainingNoteView使用焦点控制的safeAreaInset收起区，避免sheet内toolbar未呈现；增加键盘存在和编辑/收起/键盘边界断言。
- 复验：ui-r2与final-se通过；最终增强断言见verified-se-raw.log。后续标准手机结果见REPORT.md。
- 已应用至：.cursor/rules/55-test-engineer.mdc §FL-052、UI规格Changelog。


## FL-053 — UIKit心得字号未遵循页面字体契约

- 首轮SE编号UI断言通过，但截图se/input-drill-note.png显示巨大文字且前两条不在可视区；不能认定视觉通过。
- 根因：新UITextView使用系统preferredFont及自动缩放，模拟器系统AX字体与SwiftUI页面标准字体不同，导致局部字号膨胀。
- 修复：匹配Typography.btCallout/btBody的标准类别16/17pt；增加六行高度上限断言，保留自动增长下限与文本内容断言。恢复共享品牌色收起图标。
- 最终复验：output/numbered-notes/REPORT.md；初版图与日志保留，不作为最终视觉证据。
- 已应用至：.cursor/rules/55-test-engineer.mdc §FL-053、UI规格DR-102。

### FL-053 用户纠正与环境核验
用户指出小屏放大可能为模拟器设置残留。实测simctl ui 030E0CC1-AF30-400B-940B-0C6231E5753D content_size为accessibility-extra-extra-extra-large；17Pro为large。此前未先核验/恢复普通小屏环境是执行遗漏，不应把巨字图当成正常小屏缺陷。已将普通SE恢复large并读回确认；专用AX模拟器未改。UIKit与现有固定字号Token对齐属于组件一致性，不等同于必须通过代码修正模拟器设置。最终普通小屏证据应使用恢复large后的新轮次。


## FL-054 — 动作行功能通过但视觉退化仍被接受
- **任务**：DR-109/DR-110 今日安排与计划动作行，P2，视觉返工中。
- **现象**：左侧44pt空占位挤压正文；剂量拆为多行、行高膨胀，整体留白和阅读节奏退化。执行者看到截图后仍以内容完整和导航通过接受布局，用户再次指出。
- **根因**：将视觉审查降为可见性检查，没有独立评估整页密度与图文比例；没有落实实施到UI Reviewer的自动切换。
- **规则修复**：20-swiftui-developer新增功能后的视觉门禁、原图检查及否决项；57-ui-reviewer补自动触发。不能以新增规则代替当前UI返工。
- **状态**：规则已补；页面视觉未通过，尚未完成重新设计及截图验收。证据：用户本会话截图及output/drill-layout-final/se-attachments/。
- **日期**：2026-09-06

FL-054补充（2026-09-06）：用户指出流程表述漏掉正常测试，已显式恢复构建/静态检查/按风险选择的功能与边界回归，视觉作为补充门禁；修复后复跑受影响测试和截图，避免过度转向只看UI。

FL-054再次返工：首轮把剂量移到图片下方，用户指出错行，撤回视觉通过判断。最终修复改为图片列与文字列明确分离，名称/剂量共用左对齐线；证据改用output/drill-layout-aligned/，前两版保留为失败记录。

FL-054最终局部复验：图片列/文字列重排后，SE深色3项和17Pro浅色4项UI通过；关键原图已核对名称/剂量同列及箭头居中，见output/drill-layout-aligned/REPORT.md。先前失败结论保留，未宣称真机/iPad/AX通过。


## FL-055 — 皮革子网格保留整桌缓冲导致 iOS 17 日志洪泛崩溃
- **任务**：v60 W1，2026-09-10。
- **现象**：几何结构测试和部分首帧通过，但连续进入每日清台/打三时于 `__C3DMeshDeindex` → libtrace runtime-issue callback 崩溃。
- **根因**：每个皮革子网格仍引用整桌177346个位置；iOS17逐个报告未被元素引用的顶点，15秒日志26万余行，触发高日志量隔离回调。不是模拟器资源不足，也不能靠禁用诊断解决。
- **解决**：逐独立索引通道压缩到实际使用的属性，逐字节保留每个多边形角点的位置/法线/UV和面序；缓存紧凑几何，实例材质隔离。新增全角点字节守恒与无未使用位置测试，iOS17三个实际页面复验通过。
- **证据**：`output/pocket-leather-integration-20260910/W1/compact-fix/`（最终归档）；首次日志/崩溃另存，未删除失败记录。
- **已应用至**：`.cursor/rules/20-swiftui-developer.mdc` SceneKit兼容性要求。


## FL-056 — 把局部渲染改善误判为参考质量达标（2026-09-11）
- **任务/状态**：v62，用户否决后返工，未解决。
- **失败**：相对原版改善、功能/构建测试通过后，主控给出2/2/2/1/2并结束模拟器目标；用户真机审阅明确指出与Shooterspool仍相差很远。
- **根因**：验收把目标缩窄为相对原版提升；缺少每轮与桌面参考的直接图像差距检查，自评分替代了参考质量证据。
- **处理**：撤回画质达标结论、重开持续目标。每轮保存同镜头/球位/曝光A/B，并同时展示用户参考；不以测试通过、成本小或修掉单个几何缺陷宣布总体视觉达标。拒绝的候选及理由保留。
- **已应用至**：`.cursor/rules/57-ui-reviewer.mdc` §FL-056，以及问题集合v62.3/UI规格/进度/执行记录。

## FL-057 — 接触遮蔽参数超出 iOS 17 模拟器缓冲绑定上限
- **日期/任务**：2026-09-11，v62 S69→S70，兼容修复；整体画质仍返工。
- **症状与证据**：S69 功能、相机隔离和播放测试通过，但实际截图中 TaiNi 整块缺失。日志报告 constant buffers 21 > simulator limit 14，Plane_001 pipeline 编译失败。此前旧系统证据 S19 早于接触遮蔽接入，不能覆盖当前候选。
- **根因/修复**：16 个独立 float4 shader 参数分别占用绑定；S70 用四个 float4x4 按列传递相同数据，方程与资源不变，仅更新变化组。
- **回归**：新增 testCandidateClothRenders 实际渲染固定球位并检测台呢像素。未修生产时为0、断言失败，修复后通过；iOS17实际页面及慢速/多球/落袋原图恢复台呢。证据 output/render-quality-v62/S69-ios17-regression、S70-contact-buffer-pack；日志 S69-cloth-red.log / S70-ios17.log / S70-ios17-ui.log。
- **边界**：仅观察到模拟器限制，不据此断言真机同样失败；像素门禁只证明台呢绘制，不证明画质或60fps。
- **已应用至**：.cursor/rules/55-test-engineer.mdc §FL-057。


## FL-058 — 双球视觉对照二次摆球后未固定母球姿态

- 2026-09-11，S98静态双球遮蔽诊断首轮：scene辅助函数固定姿态后，再次applyBallLayout触发reseatCueBallHome随机朝向，开关组红点不同。审图及时发现，未采用或宣称画质通过。
- 修正：在最终applyBallLayout后调用setCueBallHomeOrientation，再拍完整12图；S98-fixed.log通过，重拍原图已审。首轮保存在S98-ball-occlusion并标INVALID-COMPARISON，不能当同条件证据。
- 后续：视觉fixture必须在最后一次重摆球后固定姿态；不能仅依赖scene创建辅助函数中的固定。生产未改。

## FL-059 — 规划页截图测试停在会员弹窗仍报通过（2026-09-12）

- **来源**：v63 W03 consumers-ui-r1，PlanThree/Snooker两张原图为Pro弹窗，工具结果却通过；属于测试覆盖失败，不能计作台面验收。
- **根因**：旧openCard只验证首页卡片可点，launchClean清除Pro后未注入目标页面所需权限，也没有目标台面断言。
- **处理**：S2布局套件使用既有-forcePremium测试夹具；进入后必须确认table.scene存在且可点、没有解锁Pro弹窗。原失败覆盖证据保留，补测consumers-ui-r2。截图迁移至output并让写盘错误显式失败。
- **规则改进建议**：布局/视觉回归必须核实目标内容，而非只核实入口点击成功；会员入口测试与目标页面布局测试明确分开。
- **已应用至**：`.cursor/rules/55-test-engineer.mdc` § FL-059（2026-09-12）。
- **状态**：✅ 测试覆盖缺口修复。consumers-ui-r2两项0失败/TEST SUCCEEDED，打三与防守目标台面原图均已打开确认；不代表规划全流程已验收。

## FL-060 — 球贴纸仅检查正面导致单侧号码遗漏（2026-09-13）

- **用户反馈**：六套设计粗糙，要求改用文生图，贴图不得自带高光，每球两个号码必须位于相对位置。
- **实查**：旧build_ball_stickers.py只在UV中心画一次号码；旧底色无烘焙灯光，但展示预览带灯光，不应与底色混为一谈。旧测试只看正面和切换行为，未覆盖球背面。
- **处理**：保留旧资源/证据；文生图生成数字图稿，Blender投影到归一化球的±Z，修复折叠UV后EMIT-only导出底图；补正反双侧可读性和无烘焙高光检查，重新验收。
- **规则改进建议**：球面贴图必须验证完整旋转与相反面，原始albedo和光照渲染分开展示；功能测试通过不得代替视觉验收。
- **已应用至**：`.cursor/rules/55-test-engineer.mdc` §FL-060；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog（2026-09-13）。
- **状态**：🔄 双面号码与集成已修复并验证；照片级视觉仍未达标。

## FL-061 — 球桌White共材质误染台呢置球点（2026-09-13）

- **现象**：深色瞄准点首轮按White材质整体染色，实际训练近景显示台呢上的置球点也变深。
- **根因**：材质名不等同于单一视觉区域；White同时覆盖库边和台内标记。
- **修复**：改色限定于有效X-Z台面外，台内保留原始diffuse；不改几何。
- **证据**：output/table-styles-20260913/contrast/ui-r1；修复后rail-only批次。
- **已应用至**：.cursor/rules/55-test-engineer.mdc § FL-061（2026-09-13）。


## FL-062 — 球杆风格缺少实物分区依据（2026-09-13）

- 用户要求实物分区与更清晰剑纹；曾错误解读为否决主题导致原图未使用，本轮按确认恢复原图。尺寸变化候选已移出App资源，源USDZ未改。
- 重做五小头/五大头的木材、插花、握把、环饰；单独核对剑纹前节，追加用户要求的加密/加深。
- 强制检查点已写入 `.cursor/rules/57-ui-reviewer.mdc` §FL-062；完整处理及验证边界见 `CUE-STYLES-20260913.md` 与 `IMPLEMENTATION-LOG.md` 同号条目。


## FL-063 — 着色器参数未隔离函数声明（2026-09-13）
- 台呢换色参考光照截图出现洋红球，r2测试断言通过但视觉失败，未作为有效预览交付。
- 根因：在含全局函数的Metal surface shader前增加#pragma arguments后，未用#pragma declaration结束参数区；SceneKit把函数内声明误解析为外部参数。
- 修复：按本机Apple SCNShadable.h契约分开参数/函数/主体，新增实际渲染洋红坏色断言；保留r2日志与原图，重新出片。
- 已应用至：.cursor/rules/55-test-engineer.mdc §FL-063；ClothAppearanceTests与UI规格Changelog。

FL-063复验：unit-r3与se-ios17两系统四项材质测试通过；六张图坏色像素均0，标准/SE/iPad实际页面无着色器错误，修复完成。原失败证据保留。

## FL-064 — 外观组合预览近墙遮挡
- 日期：2026-09-13；严重程度P1；位置：设置的球房/球桌/台呢预览。
- 根因：旧无房间预览正交机位加入房间后部分图像平面越过近墙。
- 修复：相机沿原方向移入房间，四角边界已算；最终实际截图待验。见tasks/SETTINGS-APPEARANCE-20260913.md。

FL-064验收补充（2026-09-13）：最终标准/紧凑/iPad三轮UI及原图均通过，近墙遮挡和滚转已消除；状态✅本地修复。证据见tasks/ui-reviews/UR-20260913-settings-appearance.md。

## FL-067 — 自由击球母球进袋后球库不能补回（2026-09-13）
- 严重程度P1；FreePlayView把离场母球与只读目标球同样拦截，规则自由球提示无法执行。
- 候选修复只开放非每日清台离场母球；真实页面击球/回放/切2D补球测试运行中，未验收。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md §DR-242；详情IMPLEMENTATION-LOG同号条目。

## FL-068 — 详情首杆解算期间可播放空桌（2026-09-13）
- P1，DrillSceneController.setup把首次摆球推迟到异步解算结束，play却已可调用；实页p1-playing-state原图为空桌，原按钮/HUD测试仍通过。
- 候选修复：立即摆保存球形并建立重播起点，晚到预览只在idle重绘。无挂起即时播放单测通过0.424s，标准实页暂停流程48.786s通过，改后原图已查看有球；SE/iPad未验。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md §DR-246/FL-068。

## FL-069 — 收集只看球心导致已接触软袋的球无限下落（2026-09-13）
- c039第4杆完整序列测试发现，未判捕获的object下落至Y=-1033m，触发15s上限，整段导出被拒绝。
- 已定位球体与软袋截面接触而球心在外；DR-253按真实半径圆截面相交修复，3项针对测试通过，完整序列/六袋复验中。
- 已应用至：geometry-spatial-reasoning SKILL §FL-069及table-geometry §DR-253。

FL-069复验：完整8杆实时/编码113.321s、六袋边界与正常入口通过，67.233333s视频成功。✅ 固定无限下落缺陷本地修复；其余v63物理/页面范围保持未完成。

## FL-071 — 默认9球开球失败且3D提示被覆盖（2026-09-13）
实页9球种子17829163102452725902在默认8.0力度出现penetration(0.0011684512086055138)，0.34930834秒终止，单测精确复现。3D普通说明覆盖失败文案的分支已修、状态测试通过；底层开球失败及修后实页截图未闭合。证据与反馈契约见IMPLEMENTATION-LOG DR-284。

FL-071补验：DR-285按球体前缘提前接管，原9球种子已完整停稳且5次交接无超预算重叠；六项回归及当前SE最大字号真实15/9球UI通过。固定缺陷✅本地修复；其他物理与跨平台性能不外推。


## FL-072 — 支架杆末快照与跨线程回调（2026-09-15）
真机连续八杆随机丢失支架球；主线程正常收尾与SceneKit渲染队列同时写库存，fix-r3/r4 .ips确认。自有递归锁与显式杆末提交候选复验中；取消仍回杆前。立即弱引用判空被裸SCNNode对照证明前提过严，修订为主线程有限等待后仍须全释放。见 IMPLEMENTATION-LOG FL-072 与 W16-device-20260914。

FL-072最终定向验收（2026-09-15）：真机fix-r5六项通过，含八杆四档4638帧；optimized-final-r6全部23核心+3UI通过，库存/动作释放也通过。此前竞争与杆末漏球在本轮复验闭合；完整平台/持续性能边界仍见W16-device-20260914。

## FL-073 — 开球进袋球未跨杆保留（2026-09-15）
真实 runner 开球复现，非 recorder 尾段单测：共享入口漏传库存，交付又清空。已修；模拟器 25 项通过、真机三宿主恢复定向测试通过，实际 UI 续验见 `tasks/3d-v63/W17-break-rails-20260915.md`。完整 v63 未完成。

FL-073最终定向复验：真机核心1项14.298s、独立UI1项110.109s通过；初次UI自动化初始化超时单列保留。gate/doc-size/diff通过，手机正常启动。

## FL-074
- **任务**：角度与瞄准竖屏视频
- **现象**：镜头过近、导出未带页面屏幕标注层。
- **根因**：把隐藏操作控件扩大为删教学信息，SCNRenderer遗漏UIKit叠层。
- **状态**：⚠️ 静帧返工中；恢复生产标注并拉远机位，待视觉复核。
- **日期**：2026-09-15
- **已应用至**：`.cursor/rules/55-test-engineer.mdc` § FL-074；详见`IMPLEMENTATION-LOG.md`。

## FL-076 — 动画球的阴影参数晚一帧

- 日期：2026-09-15；用户指出球像跳起。
- 根因：MobileContactOcclusion 在渲染回调中嵌套显式 SCNTransaction，球体动画已进入当前帧，而材质 contactGroup 参数延后生效。模型/阴影参数读回一致仍不能证明GPU实际帧一致。
- 证据：SCNAction 8m/s、120Hz取13帧，最后一帧与相同时间/姿态再次渲染相比，最大通道差184；去掉嵌套事务后 <=3，5项通过，移动/停住原图已核对。flush与调整回调阶段均无效，候选日志保留。
- 修复：保留 didApplyAnimationsAtTime，在现有帧事务中直接更新变化的矩阵；不改球高、物理或回放轨迹。最终两倍平面灯下标准模拟器与iOS17各5项通过；真机最终复验见报告。
- 已应用至：`.cursor/rules/55-test-engineer.mdc` §FL-076；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。
- 证据目录：`output/canopy-light-20260915/lag-{red,flush,willrender-r2,no-transaction}.log`，最终 `output/double-table-light-20260915/`。

## FL-077 — 序列视频误用旧离线外观
- 日期：2026-09-16；高级蛇彩15球视频，用户指出背景、灯光未对齐。
- 根因：SequenceVideoExporter显式mobileRendering=false；旧studioLook并非当前App灯光，且未接contactOcclusion渲染委托。
- 处理：暂停黑背景成片；为本视频显式开启App外观（球房、标准桌、绿台呢、当前面灯、接触阴影），重新审静帧再导出；旧封面作废。
- 状态：✅ 本地成片返工完成；最终导出1测0失败，45张MP4抽帧检查通过。见 tasks/ADVANCED-SNAKE-VIDEO-20260916.md。
- 已应用至：.cursor/rules/55-test-engineer.mdc §FL-077。

## FL-078 — 切点辅助线平行参照误读（2026-09-16）
- 现象：将用户要求的切点辅助线画成水平；用户明确纠正为垂直。
- 根因：把“现在的线”误指向水平参考虚线，实际应平行白色竖直瞄准线。
- 修正：固定 x=contactPoint.x，端点 y 与白色瞄准线一致；红点与原水平参考线保持。
- 规则改进建议：同图多条线时，平行关系必须明确参照线的颜色、方向和作用，再用端点向量验证。
- 已应用至：`.cursor/skills/geometry-spatial-reasoning/SKILL.md` §FL-078。

## FL-079 — 把短程滑动减速度当作全程「硬能量界」（2026-09-17）
- 现象：六球 v4 阶段 1 规划器把母球可达距离上限写成 v²/(2a)，a 取实测「自由运动减速度」中位 1.962 m/s²，并在报告中把由此产生的 `beyondEnergyRange`（第 3 段起约 30% 的失败）标为「真硬界」。
- 根因：减速度样本全部来自 <1 m 的刚出手/刚碰撞行程，处于纯滑动相；1.962 = µ_s·g（0.2×9.81）恰好等于滑动摩擦，与滚动相 µ_r·g ≈ 0.098 m/s² 相差 20 倍。滑→滚转换后母球在台面尺度上几乎不受距离限制，「硬界」是对测量口径的误读，不是物理。
- 修正：能量模型改为两相（滑动段按 µ_s 与自旋状态计到滚动速度，随后按 µ_r），并新增长程自由运动探针（多速度、多自旋，测到停或到远端库的实际距离与到达速度）实测校准；删除单一 a 的 ballistic 剪枝。
- 规则改进建议：任何被标为「硬物理界」的剪枝，必须先回答「这个系数对应哪一相、样本行程是否覆盖了目标行程尺度」；实测中位恰等于某一常数（如 µ·g）时应视为该相的信号而非全程有效。
- 已应用至：`.cursor/skills/geometry-spatial-reasoning/SKILL.md` §FL-079（同日）。

## FL-080 — 两杆清台预览机位偏离规范、球杆穿库（2026-09-20）
- 现象：用户指出 r1 的摄像头角度/高度不符合要求、球杆与桌框重合，并要求正常速度。
- 根因：研究预览擅自选用 60° 自动全桌机位及 0.5×；绘制球杆时硬编码 elevationOverride=0，绕开生产 requiredElevation 的库边/球体避让。r1 的物理复验与编码通过不能证明画面符合用户规范。
- 修正：r2 使用已保存模板 30°、距桌心5.10m、离地3.35m、垂直FOV40°，1×，1440×2560/60fps；每杆计算并冻结生产避让仰角，blocked则拒绝导出。先检查两杆瞄准静帧，再验成片。
- 规则改进建议：复用已确认的机位数值与避让入口，禁止为了研究导出强制球杆水平；验收必须包含第二杆近库瞄准帧。
- 状态：r2 静帧及完整导出各1测通过，全片解码/编码抽帧通过，见video-r2/REPORT.md；范围仅研究视频入口，不修改物理引擎。


## FL-081 — 清空桌面未使首碰预览数据失效（2026-09-21）
- 新增缓存生命周期回归发现clearTable只清可见节点，freeAimContact与特写gate保留上一球。
- 修复：空桌刷新首碰覆盖层，一并使contact、几何key、gate失效；不删除失败断言。
- 证据：`build/daily-final-optimization-20260921/`；修复后最终复验见等画质报告。
- 已应用至：`.cursor/rules/55-test-engineer.mdc` §FL-081、`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

## FL-082 — 性能夹具对象标识错误与证据层级混用（2026-09-21）
- **任务**：每日清台持续性能v2.1电脑纠偏。
- **现象**：局部阴影SceneKit首轮2测试通过，但实际drawable中只有阴影没有球；此前又把模拟器整场景命令跨度负结果扩大为算法本身无效。
- **根因**：测试使用`showBall(key: "cue")`而生产键为`PositionPlayBall.cueKey`（cueBall），guard静默返回；仅材质程序存在/测试完成不足以证明目标对象参与渲染。整场景/单项、模拟器/原生GPU证据未充分区分。
- **处理**：首轮保留为`correction/local-scene-invalid`，排除性能/视觉结论；改用生产键并断言唯一可见母球，重跑验收记录见DAILY-CLEARANCE-CORRECTION-20260921。新增同计量路径drawable读回、导出实际程序；原生Metal隔离实验显示指定夹具R/S存在收益，撤回算法必然无效的泛化结论。
- **规则改进**：性能夹具须用生产对象ID并断言可见对象集合；另一次snapshot不可替代计时drawable；输出须区分单项GPU成本、完整渲染路径、整页/手机功耗，某层负结果不得代替其他层结论。
- **已应用至**：`55-test-engineer.mdc` § FL-082。

### FL-082 续：真机采样起始窗口（2026-09-21）
- 首轮组件排序的首段0帧后仍继续采样，最后测试宿主异常退出；失败原始数据已保存。修正诊断夹具先确认前台active及15个实际绘制帧，再预热计时；不足11帧/出现GPU错误的窗口立即终止，不能接着生成貌似完整的排名。
- 修订时误将前置逻辑插入无rankingMode参数的另一帮助方法，构建发现后移除；复建通过。生产代码未变，重测使用独立attempt2证据目录。

## FL-083 — 每日清台候选球影分层与横屏透视未充分验收（2026-09-23）
- 用户真机截图指出球影呈波纹、近远球大小差异过强。先前全图均值、固定盘面与性能通过，不证明近景低角度视觉成立。
- 球影重点嫌疑为S的8条Gauss积分，未逐像素证明用户原图的唯一根因；本轮撤出手机S候选，以R恢复原directShadowShader作对照。保留台呢与亮度候选，并明确整套输出不等于早期A。
- 镜头使用每日专属DEBUG配置：FOV40/50改28/32，半径及高度按tan(old/2)/tan(new/2)约1.460/1.626倍后退；默认配置不变。全桌仍按真实viewport拟合；观察入口改为读取实例配置以避免切换跳回旧镜头。
- 模拟器同机位三组对照1项0失败3.691秒；实页2D/3D瞄准轮与休眠1项0失败18.808秒；目视镜头近远差异减小、原影更连续。不是用户原盘面复现，不宣布手机视觉或性能验收。
- 下一步：真机用户确认球影/镜头，再测R+台呢+亮度+镜头组合性能；不得沿用RS的GPU与60Hz结论。
- 规则改进：性能候选必须包含低角度、画面边缘近球及运动球影局部检查；用户视觉打回后冻结晋级、分别对照材质与相机变量。
- 已应用至：`.cursor/rules/55-test-engineer.mdc` §FL-083；`tasks/UI-IMPLEMENTATION-SPEC.md`。

## FL-084 — 每日清台3D终局结果栏收缩（2026-09-24）
- **任务**：每日清台交互与规则 v2 W7，截图审查。
- **现象/严重性**：P1；实际进9完成，结果栏被压到左上角，与返回/标题重叠。功能测试能找到“再来一局”不足以证明可用。
- **根因**：3D场景迁到全屏底层后，中央ZStack在终局没有内容，overlay继承零尺寸。
- **修复**：中央容器显式占满GeometryReader；终局UI测试追加结果按钮位于下半屏、宽度与可点击断言。
- **证据**：修复前 `build/daily-clearance-interaction-v2/W7-r3/rules-nineBall-complete.png`；修复后 `W7-r4/rules-nineBall-complete.png` 已目视，结果栏正常位于底部。
- **状态**：✅ `W7-r4/test.log` 22项控制器/存档测试及2项实际开球/双玩法终局UI通过；位置/尺寸/可点击断言和截图审查分别通过。

## FL-085 — 低位相机打点盘锚点使用台呢高度（2026-09-24）
- **任务**：每日清台交互与规则 W2/W4 联合截图审查。
- **现象/严重性**：P1；第一人称中面板底部覆盖近库上表面，顶部回合标签遮住上方向键。
- **根因**：投影使用台呢平面而非库鼻高度；低机位放大高度差。回合标签没有避让打开的打点盘。
- **修复**：投影Y采用 `surfaceY + BTTablePhysics.cushionHeight`（现有0.037m真源）；打点盘打开时隐藏回合标签，不改变物理球径或打点。
- **证据**：修复前 `W4-final/preset-pad-shotCamera.firstPerson.png`；修复后 `W4-final-r4/preset-pad-shotCamera.firstPerson.png` 已目视。
- **状态**：✅ W4-final-r4 实页联验1项通过：双预设打点盘、缩放边界、关闭打点后手动接管及击球保留视角。图中近库可见，上方向键无遮挡。

## FL-086 — 共享打点盘投影坐标与固定宽度导致近库遮挡（2026-09-24）
- **任务**：每日清台交互与规则 W8。
- **现象/严重性**：P1；竖屏求解器3D打点盘底边压近库，基础可点击测试不能发现。
- **根因**：窗口投影与SwiftUI global转换存在原点差异；仅改局部投影仍未解决。固定336pt面板超过投影球桌可用宽度，底边求交退回屏幕底部，才是复验中持续遮挡的直接原因。
- **修复**：同场景浮层使用带深度检查的局部投影；按投影球桌跨度收窄面板，再求近库内沿交点。每日分层HUD保留窗口坐标转换。展开打点盘时隐藏相机图标，避免图标叠在方向键后。
- **证据**：W8-final共享竖屏UI通过；W9-small共享竖屏UI再次通过，shared-reflection-pad-3d.png已目视，近库无遮挡，机位图标不再重叠。
- **状态**：✅ 已修复并复验。

## FL-087 — 连续重开沿用旧目标袋口，击球持续不可用（2026-09-24）
- **任务**：每日清台交互与规则W9实际连续开球回归。
- **现象**：第二次开球完成后无轨迹、击球禁用；等待40秒仍未恢复。
- **根因**：loadBoard为编辑/重打保留仍在桌上的目标及有效编号袋口；新一局同名球位置已经变化，原袋口几何不再可行，且没有重新执行临时自由策略。
- **修复**：BreakFlowRunner交付回调先让宿主应用规则裁决，再对启用自动进袋策略的VM重新评估合法目标和最近可行袋口；不更改普通快照重打的参数保留语义。
- **证据**：W9-standard-r2重复失败，xcresult附件及failure-frame.png留存；W9-standard-r3同用例通过（45.045秒），4项合法目标/临时自由单测亦通过。
- **状态**：✅ 同一连续重开UI修复后通过；保留失败日志及录屏，不以放宽时序掩盖生产问题。

## FL-088 — 皮革只验顶部近景，遗漏台内低位观察（2026-09-24）
- **任务**：球桌材质v64皮革用户视觉返工。
- **现象**：正常打球距离颗粒消失，中袋内壁呈模糊浅色面；原顶部近景通过不能覆盖用户截图。
- **根因**：旧0.89mm名义单元在实际投影中偏小；验收中袋眼位位于桌外，没有从台内看侧壁。源色斑是次要贡献，底部宽明暗仍含模型/照明响应。
- **修复**：扩大到2.32mm名义单元，淘汰硬碎块r3，接受圆润r4；增加正常距离/内壁/角袋/动态采样，保留几何明暗，不通过全局增亮抹平。
- **验证**：最终27次定向测试执行0失败（含iOS17），原图已目视；用户已认可r4并授权正式应用，视觉返工关闭；生成默认复现哈希一致，真机性能独立待验。见tasks/materials-v64/W5-皮革内壁返修.md。
- **已应用至**：`.cursor/rules/55-test-engineer.mdc` §FL-088；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

## FL-089 — 模拟器导出通过测试但仍输出旧配色（2026-09-24）

- 事实：V015 A版首次900帧导出1测0失败，但frames.json仍为red且缺少black/white字段，成片验收拦截；源码已是A版，构建日志包含编译及链接。安装缓存为假设，具体根因未证实。
- 处理：错误产物隔离至output/pipe-aiming-A-final-20260924/rejected-stale-install；只卸载本任务专用模拟器上的com.xinkuan.qiuji，触碰对应源文件后重新构建导出，最终A版原生1测0失败（113.104秒），900帧版本/几何及完整解码通过，编码后抽帧确认暗红圈/黑管道/白标注。
- 规则改进：导出测试成功仅证明流程成功，仍须用实际产物及版本字段验证本次改动；失败不得覆盖验证期望或混用旧帧。
- 已应用至：.cursor/rules/60-devops-release.mdc § FL-089（2026-09-24）。

## FL-090 — 为提示新增占位行缩小每日2D球桌（2026-09-25）

- 用户打回：DR-330新增32pt状态/提示行，把原44pt顶部区域扩大为76pt，2D球桌随之缩小，违反既有球桌最大化要求。此前视觉通过结论撤回。
- 根因：将提示不盖袋口置于最大化约束之上；验收只检查文字/遮挡，缺少台面尺寸基线，错误地把缩桌称为布局取舍。
- 修复：恢复44pt顶部与原sceneSize，状态/消息改为非布局overlay；消息、模态出现/消失不得影响stage.frame。
- 验证：定向UI增加stage高度不小于viewport减44pt、提示前后/模态关闭后frame一致；截图与原最大化基线对照，结果记录在提示体系报告。标准屏/小屏各2UI及最终标准屏/iPad各1UI通过，台呢像素边界与原基线一致，FL-090关闭。
- 已应用至：docs/design/feedback/提示与弹窗规范.md、tasks/UI-IMPLEMENTATION-SPEC.md、swiftui-design-system技能DR-330。


## FL-091 — 旋转近景只验运动，未校准球体质感（2026-09-27）
- **任务**：V019母球旋转视觉验证。
- **现象**：用户否决首版母球的发灰、哑光和缺乏立体感；运动/编码通过不代表近景视觉可用。
- **原因**：直接放大整桌使用的母球渲染，未先核验独立球体特写的明暗转折、灯板反射、贴图瑕疵与接触阴影。
- **处理**：回到单球静态对照；同机位比较原版、仅粗糙度变更与独立近景灯光/PBR候选。仅改导出夹具，生产默认不变。
- **状态**：⚠️ 视觉返工中；候选待用户审看，不认定修复完成。
- **规则改进建议 / 回写目标**：`.cursor/rules/55-test-engineer.mdc`，近景先验体积/材质，再验运动。
- **已应用至**：`.cursor/rules/55-test-engineer.mdc` § FL-091（2026-09-27）。


## FL-092 — 将各球房统一替换误解为统一花纹（2026-09-28）
- **用户打回**：此前已逐房选款，r2却把三房统一为大人字纹；真机效果也未达到概念图观感。
- **原因**：丢失逐场景认可映射；用程序花纹近似和模拟器通过代替实际材质对照，未完成手机侧证据。
- **处理**：r3恢复赛事大人字、木质篮式编织、东方回纹边饰三份独立材质，保留认可原图；同机位前后对比与真机静帧独立记录。
- **状态**：r3分款与真机静帧测试通过后，用户再次指出纹样过大和粗糙；r4缩小花纹并细化纹理。r4再被否决为“毫无质感”，进入r5分离花纹/纤维的质感校准。用户随后认可r5赛事款；r6保留赛事款并延展细绒至木质/东方，后两款仍待实看，静帧不等于动态闪烁或温升验收。
- **已应用至**：`.cursor/rules/55-test-engineer.mdc` § FL-092；具体结果见 `tasks/ui-reviews/UR-20260928-carpet-styles.md`。


## FL-093 — 近库打点可达策略过严且保留无效选择（2026-09-28）
- **用户反馈**：仍有抬杆空间却拒绝击球；可用区未空时应自动调整打点，当前隐藏球杆。
- **已确认原因**：DR-338将普通上限硬设15°，直接复用12mm保守渲染包络；失效后保留原点并隐藏杆，无自动纠偏。按当前公式独立复算，球心距库10cm（球面净距7.1425cm）中心杆需17.58°，因此被拒绝。
- **其他发现**：nudge仅接受下一步已合法，旧点深入禁区时向上微调也不响应；constrained只查同一侧塞列，不能发现其他列可行点；球障碍横向偏移被保守忽略，库边按完整半空间而非资产有限断面；姿态仰角未作为本轮新增物理输入。后两项几何简化的实际误差还需资产对拍。
- **修正方向**：先校核真实杆/库包络与合理抬杆范围；统一返回可用区、自动修正点、杆姿；有效点保持、无效点就近纠偏，只有整个可用区为空才拒绝。自动修改应原子更新输入与预测，并防止边界抖动；只读历史保持数据语义。
- **状态**：⚠️ 分析完成，待实现；本轮未修改业务代码或重新构建App。旧35项通过证明旧策略自洽，不证明产品行为可接受。
- **已应用至**：`.cursor/skills/geometry-spatial-reasoning/SKILL.md` § FL-093。

FL-093 / DR-338 r2续验：30°及自动打点已实现；final核心37项与1UI通过，ui-final最终2UI通过，245664次实际模型顶点检查通过，最终四张页面图已审。报告tasks/ui-reviews/UR-20260928-cue-access-r2.md。关闭本轮实现返工，保留真机/用户视觉验收边界。

FL-093 / DR-338 r3续验：用户截图指出贴库高杆仍过陡，r2“安全即合理”的验收不足。已改实际模型分段包络+独立库边间隙+自动默认点姿态评分；39核心+3UI及补充2项通过，新增同球位前后侧视对比和降低角度反证。实现返工关闭，用户视觉接受、真机体验与倾斜动力学仍未验证。报告`tasks/ui-reviews/UR-20260928-cue-access-r3.md`。


## FL-095 — 自动推荐偏好误作手动选袋禁用条件（2026-09-28）
- **反馈**：看似可进的袋口被提示不可进；联合评分范围过大、排序不符合用户意图。
- **根因**：isStraightPocketAvailable复用评分候选，干净管道余量/中心球仰角/正容错被当作硬可行性。上一版测试只证明公式与自身假设一致，未覆盖手动难球和零余量贴库。
- **修正契约**：按母球距离逐球检查六袋，最小切角≤60°立即停止；全部难球才取全局最小切角，无可行线路才自由模式。手动球锁定、袋口不受60°限制；仅二维球/直库线段几何，不做轮廓搜索、姿态评分和物理预测。物理在选择提交后运行，代际检查隔离旧回调。
- **已应用至**：`.cursor/rules/55-test-engineer.mdc` §FL-095，`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。
- **验证**：最终结果见 tasks/DAILY-SHOT-SELECTION-R2-20260928.md；保留旧轮次日志，替换旧评分测试为新用户契约测试。

FL-095最终验证：28单元/状态+1项2D/3D UI通过，六袋编号与八种贴库方向回归通过，最终截图已审，gate/doc-size/diff通过。实现返工关闭，真机响应与用户争议盘面复看待验，未发布。见 tasks/DAILY-SHOT-SELECTION-R2-20260928.md。

## FL-094 r3 — 三视角截图通过但实际手势不符合预期（2026-09-29）

- **现象**：母球附近吞拖动、斜拖丢一轴、上下反馈相反、显式换目标没有沿新杆线观察、观察可转到地面/天花板；旧静帧矩阵不足以证明交互可用。此前轨迹见 IMPLEMENTATION-LOG 的 FL-094/DR-342。
- **根因**：宿主将不能移动的母球注册为可拖对象；原主轴锁和逐样本重启缓动残留；模式恢复和显式沿杆请求未分开；范围只验数值未验实际端点。
- **解决**：能力先于命中分派、原生二维增量立即提交、统一竖向符号、ObservationEntry区分restore/alongShot、观察初始俯角±8°；原生触控重跑并保留合法摆球、倍率记忆与击球生命周期。
- **状态**：最终79核心+三尺寸10次原生UI执行通过；iPad测试窗口坐标误判已定位并修正后全矩阵复跑，本轮实现返工关闭，真机手感未验；结果归档于 [修复报告](CAMERA-INTERACTION-FIX-20260929.md)。
- **已应用至**：`.cursor/skills/geometry-spatial-reasoning/SKILL.md` §FL-094 r3、`tasks/UI-IMPLEMENTATION-SPEC.md` DR-343、三视角方案v1.6。

## FL-094 r4 — 用户否决整体相机改版，恢复旧基线（2026-09-29）

- 用户明确反馈多轮修正仍不如整体调整前，要求回退；此前自动化／模拟器检查不能抵消实际体验否决。
- 处置：恢复 DR-337 C 档旧 CameraRig、旧手势与消费者接入，撤回 DR-339、DR-342～344；所有改版代码和证据留档。
- 状态：改版撤回，问题不按“修复完成”关闭；恢复验证见 `CAMERA-ROLLBACK-20260929.md`。后续改动需以用户认可手感为边界，小步比较，避免全面替换。

FL-093重新打开（2026-09-29）：用户指出贴库/相贴高杆被误拒绝。新增根因是球冠相切没有接入pose，且杆坐标a/b与固定世界接触高度混用；此前真实网格净空测试只证明给定错误姿态不碰障碍。须先验证接触姿态，再验证可达与净空；“后方正相贴全盘无解”旧断言不能作产品真值。只读数值反例与方案见IMPLEMENTATION-LOG本日记录，未实施。

FL-093 / DR-338 r5实施：已统一杆坐标接触变换、球冠相切杆姿与实际冠面，撤销“后方正贴全盘无解”错误前提。新增先验：必须先检查冠面真实贴合和母球不穿入，再检库/其他球净空；测试不能只复述当前错误pose。51核心+4UI通过，球冠外观收尾复验见crown-final结果。实现修复，不代表真机或完整仰杆动力学验收。


## FL-094 r5 — 修复复位/墙内仍不满足观察用途（2026-10-01）

- 用户反馈不同球形仍有问题，明确必须能看目标袋、视野更大，并要求第一性原理分析。
- 根因：标准注视母球+窄镜头不覆盖袋；上下轨道降眼会穿杆；入框不保证实体无遮挡；旧袋上下文和下一杆更新会干扰手动约束。
- 处理：Daily全局35°，两球与CAD袋嘴包络的动态构图、紧邻球角分离偏好、有界镜头和局部站位，固定眼位上下及entry冻结上下文；广义几何扫描、跨尺寸独立实体投影与真实原生截图分别记录。
- 自动化通过不等于所有盘面遮挡解决。最终交付与剩余模型/第三球遮挡边界见tasks/DAILY-CAMERA-FORMATIONS-20261001.md；真机与用户视觉验收仍单列。
- 已应用至：swiftui-design-system/SKILL.md §DR-337 r4 / FL-094 r5；docs/05、UI-IMPLEMENTATION-SPEC同条。

## FL-094 r6 — 投影数量不足以证明观察场景覆盖（2026-10-01）

- 用户指出场景仍不足；三个子智能体复核独立布局、连续几何与操作生命周期，主控补实际CameraRig诊断。
- 原3072为1024布局×3比例，相机节点场景没有实体遮挡，真实原生仅14球形。新增230条记录、6835第三球候选确认：detail缩回后零纵向输入改俯角；0.1mm球位变化使最终眼位改变22.26cm；84次resize/恢复中的4次丢袋；不占两段理想线路的第三球遮住约44%目标轮廓采样射线。
- 状态：⚠️分析与诊断完成，新缺陷开放，生产未修。2项诊断执行成功不是产品验收通过；转场接管、高杆边界与真实HUD另列未证实风险。
- 规则改进：按独立布局/重复投影/真实渲染分列，检验连续性、操作组合、零轴不变量、运行中resize和全盘遮挡；不能只加静帧数量。
- 已应用至：`.cursor/skills/swiftui-design-system/SKILL.md` §FL-094 r6；完整证据见`tasks/DAILY-CAMERA-COVERAGE-AUDIT-20261001.md`。


## FL-096 — 选袋轻量主库检查误拒贴库线路（2026-10-01）

- **状态**：本轮修复并回归验证；引入于尚未交付的袋口选择重构首轮。
- **根因**：加入有限主库球心管道检查时，只沿用内缩袋嘴采样；圆角鼻尖附近的可直进射线不在该小采样集内，导致已有64个物理进袋例全部失去推荐。不能把有限采样不足等同物理不可能。
- **修复**：有界候选保留开口端点及沿库相切点（最多8点），几何判定明确区分候选可用、硬阻挡与不确定。手动不确定保持球袋并只预测当前杆；不跑螺旋或翻袋搜索。
- **证据**：首轮build/pocket-selection-20261001/core.log保留失败；core-r2、core-final、core-final-r2及se17-core的DailyShotRankingTests包含原64个物理进袋断言，全部通过，输出RAIL_REGRESSION physicalPots=64 geometryAccepted=64。原物理断言保留，未修改袋口资产或物理引擎。
- **防复发**：增加库边几何过滤时必须同时跑近库物理金标准与相切样例；袋嘴候选未命中只能构成估计不足，不自行宣称不能进。

## FL-097 — 实际中间机位恢复后兑现旧目标（2026-10-02）

- 严重程度：P1；范围：每日两视角未转正候选。
- 现象：FP记忆保存connector中间pose后，横滑可能回旧entry眼位；新观看上下文可能继续完成上一上下文的connector。
- 根因：控制base与实际pose不一致，context变更只清记忆而未撤销pending motion。
- 修复：context增revision、清connector/memory destination并冻结实际pose；恢复/接管FP有eye差异时从实际pose重基准。
- 证据：独立状态复审反例与final-repair新增2项回归，23核心+5UI通过；旧两条P1修复已再次只读确认。完整C09/C10/S02不据此放行。
- 已应用至：swiftui-design-system §DR-348；实施记录、ADR-P18-04。

## FL-098 — 功能通过但近库FP遮挡与TP入口主体过小（2026-10-02）

- 严重程度：P1；范围：每日两视角未转正候选。状态：入口策略部分返修，r3最终图像已复验，TP远侧主体尺度及FP完整ROI仍开放。
- 现象：final-host formation3/13 FP中真实库体截断母球下缘；三个TP样例默认退到room远端，主体过小，不支持本杆精读。
- 根因：FP复用杆后0.90m/+0.13m旧入口，没有真实网格视线约束；TP把远端包络入框等同任务适合。
- 修复：FP明确入口使用实际table子树segment检查有限接触/下缘ROI，求可清视线的眼高，再冻结eye/lens；TP按实际任务包络可读区求更近的入口，稳定H/FOV不变。没有隐藏库体或修改杆/物理。
- 证据与边界：实际原图、失败编译尝试、复验与逐图结论见UR-20261002-two-view-camera及实施记录。有限ROI、采样fit、单设备图仍不证明全场/全域；真实遮挡不能靠pitch/FOV解决。
- 已应用至：swiftui-design-system §DR-348；原生整屏图须与功能证据分列。

FL-098 r3复验：52核心＋5原生UI通过，17张新候选整屏图已全部实审。fixture3/13母球接触区明显改善，fixture3最低轮廓仍紧邻库沿；TP台面变大但远端母球偏小，近推关注对象未闭合。**不关闭视觉返工，不转正**。原图/逐任务判定见UR-20261002-two-view-camera。


FL-098 v0.2返修：本杆入口比较较小球尺度，并优先两球投影轮廓分离；近端按两球AABB/HUD求径向约束。首轮只冻结insets导致viewport改变轨道的核心用例失败，已改冻结railViewport。新增摆球测试首版误用CanvasPoint.y=0.6超合法[0,0.5]，出现钳制/撞边断言失败；已改合法夹具，不放宽断言。独立状态复审发现moveDailyCue/dragMoved/nudgeBall绕过place失效逻辑，已补真实位移上下文失效；转场无解hold后下次输入可能瞬跳，已补suspended实际pose与revision。最终执行/图像见实施记录§7；FP完整ROI、长台精读/明显推近余量、连续安全/页面layout反馈仍不据局部修复关闭。


## FL-099 — 把桌参照连续轨道实现成本杆两球取景（2026-10-02）

- 状态：🔄 桌参照v1.5方向已实现并形成新版子证据，待用户舒适度/完整验收；不关闭或生产放行。
- 根因：误将“当前视角下球桌构图舒服”换成两球/袋包络fit和入口选向，并把固定眼高当硬要求。功能检查成功只证明错误模型的局部行为。
- 用户澄清：固定算法轨道＋自适应俯角；前进渐向第一人称感觉，需要靠近/降低/放平的联合变化。TP仍绕桌观察，不能自动转为沿杆FP。
- 处理：用户授权后按v1.5替换TP profile：桌/房间/实际HUD联合求r/h/pitch/gaze，55°固定镜头；远端总览、近端降眼/放平，首次全桌。TP记忆与FP杆上下文分离，layout改变下一有效输入从actual重接。新版62核心通过、6原生UI分别通过、46整屏原图实审，来源/尝试见实施§8；没有沿用旧58＋5UI/29图作为新版证据。
- 强制检查：TP依据桌/房间/布局生成，选球袋不改轨道；禁止继续调两球near/entryYaw包装成修复。联合检查距离/高度/俯角、进度语义和全过程构图，旧测试/截图不得记作新方案通过。
- 已应用至：`.cursor/skills/swiftui-design-system/SKILL.md` §FL-099；UI-IMPLEMENTATION-SPEC、方案/验收、PROGRESS与Hub。

v1.5复验保留失败：首轮误把重复选球重新推荐袋当no-op；原生θ校准遗漏UIKit识别前行程；初版far低平导致空地多；最终UI复位测试把实际heading与EulerY混比。分别修测试前提/手势helper、联合far构图及实际heading读取，不放宽有效断言；最终生产源码一致。TP低位近景允许局部裁切/库体遮挡，FP3/4/13完整下缘仍不足，FL-098开放；真机与连续mesh/connector安全缺证，完整38项与R/P未放行。

## FL-100 — 临时轨道进度改变但部分球形无实际退远（2026-10-03）

- 场景：DR-348 v2首轮真实UI触摸包6条5过1失败，vertical退远actual XZ位移4e-8m；scenario0/4明确LIMITED，而3/13高度增幅约0.87m。原证据 `build/temporary-shot-camera-20261003/ui.xcresult`、`ui.log:1397` 及原生录屏保留。
- 根因：far生成只尝试一个35°偏好俯角且固定gaze；近域r/H采样也粗。细草稿证实selection固定gaze/dr≥.10m下台呢最高23.87%，低于26.27%真实基准护栏；仅加网格点仍无解，必须联合取景中心/俯角而非放松主体尺度。
- 处理：engines正在实施有界r/H/pitch/gaze联合求解、近域采样与局部细化，加抬高成本；默认沿杆眼位与镜头不改，θ锁定不绕桌，80%球及台呢门槛保留。修后重跑实际失败、四球形和两尺寸；未通过前不把进度变化/回位成功记为退远通过。
- 强制检查：真实眼位必须移动，远端证据包括球/台面尺度和实际持触图；无解信息不能替代常规用户观察任务。

## FL-101 — 初始化自动第三人称被晚到布局取消且击球持续禁用（2026-10-03）

- 严重程度：P1；范围：DR-348 v2.1每日DEBUG候选；状态：修复中，未安装。
- 现象：首轮原生8项中4项在初始strikeEnabled等待失败，尚未进入推荐/透明俯视验收；4项显式按钮/手势通过。AX证明CompletedSolves=1、computing=false、autoEntry=1、moving=false，实际eye/FOV仍旧机位，与shotProfile.default不同。
- 根因：实际HUD/viewport晚于自动TP请求到达，TwoViewCamera.revalidateLayout同步清connector、冻结实际pose；CameraRig只在update前后比较转场完成，漏掉update外取消，VM cameraTransitionBusy粘住。接受请求计数不能证明已到达本杆默认机位。
- 修复：默认TP入口在未完成/未被用户接管时按最新有效布局重建并续接；真正取消须通知VM退出busy；既有手动观察的布局hold策略保留。正在实施并补时序回归。
- 证据：build/shot-camera-overlay-20261003/ui.log/.xcresult、initial-app.log、原始录屏/失败附件。失败记录保留，不延长等待掩盖取消，也不只清busy后把旧pose当默认。
- 强制检查：首次场景加载及2D→3D时检查实际pose到达沿杆默认、转场结束和strikeEnabled，再检查真实推荐、长按叠层。布局取消和正常完成必须分别覆盖。

FL-100 v2定向收尾：最终旧v2四球形真实退远及两尺寸相关UI已有通过记录（实施§9.3），progress不再代替actual位移；最新v2.1恢复lens/站位后需重新查看远端实际图，不复用旧尺度验收。本条强制检查继续适用。

## FL-102 — 场景通用clone触发自定义袋口节点初始化崩溃（2026-10-03）

- 严重程度：P1；范围：DR-348 v2.1透明俯视；状态：修复中，未安装。
- 现象：首个真实长按进入临时俯视即SIGTRAP，尚无透明图产生；原生ui-r2包8项6过2失败（另一项是力度重算测试待分析）。叠层不可据源码隔离或核心相机绿色放行。
- 根因：SCNNode.clone递归调用copyWithZone，触发Swift自定义PocketLeatherMarker.init不受支持入口，崩溃栈指向AngleTrainingScene.makeTemporaryTopDownRenderScene；不是GPU负载或背景alpha问题。
- 修复：递归创建普通SCNNode，复制冻结presentation与渲染属性，共享几何/材质只读，不调用自定义源节点构造器；新增实际桌模型复制回归，之后真实长按/透明PNG/原生画面复验。
- 证据：build/shot-camera-overlay-20261003/overlay-crash.ips、ui-r2.log/.xcresult；原始录屏保留为native-rail-recommendation.mp4。
- 强制检查：SCNNode派生类必须实走真实资产子树复制，不能只测试相机数学或空节点；本轮透明层须有未改PNG alpha和持触原生合成图。

FL-101定向收尾：修后core-r4实际79/0，原生ui-r2首次加载/四球形/分轴与真实杆末推荐六项通过；focused手选＋力度项也通过，验证actual默认与strikeEnabled，不以entry计数代替。未安装手机。

FL-102补证：clone-core-r2的42处世界矩阵误差0.99999994来自未呈现fixture新加marker的presentation identity；先真实渲染并前置校验静态model/presentation后，r3复制1项通过，最大矩阵元素误差0，源不变断言完整保留。首LP已不崩溃、原PNG桌外alpha0、原合成6袋/HUD/底层房间经独立实看；原native断言发现SCNRenderer底左到UIKit顶左的诊断Y映射缺失，修诊断后继续全LP复验，取景不变。

## FL-103 — 临时俯视释放后静止状态不唤醒新镜头转场（2026-10-03）

- P1，DR-348 v2.1 DEBUG候选；原生LP r2首TP hold/release全部通过，随后FP按钮已选中但主相机仍TP，15s等待失败，原录屏及失败帧保存。
- 根因：FreePlay的contentIsAnimating不含cameraTransitionBusy。FP入口仅创建connector，尚无实际SceneKit节点写入；画面idle时无事件唤醒displayLink，不能依赖其他场景变更偶然起帧。
- 修复：仅usesDailyTwoViewControls候选把VM cameraTransitionBusy纳入activity；成功请求显式唤醒，原完成回调false恢复idle。保原相机和叠层取景，不延长超时/削弱assertion。
- 强制检查：完整TP长按、释放、静止、FP转场、FP长按、释放、相反朝向重复，检查actual机位、busy和原生持触图。
- 证据：build/shot-camera-overlay-20261003/ui-overlay-r2.log/.xcresult与output/shot-camera-overlay-20261003/native-overlay-r2.mp4、overlay-r2-fp-timeout.png；修后r3正在执行。

FL-100/101/102/103定向收尾：标准完整LP-r3 1/0、SE最终2/0，4球形实际远端及8次两模式/朝向真实LP图经复审；main矩阵/FOV delta0、原3D/room保持、释放后FP新转场、alpha及1次snapshot均原断言通过。候选P1在该范围闭合，全连续域/FP原边界与手机体验不含在内。最终手机unavailable实际安装失败，不以签名构建替代安装。

## FL-104 — 第三人称保持契约被页面释放回调覆盖（2026-10-03）

- P1，DR-348 v3.1 开发候选；首轮原生 10 项中 5 项失败。核心控制器已保持 actual，但 VM 释放后无条件 requestPlayerView 再次归正。
- 修复：VM 仅 FP 释放重算正向，TP 释放只结束本次输入。补真实 VM 调用链测试及连续上下/左右、长按恢复原生回归；不放宽姿态断言。
- 强制检查：改变相机交互契约须追到手势→VM→Rig→最终节点整条链；核心数学通过不能代替实际页面行为。
- 证据：`build/landscape-camera-v31-20261003/ui-r1.xcresult`、`core-r3.xcresult`；最终核心 44/0、标准原生 ui-r4 10/0，VM 释放保持修复已复验。详 `tasks/ui-reviews/UR-20261003-landscape-camera-v31.md`。

## FL-105 — 第三人称近端只验入框，未验实体库遮挡（2026-10-03）

- P1，DR-348 v3.1；标准原生 r2 的 10 项通过后，放大近短库 approach 图仍见母球下缘被库体盖住，不能据测试绿判视觉通过。
- 根因：ShotRailProfile 近端只约束两球包络/袋嘴投影，没有使用真实球桌节点的视线检测。
- 修复：按眼位计算球体可见切圆，采样轮廓并用已有真实 table hitTest 检查；默认位必要时抬眼并重拟合镜头，近端生成时拒绝遮挡候选。缓存预留边界余量并有界退让视线，避免横转因插值微越界提前停止。预建执行，不增加每帧 mesh 搜索。最终 core-r7 44/0、ui-r4 10/0，同球形默认/近端大图已确认母球下缘露出；小屏复验另记审查报告。
- 证据：`output/landscape-camera-v31-20261003/screens-r2/landscape-v31-formation-3-approach-held.jpg`、`build/landscape-camera-v31-20261003/ui-r2.xcresult`。r2 与首 SE 两项属于修复前版本；最终标准截图位于同目录 screens-r4，有限截图/采样不等于全连续网格无穿遮。

## FL-106 — 球库提示动画覆盖母球模型基础比例（2026-10-04）

- P1；真实每日页面点击母球按钮后，节点 scale 从 0.0010945576 变为 1，放大约 913 倍。相机进入巨大球体而外表面被背面剔除，接触阴影仍按正常球半径绘制。
- 根因：TableBallPulse 使用 scale(to: 1.7) / scale(to: 1) 假设所有导入球节点的基础比例为 1；实际编号球约 0.9968，母球约 0.00109。
- 修复：保存节点原始三轴比例，提示/拖球按相对倍率运行；重入和布局/播放取消时恢复原始比例。不得把 USDZ 根节点比例重置为 1。
- 修前证据：build/simple-camera-20261004/pulse-native-before.log，原生点击后的比例断言实际失败 1 次；离屏 SCNView.snapshot 未推进动画，曾触发测试前置断言失败，不能作为运行证据。修后验证另记 v4 审查结果。

FL-106定向修后：真实母球库点击原生回归通过，原始比例保持且截图实体可见；导入各球中断恢复核心通过。证据 ui-final/core-final-r2。独立的贴库低位几何遮挡仍开放，不与比例缺陷混为已解决。

## FL-107 — 复用旧视频机位落到新球房墙外（2026-10-04）

- P2；V023 M208 首轮原生关键帧只有灰墙和标题，物理及导出测试通过不能证明场景可见。
- 根因：直接沿用旧视频5.10m/30°机位，眼位X=-4.417m，超出当前房间X±4m墙界。
- 修复：本片导出机位改4.20m/30°、竖向FOV48°，眼位X=-3.637m；重新生成起始/碰库/临袋关键帧，真实球桌与两球可见后才开始视频编码。未改生产相机。
- 强制检查：复用导出参数须核对当前房间真实边界及眼位，先检实际关键帧，不能用XCTest绿色代替内容可见性。
- 证据：`output/cue-scratch-m208-20261004/r1/manifest.json`、`frame-0000.png`、`frame-0191.png`、`frame-0454.png`；已同步60-devops-release规则。


## FL-108 — 俯视精确拖球丢失手势识别段位移（2026-10-04）

- P2，DR-348 v5实验候选；真实UI拖母球45pt仅移动35pt，原断言失败，未放宽容差。
- 原因：用UIPan进入began时的位置/translation还原抓取点，未保存touch-down原点；ended只结束拖动，未提交最后触点，造成手指与球位偏移。
- 修复：在手势delegate的shouldReceive保存该次pan的真实触点，保留球心抓取偏移；正常ended提交最终坐标再收尾，cancel保留最后合法位置。仍经原摆球合法性，不直接改球位绕过规则。
- 强制检查：要求精准拖放时，原生测试必须比较手指与对象实际位移，覆盖非中心抓取、正常结束及禁摆状态，不能仅断言“移动过”。坐标必须独立对照渲染器实际投影。
- 证据：build/merged-camera-20261004/ui.log修前失败；refine.log修后复验，最终计数见UR-20261004-merged-camera.md。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md § FL-108、tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## FL-109 — 曲面光滑不代表拖动响应均匀（2026-10-05）

- P2，DR-348 S1手机试用反馈：左右方向与用户预期相反；短拖不动、不同位置速度差异大。
- 根因：额外8pt/1.3分轴阈值丢失识别前输入且整次锁轴；travel两段线性距离映射在默认处出现约1.13～4.10倍局部速度差（已查样例）；平滑姿态公式没有约束屏幕速度。
- S2修复：横向符号反转；仅曲面实验改双轴直接输入，保存touch-down至ended位移；用固定台面地标投影运动量调节有界响应增益，在实际距离空间做中点积分，保持S1可达几何与默认位置。
- 强制检查：曲面验收除机位/松手保持外，必须核对操作符号、默认带两侧局部响应、同路径不同事件分包、45度斜拖与短反向。测试绿不能代替用户手感。
- 状态：S2最终12项定向测试通过，10-05 04:10已更新安装，用户手感待验；原始S1安装与测试记录保留；不因S2关闭FL-094的全域遮挡等旧问题。
- 已应用至：swiftui-design-system SKILL § DR-348 S2 / FL-109、UI-IMPLEMENTATION-SPEC Changelog。


## FL-110 — 封面镜像请求扩大为重新设计（2026-10-05）
- 用户要求已有封面配合视频镜像；首轮重排标题装饰与场景，用户重新发送原封面并确认只镜像。
- 根因：把系列样式参考当成重新设计授权，未锁定原图的保留区域。
- 修订：以用户原图为唯一编辑底稿，顶部标题/装饰保持原样，下方场景与小窗左右镜像、字形正向；cover-r1为历史，r2为当前待审。
- 验证：941×1672，标题/布局/文字方向目视检查，源副本SHA-256一致；生成式编辑不宣称像素相等，待用户验收。
- 已应用至：.cursor/rules/00-orchestrator.mdc § FL-110；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## FL-112 — 空闲帧判定扫描SceneKit动作时崩溃（2026-10-05）

- P1；S2最终原生复验进页时一次SIGSEGV，栈为objc_msgSend → SCNNode.hasActions → Coordinator.updateFramePacing子节点枚举（line873），非手势输入或相机公式。录屏显示进程已退出至桌面；不能只标为启动等待超时。
- 证据：build/camera-surface-experiment/s2-launch-crash.ips、s2-final-validation.log、s2-screenshots/launch-timeout.png及原录屏。未改源码的单独shot-retry通过，故复现并非确定性。
- 修复假设：主线程遍历动作状态期间，与SceneKit渲染线程释放/改变动作存储交错。以SCNTransaction全局锁保护图遍历与动作/动画复合读取；root已活跃时不再多余遍历。SDK SCNTransaction.h定义lock/unlock为global lock。不改变idle判据、不强制常驻渲染。
- 验证：补原有真实SceneKit动作唤醒/完成/重入空闲测试，并最终复跑相机核心与原生流程；s2-guard-validation.log最终12/0，未再复现。单次/有限复验不宣称所有SceneKit并发问题根治。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md § FL-112；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## FL-111 — 视频切角核验混用袋心与推荐瞄点（2026-10-05）

- P2；V023七例预览首轮静帧测试4处角度断言失败：导出器用袋心算角，图册字段来自dailyPocketCandidate所选有限瞄点，两者不是同一量。原碰撞/袋号/时刻复验保持一致，未改变球形或物理求解。
- 修复：推荐角沿原dailyPocketCandidate路径独立核验；视频切角改为实际入射方向与首次碰撞法线夹角，与渲染的接触假想球一致，manifest同时保存两种角。Python独立向量复算误差<0.0001°，最终静帧1项通过；未放宽旧断言或把图册数值强写进真实角度。
- 证据：output/cue-scratch-selection-20261005/r1/stills-initial-angle-check.log、manifest-initial-angle-check.json、stills.log；已在geometry-spatial-reasoning经验中补充口径。

## FL-112 — 沿杆第三人称被误做成固定桌端视角（2026-10-05）

- P2；V023用户说明“第三人称是指摄像头在球杆方向”。r1只采用固定桌端斜视，未随各球形实际杆向变化。
- 修复：r2眼位在母球后上方，眼位—母球与水平光轴均沿实际补偿瞄准轴，侧偏为0；不以母球—目标球球心连线替代。原生关键帧1项通过，Python独立共线/方向及物理不变核验通过。
- 范围：按用户后续要求只生成关键帧，未导r2视频；r1保留为历史，不再标作当前有效机位。证据：output/cue-scratch-selection-20261005/r2-cue-axis/。
- 已应用至：geometry-spatial-reasoning技能下方相机语义护栏。


## FL-113 — 中袋瞄准管道被台呢内部拼接缝截断（2026-10-05）

- 用户指出三条白线必须吃到库。上一版60°/75°端点停在X=0.634917m，未到真实短库；仅与旧版逐帧一致及编码无错不足以证明教学线达标。
- 根因：clothEnd取相连三角网格的首次出口，实测台面拼接边X=0.634917/0.636217m，约1.30mm内部缝隙被误判为台呢外缘。首轮1mm射线缝合未通过端点断言，失败日志保留。
- 修订：视频隔离导出器仅跨越物理击球矩形内部、沿射线≤2mm的小缝；真正袋口空洞保留，虚线末端补短实线。球位/机位/台呢模型不变，生产代码未改。
- 强制检查：三条白线分别记录端点；全角度序列检查平行、球径间距和实际边界到达，编码后复查大角度。与历史错误版字段相等不能替代新要求验收。
- 证据：output/feel-middle-standard-20261005-r2/mesh-seam-evidence.json、keyframes-failed-seam-tolerance.log、keyframes-build.log；最终全帧结果见该目录REPORT.md。应用于geometry-spatial-reasoning技能。

FL-112 / r3构图复验（2026-10-05）：用户进一步要求常规高1.10m/后退1.65m且仅调俯角。删除M066后，首轮1440×1916视口固定44°镜头下M007的8cm包络得分1.000906>1，原生断言实际失败1次（stills-initial-framing.log保留）。重排参数栏与独立1440×1800主视口，眼位/镜头不变、包络阈值不放宽；可行俯角中取最近常规看向母球角者，最终6例32.5–33.7°，原生1项通过、6图已审。视口比例影响水平视野，须连同FOV和机位一起记录。


## FL-114 — 曲面输入终点正确但连续运动呈阶梯（2026-10-05）

- 用户反馈切换连贯性差，并明确没有掉帧。此前空间采样、终点与状态测试不足以证明时间域平滑。
- 代码机制：手势事件直接写pose与节点，斜拖横/纵各提交一次；显示帧无输入重采样。4pt积分子步只影响数值结果，并不生成显示中间帧。按钮走眼位直线/旋转/FOV插值，没有沿曲面参数过渡。
- S3修订：目标输入与显示曲面分离，33ms短缓存按真实时间插值，不预测/不惯性外推；两轴合成一个样本，只有显示循环提交镜头；松手最多缓存时长内完成真实末触点并保持；新杆/俯视恢复取消旧样本；按钮沿曲面参数过渡，触控在当前可见点接管。
- 强制检查：60/120Hz固定显示节奏＋不均匀输入间隔的逐帧位移分布、末触点完整消费与无拖尾、手动打断按钮、新杆取消、快照恢复；不得再以几何/终点正确替代时间连续性。
- 验证：最终13核心（排除共享无关编译错误）通过，6组60/120Hz相对连续输入逐帧误差<1%；1场景+5原生UI通过，末次边界后2UI复验通过。Release/gate通过；手机手感待验，见UR-20261005-camera-surface-s3.md。此条不认定GPU掉帧或全场景性能问题。

V023相机FL-112 / r6续验（2026-10-05）：红框“剪短”首轮被解释为裁底部，用户澄清要调相机；裁切实验标废弃，保留完整9:16，改俯角/镜头。固定26°下M053轨迹包络触参数框10处，失败日志/图保留；通用有界俯角26–34°求最近不重叠解，最终26.7°，未放宽8cm包络/20px框余量。最终1测0失败。相机语义护栏已补充区分红框取景目标与裁切方式。


## FL-115 — 分轴左滑回归误用有符号角差（2026-10-05）
- S5首轮16核心+4UI通过，新增分轴UI最后左滑断言失败：实测angleDifference=-0.0355877rad，却写成>+0.005；同用例横向等高、竖向bearing及短反向已通过。
- angleDifference=atan2(sin(lhs-rhs),cos(lhs-rhs))保留正负，左滑应负。断言改为<-0.005，保留方向性；未改生产逻辑、未删除检查或放宽阈值。
- ✅ 修订后同UI完整复跑1项通过，方向隔离与左滑反向均通过；原始失败证据：build/camera-surface-s5-20261005/tests.log/xcresult，修订复跑见axis-retest.log/xcresult。
- **已应用至**：.cursor/skills/geometry-spatial-reasoning/SKILL.md § FL-115；UI实施规范Changelog。


## FL-116 — 相机模式写入争用与临时俯视反馈缺失（2026-10-05）
- 用户反馈四项：转镜生硬；3D/临时俯视手选球袋无反馈；临时俯视点球偶发整桌闪；普通2D拖动黑底3D。普通2D点球闪已被用户明确排除。
- 根因：simple入口将0.95秒压到0.3秒；桌面选球未接已有pulse；手动袋口延迟1秒且临时副场景未同步其动态状态；选择/预测revision重建副场景；updateCuePose经applyTwoViewPose无视普通2D投影所有权。
- 修订：共享0.95秒与五次缓动；VM成功选球统一pulse，手动袋口即时反馈；驻留副场景同步presentation及局部节点增删；CameraRig显式2D展示所有权。
- 护栏：先保留两项红色回归（投影、0.3秒截断），再检查源/副场景真实像素与恢复、节点身份稳定、原生拖动回调中正交投影、原有分轴与选袋语义。临时闪烁的重建机制被移除，静态截图不当作逐帧无闪证明。
- 已应用至：swiftui-design-system §DR-348 S6、UI-IMPLEMENTATION-SPEC、实施记录与S6审查报告；最终结果按报告回填。

FL-116兼容性回归：扩大到PerspectiveStateV63Tests后，testExplicitFocusReplacesSavedObservation原断言失败（2条）。全局update阻断影响旧宿主在2D预备显式focus；修订仅对TwoView控制器阻断2D时3D更新，旧宿主保留原流程。失败日志final-tests.log/xcresult保留，原断言不变，复验结果见S6报告。

FL-116最终验证：final-retest 47项0失败，含旧focus原断言；5个唯一原生UI分批通过。Debug-O/签名/手机安装启动通过，详S6报告；临时闪烁需用户真机继续观察，不以静态图认定全部时序问题已消失。


## FL-117 — 球心缩放穿台与presentation pivot重复（2026-10-05）
用户报告选球放大仍维持原球心高度。真实USDZ渲染回归复现1.7倍后球底低约19.93mm；TableBallPulse过去仅改scale。修订按世界Y通过视觉pivot上移R(s-1)，物理中心不变，并保留原基值供还原/打断。检查过程中发现presentation.transform已含pivot，旧俯视镜像及首版顶点oracle额外复制/应用pivot会重复抬升；按原生model/presentation日志修正，0.3mm球底断言不放宽。final38项通过，原生/安装状态见S7报告。首轮Rig速度测试初始化未提交相机姿态，已补正常display更新而非放宽速度界；额外用例类名错误0执行已纠正到真实类名，最终确实执行1条。已应用至swiftui-design-system与UI实施规范S7。

FL-117收尾：源/副场景球底与物理中心、原基值恢复通过；最终39核心＋4UI共43项唯一用例分批通过，gate/设备构建签名/安装启动通过，真机观感待用户试用。


## FL-118 — 点球取景不应依赖换球和可进袋（2026-10-05）
旧队列只在target变化且pocket可行求解完成后进入第三人称，漏掉重复点击和自由模式/无袋口回退；开球默认按钮回中圈而非最远端。S8以当前合法选择的几何瞄准请求曲面取景，并在临时俯视退出时消费；开球入口统一travel=1沿开球方向。
首轮新测试将Snapshot的当前可见travel当作目的地，在尚未推进渲染时断言0.5，导致6项断言失败；另将含context变化的revision当作自动取景次数导致1项失败。按真实API契约改为先推进显示循环、用自动取景计数及普通2D实际投影/变换验证，未放宽终点阈值。修订35核心通过；原生真实击球入口按钮等待仍诊断中。
已应用至：`.cursor/skills/swiftui-design-system/SKILL.md` §DR-348 S8 / FL-118；UI实施规范Changelog。最终证据见S8报告。


FL-118时序补充：checked/shot-diagnostic/shot-state的真实击球UI在初始按钮等待失败，最终原生诊断明确twoViewComputing=false、twoViewFeasible=true、twoViewCameraBusy=true、twoViewMoving=true、twoViewOrtho=true，眼位(0,5.8,0)。根因是SwiftUI Coordinator的cameraMode尚未同步时，旧2D显示回调在scene已转3D后重新applyTopDown2D，S6展示所有权锁随后让3D转镜无法推进。旧版等待异步求解后再转镜偶然掩盖此时序。修订TwoView渲染提交前必须与scene.currentCameraMode一致，过期帧不写相机；普通2D守卫保留。新超时诊断在XCTest断言前捕获，避免continueAfterFailure=false时defer未记录现场。复验见S8报告。


FL-118副场景补充：final原生临时俯视点袋口时一次SIGABRT，保留xcresult诊断及overlay-crash-stack.txt。malloc报告pointer being freed was not allocated，触发栈__BuildRenderableSourceChannelsAndSemanticInfos → C3DMeshBuildRenderableData → SCNRenderer，属于网格内部缓存构建。旧镜像直接引用source.geometry，主/副SCNView渲染队列共享同一C3DMesh。S8改为每个镜像节点保存源geometry身份，变化时用源顶点/索引数据创建独立SCNGeometrySource/Element/Geometry；维持材质引用以同步选袋反馈。静态节点仍驻留，不在每帧重建网格。原快照测试“共享geometry身份”断言被新缓存隔离契约替代，同时逐项验证顶点/索引data和材质未变；原球底、视觉反馈与源节点不变断言保留。待原生复验，不能把未再崩溃当作全场景保证。


FL-118视觉返工：mesh-retest的6核心＋2UI及stress六轮交互虽然通过，导出的原生“临时俯视选袋”截图却出现整桌三角形撕裂；该版被否决，未安装。原因是从USDZ geometry的data/bytesPerComponent等公开字段重建SCNGeometrySource不能保持其原生打包格式；数据字节相等不代表渲染解释等价。修订保留原生SCNGeometrySource/Element对象，仅创建独立SCNGeometry（C3DMesh缓存），仍保持材质同步。新增同一渲染器串行、相同镜头/光照下“独立geometry与原导入geometry”像素MAE<0.005对照，并保留原图；不能以UI状态/字节等价替代渲染验收。此前mesh构建曾因局部非throws函数内XCTUnwrap编译失败，改为显式XCTFail+guard，没有吞错误。


FL-118最终几何实现：仅由sources/elements构造新的SCNGeometry仍漏掉导入台呢，新增像素回归真实失败MAE=0.0867955，未放宽0.005阈值。最终采用SceneKit原生SCNGeometry.copy()保留完整Model I/O内部元数据，镜像保持独立geometry对象，并显式共享既有materials供反馈同步；7项源/副场景、真实球底及图像对照通过，像素MAE=0。原始SCNNode仍为基类，不clone源子类。后续原生压力与交付见S8报告。此最终实现覆盖前两种手工重建geometry的失败尝试。


DR-348 S8 / FL-118交付回填：最终43核心＋6原生UI，49项唯一用例分批通过；独立geometry原生复制相对原导入模型像素MAE=0，连续6轮临时俯视选球/六袋编辑通过，最终原图已审。delivery-gate、Debug-O设备构建、严格codesign通过。iPhone16Pro最终仍unavailable，未安装S8，手机最后交付S7；待连接安装及用户手感验收。见UR-20261005-camera-surface-s8.md。


## FL-119 — 首次3D经过相反方向的旧全桌机位（2026-10-05）
- 用户反馈：开球进入最远第三人称前先大幅转镜。
- 根因：场景首次3D兜底先应用yaw=π旧全桌机位，页面再请求沿杆曲面；旧测试只验最终落点，未验第一帧。
- 修订：展示所有权切换后、全桌兜底前由宿主初始化当前曲面；首次duration=0，成功后页面不发第二次请求；已有3D转镜保留速度策略。
- 修前构造性失败：实际VM链路6.207933m位置差、约180°方向差，普通/旋转2D均复现。验证与安装见ui-reviews/UR-20261005-camera-surface-s9.md。
- 已应用至：`.cursor/skills/swiftui-design-system/SKILL.md` § FL-119，2026-10-05。


## FL-120 — 更多菜单到透明度浮窗未呈现（2026-10-05）
新增透明度项首轮原生点击后大盘已展开，但附在Menu上的系统popover未进入辅助功能树，滑条存在断言失败（build/daily-spin-setting-20261005/standard.xcresult）。推断为菜单收起与popover呈现生命周期冲突；不通过增加延时或放宽断言掩盖。改为每日页面稳定根节点内的HUD浮层，透明拦截层关闭设置，滑条即时绑定持久化偏好。原生入口/端点/跨模式/重启原断言保留，复验见UR-20261005-daily-spin-setting.md。
- 已应用至：swiftui-design-system §DR-335 r5；UI实施规范与实施记录同条。

FL-120视觉补充：首版页内浮层功能流程通过，但TupleView布局将设置卡居中覆盖大盘；图审否决。改用显式ZStack(topTrailing)固定右上锚点，原生测试增加滑条处于屏幕右上区域的边界断言。滑条去除0.01离散步进以避免iOS26渲染密集刻度，保留连续调节及百分比读数。最终复验另记。

FL-120收尾：standard-final与compact-delivery分别在标准/小屏通过同一原生全流程，真实滑动、右上边界、模式共享、重启恢复均通过；最终四张设置原图实看，280pt实色深底读数清晰。1项默认与持久化单测通过，未安装手机。

FL-120 / DR-335 r6测试时序补充：紧凑面板standard原生测试在拖动后即时75±5%断言失败，但失败录像末帧显示77%。按SwiftUI辅助功能发布异步处理，增加最多3秒的条件等待，原70–80%阈值及重启保存断言不变；不使用固定sleep。证据与复验见UR-20261005-daily-spin-setting-compact.md。

FL-120/r6收尾：small-final、standard-final原生流程各1项通过；原百分比阈值保持、跨模式与重启恢复通过。标准/小屏2D/3D四张紧凑版原图已实看，详r6审查记录。


FL-120/r9：按用户要求改为按钮同款24%透明底后，原生流程通过，但截图发现底下小白盘透出叠在50%读数后。图审返工：设置打开时暂隐下方仪表列（保留布局占位），关闭恢复；不以重新加黑面板代替修复。最终复验见UR-20261005-daily-spin-glass.md。


## FL-121 — 每日清台特写漏保护与透视相交（2026-10-05）
- 用户截图显示特写遮住进球线，追加六袋、首库前母球线、完整球杆与2D台内边界要求；原keepout不含全部实际渲染几何，3D全屏投影未换算到中间stage，且旧soft fallback允许遮挡。
- 修订：每日页单独使用实际场景投影的硬障碍求解；整圆限台内，先缩小再隐藏；球杆近裁面裁剪+投影凸包。特写内部用桌面等比例映射保持2R相切，外部仍按真实相机摆放。
- 验证纠偏：早期UI通过却未实际打开特写（命令行字符串未成为Bool），图片作废；用DEBUG fixture设置真实偏好后重跑。按钮拖出不等于取消的错误测试假设已修，按释放击球、重建球形验证下一项。
- 已应用至：swiftui-design-system、geometry-spatial-reasoning技能末尾API/约束回填；最终测试和原图见ui-reviews/UR-20261005-daily-hud-avoidance.md。


## FL-122 — 每日2D→3D渲染视图重建黑帧（2026-10-05）
根因：同一scene分别挂在两个条件分支的SCNView，模式切换销毁/新建渲染器，3D首帧就绪前露黑底；原生录屏约70ms。修前实例身份UI在首个2D→3D断言失败（before.log），证明生命周期改变。修复改为单一结构身份、模式只改屏幕frame；后续验证见UR-20261005-daily-renderer-stable.md。
回写目标：swiftui-design-system技能；SCNView切换需验实例存续及连续帧，不能只验最终相机/静态截图。

FL-122验证补充：首轮修复推算stage高331pt而实际338pt，第二轮全屏被控件最小高度撑到382pt，均由严格frame断言打回；改为页面实际高度约束背景、中央stage实测全局坐标。final2两尺寸原生通过且无黑帧，但图审发现首次3D旧viewport构图一帧，追加布局时同步相机后复验。

FL-122收尾：稳定SCNView + 每日layout回调同步viewport/相机，修前身份断言失败、最终两尺寸3次往返和点球验证通过（小屏1UI、标准2UI）；最终录屏切换段黑场0，原约70ms消失。前两轮frame推算失败留痕，已改实测坐标；未装机/提交发布。见UR-20261005-daily-renderer-stable.md。

## FL-123 — 球桌适配提案未完整对齐参考页能力（2026-10-06）
- 任务：P01-A方案评审，用户打回r01。
- 现象：底部球库偏离每日顶部参考，进袋等入口仍常驻，未逐项纳入每日适用设置。
- 根因：方案只按空间与旧页能力安排，未建立参考页完整设置／状态映射。
- 解决：r02顶部球库、设置收纳及逐项能力对照；记录偏好范围、接线缺口、菜单显示置底实际组合与验证。仅方案修订，App未实施。
- 回写目标及已应用至：`.agents/skills/table-page-adaptation/SKILL.md` v1.1及任务卡模板；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog；2026-10-06。
- 证据：`tasks/table-page-adaptation/P01-SETTINGS-MAPPING.md`、`output/table-page-adaptation/P01/r02/`。方案遗漏已修订，原生实现及用户对r02完整体验的认可未完成。

FL-123 / r03视觉返工（2026-10-06）：用户指出r02球桌比例、左右对称和仅3D视角入口不符。根因是用抽象通用线框替代逐模式原图对照。已撤回r02布局图，重开原始2D/3D附件并在r03原样展示，锁定真实桌形、双尺等宽同有效区上下沿、打点位置和3D右外侧相机入口。设置对照保留；App未实施、不得称视觉通过。已回写table-page-adaptation v1.2与P01契约、UI实施规范；证据output/table-page-adaptation/P01/r03/。

## FL-124 — 自适应W1回归偶发临时俯视SIGBUS（2026-10-06，X未关闭）

- 首次W1 Pro16核心tour在打开临时俯视时退出，原ips为B6334AF8-FC8D-414B-BCE8-165EC2AFFDC1；SceneKit主renderer的C3DAnimationManagerApplyActions→CFGetTypeID地址0xa。主线程同期配置第二SCNView。不是此前Metal线程组SIGABRT，也无OOM证据。
- 只提取每日常量/等价公式的W1增量无scene/action改动；原selector重跑、W0r3对照和原S8六循环选球选袋stress均通过，但不能证明偶发故障修复或明确归因。首次SpringBoard截图排除golden，原日志/失败结果不覆盖。
- W1完整62静态状态补齐，同名frame/existence零变化；布局准入与稳定性分开记录。X保持未关闭，后续核心回归保留临时俯视路径，若再现须结合动作/overlay时序和内存诊断定位；不得删断言/扩timeout/禁Metal校验/禁功能求绿。
- 原证据与分析：`output/daily-adaptive-execution-20261006/evidence/W1-validation-pro16-core/`、`analysis/W1-scenekit-crash-review.md`、`analysis/W1-action-lifetime-review.md`、`evidence/W1-X-queue.json`。


FL-123 / lab-r01实验续记（2026-10-06）：用户授权隔离原生首版后，真实模型按每日横屏骨架落地。test-03发现自定义返回箭头未设置矩形命中区，AX只有10×18pt字形，中心点击无效；已对齐每日44pt热区，test-04／05正常路由返回通过。早期逃逸闭包编译及旧SCNView isHittable定位失败均保留。首设备两尺几何断言、设置与拖球／击球链路通过；用户体验与全尺寸尚待，不能自动结案。证据：output/table-page-adaptation/P01/lab-r01/REPORT.md。

## FL-125 — 顶栏临界宽度测试通过但中文标题省略（2026-10-06）

- W2r2/r3 Max受控header在T=749.066148pt显示“每日…”，T−1/T+1完整；AX label仍是完整“每日清台”，实际文字frame仅43.3pt。首次原图/日志保留，W2未按测试绿关闭。
- 根因证据：容量使用UIFont/NSString估宽59.533074pt，而SwiftUI实际自然宽59.666667pt；估值又被用作minimumScaleFactor的精确下界，恰阈值无法排入完整文字。改为同源SwiftUI Text自然量测，并恢复原regular文字fit行为；上层容量仍只预算原2pt压缩。
- W2r4构建/原边界selector通过，exactT=749.333333pt原图完整、AX57.7pt。候选尚未完成最终跨尺寸回归；W2r5补实际文字宽度断言和T±显示像素。
- 强制检查点：完整AX label不能证明文字未省略；容量边界须量测同一字体环境的Text，并核对实际排版宽/原图，禁止仅按估宽精确限制缩放后以语义标签断言放行。
- 已应用至：`.cursor/rules/57-ui-reviewer.mdc` §FL-125；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog（2026-10-06）。证据见`output/daily-adaptive-execution-20261006/analysis/W2-visual-review.md`与`evidence/boundary/`。


FL-125解决回填（2026-10-06，W2r5）：W2r5最终11单元/16测试退出0，114张原图逐张独审；冻结源`9e01a5e9c1f03b75b5d571e398ee3637808d85ce227d4cbf6879d07625c0cdfa`，双Pro58对geometry/existence零变化。MAE255范围0–0.0119321394553、均值0.0047279809951，仅描述差异。 同字体SwiftUI Text自然宽59.666667pt量测，regular保留原fit、上层仅预算原2pt压缩；exactT=749.333333及±1pixel/±1pt标题完整，恢复通过。iOS<26每日header尾延伸0、26保留24pt，共享Menu默认不变。iOS17 More44×44、mode67×41，实际边缘动作通过，AX描边仍0.5×41pt交集，不称几何零交集。27/32pt例外仅球库。 首次r2/r3省略与r4候选原证据保留；最终资格`output/daily-adaptive-execution-20261006/evidence/W2-qualification.json`及114图报告。只解决FL-125，FL-124/X不关闭。已应用至swiftui-design-system顶部DR349（主控完成）；见analysis/W2-closeout.md。

## FL-126 — 自适应面板的限高撑大 Pro 玻璃背景（2026-10-06，复验中）

W4r2首个Pro16 core原图显示透明度内容仍靠顶，但glass从原96pt撑到剩余页面高度；功能tour退出0不能放行。根因：外层ViewThatFits与maxHeight参与父提案，maxHeight被当扩张容器而非只限制自然高。主控在完整矩阵前否决，停止scheduler；当时已启动SE文字test独立结束，所有r2证据保留。修订为相同宽度、不限高naturalContent实测，只在自然高超过available时给ScrollView明确viewport，普通分支不挂maxHeight。尚待W4r3真实基准与大字号复验，不能标已解决。
- 强制检查点：卡片最大高度不是自然高度；普通候选必须先核对实际外框/材质边界，不能因文字/按钮本身通过而忽略背景铺满。隐藏自然测量不参与hit/AX，不改变字体约束；限高滚动与正常分支各验。
- 证据：output/daily-adaptive-execution-20261006/evidence/W4r2-first-pro16-core/screenshots/core-2D-transparency.png；analysis/W4-visual-review.md。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md §FL-126；tasks/UI-IMPLEMENTATION-SPEC.md Changelog，2026-10-06。

## FL-127 — 透明度卡片空白命中落到盘外关闭（2026-10-06，复验中）

W4r3 SE AX3四向键/回中通过后，卡片左内侧2pt点按+12pt拖动导致panel消失，底层aim/spin/velocity/count无变。同一W4r3 App纯UI专项在Pro16 AX3把动作拆分，实际panel(576,48,252,173.3333)，tap(578,134.6667)即关闭，尚未拖动；图与AX/状态保存。故不是仅拖动尾段或布局高度问题。卡片独立clear background空tap未建立整个可见卡的命中边界，当前候选改为卡片本体contentShape(Rectangle)+空tap，保留子Button/Slider原动作并必须实际复验，不以隐藏AX或SDK零issues替代。
- 强制检查点：弹层空白/边缘要逐步真实tap/drag并核对呈现和业务状态；background材质、isModal或AXframe不能证明事件拦截。子动作/slider两端、盘外关闭均需回归。
- 证据：output/daily-adaptive-execution-20261006/evidence/W4r3-first-se26-ax3-spin；W4r3-padding-pro16-ax3（纯UI诊断）。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md §FL127；tasks/UI-IMPLEMENTATION-SPEC.md Changelog，2026-10-06。

## FL-128 — 小屏增高设置卡遮挡相邻打点与相机控件（2026-10-06，复验中）

W4r4 SE最大普通字号原生text/slider测试通过，但独立原图审查发现100%卡片增高覆盖大盘右键，3D端点/slider与全局观察眼睛重叠。单个卡片文字完整不等于多个浮层共同布局合格。当前候选按264pt预览卡与252pt设置卡的真实横向容量做局部并列，保留相机48pt通道；Pro标准原位置无横交时保留。只移动卡片不移动覆盖整个stage的关闭层，世界坐标/桌面比例不变。尚待构建、同源基准、各字号及真实命中复验。
- 强制检查点：弹层增高要审相邻交互层/文字的组合，不以单项contains/hittable或测试绿豁免视觉遮挡；断点来自现有组件容量，不能按机型或全UI比例缩放。
- 证据：output/daily-adaptive-execution-20261006/analysis/W4r4-visual-SE-text.md；W4-paired-panel-design-review.md；W4-paired-panel-numeric-draft.json。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md §FL-128；tasks/UI-IMPLEMENTATION-SPEC.md Changelog，2026-10-06。

FL-128 r2（2026-10-06）：W4r5 SE最大AX测试exit0/33图，但2D3D设置卡(388,48,223,319)与击球(555,308.5,60,60)相交，原图独审否决；不得推进broad。当前R6候选读取击球在freeplay命名坐标系的实际frame，仅在水平相交时把设置最大高限制到其上沿减8pt间隔；自然高保持，超容量阅读区滚动、关闭键固定。新增对应不相交断言；待真实同源复验。证据：analysis/W4r5-maxAX-visual.md及W4r6-panel-height-draft.json。


## FL-129 — 打点卡可操作但越过小屏球桌内框（2026-10-06，返工中）

用户在W4r6图审过程中指出小屏打点盘过大、应位于球桌内侧，iPad应固定设计大小。旧验收只覆盖窗口内可见/命中和相邻设置卡避让，没有把整张打点卡对内框的包含关系作为产品判据；SE的264pt卡越过内框上边，并列时又贴stage而非内框。旧测试绿不能作为该视觉意图通过。R7候选以原未缩放2D内框的宽/高限定整卡≤264，白盘承担尺寸变化，44pt键和8ptpadding不变；并列的左极限取inner.minX，2D3D同锚。Pro实际容量够时保留264/160，iPad同上限；极小窗口最低操作容量留W6。
- 强制检查点：球桌相关浮层须检查完整外框对明确目标区域的包含，不只检查圆心/底锚/窗口可见；用户基准尺寸不能被误解为所有容器的固定最小尺寸。
- 证据：analysis/W4r7-inner-fit-numeric-draft.json、W4r7-source-review.md（位于output/daily-adaptive-execution-20261006），R6原图保留；候选未称通过。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md §FL-129；tasks/UI-IMPLEMENTATION-SPEC.md Changelog；方案v2.2（2026-10-06）。


## FL-130 — 容量与基准保护代替了设计语义验收（2026-10-06，返工待实施）

用户指出每日清台适配没有理解16 Pro尺寸的设计目的：桌面最大化、球库单行易点、按钮用好剩余空间、平板双尺合理定长及近方形重排。旧W2/W3主要证明放得下和基准不变，固定列/按钮/球径没有对应的空间收益评审。不能据此宣布整体适配完成。
- 本轮处理：v3替代未来排期；R0复审完成，W2/W3总体验收重新打开；保留文字量测、低高度动作重排、面板命中/避让等局部成果，不回滚全部工作。App修订未实施。
- 强制检查：每个尺寸标注硬约束/参考偏好/上限/弹性用途；审stage与实际桌框、宽高瓶颈、控件触点及剩余空间；近方形结构比较前移。历史测试绿和窄触点例外不能代替新语义验证。
- 证据：tasks/ui-reviews/UR-20261006-daily-adaptive-semantic-review.md；output/daily-adaptive-semantic-review-20261006/；方案v3。
- 已应用至：swiftui-design-system技能FL-130、UI-IMPLEMENTATION-SPEC Changelog、PROGRESS。状态：复审/方案修订完成，R1–R5待实施。

FL-123 / lab-r02真机返工（2026-10-06，F04）：lab-r01仅自身对称，没有同窗口Daily对拍；漏掉球库外沿锚定与镜像留白，误保留旧页面仅自由模式显示方向尺。现修正实验快照布局并接入已有临时自由状态机。初次同窗口测试已确认table.scene、双尺、打点、球库一致，但击球按钮AX范围61而Daily60pt；改用相同圆形contentShape与样式继续复验。已应用至 `.agents/skills/table-page-adaptation/SKILL.md` v1.3，页面卡和设置契约同步；未影响每日在途工作。最终验证见 lab-r02/REPORT.md。

## FL-131 — R1回收余量越过参考手机辅助动作阈值（2026-10-06，参考回归已修验）

- **任务/严重程度**：每日清台v3 R1；P2，参考Pro构图回归。
- **现象/证据**：candidate1构建与14项度量测试通过，但真实USDZ量测后回收1pt，将358pt控制区减至356pt，触发重打/回放横排。原始帧与布局JSON保留于 `output/daily-adaptive-execution-20261006/evidence/R1-candidate1-pro16-baseline/`。
- **根因**：只保护控件自然最小高度，遗漏纵排阈值的2pt余量；纯测试只覆盖默认外框，未覆盖实际加载外框的较窄Z尺寸。
- **处理**：Space回收预算同时保护当前动作排列边界；补真实外框参考输入测试。candidate2的16 Pro原生stage及七个关键控件frame与before一致，17 Pro同批基准通过；candidate3保留此分支并继续核心动作复验。不覆盖candidate1失败证据；R1整体候选是否采用另行记录。
- **另一个证据问题**：candidate1方形UI用例将144逻辑pt直接与iPad缩放窗口live屏幕frame比较，实际124.14导致失败；snapshot中两尺均144且同Y。candidate2分别断言逻辑144与live等长/端点，并同时保存两套frame；此修订不是把原失败记为通过。
- **规则回写**：`20-swiftui-developer.mdc` FL-131：回收剩余空间须保护离散布局阈值；模拟器窗口缩放须区分逻辑与屏幕坐标。

FL-131 / R1证据边界补充：candidate2极小窗口的父VStack AX标识覆盖了返回按钮标识；candidate3改为标题持状态标识、返回独立ID。首次candidate3返回用例又因测试从deeplink根视图启动而没有可pop导航栈，失败保留；h3使用真实训练首页→每日清台→返回路径，600×300与320×760两例均退出0并保存返回首页图。仅证明受控容器返回，不证明系统resize恢复。证据见 `UR-20261006-daily-r1-space.md`、`candidate3-harness3-tour.json`。


## FL-132 — Figma缩放工具验收未覆盖用户普通拖角（2026-10-06，已修复操作结构）

- **现象**：用户普通Resize后，SE方向条外框16×153、内部尺区仍44×174，发生错位。此前只测K缩放不能证明无需快捷键的操作体验。
- **处理**：保留用户布局与90张原始结构备份；用户版1215个控件用独立3倍透明图块、FIT填充、锁定比例。另建精调版恢复1215结构控件/3125文字节点。SVG中间方案丢失杆速圆角，目检后弃用。
- **验证**：桌面普通Move拖角：方向条38.69×153→49×194、杆速44×190→35×152，内容同步，随后恢复。转换/恢复错误0；粗调控件未锁比例0。这里只关闭Figma编辑操作问题，不代表布局被认可或App适配完成。
- **规则回写**：`.agents/skills/table-page-adaptation/SKILL.md` FL-132：按用户实际操作验收，区分粗调图块与完整精调结构；用户确认精调后才进入代码。

FL-132 / C19补充（2026-10-07）：C18遗漏竖向球桌Frame，外框609×1108、内图544×989固定不变。已将用户版9张竖屏球桌改为独立图块；普通拖角实测556×1012后还原609×1108及用户位置，非球桌改动0。规则补充：可拖拽交付盘点包含球桌/场景容器，不只HUD；检查旋转子图与外框是否同步。

FL-132 / C30补充（2026-10-07）：功能状态再次仅交付静态图册，遗漏用户可调整副本。已在用户文件03页新增20张独立FIT图块画板，普通V拖角及移动验收通过并还原；交付入口明确区分“只读图册”和“可调整Figma”，精调源保留矢量/文字。


## FL-132 / C35 — 跨文件图片引用存在不代表资源已复制（2026-10-07）

- 用户发现C34多屏没有文字。源稿图册正常，但目标用户文件44个图片hash中26个在1.2秒检查窗口内无法读取，影响32屏58对象；图层、尺寸、可见性均存在。上轮未全量验证目标文件图片字节与实际渲染，错误地以源稿导出和几何检查代替交付完整性。
- 原位修复：从精调源稿导出75控件及5底图完整PNG字节，通过本地插件createImage直接嵌入用户文件115对象；不依赖跨文件剪贴板异步图片加载。保留当前ID、位置/大小/旋转、透明度、锁定、比例及图层关系，几何差异0；用户其他页不变。
- 复验：全部图片字节可读，错误0；从用户文件实际导出40屏，75控件PNG非空；40屏提示区域目检完整，iPad横屏缺字原位实看恢复。与C34源稿40图对比最大平均通道差0.221/255（栅格化/采样差异），不声称逐像素相同。证据：output/daily-figma-workspace-20261006/c35/。
- 已应用至：.agents/skills/table-page-adaptation/SKILL.md FL-132/C35；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。之后跨文件交付须在目标文件验证图片字节、透明非空和全部状态实际渲染；资源缺失先补字节，不重排用户布局。

## FL-133 — 每日适配恢复候选的安全区与球库命中漏检（2026-10-07，已修复并定向复验）

B1/B2暂停稿恢复时，测试方向类型 `XCUIDeviceOrientation` 不存在，改用UIKit的 `UIDeviceOrientation`；球库父级identifier传播覆盖15个子球的identifier，改为独立透明AX探针。保留失败构建和before-pro xcresult。

r1/r2虽然窗口内断言通过，实图与源代码复核发现底部整体忽略安全区、竖屏操作组偏低；r3小屏单独球库采用过大球径，母球胶囊压住开球入口。修复2D尊重底部安全区、完整操作组围绕桌心且受安全内容边界限制、低矮横屏独立球库预留两侧操作通道；新增球库与开球/打点入口交叉命中断言。此类问题不能用“全在window内”替代safe bounds与跨组相交检查。

另两次测试失败属于测试假设：selection球形中的黑8在桌且尚非法，不是已进袋；短距离打点拖动尚未越过既有52pt移开手指门槛，不能据此断言拖动无响应。按实际规则及手势契约修正测试，不改业务策略来求绿。各轮证据完整保留于 `output/daily-adaptive-v4/B12-resume/`。最终状态见[B1/B2](daily-adaptive/B1.md)。

FL-133追加：iPadOS26窗口模式横屏虽top inset为0且AX在window内，系统窗口控制按钮仍覆盖自定义返回。关闭每日页在Pad上的隐藏状态栏策略，保留系统顶部区域后复验。窄窗测试同时统一使用snapshot逻辑坐标，避免拿缩放后的live window与逻辑球槽frame混比；补整卡落在inner rails及越过52pt门槛的实际拖动检查。

FL-133补充：图册原Pad横竖是浮动窗口，漏做全屏主入口。旋转通过和logical窗口等于屏幕不能证明全屏；应核验live窗口原点/范围与设备像素并实看桌面外边。已在同一r6构建最大化App后补全屏三态（pad-fullscreen-r1，1 UI通过），图册默认全屏、浮窗单独标注；生产代码未改。

FL-133 B3–B7追加：原透明度0端点的XCTest归一化手势停于5%，改为实际滑块越过轨道端点并读回0/100；旧仪表断言用共享6pt间隔推算，与每日4pt不符，改检查实框包含、120/144尺程及击球4pt/60pt关系。最大字号切玩法确认真实超出小屏，增加锚点两侧容量和标题滚动、固定按钮；最大字号菜单测试整屏滑动跳过目标，改有方向的小步拖动并仍要求整行可见及可点击，保留首轮失败。新修复复测状态以B7/B8为准。

FL-133 B8补充：r2/r3确认框边界测试虽通过，实际大字标题仍只露半行；根因是隐藏测量层继承21pt标题槽高度，增加外层fixedSize(vertical:true)后重新测自然高度，常态不变。菜单滚动改按目标差量、慢速并停留后释放，避免惯性使目标反复越过可见边缘；继续保留完整可见/可点要求。

FL-133 / B8续验：最大字号确认标题隐藏副本测量未回传，自动可点仍遮字；改ScrollView内容自然测量并纳入字形框。iPad resize r1系统frame变、内容frame未变，降级为兼容模式证据；补iPad方向后r2因浮窗下错误起点未触发改窗，保留失败；r3真实834×1210→375×675、内部375×655且同场景/意图保持。继续修复系统窗口控件遮挡返回，使用官方corner-aware guide，复验后收口。

FL-133 / B8最终复验：r5真实窗口已验证返回避让；r6浮窗透明度检查发现更多按钮受圆角额外右边距左移6.5pt，面板未同步。r7统一菜单/透明度与导航右边距，保留严格0.5pt对齐断言。Pad竖屏3D快速端点拖动曾停99%，改窗口内慢拖并停留，仍要求精确100%。iOS17两轮在XCTest AX查询时触发XCTAutomationSupport日志高流量隔离回调空指针，保存ips；移除截图采集器对每个装饰节点的重复isHittable查询，实际交互位置仍保留命中断言。以上结果以B8最终复验记录为准，未删除失败证据。

FL-133 / B8返回全屏：同App浮窗最大化后SwiftUI沿用旧top=0/bottom=20，原仅验证全屏启动/单向缩窗未覆盖回程。r10补实时window与geo的safe-area差额、响应UIKit安全区变化；原图与补验保留。r10首个Pad作业安装hash仍旧，主动中断并重跑，不把构建启动时间等同于产物安装身份。


FL-133 / B8回程关闭（r14）：r10–r12桥接window inset、异步重读及重建测量视图均未解决；r13实测UIKit窗口/宿主仍top10而状态栏高32。r14将实测状态栏屏幕带转入UIWindow求交集，只补GeometryReader未消费的顶部量；浮窗交集为空不加空白，最大化标题y32避开状态栏。同PID 22580的scene/coordinator/WindowScene保持，安装包hash一致；r14真实缩窗、双模式透明度/端点/重开、横竖回归通过，原图实看。测量桥不再强制layout或随尺寸重建。详见B8与pad-system/maximize-r14-verification.json。
