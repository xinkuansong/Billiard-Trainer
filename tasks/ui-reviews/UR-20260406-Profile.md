## UI 审查报告 — ProfileView + SettingsView + FavoriteDrillsView（Light & Dark 代码审查）

日期：2026-04-06
审查方式：代码对照 stitch 设计稿（screen.png + code.html）+ ref-screenshots + UI-IMPLEMENTATION-SPEC.md
审查文件：`ProfileView.swift`（530 行）· `SettingsView.swift`（171 行）· `FavoriteDrillsView.swift`（78 行）

---

### U-01 Pro 会员 Badge 配色使用 btPrimary 绿色，设计稿为金色渐变

- **类别**：Design Token / 产品规格
- **严重程度**：P1（功能缺陷）
- **位置**：我的 > ProfileView > loggedInHeader > Pro 会员 Badge
- **现状**：Badge 文字使用 `.btPrimary`（绿色），背景使用 `Color.btPrimary.opacity(0.12)`（浅绿），整体呈绿色调
- **预期**：stitch `code.html` 中 Pro Badge 使用 `pro-gradient`（`linear-gradient(135deg, #D4941A 0%, #FCB73F 100%)`）+ 白字，即 btAccent 金色渐变。stitch 截图也清晰展示金色 Badge
- **修复方向**：Badge 背景改为 btAccent 金色渐变（或简化为 `btAccent.opacity(0.15)` 底 + `btAccent` 文字，与 BTPremiumLock PRO 徽章体系一致），文字改为白色或 btAccent
- **路由至**：swiftui-developer
- **代码提示**：`ProfileView.swift` L126–L140 `loggedInHeader` Pro 区域

---

### U-02 月度概览统计数字颜色应使用品牌色强调

- **类别**：Design Token
- **严重程度**：P1（视觉与设计稿不符，信息层级偏差）
- **位置**：我的 > ProfileView > monthlyOverview > statColumn
- **现状**：所有统计数字（练习天数、训练时长、连续打卡）统一使用 `.btText`（黑/白色）
- **预期**：stitch `code.html` 中练习天数和训练时长使用 `text-primary`（btPrimary 绿色），连续打卡使用 `text-secondary`（btAccent 金色 `#805600`）。数据应以品牌色为主角（SKILL.md §一：数据即主角）
- **修复方向**：前两个指标 `.foregroundStyle(.btPrimary)`，连续打卡 `.foregroundStyle(.btAccent)`
- **路由至**：swiftui-developer
- **代码提示**：`ProfileView.swift` L173–L183 `statColumn` 函数

---

### U-03 Pro 推广卡背景使用硬编码 RGB 值

- **类别**：Design Token / Dark Mode
- **严重程度**：P1（违反 Token 规则，Dark Mode 无法自动适配）
- **位置**：我的 > ProfileView（访客）> proPromotionCard
- **现状**：背景使用 `LinearGradient(colors: [Color(red: 0.1, green: 0.22, blue: 0.15), Color(red: 0.08, green: 0.16, blue: 0.12)])`（硬编码深绿渐变）
- **预期**：stitch `code.html` 使用 `bg-[#1C1C1E]`（纯暗灰色背景）。所有颜色应使用 Token。设计系统 SKILL.md §二规则：「禁止在代码中硬编码 hex 值」
- **修复方向**：方案 A — 改用固定深色背景 `Color(uiColor: UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1))` 并注册为资产 Token；方案 B — 使用 `Color(.systemBackground).colorInvert()` 等语义手段。建议参照 stitch 使用类似 `#1C1C1E` 的暗色卡片底色
- **路由至**：swiftui-developer
- **代码提示**：`ProfileView.swift` L274–L279 `proPromotionCard` 背景区域

---

### U-04 FavoriteDrillsView 使用 .large 标题模式，push 子页面应为 .inline

- **类别**：HIG / 产品规格
- **严重程度**：P1（与导航规范不一致）
- **位置**：我的 > 收藏夹 > FavoriteDrillsView
- **现状**：`.navigationBarTitleDisplayMode(.large)` — 大标题模式
- **预期**：UI-IMPLEMENTATION-SPEC.md §四导航模式表：push 子页面使用「返回箭头 + 17pt Semibold 居中标题 + 无 Tab」。FavoriteDrills 明确列在 push 子页面清单中，应使用 `.inline`
- **修复方向**：改为 `.navigationBarTitleDisplayMode(.inline)`
- **路由至**：swiftui-developer
- **代码提示**：`FavoriteDrillsView.swift` L42

