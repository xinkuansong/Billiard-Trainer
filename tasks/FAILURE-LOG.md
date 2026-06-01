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
- **规则改进建议**：xcodegen 中所有 `type: folder` 的 resources 必须配套后处理补丁；禁止 README 之外的任何地方建议"直接跑 xcodegen generate"。新增 folder 资源时同步更新 `scripts/patch-pbxproj-folder-refs.py` 的 FOLDERS 表
- **已应用至**：✅ `scripts/patch-pbxproj-folder-refs.py` + `scripts/Makefile` `xcodegen` 目标 + `project.yml` 顶部告警（2026-05-25）；待回写至 `60-devops-release.mdc` § 经验教训

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
