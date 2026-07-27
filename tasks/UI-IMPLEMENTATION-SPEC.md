# UI 实施规范（UI Implementation Spec）

> **状态**：活跃文档（Living Document） | **版本**：1.0 | **创建日期**：2026-04-05
>
> **用途**：SwiftUI 开发者的唯一实施参考。合并了 `design-decisions.md`、`dark-mode-spec.md`、`design-guidelines.md`、`screenshot-index.md` 以及 14 项已知偏差修正。
>
> **优先级**：本文件 > 单个设计任务文件夹中的 DESIGN.md。
>
> **设计参考三步流程（每个任务必执行）**：
> 1. `screen.png` — 整体视觉印象与布局结构
> 2. `code.html` — 提取精确布局数值（间距、字号、排列方式、固定/滚动行为）
> 3. 本文件（`UI-IMPLEMENTATION-SPEC.md`）— Token 与组件 API（与截图/HTML 冲突时以本文件为准）

---

## 一、Design Token 完整表

### 1.1 颜色 Token（23 个，Light / Dark）

#### 品牌与功能色

| Token | 用途 | Light | Dark | SwiftUI |
|-------|------|-------|------|---------|
| `btPrimary` | 品牌主色、按钮、链接 | `#1A6B3C` | `#25A25A` | `Color("btPrimary")` |
| `btPrimaryMuted` | 主色弱化背景 | `#1A6B3C` α10% | `#25A25A` α15% | `Color("btPrimaryMuted")` |
| `btAccent` | Pro 金色、强调 | `#D4941A` | `#F0AD30` | `Color("btAccent")` |
| `btSuccess` | 正面反馈 | `#2E7D32` | `#4CAF50` | `Color("btSuccess")` |
| `btWarning` | 警告 | `#E65100` | `#FF7043` | `Color("btWarning")` |
| `btDestructive` | 危险/删除 | `#C62828` | `#EF5350` | `Color("btDestructive")` |

#### 背景色

| Token | 用途 | Light | Dark | SwiftUI |
|-------|------|-------|------|---------|
| `btBG` | 页面主背景 | `#F2F2F7` | `#000000` | `Color("btBG")` |
| `btBGSecondary` | 卡片/列表背景（别名 `btSurface`） | `#FFFFFF` | `#1C1C1E` | `Color("btBGSecondary")` |
| `btBGTertiary` | 搜索框、输入框底色 | `#E5E5EA` | `#2C2C2E` | `Color("btBGTertiary")` |
| `btBGQuaternary` | 分隔/更深层级 | `#D1D1D6` | `#3A3A3C` | `Color("btBGQuaternary")` |

#### 文字与分隔线

| Token | 用途 | Light | Dark | SwiftUI |
|-------|------|-------|------|---------|
| `btText` | 主文字 | `#000000` | `#FFFFFF` | `Color("btText")` |
| `btTextSecondary` | 辅助文字 | `rgba(60,60,67,0.6)` | `rgba(235,235,240,0.6)` | `Color("btTextSecondary")` |
| `btTextTertiary` | 弱文字/占位 | `rgba(60,60,67,0.3)` | `rgba(235,235,240,0.3)` | `Color("btTextTertiary")` |
| `btSeparator` | 分隔线 | `rgba(60,60,67,0.18)` | `#38383A` | `Color("btSeparator")` |

#### 球台专用色

| Token | 用途 | Light | Dark | SwiftUI |
|-------|------|-------|------|---------|
| `btTableFelt` | 台面绿 | `#1B6B3A` | `#144D2A` | `Color("btTableFelt")` |
| `btTableCushion` | 库边棕 | `#7B3F00` | `#5C2E00` | `Color("btTableCushion")` |
| `btTablePocket` | 袋口 | `#1A1A1A` | `#1A1A1A` | `Color("btTablePocket")` |
| `btBallCue` | 母球 | `#F5F5F5` | `#F5F5F5` | `Color("btBallCue")` |
| `btBallTarget` | 目标球 | `#F5A623` | `#F5A623` | `Color("btBallTarget")` |
| `btPathCue` | 母球路径 | `#FFFFFF` α60% | 同左 | `Color("btPathCue")` |
| `btPathTarget` | 目标球路径 | `#F5A623` α70% | 同左 | `Color("btPathTarget")` |

### 1.2 间距 Token

| Token | 值 (pt) | 典型用途 |
|-------|---------|---------|
| `Spacing.xs` | 4 | 紧凑间距 |
| `Spacing.sm` | 8 | 列表行内 |
| `Spacing.md` | 12 | 卡片内边距 |
| `Spacing.lg` | 16 | 页面水平边距、标准 padding |
| `Spacing.xl` | 20 | 较大间距 |
| `Spacing.xxl` | 24 | Section 间距 |
| `Spacing.xxxl` | 32 | 大区块 |
| `Spacing.xxxxl` | 48 | 页面级留白 |

### 1.3 圆角 Token

| Token | 值 (pt) | 典型用途 |
|-------|---------|---------|
| `BTRadius.xs` | 6 | 小标签、徽章 |
| `BTRadius.sm` | 8 | 按钮、输入框 |
| `BTRadius.md` | 12 | 卡片 |
| `BTRadius.lg` | 16 | 大卡片、弹窗 |
| `BTRadius.xl` | 20 | Sheet 顶部 |
| `BTRadius.full` | 999 | 胶囊形 |

### 1.4 字体 Token

> **更新（2026-05-26 · DR-014）**：全局字体密度优化。以角度训练首页为基准向下收敛，主要降低展示级与标题级的字号，避免列表/卡片字号过强。详见本节末尾「字号选用指引」。

| Token | 字号 | 字重 | 设计 | 用途 |
|-------|------|------|------|------|
| `btDisplay` | 44pt | Bold | Rounded | 单屏唯一核心指标数字（训练总结成功率等）|
| `btDisplaySmall` | 30pt | Bold | Rounded | 详情页 Hero 标题、卡片中等数字徽章 |
| `btLargeTitle` | 32pt | Bold | Rounded | Tab 根页面标题（训练 / 动作库 / 角度 / 记录 / 我的）|
| `btCoverWatermark` | 56pt | Black | Rounded | 练习首页封面大字水印（v7 C20）|
| `btHeroSymbol` | 32pt | Regular | Default | Hero SF Symbol（不强制 bold；v7 C21 `BTDailyLimitGate` 皇冠）|
| `btChapterNumber` | 26pt | Bold | Rounded | 章节序号（「第 N 周」「第 N 期」）|
| `btTitle` | 20pt | Bold | Rounded | Section 大标题 |
| `btTitle2` | 18pt | Semibold | Default | 次级标题、SubSection |
| `btTitleMedium` | 17pt | Semibold | Default | 编辑式次级标题（与 btHeadline 字号同，可视场景选用）|
| `btHeadline` | 17pt | Semibold | Default | 列表行主标题、卡片主标题（首选）|
| `btStatNumber` | 24pt | Bold | Rounded | 卡片内常用大数字（统计、计划页 8/3/60）|
| `btBody` | 17pt | Regular | Default | 主要正文 |
| `btBodyMedium` | 17pt | Medium | Default | 强调正文（不加粗但略重）|
| `btCallout` | 16pt | Regular | Default | 次要正文、按钮文字 |
| `btSubheadline` | 15pt | Regular | Default | 辅助信息 |
| `btSubheadlineMedium` | 15pt | Medium | Default | 辅助强调 |
| `btSubheadlineSemibold` | 15pt | Semibold | Default | 列表行序号、轻量强调 |
| `btCTALabelRounded` | 15pt | Semibold | Rounded | CTA 胶囊标签（v7 C21 `BTDailyLimitGate` 解锁钮）|
| `btFootnote14` | 14pt | Regular | Default | 介于 footnote 与 callout 间的辅助文字 |
| `btFootnote` | 13pt | Regular | Default | 时间戳、次要说明 |
| `btCaption` | 12pt | Regular | Default | 标签、图表轴 |
| `btCaption2` | 11pt | Medium | Default | 最小标签（「免费」「付费」角标）|
| `btMicro` | 10pt | Medium | Default | Timeline 小点、徽章角标（禁止用于正文信息）|

#### 字号选用指引

- **根 Tab 页标题** → `btLargeTitle`
- **Hero 标题（详情页主名称）** → `btDisplaySmall` 或 `btTitle`
- **Section 大标题** → `btTitle`
- **次级 Section** → `btTitle2`
- **卡片/列表行主标题** → 优先 `btHeadline`；需要中文编辑感时使用 `btTitleMedium`
- **正文** → `btBody`（普通）/ `btBodyMedium`（强调）
- **副标题/描述** → `btCallout`（紧靠主标）或 `btSubheadline`
- **时间戳/脚注** → `btFootnote` / `btFootnote14`
- **统计数字（卡片内）** → `btStatNumber`
- **核心展示数字** → `btDisplay` / `btDisplaySmall`
- **章节序号** → `btChapterNumber`
- **极小徽章/Timeline** → `btCaption2` / `btMicro`
- **练习首页封面水印** → `btCoverWatermark`

#### 红线（v7 D6 · 2026-07-16）

- **新代码禁止新增字面量字号**（`.font(.system(size: …))` / 裸 `Font.system(size:)`）。缺 token 时先在 `Typography.swift` 登记再引用；存量页面按页渐进迁移，不要求本轮清零。

---

## 二、组件完整清单（16 个）

### 2.1 BTButton — 7 种样式

**文件路径**：`QiuJi/Core/Components/BTButton.swift`
**设计参考**：`ui_design/tasks/A-02/stitch_task_02_02/screen.png` + `code.html`

| 样式 | 视觉 | 适用场景 | 禁用规则 |
|------|------|---------|---------|
| `primary` | btPrimary 填充 + 白字，圆角 BTRadius.sm，高度 52pt | 页面主操作 | 同一视图最多 1 个 |
| `secondary` | btPrimary 描边 + 品牌色文字，高度 52pt | 次要操作 | — |
| `text` | 无背景 + 品牌色文字 | 弱操作/取消 | — |
| `destructive` | btDestructive 文字 | 不可逆操作 | 仅删除/注销 |
| `darkPill` | `#1C1C1E` 填充 + 白字，BTRadius.full 胶囊 | 底栏关闭/返回 | 仅叠加场景 |
| `iconCircle` | 48pt 圆形，btPrimary 填充 + 白色 SF Symbol | 工具栏图标 | — |
| `segmentedPill` | 选中：btPrimary 填充+白字；未选中：白底+灰边框 | 分段选项组 | — |

**SwiftUI API**：

```swift
enum BTButtonStyle: ButtonStyle {
    case primary, secondary, text, destructive
    case darkPill, iconCircle
    case segmentedPill(isSelected: Bool)
}
```

### 2.2 BTEmptyState

**文件路径**：`QiuJi/Core/Components/BTEmptyState.swift`
**设计参考**：`ui_design/tasks/A-03/stitch_task_03_02/screen.png`

| 属性 | 规范 |
|------|------|
| 图标 | 48pt SF Symbol，btPrimary 30% 圆形底 |
| 标题 | 17pt Semibold (btHeadline) |
| 副标题 | 16pt Regular 灰色 (btCallout) |
| CTA | 可选，Primary 按钮 |

**SwiftUI API**：

```swift
struct BTEmptyState: View {
    let icon: String        // SF Symbol name
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
}
```

### 2.3 BTDrillCard

**文件路径**：`QiuJi/Core/Components/BTDrillCard.swift`
**设计参考**：`ui_design/tasks/P1-01/stitch_task_p1_01_02/screen.png`

| 属性 | 规范 |
|------|------|
| 缩略图 | 64pt 方形，圆角 BTRadius.sm，台球照片 |
| 名称 | btHeadline |
| 标签行 | 球种胶囊 + BTLevelBadge + 推荐组数 |
| 右侧 | chevron（灰色）；Pro 锁定时显示锁+PRO 金色角标 |
| Dark Mode | 缩略图添加 0.5pt btSeparator 描边 |

**SwiftUI API**：

```swift
struct BTDrillCard: View {
    let drill: DrillContent
    let isFavorited: Bool
    var onFavoriteTap: (() -> Void)? = nil
}
```

### 2.4 BTLevelBadge — 五级配色

**文件路径**：`QiuJi/Core/Components/BTLevelBadge.swift`
**设计参考**：`ui_design/tasks/A-03/stitch_task_03_02/screen.png`

| 等级 | Light 文字色 | Light 底色 | Dark 文字色 | Dark 底色 |
|------|------------|-----------|------------|----------|
| L0 入门 | 白色 | btPrimary 实心 | `#25A25A` | `rgba(37,162,90,0.15)` |
| L1 初级 | 蓝色 | 浅蓝底 15% | `#0A84FF` | `rgba(0,122,255,0.15)` |
| L2 中级 | 琥珀色 | 浅琥珀底 15% | `#F0AD30` | `rgba(240,173,48,0.15)` |
| L3 高级 | 橙色 | 浅橙底 15% | `#FF9F0A` | `rgba(255,159,10,0.15)` |
| L4 专家 | 红色 | 浅红底 15% | `#EF5350` | `rgba(239,83,80,0.15)` |

**SwiftUI API**：

```swift
struct BTLevelBadge: View {
    let level: DrillLevel   // enum: L0, L1, L2, L3, L4
}
```

### 2.5 BTBilliardTable

**文件路径**：`QiuJi/Core/Components/BTBilliardTable.swift`
**设计参考**：`ui_design/tasks/A-08/stitch_task_08_02/code.html`（PNG 可能不完整）

| 属性 | 规范 |
|------|------|
| 台面色 | btTableFelt（`#1B6B3A` / `#144D2A`）|
| 库边色 | btTableCushion（`#7B3F00` / `#5C2E00`）|
| 宽高比 | 2:1（`aspectRatio(2.0, contentMode: .fit)`）|
| 动画 | 分段播放：击球前 → 接触 → 母球走位 → 目标球走位 |

### 2.6 BTPremiumLock — 两种模式

**文件路径**：`QiuJi/Core/Components/BTPremiumLock.swift`
**设计参考**：`ui_design/tasks/A-04/stitch_task_04_02/screen.png`

| 模式 | 视觉 | 适用 |
|------|------|------|
| 渐进式锁 | 显示前 2-3 条 → 隐藏剩余 → 金色锁图标 + 金色描边「点这里解锁」 | Drill 详情 |
| 全遮罩 | Light：白色渐变磨砂 + 卡片剪影；Dark：黑色渐变 `rgba(0,0,0,0)→rgba(0,0,0,0.95)` | 统计图表 |

**Pro 金色 CTA 体系**：

| 元素 | Light | Dark |
|------|-------|------|
| PRO 徽章 | `rgba(212,148,26,0.12)` 底 + `#D4941A` 字 | `rgba(240,173,48,0.15)` 底 + `#F0AD30` 字 |
| 锁图标容器 | `#FFDDAF` 浅琥珀圆 + `#D4941A` 锁 | `rgba(240,173,48,0.20)` 圆 + `#F0AD30` 锁 |
| 金色填充 CTA | `#D4941A` + 白字 | `#F0AD30` + 白字 |
| 金色描边 CTA | `#D4941A` 边框 | `#F0AD30` 边框 |

### 2.7 BTSegmentedTab（新建）

**文件路径**：`QiuJi/Core/Components/BTSegmentedTab.swift`
**设计参考**：`ui_design/tasks/A-06/stitch_task_06_02/code.html`（PNG 可能不完整）

| 属性 | 规范 |
|------|------|
| 活跃项 | btPrimary 文字 + 底部 2pt btPrimary 下划线 |
| 非活跃项 | btTextSecondary 文字 |
| 间距 | 标签间 24pt |
| 字体 | 16pt Medium (btCallout) |

**SwiftUI API**：

```swift
struct BTSegmentedTab<T: Hashable>: View {
    let tabs: [T]
    @Binding var selected: T
    let label: (T) -> String
}
```

### 2.8 BTTogglePillGroup（新建）

**文件路径**：`QiuJi/Core/Components/BTTogglePillGroup.swift`
**设计参考**：`ui_design/tasks/A-06/stitch_task_06_02/code.html`

| 属性 | 规范 |
|------|------|
| 选中 | btPrimary 填充 + 白字 |
| 未选中 | 白底 + btSeparator 边框 + btText 文字 |
| 高度 | 36pt |
| 圆角 | BTRadius.full（胶囊形）|

**SwiftUI API**：

```swift
struct BTTogglePillGroup<T: Hashable>: View {
    let options: [T]
    @Binding var selected: T
    let label: (T) -> String
}
```

### 2.9 BTOverflowMenu（新建）

**文件路径**：`QiuJi/Core/Components/BTOverflowMenu.swift`
**设计参考**：`ui_design/tasks/A-06/stitch_task_06_02/code.html`

| 属性 | 规范 |
|------|------|
| 触发器 | 三点「⋮」图标 |
| 浮层 | 白色圆角 16pt 卡片，带阴影 |
| 菜单项 | 图标（24pt 彩色圆底）+ 标签（16pt） |
| 危险项 | 红色图标 + 红色文字 + 上方全宽分隔线 |

**SwiftUI API**：