---

### U-05 退出登录按钮字体应为 Semibold

- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：我的 > ProfileView（已登录）> logoutButton
- **现状**：使用 `.btBody`（17pt Regular）
- **预期**：stitch `code.html` 中退出登录为 `text-[17px] font-semibold text-[#C62828]`，即 17pt Semibold。颜色已正确使用 btDestructive（L-6 修正 ✅），但字重偏轻
- **修复方向**：改为 `.btHeadline`（17pt Semibold）或 `.btBody.weight(.semibold)`
- **路由至**：swiftui-developer
- **代码提示**：`ProfileView.swift` L414

---

### U-06 Pro 推广卡副标题硬编码 `.white.opacity(0.7)`

- **类别**：Dark Mode / Design Token
- **严重程度**：P2（违反 Token 规则，但固定深色卡片上下文可接受）
- **位置**：我的 > ProfileView（访客）> proPromotionCard > 副标题
- **现状**：`foregroundStyle(.white.opacity(0.7))` — 硬编码白色
- **预期**：设计系统 SKILL.md §十五 Dark Mode 检查清单：「无硬编码 hex / `.white` / `.black`」。由于卡片背景固定为深色，白字在 Light/Dark 下均正确渲染，但违反规则
- **修复方向**：若卡片背景注册为 Token 后，可使用 `btText` 反色逻辑；或作为例外标注。最小修复：提取为具名常量（如 `proCardSubtitle`）并在注释中说明固定深色背景例外
- **路由至**：swiftui-developer
- **代码提示**：`ProfileView.swift` L249

---

### U-07 月度概览缺少三列之间的竖分隔线

- **类别**：布局 / 视觉打磨
- **严重程度**：P2（视觉瑕疵）
- **位置**：我的 > ProfileView（已登录）> monthlyOverview
- **现状**：三列统计数据之间仅用 `Spacer()` 分隔，无视觉分隔线
- **预期**：stitch `code.html` 中在三列之间有 `w-[0.5px] h-8 bg-surface-container-highest` 竖线分隔符，stitch 截图也可见淡色竖线
- **修复方向**：在三列之间添加 `Divider().frame(height: 32)` 或等效的 0.5pt 竖线，颜色使用 `btSeparator`
- **路由至**：swiftui-developer
- **代码提示**：`ProfileView.swift` L160–L166 `monthlyOverview` HStack

---

### U-08 「关于与反馈」菜单图标颜色应为紫色

- **类别**：Design Token / 视觉打磨
- **严重程度**：P2（视觉瑕疵）
- **位置**：我的 > ProfileView > secondaryMenuGroup > 关于与反馈 行
- **现状**：图标底色 `Color.blue.opacity(0.12)` + 图标色 `.blue`（蓝色）
- **预期**：stitch `code.html` 中「关于与反馈」使用 `bg-purple-100` + `text-purple-600`（紫色）。两版 stitch（已登录 + 访客）均为紫色
- **修复方向**：改为 `Color.purple.opacity(0.12)` + `.purple`
- **路由至**：swiftui-developer
- **代码提示**：`ProfileView.swift` L396–L401 关于与反馈 `ProfileMenuRow`

---

### U-09 菜单行标题字号为 17pt，设计稿为 16pt

- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：我的 > ProfileView > ProfileMenuRow > title
- **现状**：使用 `.btBody`（17pt Regular）
- **预期**：两版 stitch `code.html` 中菜单行标题均为 `text-[16px]`，对应 `btCallout`（16pt Regular）
- **修复方向**：ProfileMenuRow 的 `title` 字体从 `.btBody` 改为 `.btCallout`
- **路由至**：swiftui-developer
- **代码提示**：`ProfileView.swift` L475 ProfileMenuRow body

---

### U-10 三个菜单项（个人信息/训练目标/偏好设置）路由至同一 SettingsView

