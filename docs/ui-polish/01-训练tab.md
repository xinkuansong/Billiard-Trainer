# UI 打磨审阅：训练 Tab（TR）

审阅范围：`QiuJi/Features/Training/Views/` 下全部 View  
（`TrainingHomeView`、`PlanListView`、`PlanDetailView`、`CustomPlanBuilderView`、`ActiveTrainingView`（含 `DrillPickerSheet`）、`DrillRecordView`、`TrainingNoteView`、`TrainingShareView`、`TrainingSummaryView`）。  
共享组件仅评「该页用法」，不评组件本体实现。

---

## 页面概述

**TrainingHomeView**  
训练 Tab 根页：有激活计划时展示「今日安排」前三项 + 底部固定「开始训练」；无计划时引导选计划/自由记录。下方用分段切换官方/自定义计划浏览，官方侧带等级筛选 chips 与海报网格。

**PlanListView**  
全量训练计划列表页：按等级分组的官方海报卡 +「我的计划」自定义卡（编辑/激活/删除 Menu）。顶栏「新建」进自定义构建器。

**PlanDetailView**  
官方计划详情：杂志风封面 Hero、训练要点条、周时间轴与可折叠周/天/drill 轨；底栏「开始此计划 / 解锁 / 已激活」三态，激活有确认弹窗。

**CustomPlanBuilderView**  
新建/编辑自定义计划：名称、每周天数步进、可拖拽排序的 drill 列表、添加项目 sheet、单项设置 sheet（组数/球数/移除）；保存 Menu 支持「仅保存 / 保存并激活」。

**ActiveTrainingView**  
训练会话全屏流：active（计时顶栏 + 分页记分 / 总览 / 空态）→ note → summary；组间休息半透明覆层；底栏最小化/更多/添加/心得/切换。内含 `DrillPickerSheet`。

**DrillRecordView**  
单 drill 记分页：练习行、备注框、休息设置、计时/成功率开关、`BTScoreInputGrid`、进行中统计条、可折叠球台示意。

**TrainingNoteView**  
训练结束后心得编辑：提示文案 + 多行编辑器 + 字数软限制 +「跳过 / 完成」。

**TrainingSummaryView**  
总结页：2×2 统计卡 + 成功率条、分 drill 明细、心得回显；底栏保存/分享图/看历史，工具栏亦有分享入口。

**TrainingShareView**  
分享图定制 sheet：卡片预览 + 字体/主题/选项开关 + 微信/相册/返回操作。

---

## Findings

### F-TR-01 「保存相册」弹出「已保存」但未真正保存
- **类别**：B微交互
- **位置**：`QiuJi/Features/Training/Views/TrainingShareView.swift:199-208`；配套文案 `37-39`
```swift
shareButton(...) { showSavedAlert = true }
// ...
.alert("已保存到相册", isPresented: $showSavedAlert) {
```
- **现状**：点「保存相册」仅把 `showSavedAlert = true`，无 `UIImageWriteToSavedPhotosAlbum` / Photos 写入；Alert 文案声称已保存。
- **问题**：对照 B3——完成反馈必须诚实；假完成会让用户以为图已在相册。
- **建议**：在写入成功后再弹「已保存」；失败弹错误；若相册能力未接线，按钮应禁用或改为「即将支持」，禁止假成功文案。
- **语义影响**：无（只修正反馈诚实性与既有按钮承诺的兑现方式，不改分享信息架构）。
- **严重度**：P1

### F-TR-02 「隐藏备注」开关切换后预览无变化
- **类别**：B微交互
- **位置**：`TrainingShareView.swift:162`（开关）；`47-53`（`BTShareCard` 调用未传入备注隐藏）
```swift
togglePill("隐藏备注", isActive: $hideNote)
// BTShareCard(..., hideSuccessRate:, hideBallTable:) // 无 hideNote
```
- **现状**：`hideNote` 有状态与动画，但未传入 `BTShareCard`；卡片组件侧亦无对应参数消费（本 finding 只评本页用法）。
- **问题**：对照 B3——控件反馈与可见结果脱节，属可感知的假交互。
- **建议**：要么把 `hideNote` 接到卡片预览（若组件已有/可加参数），要么暂时隐藏该 pill，避免无效开关。
- **语义影响**：无（对齐开关标签与预览表现，不增删分享能力）。
- **严重度**：P2

