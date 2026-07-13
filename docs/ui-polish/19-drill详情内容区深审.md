# UI 打磨审阅：Drill 详情内容区深审（DrillDetailView 内容区块 + 精讲入口衔接）

## 与已有条目的边界

| 本文件不收录 | 已收录位置 | 边界说明 |
|---|---|---|
| 伪入口「要点/历史/图表」、备注卡假 affordance | F-DL-01 | 本轮不重复；仅在概述中承认其打断内容区节奏 |
| 底栏空 CTA「加入训练」 | F-DL-02 | 不重复；精讲入口权重问题单独从「内容区入口」角度写 |
| 台面覆层回放/试打按压态 | F-DL-03 / F-SC-* | 台面 chrome 不属本轮 |
| 列表球种 chips | F-DL-04 | 列表页，不属详情内容区 |
| 精讲页分区色 / 球形切换硬切 | F-DL-05 / F-DL-07 | 精讲本体由另审；本轮只审「从详情进精讲」入口与信息衔接 |
| 试打说明卡 token | F-DL-06 | 试打宿主，不属详情 |
| formation sheet 字号/系统色 token | F-DL-08 | 不重复；本轮不因同一 sheet 再开 token 条 |
| formation sheet 强制 dark / detent | 02 存疑 / 13 | 不升格 |
| DrillSceneView 本体 | F-SC-01/02/07 | 豁免内容渲染 + 已审 chrome |
| Freemium 三套视觉语言 / CTA 文案分裂 | F-ST-04 | 不重复；本轮只写详情页 progressive **阅读衔接** |
| `visibleItems` 未消费 | 12 存疑 | 不升格；在存疑中交叉引用 |
| BT* 组件库内部 | 12 | 不审组件实现，只审详情页如何组装 |

**数据事实（Bundle 72 drills，2026-07-13 普查）**：`description` / `coachingPoints`(均为 3 条) / `standardCriteria` / `tutorial` **全非空**；`videos` 有 62、空 10；`description` 均长约 33–67 字。详情页**从不渲染** `description` / `nameEn` / `subcategory`；`difficulty` 仅喂给启发式「训练维度」。

---

## 页面概述

Drill 详情是「决定要不要练」的转化页：首屏台面演示（内容豁免）之后，用户应靠标题摘要、要点、达标、示范与精讲入口完成决策，底栏/试打为行动。当前内容区在伪入口行与备注卡（F-DL-01）之后进入分组卡片——训练要点（含「查看精讲」）、达标标准、训练维度条、视频示范；Premium 时仅要点卡包进 `BTPremiumLock.progressive`，其余内容区块整段不渲染。收藏靠导航栏心形与列表卡共用 SwiftData `@Query`，跨页状态能同步，但切换无过渡反馈。

---

## Findings

### F-DD-01 全库有 `description`，详情转化页却零渲染
- **类别**：C视觉
- **位置**：`QiuJi/Data/Services/DrillContentService.swift:15`（字段存在）；`QiuJi/Features/DrillLibrary/Views/DrillDetailView.swift:42-48`（标题后直接伪入口，无简介）；对照 `DrillTutorialView.swift:131-134`（精讲页才展示）
  ```swift
  Text(drill.nameZh)
      .font(.btTitle)
  // … 无 drill.description
  actionIconRow
  ```
- **现状**：72/72 drill 均有一句中文简介；详情标题下不展示，用户必须点进精讲才能读到「这练什么」。转化页信息层级缺最便宜的决策句。
- **问题**：对照 **C2**（视觉/信息权重应匹配决策重要性——简介应在标题近旁，不应藏到下一页）。
- **建议**：在 `nameZh` 与 tags 之间用 `Font.btCallout` + `.btTextSecondary` 渲染 `drill.description`（与精讲 header 同口径）；不新增字段、不改 IA 分区名。
- **语义影响**：无（只露出已有 Bundle 字段，与精讲页已展示内容同源）。
- **严重度**：P2

### F-DD-02 「训练维度」百分比由 category 启发式编造，伪装成测得权重
- **类别**：C视觉
- **位置**：`QiuJi/Features/DrillLibrary/Views/DrillDetailView.swift:399-445`（switch 赋初值）；`:362-364`（以 `Int(dim.value * 100)%` 展示）
  ```swift
  case "accuracy":
      accuracy = 0.7 + diff * 0.2
  // …
  Text("\(Int(dim.value * 100))%")
  ```
- **现状**：无 JSON/模型维度字段；五条进度条 + 精确百分数完全由 `category`+`difficulty` 公式生成，且各维独立封顶 1.0（可同时「准度 90% + 力量 40%…」），读感像测评结果。
- **问题**：对照 **C4**（用高对比进度条+数字制造虚假精度焦点）；属「空数据假装有内容」的变体——有 UI 壳、无真实数据。
- **建议**：保留分区亦可，但去掉精确 `%`，改为定性（高/中/低）或弱化条（单色矮轨 + 文案「参考倾向，非测评」）；禁止暗示可加总的权重语义。不新增真实测评功能。
- **语义影响**：无（不增删训练能力模型，只纠正呈现诚实度）。
- **严重度**：P2

