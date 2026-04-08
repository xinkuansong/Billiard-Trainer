## UI 审查报告 — HistoryCalendarView + StatisticsView + TrainingDetailView（V2 Delta）
日期：2026-04-06

审查对象：记录 Tab（日历视图 + 统计页 + 训练详情页）
截图来源：P1-07-01, P1-08-01~05, P1-10-01（7 张 V2 实机截图）
设计参考：P1-08 HistoryCalendar_02, P1-08 TrainingDetailView_02, P1-10_02
前次审查：`tasks/ui-reviews/UR-20260406-HistoryStats-Screenshot.md`（S-01 ~ S-11）

---

## 一、前次问题回溯（S-01 ~ S-11）

| 编号 | 标题 | 严重度 | V2 状态 | 说明 |
|------|------|--------|---------|------|
| S-01 | History Calendar 缺少「月报」「日历设置」按钮 | P1 | **OPEN** | V2 截图中月导航与日历之间仍无按钮 |
| S-02 | 统计页时间范围缺「自定时间」和「设置」 | P1 | **OPEN** | 时间范围胶囊被模糊覆盖区域遮挡，且可见部分仅显示 3 个选项 |
| S-03 | Pro 锁定遮罩采用底部渐变而非居中叠加 | P1 | **FIXED** | 锁图标 72pt 金圈居中，标题 + 副标题 + CTA 居中布局，与设计一致 |
| S-04 | Pro 锁定缺少营销文案 | P1 | **FIXED** | 标题「统计功能为 Pro 专属」+ 副标题完整显示 |
| S-05 | 统计数据无磨砂效果仍可读 | P1 | **FIXED** | `.blur(radius: 8)` 已应用，数据不可辨认 |
| S-06 | 「解锁 Pro」按钮非胶囊形 | P2 | **FIXED** | 使用 `BTRadius.full` 胶囊形 |
| S-07 | 「解锁 Pro」按钮使用文字徽章 | P2 | **FIXED** | 使用 `crown.fill` SF Symbol 图标 |
| S-08 | 页面标题「记录」字号偏小 | P2 | **FIXED** | V2 截图标题视觉尺寸与设计 `text-3xl` 一致 |
| S-09 | 统计卡片左侧绿色装饰线 | P2 | **OPEN** ⁽¹⁾ | 模糊遮罩下无法确认，待 Pro 解锁后验证 |
| S-10 | 训练时长卡片日期范围格式 | P2 | **OPEN** ⁽¹⁾ | 模糊遮罩下无法确认，待 Pro 解锁后验证 |
| S-11 | 统计页未选中 Tab 文字偏灰/偏小 | P2 | **PARTIAL** | Tab 文字仍显示为 `btCallout`（16pt medium），设计要求 `text-lg`（≈18pt semibold） |

> ⁽¹⁾ 由于 Pro 锁定模糊覆盖，这两项无法从当前截图验证。建议在 Pro 解锁状态下复验。

**统计：FIXED 6 / PARTIAL 1 / OPEN 4**

---

## 二、V2 新增问题

### N-01 Training Detail 顶栏缺少「存为模版」快捷按钮
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：训练详情页 > 顶部导航栏右侧
- **现状**：顶栏仅显示 ✕ 关闭按钮（左）和计划名称（居中），右侧无操作按钮
- **预期**：设计在顶栏右侧显示「存为模版」文字按钮（`text-[15px] font-semibold text-[#1A6B3C]`），参见 `TrainingDetailView_02/code.html` L104
- **修复方向**：在 Sheet header 右侧添加 `Button("存为模版")` 文字按钮，使用 `.btPrimary` 前景色
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/History/Views/TrainingDetailView.swift`（导航栏区域）

---

### N-02 Training Detail 缺少「设置颜色」胶囊按钮
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：训练详情页 > 计划标题右侧
- **现状**：标题行仅显示计划名称「基础功训练」，无附属操作按钮
- **预期**：设计在计划标题右侧显示「设置颜色」胶囊按钮（`border border-primary-container text-primary-container rounded-full`），参见 `TrainingDetailView_02/code.html` L110
- **修复方向**：在标题 HStack 中添加描边胶囊按钮，使用 `btPrimaryContainer` 边框色 + `BTRadius.full`
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/History/Views/TrainingDetailView.swift`（标题区域）

---

### N-03 Training Detail Drill Set 行缺少「休息时间」显示
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：训练详情页 > Drill 卡片 > 各组行
- **现状**：每组行显示「第N组  分数  ✓」，无休息时间信息
- **预期**：设计在勾选图标右侧显示「休息 60s」等休息时间文字（`text-on-surface-variant text-[13px]`），参见 `TrainingDetailView_02/code.html` L156、L163 等
- **修复方向**：在 set 行的 checkmark 右侧添加休息时间 label，使用 `btTextSecondary` + `btCaption` 字体；数据来源需确认 TrainingSession 模型是否已存储 restDuration
- **路由至**：swiftui-developer + data-engineer
- **代码提示**：`QiuJi/Features/History/Views/TrainingDetailView.swift`（set row 区域）

---

