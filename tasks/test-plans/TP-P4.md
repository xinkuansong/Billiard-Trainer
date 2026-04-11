# 人工测试计划 — Phase 4 Training Log（训练记录）

> **使用方式**：在模拟器或真机上逐条执行，通过则勾选 `[x]`，失败则记录问题描述。
> **时机**：P4 功能代码 + 自动化测试完成后，QA Reviewer 验收前。
> **更新记录**：2026-04-06 — 反映 R-UI 后 ActiveTrainingView（毛玻璃顶栏 + 5 键底栏）、DrillRecordView（BTSetInputGrid TextField 输入）、TrainingNoteView（极简沉浸式）、TrainingSummaryView（2×2 统计 + 分组明细 + 分享入口）、CustomPlanBuilderView（自定义步进器 + 缩略图 + 齿轮设置弹层）重构（V2）

> **执行进度**（由 Manual Test Runner 自动维护）：已完成 92/98 项（4 失败 · 1 已知问题 · 1 跳过）+ 1 新发现缺失功能 · 最后更新：2026-04-11

---

## 前置条件

- [x] Debug 构建成功（Scheme: QiuJi, Destination: iPhone 17 Pro Simulator）
- [x] 全新安装（删除已有 App 后重新安装）
- [x] 无登录状态（匿名用户）
- [x] P3 Drill Library 功能正常可用（训练依赖 Drill 数据）

---

## 一、视觉与 UI

| # | 页面 | 检查项 | 通过 |
|---|------|--------|------|
| V-01 | TrainingHomeView | 无激活计划时 BTEmptyState（选择训练计划 CTA + 自由记录链接）| [x] |
| V-02 | TrainingHomeView | BTSegmentedTab 计划浏览切换正常 | [x] |
| V-03 | TrainingHomeView | 有激活计划时今日安排卡片展示 Drill 列表 + 完成项标记 | [x] |
| V-04 | TrainingHomeView | 球种/分类筛选 Chip 样式与动作库一致 | [x] |
| V-05 | TrainingHomeView | 固定底部「开始今日训练」按钮 | [x] |
| V-06 | PlanListView | 计划按等级分组，标题/描述/时长/Drill 数可读 | [x] |
| V-07 | PlanListView | 免费计划（beginner/cueball）无锁定，付费计划有 BTPremiumLock | [x] |
| V-08 | PlanDetailView | 总周期、每周频次、单次时长、目标等级信息完整 | [x] |
| V-09 | PlanDetailView | 按周/天展示 Drill 安排，可展开/折叠 | [x] |
| V-10 | ActiveTrainingView | 毛玻璃顶栏：4 图标（play/timer/filter/checkmark）+ 计划名 + 进度文字 | [x] |
| V-11 | ActiveTrainingView | 5 键底部工具栏带文字标签（最小化/更多/添加/心得/切换） | [x] |
| V-12 | ActiveTrainingView | 计时器数字清晰，开始/暂停状态明确 | [x] |
| V-13 | DrillRecordView | 当前 Drill 名称 + 进度文字 + BTExerciseRow 展示 | [x] |
| V-14 | DrillRecordView | BTSetInputGrid：每行含组号 + TextField（数字键盘）+ 目标球数 + 溢出菜单 | [x] |
| V-15 | DrillRecordView | 热身行有橙色「热」标记（btWarning 色） | [x] |
| V-16 | DrillRecordView | 成功率实时显示（百分比 + 进度条） | [ ] | <!-- 失败 P1：无百分比和进度条 FL-006 -->
| V-17 | TrainingNoteView | 极简布局：2 行引导提示 + 全屏无边框 TextEditor | [x] |
| V-18 | TrainingNoteView | 固定底栏：左「跳过」+ 右「完成」按钮 | [x] |
| V-19 | TrainingSummaryView | 2×2 统计网格（总时长/训练项目/总组数/成功率） | [x] |
| V-20 | TrainingSummaryView | 全宽成功率进度条卡 | [x] |
| V-21 | TrainingSummaryView | 每个 Drill 卡片展示 BTLevelBadge + 名称 + 分组明细展开 | [x] |
| V-22 | TrainingSummaryView | 底部固定操作栏：「保存训练」primary +「生成分享图」secondary +「查看历史记录」tertiary 文字按钮 | [x] |
| V-23 | CustomPlanBuilderView | Plan Info Card（编辑图标 + 名称 TextField + 统计摘要） | [x] |
| V-24 | CustomPlanBuilderView | Drill 行：拖拽手柄 + 迷你球台缩略图 + 名称 + 「X组·Y球」+ 齿轮图标 | [] | <!-- 失败 P1：拖拽手柄不生效 -->
| V-25 | CustomPlanBuilderView | 自定义 -/数字/+ 步进器（非原生 Stepper） | [x] |
| V-26 | TrainingShareView | BTShareCard 预览 + 字体选择 + 隐藏成功率开关 + 分享按钮 | [x] |

