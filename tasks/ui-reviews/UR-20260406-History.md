## UI 审查报告 — 历史日历 + 训练详情 + 统计（Light）

日期：2026-04-06
任务：T-R1-07
审查范围：HistoryCalendarView / TrainingDetailView / StatisticsView
审查方式：代码走查 + 设计稿对比（screen.png + code.html + UI-IMPLEMENTATION-SPEC.md）

---

### U-01 StatisticsView 缺少 Pro 付费墙
- **类别**：产品规格
- **严重程度**：P1（功能缺陷）
- **位置**：记录 > 统计 Tab
- **现状**：`StatisticsView` 虽然注入了 `subscriptionManager`，但未在任何位置检查 `isPremium`。非 Pro 用户可完整访问所有统计数据、图表和分类对比，无任何遮罩或引导。
- **预期**：P1-10 设计稿明确显示：非 Pro 用户应看到 `BTPremiumLock(.fullMask)` 覆盖统计卡片区域，露出模糊轮廓 + 金色锁图标 + "统计功能为 Pro 专属" 标题 + "解锁 Pro" 金色 CTA。参见 `UI-IMPLEMENTATION-SPEC.md` § 四 Tab 4 及 `docs/08` Freemium 模型。
- **修复方向**：在 `statsContent` 外层包裹条件判断——`isPremium` 为 false 时显示 `BTPremiumLock(.fullMask)` 遮罩 + 解锁按钮，点击弹出 `SubscriptionView`。
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/History/Views/StatisticsView.swift` L13-27、`QiuJi/Core/Components/BTPremiumLock.swift`

---

### U-02 TrainingDetailView set 行缺少休息时间信息
- **类别**：产品规格
- **严重程度**：P1（功能缺陷）
- **位置**：记录 > 训练详情 > Drill 卡片 > 各组行
- **现状**：`setRow` 仅显示「第N组」+「made/target」+ checkmark 图标。无休息时间信息。
- **预期**：P1-08 TrainingDetailView code.html 明确在每行 checkmark 右侧显示「休息 60s」「休息 90s」等文字（13px btTextSecondary 色）。这是训练日志的重要数据维度。
- **修复方向**：`DrillSet` 模型需确认是否包含 `restSeconds` 字段；若有则在 `setRow` checkmark 右侧追加 `Text("休息 \(drillSet.restSeconds)s")`；若模型无此字段则为 data-engineer 补充。
- **路由至**：swiftui-developer / data-engineer
- **代码提示**：`QiuJi/Features/History/Views/TrainingDetailView.swift` L178-195

---

### U-03 TrainingDetailView 缺少「存为模版」工具栏按钮
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵 / 功能缺失）
- **位置**：记录 > 训练详情 > 顶部工具栏右侧
- **现状**：工具栏仅有左侧关闭按钮 + 居中标题，右侧为空。
- **预期**：P1-08 设计稿 screen.png 与 code.html 均在 toolbar 右侧显示「存为模版」按钮（15px Semibold btPrimary 色文字）。
- **修复方向**：在 `ToolbarItem(placement: .navigationBarTrailing)` 添加「存为模版」按钮，点击逻辑可暂留空。
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/History/Views/TrainingDetailView.swift` L24-42

---

### U-04 TrainingDetailView 缺少「设置颜色」标签
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：记录 > 训练详情 > headerSection
- **现状**：headerSection 仅显示训练名称，无颜色标签。
- **预期**：P1-08 code.html 在训练名称右侧显示「设置颜色」胶囊标签（btPrimary 描边 + btPrimary 文字，12pt，圆角 full）。
- **修复方向**：在 `headerSection` 标题旁添加 `Button` 胶囊标签。功能逻辑可暂留空。
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/History/Views/TrainingDetailView.swift` L87-95

---

### U-05 HistoryCalendarView 缺少「月报」/「日历设置」功能按钮
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵 / 功能缺失）
- **位置**：记录 > 历史 Tab > 月导航下方
- **现状**：月导航器下方直接接日历卡片，无功能按钮行。
- **预期**：P1-07 code.html 在月导航下方显示两个药丸按钮：「月报」（btPrimary 10% 底 + btPrimary 文字）和「日历设置」（灰底 + 灰字）。P1-08 空状态设计也包含此行（带 SF Symbol 图标版）。
- **修复方向**：在 `monthNavigator` 和 `calendarCard` 之间插入药丸按钮行。功能可暂留空。
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/History/Views/HistoryCalendarView.swift` L59-68

