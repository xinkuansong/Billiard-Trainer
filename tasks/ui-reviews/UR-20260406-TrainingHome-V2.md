## UI V2 审查报告 — TrainingHomeView（第二轮截图对照）
日期：2026-04-06

审查对象：训练首页（Training Tab）
截图来源：screenshot-v2/P0-01-01 ~ P0-01-03, P0-02-01（4 张 V2 截图）
对比基线：UR-20260406-TrainingHome-Screenshot.md（9 项：P1:3, P2:6）

---

## 一、前轮问题追踪

| # | 原编号 | 问题摘要 | 原严重程度 | V2 状态 | 说明 |
|---|--------|---------|-----------|---------|------|
| 1 | S-01 | 滚动后导航标题与状态栏时间重叠 | P1 | ⚠️ 仍存在 | P0-01-01 顶部可见「训练₂₈」——系统 inline title 与状态栏时间仍有重叠；P0-01-02（未滚动）正常 |
| 2 | S-02 | 缺少「即将到来」区域 | P1 | ❌ 未修复 | 4 张截图中均无「即将到来」section，代码中无对应实现 |
| 3 | S-03 | 自定义模版空状态同屏两个 Primary 按钮 | P1 | ✅ 已修复 | 代码已将「创建计划」按钮改为 `.buttonStyle(BTButtonStyle.secondary)`（描边样式） |
| 4 | S-04 | 缺少「综合」等级筛选 Chip | P2 | ❌ 未修复 | P0-01-01、P0-01-03 仍为 5 个 Chip（全部/入门/初级/中级/高级），缺少设计要求的「综合」 |
| 5 | S-05 | 待完成 Drill 全部显示 GO! 按钮 | P2 | ❌ 未修复 | P0-01-01 三张卡片全部显示 GO!；P0-01-02 同样三张均 GO!。设计要求仅「当前」卡片显示 GO!，后续卡片显示 ⋮ 菜单 |
| 6 | S-06 | 等级标签「L1 初级」→ 应仅显示「初级」 | P2 | ✅ 已修复 | P0-01-01 标签显示「初级」，P0-01-03 显示「初级」「中级」，均无 L 前缀。代码使用 `drillLevel?.displayName` |
| 7 | S-07 | 副标题单位「组」→ 应为「练」 | P2 | ✅ 已修复 | P0-01-01 显示「测试 · 3 练」，P0-01-02 显示「基础杆法专项 · 2 练」等，单位已改为「练」 |
| 8 | S-08 | 计划卡片缩略图均为相同占位图标 | P2 | ❌ 未修复 | 所有计划卡片仍使用同一绿色渐变 + `figure.pool.swim` 图标，无法区分不同计划。需美术资源，预期内 |
| 9 | S-09 | 底部「开始训练」按钮与列表末项重叠 | P2 | ⚠️ 部分改善 | 代码已增加 `.padding(.bottom, 176)` 底部留白。P0-01-02 标准按钮状态基本不再重叠；但 P0-01-01 的活跃训练条（「训练中 0:46」状态栏）高度大于标准按钮，末项「走位突破计划」仍被部分遮挡 |

---

## 二、新发现问题

### N-01 页面标题 icon 触控目标低于 HIG 44pt 最小值
- **类别**：HIG
- **严重程度**：P2
- **位置**：训练 > TrainingHomeView > pageHeader > 右侧图标按钮（person.2 + ellipsis）
- **截图现状**：P0-01-02 右上角两个功能图标按钮视觉尺寸偏小
- **设计预期**：P0-01 design（code.html line 108–112）中两个按钮均为 `w-[44px] h-[44px]`，满足 HIG 44pt 最小触控目标。SKILL.md §十「Apple HIG 合规」要求 >= 44pt
- **修复方向**：将 `pageHeader` 中 `.frame(width: 36, height: 36)` 改为 `.frame(width: 44, height: 44)`，确保触控目标达标
- **路由至**：swiftui-developer
- **代码提示**：`Features/Training/Views/TrainingHomeView.swift` line 74、93 的 `.frame(width: 36, height: 36)`

