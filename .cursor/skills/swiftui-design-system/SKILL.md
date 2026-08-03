# SwiftUI Design System Skill

## 触发场景

在以下情况读取并遵循本技能：
- 创建或修改任何 SwiftUI View 文件
- 定义 Color、Font、Spacing 常量
- 创建可复用 UI 组件

---

## 一、视觉风格定位

### 设计参照：训记

训记的核心设计哲学：**数据即主角，界面退为工具**。
- 无装饰性插图，无渐变大图背景
- 数字、进度、成功率等数据用大字重点展示
- 信息密度适中：卡片式布局，足够留白但不浪费空间
- iOS 原生质感：遵循 HIG，使用系统组件为主

### 球迹的适配调整

在训记风格基础上加入台球场景感：
- **主色调**：台球绿（深绿）代替健身类常见的橙/蓝，建立产品独特记忆
- **暗色模式优先**：球馆环境偏暗，Dark Mode 体验必须一流
- **Canvas 球台**是唯一「重视觉」的核心元素，其余界面克制

---

## 二、色彩系统

### 主色板

```swift
extension Color {
    // ── 主色：台球绿 ──────────────────────────────────
    static let btPrimary        = Color("btPrimary")
    // Light: #1A6B3C   Dark: #25A25A
    // 用于：主按钮填充、Tab选中态、进度环、重要高亮

    static let btPrimaryMuted   = Color("btPrimaryMuted")
    // Light: #1A6B3C1A (10% opacity)   Dark: #25A25A26 (15% opacity)
    // 用于：等级标签背景、选中行背景、轻触反馈

    // ── 辅色：金色 ──────────────────────────────────
    static let btAccent         = Color("btAccent")
    // Light: #D4941A   Dark: #F0AD30
    // 用于：收藏心形、成就徽章、「最划算」标签、特别强调

    // ── 语义色 ──────────────────────────────────────
    static let btSuccess        = Color("btSuccess")
    // Light: #2E7D32   Dark: #4CAF50
    // 用于：答对提示、目标达成、DoD通过

    static let btWarning        = Color("btWarning")
    // Light: #E65100   Dark: #FF7043
    // 用于：接近但未达标、注意提示

    static let btDestructive    = Color("btDestructive")
    // Light: #C62828   Dark: #EF5350
    // 用于：删除、错误、超出限制

    // ── 背景层次（4层）──────────────────────────────
    static let btBG             = Color("btBG")
    // Light: #F2F2F7   Dark: #000000
    // 用于：页面最底层背景（系统标准）

    static let btBGSecondary    = Color("btBGSecondary")
    // Light: #FFFFFF    Dark: #1C1C1E
    // 用于：卡片、列表行背景

    static let btBGTertiary     = Color("btBGTertiary")
    // Light: #E5E5EA    Dark: #2C2C2E
    // 用于：输入框背景、次级卡片

    static let btBGQuaternary   = Color("btBGQuaternary")
    // Light: #D1D1D6    Dark: #3A3A3C
    // 用于：分隔线、禁用背景

    // ── 文字层次（3层）──────────────────────────────
    static let btText           = Color("btText")
    // Light: #000000    Dark: #FFFFFF
    // 用于：主要文字、数字

    static let btTextSecondary  = Color("btTextSecondary")
    // Light: #3C3C43 (60% opacity)   Dark: #EBEBF0 (60% opacity)
    // 用于：说明文字、副标题

    static let btTextTertiary   = Color("btTextTertiary")
    // Light: #3C3C43 (30% opacity)   Dark: #EBEBF0 (30% opacity)
    // 用于：占位符、禁用状态、时间戳

    // ── 分隔线 ──────────────────────────────────────
    static let btSeparator      = Color("btSeparator")
    // Light: rgba(60,60,67,0.18)    Dark: #38383A
    // 用于：列表分隔线

    // ── 球台专属 ─────────────────────────────────────
    static let btTableFelt      = Color("btTableFelt")
    // Light: #1B6B3A    Dark: #144D2A
    // 用于：Canvas 球台台面

    static let btTableCushion   = Color("btTableCushion")
    // Light: #7B3F00    Dark: #5C2E00
    // 用于：Canvas 球台库边

    static let btTablePocket    = Color("btTablePocket")
    // #1A1A1A（固定深色，与台面形成对比）
    // 用于：Canvas 袋口

    static let btBallCue        = Color("btBallCue")
    // #F5F5F5（母球近白）
    // 用于：Canvas 母球

    static let btBallTarget     = Color("btBallTarget")
    // #F5A623（目标球橙黄）
    // 用于：Canvas 目标球

    static let btPathCue        = Color("btPathCue")
    // #FFFFFF (60% opacity)
    // 用于：Canvas 母球路径线

    static let btPathTarget     = Color("btPathTarget")
    // #F5A623 (70% opacity)
    // 用于：Canvas 目标球路径线
}
```

