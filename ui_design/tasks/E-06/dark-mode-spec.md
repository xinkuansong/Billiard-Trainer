# 球迹 (QiuJi) Dark Mode 完整设计规范

**生成日期**: 2026-04-05
**来源**: `dark-mode-rules.md` + E-01 参考帧 + E-02~E-04 标注文档 + E-05 终审补充

---

## 一、Dark Mode Token 完整表

### 1.1 基础 Token

| Token | Light Mode | Dark Mode | 用途 |
|-------|-----------|-----------|------|
| btBG | `#F2F2F7` | `#000000` | 页面主背景（OLED 纯黑） |
| btBGSecondary | `#FFFFFF` | `#1C1C1E` | 卡片/列表/分组背景 |
| btBGTertiary | `#E5E5EA` | `#2C2C2E` | 次要区块（搜索框、输入框底色）|
| btBGQuaternary | `#D1D1D6` | `#3A3A3C` | 分隔/更深层级 |
| btText | `#000000` | `#FFFFFF` | 主文字 |
| btTextSecondary | `rgba(60,60,67,0.6)` | `rgba(235,235,240,0.6)` | 辅助文字 |
| btTextTertiary | `rgba(60,60,67,0.3)` | `rgba(235,235,240,0.3)` | 弱文字/占位符 |
| btSeparator | `rgba(60,60,67,0.18)` | `#38383A` | 分隔线 |

### 1.2 品牌色 Token

| Token | Light Mode | Dark Mode | 说明 |
|-------|-----------|-----------|------|
| btPrimary | `#1A6B3C` | `#25A25A` | 品牌绿（Dark 提亮保持 WCAG AA ≥4.5:1）|
| btAccent | `#D4941A` | `#F0AD30` | Pro 金色（Dark 提亮）|
| btDestructive | `#C62828` | `#EF5350` | 危险色（Dark 提亮）|
| btSuccess | `#4CAF50` | `#4CAF50` | 正面反馈/成功/上升趋势 |

### 1.3 组件级 Token

| Token | Light Mode | Dark Mode | 用途 |
|-------|-----------|-----------|------|
| btTableFace | `#1B6B3A` | `#144D2A` | 球台台面 |
| btTableRail | `#7B3F00` | `#5C2E00` | 球台库边 |

---

## 二、全局映射规则

### 2.1 页面背景

- 所有页面背景 → `#000000`（OLED 纯黑）
- iOS 状态栏 → 白色文字（light content style）

### 2.2 卡片容器

- 卡片背景 → `#1C1C1E`
- **移除所有阴影**，靠 `#000000` vs `#1C1C1E` 色差分层
- 需额外区分时：`#38383A` 1px 细边框

### 2.3 Tab 栏与导航栏

- Tab 栏背景：iOS 原生深色模糊（近似 `#1C1C1E` 半透明）
- 导航栏背景：与页面背景融合（`#000000`）
- 未激活 Tab 图标：`rgba(235,235,240,0.6)`
- 激活 Tab 图标+文字：`#25A25A`
- 大标题文字：`#FFFFFF`

### 2.4 筛选 Chip

- 选中态：`#F2F2F7` 填充 + `#000000` 文字（反转）
- 未选态：`#2C2C2E` 填充 + `rgba(235,235,240,0.6)` 文字 + `#3A3A3C` 描边

---

## 三、组件级特殊处理

### 3.1 BTLevelBadge Dark

| 等级 | 底色 | 文字色 |
|------|------|--------|
| L0 入门 | `rgba(37,162,90,0.15)` | `#25A25A` |
| L1 初级 | `rgba(0,122,255,0.15)` | `#0A84FF` |
| L2 中级 | `rgba(240,173,48,0.15)` | `#F0AD30` |
| L3 高级 | `rgba(255,159,10,0.15)` | `#FF9F0A` |

### 3.2 PRO 标签胶囊 Dark

- 浅金底 `rgba(240,173,48,0.15)` + 金色文字 `#F0AD30`

### 3.3 锁图标容器 Dark

