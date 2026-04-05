## UI 审查报告 — 动作库列表 + 详情 + 收藏夹（Light Mode 代码审查）

日期：2026-04-06
任务：T-R1-05
审查对象：`DrillListView.swift`（217 行）、`DrillDetailView.swift`（335 行）、`FavoriteDrillsView.swift`（79 行）
设计参考：P1-01 ~ P1-04 stitch + code.html、P2-07 stitch、UI-IMPLEMENTATION-SPEC § 四 Tab 2 / § 七

---

### U-01 BTDrillCard 等级标签位置反转

- **类别**：产品规格
- **严重程度**：P1
- **位置**：Tab 2 > 动作库列表 > BTDrillCard 所有实例
- **现状**：BTLevelBadge 位于 Drill 名称**左侧**（`HStack { BTLevelBadge; Text(nameZh) }`）
- **预期**：设计稿 P1-01 code.html 使用 `flex justify-between items-start`，标签在名称**右侧**。截图同样显示 badge 在行右端。
- **修复方向**：将 BTDrillCard 内 `HStack` 中 BTLevelBadge 移至 Text 之后，或使用 Spacer 将 badge 推到右端。
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Core/Components/BTDrillCard.swift` L33-39

---

### U-02 BTDrillCard 卡片布局结构与设计稿偏差

- **类别**：产品规格
- **严重程度**：P1
- **位置**：Tab 2 > 动作库列表 > BTDrillCard 所有实例
- **现状**：卡片显示三行（名称行、分类·球种+难度圆点行、"3组×15球"行），右侧上方为心形/锁图标，下方 chevron。
- **预期**：设计稿 P1-01 显示两行（名称行 + "通用 · 推荐 2 组"行），右侧仅 chevron 居中。无难度圆点行，无第三行。Pro 卡片的 PRO 标签与 Level 标签并排在名称右侧。
- **修复方向**：
  1. 移除 `difficultyDots` 组件（设计稿中无此元素）
  2. 将第二行改为「球种 · 推荐 X 组」格式
  3. 移除第三行 "X组×Y球"
  4. 右侧改为单独 chevron 居中对齐；收藏心形可移至其他位置或保留为增强功能
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Core/Components/BTDrillCard.swift` L28-84

---

### U-03 DrillDetailView 缺少球台下方 Drill 大标题

- **类别**：产品规格
- **严重程度**：P1
- **位置**：Tab 2 > 动作详情 > 球台下方区域
- **现状**：球台下方直接显示操作图标行（要点/历史/图表），Drill 名称仅出现在 `.navigationTitle`（inline 导航栏标题）。
- **预期**：设计稿 P1-03 code.html 在球台下方有独立大标题 `<h1 class="text-[22px] font-headline font-extrabold">直线球定点练习</h1>`。截图同样显示球台下方有 22pt Bold 的 Drill 名称。
- **修复方向**：在 `tableSection` 和 `actionIconRow` 之间增加一行 `Text(drill.nameZh).font(.btTitle).foregroundStyle(.btText)` 左对齐。
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/DrillLibrary/Views/DrillDetailView.swift` L29-33

---

### U-04 FavoriteDrillsView 导航标题与显示模式不符

- **类别**：产品规格
- **严重程度**：P1
- **位置**：Tab 5 > 我的 > 收藏夹
- **现状**：标题为"收藏夹"，使用 `.navigationBarTitleDisplayMode(.large)`（大标题模式）。
- **预期**：设计稿 P2-07 截图显示标题"我的收藏"，居中小标题，back 按钮 "< 我的"。属 push 子页面，应使用 `.inline` 模式。UI-IMPLEMENTATION-SPEC § 三 明确 push 子页面使用「返回箭头 + 17pt Semibold 居中标题」。
- **修复方向**：
  1. 将 `.navigationTitle("收藏夹")` 改为 `.navigationTitle("我的收藏")`
  2. 将 `.navigationBarTitleDisplayMode(.large)` 改为 `.inline`
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/Profile/Views/FavoriteDrillsView.swift` L41-42

---

### U-05 FavoriteDrillsView 空状态缺 CTA 按钮且文案偏差