```swift
struct BTOverflowMenu: View {
    let items: [BTMenuItem]
    struct BTMenuItem: Identifiable {
        let id = UUID()
        let icon: String          // SF Symbol
        let iconColor: Color
        let label: String
        let isDestructive: Bool
        let action: () -> Void
    }
}
```

### 2.10 BTExerciseRow（新建）

**文件路径**：`QiuJi/Core/Components/BTExerciseRow.swift`
**设计参考**：`ui_design/tasks/A-07/stitch_task_07_02/code.html`（PNG 可能不完整）

| 属性 | 规范 |
|------|------|
| 卡片 | 白色背景，圆角 BTRadius.md，高度 ~80pt |
| 左侧 | 球台缩略图 56pt 方形圆角 |
| 中部 | Drill 名称 btHeadline + 「X 组」btFootnote |
| 右侧 | 累计「0/180」btSubheadline + 齿轮图标 |
| 底部 | 进度圆点 ●●●○○（btPrimary 已完成 / btBGQuaternary 待完成）|

**SwiftUI API**：

```swift
struct BTExerciseRow: View {
    let drillName: String
    let thumbnailAnimation: DrillAnimation?
    let totalSets: Int
    let completedSets: Int
    let madeBalls: Int
    let targetBalls: Int
    var onTap: () -> Void = {}
}
```

### 2.11 BTSetInputGrid（新建）

**文件路径**：`QiuJi/Core/Components/BTSetInputGrid.swift`
**设计参考**：`ui_design/tasks/A-07/stitch_task_07_02/code.html`（PNG 可能不完整）

| 列 | 宽度 | 内容 |
|----|------|------|
| 组号 | 32pt | 数字或橙色「热」标记 |
| 进球数 | 44pt 方块 | 可编辑圆角方块，粗体数字居中 |
| 总球数 | 44pt 方块 | 同上 |
| 完成 | 44pt | 勾选：btPrimary 填充 ✓ / 灰色轮廓 |
| 菜单 | 44pt | 「⋯」溢出菜单 |

**行状态**：

| 状态 | 视觉 |
|------|------|
| 已完成 | btPrimaryMuted 浅底 + 填充 ✓ |
| 当前 | btPrimary 边框高亮 |
| 未完成 | 默认灰色边框 |
| 热身 | 组号位置橙色「热」标记 |

**SwiftUI API**：

```swift
struct BTSetInputGrid: View {
    @Binding var sets: [DrillSetData]
    var onAddSet: () -> Void
    var onComplete: (Int) -> Void   // set index
    var onDeleteSet: ((Int) -> Void)? = nil  // set index, enables overflow menu delete
    struct DrillSetData: Identifiable {
        let id: Int                 // set number
        var madeBalls: Int
        var targetBalls: Int
        var isCompleted: Bool
        var isWarmup: Bool
    }
}
```

### 2.12 BTRestTimer（新建）

**文件路径**：`QiuJi/Core/Components/BTRestTimer.swift`
**设计参考**：`ui_design/tasks/A-05/stitch_task_05_02/screen.png` + `code.html`

| 属性 | 规范 |
|------|------|
| 外环 | btPrimary 色，表示总休息进度 |
| 内环 | btAccent 金色，表示剩余秒数 |
| 尺寸 | 200pt 直径 |
| 中心 | 倒计时数字 32pt Bold + 类型标签 13pt |
| 按钮 | 「完成」Primary + 「+30s」Secondary 横向并排 |

**SwiftUI API**：

```swift
struct BTRestTimer: View {
    let totalSeconds: Int
    @Binding var remainingSeconds: Int
    var onComplete: () -> Void
    var onExtend: (Int) -> Void     // extend by N seconds
}
```

### 2.13 BTFloatingIndicator（新建）

**文件路径**：`QiuJi/Core/Components/BTFloatingIndicator.swift`
**设计参考**：`ui_design/tasks/A-05/stitch_task_05_02/screen.png`

| 属性 | 规范 |
|------|------|
| 形状 | 胶囊 BTRadius.full，高度 44pt |
| 颜色 | btPrimary 背景 + 白色文字 |
| 位置 | 右对齐距右 16pt，Tab 栏上方 8pt |
| 内容 | 「训练中 12:34 ←」 |
| 动画 | 轻微上下浮动呼吸动画 + 阴影 |

**SwiftUI API**：

```swift
struct BTFloatingIndicator: View {
    let elapsedSeconds: Int
    var onTap: () -> Void
}
```

### 2.14 BTShareCard（新建）

**文件路径**：`QiuJi/Core/Components/BTShareCard.swift`
**设计参考**：`ui_design/tasks/A-08/stitch_task_08_02/code.html`（PNG 可能不完整）

| 属性 | 规范 |
|------|------|
| 容器 | 深色主题卡片，圆角 BTRadius.lg |
| 内容 | 日期 + 训练数据 + Drill 列表 |
| 底部 | App Logo + 品牌文案 + 二维码 |
| 配色 | 支持多种预设主题 |
| 成功率色阶 | ≥90% 亮绿 / 70-89% 品牌绿 / <70% 弱化白 |

**SwiftUI API**：

```swift
struct BTShareCard: View {
    let session: TrainingSessionSummary
    let theme: ShareCardTheme
    enum ShareCardTheme: CaseIterable {
        case defaultGreen, blackWhite, nightBlue
    }
}
```

### 2.15 BTAngleTestTable

**文件路径**：`QiuJi/Features/AngleTraining/Views/BTAngleTestTable.swift`
**已存在**，保持现有 API。

### 2.16 BTBilliardTable（已有，需校验）

**文件路径**：`QiuJi/Core/Components/BTBilliardTable.swift`
**已存在**，校验台面/库边色值与 A-08-D1 一致。

---

## 三、导航模式规范（5 种）

| 模式 | 特征 | 适用页面 |
|------|------|---------|
| iOS 大标题 + 5 Tab | 34pt Bold Rounded + `#F2F2F7` 背景 | TrainingHome, DrillList, AngleHome, HistoryCalendar, Profile |
| push 子页面 | 返回箭头 + 17pt Semibold 居中标题 + 无 Tab | DrillDetail, PlanList/Detail, AngleHistory, FavoriteDrills, CustomPlanBuilder |
| Sheet 模态 | 圆角底板 + 拖拽条 + 遮罩 | DrillPickerSheet, TrainingDetail, LoginView |
| 全屏沉浸式 | 毛玻璃顶栏 + 无 Tab | ActiveTraining, RestTimer, AngleTest, TrainingNote |
| 独立全屏 | 特殊背景 + 无 Tab | Onboarding（浅色）, Subscription（深色 #111111）|

**Tab 栏规范**：

| 属性 | 值 |
|------|-----|
| Tab 数量 | 5：训练 / 动作库 / 角度 / 记录 / 我的 |
| 激活态 | btPrimary 图标 + 文字 |
| 未激活态 | 灰色图标 + 文字 |
| Tab 文案 | 固定为「动作库」（非「题库」） |
| 隐藏条件 | push 子页面、全屏沉浸、Sheet、独立全屏 |

---

## 四、页面-组件映射表

以下列出每个页面使用的 BT* 组件和对应的设计截图路径。

> 截图路径均相对于 `ui_design/` 目录。

### Tab 1 — 训练

| 页面 | 组件 | 截图 PNG | code.html |
|------|------|---------|-----------|
| TrainingHomeView（有计划） | BTSegmentedTab, BTLevelBadge, BTButton.primary | `tasks/P0-01/stitch_task_p0_01_02/screen.png` | 同目录 |
| TrainingHomeView（空状态） | BTEmptyState, BTButton.primary/secondary | `tasks/P0-02/stitch_task_p0_02_02/screen.png` | 同目录 |
| ActiveTrainingView 总览 | BTExerciseRow, BTButton.iconCircle | `tasks/P0-03/stitch_task_p0_03_02/screen.png` | 同目录 |
| ActiveTrainingView 单项 | BTSetInputGrid, BTBilliardTable | `tasks/P0-04/stitch_task_p0_04_04/screen.png` | 同目录 |
| BTRestTimer 弹层 | BTRestTimer | `tasks/P0-05/stitch_task_p0_05_restTimer/screen.png` | 同目录 |
| DrillPickerSheet | BTDrillCard, BTButton.primary | `tasks/P0-05/stitch_task_p0_05_DrillPickerSheet/screen.png` | 同目录 |
| TrainingSummaryView | BTShareCard 容器 | `tasks/P0-06/stitch_task_p0_06_trainingsummaryview_02/screen.png` | 同目录 |
| TrainingShareView | BTShareCard | `tasks/P0-06/stitch_task_p0_06_trainingshareview_02/screen.png` | 同目录 |
| TrainingNoteView | BTButton.primary/text | `tasks/P0-08/stitch_task_p0_08_02/screen.png` | 同目录 |
| PlanListView | BTDrillCard, BTLevelBadge, BTPremiumLock | `tasks/P2-01/stitch_task_p2_01_planlistview_02/screen.png` | 同目录 |
| PlanDetailView | BTButton.primary, BTPremiumLock | `tasks/P2-01/stitch_task_p2_01_plandetailview/screen.png` | 同目录 |
| CustomPlanBuilderView | BTButton.primary, BTDrillCard | `tasks/P2-02/stitch_task_p2_02_02/screen.png` | 同目录 |

### Tab 2 — 动作库

| 页面 | 组件 | 截图 PNG | code.html |
|------|------|---------|-----------|
| DrillListView（默认） | BTDrillCard, BTLevelBadge | `tasks/P1-01/stitch_task_p1_01_02/screen.png` | 同目录 |
| DrillListView（无结果） | BTEmptyState | `tasks/P1-02/stitch_task_p1_02_02/screen.png` | 同目录 |
| DrillDetailView（完整） | BTBilliardTable, BTButton.primary/darkPill, BTLevelBadge | `tasks/P1-03/stitch_task_p1_03_02/screen.png` | 同目录 |
| DrillDetailView（Pro 锁） | BTPremiumLock（渐进式）, BTButton.goldFilled | `tasks/P1-04/stitch_task_p1_04_02/screen.png` | 同目录 |
| FavoriteDrillsView | BTDrillCard | `tasks/P2-07/stitch_task_p2_07_favoritedrillsview/screen.png` | 同目录 |
| FavoriteDrillsView（空） | BTEmptyState | `tasks/P2-07/stitch_task_p2_07_favoritedrillsviewempty/screen.png` | 同目录 |

### Tab 3 — 角度

| 页面 | 组件 | 截图 PNG | code.html |
|------|------|---------|-----------|
| AngleHomeView | BTButton.primary | `tasks/P1-05/stitch_task_p1_05_02/screen.png` | 同目录 |
| ContactPointTableView | — | `tasks/P1-05/stitch_task_p1_05_contactpointtableview_02/screen.png` | 同目录 |
| AngleTestView 答题 | BTAngleTestTable | `tasks/P0-07/stitch_task_p0_07_angletestview_02/screen.png` | 同目录 |
| AngleTestView 结果 | BTAngleTestTable | `tasks/P0-07/stitch_task_p0_07_angletestviewresult_02/screen.png` | 同目录 |
| AngleHistoryView | — (Swift Charts) | `tasks/P1-06/stitch_task_p1_06_02/screen.png` | 同目录 |
| AimingPrincipleView | — (Canvas 插图) | `tasks/P9-02/stitch_task_p9_02_aimingprinciple/screen.png` | 同目录（P9 待产出） |
| AngleDynamicView | — (Canvas 交互) | `tasks/P9-03/stitch_task_p9_03_angledynamic/screen.png` | 同目录（P9 待产出） |
| GeometricAngleQuizView | — (Canvas) | `tasks/P9-04/stitch_task_p9_04_geometricquiz/screen.png` | 同目录（P9 待产出） |
| SceneAnglePredictionView 2D 答题 | AngleSceneView | `tasks/P9-05/stitch_task_p9_05_sceneprediction_2d/screen.png` | 同目录（P9 待产出） |
| SceneAnglePredictionView 3D 答题 | AngleSceneView | `tasks/P9-05/stitch_task_p9_05_sceneprediction_3d/screen.png` | 同目录（P9 待产出） |
| BallFeelView | — (Canvas 插图) | `tasks/P9-07/stitch_task_p9_07_ballfeel/screen.png` | 同目录（P9 待产出） |

### Tab 4 — 历史

| 页面 | 组件 | 截图 PNG | code.html |
|------|------|---------|-----------|
| HistoryCalendarView（有数据） | BTSegmentedTab | `tasks/P1-07/stitch_task_p1_07_02/screen.png` | 同目录 |
| HistoryCalendarView（空） | BTEmptyState | `tasks/P1-08/stitch_task_p1_08_historycalendarview_02/screen.png` | 同目录 |
| TrainingDetailView | BTOverflowMenu, BTButton.primary/secondary | `tasks/P1-08/stitch_task_p1_08_trainingdetailview_02/screen.png` | 同目录 |
| StatisticsView（有数据） | BTSegmentedTab (Swift Charts) | `tasks/P1-09/stitch_task_p1_09_02/screen.png` | 同目录 |
| StatisticsView（Pro 锁） | BTPremiumLock（全遮罩） | `tasks/P1-10/stitch_task_p1_10_02/screen.png` | 同目录 |

### Tab 5 — 我的

| 页面 | 组件 | 截图 PNG | code.html |
|------|------|---------|-----------|
| ProfileView（已登录） | BTButton.destructive | `tasks/P2-03/stitch_task_p2_03_userprofile_02/screen.png` | 同目录 |
| ProfileView（访客） | BTButton.primary | `tasks/P2-03/stitch_task_p2_03_guestprofile_02/screen.png` | 同目录 |
| OnboardingView | BTButton.primary/text | `tasks/P2-04/stitch_task_p2_04_02/screen.png` | 同目录 |
| LoginView | BTButton（Apple黑/微信绿/手机号描边） | `tasks/P2-05/stitch_task_02_05_loginview_02/screen.png` | 同目录 |
| PhoneLoginView | BTButton.primary/text | `tasks/P2-05/stitch_task_02_05_phoneloginview/screen.png` | 同目录 |
| SubscriptionView | BTButton.primary | `tasks/P2-06/stitch_task_p2_06_02/screen.png` | 同目录 |

### 全局组件

| 组件 | 截图 PNG | code.html |
|------|---------|-----------|
| BTFloatingIndicator 跨 Tab | `tasks/P2-08/stitch_task_p2_08/screen.png` | 同目录 |

### Dark Mode 参考帧

| 页面 | 截图 PNG |
|------|---------|
| TrainingHomeView Dark | `tasks/E-01/stitch_task_e_01/screen.png` |
| ActiveTraining 总览 Dark | `tasks/E-01/stitch_task_e_01_frame2/screen.png` |
| ActiveTraining 记录 Dark | `tasks/E-01/stitch_task_e_01_frame3_02/screen.png` |
| TrainingSummary Dark | `tasks/E-01/stitch_task_e_01_frame4_02/screen.png` |
| PlanListView Dark | `tasks/E-01/stitch_task_e1_frame5/screen.png` |

---

## 五、已知偏差修正（14 项）

开发时**必须按开发基准实施**，不按截图中的偏差值。

### 5.1 Light Mode（7 项）

| # | 偏差 | 偏差页面 | 开发基准 |
|---|------|---------|---------|
| L-1 | 底部添加按钮蓝色 | P0-03 | btPrimary `#1A6B3C`（参照 P0-04）|
| L-2 | 大标题居中偏小 | P1-09 | 左对齐 34pt Bold Rounded（参照 P1-07）|
| L-3 | 卡片左侧绿线 | P1-09 | 统计页面专属装饰，**保留** |
| L-4 | 缩略图为电钻 stock 图 | P2-07 | 替换为台球场景照片 |
| L-5 | Tab 显示「题库」 | P2-08 | 使用「动作库」（参照 P1-01）|
| L-6 | 退出登录色偏 | P2-03 | btDestructive `#C62828` |
| L-7 | 卡片圆角 8px | P2-07 | BTRadius.md = 12pt |

### 5.2 Dark Mode（7 项）

| # | 偏差 | 偏差帧 | 开发基准 |
|---|------|--------|---------|
| D-1 | Chip 选中态白描边 | E-01 帧1 | `#F2F2F7` 填充 + 黑字 |
| D-2 | 球台区琥珀边框 | E-01 帧3 | P0-04 为准（无边框）|
| D-3 | 「详情」标签 | E-01 帧4 | 跟随 Light Mode P0-06 |
| D-4 | 底部显示 Tab | E-01 帧5a | push 子页面不显示 Tab |
| D-5 | PRO/Level 合并 | E-01 帧5a | 分别独立显示 |
| D-6 | 缺少 chevron | E-01 帧5a | 补充 chevron |
| D-7 | PlanDetailView Dark 未交付 | E-01 帧5b | 标准 Token 映射 |

---

## 六、Dark Mode 全局规则

### 6.1 页面背景

- 所有页面 → `#000000`（OLED 纯黑）
- 状态栏 → 白色文字

### 6.2 卡片容器

- 背景 → `#1C1C1E`
- **移除所有阴影**，靠色差分层
- 需区分时 → `#38383A` 1px 细边框

### 6.3 筛选 Chip

- 选中：`#F2F2F7` 填充 + `#000000` 文字
- 未选：`#2C2C2E` 填充 + `rgba(235,235,240,0.6)` 文字 + `#3A3A3C` 描边