> **规则**：所有颜色在 `Assets.xcassets` 中定义 Light + Dark 变体，使用 `Any Appearance` + `Dark` 双槽。**禁止在代码中硬编码 hex 值**。

---

## 三、字体系统

> **设计取向**：克制 + 数据为主角。基线参考角度训练首页（34 → 17 → 13 的紧凑层级），其它页面向其靠拢。**DR-014（2026-05-26）** 全局字号下调，详见末尾「使用原则」。

```swift
extension Font {
    // ── 展示级（单屏核心数据 / 编辑式排版）─────────────
    static let btDisplay        = Font.system(size: 44, weight: .bold, design: .rounded)
    // 用于：单屏唯一核心指标数字（训练总结成功率等）

    static let btDisplaySmall   = Font.system(size: 30, weight: .bold, design: .rounded)
    // 用于：详情页 Hero 标题、卡片中等数字徽章 — DR-013/DR-014

    static let btLargeTitle     = Font.system(size: 32, weight: .bold, design: .rounded)
    // 用于：Tab 根页面大标题（训练 / 动作库 / 角度 / 记录 / 我的）

    static let btChapterNumber  = Font.system(size: 26, weight: .bold, design: .rounded)
    // 用于：章节序号（「第 N 周」「第 N 期」），编辑式排版专用 — DR-013/DR-014

    // ── 标题级 ──────────────────────────────────────
    static let btTitle          = Font.system(size: 20, weight: .bold, design: .rounded)
    // 用于：Section 大标题

    static let btTitle2         = Font.system(size: 18, weight: .semibold)
    // 用于：次级 Section 标题、SubSection

    static let btTitleMedium    = Font.system(size: 17, weight: .semibold)
    // 用于：中文编辑式次级标题（字号同 btHeadline，按语义可与之互换）— DR-014

    static let btHeadline       = Font.system(size: 17, weight: .semibold)
    // 用于：列表行标题、卡片主标题、表单标签

    // ── 正文级 ──────────────────────────────────────
    static let btBody           = Font.system(size: 17, weight: .regular)
    // 用于：主要正文内容

    static let btBodyMedium     = Font.system(size: 17, weight: .medium)
    // 用于：强调正文（不加粗但略重）

    static let btCallout        = Font.system(size: 16, weight: .regular)
    // 用于：次要正文、描述文字、按钮文字

    // ── 数据展示级 ───────────────────────────────────
    static let btStatNumber     = Font.system(size: 24, weight: .bold, design: .rounded)
    // 用于：卡片内常用大数字（统计、训练数、计划页 8/3/60）

    // ── 辅助级 ──────────────────────────────────────
    static let btSubheadline         = Font.system(size: 15, weight: .regular)
    static let btSubheadlineMedium   = Font.system(size: 15, weight: .medium)
    static let btSubheadlineSemibold = Font.system(size: 15, weight: .semibold)
    // 用于：副标题、说明、列表行序号、轻量强调

    static let btFootnote14     = Font.system(size: 14, weight: .regular)
    // 用于：介于 footnote 与 callout 之间的辅助说明

    static let btFootnote       = Font.system(size: 13, weight: .regular)
    // 用于：时间戳、次要说明

    static let btCaption        = Font.system(size: 12, weight: .regular)
    static let btCaption2       = Font.system(size: 11, weight: .medium)
    // 用于：徽章/图表轴；极小标签角标

    static let btMicro          = Font.system(size: 10, weight: .medium)
    // 用于：Timeline 小点、徽章中的角标 — 禁止用于正文信息
}
```

**使用原则**：
- 数字永远比文字字号更大（训练成绩是主角）
- 标题使用 `.rounded` 设计，正文使用默认设计
- 不使用自定义字体（纯系统字体，减小包体积，适配无障碍）
- **避免 `btTitle2` 滥用于列表卡片标题**：默认列表行用 `btHeadline`
- **避免 `btDisplaySmall` 用于卡片内统计数字**：用 `btStatNumber` 替代
- **避免 `btTitleMedium` 用作强调正文**：用 `btBodyMedium`
- **保留 `.system(size:)`** 仅限：Canvas/SceneKit 文本、数字键盘、SF Symbol 图标精确大小、live monospaced 计时器

