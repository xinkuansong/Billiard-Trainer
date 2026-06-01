# UI 审查报告 — 全 App 浅色模式巡游
日期：2026-05-29
设备：iPhone 17 Pro（iOS 26.2 模拟器）· 浅色模式 · 游客态首启
截图来源：`QiuJiUITests/ScreenshotTourUITests`（自动巡游）→ `screenshot-v4/`（25 帧，00–24）

> 覆盖：5 Tab（训练 / 动作库 / 角度 / 记录 / 我的）+ 计划列表 / 计划详情 / 动作详情 / 角度 7 子页 / 统计 / 个人信息 / 训练目标 / 偏好设置 / 关于 / 订阅 Paywall。
> 本轮为静态截图审查；交互态问题（见「未覆盖」节）需动态复检。

---

## 一、问题清单

### U-01 角度 2D/动态场景台面偏荧光绿（plain 渲染管线过曝 + 未做台呢材质增强）
- **类别**：渲染/光照 / 视觉打磨
- **严重程度**：P1
- **位置**：角度 > 2D 瞄准训练（`13`）/ 角度与打点（`10`）
- **现状**：台呢呈高饱和荧光绿。**根因不是硬编码颜色**——台呢是 `TaiQiuZhuo.usdz` 烘焙的布料材质；2D/动态页走的是 `AngleTrainingScene.setupScene()` 默认 **plain 管线**（`enhancedRendering = false`）：`setupPlainLighting()` 光照偏强（ambient 1000 + directional 1400 + fill 500）、相机 `exposureOffset = -0.15`，且**不调用** `MaterialFactory.enhanceClothMaterials`（缺少 ~8% 去饱和 multiply + roughness/normal 处理），导致布料被打亮、显荧光。对比 `14-3D 瞄准` 走 `enhanced: true` 的 studio 管线（key 820/fill 50/rim 120 + IBL + HDR tone-mapping + 布料增强），同一 USDZ 呈自然深绿。
- **预期**：2D/动态台呢观感与 3D studio 一致、接近真实深绿（参考 btTableFelt #1B6B3A），模块内统一。
- **修复方向**（任一或组合，均为可调项）：① 降低 `setupPlainLighting` 强度（如 ambient ~400–500、directional ~700–900、fill ~150–250）并/或把相机 `exposureOffset` 调更负；② 在 plain 管线也调用 `MaterialFactory.enhanceClothMaterials`（轻量，仅材质 multiply 去饱和 + roughness），直接压住荧光绿；③ 视性能为 2D 页启用 enhanced 管线。建议先试 ②+① 组合，逐档对比截图。
- **路由至**：SwiftUI Developer
- **代码提示**：`QiuJi/Core/Scene/AngleTrainingScene.swift`（`setupPlainLighting()` / `setupCamera()` 非 enhanced 分支 / `setupTable()` 的 `enhancedRendering` 判断）、`QiuJi/Core/Scene/MaterialFactory.swift`（`enhanceClothMaterials`）

### U-02 计划详情顶部标题与状态栏重叠
- **类别**：布局 / HIG
- **严重程度**：P1
- **位置**：训练 > 计划详情（`04-plan-detail`）
- **现状**：页面顶部大号「01 / 第 1 期」与系统状态栏时钟「03:06」重叠，左上返回键也压在状态栏区域；顶部 hero 头图未给安全区顶部留白。
- **预期**：顶部内容尊重 Safe Area top inset；返回键与标题不与状态栏元素重叠。
- **修复方向**：hero 头部增加 `.safeAreaInset(edge: .top)` 或 `padding(.top, safeAreaInsets.top)`；返回键下移到安全区内。
- **路由至**：SwiftUI Developer
- **代码提示**：`QiuJi/Features/Training/Views/PlanDetailView.swift`

### U-03 记录-日历空状态文案穿透到 Tab 栏后方
- **类别**：布局 / 视觉打磨
- **严重程度**：P1
- **位置**：记录 > 历史（`16-history-calendar`）
- **现状**：底部「去开始第一次练球吧」与右上角淡色文字渲染在日历卡片/Tab 栏「之后/之下」，与悬浮按钮、Tab 栏叠加，呈现脏渲染/层级错乱观感。
- **预期**：空状态提示应在内容层内、不与 Tab 栏重叠；或在有日历时不展示该水印式提示。
- **修复方向**：检查空状态 overlay 的 z-order 与 padding，给底部 Tab 栏预留安全区。
- **路由至**：SwiftUI Developer
- **代码提示**：`QiuJi/Features/History/Views/HistoryCalendarView.swift`

