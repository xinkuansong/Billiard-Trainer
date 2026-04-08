## UI 截图审查报告 — SubscriptionView + FavoriteDrillsView（截图对照）
日期：2026-04-06

审查对象：订阅付费墙 + 收藏动作列表
截图来源：P2-06-01, P2-07-01, P2-07-02（3 张实机截图）
设计参考：P2-06 SubscriptionView, P2-07 FavoriteDrillsView, ref-screenshots/09-premium-paywall

---

### 📱 P2-06-01 — 订阅付费墙（Loading 状态）

---

### S-01 加载中状态缺少骨架屏 / 占位卡片，用户无法预览定价
- **类别**：产品规格 / 布局
- **严重程度**：P1（功能缺陷）
- **位置**：我的 > 订阅 > 定价卡片区域
- **截图现状**：产品未加载完成时，特性列表下方出现大片空白区，仅在中间显示一个小尺寸 `ProgressView` 旋转指示器；底部订阅按钮同样替换为 `ProgressView`，用户无法了解有哪些方案和价格。
- **设计预期**：设计稿（`P2-06/stitch_task_p2_06_02/screen.png`）直接展示 3 列定价卡片（月订阅 ¥18 / 年订阅 ¥88 / 终身买断 ¥198）和完整 CTA 按钮文案 "立即订阅 — 年订阅 ¥88"。虽然设计稿无 loading 态规格，但当前实现的空白 + 小 spinner 体验较差。
- **修复方向**：为 loading 态添加 3 列骨架卡片占位（shimmer 或 redacted modifier），按钮区域可显示 "加载中…" 文案替代纯 spinner。若 StoreKit 加载失败应显示重试提示而非持续 spinner。
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/Profile/Views/SubscriptionView.swift` `pricingGrid` — 当 `subscriptionManager.products.isEmpty && subscriptionManager.isLoading` 时的占位 UI；`subscribeButton` 的 loading 分支。

---

### S-02 Hero 图标使用 SF Symbol "target"，与设计稿风格不一致
- **类别**：视觉打磨
- **严重程度**：P2（视觉瑕疵）
- **位置**：我的 > 订阅 > Hero 区域图标
- **截图现状**：Hero 区使用 `Image(systemName: "target")` 显示同心圆靶心图标，绿色填充。
- **设计预期**：设计稿 HTML 使用 `sports_score`（棋盘旗帜风格 Material Symbol），渲染为绿色棋盘旗帜，更贴合"解锁成就"语境。参考竞品训记的 paywall（`ref-screenshots/09-premium-paywall/03-paywall.png`）使用自定义品牌图标。
- **修复方向**：考虑替换为更具辨识度的图标，如 `trophy.fill`、`flag.checkered` 或自定义 Pro 品牌图标（如设计稿中的棋盘旗帜风格）。这是风格偏好，非阻塞。
- **路由至**：swiftui-developer
- **代码提示**：`SubscriptionView.swift` 第 89 行 `Image(systemName: "target")`

---

### S-03 特性列表标题字号与设计稿存在差异（13pt vs 设计 13pt 一致但视觉偏小）
- **类别**：Design Token
- **严重程度**：P2（视觉瑕疵）
- **位置**：我的 > 订阅 > 特性列表
- **截图现状**：特性标题使用 `.btFootnote`（13pt, regular）+ `.fontWeight(.medium)`，副标题使用 `.btCaption2`（11pt）。在深色背景上 13pt medium 的视觉存在感偏弱。
- **设计预期**：设计稿 HTML 中特性标题为 `text-[13pt] font-medium`，副标题为 `text-[11pt]`。数值一致但设计稿 HTML 使用 Manrope 字族（字形更宽）在视觉上比 SF Pro 13pt 更显眼。考虑到深色背景的阅读性，可酌情提升至 `btSubheadline`（15pt）。
- **修复方向**：建议特性标题提升至 `.btSubheadline`（15pt, medium），副标题提升至 `.btFootnote`（13pt），以增强深色背景上的可读性。对比设计稿视觉效果做最终决定。
- **路由至**：swiftui-developer
- **代码提示**：`SubscriptionView.swift` 第 131–136 行 `featureRow` 函数内的字体定义。

---

### 📱 P2-07-01 — 收藏列表（空状态）

---

### S-04 返回按钮显示为白色圆形，缺少"我的"文字标签
- **类别**：HIG / 产品规格
- **严重程度**：P1（功能缺陷）
- **位置**：我的 > 我的收藏 > 导航栏返回按钮
- **截图现状**：返回按钮表现为白色圆形背景内的 "<" 箭头，没有显示上一页标题 "我的"。圆形背景样式不是 iOS 标准导航栏返回按钮。
- **设计预期**：设计稿（`P2-07/stitch_task_p2_07_favoritedrillsviewempty/screen.png`）显示标准 iOS 导航栏返回按钮："< 我的" 文字链接（btPrimary 绿色），无圆形背景。符合 HIG 标准 NavigationStack 行为。
- **修复方向**：确认 `FavoriteDrillsView` 上一级（ProfileView）是否正确设置了 `.navigationTitle("我的")`，确保未自定义返回按钮样式（如添加圆形背景）。移除任何自定义返回按钮覆盖，使用系统默认样式。
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Features/Profile/Views/FavoriteDrillsView.swift` 使用系统 `.navigationTitle("我的收藏")`，返回按钮由 NavigationStack 自动生成；检查 `ProfileView.swift` 是否正确设置 `.navigationTitle("我的")`，以及是否存在 `.toolbar` 自定义返回按钮。