### F-TR-03 休息倒计时覆层：字号/间距硬编码，主操作无组件按压态
- **类别**：D一致性 / B微交互
- **位置**：`ActiveTrainingView.swift:588-628`
```swift
.font(.system(size: 32, weight: .bold, design: .default))
.font(.system(size: 13))
HStack(spacing: 12) { ... Text("+30S") ... Text("完成休息") ... }
```
- **现状**：覆层内计时、副文案、双按钮大量 `.system(size:)` 与 `spacing: 12` / `padding(.vertical, 14)`；「完成休息」手写实心胶囊，未用 `BTButtonStyle`（后者含 0.98 scale 按压）。
- **问题**：对照 D3（chrome 应用 token）、B1（主要操作应有按压态）。同页底栏「添加」已用 `BTButtonStyle.iconCircle`，此处形态脱节。
- **建议**：计时用 `btLargeTitle`/`btStatNumber` + monospaced；副文案 `btFootnote`；间距改 `Spacing.md`；「完成休息」改 `BTButtonStyle.primary`，「+30S」改 `BTButtonStyle.secondary` 或等价带 scale 的 style。
- **语义影响**：无（仅视觉与按压反馈，休息逻辑不变）。
- **严重度**：P2

### F-TR-04 计划列表「激活此计划」无确认，与详情/构建器不一致
- **类别**：B微交互 / D一致性
- **位置**：`PlanListView.swift:168-172`（无确认直接 `activateCustomPlan`）；对照 `PlanDetailView.swift:69-77`、`CustomPlanBuilderView.swift:77-84`（均有替换确认）
```swift
Button { activateCustomPlan(plan) } label: {
    Label("激活此计划", systemImage: "play.circle")
}
```
- **现状**：列表 Menu 一点即替换当前激活计划；详情「开始此计划」、构建器「保存并激活」均有 Alert 说明会替换。
- **问题**：对照 B4（覆盖类操作应有确认）、D2（同类「激活」应同形态）。
- **建议**：列表激活前复用与详情相同的确认文案（已有激活计划时强调替换）。
- **语义影响**：无（不改变激活语义，只统一防误触）。
- **严重度**：P2

### F-TR-05 今日列表未开始项展示不可点的 `menu` 图标（伪可点）
- **类别**：C视觉 / B微交互
- **位置**：`TrainingHomeView.swift:221-226`
```swift
} else {
    Image(systemName: BTIcon.menu)
        .font(.btBody)
        .foregroundStyle(.btTextTertiary)
        .frame(width: 44, height: 44)
}
```
- **现状**：已完成项有勾选；当前项有「GO!」；其余未开始项放 44×44 的 menu 图标，但无 `Button`/`onTap`，仅占位。
- **问题**：对照 C2（视觉权重应匹配可操作性）、B1（可点形貌应有反馈——此处像可点却不可点）。
- **建议**：改为弱化序号态/锁态/「排队」文案，或纯留白；勿用常见可点 SF Symbol 当装饰。
- **语义影响**：无（不改变只能从当前项/底栏开训的流程）。
- **严重度**：P2

### F-TR-06 首页「GO!」手写主色按钮，与底栏 `BTButtonStyle.primary` 脱节且缺统一按压
- **类别**：D一致性 / B微交互
- **位置**：`TrainingHomeView.swift:210-220`；对照同文件 `564-574`（`BTButtonStyle.primary`）
```swift
Text("GO!")
    .background(Color.btPrimary)
    .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
```
- **现状**：卡片内主行动手写填充；底栏「开始训练」走设计系统按钮（含 scale 按压）。
- **问题**：对照 D2/D4（同类主操作同形态）、B1。
- **建议**：抽紧凑版 primary（或 `BTButtonStyle` 增加 compact），或至少加与 `BTButtonStyle` 同参数的 `ButtonStyle`（scale 0.96–0.98）。
- **语义影响**：无（仍是启动当日训练）。
- **严重度**：P2

### F-TR-07 筛选 chip 硬编码 RGB，动效用 `spring(duration:)` 漂移
- **类别**：D一致性
- **位置**：`TrainingHomeView.swift:295`；`315-328`
```swift
withAnimation(.spring(duration: 0.2)) { viewModel.selectedFilter = filter }
private static let chipActiveFillLight = Color(red: 0x1C/255, ...)
private static let chipActiveFillDark = Color(red: 0xF2/255, ...)
```
- **现状**：选中底用裸 RGB（近似 label/系统灰），未走 `Color.bt*`；动画为 `spring(duration:)` 短弹簧，与仓库收敛的 `spring(response: 0.34, dampingFraction: 0.86)` / `0.35/0.75` 不一致。说明：`BTChipRow` 是暗色 HUD 胶囊，**不宜**直接替换本页浅色筛选（故不记 D4 误用）。
- **问题**：对照 D3、D1；高频 chips 用短动画合理，但应收编为统一短弹簧或 `easeOut`≤200ms，颜色用 token（如选中 `btText` 底 + `btBG` 字）。
- **建议**：选中填充改语义色；`withAnimation` 收编为 `spring(response: 0.28, dampingFraction: 0.86)` 或 `easeOut(duration: 0.15)`（A3 高频）。
- **语义影响**：无（筛选语义不变）。
- **严重度**：P2

