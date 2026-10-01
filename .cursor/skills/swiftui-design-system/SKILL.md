# SwiftUI Design System Skill

### 每日清台进袋回切恢复（2026-10-01）

每日第一人称击球在本杆目标球的 pocket 事件实际播放时才回切第三人称；自由瞄准按第一颗非母球进袋，无目标进袋则整杆结束回切。不得在触球时根据预测进球标志提前站起。延后相机引用击球前母球位置和杆向，回调受本杆代际保护，取消/重开停止旧动作。全局/第三人称、手势接管、历史回放及重打快照沿用既有契约。本条仅恢复回切时机，不恢复 DR-342 已撤回的整体相机策略。验证见 tasks/DAILY-POCKET-CAMERA-20261001.md。

### DR-315 — 每日清台外部控件的渲染活动（2026-09-22）

位于SCNView之外的瞄准轮不能仅依赖场景变更唤醒，否则显式静止的requestedFPS仍限制到30。每日清台通过拖动生命周期参与contentIsAnimating，结束/取消/离页/后台清除；其它页面暂不扩展。AngleTrainingScene.renderingProfile在setup前设置，球材质重建、房间资源重绑必须保持该实例配置；普通默认A，Debug -dailyClearance.rendering只用于本页候选。模拟器帧间隔改善不等于手机热验收通过。Changelog：DR-315，2026-09-22。

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


### DR-310 — 每日清台等画质预览复用
AngleTrainingScene.setFreeAimPreviewLine(nil)/setIdealObjectLine(nil)移除可见节点但可保留私有缓存；非nil仅在几何输入改变时重建裁剪mesh，节点/材质复用。setupTable必须使几何key失效，hideAllVisualization同时清两层。普通SwiftUI同状态发布不能无条件延长渲染窗口；实际手势、动作、播放和相机过渡照常唤醒，不改既有活动FPS。
Changelog：2026-09-21 / DR-310 / 预览节点及刷新工作量契约。

### DR-311 — 接触球影参数提交契约
MobileContactOcclusion 默认将四球矩阵合并为具名 Metal struct，以不可变 NSData 一次绑定。保持 SIMD 字节排列、同帧 presentation 更新、零变化不提交。不得用在途可变缓冲覆写或降低采样替代。旧分组模式仅为诊断参考；调用次数降幅不等于整页 CPU/GPU 降幅。六姿态跨 iOS17/26 像素等价、动态帧及计数回归见 DAILY-CLEARANCE-RENDER-FOLLOWUP-20260921.md。
Changelog：2026-09-21 / DR-311 / 等画质合并提交。


### DR-312 — 静止显示回调与失效唤醒
AngleSceneView在显式静止、无动作/过渡/阻尼时暂停CADisplayLink；手势/内容/视口和SceneKit重绘失效唤醒，FrameDelegate跨线程合并通知。不能只暂停而遗漏直接SCNAction、布局变化或销毁清理；nil活动状态旧调用方仍连续更新。静止HUD在状态切换更新，不靠轮询。活动FPS/着色/物理不变；回调归零不等于GPU或温升已改善。
Changelog：2026-09-21 / DR-312 / 事件驱动休眠与唤醒契约。


### DR-313 — 平衡采样候选契约
MobileReferenceLighting.SamplingProfile保留reference，提供reducedShadows/reducedReflections/balanced。阴影近区8×4→4×4、反射64→32同时改分布和归一化分母；默认/Release原版，Debug以-balancedRendering预览。不得因采样减半声称GPU减半，也不得把Fair→Serious漂移样本用于收益验收；新分项测试严格Nominal预飞和段间冷却，严重热状态停止。
Changelog：2026-09-21 / DR-313 / 允许画质取舍后的显式候选。

### DR-314 — 专用渲染候选与资源生命周期
Debug以-specializedRendering A/R/S/RS选择原版/预积分反射/解析条带球影/组合，普通启动与Release仍A直到真机验收。R必须完整退出64样本循环，预过滤按probe一次生成，LUT/pipeline按device共享；房间切换重绑对应资源，台呢颜色走uniform，失败恢复原shader。S分离未遮挡照度、材质高光与球影，同帧读取presentation参数，保留原接触AO。-renderProfileProbe仅用于UI验证实际材质/调度，性能段不启用；原生分辨率/MSAA4/活动60fps保持。数值/截图/模拟器不能替代真机GPU与持续温升证据。
Changelog：2026-09-21 / DR-314 / 候选接口v1与B7默认发布门槛。