---

### S-05 空状态图标使用 heart.slash 带灰色圆形背景，与设计稿 star 图标风格不同
- **类别**：产品规格 / 视觉打磨
- **严重程度**：P2（视觉瑕疵）
- **位置**：我的 > 我的收藏 > 空状态图标
- **截图现状**：空状态图标为 `heart.slash` SF Symbol，被包裹在一个较大的浅灰色圆形背景内（约 80pt 直径）。整体风格偏"重"。
- **设计预期**：设计稿使用 `star_half` 图标（星星风格），以 30% 不透明度的 btPrimary 颜色直接渲染（`text-[#1A6B3C]/30`），尺寸 48pt，**无圆形背景**。视觉更轻盈、更克制，符合训记风格"界面退为工具"的理念。
- **修复方向**：（1）移除 BTEmptyState 中图标的灰色圆形背景，直接以 btPrimary 30% 不透明度渲染图标；（2）图标选择可保留 `heart.slash`（语义更贴合"收藏"功能），或按设计稿改为 `star.slash`。两者功能等价，优先保持一致性。
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Core/Components/BTEmptyState.swift` 图标渲染部分（可能存在圆形背景 wrapper）；`FavoriteDrillsView.swift` 第 19 行 `icon: "heart.slash"`。

---

### S-06 空状态 CTA 按钮宽度过宽，设计稿为固定 200pt
- **类别**：布局
- **严重程度**：P2（视觉瑕疵）
- **位置**：我的 > 我的收藏 > 空状态 "浏览动作库" 按钮
- **截图现状**：按钮宽度接近全屏（左右仅留约 32pt 边距），在空旷的页面中视觉权重偏大。
- **设计预期**：设计稿 HTML 指定按钮为固定宽度 `w-[200pt]`、高度 `h-[44pt]`、圆角 `rounded-[12pt]`。较窄的按钮在大面积空白中更显精致。
- **修复方向**：在 BTEmptyState 中将 CTA 按钮宽度限制为 `frame(width: 200)` 或 `frame(maxWidth: 240)`，而非跟随父容器撑满。
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Core/Components/BTEmptyState.swift` 按钮布局部分。

---

### 📱 P2-07-02 — 收藏列表（有内容）

---

### S-07 Drill 卡片标签未使用独立 pill 样式，与设计稿布局差异明显
- **类别**：产品规格 / Design Token
- **严重程度**：P1（功能缺陷）
- **位置**：我的 > 我的收藏 > Drill 卡片标签区
- **截图现状**：卡片标签区显示为 "中式 · 推荐 3 组" 纯文本（灰色，无背景），加上一个独立的 "L1 初级" 等级徽章（绿底白字）。文字与徽章混排，无统一的 pill 容器。
- **设计预期**：设计稿（`P2-07/stitch_task_p2_07_favoritedrillsview/code.html`）中每个标签均为独立 pill 元素 — "中式台球" pill（浅灰底 + 灰色文字）、"L1 初学" pill（绿底 + 白字）、"推荐 3 组" pill（浅灰底 + 灰色文字），使用 `px-2 py-0.5 rounded-full` 容器，间距 `gap-1.5`。
- **修复方向**：更新 `BTDrillCard` 标签区，将 tableType、推荐组数也包裹在 pill 样式容器中（背景 `btBG`，文字 `btTextSecondary`，圆角 `BTRadius.full`），与等级徽章平行排列。
- **路由至**：swiftui-developer
- **代码提示**：`QiuJi/Core/Components/BTDrillCard.swift` 标签渲染区域。

