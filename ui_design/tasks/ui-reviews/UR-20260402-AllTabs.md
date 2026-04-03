## UI 审查报告 — 全 Tab 首轮截图审查（Light Mode）
日期：2026-04-02  
截图来源：`ui_test_imgs/` IMG_0662–IMG_0672（共 11 张）  
覆盖页面：训练 Tab / 动作库 / 角度 Tab / 历史 Tab / 我的 Tab / 自由记录流程 / 选择训练项目 Sheet / 结束训练弹窗

---

### U-01 训练 Tab 图标使用游泳人形图标，与台球主题不符
- **类别**：视觉打磨
- **严重程度**：P1
- **位置**：全局 Tab Bar > 训练 Tab（第一个 Tab）
- **现状**：IMG_0663 底部 Tab Bar 可见，训练 Tab 图标为游泳/运动人形 SF Symbol（类似 `figure.pool.swim`），与台球训练 App 主题严重不符。
- **预期**：应使用台球相关图标，如 `sportscourt.fill`、`figure.pool.swim` 替换为 billiard/cue 相关自定义图标或 `gamecontroller.fill`，或与品牌视觉一致的自定义 SF Symbol。
- **修复方向**：在 `TrainingTabView` 或 5 Tab 骨架 `ContentView` 的 `tabItem` 中更换图标。
- **路由至**：SwiftUI Developer
- **代码提示**：`QiuJi/Features/Training/TrainingTabView.swift` 或 `QiuJi/App/ContentView.swift`

---

### U-02 训练 Tab 及自由记录页右上角按钮内容不显示
- **类别**：布局 / HIG
- **严重程度**：P1
- **位置**：训练 Tab > 右上角；自由记录页 > 右上角（两处圆角矩形按钮）
- **现状**：IMG_0662 右上角有一个灰色圆角矩形，无文字无图标；IMG_0667/0672 右上角也有两个灰色圆角矩形，均无任何内容显示。按钮存在但用户无法判断其功能。
- **预期**：每个操作按钮必须有清晰的文本标签或 SF Symbol 图标（HIG：按钮需有明确的文字或图标标识）。训练 Tab 右上角可能是"设置"或"计划管理"；自由记录右上角应为"+" 添加和"完成"等操作。
- **修复方向**：检查 `toolbar` / `navigationBarItems` 中的 Button 是否因 Label 内容缺失而呈现为空胶囊。确认 `Label("添加", systemImage: "plus")` 或 `.toolbarItem` 正确绑定。
- **路由至**：SwiftUI Developer
- **代码提示**：`QiuJi/Features/Training/TrainingView.swift`、`QiuJi/Features/Training/FreeSessionView.swift`

---

### U-03 动作库与选择训练项目弹窗中 Drill 名称未显示
- **类别**：产品规格 / 布局
- **严重程度**：P1
- **位置**：动作库 Tab > Drill 列表；自由记录 > 选择训练项目 Sheet
- **现状**：IMG_0663 每条列表行只显示"基础功 · 通用"和"3组×15球"，Drill 具体名称（如"握杆稳定性训练"）缺失，标题行为空。IMG_0668 同样只显示"基础功 · 3组×15球"，无 Drill 名。
- **预期**：每条 Drill 行应显示 Drill 名称（btHeadline，17pt Semibold）+ 分类·球种 + 推荐组数（btFootnote）。Drill 名称是列表的主要信息。
- **修复方向**：检查列表单元格 View 中 `drill.name` 或 `drill.title` 字段是否正确绑定。排查 JSON 解析、ViewModel 映射或本地化 key 是否有误。
- **路由至**：SwiftUI Developer / Data Engineer（若为数据映射问题）
- **代码提示**：`QiuJi/Features/DrillLibrary/DrillListView.swift`、`QiuJi/Features/DrillLibrary/DrillRowView.swift`

---

### U-04 动作库顶部球种筛选下方出现孤立数字"8"
- **类别**：布局
- **严重程度**：P2
- **位置**：动作库 Tab > 球种筛选 Chip 下方
- **现状**：IMG_0663 球种筛选行（"中式台球 / 9球"）下方独立显示数字"8"，无标签、无上下文，视觉突兀。
- **预期**：若为分类计数或 Drill 数量标注，应有上下文标签（如"8 项"或嵌入分类标题）；若为调试残留代码，应删除。
- **修复方向**：定位渲染数字"8"的 Text 控件，补充标签或删除。
- **路由至**：SwiftUI Developer
- **代码提示**：`QiuJi/Features/DrillLibrary/DrillListView.swift`

