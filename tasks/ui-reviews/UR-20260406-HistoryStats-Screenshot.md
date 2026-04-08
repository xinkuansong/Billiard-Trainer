## UI 截图审查报告 — HistoryCalendarView + StatisticsView（截图对照）
日期：2026-04-06

审查对象：记录 Tab（日历视图 + 统计页）
截图来源：P1-07-01, P1-10-01（2 张实机截图）
设计参考：P1-08 HistoryCalendar, P1-10 Statistics, ref-screenshots/05+06

---

### S-01 History Calendar 缺少「月报」「日历设置」功能按钮
- **类别**：产品规格
- **严重程度**：P1（功能缺陷）
- **位置**：记录 > 历史 > 月导航下方区域
- **截图现状**：月导航（`< 2026年4月 >`）下方直接接日历卡片，无任何快捷操作按钮
- **设计预期**：P1-08 设计在月导航与日历之间有两个胶囊按钮 —— `📊 月报`（`bg-secondary-container` 填充）和 `⚙️ 日历设置`（`bg-surface-variant/50` 填充），参见 `code.html` L129–L139
- **修复方向**：在 `HistoryCalendarView.historyContent` 中 `monthNavigator` 和 `calendarCard` 之间添加 HStack，包含两个胶囊按钮（SF Symbol + 文字），样式使用 `btPrimaryMuted` / `btBGTertiary` 背景 + `BTRadius.full`
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/History/Views/HistoryCalendarView.swift` L68–L77（historyContent）

---

### S-02 统计页时间范围选项缺少「自定时间」和「设置」
- **类别**：产品规格
- **严重程度**：P1（功能缺陷）
- **位置**：记录 > 统计 > 时间范围选择器
- **截图现状**：仅显示 3 个胶囊选项：周 / 月 / 年
- **设计预期**：P1-10 设计显示 5 个选项：周 / 月 / 年 / 自定时间 / ⚙️，参见 `code.html` L107–L116；ref-screenshots/06 参考也显示「自定时间」和「设置」
- **修复方向**：在 `StatisticsTimeRange` 枚举中添加 `.custom` case；在 `BTTogglePillGroup` 右侧追加一个圆形设置图标按钮（SF Symbol `gearshape`，`btBGTertiary` 背景）
- **路由至**：swiftui-developer + data-engineer（自定义时间范围需要 ViewModel 支持）
- **代码提示**：`StatisticsView.swift` L75–L79（timeRangePicker）；`StatisticsViewModel.swift` 中 `StatisticsTimeRange` 枚举

---

### S-03 Pro 锁定遮罩采用底部渐变而非设计要求的居中叠加模式
- **类别**：产品规格
- **严重程度**：P1（功能缺陷）
- **位置**：记录 > 统计 > BTPremiumLock 整体布局
- **截图现状**：`BTPremiumLock(.fullMask)` 将实际内容完整渲染，仅在底部叠加 200pt 高的白色渐变 + 锁图标（56pt 圆）+ 金色「解锁 Pro」按钮，锁图标大致位于页面中部偏下
- **设计预期**：P1-10 设计要求居中叠加模式 —— 锁图标（72px 圆，金色背景 + 阴影）居中置于 frosted 卡片上方，下接标题「统计功能为 Pro 专属」（`text-2xl font-bold`）+ 副标题「升级 Pro 解锁训练统计、趋势图表和分类对比」+ 金色胶囊 CTA 按钮，参见 `code.html` L166–L184
- **修复方向**：为 `BTPremiumLock` 新增 `.centeredOverlay` 模式（或改造 `.fullMask`），将锁图标 + 文案 + CTA 居中显示在模糊/frosted 内容上方；锁圆圈放大至 72pt；增加标题和副标题 Text
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Core/Components/BTPremiumLock.swift` L51–L69（fullMaskLock）

---