---

### U-06 StatisticsView 时间范围缺少「自定时间」选项和「设置」按钮
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：记录 > 统计 Tab > 时间范围选择器
- **现状**：`StatisticsTimeRange` 枚举仅含 `week/month/year` 三个选项，`BTTogglePillGroup` 仅展示三个药丸。
- **预期**：P1-09 code.html 和 P1-10 screen.png 均显示 4 个药丸（周/月/年/自定时间）+ 右侧齿轮「设置」按钮。
- **修复方向**：枚举添加 `custom` case + 设置按钮入口。功能逻辑可暂留空，UI 先对齐设计。
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/History/ViewModels/StatisticsViewModel.swift` L4-8、`StatisticsView.swift` L64-69

---

### U-07 StatisticsView 缺少「统计所有分类」复选框
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：记录 > 统计 > 训练概况卡片右上角
- **现状**：训练概况卡片仅有标题「训练概况」，无右侧控件。
- **预期**：P1-09 code.html 在标题右侧显示「统计所有分类」文字 + 绿色 checkbox 图标。
- **修复方向**：在 overviewCard 标题行右侧添加 HStack（文字 + Toggle/Checkbox），切换全分类/单分类统计范围。
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/History/Views/StatisticsView.swift` L73-115

---

### U-08 StatisticsView 分类对比缺少切换控件和管理入口
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：记录 > 统计 > 各分类对比 Section
- **现状**：Section 仅有标题「各分类对比」+ 网格。
- **预期**：P1-09 code.html 在标题右侧显示「组数对比 | 成功率对比」分段切换 + 「管理分类」文字按钮。
- **修复方向**：标题行右侧添加 Picker/SegmentedPill + 管理入口。可先仅展示 UI。
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/History/Views/StatisticsView.swift` L297-313

---

### U-09 月导航箭头按钮触摸目标不足 44pt
- **类别**：HIG / 无障碍
- **严重程度**：P2（视觉瑕疵）
- **位置**：记录 > 历史 Tab > 月份导航 < > 箭头
- **现状**：左右箭头按钮仅包含 `Image(systemName:)` 图标，无 `.frame` 约束，触摸区域由图标尺寸决定（约 17pt），远低于 44pt 最低标准。
- **预期**：Apple HIG 要求所有可点击元素触摸目标 >= 44pt × 44pt。
- **修复方向**：为箭头 `Button` 内的 `Image` 添加 `.frame(width: 44, height: 44)` + `.contentShape(Rectangle())`。
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/History/Views/HistoryCalendarView.swift` L75-87

---

### U-10 TrainingDetailView 关闭按钮背景色偏差
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：记录 > 训练详情 > 左上角关闭按钮
- **现状**：使用 `Color.btBGTertiary.opacity(0.5)` 作为圆形底色。Light 下为 `#E5E5EA` 50% = 较明显灰色。
- **预期**：P1-08 code.html 使用 `rgba(60,60,67,0.06)` ≈ 6% 深灰，几乎透明。应使用更轻的背景。
- **修复方向**：将背景改为 `Color(.systemGray5).opacity(0.6)` 或 `Color.btBGTertiary.opacity(0.3)` 以接近设计值。
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/History/Views/TrainingDetailView.swift` L33

---

### U-11 StatisticsView btStatNumber 字重覆盖
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：记录 > 统计 > 训练时长/成功率 卡片数字
- **现状**：代码使用 `.font(.btStatNumber).fontWeight(.black)`，`.black` (900) 覆盖了 Token 定义的 `.bold` (700)。
- **预期**：`btStatNumber` Token 定义为 28pt Bold Rounded。设计 code.html 使用 `font-black` (900)，但 Token 定义为 Bold，应以 Token 为准。
- **修复方向**：移除 `.fontWeight(.black)` 修饰符，让 Token 自身的 Bold 生效。若需要更粗，应在 Token 定义中统一修改。
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/History/Views/StatisticsView.swift` L166-167、L241-242

