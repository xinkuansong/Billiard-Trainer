## UI 审查报告 — 角度训练模块（AngleHome / AngleTest / ContactPointTable / AngleHistory / BTAngleTestTable）
日期：2026-04-06
审查任务：T-R1-06
模式：代码审查 + 设计稿对照（Light Mode stitch）

---

### U-01 AngleHistoryView 缺少时间周期选择器（周/月/全部）
- **类别**：产品规格
- **严重程度**：P1（功能缺失）
- **位置**：角度 > 测试历史 > statsGrid 与 trendSection 之间
- **现状**：代码只有「角袋/中袋」袋型切换（`pocketToggle`），没有时间范围筛选器
- **预期**：设计稿 `P1-06/screen.png` 在统计卡片与趋势图之间显示「周 · 月 · 全部」分段选择器，点选后过滤趋势与统计数据
- **修复方向**：在 `statsGrid` 与 `trendSection` 之间添加 `BTSegmentedTab`（或 `Picker` segmented style），并在 ViewModel 中添加时间范围过滤逻辑
- **路由至**：swiftui-developer + data-engineer
- **代码提示**：`AngleHistoryView.swift` L11-32、`AngleHistoryViewModel.swift`（需添加时间过滤参数）

---

### U-02 AngleHomeView 功能卡片图标容器形状与设计不符
- **类别**：视觉打磨
- **严重程度**：P2
- **位置**：角度 > 首页 > FeatureCard 图标区域
- **现状**：代码使用 `RoundedRectangle(cornerRadius: BTRadius.md)`（12pt 圆角矩形），尺寸 52×52
- **预期**：设计稿 `P1-05/code.html` L100 显示 `w-12 h-12 rounded-full`（48×48 正圆形），同时在 btPrimary 10% 背景上
- **修复方向**：将 `.clipShape(RoundedRectangle(...))` 改为 `.clipShape(Circle())`，frame 调整为 48×48 以匹配设计
- **路由至**：swiftui-developer
- **代码提示**：`AngleHomeView.swift` L88-90（FeatureCard 图标容器）

---

### U-03 AngleHomeView 功能卡片圆角使用 BTRadius.md(12) 而设计为 16pt
- **类别**：Design Token
- **严重程度**：P2
- **位置**：角度 > 首页 > FeatureCard 外框
- **现状**：代码使用 `BTRadius.md`（12pt）
- **预期**：设计稿 `P1-05/code.html` L99 显示 `rounded-[16px]` → 应使用 `BTRadius.lg`（16pt）
- **修复方向**：将 FeatureCard 的 `.clipShape(RoundedRectangle(cornerRadius: BTRadius.md))` 改为 `BTRadius.lg`
- **路由至**：swiftui-developer
- **代码提示**：`AngleHomeView.swift` L90, L114

---

### U-04 AngleHomeView 功能卡片副标题字体 Token 偏小
- **类别**：Design Token
- **严重程度**：P2
- **位置**：角度 > 首页 > FeatureCard 副标题
- **现状**：使用 `.btCaption`（12pt）
- **预期**：设计稿显示 `text-[13px]` → 应使用 `.btFootnote`（13pt），语义上也更匹配"次要说明"用途
- **修复方向**：将 `.font(.btCaption)` 改为 `.font(.btFootnote)`
- **路由至**：swiftui-developer
- **代码提示**：`AngleHomeView.swift` L97

---

### U-05 AngleTestView 球台缺少卡片包裹容器
- **类别**：布局
- **严重程度**：P2
- **位置**：角度 > 角度测试 > 球台区域
- **现状**：`BTAngleTestTable` 直接放在 ScrollView 中，无白色卡片背景
- **预期**：设计稿 `P0-07/code.html` L125 显示球台在 `bg-surface-container-lowest rounded-xl p-4 shadow-[...]` 白色卡片内
- **修复方向**：在 `tableSection` 中用 `.padding(Spacing.md).background(.btBGSecondary).clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))` 包裹 BTAngleTestTable
- **路由至**：swiftui-developer
- **代码提示**：`AngleTestView.swift` L82-86

---

### U-06 AngleTestView 结果模式缺少球台下方说明文字
- **类别**：产品规格
- **严重程度**：P2
- **位置**：角度 > 角度测试 > 球台下方（答题后）
- **现状**：答题后只显示球台和结果卡片，无 caption 说明
- **预期**：设计稿 `P0-07/stitch_task_p0_07_angletestviewresult_02/screen.png` 在球台下方显示 "击球路径与偏角可视化" 说明行（眼睛图标 + 文字）
- **修复方向**：在 `showResult == true` 时，在 BTAngleTestTable 下方添加 `HStack { Image(systemName: "eye") Text("击球路径与偏角可视化") }` caption
- **路由至**：swiftui-developer
- **代码提示**：`AngleTestView.swift` L82-86（tableSection）