- **类别**：产品规格
- **严重程度**：P1
- **位置**：Tab 5 > 我的 > 收藏夹（空状态）
- **现状**：空状态显示 icon `heart.slash` + 标题"还没有收藏" + 副标题"在动作库中点击心形图标收藏训练项目"，无 CTA 按钮。
- **预期**：设计稿 P2-07 空状态截图显示"还没有收藏" + 副标题"去动作库看看吧" + 绿色 CTA 按钮"浏览动作库"。图标为星形而非心形。
- **修复方向**：
  1. 副标题改为"去动作库看看吧"
  2. 添加 `actionTitle: "浏览动作库"` + 对应导航跳转 action
  3. 图标考虑改为 `star` 或保持 `heart.slash`（与收藏语义一致）
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/Profile/Views/FavoriteDrillsView.swift` L16-20

---

### U-06 DrillListView 搜索无结果空状态缺 CTA 按钮且文案偏差

- **类别**：产品规格
- **严重程度**：P1
- **位置**：Tab 2 > 动作库列表（搜索无结果）
- **现状**：显示"没有找到相关训练项目" + "试试换个关键词搜索"，无 CTA。
- **预期**：设计稿 P1-02 显示"没有找到相关动作" + "试试其他关键词或浏览分类" + 绿色 CTA 按钮"浏览全部动作"。
- **修复方向**：
  1. 标题改为"没有找到相关动作"
  2. 副标题改为"试试其他关键词或浏览分类"
  3. 添加 `actionTitle: "浏览全部动作"` + 清空搜索词的 action
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/DrillLibrary/Views/DrillListView.swift` L33-43

---

### U-07 DrillListView 筛选 Chip 使用硬编码 .black / .white

- **类别**：Design Token
- **严重程度**：P2
- **位置**：Tab 2 > 动作库列表 > 筛选 Chip 行
- **现状**：`chipSelectedText` 使用 `colorScheme == .dark ? .black : .white`，`chipSelectedFill` 使用 `Color(red: 0xF2/255, ...)` 硬编码 hex。
- **预期**：SKILL.md § 十五 Dark Mode 检查清单要求「所有颜色使用 Token，无硬编码 hex / `.white` / `.black`」。虽然 Chip 选中色确实无现成 Token，但 `.black` / `.white` 应替换为语义等价色或新建 Token。
- **修复方向**：考虑新建 `btChipSelectedFill` / `btChipSelectedText` Token 在 Assets.xcassets 中定义 Light/Dark 变体；或至少使用 `Color.btText` 替代 `.black`、`Color.btBG` 方向逆向映射（但语义不同，需确认）。
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/DrillLibrary/Views/DrillListView.swift` L10-18

---

### U-08 DrillListView Section 标题样式与设计稿偏差

- **类别**：视觉打磨
- **严重程度**：P2
- **位置**：Tab 2 > 动作库列表 > 分类 Section 标题行
- **现状**：标题行包含品牌绿分类图标 + btHeadline (17pt semibold) 文字 + 灰色"X 项"计数胶囊。
- **预期**：设计稿 P1-01 code.html Section 标题为 `text-xl font-bold`（约 20pt bold），无图标，无计数胶囊。部分 Section 有右侧品牌绿"更多"链接。
- **修复方向**：
  1. 移除分类图标前缀
  2. 字体改为 `btTitle2`（20pt semibold）或 `btTitle`（22pt bold）更贴近设计
  3. 移除计数胶囊
  4. 考虑添加可选"更多"链接
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/DrillLibrary/Views/DrillListView.swift` L162-185

---

### U-09 DrillListView 两行 Chip 字号不一致

- **类别**：Design Token
- **严重程度**：P2
- **位置**：Tab 2 > 动作库列表 > 球种筛选行 vs 分类筛选行
- **现状**：球种行 Chip 使用 `btSubheadlineMedium`（15pt Medium），分类行 Chip 使用 `btCaption`（12pt Regular）。两行视觉大小差距明显。
- **预期**：设计稿 P1-01 code.html 两行均使用 `text-sm font-medium`（约 14px Medium）。两行应视觉一致。
- **修复方向**：统一两行 Chip 字体为 `btFootnote14`（14pt Regular）或 `btSubheadlineMedium`（15pt Medium），保持一致。
- **路由至**：swiftui-developer
- **代码提示**：`DrillListView.swift` L67 vs L121-122

