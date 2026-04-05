# P4 — Training Log（训练记录）

> **目标**：完整的训练记录流程（按计划/自由记录）、官方训练计划浏览与激活、自定义计划。
> **前置 Phase**：P3 通过 QA

---

## T-P4-01 官方训练计划 JSON 生产（6 套）

- **负责角色**：Content Engineer
- **前置依赖**：T-P3-01（Drill JSON 已有）
- **产出物**：`Resources/Plans/plan_beginner.json` 等 6 个文件

### DoD

- [ ] 6 套计划全部生产：plan_beginner / plan_cueball / plan_positioning / plan_intermediate / plan_advanced / plan_fullskill
- [ ] 每套计划 `drillId` 引用均存在于 `Resources/Drills/index.json`（无悬空引用）
- [ ] `isPremium` 分配：前两套（beginner、cueball）为 `false`，其余为 `true`
- [ ] 符合单次会话结构（热身 → 专项 → 综合 → 复盘，见 `docs/07` § 2）
- [ ] `OfficialPlan` Swift 结构体可 Codable 解析全部计划

---

## T-P4-02 训练 Tab — 今日计划视图

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P4-01, T-P2-01
- **产出物**：`Features/Training/Views/TrainingHomeView.swift`

### DoD

- [x] 有激活计划时：展示「今日训练」（本日 Drill 列表 + 完成状态）
- [x] 无激活计划时：空状态视图，引导「选择一个计划开始」
- [x] 「自由记录」入口（不依赖计划直接开始）
- [x] 今日已完成的训练有对勾标记

---

## T-P4-03 官方计划列表与详情页（F3）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P4-01
- **产出物**：`Features/Training/Views/PlanListView.swift`、`PlanDetailView.swift`

### DoD

- [ ] 计划列表按等级分组（L0→L1 / L1→L2 / L2 / L3 / L4）
- [ ] 详情页展示：总周期、每周频次、单次时长、目标等级
- [ ] 按周/天展示 Drill 安排（可展开）
- [ ] 「开始此计划」按钮激活计划（写入 `UserActivePlan`）
- [ ] 付费计划用 `BTPremiumLock` 遮罩

---

## T-P4-04 开始训练流程（F5）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P4-02
- **产出物**：`Features/Training/Views/ActiveTrainingView.swift`

### DoD

- [ ] 支持两种模式：按计划（今日 Drill 预加载）/ 自由记录（空白，用户手动添加 Drill）
- [ ] 进入第一个 Drill 记录界面**不超过 3 步操作**
- [ ] 计时器（可手动开始/暂停，或跳过不计时）
- [ ] Drill 列表可滑动到下一个

---

## T-P4-05 训练中 Drill 记录界面（F5）

- **负责角色**：SwiftUI Developer
- **设计参考**：PNG: `ui_design/tasks/P0-04/stitch_task_p0_04_04/screen.png`
- **前置依赖**：T-P4-04
- **产出物**：`Features/Training/Views/DrillRecordView.swift`

### DoD

- [ ] 显示当前 Drill 名称 + 简要说明
- [ ] 每组记录：`目标球数`（可调，默认来自 Drill JSON）+ `进球数`（数字键盘输入）
- [ ] 「+ 添加一组」按钮，可添加多组
- [ ] 每组成功率实时计算显示
- [ ] 「完成此 Drill」→ 滑动到下一个
- [ ] 长按可删除某组记录
- [ ] 使用 BTSetInputGrid + BTExerciseRow 组件
- [ ] 使用 R0 BT* 组件，不自建临时组件
- [ ] 布局对照 `tasks/UI-IMPLEMENTATION-SPEC.md` 中对应设计截图
- [ ] Light + Dark `#Preview` 通过视觉检查
- [ ] 如有组件 API 或设计解读变更，追加 DR/PD 至 `tasks/IMPLEMENTATION-LOG.md` 并更新 `UI-IMPLEMENTATION-SPEC.md` Changelog