### DR-316 — 每日清台设置入口（2026-09-23）

仅每日清台将瞄准模式（进袋/自由）、轨迹显示（全部/双球/瞄准线）收进右上角菜单第一层的击球设置。HUD在玩法后显示只读模式；不改变普通自由击球及其他击打页。沿用toggleAimMode保留杆向，轨迹沿用共享偏好并触发recompute；播放/开球/结算禁用。菜单标题避免重复“轨迹”导致窄屏换行。Changelog：DR-316，页面入口契约v1。

### DR-317 — 每日清台横屏2D（2026-09-23）

覆盖DR-316的2D布局：每日清台进入时通过scene-local方向控制切横屏，退出/3D回竖屏；普通页面维持原方向。顶部44pt操作行，16球直径最高24pt、间隔2pt、整组居中贴上库边；左24pt瞄准轮，右32pt力度区，中央球桌按现有横屏相机适配。2D隐藏计时/玩法/杆数HUD，轨迹/模式留菜单；开球/重打/回放/击球恢复顶部常驻。力度拖动停稳180ms求解，松手消费最新代次且只击打一杆，拖出/离页/后台/新意图取消。共享力度组件回调为opt-in，3D不接松手击球。


### DR-318 — 每日2D紧凑布局（2026-09-23）
仅调整布局，用户明确未授权改变配色。短瞄准尺与短力度区，两侧44pt触摸宽、28pt视觉宽；球库最高20pt/2pt间隔贴库边，开球顶部，重打/回放左下、击球右下，松手击球是文本提示。台呢与桌框继续跟随原用户偏好，背景保持黑色；已撤回本轮误加的场景颜色覆盖。BTAimWheel.visibleWidth、BTShotInstrumentColumn.usesCompactAppearance均为opt-in；默认消费者不改，力度原渐变、读数与指示色保持。Changelog：DR-318，紧凑布局与窄视觉宽触摸契约。


### DR-319 — 每日2D球库尺寸与操作分组（2026-09-23）
参考图仅用于布局：球库球径最高32pt，16球单行、面间4pt、纵向命中44pt；窄屏按实际可用宽度收缩，胶囊底板下缘距离上库边2pt。重打/回放等操作加轻薄圆角底板；每日紧凑力度尺显示4pt白色手柄，原渐变及读数色保留。用户明确本轮不新增拖动、不改每日清台球形和成绩逻辑；点选仍只定位桌上球。3D及其他消费者保持原样。Changelog：DR-319，布局增量。


### DR-320 — 参考图整体布局与适度球径（2026-09-23）
覆盖DR-319的大球径和中间两行顶栏试稿：每日2D恢复44pt单行顶栏，球径最高24pt、球面间4pt，球库中心与球桌中心一致并贴库。标准宽度左页名/右2D·3D切换；窄屏先省页名并收紧切换，不增加顶栏行数。左右52pt操作区；左侧微调、开球/重打/回放，右侧击球点、完整力度面板、52pt主击球按钮。BTShotInstrumentColumn仅usesCompactAppearance启用圆形打点底板、击球点标签与力度面板；其他调用保留旧外观。每日清台球形、计分、选球逻辑不变，不新增球库拖动；3D不改。


### DR-321 — 每日2D尺子样式统一（2026-09-23）
BTAimWheel新增usesCompactAppearance=false；每日启用后直接使用HUDStyle.panelBackground，不再将黑色glassTint叠在页面底板上压暗。紧凑力度尺移除宽外壳，读数在尺子上方，保留原纵向几何；两尺同为28pt可见宽、12pt圆角、同底色与hairline描边、共享长短刻度色及线宽。力度标签与微调/击球点统一btMicro/btTextSecondary。其他消费者默认不变；球桌/顶栏/球库/每日逻辑与3D不变。