### S-04 Pro 锁定缺少营销文案（标题 + 副标题）
- **类别**：产品规格
- **严重程度**：P1（功能缺陷）
- **位置**：记录 > 统计 > Pro 锁定叠加层
- **截图现状**：锁定区域仅有锁图标和「解锁 Pro」按钮，无任何描述性文字
- **设计预期**：P1-10 设计在锁图标下方显示两行文字：① 标题「统计功能为 Pro 专属」（`text-2xl font-bold`，约 24pt）② 副标题「升级 Pro 解锁训练统计、趋势图表和分类对比」（`text-base opacity-80`），参见 `code.html` L174–L177
- **修复方向**：在 `BTPremiumLock` 组件中 `lockIcon` 和 CTA 之间添加标题/副标题参数（或允许外部注入自定义 content），使用 `btText` + `btTitle` 和 `btTextSecondary` + `btSubheadline`
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Core/Components/BTPremiumLock.swift` L64–L68

---

### S-05 统计数据在 Pro 锁定后仍完全可读（缺少磨砂/模糊效果）
- **类别**：产品规格
- **严重程度**：P1（功能缺陷）
- **位置**：记录 > 统计 > 锁定区域背景卡片
- **截图现状**：训练概况卡片（「1天」大数字、「本周训练天数」、「基础 1天」）和训练时长卡片（「0.0 小时/周」、日期范围、图表轴标签）均完全可读，未应用任何模糊遮挡
- **设计预期**：P1-10 设计对锁定区域卡片施加渐进式磨砂效果 —— 第一张卡片 `frost-25`（25% 模糊 + 75% 白底）、第二张 `frost-50`（50% 模糊 + 50% 白底）、第三张 `frost-gradual`（线性渐进模糊），使数据不可辨认，参见 `code.html` L120–L165 中 `.frost-25 / .frost-50 / .frost-gradual` class
- **修复方向**：在 `BTPremiumLock(.fullMask)` 的 content 容器上叠加 `.blur(radius:)` 或半透明遮罩层；或在 `StatisticsView` 中当 Pro 未解锁时渲染占位卡片（灰色矩形剪影）而非真实数据
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Core/Components/BTPremiumLock.swift` L53（content() 未加任何模糊）；`StatisticsView.swift` L22–L28

---

### S-06 「解锁 Pro」按钮形状为小圆角而非设计要求的胶囊形
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：记录 > 统计 > Pro 锁定 CTA 按钮
- **截图现状**：「解锁 Pro」按钮使用 `BTRadius.sm`（8pt）圆角
- **设计预期**：P1-10 设计使用 `rounded-full`（完全胶囊形 / 9999px），按钮高度 `py-4` ≈ 48pt，参见 `code.html` L179
- **修复方向**：将 `goldFilledCTA` 和 `goldOutlineCTA` 的 `BTRadius.sm` 改为 `BTRadius.full`（999pt 胶囊）
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Core/Components/BTPremiumLock.swift` L119（`.clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))`）

---

### S-07 「解锁 Pro」按钮使用文字徽章而非设计要求的图标
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：记录 > 统计 > Pro 锁定 CTA 按钮内部
- **截图现状**：按钮内容为 `[PRO]` 文字徽章 + 「解锁 Pro」文字
- **设计预期**：P1-10 设计在按钮内使用 `workspace_premium` 图标（filled）+ 「解锁 Pro」文字，参见 `code.html` L179–L181
- **修复方向**：将 `proBadge` 替换为 SF Symbol `crown.fill` 或 `star.circle.fill`（iOS 无 Material 图标需选择等效 SF Symbol），白色前景
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Core/Components/BTPremiumLock.swift` L108–L123

---

