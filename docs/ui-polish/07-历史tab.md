# UI 打磨审阅：历史 Tab（HI）

审阅范围：`QiuJi/Features/History/` 全部  
文件清单：`HistoryCalendarView.swift`、`StatisticsView.swift`、`TrainingDetailView.swift`、`HistoryAccessController.swift`（无 UI）、`HistoryViewModel.swift` / `StatisticsViewModel.swift`（状态源）

---

## 页面概述

**历史（日历）**：根 Tab「记录」的默认子页。月历标有训练日标记，点选日期后下列当日训练 / 角度训练列表；无记录时空态引导去训练；超期记录以 Pro 锁定行呈现并拉起订阅。核心交互是换月、选日、点开详情 sheet。

**统计**：同页 `BTSegmentedTab` 第二段。周/月/年切换下展示训练天数、时长柱状图、成功率、分类对比；非 Pro 用 `BTPremiumLock(.fullMask)` 遮罩图表区；无 drill 记录时用 `BTEmptyState`，仍可看下方角度训练聚合。数据与图表是主角。

**训练详情**：从日历行 sheet 进入。顶栏关闭 + 标题，中部横向统计与逐 drill/组明细，底栏「编辑数据 / 复制到今天 / 溢出菜单」。`HistoryAccessController` 仅提供 60 天免费可读门槛，无视图层。

---

## Findings

### F-HI-01 日历选日与列表切换无过渡，内容硬切
- **类别**：A动效
- **位置**：`QiuJi/Features/History/Views/HistoryCalendarView.swift:159-162`（选日赋值）；同文件 `92-114`（换月无 animation）；全文件无 `withAnimation` / `.animation`
- **现状**：`vm.selectedDate = day.date`、`previousMonth`/`nextMonth` 直接改状态；选中圆圈出现/消失、当日列表替换均为瞬时跳变。
- **问题**：对照 A6（突现突消）；换月/选日属中频 UI chrome，应有短 spring 或 opacity 过渡，而非零过渡。
- **建议**：选日与换月用基准面板 spring `response: 0.34, dampingFraction: 0.86` 包裹状态变更；列表用 `.animation(..., value: selectedDate)` 或轻量 `opacity` 过渡。勿对数据加载本身做长动画。
- **语义影响**：无（仅补过渡，不改选日/换月语义）
- **严重度**：P2

### F-HI-02 会话行 / 日期格可点但无按压缩放反馈
- **类别**：B微交互
- **位置**：`QiuJi/Features/History/Views/HistoryCalendarView.swift:203`（`dayCell`）；`246` / `254`（session / angle 行 `.buttonStyle(.plain)`）
- **现状**：主要可点面（日历格、当日记录卡片）均用 `.plain`，无 `scaleEffect` / 高亮；对比 `BTButtonStyle` 已有按下 `0.96–0.98`。
- **问题**：对照 B1（主要操作无按压态 = P2）。数据 Tab 的主交互就是点这些行。
- **建议**：抽一个轻量 `ButtonStyle`（按下 scale ≈0.98 + 可选 opacity），套在 dayCell 与 session/angle 行上；勿改成会改变布局的样式。
- **语义影响**：无（只加按下瞬时反馈）
- **严重度**：P2

### F-HI-03 加载失败有 errorMessage 但界面完全不展示
- **类别**：B微交互
- **位置**：`QiuJi/Features/History/ViewModels/HistoryViewModel.swift:376`（赋值 `"加载训练记录失败"`）；`HistoryCalendarView.swift:36-42`（仅 `isLoading` / 内容二分，未读 `errorMessage`）
- **现状**：`loadSessions` 失败时写入 `errorMessage`，视图层无横幅、空态或 toast；用户看到的是「还没有训练记录」类空态，与真失败不可区分。
- **问题**：对照 B3（失败要有诚实友好反馈）。
- **建议**：`errorMessage != nil` 时在日历下展示一行可关闭的错误提示（或替换 emptyState 文案为失败态 +「重试」调用 `loadSessions`），成功后清空。
- **语义影响**：无（不改加载逻辑，只把已有错误状态露出）
- **严重度**：P2