- 深琥珀圆底 `rgba(240,173,48,0.20)` + `#F0AD30` 锁图标
- Light 的 `#FFDDAF` 浅琥珀在深色页面过亮，需降至 20% 透明度

### 3.4 金色 CTA Dark

- 金色填充 `#F0AD30` + 白字（从 Light `#D4941A` 提亮）
- 金色描边 `#F0AD30` 边框

### 3.5 BTBilliardTable Dark

- 台面 `#144D2A`（比 Light 更深），库边 `#5C2E00`
- 球体颜色不变：母球 `#F5F5F5`，目标球 `#F5A623`
- 球台作为独立视觉元素，不跟随页面背景反转
- 击球线、路径线颜色不变

### 3.6 BTDrillCard 缩略图 Dark

- 深色卡片 `#1C1C1E` 上照片缩略图边缘可能融合
- 添加 0.5pt `#38383A` 描边（或 `.overlay` 遮罩）

### 3.7 功能入口图标容器 Dark

- Light：浅绿圆底 `rgba(26,107,60,0.12)`
- Dark：深绿圆底 `rgba(37,162,90,0.15)`（12% → 15%，使用 Dark 绿值）

### 3.8 搜索栏 Dark

- 背景 `#2C2C2E`
- 搜索图标/占位符 `rgba(235,235,240,0.3)`

### 3.9 Pro 全遮罩毛玻璃 Dark

- Light：白色渐变 + 高斯模糊
- Dark：**黑色渐变** `rgba(0,0,0,0)` → `rgba(0,0,0,0.95)` + 高斯模糊
- 模糊半径可能需比 Light 略小（深色下模糊容易过度发灰）
- 底层应隐约可见轮廓，不能完全变黑

---

## 四、页面级特殊处理清单

### 4.1 训练流程（E-01 Stitch 参考帧覆盖）

| 页面 | 特殊处理 |
|------|---------|
| P0-01 TrainingHomeView | Chip 反转、PRO 徽章 Dark Token |
| P0-03 ActiveTraining 总览 | 毛玻璃顶栏 Dark 变体、计时器 `#25A25A` |
| P0-04 ActiveTraining 记录 | 球台 Dark Token、网格/热身标记 |
| P0-06a TrainingSummary | 统计卡片、成功率色阶 |
| P2-01 PlanListView | PRO 标签、Level 徽章、chevron |

### 4.2 动作库 + 角度 + 收藏（E-02 标注覆盖）

| 页面 | 特殊处理 |
|------|---------|
| P1-01 DrillListView | Chip 反转、缩略图描边、多色 LevelBadge、搜索栏 |
| P1-03 DrillDetailView | 导航栏融合、球台 Dark Token、底部双按钮层级 |
| P1-05 AngleHome + ContactPoint | 图标容器透明度 12%→15%、对照表绿色高亮 |
| P0-07 AngleTestView | 球台 Canvas 独立、输入框焦点、进度条、反馈色 WCAG |
| P2-07 FavoriteDrillsView | 与 DrillList 卡片统一、空状态 |

### 4.3 历史 + 统计（E-03 标注覆盖）

| 页面 | 特殊处理 |
|------|---------|
| P1-07 HistoryCalendarView | 日历四态、训练日绿点、彩色圆点保持原色 |
| P1-09 StatisticsView | 时间范围胶囊、柱状图双色、绿线、环比三色 |
| P1-10 StatisticsView Pro 锁 | 毛玻璃黑色渐变、琥珀锁容器 20%、金色 CTA |

### 4.4 个人中心 + 登录（E-04 标注覆盖）

| 页面 | 特殊处理 |
|------|---------|
| P2-03 ProfileView 已登录 | 多色菜单图标 systemColor Dark、退出登录 #EF5350 |
| P2-03 ProfileView 访客 | Pro 推广卡边界（可加 1pt #38383A 描边） |
| P2-05 LoginView Sheet | 容器 #1C1C1E、Apple 按钮反转白底、微信保持 #07C160、手机号描边适配 |
| P2-05 PhoneLoginView | 输入框 #2C2C2E + 焦点绿框、验证码药丸可用/冷却/禁用三态 |

