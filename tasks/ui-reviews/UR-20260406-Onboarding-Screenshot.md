## UI 截图审查报告 — OnboardingView + LoginView（截图对照）
日期：2026-04-06

审查对象：引导页 + 登录选项页
截图来源：P2-04-01 ~ P2-04-04, P2-05-01（5 张实机截图）
设计参考：P2-04 OnboardingView, P2-05 LoginView, ref-screenshots/08-onboarding-login

> 本报告为**截图对照审查**，对比实机运行效果与设计稿视觉输出。与已有代码审查报告 `UR-20260406-Onboarding.md` 互补；已修复项不再重复列出。

---

### S-01 Page 3 App Logo 样式与设计稿差异显著
- **类别**：视觉打磨
- **严重程度**：P2（视觉瑕疵）
- **位置**：OnboardingView > Page 3（品牌总览页）> 顶部 Logo 区域
- **截图现状**：灰色实心圆（btBGTertiary #E5E5EA，100pt）内含一个绿色圆角矩形徽章（40×28pt），徽章上白色 "QJ" 文字，整体偏移下方 4pt。视觉上为一个朴素的标签贴在灰色底圆上
- **设计预期**：设计稿（P2-04 screen.png + code.html L108-118）为白色台球造型——白色圆形底、中间一条绿色横条纹（#1A6B3C，高度 24pt）、带径向高光渐变模拟球体立体感，中心有一个白色小圆内显示 "QJ"。整体传达台球品牌感
- **修复方向**：将 `appLogo` 重构为台球球体设计——白色底圆 + 绿色水平条纹 + 径向渐变高光 + 中心白色 "QJ" 圆。可参考 code.html L108-118 的 CSS 结构翻译为 SwiftUI ZStack 叠层
- **路由至**：swiftui-developer
- **代码提示**：`OnboardingView.swift` L172-190 `appLogo` computed property

---

### S-02 Page 3 功能行副标题字号偏小（13pt vs 15pt）
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：OnboardingView > Page 3 > 三行功能介绍 > 副标题文字
- **截图现状**：三行副标题（"海量练习动作，轻松记录训练"、"模拟球台场景，提升角度判断力"、"可视化训练进度，发现薄弱项"）使用 `btFootnote`（13pt），视觉上偏小，与标题的层级差过大
- **设计预期**：code.html L132 明确使用 `text-[15pt]`，对应 Token `btSubheadline`（15pt regular）。15pt 副标题与 17pt 标题之间形成更紧凑的层级对比
- **修复方向**：`OnboardingFeatureRow` 中副标题字体从 `.btFootnote` 改为 `.btSubheadline`
- **路由至**：swiftui-developer
- **代码提示**：`OnboardingView.swift` L216 `.font(.btFootnote)` → `.font(.btSubheadline)`

---

### S-03 Page 3 功能行垂直间距偏紧（20pt vs 32pt）
- **类别**：布局
- **严重程度**：P2（视觉瑕疵）
- **位置**：OnboardingView > Page 3 > 三行功能介绍之间的垂直间距
- **截图现状**：三行功能介绍间距为 `Spacing.xl`（20pt），三行之间紧凑，呼吸感不足
- **设计预期**：code.html L124 `flex flex-col gap-8`，Tailwind `gap-8` = 32px ≈ 32pt。对应 Token `Spacing.xxxl`（32pt），为功能行之间提供更充裕的视觉呼吸空间
- **修复方向**：将 `loginPage` 中功能区 `VStack(spacing: Spacing.xl)` 改为 `VStack(spacing: Spacing.xxxl)`
- **路由至**：swiftui-developer
- **代码提示**：`OnboardingView.swift` L101 `VStack(spacing: Spacing.xl)` → `VStack(spacing: Spacing.xxxl)`

---

### S-04 LoginView "欢迎使用球迹" 标题字号偏小（22pt vs 26pt）
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：LoginView > 标题区域
- **截图现状**：标题 "欢迎使用球迹" 使用 `btTitle`（22pt Bold Rounded），作为独立模态页的主标题，视觉权重略显不足
- **设计预期**：code.html L56 使用 `text-[26pt] font-bold`。26pt 介于 btTitle（22pt）与 btLargeTitle（34pt）之间，在 Sheet 上下文中更具视觉冲击力
- **修复方向**：可新增 `btTitle1 = Font.system(size: 26, weight: .bold, design: .rounded)` Token，或在此处特例使用 `Font.system(size: 26, weight: .bold, design: .rounded)` 并注释说明来源
- **路由至**：swiftui-developer
- **代码提示**：`LoginView.swift` L29 `.font(.btTitle)`；可能需同步更新 `Typography.swift`
- **备注**：与代码审查报告 U-07 为同一问题，此处从截图角度确认偏差在实机上可感知

---