### S-08 页面标题「记录」字号偏小
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：记录 Tab > 顶部标题
- **截图现状**：使用 `btTitle`（22pt bold rounded）
- **设计预期**：P1-08 和 P1-10 设计均使用 `text-3xl`（≈30pt）+ `font-bold tracking-tight`，更接近 `btLargeTitle`（34pt）；且 ref-screenshots 中其他 Tab 均采用系统 Large Title 尺寸
- **修复方向**：将 `HistoryCalendarView` 中「记录」标题 font 从 `.btTitle` 改为 `.btLargeTitle`（34pt），或使用系统 `NavigationStack` + `.navigationTitle("记录")` + `.navigationBarTitleDisplayMode(.large)` 获得原生 Large Title
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/History/Views/HistoryCalendarView.swift` L24–L26

---

### S-09 统计卡片左侧绿色装饰线设计稿未定义
- **类别**：视觉打磨
- **严重程度**：P2（视觉瑕疵）
- **位置**：记录 > 统计 > 训练概况 / 训练时长 / 分类成功率卡片左侧
- **截图现状**：每张统计卡片左侧有一条 3pt 宽的 btPrimary 绿色竖线装饰
- **设计预期**：P1-10 设计的卡片（`code.html` L121–L165）为纯白背景 `bg-white rounded-2xl shadow-sm border border-black/5`，无左侧装饰线；ref-screenshots/06 参考也无此装饰
- **修复方向**：若为有意设计改进，在 `tasks/IMPLEMENTATION-LOG.md` 追加 DR-NNN 记录此偏差；若为无意添加，移除 `StatisticsCardModifier` 中 `.overlay(HStack { RoundedRectangle... })` 的绿色竖线
- **路由至**：swiftui-developer（确认设计意图后决定保留或移除）
- **代码提示**：`QiuJi/Features/History/Views/StatisticsView.swift` L417–L426（StatisticsCardModifier overlay）

---

### S-10 训练时长卡片日期范围格式不够清晰
- **类别**：视觉打磨
- **严重程度**：P2（视觉瑕疵）
- **位置**：记录 > 统计 > 训练时长卡片 > 日期范围
- **截图现状**：显示 `2026-03-31-2026-04-06`，日期之间使用单个连字符 `-`，与日期内部的连字符混淆
- **设计预期**：ref-screenshots/06 使用波浪号分隔（`2025-11-17~2026-03-30`），更清晰
- **修复方向**：将 `StatisticsViewModel.dateRangeLabel` 中日期间分隔符从 `-` 改为 `~` 或 ` – `（en dash）
- **路由至**：data-engineer
- **代码提示**：`QiuJi/Features/History/ViewModels/StatisticsViewModel.swift`（dateRangeLabel 属性）

---

### S-11 统计页「历史」Tab 文字偏灰缺乏层次区分
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：记录 > 统计 Tab 选中时 > 「历史」未选中 Tab 文字
- **截图现状**：未选中的「历史」文字使用 `btTextSecondary`（60% 不透明度灰色），与设计中的 `text-zinc-500` 一致，但视觉上偏暗，与选中态 btPrimary 绿色的对比不够鲜明
- **设计预期**：P1-10 `code.html` L102 使用 `text-zinc-500 font-semibold text-lg`，P1-08 `code.html` L114 使用 `text-on-surface-variant/60`。当前实现 `BTSegmentedTab` 使用 `.btCallout`（16pt medium）而非设计的 `text-lg`（≈18pt semibold）
- **修复方向**：将 `BTSegmentedTab` 的字体从 `.btCallout`（16pt medium）调大为 `.btHeadline`（17pt semibold），与设计 `text-lg font-semibold` 对齐
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Core/Components/BTSegmentedTab.swift` L21（`.font(.btCallout)`）

---

### 审查总结
- 截图数量：2 张
- 发现问题：11 项（P0: 0 / P1: 5 / P2: 6）
- 总体评价：History Calendar 日历布局和训练列表整体还原度较好，日期选中态、今日高亮、会话行卡片风格与设计系统一致。**最大偏差集中在 Statistics 页的 Pro 锁定体验**：当前实现暴露了真实统计数据且缺少设计要求的磨砂遮罩和营销文案，削弱了付费转化驱动力。此外，History Calendar 缺少「月报」「日历设置」两个设计明确要求的功能入口。
- 建议下一步：
  1. **优先修复 S-03 / S-04 / S-05**（Pro 锁定体验）—— 直接影响商业化转化
  2. **其次修复 S-01 / S-02**（缺失功能按钮）—— 影响功能完整度
  3. P2 项作为后续打磨批量处理