### F-DD-03 无视频时仍铺三枚幽灵缩略图，空区块假装片库
- **类别**：C视觉
- **位置**：`QiuJi/Features/DrillLibrary/Views/DrillDetailView.swift:466-502`
  ```swift
  if videos.isEmpty {
      emptyVideoPlaceholder  // ForEach(0..<3) 灰块 + play.slash +「即将上线」
  }
  ```
- **现状**：10/72 drill `videos` 为空时，仍横向排出 3 个 96×64 灰块播放图标，视觉密度接近「有片可点」，仅靠末尾「即将上线」纠偏。
- **问题**：对照 **C1/C4**（空态不应抢内容主角位、不应伪造内容密度）；转化页滚动成本被三枚假缩略图抬高。
- **建议**：空态改为单行弱文案或 `BTEmptyState` 级紧凑提示（无多枚假封面）；有视频时保持现横向缩略列。
- **语义影响**：无（不改变有视频时的播放入口与条数展示）。
- **严重度**：P2

### F-DD-04 Progressive 遮罩切穿要点卡内真实「查看精讲」主钮
- **类别**：B微交互 / C视觉
- **位置**：`QiuJi/Features/DrillLibrary/Views/DrillDetailView.swift:52-57` + `:279-286`；遮罩行为 `BTPremiumLock.swift:36-50`（`allowsHitTesting(false)` + 固定渐隐）
  ```swift
  BTPremiumLock(mode: .progressive(visibleItems: 1), …) {
      coachingSection(drill)  // 内含 BTButtonStyle.primary「查看精讲」
  }
  ```
- **现状**：锁定态把整块要点卡（含编号列表与精讲主色按钮）送进渐隐 mask；按钮半透明可见但不可点，易读成「坏掉的入口」而非「需解锁」。
- **问题**：对照 **B3**（锁定态反馈应诚实）、**C2**（真 CTA 形态出现在不可用区 = 权重误导）。异于 F-ST-04（三套锁语言），本条专指详情组装把可点 chrome 放进 progressive 内容槽。
- **建议**：锁定态 `coachingSection` 不渲染「查看精讲」，或把精讲钮挪到 mask 外并改为「解锁后查看精讲」弱样式；保持 Freemium 门槛不变。
- **语义影响**：无（不提前解锁精讲，只避免假可点）。
- **严重度**：P2

### F-DD-05 精讲入口仅埋在要点卡底，与精讲页头信息重复且简介错位
- **类别**：C视觉
- **位置**：详情入口 `DrillDetailView.swift:279-286`；精讲头 `DrillTutorialView.swift:115-134`（再次 category + level + nameZh + **description**）
  ```swift
  // 详情：仅在要点卡底部
  Button { showTutorial = true } label: { Text("查看精讲") }
      .buttonStyle(BTButtonStyle.primary)
  ```
- **现状**：从详情进精讲后，前三屏信息大量重复（分类/等级/标题）；用户真正尚未在详情读过的 `description` 却出现在精讲头。入口本身也远离标题决策区，夹在要点列表与（解锁后才有的）达标卡之间。
- **问题**：对照 **C2**（转化页主内容路径应靠近决策点）、**C6**（跨页同一元数据不应迫使用户重读一遍才看到简介——与 F-DD-01 联动）。
- **建议**：详情标题区补简介（F-DD-01）后，精讲头可弱化/省略重复的 name+badge 行，或入口旁加一句「图文分步」副文降低预期重叠感；入口可保留在要点卡，但避免再与空底栏主 CTA 抢「唯一主色按钮」心智（底栏空壳见 F-DL-02，此处不重复开方）。
- **语义影响**：无（不改 push 精讲路由与 tutorial 数据模型）。
- **严重度**：P2

### F-DD-06 视频缩略图按钮无按压态
- **类别**：B微交互
- **位置**：`QiuJi/Features/DrillLibrary/Views/DrillDetailView.swift:505-519`
  ```swift
  Button { playingVideo = video } label: { … }
      .buttonStyle(.plain)
  ```
- **现状**：有视频时可点缩略图进 `DrillVideoPlayerSheet`，但 `.plain` 无 scale/高亮；与同页 `BTButtonStyle` / `GoldFilledButtonStyle` 按压反馈不一致。
- **问题**：对照 **B1**（主要可点控件应有按下即时反馈）。
- **建议**：轻量 `ButtonStyle`（按下 `scale 0.96–0.98` + 透明度微变，~100ms），保持 96×64 封面形态。
- **语义影响**：无。
- **严重度**：P2

### F-DD-07 收藏切换无过渡，仅系统图标瞬间替换
- **类别**：A动效 / B微交互
- **位置**：`QiuJi/Features/DrillLibrary/Views/DrillDetailView.swift:88-94`；`:571-576`
  ```swift
  Button { toggleFavorite() } label: {
      Image(systemName: isFavorited ? "heart.fill" : "heart")
  }
  // toggleFavorite：delete / insert，无 withAnimation / symbolEffect
  ```