---

## 四、间距系统

```swift
enum Spacing {
    static let xs:   CGFloat = 4   // 图标与文字间距、标签内边距
    static let sm:   CGFloat = 8   // 行内元素间距
    static let md:   CGFloat = 12  // 卡片内边距（紧凑）
    static let lg:   CGFloat = 16  // 卡片标准内边距、列表行高
    static let xl:   CGFloat = 20  // Section 间距
    static let xxl:  CGFloat = 24  // 页面水平边距
    static let xxxl: CGFloat = 32  // 大 Section 分隔、顶部留白
    static let xxxxl: CGFloat = 48 // 空状态中心留白
}
```

---

## 五、形状与圆角

```swift
enum BTRadius {
    static let xs:  CGFloat = 6   // 标签、徽章
    static let sm:  CGFloat = 8   // 按钮（次级）、输入框
    static let md:  CGFloat = 12  // 标准卡片
    static let lg:  CGFloat = 16  // 大卡片、底部弹窗
    static let xl:  CGFloat = 20  // 订阅页卡片
    static let full: CGFloat = 999 // 胶囊按钮、圆形元素
}
```

---

## 六、阴影策略

**原则：克制使用阴影，以层次色替代投影。**

```swift
// ✅ 推荐：用背景色区分层次，无阴影
VStack { ... }
    .background(Color.btBGSecondary)
    .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))

// ✅ 仅在悬浮元素（如弹窗）上使用轻阴影
.shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)

// ❌ 避免：多层叠加阴影、模糊半径 > 16
.shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
```

---

## 七、按钮规范（BTButton — 8 种样式）

```swift
enum BTButtonStyle: ButtonStyle {
    // 原有 4 种
    case primary        // btPrimary 填充 + 白字，高度 52pt，圆角 BTRadius.sm
    case secondary      // btPrimary 描边 + 品牌色文字，高度 52pt
    case text           // 无背景 + 品牌色文字
    case destructive    // btDestructive 文字
    // R0 新增 3 种
    case darkPill       // #1C1C1E 填充 + 白字，BTRadius.full 胶囊，高度 44pt
    case iconCircle     // 48pt 圆形，btPrimary 填充 + 白色 SF Symbol
    case segmentedPill(isSelected: Bool)  // 选中：btPrimary 填充+白字；未选中：白底+灰边框，高度 36pt
    // DR-043
    case goldFilled     // btAccent 填充 + 白字 bold，高度 48pt 胶囊 — 仅 Pro 解锁 CTA
}

// 使用规则：
// - Primary：同一视图最多 1 个
// - darkPill：仅底栏/叠加场景（如 DrillDetail 关闭按钮）
// - iconCircle：工具栏图标（如训练页 + 添加按钮）
// - segmentedPill：分段选项组（如设置偏好）
// - goldFilled：仅 Pro 付费解锁场景（如 DrillDetail「解锁 Pro」）
```

---

## 八、列表与卡片规范

### 列表行（训记风格）

```
┌────────────────────────────────────────┐
│  [图标/等级]  标题（btHeadline）        │
│              说明（btFootnote, 次级色） │
│                              数值 >    │
└────────────────────────────────────────┘
高度：56–64pt，分隔线距左边距 16pt
```

### 数据卡片（训记核心元素）

```
┌─────────────────────────┐
│  指标名称（btCaption）   │
│  48     （btDisplay）   │
│  次/组  （btFootnote）  │
└─────────────────────────┘
圆角：BTRadius.md，背景：btBGSecondary
内边距：Spacing.lg，无阴影
```

### Drill 卡片（BTDrillCard）

```
┌────────────────────────────────────────────┐
│  [L0] 半台直线球          [难度●●○○○]     │
│  准度训练 · 通用                  [收藏♡] │
│  默认 3组×15球                      >     │
└────────────────────────────────────────────┘
高度：72pt，圆角：BTRadius.md
付费时右侧显示锁图标，整行文字使用 btTextTertiary
```

---

## 九、等级标签（BTLevelBadge — 五级配色）

