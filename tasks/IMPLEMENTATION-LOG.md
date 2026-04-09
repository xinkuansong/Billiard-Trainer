# 实施日志（IMPLEMENTATION LOG）

> Orchestrator / 各专项角色在发生返工、设计调整或模式发现时维护本文件。
> **目的**：捕获实施轨迹（失败、设计调整、可复用模式），便于规则改进与跨会话知识累积。
> **编号**：三种条目类型，各自独立递增：
> - `FL-NNN`：失败与返工（Failure）
> - `DR-NNN`：设计调整（Design Refinement）— 设计规范在 SwiftUI 实施中需要调整
> - `PD-NNN`：模式发现（Pattern Discovery）— 可复用的实施模式
>
> 与 `tasks/PROGRESS.md` 中 `⚠️ 返工（见 FL-xxx）` 交叉引用。
> 与 `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog 同步更新。

---

## 如何新增一条记录

1. 使用下一个可用编号（FL/DR/PD 各自独立计数）。
2. 必填字段：`任务`、`描述`、`日期`。
3. FL 额外必填：`现象`、`根因`、`解决`。
4. DR 额外必填：`原始规范`、`调整后`、`原因`。
5. PD 额外必填：`模式描述`、`适用场景`、`代码示例`。
6. 通用选填：`回写目标`（指向具体 `.mdc` / `SKILL.md` 文件）。
7. 同步操作：
   - FL → 在 `PROGRESS.md` 将任务标为 `⚠️ 返工（见 FL-NNN）`
   - DR/PD → 更新 `UI-IMPLEMENTATION-SPEC.md` § Changelog
   - 全部 → 触发 Orchestrator 回写流程（见 `00-orchestrator.mdc` § 实施知识回写）

### FL 模板

```markdown
## FL-NNN
- **任务**：T-Pn-xx
- **现象**：（可观测的失败）
- **根因**：（为何发生）
- **解决**：（实际修复）
- **日期**：YYYY-MM-DD
- **回写目标**：（可选）`路径/to/rule.mdc`
- **已应用至**：⏳ 待回写 / ✅ `路径/rule.mdc`（YYYY-MM-DD）
```

### DR 模板

```markdown
## DR-NNN
- **任务**：T-Pn-xx
- **原始规范**：（UI-IMPLEMENTATION-SPEC 或设计截图中的原始定义）
- **调整后**：（SwiftUI 实施中实际采用的值/行为）
- **原因**：（为何需要调整）
- **影响组件**：（受影响的 BT* 组件或页面）
- **日期**：YYYY-MM-DD
- **回写目标**：`SKILL.md` / `UI-IMPLEMENTATION-SPEC.md`
- **已应用至**：⏳ 待回写 / ✅ `路径`（YYYY-MM-DD）
```

### PD 模板

```markdown
## PD-NNN
- **任务**：T-Pn-xx
- **模式描述**：（一句话概括可复用模式）
- **适用场景**：（何时应使用此模式）
- **代码示例**：（关键 SwiftUI 代码片段）
- **日期**：YYYY-MM-DD
- **回写目标**：`20-swiftui-developer.mdc` / `SKILL.md`
- **已应用至**：⏳ 待回写 / ✅ `路径`（YYYY-MM-DD）
```

---

## FL 记录（失败与返工）

## FL-001
- **任务**：T-P1-07 / T-P2-05（用户认证 + 数据同步）
- **现象**：H-06（LeanCloud 账号注册）永久阻塞 — LeanCloud 已停止中国大陆新用户注册，无法解除阻塞。
- **根因**：架构设计（v0.3）依赖 LeanCloud 作为用户认证和数据同步托管服务，而该服务在项目开发期间停止国内新注册，属于外部服务不可用风险未在选型时充分评估。
- **解决**：执行 ADR-001（2026-03-29）— 改用自建极简 REST API（腾讯云 Node.js + MongoDB）。iOS/Android 共用同一套 API，长期架构更清晰。同步移除 LeanCloud Swift SDK，包体积减小约 5MB。
- **日期**：2026-03-29
- **回写目标**：`30-data-engineer.mdc`
- **已应用至**：✅ `.cursor/rules/30-data-engineer.mdc` § 经验教训 / ⛔ FL-001（2026-03-29）

---

## DR 记录（设计调整）

## DR-001
- **任务**：T-R0-02
- **原始规范**：SKILL.md 中 `btBGTertiary` Light = `#F2F2F7`、`btBGQuaternary` Light = `#E5E5EA`、`btSeparator` Light = `#C6C6C8`（α1.0）
- **调整后**：`btBGTertiary` Light = `#E5E5EA`、`btBGQuaternary` Light = `#D1D1D6`、`btSeparator` Light = `rgba(60,60,67,0.18)`。与 UI 设计交付物（`UI-IMPLEMENTATION-SPEC.md` § 1.1）对齐。
- **原因**：原始 SKILL.md 使用了旧 Token 值，背景层次向下偏移了一级；`btSeparator` 应为半透明以适配不同底色叠加。设计交付物 44 帧已统一使用新值。
- **影响组件**：全局 — 所有使用 btBGTertiary/btBGQuaternary/btSeparator 的视图
- **日期**：2026-04-05
- **回写目标**：`SKILL.md` § 二·色彩系统
- **已应用至**：✅ `.cursor/skills/swiftui-design-system/SKILL.md` § 二（2026-04-05）