### F-TR-08 计划海报/Hero 副文案与 PRO 标重复逃逸 `.system(size:)`
- **类别**：D一致性
- **位置**：
  - `TrainingHomeView.swift:378`、`401`
  - `PlanListView.swift:347`、`358`
  - `PlanDetailView.swift:105`、`146`
```swift
.font(.system(size: 11, weight: .medium))  // 副标题
.font(.system(size: 10, weight: .heavy))   // PRO
.font(.system(size: 28, weight: .bold, design: .rounded)) // Detail Hero 标题
```
- **现状**：三处海报卡拷贝同一套 system 11/10；详情 Hero 标题 28pt 亦裸写（近 `btDisplaySmall` 30 / `btChapterNumber` 26）。
- **问题**：对照 D3——chrome/封面 UI 文案应用 `Font.bt*`（`btCaption2`≈11、`btMicro`≈10；Hero 用 `btDisplaySmall` 或明确展示级 token）。
- **建议**：抽共享 `PlanPosterMeta`/`ProTag` 小视图并改 token，避免三处漂移。
- **语义影响**：无（信息不增减）。
- **严重度**：P2

### F-TR-09 训练阶段/总览切换统一 `easeInOut`，未收编仓库 spring
- **类别**：A动效 / D一致性
- **位置**：`ActiveTrainingView.swift:59-60`、`221-223`、`509-511`
```swift
.animation(.easeInOut(duration: 0.3), value: viewModel.trainingPhase)
.animation(.easeInOut(duration: 0.25), value: viewModel.isRestTimerActive)
withAnimation(.easeInOut(duration: 0.25)) { viewModel.showingOverview = false }
```
- **现状**：阶段切换、休息覆层显隐、总览⇄单项均为 easeInOut 0.25–0.3s；其它 Feature 已收敛两套 spring。
- **问题**：对照 A1（进出场宜 ease-out/spring）、D1（参数漂移）。时长本身未明显超时，但手感与其它 Tab 不一致。
- **建议**：面板级改 `spring(response: 0.34, dampingFraction: 0.86)`；总览切换可同参或略短 `0.28/0.86`。休息环上的 `.linear(duration: 1)` 属秒针内容动画，保留为例外。
- **语义影响**：无。
- **严重度**：P2

### F-TR-10 心得页「完成」手写主按钮，缺设计系统按压态
- **类别**：D一致性 / B微交互
- **位置**：`TrainingNoteView.swift:100-113`
```swift
Button(action: onComplete) {
    Text("完成")
        .background(Color.btPrimary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
}
```
- **现状**：主 CTA 手写；同流程总结页「保存训练」已用 `BTButtonStyle.primary`（`TrainingSummaryView.swift:267-270`）。
- **问题**：对照 D4/D2、B1。
- **建议**：改为 `BTButtonStyle.primary`（或 compact 变体），「跳过」保持文字次操作即可。
- **语义影响**：无。
- **严重度**：P2

### F-TR-11 训练顶栏「更多」使用 `BTIcon.filter`，语义不符
- **类别**：C视觉 / D一致性
- **位置**：`ActiveTrainingView.swift:370-376`
```swift
Image(systemName: BTIcon.filter)  // accessibilityLabel("更多选项")
```
- **现状**：Menu 承载结束/跳过计时，图标却是筛选；底栏同能力用 `BTIcon.menu`（`468-469`）。
- **问题**：对照 C6（图标与叫法一致）、D2（同类「更多」同图标）。
- **建议**：顶栏改为与底栏一致的 `BTIcon.menu`（或 `ellipsis.circle`）。
- **语义影响**：无。
- **严重度**：P3

### F-TR-12 计划详情周折叠 `spring(duration: 0.3)` 参数漂移
- **类别**：D一致性
- **位置**：`PlanDetailView.swift:286-292`
```swift
withAnimation(.spring(duration: 0.3)) {
    // expand/collapse week
}
```
- **现状**：手风琴使用 `spring(duration:)`，与基准表 `response/dampingFraction` 两套值不一致；展开内容另有 `.opacity + .move(edge: .top)`（`306`），方向一致尚可。
- **问题**：对照 D1。
- **建议**：收编为 `spring(response: 0.34, dampingFraction: 0.86)`（面板/卡片切换档）。
- **语义影响**：无。
- **严重度**：P3