```swift
struct BTLevelBadge: View {
    let level: DrillLevel  // L0–L4
    var onDarkSurface: Bool = false  // DR-043：深绿台面覆层 → 白字 + 黑 45% 底；默认 false 不改列表白卡
}

// 五级配色（Light Mode / Dark Mode；onDarkSurface == false）：
//
// | 等级 | Light 文字色 | Light 底色      | Dark 文字色 | Dark 底色               |
// |------|------------|----------------|------------|------------------------|
// | L0   | 白色        | btPrimary 实心   | #25A25A    | rgba(37,162,90,0.15)   |
// | L1   | 蓝色        | 浅蓝底 15%      | #0A84FF    | rgba(0,122,255,0.15)   |
// | L2   | 琥珀色      | 浅琥珀底 15%    | #F0AD30    | rgba(240,173,48,0.15)  |
// | L3   | 橙色        | 浅橙底 15%      | #FF9F0A    | rgba(255,159,10,0.15)  |
// | L4   | 红色        | 浅红底 15%      | #EF5350    | rgba(239,83,80,0.15)   |
//
// displayName: L0「入门」L1「初级」L2「中级」L3「高级」L4「专家」
// onDarkSurface：与 BTDrillGridCard 特征胶囊同族（白字 + Color.black.opacity(0.45)）
```

## 九-b、筛选胶囊（BTFilterChip — DR-043）

```swift
struct BTFilterChip: View {
    let title: String
    let isSelected: Bool
    var accessibilityIdentifier: String? = nil
    let action: () -> Void
}

// 基准：训练页 filterChips（SPEC §6.3 / §7）
// 字号 btFootnote14.medium；水平 Spacing.xl；选中 btChipActiveFill*；未选 1pt btSeparator
// 调用方：TrainingHomeView、DrillListView（等级 + 球种）
```

## 九-c、封面色板与缩略图相框（CoverPalette / BTThumbnailFrame — DR-044）

```swift
// 分区色：学绿 / 练金 / 打蓝青 / 解石墨；区内仅明度阶梯；明暗同 RGB
CoverPalette.aimingPrinciple  // Pair(top:bottom:)
CoverPalette.PlanStyle.forLevel("L1")
CoverPalette.Glyph.opacity            // 0.20
Font.btCoverWatermark                 // 56pt
Font.btCoverWatermark(size: 96)       // 训练海报

view.btThumbnailFrame(
    cornerRadius: BTRadius.sm,
    topCornersOnly: false,
    showsStroke: true,
    colorScheme: colorScheme
)
```

- `typealias AngleCoverPalette = CoverPalette`（旧调用方无需改名）
- 禁止为封面色板发明 Dark 专用变体

---

## 十、导航与 Tab Bar

- **导航栏**：使用系统 `NavigationStack`，Large Title（首屏）+ 标准 Title（子页面）
- **Tab Bar**：系统 `TabView`，不自定义样式；选中色使用 `.tint(.btPrimary)`
- **返回按钮**：系统默认（`btPrimary` 色），不自定义文字

---

## 十一、球台 Canvas 实现规范

> 完整物理参数见 `.kiro/steering/table-geometry.md`。以下为 Canvas 渲染使用的归一化常量。

### 坐标系

- Canvas 宽度 = 1.0，高度 = 0.5（宽高比 2:1，对应 innerLength × innerWidth）
- 原点在**左上角**（对应台面上侧左端）
- X 从左到右（0 = 左库，1 = 右库），Y 从上到下（0 = 上库，0.5 = 下库）

### 渲染常量（`TableRenderConstants`）

```swift
enum TableRender {
    // 尺寸比例（相对 Canvas 宽度 1.0）
    static let cushionWidth:         CGFloat = 0.0197   // 库边宽度
    static let ballRadius:           CGFloat = 0.01125  // 球半径
    static let cornerPocketRadius:   CGFloat = 0.01654  // 角袋半径
    static let sidePocketRadius:     CGFloat = 0.01693  // 中袋半径
    static let railLineWidth:        CGFloat = 0.003    // 路径线宽

    // 袋口中心（归一化坐标，略超 Canvas 边界属正常）
    static let pockets: [(x: CGFloat, y: CGFloat, isSide: Bool)] = [
        (-0.0165, -0.0165, false),  // 左上角袋
        ( 1.0165, -0.0165, false),  // 右上角袋
        (-0.0165,  0.5165, false),  // 左下角袋
        ( 1.0165,  0.5165, false),  // 右下角袋
        ( 0.5,    -0.0268, true),   // 上中袋
        ( 0.5,     0.5268, true),   // 下中袋
    ]
}
```

