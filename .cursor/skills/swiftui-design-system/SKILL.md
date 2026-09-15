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
│  准度 · 通用                      [收藏♡] │
│  默认 3组×15球                      >     │
└────────────────────────────────────────────┘
高度：72pt，圆角：BTRadius.md
付费时右侧显示锁图标，整行文字使用 btTextTertiary
```

网格卡（`BTDrillGridCard`）台面覆层：左上等级、右上 Pro/收藏、**已练过右下 `BTPracticedBadge`（DR-077）**。课名一律 `.btText`（Pro 只靠右上角标，禁止再洗成三级灰）。禁止用灰色「已完成」元信息行表示练过。

```swift
struct BTPracticedBadge: View {}
// ✓ 已练；白字 + Dark btPrimary（#25A25A）Capsule。台面≈Light primary，浅色绿会隐进呢面。
// 语义 = 任意 TrainingSession / DrillEntry 出现过，不是「已精通」
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

## Pro角标会员状态（DR-096）

2026-09-06补充：`isPremium`是当前登录会话的有效权益，不等同设备Apple购买记录。退出/登录失效/注销后所有角标和门控均回到免费，重新登录重新校验；禁止页面单独用购买ID或模拟器持久开关绕过会话限制。

`BTProBadge(isUnlocked: Bool, prominent: Bool = false)` 是计划、动作、练习与统计的统一角标。调用方观察当前 `SubscriptionManager.isPremium` 并传入，禁止固定闭锁或用内容的 `isPremium` 代替用户权益。未解锁使用 `lock.fill`，已解锁使用 `lock.open.fill`；保持黑金胶囊及PRO文字。详情采用prominent样式并放在导航栏topBarTrailing，避免封面内部重复计算安全区。角标只表达权益，原有付费门控不变；无障碍值分别为未解锁/已解锁。

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
// 调用方：TrainingHomeView、DrillListView（仅等级一行；球种在筛选 Menu，v28 W3）
```

## 九-c、封面色板与缩略图相框（CoverPalette / BTThumbnailFrame — DR-044 / DR-045）

```swift
// 分区色：学绿 / 练金 / 打蓝青 / 解石墨；区内仅明度阶梯；明暗同 RGB
CoverPalette.aimingPrinciple  // Pair(top:bottom:)
// 计划色：独立六色编辑式色板（绿/蓝/青/黑金/棕金/红；DR-047）
CoverPalette.PlanStyle.forLevel("L1")
CoverPalette.Glyph.color(against:)    // DR-056：柔和深墨 0.52；L<0.15 金色；|ΔL|≥0.07
CoverPalette.Glyph.darkOpacity        // 0.52
CoverPalette.Glyph.gridAbsoluteSize   // 37（单行 ≈2/3）
CoverPalette.Glyph.goldOpacity        // 0.62
Font.btCoverWatermark                 // 56pt
Font.btCoverWatermark(size: 96)       // 训练列表海报
BTPlanCover(planId: ..., targetLevel: ..., issueNumber: ..., mode: .list) // 或 .hero
// v46 DR-080：卡面走 AtmosphereCatalog.image / CoverArtKey，showsColorWash=false
// Tab 矮顶带仍 AtmosphereKey.felt* + 色罩；自定义模版 hash templatePool（12）