### U-04 订阅 Paywall 价格与 CTA 长时间转圈，无错误/兜底态
- **类别**：产品规格（Freemium）/ HIG
- **严重程度**：P1（需结合真机/StoreKit 复检）
- **位置**：我的 > 解锁球迹 Pro（`24-subscription-paywall`）
- **现状**：权益清单已渲染，但价格区与底部购买按钮持续显示 loading 转圈（StoreKit 产品未加载完成）。无超时、错误提示或重试入口。
- **预期**：产品加载有骨架/超时与失败兜底（「加载失败 重试」），避免用户停留在不可用 paywall。
- **修复方向**：为 product 加载增加超时与 error state UI；确认 `Products.storekit` 在调试态正确加载。
- **路由至**：SwiftUI Developer（UI 兜底）/ Data Engineer（StoreKit 加载）
- **代码提示**：`QiuJi/Features/Subscription/...`、`QiuJi/Resources/Products.storekit`

### U-05 文案疑似错别字「浅淡球感」应为「浅谈球感」
- **类别**：产品规格 / 内容
- **严重程度**：P2
- **位置**：角度 > 角度首页卡片（`08`）+ 球感子页导航标题（`11`）
- **现状**：标题显示「浅淡球感」。结合副标题「从理性分析到直觉判断」，语义应为「浅谈（简要讨论）球感」，「浅淡」（颜色浅/淡）为别字。
- **预期**：统一为「浅谈球感」（或产品确认的正式命名）。
- **修复方向**：全局检索替换该字符串。
- **路由至**：Content Engineer
- **代码提示**：`QiuJi/Features/AngleTraining/Views/AngleHomeView.swift`、`BallFeelView.swift`

### U-06 动作详情顶栏无毛玻璃背景，滚动内容穿透状态栏/标题栏
- **类别**：布局 / 视觉打磨
- **严重程度**：P2
- **位置**：动作库 > 动作详情（`07-drill-detail-bottom`）
- **现状**：下滑后，被滚动的正文（训练要点等）透显在状态栏与固定顶栏（返回/标题/收藏）之下，缺少 material 背景遮挡。
- **预期**：固定顶栏使用 `.ultraThinMaterial`/不透明背景，滚动内容不与状态栏文字叠加。
- **修复方向**：给顶栏容器加材质背景并填充至安全区顶部。
- **路由至**：SwiftUI Developer
- **代码提示**：`QiuJi/Features/DrillLibrary/Views/DrillDetailView.swift`

### U-07 「角度与打点」场景标签在亮绿台面上可读性差
- **类别**：无障碍 / 视觉打磨
- **严重程度**：P2
- **位置**：角度 > 角度与打点（`10-angle-dynamic`）
- **现状**：旋转贴线的「碰撞线」（红）与「瞄准线」（白/绿）文字在荧光绿台面上对比不足、与彩色线条交叠，辨识困难。
- **预期**：文字加描边/底色或移至空白区；对比度达 WCAG AA。
- **修复方向**：标签加半透明底板或描边；台面色修正（见 U-01）后亦会改善。
- **路由至**：SwiftUI Developer
- **代码提示**：`QiuJi/Features/AngleTraining/Views/AngleDynamicView.swift`

### U-08 多处「即将上线/即将推出」占位对外可见
- **类别**：产品规格 / 路线图
- **严重程度**：P2（内容/排期，非缺陷）
- **位置**：动作详情「视频示范」空占位（`07`）；偏好设置「数据导出 即将推出」（`22`）
- **现状**：视频示范为灰色空缩略图 + 「即将上线」；数据导出标注「即将推出」。
- **预期**：上线前补齐内容，或对未就绪能力收敛入口/明确说明。对应 `todo.md` 第 3 项（视频拼接/GIF）。
- **路由至**：Content Engineer / 产品
- **代码提示**：`DrillDetailView.swift` 视频区、`SettingsView.swift`