---

### U-07 AngleTestView 结果评级 badge 使用硬编码 `.white`
- **类别**：Dark Mode
- **严重程度**：P2
- **位置**：角度 > 角度测试 > 结果区域 > 评级标签
- **现状**：`Text(vm.errorRating.label).foregroundStyle(.white)` 使用硬编码 `.white`
- **预期**：SKILL.md §15 规定"无硬编码 `.white` / `.black`"。虽然白字在实心色底上两种模式均视觉正确，仍应统一为 `Color(.white)` 或抽取为语义 Token（如 `btOnAccent`）保持一致性
- **修复方向**：保持当前视觉效果即可，但建议添加 `// 白字在实心色底上：视觉正确` 注释，或抽取 `btOnSolid` Token
- **路由至**：swiftui-developer
- **代码提示**：`AngleTestView.swift` L143

---

### U-08 AngleTestView 进度条 cornerRadius 硬编码
- **类别**：Design Token
- **严重程度**：P2
- **位置**：角度 > 角度测试 > 进度条
- **现状**：`RoundedRectangle(cornerRadius: 3)` — 3 不是 BTRadius 枚举值
- **预期**：BTRadius 最小值为 xs=6，但进度条高度仅 6pt，cornerRadius 3 实现半高胶囊效果。建议改用 `Capsule()` 或 `BTRadius.full`
- **修复方向**：将 `RoundedRectangle(cornerRadius: 3)` 替换为 `Capsule()` 以保持 Token 一致性
- **路由至**：swiftui-developer
- **代码提示**：`AngleTestView.swift` L56-60

---

### U-09 ContactPointTableView 交互区角度数字字号偏小
- **类别**：Design Token
- **严重程度**：P2
- **位置**：角度 > 进球点对照表 > 交互区角度数字
- **现状**：使用 `.btStatNumber`（28pt bold rounded）+ `.fontWeight(.heavy)` 覆盖
- **预期**：设计稿 `P1-05/screen.png` 显示角度数字约 32pt。`.btStatNumber` 为 28pt，设计更接近 `btLargeTitle`（34pt）或需新建中间 Token
- **修复方向**：改用 `.btLargeTitle`（34pt）并移除 `.fontWeight(.heavy)` 覆盖，或在设计系统中补充 32pt Token
- **路由至**：swiftui-developer
- **代码提示**：`ContactPointTableView.swift` L55-56

---

### U-10 ContactPointTableView 球面图缺少圆形灰色背景容器
- **类别**：视觉打磨
- **严重程度**：P2
- **位置**：角度 > 进球点对照表 > 交互区球面图
- **现状**：Canvas 绘制裸圆形轮廓在透明背景上
- **预期**：设计稿 `P1-05/code.html` L121 显示球面图在 `w-[160px] h-[160px] bg-[#E8E8ED] rounded-full` 灰色圆形容器内，有 `shadow-inner` 效果
- **修复方向**：在 `ballDiagram` 外层添加圆形灰色背景容器 `Circle().fill(.btBGTertiary).frame(width: 160, height: 160).overlay { ballDiagram(...) }`
- **路由至**：swiftui-developer
- **代码提示**：`ContactPointTableView.swift` L51, L182-224

---

### U-11 ContactPointTableView 原理区段标题与设计不符
- **类别**：产品规格
- **严重程度**：P2
- **位置**：角度 > 进球点对照表 > 原理区段
- **现状**：标题为 "原理"（纯文字），无图标
- **预期**：设计稿 `P1-05/code.html` L152-153 显示 info 填充图标 + "原理说明"
- **修复方向**：标题改为 `HStack { Image(systemName: "info.circle.fill").foregroundStyle(.btPrimary)  Text("原理说明") }`
- **路由至**：swiftui-developer
- **代码提示**：`ContactPointTableView.swift` L96-97

---

### U-12 ContactPointTableView 原理提示文字缺少左边框装饰
- **类别**：视觉打磨
- **严重程度**：P2
- **位置**：角度 > 进球点对照表 > 原理区段 > 提示段落
- **现状**："切入角越大..." 为普通 Text
- **预期**：设计稿 `P1-05/code.html` L161 显示 `border-l-4 border-tertiary` 左侧 4pt 色条 + 浅背景
- **修复方向**：将提示文字包裹在带左侧边框的容器中：`.overlay(alignment: .leading) { Rectangle().fill(.btAccent).frame(width: 4) }` + `.padding(.leading, Spacing.md)` + 浅色背景
- **路由至**：swiftui-developer
- **代码提示**：`ContactPointTableView.swift` L102-103