### DR-322 — 两尺同外壳与开球结束选择（2026-09-23）
按用户追加要求覆盖DR-321去外壳方案：每日2D两尺均为40pt外壳/28pt内尺，同面板底色与描边。自动开球成功交付或手动开球停稳后，居中仅显示“重新开球 / 完成”两个按钮，无标题和说明：重新开球沿用dailyController.confirmRerack，完成沿用runner.confirmSettled（自动已交付时只关闭提示）。保持自动异常重试、每日计分和3D原操作；手动停稳后从3D回2D时补显示选择，移除底部重复完成入口。界面弹窗从大型pageBody拆出，避免Swift类型检查超时。


### DR-323 — 每日清台3D横屏共用布局（2026-09-23）
按用户新授权，覆盖DR-317至322的“3D不改”限制，仅每日清台3D接入同一横屏壳。2D/3D往返不旋转，退出回竖屏；顶部球库/视图切换、左右仪表及开球双选项共用，3D球库固定在顶栏不随相机投影偏移。3D旋转/缩放/母球拖动走原AngleSceneView，菜单保留观察全桌/球/袋与回到瞄准。2D仅按原规则取景；普通自由击球不改。隐藏常驻统计，但每日清台状态通过landscape的无障碍label/value提供，测试从此读取杆数并验证跨模式保留。

DR-323取景补充：首次进入每日3D与开球全桌观察用既有长库侧全桌拟合（yaw=π/2），以后切换保留保存视角。ShotObservationMenu.overviewYaw默认nil沿用旧行为，仅每日3D传π/2；回到瞄准仍复用原相机路径。

### DR-324 — 每日清台3D操作驱动取景（2026-09-23）
- 仅每日清台3D：点击在桌目标球沿母球至该球方向观察；点击母球沿现有杆向进入较低姿态（既有姿态梯度0.25），目标观察维持默认0.5。点击不调用selectTarget、不改杆向/袋口/规则。
- 移除该页更多菜单中的视角选择；旋转/缩放与普通参数变化保持手动视角，显式点球才重新取景。击球、结果或开球期间不执行点球观察。
- CameraRig.enterAiming新增默认0.5的entryZoom参数，其余调用不变；本轮先落地三个核心行为，动态击球跟镜尚未新增。

### DR-325 — 每日清台正式场景配置
覆盖DR-314仅每日页的全局默认A约定：每日正常入口在setupScene前调用configureDailyClearanceRendering，启用R/原球影/PBR台呢、曝光-0.1、较窄镜头与匹配后退。其他消费者仍默认A；S与constant台呢仍为显式Debug实验，不自动随R启用。配置变化后性能/持续温升重新验，不能沿用旧RS组合结果。
Changelog：2026-09-23 / DR-325 / 用户授权有效修改落成每日默认。

### DR-326 — 每日清台统一HUD与显式击球（2026-09-24）
用户授权执行交互与规则v2全部批次。W1：2D/3D顶栏统一40pt可见高度、玩法固定居中球库，3D场景铺满HUD背后；方向/力度读数移入框内底部，方向尺按行程节流触感，开球使用带球三角。普通击球与手动开球力度松手仅刷新预览，移除求解迟到自动出杆及力度条辅助功能击球入口；显式击球按钮保留。默认瞄准特写关闭，保留用户已存偏好。开球选择用高对比双按钮“重新开球/继续击球”；运行中重开的事务安全待W7。
验证：W1 build通过；4项DailyPowerReleaseTests通过，常规屏HUD/实际按键击球2项、小屏五玩法HUD1项；W2/standard补验实际手动开球1项及4项力度回归通过。证据build/daily-clearance-interaction-v2/W1与W2/standard。已目视常规/小屏双模式；真机触感与持续性能未验收。共享其它页面逐项接入属于W8。