---

## 五、排除 Dark Mode 的页面

| 页面 | 理由 |
|------|------|
| P2-04 OnboardingView | 品牌首屏保持浅色品牌识别 |
| P2-06 SubscriptionView | 自身已是深色设计（#111111 背景）|
| P0-06b TrainingShareView | 分享卡自身已是深色主题 |

---

## 六、开发实施总 Checklist

### 全局

- [ ] SwiftUI `Color` Asset Catalog 配置 Light/Dark 双值
- [ ] `btPrimary` Light `#1A6B3C` / Dark `#25A25A`
- [ ] `btAccent` Light `#D4941A` / Dark `#F0AD30`
- [ ] `btDestructive` Light `#C62828` / Dark `#EF5350`
- [ ] 全部卡片阴影在 Dark Mode 下移除
- [ ] 状态栏使用 `.preferredStatusBarStyle = .lightContent`

### E-02 覆盖页面

- [ ] DrillListView: 筛选 Chip 反转，与 TrainingHomeView 一致
- [ ] DrillListView: BTDrillCard 缩略图 0.5pt 描边
- [ ] DrillListView: 搜索栏 #2C2C2E + 占位符 30%
- [ ] DrillDetailView: Hero 球台 Dark Token
- [ ] DrillDetailView: 底部双按钮层级
- [ ] AngleHomeView: 图标容器透明度 12% → 15%
- [ ] ContactPointTableView: 绿色高亮 #25A25A
- [ ] AngleTestView: 进度条/反馈色 WCAG AA
- [ ] AngleTestView: 球台 Canvas 独立
- [ ] FavoriteDrillsView: 与 DrillListView 卡片统一
- [ ] FavoriteDrillsView: 空状态图标/文字层级

### E-03 覆盖页面

- [ ] HistoryCalendarView: 日历四态颜色
- [ ] HistoryCalendarView: 训练日绿点 #25A25A
- [ ] StatisticsView: 时间范围胶囊 #2C2C2E + 绿边框
- [ ] StatisticsView: 柱状图双色饱和度
- [ ] StatisticsView: 左侧绿线 #25A25A
- [ ] StatisticsView: 环比三色 WCAG AA
- [ ] StatisticsView Pro 锁: 毛玻璃黑色渐变调试
- [ ] StatisticsView Pro 锁: 琥珀锁容器 20%
- [ ] StatisticsView Pro 锁: 金色 CTA #F0AD30

### E-04 覆盖页面

- [ ] ProfileView: 多色菜单图标 systemColor Dark
- [ ] ProfileView: 退出登录 #EF5350
- [ ] ProfileView: 头像边缘处理
- [ ] ProfileView 访客: Pro 推广卡边界
- [ ] LoginView Sheet: 容器 #1C1C1E + 拖拽条 #3A3A3C
- [ ] LoginView Sheet: Apple 按钮白底黑字（HIG Dark）
- [ ] LoginView Sheet: 微信按钮 #07C160 不变
- [ ] LoginView Sheet: 手机号按钮描边适配
- [ ] PhoneLoginView: 输入框 + 焦点绿框
- [ ] PhoneLoginView: 验证码/登录按钮三态

---

## 七、Dark Mode 参考文件索引

| 文件 | 路径 | 说明 |
|------|------|------|
| Token 规则 | `.cursor/skills/stitch-prompt-gen/rules/dark-mode-rules.md` | DM-001~DM-009 |
| E-01 参考帧 | `tasks/E-01/stitch_task_e_01*/screen.png` (5 帧) | Stitch 生成 Dark Mode 视觉样本 |
| E-02 标注 | `tasks/E-02/dark-mode-annotations.md` | 动作库+角度+收藏 |
| E-03 标注 | `tasks/E-03/dark-mode-annotations.md` | 历史+统计 |
| E-04 标注 | `tasks/E-04/dark-mode-annotations.md` | 个人中心+登录 |
| E-05 终审 | `tasks/E-05/global-final-review.md` | Token 交叉验证 + 品牌审核 |
