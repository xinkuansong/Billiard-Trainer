## UI 审查报告（V2 Delta）— ProfileView + SettingsView（游客模式 Light）
日期：2026-04-06

审查对象：我的 Tab（游客模式 + 偏好设置页）
截图来源：P2-03-01 ~ P2-03-04（4 张 V2 实机截图）
设计参考：P2-03 GuestProfile_02 / UserProfile_02, ref-screenshots/07-profile
前次报告：`UR-20260406-Profile-Screenshot.md`（S-01 ~ S-07）

---

### 前次问题追踪

| ID | 严重程度 | V2 状态 | 说明 |
|----|---------|---------|------|
| S-01 | P1 | ✅ 已修复 | Pro 推广卡片已改为固定深色背景（`proCardDarkBG ≈ #1C1C1E`），与设计稿一致 |
| S-02 | P1 | ✅ 已修复 | 副标题「让你的训练更高效」在深色背景上清晰可见（`white.opacity(0.7)`） |
| S-03 | P2 | ❌ 未修复 | 标题「我的」仍为自定义 btTitle（22pt），未使用系统 Large Title（34pt）。代码仍用 `.toolbar(.hidden, for: .navigationBar)` + 手动 HStack 渲染 |
| S-04 | P2 | ⏸️ 暂缓 | 标题颜色仍为 `.btText`（黑色），设计稿游客态用 `#005129` 绿色。建议统一用黑色更符合 HIG，可暂缓 |
| S-05 | P2 | ✅ 已修复 | 「升级 Pro」文字已改为 `.btAccent` 金色，与设计稿一致 |
| S-06 | P2 | ❌ 未修复 | 偏好设置页仍显示自定义圆形返回按钮（截图 P2-03-04 可见），非系统默认 |
| S-07 | P2 | ❌ 未修复 | 游客模式下「个人信息」显示「中式台球」、「训练目标」显示「每周 3 天」（UserPreferences 默认值），设计稿预期为「未设置」 |

**小结**：7 项中 3 项已修复（含 2 个 P1），3 项仍 Open，1 项暂缓。P1 问题已全部清除。

---

### 新发现问题

### N-01 Pro 卡片图标与设计稿不一致（star.fill vs workspace_premium）
- **类别**：产品规格 / 视觉打磨
- **严重程度**：P2
- **位置**：我的 Tab > 游客模式 > Pro 推广卡片 > 右侧图标
- **现状**：使用 SF Symbol `star.fill`（28pt btStatNumber），放置在金色半透明圆底上。
- **预期**：设计稿（guestprofile_02 code.html L151）使用 Material `workspace_premium`（奖章/勋章）图标，52px，金色填充，传达更明确的「高级会员」含义。
- **修复方向**：将 `star.fill` 替换为更接近奖章/皇冠的 SF Symbol，例如 `medal.fill` 或 `trophy.fill`；或保留 `crown.fill` 与订阅管理行图标一致。金色半透明圆底保留即可。
- **路由至**：swiftui-developer
- **代码提示**：`ProfileView.swift` L280–L283 `Image(systemName: "star.fill")`

---

### N-02 导航路由错误：「个人信息」与「训练目标」均指向 SettingsView
- **类别**：产品规格
- **严重程度**：P1
- **位置**：我的 Tab > 主菜单组 > 「个人信息」行 / 「训练目标」行
- **现状**：代码中三个菜单项均使用 `NavigationLink(value: "settings")`，点击后全部跳转至 `SettingsView`。`PersonalInfoView` 和 `TrainingGoalView` 已实现但无法通过 ProfileView 导航到达。
- **预期**：
  - 「个人信息」→ `PersonalInfoView`（球种、水平、球龄、账号绑定）
  - 「训练目标」→ `TrainingGoalView`（进度环、每周天数、时长、提醒）
  - 「偏好设置」→ `SettingsView`（外观、数据管理、账号安全）
- **修复方向**：
  - 「个人信息」NavigationLink value 改为 `"personalInfo"`
  - 「训练目标」NavigationLink value 改为 `"trainingGoal"`
  - 仅「偏好设置」保留 `"settings"`
- **路由至**：swiftui-developer
- **代码提示**：`ProfileView.swift` L308 `NavigationLink(value: "settings")` → `"personalInfo"`；L321 `NavigationLink(value: "settings")` → `"trainingGoal"`。导航目标 `case "personalInfo": PersonalInfoView()` 和 `case "trainingGoal": TrainingGoalView()` 在 L62–L65 已定义，只需修改 NavigationLink value。

---