### N-04 Training Detail Overflow 菜单缺少彩色图标圆
- **类别**：视觉打磨
- **严重程度**：P2（视觉瑕疵）
- **位置**：训练详情页 > ··· 按钮弹出菜单
- **现状**：弹出菜单为纯文本列表样式（深色背景毛玻璃），每项仅有文字，「删除」为红色文字
- **预期**：设计使用白色/半透明背景自定义弹窗，每项左侧带彩色圆形图标 — 蓝色（分享）、紫色（移动）、绿色（心得）、金色（模版）、红色（删除），参见 `TrainingDetailView_02/code.html` L284–L317
- **修复方向**：将系统 `.confirmationDialog` 改为自定义 Popover 组件或半透明 Sheet，按钮左侧添加 28pt 彩色圆形 + SF Symbol 图标
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/History/Views/TrainingDetailView.swift`（overflow menu / action sheet 区域）

---

### N-05 空日状态内容被 Tab Bar 截断需滚动
- **类别**：布局
- **严重程度**：P2（视觉瑕疵）
- **位置**：记录 > 历史 > 选中无数据日（P1-08-01）
- **现状**：选中无训练数据的日期后，「4月6日 星期一」下方显示日历空状态图标，但标题「还没有训练记录」和按钮被 Tab Bar 遮挡，需向下滚动才可见（P1-08-02）
- **预期**：空日提示内容（图标 + 标题 + 副标题 + 按钮）应在不滚动的情况下完整可见，或至少标题文字可见
- **修复方向**：减小空日状态区域的顶部间距，或将日历卡片在空日状态下自动折叠（仅显示当周），使下方有足够空间展示完整空状态
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/History/Views/HistoryCalendarView.swift`（空状态区域布局）

---

### N-06 Pro Lock 模糊为均匀 blur 而非设计要求的渐进式磨砂
- **类别**：视觉打磨
- **严重程度**：P2（视觉瑕疵）
- **位置**：记录 > 统计 > Pro 锁定区域背景
- **现状**：`BTPremiumLock.fullMaskLock` 对整个 content 施加统一 `.blur(radius: 8)`，所有卡片模糊程度相同
- **预期**：设计使用渐进式磨砂 — 第一张卡片 `frost-25`（blur 4px + 75% 白底）、第二张 `frost-50`（blur 8px + 50% 白底）、第三张 `frost-gradual`（线性渐进 blur 12px），参见 `P1-10_02/code.html` L16–L21、L132/L154/L164
- **修复方向**：将统一 blur 替换为逐卡片递增的模糊 + 白色覆盖层；或在 `StatisticsView` 中为各卡片分别套用不同 blur 值的 overlay，由上至下递增模糊强度
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Core/Components/BTPremiumLock.swift` L53–54；`QiuJi/Features/History/Views/StatisticsView.swift`

---

### N-07 统计页时间范围选择器被 Pro 模糊遮罩覆盖
- **类别**：产品规格
- **严重程度**：P1（功能缺陷）
- **位置**：记录 > 统计 > 时间范围选择区域
- **现状**：V2 截图中时间范围胶囊（周/月/年）被模糊效果完全覆盖，用户无法操作
- **预期**：设计中时间范围选择器位于 Pro 锁定区域**上方**（L107–L116 在 L119 main 之前），不受模糊影响，即使未订阅也应可见可交互
- **修复方向**：将时间范围选择器从 `BTPremiumLock` 的 content 中移出，放在锁定区域之前的层级，确保其始终可见可交互
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/History/Views/StatisticsView.swift`（timeRangePicker 与 BTPremiumLock 的层级关系）

---

## 三、审查总结

| 指标 | 数值 |
|------|------|
| 截图数量 | 7 张（日历有数据、空日、空状态、训练详情上/下/菜单、统计 Pro 锁） |
| 前次问题 | 11 项 → FIXED 6 / PARTIAL 1 / OPEN 4 |
| V2 新增问题 | 7 项（P1: 1 / P2: 6） |
| 当前总遗留 | 12 项（P1: 3 / P2: 9） |

### 总体评价

**Statistics Pro Lock 体验大幅改善**：S-03 ~ S-07 全部修复，居中叠加布局 + 营销文案 + 模糊遮罩 + 胶囊 CTA + crown 图标均已到位，与设计参考高度一致。这是本次迭代最大的进步，直接改善了付费转化体验。

**Training Detail 为新增审查范围**：整体结构（统计行、Drill 卡片、Set 行、底部操作栏）实现良好，主要缺少的是「存为模版」快捷入口、「设置颜色」、休息时间数据和自定义弹窗样式等细节。

**Calendar 页面**：日历核心功能（月导航、日期选择、今日高亮、训练标记）实现正确。空日状态的内容截断和「月报/日历设置」功能入口仍是待处理项。

### 建议下一步

1. **优先修复 N-07 + S-01 + S-02**（P1）— 时间范围选择器被误遮挡、月报/日历设置/自定时间缺失影响功能完整度
2. **其次处理 N-01 ~ N-06**（P2）— Training Detail 细节打磨 + 渐进式磨砂 + 空日布局
3. **待 Pro 解锁后复验 S-09 / S-10** — 装饰线和日期格式
4. S-11 Tab 字号微调可与其他 P2 项一并批量处理