### Canvas 绘制顺序

```swift
Canvas { ctx, size in
    let w = size.width
    let h = size.height   // = w * 0.5

    // 1. 台面底色（整个 Canvas）
    ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.btTableFelt))

    // 2. 四边库边（矩形条）
    let cw = TableRender.cushionWidth * w
    let cushions: [CGRect] = [
        CGRect(x: 0, y: 0, width: w, height: cw),            // 上库
        CGRect(x: 0, y: h - cw, width: w, height: cw),       // 下库
        CGRect(x: 0, y: 0, width: cw, height: h),            // 左库
        CGRect(x: w - cw, y: 0, width: cw, height: h),       // 右库
    ]
    for rect in cushions {
        ctx.fill(Path(rect), with: .color(.btTableCushion))
    }

    // 3. 袋口（黑色圆，以袋口中心为圆心，绘制在库边之上）
    for pocket in TableRender.pockets {
        let r = (pocket.isSide ? TableRender.sidePocketRadius : TableRender.cornerPocketRadius) * w
        let center = CGPoint(x: pocket.x * w, y: pocket.y * h * 2)  // h = w*0.5, 所以 y*h*2 = y*w
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r,
                                        width: r*2, height: r*2)),
                 with: .color(.btTablePocket))
    }

    // 4. 目标球路径（btPathTarget，虚线，动画 progress 0→1）
    // 5. 母球路径（btPathCue，虚线，动画 progress 0→1，延迟）
    // 6. 目标球（btBallTarget）、母球（btBallCue）
}
.aspectRatio(2.0, contentMode: .fit)
.clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
.onAppear { withAnimation(.easeInOut(duration: 1.4)) { animProgress = 1 } }
```

> **坐标换算提示**（Drill JSON → Canvas 像素）：
> ```swift
> // JSON 坐标 (0.0–1.0) → Canvas 像素坐标
> func toCanvas(_ pt: CGPoint, size: CGSize) -> CGPoint {
>     CGPoint(x: pt.x * size.width, y: pt.y * size.width)  // y 也乘以 width（非 height）
> }
> ```
> 因为 JSON 中 y 单位也是台面**宽度**百分比，height = width × 0.5。

---

## 十二、空状态（BTEmptyState）

```swift
// 训记风格：图标 + 主标题 + 副标题 + 可选按钮，居中对齐
struct BTEmptyState: View {
    let icon: String        // SF Symbol name
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
}

// 示例使用：
BTEmptyState(
    icon: "figure.pool.swim",
    title: "还没有训练记录",
    subtitle: "完成第一次训练后，记录将在这里显示",
    actionTitle: "开始训练",
    action: { ... }
)
```

---

## 十三、可复用组件清单（16 个）

> 详细 API 定义见 `tasks/UI-IMPLEMENTATION-SPEC.md` § 二。
> 设计参考截图见 `ui_design/tasks/E-06/screenshot-index.md`。