---

## T-P4-06 心得备注输入（F5）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P4-05
- **产出物**：`Features/Training/Views/TrainingNoteView.swift`

### DoD

- [ ] 训练结束时出现心得输入页（可跳过）
- [ ] 多行文本输入，无字数强制限制，有软提示
- [ ] 键盘出现时界面上移（`KeyboardAwarePadding` 或 `.ignoresSafeArea(.keyboard)`）
- [ ] 使用 R0 BT* 组件，不自建临时组件
- [ ] 布局对照 `tasks/UI-IMPLEMENTATION-SPEC.md` 中对应设计截图
- [ ] Light + Dark `#Preview` 通过视觉检查
- [ ] 如有组件 API 或设计解读变更，追加 DR/PD 至 `tasks/IMPLEMENTATION-LOG.md` 并更新 `UI-IMPLEMENTATION-SPEC.md` Changelog

---

## T-P4-07 训练完成总结页（F5）

- **负责角色**：SwiftUI Developer
- **设计参考**：PNG: `ui_design/tasks/P0-06/stitch_task_p0_06_trainingsummaryview_02/screen.png`
- **前置依赖**：T-P4-05, T-P4-06
- **产出物**：`Features/Training/Views/TrainingSummaryView.swift`

### DoD

- [ ] 展示：总时长、训练项目数、总组数、整体成功率
- [ ] 各 Drill 成功率列表（从高到低排序）
- [ ] 「保存训练」按钮触发持久化
- [ ] 「查看历史」快捷入口（跳转到历史 Tab）
- [ ] 使用 BTShareCard 容器
- [ ] 使用 R0 BT* 组件，不自建临时组件
- [ ] 布局对照 `tasks/UI-IMPLEMENTATION-SPEC.md` 中对应设计截图
- [ ] Light + Dark `#Preview` 通过视觉检查
- [ ] 如有组件 API 或设计解读变更，追加 DR/PD 至 `tasks/IMPLEMENTATION-LOG.md` 并更新 `UI-IMPLEMENTATION-SPEC.md` Changelog

---

## T-P4-08 TrainingSession 持久化（F5）

- **负责角色**：Data Engineer
- **前置依赖**：T-P2-02, T-P4-07
- **产出物**：`TrainingSessionRepository` 使用整合

### DoD

- [ ] 点击「保存训练」后，`TrainingSession`（含 `DrillEntry`、`DrillSet`）写入 SwiftData
- [ ] 保存成功后 SyncQueue 中加入同步任务
- [ ] 保存失败时（如磁盘满）有中文错误提示，不崩溃
- [ ] 使用 R0 BT* 组件，不自建临时组件
- [ ] 布局对照 `tasks/UI-IMPLEMENTATION-SPEC.md` 中对应设计截图
- [ ] Light + Dark `#Preview` 通过视觉检查
- [ ] 如有组件 API 或设计解读变更，追加 DR/PD 至 `tasks/IMPLEMENTATION-LOG.md` 并更新 `UI-IMPLEMENTATION-SPEC.md` Changelog

---

## T-P4-09 自定义训练计划（F4）

- **负责角色**：SwiftUI Developer + Data Engineer
- **前置依赖**：T-P3-06, T-P4-03
- **产出物**：`Features/Training/Views/CustomPlanBuilderView.swift`

### DoD

- [ ] 可新建自定义计划（命名 + 每周天数设置）
- [ ] 从动作库选择 Drill，设置每个 Drill 的组数和每组球数
- [ ] 自定义计划保存到本地（`UserActivePlan` + 自定义结构）
- [ ] 可激活自定义计划，替代官方计划
- [ ] 使用 R0 BT* 组件，不自建临时组件
- [ ] 布局对照 `tasks/UI-IMPLEMENTATION-SPEC.md` 中对应设计截图
- [ ] Light + Dark `#Preview` 通过视觉检查
- [ ] 如有组件 API 或设计解读变更，追加 DR/PD 至 `tasks/IMPLEMENTATION-LOG.md` 并更新 `UI-IMPLEMENTATION-SPEC.md` Changelog

