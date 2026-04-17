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

| Token | 字号 | 字重 | 设计 | 用途 |
|-------|------|------|------|------|
| `btDisplay` | 48pt | Bold | Rounded | 大数字 |
| `btLargeTitle` | 34pt | Bold | Rounded | Tab 根页面标题 |
| `btTitle` | 22pt | Bold | Rounded | Section/卡片标题 |
| `btTitle2` | 20pt | Semibold | Default | 次级标题 |
| `btHeadline` | 17pt | Semibold | Default | 列表行主标题 |
| `btBody` | 17pt | Regular | Default | 正文 |
| `btBodyMedium` | 17pt | Medium | Default | 正文加粗 |
| `btCallout` | 16pt | Regular | Default | 按钮文字 |
| `btSubheadline` | 15pt | Regular | Default | 辅助信息 |
| `btSubheadlineMedium` | 15pt | Medium | Default | 辅助强调 |
| `btFootnote` | 13pt | Regular | Default | 脚注 |
| `btCaption` | 12pt | Regular | Default | 标签 |
| `btCaption2` | 11pt | Medium | Default | 最小标签 |

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

## Changelog

> 每次任务执行后如有组件 API 变更或设计调整，在此追加记录。

| 日期 | 条目 | 类型 | 影响范围 | 来源任务 |
|------|------|------|---------|---------|
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