### S-05 LoginView App 图标尺寸偏大（80pt vs 72pt）
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：LoginView > App 图标
- **截图现状**：绿色圆角方块图标为 80×80pt，圆角 18pt。在 Sheet 上下文中图标偏大，与标题文字的比例略失衡
- **设计预期**：code.html L53 定义 `w-[72pt] h-[72pt] rounded-[16pt]`。72pt 图标 + 16pt 圆角在 Sheet 中更紧凑协调
- **修复方向**：将 `appIcon` 尺寸从 80→72pt，圆角从 18→16pt
- **路由至**：swiftui-developer
- **代码提示**：`LoginView.swift` L92-93 `frame(width: 80, height: 80)` + `cornerRadius: 18`

---

### S-06 LoginView 协议链接颜色不一致（绿色 vs 灰色）
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：LoginView > 底部法律文案 > "用户协议" / "隐私政策" 链接
- **截图现状**：两个链接文字使用 `btPrimary`（#1A6B3C 绿色）+ 下划线，在浅色背景上较为醒目
- **设计预期**：code.html L86 使用 `text-[12pt] text-ios-gray` + `underline decoration-ios-border`。链接与周围正文同为灰色，仅靠下划线区分可点击性，视觉层级低于上方按钮。`ios-gray` = `rgba(60,60,67,0.6)` 对应 `btTextSecondary`
- **修复方向**：将链接文字颜色从 `.btPrimary` 改为 `.btTextSecondary`，保留 `.underline()` 装饰。或保持绿色（绿色更符合无障碍可点击标识），视为有意偏离并记录决策
- **路由至**：swiftui-developer
- **代码提示**：`LoginView.swift` L64-67, L72-74 `.foregroundStyle(.btPrimary)`

---

### S-07 LoginView 微信按钮图标为通用消息气泡
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：LoginView > 微信登录按钮 > 左侧图标
- **截图现状**：使用 SF Symbol `message.fill`（通用消息气泡图标），与微信品牌视觉无关联
- **设计预期**：设计稿 code.html L70 使用 Material Symbol `chat_bubble`（同为通用图标占位）。但参考应用训记（ref-screenshots 03-login-in-options.png）使用微信官方绿色气泡 Logo。用户在登录场景中期望看到官方品牌图标以建立信任
- **修复方向**：待微信 SDK 集成后（H-05），使用官方微信 Logo 资源替换 SF Symbol。当前阶段可在 Assets.xcassets 中预置一个 `wechat-logo` 图片资源（白色微信 Logo SVG），或使用微信品牌指南中的 SF Symbol 近似图标
- **路由至**：swiftui-developer（图标资源）/ devops-release（微信 SDK 集成）
- **代码提示**：`LoginView.swift` L132 `Image(systemName: "message.fill")`

---

### S-08 LoginView 三按钮高度 52pt vs 设计稿 50pt
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：LoginView > Apple / 微信 / 手机号三个按钮
- **截图现状**：三个按钮均为 `frame(height: 52)`，与 BTButtonStyle.primary 保持一致
- **设计预期**：code.html L62, L69, L74 均使用 `h-[50pt]`。2pt 差异在视觉上不显著，但三个按钮叠加后整体区域比设计稿高 6pt
- **修复方向**：考虑将此处按钮高度调整为 50pt 以匹配设计稿，或接受 2pt 差异以与 BTButton 系统保持一致。建议保持 52pt（系统一致性优先），记录为有意偏离
- **路由至**：swiftui-developer
- **代码提示**：`LoginView.swift` L121, L138, L150 `.frame(height: 52)`

---

### S-09 Page 3 "你的台球训练伙伴" 副标题字号微偏（16pt vs 17pt）
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：OnboardingView > Page 3 > "球迹" 标题下方副标题
- **截图现状**：副标题使用 `btCallout`（16pt regular），略小于设计意图
- **设计预期**：code.html L121 使用 `text-[17pt]`，对应 Token `btBody`（17pt regular）
- **修复方向**：将 `loginPage` 中 "你的台球训练伙伴" 的字体从 `.btCallout` 改为 `.btBody`
- **路由至**：swiftui-developer
- **代码提示**：`OnboardingView.swift` L97 `.font(.btCallout)` → `.font(.btBody)`

---

### S-10 Page 1-2 图标与文字区域垂直分布偏上，下方空间过大
- **类别**：布局
- **严重程度**：P2（视觉瑕疵）
- **位置**：OnboardingView > Page 1 / Page 2 > 整体内容垂直居中
- **截图现状**：图标圆 + 标题 + 副标题整体偏向屏幕上半部分（约 40% 位置），下方留有大量空白直到页面指示器区域。底部 "继续" 按钮和 "跳过" 链接与内容区之间有很大间隙
- **设计预期**：设计参考 ref-screenshots 01-onboarding-1.png 中训记的引导页将核心内容放在屏幕垂直居中偏下（约 50-60% 位置），文字与底部操作区之间的间隙更均匀。P2-04 设计稿仅提供 Page 3 布局，Pages 1-2 无专用设计稿，但垂直居中是引导页的通用最佳实践
- **修复方向**：调整 `featurePage` 中 Spacer 比例——将底部双 Spacer (`Spacer(); Spacer()`) 改为单个 Spacer 或使用 `Spacer().frame(minHeight:)` 控制底部最小间距，使内容区在 TabView 可视区域内更接近视觉居中
- **路由至**：swiftui-developer
- **代码提示**：`OnboardingView.swift` L52-78 `featurePage` 函数内 Spacer 布局