---

### U-12 TrainingDetailView Divider 颜色设置方式不当
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：记录 > 训练详情 > Drill 卡片分隔线
- **现状**：`Divider().foregroundStyle(.btSeparator)` — SwiftUI 的 `Divider` 视图有自己的渲染逻辑，`foregroundStyle` 可能不生效或行为不一致。
- **预期**：分隔线应使用 btSeparator Token 色。
- **修复方向**：替换为显式的 `Rectangle().fill(Color.btSeparator).frame(height: 0.5)` 或使用系统 `Color(.separator)`。
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/History/Views/TrainingDetailView.swift` L147-148

---

### U-13 StatisticsView Color hex init 冗余定义
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵 / 代码质量）
- **位置**：StatisticsView.swift L433-443
- **现状**：文件底部定义了 `Color.init(hex:opacity:)` 扩展。虽未在当前代码中使用硬编码 hex，但此扩展的存在违反了设计系统禁止硬编码 hex 的规则，可能误导后续开发。
- **预期**：所有颜色通过 Asset Catalog Token 引用，不使用 hex init。参见 `SKILL.md` §二规则。
- **修复方向**：移除此 `Color(hex:)` 扩展。如果其他文件依赖，需逐一替换为 Token 引用。
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/History/Views/StatisticsView.swift` L433-443

---

### 已知偏差修正验证

| 偏差项 | 要求 | 实现状态 |
|--------|------|---------|
| L-2 大标题左对齐 34pt Bold Rounded | NavigationStack 系统 Large Title | ✅ Preview 中使用 `.navigationTitle("记录")` |
| L-3 统计页卡片左侧绿线保留 | `StatisticsCardModifier` overlay | ✅ 3pt btPrimary 竖线 |
| 月历完整 6 行 | `weeksInMonth` 返回 42 cells | ✅ `while days.count < 42` |
| 下月灰显 | `isCurrentMonth` false → `btTextTertiary.opacity(0.6)` | ✅ |
| 训练日标记：绿底白字小胶囊 | btPrimary 底 + 白色文字 + 3pt 圆角 | ✅ |
| 周末不标红 | 无红色周末逻辑 | ✅ |
| Section 标题：统计页 btPrimary 色 | `.foregroundStyle(.btPrimary)` | ✅ 四处标题均为 btPrimary |
| 图表双色：琥珀 + btPrimary | `chartAmberColor` + `Color.btPrimary.opacity(0.6)` | ✅ |

---

### 审查总结
- 截图/设计稿对照：P1-07 / P1-08 / P1-09 / P1-10 + ref-screenshots + code.html
- 发现问题：13 项（P0: 0 / P1: 2 / P2: 11）
- 总体评价：三个页面的 Design Token 使用和布局结构整体规范，日历 6 行、绿色胶囊标记、统计卡片左侧绿线等已知偏差修正全部到位。**最关键缺陷**是 StatisticsView 缺少 Pro 付费墙（P1），非 Pro 用户可直接访问全部统计数据，违反 Freemium 模型；其次是训练详情缺少组间休息时间展示（P1）。其余 P2 项主要为设计稿中的辅助控件缺失和细节打磨。
- 建议下一步：
  1. **优先修复** U-01（Pro 付费墙）— 直接影响商业化逻辑
  2. **次优先修复** U-02（休息时间）— 需确认 DrillSet 数据模型是否含该字段
  3. P2 项可作为后续打磨迭代处理
