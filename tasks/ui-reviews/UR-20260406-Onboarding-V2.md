## UI V2 审查报告 — OnboardingView + LoginView（第二轮截图对照）
日期：2026-04-06

审查对象：引导页 + 登录选项页
截图来源：screenshot-v2/P2-04-01 ~ P2-04-08（8 张 V2 截图，含 2 次运行）
对比基线：UR-20260406-Onboarding-Screenshot.md（11 项）
设计参考：ui_design/tasks/P2-04/stitch_task_p2_04_02/screen.png + code.html

> 本报告为 **V2 Delta 审查**：逐条验证前轮 S-01 ~ S-11 修复情况，并记录新发现问题。LoginView 本轮未提供截图，S-04 ~ S-08 仅通过代码审查验证。

---

## 一、前轮问题追踪

| # | 原编号 | 问题摘要 | 原严重程度 | V2 状态 | 说明 |
|---|--------|---------|-----------|---------|------|
| 1 | S-01 | Page 3 App Logo 样式差异（灰圆+绿徽章 vs 台球造型） | P2 | ❌ 未修复 | `appLogo` 仍为 `btBGTertiary` 灰圆 + 绿色矩形 "QJ" 徽章（L172-190），未重构为设计稿的白色台球球体 |
| 2 | S-02 | Page 3 功能行副标题字号 13pt → 15pt | P2 | ✅ 已修复 | `OnboardingFeatureRow` L216 已从 `.btFootnote`(13pt) 改为 `.btSubheadline`(15pt)；V2 截图中副标题与标题层级差明显缩小，视觉匹配设计稿 |
| 3 | S-03 | Page 3 功能行垂直间距 20pt → 32pt | P2 | ✅ 已修复 | `loginPage` L101 已从 `Spacing.xl`(20pt) 改为 `Spacing.xxxl`(32pt)；V2 截图中三行功能介绍呼吸感充裕，与设计稿 `gap-8` 一致 |
| 4 | S-04 | LoginView 标题字号 22pt → 26pt | P2 | ✅ 已修复（代码确认） | `LoginView` L29 已改为 `.system(size: 26, weight: .bold, design: .rounded)`；本轮无 LoginView 截图，后续截图轮次可视觉验证 |
| 5 | S-05 | LoginView 图标尺寸 80pt → 72pt | P2 | ✅ 已修复（代码确认） | `LoginView` L92-94 已改为 `cornerRadius: 16` + `frame(width: 72, height: 72)`，完全匹配设计稿 |
| 6 | S-06 | LoginView 协议链接颜色（绿色 vs 灰色） | P2 | ❌ 未修复（有意保留） | L66/73 仍使用 `.btPrimary`。绿色链接更符合无障碍可点击识别标准（WCAG），建议记为有意偏离设计稿 |
| 7 | S-07 | LoginView 微信按钮图标为通用气泡 | P2 | ❌ 未修复（待 H-05） | L132 仍使用 `message.fill`；需待微信 SDK 集成（H-05）后替换为官方 Logo |
| 8 | S-08 | LoginView 按钮高度 52pt vs 设计稿 50pt | P2 | ❌ 未修复（有意保留） | L121/138/152 仍为 52pt；与 BTButtonStyle.primary 系统保持一致，2pt 差异不影响视觉，记为有意偏离 |
| 9 | S-09 | Page 3 "你的台球训练伙伴" 副标题 16pt → 17pt | P2 | ✅ 已修复 | L96 已从 `.btCallout`(16pt) 改为 `.btBody`(17pt)；V2 截图中副标题与 "球迹" 标题比例更协调 |
| 10 | S-10 | Page 1-2 内容偏上、下方空间过大 | P2 | ❌ 未修复 | `featurePage` L53+76-77 仍为 1:2 Spacer 比例（顶部 1 个、底部 2 个），V2 截图确认图标+文字仍位于屏幕约 35-40% 处，底部空白显著 |
| 11 | S-11 | 系统权限弹窗遮挡首屏 | P2 | ❌ 未修复（系统行为） | P2-04-01 与 P2-04-05 两次运行均出现 iOS "允许使用无线数据" 弹窗。此为系统级行为，仅在中国区首次安装触发，非代码可直接控制 |

---

## 二、新发现问题

### N-01 "跳过" / "登录已有账号" 文字字号偏大（16pt vs 15pt）
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：OnboardingView > Page 1-2 "跳过" 按钮、Page 3 "登录已有账号" 按钮
- **截图现状**：两处次要操作文字使用 `btCallout`（16pt regular），视觉上与主按钮的层级差略小
- **设计预期**：code.html L165 明确使用 `text-[15pt]`，对应 Token `btSubheadline`（15pt regular）。15pt 与 17pt 主按钮之间形成更清晰的视觉层级
- **修复方向**：将 `OnboardingView` 底部栏中 "跳过" 和 "登录已有账号" 按钮的 `.font(.btCallout)` 改为 `.font(.btSubheadline)`
- **路由至**：swiftui-developer
- **代码提示**：`OnboardingView.swift` L140 和 L152 `.font(.btCallout)` → `.font(.btSubheadline)`

