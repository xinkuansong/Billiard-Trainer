## UI 审查报告 — AngleTraining V2 Delta Review
日期：2026-04-06

审查对象：角度训练首页 + 角度测试 + 击球点对照表 + 测试历史
截图来源：V2 实机截图 7 张（P0-07-01 ~ P0-07-03, P1-05-01 ~ P1-05-02, P1-06-01 ~ P1-06-02）
设计参考：P0-07 / P1-05 / P1-06 各 code.html + screen.png
前次审查：`tasks/ui-reviews/UR-20260406-AngleTraining-Screenshot.md`（S-01 ~ S-10）

---

### 前次问题状态一览

| 编号 | 标题 | 严重程度 | 状态 | 说明 |
|------|------|---------|------|------|
| S-01 | 击球点对照表接触点颜色 btDestructive→btPrimary | P1 | ✅ FIXED | V2 球面图接触点已改为绿色（btPrimary），代码确认 `with: .color(.btPrimary)` |
| S-02 | 角度测试导航栏缺少帮助(?)按钮 | P2 | 🔴 OPEN | P0-07-01/02/03 导航栏右侧仍无帮助图标，代码中无对应 toolbar item |
| S-03 | 子页面返回按钮缺少 "角度训练" 文字 | P2 | 🔴 OPEN | P0-07-01/P1-05-02/P1-06-01 返回按钮仍仅显示 `<` chevron，无父页面标题文字；根因可能与 S-07 相同——NavigationStack 层级导致 `.navigationTitle` 未被子页面 back button 引用 |
| S-04 | 0°/90° 偏移列使用语义名称 | P2 | ✅ FIXED | 代码已对 0° 显示 "球心"、90° 显示 "球边缘"；V2 截图 P1-05-02 表格中 0° 行偏移列显示 "球心" |
| S-05 | 交互区偏移百分比多余小数位 | P2 | ✅ FIXED | P1-05-02 显示 "偏移 50%"（无小数），代码使用 `%.0f%%` |
| S-06 | 对照表区标题文案与图标 | P2 | ✅ FIXED | P1-05-02 显示 `tablecells` 图标 + "对照表"，与设计一致 |
| S-07 | 首页标题字号偏小 (btTitle→btLargeTitle) | P2 | 🟡 PARTIAL | 代码已改用 `.navigationTitle("角度训练")` + `.navigationBarTitleDisplayMode(.large)`，但 V2 截图 P1-05-01 中**不可见大标题**——首页内容直接从状态栏下方开始，无 Large Title 渲染。可能原因：NavigationStack 层级问题或 Tab 嵌套导致系统 Large Title 未生效 |
| S-08 | 测试历史空状态缺少操作按钮 | P2 | ✅ FIXED | 代码已添加 `actionTitle: "开始角度测试"`；V2 截图为有数据状态，无法视觉验证空状态，以代码为准 |
| S-09 | "查看测试历史"→"测试历史" 文案与图标 | P2 | ✅ FIXED | P1-05-01 显示 `clock.arrow.circlepath` 图标 + "测试历史"，与设计一致 |
| S-10 | 功能卡片副标题文案差异 | P2 | ✅ FIXED | P1-05-01 角度测试 = "训练角度视觉感知"，进球点对照表 = "角度与接触点对照"，完全对齐设计 |

---

### 新发现问题

### N-01 测试历史时间范围选择器样式与设计不一致
- **类别**：Design Token / 产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：角度 > 测试历史 > 时间范围选择器
- **现状**：P1-06-01 使用 BTSegmentedTab 组件，呈现为三个文字标签 "本周 / 本月 / 全部"，选中项以下划线/加粗标记
- **预期**：设计 `stitch_task_p1_06_02` code.html line 148-152 使用胶囊形（capsule）分段控件：`bg-surface-container-highest p-1 rounded-full` 容器 + 选中项 `bg-primary-container text-on-primary rounded-full` 填充背景；标签文案为 "周 / 月 / 全部"（短标签）
- **差异点**：①样式：下划线 vs 胶囊填充；②标签："本周/本月" vs "周/月"
- **修复方向**：使用 BTTogglePillGroup（已有组件，若支持 3 项）或为 BTSegmentedTab 添加 capsule 变体样式；标签改为 "周/月/全部"
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/AngleTraining/Views/AngleHistoryView.swift` 第 20-21 行 `BTSegmentedTab` 调用处

---

### N-02 击球点对照表——球面图接触点缺少外环光晕效果
- **类别**：视觉打磨
- **严重程度**：P2（视觉瑕疵）
- **位置**：角度 > 进球点对照表 > 交互滑块区 > 球面截面图
- **现状**：P1-05-02 接触点为纯实心绿色圆点（btPrimary），无装饰
- **预期**：设计 `stitch_task_p1_05_contactpointtableview_02` code.html line 125 接触点使用 `bg-primary-container rounded-full ring-4 ring-primary-container/20 shadow-lg`，即实心圆点外围有一圈半透明绿色光环（ring）和微阴影，提升进球点的视觉辨识度
- **修复方向**：在 `ballDiagram()` Canvas 绘制接触点时，先绘制一个更大、低透明度的圆（ring），再绘制实心圆点叠加其上
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/AngleTraining/Views/ContactPointTableView.swift` 第 227-229 行 Canvas 绘制接触点处，在实心圆之前添加 `ctx.fill(... with: .color(.btPrimary.opacity(0.2)))` 的更大圆

---

### 审查总结

- 截图数量：7 张（V2）
- 设计参考：4 组
- **前次 10 项问题**：✅ FIXED 7 项 / 🟡 PARTIAL 1 项 / 🔴 OPEN 2 项
- **新发现**：2 项（P0: 0 / P1: 0 / P2: 2）
- 总体评价：V2 修复率 70%，7 项 P2 问题全部解决，P1 问题（S-01 接触点颜色）已修复。核心遗留为 S-07（大标题不渲染）与 S-03（返回按钮无文字），两者疑似同根——NavigationStack 层级未正确传递 `.navigationTitle`。新发现均为 P2 级视觉打磨项。
- 建议下一步：
  1. **优先排查 S-07 + S-03 根因**：确认 `AngleHomeView` 所在的 NavigationStack 是否正确嵌套（检查 Tab 入口处的 NavigationStack 配置），修复后两个问题应同时消除
  2. **S-02（帮助按钮）** 可在功能迭代中添加
  3. **N-01（时间选择器样式）+ N-02（接触点光晕）** 归入下一轮视觉打磨