### 6.4 排除 Dark Mode 的页面

| 页面 | 理由 |
|------|------|
| OnboardingView | 品牌首屏保持浅色 |
| SubscriptionView | 自身深色 `#111111` |
| TrainingShareView | 分享卡自身深色 |

### 6.5 SwiftUI 实施模式

```swift
// 阴影 Dark 下移除
.shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.1), radius: 8, x: 0, y: 2)

// 缩略图 Dark 描边
.overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.btSeparator, lineWidth: colorScheme == .dark ? 0.5 : 0))
```

---

## 七、关键页面决策速查

### 训练流程

| 决策 | 值 |
|------|-----|
| 筛选 Chip 选中态 | `#1C1C1E` 填充 + 白字（非品牌绿）|
| 全屏训练页框架 | 毛玻璃顶栏 + 5 键底栏 |
| 热身标记 | 橙色「热」代替组号 |
| 网格在上球台在下 | 信息优先级 |
| 分享卡成功率色 | ≥90% 亮绿 / 70-89% 品牌绿 / <70% 弱化白 |

### 动作库

| 决策 | 值 |
|------|-----|
| 详情导航栏 | 居中中文 Drill 名 |
| 操作图标行 | 灰色非品牌绿 |
| 详情底栏 | darkPill「关闭」+ primary「加入训练」|
| Pro 锁底栏 | 金色填充「解锁 Pro」|
| Pro 锁内容 | 隐藏（非模糊）下方区块 |

### 历史与统计

| 决策 | 值 |
|------|-----|
| 月历 | 完整 6 行，下月灰显 |
| 训练日标记 | 绿底白字小胶囊 |
| 周末不标红 | 避免与错误语义混淆 |
| Section 标题 | 统计页 btPrimary 色，其他页黑色 |
| 图表双色 | 琥珀 `#F5A623` 时长 + btPrimary 成功率 |
| 卡片左侧绿线 | 统计页面专属装饰 |

### 辅助页面

| 决策 | 值 |
|------|-----|
| 登录三按钮层级 | Apple 黑 > 微信绿 > 手机号描边 |
| 付费墙背景 | 全屏深色 `#111111` |
| 年订推荐 | 绿框 + 推荐标签 + 勾选 + 月均 |
| 收藏页 | 无搜索/筛选，纯列表 |

---

## 八、场景页规范（明暗三档 + 瞄准辅助显示矩阵）

> 来源：P18 B3 T-P18-13（10-d）。「场景页」= 以 USDZ 球桌（`AngleSceneView`/`AngleTrainingScene`）或全屏画布为主体的页面。

### 8.1 明暗三档策略

| 档 | 策略 | 实施方式 | 适用页面 |
|---|------|---------|---------|
| ① 场景页 = 黑底暗语言 | 页面**不改系统 colorScheme**，用 `.background(Color.black.ignoresSafeArea())` + 白字 + 半透明白卡（`.white.opacity(0.06~0.12)`）；毛玻璃控件局部 `.environment(\.colorScheme, .dark)` 保证材质暗解析 | 黑底是设计常量，Light/Dark 下观感一致，无需双值 Token | 分离角与走位、分离角图谱（学）、走位编排台（含自由击球）、思路训练器、打一走二想三、做斯诺克、球形生成器、2D/3D 瞄准训练、角度与打点、几何角度预测、翻袋解球、反射解球、拍照建球形、批量出片台（SIM） |
| ② 常规页 = 随系统 | Token 双值（§一/§六），不强制 colorScheme | 全部 Tab 常规页面 | 训练 / 动作库 / 练习首页 / 历史 / 我的 及其子页 |
| ③ 特例页 = 强制 | 显式 `preferredColorScheme` | `SubscriptionView` 强 dark（自身 #111111）；`OnboardingView` 强 light（品牌首屏）；`TrainingShareView` 分享卡自身深色 | 仅此三页，新增特例须记 Changelog |

**场景页控件语言**（与 ① 配套）：主操作 = 品牌绿实底胶囊（白字 semibold rounded）；次级 = 半透明白胶囊（`.white.opacity(0.12)`）；分段 = `BTChipRow`；FAB = `BTSceneFAB`；底部控制条 = `ShotControlBar`。禁止在场景页使用常规页组件样式（如 `BTButtonStyle.primary` 大圆角矩形按钮）。

### 8.2 瞄准辅助显示矩阵（8 场景页 × 6 辅助元素）

图例：●=常驻 ◐=条件显示（括注条件） ○=不显示。「假想球 ghost」列的形态与档位细则见 §8.7 重叠标注三档配档表（T-P18-42 后 ghost = 绿虚线圈 + 接触点绿点成对出现）。

| 场景页 | 瞄准线（母球→假想球） | 进球线（目标→袋） | 假想球 ghost | 轨迹预测线（母/目标） | 分离角标注 | 切角/厚度读数 |
|---|---|---|---|---|---|---|
| 分离角与走位 `ShotSimulationView` | ●（手动模式另画自动解虚线对照） | ● | ● | ●（真实模拟折线） | ◐（`showSeparationAngle`） | ●（顶部指标胶囊） |
| 走位编排台/自由击球 `PositionPlayComposerView` | ● | ●（袋口模式） | ● | ●（含 `extraBallPaths` 碰后方向） | ◐（`showSeparationAngle`） | ●（首碰胶囊：厚度重叠+切角+碰球号，自由模式） |
| 思路训练器 `SiluTrainerView` | ●（解出后） | ● | ● | ●（解的轨迹+落区/过点叠加） | ◐（`showSeparationAngle`） | ○ |
| 打一走二想三 `PlanThreeView` | ●（解出后） | ● | ● | ● | ◐（`showSeparationAngle`） | ○ |
| 做斯诺克 `SnookerTacticsView` | ●（解出后） | ○（安全球不进袋） | ● | ●（+遮挡扇形叠加） | ◐（`showSeparationAngle`） | ○ |
| 球形生成器 `RackGeneratorView` | ●（开球瞄准线，锁顶球） | ○ | ○ | ○（开球后直接回放） | ○ | ○ |
| 2D/3D 瞄准训练 `Scene2D/3DAimingView` | ●（含「瞄准线」文字标注；3D 隐藏文字） | ●（同上） | ● | ○ | ○ | ●（角度弧+读数） |
| 角度与打点 `AngleDynamicView` | ● | ● | ● | ○ | ○ | ●（常驻指标行：角度/厚度图示/d/R/横移） |

**`showSeparationAngle` 设置项覆盖范围声明**：该开关（设置·瞄准辅助，默认关）门控上表 5 个场景页 + drill 回放（`DrillSceneView`）共 **6 处**的分离角标注；不影响 2D/3D 瞄准训练与角度与打点（其角度弧为教学主体非辅助）。

### 8.3 场景页导航栏规范（T-P18-31 / G20）

所有黑底练习页（测验 + 沙盘 + 向导确认步）统一 chrome：

- **`toolbarColorScheme(.dark, for: .navigationBar)`** + **`toolbarBackground(Color.black, for: .navigationBar)`** + **`toolbarBackground(.visible)`**——禁止亮色导航栏跳变。
- **principal**：统一用共享 `BTSolverNavStatus`（品牌绿 14pt 标题；可选 11pt 副行承载状态文案；`statusText: nil` 且非 busy 时仅标题——暗色测验页简化形态，组件同源）。禁止页面再自写 `navStatus`。
- **标题颜色**：全局 `UINavigationBarAppearance.titleTextAttributes` 已设品牌绿；`.toolbarColorScheme(.dark)` 会把系统标题渲成白色——故凡走 dark chrome 的页**必须**自带 principal（`BTSolverNavStatus`）。
- **Frame preference**：场景/球库 frame 上报一律走共享 `BTShotPageFramePreference`（`SolverFramePreference` 为迁移别名）。
- **右上角控件语义分工**（每页最多两个图标）：
  - 齿轮 `gearshape.fill` = 页面级设置（训练设置、求解范围等 Toggle 类）；
  - (i) `info.circle` = 帮助/原理说明（打开说明 sheet）；
  - 省略号 `ellipsis.circle` = 文档/桌面操作（重命名、清空桌面、恢复默认等动作类）。
- 归位基线（2026-07-04）：2D/3D 瞄准=齿轮 ✓；翻袋/反射=(i) ✓；编排台=省略号（重命名/清空）✓；思路/打一走二想三/做斯诺克的「求解范围」Toggle 从省略号菜单迁至齿轮菜单，省略号只留动作类。
- G10 顶/底栏定高：`ShotStageMetrics.topRowHeight`（46）+ `BottomBarHeight` 三档（`.paletteOnly` 78 / `.composer` 94 / `.planThree` 116）。

### 8.4 场景页顶部控制区「最多两行」硬规范（T-P18-32）

- 场景页顶部控制区（`safeAreaInset(edge: .top)` 内）**≤2 行**；超出的控件收进抽屉/浮层/右上角菜单。
- 常驻说明文案（教学解释类长文本）禁止占顶部行，收进 (i) 说明 sheet。
- 求解状态 pill（求解中/有解/无解）不计入行数——以浮层形式叠在球桌上（`overlay`），不参与 `safeAreaInset` 挤压球桌高度。
- 发力滑块等条件展开控件优先与所属 chips 同行内联，放不下时走浮层。

### 8.5 色彩语义（T-P18-39）

| 色 | 语义 | 用途示例 | 禁止 |
|---|------|---------|------|
| 品牌绿 `btPrimary` | 主操作 / 选中态 | 击球按钮、选中 chip、场景页标题 | 用作警示 |
| 橙（`.orange`） | 次级操作强调 | 「试打」按钮 | 同屏再用橙表状态/进行中 |
| 金 `btAccent` | 控件量值 / 商业化 | 发力滑条 tint、剩余次数、Pro/订阅 | 用作普通选中态（袋口选择 chips 为既有例外，v1.x 收敛） |
| 状态色 | 仅状态反馈 | 成功=btSuccess、错误/危险=红、警示=btWarning 橙 | 与操作色混用 |

### 8.6 无障碍基线（并入本节走查，来源 U2）

- 常规页：Dynamic Type 至 XL 档不破版；可点控件全有 `accessibilityLabel`。
- 场景页（画布类）声明豁免 Dynamic Type；但顶部胶囊/底栏按钮仍须有 `accessibilityLabel`。

### 8.7 重叠标注三档配档表（T-P18-42，设计稿 §1.3；细化并接管 §8.2 的「假想球 ghost」列）

三档定义（组件真源：`AngleTrainingScene.ghostBallNode` = **品牌绿虚线圈**〔16 段贴台呢平放，`TrajectoryStyle.contactColor` + `lineHint`〕；`contactDotNode` = 接触点绿点，摆位统一走 `updateContactDot(ghostCenter:targetCenter:)`）：

- **L0 基础档**：假想球虚线圈 + 接触点绿点，零文字零占位——所有瞄准场景常驻，潜移默化教「什么角度打哪里」。
- **L1 读数档**：L0 + 切角数值（贴弧或紧邻 HUD 读数）。
- **L2 全指标档**：L0 + 顶部完整指标条（切角/厚度图示/d/R/横移/偏移）——**仅角度与打点一页**（教学页，指标条即内容本体；其他页嫌占空间的根因是错用了 L2，降档即解）。

| 页面 | 档位 | L0 呈现时机 | 数值载体 | 理由 |
|---|---|---|---|---|
| 角度与打点 | **L2**（唯一） | 常驻（拖球实时） | 顶部指标条（§8.2）+ 贴弧角度 | 教学页，指标即内容 |
| 2D/3D 瞄准训练 | L1 | 辅助开启时（答题公平性：辅助关闭=无任何线） | 贴弧角度读数 | 练估角需对照读数 |
| 分离角与走位 | L1 | 自动=解出即显；手动=瞄准射线首碰实时 | 顶部「夹角」BTReadout | 分离角是页面主题 |
| 走位编排台 / 自由击球 | L0 | 袋口模式=解出即显；自由模式=瞄准首碰实时 | 首碰胶囊（Z2，切角+厚度+碰球号） | 主线是走位编排，台面不加读数抢焦点 |
| 思路训练器 | L1 | 选球选袋即时几何预览 + 解出后 | 解摘要（ShotControlBar readOnly） | 反解页读数在 HUD 不贴弧 |
| 打一走二想三 | L1 | ①球预览 + 解出后 | 同思路 | 同思路 |
| 做斯诺克 | L0 | 解出后（首碰瞬间母球球心摆圈） | 无切角读数 | 安全球不进袋，无切角教学诉求 |
| 翻袋解球器 | L0 | 解出后（接触点绿点） | 解 pill「切角 X°」（Z4） | 台面已有解路线，读数入 pill |
| 反射解球器 | L0 | 解出后（有球-球接触时） | 无 | 绕库到点为主，接触为次 |
| 角度预测 | —（题面抽象画布） | T-P18-46 真台化后升 L0 | 结果角标 | 46 重构时接入 |
| 学三页（原理/球感/对照表） | 插图内含 L0 元素 | T-P18-46 真台化插图 | — | 插图与场景页同语言 |
| 渲染管线（`SequenceVideoExporter`） | L0 | 每杆预告帧（袋口模式） | HUD 条（打点/力度） | 与 App 同源同语义 |

> 显隐原则（设计稿 §1.3）：**用户此刻的任务需要哪条线才画哪条线**——瞄准任务显示瞄准线，进球判断任务加进球线，走位任务加球迹线；不为装饰画线。L1 的「贴弧数值」在思路/三杆等反解页暂以 HUD 读数替代，台面贴弧收尾随 T-P18-43/44/46。

### 8.8 术语词表（T-P18-50，设计稿 §4-2；用户可见文案唯一口径）

> 适用范围：练习 Tab 全部页面 + 渲染管线产物（HUD/字幕）+ 历史/记录展示。代码注释与内部标识符不强制，但**新增用户可见字符串必须查表**；表外新术语先入表再上屏。

| 规范术语 | 含义 | 禁用别名 |
|---|---|---|
| 切角 θ | 瞄准线与进球线的夹角（0°=正撞）；全局用户可见符号统一 **θ**（问题集合条 4.4，A8 落地） | α（旧符号）、切球角、切球、cut angle 直译混排 |
| 假想球 | 母球撞击目标球瞬间所在虚位（虚线圈；球心记 **G**，红点=瞄准点） | 幽灵球、ghost ball |
| 力度 | 击球初速（m/s，量程 `ShotTuning.velocityRange`） | 发力、power 直译 |
| 厚度 | 重叠比例（正/半/薄…） | 厚薄度 |
| 横移 mm | 接触点相对球心的横向偏移（毫米） | — |
| 偏移 % | 瞄准偏移百分比 | — |
| 塞 / 打点 | 左右塞、高低杆的击点选择 | 加塞（保留口语场合）、spin 直译 |
| 库 | 台边（1 库/2 库…） | 颗星（教学页解释钻石系统时可提及一次） |
| 分离角 | 母球与目标球碰后路径夹角 | — |
| 瞄准线 / 进球线 / 球迹线 | §8.2/设计稿 §1.2 线语言三名词 | 击球线、走位线 |
| 接触点 | 两球碰撞瞬间的球面切点（目标球侧 Pt=背袋点、母球侧 Pc=对应点，Q=碰合点）；与「瞄准点」严格区分（v11 Y1，FL-026 口径） | 撞击点 |
| 管道 / 试瞄角 φ | 「瞄准方法」页管道瞄准法专用：瞄准线/进球线扩成的半径 R 圆管；用户试拖的瞄准角 φ（相切 ⇔ φ=θ）（v11 Y1） | 隧道（正文可括注一次） |
| 切线 | 过接触点、垂直连心线的方向；滑动状态母球碰后沿切线离开（90° 法则 / 切线法则）（v11 Y2） | tangent line 直译混排 |
| 滑动 / 前旋 / 后旋 / 自然滚动 | 母球旋转状态四态：滑动=纯平移（stun 括注，口语定杆括注）；前旋=高杆（口语跟进括注）；后旋=低杆（口语缩杆括注）；自然滚动=线速与自转匹配稳态（v11 Y2） | 英文单用；跟进/缩杆单用（可括注） |
| 打滑极限 | 可靠打点上限 = `CuePhysics.miscueLimitFraction`·R（当前 0.5R）；超过易滑杆（滑杆=后果描述非术语）（v11 Y2） | miscue 直译 |
| 挤偏 / 弧线 / 投掷 | squirt / swerve / throw 的规范中文名（英文仅括注）；深讲归「瞄准修正」页（v12），其余页只作一句话概念（v11 Y2 预告口径） | 让点/喷射单用 |
| 页名 = 入口卡名 | 「角度预测」「2D/3D 角度训练」「翻袋解球器」等，卡与导航标题逐字一致；批改名：瞄准训练→角度训练、进球点对照表→瞄准点对照表、走位编排台→自由走位、思路训练器→思路训练；**问题集合 v5 增补**：角度与打点→**角度与瞄准**、做斯诺克→**防守** | 旧页名 |

### 8.9 瞄准与求解交互规范（问题集合 v5 定稿，2026-07-13）

