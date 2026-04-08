## UI 截图审查报告 — PlanListView + PlanDetailView（截图对照）
日期：2026-04-06

审查对象：官方计划列表 + 计划详情页
截图来源：P2-01-01 ~ P2-01-03（3 张实机截图）
设计参考：P2-01 PlanListView + PlanDetailView, ref-screenshots/03-training-plan

---

### S-01 计划列表分组标题结构与设计稿不一致
- **类别**：产品规格
- **严重程度**：P1
- **位置**：训练 > 训练计划 > 官方计划分组标题
- **截图现状**：分组标题使用进阶路径标记法，如「🏃 入门 → 初级 (1)」「⚡ 初级 → 中级 (1)」「⚡ 中级突破 (1)」，带 SF Symbol 图标 + 箭头 + 计数气泡
- **设计预期**：设计稿使用简洁的等级分层标题：「入门计划」「中级计划」「高级计划」，18px bold，无图标，无箭头，无计数气泡
- **修复方向**：将 `titleForLevel()` 映射改为等级分层命名（入门计划/中级计划/高级计划）；移除 SF Symbol 图标和计数胶囊；简化 `levelSectionHeader` 为纯文字标题
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/Training/Views/PlanListView.swift` L257-L280（`levelSectionHeader`）、L282-L316（`titleForLevel` / `iconForLevel` / `colorForLevel`）

---

### S-02 计划卡片缩略图使用 SF Symbol 占位，设计要求真实台球照片
- **类别**：产品规格 / 视觉打磨
- **严重程度**：P1
- **位置**：训练 > 训练计划 > 所有官方计划卡片左侧缩略图
- **截图现状**：72×72 圆角方形，使用 SF Symbol 图标（figure.walk / figure.run / bolt.fill）叠加在等级色渐变背景上（LinearGradient 25%→8% opacity）
- **设计预期**：72×72 圆角缩略图（cornerRadius 10px）使用真实台球场景照片（台球桌、球、杆等），付费计划缩略图上有半透明黑色遮罩 + 白色锁图标
- **修复方向**：为每个官方计划配置缩略图资源（可使用 Bundle 内图片或 SF Symbol 作降级）；`PlanCard` 中将 `ZStack { gradient + SF Symbol }` 替换为 `AsyncImage` 或本地 Image 加载；付费计划叠加锁遮罩
- **路由至**：swiftui-developer + content-engineer（提供图片资源）
- **代码提示**：`QiuJi/Features/Training/Views/PlanListView.swift` L351-L365（`PlanCard` 缩略图区域）

---

### S-03 付费标记使用 crown+付费 文字，设计要求 PRO 金色胶囊徽章
- **类别**：产品规格
- **严重程度**：P1
- **位置**：训练 > 训练计划 > 付费计划卡片（走位突破计划、中级综合突破等）
- **截图现状**：使用 `crown.fill` 图标 + "付费" 文字，btAccent 色，放置在等级标签与周数之后的同一行
- **设计预期**：「PRO」金色胶囊徽章（圆角 full，bg: secondaryFixedDim #FFBA44，文字 10px extrabold 深色），紧贴计划标题右侧而非在标签行
- **修复方向**：新增 `BTProBadge` 组件或在 `PlanCard` 中将 crown+付费替换为 PRO pill；位置从标签行移至标题行右侧（与 `h4` 同行）；使用 btAccent 填充背景 + 深色文字
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/Training/Views/PlanListView.swift` L381-L389（premium indicator in PlanCard）

---