### DR-327 — 规则候选与临时自由瞄准（2026-09-24）
每日清台移除3D点球inspect提前返回，2D/3D经相同合法目标校验后调用selectTarget。非法点球保留目标/袋口/力度/打点，给出全色/花色/黑8或最低号提示。VM提供legalAimTargets，空集合表示没有合法目标；自动选球只从合法集合取。usesAutomaticPocketFallback显式接入每日：默认偏好进袋，最近可直进袋优先，无解临时自由；合法换球/下一杆重评恢复，显式自由偏好保留。方向尺进入本杆临时自由；显式不可直进袋口拒绝并提示。异步仍用predictGeneration丢弃旧结果。
新增BTRuleNoticeCenter：终局/裁决/选球/模式优先级，旧计时器不会清掉新消息，VoiceOver播报。其它消费者在W8按能力迁移。W4再接正式选球后的镜头，W5至W7再接双方规则及杆末结构化提示。
验证：4项DailyAimSelectionTests与1项RuleNoticeTests通过（W2/ipad/test.log中的独立单元部分）；常规屏真实2D/3D选合法/非法球UI通过，截图可见假想球、轨迹、袋口及全色提示（W3/standard-r2）。首轮UI失败因为诊断坐标仅3D开放，改为DEBUG双模式只读投影后通过；不是生产选球失败。W3主要行为完成，完整规则矩阵随W5至W7收口。

### DR-328 — 库边玩家视角与统一打点盘（2026-09-24）

每日清台采用共享CameraRig玩家视角：沿杆反向射线落在外库后，俯身/站立眼高分别为台面上0.16m/0.84m，默认过渡0.95s；减少动态效果用0.1s。光学放大下限18度，缩小止于该预设初始FOV（第一42度、第三48度；全桌按配置初始值），不再无限拉远。手势接管取消旧过渡。打点盘方向键44pt十字分布，交互红点半径减半，只读真实比例保持；底边按内库投影，投影不可用时走安全回退。9项相机/布局单测通过；常规/小屏/iPad基础双模式打点盘通过。全部调用方按W8能力审计接入，动态机位联验未完成前不标整批通过。

### DR-329 — 共享交互仪表与镜头能力接入（2026-09-24）
交互BTAimWheel默认滑动行程触感并在外框底部显示“方向”；BTShotInstrumentColumn默认紧凑外框，底部“力度/数值”，只读演示保持原读数和尺寸。ShotPlayerCameraButtons接受CameraRig与动作，VM无关；求解器通过当前已求得的方向显式接入，不改变求解目标。CueStroke增加默认关闭的switchesPlayerCameraOnContact，普通击球显式开启；开球、回放、序列和导出保持默认关闭，防止镜头政策串到视频。BTProjectedSpinPadOverlay采用场景局部可见投影，独立全屏每日HUD采用窗口投影。真源v2 W8能力表；W8-shared 9单测+2UI通过，10页面初次双模式控件测试通过，但FL-086截图问题修复后仍需复验，不记视觉全通过。

### DR-330 — 中性反馈表面与每日提示分层（2026-09-25）

统一BTNoticeContent（深色表面、白字、语义小图标）、BTDecisionPanel与BTDecisionActionStyle；每日状态不因轻提示消失，弹窗/打点盘展开时隐藏非必要消息，结束只显示结果。常规继续击球不重复Toast，计算状态放入击球控件。文案保留首碰、组合9、换手、自由球范围及重置等必要信息，不截断规则原因。FL-090更正：独立信息行缩小球桌，违反用户最大化要求，已撤销；状态/提示必须overlay，不能改变球桌尺寸；规范真源docs/design/feedback/提示与弹窗规范.md，截图审查与功能测试分别记录。

已应用至：.cursor/skills/swiftui-design-system/SKILL.md、tasks/UI-IMPLEMENTATION-SPEC.md（DR-330）。每日清台三尺寸定向截图/录屏审查及最终规则、交互测试完成，详见tasks/ui-reviews/UR-20260925-提示与弹窗体系.md；结果操作亦复用共享按钮。不宣称全项目独立弹窗、消息生命周期或完整辅助功能已迁移/验收。


### DR-331 — 每日相机契约（2026-09-25）
每日相机通过usesShotAwareCamera显式启用；共享页面与视频保持原预设。人称眼位读取实际杆姿，镜头视野按真实SCNView宽高约束水平角。观察中心仅由明确操作改变；运杆不带头、手动观察不被重算抢占。新增相机入口必须沿用同一镜头策略，并验证抬杆实页截图、中心保持和2D/3D往返。 每日独立三键从上至下为全局、观察、第一人称；第一人称使用朝左的低头架杆实心人物剪影（后肘抬起，避免折线火柴人），全局高亮绑定实际全桌构图状态，更多菜单不重复入口。