> 来源：`问题集合_v5.md` G13–G18 各批（V1–V10）执行结论提炼，语义不增删。适用范围：全部接了瞄准拖动 / 需要求解的场景页（自由击球、自由走位含试打变体、分离角与走位、批量出片台、翻袋自由、反射自由、2D/3D 瞄准点训练、思路训练、打一走二想三、防守、开球四宿主）。四条全局契约与后续新页一律遵守。

**a. 瞄准拖动 = 选中 + 相对调整（G13，V1 定稿）**

- 空白处起手拖动时，**第一落点只选中瞄准线、不转向**（`AngleSceneView.Coordinator.handlePan` 的 `.began` 不回调）；随后每帧把手指绕**母球屏幕投影**的角位移换算为瞄准线的相对旋转（喂 `rotatedAim`）——「抓住线甩」，径向拖动不转向、切向才转向。
- 增益模型 = **绕母球公转**（杠杆自适应，非固定 度/pt）：手指绕母球公转 1° ⇒ 瞄准线转 1°；等价切向增益 = `(180/π)/r` 度/pt（r = 手指到母球屏幕距离 pt），故天然随母球距离缩放（远=细调、近=粗调）。近母球处发散，用最大切向增益 `maxGainDegPerPt = 0.6` 度/pt 封顶（`AngleSceneCalculator.aimNudgeDegrees` 默认参数；约为 `BTAimWheel` 细调 0.15 度/pt 的 4 倍）。**0.6 为代码默认，待真机手感定稿**——偏灵/偏钝调此单一常量。
- **tap（点击）绝对指向语义按现状保留**（v5 只改拖动语义，未发现冲突）。
- 开球模式（G18）的拖屏调向与左侧 `BTAimWheel` 复用同一 V1 链路（`aimNudgeDegrees` + `rotatedAim`）。

**b. 求解去抖（G14，V1 定稿）**

- 任何需要求解的瞄准/拖动变更（拖瞄准线、拖球、瞄准刻度条），拖动过程中**不触发求解**，只做纯几何预览（假想球 / 首碰点 / 闭式瞄准线，空杆延伸库边走共享 `rayToInnerRail`）。
- 用户停下（无新输入）**0.5s idle** 后才触发求解（`SolveDebounceScheduler`：交互态拖动挂起 + 0.5s idle 触发；离散态保留 ~20ms）。
- 落点：`PositionPlayViewModel.recompute(interactive:)` 调度层、`BankShotViewModel`/`DiamondSystemViewModel` 求解模式（原 120ms → 0.5s idle）、`BTAimWheel` 消费方及后续新页。纯几何预览路径（翻袋/反射自由模式拖动本就不求解）不受影响。

**c. 开球通用规范（G18，V6 定稿）**

- **单一真源** `BreakFlowRunner` + 共享 `BreakControlBar` + 共享 `BreakInstrumentsOverlay`；`FreePlayBreakBar` 已删除（消灭双开球条真源）。
- 随机性**只保留球堆的球与球间距**（`RackLayout.jitterRadius` 保留；`breakJitter` 随机塞已删，spinX/spinY 恒 0）。
- **开放瞄准**：开球模式支持拖屏调整瞄准方向（遵 G13 相对调整语义）+ 左侧 `BTAimWheel`；未手动调向时默认锁顶球跟随，手动调向后固定绝对方向。
- **力度条默认 6 m/s**（`BreakFlowRunner.velocity`，常量 `defaultBreakVelocity = 6.0`，替代原固定 7.0），右侧 `BTShotInstrumentColumn` 绑定可调；布局遵 `ShotStageProxy` 标准（G4/G5/G7，左瞄准轮 + 右力度柱同底贴边，仅 `.racked` 可调）。
- 按钮：`取消`（最左）/ `重开`（次级恒显，`reRack()` 换 seed 重摆，合并原「换一局」语义）/ 主按钮（最右：手动交付且停稳=`完成`，否则=`开球`）——相对旧 `FreePlayBreakBar` 完成/重开**位置互换**。
- 适用宿主（四可达）：自由击球（FreePlay）、思路训练（Q14）、打一走二想三（Q15.4）、**自由走位 Composer（D12/W9b 已放开）**。入口一律 `BTBreakSideButton`（AX `break.entry`）；`BreakEntryTile` 已删（C32）。无开球页按 D14 **不显示**禁用占位。

**d. 「上一杆」= 完整快照恢复（G17，V3 定稿 + V8/V9 扩展）**

- 所有场景「上一杆」= 回到上一杆击打前的**完整状态**：球形 + 选择模型（目标/袋口或角色/约束）+ 解集缓存 + 打点/力度/瞄准 + 求解选项，**不重求解**（`isComputing`/`isSolving` 恒 false）。
- 共享结构 `SolveShotSnapshot`（`before` 球形 + `shot` + `prediction` + `solutions`/`currentIndex` 解缓存 + `draft` 约束 + `velocity`/`spinX`/`spinY` + `allowSideSpin`/`basicPositionOnly`）+ `SolveConstraintDraft`（`region`/`restPoint`/`passPoint`，两页 `Draft` 上收单一口径）；页面特有选择模型由各 VM 的 `UndoContext` 以本快照为基座携带（思路=目标球+袋口，打三=①②③角色，防守=目标球）。
- **翻袋/反射用页面原生类型 `SolveUndoContext`**（引擎解为 `BankEngineSolution`/`KickEngineSolution`，与 `SolveShotSnapshot` 的 `PositionPlaySolution` 类型不兼容，取舍已在真源 V9 段留档）；`SolveShotSnapshot` 结构未改。

**e. 其余全局小件登记（V2/V4/V8）**

- **回放禁尾速截断（G15，V2）**：删除 `TrajectoryPlayback.perceptibleSettleTime()` 方法及全部 14 个消费点，统一 `let settle = playback.duration`（播满引擎自然静止，不做 0.07 m/s 感知截断）；`stateAt` stationary 置零与 `EngineNumerics` 0.001 静止判定保留（物理语义）；`SequenceVideoExporter` 本就同口径无需改。副作用：收尾比旧截断晚 ~0.3–0.5s（被消除的 creep 尾段真实时长），属预期。
- **打点盘 inset 5→2（G16，V2）**：`BTSpinPad` 一处改动（盘区 104×104、卡片 228 不变；白盘直径 94→100，打滑圈/皮头斑随 ballR 等比放大）。
- **设置入口三点统一（G19，V2）**：`ellipsis.circle` 扫替练习 Tab（AngleDynamic/SceneAiming）+ 外围（CustomPlanBuilder/BTExerciseRow）；**ProfileView「偏好设置」行 `BTIcon.gear` 豁免保留**（iOS 设置风格导航行徽标，非图标按钮式入口）。翻袋/反射 i→三点（原理说明 + 网格 Toggle）随 Q17/Q18 落地。**内容层顺序见 G25**（本条只定图标真源）。
- **防守评分权重（V8）**：对手进球难度 `d = 0.6·(切角/90°) + 0.4·min(1, 球距/2.54m)`，权重集中在 `AngleSceneCalculator` 常量单点可调，**v1 待实测调优**（见遗留项）。

**f. 动作列文案字典 + 左下插槽协议（G24，v7 W9a）**

- **主击文案字典**（`BTStrikeTitle`）：自由试打=`击球` / 解演示=`击打` / PlanThree 合法值=`打一`（D13）；忙碌态=`击球中`/`演示中`。中钮：`replayCurrent`→「重打」，真 `undoLastShot`→「上一杆」。
- **Slot L1 五选一**（贴底，外形 `ShotStageMetrics.breakButtonSize` / `BTSlotL1Button`）：开球 | 禁用开球 | 下一解 | 恢复球形 | 重摆球形。反解竖叠「求解/下一解」=`BTSolverLeftColumn`。无开球页不显示禁用占位（D14）。

**g. 三点菜单内容模板（G25，v7 W9b）**

- 单一组件 `BTSolverMoreMenu`（`BTShotPageChrome`）：固定顺序 = 原理说明（可选）→ Section「求解范围」（可选）→ Section「显示」网格 → `pageExtras` → 清空桌面（可选）→ **恢复默认**（可选；统一文案，禁止「重置默认球形」）。
- 三套模板：解球器（Bank/Diamond：`onPrinciple`+`onReset`）；反解训练（Silu/PlanThree/Snooker：`solveRange`+清空+恢复默认）；自由击打（Composer/FreePlay/ShotSim：显示+页特有；Composer「清空并重来」为页特有语义豁免，不并入「恢复默认」）。
- **测验页 trailing（C31）**：有可配项（台面网格 / 训练设置）必须提供三点入口——AimPointScene（2D/3D）补 `BTSolverMoreMenu` 网格；AimPointTraining（2D 特写、无 `AngleTrainingScene`）无可配项，代码注释留档不并三点；Geometric 无可配显示项 → **不并三点**，重置统计保留独立 trailing（与三点并存策略=「重置统计是破坏性动作，不塞菜单」）。
- **测验页主操作按钮（C30）**：Geometric / AimPointTraining 主 CTA 一律 `BTTextActionButton`（与 SceneAiming / AimPointScene 同源）。`NumericKeypadHUD` 呈现契约 = **全屏 ZStack 底浮层**（与 SceneAiming 同构；不用 `safeAreaInset`，避免压缩球桌/画布高度）。

---

## 九、练习体验品牌设计定稿（「球迹 · 教练仪表盘」，T-P18-52 收录设计稿 v4）

> 真源：`docs/research/20260704-练习Tab功能契约梳理.md`（设计过程与理由）；本节是**实现后的定稿契约**——B3.5 批（T-P18-41~52）全部落地后的现行规范。改任何场景页 UI 前先读本节。

### 9.1 设计语言（五签名元素 + 唯一真源索引）

**品牌概念**：台面是世界，其余皆仪表。个性三关键词：精密（仪器感）、教练（战术板）、专注（夜场聚光）。场景页任何元素先问「它是仪表盘上的哪件仪器」，说不清就不该存在。

| 签名元素 | 内容 | 代码唯一真源 |
|---|---|---|
| ① 轨迹与标注语言（**v2**，问题集合条 12） | 线色=球的身份（白=母球路径；目标球本色=该球路径，深色球取亮变体）；线型 v2：瞄准线=白**实线**唯一实线，**进球线与所有击后轨迹（母球+全部被带动球）一律虚线**（本色绑定保留）；短虚线=理论释义（90° 分离角=品牌绿短虚线过假想球心，DR-021）；**假想球心=红点（瞄准点唯一标记），接触点=绿点**；金=方案标记专属；球选中圆圈全局移除（拍照建球形除外） | `TrajectoryStyle`（App 场景页 + `SequenceVideoExporter` 全部产物同源） |
| ② 标注三档（**v2**，条 12.5） | `BTTrajectoryDetailChip` 三档全页统一：全部球轨迹 / 仅母球+目标球 / 仅瞄准线+假想球；自由模式未碰目标球时瞄准线延伸至库边；配档表见 §8.7 | `BTTrajectoryDetailChip` / `AngleTrainingScene.ghostBallNode` |
| ③ 读数胶囊 | label+value 仪表窗；金=可调、白=测量、红=失误；数字 `.rounded + monospacedDigit` | `BTReadout` |
| ④ 交互语言（**v2**，条 13/18） | 自由瞄准：粗调=手指跟随（球命中优先移球）、细调=贴缘**纯相对**刻度轮（无绝对角度/数值）；力度柱：量程 0.5–8.0 m/s、非线性 γ=1.8（低段细高段快）、两行读数（力度名/速度值）、默认 1.5；打点盘紧凑近透明、点盘外关闭；布局 v2：仪表柱底部与下角袋橡胶上沿齐平，右侧竖排文字动作列（击球/上一杆/回放），左侧开球钮（无开球页禁用态常驻），球库两排居中放大 | `BTAimWheel` / `BTShotInstrumentColumn` / `BTSpinPadOverlay` / `BTShotActionColumn` / `BTBreakSideButton` |
| ⑤ 大字海报卡 + 仪表玻璃 | 入口卡渐变底+单字水印；场景页恒黑底；HUD 皮肤=黑 60% 玻璃+0.5pt 发丝描边+**无阴影无光效**；形状只有胶囊/正圆/圆角矩形三种；文字三级（label 11pt 白 55% / value 15pt 等宽 / title 14pt 品牌绿）；状态语法（未选=玻璃底白 75%、选中=绿实底、禁用=文字 30%；绿管选择、金管数值） | `HUDStyle` + `View.btHudGlass(in:)` |

**信号色封闭**：品牌绿（选择/教学标注）+ 金（量值/方案）+ 白（测量/母球）+ 红（失误）四通道之外，场景页不引入新色。

### 9.2 HUD 七分区（场景页骨架）

| 区 | 位置 | 仪表盘角色 | 允许内容 | 禁止内容 | 组件 |
|---|---|---|---|---|---|
| Z1 导航栏 | 顶 | 铭牌：身份+状态唯一真源 | 绿标题；齿轮/(i)/⋯；副标题=状态一句话 | 业务控件 | principal 绿标题 |
| Z2 顶部控制区 | ≤2 行（§8.4） | 旋钮：**定义问题** | 模式 chip、约束工具、库数、求解参数 | 执行按钮、长文案、结果读数 | `BTChipRow` |
| Z3 台面区 | 中，最大化 | 世界：可视化+直接操纵 | 拖球/点选/手指跟随瞄准/直点袋口；标注仅限 §9.1-① 语言 | 遮挡球位的悬浮件 | `AngleSceneView` |
| Z3a 贴缘仪表柱 | 左右缘 | 精调旋钮 | 左：瞄准刻度轮；右：打点+力度柱 | 其他 | `BTAimWheel` / `BTShotInstrumentColumn` |
| Z4 方案 pill | 左下浮层 | 表盘：解/结果摘要（只读） | 方案 pill、失误 pill | 交互控件、与 Z1 重复状态 | `BTReadout` |
| Z5 FAB 列 | 右下 | 快捷键 ≤3 | 重置/下一解/辅助/答题 | 主执行动作 | `BTSceneFAB` |
| Z6 底部操作条 | 底 | 扳机：**执行动作** | 球库（两排居中放大）+（三杆）角色行；击球/上一杆/回放已迁至右侧 `BTShotActionColumn`、开球至左侧 `BTBreakSideButton`（布局 v2，条 18） | 模式切换、问题定义 | `ShotControlBar` v2 / `BTShotActionColumn` / `BTBreakSideButton` |
| Z7 浮出层 | sheet | 工具箱：低频设置 | 训练设置、打点盘、原理、玩法选择 | — | 一律暗材质（`preferredColorScheme(.dark)`） |

铁律：① 顶定义问题、底执行动作（判据：改它是否重新定义问题）；② 状态只出现一次（Z1 副标题 vs Z4 pill 不重复）；③ 新控件先归区再选组件。

### 9.3 逐页契约（问题集合批 v2 后现行形态，学/练/打/解四分类）

