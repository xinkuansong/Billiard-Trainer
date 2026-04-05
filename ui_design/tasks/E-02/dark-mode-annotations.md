# E-02 Dark Mode 开发标注 — 动作库 + 角度 + 收藏

> 策略变更：不再通过 Stitch 生成 Dark Mode 截图，改为基于已验证的 Token 表直接标注开发。
> 通用 Token 映射参见 `dark-mode-rules.md` DM-001，此文档仅列出**超出标准映射的特殊处理**。

---

## 通用规则（所有页面适用）

| 元素 | Light → Dark |
|------|-------------|
| 页面背景 | `#F2F2F7` → `#000000` |
| 卡片/列表行 | `#FFFFFF` → `#1C1C1E` |
| 输入框/搜索栏 | `#E5E5EA` → `#2C2C2E` |
| 主文字 | `#000000` → `#FFFFFF` |
| 辅助文字 | `rgba(60,60,67,0.6)` → `rgba(235,235,240,0.6)` |
| 占位符 | `rgba(60,60,67,0.3)` → `rgba(235,235,240,0.3)` |
| 分隔线 | `rgba(60,60,67,0.18)` → `#38383A` |
| 品牌绿 | `#1A6B3C` → `#25A25A` |
| Tab 栏背景 | 系统浅色模糊 → 系统深色模糊（近 `#1C1C1E` 半透明）|
| Tab 激活态 | `#1A6B3C` → `#25A25A` |
| Tab 非激活 | `rgba(60,60,67,0.6)` → `rgba(235,235,240,0.6)` |
| 卡片阴影 | 移除，靠 `#000000` vs `#1C1C1E` 色差分层 |
| 状态栏 | 黑色文字 → 白色文字（light content） |

---

## 页面 1: DrillListView — 对应 P1-01

**Light Mode 参考**: `tasks/P1-01/stitch_task_p1_01_02/screen.png`

### 特殊处理

**1. 筛选 Chip 选中/未选态**
- Light 选中态：`#1C1C1E` 填充 + 白字
- Dark 选中态：`#F2F2F7` 填充 + `#000000` 文字（反转）
- Dark 未选态：`#2C2C2E` 填充 + `rgba(235,235,240,0.6)` 文字 + `#3A3A3C` 描边
- 与 E-01 帧1 TrainingHomeView 筛选 Chip 保持一致（decision-log E-01 决策 1）

**2. BTDrillCard 缩略图边缘**
- 深色卡片背景 `#1C1C1E` 上照片缩略图可能边缘融合
- 添加 0.5pt `#38383A` 描边（或使用 `.overlay` 遮罩）确保轮廓清晰

**3. BTLevelBadge 多色方案**
- L0 绿：`rgba(37,162,90,0.15)` 底 + `#25A25A` 文字
- L1 蓝：`rgba(0,122,255,0.15)` 底 + `#0A84FF` 文字
- L2 琥珀：`rgba(240,173,48,0.15)` 底 + `#F0AD30` 文字
- L3 橙：`rgba(255,159,10,0.15)` 底 + `#FF9F0A` 文字
- 所有颜色在 `#1C1C1E` 卡片上验证 WCAG AA 对比度

**4. PRO 徽章**
- 浅金底 `rgba(240,173,48,0.15)` + 金色文字 `#F0AD30`
- 与 Light Mode 结构一致，仅色值切换到 Dark Token

**5. 搜索栏**
- 背景：`#2C2C2E`
- 搜索图标：`rgba(235,235,240,0.3)`
- 占位符「搜索动作」：`rgba(235,235,240,0.3)`

---

## 页面 2: DrillDetailView — 对应 P1-03

**Light Mode 参考**: `tasks/P1-03/stitch_task_p1_03_02/screen.png`

### 特殊处理

**1. 导航栏**
- push 子页面，标准 iOS 返回箭头 + 品牌绿 `#25A25A` 返回文字
- 居中标题白色 `#FFFFFF`
- 页面背景 `#000000`，导航栏与背景融合

**2. Hero 球台区域**
- 球台颜色使用 Dark Token：台面 `#144D2A`，库边 `#5C2E00`
- 球体颜色不变：母球 `#F5F5F5`，目标球 `#F5A623`
- 球台区域为 BTBilliardTable 组件，独立于页面背景色

**3. 操作图标行**
- 图标色：`rgba(235,235,240,0.6)`（对应 Light 的 `rgba(60,60,67,0.6)`）

**4. 底部双按钮**
- darkPill（关闭）：`#2C2C2E` 填充 + 白字（Light 为 `#1C1C1E` + 白字）
- primary（加入训练）：`#25A25A` 填充 + 白字
- 两按钮在 Dark 下仍需明确的视觉层级区分

