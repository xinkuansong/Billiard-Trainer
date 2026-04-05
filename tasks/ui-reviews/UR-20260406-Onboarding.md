## UI 审查报告 — OnboardingView + LoginView + PhoneLoginView（Light + Dark）
日期：2026-04-06
任务：T-R1-09

### 审查范围

| 页面 | 文件 | 行数 | 设计参考 |
|------|------|------|---------|
| OnboardingView | `Features/Profile/Views/OnboardingView.swift` | 227 | P2-04 stitch |
| LoginView | `Features/Profile/Views/LoginView.swift` | 194 | P2-05 loginview stitch |
| PhoneLoginView | `Features/Profile/Views/PhoneLoginView.swift` | 201 | P2-05 phoneloginview stitch |

---

### U-01 LoginView 三按钮圆角 8pt → 设计稿 12pt
- **类别**：Design Token
- **严重程度**：P1（功能缺陷）
- **位置**：Tab 5 > LoginView > 登录按钮区域
- **现状**：Apple、微信、手机号三个按钮均使用 `BTRadius.sm`（8pt）圆角 `clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))`
- **预期**：stitch code.html 明确定义 `rounded-btn: 12pt`，screen.png 也显示更大的圆角。由于这三个按钮是自定义样式（非 BTButtonStyle），应跟随设计稿使用 `BTRadius.md`（12pt）
- **修复方向**：将 LoginView 中三个按钮的 `BTRadius.sm` 替换为 `BTRadius.md`
- **路由至**：swiftui-developer
- **代码提示**：`LoginView.swift` L119, L136, L149, L151 — 4 处 `BTRadius.sm` 引用

---

### U-02 OnboardingView「登录已有账号」/「跳过」按钮使用绿色 → 设计稿为灰色
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：Tab 5 > OnboardingView > 底部操作区
- **现状**：「跳过」和「登录已有账号」均使用 `BTButtonStyle.text`，渲染为 btPrimary 绿色文字
- **预期**：stitch P2-04 code.html L165 明确使用 `text-[#404940]`（灰色），对应 btTextSecondary。这些是弱操作链接，视觉层级应低于主按钮
- **修复方向**：将「跳过」/「登录已有账号」按钮改为 `.font(.btCallout) .foregroundStyle(.btTextSecondary)`（不使用 BTButtonStyle.text），或新增一种灰色 text 按钮变体
- **路由至**：swiftui-developer
- **代码提示**：`OnboardingView.swift` L138-140（跳过）、L148-150（登录已有账号）

---

### U-03 LoginView 法律链接缺少下划线装饰
- **类别**：视觉打磨
- **严重程度**：P2（视觉瑕疵）
- **位置**：Tab 5 > LoginView > 底部法律文案
- **现状**：「用户协议」和「隐私政策」仅使用 btPrimary 绿色文字，无下划线
- **预期**：stitch code.html L86 使用 `underline decoration-ios-border` 下划线装饰。下划线明确标识可点击链接，改善无障碍识别
- **修复方向**：为两个链接 Text 添加 `.underline()` 修饰符
- **路由至**：swiftui-developer
- **代码提示**：`LoginView.swift` L62-70

---

### U-04 PhoneLoginView「发送验证码」激活态视觉不匹配设计稿
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：Tab 5 > PhoneLoginView > 验证码输入行
- **现状**：`canSendCode` 为 true 时，按钮为 `btPrimary` 实心填充 + 白色文字（高视觉权重）
- **预期**：stitch code.html L137 使用 `bg-[#1A6B3C]/10 text-[#1A6B3C]`（btPrimaryMuted 底色 + btPrimary 文字），视觉权重低于底部主登录按钮
- **修复方向**：激活态改为 `background(Color.btPrimaryMuted) + foregroundStyle(.btPrimary)`，保持「登录」主按钮为唯一实心绿色 CTA
- **路由至**：swiftui-developer
- **代码提示**：`PhoneLoginView.swift` L76-79

---

