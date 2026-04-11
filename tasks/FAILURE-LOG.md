# FAILURE LOG

> 记录所有返工/回退/QA 失败条目。格式：FL-NNN（三位数字递增）。
> 每条写入后须按 `00-orchestrator.mdc §⚡实施知识回写` 同步至对应规则文件。

---

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

## FL-003
- **任务**：QA-P3（人工测试 TP-P3）
- **现象**：付费 Drill（L2+）详情页中，训练要点（coachingPoints）内容对匿名/免费用户完整可见，`BTPremiumLock` 渐进遮罩未生效
- **严重程度**：P1（Freemium 核心付费墙失效，影响商业化）
- **关联检查项**：V-18、流程5-a
- **根因**：`BTPremiumLock.progressiveLock` 直接渲染 `content()`，`visibleItems` 参数完全未使用，无任何模糊/渐变遮罩
- **解决**：✅ 添加 `LinearGradient` mask（顶部 0%→25% 完整可见，65% 渐隐至透明）+ `allowsHitTesting(false)`（2026-04-11）
- **日期**：2026-04-11
- **规则改进建议**：Freemium 付费墙组件挂载须在 QA 阶段以匿名用户 + 免费状态专项验证，不能仅依赖代码审查
- **已应用至**：待路由

## FL-004
- **任务**：QA-P3（人工测试 TP-P3）
- **现象**：搜索「直线」时，全名不包含「直线」的 Drill 也出现在搜索结果中，且排在包含「直线」的结果前面
- **严重程度**：P2（搜索体验受损，用户无法准确找到目标 Drill）
- **关联检查项**：流程2-a
- **根因**：`applyFilters()` 搜索条件匹配了 `description` 字段，导致名字不含关键词但描述含关键词的 Drill 混入结果
- **解决**：✅ 移除 `$0.description.lowercased().contains(query)` 匹配，仅搜索 `nameZh` + `nameEn`（2026-04-11）
- **日期**：2026-04-11
- **规则改进建议**：搜索过滤须限定字段范围（`name` 优先），并在测试时验证结果集中无额外字段的误匹配
- **已应用至**：待路由

## FL-005
- **任务**：QA-P3（人工测试 TP-P3）
- **现象**：球种筛选 Chip「全部」始终处于选中（深色）状态，切换到「中式台球」或「9球」后无法通过点击「全部」恢复至全量列表；「全部」点击无响应
- **严重程度**：P2（筛选功能异常，用户无法重置球种筛选）
- **关联检查项**：流程3-c
- **根因**：`BallTypeFilter.allCases` 包含 4 个 case（含 `.universal = "通用"`），但规格要求只展示 3 个；多余的「通用」Chip 导致视觉混乱；Chip 切换无动画反馈使状态变化不明显
- **解决**：✅ 新增 `displayCases: [.all, .chinese8, .nineBall]` 仅展示 3 个 Chip；`withAnimation(.easeInOut)` 切换选中态（2026-04-11）
- **日期**：2026-04-11
- **规则改进建议**：筛选重置路径（选中态 → 全部）须作为独立检查项纳入 QA；展示用的 case 与逻辑用的 allCases 应分离
- **已应用至**：待路由

## FL-006
- **任务**：QA-P4（人工测试 TP-P4）
- **现象**：DrillRecordView 训练记录界面无成功率实时显示（缺少百分比数字和进度条）
- **严重程度**：P1
- **关联检查项**：V-16, Flow1-④
- **根因**：DrillRecordView 仅在 completedBanner（全部组完成后）显示成功率，训练过程中无实时反馈
- **解决**：✅ 新增 `successRateSection`：大字号百分比 + ProgressView 进度条 + 进球/目标统计，受 `showSuccessRate` 开关控制（2026-04-11）
- **日期**：2026-04-11
- **规则改进建议**：成功率实时反馈是训练核心指标，应作为 DrillRecordView 的必需 UI 元素加入 DoD
- **已应用至**：✅ DrillRecordView.swift successRateSection（2026-04-11）

## FL-007
- **任务**：QA-P4（人工测试 TP-P4）
- **现象**：一组训练结束后无休息倒计时弹出；缺少组间休息功能（休息时间设置 + 锁屏后显示倒计时）
- **严重程度**：P1（训练核心体验缺失，组间休息是实际训练刚需）
- **关联检查项**：TP-P4 新发现
- **根因**：ViewModel 已有 `startRestTimer()` 逻辑，但 UI 仅在顶栏用小字展示剩余秒数，无明显视觉反馈
- **解决**：✅ 新增 `restCountdownOverlay`：全屏半透明遮罩 + 圆环倒计时动画 + 大字号秒数 + 跳过/+30s 按钮 + 快速切换休息时长（30/45/60/90s）+ 倒计时结束触觉反馈 + 屏幕常亮（2026-04-11）
- **日期**：2026-04-11
- **规则改进建议**：组间休息是训练记录的核心交互环节，应作为 T-P4-05（Drill 记录界面）DoD 必需项
- **已应用至**：✅ ActiveTrainingView.swift restCountdownOverlay + ActiveTrainingViewModel.swift addRestTime/onRestComplete（2026-04-11）

## FL-008
- **任务**：QA-P4（人工测试 TP-P4）
- **现象**：CustomPlanBuilderView 中 Drill 行拖拽手柄不生效，迷你球台缩略图缺失（Light + Dark 均不可见）
- **严重程度**：P2
- **关联检查项**：V-24, D-11
- **根因**：(1) VStack + ForEach 不支持 `.onMove`，手柄仅为视觉图标；(2) 缩略图实际存在但使用静态绘制
- **解决**：✅ 改用 `List` + `ForEach` + `.onMove` + `editMode(.active)` 启用系统原生拖拽手柄；缩略图保留（2026-04-11）
- **日期**：2026-04-11
- **规则改进建议**：拖拽排序功能需在实现时同步验证 onMove 回调；缩略图组件集成须有视觉验收截图
- **已应用至**：✅ CustomPlanBuilderView.swift drillListSection（2026-04-11）

## FL-009
- **任务**：QA-P4（人工测试 TP-P4）
- **现象**：训练中 App 进入后台时计时器暂停，返回前台后才继续计时；训练数据不丢失
- **严重程度**：P3
- **关联检查项**：E-06
- **根因**：Timer 基于 `Timer.scheduledTimer` 或 SwiftUI `.onReceive`，App 进入后台后 RunLoop 暂停导致计时停止
- **解决**：⏳ 待评估（可记录 `backgroundDate` 在 `scenePhase` 变化时补偿差值；或接受当前行为作为 V1 已知限制）
- **日期**：2026-04-11
- **规则改进建议**：计时器类功能需考虑后台场景，使用 `Date` 差值而非累加间隔
- **已应用至**：⏳ 待回写
