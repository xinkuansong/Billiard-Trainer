# v56 W0 色彩语义、冲突与基线台账

> 日期：2026-09-04
> 方案真源：`问题集合_v56.md` v56.6
> 本批边界：只建立契约与证据，不修改 SwiftUI、Design Token 或 Asset Catalog。

## 1. 已冻结的设计裁定

- 品牌绿不改色相：Light `#1A6B3C`，Dark `#25A25A`。
- 同一品牌语义分三级：导航用绿字/绿指示线；高频筛选用弱绿表面 + 绿字/边框；主操作与关键二元切换才用实绿 + 白字。
- Pro 保留现有 `star.fill` / `crown.fill` 轮廓。生成图只提供拉丝香槟金材质；轮廓由 SF Symbol mask 决定。
- Premium 拆为 `btPremiumForeground`、`btPremiumSurface`、`btPremiumBorder`。文字永远使用纯色前景；小于 24pt 的图形关闭或显著降低纹理。
- Apple 登录按钮、固定暗场工具、彩球/球号、白色瞄准线、轨迹/接触点与 HUD 三通道为明确例外。
- `BTBrandLogo` / `BTLogoMark` 保持现状，不套 Premium 材质。

## 2. 基线与证据冻结

| 项目 | 冻结值 |
|---|---|
| v56 初审源码指纹 | `5c84e0beabb481d48e0d482fa9f3bc7fdee1fa54bd2c61cc17cba3a66f5a5aef` |
| W0 当前源码指纹 | `d7e9b5108153f2c82aaab0c15464ba5d7d453a82bee513d534c5ed3747068dc9` |
| 指纹算法 | `scripts/run_simulator_matrix.py:source_fingerprint` + `scripts/simulator-matrix.json` |
| 66 文件 manifest | `docs/design/v47/baseline-screenshots.sha256`；67 行含 1 行注释、66 个 PNG |
| Light 基线 | `build/v51/matrix/ios-17.0/A2-iPhone-15-Pro/light/standard/tour/` |
| Dark 基线 | `build/v51/matrix/ios-17.0/A1-iPhone-SE-3rd-generation/dark/standard/tour/` |
| Dark 审查替换证据 | `build/v51/dark-review-20260903/`；只替换身份失真的 `70-login.png`，原件不覆盖 |
| 初审报告 | `tasks/ui-reviews/UR-20260903-full-app-color-consistency.md` |

`00-launch.png` 与 `01-training-home.png` 在旧 Light 基线内容重复；`70-login.png` 在旧 Dark 主巡游实际是个人页。W1 修复前，66 只能称“66 个命名文件”，不能称“66 个不同生产页面”。后续任何截图报告必须记录当次源码指纹、文件数、生产页面数、测试专用页面数与独立视觉状态数。

## 3. v55 / v51 唯一 owner 台账

| 路径 / 符号 | 唯一 owner | v56 规则 |
|---|---|---|
| `StatisticsView.swift`、`StatisticsViewModel.swift`、统计 fixture / tests | v55 W1–W5 | v56 不重排、不改数据口径；W7 等 v55 稳定后复验 |
| `AngleHistorySection.swift`、`AngleHistoryViewModel.swift` | v55 W1–W5 | 当前 `btAccent` 使用登记为“待 v55”，v56 不先改 |
| `Colors.swift:btChartSeries` | v55 W2–W5 | 图表系列语义由 v55 定稿；v56 只在其完成后确认不再借 Premium |
| `ScreenshotTourUITests.swift` 全量路由 | v51 W5 | W1 先以当前文件为基线，仅窄改页面身份与登录契约；不覆盖 v51 路由修复 |
| `LoginView.swift` / `OnboardingView.swift` Hero | 当前生产实现 | v56 不接入 D 系列概念图，不改登录产品能力 |
| 60 张 cover Asset Catalog | 封面试装工作 | G1 前只读度量，禁止 v56 写图 |

唯一 owner 已明确，因此 W2 可在 W1 证据链修复后开始；W3 跳过所有 v55 冻结项；最终 W7 必须等待 v55 W1–W5 和 v51 W5 的最终源码。

## 4. `btAccent` 全量使用台账

扫描命令：`rg -n "btAccent" QiuJi --glob '*.swift'`。当前为 42 个文件、114 个命中。以下按文件全量登记，不以命中数直接替换。

### 4.1 迁入 Premium 三层 / 材质组件