### F-HI-04 切到「统计」每次重建 StatisticsView，触发整页 ProgressView 闪一下
- **类别**：B微交互
- **位置**：`QiuJi/Features/History/Views/HistoryCalendarView.swift:43-45`（`else { StatisticsView() }`）；`StatisticsView.swift:17-19` + `55-57`（`isLoading` → `ProgressView`，`.task` 重新 `loadSessions`）
- **现状**：`if activeTab` 分支销毁/重建 `StatisticsView`，每次进入统计都闪加载指示器并重拉数据。
- **问题**：对照 B3（进行时反馈应诚实，但不应在高频 Tab 切换上制造假加载感）；对照 A3（高频切换动画/反馈应极短或没有）。
- **建议**：父级用 `ZStack`/`opacity`/`allowsHitTesting` 同时保活历史与统计，或把 `StatisticsViewModel` 上提由父级持有，避免切段时 remount；加载态仅首次无数据时显示。
- **语义影响**：无（交互仍是两段切换，不改 Tab 语义与数据含义）
- **严重度**：P2

### F-HI-05 锁定训练行与角度训练行共用 btAccent 圆点，扫视易混
- **类别**：C视觉
- **位置**：`QiuJi/Features/History/Views/HistoryCalendarView.swift:307-309`（`locked ? Color.btAccent : Color.btPrimary`）；`352-354`（角度行固定 `Color.btAccent`）
- **现状**：Freemium 锁定的 drill 会话与角度训练会话左侧指示点同色（btAccent）；锁定另有 Pro 文案与 `opacity 0.7`，但色点层先抢视觉。
- **问题**：对照 C4 / C6（层级手段应区分不同类别；同一色点表达两种语义）。
- **建议**：锁定行保持 `btPrimary` 圆点 + 右侧 Pro 徽章/`opacity` 表达锁定；或锁定用 `btTextTertiary` 空心点，把 btAccent 留给角度训练专属。
- **语义影响**：无（仍可点开订阅 / 详情，不改锁定规则）
- **严重度**：P2

### F-HI-06 时长/成功率环比指示器下跌仍用 btPrimary，与分类对比语义冲突
- **类别**：C视觉
- **位置**：`QiuJi/Features/History/Views/StatisticsView.swift:410-415`（`changeIndicator` 恒 `.foregroundStyle(.btPrimary)`）；对照同文件 `381-384`（分类对比负向用 `.btWarning`）
- **现状**：概况卡右上角 `+x 小时 (+y%)` 无论正负皆 btPrimary；分类格子下跌已用 btWarning。
- **问题**：对照 C2（权重/语义色应与重要性及方向一致）；同页两套涨跌色 = 用户需二次解读。
- **建议**：`percent >= 0` 用 `btPrimary`（或保持现色），`< 0` 用 `btWarning`，与 `categoryComparisonCell` 拉齐；不改数值计算。
- **语义影响**：无（仅着色，不改指标含义）
- **严重度**：P2

### F-HI-07 详情溢出菜单图标色使用系统 `.blue` / `.purple`
- **类别**：D一致性
- **位置**：`QiuJi/Features/History/Views/TrainingDetailView.swift:240-241`
- **现状**：`BTMenuItem(iconColor: .blue, …)`、`iconColor: .purple`；同文件其余项已用 `.btPrimary` / `.btAccent` / `.btDestructive`。
- **问题**：对照 D3（硬编码系统色属 token 逃逸；暗色下与 bt* 语义色体系脱节）。
- **建议**：改为既有语义色（如分享 → `btPrimary`，日历 → `btAccent` 或 `btTextSecondary`），与同菜单其它项一致。
- **语义影响**：无（confirmationDialog 路径甚至不展示 iconColor，改色不影响功能）
- **严重度**：P3