### DR-333 — 每日打点盘按2D内框统一几何（2026-09-25）
用户二次裁定：缩小且固定大小，大屏底对齐。仅每日清台启用BTSpinPadOverlay/BTSpinPadCard.usesFixedLayout；白盘160pt、背景264×264pt，四向键44pt，读数/回中分置下方向键两侧。两模式共用ShotTableLayout.landscapePlayingRect计算2D台面内框下沿，面板水平居中、底边贴齐；iPad不拉伸。默认false保持其他页面。覆盖首稿上下填满内框及DR-328每日随当前相机投影定位的约定；球桌取景本身不变。用户追加力度条固定长度：BTShotInstrumentColumn.fixedPowerBarHeight可选值，仅每日传144pt滑动区高度，移除宿主随屏高拉伸的仪表高度；力度范围/映射/拖动逻辑保持。
Changelog：2026-09-25，DR-333，新增usesFixedLayout，每日双模式固定尺寸、2D内框底对齐。
- 验证：8布局单元通过；最终常规手机/iPad/SE三项双模式UI及SE力度拖动1项通过，三尺寸原图已审；gate/diff/doc-size通过。一次短按连发与旧状态文案测试失败已留证，详情见`tasks/ui-reviews/UR-20260925-每日打点盘.md`。未真机验收。

### DR-332 — 球库状态与场景轻量反馈（2026-09-25）
用户最新确认覆盖DR-330每日场景契约：球库按玩法分区、固定球位，合法剩余球淡绿背景，当前瞄准细圈，已进袋暗显；取消常驻球组文字。HUDStyle.accent复用btOverviewDays深色淡绿，工具按钮轻透明底且始终有细框；无框文字提示/决策/结果位于上中袋下方，不增占位行、不缩球桌。BTNoticeContent.textOnly为显式场景入口；BTSceneDecisionActionStyle紧凑44pt点击区域无外层面板。普通页面提示保留原组件。详见docs/design/feedback/提示与弹窗规范.md修订节，验证状态以本轮报告为准。

2026-09-25 用户进一步澄清：需要用户选择的决策（重新开球/完成、局中重开、犯规处理）保持屏幕正中；仅普通文字提示和结果说明位于上中袋下方。按钮透明底细框，无外层大面板。此条覆盖此前将决策一起上移的理解。

最终位置口径：所有带操作选项的信息，包括清台结果＋再来一局、失败结果＋重新开球，统一屏幕正中；仅无操作临时提示放上中袋下方。2D/3D共用同一个中心覆盖层及组件，禁止分开定位。

### DR-334 · 角度训练操作试适配（2026-09-26）

SceneAimingView两个固定维度入口均自动横屏、退出恢复竖屏。顶部44pt完整单排参考球库（母球与1–15号，目标球高亮）；左侧52pt视角列；右侧96pt题目/结果、辅助和52pt淡绿圆形主操作列。2D横向全桌，袋口方位按横向取景映射；3D称高亮角袋/中袋。NumericKeypadHUD.usesSceneStyle默认false，仅两页启用深色右侧浮层及44pt按键，stage不随输入/反馈缩放；键盘允许局部遮挡。3D复用每日全局/观察/第一人称按钮和玩家眼位/横屏视野约束，切题沿用所选模式，回到瞄准进入第一人称，输入/结果禁用切换。不迁移每日规则或共享渲染循环。验收见UR-20260926-angle-training-trial。


### DR-335 — 每日清台球库按目标球居中（2026-09-28）

每日2D/3D共用单行44pt顶栏：母球独立放在左侧，右侧保留同宽透明布局空间；目标球行以球桌区域中线居中。中八按1–7｜8｜9–15对称，8号对齐2D中袋；追分9/6/5/4球按玩法固定目标球集合居中，偶数球以中间两球的间隙为中心，不套用黑8锚点。已进袋暗显且保留原位置，合法高亮/点选/禁用逻辑不变。左右操作列共用60pt宽度，击球按钮60pt并居中于力度仪表下方的剩余区域，与2D舞台隔开；顶栏不增高；球径先按安全区宽度确定（740pt及以上30pt、窄屏25pt），再扩展球库布局容器容纳母球镜像占位，不能用占位反向压缩球径。3D球库固定在HUD中线，不跟随观察相机中的袋口投影。