---

### U-10 DrillDetailView 缺少备注输入区

- **类别**：产品规格
- **严重程度**：P2
- **位置**：Tab 2 > 动作详情 > Tags 与训练要点之间
- **现状**：Tags 行后直接进入训练要点（或 Pro 锁定内容），无备注输入卡片。
- **预期**：设计稿 P1-03 / P1-04 在 Tags 与训练要点之间有一张备注卡片："✏️ 点击此处输入备注"（白色圆角卡片，灰色编辑图标 + 占位符文字）。
- **修复方向**：在 `tagsRow` 之后添加备注输入卡片组件（可点击跳转编辑或内联 TextField）。
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/DrillLibrary/Views/DrillDetailView.swift` L29-45 之间

---

### U-11 DrillDetailView 缺少训练维度进度条区

- **类别**：产品规格
- **严重程度**：P2
- **位置**：Tab 2 > 动作详情（非锁定态）> 训练要点下方
- **现状**：训练要点后显示"达标标准"（target 图标 + 标准文字 + 默认组数文字），为简单文本展示。
- **预期**：设计稿 P1-03 在训练要点之后有"训练维度"区，包含 5 个维度（准度 85%、力量控制 40%、走位判断 60%、杆法技巧 30%、心理素质 20%）的水平进度条，底部注释"此 Drill 主要训练准度能力"。
- **修复方向**：如 DrillContent 数据模型中无维度数据，可先标注为 TODO 或使用 placeholder。若有数据，实现水平进度条卡片。当前"达标标准"区可保留但样式需对齐设计（或考虑合并）。
- **路由至**：swiftui-developer / data-engineer（数据模型）
- **代码提示**：`DrillDetailView.swift` L198-225

---

### U-12 DrillDetailView 工具栏图标从分享变为心形

- **类别**：产品规格
- **严重程度**：P2
- **位置**：Tab 2 > 动作详情 > 导航栏右上角
- **现状**：导航栏右上角为收藏心形图标（heart / heart.fill），切换收藏状态。
- **预期**：设计稿 P1-03 / P1-04 右上角为分享图标（share / ios_share）。收藏功能在球台叠加层（"❤️ 收藏"胶囊按钮）上。
- **修复方向**：右上角改为分享图标；收藏功能可保留在球台叠加层或另择位置。属设计意图确认范畴，建议与产品确认。
- **路由至**：swiftui-developer
- **代码提示**：`DrillDetailView.swift` L62-69

---

### U-13 DrillListView 搜索提示文案偏差

- **类别**：产品规格
- **严重程度**：P2
- **位置**：Tab 2 > 动作库列表 > 搜索框
- **现状**：搜索框 placeholder 为"搜索训练项目"。
- **预期**：设计稿 P1-01 code.html 搜索框 placeholder 为"搜索动作"。
- **修复方向**：将 `.searchable(text:prompt:)` 的 prompt 改为"搜索动作"。
- **路由至**：swiftui-developer
- **代码提示**：`DrillListView.swift` L50

---

### 审查总结

- **截图数量**：6 张设计稿 stitch（P1-01 ~ P1-04、P2-07 有/空）+ 对应 code.html
- **发现问题**：13 项（P0: 0 / P1: 6 / P2: 7）
- **总体评价**：三个页面的核心框架（导航结构、组件选用、Dark Mode Token、底栏按钮样式）已基本就位，大部分已知偏差修正（灰色图标行、darkPill+primary 底栏、Pro 金色填充按钮）已正确实施。主要偏差集中在 BTDrillCard 卡片内部布局（badge 位置、行结构）与设计稿有显著差异，以及 FavoriteDrillsView 的导航模式/空状态功能缺失。
- **建议下一步**：
  1. **优先修复 U-01 + U-02**：BTDrillCard 被多处复用（DrillList、FavoriteDrills、PlanDetail、CustomPlanBuilder 等），修正后收益最大
  2. **修复 U-04**：FavoriteDrillsView 导航模式与空状态
  3. **修复 U-03**：DrillDetailView 大标题
  4. P2 项可在后续打磨阶段统一处理