- **现状**：心形填色瞬间切换；列表卡角标经 `@Query` 能同步（跨页状态正确），但详情触发点缺少可感知反馈。列表侧收藏同样无动画（同模型），详情作为决策页更需确认感。
- **问题**：对照 **A6**（状态变化突现）、**B1**（关键次操作缺即时反馈）。
- **建议**：`toggleFavorite` 外包短 `withAnimation`（`easeInOut(0.15–0.2)` 或 `symbolEffect(.bounce)`）；不改 SwiftData 写入语义。
- **语义影响**：无。
- **严重度**：P3

### F-DD-08 内容区 chrome 字号/圆角 token 逃逸
- **类别**：D一致性
- **位置**：
  - 维度条：`DrillDetailView.swift:369-374`（`cornerRadius: 3`）
  - 空视频图标：`:492-493`（`.system(size: 22)`）
  - 缩略播放标：`:648-649`（`.system(size: 26)`）
  ```swift
  RoundedRectangle(cornerRadius: 3)
  Image(systemName: BTIcon.playSlashed).font(.system(size: 22))
  ```
- **现状**：同页区块标题/正文已走 `Font.bt*` + `BTRadius.md`，维度轨与视频区 chrome 仍用字面量圆角与 system 字号。
- **问题**：对照 **D3**（页面 chrome 硬编码；非台面 Canvas 豁免范围）。
- **建议**：圆角收近 `BTRadius.xs`（或共享 2–4pt track token）；图标改 `Font.btTitle` / `btTitle2` 等最接近档。
- **语义影响**：无。
- **严重度**：P3

### F-DD-09 Premium progressive 衔接：要点卡中部渐隐后突接大块锁区，阅读节奏断裂
- **类别**：C视觉
- **位置**：组装 `DrillDetailView.swift:52-63`（锁定只包 `coachingSection`，达标/维度/视频整段省略）；渐隐+CTA `BTPremiumLock.swift:36-58`（mask 后 `padding(.vertical, Spacing.xxl)` 锁区）
  ```swift
  if isLocked {
      BTPremiumLock(…) { coachingSection(drill) }
  } else {
      coachingSection(drill)
      criteriaSection(drill) …
  }
  ```
- **现状**：免费用户看到连续四张内容卡；锁定用户在伪入口/备注后只见一张被竖向切半的要点卡，随即落到页面底色上的锁图标+描边 CTA（大段垂直空白）。转化阅读在「内容卡 → 付费墙」之间缺少同一容器的收束，像页面截断而非有意预览。
- **问题**：对照 **C3**（组间节奏）与 **C2**（付费墙应接在预览内容的明确边界上，而非卡内腰斩）。不重复 F-ST-04 的文案/按钮族分裂。
- **建议**：让 mask 落点对齐卡片底边（或预览仅露标题+首条要点），CTA 视觉上承接同一 `btBGSecondary` 卡片/分组；**不**在本条要求把达标/视频移出付费墙（见存疑）。
- **语义影响**：无（不改变 `isPremium` 门槛与可解锁范围，只调预览裁切与分组外形）。
- **严重度**：P2

---

## D1 动效参数普查表

| 位置 | 当前值 | 判定（吻合/漂移/例外） |
|---|---|---|
| `DrillDetailView.swift:739` `GoldFilledButtonStyle` 按压 | `easeInOut(duration: 0.1)` | 吻合（按压带，与 BTButton 同族） |
| 收藏 toggle（`:88-94` / `:571-576`） | **无** animation / symbolEffect | 缺口（见 F-DD-07） |
| 视频缩略 Button（`:519`） | `.plain`，无按压动画 | 缺口（见 F-DD-06） |
| 内容区块显隐 / progressive 组装 | 无进场 transition | 中性（锁态由组件静态 mask，非进出场） |
| 本文件范围 | **未使用**基准 spring `0.34/0.86`、`0.35/0.75` | 事实：详情内容区 chrome 几乎无布局 spring 需求 |

---

## 存疑项（不确定是否越红线的，单独列出待主控裁决，不算 finding）

1. **锁定态是否应露出「达标标准」**：达标句对「要不要练」决策很关键，现随 Premium 整段隐藏。若露出算放宽预览、可能触碰 Freemium 语义——本轮 F-DD-09 只收阅读衔接，不建议改门槛。
2. **`visibleItems: 1` 未消费**：已在 `12-基础组件库补审.md` 存疑；详情传入值与真实裁切无关，修复会改变露出量，仍待主控。
3. **导航栏 `principal` 与正文 `nameZh` 双标题**：inline 顶栏 + 台下再挂一级标题，首屏重复。属常见模式还是 C4 噪音，体验确认后再定。
4. **训练维度分区去留**：F-DD-02 建议去伪精度；若产品认定「启发式倾向」是正式功能，则只改文案口径而非弱化条形。
5. **formation 列表项「chevron = 将 push」心智**：选中实为 dismiss sheet + 另路 `navigationDestination`，形态已由 F-DL-08 管 token，交互隐喻是否单开另议。