**5. 内容区卡片**
- 训练要点/历史数据等内容区使用 `#1C1C1E` 卡片背景
- section 标题白色，正文 `rgba(235,235,240,0.8)`

---

## 页面 3: AngleHomeView + ContactPointTableView — 对应 P1-05

**Light Mode 参考**: `tasks/P1-05/stitch_task_p1_05_02/screen.png` + `tasks/P1-05/stitch_task_p1_05_contactpointtableview_02/screen.png`

### 特殊处理

**1. 功能入口卡片图标容器**
- Light：浅绿圆底 `rgba(26,107,60,0.12)` + 品牌绿图标 `#1A6B3C`
- Dark：深绿圆底 `rgba(37,162,90,0.15)` + 品牌绿图标 `#25A25A`
- 12% 浅绿在深色表面上会异常亮，需调整为 15% 透明度并使用 Dark 绿值

**2. ContactPointTableView 对照表**
- 表格行交替背景：不使用，统一 `#1C1C1E`
- 绿色高亮行文字：`#25A25A`（从 `#1A6B3C` 提亮，确保 `#1C1C1E` 上可读）
- 表格分隔线：`#38383A`

**3. Tab 根页面大标题**
- 「角度」大标题 34pt Bold Rounded → `#FFFFFF`

---

## 页面 4: AngleTestView — 对应 P0-07

**Light Mode 参考**: `tasks/P0-07/stitch_task_p0_07_angletestview_02/screen.png` + `tasks/P0-07/stitch_task_p0_07_angletestviewresult_02/screen.png`

### 特殊处理

**1. 球台 Canvas**
- 球台作为独立视觉元素，不跟随页面背景反转
- 台面：`#144D2A`（Dark Token，比 Light `#1B6B3A` 更深）
- 库边：`#5C2E00`（Dark Token）
- 球体、击球线、路径线颜色不变
- 球台区域与 `#000000` 页面背景有天然对比

**2. 角度输入框**
- 输入框背景：`#2C2C2E`
- 焦点边框：`#25A25A`（品牌绿 Dark）
- 输入文字：`#FFFFFF`

**3. 进度条**
- 轨道：`#3A3A3C`
- 填充：`#25A25A`
- 文字「第 X/共 20」：`rgba(235,235,240,0.6)`

**4. 结果反馈色**
- 正确/绿色胶囊：`#4CAF50`（btSuccess Dark）+ 白字
- 错误/红色胶囊：`#EF5350`（btDestructive Dark）+ 白字
- 在 `#000000` 背景上验证对比度 ≥ 4.5:1

**5. 教育提示容器**
- 使用 `#1C1C1E` 背景卡片
- 正文 `rgba(235,235,240,0.8)`

---

## 页面 5: FavoriteDrillsView — 对应 P2-07

**Light Mode 参考**: `tasks/P2-07/stitch_task_p2_07_favoritedrillsview/screen.png` + `tasks/P2-07/stitch_task_p2_07_favoritedrillsviewempty/screen.png`

### 特殊处理

**1. push 子页面导航**
- 返回箭头 + 品牌绿 `#25A25A`「我的」+ 居中「收藏动作」`#FFFFFF`
- 无底部 Tab 栏

**2. BTDrillCard**
- 与页面 1 (DrillListView) 完全一致：`#1C1C1E` 卡片 + 缩略图描边 + 多色 Level 徽章 + PRO 标签

**3. 空状态 (BTEmptyState)**
- 图标色：`rgba(235,235,240,0.3)`
- 标题「还没有收藏」：`#FFFFFF`
- 副标题「去动作库看看吧」：`rgba(235,235,240,0.6)`
- CTA 按钮「浏览动作库」：`#25A25A` 填充 + 白字

---

## 开发 Checklist

- [ ] DrillListView: 筛选 Chip Dark 态反转，与 TrainingHomeView 一致
- [ ] DrillListView: BTDrillCard 缩略图边缘处理
- [ ] DrillListView: 搜索栏 `#2C2C2E` + 占位符 30% 透明
- [ ] DrillDetailView: Hero 球台使用 Dark Token
- [ ] DrillDetailView: 底部双按钮层级在 Dark 下清晰
- [ ] AngleHomeView: 功能入口图标容器透明度调整 12% → 15%
- [ ] ContactPointTableView: 绿色高亮文字 `#25A25A` 可读性
- [ ] AngleTestView: 进度条/反馈色 WCAG AA 验证
- [ ] AngleTestView: 球台 Canvas 独立于页面背景
- [ ] FavoriteDrillsView: 与 DrillListView 卡片样式统一
- [ ] FavoriteDrillsView: 空状态在 Dark 下的图标/文字层级
- [ ] 全部页面: 状态栏白色文字、无卡片阴影
