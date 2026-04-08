## UI 审查报告 — DrillListView V2 Delta（截图对照）
日期：2026-04-06

审查对象：动作库列表页（左侧栏 + 右侧 2 列网格布局）
截图来源：P1-01-01 ~ P1-01-04（4 张实机截图，Light Mode）
设计参考：P1-01 code.html + screen.png（配色/字体参考）
前次审查：UR-20260406-DrillLibrary-Screenshot.md（S-01 ~ S-07）
备注：左侧分类导航栏 + 右侧 2 列网格为已确认的新设计，不作为偏差项

---

### 前次问题追踪（S-01 ~ S-07）

| ID | 问题 | 严重程度 | V2 状态 | 说明 |
|----|------|----------|---------|------|
| S-01 | 空筛选结果时侧边栏消失，布局断裂 | P1 | ✅ FIXED | `mainContent` 始终渲染 sidebar + grid；空状态移入 `drillGrid` 内部 `gridEmptyState`，侧边栏常驻 |
| S-02 | 空筛选结果显示"加载中"文案 | P1 | ✅ FIXED | `gridEmptyState` 现在区分搜索无结果（"没有找到相关动作"）与筛选无结果（"该分类暂无训练项目"），不再误导 |
| S-03 | 搜索栏使用 btBGSecondary 而非 btBGTertiary | P2 | ✅ FIXED | `DrillListView.swift` L71 已改为 `.background(Color.btBGTertiary)`，搜索栏呈现正确的凹陷质感 |
| S-04 | 球种 Chip 选中态使用硬编码 hex 颜色 | P2 | 🔴 OPEN | `DrillListView.swift` L15–23 仍使用 `Color(red:green:blue:)` 硬编码 `#1C1C1E`（Light）/ `#F2F2F7`（Dark），未引用 Design Token |
| S-05 | 收藏心形按钮触摸目标 30pt < HIG 44pt | P2 | 🔴 OPEN | `BTDrillCard.swift` L203 仍为 `.frame(width: 30, height: 30)`，未扩展 `contentShape` |
| S-06 | 侧边栏背景使用非标准透明度 | P2 | ✅ FIXED | `DrillListView.swift` L106 已改为 `.background(Color.btBGSecondary)` 纯色，无自定义 opacity |
| S-07 | L0 等级标签与绿色球台缩略图对比度偏低 | P2 | 🔴 OPEN | L0 badge（btPrimary #1A6B3C）叠在台面（btTableFelt #1B6B3A）上仍难辨识；底部渐变仅覆盖 table 底部 32pt，不影响左上角 badge 区域 |

**前次总计**：7 项 → 4 FIXED / 3 OPEN

---

### 新发现问题

### N-01 球种 Chip "9 球" 与设计稿 "九球" 命名不一致
- **类别**：产品规格 / 内容
- **严重程度**：P2（视觉瑕疵）
- **位置**：动作库 > 球种筛选 Chip 行
- **截图现状**：P1-01-01 ~ P1-01-04 中第三个球种 Chip 显示为 "9 球"（阿拉伯数字 + 空格 + 球）。
- **设计预期**：设计参考 code.html L124 使用 "九球"（中文数字，无空格）。`docs/04-功能规划.md` 中亦用"九球"。应保持全 App 术语一致。
- **修复方向**：将 `BallTypeFilter` 枚举的 `nineBall` case rawValue 从 `"9 球"` 改为 `"九球"`。
- **路由至**：swiftui-developer / content-engineer
- **代码提示**：`BallTypeFilter` 枚举定义处（grep `BallTypeFilter`），修改 rawValue

---

### N-02 侧边栏选中项背景与未选中项对比度不足
- **类别**：视觉打磨
- **严重程度**：P2（视觉瑕疵）
- **位置**：动作库 > 左侧分类导航栏 > 选中态
- **截图现状**：P1-01-01 中 "全部" 选中态，视觉上选中与未选中项的区分主要依赖文字颜色（btPrimary 绿 vs btTextSecondary 灰）和左侧 3px 绿色指示条。选中项背景 `btBG`（#F2F2F7）与侧边栏底色 `btBGSecondary`（#FFFFFF）差异仅约 5% 亮度，在小尺寸侧边栏上不够醒目。
- **设计预期**：选中项应有明确的视觉区分。P1-01-03 中 "基础功" 选中态的绿色指示条可见，但整体选中行的背景对比偏弱。
- **修复方向**：可考虑选中项使用 `btPrimaryMuted`（btPrimary 10% opacity）作为背景色，与绿色指示条 + 绿色文字形成统一的品牌色选中态。或保持现状（有绿色指示条已可辨识，仅为打磨建议）。
- **路由至**：swiftui-developer
- **代码提示**：`DrillListView.swift` L120 `.background(isSelected ? Color.btBG : .clear)` → 可改为 `Color.btPrimaryMuted`

---

### 审查总结

- 截图数量：4 张（Light Mode）
- 前次问题：4/7 已修复（S-01、S-02、S-03、S-06），3 项保持 OPEN（S-04、S-05、S-07）
- 新发现问题：2 项（P0: 0 / P1: 0 / P2: 2）
- 当前遗留总计：5 项（P0: 0 / P1: 0 / P2: 5）
- 总体评价：V2 修复了全部 P1 问题，空状态逻辑和搜索栏 Token 均已正确修复，侧边栏不再使用非标准透明度。整体质量提升显著，剩余问题均为 P2 打磨项（硬编码色值、触摸目标、标签对比度、命名一致性、选中态对比度），不影响核心功能。
- 建议下一步：
  1. 将 S-04 chipActiveFill 改为 Design Token 引用（如 `btText` / `btBG`），消除硬编码
  2. S-05 收藏按钮扩大 contentShape 至 44×44pt
  3. S-07 为 L0 badge 添加轻微暗色衬底或 shadow，确保在绿色台面上可辨识
  4. N-01 统一球种命名为"九球"
  5. N-02 视情况优化侧边栏选中态背景色
  6. 建议补充 Dark Mode 截图进行审查（本次仅覆盖 Light Mode）
