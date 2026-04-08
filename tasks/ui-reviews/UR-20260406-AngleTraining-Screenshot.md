## UI 截图审查报告 — AngleTraining 系列（截图对照）
日期：2026-04-06

审查对象：角度训练首页 + 角度测试 + 击球点对照表 + 测试历史
截图来源：P0-07-01, P0-07-02, P1-05-01 ~ P1-05-03, P1-06-01（6 张实机截图）
设计参考：P0-07, P1-05, P1-06 各 code.html + screen.png

---

### S-01 击球点对照表——接触点颜色使用 btDestructive（红色）而非 btPrimary（绿色）
- **类别**：Design Token
- **严重程度**：P1（功能缺陷）
- **位置**：角度 > 进球点对照表 > 球面可视化圆圈
- **截图现状**：P1-05-02 中，球面截面图上的接触点标记为较大的**红色圆点**（位于圆左侧），视觉上与 btDestructive (#C62828) 一致
- **设计预期**：设计参考 `stitch_task_p1_05_contactpointtableview_02/screen.png` 中接触点为**绿色圆点**（primary-container #1A6B3C），带有半透明环效果；code.html line 125 使用 `bg-primary-container rounded-full ring-4 ring-primary-container/20`
- **修复方向**：将 `ContactPointTableView.swift` 中 `ballDiagram()` 方法内 Canvas 绘制接触点的颜色从 `.btDestructive` 改为 `.btPrimary`
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/AngleTraining/Views/ContactPointTableView.swift` 第 217 行 `with: .color(.btDestructive)` → `with: .color(.btPrimary)`

---

### S-02 角度测试导航栏缺少帮助（?）按钮
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：角度 > 角度测试 > 导航栏右侧
- **截图现状**：P0-07-01 / P0-07-02 导航栏仅显示 "< 角度测试"，右侧无任何图标
- **设计预期**：设计 `stitch_task_p0_07_angletestview_02` 导航栏右侧有 `help` 图标（Material Symbols "help"），code.html line 109-111；用于展示规则说明
- **修复方向**：在 `AngleTestView` 的 `.toolbar` 中添加 trailing ToolbarItem，放置 SF Symbol `questionmark.circle` 并绑定规则说明 Sheet
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/AngleTraining/Views/AngleTestView.swift`，在 `.toolbar(.hidden, for: .tabBar)` 附近添加 `.toolbar { ToolbarItem(placement: .topBarTrailing) { ... } }`

---

### S-03 子页面返回按钮缺少父页面标题文字 "角度训练"
- **类别**：HIG
- **严重程度**：P2（视觉瑕疵）
- **位置**：角度测试、进球点对照表、测试历史——所有子页面导航栏
- **截图现状**：P0-07-01、P1-05-02、P1-06-01 返回按钮均仅显示 "<" 系统 chevron，无 "角度训练" 文字标签
- **设计预期**：设计参考中 angletestview code.html line 105-106 显示 `arrow_back_ios` + "角度训练" 文字；contactpointtableview code.html line 109-111 也显示 `arrow_back_ios` + "角度训练"；符合 iOS HIG 标准导航回退标签
- **修复方向**：确认 `AngleHomeView` 所在的 NavigationStack 正确设置了 `.navigationTitle("角度训练")`；iOS 系统会自动将父页面 title 作为子页面返回按钮文字。若 AngleHomeView 使用手动 pageHeader 而非系统 navigationTitle，则需确保系统标题也被设置
- **路由至**：ios-architect
- **代码提示**：`QiuJi/Features/AngleTraining/Views/AngleHomeView.swift` — 当前 body 中未设置 `.navigationTitle()`（仅在 #Preview 中设置）；需在 body 的 ScrollView 修饰符中添加 `.navigationTitle("角度训练")` 并配合 `.navigationBarTitleDisplayMode(.large)` 以同时获得大标题和子页面回退文字

---

### S-04 击球点对照表——0° 和 90° 偏移列使用纯百分比而非语义名称
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：角度 > 进球点对照表 > 标准角度对照表 > 0° 行 "偏移" 列 & 90° 行 "偏移" 列
- **截图现状**：P1-05-03 中 0° 行偏移列显示 "0%"，90° 行偏移列显示 "100%"
- **设计预期**：设计 `stitch_task_p1_05_contactpointtableview_02` code.html line 188-191 中 0° 行偏移列显示 "球心"（语义化标签），line 263-266 中 90° 行偏移列显示 "球边缘"；这些语义名称帮助用户理解物理含义
- **修复方向**：在 `ContactPointTableView.swift` 的 `tableRow()` 方法中，对 0° 和 90° 进行特殊处理：0° 偏移列显示 "球心" 代替 "0%"，90° 偏移列显示 "球边缘" 代替 "100%"
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/AngleTraining/Views/ContactPointTableView.swift` 第 169 行 `Text(String(format: "%.0f%%", offset * 100))`，需对 `entry.angle == 0` 和 `entry.angle == 90` 条件分支

---

### S-05 击球点对照表——交互区偏移百分比显示多余小数位
- **类别**：视觉打磨
- **严重程度**：P2（视觉瑕疵）
- **位置**：角度 > 进球点对照表 > 交互滑块区域 > 偏移文字
- **截图现状**：P1-05-02 显示 "偏移 50.0%"（一位小数）
- **设计预期**：设计 `stitch_task_p1_05_contactpointtableview_02` screen.png 显示 "偏移 50%"（无小数位）；code.html line 132 使用 "偏移 50%" 无小数
- **修复方向**：将格式化字符串从 `"%.1f%%"` 改为 `"%.0f%%"`，或使用智能格式化（整数时不显示小数，非整数时保留一位）
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/AngleTraining/Views/ContactPointTableView.swift` 第 61 行 `String(format: "偏移 %.1f%%", ...)` → `String(format: "偏移 %.0f%%", ...)`

---

### S-06 击球点对照表——对照表区标题文案与设计不一致
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：角度 > 进球点对照表 > 静态表格区 > 标题
- **截图现状**：P1-05-03 显示标题为 "标准角度对照"，无图标前缀
- **设计预期**：设计 code.html line 170-173 标题为 "对照表" 并带 `grid_on` 图标前缀（`<span class="material-symbols-outlined">grid_on</span>` + `<h2>对照表</h2>`）
- **修复方向**：将标题文案改为 "对照表" 并在前方添加 SF Symbol `tablecells`（对应设计中的 grid_on 图标）
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/AngleTraining/Views/ContactPointTableView.swift` 第 129 行 `Text("标准角度对照")`

---

### S-07 角度训练首页——标题字号偏小，使用 btTitle (22pt) 而非设计的 34px
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：角度 > 角度训练首页 > 页面标题 "角度训练"
- **截图现状**：P1-05-01 标题 "角度训练" 为粗体，但视觉上相对较小（代码确认使用 `.btTitle` = 22pt bold rounded）
- **设计预期**：设计 `stitch_task_p1_05_02` code.html line 93 使用 `text-[34px] font-bold`（对应 btLargeTitle = 34pt bold rounded）；作为 Tab 首屏页面，应使用 iOS Large Title 风格
- **修复方向**：将 `pageHeader` 中的 `.btTitle` 改为 `.btLargeTitle`；或更优方案——移除手动 pageHeader，改用系统 `.navigationTitle("角度训练")` + `.navigationBarTitleDisplayMode(.large)` 获得原生大标题效果（同时解决 S-03 的返回按钮文字问题）
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/AngleTraining/Views/AngleHomeView.swift` 第 39 行 `.font(.btTitle)` → `.font(.btLargeTitle)`，或在 body 中添加 `.navigationTitle("角度训练")` + `.navigationBarTitleDisplayMode(.large)` 并移除 `pageHeader`

---

### S-08 测试历史空状态缺少操作按钮
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：角度 > 测试历史 > 空状态
- **截图现状**：P1-06-01 显示图标 + "暂无测试记录" + 副标题，无操作按钮
- **设计预期**：BTEmptyState 组件支持可选的 `actionTitle` + `action` 参数（见 SKILL.md §十二）；空状态最佳实践应提供快捷入口引导用户完成首次操作
- **修复方向**：为 AngleHistoryView 空状态的 BTEmptyState 添加 `actionTitle: "开始角度测试"` 和对应的导航 action（跳转到角度测试页面）
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/AngleTraining/Views/AngleHistoryView.swift` 第 14-16 行 BTEmptyState 调用处，添加 `actionTitle` 和 `action` 参数

---

### S-09 角度训练首页——"查看测试历史" 与设计文案 "测试历史" 不一致
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：角度 > 角度训练首页 > 历史入口行
- **截图现状**：P1-05-01 显示图标（chart.line.uptrend.xyaxis）+ "查看测试历史"
- **设计预期**：设计 `stitch_task_p1_05_02` code.html line 122-126 使用 `history` 图标 + "测试历史" 文案（简洁，符合 iOS 列表行命名惯例）
- **修复方向**：将文案从 "查看测试历史" 改为 "测试历史"；图标从 `chart.line.uptrend.xyaxis` 改为 `clock.arrow.circlepath`（对应设计中的 history 图标）
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/AngleTraining/Views/AngleHomeView.swift` 第 72 行 `Image(systemName: "chart.line.uptrend.xyaxis")` 和第 73 行 `Text("查看测试历史")`

---

### S-10 角度训练首页——功能卡片副标题与设计文案差异
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：角度 > 角度训练首页 > 角度测试卡片副标题 & 进球点对照表卡片副标题
- **截图现状**：P1-05-01 角度测试副标题为 "判断切球角度，AI 自适应出题"；进球点对照表副标题为 "交互式查看不同角度的接触点"
- **设计预期**：设计 `stitch_task_p1_05_02` code.html line 105 角度测试副标题为 "训练角度视觉感知"（简洁）；line 115 进球点对照表副标题为 "角度与接触点对照"（简洁）
- **修复方向**：将副标题对齐设计文案：角度测试 → "训练角度视觉感知"，进球点对照表 → "角度与接触点对照"。当前文案信息量更大但较长，可根据产品决策保留或简化
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/AngleTraining/Views/AngleHomeView.swift` 第 52 行和第 61 行 subtitle 参数

---

### 审查总结
- 截图数量：6 张
- 设计参考：5 组（code.html + screen.png）
- 发现问题：10 项（P0: 0 / P1: 1 / P2: 9）
- 总体评价：角度训练模块整体实现质量良好，布局结构、Token 使用、球台 Canvas 渲染均基本到位。最突出的问题是击球点对照表中接触点标记使用了红色（btDestructive）而非品牌绿色（btPrimary），与设计明确不符。其余为文案对齐、字号微调和小型 UX 增强项。
- 建议下一步：
  1. **优先修复 S-01**（P1）：仅需改一行代码，将接触点颜色从 `.btDestructive` 改为 `.btPrimary`
  2. **打包修复 S-03 + S-07**：通过将 AngleHomeView 切换为系统 `.navigationTitle` + `.navigationBarTitleDisplayMode(.large)` 同时解决大标题尺寸和子页面返回按钮文字两个问题
  3. 其余 P2 项可在下一个打磨迭代中统一处理