view.btThumbnailFrame(
    cornerRadius: BTRadius.sm,
    topCornersOnly: false,
    showsStroke: true,
    colorScheme: colorScheme
)
```

- `typealias AngleCoverPalette = CoverPalette`（旧调用方无需改名）
- 分区阶梯用每区 `ZoneLadder`（练区防泥褐 B 地板；解区起点压暗）
- 训练计划颜色按 `targetLevel` 只供缺图回退；**禁止**再叠主题水印（DR-081）。列表保留「第 N 期」。`PlanCoverLabel` 不上屏。练习卡禁止两字水印 / chip，保留左上 01 + Pro
- 禁止为封面色板发明 Dark 专用变体；禁止按卡硬写 RGB 绕过阶梯

## 九-d、共享表层语法与练习混合封面（DR-045 / v28）

```swift
BTContentGridCard(title:subtitle:coverAspectRatio:) { cover }
BTLibrarySearchBar(placeholder:text:) { trailing }
BTLibrarySectionHeader(systemImage:title:caption:)
BTPracticeCover(visual: PracticeCoverCatalog.visual(for: route), chip: "2D")
```

- 学区封面 = `PracticeCoverVisual.geometric`；练/打/解 = `.tablePreview`；禁网格内启动 VM/求解器
- 真台复用 `BTTableFigure` + `TableFigureRenderer` 缓存
- 动作库网格：台面只留等级/Pro·收藏；完成与旧新版进标题下元信息（不再叠距离/袋口特征胶囊）
- **DR-051**：练习首页默认封面恢复 v27 渐变底 + 路由语义单字水印；保留 v28 共享卡片壳、搜索栏、栏目头。`BTPracticeCover` 不再作为首页默认封面。
- **DR-052**：练习首页单字水印改用 pre-v27 逐卡独立多彩渐变，通过 `CoverPalette.PracticeMulticolor` 消费历史色值；禁止退回学/练/打/解四分区同色阶或在 View 内硬编码 RGB。
- **DR-053**：练习首页水印尽量用两字语义词；每个分组从 01 独立编号；高级入口的 `BTProBadge` 必须与真实订阅门控成对出现，非 Pro 点击统一弹 `SubscriptionView`。
- **DR-054**：练习首页大字水印按 `CoverPalette.Glyph.gridAbsoluteSize * 0.06` 下移；类型标签固定在彩色封面右下角，Pro 徽标继续位于右上角。
- **DR-065（v32 / v32.2）**：练习侧栏 **学 / 理 / 练 / 打 / 解**。理区 = `TheoryCatalog` 已上线篇各一张卡直达详情（无「球理」总卡）；学区不得放定理卡。UITest：`TheoryIndexNavigation.openPage(cardTitle:)`。

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

## 训练浮层胶囊（DR-094）

- 五种展示：训练、继续、自由、播放图标+累计时间、计时器图标+倒计时。带时间时隐藏可见标题，保留完整无障碍说明（2026-09-06用户后续裁定）。
- 统一 `BTTrainingPill`：高44pt，水平内边距16pt，图标/文字/时间间距8pt；普通品牌绿、休息warning；不持续漂浮。
- 定位统一 `btTrainingPillOverlay`：右侧12pt；底部距当前安全区/可见Tab/操作栏上沿12pt。
- 固定操作栏完整布局（含padding）声明 `btTrainingPillObstacle`；页面退出清除占位。不可只给某设备额外加bottom偏移，不可把含Spacer的全屏容器登记为障碍。
- 修改后验证五状态高度、真实按钮不相交及可点击、push/pop后占位恢复、长计时和不同底部安全区。
- UIKit Tab显隐可能晚于SwiftUI布局；返回后必须检查五个Tab全部无遮挡。休息胶囊用独立标识定位，不能用“展开组间休息”前缀误选顶部按钮。

## Tab 根页线稿背景（DR-114）

`BTBlueprintBackground(style:)` 是五个 Tab 的共享静态底层。`training` 保留原训练构图，`library` / `practice` 使用边缘瞄准圈、虚线和刻度（练习另有圆弧），`history` 无虚线路径，`profile` 仅瞄准圈和圆弧。统一 `btBG` + `btPrimary`（Dark 13%、Light 8%），线宽 1pt；这是低对比度线稿，不是大面积品牌色铺底。放在根页 `.background` 或 ZStack 内容下方并忽略安全区，不放进 ScrollView 内容；不改卡片底色，不向详情页自动传播。组件内部关闭命中、无障碍朗读并裁剪越界线稿。图案使用页面 point 坐标，不表达真实球桌几何或统计数据。扩展时检查手机及 iPad、Light/Dark 原图，禁止用提高透明度掩盖被卡片遮住的正常层级。

## Changelog

- 2026-09-06（DR-114）— 五个 Tab 共用 BTBlueprintBackground，训练原样、记录及我的降低图案密度。

- 2026-09-06（DR-096）— Pro角标必传会员权益状态；闭锁/开锁统一，计划详情使用导航栏右上角prominent样式。

- 2026-09-06（DR-094）— 训练五态共用44pt胶囊与12pt边距，页面上报底栏占位自动避让。

- 2026-08-31（DR-082）— 训练首页按时间尺度拆分统计：本周卡只放周目标、连续天数与周一至周日真实轨迹；今日完成数和预计用时只在未完成时放到「今日安排」标题右侧，完成后切庆祝标志；周数字与轨迹必须共用周一起点。
- 2026-08-30（DR-081）— 计划/练习/模版封面去主题水印与 chip；编号保留（第 N 期 / 01 / 模版序号）。卡下标题保留。
- 2026-08-29（DR-080 / v46）— 官方/练习/模版封面去彩色罩：`CoverArtKey` 60 + `showsColorWash=false` + 中性暗幕 0.12。`AtmosphereKey` 仍 6 个 `felt*` 只给 Tab。`CustomPlanAtmosphere` hash `templatePool` 12。
- 2026-08-27（DR-079）— `ShareCardTheme.paper`（浅色）为默认；卡内文色走 `primaryText` 等，禁止写死 `.white`。分享页选择器标「背景」。总结页「生成分享图」同时落库，`saveTraining` 幂等。
- 2026-08-26（DR-078）— 动作库类别短名：基础 / 准度 / 杆法 / 走位 / 控力。`PlanListView` 取消 `groupedPlans` 按档分节，官方计划按 `Plans/index.json` 序单节排列。
- 2026-08-25（DR-077）— 动作库已练过用封面右下亮绿 `BTPracticedBadge`（✓ 已练，Dark `btPrimary`）；网格课名一律主色，Pro 不再洗灰。禁止灰色「已完成」元信息行。
- 2026-08-14（DR-072 / v37 W4）— 计划货架 11 份：`PlanCoverLabel` 走位Ⅰ/Ⅱ、准度Ⅱ、特殊球、全能综合；`groupedPlans` 必须覆盖全部 `targetLevel`（未知档追加，禁止只枚举 6 档导致丢卡）；新档颜色别名到现有 6 色，不扩 `planLevelKeys`。
- 2026-08-14（DR-071 续）— `BTLoadRadarChart` 上屏标题「难度画像」；台呢底 + 发光填充 + 峰值金色顶点。
- 2026-08-13（DR-071 / D-v37-6）— 新增 `BTLoadRadarChart`：详情页最下方六轴雷达；存储 0–4，展示 1–5（+1）；删假五维「训练维度」。
- 2026-08-08（DR-065 / v32）— 练习侧栏五分类：学→理→练→打→解；理区仅「球理」索引卡；学区无球理；`TheoryIndexNavigation`。
- 2026-08-05（DR-056）— 封面深墨调浅 + 单行字号缩小：
  - `darkOpacity` 0.85→0.52；暗底改 `charcoalLuminanceCeiling` 0.15；`minLuminanceDelta` 0.07
  - 练习网格水印 56→37；计划单行 2/3 字 scale 0.40/0.32（4 字双行仍 0.40）
- 2026-08-05（DR-055）— 封面大字统一深墨：
  - 训练计划与练习页均走 `CoverPalette.Glyph.color(against:)`
  - 默认深墨；金色仅用于暗底；废除半透明白与 `PlanStyle` 按档硬编码
- 2026-08-05 — 动作库网格卡去掉台面特征胶囊（距离/袋口），覆层仅留等级与 Pro/收藏。
- 2026-08-05（DR-054）— 练习卡封面视觉重心调整：
  - 大字水印按字号 6% 下移，对齐训练计划封面
  - 类型标签移至封面右下角，Pro 徽标保留右上角
- 2026-08-04（DR-053）— 计划期号去重与练习首页 Pro 分层：
  - `BTPlanCover` 列表态只显示「第 N 期」；`plan_advanced` 使用「加塞／多库」双行水印
  - `AngleGridCard` 采用两字语义水印、分组内独立编号；Pro 徽标必须同时接实际订阅门控
- 2026-08-04（DR-052）— 练习首页恢复 pre-v27 逐卡多彩色板：
  - 保留语义单字水印、chip 与 v28 `BTContentGridCard` / 搜索栏 / 栏目头
  - 四分区同色阶替换为历史逐卡独立 RGB 渐变，统一收口到 `CoverPalette.PracticeMulticolor`
- 2026-08-04（DR-051）— 练习首页恢复 v27 单字水印图标：
  - 保留 v28 `BTContentGridCard` / 搜索栏 / 栏目头，只回退封面视觉
  - 几何微插图与真台预览恢复为渐变底 + 瞄/法/偏/旋/角/走/翻等语义单字
- 2026-08-04（DR-050）— 训练计划主题水印视觉重心下移：
  - 水印向下偏移基础字号 6%，list/hero 按各自基础字号同比缩放
  - 期号、字号、断行与卡片尺寸保持不变
- 2026-08-04（DR-049）— 训练计划主题水印缩小与四字双行：
  - 2/3 字单行缩为基础字号 60%/48%，避免抢占标题层级
  - 4 字主题固定按 2×2 双行显示，字号取 40%，保留原期号与安全区
- 2026-08-04（DR-048）— 训练计划封面改课程主题标签：
  - `BTPlanCover` 新增必填 `planId`，颜色与文字职责拆分
  - `PlanCoverLabel` 映射 11 套计划为入门/杆法/准度/控力/分离角/加塞/走位Ⅰ/走位Ⅱ/准度Ⅱ/特殊球/全能综合
  - 2–4 字分档缩放并保留水平安全区，禁止铺满或复制完整标题
- 2026-08-04（DR-047）— 训练计划封面恢复 v27 W2 前六色大字杂志卡：
  - 保留 v28 `BTContentGridCard` 与 `BTPlanCover.Mode` list/hero API
  - `CoverPalette.PlanStyle` 从 teal 单色阶恢复入门绿 / 初级蓝 / 进阶青 / 中级黑金 / 高级棕金 / 专家红
  - 文生图方案仅作比较，未纳入 App 资源
- 2026-08-04（DR-046）— 训练首页当日内容卡：
  - 白色摘要卡严格两行：首行栏目+计划+完成数，次行主题+周/天/时长；进度用不占行高的 2pt 底边线
  - 动作行复用 `BTBakedDrillTable(.fill)`，90×50 专用裁口只裁烘焙 PNG 透明留边，须完整保留六袋四库；首页小行卡不加底部暗角、不另启运行时场景
  - 删除图上序号；阶段色仅作小色点，阶段文字与组球数保持中性
- 2026-08-04（v28 · DR-045）— 三 Tab 表层语法与专业内容封面：
  - 新增 `BTContentGridCard` / `BTLibrarySearchBar` / `BTLibrarySectionHeader`
  - 新增 `PracticeCoverVisual` + `BTPracticeCover`（学几何 / 练打解真台）
  - `CoverPalette.PlanStyle` 独立计划色阶；`BTPlanCover.Mode` list/hero
  - 动作库球种进 Menu；完成/旧新版迁元信息行
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


## 引导特例（DR-120，2026-09-08）
用户批准 A2 深色品牌引导：仅 OnboardingView 固定深色，使用 btIntroBackground / btIntroForeground / btIntroRule 色板及 btIntroTitle 内置 OFL Noto Serif SC 子集 QiuJiIntroSerif-Bold（Dynamic Type）。这不是通用页面新默认；五页图解与原生文字/按钮分离。

## DR-140 — 开球仪表透视选项（2026-09-12）

`BreakInstrumentsOverlay(runner:proxy:isPerspective:)` 的 `isPerspective` 默认 false，原2D宿主保持不变；自由击球standard入口3D时显式传true。透视仪表使用 `ShotPerspectiveLayout(sceneSize:)` 的视口坐标，不得拿2D球桌矩形定位；切视角自动关闭开球打点盘。`ShotPlayCamera` 切换只操作相机，开球方向读取runner.aimDir，忙碌与停稳不能重置瞄准视角或隐式确认交付。3D台面手势不绑定onAimNudged，瞄准交由刻度轮。

Changelog：2026-09-12，DR-140新增上述可选接口及两模式隔离契约。


## DR-142 — 观察菜单（2026-09-12）
`ShotObservationMenu(vm:identifierPrefix:)`是击球页共用观察入口，调用ShotPlayCamera的observeBall/observePocket/observeWholeTable；不可替换成业务选球或选袋。菜单标签44pt最小命中区，底部现有提示行中排列；开球使用原上沿相机区域。独立focus按钮保留原标识与直接返回瞄准行为。无有效球/袋时禁用对应项。标准/紧凑截图检查文字不换行、不挤压主要击球按钮。

Changelog：2026-09-12，DR-142新增ShotObservationMenu及其目标选择隔离契约。


## DR-143 — 台面辅助层（2026-09-12）
AngleTrainingScene.addLine/addDashedLine的placement默认spatial；仅table使用裁剪台面带状网格。可选layer默认route，TableAssistLayer依次为fill(5)、reference(10)、route(20)、aiming(30)。投影材料读取实体深度但不写深度，避免共面辅助线彼此遮挡碎裂；不可全局关闭深度测试。持久训练线替换几何时须同步材质深度策略与节点层级，保留虚线纹理/颜色。投影是显示副本，不改变物理坐标；假想球/球面点/杆轴保持空间含义。

Changelog：2026-09-12，DR-143新增台面辅助层与持久材质更新契约。

## DR-156 — 球房风格卡片（2026-09-12）
SettingsView的球房风格使用实际渲染预览图，不用概念图冒充；RoomStyle为④极简赛事/②温润木质/⑥当代东方，默认赛事，本地持久化；②沿用walnut持久值。整行Button声明contentShape，VoiceOver值为已选择/未选择。当前仅Debug消费，正式开放须同时启用实际渲染路径。切换只替换外围，不重建训练场景或重置球位/相机。

Changelog：2026-09-12，DR-156新增球房风格卡片与选择隔离约定。


## DR-194 — 球贴纸选择（2026-09-13）
设置页独立导航 BallStickerSettingsView，六款为 modern/minimal/american/badge/broadcast/vintage，默认modern，ballStickerStyle.v1本地持久化。使用实际Blender球网格预览；整卡contentShape，辅助功能声明名称与已选择/未选择。球号颜色关系与母球红点保持。AngleTrainingScene初始化选择当前款，AngleSceneView仅在风格变化时更新编号球底色，不重建场景、不重置姿态/球位/相机、不替换光照shader。测试Bundle内UV帧用于无光照贴图校验；实际页面另行验收。

Changelog：2026-09-13，DR-194，新增六款球贴纸与实时场景隔离契约。

### DR-200 — 球贴纸照片参照返工（2026-09-13）
球贴纸图稿采用文生图，生产只烘焙albedo；每个编号球两枚相同号码、中心方向相反。源背面UV不可盲用，SceneKit新UV图像V轴须显式换向并审图。只更新UV和编号球抛光外观，原位置/法线/面及母球保持。预览明确区分文生图目标、Blender渲染和App实际画面；功能通过不代表照片级验收。

## DR-209 — 外观组合选择（2026-09-13）
设置外观入口顺序为球房（Debug）/球桌/台呢/贴纸/球杆/颗星开关；三类场景选择页使用AppearanceCombinationPreview独立场景，共读当前四项偏好，只改被选择项。预览静止不持续渲染，不允许固定标准款PNG冒充当前搭配。入口整行命中，窄屏/大字号可回退两行，640pt内容上限。验证跨页继承、修改单项、重启与颗星开关，预览辅助功能值来自已安装材质。
Changelog：2026-09-13 / DR-209 / 外观分组与组合预览契约。

FL-064补充：独立物品预览加入外围环境时，必须校验正交图像平面四角均在房间内；仅相机中心在室内不足以排除近墙遮挡。保留取景比例，实际截图确认六袋与桌框可见。Changelog：2026-09-13 / FL-064。

DR-209取景补充：球房页showsRoomOverview=true，展示带壁灯、杆架及座椅的X侧墙；球桌/台呢用完整桌体取景。必须显式指定世界up与相机localFront以消除继承滚转。六项组按用户最终裁定下移至常规设置后、数据管理前。Changelog：2026-09-13 / 用户视角及顺序纠正。


### DR-240 — 3D打点浅横排（2026-09-13）
BTSpinPadCard与BTSpinPadOverlay新增usesCompactLayout=false；3D宿主启用后球盘与完整方向十字并排、读数及回中在下方，以缩短遮挡高度。2D默认布局保持。三消费者为开球仪表、自由击球与分离角。验收必须实看展开时母球，而不只验证按钮可点；标准/紧凑/iPad及相机姿态边界分别记录。此条为DR-240增量更新。

### DR-242 / FL-067 — 自由击球参考球库的母球例外
非每日清台自由击球的目标球球库保持只读；母球离场后，点击母球须能补回以执行自由球规则，摆位沿用VM现有防重叠与台面约束。3D隐藏球库时明确提示切2D补球。VM方法存在不代表页面可达，须实页点击验证。每日清台独立失败/继续规则不受此例外改变。
Changelog：2026-09-13 / DR-242 / 母球补回页面入口；FL-067证据边界。

### DR-243 — 自由击球顶栏警告优先（2026-09-13）
普通自由击球母球进袋警告占用瞄准数值胶囊位置，不叠加第四项挤压模式按钮与规则信息。警告解除后恢复瞄准信息。模式按钮和警告保持单行，必须在SE真实落袋/补回两状态审查；不以UI点击通过替代文本可读性。
Changelog：2026-09-13 / DR-243 / 落袋顶栏信息优先级。

### DR-246 / FL-068 — 详情静止球形不等待预测
DrillSceneController先从保存board摆球并建立homePositions，再异步计算预告。初始显示不调用会同步求解的DrillStaticPreview.apply；结果返回只在idle重绘，不能清正在播放的装饰或球杆朝向。测试除播放按钮/HUD还需在无异步挂起条件下验证球节点已显示，实页原图另验。
Changelog：2026-09-13 / DR-246 / FL-068 / 首屏与立即播放球形准备。

### DR-247 — 动作详情观察入口
DrillSceneController.setCameraMode/observeWholeTable只改变相机，stepLabel随播放杆变化；DrillSceneView独立44pt工具行提供2D/3D与全桌，不占台面手势。3D的透明回放控制面allowsHitTesting=false，场景onTableTapped唤出控制；观察不选球/袋。DrillStaticPreview.Options.adjustsTopDownCamera默认true，3D详情传false防迟到预览强切正交。真实拖动/捏合、杆末暂停往返和旧2D都需验收，不能用按钮值证明相机真正切换。
Changelog：2026-09-13 / DR-247 / 详情3D观看，实页验收中。

DR-247取景补充：CameraRig.observeWholeTable(yaw:nil)保留现有朝向；显式yaw在beginManualOrbit之后、拟合之前设置，避免首次接管覆盖。详情横幅用+π/2从长库观看并snapToTarget，以实际camera.convertVector验证屏幕右为+X；仅赋值targetYaw再调用旧入口曾被覆盖，必须看实际相机及原图。

### DR-248 — 试打页3D消费
Composer的试打变体提供2D/3D入口，复用ShotPlayCamera与观察菜单；3D台面不绑定onAimNudged/onTableTapped瞄准、不提供draggableBallNodes，摆球仍回2D。ShotPerspectiveLayout定位仪表/动作/轮和重摆；底部观察行替代球库；只读序列打点保持isReadOnly，不能因紧凑布局恢复写入。模式切换、杆末暂停/重播与切自由恢复tryoutBoard分别验证。
Changelog：2026-09-13 / DR-248 / 试打3D接入，验收中。

DR-248只读布局补充：BTSpinPadCard在usesCompactLayout且isReadOnly时使用内容本征宽度，可编辑紧凑双列与2D固定宽度保持原契约。实页须检查spinPad.card边界不覆盖动作列，截图在展开过渡后取证。Changelog：2026-09-13 / DR-248 / 只读紧凑卡宽度修复，验收中。

### DR-249 — 全桌拟合意图与实际布局
CameraRig全桌观察须跟随AngleSceneView实际viewport变化，不能把切换回调中旧2D视口当最终3D尺寸。只有全桌观察意图自动重拟合；手动手势、指定球袋观察和预设瞄准退出该意图。PerspectiveState保存恢复该意图。验证须包含底栏高度变化后的实页投影，以及手动姿态不被resize抢回。Changelog：2026-09-13 / DR-249 / 全桌视口更新，验收中。

### DR-250 — 3D序列只读参数行
试打3D序列把打点图、力度名/速度数值放入顶部模式行，使用当前杆vm参数；暂停才可展开只读打点。移除3D序列侧边不可编辑的长力度尺，以免遮挡袋口；普通击球和2D序列仪表不变。实际控件边界应处于场景上方，跨尺寸原图与暂停重播流程须复验。Changelog：2026-09-13 / DR-250 / 参数行避让，验收中。

### DR-251 — 重打的球形与视角恢复
非录制replayCurrent将本杆lastPlaybackContext里的击球前PerspectiveState与球形一起恢复。AngleTrainingScene.capturePerspectiveView在3D取当前状态，在2D取已保存3D状态；restorePerspectiveView在3D立即落实，在2D保留至下一次切换。无已有3D状态时，仅当前3D使用本杆记录aimDirection重新瞄准。验收不能只看击球按钮恢复，须检查母球及杆头回到可用视角。录制多级撤回的历史视角另验。Changelog：2026-09-13 / DR-251 / 非录制重打取景，验收中。

### DR-252 — 3D教学导出杆号（2026-09-13）
SequenceVideoExporter.Options.showSequenceProgress默认false，teachingVideo3D/Hi为true；仅showShotHUD开启时追加按宽度缩放的44px@720杆号行，放在台面外且不缩小原打点/力度条。观察帧显示杆号与观察球形，执行/收尾保留杆号，无可行解明确说明。outputSize必须包含新行，原2D/GIF/card尺寸不变。

### DR-254 — 3D瞄准点提交点击区（2026-09-13）
AimPointSceneTrainingView浮动提交使用BTTextActionButton(height:44)，保留默认56pt宽；该页不沿用共享按钮默认30pt高度。换题验收须等待提交先消失再重新出现，且查看新题球形原图；仅按钮出现不能证明自动换题与母球可见性。

### DR-255 — BTSceneObservationMenu（2026-09-13）
- API：`scene: AngleTrainingScene`、`targetNode: SCNNode?`、`pocketIndex: Int`、`identifierPrefix: String`、`onReturnToAim: () -> Void`。仅相机观察；固定题目的训练页复用，不改变选球/袋口与作答。
- 内容：全桌/母球/目标球/目标袋/回到瞄准，隐藏球或无效袋索引禁用对应项。页面按作答阶段禁用整个菜单。
- 既有页内状态栏右端承载44pt菜单标签，不新增行高；工具栏原生适配36pt、frame与HStack包装均无效，已撤回。实际尺寸、下缘点击、题内禁用和原图均须验证，不能由frame源码或下缘点击成功推定尺寸通过。r4标准机两页三题及原图通过，其他尺寸待验。
- Changelog：2026-09-13 / DR-255 / 训练观察菜单API。

### DR-256 — Composer与试打共用3D入口（2026-09-13）
- PositionPlayComposerView两变体均显示cameraToggle；cameraIdentifierPrefix=sourceDrill非nil时tryout，否则composer，用于cameraMode/观察/focus。旧试打标识保持兼容。
- 3D观察采用既有ShotPlayCamera与透视布局；球库/摆球仍2D，切换不创建新VM或序列。页面当前无录制按钮/目标区编辑入口，不把模型API误认为已暴露产品功能。
- Changelog：2026-09-13 / DR-256 / 自由走位正式启用共用3D观看，紧凑机实页往返与实际录制草稿模型不变量已验，其他范围待验。

### DR-257 — 球库拖回终点（2026-09-13）
AngleSceneView.onDragEndedAt提供手指松开时的SCNView本地pt坐标，供BTBallPaletteDragBack转换至页面命名坐标后命中。台面精细摆放的指球间距只用于onDragMoved，不能用于外部球库接收判定，否则52pt死区及抓取偏移会侵蚀有效区域。验收必须包含实际移除反馈与具体球号原图，按钮/导航成功不能证明球已移回。Changelog：2026-09-13 / DR-257 / 统一外部放下坐标，复验中。

### DR-258 — 空桌角度结果（2026-09-13）
PositionPlayViewModel.clearTable清空cutAngleDeg，结果胶囊显示—°；清空轨迹节点不能替代清空学员可见读数。实际清空→3D/2D→重来流程须核对空桌无旧角度。Changelog：2026-09-13 / DR-258 / 空桌角度清理，验收中。

### DR-259 — 思路页规划与观察（2026-09-13）
SiluTrainerView.silu.cameraMode切换复用Scene相机保存恢复，首次3D取全桌。3D禁用顶部绘制工具、移除SolveConstraintDrawingOverlay命中和球体拖动，但不能清空activeTool/约束以实现手势隔离；透视侧栏走ShotPerspectiveLayout。2D回切恢复编辑与球库。Changelog：2026-09-13 / DR-259 / 首页面候选，完整W13待验。

### DR-261 — 规划页观察菜单可用性（2026-09-13）
BTSceneObservationMenu增加canReturnToAim: Bool = true，false时禁用回到瞄准。规划页必须取当前有效解已生成的杆向，不能以母球至目标球直线替代。Silu底栏接入，播放时禁用菜单，无完整解时仍可观察全桌/可见球/有效目标袋。
Changelog：2026-09-13 / DR-261 / 观察菜单API增量v2。

### DR-263 — 无目标袋的观察菜单（2026-09-13）
BTSceneObservationMenu.pocketIndex为Int?；nil表示本页没有目标袋功能，省略该项，负数仍表示有该能力但未选择而禁用。SnookerTacticsView只选中八防守目标球，不引入目标袋或落区编辑；3D观察以当前完整解杆向返回瞄准。
Changelog：2026-09-13 / DR-263 / 观察菜单API增量v3。

- DR-262补充（2026-09-13）：W13三页3D打点面板复用FreePlay现有usesCompactLayout，宽度取stage扣两侧Spacing.lg，底距Spacing.sm；2D使用原布局。PlanThree非开球3D底栏按现有角色行48pt+观察行topRowHeight分配，恢复台面空间。Silu的3D点球/点袋入口与另两页统一禁用，2D回切保留编辑状态。构建已通过，紧凑机实页复验中；状态文案与完整W13尚未验收。

- 2026-09-13 / DR-264：规划页开球为临时场景。取消保留VM角色/目标/约束/当前解/工具并恢复球位和视角；完成才载入新球形。保留工具时须以!isBreakMode关闭绘制覆盖层。两页状态测试通过，实页验证随W13记录。

### DR-265 — 线条文字朝向（2026-09-13，行为增量v1）
AngleTrainingScene显示的inline线标签在3D使用与角度数字相同的全轴billboard，锚点保持在线段旁；2D恢复创建时平面yaw。不得将固定俯视的正反向规则直接用于任意观察相机。新建/重建标签与模式切换均应用朝向，清理重建前的标签引用。

### DR-266 — 每日清台终态（2026-09-13，行为增量v1）
FreePlayView每日清台完成/失败状态禁止继续击球与编辑，隐藏击球工具，保留观察和显式再开局入口。重新进入只有完成汇总的记录时，清除初始化示例球形；不能把示例当作用户完成后的球形。

### DR-267 — 开球交付与观察权（2026-09-13，行为增量v1）
监听可选breakRunner.seed时，nil表示交付/销毁，不是新球架，不触发focus。每日自动开球初始使用全桌观察；手动开球使用现有瞄准构图。交付后保留已有观察角度。

### DR-269 — 每日清台开球操作（2026-09-13，API增量v1）
BreakControlBar.showsCancel默认true。每日清台确认重开已放弃旧局，传false避免恢复旧桌面但控制器仍待开球；普通自由击球及规划页保持默认。页面返回仍保存草稿，下次进入恢复待开球。

- DR-269 API增量v2：onRerack可选回调默认nil，nil仍调用runner.reRack。每日清台必须经dailyController.confirmRerack同步草稿seed与球架seed，避免交付被旧seed守卫拒绝。

- DR-269修正：controller重开回调必须真正替换runner；startBreakFlow在runner非nil时拒绝启动。每日host先cancelBreakFlow再start，不能仅验证重启后的新seed，需要不重启实际交付与再次恢复。

### DR-270 — SceneKit视图销毁（2026-09-13，生命周期增量v1）
AngleSceneView.dismantleUIView须停止displayLink与isPlaying，并解除pointOfView/scene引用；仅view/controller离开作用域不保证渲染场景释放。用实际场景三次创建播放/销毁的weak引用检查验证；场景释放不等于GPU缓存峰值验收。

### DR-271 — 每日清台大字号结算（2026-09-13，布局增量v1）
辅助功能字号时结算摘要与按钮纵排，底栏通过ScaledMetric为动态按钮预留高度；标准字号保持原横排。按钮AX可点不代表文字完整，必须查看最大字号原图，不能靠限制字号掩盖截断。

### DR-272 — 瞄准尺VoiceOver（2026-09-13，交互增量v1）
BTAimWheel增减使用页面当前degreesPerPoint，回调生命周期true→nudge→false，disabled时不执行。使用处原allowsHitTesting可编辑边界须同步disabled，避免无障碍绕过触摸禁用；训练题按phase隐藏保持。构建不等于真机VoiceOver验收。

### DR-273 — 比分胶囊按可用宽度布局
FreePlayView.gamePill宽时横排比分与当前玩家，窄时用ViewThatFits纵排两行，保持完整规则文本和字号。以固定顶栏中实页截图验证不截断、不越界，不能仅验证AX标签完整；dailyStatusPill不共用本布局。
Changelog：2026-09-13 / DR-273 / 比分胶囊自适应候选。

### DR-309 — 共享 2D/3D 拖球（2026-09-15）
按用户裁定，所有可摆球页面通过 AngleSceneView 的同一套拖动入口支持 3D：起手命中可移动球则拖球，空白处拖动仍控制相机，双指缩放保持。页面只负责可编辑球集合和落点规则，不再以 is3D 清空集合。此条覆盖 DR-259/262 等历史“3D 禁止拖球”的约定；3D 绘制工具仍挂起，回切 2D 保留工具及约束。
自由击球/每日清台仅移动母球，开球仅移动开球区母球；回放、结算与试打序列只读，固定题目不开放改摆。隐藏球库不接收拖回删除。共享抓取选择最近可见球，遮挡球不可穿透抓取，拖球期间暂停相机更新，取消/失败/销毁须结束拖动且不执行外部投放。
Changelog：2026-09-15 / DR-309 / 共用拖球交互，验证记录见 tasks/ui-reviews/UR-20260915-shared-3d-drag.md。

DR-309 追加（用户触摸容错要求）：球心周围48pt为共享抓取容错区；点选/拖过的可移动球保持优先，近邻区域起手继续拖该球，直接命中另一颗球优先切换，点/拖空白处解除优先；单次抓取后直到松手均不切换对象。遮挡/隐藏/只读不因容错放开。
