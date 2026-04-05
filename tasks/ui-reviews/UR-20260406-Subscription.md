## UI 审查报告 — SubscriptionView（独立深色全屏）

日期：2026-04-06
审查任务：T-R1-10
源文件：`QiuJi/Features/Profile/Views/SubscriptionView.swift`（373 行）
设计参考：`ui_design/tasks/P2-06/stitch_task_p2_06_02/screen.png` + `code.html`
参照截图：`ui_design/ref-screenshots/09-premium-paywall/03-paywall.png`（训记付费墙模式）
规范：`tasks/UI-IMPLEMENTATION-SPEC.md` § 三（独立全屏导航）、§ 六.4（排除 Dark Mode）、§ 七（辅助页面决策）

---

### U-01 底部区域 padding 与设计不一致

- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：Tab 5 > SubscriptionView > bottomSection
- **现状**：`bottomSection` 底部 padding 使用 `Spacing.lg`（16pt）
- **预期**：code.html 中 outer container 使用 `pb-6`（24pt），应与水平 padding `Spacing.xxl`（24pt）一致
- **修复方向**：将 `.padding(.bottom, Spacing.lg)` 改为 `.padding(.bottom, Spacing.xxl)`
- **路由至**：swiftui-developer
- **代码提示**：`SubscriptionView.swift` L36

---

### U-02 功能列表行间距使用硬编码值 `11`

- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：Tab 5 > SubscriptionView > featuresList
- **现状**：`VStack(spacing: 11)` — `11` 不是 `Spacing` 枚举值
- **预期**：使用最近的 Spacing Token。code.html 中 `space-y-[11pt]` 对应无精确 Token，最近为 `Spacing.md`（12pt）
- **修复方向**：将 `spacing: 11` 改为 `spacing: Spacing.md`；若设计执意 11pt，在 `Spacing` 枚举中补充（不推荐）
- **路由至**：swiftui-developer
- **代码提示**：`SubscriptionView.swift` L105

---

### U-03 功能行标题-副标题间距使用硬编码值 `1`

- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：Tab 5 > SubscriptionView > featureRow
- **现状**：`VStack(alignment: .leading, spacing: 1)` — `1` 不是 `Spacing` 枚举值
- **预期**：最小标准 Token 为 `Spacing.xs`（4pt）。code.html 中标题与副标题间距约 2-4px
- **修复方向**：改为 `spacing: 2` 并注释说明，或使用 `Spacing.xs`（4pt）以符合 Token 规范
- **路由至**：swiftui-developer
- **代码提示**：`SubscriptionView.swift` L126

---

### U-04 Hero 渐变使用硬编码灰色 `Color(white: 0.21)`

- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：Tab 5 > SubscriptionView > heroSection 圆形渐变
- **现状**：`LinearGradient(colors: [Color.btPrimary.opacity(0.4), Color(white: 0.21)], ...)`，`Color(white: 0.21)` 为硬编码灰
- **预期**：code.html 中对应 `surface-container-highest`（`#353534`）。虽无精确 Token 对应，建议使用 `Color.btBGTertiary`（Dark 变体 `#2C2C2E`）或 `Color.btBGQuaternary`（Dark 变体 `#3A3A3C`）近似
- **修复方向**：替换为 `Color.btBGTertiary` 作为渐变终止色
- **路由至**：swiftui-developer
- **代码提示**：`SubscriptionView.swift` L75

---

### U-05 Hero 标题字号 22pt（btTitle）与设计 24pt 不一致

- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：Tab 5 > SubscriptionView > heroSection 标题
- **现状**：使用 `.btTitle`（22pt Bold Rounded）
- **预期**：code.html 明确标注 `text-[24pt] font-bold`。Token 系统无 24pt 字号，最近为 btTitle（22pt）和 btStatNumber（28pt）
- **修复方向**：可接受使用 btTitle（22pt）作为最近 Token；若需精确匹配设计，可在 Typography.swift 中补充 btTitle1（24pt）或接受 2pt 偏差
- **路由至**：swiftui-developer
- **代码提示**：`SubscriptionView.swift` L93，`Typography.swift`

---

### U-06 CTA 按钮缺少阴影

