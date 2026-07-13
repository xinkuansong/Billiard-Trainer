# UI 打磨审阅：动作库 Tab（DrillListView / DrillDetailView / DrillTutorialView / DrillTryoutBrief）

## 页面概述

**DrillListView（动作库根页）**：双栏浏览——左侧分类侧栏 + 右侧网格卡片；顶部搜索与球种 Capsule chips 过滤；空态/骨架已接 BTEmptyState、BTDrillListSkeleton。核心交互是筛选用、点卡片进详情。

**DrillDetailView（动作详情）**：首屏主角是内嵌 `DrillSceneView`（USDZ 顶视回放 +「上手试打」入口）；下方为标题、伪入口图标行、标签、备注占位、训练要点/达标/维度/视频；底栏「关闭 / 加入训练」或 Pro 解锁。试打多球形走 formation sheet。

**DrillTutorialView（图文精讲）**：长文分区卡片（原理/要领/错误/进阶）+ 可选多球形 sticky segmented；配图可进全屏 `TutorialMediaViewer`（缩放 / 下滑关闭 / 循环 clip）。

**DrillTryoutBriefCard（试打进场说明卡）**：非 modal 半透明 HUD 卡，三行从 drill JSON 生成；点卡或首次交互淡出，顶栏 info 可召回（进出场动画由宿主 `PositionPlayComposerView` 驱动）。

## Findings

### F-DL-01 详情页「要点 / 历史 / 图表」与备注卡具备按钮形态却无交互
- **类别**：B微交互 / C视觉
- **位置**：`QiuJi/Features/DrillLibrary/Views/DrillDetailView.swift:192-214`；同文件 `327-343`
- **现状**：`actionIconRow` 用 44×44 圆形底 + 图标 + 文案，视觉等同可点入口，但实现为纯 `VStack`，无 `Button`/`onTapGesture`。`notesCard` 文案为「点击此处输入备注」，同样无点击手势。
- **问题**：对照 B1（可点元素应有按压反馈——此处连可点性都不存在却伪装成有）、C2（视觉权重暗示次级导航，实际死触）。
- **建议**：在功能未接线前，去掉圆形「按钮底」与「点击此处」措辞，改为静态信息行/弱标签（例如仅图标+标题、备注改为「备注（即将支持）」或省略卡），避免误触反馈真空；接线后再恢复按压态与真实入口。
- **语义影响**：无（不增删已上线能力，只纠正虚假 affordance，不改变筛/试打/精讲等既有路径）。
- **严重度**：P2

### F-DL-02 底栏主 CTA「加入训练」为空实现，主操作点击无结果
- **类别**：B微交互 / C视觉
- **位置**：`QiuJi/Features/DrillLibrary/Views/DrillDetailView.swift:546-555`
- **现状**：解锁态底栏右侧使用 `BTButtonStyle.primary` 的「加入训练」，`action` 内仅 `// TODO: Add to active training`，点击无状态变化。
- **问题**：对照 B3（完成/失败需诚实反馈）、C2（主操作应最显著——当前最显著按钮是空壳，与「上手试打」真入口权重倒挂）。
- **建议**：接线前将按钮 `.disabled(true)` 或降为 `secondary`/`text` 并附短暂不可用说明（不新增功能）；或临时隐藏该 CTA，把视觉焦点留给已可用的台面「上手试打」与「查看精讲」。
- **语义影响**：无（不改变训练加入的产品语义定义，只避免空主按钮骗点击）。
- **严重度**：P2

### F-DL-03 台面覆层「回放 / 上手试打」按钮无按压态
- **类别**：B微交互
- **位置**：`QiuJi/Core/Scene/DrillSceneView.swift:354-366`；同文件 `370-390`
- **现状**：播放圆钮与「上手试打」胶囊均为默认 `Button` + `.black.opacity(0.4)` 底，未使用 `BTButtonStyle` 或自定义 `ButtonStyle`，无 `scaleEffect` / 高亮按压。
- **问题**：对照 B1（主要操作按钮无按压态 = P2）；二者是详情页台面层最高频 chrome 操作。
- **建议**：为两钮加轻量 `ButtonStyle`（按下 `scale 0.96–0.98` + 背景 opacity 微变，时长 ~100ms，对齐 `BTButtonStyle` 既有 `easeInOut(0.1)`），保持现有 32pt 高度与半透明黑胶囊形态不变。
- **语义影响**：无（不改变回放/试打入口语义与 Freemium 锁定行为）。
- **严重度**：P2

