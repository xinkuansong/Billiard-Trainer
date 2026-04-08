## UI 截图审查报告 — DrillDetailView（截图对照）
日期：2026-04-06

审查对象：动作详情页
截图来源：P1-03-01, P1-03-02（2 张实机截图）
设计参考：P1-03 code.html + screen.png, ref-screenshots/04-exercise-library/05-07

---

### S-01 「查看精讲」按钮样式与设计严重不符
- **类别**：Design Token / 产品规格
- **严重程度**：P1
- **位置**：动作库 > 动作详情 > 训练要点卡片 > 底部按钮
- **截图现状**：按钮为居中小型胶囊形态，绿色文字（btPrimary）搭配浅绿色背景（btPrimaryMuted），宽度仅包裹文字
- **设计预期**：`code.html` 第 209 行定义 `w-full py-3 bg-[#1A6B3C] text-white font-bold rounded-full`——全宽绿色填充按钮，白色文字，高度约 48pt，与 BTButtonStyle.primary 一致
- **修复方向**：将「查看精讲」按钮改为 `BTButtonStyle.primary`（全宽、btPrimary 填充、白色文字、圆角 BTRadius.sm），或改用 `BTButton`（style: .primary）组件
- **代码提示**：`DrillDetailView.swift` 第 199–211 行 coachingSection 中的 Button

---

### S-02 备注卡片占位符使用 btPrimary 绿色而非灰色
- **类别**：Design Token
- **严重程度**：P1
- **位置**：动作库 > 动作详情 > 备注输入区
- **截图现状**：铅笔图标和「点击此处输入备注」文字均使用 btPrimary 绿色（#1A6B3C），视觉上像可交互链接而非空占位符
- **设计预期**：`code.html` 第 180–183 行，图标使用 `text-outline`（灰色 #707A70），文字使用 `text-on-surface-variant opacity-30`（极浅灰色）；占位符应表达"空状态，可点击填写"语义
- **修复方向**：图标颜色改为 `.btTextSecondary`，占位符文字改为 `.btTextTertiary`（30% 透明度），与设计一致
- **代码提示**：`DrillDetailView.swift` 第 252–268 行 notesCard

---

### S-03 标签显示原始值 "chinese8" 而非中文名
- **类别**：产品规格
- **严重程度**：P1
- **位置**：动作库 > 动作详情 > 标签行（第一个标签）
- **截图现状**：第一个标签显示原始英文枚举值 "chinese8"
- **设计预期**：`code.html` 第 173 行显示 "中式台球"——应使用 ballType 的本地化显示名称
- **修复方向**：为 ballType 枚举添加 `nameZh` 映射（类似 `DrillCategory.nameZh`），如 `"chinese8" → "中式台球"`、`"snooker" → "斯诺克"` 等
- **代码提示**：`DrillDetailView.swift` 第 150–158 行 tagsRow 中 `ForEach(drill.ballType...)` 直接输出原始字符串

---

### S-04 导航栏缺少分享按钮
- **类别**：产品规格
- **严重程度**：P2
- **位置**：动作库 > 动作详情 > 导航栏右侧
- **截图现状**：导航栏右侧仅有收藏心形图标（btAccent 金色）
- **设计预期**：`code.html` 第 112–114 行，导航栏右侧为分享按钮（share icon）；收藏按钮位于球台 Canvas 右上角叠层（第 132–135 行 `收藏` pill overlay）
- **修复方向**：在 ToolbarItem(placement: .topBarTrailing) 增加分享按钮（或调整为 share + heart 双按钮布局）；可在 Phase 后续迭代添加
- **代码提示**：`DrillDetailView.swift` 第 71–79 行 toolbar

---

### S-05 球台 Canvas 叠层元素与设计不一致
- **类别**：产品规格
- **严重程度**：P2
- **位置**：动作库 > 动作详情 > 球台 Canvas 区域
- **截图现状**：仅有左下角重播按钮（arrow.counterclockwise，32pt 圆形，半透明黑底）
- **设计预期**：`code.html` 第 131–144 行定义 3 个叠层元素：① 右上角「♥ 收藏」胶囊（bg-black/40 + backdrop-blur）；② 右下角全屏按钮（fullscreen icon）；③ 左下角视频缩略图（10×10 圆形带播放图标）。重播按钮不在设计中
- **修复方向**：考虑将重播按钮保留（实用功能）；按设计补充全屏图标（右下角）；收藏按钮若保留在导航栏则不必重复放在球台上。此项可作为 UI 打磨迭代
- **代码提示**：`DrillDetailView.swift` 第 94–118 行 tableSection

---