### U-09 关于页 App 图标质感待打磨
- **类别**：视觉打磨
- **严重程度**：P2
- **位置**：我的 > 关于与反馈（`23`）
- **现状**：浅灰圆角底 + 绿色「Q」字标，质感偏简，与 `todo.md` 第 1 项「logo 和图标设计」一致。
- **预期**：完善品牌图标（见 BTLogoMark / AppIcon 资产迭代）。
- **路由至**：SwiftUI Developer / 设计
- **代码提示**：`QiuJi/Core/DesignSystem/BTLogoMark.swift`、`Assets.xcassets/AppIcon.appiconset`

---

## 二、未覆盖 / 需动态复检

- **`现有问题.md` 角度交互态**：小角度时角度值文字被挤压、左下 HUD 文案上移并常驻、自动选袋触发角度提高到 85°——均为「选定袋口后」的交互态。本轮 `13-angle-scene2d-aiming` 为初始态（0/20 · 右上 · 剩余 20），未触发，需动态复检。
- **自由记录 / 训练会话页（ActiveTrainingView）**、**组间休息倒计时**、**训练总结**：会话态，巡游最后一步未稳定进入，未截到。
- **动作详情「查看精讲」、收藏列表有数据态、计划进行中态**：需造数据后复检。

---

## 三、审查总结

- 问题数量：9 项（P0: 0 / P1: 4 / P2: 5）。
- 总体评价：信息架构清晰、浅色设计系统执行整体到位（卡片、分段、空状态、列表行规范）；**最突出问题是角度模块真实台面的荧光绿与设计 token 不一致（U-01）**，其次为计划详情安全区重叠（U-02）、日历空状态层级错乱（U-03）、Paywall 加载兜底缺失（U-04）。内容侧有一处错别字（U-05）与若干「即将上线」占位待补。
- P1 项已登记 FAILURE-LOG：FL-011（U-01）/ FL-012（U-02）/ FL-013（U-03）/ FL-014（U-04）。

---

## 四、修复记录（2026-05-29 同日修复并回归）

| 编号 | 状态 | 修复要点 | 改动文件 |
|------|------|----------|----------|
| U-01 | ✅ | 修复 `enhanceClothMaterials` 的 multiply 守卫（USDZ 台呢 diffuse 为 NSURL 贴图，原守卫使着色从未生效）；新增 plain/studio 两套 cloth tint，plain 管线用强暗化去饱和；plain 光照下调 + 曝光下压。台呢由荧光绿改为自然深绿 | `MaterialFactory.swift`、`AngleTrainingScene.swift` |
| U-02 | ✅ | `BTPlanCover` 新增 `showIssueLabel`，详情页 Hero 隐藏左上期号标签，消除与状态栏重叠 | `BTPlanCover.swift`、`PlanDetailView.swift` |
| U-03 | ✅ | 日历空状态由整屏 `BTEmptyState` 改为紧凑内嵌；底部 padding→96 预留 Tab 栏 | `HistoryCalendarView.swift` |
| U-04 | ✅ | StoreKit 产品加载加 8s 超时，复用既有错误/重试兜底 | `SubscriptionManager.swift` |
| U-05 | ✅ | 「浅淡球感」→「浅谈球感」 | `AngleHomeView.swift`、`BallFeelView.swift` |
| U-06 | ✅ | 动作详情固定顶栏 `.toolbarBackground(.visible/.ultraThinMaterial)`，消除穿透 | `DrillDetailView.swift` |
| U-07 | ✅ | 随 U-01 台呢变深后线标签对比度改善，复检通过 | （随 U-01） |
| U-08 | ⏳ | 视频示范/数据导出占位 — 内容/路线图，未改 | — |
| U-09 | ⏳ | App 图标质感 — 设计轨道，未改 | — |

回归方式：`QiuJiUITours` 截图巡游重跑，`screenshot-v4/` 已更新（新增 `25-subscription-paywall-timeout` 验证超时兜底）。

### 截图索引（`screenshot-v4/`）
00 启动/训练首页 · 01 训练首页 · 02 自定义模版 · 03 计划列表 · 04 计划详情 · 05 动作库 · 06 动作详情上 · 07 动作详情下 · 08 角度首页 · 09 瞄准原理 · 10 角度与打点 · 11 球感 · 12 几何角度 · 13 2D 瞄准 · 14 3D 瞄准 · 15 进球点对照表 · 16 历史日历 · 17 统计 · 18 我的上 · 19 我的下 · 20 个人信息 · 21 训练目标 · 22 偏好设置 · 23 关于 · 24 订阅 Paywall