---

## 二、Dark Mode

| # | 页面 | 检查项 | 通过 |
|---|------|--------|------|
| D-01 | TrainingHomeView | 背景深色，空状态/计划列表文字可读 | [x] |
| D-02 | PlanListView | 计划卡片 Dark 下边框/背景对比度充足 | [x] |
| D-03 | PlanDetailView | Drill 安排表格 Dark 下行间区分清晰 | [x] |
| D-04 | ActiveTrainingView | 毛玻璃顶栏 Dark 下半透明效果正常 | [x] |
| D-05 | ActiveTrainingView | 5 键底栏 Dark 下图标 + 文字标签可读 | [x] |
| D-06 | DrillRecordView | BTSetInputGrid TextField Dark 下边框可见 | [x] |
| D-07 | DrillRecordView | 热身橙色标记 Dark 下可辨 | [x] |
| D-08 | TrainingNoteView | TextEditor Dark 下文字可读，无白底残留 | [x] |
| D-09 | TrainingSummaryView | 2×2 统计网格 + Drill 卡片 Dark 下对比度充足 | [x] |
| D-10 | TrainingSummaryView | 缩略图 Dark 描边 0.5pt btSeparator 可见 | [x] |
| D-11 | CustomPlanBuilderView | 迷你球台缩略图 Dark 描边可见 | [] | <!-- 失败 P1：没有缩略图 -->
| D-12 | BTPremiumLock | 付费计划遮罩 Dark 下不与背景融合 | [x] |

---

## 三、动画与过渡

| # | 场景 | 检查项 | 通过 |
|---|------|--------|------|
| A-01 | 训练首页 → 开始训练 | 过渡动画流畅 | [x] |
| A-02 | Drill 间滑动切换 | 底栏切换按钮切 Drill 响应自然 | [x] |
| A-03 | 训练完成 → 心得页 → 总结页 | 过渡无闪烁 | [x] |
| A-04 | 计时器运行 | 数字更新流畅，无抖动 | [x] |
| A-05 | BTSetInputGrid 添加/删除行 | 行增减有动画，列表不跳动 | [x] |

---

## 四、用户流程

### 流程 1：按计划训练（完整流程）

**步骤**：
1. 启动 App → 训练 Tab
2. 训练首页显示空状态 → 点击引导按钮进入计划列表
3. 选择「beginner（入门基础）」计划 → 进入计划详情
4. 点击「开始此计划」激活计划
5. 返回训练首页 → 确认今日安排卡片显示 Drill 列表
6. 点击「开始今日训练」
7. 毛玻璃顶栏显示计划名 + 进度；5 键底栏可见
8. 在第一个 Drill 记录界面：BTSetInputGrid 显示一行
9. 在 TextField 中输入进球数 7（数字键盘），目标球数 10
10. 点击底栏「+添加」→ 新增一行 → 输入进球数 8
11. 点击底栏「切换」→ 滑到第二个 Drill
12. 录入 1 组数据 → 点击底栏「心得」
13. 心得页面输入「练习手感不错」→ 点击「完成」
14. 总结页查看 2×2 统计网格 + 各 Drill 成功率
15. 点击「保存训练」

**预期结果**：完整训练流程顺畅