---

### U-05 动作库缺少左侧分类导航，与规格要求的两栏布局不符
- **类别**：产品规格
- **严重程度**：P1
- **位置**：动作库 Tab > 主列表区
- **现状**：IMG_0663 呈现为简单的全宽平铺列表，无左侧 8 大类导航栏。
- **预期**：`docs/05` 规格要求"左侧分类导航（8个大类）+ 右侧内容区"两栏布局，子分类横向 Tab。8 大类：基础功、准度训练、杆法、分离角、走位、控力、特殊球路、综合球形。
- **修复方向**：若 T-P3-06 已完成但布局与规格不符，需评估当前实现是否临时简化。建议参考规格补充左侧 NavigationSplitView 或自定义侧边分类选择器。
- **路由至**：SwiftUI Developer / iOS Architect（布局方案决策）
- **代码提示**：`QiuJi/Features/DrillLibrary/DrillListView.swift`

---

### U-06 训练记录 Drill 详情页仅有列标题，缺少球数输入控件（T-P4-05 待开发）
- **类别**：产品规格
- **严重程度**：P0
- **位置**：自由记录 > Drill 详情记录页（IMG_0669、IMG_0670）
- **现状**：页面底部仅显示"组 / 球/组 / 总球数"三个灰色标题行，无任何输入控件（步进器、数字键盘、大按钮等）。用户在训练中无法记录数据。同时缺少球台动画区域。
- **预期**：根据 `docs/05` 训练记录流程：「记录本组完成数：数字键盘输入"进了X球 / 共Y球"」，应有每组输入组件 + 完成本组按钮。BTBilliardTable Canvas 动画区域也应在页面上方显示。
- **修复方向**：此为 T-P4-05（训练中 Drill 记录界面，⏳ 待开始）的核心 UI。尽快排期开发；当前页面应加 placeholder 提示而非仅显示空标题。
- **路由至**：SwiftUI Developer
- **代码提示**：`QiuJi/Features/Training/DrillSessionView.swift`（或对应记录界面文件）

---

### U-07 结束训练确认弹窗左侧按钮无文字
- **类别**：HIG / 无障碍
- **严重程度**：P0
- **位置**：自由记录 > 结束训练 > 确认弹窗（IMG_0671）
- **现状**：弹窗右侧有红色"结束"按钮，左侧为纯灰色圆角矩形，完全无文字标签。用户不知道左侧按钮的功能（应为"取消"）。VoiceOver 无法读出该按钮。
- **预期**：HIG 要求 Alert/确认弹窗每个按钮必须有明确文本。左侧按钮应标注"取消"（btBody，默认色）。
- **修复方向**：检查自定义弹窗中左侧 Button 的 Label 是否绑定了空字符串或 EmptyView。修复为 `Button("取消") { ... }`。
- **路由至**：SwiftUI Developer
- **代码提示**：`QiuJi/Features/Training/FreeSessionView.swift`（确认弹窗实现处）

---

### U-08 我的 Tab 部分列表行缺少文字标签
- **类别**：布局 / 产品规格
- **严重程度**：P1
- **位置**：我的 Tab > 设置/功能列表区（IMG_0666）
- **现状**：列表中间有 2 行仅显示右箭头（">"），完全无文字或图标；下方 2 行有 SF Symbol 图标但无文字说明（分别是文档图标和 info 图标）。用户无法知道这些入口的用途。
- **预期**：`docs/05` 规格"我的 Tab"包含：个人信息、数据工具、设置（账号与安全、通知设置、偏好设置、关于/反馈）。所有列表行均需显示对应文字标签。
- **修复方向**：检查 Profile Tab 列表行 View 中 `Label` 的文字绑定，排查是否因 `LocalizedStringKey` 缺失、条件渲染逻辑问题导致文字未显示。
- **路由至**：SwiftUI Developer
- **代码提示**：`QiuJi/Features/Profile/ProfileView.swift`

---