### U-05 PhoneLoginView「登录」按钮禁用态视觉区分不足
- **类别**：无障碍
- **严重程度**：P2（视觉瑕疵）
- **位置**：Tab 5 > PhoneLoginView > 登录按钮
- **现状**：使用 `BTButtonStyle.primary` + `.disabled(!canLogin)`，SwiftUI 默认仅降低 opacity（~0.4），仍呈现为淡绿色
- **预期**：stitch code.html L143 使用 `bg-on-background/10 text-on-surface/30`（灰色背景 + 浅灰文字），明确传达不可点击状态
- **修复方向**：在 BTButtonStyle.primary 的 PrimaryButtonBody 中增加 `@Environment(\.isEnabled)` 判断，禁用时背景改为 `btBGQuaternary`、文字改为 `btTextTertiary`；或在 PhoneLoginView 本地覆盖禁用样式
- **路由至**：swiftui-developer
- **代码提示**：`BTButton.swift` PrimaryButtonBody（L38-51）或 `PhoneLoginView.swift` L101-106

---

### U-06 LoginView WeChat 绿色硬编码 RGB
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：Tab 5 > LoginView > 微信登录按钮
- **现状**：`Color(red: 0.027, green: 0.757, blue: 0.376)` 直接硬编码 `#07C160`
- **预期**：所有颜色应使用语义 Token 或命名常量（SKILL.md §二 规则："禁止在代码中硬编码 hex 值"）
- **修复方向**：在 Colors.swift 或 LoginView 内定义 `static let btWechat = Color(red: 0.027, green: 0.757, blue: 0.376)` 命名常量（第三方品牌色无需 Asset Catalog Light/Dark 变体）
- **路由至**：swiftui-developer
- **代码提示**：`LoginView.swift` L135

---

### U-07 LoginView「欢迎使用球迹」标题字号偏小
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：Tab 5 > LoginView > 标题区域
- **现状**：使用 `.btTitle`（22pt Bold Rounded），页面主标题视觉权重偏低
- **预期**：stitch code.html L56 使用 `text-[26pt] font-bold`。Token 系统无精确 26pt Token，最接近为 btLargeTitle（34pt，过大）。作为独立模态页面的主标题，26pt 可提升视觉冲击力
- **修复方向**：考虑在 Typography 中添加 `btTitle1` = 26pt Bold Rounded Token（介于 btTitle 22pt 和 btLargeTitle 34pt 之间），或将此处特例为 `Font.system(size: 26, weight: .bold, design: .rounded)` 并注释说明
- **路由至**：swiftui-developer
- **代码提示**：`LoginView.swift` L28；可能需同步更新 `Typography.swift`

---

### 审查通过项（无问题）

#### 1. Design Token 一致性（部分通过）
- ✅ 三个页面背景均使用 `Color.btBG.ignoresSafeArea()`
- ✅ 文字层次正确使用 btText / btTextSecondary / btTextTertiary
- ✅ 间距全部使用 Spacing 枚举（xs/sm/md/lg/xl/xxl/xxxl/xxxxl）
- ✅ OnboardingView Feature Row 图标底圆使用 `btPrimary.opacity(0.12)`，匹配 stitch 10% opacity
- ⚠️ 7 项偏差见上方 U-01 ~ U-07

#### 2. 布局与结构
- ✅ OnboardingView 使用 TabView + page 样式，3 页滑动引导
- ✅ LoginView VStack 垂直布局，按钮组集中在中部
- ✅ PhoneLoginView 输入字段为药丸形 Capsule，匹配设计稿
- ✅ PhoneLoginView 底部品牌标识（同心圆 + 球迹 · QIUJI）匹配 stitch
- ✅ 长文本（feature subtitle）使用 `.multilineTextAlignment(.center)` + `.lineSpacing(4)`
- ✅ Safe Area 合规 — btBG `ignoresSafeArea` 确保背景延伸