| 文件 | 当前职责 | 迁移 |
|---|---|---|
| `Core/Components/BTButton.swift` | `goldFilled` Pro CTA | 改由 Premium CTA 语义；禁用“中亮金底 + 白字” |
| `Core/Components/BTPremiumLock.swift` | 锁图、描边、CTA | 图标 ≥24pt 可用材质；文字/小锁用 `btPremiumForeground` |
| `Core/Components/BTDailyLimitGate.swift` | 皇冠与解锁 CTA；同文件含 `BTProBadge` | 皇冠按尺寸材质/纯色回退；Badge 用三层 token |
| `Core/DesignSystem/IconToken.swift` | `.accent` 商业化/强调图标 | 拆出 `.premium`；普通强调不再自动等于 Pro |
| `Features/Profile/Views/ProfileView.swift` | Pro 推广卡与订阅菜单，同时混有 warning / 月指标 | Pro 部分迁 Premium；warning 迁 `btWarning`；非 Pro 数据另判 |
| `Features/Profile/Views/SubscriptionView.swift` | Paywall 全局金 | 迁 Premium 三层；大皇冠可用材质 |
| `Features/Profile/Views/SubscriptionStatusView.swift` | 会员状态皇冠/金 | 迁 Premium 三层；大皇冠可用材质 |
| `Features/DrillLibrary/Views/DrillDetailView.swift` | 解锁 CTA + 普通收藏 | 解锁迁 Premium；收藏迁 primary/中性，二者拆开 |

### 4.2 迁出 warning / selection / progress / 普通强调

| 文件组 | 当前职责 | 目标语义 |
|---|---|---|
| `Core/Components/BTToast.swift`、`Theory/TheoryPageChrome.swift` | warning / 误区 | `btWarning` |
| `Core/Components/BTDrillCard.swift`、`DrillDetailView.swift` | 收藏 | `btPrimary` 或中性激活；保留心形第二编码 |
| `Core/Components/BTOverflowMenu.swift`、`Profile/SettingsView.swift`、`Profile/AboutView.swift` | 编辑/普通菜单/普通设置强调 | primary 或 neutral；About 的 `star.fill` 不是 Pro，不使用材质 |
| `TrainingHomeView.swift`、`PlanListView.swift`、`PlanDetailView.swift`、`ActiveTrainingView.swift`、`TrainingSummaryView.swift` | 预习/进行中/关键统计/进度装饰 | success、primary、neutral 或稀疏品牌签名；逐点判定 |
| `Core/Components/BTPlanWeekTimeline.swift`、`BTPhaseTimeline.swift`、`BTRestTimer.swift` | 当前周/阶段/计时进度 | primary / success / warning，不能借 Premium |
| `Features/Profile/Views/TrainingGoalView.swift` | 目标达成强调 | success / primary |
| `HistoryCalendarView.swift`、`AngleSessionDetailView.swift` | 角度记录/数据图标 | chart / data-domain；不使用 Premium |
| `BatchAuthoringView.swift`、`BatchBallExtractionView.swift` | 内部工具约束/保存 | primary / warning；不使用 Premium |
| `Core/Components/BTLoadRadarChart.swift` | 峰值点 | 保留“稀疏关键值”候选，W3 以截图确认；不得套材质 |
| `Core/DesignSystem/BTDrillCategoryIcon.swift`、`BTTrainingIcon.swift` | 品牌插图小强调 | 稀疏品牌签名候选；不得套 Premium 材质 |
| `Core/DesignSystem/BTLogoMark.swift` | 品牌 Logo 金色细节 | 受保护品牌签名；保持轮廓与现有渲染，不套 Premium |

### 4.3 待 v55

`Features/AngleTraining/Views/AngleHistorySection.swift` 的 5 处使用与 `Core/DesignSystem/Colors.swift:btChartSeries` 冻结给 v55。`History/StatisticsView*` 的间接消费也由 v55 定稿后再复验。

### 4.4 受保护物理 / 教学语义

| 文件 | 现有含义 | v56 处理 |
|---|---|---|
| `Core/DesignSystem/HUDStyle.swift` | 可调值、刻度指示 | 保留金/橙管语义；必要时改名为物理专用 token，不改色觉编码 |
| `Core/Components/PoolBallFace.swift` | 轨迹/示意线 | 迁专用物理 token，禁止直接换 Premium 色 |
| `Core/Components/ShotControlBar.swift` | 暗场主操作/力度 | 保留暗场契约，逐截图确认 |
| `AimingPrincipleView.swift`、`AimingMethodsView.swift`、`AimingCorrectionView.swift`、`ContactPointTableView.swift`、`SpinAndEnglishView.swift` | 中心线、切线、高杆/顺塞、教学图签 | W3b 按 path / adjustable / warning 拆名；不改几何、线型或含义 |
| `Core/DesignSystem/CoverPalette.swift` | 历史色板注释 | 不把练区金误当 Premium；封面由 W6 单独治理 |

## 5. 硬编码 `Color(red:)` 台账

扫描得到 24 个文件、155 个命中。文件级分类如下：

