## UI 截图审查报告 — DrillListView（截图对照）
日期：2026-04-06

审查对象：动作库列表页（新版左侧栏 + 右侧网格布局）
截图来源：P1-01-01 ~ P1-01-06（6 张实机截图，Light Mode）
设计参考：P1-01 code.html + screen.png（配色/字体参考）, ref-screenshots/04-exercise-library（布局参考）
备注：左侧分类导航栏 + 右侧 2 列网格为已确认的新设计，不作为偏差项

---

### S-01 空筛选结果时侧边栏消失，布局断裂
- **类别**：布局 / 产品规格
- **严重程度**：P1（功能缺陷）
- **位置**：动作库 > 球种筛选「9 球」/ 「通用」
- **截图现状**：P1-01-05（9 球）和 P1-01-06（通用）截图中，选择这两个球种后，左侧分类导航栏完全消失，仅显示居中的空状态视图。整个页面从 sidebar + grid 布局退化为单栏居中布局。
- **设计预期**：参考 ref-screenshots/04-exercise-library/01-list-default.png，训记 App 的左侧导航栏始终可见，不因内容区状态变化而消失。侧边栏应独立于内容区保持常驻，内容区域内部显示空状态。
- **修复方向**：将 `DrillListView.body` 中的空状态判断从 `mainContent` 外部移入 `drillGrid` 内部。当 `drillsByCategory.isEmpty` 时，`mainContent`（含 sidebar）仍渲染，`drillGrid` 区域内部展示空状态。
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/DrillLibrary/Views/DrillListView.swift` L32–L39，当前逻辑为 `if isLoading → skeleton / else if empty → emptyState / else → mainContent`，应改为 `mainContent` 常驻，grid 区域内部分支处理 empty/skeleton。

---

### S-02 空筛选结果显示"加载中"文案，误导用户
- **类别**：产品规格
- **严重程度**：P1（功能缺陷）
- **位置**：动作库 > 球种筛选「9 球」/「通用」> 空状态视图
- **截图现状**：P1-01-05 和 P1-01-06 中，数据已加载完成（非 loading 状态），但因当前球种下无 Drill 数据，空状态显示"内容加载中，请稍候"+"动作库内容正在准备中"。用户会误以为数据仍在加载。
- **设计预期**：数据加载完成后筛选结果为空时，应显示"该分类暂无训练项目"或类似提示文案，而非"加载中"。仅在 `isLoading == true` 时才显示加载提示。
- **修复方向**：`emptyState` 需区分三种场景：(1) 搜索无结果 → "没有找到相关动作"；(2) 筛选无结果（球种/分类均无数据） → "该分类暂无训练项目"；(3) 数据首次加载 → skeleton（已有）。当前逻辑仅根据 `searchText.isEmpty` 二分判断，缺少对筛选空结果的第三分支。
- **路由至**：swiftui-developer
- **代码提示**：`DrillListView.swift` L210–L218 `emptyState` 计算属性；`DrillListViewModel` 中需暴露筛选状态信息。

---

### S-03 搜索栏使用 btBGSecondary 而非 btBGTertiary
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：动作库 > 搜索栏
- **截图现状**：搜索栏背景为白色（btBGSecondary = #FFFFFF），比页面背景（btBG = #F2F2F7）更亮，视觉上呈"凸出"效果。
- **设计预期**：SKILL.md §二 明确 `btBGTertiary`（Light: #E5E5EA）用于输入框背景。输入框应比页面背景略深，呈"凹陷"质感。设计参考 code.html 使用 `bg-surface-container`（#EDEDF2）亦为略深灰色。
- **修复方向**：将搜索栏 `.background(Color.btBGSecondary)` 改为 `.background(Color.btBGTertiary)`。
- **路由至**：swiftui-developer
- **代码提示**：`DrillListView.swift` L78

---

### S-04 球种 Chip 选中态使用硬编码 hex 颜色
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：动作库 > 球种筛选 Chip 行
- **截图现状**：选中的 Chip（如 P1-01-01 "全部"、P1-01-04 "中式台球"）使用深色填充 + 浅色文字，视觉效果正确。
- **设计预期**：SKILL.md §二 规则"禁止在代码中硬编码 hex 值"。当前 `chipActiveFill` 硬编码 `#1C1C1E`（Light）/ `#F2F2F7`（Dark），`chipActiveText` 使用 `UIColor.systemBackground`。应使用 SKILL.md §七 定义的 `BTButtonStyle.darkPill`（`#1C1C1E` 填充 + 白字）或引入对应语义 Token。
- **修复方向**：将 `chipActiveFill` / `chipActiveText` 改为 Design Token 引用（如 `btText` / `Color(uiColor: .systemBackground)`），或直接采用 `BTButton(.darkPill)` 样式。如需在 Assets.xcassets 中定义新的 `btChipActiveFill` Token 亦可。
- **路由至**：swiftui-developer
- **代码提示**：`DrillListView.swift` L15–L23