### S-04 付费计划缩略图缺少锁图标遮罩
- **类别**：产品规格
- **严重程度**：P2
- **位置**：训练 > 训练计划 > 付费计划缩略图区域
- **截图现状**：付费计划缩略图与免费计划外观相同，仅在右侧文字区域有 crown+付费 标记
- **设计预期**：付费计划缩略图叠加半透明黑色遮罩（bg-black/10）+ 居中白色锁图标（SF Symbol lock, filled），明确传达内容锁定状态
- **修复方向**：在 `PlanCard` 的缩略图 ZStack 中，当 `plan.isPremium` 时追加 overlay 层：半透明黑底 + 白色 lock 图标
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/Training/Views/PlanListView.swift` L353-L365

---

### S-05 计划详情页缺少顶部大图横幅
- **类别**：产品规格
- **严重程度**：P1
- **位置**：训练 > 计划详情 > 页面顶部区域
- **截图现状**：页面直接从导航栏标题进入等级标签 + 描述文字，无任何视觉引导图
- **设计预期**：180pt 高度的全宽台球场景图（圆角 xl=12，带底部渐变阴影 from-black/40 to-transparent），作为页面视觉锚点
- **修复方向**：在 `planContent` 顶部添加 hero image 区域；图片可从计划 JSON 元数据中引用或使用通用占位图；设置 `aspectRatio` 与 `clipShape`
- **路由至**：swiftui-developer + content-engineer（提供图片资源）
- **代码提示**：`QiuJi/Features/Training/Views/PlanDetailView.swift` L59-L76（`planContent` 函数开头）

---

### S-06 计划详情页标题放在导航栏，设计要求放在内容卡片区
- **类别**：布局
- **严重程度**：P1
- **位置**：训练 > 计划详情 > 页面标题区域
- **截图现状**：计划名称「新手入门计划」作为 `.navigationTitle` 显示在导航栏中（inline 模式），内容区域仅显示等级标签 + 描述
- **设计预期**：导航栏只显示计划名称作为 inline title；但内容区在 hero image 下方有一个白色圆角卡片，内含：大标题（22px bold）+ PRO 徽章（若付费）+ 等级/周数标签 + 描述 + 统计数据行，整体为一个 section card
- **修复方向**：保留 `.navigationTitle` 作为 inline 显示；在 `planHeader` 中增加计划名称（btTitle 22pt bold）；将 header + stats 合并到同一个 btBGSecondary 卡片中，添加内边距和圆角
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/Training/Views/PlanDetailView.swift` L80-L106（`planHeader`）、L110-L137（`statsGrid`）

---

### S-07 统计行使用4项图标卡片，设计要求3项大数字行
- **类别**：产品规格 / Design Token
- **严重程度**：P1
- **位置**：训练 > 计划详情 > 统计数据区域
- **截图现状**：4 个独立圆角卡片（btBGSecondary），每个包含：SF Symbol 图标（btTitle2 大小）→ 数字（btStatNumber 28pt）→ 单位标签；指标为「周」「次/周」「分钟/次」「目标」
- **设计预期**：3 列统计行位于 header card 内部（border-top 分隔），使用 28pt bold green 数字 + 13pt 灰色标签；指标为「训练天数」「训练项目」「预计每日」；无 SF Symbol 图标，无独立卡片背景
- **修复方向**：将 `statsGrid` 改为 3 列 grid 布局（训练天数/训练项目/预计每日），移除 icon 行，数字使用 btStatNumber + btPrimary 颜色；整合到 planHeader 卡片内，以 `Divider()` 或 border-top 分隔；从 plan 数据计算「训练天数」「训练项目总数」等指标
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/Training/Views/PlanDetailView.swift` L110-L137（`statsGrid` + `statCell`）

---

### S-08 周卡片左侧出现 W1/W2 圆形编号徽章，设计中无此元素
- **类别**：产品规格
- **严重程度**：P2
- **位置**：训练 > 计划详情 > 训练安排 > 周列表
- **截图现状**：每周行左侧有一个 36pt 圆形徽章（btPrimary 12% opacity 背景 + "W1"/"W2" 文字），占据额外水平空间
- **设计预期**：周行为简洁的「第 X 周」文字 + 右侧展开/收起 chevron，无左侧圆形徽章；展开后显示分日内容
- **修复方向**：移除 `weekHeader` 中的 `ZStack { Circle + Text("W\(n)") }` 圆形徽章；仅保留「第 X 周」文字标题 + chevron
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/Training/Views/PlanDetailView.swift` L227-L258（`weekHeader`）、L225（`weekBadgeSize`）

---

### S-09 等级标签名称与设计稿存在差异（App 遵循 SKILL.md 规范）
- **类别**：产品规格
- **严重程度**：P2
- **位置**：训练 > 训练计划 > 所有计划卡片等级标签
- **截图现状**：App 显示 L1 初级、L2 中级、L3 高级、L4 专家（符合 `BTLevelBadge` 和 SKILL.md §九 定义）
- **设计预期**：设计稿中使用 L0 入门、L1 初学、L2 进阶、L3 熟练（与 SKILL.md 定义不一致）
- **修复方向**：此处 **App 实现正确**，遵循了 SKILL.md 规范。设计稿中的命名可能为早期版本，建议确认并更新设计稿以与代码规范对齐。无需代码修改
- **路由至**：content-engineer（确认设计稿是否需要更新）
- **代码提示**：`QiuJi/Core/Components/BTLevelBadge.swift` L6-L14（`displayName`）