---

## T-P4-10 训练分享卡定制页（新增）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P4-07
- **产出物**：`Features/Training/Views/TrainingShareView.swift`
- **设计参考**：
  - PNG: `ui_design/tasks/P0-06/stitch_task_p0_06_trainingshareview_02/screen.png`
  - HTML: 同目录 `code.html`

### DoD

- [ ] 深色主题分享卡预览区（BTShareCard 组件）
- [ ] 定制控件：字体选择 + 配色主题卡片 + 内容开关胶囊
- [ ] 分享目标：微信好友 / 朋友圈 / 保存相册（3 个圆形图标按钮）
- [ ] 成功率色阶：≥90% 亮绿 / 70-89% 品牌绿 / <70% 弱化白
- [ ] 使用 R0 BTShareCard 组件
- [ ] Light + Dark `#Preview`
- [ ] 如有组件 API 变更，追加 DR/PD 至 IMPLEMENTATION-LOG.md

---

## QA-P4 P4 验收

- **负责角色**：QA Reviewer

### 验收要点

- [x] 从训练首页到第一个 Drill 录入界面，操作步骤 ≤ 3 步
- [x] 完整记录一次训练（2个Drill，各2组）→ 保存 → 历史 Tab 能查到（P6前用调试方式验证数据存在）
- [x] 自由记录模式可在无计划情况下正常使用
- [x] 离线状态下记录训练，数据正确保存到 SwiftData
- [x] 心得可跳过，跳过后训练仍能正常保存
- [x] 付费官方计划有锁定，免费计划（beginner/cueball）可正常使用

### QA 验收报告 — Phase 4 Training Log

验收日期：2026-04-05

#### ✅ 通过项（代码审查 + 自动化测试）

- T-P4-01 官方训练计划 JSON：6 套计划文件存在，isPremium 分配正确（beginner/cueball=false, 其余=true）
- T-P4-02 训练 Tab 今日计划视图：空状态引导 + 有计划时今日训练列表 + 自由记录入口
- T-P4-03 官方计划列表与详情页：按等级分组展示，详情含周期/频次/时长，付费锁定
- T-P4-04 开始训练流程：plan/free 双模式 + 计时器（start/pause/skip）+ Drill TabView 轮播
- T-P4-05 训练中 Drill 记录界面：BTSetInputGrid + BTExerciseRow，数字键盘输入，实时成功率
- T-P4-06 心得备注输入：匹配 code.html 设计，极简输入 + 跳过/完成，无装饰（DR-004）
- T-P4-07 训练完成总结页：2×2 统计网格 + 成功率进度条 + Drill 分组明细（DR-005）
- T-P4-08 TrainingSession 持久化：SwiftData 写入 + SyncQueue 入队 + 错误处理，30/30 测试通过
- T-P4-09 自定义训练计划：ScrollView 卡片布局 + 自定义步进器 + DrillSettingsSheet + 保存/激活（DR-007）
- T-P4-10 TrainingShareView：BTShareCard 匹配 code.html + 定制面板 + 分享目标入口（DR-006）

#### 📊 自动化测试

- 总测试数：232/232 通过，0 失败
- 关键套件：ActiveTrainingViewModelTests 30/30, CustomPlanBuilderViewModelTests 19/19

#### 🧪 人工测试

- 计划文件：`tasks/test-plans/TP-P4.md`
- 执行状态：⏳ 待执行（R-UI 完成后统一执行）
- 原因：P4 页面将在 R-UI Phase 中进行视觉对齐，人工测试在 UI 稳定后执行更有效

#### 📋 总结

状态：✅ **附条件通过**
- 代码审查 + 自动化测试全部通过
- 人工测试（TP-P4）待 R-UI 完成后执行
- 无 P0/P1 阻塞项

---

## ADR 记录区