- **W2/W3 必须迁出 UI 硬编码**：`Core/Components/BTTogglePillGroup.swift`、`Core/Components/BTButton.swift`、`Core/Components/BTPremiumLock.swift`、`Features/Profile/Views/ProfileView.swift`、`Features/Profile/Views/SubscriptionView.swift`、`Features/Training/Views/TrainingShareView.swift`。
- **Design Token 定义点**：`Core/DesignSystem/Colors.swift`。W3 只新增/调整语义 token；不会把定义点本身误报为消费违规。
- **独立主题/封面色板，保持数据化**：`Core/DesignSystem/CoverPalette.swift`、`Core/Components/BTShareCard.swift`、`Core/Components/BTLevelBadge.swift`。不因 v56 强制合并色相；只检查它们是否冒充 selection / Premium。
- **受保护物理/SceneKit**：`Core/Scene/CueStick.swift`、`BTScenePalette.swift`、`AngleTrainingScene.swift`、`MaterialFactory.swift`、`Core/DesignSystem/HUDStyle.swift`、`Core/Components/PoolBallFace.swift`、`BTAimCloseupHUD.swift`、`BTAimWheel.swift`、`Features/AngleTraining/SeparationAngleAtlasGeometry.swift`、`CushionEnglishAtlasGeometry.swift`、`Features/PositionPlay/ViewModels/PlanThreeViewModel.swift`、`SiluTrainerViewModel.swift`、`Features/SnookerTactics/ViewModels/SnookerTacticsViewModel.swift`、`Features/BatchDrillStudio/BatchAuthoringView.swift`。W3b 仅改语义归属；不动几何、物理、球色或材质参数。

## 6. 选中态台账

| 视觉家族 | 真源 / 主要消费 | 裁定 |
|---|---|---|
| 高频筛选 | `BTFilterChip` → `TrainingHomeView`、`DrillListView` | 弱绿表面 + 品牌绿字/边框；去 Light 黑 / Dark 白反相 |
| 关键二元/少量互斥切换 | `BTTogglePillGroup` → `SettingsView` 及训练/工具设置 | 实绿 + 白字；Dark 不再变白底黑字 |
| 内容分段导航 | `BTSegmentedTab` → `HistoryCalendarView`、计划/内容分段 | 保持绿字 + 2pt 指示线 |
| 侧栏导航 | `AngleHomeView` | 保持绿文字/图标 + 侧轨；不改成绿实底 |
| 暗场 HUD chip | `BTChipRow`、`SolverStageChrome`、球桌工具消费页 | 受保护暗场语义，不套内容页弱绿筛选 |
| 纯行为状态 | `AppRouter`、`RootView`、各 ViewModel / Service 中的 `selected*` | 已审计，无视觉迁移；不得为了命中数改业务状态 |

所有共享选中组件必须保留 `.isSelected` 或等效文字/形状第二编码；颜色不是唯一编码。

## 7. 封面叠层台账

| 路径 | 当前事实 | v56 规则 |
|---|---|---|
| `Core/Components/BTAtmosphereLayer.swift` | `showsColorWash`；可选 12% 中性黑幕；底部 45% 渐变 | W6 只从共享语义参数治理，不在页面散写 opacity |
| `Core/Components/BTPlanCover.swift` | `showsColorWash=false`、`showsNeutralScrim=true` | 保持 DR-080/081 |
| `Features/AngleTraining/Views/AngleHomeView.swift` | 36 入口共用无彩罩 + 中性幕 | 素材锁定后统一量化复验 |
| `Features/Training/Views/PlanListView.swift:CustomPlanAtmosphere` | 12 图稳定 hash；无彩罩 + 中性幕 | 不改 hash/映射；G1 前不写图 |

## 8. Pro 入口与材质契约

直接图形入口：`BTPremiumLock`、`BTDailyLimitGate`、`BTProBadge`、`BTButton.goldFilled`、`BTIcon.crown`、`SubscriptionView`、`SubscriptionStatusView`、`ProfileView.proPromotionCard`、`DrillDetailView` 解锁 CTA。间接门控消费：`StatisticsView`、`HistoryCalendarView`、`TrainingHomeView`、`PlanListView`、`AngleHomeView`、两个瞄准训练页与几何角度测验页。

生产组件须满足：

1. SF Symbol 负责 `star.fill` / `crown.fill` 轮廓和 accessibility；生成 PNG 只作为内部 fill。
2. ≥24pt 可显示低对比拉丝；<24pt 或 Reduce Transparency / Increase Contrast 时使用 `btPremiumForeground` 纯色回退。
3. `PRO`、会员状态、CTA 文案始终使用纯色，并提供“Pro / 解锁 Pro / 已订阅”等第二编码。
4. 不将 About 页普通 `star.fill`、品牌 Logo、成就或雷达峰值自动套材质。
5. 母版只存设计证据，W3 经缩小与对比度验证后才可复制到新的 Asset Catalog imageset。

母版：

| 文件 | 模式 | SHA-256 |
|---|---|---|
| `docs/design/v56-color-calibration/21-premium-material-master-light.png` | Light | `248861cba0c2f179cdada1fc5a4f4d2ac72b7683483a17eba3733e9921c04058` |
| `docs/design/v56-color-calibration/22-premium-material-master-dark.png` | Dark | `aae2b6b196a6633fe393e77eccb6bb70443a55a0f1857af231fdd1dd7b33f69b` |

两张均为边到边正交材质场，无图标、文字、边框、金币、珠宝或浮雕。当前 Light 版明暗跨度更克制；Dark 版高光更宽，W3 缩入 24–48pt mask 时需限制采样区域和对比度，避免重新出现“发光金”。