| 页 | 分类 | 核心职责 | 关键契约（已落地） |
|---|---|---|---|
| 瞄准原理 | 学 | 切角/假想球/厚度+公式 | 插图全真台化（`BTTableFigure`）；页末 CTA→角度预测 |
| 瞄准方法 | 学 | 管道/接触点/平行线三法 | v11 Y1；θ 滑杆 + 交互插图；交叉引用瞄准原理/对照表 |
| 瞄准修正 | 学 | 投掷/高低杆厚度/挤偏+弧线/求解补偿 | v12 Z3；六节结构 ①Δ实况 ②投掷 ③高低杆三联 ④加塞俯视 ⑤两档求解对比+定性速查 ⑥实战启示→思路训练；共享控件三轴（力度 `ShotTuning.velocityRange` + 高低杆三档 spinY=±0.4/0 + 左右塞，合成幅值钳 `miscueLimitFraction`）；20ms 去抖+单飞+末班车；插图一律 `BTTableFigure`+`BTFigureBall`/`BTGhostCircle`/`BTContactDot`/`BTFigureTag`/`FigureLine`（② closeup 特写、③ 单图三线选中高亮参照 SeparationPathsFigure）；速查表符号来源 `build/z1-evidence/quickref-symbols.txt` + `z2-evidence/z2-quickref-symbols.txt` + `z3-evidence/z3-quickref-symbols.txt`；AX `aimingCorrection.*`；巡游 a16 |
| 旋转与加塞 | 学 | 旋转四态→分离角 + 加塞本体 | v12 Z4（自 v11 Y2 重做）：共享切角 θ 滑杆（5°–75°，默认半球）驱动三路径球形；示意分离角为教学折线 90°/60°/120°（非半球不声称精确分离角，UI 标注「示意角 · 教学折线」）；打点→旋转示意 + 最小加塞/打滑极限（`miscueLimitFraction`）+ 左右塞×吃库反弹定性示意（T09/Jewett Run·Rev，非引擎实况）；挤偏/弧线/投掷一句话 + 真 `PracticeCTA`→`.aimingCorrection`；交叉引用瞄准原理/方法/分离角图谱/瞄准修正；插图 `BTTableFigure`+token 盘面；AX `spinAndEnglish.*`；巡游 a14 |
| 分离角图谱 | 学 | 8 档高低杆碰后轨迹对比 | v15 W1（自 v11 Y3）：SceneKit 真台+可拖多球；`ShotStageProxy` G10；**左缘 8 只读迷你打点盘**（`aimWheelFrame`，高→低与 `trackColors`/spinY 同序）；右缘纯力度柱（`onSpinTap=nil`，底部弹出 8 点盘退役）；台面**无**「纯高杆/纯低杆」文字；底栏 `BTBallPaletteBar`（点击+拖放上桌、拖回库撤下；换目标/障碍进 `simulateFree`；母球不可撤；默认母+8）；**页内 8 色轨迹豁免线语言 v2**（DR-025）；切片=碰后→第一库，**碰后未吃库降级为碰撞点→停球点**；去抖+单飞+并行 `simulateFree` |
| 角度与打点 | 学 | 拖两球实时看指标联动 | **L2 唯一持有页**；首拖提示（一次性）；90° 短虚线常驻 |
| 浅谈球感 | 学 | 方法论+四档厚度锚点 | 锚点卡真台渲染；页末 CTA→2D 瞄准训练 |
| 瞄准点对照表（原进球点对照表） | 学 | 速查工具 | 俯视真台交互图：瞄准点（红点）+接触点（绿点）+横移金标尺同见；新增估角误差交互演示（母球-目标球连线估角，远距误差变小） |
| 角度预测 | 练 | 抽象估角第 1 步 | 题面真台化；参考线含 90°；键盘不遮挡输入；交互对齐 2D 角度训练；答错「回看原理」+ 常驻「去真台练」 |
| 2D / 3D 角度训练（原瞄准训练） | 练 | 俯视练几何 / 站位练球感 | 两卡两 route 视角固定；进页先弹设置 sheet（暗材质）再开始；随机球号；plain 渲染管线；L1；辅助关闭=无任何线（答题公平） |
| 瞄准点训练（新） | 练 | 给角度问瞄准点 | **G1（v3 S3）**：瞄准点=瞄准线与过目标球心垂线交点（水平线+红小点 `BTAimPointDot`），假想球仅虚线圈无球心红点；向左/右切口径=目标球移动方向（母球打对侧）；拖动假想球调 φ；提交后正确瞄准线（红）+正确瞄准点；误差 mm（大正小负）；顶栏统计单行 compact |
| 2D / 3D 瞄准点训练（新） | 练 | 给球形求打点 | **G1（v3 S3）**：辅助线=过目标球心且垂直用户瞄准线（随瞄准旋转）；瞄准点=两线交点（垂足）；误差=用户/正确瞄准点相对目标球心有符号偏移之差 mm；提交后正确线红+正确瞄准点红小圆片；停留 3s 后按用户瞄准线物理击球；3D 为相机版 |
| 自由击球（新页） | 打 | 球库+开球+对局 | `FreePlayView`；开球状态机（开球→开球中→重开/完成）；中八/追分完整规则引擎（`BilliardRulesEngine`：轮转/判罚/胜负/计分） |
| 自由走位（原走位编排台） | 打 | 旗舰：逐杆编排推演 | 手指跟随瞄准；仪表柱；**无开球无录制**；进袋/自由单钮切换（`BTAimModeToggleButton`，切自由保留进袋瞄准点）；失误只在 Z2 红 pill；L0 |
| 分离角与走位 | 打 | 演示碰后走向 | `PositionPlayViewModel` 底座；进袋/自由切换；球库限 2 目标球；分离角弧+90° 短虚线 L1 常驻 |
| 拍照建球形 | 打 | 照片→球形供给 | 四步步骤指示（第 n 步/共 4 步）；送入菜单三目的地（自由走位/思路训练/三杆） |
| 思路训练（原思路训练器） | 解 | 单杆走位反解 | 落区只留矩形；「求解/下一解」左侧竖排；右侧仪表柱+击球/上一杆/回放；求解后可微调力度/打点即时重预测；无导出无试打；齿轮并入 ⋯ 菜单、标题居中；L1 |
| 打一走二想三 | 解 | 三杆规划 | 角色 chip Z6 底部横排（台面全宽）；余同思路训练规范 |
| 做斯诺克 | 解 | 安全球反解 | 同思路训练规范；遮挡可视化；无开球（禁用态钮常驻）；L0 |
| 翻袋解球器 | 解 | 目标球翻库进袋 | 袋口台面直点；顶部两行（库数 / 理想·真实+力度）；「下一解」FAB；解 pill「切角 X°」 |
| 反射解球器 | 解 | 母球绕库碰球 | 结构即目标形态；线语言/力度术语已收编 |
| （球形生成器） | — | **已下线** | 开球能力内置编排台/思路/三杆（`BreakFlowRunner`） |

全局项：页名=入口卡名；术语查 §8.8 词表；渲染管线与 App 同 token 同源；Z7 一律暗材质；学→练 CTA 三条（原理→预测、球感→2D、预测→真台）。埋点骨架（`practice_enter/core_action/result/handoff`）挂 B5。

### 9.3.1 文档学页壳（问题集合 v14；六张浅色文档学页）

> **范围**：瞄准原理 / 瞄准方法 / 瞄准修正 / 旋转与加塞 / 浅谈球感 / 瞄准点对照表。  
> **排除（红线）**：`AngleDynamicView`（角度与瞄准）、`SeparationAngleAtlasView`（分离角图谱）——暗色沙盘，本契约不适用、禁止借壳改动。  
> **不做**：精讲「为什么 / 怎么打 / 自检」三标签；动作库 / 蛇彩 CTA；统一成八页同滚动模板。

| 零件 | 口径 | 代码锚点 |
|---|---|---|
| 字色 / 行距 | 主阅读路径 `.btText` + 明确行距（`LearnDocText.bodyLineSpacing` = 5）；脚注 / caption `.btTextSecondary`（`.learnDocFootnoteStyle()`）；禁止整页主文长期灰字墙 | `LearnDocChrome.swift` |
| 节卡 | 标题层级（section=`btTitle` / subsection=`btHeadline`）+ 内边距 `Spacing.lg` + 圆角 `BTRadius.lg` + 背景 `.btBGSecondary` | `LearnDocSectionCard` |
| 控件条 | `LearnControlStrip.Theta`（切角 θ，默认 5…75 step 1）+ `LearnControlStrip.LiveAxes`（力度 / 高低杆 / 左右塞，Binding，不绑 ViewModel）+ 可选 `ReadoutRow`；视觉对齐现网方法页 θ / 修正页 `sharedControls` | `LearnControlStrip.swift` |
| CTA 密度 | 页末 `PracticeCTA` 大卡 **≤2**（D-v14-6）；超出改为 `LearnDocTextLink`（文字行 NavigationLink）或 chip；学→练优先保留；不新增动作库/蛇彩深链 | `PracticeCTA`（`AngleHomeView`）；`LearnDocTextLink` |
| 插图红线 | 继续 `BTTableFigure` / `FigureLine` / 球组件；禁止再私设线色台面比例 | `BTTableFigure.swift` |
| 局部试瞄 φ | 管道节试瞄角 **不得** 复用 `LearnControlStrip.Theta` 外观冒充全局 θ；须有「局部试瞄」标注 + 次级底区分 | `AimingMethodsView` 管道节 |
| 公式降级 | 推导 / 速查用 `LearnDocFormulaNest`（`.btBGTertiary` + caption 标题）收拢；节卡可用 `titleLevel: .subsection`；默认不做 Disclosure（公式块＞2 处再局部折叠）；不压「名词 / 切角」同级主阅读权重；**不删**公式内容 | `LearnDocFormulaNest`；`AimingPrincipleView` |

B1–B3 六文档学页接壳已落地（交互四页 + 原理/球感只读两页）。

### 9.4 重叠标注配档表

见 §8.7（T-P18-42 落定，含 L0/L1/L2 定义、12 行逐页档位与理由、显隐原则）。本节不重复维护；改档位改 §8.7。

---

## Changelog

> 每次任务执行后如有组件 API 变更或设计调整，在此追加记录。

