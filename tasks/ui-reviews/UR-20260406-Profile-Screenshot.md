## UI 截图审查报告 — ProfileView + SettingsView（截图对照）
日期：2026-04-06

审查对象：我的 Tab（游客模式 + 设置页）
截图来源：P2-03-01 ~ P2-03-03（3 张实机截图）
设计参考：P2-03 GuestProfile + UserProfile, ref-screenshots/07-profile

---

### S-01 Pro 推广卡片背景与设计稿严重不符（暗色 → 亮色）
- **类别**：Design Token / 产品规格
- **严重程度**：P1
- **位置**：我的 Tab > 游客模式 > Pro 推广卡片
- **截图现状**：Pro 卡片使用 btBGSecondary 白色背景，整体为浅色卡片，「解锁球迹 Pro」和「了解更多」以 btAccent 金色文字显示，星形图标在金色半透明圆中。
- **设计预期**：设计稿（guestprofile_02/screen.png + code.html L140）Pro 卡片使用 `#1C1C1E` 深色背景，标题为白色粗体文字，「了解更多」为金色，右侧为金色 workspace_premium 图标。整体营造高级暗色卡片质感。
- **修复方向**：将 Pro 卡片背景改为固定深色（Light/Dark 均为 `#1C1C1E` 或 btBGSecondary 的 Dark 变体），标题改为白色，保持金色强调色。可添加设计稿中的模糊光晕装饰（`blur-3xl` 渐变圆）。
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/Profile/Views/ProfileView.swift` L250–L291 `proPromotionCard`，当前 `.background(Color.btBGSecondary)` 应改为固定深色。

---

### S-02 Pro 卡片副标题「让你的训练更高效」在浅色背景上不可见
- **类别**：Design Token
- **严重程度**：P1
- **位置**：我的 Tab > 游客模式 > Pro 推广卡片 > 副标题行
- **截图现状**：截图中仅可见「解锁球迹 Pro」和「了解更多 >」，副标题「让你的训练更高效」完全不可见。
- **设计预期**：设计稿显示副标题「让你的训练更高效」位于标题下方，使用 `text-white/70` 白色 70% 透明度（在深色卡片背景上清晰可读）。
- **修复方向**：修复 S-01 后本问题自动解决。当前代码 `proCardSubtitle = Color.white.opacity(0.7)` 在白色 btBGSecondary 上几乎不可见——若保留浅色卡片，需改为 `.btTextSecondary`；若改回深色背景，保留白色即可。
- **路由至**：swiftui-developer
- **代码提示**：`ProfileView.swift` L15 `proCardSubtitle` 定义、L258 使用处。

---

### S-03 页面标题「我的」未使用系统 Large Title，字号偏小
- **类别**：HIG / 布局
- **严重程度**：P2
- **位置**：我的 Tab > 顶部标题
- **截图现状**：标题「我的」使用 btTitle（22pt bold rounded），通过隐藏系统导航栏 + 手动 HStack 渲染。无 Large Title → Inline 滚动收缩动画。
- **设计预期**：设计稿 userprofile_02 标题为 34px bold（`sf-rounded text-[34px]`），等同于 iOS Large Title 样式。iOS HIG 建议根 Tab 页面使用 NavigationStack Large Title。
- **修复方向**：移除 `.toolbar(.hidden, for: .navigationBar)`，改用系统 `NavigationStack` 的 `.navigationTitle("我的")` + `.navigationBarTitleDisplayMode(.large)`。或将自定义标题字号升至 btLargeTitle（34pt）。
- **路由至**：swiftui-developer
- **代码提示**：`ProfileView.swift` L59 `.toolbar(.hidden)` 与 L24–L29 手动标题。

---

### S-04 页面标题「我的」颜色不匹配设计稿（游客态）
- **类别**：Design Token
- **严重程度**：P2
- **位置**：我的 Tab > 顶部标题
- **截图现状**：标题使用 `.btText`（Light: #000000 黑色）。
- **设计预期**：游客设计稿（guestprofile_02 code.html L114）标题使用 `text-[#005129]`（btPrimary 绿色）。注：登录态设计稿使用 `text-on-surface`（黑色），两态存在差异。
- **修复方向**：若决定游客/登录统一使用黑色标题则忽略（更符合 HIG）。若遵循游客设计稿，可在游客态将标题改为 `.btPrimary`。建议与设计师确认统一方案。
- **路由至**：swiftui-developer
- **代码提示**：`ProfileView.swift` L27 `.foregroundStyle(.btText)`。

---

### S-05 「订阅管理」行「升级 Pro」文字颜色应为金色
- **类别**：Design Token
- **严重程度**：P2
- **位置**：我的 Tab > 主菜单组 > 订阅管理行 > 详情文字
- **截图现状**：非 Premium 状态下「升级 Pro」文字使用 `.btPrimary`（绿色 #1A6B3C）。
- **设计预期**：设计稿（guestprofile_02 code.html L191）使用 `text-[#D4941A] font-medium`，即 btAccent 金色，与订阅/Pro 品牌色一致。
- **修复方向**：将非 Premium 状态的 detailColor 从 `.btPrimary` 改为 `.btAccent`。
- **路由至**：swiftui-developer
- **代码提示**：`ProfileView.swift` L342 `detailColor: subscriptionManager.isPremium ? .btTextSecondary : .btPrimary` → 将 `.btPrimary` 改为 `.btAccent`。

---

### S-06 偏好设置页使用自定义圆形返回按钮，不符合 HIG
- **类别**：HIG
- **严重程度**：P2
- **位置**：偏好设置 > 导航栏 > 返回按钮
- **截图现状**：返回按钮为一个带描边的圆形容器内嵌 `<` 箭头，非系统原生样式。
- **设计预期**：iOS HIG 要求使用系统默认返回按钮（btPrimary 色 chevron.left + 上级页面标题或 "返回"），不自定义返回按钮形状。设计系统规范（SKILL.md §十）也明确「返回按钮：系统默认（btPrimary 色），不自定义文字」。
- **修复方向**：检查是否有全局 NavigationBar Appearance 或自定义 toolbar item 覆盖了系统返回按钮。确保 SettingsView push 时使用系统默认返回按钮。
- **路由至**：swiftui-developer / ios-architect
- **代码提示**：`SettingsView.swift` L64–L66 当前仅设置 `.navigationTitle` 和 `.inline` 显示模式，未自定义返回按钮——可能是全局 NavigationBar 主题或 ProfileView 的 `.toolbar(.hidden)` 导致系统无法正确显示标准返回按钮。需检查 `AppRouter` 或全局 appearance 配置。

---

### S-07 游客模式「个人信息」与「训练目标」显示默认值而非「未设置」
- **类别**：产品规格
- **严重程度**：P2
- **位置**：我的 Tab > 主菜单组 > 个人信息 / 训练目标行
- **截图现状**：游客模式下「个人信息」显示「中式台球」，「训练目标」显示「每周 3 天」（UserPreferences 默认值）。
- **设计预期**：游客设计稿（guestprofile_02 code.html L171, L181）两行均显示「未设置」（`text-black/40`），提示用户尚未配置。
- **修复方向**：在 UserPreferences 中添加 `hasSetSport` / `hasSetGoal` 布尔标志，初始为 false。仅在用户主动选择后标记为 true。ProfileMenuRow 在标志为 false 时显示「未设置」而非默认值。
- **路由至**：swiftui-developer / data-engineer
- **代码提示**：`SettingsView.swift` UserPreferences 类（L22–L42）需增加 hasSet 判断逻辑；`ProfileView.swift` L315 `prefs.sportSummary` 与 L328 `prefs.goalSummary` 需条件判断。

---

### 审查总结
- 截图数量：3 张
- 发现问题：7 项（P0: 0 / P1: 2 / P2: 5）
- 总体评价：Profile 页面整体结构与设计稿吻合度较高，菜单分组、图标配色、间距等基本到位。**最突出的问题是 Pro 推广卡片丢失了设计稿的深色高级质感**，导致副标题不可见且视觉层次感下降。其余为标题样式、细节色值和 HIG 合规性问题。Settings 偏好设置页简洁实用，但返回按钮不符合系统规范。
- 建议下一步：
  1. **优先修复 S-01 + S-02**（Pro 卡片背景与副标题），直接影响产品高级感和文字可读性。
  2. S-05（升级 Pro 颜色）为简单单行修改，可顺带完成。
  3. S-03（Large Title）需评估是否重构 NavigationStack 结构，影响范围较大，可后续统一处理。
  4. S-06（返回按钮）需排查全局导航配置，建议在统一导航治理时一并解决。
  5. S-07（未设置 vs 默认值）需与产品确认行为预期。