| 组件 | 文件路径 | 设计参考 | 状态 |
|------|---------|---------|------|
| `BTButton`（8 种样式） | `Core/Components/BTButton.swift` | `A-02/screen.png` | R0 升级；DR-043 +goldFilled |
| `BTFilterChip` | `Core/Components/BTFilterChip.swift` | — | DR-043 新增 |
| `BTEmptyState` | `Core/Components/BTEmptyState.swift` | `A-03/screen.png` | 已有，R0 校验 |
| `BTDrillCard` | `Core/Components/BTDrillCard.swift` | `P1-01/screen.png` | 已有，R0 添加缩略图 |
| `BTLevelBadge` | `Core/Components/BTLevelBadge.swift` | `A-03/screen.png` | 已有，R0 修正配色 |
| `BTBilliardTable` | `Core/Components/BTBilliardTable.swift` | `A-08/code.html` | 已有，R0 校验 |
| `BTPremiumLock` | `Core/Components/BTPremiumLock.swift` | `A-04/screen.png` | 已有，R0 双模式 |
| `BTAngleTestTable` | `Features/AngleTraining/Views/BTAngleTestTable.swift` | `P0-07/screen.png` | 已有 |
| `BTSegmentedTab` | `Core/Components/BTSegmentedTab.swift` | `A-06/code.html` | R0 新建 |
| `BTTogglePillGroup` | `Core/Components/BTTogglePillGroup.swift` | `A-06/code.html` | R0 新建 |
| `BTOverflowMenu` | `Core/Components/BTOverflowMenu.swift` | `A-06/code.html` | R0 新建 |
| `BTExerciseRow` | `Core/Components/BTExerciseRow.swift` | `A-07/code.html` | R0 新建 |
| `BTSetInputGrid` | `Core/Components/BTSetInputGrid.swift` | `A-07/code.html` | R0 新建 |
| `BTRestTimer` | `Core/Components/BTRestTimer.swift` | `A-05/screen.png` | R0 新建 |
| `BTFloatingIndicator` | `Core/Components/BTFloatingIndicator.swift` | `A-05/screen.png` | R0 新建 |
| `BTShareCard` | `Core/Components/BTShareCard.swift` | `A-08/code.html` | R0 新建 |
| `BTProgressRing` | `Core/Components/BTProgressRing.swift` | — | 已有 |
| `BTGoldRule` | `Features/Training/Views/PlanDetailView.swift` | DR-013 | 编辑式排版细金线 |
| `BTArcSeparator` | `Features/Training/Views/PlanDetailView.swift` | DR-013 | 台球母题章节分隔（金色弧 + 母球） |
| `BTPlanWeekTimeline` | `Core/Components/BTPlanWeekTimeline.swift` | DR-013 | 横向 N 点周进度条（四态 + 虚线连接 + Premium 锁） |
| `BTPhaseTimeline` | `Core/Components/BTPhaseTimeline.swift` | DR-013 | 纵向阶段时间线（虚线 + 染色圆点） |
| `BTBallPaletteBar` | `Core/Components/BTBallPaletteBar.swift` | G21 / W4 | 交互球库（拖拽幽灵 / 拖回删球回调 / pulse·place）；姊妹 `BTDecorativeBallPalette` / `BTReferenceBallPalette` |

---

## 十三·附、BTBallPaletteBar API（G21 / v7 W4）

```swift
// 两档球径（D7）：紧凑 30 / 常规 36（默认）
BTBallPaletteMetrics.compactDiameter  // 30
BTBallPaletteMetrics.regularDiameter  // 36
BTBallPaletteMetrics.ghostDiameter    // 42
BTBallPaletteMetrics.dragMinimumDistance // 10
BTBallPaletteMetrics.rowSpacing       // 3

// 交互球库（Composer / Silu / PlanThree / Snooker / ShotSim / Solver / BatchAuthoring）
BTBallPaletteBar(
    coordinateSpace: "composer",
    ballDiameter: BTBallPaletteMetrics.regularDiameter, // 默认 36
    isPlaying: vm.isPlaying,
    libraryWidth: proxy.libraryWidth,
    isOnTable: { vm.onTableKeys.contains($0) },
    allowsDrag: nil, // 默认 !isOnTable；Solver 可覆盖固定球
    sceneFrame: sceneFrame,
    unproject: { projector.unproject?($0) },
    onTap: { key in /* pulse / place */ },
    onPlace: { key, world in /* place at world or default */ },
    onDragInteraction: { /* 可选：关说明卡 */ },
    draggingKey: $draggingKey,
    dragLocation: $dragLocation,
    dragOverTable: $dragOverTable
)

// ZStack 幽灵（与球库同 coordinateSpace）
BTBallPaletteDragGhost(key: key, location: dragLocation, overTable: dragOverTable)

// Extraction 等自定义底栏：单槽 token
BTBallPaletteToken(...)

// 装饰只读（C14 SceneAiming / AimPointScene）——姊妹组件，避免交互态 dummy Binding
BTDecorativeBallPalette(
    ballDiameter: BTBallPaletteMetrics.regularDiameter,
    libraryWidth: proxy.libraryWidth,
    opacityForKey: { key in /* 目标球 1 / 其余 0.25 */ }
)

// FreePlay 参考库（不可拖，点脉冲 / 提示）
BTReferenceBallPalette(...)

// 拖回删球 hit-test
BTBallPaletteDragBack.hitPalette(localPoint:sceneFrame:paletteFrame:)
```

**豁免（留档）**：`AngleDynamicView` 保留 Button+目标描边的私有两行布局（无 drag/ghost）；Extraction / BatchExtract 保留 `paletteTwoRows` 侧栏按钮壳，token/ghost/drag 已走组件。