### F-TR-13 首页自定义计划卡 Light/Dark 容器层级不一致
- **类别**：C视觉
- **位置**：`TrainingHomeView.swift:506-508`
```swift
.padding(colorScheme == .dark ? Spacing.md : Spacing.sm)
.background(colorScheme == .dark ? Color.btBGSecondary : .clear)
.clipShape(RoundedRectangle(cornerRadius: colorScheme == .dark ? BTRadius.md : 0))
```
- **现状**：Dark 有二次表面卡片；Light 几乎无底无圆角。对照 `PlanListView` 自定义卡始终 `btBGSecondary`（`210-212`）。
- **问题**：对照 C5（暗色层级手段）与跨页 D2；Light 下与官方海报网格的「卡片感」节奏不齐，Dark 又突然「成卡」。
- **建议**：与 `PlanListView` 对齐为双模式均 `btBGSecondary + BTRadius.md`（或双模式均轻列表无底——二选一并统一）。
- **语义影响**：无。
- **严重度**：P3

### F-TR-14 自定义计划缩略图尺寸跨页不一致
- **类别**：D一致性
- **位置**：`TrainingHomeView.swift:430`（56×56）；`PlanListView.swift:238`（72×72）
```swift
.frame(width: 56, height: 56)  // Home
.frame(width: 72, height: 72)  // PlanList
```
- **现状**：同一「自定义计划行」缩略在不同入口尺寸/字号（Home `btStatNumber` vs List `btDisplaySmall`）不一致。
- **问题**：对照 D2。
- **建议**：统一边长与字号 token（建议 56 + `btStatNumber`，或统一 64）。
- **语义影响**：无。
- **严重度**：P3

---

## D1 动效参数普查表

| 位置 | 当前值 | 判定（吻合/漂移/例外） |
|---|---|---|
| `TrainingHomeView.swift:295` 筛选 chip | `spring(duration: 0.2)` | 漂移（高频可短，建议收编短 spring/`easeOut`） |
| `PlanDetailView.swift:286` 周折叠 | `spring(duration: 0.3)` | 漂移 → 建议 `0.34/0.86` |
| `CustomPlanBuilderView.swift:130,150` 天数 ± | `snappy(duration: 0.15)` | 例外（高频步进，A3 合理） |
| `ActiveTrainingView.swift:59` 阶段切换 | `easeInOut(0.3)` | 漂移 → 建议面板 spring |
| `ActiveTrainingView.swift:60` 休息覆层显隐 | `easeInOut(0.25)` | 漂移 → 建议面板 spring |
| `ActiveTrainingView.swift:221,509` 总览切换 | `easeInOut(0.25)` | 漂移 |
| `ActiveTrainingView.swift:261,325` 计时数字 | `.default` + `numericText` | 例外（内容秒表） |
| `ActiveTrainingView.swift:572,586` 休息环 | `linear(duration: 1)` | 例外（按秒内容动画） |
| `DrillRecordView.swift:249,273` 开关/球台折叠 | `easeInOut(0.2)` | 漂移（可接受短 chrome，建议统一短 spring） |
| `DrillRecordView.swift:139` 成功率数字 | `.default` | 例外（数值内容） |
| `TrainingShareView.swift:94,147` 字体/主题 | `easeInOut(0.2)` | 漂移 |
| `TrainingShareView.swift:171` 选项 pill | `easeInOut(0.15)` | 漂移（高频，可保留短时长但统一曲线） |
| `TrainingNoteView` / `TrainingSummaryView` / `PlanListView` | 无页面级 withAnimation | — |

---

## 存疑项（不确定是否越红线，待主控裁决，不算 finding）

1. **微信好友/朋友圈按钮空 action**（`TrainingShareView.swift:193-198`，注释 H-05 deferred）：点按无任何反馈。补「暂未开放」toast 属打磨；真正接 SDK 属功能/人工项。是否本轮只做空态反馈？
2. **`DrillRecordView` 的 `noteText` 仅 `@State` 本地**（`153-169`），未见写回会话/总结：像未接线功能。修持久化可能动模型，疑越「不改功能语义」红线。
3. **总结页分享双入口**（工具栏 `TrainingSummaryView.swift:38-40` + 底栏 `272-275`）：是否刻意（快捷 + 主路径）？若收成一处可能被视作改 IA，故不记 finding。
4. **`TrainingNoteView` TODO「隐藏备注」**（`7`）：与分享页死开关相关，产品是否要做需确认。
5. **自由模式空态仍展示大块 `timerSection`**（`ActiveTrainingView.swift:658-662`）：强化计时还是抢「添加项目」主操作？调整权重可能被视作改层级策略，仅存疑。
