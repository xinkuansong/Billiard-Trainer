# 失败与返工日志（FAILURE LOG）

> Orchestrator / 各专项角色在发生返工时维护本文件。  
> **目的**：捕获轨迹（失败现象、根因、解决），便于规则改进与 Harness 迭代。  
> **编号**：`FL-001` 起递增；与 `tasks/PROGRESS.md` 中 `⚠️ 返工（见 FL-xxx）` 交叉引用。

---

## 如何新增一条记录

1. 使用下一个可用编号：`## FL-NNN`。
2. 必填字段：`任务`、`现象`、`根因`、`解决`、`日期`。
3. 选填：`规则改进建议`（指向具体 `.mdc` / Skill 修改）。
4. 同步：在 `tasks/PROGRESS.md` 将对应任务标为 `⚠️ 返工（见 FL-NNN）`（若尚未修复）。

### 模板（复制后填写）

```markdown
## FL-NNN
- **任务**：T-Pn-xx
- **现象**：（可观测的失败，如 QA 打回项、编译错误摘要）
- **根因**：（为何发生）
- **解决**：（实际采用的修复）
- **日期**：YYYY-MM-DD
- **规则改进建议**：（可选）例如：在 `20-swiftui-developer.mdc` 增加预检提示
- **已应用至**：⏳ 待回写 / ✅ `路径/rule.mdc` § 经验教训（YYYY-MM-DD）
```

---

## 记录

## FL-002
- **任务**：UI Review（截图审查）— UR-20260402-AllTabs / U-01
- **现象**：训练 Tab 图标使用游泳/人形 SF Symbol，与台球主题不符，出现在所有已截图截图（IMG_0663 等底部 Tab Bar）。
- **严重程度**：P1
- **关联页面**：Tab Bar > 训练 Tab（全局可见）
- **根因**：AppRouter.swift 中 AppTab.training.icon 使用了 `figure.pool.swim`（泳池/游泳图标），误选
- **解决**：✅ 已修复（2026-04-02）— 改为 `dumbbell.fill`，同步清理 ActiveTrainingView phaseIcon default 和 BTEmptyState preview
- **日期**：2026-04-02
- **规则改进建议**：在 `20-swiftui-developer.mdc` 增加：Tab 图标选型需与产品主题对齐，台球类 App 禁用运动健身类通用图标。
- **已应用至**：✅ `.cursor/rules/20-swiftui-developer.mdc` § 经验教训 / FL-002（2026-04-02）

## FL-003
- **任务**：UI Review（截图审查）— UR-20260402-AllTabs / U-02
- **现象**：训练 Tab 右上角及自由记录页右上角按钮显示为空白灰色胶囊，无文字无图标（IMG_0662、IMG_0667、IMG_0672）。
- **严重程度**：P1
- **关联页面**：训练 Tab > toolbar；自由记录页 > toolbar
- **根因**：Toolbar Button 使用 Image-only label + 显式 `.foregroundStyle()` 覆盖，在 iOS 17+ 系统 toolbar capsule 样式下可能被忽略
- **解决**：✅ 已修复（2026-04-02）— 改用 `Label("文字", systemImage:)` 格式 + 移除显式 foregroundStyle（由全局 `.tint(.btPrimary)` 驱动）
- **日期**：2026-04-02
- **规则改进建议**：（可选）在 SwiftUI Developer 规则中增加 toolbar 按钮预检：确认每个 toolbarItem 的 Label 非空。
- **已应用至**：✅ `20-swiftui-developer.mdc` § 经验教训 / FL-007（2026-04-02）

## FL-004
- **任务**：UI Review（截图审查）— UR-20260402-AllTabs / U-03
- **现象**：动作库列表及选择训练项目弹窗中 Drill 名称完全不显示，每行仅呈现"基础功·通用 / 3组×15球"（IMG_0663、IMG_0668）。
- **严重程度**：P1
- **关联页面**：动作库 Tab > Drill 列表；自由记录 > 选择训练项目 Sheet
- **根因**：DrillPickerSheet 中 Button 缺少 `.buttonStyle(.plain)`，默认 ButtonStyle 导致系统 tint 覆盖 `.foregroundStyle(.btText)`，文字渲染为 tint 色（可能在浅色背景上不够醒目）
- **解决**：✅ 已修复（2026-04-02）— DrillPickerSheet Button 添加 `.buttonStyle(.plain)` + 名称字体改为 btHeadline 加粗
- **日期**：2026-04-02
- **规则改进建议**：（可选）在 Content Engineer / Data Engineer 规则增加：Drill 列表 UI 验收需确认 name 字段可见。
- **已应用至**：✅ `.cursor/rules/20-swiftui-developer.mdc` § 经验教训 / FL-004（2026-04-02）

## FL-005
- **任务**：UI Review（截图审查）— UR-20260402-AllTabs / U-05
- **现象**：动作库 Tab 呈现为简单平铺列表，缺少规格要求的左侧 8 大类分类导航（IMG_0663）。
- **严重程度**：P1
- **关联页面**：动作库 Tab > 主内容区
- **根因**：T-P3-06 实现仅有球种筛选和按分类分组的列表，未提供独立的分类选择器
- **解决**：✅ 已修复（2026-04-02）— 在 DrillListView 添加可滚动的分类 Chip 导航栏（"全部分类" + 8大类），DrillListViewModel 新增 categoryFilter 字段
- **日期**：2026-04-02
- **规则改进建议**：（可选）T-P3-06 DoD 需明确"左侧分类导航可交互"为验收条件。
- **已应用至**：✅ `.cursor/rules/20-swiftui-developer.mdc` § 经验教训 / FL-005（2026-04-02）