| 日期 | 条目 | 类型 | 影响范围 | 来源任务 |
|------|------|------|---------|---------|
| 2026-07-25 | **Logo Mark / App Icon 摆位改「环（O）光学居中」+ 占比放大（DR-026）**：① 摆位——`brand.logo-mark{,-dark}.svg` transform `translate(-559 -443)`→`translate(-456.4 -443)`（scale 1.492 不变）、`AppIcon.png` 图形右移 34px，环心偏移 −7.8%→−2.8%（SVG）/ −5.5%→−2.2%（Icon）；② 占比——App Icon 以环心为中心矢量重渲染放大 1.25×（图形宽 58.7%→73.7%）、`BTBrandLogo.onTile` 内边距 16%→10%（图形宽 57.2%→67.8%），`.onDisc` 保持 16% | DR | BTBrandLogo（Onboarding/Login/About/ShareCard）、主 App Icon | Logo 居中 + 放大 |
| 2026-07-20 | **问题集合 v14 B3「只读两页接壳 + 六页巡游」**：原理/球感接 `LearnDocSectionCard`+`LearnDocText`；公式/速查→`LearnDocFormulaNest` 次级卡收拢（D-v14-5）；学→练 CTA 保留 + 学页互链 `LearnDocTextLink`；球感全宽出血布局保留；`testAngleLearningPages` 扩 v14-b3 取证帧；§9.3.1 补公式降级口径 | 重构 | AimingPrincipleView, BallFeelView, LearnDocChrome, ScreenshotTourUITests, §9.3.1 | 问题集合 v14 B3 |
| 2026-07-20 | **问题集合 v14 B2「交互四页接壳」**：方法/修正/旋转/对照表接 `LearnDocSectionCard`+`LearnDocText`；θ→`LearnControlStrip.Theta`、修正三轴→`LiveAxes`、对照表估距→`ReadoutRow`；管道 φ「局部试瞄」条与全局 θ 区分；CTA≤2 + 新增 `LearnDocTextLink`；§9.3.1 补 φ/轻量链口径；UI 测 `testV14B2InteractiveLearnShellShots` | 重构 | AimingMethods/Correction/SpinAndEnglish/ContactPointTable Views, LearnDocChrome, ScreenshotTourUITests, §9.3.1 | 问题集合 v14 B2 |
| 2026-07-20 | **问题集合 v15 W1「分离角图谱」图例/球库/学卡序**：去台面「纯高杆/纯低杆」；左缘 8 只读迷你打点盘（`aimWheelFrame`）；右缘纯力度柱；底栏接 `BTBallPaletteBar`（点+拖+拖回库）；学卡「角度与瞄准」↔「分离角图谱」对调；§9.3 契约同步 | 修正/重构 | SeparationAngleAtlasView/ViewModel, AngleHomeView, ScreenshotTourUITests, §9.3 | 问题集合 v15 W1 |
| 2026-07-19 | **问题集合 v14 B1「文档学页壳」组件**：新增 `LearnDocSectionCard` + `LearnDocText`/`learnDocBodyStyle`/`learnDocFootnoteStyle` + `LearnControlStrip`（Theta / LiveAxes / ReadoutRow）；§9.3.1 文档学页壳短契约（字色行距/节卡/控件条/CTA≤2/插图红线/排除两沙盘页）；六学页业务接壳留 B2/B3 | 新增 | LearnDocChrome.swift, LearnControlStrip.swift, LearnDocChromeCompileTests, §9.3.1 | 问题集合 v14 B1 |
| 2026-07-19 | **问题集合 v13 B2「瞄准方法」教学标注收口**：开篇符号图例（θ/φ/Q/Pt/Pc/G/管道·隧道）；接触点节默认碰合终帧 +「重播碰合过程」+ 误差角徽章常显；平行线主标 Q（点对称）；三节 d=2R·sinθ 等价说明收拢开篇一处；节内「当前 θ = N°」读数（非 sticky）；§8.8 假想球补球心 G；UI 测 `testAimingMethodsInteractions` 增 B2 取证帧 | 修正 | AimingMethodsView, ScreenshotTourUITests, §8.8 | 问题集合 v13 B2 |
| 2026-07-18 | **问题集合 v12 Z4「旋转与加塞」页重做**：切角 θ 滑杆联动三路径；示意角教学折线 90/60/120（非半球诚实标注）；打点→旋转 + 吃库顺/逆塞定性示意（T09/Jewett，非引擎实况）；MiscueLimitFigure token 化；teaser→真 `PracticeCTA`→`.aimingCorrection`；a14 补 scrolled5；§9.3 契约 | 重构 | SpinAndEnglishView/Geometry, SpinAndEnglishGeometryTests, ScreenshotTourUITests, SpinAndEnglishZ4UITests, §9.3 | 问题集合 v12 Z4 |
| 2026-07-18 | **问题集合 v12 Z3「瞄准修正」收口 + ②③图风格重做**：②投掷/③高低杆插图由裸 Canvas（硬编码 RGB+Text）改为学区统一 `BTTableFigure` 语言；④加塞节（挤偏+弧线俯视实况，左右塞轴开放，打滑极限圆盘钳制）；⑤两档求解对比（A 中杆中速 / B 低杆轻推+左塞）+ 定性速查表（符号引 z1/z2/z3 草稿）；⑥实战启示核对；UI 巡游 a16 明/暗；§9.3 页面契约 | 新增/重构 | AimingCorrectionView/ViewModel/Math, ScreenshotTourUITests, §9.3 | 问题集合 v12 Z3 |
| 2026-04-05 | 初始版本创建 | — | 全部 | T-R0-01 |
| 2026-04-05 | btBGTertiary/btBGQuaternary/btSeparator Light 值修正（DR-001） | DR | 全局背景/分隔线 | T-R0-02 |
| 2026-04-05 | btSurface 别名添加（= btBGSecondary） | 新增 | Colors.swift | T-R0-02 |
| 2026-04-05 | Token Swatch Preview 添加（Light + Dark） | 新增 | Colors.swift | T-R0-02 |
| 2026-04-05 | BTButton 新增 darkPill/iconCircle/segmentedPill 3 种样式 | 新增 | BTButton.swift | T-R0-03 |
| 2026-04-05 | segmentedPill API 改为 `segmentedPill(isSelected: Bool)`（DR-002） | DR | BTButton | T-R0-03 |
| 2026-04-05 | BTSegmentedTab / BTTogglePillGroup / BTOverflowMenu 新建 | 新增 | Core/Components | T-R0-04 |
| 2026-04-05 | BTExerciseRow / BTSetInputGrid 新建 | 新增 | Core/Components | T-R0-05 |
| 2026-04-05 | BTRestTimer / BTFloatingIndicator / BTShareCard 新建 | 新增 | Core/Components | T-R0-06 |
| 2026-04-05 | BTLevelBadge 五级配色全部修正 + displayName L4「专家」 | 修正 | BTLevelBadge | T-R0-07 |
| 2026-04-05 | BTDrillCard 新增 64pt 缩略图 + Dark 描边 | 修正 | BTDrillCard | T-R0-07 |
| 2026-04-05 | BTPremiumLock 重构为泛型双模式（progressive / fullMask） | 重构 | BTPremiumLock | T-R0-07 |
| 2026-04-05 | BTEmptyState 图标添加 btPrimary 圆形背景 | 修正 | BTEmptyState | T-R0-07 |
| 2026-04-05 | BTButton 补全 7 种样式；segmentedPill 添加 isSelected 关联值（DR-002） | DR | BTButton.swift | T-R0-03 |
| 2026-04-05 | BTSetInputGrid 新增 onDeleteSet 回调 + 可编辑 TextField 单元格（DR-003） | DR | BTSetInputGrid | T-P4-05 |
| 2026-04-05 | 新建 DrillRecordView（使用 BTSetInputGrid + BTExerciseRow） | 新增 | Training/Views | T-P4-05 |
| 2026-04-05 | ActiveTrainingViewModel 重构为 DrillSetData 数组（替代 ballsMadeRecords） | 重构 | ViewModels | T-P4-05 |
| 2026-04-05 | UI-IMPLEMENTATION-SPEC 文件头更新为三步设计参考流程（PD-001） | PD | 全部 UI 任务 | T-P4-06 |
| 2026-04-05 | TrainingNoteView 重写匹配设计（DR-004）：移除装饰 header/stats、极简输入 + 固定底栏 | DR | TrainingNoteView | T-P4-06 |
| 2026-04-05 | TrainingNoteView API 简化 5→3 参数；ActiveTrainingViewModel 新增 resumeTraining() | 重构 | Training 模块 | T-P4-06 |
| 2026-04-05 | TrainingSummaryView 重写匹配 code.html 设计（DR-005）：2×2 统计网格 + 成功率进度条 + Drill 分组明细 + 训练心得 + 固定底栏 | DR | TrainingSummaryView | T-P4-07 |
| 2026-04-05 | DrillSummary 新增 level + sets（SetResult 分组明细）；ActiveDrill 新增 level；ViewModel 新增 totalBallsMade | 重构 | ViewModel + Model | T-P4-07 |
| 2026-04-05 | BTShareCard 重构匹配 code.html 设计（DR-006）：logo header + drill 行卡片 + stats grid + 品牌 footer；新增 fontChoice/hideSuccessRate 参数 | DR | BTShareCard | T-P4-10 |
| 2026-04-05 | TrainingSessionSummary.DrillResult 新增 setsCount；新增 totalBallsMade 计算属性；新增 ShareCardFont 枚举 | 重构 | BTShareCard 支持类型 | T-P4-10 |
| 2026-04-05 | 新建 TrainingShareView（定制面板 + 分享入口）；ActiveTrainingView 新增 sheet 连接 | 新增 | Training/Views | T-P4-10 |
| 2026-04-05 | CustomPlanBuilderView 重写匹配 code.html 设计（DR-007）：ScrollView 卡片布局 + 自定义步进器 + 56pt 球台缩略图行 + DrillSettingsSheet | DR | CustomPlanBuilderView | T-P4-09 |
| 2026-04-05 | CustomPlanBuilderViewModel 新增 totalSetsCount/totalBallsCount/updateDrillSettings/removeDrill | 重构 | ViewModel | T-P4-09 |
| 2026-04-05 | SubscriptionView 重写匹配 P2-06 code.html 设计：#111111 深色全屏 + 金色编号功能列表 + 3 列方案卡 + 年订绿框推荐标签 + 动态价格 CTA | DR | SubscriptionView | T-P7-03 |
| 2026-04-05 | AngleTestView 新增 subscriptionManager.isPremium → limiter 同步（修复 limiter 未连接 bug） | 修正 | AngleTestView | T-P7-05 |
| 2026-04-05 | ActiveTrainingView 顶栏扩展为 4 图标 + 计划名进度区 + 底栏 5 键带文字标签（DR-008） | DR | ActiveTrainingView | T-RUI-03 |
| 2026-04-05 | BTSetInputGrid 热身「热」标记由 btAccent 改为 btWarning 橙色 | 修正 | BTSetInputGrid | T-RUI-03 |
| 2026-04-05 | ProfileView 重写：横向用户卡 + 月度概览 + 彩色圆底菜单 + 访客警告/Pro 推广卡（DR-009） | DR | ProfileView | T-RUI-04 |
| 2026-04-05 | LoginView 重写：三按钮分层（Apple 黑 > 微信绿 > 手机描边）+ App 图标 + 法律文案（DR-009） | DR | LoginView | T-RUI-04 |
| 2026-04-05 | PhoneLoginView 输入改为药丸形 Capsule + 内嵌发送验证码按钮 + 底部品牌标识（DR-009） | DR | PhoneLoginView | T-RUI-04 |
| 2026-04-05 | OnboardingView 重写：QJ Logo + 品牌绿圆底 FeatureRow + 强制浅色 `.preferredColorScheme(.light)`（DR-010） | DR | OnboardingView | T-RUI-05 |
| 2026-04-05 | BTFloatingIndicator 接入 MainTabView — AppRouter 状态桥接 + 最小化/恢复训练流 | 新增 | MainTabView, AppRouter, ActiveTrainingView, TrainingHomeView | T-P8-13 P8-E |
| 2026-04-05 | DrillDetailView 底栏按钮改用 BTButtonStyle.primary/darkPill + GoldFilledButtonStyle | 修正 | DrillDetailView | T-P8-13 P8-F |
| 2026-04-05 | TrainingHomeView 底部「开始训练」按钮改用 BTButtonStyle.primary | 修正 | TrainingHomeView | T-P8-13 P8-F |
| 2026-04-05 | DrillDetailView Pro 锁定态使用 BTPremiumLock.progressive 组件 | 修正 | DrillDetailView | T-P8-13 P8-G |
| 2026-04-05 | ProfileView Pro 推广卡标题颜色从白色改为 btAccent 金色 | 修正 | ProfileView | T-P8-13 P8-H |
| 2026-04-05 | TrainingSummaryView 训练明细区「详情」标签移除 | 修正 | TrainingSummaryView | T-P8-13 P8-D |
| 2026-04-05 | Dark Mode 全面通刷：BTDrillCard 缩略图 0.5pt Dark 描边 | 修正 | BTDrillCard | T-P8-11 |
| 2026-04-05 | BTButton darkPill Dark 改用 btBGTertiary（#2C2C2E） | 修正 | BTButton | T-P8-11 |
| 2026-04-05 | BTOverflowMenu / BTFloatingIndicator 阴影 Dark 条件化 | 修正 | BTOverflowMenu, BTFloatingIndicator | T-P8-11 |
| 2026-04-05 | TrainingHomeView「开始训练」阴影 Dark 条件化 | 修正 | TrainingHomeView | T-P8-11 |
| 2026-04-05 | TrainingSummaryView / CustomPlanBuilderView 缩略图 Dark 描边 | 修正 | TrainingSummaryView, CustomPlanBuilderView | T-P8-11 |
| 2026-04-05 | LoginView Apple 按钮 Dark HIG（白底黑字）+ 手机号 Dark 样式 | 修正 | LoginView | T-P8-11 |
| 2026-04-05 | AngleHomeView 图标容器 opacity 12%→15% Dark 适配 | 修正 | AngleHomeView | T-P8-11 |
| 2026-04-05 | DrillDetailView 金色按钮改用 btAccent Token + 底栏背景统一 btBG | 修正 | DrillDetailView | T-P8-11 |
| 2026-04-05 | StatisticsView 图表琥珀色 Dark 适配（btAccent Dark #F0AD30） | 修正 | StatisticsView | T-P8-11 |
| 2026-04-05 | ProfileView Pro 推广卡 Dark 添加 1pt btSeparator 边框 | 修正 | ProfileView | T-P8-11 |
| 2026-04-05 | TrainingShareView 阴影 Dark 条件化 | 修正 | TrainingShareView | T-P8-11 |
| 2026-04-05 | HistoryCalendarView 非当月日期 opacity 调整 0.5→0.6（接近 18%） | 修正 | HistoryCalendarView | T-P8-11 |
| 2026-04-05 | Dark Mode 通刷模式发现（PD-002）：5 条标准化规则 | PD | 全局 | T-P8-11 |
| 2026-04-06 | R1 审查修复：10 组并行修复 ~120 项偏差（33 P1 + ~87 P2），235/235 测试通过 | 修正 | 全局 30+ 文件 | R1 |
| 2026-04-06 | 新建 BTMiniTable.swift — 缩略图专用 Canvas（球径 3x、路径 2x、袋口高亮、无库边） | 新增 | Core/Components | DR-011 |
| 2026-04-06 | BTDrillGridCard 重构：BTMiniTable + 等级徽章/PRO/收藏叠加 + 底部渐变 + 名称/球种 | 重构 | BTDrillCard | DR-011 |
| 2026-04-06 | DrillListView 布局重构：训记风格左侧分类侧边栏（72pt）+ 右侧 2 列 LazyVGrid | 重构 | DrillListView | DR-011 |
| 2026-04-06 | DrillDetailView 新增：备注卡、训练维度 5 进度条、查看精讲 Pill、真人示范横滚占位 | 新增 | DrillDetailView | DR-011 |
| 2026-04-06 | BTDrillListSkeleton 更新为 2 列网格骨架 | 修正 | BTShimmer | DR-011 |
| 2026-04-06 | BTDrillThumbnail 改用 BTMiniTable 替代旧渐变+图标占位 | 修正 | BTDrillCard | DR-011 |
| 2026-05-25 | Typography 新增 btDisplaySmall (36pt rounded bold) / btChapterNumber (32pt rounded bold) / btTitleMedium (19pt semibold) | 新增 | Typography.swift | DR-013 |
| 2026-05-25 | 新建 BTGoldRule（1pt × 32pt × btAccent.opacity(0.6)）+ BTArcSeparator（金色台球母题章节分隔）| 新增 | PlanDetailView | DR-013 |
| 2026-05-25 | 新建 BTPlanWeekTimeline — 横向 N 点周进度条，四态（completed/current/upcoming/locked）+ 虚线连接 + Premium 锁支持 | 新增 | Core/Components | DR-013 |
| 2026-05-25 | 新建 BTPhaseTimeline + BTPhaseEntry — 纵向虚线 + 8pt 染色圆点（warmup 绿/focused 主色/combined 金/review 灰），替换 PlanDetailView 内 phaseRow | 新增 | Core/Components | DR-013 |
| 2026-05-25 | PlanDetailView 重写：coverHeader（系列上眉 + Display 主标 + 金线 + 首句加粗）+ statsRibbon（奥运记分牌式 36pt 数字）+ chapterHeader（32pt 周序号 + 主题）+ Round 2 装饰（hero 水印 / 弧形分隔 / 教练引语） | 重构 | PlanDetailView | DR-013 |
| 2026-05-25 | PlanListView 重写：levelSectionHeader 编辑式（L 上眉 + 中文主标 + 金线 + count chip）+ PlanCard 序号刻度缩略图（02 序号 + 第 N 期 + level 色）+ 首句加粗描述 | 重构 | PlanListView | DR-013 |
| 2026-05-25 | TrainingHomeView 计划浏览升级：planBrowseCard 56pt 序号缩略图 + 首句加粗；customPlanCard 同步样式；todayScheduleSection 编辑式上眉（第 N 周 · 第 N 天 · X / Y）+ 金线；todayDrillCard 序号化（01 02 03） | 重构 | TrainingHomeView | DR-013 |
| 2026-05-25 | 中文编辑式排版语言确立（PD-005）：极致字号差 + tabular monospaced 数字 + 1pt 金色细线 + 首句加粗 + 大序号刻度五件套 | PD | 全局 long-text 列表/详情 | DR-013 |
| 2026-05-26 | Typography 全局字体密度优化（DR-014）：btDisplay 48→44、btDisplaySmall 36→30、btLargeTitle 34→32、btChapterNumber 32→26、btTitle 22→20、btTitle2 20→18、btTitleMedium 19→17、btStatNumber 28→24；新增 btSubheadlineSemibold/btFootnote14/btMicro 文档化 | DR | 全局 Typography + 主要页面 | UI 截图反馈 |
| 2026-05-26 | TrainingHomeView 今日 Drill 卡：标题 btTitle2→btHeadline；序号 btTitleMedium→btSubheadlineSemibold；issueThumbnail 数字硬编码 26pt → btStatNumber | 修正 | TrainingHomeView | DR-014 |
| 2026-05-26 | PlanDetailView：描述 lead 句改为 btBodyMedium（原 btTitleMedium），statCell 数字 btDisplaySmall→btStatNumber | 修正 | PlanDetailView | DR-014 |
| 2026-06-04 | 新建 BTDrillTableView — 统一拟真 2D 球桌（BTAimTableView feltOnly 台呢 + BTRealisticBall + 烘焙/手画轨迹 + 袋口标记 + 目标袋光环），双模式：animationProgress=nil 静态缩略图 / !=nil 动画回放 | 新增 | Core/Components | DR-015 |
| 2026-06-04 | 删除 BTMiniTable.swift；BTBilliardTable 退化为薄封装委托 BTDrillTableView（保留 animationProgress API + TableRender 常量供 BTAngleTestTable） | 重构 | BTMiniTable/BTBilliardTable | DR-015 |
| 2026-06-04 | BTDrillCard 网格卡 + BTDrillThumbnail + PlanDetailView 迷你台改用 BTDrillTableView；去掉 BTDrillCard 的 BTDrillPreviewPlayer PNG 帧短路 | 重构 | BTDrillCard, PlanDetailView | DR-015 |
| 2026-06-04 | 动作库 2D 台改用「USDZ 真台 2D 顶视」那套（同角度页）：缩略图离线烘焙 PNG（DrillThumbnailRenderer→Resources/DrillThumbnails 72 张 + BTBakedDrillTable/DrillThumbnailStore 运行时秒加载，零 SceneKit 成本）；详情页 live 场景（DrillSceneView+DrillSceneController，AngleSceneView 顶视+摆球+烘焙轨迹+回放）；记录页改 BTBakedDrillTable | 重构 | Core/Scene, Core/Components, DrillLibrary/Training Views | DR-016 |
| 2026-06-04 | 退役 DR-015 的 SwiftUI Canvas 拟真台：删除 BTDrillTableView.swift；移除 BTBilliardTable 视图，BTBilliardTable.swift 仅留 TableRender 常量（BTAngleTestTable 仍用） | 删除 | BTDrillTableView, BTBilliardTable | DR-016 |
| 2026-06-04 | 动作库轨迹/走位改由物理引擎 ShotPredictor 真算（缩略图烘焙 + 详情页回放），不再消费手画 DrillAnimation 折线：新增 DrillShotResolver（Drill→ShotInput，优先 shotIntent 否则反推中等力度）；缩略图画 prediction.cuePath/objectPath、72/72 物理重烘焙；详情页用 TrajectoryPlayback 按真实模拟逐帧回放；物理不可行才退回手画 | 修正 | DrillShotResolver, DrillThumbnailRenderer, DrillSceneView, DrillDetailView | DR-017 |
| 2026-06-05 | 打点盘（SpinPadView）真实化：按真实皮头(11mm)/母球(57.15mm)比例画接触斑 + 打滑极限虚线圈；**用户摆放皮头中心**，真实接触点=中心偏移×曲率拉心系数 R/(R+ρ)（pooltool a,b，喂物理）；接触点钳到打滑极限 0.5R（之前到球边缘 1.0R）；读数改「占满塞百分比」。统一参数源 CuePhysics.tipDiameter/tipContactRadius/tipCurvatureRadius/miscueLimitFraction/tipContactPullFactor。配套：shotIntent 内容 miscue 体检（4 条 |spin|>0.5R 钳回 + shotInput() 守门 clampToMiscueLimit + 4 缩略图重烘焙） | DR | SpinPadView(ShotSimulationView), CuePhysics, CueStick, ShotIntent, Drills | DR-018 |
| 2026-06-12 | **暗色场景页统一设计语言**（ADR-P11-07）：①新增 `BTChipRow`（胶囊分段，选中实底/未选 white 0.12，超宽横滚，居 ReflectionModeControl.swift）替代系统 segmented——反射/翻袋库数与理想/真实、翻袋袋口行全部接入；②场景页规范=黑底 + 品牌绿 inline 标题 + **单行指标胶囊**（13pt semibold rounded 值 / 11pt white 0.6 标签 / 1×14 white 0.18 分隔 / ultraThinMaterial dark capsule）+ 右下 FAB；分离角大结果卡、角度预测统计四格均收口为指标胶囊；编排台 principal 标题改 btPrimary | 新增/DR | BTChipRow, DiamondSystemView, BankShotView, ShotSimulationView, GeometricAngleQuizView, PositionPlayComposerView | ADR-P11-07 |
| 2026-06-12 | 角度预测页（GeometricAngleQuizView）整页暗色重做：黑底、顶部指标胶囊（次数/正确率/平均/剩余）、画布下方「换题/显示参考」胶囊操作行（FAB 与表单按钮重叠，弃）、重置统计上移导航栏图标、输入/结果/限免卡 white 0.06 暗卡 | 重构 | GeometricAngleQuizView | ADR-P11-07 |
| 2026-06-12 | 角度Tab首页卡片化（对齐训练/动作库语言）：学习/工具=整行卡（48pt 彩色渐变图标块），训练/进阶=双列彩色封面卡（76pt 渐变封面+大图标+白底角标 chip）；折叠 section 改静态 section 标题 | 重构 | AngleHomeView | ADR-P11-07 |
| 2026-06-12 | **2D 球桌统一自适应取景**（ADR-P11-08）：`CameraRig.fitRotatedTable(viewSize:)` 按视口宽高比 + 实测球桌包围盒算正交 scale（双轴约束取大 + 1.2% 余量），`AngleSceneView` 新参 `autoFitsRotatedTable`；6 个 2D 球桌页（分离角/反射/翻袋/2D瞄准/角度与打点/编排台）统一启用，删除全部页内硬编码 scale——球桌任何视口完整可见、双轴居中 | 新增/重构 | CameraRig, AngleTrainingScene, AngleSceneView, 6 场景页 | ADR-P11-08 |
| 2026-06-12 | 新增 `BTSceneFAB` — 暗色场景页统一圆形浮动按钮：56pt、VStack(icon 19pt semibold + 标题 10pt semibold rounded)、primary=品牌绿渐变 / neutral=white 0.16、white 0.12 描边 + 黑 0.35 阴影；替换分离角/反射/翻袋/2D瞄准 4 页自绘 FAB | 新增 | BTSceneFAB, ShotSimulationView, DiamondSystemView, BankShotView, Scene2DAimingView | ADR-P11-08 |
| 2026-06-12 | 角度首页重写为三分段海报墙：`BTSegmentedTab`（学习/训练/工具，新参 `accessibilityIdentifierPrefix`）+ 双列 `AnglePosterCard`（渐变封面 + 76pt 大字水印 + 底部标题/副标题 + 右上 chip，与训练页 BTPlanCover 同语言）；每分段 ≤4 卡单屏放完。`BTChipRow` 新参 `scrollable:false`（紧凑内联不包 ScrollView） | 重构 | AngleHomeView, BTSegmentedTab, BTChipRow | ADR-P11-08 |
| 2026-06-12 | 编排台去 60pt 左栏：信息上移顶部单行（进袋/自由 BTChipRow(scrollable:false) + 切角/厚薄胶囊 + 母球进袋/录制 pill），球桌区占满全宽水平真居中；打点盘 sheet 右上加 ✕ 关闭钮（xmark.circle.fill 20pt white 0.45，AX「关闭打点」） | 重构 | PositionPlayComposerView | ADR-P11-08 |
| 2026-06-12 | 分离角页底部控制条对齐编排台：删右侧 FAB 列 + 击球设置 HUD，改「`BTSpinMiniIcon`(28pt) + 力度滑条(0.5–6.0) + 档名读数 + 重置圆钮(43×42 white 0.14) + 击球胶囊(92×42 btPrimary)」底部条（`Color(white:0.11)` + 顶部分隔线）；速度 5 档枚举→连续 velocity | 重构 | ShotSimulationView, ShotSimulationViewModel | ADR-P11-09 |
| 2026-06-12 | 打点盘改共享浮层卡片 `BTSpinPadCard`（「打点」标题 + ✕ + BTSpinPad 128pt + 读数 + 回中，`ultraThinMaterial` 圆角卡 + white 0.08 描边，浮在球桌底缘 spring 进出场）；**禁止放系统 sheet**——sheet 底下纯黑+压暗层使材质过深（另 environment(\.colorScheme) 不影响 presentationBackground 解析），半透明材质须浮在球桌上透出绿色；组件下沉共享 `BTSpinPadCard`/`BTSpinMiniIcon`/`CueStickShape`/`PowerDisplay`/`SpinDisplay` → BTSpinPad.swift | 重构/下沉 | BTSpinPad, ShotSimulationView, PositionPlayComposerView | ADR-P11-09 |
| 2026-06-13 | 图文精讲结构化渲染（DR-019）：`TutorialSection` +`items`/`params`/`caption` 可选字段（向后兼容）；`DrillTutorialView` 新增「彩色标签胶囊+正文」条目行（为什么=blue/怎么打=btPrimary/自检=orange/其余中性）、击球参数行（`BTSpinMiniIcon` 40pt trueScale + 打点读数胶囊 + 力度胶囊，与导出 HUD 同口径）、content 分段+inline markdown、图注 btCaption | 新增/重构 | DrillTutorialView, DrillContentService, drill_c042.json, Drills/schema.md | DR-019 |
| 2026-07-02 | 袋心 API 分离（PD-025/ADR-P10-09）：`AngleSceneCalculator.pocketPositions` 语义改为 CAD 物理孔心（瞄准/物理真源），新增 `pocketMarkerPositions`（USDZ 视觉袋心）——袋口标记盘（`AngleTrainingScene.addPocketMarkers`）与点选命中（`AngleSceneView` hitTest 兜底）改用后者；两者禁止互串 | API 变更 | AngleSceneCalculator, AngleTrainingScene, AngleSceneView | ADR-P10-09 |
| 2026-07-03 | 「角度」Tab 改名「练习」+ 首页改动作库式布局（DR-020）：`AppTab.angle` title「角度」→「练习」、icon `angle`→`scope`；`AngleHomeView` 由「分段 Tab + 海报网格」改为动作库同款「左侧图标分类侧栏（全部/学/练/打/解，76pt）+ 右侧双列分组网格（钉住分组头=图标+单字+说明）」；卡片改 `BTDrillGridCard` 同款上图下文式 `AngleGridCard`（封面区保留渐变大字水印 + chip，底部 btBGSecondary 标题/副标题、Dark 描边、Light 阴影）；侧栏项沿用 `angleHomeTab_*` AX 标识（UI 测试选择器零改动）；同日追加动作库同款搜索框（占位「搜索练习」，标题/副标题大小写不敏感过滤 + 只留命中分组 + `BTEmptyState` 空态「浏览全部练习」清空） | DR/重构 | AppRouter, AngleHomeView, UI 测试（Tab 枚举/标题断言/搜索冒烟） | DR-020 |
| 2026-07-04 | **HUD 仪表玻璃 token 落 DesignSystem**（T-P18-45，设计稿 §1.7）：新建 `HUDStyle.swift`——材质配方（glassTint 黑 60% + ultraThinMaterial 模糊、hairline 白 12% 0.5pt，**无阴影**，光效禁止）、文字三级（label 11pt semibold 白 55% / value 15pt bold rounded mono〔compact 13pt〕/ title 14pt semibold 品牌绿）、value 三通道（白=测量/金=可调·方案量值/红=失误）、chip 状态语法（未选玻璃底白 75% 字/选中实底白字/禁用文字 30%）、刻度语法（三级白 40/25/15% + 金指示）；`View.btHudGlass(in:)` 修饰器（形状语法：胶囊/正圆/圆角矩形三种） | 新增 | HUDStyle.swift（DesignSystem） | T-P18-45 |
| 2026-07-04 | 新增 `BTReadout` 读数胶囊「仪表窗」：label+value 对（regular/compact 两档、emphasis 三通道、数字 rounded+monospacedDigit），`standalone: true` 自带 hudGlass 胶囊底；ADR-P11-07 的「单行指标胶囊」式样升级为本组件 | 新增 | BTReadout.swift | T-P18-45 |
| 2026-07-04 | 8 页 HUD 读数换装 + 材质收编：角度与打点指标条、分离角夹角、翻袋/反射三态解 pill（库数金）、瞄准训练进度 pill/答题 HUD/总结卡、角度预测统计条、编排台瞄准胶囊——全部弃 `ultraThinMaterial`+shadow 改 `btHudGlass`；`BTChipRow` 未选态改玻璃底+白 75% 字；`BTSceneFAB` 去阴影（ADR-P11-08 条目中「黑 0.35 阴影」作废）；`BTAimWheel` 刻度改三级 40/25/15% + 读数金字弃金底容器；`BTSpinPadCard` 玻璃底 + 绿 title + 金读数；`ShotControlBar` 力度读数金 + subtitle 等宽；导出 `ShotHUDView` 打点/力度金量值 + 力度水位金填充 | DR/重构 | 8 场景页, BTChipRow, BTSceneFAB, BTAimWheel, BTSpinPad, ShotControlBar, SequenceVideoExporter | T-P18-45 |
| 2026-07-05 | **重叠标注三档组件化**（T-P18-42，设计稿 §1.3）：`AngleTrainingScene.ghostBallNode` 由黄色实心球重建为品牌绿虚线圈（16 段贴台呢平放，`TrajectoryStyle.contactColor`+`lineHint`，节点 API 不变 ⇒ 全部消费方自动换装）；新增 `updateContactDot(ghostCenter:targetCenter:)`/`hideContactDot()` 场景助手，分离角手动/编排台自由瞄准与袋口解/思路/三杆/斯诺克（解出后首次显示）/导出器 8 处接线补齐「圈+点成对」；新增 §8.7 配档表（L0/L1/L2 定义 + 12 行逐页档位与理由），§8.2 ghost 列指向 §8.7 | 新增/DR | AngleTrainingScene, 6 个 VM, SequenceVideoExporter, SPEC §8.2/§8.7 | T-P18-42 |
| 2026-07-05 | FL-024 修复：`ShotSimulationView` 手动模式对照虚线 `addDashedPath` 浮点相位推进死循环（主线程挂死）重写为整数周期索引算法；视觉不变 | 修正 | ShotSimulationViewModel | FL-024 |
| 2026-07-05 | **DR-021 90° 分离角释义线修正**（用户裁决）：①锚点从目标球球心改**假想球球心**（90° 法则讲母球碰后沿切线离开，`updatePerpLine(ghost:)`、`drawPottingPerpendicular` 改锚 `firstContact ?? ghost`）；②颜色白→**品牌绿**短虚线（`TrajectoryStyle.separationColor` token 单点换色）——定杆时白线与母球白轨迹共线重合不可辨，绿与假想球圈/接触点同教学标注家族 | DR | TrajectoryStyle, AngleTrainingScene, ShotSimulationViewModel, 设计稿 §1.2 | DR-021 |
| 2026-07-05 | **自由瞄准重做**（T-P18-43，设计稿 §1.5）：粗调=手指跟随——`AngleSceneView` 删手柄 44pt 命中判定，pan 起手未命中球即进入瞄准跟随分支（新 API `onAimDragged`/`onAimDragEnded`，替代 `onAimHandleDragged`，.began 起逐帧回调台面世界坐标）；瞄准线手柄圆环删除（`AngleTrainingScene.setupAimHandle/updateAimHandle/aimHandleNode` 删净，VM `handleAimHandleDrag`→`handleAimDrag`）；`BTAimWheel` 删角度数值胶囊与整十度数字，只留 1°/5°/10° 三级刻度（`HUDStyle.tickColor` 助手）+ 金指示线 | API 变更/重构 | AngleSceneView, AngleTrainingScene, BTAimWheel, PositionPlayViewModel, ShotSimulationViewModel | T-P18-43 |
| 2026-07-05 | **ShotControlBar v2 + 贴缘仪表柱**（T-P18-44，设计稿 §1.5/Z3a）：新增 `BTShotInstrumentColumn`（打点盘迷你图示置顶 + 竖直力度柱〔三级刻度同瞄准轮家族、暗绿→暗金→暗橙水位渐变 `HUDStyle.powerGradient`、金档位线、0.1 步进 detent 轻触感〕+ `BTReadout` 金读数），A 类三页+批量出片台贴桌**右**缘换装、瞄准刻度轮移**左**缘；`ShotControlBar` 删 editable 形态（签名改平铺 `velocity/subtitle/subtitleTint`），B 类三页底栏只留解读数+试打；编排台/批量出片台底部控制行删除（底部=球库+操作列） | API 变更/重构 | BTShotInstrumentColumn（新）, ShotControlBar, ShotSimulationView, PositionPlayComposerView, RackGeneratorView, BatchAuthoringView, HUDStyle | T-P18-44 |
| 2026-07-05 | **学练四页真台化共享基建**（T-P18-46，设计稿 §3.1/§5-5）：新增 `TableFigureRenderer`（真实 USDZ 空台离屏渲一次按 key 缓存；`Backdrop.imagePoint/imageLength` 正交线性映射，坐标契约：landscape 屏右=+X 屏上=−Z / portrait 屏上=+X 屏右=+Z；支持全台与特写〔center+halfHeight〕两种取景）+ `BTTableFigure`（容器，`TableFigureProjection.point/length/ballDiameter/lineMainWidth/lineHintWidth/pocketCenter` 以世界米摆球画线）+ `FigureLine`（SwiftUI 线语言 token，从 `TrajectoryStyle` 同源取色）+ `BTFigureBall`/`BTGhostCircle`/`BTContactDot`/`BTFigureTag`。教学插图**禁止**再私设台面比例/线色（`BTAimTableView` 仅保留给非俯视示意如球感 3D 透视卡）。瞄准原理/球感/进球点对照表（俯视交互图重设计）/角度预测（补 90° 参考线、标签钳入画布、确认钮禁用态 §1.7）四页换装；术语扫替（切球角→切角、幽灵球→假想球） | 新增/重构 | TableFigureRenderer（新）, BTTableFigure（新）, AimingPrincipleView, BallFeelView, ContactPointTableView, GeometricAngleQuizView | T-P18-46 |
| 2026-07-05 | **开球内置三宿主 + 球形生成器页下线**（T-P18-47，设计稿 §3.3-⑨/§5-6）：新增 `Core/Rack/BreakFlowRunner`（可嵌入开球流程：`rackUp/nextRack/breakNow/cancel`，母球拖动限开球区，`onSettled(board)` 交付宿主落座；力度固定 7.0 m/s 重杆、散局多样性由 seed 扰动承担）+ 共享 UI `BreakGamePickerSheet`（暗材质玩法选择：中八/9/6/5/4 球，AX id `break.game.<n>`）、`BreakControlBar`（取消/换一局/开球主按钮，AX id `break.strike`）、`BreakEntryTile`（球库行首 44×68 入口块，AX id `break.entry`）。宿主契约：进开球模式自存 `currentSnapshot()`、挂起本页求解/约束/角色/可视化（含 `hideAllVisualization`），拖拽路由 runner，取消恢复进场前球形。编排台/思路训练器/打一走二想三三页接入；`AngleRoute.rackGenerator` 与生成器页删除（RackLayout/BreakSimulator core 保留） | 新增/下线 | BreakFlowRunner（新）, PositionPlayComposerView, SiluTrainerView, PlanThreeView, AngleHomeView, MainTabView | T-P18-47 |
| 2026-07-05 | **2D/3D 拆两卡 + 瞄准训练入口流程**（T-P18-48，设计稿 §3.2-⑥⑦/§5-8）：`AngleRoute.sceneAiming` → `sceneAiming2D/sceneAiming3D` 两 route，`SceneAimingView(initialCameraMode:)` 参数化（视角固定常量、页内 2D⇄3D toggle 删除、标题「2D/3D 瞄准训练」），练分段入口卡×2（瞄/临）；成绩分记 `quizTypeLabel` 按 route 固定 scene2D/scene3D，`AngleQuizTypeFilter` 标签对齐卡名；入口流程：`AimingQuizViewModel.setupScene` 新增 `autoStart` 参数，进页先弹完整训练设置 sheet（**`preferredColorScheme(.dark)` 才能压暗 sheet presentation 背景，`environment(\.colorScheme)` 只影响内容层**——§1.6 暗材质浮出层的正确姿势）、「开始训练/重新开始」主钮、滑关兜底默认开题；辅助线接线：`AngleTrainingScene.updateVisualization` 拆 `showOverlapMarkers`（接触点+90° 绿短虚，L1）与 `showAngleAnnotations`（数值角弧）两独立开关，辅助档保标注隐数值 | API 变更/重构 | SceneAimingView, AimingQuizViewModel, AngleTrainingScene, AngleHomeView, MainTabView, AngleHistoryViewModel | T-P18-48 |
| 2026-07-05 | **三杆角色下移 + 失误去重 + sheet 暗材质收尾 + 统计 chip 加字**（T-P18-49，设计稿 §3.4-⑭/§4）：`PlanThreeView` 右侧竖排 `roleRail` 删除 → Z6 球库行上方横排 `roleRow`（台面恢复全宽，chip 视觉语法不变仅横排化）；编排台 `makeStatus` 不再输出「母球进袋（失误）」（Z2 红 pill 唯一真源，Z1 副标题中性）；翻袋/反射原理 sheet `preferredColorScheme(.dark)`（Z7 浮出层暗材质收尾）+ info 钮 AX label「原理」；瞄准训练进度 pill 单字前缀（题/袋/差/剩）替代 SF 图标；三解页求解三态核验为已具备（就绪/求解中/解 n·N/未找到解） | 重构/修正 | PlanThreeView, PlanThreeViewModel, PositionPlayViewModel, BankShotView, DiamondSystemView, SceneAimingView | T-P18-49 |
| 2026-07-05 | **练习体验品牌设计定稿入 SPEC §9**（T-P18-52，B3.5 收官）：新增第九章——§9.1 设计语言（教练仪表盘五签名元素+唯一真源索引+信号色四通道封闭）、§9.2 HUD 七分区骨架+铁律、§9.3 逐页契约（16 页现行形态）、§9.4 指向 §8.7；设计过程真源仍在 `docs/research/20260704-练习Tab功能契约梳理.md`，本章为实现后定稿契约 | 新增 | SPEC §9 | T-P18-52 |
| 2026-07-05 | **学→练导流 + 拍照送入三目的地 + 首拖提示**（T-P18-51，设计稿 §3.1/§3.3-⑫/§5-10）：新增 `PracticeCTA` 学页页末导流卡（AngleHomeView.swift 内，`NavigationLink(value: AngleRoute)`，品牌绿描边卡）；原理→角度预测、球感→2D 瞄准训练、角度预测结果卡「去真台练」常驻+「回看原理」仅偏差较大档；拍照建球形送入收成「送入…」菜单（编排台/思路/打一走二想三）+ 步骤指示「第 n 步 / 共 4 步 · 步骤名」；角度与打点首拖提示走底部 status banner（`@AppStorage` 一次性） | 新增 | AngleHomeView（PracticeCTA）, AimingPrincipleView, BallFeelView, GeometricAngleQuizView, BallExtractionView, AngleDynamicView | T-P18-51 |
| 2026-07-05 | **翻袋顶部重排 + 术语词表**（T-P18-50，设计稿 §3.4/§4-2）：翻袋解球器袋口 chip 行删除、袋口改台面直点选定（顶部只留库数+理想/真实两行，§8.4 达标），「下一解」FAB 对齐反射页；新增 **§8.8 术语词表**（切角/假想球/力度/厚度/横移/塞/库/分离角/线语言三名词/页名=卡名，禁用别名列明，新增用户可见字符串必须查表）；全 Tab 用户可见字符串扫替清零（含 `ShotPredictor`/`AngleDynamicViewModel` 不可行文案「切球角」→「切角」、§8.7 翻袋行笔误）；页名=卡名收口（角度预测/翻袋解球器，历史筛选标签同步） | 新增/修正 | BankShotView, ShotPredictor, AngleDynamicViewModel, SPEC §8.7/§8.8, P5/Screenshot UI 测试 | T-P18-50 |
| 2026-07-07 | **线语言 v2 + 三档标注**（问题集合条 12，A1/A2）：瞄准线白实线唯一实线，进球线与全部击后轨迹（母球+所有被带动球）改本色虚线；假想球心=红点（瞄准点唯一标记）、接触点绿点；球选中圆圈全局移除（拍照建球形除外）；新增 `BTTrajectoryDetailChip` 三档标注切换（全部/母球+目标球/仅瞄准线+假想球）接入全部击打页，自由模式未碰球瞄准线延伸至库边；§9.1-①② 同步改写 | 重构/新增 | TrajectoryStyle, BTTrajectoryDetailChip（新）, AngleTrainingScene, 全部击打场景页 | 问题集合 A1/A2 |
| 2026-07-07 | **控件瘦身 + 布局规范 v2**（条 13/18，A3/A4）：`BTAimWheel` 改纯相对微调（去绝对角度/数值）；力度柱量程 0.5–8.0、非线性 γ=1.8、两行读数、默认力度 1.5（`ShotTuning`）；`BTSpinPadOverlay` 紧凑近透明点外关闭；布局 v2：仪表柱底部与下角袋齐平、右侧 `BTShotActionColumn`（击球/上一杆/回放文字钮竖排，新增回放=上一杆轨迹重放）、左侧 `BTBreakSideButton`（无开球页禁用态常驻）、球库两排居中放大；§9.1-④/§9.2-Z6 同步改写 | 重构/新增 | BTAimWheel, BTShotInstrumentColumn, BTSpinPadOverlay（新）, BTShotActionColumn（新）, BTBreakSideButton（新）, ShotTuning | 问题集合 A3/A4 |
| 2026-07-07 | **网格 + 渲染 + 物理 + 符号**（条 16/11/6.3/14/4.4，A5–A8）：4×8 台面网格开关入各球桌页设置（`UserPreferences.showTableGrid`）；地面中心纯黑、2D/3D 瞄准页发灰白收敛到 plain 观感；`pocketNoseRestitution` 0.60→0.70（`PocketBehaviorDiagTests` 标定）；全局用户可见符号 α→θ（§8.8 词表更新） | 修正 | AngleTrainingScene, BTPhysicsConstants, UserPreferences, §8.8 | 问题集合 A5–A8 |
| 2026-07-07 | **学页三张重组 + 训练页四张改造**（条 1–7，B1–B3/C1–C4）：瞄准原理（名词系统章节/θ 标注位/d=2R·sinθ 推导）；浅谈球感（定义重写+2D→3D 视角差异图重做）；进球点对照表→**瞄准点对照表**（标注对调修正/红点/估角误差交互演示）；角度与打点加球库+目标球可选换号；角度预测键盘遮挡修复+交互对齐；2D/3D 瞄准训练→**2D/3D 角度训练**（随机球号/进球线颜色修复/plain 渲染/装饰球库/按钮重排） | 重构 | AimingPrincipleView, BallFeelView, ContactPointTableView, AngleDynamicView, GeometricAngleQuizView, SceneAimingView | 问题集合 B1–C4 |
| 2026-07-07 | **新训练页三张**（条 8–10，D1–D3）：瞄准点训练（拖假想球出题、误差 mm 计〔大正小负〕、`AngleTestResult` 扩展 mm 字段）；2D 瞄准点训练（瞄准线粗调+刻度微调、过目标球心垂直辅助线交点=打点、误差=两交点距离 mm、3s 后按用户瞄准线物理击球）；3D 瞄准点训练（相机版）；§9.3 逐页契约同步 | 新增 | AimPointTrainingView（新）, AimLine2D/3DTrainingView（新）, AngleTestResult, AngleHomeView, MainTabView | 问题集合 D1–D3 |
| 2026-07-07 | **走位与对局页五项**（条 15/17/19–23，E1–E6）：编排台→**自由走位**（去开球去录制、`BTAimModeToggleButton` 进袋/自由单钮切换）；**自由击球**新页 `FreePlayView`（开球状态机：开球→开球中→重开/完成，`BreakFlowRunner.settled` 相位）+ 中八/追分完整规则引擎（`BilliardRulesEngine`/`ChineseEightBallRules`/`ZhuifenRules`，调研文档入 `docs/research/`）；分离角与走位换 `PositionPlayViewModel` 底座+限 2 目标球；批量出片台（点换+辅助线：轴吸附/均分摆球/不进 JSON）；思路训练器→**思路训练**+三解页同规范（求解/下一解左列、右侧仪表柱可求解后微调、上一杆/回放、删导出试打、菜单合并标题居中）；§9.3 同步 | 新增/重构 | FreePlayView（新）, BilliardRulesEngine（新）, PositionPlayComposerView, ShotSimulationView, BatchAuthoringView, BatchGuideLine（新）, SiluTrainerView, PlanThreeView, SnookerTacticsView | 问题集合 E1–E6 |
| 2026-07-08 | **击打页共享布局引擎**（问题集合 v3 S1，G3–G11）：新增 `ShotTableLayout.swift`——`ShotTableLayout`（镜像 `CameraRig.fitRotatedTable`，纯函数解析球桌屏幕矩形，`ShotTableLayoutTests` 覆盖）+ `ShotStageMetrics`（控件尺寸常量：竖条 1.2×=`maxBarLength 264`〔用户修订，弃 1.5×〕、刻度轮/仪表柱**同宽 38**〔用户修订，34/42 取平均〕、动作列宽 46、开球钮 48×46）+ `ShotStageProxy`（贴边 frame：`aimWheelFrame/instrumentFrame/breakButtonFrame/actionColumnFrame/chipBandHeight/libraryWidth`）；击打页控件定位一律走 proxy，禁止逐页手调 | 新增 | ShotTableLayout（新）, ShotTableLayoutTests（新） | v3 S1 |
| 2026-07-08 | **共享控件 S1 改造**：`BTBreakSideButton` 三角形内加 `BreakRackGlyph` 三圆圈（G9）；`BTShotInstrumentColumn` 力度柱移至底部与 `BTAimWheel` 同底对齐（G5，顶部固定区 72pt=打点迷你图+读数）；`BTTextActionButton` 新参 `width`、`BTShotActionColumn` 新参 `buttonWidth`（G6/G11 窄款 46 容进右黑边）；`BTTrajectoryDetailChip` 位置规范修订：下沿贴球桌上沿、靠屏幕最右（G3 用户修订版）。`FreePlayView` 为 G 规范基准页（G10 顶栏 46/底栏 94 定高锁桌；stage AX 标识须挂 background 层，挂容器会吞子控件可及性）；P10.1 球库只读 + P10.2 `BilliardRulesEngine.legalTargetKeys` 非法目标球拦截 | API 变更/重构 | BTShotPageChrome, BTShotInstrumentColumn, BTTrajectoryDetailChip, FreePlayView, BilliardRulesEngine | v3 S1 |
| 2026-07-08 | **瞄准点概念修正 G1 + 瞄准点训练页**（v3 S3）：新增 `AimPointGeometry`（瞄准点=瞄准线与过目标球心垂线交点/垂足，`offsetDistance`/`signedOffset`）；`AimingPrincipleView`/`ContactPointTableView` 文案与配图对齐 G1；`AimPointTrainingView` P8.1–P8.6（水平线、无假想球红点、红小瞄准点、左右切修正、球占比放大、统计单行）；`AimPointSceneTrainingView` P9.1 误差改垂足有符号偏移差、辅助线垂直用户瞄准线随转；`AimPointGeometryTests`+`S3_AimPointUITests` 验收 | 修正/新增 | AimPointGeometry（新）, AimingPrincipleView, ContactPointTableView, AimPointTrainingView, AimPointSceneTrainingView, BTTableFigure/BTAimPointDot | v3 S3 |
| 2026-07-08 | **全局规范推广六击打页**（v3 S2，G3–G12 + P11.1/P12.1）：分离角与走位/自由走位/批量出片台/思路训练/打一走二想三/做斯诺克全部接入 `GeometryReader + ShotStageProxy`（顶/底栏定高锁桌 G10，chip/竖条/角落控件贴边 G3–G7，球库 8 列定宽=球桌宽 G8）；`ShotTableLayout` 新增修饰器 `btChipBandPlacement`/`btStageFrame` 与 `bottomLeadingFrame/bottomTrailingFrame`（页面禁止再自摆贴边控件）；**G12**：思路/三杆/斯诺克删底部 `ShotControlBar` 解摘要行（`ShotControlBar` 组件保留但击打页不再使用，解读数=右柱仪表）；**G9 修订**：思路/三杆开球按钮保持可用（内置开球 T-P18-47），开球胶囊图标统一 `BreakRackGlyph`；**P11.1**：打页入口顺序=分离角与走位→自由走位→自由击球→拍照建球形；**P12.1 根因**：`BatchGuideLine.startPoint/endPoint` 补 `@Published`（确认按钮 enabled 依赖 `hasCurrentPoint`，非发布属性不触发重渲）。左下多按钮页（求解/下一解/开球）用 `bottomLeadingFrame(size: 48×122)` 整叠贴边 | 重构/修正 | ShotSimulationView, PositionPlayComposerView, BatchAuthoringView, SiluTrainerView, PlanThreeView, SnookerTacticsView, ShotTableLayout, AngleHomeView, S2_ShotPagesLayoutUITests（新） | v3 S2 |
| 2026-07-17 | **问题集合 v9 W1**：新建 `ShareCardImageRenderer`（离屏分享卡单一真源，固定 `361×480` 与 Preview 对齐）；`TrainingShareView` 预览/保存共用该契约 + `Task.yield` 后再 `ImageRenderer`；保存钮 `shareSaveToPhotos` AX id | 新增/修复 | ShareCardImageRenderer, TrainingShareView, BTShareCard 导出路径 | v9 W1 |
| 2026-07-16 | **问题集合 v7 W9b（G25 菜单/C29–C33）**：`BTSolverMoreMenu` 扩 Section/`solveRange`/`pageExtras`；反解三页+自由击打三页私有 Menu 迁入；「恢复默认」文案统一；AimPointScene 补三点网格、AimPointTraining/Geometric 无可配项留档；Geometric/AimPointTraining 主 CTA→`BTTextActionButton`；NumericKeypadHUD 统一 ZStack 底浮层；Composer 开球放开（第四宿主，D12）+ 删 `BreakEntryTile`；§8.9c/f/g 回写 G18 宿主与 G24/G25 | DR/重构 | BTShotPageChrome, BreakFlowRunner, 八沙盘页菜单, Geometric/AimPoint*, Composer, SPEC §8.9 | v7 W9b |
| 2026-07-16 | **问题集合 v7 W3（G22 动效/token · DR-023）**：`BTMotion` 新登记 `springLayout`/`easeInOutFast`/`easeInOutChrome`/`easeInstant`/`easePress`（值=原字面量）+ `springPanel` 消费扫齐；`AngleCoverPalette` 收编练习首页封面色；Typography `btCoverWatermark`/`btHeroSymbol`/`btCTALabelRounded`；HUD `BTHudMetricSeparator`（高 12，D5）；`BTDailyLimitGate` 字号 token 化；§1.4 增 D6 红线「新代码禁止新增字面量字号」 | DR/重构 | BTMotion, AngleCoverPalette, Typography, HUDStyle, BTDailyLimitGate, 多页动画消费点 | v7 W3 / DR-023 |
| 2026-07-16 | **问题集合 v7 W2（G20 导航 chrome）**：暗色测验五页补 dark toolbar + `BTSolverNavStatus`（`statusText` 改可选，nil=仅标题）；7 页私有 `navStatus` + BallExtraction principal 收敛共享件；9 套 `*FramePreference` → `BTShotPageFramePreference`（`SolverFramePreference` 别名）；flash 收敛 `BTToast.present`；G10 顶/底栏高度入 `ShotStageMetrics`（`topRowHeight` + `BottomBarHeight` 三档）。§8.3 回写 G20 口径 | DR/重构 | BTShotPageChrome, BTToast, ShotTableLayout, 暗色测验五页 + 沙盘/解球页 | v7 W2 |
| 2026-07-16 | **B4 截图核验暴露两个既有渲染缺陷修复（PD-026）**：① `DrillTutorialView` 精讲 formations 分段切换正文不刷新——LazyVStack `ForEach(id: \.offset)` 按 offset 复用旧行，行级复合 id（`selection-index`）修复；② `DrillDetailView` 试打球形选择 sheet 渲染空列表——`.sheet(isPresented:)` 内容闭包以陈旧 state 求值（iOS 26），改 `.sheet(item:)` + payload 快照。c042 回归 `testTryoutC042Flow` 通过 | PD/修复 | DrillTutorialView, DrillDetailView | B4 / PD-026 |
| 2026-07-18 | **v11 Y3 返工 r1**：默认力度 1.5 纯低杆（spinY=−0.5）碰后回拖停球、无 ballCushion ⇒ 旧切片返回空、第 8 条轨迹与「纯低杆」标注缺失；`SeparationAngleAtlasGeometry.pathAfterContactToFirstCueCushion` 扩展——碰后未吃库降级「碰撞点→停球点」，有吃库行为不变；补回归单测 `testPathSlice_lowPowerDraw_noCushion_fallsBackToStopPoint`；§9.3 契约同步 | 修复 | SeparationAngleAtlasGeometry, SeparationAngleAtlasTests, §9.3 | 问题集合 v11 Y3 r1 |
| 2026-07-18 | **问题集合 v11 Y3「分离角图谱」+ DR-025**：学分段新交互页——SceneKit 真台 + 可拖母球/目标球（默认 ~30° 半球）+ spinY∈[±miscueLimit] 均匀 8 档并行 `simulateFree`，切片「首次球-球→其后母球首个 ballCushion」；仅两端标注「纯高杆/纯低杆」；右缘 `BTShotInstrumentColumn`（力度可调、打点盘只读 8 色点）；20ms 去抖+单飞+末班车；**页内 8 色板豁免线语言 v2「线色=球的身份」**（DR-025，不改 `TrajectoryStyle`）；注册 4 处 + 巡游 a15 帧 + `SeparationAngleAtlasTests` | 新增/DR | SeparationAngleAtlasView/ViewModel/Geometry, AngleHomeView, MainTabView, AngleCoverPalette, SpinAndEnglish CTA, SPEC §9.3 | 问题集合 v11 Y3 / DR-025 |
| 2026-07-17 | **问题集合 v11 Y2「旋转与加塞」学页**（v11.3 边界重定 per D-v12-1）：学区新卡「旋转与加塞」——母球旋转状态四态（滑动/前旋/后旋/自然滚动）→ 分离角联动为主轴（分段选择器高亮三条示意路径：切线 90° / 前旋 60° / 后旋 120°，半球教学球形锁定）+ 最小加塞（T09）与打滑极限图（`CuePhysics.miscueLimitFraction` 真源）+ 投掷/挤偏/弧线一句话概念与「瞄准修正」文字预告（无跳转，Z 批落地后补链）；几何真源 `SpinAndEnglishGeometry`（复用 `AimingMethodsGeometry.scene`）+ 不变量单测；§8.8 词表增补「切线」「滑动/前旋/后旋/自然滚动」「打滑极限」「挤偏/弧线/投掷」 | 新增 | SpinAndEnglishView, SpinAndEnglishGeometry, AngleHomeView, MainTabView, AngleCoverPalette, §8.8 | 问题集合 v11 Y2 |
| 2026-07-17 | **问题集合 v11 Y1「瞄准方法」学页**（含 FL-026 返工 r1）：学区新卡「瞄准方法」——管道瞄准法（双管道相切，试瞄角 φ 交互 + 三态徽章）/ 接触点瞄准法（点对点，Pt/Pc 碰合动画 + 心对点误导线）/ 平行线瞄准法（接触点连线过心平行，θ 联动；Mosconi 降为变体附注）+ 厚薄法补充节；几何真源 `AimingMethodsGeometry`（恒等式 Pc→Pt≡G−C 单测锁定）；§8.8 词表增补「接触点（Pt/Pc/Q）」「管道/试瞄角 φ」 | 新增 | AimingMethodsView, AimingMethodsGeometry, AngleHomeView, MainTabView, AngleCoverPalette, AimingPrincipleView CTA, §8.8 | 问题集合 v11 Y1 |
| 2026-07-13 | **问题集合 v5 全批次落地**（G13–G19 + Q1–Q19，V1–V11 收官）：新增 SPEC **§8.9 瞄准与求解交互规范**——四条全局契约（a 瞄准拖动=选中+相对调整〔绕母球公转增益、封顶 0.6 度/pt，`AngleSceneCalculator.aimNudgeDegrees`〕；b 求解 0.5s idle 去抖〔`SolveDebounceScheduler`〕；c 开球通用规范〔单一真源 `BreakFlowRunner`+`BreakControlBar`+`BreakInstrumentsOverlay`、随机性只留球堆间距、开放瞄准、力度默认 6 m/s、完成/重开互换〕；d 上一杆完整快照〔`SolveShotSnapshot`+`SolveConstraintDraft`+页面 `UndoContext`，翻袋/反射用原生 `SolveUndoContext`〕）+ 全局小件登记（G15 回放禁尾速截断、G16 打点盘 inset 5→2、G19 三点入口统一含 ProfileView 豁免、V8 防守评分权重 0.6/0.4 待调优）；§8.8 词表增补页面改名（角度与打点→角度与瞄准、做斯诺克→防守）。总验收：全量 `QiuJiTests` **Executed 560 tests, 2 skipped, 0 failures**；关键 UI 套件全绿（S1/S2/S5/S6/S7/S8/ScreenshotTour/DrillTryout）；`clean` 全量重建后 3 例陈旧增量构建 SIGSEGV 转绿（非代码回归） | 新增/DR | SPEC §8.9/§8.8；`问题集合_v5.md` V1–V11 落地代码（AngleSceneView/AngleSceneCalculator/PositionPlayViewModel/SolveDebounceScheduler/BreakFlowRunner/BTShotPageChrome/BTSpinPad 等） | 问题集合 v5 |