- **类别**：视觉打磨
- **严重程度**：P2（视觉瑕疵）
- **位置**：Tab 5 > SubscriptionView > subscribeButton
- **现状**：按钮无阴影修饰
- **预期**：code.html 中 CTA 按钮使用 `shadow-lg`，在深色背景上提供悬浮层次感
- **修复方向**：添加 `.shadow(color: Color.btPrimary.opacity(0.3), radius: 8, x: 0, y: 4)` 品牌色辉光阴影
- **路由至**：swiftui-developer
- **代码提示**：`SubscriptionView.swift` L276-298

---

### U-07 法律文字对比度不足（white/20 ≈ 1.8:1）

- **类别**：无障碍
- **严重程度**：P2（视觉瑕疵）
- **位置**：Tab 5 > SubscriptionView > legalSection 全部文字与链接
- **现状**：法律声明与链接均使用 `.white.opacity(0.2)`，在 `#111111` 背景上计算对比度约 1.8:1
- **预期**：WCAG AA 正常文字要求 ≥ 4.5:1，UI 组件要求 ≥ 3:1。code.html 同样使用 white/20（设计意图为极弱化），但不满足无障碍标准
- **修复方向**：提升至 `.white.opacity(0.35)` 可达到 ≈ 3.2:1（满足 UI 组件 3:1）；完全达标需 `.white.opacity(0.5)` 以上。付费墙法律文字低对比度在行业中普遍存在，酌情决定
- **路由至**：swiftui-developer
- **代码提示**：`SubscriptionView.swift` L317-338

---

### U-08 副标题与功能描述对比度偏低（white/40 ≈ 3.9:1）

- **类别**：无障碍
- **严重程度**：P2（视觉瑕疵）
- **位置**：Tab 5 > SubscriptionView > heroSection 副标题 + featureRow 副标题
- **现状**：使用 `.white.opacity(0.4)` 在 `#111111` 背景上，计算对比度约 3.9:1
- **预期**：11pt 文字（btCaption2）为正常文字，WCAG AA 要求 ≥ 4.5:1；差 0.6:1
- **修复方向**：提升至 `.white.opacity(0.5)` 可达到 ≈ 5.0:1 满足标准，同时保持弱化视觉效果。code.html 设计为 white/40，属设计意图但不达标
- **路由至**：swiftui-developer
- **代码提示**：`SubscriptionView.swift` L97, L132

---

### U-09 关闭按钮触摸目标可能不足 44pt

- **类别**：HIG
- **严重程度**：P2（视觉瑕疵）
- **位置**：Tab 5 > SubscriptionView > topBar X 按钮
- **现状**：关闭按钮为 17pt 图标（btBodyMedium），外层 HStack 高 48pt 但按钮宽度未显式设置，水平触摸区域取决于图标渲染宽度（约 17pt）
- **预期**：Apple HIG 要求可点击元素触摸目标 ≥ 44×44pt
- **修复方向**：为按钮添加 `.frame(width: 44, height: 44)` 或 `.contentShape(Rectangle())` 扩大点击区域
- **路由至**：swiftui-developer
- **代码提示**：`SubscriptionView.swift` L57-61

---

### U-10 「已是 Pro 会员」状态按钮使用系统 `Color.gray`

- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：Tab 5 > SubscriptionView > subscribeButton（已订阅状态）
- **现状**：`.background(subscriptionManager.isPremium ? Color.gray : Color.btPrimary)` — `Color.gray` 不属于设计系统 Token
- **预期**：禁用/已完成状态应使用 `Color.btBGQuaternary`（Dark 变体 `#3A3A3C`）或 `Color.btBGTertiary`（`#2C2C2E`），与页面深色氛围一致
- **修复方向**：替换 `Color.gray` 为 `Color.btBGTertiary` 或 `Color.btBGQuaternary`
- **路由至**：swiftui-developer
- **代码提示**：`SubscriptionView.swift` L295

---

### U-11 背景色 #111111 以 RGB 字面量硬编码

- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：Tab 5 > SubscriptionView > bgColor 属性
- **现状**：`Color(red: 0x11/255.0, green: 0x11/255.0, blue: 0x11/255.0)` — 直接硬编码 hex
- **预期**：SKILL.md §二规则「禁止在代码中硬编码 hex 值」。SubscriptionView 作为 §六.4 排除页面使用专属背景色，建议在 `Assets.xcassets` 中新增 `btBGPaywall` 色资产（Light/Dark 均为 `#111111`），或至少提取为 `static let` 并注明来源
- **修复方向**：新增 `btBGPaywall` 色资产或在 Colors.swift 中添加 `static let btBGPaywall = Color(red: 0x11/255.0, green: 0x11/255.0, blue: 0x11/255.0)` 并注释「SubscriptionView 专属」
- **路由至**：swiftui-developer
- **代码提示**：`SubscriptionView.swift` L11，`Colors.swift`

---

### 通过项（无问题）

| 维度 | 检查项 | 状态 |
|------|--------|------|
| Design Token | 金色使用 `Color.btAccent` | ✅ |
| Design Token | 品牌绿使用 `Color.btPrimary` | ✅ |
| Design Token | 方案卡圆角 `BTRadius.md`（12pt） | ✅ |
| Design Token | 水平 padding `Spacing.xxl`（24pt） | ✅ |
| Design Token | 方案卡间距 `Spacing.sm`（8pt） | ✅ |
| 布局 | 顶栏 X 按钮左对齐 + 48pt 高 | ✅ |
| 布局 | Hero 居中：圆形图标 60pt + 标题 + 副标题 | ✅ |
| 布局 | 6 项功能列表：金色编号圆 22pt + 标题 + 副标题 | ✅ |
| 布局 | 3 列方案卡（月/年/终身） | ✅ |
| 布局 | ScrollView 包裹 Hero+Features，底部固定 | ✅ |
| 布局 | 年订卡绿框 + 「推荐」胶囊标签 + 勾选图标 | ✅ |
| 布局 | 终身买断卡金色弱边框 | ✅ |
| 布局 | CTA 按钮动态显示选中方案名+价格 | ✅ |
| Dark Mode | `.preferredColorScheme(.dark)` 强制深色 + 白色状态栏 | ✅ |
| Dark Mode | 排除系统 Dark Mode 切换影响（页面始终深色） | ✅ |
| 产品规格 | 付费墙全屏深色 #111111 背景 | ✅ |
| 产品规格 | 年订绿框 + 推荐标签 + 勾选 + 月均折算 | ✅ |
| 产品规格 | 动态价格 CTA（含终身买断变体） | ✅ |
| 产品规格 | 法律声明 + 恢复购买 + 服务条款 + 隐私政策 | ✅ |
| 产品规格 | StoreKit 2 集成 + 产品加载 + 购买流程 | ✅ |
| HIG | CTA 按钮高度 44pt | ✅ |
| HIG | 系统 Alert 用于恢复购买反馈 | ✅ |
| HIG | 无 NavigationStack（独立全屏模式正确） | ✅ |
| 视觉打磨 | 方案卡玻璃效果 `rgba(255,255,255,0.04)` | ✅ |
| 视觉打磨 | 选中态绿色淡底 `btPrimary.opacity(0.1)` | ✅ |
| 视觉打磨 | 按钮弹性动画 `.spring(duration: 0.2)` | ✅ |

---

### 审查总结

- 截图数量：1 张 stitch + 5 张 ref-screenshots
- 发现问题：11 项（P0: 0 / P1: 0 / P2: 11）
- 总体评价：**SubscriptionView 整体结构与设计高度吻合**。全屏深色 #111111 背景、金色编号功能列表、3 列方案卡、年订推荐标签、动态价格 CTA 均正确实现。问题集中在 Token 规范化（硬编码间距/颜色）和无障碍对比度两个方面，均为 P2 级别视觉瑕疵，不影响功能使用。
- 建议下一步：
  1. **优先修复** U-09（关闭按钮触摸目标）— 最接近功能影响
  2. **批量修复** U-01~U-04、U-10~U-11（Token 规范化）— 统一清理硬编码值
  3. **酌情处理** U-07~U-08（对比度）— 付费墙行业惯例允许法律文字极低对比度，但建议至少提升至 3:1
  4. **低优先级** U-05~U-06（细节打磨）
