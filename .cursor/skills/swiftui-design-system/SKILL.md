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

### 台球训练伴侣的适配调整

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
    // Light: #F2F2F7    Dark: #2C2C2E
    // 用于：输入框背景、次级卡片

    static let btBGQuaternary   = Color("btBGQuaternary")
    // Light: #E5E5EA    Dark: #3A3A3C
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
    // Light: #C6C6C8    Dark: #38383A
    // 用于：列表分隔线（使用系统色即可：Color(.separator)）

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

```swift
extension Font {
    // ── 展示级（数据主角）────────────────────────────
    static let btDisplay        = Font.system(size: 48, weight: .bold, design: .rounded)
    // 用于：成功率大数字、角度数字（单屏核心指标）

    static let btLargeTitle     = Font.system(size: 34, weight: .bold, design: .rounded)
    // 用于：页面大标题（训练总结、统计数字）

    // ── 标题级 ──────────────────────────────────────
    static let btTitle          = Font.system(size: 22, weight: .bold, design: .rounded)
    // 用于：卡片标题、Section 大标题

    static let btTitle2         = Font.system(size: 20, weight: .semibold)
    // 用于：导航栏标题（large title 模式下使用系统自动处理）

    static let btHeadline       = Font.system(size: 17, weight: .semibold)
    // 用于：列表行标题、表单标签

    // ── 正文级 ──────────────────────────────────────
    static let btBody           = Font.system(size: 17, weight: .regular)
    // 用于：主要正文内容

    static let btBodyMedium     = Font.system(size: 17, weight: .medium)
    // 用于：强调正文（不加粗但略重）

    static let btCallout        = Font.system(size: 16, weight: .regular)
    // 用于：次要正文、描述文字

    // ── 辅助级 ──────────────────────────────────────
    static let btSubheadline    = Font.system(size: 15, weight: .regular)
    // 用于：副标题、说明

    static let btSubheadlineMedium = Font.system(size: 15, weight: .medium)
    // 用于：标签文字（等级、类型）

    static let btFootnote       = Font.system(size: 13, weight: .regular)
    // 用于：时间戳、次要说明

    static let btCaption        = Font.system(size: 12, weight: .regular)
    // 用于：徽章数字、图表轴标签

    static let btCaption2       = Font.system(size: 11, weight: .medium)
    // 用于：极小标签（如「免费」「付费」角标）
}
```

**使用原则**：
- 数字永远比文字字号更大（训练成绩是主角）
- 标题使用 `.rounded` 设计，正文使用默认设计
- 不使用自定义字体（纯系统字体，减小包体积，适配无障碍）

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

## 七、按钮规范

```swift
// 主按钮：填充色，胶囊形，全宽
BTButton.primary("开始训练") { }
// 背景：btPrimary，文字：白色，高度：52pt，圆角：BTRadius.sm(10)，水平 padding: Spacing.xxl

// 次级按钮：描边，胶囊形
BTButton.secondary("查看详情") { }
// 背景：透明，描边：btPrimary 1pt，文字：btPrimary

// 文字按钮：无背景
BTButton.text("跳过") { }
// 文字：btPrimary，无背景无描边

// 危险按钮（注销/删除）
BTButton.destructive("注销账号") { }
// 文字：btDestructive
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

## 九、等级标签（BTLevelBadge）

```swift
// L0：灰色  L1：绿色  L2：蓝色  L3：紫色  L4：金色
struct BTLevelBadge: View {
    let level: DrillLevel  // L0–L4

    var body: some View {
        Text(level.rawValue)
            .font(.btCaption2)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(level.color.opacity(0.15))
            .foregroundStyle(level.color)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.xs))
    }
}

extension DrillLevel {
    var color: Color {
        switch self {
        case .L0: return .btTextSecondary
        case .L1: return .btPrimary
        case .L2: return .blue
        case .L3: return .purple
        case .L4: return .btAccent
        }
    }
}
```

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

## 十三、可复用组件清单

| 组件 | 文件路径 | 说明 |
|------|---------|------|
| `BTButton` | `Core/Components/BTButton.swift` | 三种按钮样式（主/次/文字） |
| `BTDrillCard` | `Core/Components/BTDrillCard.swift` | 动作库列表卡片 |
| `BTEmptyState` | `Core/Components/BTEmptyState.swift` | 空数据占位 |
| `BTLoadingView` | `Core/Components/BTLoadingView.swift` | 全屏加载（系统 ProgressView 包装） |
| `BTLevelBadge` | `Core/Components/BTLevelBadge.swift` | L0–L4 等级标签 |
| `BTPremiumLock` | `Core/Components/BTPremiumLock.swift` | 付费内容锁定遮罩 |
| `BTBilliardTable` | `Core/Components/BTBilliardTable.swift` | 球台 Canvas 容器 |
| `BTProgressRing` | `Core/Components/BTProgressRing.swift` | 圆形进度指示器（成功率） |
| `BTStatCard` | `Core/Components/BTStatCard.swift` | 统计数据卡片（指标名 + 大数字） |
| `BTSectionHeader` | `Core/Components/BTSectionHeader.swift` | 列表 Section 标题（左对齐大标题） |

---

## 十四、Preview 规范

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

## 十五、Dark Mode 检查清单

每次完成 View 开发后：

- [ ] 所有颜色使用 Token，无硬编码 hex / `.white` / `.black`
- [ ] 图标使用 SF Symbols（自动适配 Dark Mode）
- [ ] 球台 Canvas 在 Dark Mode 下使用 `btTableFelt`（深色变体）
- [ ] 卡片背景使用 `btBGSecondary`（系统自动适配）
- [ ] 分隔线使用 `Color(.separator)`（系统色）