---

## 十四、中文编辑式排版语言（Chinese Editorial Typography）

> 来源：DR-013 / PD-005（2026-05-25）
> 适用：长文本主导的列表/详情页（训练计划、教程、Drill 详情、文章列表等）
> 触发条件：界面以中文为主、不能依赖英文 small caps tracking 但需要打破 list/form 平铺感

### 五件套铁律

1. **极致字号差**（替代英文 small caps tracking）
   - 主标题：`btDisplaySmall` (36pt rounded bold) 或 `btLargeTitle` (34pt)
   - 章节序号：`btChapterNumber` (32pt rounded bold) — 例「第 1 周」
   - 次级标题：`btTitleMedium` (19pt semibold) — 介于 `btTitle2` (20pt) 和 `btHeadline` (17pt)
   - 落差至少 17pt，否则等同于 list row

2. **数字英雄化** — 必须 `.monospacedDigit()`
   - 「奥运记分牌」式：数字大字号 + 下移一行小字单位（不是右对齐）
   ```swift
   VStack(spacing: Spacing.xs) {
       Text("\(value)").font(.btDisplaySmall).monospacedDigit()
       Text(unit).font(.btCaption).foregroundStyle(.btTextSecondary)
   }
   ```
   - 序号 monospacedDigit + `frame(width:alignment:)` 锁定宽度，避免抖动

3. **细金线分隔** — 用 `BTGoldRule` 替代 system Divider
   - 默认 1pt × 32pt × `Color.btAccent.opacity(0.6)`
   - 与基线对齐：`BTGoldRule().padding(.bottom, 6)`
   - 不要超过 40pt，否则像 Divider；不要 < 24pt，否则像装饰点

4. **首句加粗描述** — 用 `splitFirstSentence` 切分
   ```swift
   private func splitFirstSentence(_ text: String) -> (String, String) {
       let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
       let terminators: [Character] = ["。", "！", "？", ".", "!", "?"]
       if let idx = trimmed.firstIndex(where: { terminators.contains($0) }) {
           let endIdx = trimmed.index(after: idx)
           return (String(trimmed[..<endIdx]), String(trimmed[endIdx...]))
       }
       return (trimmed, "")
   }
   // 渲染
   (Text(lead).font(.btTitleMedium).foregroundStyle(.btText)
    + Text(rest).font(.btBody).foregroundStyle(.btTextSecondary))
    .lineSpacing(4)
   ```
   - 必须同时支持中英文标点

5. **Tracklist 序号化** — 替代 `Circle().fill(opacity 0.3)` 装饰点
   ```swift
   HStack(spacing: Spacing.sm) {
       Text(String(format: "%02d", index + 1))
           .font(.btFootnote).monospacedDigit()
           .foregroundStyle(.btTextTertiary)
           .frame(width: 24, alignment: .leading)
       Text(itemName).font(.btCallout)
       Spacer()
       Text("\(sets)×\(balls)").font(.btFootnote).monospacedDigit()
   }
   ```

### 编辑式 Section Header 模板

```swift
// 上眉行（系列名 · 期数）
HStack(spacing: Spacing.sm) {
    Text(seriesName).font(.btFootnote).foregroundStyle(.btTextSecondary)
    Circle().fill(Color.btAccent).frame(width: 3, height: 3)
    Text("第 \(issue) 期").font(.btFootnote).foregroundStyle(.btTextSecondary).monospacedDigit()
}

// 主标题 + 金线
HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
    Text("训练安排").font(.btTitle).foregroundStyle(.btText)
    BTGoldRule().padding(.bottom, 6)
    Spacer()
    Text("共 \(count) 周").font(.btCaption).foregroundStyle(.btTextSecondary).monospacedDigit()
}
```

### 装饰母题（Round 2 加成）

- **Hero 水印**：`BTTrainingIcon` 直径 96 + `opacity(0.08)` + `rotationEffect(-15°)`，放在 ZStack `topTrailing`
- **章节弧形分隔**：`BTArcSeparator(width: 80, height: 16)` 复用 `BTTrainingIcon` 内的 `quadCurve`
- **教练引语**：从 `DrillContent.coachingPoints[0]` 抽取，渲染为 `btCallout.italic()` + 2pt `btAccent` 左竖线

### 反例（不要这样做）