球库两端合法高亮使用16pt圆角，内侧仍4pt；44pt点按区域不裁切。右上视角/更多按钮组尾部对齐，并按右侧安全区余量整体右移最多24pt；球库标准屏放大至30pt球径，窄屏25pt，顶栏翼宽随球库真实宽度调整；每日清台标题以-12pt间距利用返回按钮的空白，保留44pt点击框；标准屏左移12pt、窄屏左移2pt，均下移3pt；标题胶囊高34pt且贴合内容，不覆盖整段翼宽。FPS位于2D/3D按钮下方、打点盘左侧，每日页采用10pt低对比度纯文字读数，无胶囊底色（静止时显示“静止”）；其他场景保留原位置和样式。

每日页两侧仪表改为顶部开球/击球点对应，中部方向条/力度条均固定144pt并上下端点对齐。3D三种观察按钮移至力度条右侧的独立一列并围绕刻度区居中；右侧安全区不足48pt时左右对称内收补足空间，2D/3D仪表位置一致且舞台中线不变。小屏底部重打/回放并排以保留固定刻度高度，标准屏仍竖排。

Changelog：2026-09-28 / DR-335 / 仅每日清台布局调整，覆盖DR-332整排含母球居中的旧口径。

### DR-336 — 瞄准与力度按滑速连续微调（2026-09-28）

共享BTAimWheel与BTShotInstrumentColumn按近期竖向位移/事件时间计算速度倍率，首版0.1～1；24pt/s以下精细、220pt/s以上正常，平滑升速80ms/降速25ms，事件间隔≥180ms按精细重启。只积累新增位移，无惯性；瞄准球距基础增益仍在起手锁定，覆盖旧“单次拖动内总增益不变”约定。四个瞄准消费入口接收非零有限微量，避免旧1e-4°过滤吞掉慢滑。

力度拖动连续写回，不再按step=0.1吸附；step仅用于绘制/粗调触感，新增accessibilityStep默认0.01；可编辑读数/AX显示两位小数，只读演示保留一位。沿用原力度曲线和0.6基础阻尼。每段钳制到边界，反向立即响应；仅到达边界震一次，离边超过1%行程才重新武装。粗调触感随倍率淡入、间隔至少100ms，微调静音，不对进入微调或松手震动；触感与数值提交独立。禁用/只读/取消/离页/后台清理手势状态。

Changelog：2026-09-28 / DR-336 / 共享调节行为v1；参数为待真机调校初值，测试与视觉证据见tasks/ui-reviews/UR-20260928-adaptive-controls.md。


### DR-337 — 全局视角C档与相机图标（2026-09-28）

用户选择global-camera-compare-20260928/r4的C档：CameraRig.observeWholeTable在按当前视口/方向拟合的距离上乘1.18；既有45°俯角、镜头FOV和朝向策略保持，pivot为桌心球心高度(0,surfaceY+R,0)。水平旋转沿用围绕该pivot的轨道，距离/高度/FOV不变；不强制在每个旋转方向自动缩小适配。2D拟合margin及玩家第一/第三人称预设不调整。r4已确认预览保持冻结，出图夹具反除正式倍率以保留旧基准，避免重复乘1.18。

ShotPlayerCameraButtons的全局图标改为斜向下看的眼睛配短视线箭头，观察图标改为figure.stand，第一人称继续原俯身架杆剪影。三键顺序、44pt点击区域、选中态、无障碍标签及业务动作保持。覆盖共用三键的每日清台与角度训练；原双键分支的站立图标保持。

Changelog：2026-09-28 / DR-337 / 用户确认C档并要求图标直观化；验证见tasks/ui-reviews/UR-20260928-global-camera-icons.md。


DR-337图标二次调整（2026-09-28，用户追加）：全局改用普通SF Symbol eye（btHeadline），移除斜眼及箭头；观察figure.stand从17pt放大到24pt semibold，44pt按钮区域不变，双键和三键共用观察图标尺寸。第一人称剪影与C档摄像头参数保持。此条覆盖本节前述斜眼方案。

### DR-336 r2 — 精调触感与局部刻度（2026-09-28，用户追加）

覆盖首版“微调静音”：慢滑仍提供轻反馈，倍率0.1时强度0.22、粗调渐增至0.4；精细触感间隔为粗调十分之一，100ms限频与相对行程回差保持。刻度精度改变时重设反馈起点，禁止因缩放或停手产生触感，不按触感档位量化数值。

