## UI 截图审查报告 — Dark Mode 全局（截图对照）
日期：2026-04-06

审查对象：Dark Mode 下 6 个核心页面
截图来源：E-01-01 ~ E-01-06（6 张实机截图）
设计参考：E-01 frame1~5 code.html + screen.png

**Dark Mode Token 参考（Asset Catalog 实际值）：**
| Token | Dark Hex |
|-------|----------|
| btBG | #000000 |
| btBGSecondary | #1C1C1E |
| btBGTertiary | #2C2C2E |
| btText | #FFFFFF |
| btTextSecondary | rgba(235,235,240,0.6) |
| btSeparator | #38383A |
| btPrimary | #25A25A |
| btTableFelt | #144D2A |
| btAccent | #F0AD30 |

---

### S-01 个人中心页面下半部分渲染为 Light Mode（严重回归）
- **类别**：Dark Mode
- **严重程度**：P0（不可用）
- **位置**：我的 Tab > ProfileView > 滚动至底部
- **截图现状**：E-01-06 截图显示，个人中心页面从「解锁球迹 Pro」卡片以下区域全部渲染为 Light Mode：
  - 菜单列表项（我的收藏、个人信息、训练目标、订阅管理）背景为白色卡片
  - 设置组（偏好设置、隐私政策、关于与反馈）背景为白色卡片
  - 分组间距背景为浅灰色（类似 systemGroupedBackground Light 变体）
  - 「登录 / 注册」按钮区域底色为白色
  - 「跳过，以游客身份继续」文字为绿色文字显示在白色背景上
  - 「版本 1.0.0」为灰色文字在白色背景上
  - Tab Bar 背景变为白色/浅色，失去 Dark Mode 样式