### U-09 动作库球种筛选缺少"全部"和"通用"选项
- **类别**：产品规格
- **严重程度**：P2
- **位置**：动作库 Tab > 顶部球种筛选 Chip（IMG_0663）
- **现状**：筛选 Chip 仅显示"中式台球"和"9球"两项。
- **预期**：`docs/05` 规格明确要求「顶部 Chip：全部 / 中式台球 / 9球 / 通用」共 4 个选项。"全部"为默认选中态；"通用"可筛选两种球种共用的 Drill。
- **修复方向**：在 DrillListViewModel 或 DrillFilterView 中补充 `.all` 和 `.universal` 筛选选项及对应枚举值。
- **路由至**：SwiftUI Developer
- **代码提示**：`QiuJi/Features/DrillLibrary/DrillListView.swift`、`QiuJi/Features/DrillLibrary/DrillListViewModel.swift`

---

### U-10 训练记录 Drill 详情页缺少球台动画区域
- **类别**：产品规格
- **严重程度**：P1
- **位置**：自由记录 > Drill 详情记录页（IMG_0669、IMG_0670）
- **现状**：页面仅有文字说明（Drill 描述 + 要点列表），完全无球台动画区域。BTBilliardTable Canvas 组件（T-P3-08 已完成）未在此页面中嵌入使用。
- **预期**：训练记录流程规格：「显示 Drill 名称 + 球台动画（母球/目标球路线动画）+ 要点提示」。球台动画是产品核心 UX 卖点，训练时用户依赖它理解球路。
- **修复方向**：在 Drill 详情记录页顶部嵌入 `BTBilliardTable` Canvas 组件，传入当前 Drill 的球路坐标数据。
- **路由至**：SwiftUI Developer
- **代码提示**：`QiuJi/Core/Components/BTBilliardTable.swift`、Drill 记录界面文件

---

### U-11 Large Title 字体未呈现 Rounded 设计效果
- **类别**：Design Token
- **严重程度**：P2
- **位置**：全 Tab 大标题（训练/动作库/角度训练/历史/我的）
- **现状**：IMG_0662–0666 的大标题字体观感为标准 SF Pro Display，Rounded 弧度不明显。
- **预期**：`btLargeTitle = Font.system(size: 34, weight: .bold, design: .rounded)` 应呈现 SF Pro Rounded 的特征字形（字母圆润感明显，如"a"、"e"等）。若已正确使用 Token 但效果不明显，可能是设备/渲染差异；若未使用 Token，需替换。
- **修复方向**：确认各 Tab 页面标题 Text 使用 `.font(.btLargeTitle)` 而非 `.navigationTitle()` 自动样式（`navigationTitle` 默认不应用自定义字体）。需要自定义 Large Title 的视图建议手动用 `Text(title).font(.btLargeTitle)` 代替依赖 NavigationView 的自动标题。
- **路由至**：SwiftUI Developer
- **代码提示**：各 Tab 根 View

---

### 审查总结
- **问题数量**：11 项（P0: 2 / P1: 6 / P2: 3）
- **总体评价**：App 骨架搭建完整、导航结构清晰，但存在 2 项阻塞体验的 P0 缺陷（训练记录无输入控件、弹窗按钮无文字），以及多处内容缺失/渲染异常（Drill 名称空白、按钮内容不显示、列表行标签缺失）。P4 Training Log 核心记录界面（T-P4-05）尚未开发，是当前最高优先级工作项。

| 编号 | 标题 | 严重程度 | 路由 | FL |
|------|------|----------|------|----|
| U-01 | 训练 Tab 图标使用游泳人形 | P1 | SwiftUI Developer | FL-002 |
| U-02 | 多处按钮内容不显示 | P1 | SwiftUI Developer | FL-003 |
| U-03 | Drill 名称缺失 | P1 | SwiftUI Developer / Data | FL-004 |
| U-04 | 动作库孤立数字"8" | P2 | SwiftUI Developer | — |
| U-05 | 动作库缺少左侧分类导航 | P1 | SwiftUI Developer | FL-005 |
| U-06 | 训练记录无球数输入控件 | P0 | SwiftUI Developer | FL-006 |
| U-07 | 弹窗取消按钮无文字 | P0 | SwiftUI Developer | FL-007 |
| U-08 | 我的 Tab 列表行缺少文字 | P1 | SwiftUI Developer | FL-008 |
| U-09 | 球种筛选缺少"全部"/"通用" | P2 | SwiftUI Developer | — |
| U-10 | 训练记录页缺少球台动画 | P1 | SwiftUI Developer | FL-009 |
| U-11 | Large Title 未呈现 Rounded 效果 | P2 | SwiftUI Developer | — |