- [x] 毛玻璃顶栏 4 图标 + 计划名 + 进度正确
- [x] 5 键底栏文字标签清晰可辨
- [x] BTSetInputGrid TextField 数字键盘弹出
- [没有成功率显示] 每组成功率实时计算正确（如 7/10 = 70%）
- [x] 心得页极简布局：引导文字 + TextEditor + 底栏双按钮
- [x] 总结页 2×2 统计网格数据正确
- [x] 各 Drill 卡片可展开查看每组明细
- [x] 「保存训练」可点击

### 流程 2：自由记录模式

**步骤**：
1. 训练 Tab → 点击「自由记录」
2. 进入空白训练界面 → 底栏「+添加」添加 Drill
3. 录入 1 组数据 → 完成
4. 心得页 → 点击「跳过」→ 查看总结 → 保存

**预期结果**：无计划情况下也能正常完成训练记录

- [x] 自由记录入口可正常进入
- [x] 可手动添加 Drill
- [x] 「跳过」心得后训练仍能保存

### 流程 3：付费计划锁定

**步骤**：
1. 计划列表 → 点击一个付费计划（如 intermediate）
2. 确认详情页有 BTPremiumLock 遮罩
3. 点击「解锁全部内容」

**预期结果**：付费计划不可直接使用

- [x] 付费计划有遮罩
- [x] 免费计划（beginner/cueball）无遮罩，可正常激活

### 流程 4：训练持久化验证

**步骤**：
1. 完成流程 1 并保存
2. 强制退出 App（上滑关闭）
3. 重新打开 App
4. 检查训练首页今日已完成状态
5. 切换到历史 Tab → 确认今天有训练记录

**预期结果**：训练数据持久化成功

- [x] 重启后今日训练项有完成标记
- [x] 历史 Tab 今天有记录
- [x] 数据未丢失

### 流程 5：自定义训练计划

**步骤**：
1. 训练 Tab → 自定义计划入口
2. Plan Info Card 中输入计划名称
3. 添加 2-3 个 Drill（从动作库选择）
4. 点击 Drill 行齿轮图标 → DrillSettingsSheet 半屏弹出
5. 调整组数和球数（自定义步进器 -/+）
6. 关闭弹层 → 确认 Drill 行「X组·Y球」已更新
7. 保存计划

**预期结果**：自定义计划创建流程完整

- [x] Plan Info Card 名称可编辑，统计摘要显示
- [x] Drill 行含缩略图 + 名称 + 参数
- [x] DrillSettingsSheet 步进器正常工作
- [x] 移除 Drill 功能正常
- [x] 保存后可在计划列表中找到

### 流程 6：训练分享

**步骤**：
1. 完成一次训练 → 总结页
2. 点击「分享」入口
3. TrainingShareView 展示 BTShareCard 预览（toolbar 分享图标入口）
4. 切换字体选择
5. 开启/关闭「隐藏成功率」
6. 点击分享按钮

**预期结果**：分享卡片预览正确，定制选项生效

- [x] BTShareCard 布局正确（logo + 标题 + Drill 行 + 统计 + footer）
- [x] 字体切换实时反映在预览中
- [x] 隐藏成功率选项生效
- [x] 分享 Sheet 正常弹出

---

## 五、交互响应

| # | 场景 | 检查项 | 通过 |
|---|------|--------|------|
| I-01 | BTSetInputGrid TextField | 数字键盘弹出，输入区不被底栏遮挡 | [x] |
| I-02 | 底栏「+添加」 | 点击后新增一行，列表滚动到新行 | [x] |
| I-03 | 溢出菜单删除行 | 点击溢出菜单 → 删除后列表更新 | [x] |
| I-04 | 底栏「切换」 | 切换到下一/上一个 Drill，响应灵敏 | [底栏是切换回训练列表和当前drill，合理] |
| I-05 | 计时器开始/暂停 | 顶栏 play 按钮切换即时，计时准确 | [x] |
| I-06 | 心得 TextEditor | 键盘弹出时页面上移，文字输入区可见 | [x] |
| I-07 | 总结页 Drill 卡片展开 | 点击展开/折叠每组明细流畅 | [没有展开和折叠，能接受] |
| I-08 | DrillSettingsSheet | 半屏弹层（.medium detent）拖拽交互正常 | [这是什么功能] |
| I-09 | 自定义步进器 | -/+ 按钮点击，数值在合理范围内增减 | [x] |