## DR-002
- **任务**：T-R0-03
- **原始规范**：`UI-IMPLEMENTATION-SPEC.md` § 2.1 定义 `case segmentedPill` 无关联值
- **调整后**：`case segmentedPill(isSelected: Bool)`，需传入选中状态以区分填充/描边渲染
- **原因**：ButtonStyle 协议无内建选中态；不使用关联值则无法在同一枚举中区分选中/未选中视觉
- **影响组件**：BTButton、BTTogglePillGroup（T-R0-04 将使用此 API）
- **日期**：2026-04-05
- **回写目标**：`UI-IMPLEMENTATION-SPEC.md` § 2.1、`SKILL.md` § 七
- **已应用至**：✅ `UI-IMPLEMENTATION-SPEC.md` § 2.1 + `SKILL.md` § 七（2026-04-05）

## DR-003
- **任务**：T-P4-05
- **原始规范**：`UI-IMPLEMENTATION-SPEC.md` § 2.11 BTSetInputGrid API 仅含 `onAddSet` 和 `onComplete` 回调，madeBalls/targetBalls 显示为静态 Text
- **调整后**：新增 `onDeleteSet: ((Int) -> Void)?` 回调；非已完成行的 madeBalls/targetBalls 改为 TextField（支持数字键盘输入）；溢出菜单列提供删除功能；`RowState` 从 `private` 改为 `internal` 以支持文件级 SetRow 访问
- **原因**：T-P4-05 DoD 要求「长按可删除某组记录」和「进球数（数字键盘输入）」和「目标球数（可调）」，原组件 API 不支持这些交互
- **影响组件**：BTSetInputGrid、DrillRecordView（新建）、ActiveTrainingViewModel（drillSetsData 替代 ballsMadeRecords）
- **日期**：2026-04-05
- **回写目标**：`UI-IMPLEMENTATION-SPEC.md` § 2.11、`SKILL.md` § 十三
- **已应用至**：✅ `UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-04-05）

## DR-004
- **任务**：T-P4-06
- **原始规范**：TrainingNoteView 早期实现包含大图标 header + 统计徽章行 + 有边框输入框 + 纵向堆叠全宽按钮；"完成"空文本时禁用
- **调整后**：匹配 `code.html` 设计——极简布局：顶部 2 行引导提示 + 全屏无边框 TextEditor + 固定底栏左"跳过"右"完成"；"完成"始终可点击；新增 `onBack` 返回训练功能；移除 `drillCount`/`elapsedSeconds` 参数
- **原因**：原实现未对照 `code.html` 精确布局，偏离设计意图（设计强调沉浸式写作体验，无装饰性元素）
- **影响组件**：TrainingNoteView（API 简化 5→3 参数）、ActiveTrainingView（toolbar 新增 note 阶段返回按钮）、ActiveTrainingViewModel（新增 `resumeTraining()`）
- **日期**：2026-04-05
- **回写目标**：`UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：✅ `UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-04-05）

## DR-005
- **任务**：T-P4-07
- **原始规范**：TrainingSummaryView 使用简化的 `DrillSummary`（仅聚合 totalBallsMade/totalBallsPossible），`hasNote: Bool` 标记，无"生成分享图"入口，无总进球统计卡
- **调整后**：匹配 `code.html` 设计——2×2 统计网格 + 全宽成功率进度条卡；`DrillSummary` 新增 `level: DrillLevel?` 和 `sets: [SetResult]` 支持每组明细展开；`ActiveDrill` 新增 `level` 属性；API 改为 10 参数（+totalBallsMade, trainingNote, onGenerateShareImage; -hasNote）；底部固定操作栏包含保存/分享/历史三入口
- **原因**：code.html 设计要求每个 Drill 卡片展示分组明细和等级徽章，原模型数据粒度不足；设计底部有"生成分享图"入口对接 T-P4-10
- **影响组件**：DrillSummary（新增 SetResult + level）、ActiveDrill（新增 level）、TrainingSummaryView（API 重构）、ActiveTrainingView（调用更新）、ActiveTrainingViewModel（新增 totalBallsMade）
- **日期**：2026-04-05
- **回写目标**：`UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：✅ `UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-04-05）

## DR-006
- **任务**：T-P4-10
- **原始规范**：BTShareCard R0 版本：date → title → stats → drill-dots → footer（简约列表布局）；`TrainingSessionSummary.DrillResult` 无 `setsCount`；无 `totalBallsMade` 计算属性
- **调整后**：匹配 `code.html` 设计——logo header（绿色 Q 徽章 + 品牌名 + 日期）→ title + 概要 → separator → drill 行（白色 5% 背景圆角卡片，显示名称 + 组数 + 成功率%）→ stats grid（总进球 / 总组数 / 平均成功率三列）→ footer（品牌名 + 副标题 + QR 占位）；新增 `fontChoice: ShareCardFont` + `hideSuccessRate: Bool` 参数支持定制；`DrillResult` 新增 `setsCount`；`TrainingSessionSummary` 新增 `totalBallsMade` 计算属性
- **原因**：T-P4-10 实际实现时对照 code.html 发现 R0 骨架布局与设计差异较大（顺序、样式、数据展示方式全部不同）
- **影响组件**：BTShareCard（布局重构 + API 扩展）、TrainingSessionSummary（DrillResult + computed prop）、新增 ShareCardFont 枚举、新建 TrainingShareView
- **日期**：2026-04-05
- **回写目标**：`UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：✅ `UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-04-05）

---

## PD-001
- **任务**：T-P4-06
- **模式描述**：设计参考三步流程——每个页面实现前必须依次查看 `screen.png` → `code.html` → `UI-IMPLEMENTATION-SPEC.md`，避免仅凭截图猜测布局
- **适用场景**：所有涉及 UI 实现的任务（P4-P8、R-UI）
- **代码示例**：无（流程规范，非代码模式）
- **日期**：2026-04-05
- **回写目标**：`UI-IMPLEMENTATION-SPEC.md` § 文件头优先级声明
- **已应用至**：✅ `UI-IMPLEMENTATION-SPEC.md` § 文件头（2026-04-05）——已更新为三步流程

## DR-007
- **任务**：T-P4-09
- **原始规范**：CustomPlanBuilderView 使用 List(.insetGrouped) + 标准 Stepper + 内联 Stepper 行调整组数/球数；无缩略图；无设计设置弹层
- **调整后**：匹配 `code.html` 设计——ScrollView + VStack 自定义布局；Plan Info Card（编辑图标 + 名称 TextField + 统计摘要）；自定义 -/数字/+ 步进器替代原生 Stepper；Drill 行含拖拽手柄图标 + 56pt 迷你球台缩略图 + 名称 + 「X组·Y球」+ 齿轮图标；新增 DrillSettingsSheet（半屏 .medium detent，Stepper 调组数/球数 + 移除按钮）；ViewModel 新增 totalSetsCount/totalBallsCount/updateDrillSettings/removeDrill
- **原因**：原 List 实现偏离设计意图（code.html 使用卡片式分区、自定义步进器、缩略图行布局）；齿轮设置弹层替代内联 Stepper 提升操作精度和视觉清洁度
- **影响组件**：CustomPlanBuilderView（布局完全重写）、CustomPlanBuilderViewModel（新增 4 个方法/属性）、新增 DrillSettingsSheet
- **日期**：2026-04-05
- **回写目标**：`UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：✅ `UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-04-05）

## DR-008
- **任务**：T-RUI-03
- **原始规范**：ActiveTrainingView 底部工具栏仅图标无文字标签；顶栏 2 图标（play/gear）；无计划名显示；热身标记使用 btAccent 金色
- **调整后**：底部 5 键工具栏添加可见文字标签（最小化/更多/添加/心得/切换）；顶栏扩展为 4 图标（play、timer、filter、checkmark）；frostedTopBar 新增计划名 + 进度文字区；drillRecordContent 共用 frostedTopBar 替代独立 drillRecordHeader；热身「热」标记改为 btWarning 橙色
- **原因**：匹配 P0-03/P0-04 设计截图——底栏需要文字标签辅助识别；顶栏图标数量与设计一致；计划名是设计中的显著信息层级
- **影响组件**：ActiveTrainingView（frostedTopBar/bottomToolbar 重构）、BTSetInputGrid（warmup 色值）
- **日期**：2026-04-05
- **回写目标**：`UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：✅ `UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-04-05）

## DR-009
- **任务**：T-RUI-04
- **原始规范**：ProfileView 使用居中大头像 + 纯文本菜单行（MenuRow 无彩色图标背景）；LoginView 使用卡片式选项列表（LoginOptionButton），非全宽按钮；三种登录方式视觉层级无区分
- **调整后**：ProfileView 重构为横向用户卡片（头像+名称+Pro 徽章） + 月度概览统计区 + 双分组彩色圆底图标菜单（ProfileMenuRow：32pt 圆底 + SF Symbol + 标题 + 详情文字）；访客模式新增警告横幅 + Pro 推广深色卡；LoginView 重写为三按钮分层设计（Apple 黑底 > 微信 #07C160 > 手机号灰描边）+ App 图标 + 法律文案底栏；PhoneLoginView 输入改为药丸形（Capsule）+ 发送验证码按钮内嵌 + 底部品牌标识
- **原因**：匹配 P2-03/P2-05 设计截图——彩色图标菜单提升信息层次；三按钮分层设计建立清晰的登录优先级；药丸形输入更现代
- **影响组件**：ProfileView（完全重写）、LoginView（完全重写）、PhoneLoginView（输入样式 + 布局重构）
- **日期**：2026-04-05
- **回写目标**：`UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：✅ `UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-04-05）

## DR-010
- **任务**：T-RUI-05
- **原始规范**：OnboardingView 使用 `figure.pool.swim` 大图标 + btBGSecondary 卡片背景 FeatureRow + 文案「台球训练，从记录开始」
- **调整后**：匹配 P2-04 设计——QJ Logo 圆形标识 + 品牌绿圆底图标 FeatureRow（`rgba(26,107,60,0.12)` 48pt 圆底 + SF Symbol，无卡片背景）+ 文案「你的台球训练伙伴」+ 按钮文案「开始使用」/「登录已有账号」+ `.preferredColorScheme(.light)` 强制浅色
- **原因**：原实现未对照设计截图；Onboarding 为品牌首屏需保持浅色一致性（DM-009）
- **影响组件**：OnboardingView（完全重写）
- **日期**：2026-04-05
- **回写目标**：`UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：✅ `UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-04-05）

## DR-011
- **任务**：DrillLibrary Renovation（参照训记 ref-screenshots 04-exercise-library）
- **原始规范**：DrillListView 单列横向卡片列表 + BTDrillCard 渐变色+SF Symbol 缩略图
- **调整后**：
  1. 新建 `BTMiniTable.swift` — 缩略图专用 Canvas（球径 0.034 vs 0.01125，路径宽 0.007 vs 0.003，无库边，目标袋口 btPrimary 光环高亮）
  2. `BTDrillGridCard` 竖向卡片 — BTMiniTable 缩略图 + 左上 BTLevelBadge + 右上 PRO/收藏 + 底部渐变 + 名称/球种/推荐组数
  3. `DrillListView` 布局重构 — 训记风格左侧分类侧边栏（72pt，选中 btPrimary 绿字+左竖线）+ 右侧 `LazyVGrid` 2 列网格
  4. `DrillDetailView` 新增 — 备注输入卡片、训练维度 5 进度条（准度/力量控制/走位判断/杆法技巧/心理素质）、查看精讲 Pill、真人示范横滚占位
  5. `BTDrillListSkeleton` 更新为 2 列网格骨架
  6. `BTDrillThumbnail` 改用 BTMiniTable 替代旧渐变+图标占位
- **原因**：参照训记 ref-screenshots（04-exercise-library 共 11 张），用户要求"图鉴式"2 列网格 + 左侧分类侧边栏，而非原设计稿的单列列表
- **影响组件**：BTMiniTable（新建）、BTDrillGridCard（重构）、BTDrillThumbnail（重构）、DrillListView（布局重构）、DrillDetailView（新增 4 个 Section）、BTDrillListSkeleton（网格化）
- **日期**：2026-04-06
- **回写目标**：`UI-IMPLEMENTATION-SPEC.md` § Changelog + `PROGRESS.md`
- **已应用至**：✅ `UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-04-06）、✅ `PROGRESS.md`（2026-04-06）