---

### S-11 系统权限弹窗遮挡引导页首屏内容
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：OnboardingView > Page 1 > 首次启动时
- **截图现状**：P2-04-01 截图显示 iOS "允许'球迹'使用无线数据？" 系统弹窗在 Page 1 内容上方弹出，完全遮挡了标题和副标题。用户首次体验被权限弹窗打断
- **设计预期**：参考训记（ref-screenshots 02-onboarding-2.png）在引导完成后的隐私协议页才触发通知权限弹窗。理想做法是将网络权限请求延迟到引导完成后或特定操作触发时，避免干扰首屏引导体验
- **修复方向**：此弹窗为 iOS 系统级行为（首次网络请求时自动触发），无法通过代码直接控制弹出时机。可考虑：(1) 确保 onboarding 期间不发起网络请求以延迟弹窗；(2) 在 App 初始化逻辑中将首次网络请求移到引导完成后。注意：此弹窗仅在中国区 iOS 设备首次安装时出现
- **路由至**：ios-architect
- **代码提示**：App 启动逻辑、网络初始化时机

---

### 审查通过项（与设计稿一致）

#### Onboarding Pages 1-2
- ✅ 背景色 btBG（#F2F2F7）与设计稿一致，强制 Light Mode（`.preferredColorScheme(.light)`）
- ✅ 图标圆背景 btPrimary.opacity(0.12) ≈ 设计稿 rgba(26,107,60,0.1)，视觉接近
- ✅ SF Symbol 选择正确：`figure.pool.swim`（动作库）、`angle`（角度训练）
- ✅ 页面指示器为胶囊形（活跃 24pt / 非活跃 8pt），btPrimary 色，交互正确
- ✅ "继续" 按钮使用 BTButtonStyle.primary，btPrimary 填充 + 白字
- ✅ "跳过" 文字使用 btTextSecondary 灰色，视觉层级低于主按钮（U-02 已修复）

#### Onboarding Page 3
- ✅ "球迹" 标题使用 btLargeTitle（34pt Bold Rounded），与设计稿 `text-[34pt]` 一致
- ✅ 功能行标题 btHeadline（17pt Semibold）匹配设计稿 `text-[17pt] font-semibold`
- ✅ 功能行图标圆 48×48pt 匹配设计稿 `w-[48pt] h-[48pt]`
- ✅ 功能行图标-文字间距 Spacing.lg（16pt）匹配设计稿 `gap-4`（16px）
- ✅ "开始使用" 按钮 btPrimary 填充、"登录已有账号" 灰色文字，层级正确
- ✅ 三大功能文案与设计稿完全一致

#### LoginView
- ✅ App 图标使用 `flag.checkered` SF Symbol + btPrimary 背景，与设计稿 `sports_score` 旗帜图标风格一致
- ✅ 三按钮层级正确：Apple（黑色）> 微信（绿色）> 手机号（描边），符合 UI-IMPLEMENTATION-SPEC §七
- ✅ 三按钮圆角已统一为 BTRadius.md（12pt），与设计稿 `rounded-btn: 12pt` 一致（U-01 已修复）
- ✅ 按钮间距 Spacing.md（12pt）匹配设计稿 `gap-[12pt]`
- ✅ "暂不登录，匿名使用" 文案与设计稿一致
- ✅ 底部法律文案结构与设计稿一致，链接已有下划线装饰（U-03 已修复）
- ✅ WeChat 绿色 #07C160 与设计稿一致
- ✅ Apple 按钮遵循 HIG：Light 模式黑底白字

---

### 审查总结
- 截图数量：5 张（P2-04-01 ~ P2-04-04, P2-05-01）
- 设计参考：2 组 stitch（screen.png + code.html）+ 3 张 ref-screenshots
- 发现问题：11 项（P0: 0 / P1: 0 / P2: 11）
- 已确认修复（对比 UR-20260406-Onboarding.md）：U-01（按钮圆角）✅、U-02（跳过按钮颜色）✅、U-03（链接下划线）✅
- 总体评价：引导页和登录页整体结构、功能流程与设计稿高度一致。主要偏差集中在 Page 3 的 App Logo 造型（S-01）、字号/间距的微调（S-02~S-05, S-08~S-09）以及品牌图标细节（S-07）。所有问题均为 P2 级视觉打磨项，不影响功能使用。
- 建议下一步：
  1. **优先处理 S-01**（App Logo 重构），视觉差异最明显，直接影响品牌第一印象
  2. **批量处理 S-02/S-03/S-09**（字号 + 间距），均为 OnboardingView 内的单行修改
  3. **S-04/S-05** 可与 LoginView 其他调整合并处理
  4. **S-06** 建议团队讨论决定：绿色链接（更好的无障碍识别）vs 灰色链接（更贴合设计稿）
  5. **S-07** 待微信 SDK 集成（H-05）后一并替换为官方 Logo
  6. **S-08** 建议保持 52pt 不改（系统一致性优先），记录为有意偏离
  7. **S-10/S-11** 为低优先级优化项，可安排在后续打磨迭代中处理