---

### U-13 AngleHistoryView 角度区间标签使用非标准 opacity
- **类别**：Design Token
- **严重程度**：P2
- **位置**：角度 > 测试历史 > 角度区间分析 > 区间标签文字
- **现状**：`.foregroundStyle(.btText.opacity(0.8))` — 0.8 不是设计系统定义的文字层级
- **预期**：设计系统定义 3 层文字色：btText(100%)、btTextSecondary(60%)、btTextTertiary(30%)，无 80% 级别
- **修复方向**：改用 `.foregroundStyle(.btText)` 或 `.foregroundStyle(.btTextSecondary)`，与设计系统保持一致
- **路由至**：swiftui-developer
- **代码提示**：`AngleHistoryView.swift` L178

---

### U-14 AngleHistoryView premiumGate 使用硬编码 `true`
- **类别**：产品规格
- **严重程度**：P2
- **位置**：角度 > 测试历史 > View modifier
- **现状**：`.premiumGate(isPremium: true)` 硬编码为 `true`，永远不会触发付费墙
- **预期**：若历史页对所有用户开放，应移除 `.premiumGate` 调用避免混淆；若应限制付费用户，应注入 `subscriptionManager.isPremium`
- **修复方向**：确认产品规格后：若免费可用则移除 modifier；若需付费则添加 `@EnvironmentObject private var subscriptionManager` 并使用 `subscriptionManager.isPremium`
- **路由至**：swiftui-developer
- **代码提示**：`AngleHistoryView.swift` L29

---

### U-15 BTAngleTestTable 球体高光使用硬编码 `.white`
- **类别**：Dark Mode
- **严重程度**：P2
- **位置**：角度 > 角度测试 > BTAngleTestTable > 球体渲染
- **现状**：`drawBall` 中使用 `.white.opacity(0.3)` 绘制球体高光反射点
- **预期**：SKILL.md §15 规定"无硬编码 `.white`"。此处为物理光照模拟，白色高光在深浅模式下均视觉正确
- **修复方向**：可保持现状（物理光照例外），建议在代码中注释说明原因，或使用 `Color(.white).opacity(0.3)` 保持显式意图
- **路由至**：swiftui-developer
- **代码提示**：`BTAngleTestTable.swift` L118

---

### U-16 AngleTestView "下一题" 按钮布局与设计不符
- **类别**：产品规格
- **严重程度**：P2
- **位置**：角度 > 角度测试 > 结果页 > 底部操作按钮
- **现状**：按钮在 ScrollView 内 VStack 中内联渲染，宽度跟随内容
- **预期**：设计稿 `P0-07/stitch_task_p0_07_angletestviewresult_02/code.html` L189-194 显示 "下一题 →" 为固定底部全宽按钮，带毛玻璃背景 `bg-surface-container-low/80 backdrop-blur-md`
- **修复方向**：将"下一题/查看总结"按钮移出 ScrollView，固定在底部安全区域上方，使用 `.safeAreaInset(edge: .bottom)` 或 ZStack overlay
- **路由至**：swiftui-developer
- **代码提示**：`AngleTestView.swift` L195-201

---

### 审查总结
- 截图/源码数量：5 个文件 + 5 组设计稿
- 发现问题：16 项（P0: 0 / P1: 1 / P2: 15）
- 总体评价：角度训练模块整体 Token 使用规范，Dark Mode 基础适配到位，Canvas 球台渲染符合规范。主要差距集中在**设计稿还原度**（卡片圆角、图标容器形状、缺少时间筛选器）和**少量 Token 硬编码**（progress bar cornerRadius、badge `.white`、opacity 0.8）。
- 建议下一步：
  1. **优先修复 U-01（P1）**：添加时间周期选择器（周/月/全部），需 ViewModel 配合
  2. 批量修复 U-02/U-03/U-04（AngleHomeView 卡片圆角+图标形状+字号）
  3. 修复 U-05/U-06/U-16（AngleTestView 球台卡片包裹+说明文字+底部按钮布局）
  4. 修复 U-09/U-10/U-11/U-12（ContactPointTableView 视觉细节）
  5. 确认 U-14 产品规格后清理 premiumGate