## PD-002
- **任务**：T-P8-11
- **模式描述**：Dark Mode 全面通刷标准化流程
- **适用场景**：新页面开发或 Dark Mode 审计
- **代码示例**：
  1. 阴影必须 Dark 条件化：`.shadow(color: colorScheme == .dark ? .clear : .black.opacity(X), ...)`
  2. 缩略图 Dark 描边：`.overlay(RoundedRectangle(...).stroke(Color.btSeparator, lineWidth: colorScheme == .dark ? 0.5 : 0))`
  3. Apple 登录按钮 HIG Dark：白底+黑字（Dark），黑底+白字（Light）
  4. 图标容器 opacity：Light 12% → Dark 15%（深色表面需更高对比）
  5. darkPill 按钮 Dark 使用 btBGTertiary（#2C2C2E）而非固定 #1C1C1E
- **日期**：2026-04-05
- **回写目标**：`20-swiftui-developer.mdc` § Dark Mode 模式
- **已应用至**：✅ `UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-04-05）

## FL-001
- **任务**：QA-P2（人工测试）
- **现象**：Apple 登录请求 URL 为 `http://auth/login-apple`（API_BASE_URL 未正确注入），后端不可达
- **严重程度**：P1
- **关联检查项**：TP-P2 流程8-①
- **根因**：xcconfig 中 `//` 被当作注释，`http://106.54.3.210:3000` 被截断为 `http:`；`URL(string: "http:").appendingPathComponent("/auth/login-apple")` 产生畸形 URL
- **解决**：✅ 使用 `$()` 空变量打断双斜杠：`API_BASE_URL = http:/$()/106.54.3.210:3000`；构建后 Info.plist 验证正确
- **日期**：2026-04-10
- **规则改进建议**：xcconfig 中含 `://` 的 URL 值必须使用 `$()` 打断双斜杠（`http:/$()/...`），否则后半段被丢弃
- **已应用至**：✅ `60-devops-release.mdc` § 经验教训 / FL-001（2026-04-10）

## FL-002
- **任务**：QA-P2（人工测试）
- **现象**：Sign in with Apple 登录成功后未弹出数据迁移 Alert
- **严重程度**：P2
- **关联检查项**：TP-P2 流程6-⑤
- **根因**：(1) `AuthState.login()` 中 `wasAnonymous` 仅检查 `provider == .anonymous`，但首次用户 `currentUser` 为 `nil`，条件不满足；(2) `LoginView` 在 `authState.login()` 后立即 `dismiss()`，Sheet 动画中 ProfileView 无法弹 Alert
- **解决**：✅ 条件改为 `!isLoggedIn`（覆盖 nil 和 anonymous）；新增 `pendingMigration` 标志，在 Sheet `onDismiss` 回调中触发 Alert
- **日期**：2026-04-10
- **规则改进建议**：Sheet 中修改全局状态后需 Alert 时，应通过 pending 标志 + onDismiss 延迟触发，避免 SwiftUI 动画冲突
- **已应用至**：✅ `20-swiftui-developer.mdc` § 经验教训 / FL-002（2026-04-10）