---

### S-08 收藏卡片显示金色填充心形图标，设计稿中收藏列表无心形图标
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：我的 > 我的收藏 > Drill 卡片右侧
- **截图现状**：卡片右上角显示一个金色填充的心形图标（btAccent 色），点击可取消收藏。心形图标与右侧 ">" 箭头叠放，视觉元素较多。
- **设计预期**：设计稿中收藏列表的卡片右侧仅有 ">" 导航箭头（`chevron_right`，30% 不透明度），无心形图标。在收藏列表语境下，所有卡片已是"已收藏"状态，心形图标的信息冗余。
- **修复方向**：（1）方案 A：移除收藏列表中卡片的心形图标，仅保留 chevron，改为左滑删除手势取消收藏；（2）方案 B：保留心形但将其与 chevron 合并为右侧单一操作区，降低视觉复杂度。建议与产品确认交互方式。
- **路由至**：swiftui-developer
- **代码提示**：`FavoriteDrillsView.swift` 第 33–37 行 `BTDrillCard` 传入 `isFavorited: true` 和 `onFavoriteTap` 回调。

---

### S-09 Drill 卡片缩略图使用 Canvas 台面渲染，设计稿使用照片
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：我的 > 我的收藏 > Drill 卡片左侧缩略图
- **截图现状**：缩略图为 64×64pt 圆角矩形，内容为 Canvas 绘制的迷你台球桌（绿色台面 + 白色球），是应用内 BTBilliardTable 的缩略版。
- **设计预期**：设计稿使用真实台球场景照片作为缩略图（如台球桌特写、球杆细节等氛围照）。这是 AI 生成的设计参考图，实际应用使用 Canvas 渲染更贴合产品语境和真实数据。
- **修复方向**：**无需修改**。Canvas 缩略图展示了 Drill 的实际球台布局（球位、路径），信息密度远高于装饰性照片，符合"数据即主角"设计哲学。此差异为设计稿占位图与实现的合理偏差。
- **路由至**：无（标记为接受）

---

### S-10 等级标签 "L1 初级" 文案与设计系统 displayName 不一致
- **类别**：产品规格
- **严重程度**：P2（视觉瑕疵）
- **位置**：我的 > 我的收藏 > Drill 卡片等级标签
- **截图现状**：等级标签显示为 "L1 初级"。
- **设计预期**：设计稿 HTML 中 L1 标签文案为 "L1 初学"；设计系统 SKILL.md §九 定义 L1 displayName 为「初级」（注：SKILL.md 原文 L1「初级」，而设计稿 HTML 用了"初学"）。需统一确认标准文案。
- **修复方向**：确认 L1 的 displayName 标准：若以 SKILL.md 为准则"L1 初级"正确，若以设计稿为准则应改为"L1 初学"。建议在 SKILL.md 和实现中统一。
- **路由至**：content-engineer
- **代码提示**：`QiuJi/Core/Components/BTLevelBadge.swift` 或 Drill 数据模型中的等级 displayName 定义。

---

### 审查总结

- **截图数量**：3 张（P2-06-01, P2-07-01, P2-07-02）
- **发现问题**：10 项（P0: 0 / P1: 3 / P2: 7）
- **总体评价**：订阅付费墙的视觉风格（深色背景、特性列表、定价卡片结构）与设计稿高度一致，主要问题集中在 loading 态的 UX 空白。收藏列表的功能逻辑完整，空状态和有内容态均可正常工作，但导航栏返回按钮样式和卡片标签布局与设计稿存在可见差异。Canvas 缩略图为实际数据渲染，优于设计稿的占位照片。
- **建议下一步**：
  1. **优先修复 P1**：S-01（付费墙 loading 骨架屏）、S-04（返回按钮样式）、S-07（标签 pill 样式）
  2. **批量打磨 P2**：S-05 + S-06（BTEmptyState 图标 + 按钮宽度可一并调整）
  3. **产品确认**：S-08（收藏列表是否保留心形图标）、S-10（L1 标准文案）
