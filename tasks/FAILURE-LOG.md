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