---

### N-02 页面标题使用 btTitle (22pt) 而非设计的 34pt 大标题
- **类别**：Design Token
- **严重程度**：P2
- **位置**：训练 > TrainingHomeView > pageHeader > 标题「训练」
- **截图现状**：P0-01-02 标题「训练」字号约 22pt，使用自定义 `pageHeader` 中 `.font(.btTitle)` 渲染
- **设计预期**：P0-01 design（code.html line 106）标题为 `text-[34px]` = 34pt，与 iOS Large Title 标准一致。P0-02 design（code.html line 118）同样 `text-[34px]`。Typography SKILL.md §三 定义 `btLargeTitle = 34pt .bold .rounded` 用于「页面大标题」
- **修复方向**：方案 A（推荐）——移除自定义 `pageHeader`，改用系统 `.navigationTitle("训练")` + `.navigationBarTitleDisplayMode(.large)` + `.toolbar` 添加右侧按钮，由系统自动处理 34pt Large Title 和 inline 折叠。方案 B——将自定义 header 字号改为 `.btLargeTitle`（34pt），但仍需解决 S-01 的 inline 折叠重叠问题
- **路由至**：swiftui-developer
- **代码提示**：`Features/Training/Views/TrainingHomeView.swift` line 62 `.font(.btTitle)` → `.btLargeTitle`，或重构为系统 NavigationTitle

---

### N-03 活跃训练条状态下底部留白不足
- **类别**：布局
- **严重程度**：P2
- **位置**：训练 > TrainingHomeView > 底部固定区域（活跃训练条模式）
- **截图现状**：P0-01-01 底部显示组合训练条「开始训练 | 训练中 0:46 <」，该条高度大于标准「开始训练」单按钮，导致「走位突破计划」卡片下半部仍被遮挡
- **设计预期**：列表内容在完全滚动到底时应不被底部固定元素遮挡。当前 `.padding(.bottom, 176)` 仅按标准按钮高度计算
- **修复方向**：检测是否有活跃训练 session，动态增加底部 padding（例如活跃训练条模式下加至 ~200pt），或使用 `.safeAreaInset(edge: .bottom)` 让系统自动处理
- **路由至**：swiftui-developer
- **代码提示**：`Features/Training/Views/TrainingHomeView.swift` line 29 `.padding(.bottom, 176)` — 活跃训练条场景需更大值

---

### 审查总结
- 前轮 9 项：已修复 3（S-03、S-06、S-07） / 部分改善 2（S-01、S-09） / 未修复 4（S-02、S-04、S-05、S-08）
- 新发现：3 项（P2: 3）
- 总体评价：V2 在细节层面有明显改进——等级标签格式、副标题单位、双 Primary 按钮等问题已修复，底部 padding 也有所增加。但两个 P1 问题中仅 S-03 被修复，S-01（导航标题重叠）和 S-02（缺少「即将到来」section）仍未解决。S-05（GO! 按钮逻辑）是影响产品体验一致性的重要项。空状态（P0-02-01）实现质量良好，整体结构与设计高度对齐。
- 建议下一步：
  1. **优先解决 S-01**：重构为系统 `.navigationTitle` + `.toolbar`，同时解决 N-02（标题字号）和 S-01（inline 折叠重叠）
  2. **实现 S-02**（即将到来 section）——确认是否在当前 Phase 范围内
  3. **修复 S-05**（GO! 按钮逻辑）——仅为「当前待执行」Drill 显示 GO!，后续显示 ⋮ 菜单
  4. **批量处理 P2**：N-01（icon 触控目标）+ N-03（活跃训练条 padding）+ S-04（综合 Chip）可一次性修改
  5. **S-08 留后**：计划缩略图差异化依赖美术资源，优先级最低