#### 3. Dark Mode 适配
- ✅ OnboardingView 设置 `.preferredColorScheme(.light)` 强制浅色，符合 UI-IMPLEMENTATION-SPEC §六 排除列表
- ✅ LoginView Apple 按钮 Dark HIG：`colorScheme == .dark ? Color.white : Color.black` 背景 + 反色文字
- ✅ LoginView 手机号按钮 Dark 适配：btPrimary 文字 + btBGTertiary 底色 + btPrimary 描边
- ✅ PhoneLoginView 输入框 Dark：btBGSecondary (#1C1C1E) + btSeparator 描边
- ✅ PhoneLoginView 品牌区 Dark：token 色自动适配
- ✅ LoginView / PhoneLoginView 无硬编码 `.white` / `.black`（Apple 按钮除外，该处遵循 HIG 规范）

#### 4. 产品规格一致性
- ✅ OnboardingView 3 页引导：特性页 × 2 + 登录/功能概览页 × 1
- ✅ OnboardingView Page 3 展示 QJ Logo + 品牌名 + 三大功能亮点
- ✅ LoginView 三按钮层级正确：Apple 黑 > 微信绿 > 手机号描边（UI-IMPLEMENTATION-SPEC §七）
- ✅ LoginView 底部法律文案「登录即表示您同意 用户协议 和 隐私政策」
- ✅ PhoneLoginView +86 国码 + 验证码输入 + 60s 倒计时逻辑
- ✅ 匿名使用功能完备 — OnboardingView「开始使用」/ LoginView「暂不登录，匿名使用」均调用 `authState.loginAnonymously()`

#### 5. Apple HIG 合规
- ✅ 所有按钮触摸目标 ≥ 44pt（Primary 52pt、Text minHeight 44pt）
- ✅ LoginView 作为 sheet 模态展示，系统自动提供拖拽条
- ✅ PhoneLoginView 使用 NavigationStack + inline title
- ✅ PhoneLoginView 键盘类型正确：`.phonePad`（手机号）+ `.numberPad`（验证码）
- ✅ Apple Sign In 按钮遵循 HIG 色彩规范（Light: 黑底白字 / Dark: 白底黑字）

#### 6. 无障碍
- ✅ btText (#000000) on btBG (#F2F2F7) 对比度 ∞ → ≥ 4.5:1
- ✅ btPrimary (#1A6B3C) on btBG (#F2F2F7) 对比度约 5.2:1 → ≥ 4.5:1
- ✅ 白色文字 on btPrimary (#1A6B3C) 对比度约 5.2:1 → ≥ 4.5:1
- ✅ 白色文字 on WeChat #07C160 — 17pt Semibold 属大文字（≥14pt bold），3:1 标准满足
- ✅ 交互元素不仅以颜色区分（按钮有形状、文字辅助）
- ⚠️ U-05: 禁用按钮仅靠 opacity 区分，应有更明确的视觉差异

#### 7. 视觉打磨
- ✅ OnboardingView 页面指示器：胶囊形（活跃 24pt / 非活跃 8pt），品牌绿色
- ✅ 图标使用 SF Symbols 系统图标（figure.pool.swim, angle, chart.bar.fill 等）
- ✅ PhoneLoginView 品牌标识精致（同心圆 + 小绿点 + 「球迹 · QIUJI」）
- ✅ 按钮按下态有 scale(0.98) 微动画反馈
- ✅ 无多余阴影、装饰元素

---

### 审查总结
- 截图/代码审查范围：3 个 Swift 文件 + 3 组设计稿（stitch PNG + HTML + ref-screenshots）
- 发现问题：7 项（P0: 0 / P1: 1 / P2: 6）
- 总体评价：三个页面整体结构与产品规格高度一致，Design Token 使用规范、Dark Mode 适配到位（含 HIG Apple 按钮）。主要偏差集中在 LoginView 自定义按钮圆角（P1）以及若干视觉微调项。
- 建议下一步：
  1. **优先修复 U-01**（LoginView 按钮圆角 8→12pt），影响三个按钮的视觉一致性
  2. **批量处理 U-02 ~ U-07**，多为单行修改
  3. U-05（BTButton.primary 禁用态）建议作为组件级改进，影响所有使用 BTButtonStyle.primary 的页面