---

## 六、边界场景

| # | 场景 | 检查项 | 通过 |
|---|------|--------|------|
| E-01 | 首次启动无计划 | 训练首页显示 BTEmptyState | [x] |
| E-02 | 飞行模式下训练 | 离线状态下完整记录训练并保存到 SwiftData | [x] |
| E-03 | 进球数 > 目标球数 | 输入异常数据时有提示或自动修正 | [x] |
| E-04 | 进球数为 0 | 允许录入 0 进球，成功率显示 0% | [x] |
| E-05 | 只录 1 组就完成 | 最少 1 组数据即可完成 Drill | [x] |
| E-06 | 训练中 App 进后台 | 返回前台后计时器和数据不丢失 | [计时器未正常运行，切到后台时，计时会停止，切换回来才会继续，数据不丢失] |
| E-07 | 心得跳过 | 点击「跳过」后训练正常保存，心得字段为空 | [x] |
| E-08 | 心得返回训练 | 心得页点击返回（onBack）可继续训练 | [x] |

---

## 七、设备矩阵

> 在不同屏幕尺寸上各走一遍流程 1。

| # | 设备 | 核心流程通过 | 布局正常 | 备注 |
|---|------|------------|---------|------|
| DM-01 | iPhone SE 3rd（4.7"） | [x] | [x] | 注意底栏 5 按钮在小屏上是否挤压 |
| DM-02 | iPhone 17 Pro（6.3"） | [x] | [x] | |
| DM-03 | iPhone 17 Pro Max（6.9"） | [x] | [x] | |

---

## 八、可访问性

| # | 检查项 | 通过 |
|---|--------|------|
| AC-01 | Dynamic Type 最大字号下训练首页布局不溢出 | [x] |
| AC-02 | Dynamic Type 最大字号下 BTSetInputGrid 输入框仍可用 | [x] |
| AC-03 | VoiceOver 可朗读计划名称和 Drill 名称 | [x] |

---

## 九、性能

| # | 指标 | 阈值 | 通过 |
|---|------|------|------|
| PF-01 | 开始训练到首个 Drill 记录界面加载时间 | < 1 秒 | [x] |
| PF-02 | 训练中 CPU 占用（计时器运行时） | < 15% | [x] |
| PF-03 | 保存训练（含 10+ 组数据）耗时 | < 1 秒 | [x] |
| PF-04 | 正常训练流程内存峰值 | < 80 MB | [x] |

---

## 测试结果

| 项目 | 内容 |
|------|------|
| 测试人 | song |
| 日期 | 2026-04-11 |
| 设备 | iPhone 17 Pro Simulator + iPhone SE 3rd + iPhone 17 Pro Max |
| 构建版本 | Debug |
| 总体结论 | **附条件通过**（92/98 通过，4 失败，1 已知问题，1 跳过，1 新发现缺失功能；详见下方） |

### 发现的问题

| # | 严重程度 | 页面/流程 | 描述 | 关联检查项 |
|---|---------|----------|------|-----------|
| 1 | P1 | DrillRecordView | 成功率实时显示缺失：无百分比数字和进度条 | V-16, Flow1-④ (FL-006) |
| 2 | P1 | ActiveTrainingView | 一组训练结束后无休息倒计时弹出；需支持：(1) 休息时间可设置 (2) 锁屏后显示倒计时（Live Activity / 常亮） | 新发现 (FL-007) |
| 3 | P2 | CustomPlanBuilderView | Drill 行拖拽手柄不生效；迷你球台缩略图缺失（Light + Dark） | V-24, D-11 (FL-008) |
| 4 | P3 | ActiveTrainingView | 计时器后台暂停：App 进后台时计时停止，返回前台后继续；数据不丢失 | E-06 (FL-009) |
| 5 | Info | 交互偏差 | I-04「切换」底栏为列表/Drill 切换（与规格不同但合理）；I-07 总结页无展开折叠（可接受）；I-08 DrillSettingsSheet 半屏弹层功能不明确 | I-04, I-07, I-08 |