### N-03 「关于与反馈」行缺少导航动作（显示 chevron 但不可点击）
- **类别**：产品规格 / HIG
- **严重程度**：P2
- **位置**：我的 Tab > 次级菜单组 > 「关于与反馈」行
- **现状**：ProfileMenuRow 渲染了 chevron.right 箭头（暗示可点击），但该行未包裹在 NavigationLink 或 Button 中。点击无反应。`AboutView` 已实现，导航目标 `case "about": AboutView()` 已在 L71 定义，但无入口引用。
- **预期**：点击「关于与反馈」应导航至 AboutView（应用 Logo、版本号、意见反馈、给个好评、用户协议、隐私政策）。
- **修复方向**：将「关于与反馈」ProfileMenuRow 包裹在 `NavigationLink(value: "about")` 中。
- **路由至**：swiftui-developer
- **代码提示**：`ProfileView.swift` L398–L403，需包裹为 `NavigationLink(value: "about") { ... }.buttonStyle(.plain)`

---

### N-04 偏好设置页（截图 P2-03-04）内容不完整
- **类别**：产品规格 / 布局
- **严重程度**：P2
- **位置**：偏好设置页
- **现状**：截图 P2-03-04 显示「偏好设置」页面仅包含两个区块：「主打球种」pill 选择器 + 「每周训练目标」天数列表。页面下半部分为大面积空白。此内容实际上是 PersonalInfoView 和 TrainingGoalView 的子集，与 SettingsView 代码中的「外观」「数据管理」「账号安全」section 不一致。
- **预期**：
  - 若为合并偏好页：应包含外观切换（跟随系统/浅色/深色）、球种、每周天数、每次时长目标、训练提醒开关等完整偏好项。
  - 若保持分离架构：应修复 N-02 路由，使三个页面各自独立可达。
- **修复方向**：修复 N-02 后此问题可能自动消解——「偏好设置」应显示 SettingsView（含外观/数据管理），「个人信息」和「训练目标」各跳转专属页面。若截图所示为旧版本 build，修复路由后需重新截图验证。
- **路由至**：swiftui-developer / ios-architect
- **代码提示**：`SettingsView.swift` 当前代码含 `appearanceSection`（L57–L69）、`dataSection`（L73–L94）、`accountSection`（L98–L113），与截图显示内容不符。需排查实际运行时加载的是否为正确的 SettingsView。

---

### N-05 版本号「版本 1.0.0」在最大滚动状态下不可见
- **类别**：布局
- **严重程度**：P2
- **位置**：我的 Tab > 页面底部
- **现状**：截图 P2-03-02（已滚动至底部）显示「登录 / 注册」按钮紧贴 Tab Bar 上方，版本号文字和「跳过，以游客身份继续」按钮均不可见。
- **预期**：设计稿（userprofile_02 L245）在底部显示「版本 1.0.0」。代码中 `Text("版本 1.0.0")` 位于 `guestBottomActions` 之后，带 `.padding(.bottom, Spacing.xxxl)`（32pt）。
- **修复方向**：增加底部安全区 padding，确保「跳过」按钮和版本号在 Tab Bar 上方可见。建议将 `.padding(.bottom, Spacing.xxxl)` 改为 `.padding(.bottom, Spacing.xxxxl)` (48pt) 或使用 `.safeAreaInset(edge: .bottom)` 计算实际 Tab Bar 高度。
- **路由至**：swiftui-developer
- **代码提示**：`ProfileView.swift` L43–L47 版本号文字、L441–L451 `guestBottomActions`。底部 padding 在 VStack 最后一个元素上。

---

### 审查总结
- 截图数量：4 张（3 张 Profile 主页 + 1 张偏好设置）
- 前次问题：3/7 已修复（S-01 ✅、S-02 ✅、S-05 ✅）、3 项 Open（S-03、S-06、S-07）、1 项暂缓（S-04）
- 新发现问题：5 项（P0: 0 / P1: 1 / P2: 4）
- 总遗留问题：8 项（P1: 1 / P2: 7）

### 总体评价
V2 版本成功解决了最关键的 Pro 卡片视觉问题（S-01/S-02），暗色背景 + 白色文字 + 金色强调的层次感显著提升，与设计稿高级质感一致。「升级 Pro」金色文字（S-05）也已到位。整体页面结构、菜单分组、图标配色、间距质量保持良好。

**最突出的新问题是 N-02 导航路由错误**——三个菜单项全部指向同一个 SettingsView，导致 PersonalInfoView 和 TrainingGoalView 无法访问。这是一个 P1 级功能缺陷，直接影响用户修改个人信息和训练目标的能力。

### 建议下一步
1. **优先修复 N-02**（导航路由）：简单修改两个 NavigationLink value 即可，影响最大。
2. **顺带修复 N-03**（关于与反馈）：一行 NavigationLink 包裹。
3. **S-07**（未设置 vs 默认值）：在 UserPreferences 中添加 hasSet 标志，简单但需设计确认。
4. **N-05**（底部 padding）：调整底部安全区间距。
5. **S-03**（Large Title）和 **S-06**（返回按钮）建议在全局导航治理时统一处理。
6. **N-01**（图标）和 **N-04**（设置页内容）为打磨项，可在后续迭代中处理。