### S-06 导航栏标题疑似呈现为 btPrimary 绿色
- **类别**：HIG / Design Token
- **严重程度**：P2
- **位置**：动作库 > 动作详情 > 导航栏 inline title
- **截图现状**：inline 导航标题「一库走位定点」在截图中呈现绿色色调，与下方卡片标题的 btText（黑色）有明显色差
- **设计预期**：`code.html` 第 111 行 title 使用 `text-[#000000]`（纯黑）；Apple HIG 要求 inline 导航标题使用系统 label 色
- **修复方向**：检查 NavigationStack 或全局是否设置了 `.tint(.btPrimary)` 或 `accentColor` 导致标题色被覆盖。若需保持 btPrimary 作为 tint 色（影响返回按钮），可通过 `.toolbarTitleDisplayMode(.inline)` + 自定义 `toolbar { ToolbarItem(placement: .principal) }` 确保标题使用 btText 色
- **代码提示**：`DrillDetailView.swift` 第 67 行 `.navigationTitle()`，以及应用入口的全局 tint 设置

---

### S-07 「真人示范」视频缩略图尺寸与比例偏差
- **类别**：布局 / 视觉打磨
- **严重程度**：P2
- **位置**：动作库 > 动作详情 > 真人示范区域
- **截图现状**：缩略图为矩形（约 100×72pt），仅显示 3 个；play 图标使用 `play.circle.fill` 28pt 居中
- **设计预期**：`code.html` 第 267–284 行，缩略图为 `w-14 h-14`（56×56pt 正方形），圆角 `rounded-lg`（8pt），显示 6 个占位；使用 Material Symbols `play_circle` filled 图标
- **修复方向**：将缩略图尺寸改为 56×56pt 正方形，圆角 BTRadius.sm (8pt)；增加到 5-6 个占位块以表示扩展性
- **代码提示**：`DrillDetailView.swift` 第 375–404 行 videoSection，`.frame(width: 100, height: 72)` → `.frame(width: 56, height: 56)`

---

### S-08 训练维度进度条缺少上方标签行（标签+百分比两端对齐）
- **类别**：布局
- **严重程度**：P2
- **位置**：动作库 > 动作详情 > 训练维度卡片
- **截图现状**：标签名（如"准度"）在进度条左侧同行，百分比在右侧同行，进度条在中间。整体为单行水平排列：`[标签] [===进度条===] [百分比]`
- **设计预期**：`code.html` 第 215–259 行，标签名和百分比在进度条上方一行（`flex justify-between`），进度条在下方独占一行。两行布局：`[标签 .............. 百分比]` + `[========进度条========]`
- **修复方向**：改为 VStack 布局：上行 HStack（标签名 + Spacer + 百分比），下行为进度条全宽。更贴近设计且进度条能利用更多水平空间
- **代码提示**：`DrillDetailView.swift` 第 280–304 行 dimensionsSection 中 ForEach 内部布局

---

### S-09 达标标准 section 缺少上方分隔（设计中为独立卡片）
- **类别**：布局 / 视觉打磨
- **严重程度**：P2
- **位置**：动作库 > 动作详情 > 达标标准区域
- **截图现状**：「达标标准」标题直接显示在页面上，其内容在一个带 btBGSecondary 背景的卡片中，但标题本身不在卡片内
- **设计预期**：在设计参考中没有单独的「达标标准」section——该信息似乎被整合在训练要点区域。若作为独立 section，标题应包含在卡片内部（与训练维度、真人示范卡片保持一致的卡片样式：标题 + 内容均在同一白色卡片中）
- **修复方向**：将「达标标准」标题移入卡片内部，与其他 section 卡片保持一致的视觉结构（标题在卡片内顶部）
- **代码提示**：`DrillDetailView.swift` 第 221–248 行 criteriaSection

---

### 审查总结
- 截图数量：2 张
- 发现问题：9 项（P0: 0 / P1: 3 / P2: 6）
- 总体评价：页面整体结构和信息层次与设计基本一致，卡片式布局清晰。球台 Canvas 渲染质量良好。主要差距集中在 3 个 P1 项：「查看精讲」按钮样式错误（应为全宽主按钮）、备注占位符颜色误用 btPrimary、以及 ballType 未本地化显示。P2 项多为叠层元素缺失和尺寸微调，可在后续打磨迭代中处理。
- 建议下一步：
  1. **优先修复 P1**：S-01（查看精讲按钮）、S-02（备注颜色）、S-03（ballType 本地化）
  2. **二轮打磨 P2**：S-08（维度进度条布局改为两行式）→ S-07（视频缩略图尺寸）→ S-06（导航标题色）→ 其余
  3. 修复后提供新截图进行对比验证