---

### S-10 导航栏右按钮使用 "+" 图标，设计使用 "新建" 文字
- **类别**：HIG / 视觉打磨
- **严重程度**：P2
- **位置**：训练 > 训练计划 > 导航栏右侧
- **截图现状**：导航栏右侧显示系统 `+` (plus) SF Symbol 图标按钮
- **设计预期**：导航栏右侧显示「新建」文字按钮（绿色 17px font-semibold）
- **修复方向**：将 toolbar `Label("新建", systemImage: "plus")` 改为纯文字 `Button("新建")`，或保留当前图标按钮（HIG 允许两种形式，图标更简洁）；建议与产品确认偏好
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/Training/Views/PlanListView.swift` L77-L82（toolbar item）

---

### S-11 滚动后计划列表变为扁平布局，分组上下文丢失
- **类别**：布局
- **严重程度**：P2
- **位置**：训练 > 训练计划 > 滚动到底部（P2-01-03 截图）
- **截图现状**：滚动后（P2-01-03）所有计划卡片呈扁平列表排列，分组标题不可见，用户失去当前浏览位置的上下文
- **设计预期**：设计稿中分组结构清晰（入门计划/中级计划/高级计划），即使滚动仍能感知分组边界
- **修复方向**：考虑使用 `pinnedViews: [.sectionHeaders]` 使分组标题在滚动时吸顶（代码已声明但 LazyVStack 分组方式可能导致 headers 未正确 pin）；或增加每个 section 之间的间距以视觉区分
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/Training/Views/PlanListView.swift` L38（`pinnedViews: [.sectionHeaders]`）

---

### S-12 计划详情「训练安排」标题字体使用 btTitle2，设计使用 18px bold
- **类别**：Design Token
- **严重程度**：P2
- **位置**：训练 > 计划详情 > 训练安排标题
- **截图现状**：使用 `btTitle2`（20pt semibold），视觉上偏大
- **设计预期**：设计稿中「训练安排」标题为 18px bold（介于 btHeadline 17pt 和 btTitle2 20pt 之间）
- **修复方向**：考虑使用 `btHeadline`（17pt semibold）或自定义 `Font.system(size: 18, weight: .bold)` 匹配设计
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/Training/Views/PlanDetailView.swift` L173

---

### S-13 卡片内 padding 差异：App 使用 12pt，设计稿使用 12-16pt 混合
- **类别**：Design Token
- **严重程度**：P2
- **位置**：训练 > 训练计划 > 计划卡片内边距
- **截图现状**：PlanCard 使用 `.padding(Spacing.md)` = 12pt 内边距，整体显得略紧凑
- **设计预期**：设计稿 HTML 中卡片使用 `p-3`（12px）但内容间距更松；部分子区域有额外 margin
- **修复方向**：可考虑将卡片 padding 从 `Spacing.md` (12) 提升为 `Spacing.lg` (16) 以增加呼吸感，与设计 `plan header card` 的 `p-5`（20px）对齐
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/Training/Views/PlanListView.swift` L404

---

### 审查总结
- 截图数量：3 张
- 发现问题：13 项（P0: 0 / P1: 5 / P2: 8）
- 总体评价：计划列表和详情页基本功能完整，但**整体布局结构与设计稿存在较大偏差**。最突出的问题集中在三个方面：①分组标题结构（进阶路径法 vs 等级分层法）、②缩略图视觉（SF Symbol 占位 vs 台球照片）、③详情页 header 布局（缺少 hero image 和合并式 card 布局）。等级标签颜色体系和基础组件（BTLevelBadge、BTPremiumLock）使用正确。
- 建议下一步：
  1. **优先修复 S-01 + S-02 + S-03**（计划列表视觉主体）— 分组标题结构调整 + 缩略图资源补充 + PRO 徽章样式
  2. **其次修复 S-05 + S-06 + S-07**（详情页布局重构）— hero image + header card 合并 + stats 行重设计
  3. **最后处理 P2 级打磨项**（S-04, S-08, S-10~S-13）