### F-DL-04 球种 chips 手写反色填充 + 无按压态，与设计系统 segmentedPill 漂移
- **类别**：D一致性 / B微交互
- **位置**：`QiuJi/Features/DrillLibrary/Views/DrillListView.swift:15-23`；同文件 `209-234`
- **现状**：`chipActiveFill` / `chipActiveText` 使用硬编码 `Color(red: 0xF2…)` / `0x1C…` 与 `UIColor.systemBackground` 做「反色选中」；chip `Button` 无 `buttonStyle` 按压缩放。同库已有 `BTButtonStyle.segmentedPill`（选中 `btPrimary` 实底、未选描边、按下 scale 0.96）。
- **问题**：对照 D3（硬编码色）、D4（手写替身）、B1（高频过滤控件缺即时按压反馈）。
- **建议**：优先复用 `BTButtonStyle.segmentedPill(isSelected:)`（或抽共享 light-surface chip token）；若刻意保留反色选中，也应收编为 DesignSystem 语义色而非页面内 `Color(red:)`，并补上与 segmentedPill 同级的按压 scale。
- **语义影响**：无（过滤选项与交互模型不变，仅视觉/反馈收编）。
- **严重度**：P2

### F-DL-05 精讲多球形切换时正文区无过渡，内容硬切
- **类别**：A动效
- **位置**：`QiuJi/Features/DrillLibrary/Views/DrillTutorialView.swift:59-66`；同文件 `98-108`
- **现状**：`Picker` 绑定 `selectedFormation` 驱动 `sectionList`；切换时无 `withAnimation` / `.animation` / `.transition`，下方整块卡片瞬间替换。
- **问题**：对照 A6（元素出现/消失无过渡造成跳变 = P2）；球形切换属中频操作，适合短 opacity 交叉淡入。
- **建议**：对 `selectedFormation` 包 `withAnimation(.easeInOut(duration: 0.2))`（或基准 spring `0.34/0.86`），`sectionList` 加 `.transition(.opacity)`，保持 sticky picker 与内容结构不变。
- **语义影响**：无（不改变多球形数据模型与分段内容）。
- **严重度**：P2

### F-DL-06 试打说明卡字号/间距/圆角未走 token（HUD chrome）
- **类别**：D一致性
- **位置**：`QiuJi/Features/PositionPlay/Views/DrillTryoutBrief.swift:127-151`
- **现状**：标签/正文/脚注分别 `.system(size: 11/12/10.5)`；行间距 `6`、标签间距 `8`；`cornerRadius: 12` 字面量（恰等于 `BTRadius.md` 却未引用）。
- **问题**：对照 D3（页面 chrome 硬编码字号/间距/圆角）；基准豁免的是台面 Canvas 标注，本卡为可点 HUD chrome。
- **建议**：字号收编到最近 `Font.bt*`（如 `btCaption2` / `btCaption` / `btMicro`），间距改 `Spacing.xs`/`sm`，圆角改 `BTRadius.md`；保持 `btHudGlass` 与点关闭行为不变。
- **语义影响**：无（文案生成逻辑与三行结构不变）。
- **严重度**：P3

### F-DL-07 精讲分区强调色使用系统 `.blue` / `.orange` / `.purple`
- **类别**：D一致性 / C视觉
- **位置**：`QiuJi/Features/DrillLibrary/Views/DrillTutorialView.swift:149-154`；同文件 `156-161`
- **现状**：`sectionColors` / `itemLabelColors` 混用系统色与 `btPrimary`，图标圆底随系统色变化。
- **问题**：对照 D3（硬编码非 `Color.bt*`）；C5 下系统色与品牌绿并存时暗色层级易「花」、与训练 Tab 卡片强调不一致。
- **建议**：映射到已有语义色（如原理→`btPrimary`/`btPrimaryMuted`，错误→`btWarning`，进阶→`btAccent` 或单一中性+字重层级），避免一屏多饱和色抢正文。
- **语义影响**：无（分区标题与正文内容不变，仅强调色收编）。
- **严重度**：P3

