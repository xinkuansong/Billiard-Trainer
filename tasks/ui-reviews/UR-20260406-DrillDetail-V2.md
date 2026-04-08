## UI 审查报告（V2 Delta）— DrillDetailView
日期：2026-04-06

审查对象：动作详情页（V2 修复后截图）
V2 截图来源：P1-03-01（顶部）、P1-03-02（底部滚动）
设计参考：P1-03 code.html + screen.png, ref-screenshots/04-exercise-library/05–06
前次报告：`UR-20260406-DrillDetail-Screenshot.md`（S-01 ~ S-09）

---

### 前次问题追踪

| ID | 标题 | V1 级别 | V2 状态 | 说明 |
|----|------|---------|---------|------|
| S-01 | 「查看精讲」按钮样式不符 | P1 | ✅ FIXED | 已改用 `BTButtonStyle.primary`（全宽绿色填充、白色文字），与 `code.html` L209 一致 |
| S-02 | 备注占位符使用 btPrimary 绿色 | P1 | ✅ FIXED | 铅笔图标 `.btTextSecondary`、占位文字 `.btTextTertiary`，均为灰色调，符合设计 |
| S-03 | ballType 显示原始值 "chinese8" | P1 | ✅ FIXED | 标签行正确显示"中式台球"，`ballTypeDisplayNames` 映射已生效 |
| S-04 | 导航栏缺少分享按钮 | P2 | 🟡 OPEN | 右侧仍仅有收藏心形图标；设计 `code.html` L112–114 要求分享按钮 |
| S-05 | 球台 Canvas 叠层元素缺失 | P2 | 🟡 OPEN | 仍仅有左下角重播按钮；缺少设计中的右上角收藏胶囊、右下角全屏图标 |
| S-06 | 导航栏标题呈现 btPrimary 绿色 | P2 | 🟡 OPEN | 标题"三球连打"仍为绿色；应为系统 label 色（btText），见下方 N-01 补充分析 |
| S-07 | 视频缩略图尺寸与比例偏差 | P2 | 🟡 OPEN | 仍为 100×72pt 矩形；设计要求 56×56pt 正方形（`code.html` L267） |
| S-08 | 训练维度进度条布局 | P2 | ✅ FIXED | 已改为两行式：上行（标签 + 百分比两端对齐），下行（进度条全宽），与设计一致 |
| S-09 | 达标标准标题在卡片外部 | P2 | 🟡 OPEN | "达标标准"标题仍在 `.btBGSecondary` 卡片外；其余 section（训练要点/训练维度/真人示范）标题均在卡片内 |

**小结**：3 项 P1 全部修复 ✅；6 项 P2 中修复 1 项，仍有 5 项 OPEN。

---

### 新发现问题

### N-01 导航栏标题绿色问题根因补充（S-06 升级分析）
- **类别**：HIG / Design Token
- **严重程度**：P2
- **位置**：动作库 > 动作详情 > 导航栏 inline title
- **现状**：V2 截图确认导航标题"三球连打"为 btPrimary 绿色，返回箭头同为绿色——说明全局 `.tint(.btPrimary)` 同时影响了 inline title
- **预期**：Apple HIG 要求 inline 导航标题使用系统 label 色（`Color.primary` / btText）；tint 仅应影响可交互元素（返回按钮、toolbar button），不应染色标题文字
- **修复方向**：在 `DrillDetailView` toolbar 中添加 `ToolbarItem(placement: .principal)` 自定义标题视图，显式使用 `.foregroundStyle(.btText)`，确保标题与 tint 解耦：
  ```swift
  ToolbarItem(placement: .principal) {
      Text(drill?.nameZh ?? "加载中")
          .font(.btHeadline)
          .foregroundStyle(.btText)
  }
  ```
  同时移除 `.navigationTitle()` 以避免双重标题
- **路由至**：swiftui-developer
- **代码提示**：`DrillDetailView.swift` L67–68（`.navigationTitle` + `.navigationBarTitleDisplayMode`）

---

### N-02 达标标准 section 卡片结构与其他 section 不一致（S-09 修复方案补充）
- **类别**：布局 / 视觉打磨
- **严重程度**：P2
- **位置**：动作库 > 动作详情 > 达标标准区域
- **现状**："达标标准"标题在白色卡片外部，而训练要点、训练维度、真人示范三个 section 的标题均在各自的 `btBGSecondary` 卡片内部
- **预期**：所有 section 采用统一结构——标题 + 内容均包裹在同一卡片中（`code.html` 每个 `<section>` 均为 `bg-surface-container-lowest rounded-xl p-5` 整体容器）
- **修复方向**：将 `criteriaSection` 的整个 VStack（含标题）包裹进 `.background(.btBGSecondary)` 卡片，与 `coachingSection` / `dimensionsSection` / `videoSection` 对齐：
  ```swift
  VStack(alignment: .leading, spacing: Spacing.sm) {
      Text("达标标准").font(.btHeadline).foregroundStyle(.btText)
      HStack { /* 现有内容 */ }
  }
  .padding(Spacing.lg)
  .background(.btBGSecondary)
  .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
  ```
- **路由至**：swiftui-developer
- **代码提示**：`DrillDetailView.swift` L224–251 `criteriaSection`

---

### N-03 视频缩略图数量不足且形状不符（S-07 细化）
- **类别**：布局 / 产品规格
- **严重程度**：P2
- **位置**：动作库 > 动作详情 > 真人示范区域
- **现状**：V2 截图可见 3 个矩形缩略图（100×72pt），代码生成 5 个；设计要求 6 个 56×56pt 正方形
- **预期**：`code.html` L266–284 定义 6 个 `w-14 h-14`（56×56pt）正方形占位，圆角 `rounded-lg`（BTRadius.sm = 8pt），水平可滚动
- **修复方向**：
  1. 缩略图尺寸改为 `.frame(width: 56, height: 56)`
  2. 数量改为 6（`ForEach(0..<6, ...)`）
  3. 圆角已使用 `BTRadius.sm`，无需改动
- **路由至**：swiftui-developer
- **代码提示**：`DrillDetailView.swift` L386（`ForEach(0..<5`）、L394（`.frame(width: 100, height: 72)`）

---

### 审查总结
- 截图数量：2 张（V2）
- 前次问题 9 项：**4 项 FIXED**（S-01/02/03/08）、**5 项 OPEN**（S-04/05/06/07/09）
- 新发现问题：3 项（N-01/02/03），均为 P2，其中 N-01/N-02 是对 S-06/S-09 的修复方案细化，N-03 是 S-07 的补充
- P0: 0 / P1: 0 / P2: 5 OPEN + 3 NEW = 8 项待处理
- 总体评价：**所有 P1 问题已清零**，页面核心功能与交互符合设计预期。按钮样式、颜色 Token、本地化标签、维度进度条布局四项关键修复质量良好。剩余 P2 项为视觉打磨类问题（导航标题色、卡片结构一致性、叠层元素、缩略图尺寸），不影响功能发布。
- 建议下一步：
  1. **优先修复**：N-01（导航标题色，影响全局 HIG 合规）+ N-02（达标标准卡片结构，改动小）
  2. **二轮打磨**：N-03（缩略图尺寸）→ S-04（分享按钮）→ S-05（Canvas 叠层元素）
  3. S-04 和 S-05 可推迟至功能迭代阶段，不阻塞当前 Phase