- **类别**：产品规格 / 布局
- **严重程度**：P2（UX 混淆）
- **位置**：我的 > ProfileView > primaryMenuGroup / secondaryMenuGroup
- **现状**：「个人信息」「训练目标」「偏好设置」三个 NavigationLink 均指向 `value: "settings"`，导航至同一个 SettingsView（标题为"偏好设置"）。用户点击「个人信息」后看到"偏好设置"标题，预期不一致
- **预期**：stitch 设计中这些是独立入口，虽然 MVP 阶段可合并，但至少导航标题应上下文相关
- **修复方向**：方案 A（推荐）— 传递参数区分来源，SettingsView 根据来源显示对应标题和自动滚动到对应 section；方案 B — 至少在 SettingsView 中将两个 section 组织得更清晰，使「个人信息」→ sport section、「训练目标」→ goal section 的关联直观
- **路由至**：ios-architect（导航路由设计）
- **代码提示**：`ProfileView.swift` L306–L328 NavigationLink；`SettingsView.swift` L50–L67

---

### U-11 月度概览 Section 标题字号/图标偏差

- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：我的 > ProfileView > monthlyOverview > 标题行
- **现状**：日历图标使用 `.btFootnote14`（14pt），文字使用 `.btSubheadlineMedium`（15pt Medium）
- **预期**：stitch `code.html` 标题行为 `text-[13px] font-semibold`（13pt Semibold），图标为 16pt。对应 Token 应为 `.btFootnote`（13pt）配 `.fontWeight(.semibold)`
- **修复方向**：标题文字改为 `.btFootnote.weight(.semibold)` + `.btTextSecondary`；图标保持 16pt 可不变
- **路由至**：swiftui-developer
- **代码提示**：`ProfileView.swift` L151–L158 monthlyOverview 标题 HStack

---

### U-12 访客 Warning 卡片使用 btWarning 橙色，设计稿为 btAccent 金色

- **类别**：Design Token / 视觉打磨
- **严重程度**：P2（色调偏差，不影响功能）
- **位置**：我的 > ProfileView（访客）> guestWarning
- **现状**：图标和背景使用 `.btWarning`（Light: `#E65100` 橙色），border 使用 `btWarning.opacity(0.3)`
- **预期**：stitch `code.html` 中使用 `text-[#D4941A]`（btAccent 金色）、`bg-[#D4941A]/10`、`border-[#D4941A]/10`。金色调与下方 Pro 推广卡视觉呼应。使用 btWarning 在语义上正确，但在视觉上与 stitch 不一致
- **修复方向**：改为 btAccent Token 以匹配 stitch 设计意图（金色警告比橙色更温和，符合"提醒登录"而非"危险"的语义场景）
- **路由至**：swiftui-developer
- **代码提示**：`ProfileView.swift` L221–L238 guestWarning

---

### U-13 SettingsView 偏好选项缺少分段胶囊组件

- **类别**：产品规格 / 视觉打磨
- **严重程度**：P2（视觉瑕疵，功能正常）
- **位置**：我的 > 偏好设置 > SettingsView
- **现状**：球种和训练目标使用简单的列表选择 + checkmark 样式
- **预期**：ref-screenshots 中训记的偏好设置使用 BTTogglePillGroup 胶囊选择样式（如"弹出/不弹出"胶囊对）。本项目已有 `BTTogglePillGroup` 组件可复用。球种三选一（中式台球/9球/两者）适合胶囊组
- **修复方向**：将球种选择改为 `BTTogglePillGroup`，每周目标可保留列表（选项多达 7 个，胶囊不适合）
- **路由至**：swiftui-developer
- **代码提示**：`SettingsView.swift` L71–L111 sportSection

---

### 审查总结

- 截图/代码数量：3 个文件，2 版 stitch 设计稿（已登录 + 访客），7 张 ref-screenshots
- 发现问题：13 项（P0: 0 / P1: 4 / P2: 9）
- 总体评价：ProfileView 整体结构与设计稿高度一致，已正确实施彩色圆底图标菜单、月度概览、访客警告与 Pro 推广卡等关键设计元素。已知偏差修正（L-6 退出登录色、Pro 标题金色、Dark 边框）均已正确应用。主要差距集中在颜色细节（Pro Badge 绿→金、统计数字强调色缺失）和少量硬编码值。SettingsView 和 FavoriteDrillsView 结构简洁，Token 使用基本规范。
- 建议下一步：优先修复 4 项 P1（U-01 ~ U-04），尤其是 Pro Badge 配色和统计数字强调色直接影响页面视觉层级感。P2 项可在后续打磨中批量处理。