### F-DL-08 多球形试打选择 sheet 混用系统字号与 `.primary`/`.secondary`
- **类别**：D一致性
- **位置**：`QiuJi/Features/DrillLibrary/Views/DrillDetailView.swift:163-178`
- **现状**：序号用 `.system(size: 15, weight: .bold, design: .rounded)`；标题/副文用 `.foregroundStyle(.primary)` / `.secondary` / `.tertiary`，未走 `btBody`/`btText*`。
- **问题**：对照 D3；同页其余区块已用 `Font.bt*` + `btText`，sheet 成为孤岛。
- **建议**：序号改 `Font.btSubheadline`/`btCallout` + `.btPrimary`；文案改 `.btText` / `.btTextSecondary` / `.btTextTertiary`；保持 List 结构与选中即进试打流程。
- **语义影响**：无。
- **严重度**：P3

## D1 动效参数普查表

| 位置 | 当前值 | 判定（吻合/漂移/例外） |
|---|---|---|
| `DrillListView.swift:215` 球种 chip 切换 | `easeInOut(duration: 0.2)` | 吻合（高频过滤，≤300ms；短于基准 spring 合理） |
| `DrillListView.swift:160` 骨架 | `.transition(.opacity)`（无显式 animation 包裹加载态） | 漂移/缺口：过渡声明在，但 `isLoading` 切换未见配套 `withAnimation` |
| `DrillSceneView.swift:352` 击球前 overlay 显隐 | `easeInOut(duration: 0.2)` | 例外偏吻合：贴内容指示器淡入淡出，短时长合理 |
| `DrillDetailView.swift:739` `GoldFilledButtonStyle` 按压 | `easeInOut(duration: 0.1)` | 吻合（与 `BTButtonStyle` 按压同族） |
| `DrillTutorialView.swift:472-473` `ZoomableContainer` | `.interactiveSpring()` on `scale` / `dismissDrag` | 例外：手势动量缩放/下滑关闭，A7 允许拖拽释放类 bounce |
| 宿主 `PositionPlayComposerView.swift:155` 说明卡进场 | `easeInOut(duration: 0.35).delay(0.6)` | 例外：低频首次 delight（基准 A3）；时长落在面板 200–350ms 上沿，delay 属进场编排而非 chrome 超时 |
| 宿主同文件 `171` / `279` 说明卡出场 | `easeOut(duration: 0.25)` | 吻合（先快后慢出场） |
| 宿主同文件 `177` info 召回 toggle | `easeInOut(duration: 0.25)` | 吻合 |
| 宿主同文件 `154` 试打舞台揭示 | `easeIn(duration: 0.45).delay(0.1)` | 漂移且触 A1：UI 进场用了 `easeIn`（本卡范围外宿主，记入存疑） |
| 本范围 View 内 | **未使用**基准两套 `spring(0.34/0.86)`、`spring(0.35/0.75)` | 事实：动作库 Tab chrome 以短 ease 为主，无面板 spring 收编对象 |

## 存疑项（不确定是否越红线的，单独列出待主控裁决，不算 finding）

1. **详情伪入口「要点 / 历史 / 图表」是否计划接线**：若产品已排期，打磨应只做「待上线」弱化；若永久不做，删除整行是否算「删功能入口」需主控拍板（F-DL-01 仅建议去按钮态，未建议删行）。
2. **「加入训练」空 CTA**：隐藏 vs disabled 是否触及信息架构（底栏双钮布局），待产品确认（F-DL-02 给了多选一建议）。
3. **试打舞台 `easeIn(0.45)` 揭示**（`PositionPlayComposerView:154`）：属试打页宿主、非 Brief 文件本身；是否纳入动作库范围的动效收编，待主控划界。
4. **`DrillSceneView` 台面内力度条绿→黄→橙渐变与 8pt 速度字**（`DrillSceneView.swift:514-522`）：偏内容渲染标注，是否按 D3 收编有歧义，本轮未记 finding。
5. **详情强制 `.preferredColorScheme(.dark)` 于 formation sheet**（`DrillDetailView.swift:187`）：为与试打暗场衔接的有意设计还是 light 用户突兀，需体验确认后再定是否算 C5 问题。