### F-HI-08 成功率图例写「趋势线」，实际为均值 RuleMark
- **类别**：C视觉
- **位置**：`QiuJi/Features/History/Views/StatisticsView.swift:305`（`chartLegend(…, label2: "趋势线")`）；对照 `323-325`（`RuleMark` 画的是 `avg * 100`）；时长卡同结构标为 `"均值线"`（`230`）
- **现状**：两张柱图都是均值参考线，文案一处「均值线」、一处「趋势线」，误导读图。
- **问题**：对照 C6（同一概念跨卡片同一叫法）。
- **建议**：统一为「均值线」（或两者都改为更准确的「平均」）。
- **语义影响**：无（只改正文案，不改图表数据）
- **严重度**：P3

### F-HI-09 日历日标记圆角硬编码 3，不在 BTRadius
- **类别**：D一致性
- **位置**：`QiuJi/Features/History/Views/HistoryCalendarView.swift:196`（`cornerRadius: 3`）；对照 `Spacing.swift` 中 `BTRadius.xs = 6` 起
- **现状**：有训练日的 micro 标签用 `cornerRadius: 3`；卡片本体用 `BTRadius.md`。
- **问题**：对照 D3（magic 圆角）。
- **建议**：用 `BTRadius.xs`（若视觉偏大可评估是否新增更小 token，但本轮以收编到现有 xs 为先）；或与其它 micro chip 统一。
- **语义影响**：无（纯视觉 token）
- **严重度**：P3

### F-HI-10 详情页标题重复：导航 principal 与正文 header 同文案叠两层
- **类别**：C视觉
- **位置**：`QiuJi/Features/History/Views/TrainingDetailView.swift:37-40`（toolbar `.principal`）；`87-91`（`headerSection` 再次 `trainingNameZh`）
- **现状**：sheet 顶栏已显示分类训练名，滚动区顶部再以 `btTitle2` 重复同一字符串，统计条被挤下，一屏双焦点。
- **问题**：对照 C4（一屏强调 ≤1；层级手段重复）。
- **建议**：去掉 `headerSection` 标题，或 toolbar 只留「训练详情」泛称、正文保留大标题——二选一，避免双份。
- **语义影响**：无（信息不删减，只去掉重复呈现）
- **严重度**：P3

---

## D1 动效参数普查表

| 位置 | 当前值 | 判定（吻合/漂移/例外） |
|---|---|---|
| `HistoryCalendarView` 全文 | 无 `withAnimation` / `.animation` / `spring` / `ease*` | **缺席**（选日、换月、列表切换、loading→内容均为硬切；补齐时应收编至基准 `spring(0.34, 0.86)`） |
| `StatisticsView` 全文 | 无页面级 UI chrome 动画；Charts 为数据绘制 | **例外**（图表绘制非 UI chrome） |
| `TrainingDetailView` 全文 | 无进场/按压以外的显式动画；底栏按钮走 `BTButtonStyle`（组件内 scale） | 底栏按压 **吻合**（组件库）；页面其余 **缺席** |
| `HistoryCalendarView` → `BTSegmentedTab` | 分段下划线 `easeInOut(duration: 0.25)`（组件内） | **漂移**（相对基准两套 spring；属组件级，本范围不改组件，仅登记） |
| `HistoryAccessController` | 无 UI | — |

---

## 存疑项（不确定是否越红线的，单独列出待主控裁决，不算 finding）

1. **详情底栏「编辑数据」「复制到今天」及溢出菜单项 action 均为空闭包**（`TrainingDetailView.swift:221-244`）：点按无效果。若补反馈/禁用态属 polish；若实现编辑/复制则越出本轮「不改功能语义」红线。建议主控另开功能任务。
2. **每组始终 `checkmark.circle.fill` + btPrimary**（`TrainingDetailView.swift:192-195`），与进球是否达标无关。若改为按完成度变色，可能被理解为改「组完成」语义，故未收为 finding。
3. **历史空态故意不用整屏 `BTEmptyState`**（`HistoryCalendarView.swift:265` 注释引用 UR-20260529）：与统计页 `BTEmptyState` 形态不一致，但是规避 Tab 遮挡的已知设计取舍；是否在保留紧凑布局前提下统一文案/图标权重，交主控定。
4. **非 Pro 统计：时间范围 pill 在锁罩外可切换**（`StatisticsView.swift:35-46`）：模糊内容随 range 变。属产品门控策略，非纯 polish。