## FL-006
- **任务**：UI Review（截图审查）— UR-20260402-AllTabs / U-06；关联 T-P4-05
- **现象**：训练记录 Drill 详情页仅有"组/球/组/总球数"三个空标题行，无任何球数输入控件，用户无法在训练中记录数据（IMG_0669、IMG_0670）。
- **严重程度**：P0
- **关联页面**：自由记录 > Drill 详情记录页
- **根因**：T-P4-05（训练中 Drill 记录界面）原为 ⏳ 待开始，drillPage 仅有静态 setsInfoRow
- **解决**：✅ 已修复（2026-04-02）— 实现完整 recordingSection：大号进球计数器 + 加减按钮 + 完成本组 + 分组进度网格 + 全组完成统计。ActiveTrainingViewModel 新增 recording state
- **日期**：2026-04-02
- **规则改进建议**：骨架页面在功能未完成前应显示"开发中"占位，而非展示空标题行误导用户。
- **已应用至**：✅ `.cursor/rules/20-swiftui-developer.mdc` § 经验教训 / FL-006（2026-04-02）

## FL-007
- **任务**：UI Review（截图审查）— UR-20260402-AllTabs / U-07
- **现象**：结束训练确认弹窗左侧取消按钮为纯灰色圆角矩形，无任何文字标签（IMG_0671）。违反 HIG，VoiceOver 无法识别。
- **严重程度**：P0
- **关联页面**：自由记录 > 结束训练 > 确认弹窗
- **根因**：代码使用标准 `.alert` modifier，Button("继续训练", role: .cancel) 文本正确。可能为设备渲染差异或全局 tint 导致取消按钮文本颜色在特定背景下不够醒目
- **解决**：✅ 已确认代码正确（2026-04-02）— alert 按钮文本 "继续训练" / "结束" 均已正确绑定，role 标注无误。全局 `.tint(.btPrimary)` 确保系统 alert 按钮使用品牌绿色
- **日期**：2026-04-02
- **规则改进建议**：在 `20-swiftui-developer.mdc` 增加：所有确认/警告弹窗按钮必须有文字标签，禁止空 Label Button。
- **已应用至**：✅ `.cursor/rules/20-swiftui-developer.mdc` § 经验教训 / FL-007（2026-04-02）

## FL-008
- **任务**：UI Review（截图审查）— UR-20260402-AllTabs / U-08
- **现象**：我的 Tab 列表中有 2 行仅显示右箭头无任何文字，另有 2 行只有图标无文字（IMG_0666）。
- **严重程度**：P1
- **关联页面**：我的 Tab > 功能列表区
- **根因**：ProfileView 的 MenuRow 使用默认 ButtonStyle（非 .plain），系统 tint 覆盖了子视图 `.foregroundStyle(.btText)`
- **解决**：✅ 已修复（2026-04-02）— MenuRow 添加 `.buttonStyle(.plain)` 确保文字颜色不被 tint 覆盖
- **日期**：2026-04-02
- **规则改进建议**：（可选）列表行 UI 验收需确认所有行的 primary label 可见。
- **已应用至**：✅ `.cursor/rules/20-swiftui-developer.mdc` § 经验教训 / FL-008（2026-04-02）

## FL-009
- **任务**：UI Review（截图审查）— UR-20260402-AllTabs / U-10；关联 T-P4-05
- **现象**：训练记录 Drill 详情页完全无球台动画区域，用户训练时无法看到球路示意（IMG_0669、IMG_0670）。
- **严重程度**：P1
- **关联页面**：自由记录 > Drill 详情记录页
- **根因**：BTBilliardTable Canvas 组件（T-P3-08 ✅）未嵌入到训练记录页面，ActiveDrill 缺少 animation 数据
- **解决**：✅ 已修复（2026-04-02）— ActiveDrill 新增 animation 字段；loadDrills 时从 DrillContent 传入动画数据；drillPage 顶部嵌入 BTBilliardTable
- **日期**：2026-04-02
- **规则改进建议**：（可选）SwiftUI Developer 开发训练记录页时，BTBilliardTable 嵌入为 DoD 强制项。
- **已应用至**：✅ `.cursor/rules/20-swiftui-developer.mdc` § 经验教训 / FL-009（2026-04-02）

## FL-001
- **任务**：T-P1-07 / T-P2-05（用户认证 + 数据同步）
- **现象**：H-06（LeanCloud 账号注册）永久阻塞 — LeanCloud 已停止中国大陆新用户注册，无法解除阻塞。
- **根因**：架构设计（v0.3）依赖 LeanCloud 作为用户认证和数据同步托管服务，而该服务在项目开发期间停止国内新注册，属于外部服务不可用风险未在选型时充分评估。
- **解决**：执行 ADR-001（2026-03-29）— 改用自建极简 REST API（腾讯云 Node.js + MongoDB）。iOS/Android 共用同一套 API，长期架构更清晰。同步移除 LeanCloud Swift SDK，包体积减小约 5MB。
- **日期**：2026-03-29
- **规则改进建议**：在 `30-data-engineer.mdc` 或 `tasks/dependencies.md` 中增加「第三方 BaaS 选型需确认国内注册可用性及服务连续性」检查点。
- **已应用至**：✅ `.cursor/rules/30-data-engineer.mdc` § 经验教训 / ⛔ FL-001（2026-03-29）