ShotPrecisionScale以增益<0.22持续120ms进入精细、>0.55持续120ms退出；中间区/停顿/松手保持原精度，下一手势重新计时。连续输入倍率本身仍按首版曲线变化。瞄准尺围绕当前值平滑放大10倍，分级细刻度在屏幕间隔3～7pt间淡入，默认相邻粗/细刻度对应8pt基础行程及其十分之一。力度保持全范围水位，水位附近64pt局部刻度窗口显示默认0.01细分，两端裁剪到控件/实际量程。刻度缩放动画180ms，减少动态效果时关闭。两位读数、无吸附、无惯性与松手不击球保持。

Changelog：2026-09-28 / DR-336 r2 / 细调触感恢复、瞄准标尺放大、力度局部精细刻度；验证见UR-20260928-adaptive-controls.md的r2节。


### DR-336 r3 — 两尺触感增强（2026-09-28）

用户反馈r2瞄准条和力度条震动过弱。两者反馈发生器由light改为medium，共享强度由细调0.22/粗调0.40提高到0.60/0.85；力度边界由0.65提高到1.0。保留细调轻于粗调、边界强于刻度的层次；100ms限频、触发间距、防抖、连续输入与自适应标尺均沿用r2。参数是此次用户反馈后的调校值，实际震感待手机确认，不能按数值比值宣称物理震感提升倍数。

Changelog：2026-09-28 / DR-336 r3 / 两尺震感增强。

### DR-336 r4 — 两尺刻度声（2026-10-01）

BTAimWheel与BTShotInstrumentColumn在现有有效刻度反馈时调用ShotSoundBank的独立操作声通道；两者均使用原创12ms点击样本并全局100ms限频。声音沿用soundEffectsEnabled及ambient静音契约；瞄准声音不依赖degreeHapticEnabled/travelHapticEnabled。精度切换、停手、松手不发声，力度持续顶住边界不连响。数值写回保持连续，不为声音吸附；离页/后台不排队残响。默认关闭和用户保存选择保持，未完成真机试听不能宣称音色/响度满意。

Changelog：2026-10-01 / DR-336 r4 / 瞄准与力度刻度声；验证见CONTROL-AUDIO-20261001.md。

### DR-336 r5 — 金属音色及音频/触感独立频率（2026-10-01）

用户授权瞄准用A精密金属滚轮、力度用B厚重棘轮。两种单次齿声作为现有Audio目录中的WAV打包，不受物理音效Debug导入覆盖；原100ms触感限频保持，声音以独立ShotDragDetents使用60ms限频且由有效值变化驱动。两个反馈器换精度/结束/取消时均重设起点，力度到边界后重设两者，不因限频堆积声音。禁止直接循环4.4秒试听、随滑速变调或更改参数写回。共用soundEffectsEnabled和ambient静音模式。

Changelog：2026-10-01 / DR-336 r5 / 授权金属音色、音频与震动限频分离；验证见CONTROL-AUDIO-20261001.md。


### DR-337 r2 / DR-331 r2 — 每日双侧全局与连续缩放（2026-10-01）
每日全局从可见yaw选择最近长库±π/2，等距由杆向决定，60°/秒双向最短路；中途全桌取景、手势接管和2D往返须验连续帧。默认C不改，缩小边界后退8%，与观察共用投影包围框占屏幕比例，不能用低俯角面积当唯一尺度；捏合不隐式全桌居中。光学/退远缩放必须可逆，基线随观察中心和PerspectiveState保存恢复。其余页保持旧入口。
Changelog：2026-10-01 / DR-337 r2、DR-331 r2 / 用户授权的每日相机局部修复；验证见tasks/DAILY-CAMERA-ZOOM-20261001.md。