---

### N-02 "开始使用" 按钮与 "登录已有账号" 间距偏小（12pt vs 18pt）
- **类别**：布局
- **严重程度**：P2（视觉瑕疵）
- **位置**：OnboardingView > Page 3 > "开始使用" 按钮与 "登录已有账号" 之间
- **截图现状**：底部栏 `VStack(spacing: Spacing.md)` 使 两个元素间距为 12pt，"登录已有账号" 紧贴主按钮下方
- **设计预期**：code.html L165 使用 `mt-[18pt]`，即 "登录已有账号" 距主按钮 18pt。更大间距有助于避免误触次要操作
- **修复方向**：为 "登录已有账号" 按钮单独添加 `.padding(.top, Spacing.sm)`（+6pt）使总间距达到 ~18pt，或将底部栏 VStack spacing 从 `Spacing.md` 调整为自定义值
- **路由至**：swiftui-developer
- **代码提示**：`OnboardingView.swift` L127 `VStack(spacing: Spacing.md)` 或 L148/152 添加额外 top padding

---

### 审查通过项（V2 确认一致）

#### Onboarding Pages 1-2（两次运行一致）
- ✅ 背景色 btBG（#F2F2F7），强制 Light Mode 生效
- ✅ 图标圆 120pt + btPrimary.opacity(0.12) 淡绿底色
- ✅ SF Symbol 正确：`figure.pool.swim`（动作库）、`angle`（角度训练）
- ✅ 标题 btTitle2（20pt semibold）、副标题 btCallout（16pt）+ btTextSecondary
- ✅ 页面指示器胶囊形（活跃 24pt / 非活跃 8pt），btPrimary 色
- ✅ "继续" 按钮使用 BTButtonStyle.primary，btPrimary 填充 + 白字
- ✅ "跳过" 使用 btTextSecondary 灰色，层级低于主按钮

#### Onboarding Page 3（两次运行一致）
- ✅ "球迹" 标题 btLargeTitle（34pt Bold Rounded）✓ 匹配设计稿
- ✅ "你的台球训练伙伴" 已改为 btBody（17pt）✓ 匹配设计稿 `text-[17pt]`（S-09 修复）
- ✅ 功能行标题 btHeadline（17pt Semibold）✓
- ✅ 功能行副标题 btSubheadline（15pt）✓ 匹配设计稿 `text-[15pt]`（S-02 修复）
- ✅ 功能行间距 Spacing.xxxl（32pt）✓ 匹配设计稿 `gap-8`（S-03 修复）
- ✅ 功能行图标圆 48×48pt ✓
- ✅ 功能行图标-文字间距 Spacing.lg（16pt）✓
- ✅ "开始使用" 按钮 btPrimary 填充，视觉正确
- ✅ 三大功能文案与设计稿完全一致
- ✅ 两次运行渲染完全一致，无闪烁/布局跳变

#### LoginView（代码确认，本轮无截图）
- ✅ 标题已改为 26pt Bold Rounded（S-04 修复）
- ✅ 图标已改为 72×72pt + 16pt 圆角（S-05 修复）
- ✅ 三按钮圆角 BTRadius.md（12pt）✓
- ✅ 按钮间距 Spacing.md（12pt）✓
- ✅ WeChat 绿色 #07C160 ✓

---

### 审查总结
- 前轮 11 项：**已修复 5** / 有意保留 3 / 未修复 2 / 系统行为 1
  - ✅ 已修复：S-02（副标题字号）、S-03（功能行间距）、S-04（LoginView 标题）、S-05（LoginView 图标）、S-09（Page 3 副标题）
  - ❌ 有意保留：S-06（链接绿色，无障碍优先）、S-07（微信图标，待 H-05）、S-08（按钮 52pt，系统一致性）
  - ❌ 仍需处理：**S-01**（App Logo 造型）、**S-10**（Page 1-2 垂直居中）
  - ⏭ 系统行为：S-11（权限弹窗）
- 新发现：**2 项**（P0: 0 / P1: 0 / P2: 2）
- 总体评价：**Page 3 功能区域明显改善**（字号、间距三项全部修复），LoginView 关键尺寸（标题 26pt、图标 72pt）已从代码确认修复。剩余最显著的视觉偏差为 **S-01 App Logo 造型**（灰圆+徽章 vs 台球球体），直接影响品牌第一印象。
- 建议下一步：
  1. **优先处理 S-01**（App Logo 台球造型重构）— 对品牌感知影响最大
  2. **处理 S-10**（Page 1-2 垂直居中优化）— 改善引导页整体平衡感
  3. **批量修复 N-01 + N-02**（次要按钮字号 + 间距）— 各一行改动
  4. 下一轮建议提供 **LoginView 截图** 以视觉验证 S-04/S-05 修复效果