- **设计预期**：所有区域应使用 Dark Mode Token —— 页面底色 btBG #000000，卡片 btBGSecondary #1C1C1E，分组间距 btBG #000000，Tab Bar bg btBGSecondary #1C1C1E + border-t btSeparator #38383A
- **修复方向**：排查 ProfileView 中是否存在硬编码 `.white` / `Color.white` / `.background(Color(.systemGroupedBackground))` 等不随 colorScheme 切换的颜色。确保所有背景使用 `.btBG` / `.btBGSecondary` 语义 Token。同时检查 List/Form 样式是否被 `.scrollContentBackground(.hidden)` 覆盖了系统默认背景。
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/Profile/Views/ProfileView.swift`，可能涉及 List/Form 的 `.scrollContentBackground()` 修饰符或内嵌 Section 背景

---

### S-02 训练首页筛选 Chip 选中态样式与设计不符
- **类别**：Design Token / Dark Mode
- **严重程度**：P1（功能缺陷 — 选中态视觉无法区分）
- **位置**：训练 Tab > 官方计划 > 筛选 Chip 栏（全部/入门/初级/中级/高级）
- **截图现状**：E-01-01 中，选中的「全部」Chip 使用深色填充 + 白色描边 + 白色文字，与未选中 Chip 视觉几乎相同（仅描边略亮），用户难以快速识别当前选中项
- **设计预期**：design code.html §6.3 明确指定 —— 选中 Chip: `bg-[#F2F2F7] text-black font-semibold`（浅色填充 + 黑色文字），未选中: `bg-[#1C1C1E] text-white border border-[#38383A]`。两态对比度必须显著
- **修复方向**：修改 Chip 组件的选中态背景为 `Color(hex: 0xF2F2F7)`（或语义 Token `btChipSelected`），文字改为 `.black`。确保在 Dark Mode 下选中 Chip 是浅底深字的「反转」风格
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/Training/Views/TrainingHomeView.swift` 中 Chip / Picker 组件，或 `QiuJi/Core/Components/BTChip.swift`（若存在公共组件）

---

### S-03 动作库筛选 Chip 选中态样式与设计不符（同 S-02）
- **类别**：Design Token / Dark Mode
- **严重程度**：P1（功能缺陷）
- **位置**：动作库 Tab > 顶部筛选 Chip（全部/中式台球/9球/通用）
- **截图现状**：E-01-02 中，选中的「全部」Chip 同样使用深色描边 + 白色文字风格，与未选中项区分度不足
- **设计预期**：与 S-02 一致 —— 选中态应为 `bg-[#F2F2F7] text-black`
- **修复方向**：若 Chip 组件与训练首页共用同一 BTChip，修复 S-02 即可同步解决。否则需在 DrillListView 中同步修改
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/DrillLibrary/Views/DrillListView.swift`

---

### S-04 统计页周/月/年切换 Chip 选中态样式与设计不符
- **类别**：Design Token / Dark Mode
- **严重程度**：P1（功能缺陷）
- **位置**：记录 Tab > 统计 > 周/月/年切换 Chip
- **截图现状**：E-01-04 中，选中的「周」Chip 使用深色填充 + 白色文字，与未选中的「月」「年」视觉区分不够明显
- **设计预期**：选中态应采用 `#F2F2F7` 浅色填充 + 黑色文字（§6.3 Dark Mode Chip 选中态规范），形成与深色背景的强对比
- **修复方向**：统一使用 BTChip 组件的选中态样式。若此处使用了 SwiftUI Picker/Segmented 控件，确保 `.pickerStyle(.segmented)` 的 tint 与背景色在 Dark Mode 下正确
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/History/Views/StatisticsView.swift` 或 `WeeklyStatsView.swift`

---

### S-05 角度训练页卡片背景色偏灰，疑似与 btBGSecondary 偏差
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：角度 Tab > 角度训练 > 功能入口卡片（角度测试、进球点对照表、查看测试历史）
- **截图现状**：E-01-03 中，三张功能入口卡片的背景色相比训练首页和动作库的卡片色调略偏灰/偏亮，可能未使用 btBGSecondary（#1C1C1E）而是偏向 #2C2C2E 或 systemGray6
- **设计预期**：一级卡片一律使用 btBGSecondary #1C1C1E，与页面底色 btBG #000000 形成统一的暗色层级
- **修复方向**：检查 AngleHomeView 中卡片的 `.background()` 是否使用了 `.btBGSecondary` Token，排除硬编码或使用了错误的系统色
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/Angle/Views/AngleHomeView.swift` 或相关入口卡片组件

---

### S-06 统计页图表区 Pro 锁定遮罩缺少半透明暗色叠层
- **类别**：视觉打磨 / Dark Mode
- **严重程度**：P2（视觉瑕疵）
- **位置**：记录 Tab > 统计 > 训练时长卡片 > 图表区域
- **截图现状**：E-01-04 中，Pro 锁定的图表区域直接显示锁图标和「解锁 Pro」金色按钮，但背景仅为空白的卡片底色，缺少半透明叠层暗示「内容被遮挡」
- **设计预期**：Freemium 锁定区域应有半透明遮罩（如 `btBG.opacity(0.6)` 或 `LinearGradient` 渐变）覆盖图表内容，锁图标居中，「解锁 Pro」按钮在遮罩上方
- **修复方向**：添加半透明叠层 overlay，参考 `docs/08-商业化与合规.md` Freemium 遮罩规范
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/History/Views/StatisticsView.swift`，Pro 锁定区域组件

---

### S-07 训练首页「今日安排」卡片圆角与设计稿存在细微差异
- **类别**：视觉打磨
- **严重程度**：P2（视觉瑕疵）
- **位置**：训练 Tab > 今日安排 > Drill 卡片
- **截图现状**：E-01-01 中，今日安排的三张 Drill 完成卡片的圆角视觉上偏大（可能为 BTRadius.lg=16 或更大），与 Drill 设计稿中的 `rounded-[16pt]`（BTRadius.lg=16）基本一致，但「今日训练已完成」消息卡片与上方 Drill 卡片之间存在视觉分隔——设计稿用独立区块处理。此条需代码确认
- **设计预期**：所有今日安排卡片统一使用 BTRadius.lg (16pt) 圆角，卡片间距 Spacing.md (12pt)
- **修复方向**：确认代码中使用的圆角值与间距值，若已正确使用 BTRadius.lg 和 Spacing.md 则可关闭
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/Training/Views/TrainingHomeView.swift`

---

### 审查总结
- **截图审查范围**：6 张实机 Dark Mode 截图 + 5 组设计参考（screen.png + code.html）
- **发现问题**：7 项（P0: 1 / P1: 3 / P2: 3）
- **总体评价**：Dark Mode 基础框架已落地，5 个 Tab 中有 4 个的主体页面暗色表现良好——页面底色 #000000、卡片 #1C1C1E、文字层级、Tab Bar、球台缩略图等核心 Token 均正确。但存在 1 个严重回归：个人中心页面下半部分完全渲染为 Light Mode（S-01），以及所有筛选 Chip 的选中态缺失浅底反转样式（S-02~S-04），导致操作状态不清晰。
- **建议下一步**：
  1. **[最高优先]** 修复 S-01 — ProfileView Light Mode 渲染回归，这是 Dark Mode 上线的 blocking issue
  2. **[高优先]** 统一修复 S-02~S-04 — BTChip 选中态改为 `#F2F2F7` fill + black text（建议抽取公共组件一次修复）
  3. **[后续打磨]** S-05~S-07 可在下一轮 UI polish 中处理