---

### S-05 收藏心形按钮触摸目标 30pt 低于 HIG 最低 44pt
- **类别**：HIG / 无障碍
- **严重程度**：P2（视觉瑕疵）
- **位置**：动作库 > 网格卡片 > 右上角收藏按钮
- **截图现状**：P1-01-01 各卡片右上角的心形收藏按钮可见但偏小。
- **设计预期**：Apple HIG 要求所有可交互元素触摸目标 >= 44pt。当前代码中收藏按钮 `.frame(width: 30, height: 30)` 仅 30pt，低于最低标准。ref-screenshots 中类似位置的图标按钮尺寸更大。
- **修复方向**：将可点击区域扩大至 44×44pt（视觉图标可保持 14pt 不变，通过增大 frame + contentShape 扩展触摸区域）。
- **路由至**：swiftui-developer
- **代码提示**：`BTDrillCard.swift` L199–L206 `cardBadge` 中收藏按钮

---

### S-06 侧边栏背景使用非标准透明度
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：动作库 > 左侧分类导航栏
- **截图现状**：P1-01-01 ~ P1-01-04 中侧边栏背景为浅灰色半透明，与页面背景有微妙区分。
- **设计预期**：代码使用 `Color.btBGSecondary.opacity(0.6)`（Light）/ `.opacity(0.5)`（Dark），这些是非标准透明度值，不在 Design Token 体系中。侧边栏背景应使用完整的语义色 Token（如 `btBGSecondary` 纯色或 `btBG`），避免自定义 opacity 导致 Dark Mode 下层次混乱。
- **修复方向**：Light Mode 下侧边栏可直接使用 `btBGSecondary` 或 `btBG`；Dark Mode 下使用 `btBGSecondary`。参考 ref-screenshots，训记侧边栏使用与页面背景一致的纯色。
- **路由至**：swiftui-developer
- **代码提示**：`DrillListView.swift` L113

---

### S-07 L0 等级标签与绿色球台缩略图对比度偏低
- **类别**：无障碍 / 视觉打磨
- **严重程度**：P2（视觉瑕疵）
- **位置**：动作库 > 网格卡片 > 左上角 L0 等级徽章
- **截图现状**：P1-01-01 中多张 L0 卡片的等级标签（btPrimary 绿色实底 + 白字）叠在绿色球台缩略图上方。绿色标签与绿色台面相似度高，标签虽可辨识但对比度不够突出，尤其在小尺寸卡片上。L1 蓝色标签（蓝底）在相同位置则明显更易辨识。
- **设计预期**：等级标签应在任何背景上保持清晰可读。ref-screenshots 中标签使用蓝色底色，与内容区形成鲜明对比。WCAG AA 要求 UI 组件对比度 >= 3:1。
- **修复方向**：为放置在球台缩略图上的 BTLevelBadge 添加轻微的深色阴影或半透明深色衬底（类似 PRO 标签的处理方式），确保在绿色背景上的 L0 标签仍可清晰辨识。
- **路由至**：swiftui-developer
- **代码提示**：`BTDrillCard.swift` L174–L177（`BTLevelBadge` overlay）；可参考同文件 L186–L208 PRO 标签的 capsule 样式

---

### 审查总结
- 截图数量：6 张（Light Mode）
- 发现问题：7 项（P0: 0 / P1: 2 / P2: 5）
- 总体评价：动作库新版 sidebar + grid 布局整体实现质量较高，卡片设计美观，球台缩略图提供了良好的视觉识别，分类导航清晰。两个 P1 问题集中在空状态处理逻辑上（侧边栏消失 + 文案误导），修复方案明确且改动范围小。P2 问题主要为 Design Token 硬编码和 HIG 触摸目标合规性，属于打磨项。
- 建议下一步：
  1. 优先修复 S-01 + S-02（空状态布局与文案），可在同一 PR 中完成
  2. 随后处理 S-03 ~ S-06 的 Token 规范化
  3. S-07 作为后续视觉打磨项
  4. 建议补充 Dark Mode 截图进行审查（本次仅覆盖 Light Mode）