### DR-337 r3 / DR-331 r3 — 每日观察复位与防穿墙（2026-10-01）
每日显式观察入口恢复当前母球/杆向的标准FOV、距离与俯角，不恢复放大缩小或上下滑动，不为双球取景自动退远；缩小最多标准距离×1.15，投影下限仍为次级约束。房间墙内35cm安全边界须覆盖插值、绕转、缩放、恢复的每帧；捕获状态必须对应实际眼位。2D往返和重打仍恢复快照，其他宿主不改。全局40/35/30仅DEBUG截图候选，未选定前保留生产45°。
Changelog：2026-10-01 / DR-337 r3、DR-331 r3 / 用户追加观察复位、缩小范围及墙遮挡修复；证据见tasks/DAILY-CAMERA-ZOOM-20261001.md后续r3节。


### DR-337 r4 / FL-094 r5 — 动态取景验收（2026-10-01）
Daily全局正式35°。观察用途为阅读当前一杆两球与袋嘴，固定俯角或三中心入框不能证明可用：检实体包络、两球遮挡/近库下缘、自然镜头边界和手动所有权。每日有袋观察动态选朝向/俯角/FOV，超限采用有界局部站位；entry冻结主体且重进复位，换袋/自由/开球不可读旧袋。测试按几何不变量生成跨尺寸/六袋/短球/薄球布局，实际原生截图验USDZ外观；3072投影场景不等于3072原生截图或物理进球成功。规则与证据见tasks/DAILY-CAMERA-FORMATIONS-20261001.md。

### FL-094 r6 — 相机覆盖证据分层（2026-10-01）

独立球形、重复视口投影、操作序列、真实模型渲染和原生含HUD页面分别计数。只有相机节点的投影夹具不能证明无遮挡；相机可见性应覆盖在桌其他球与库/jaw等实体。补detail↔wide、零轴输入不改另一轴、运行中resize/2D恢复、转场接管、候选分支临界微扰及全部无解分支；终点入框不能替代机位连续性或途中有效性。诊断采集成功只证明执行，发现的反例仍须逐一修复验收，不宣称一般盘面可用。

Changelog：2026-10-01 / FL-094 r6 / 场景覆盖不足返工；证据见tasks/DAILY-CAMERA-COVERAGE-AUDIT-20261001.md，生产行为未在本轮修改。

### DR-345 r2：目标袋口短暂黄色反馈（2026-10-01）

- 普通目标袋被选中时显示既有 `PocketLeatherAppearance.targetTint` 黄色皮革，持续 **0.6 秒**后恢复当前球桌主题的皮革原色；不留下轮廓、纹路或持续变色。
- 2D/3D 共用实际袋口皮革网格、纹理与透视；选袋状态及命中区域保持不变，恢复原色不等于取消目标。
- 单次反馈结束后没有持续动画；切换或清除目标立即取消旧反馈；重复同步同一个目标不重启计时。
- ①/②教学角色的绿/青双色标记沿用既有规则。



### DR-336 r6 — 用户原声顺序试听（2026-10-01）

用户提供两组时按组配对逐版试听：direction.mp3+power.mp3先激活，direction-v2.mp3+power-v2.mp3保留待反馈。当前约44ms单齿取代r5合成资源；只裁切、去DC、极短淡入淡出、统一峰值，不改滑动/震动节奏。保留原文件、历史资源与可复现manifest，安装不清空训练。验证边界见CONTROL-AUDIO-20261001.md r6。


### DR-345 r3：选袋状态与延后黄色确认（2026-10-01）

覆盖r2的即时反馈约定：选择和模式立即提交，点击后固定等待 **1秒**，再显示既有黄色 **0.6秒**，恢复当前主题原皮革。`show(_:confirmsSelection:)`应用语义状态；PositionPlay调用false，显式`confirmPocketSelection(at:)`确认事件。同袋重复点击重启反馈、不重复求解；快速点选只留最后一个。新触摸、拖动、击球、清空、换模式/视图和退页取消。

Daily/普通击球/试打的进袋辅助只推荐直接线路；几何候选不足时不伪造可行袋口，确定不可直进的手动选袋保留意图并临时切自由、保留当前方向，边界不确定继续当前杆预测。后台只交付当前杆结果，不能换球袋或搜索Bank/多库、更改杆法。显式翻袋工具与自由模拟自然碰库保留。实际模式与主动偏好分别保存；状态持续显示于既有副标题/Daily标题区域。2D/3D使用同一皮革网格；①绿/②青及双方角色保留。

实现与验收真源：[袋口选择方案](../../../tasks/POCKET-SELECTION-UX-20261001.md)。