- ❌ 标题 17pt + 副标题 12pt（差 5pt 不够）
- ❌ 数字不加 `.monospacedDigit()` — 不同 frame 下宽度抖动
- ❌ 用 system Divider 当装饰线 — 默认是 0.3pt 灰，缺少品牌感
- ❌ Hero 水印用 `opacity(0.2)` — 太显眼，干扰主文案
- ❌ 章节序号 < 主标题字号 — 反客为主
- ❌ 在英文 OS 上做 `.tracking(2)` 中文 — 中文不存在字距，反而错位

---

## 十五、Preview 规范

每个 View **必须**包含 Light + Dark 两个 Preview：

```swift
#Preview("Light") {
    DrillListView()
        .modelContainer(for: DrillFavorite.self, inMemory: true)
}

#Preview("Dark") {
    DrillListView()
        .modelContainer(for: DrillFavorite.self, inMemory: true)
        .preferredColorScheme(.dark)
}
```

---

## 十六、Dark Mode 检查清单

每次完成 View 开发后：

- [ ] 所有颜色使用 Token，无硬编码 hex / `.white` / `.black`
- [ ] 图标使用 SF Symbols（自动适配 Dark Mode）
- [ ] 球台 Canvas 在 Dark Mode 下使用 `btTableFelt`（深色变体）
- [ ] 卡片背景使用 `btBGSecondary`（系统自动适配）
- [ ] 分隔线使用 `Color(.separator)`（系统色）

---

## Changelog

- 2026-08-04（v27 W2 · DR-044）— 封面色板分区收敛：
  - `CoverPalette`（`typealias AngleCoverPalette`）：学绿 / 练金 / 打蓝青 / 解石墨 + `PlanStyle`；明暗同 RGB
  - Typography：`btCoverWatermark(size:)`；`CoverPalette.Glyph.opacity` = 0.20
  - `BTThumbnailFrame`：网格卡与 64×64 行卡同款相框（描边/暗角/圆角）
- 2026-08-04（v27 W1 · DR-043）— 浅色组件收口：
  - 新增 `BTFilterChip`；训练 / 动作库等级 / 球种三处收敛
  - `BTButtonStyle.goldFilled` 收编原 `DrillDetailView` 私有金色按钮
  - `BTLevelBadge(onDarkSurface:)` 覆层变体；`BTDrillGridCard` 左上角换用
- 2026-07-16（v7 W3 / G22 · DR-023）— 动效与设计 token 收编：
  - `BTMotion`：`springLayout` / `easeInOutFast` / `easeInOutChrome` / `easeInstant` / `easePress`（值=原字面量）；`springPanel` 消费点扫齐
  - `AngleCoverPalette`：练习首页封面渐变常量组（明暗同值）→ **v27 W2 并入 `CoverPalette`**
  - Typography：`btCoverWatermark` / `btHeroSymbol` / `btCTALabelRounded`
  - HUD：`metricSeparatorHeight=12` + `BTHudMetricSeparator`；`BTDailyLimitGate` 字号 token 化
  - 红线：新代码禁止新增字面量字号（D6）
- 2026-07-16（v7 W4 / G21）— 新增 `BTBallPaletteBar` 球库组件族：
  - `BTBallPaletteBar` / `BTBallPaletteToken` / `BTBallPaletteDragGhost` / `BTDecorativeBallPalette` / `BTReferenceBallPalette` / `BTBallPaletteDragBack`
  - D7 两档球径：紧凑 30 / 常规 36（默认）；拖拽死区统一 10；ghost 描边 success 2.5 / idle 1
  - 接入：Composer / Silu / PlanThree / Snooker / Extraction / SolverStageChrome / Batch 两页 / ShotSim / FreePlay；C14 装饰库 SceneAiming + AimPointScene
- 2026-05-26（DR-014）— 全局字体密度优化：
  - `btDisplay` 48→44、`btDisplaySmall` 36→30、`btLargeTitle` 34→32、`btChapterNumber` 32→26、`btTitle` 22→20、`btTitle2` 20→18、`btTitleMedium` 19→17、`btStatNumber` 28→24
  - 新增 `btSubheadlineSemibold`（15pt semibold）、`btFootnote14`（14pt）、`btMicro`（10pt）的文档化
  - 新增「使用原则」中四条避坑指引：避免 `btTitle2` 滥用列表卡片、避免 `btDisplaySmall` 用作卡片统计数字、避免 `btTitleMedium` 作强调正文、`.system(size:)` 保留场景定义
