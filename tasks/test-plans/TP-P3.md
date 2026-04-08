# 人工测试计划 — Phase 3 Drill Library（动作库）

> **使用方式**：在模拟器或真机上逐条执行，通过则勾选 `[x]`，失败则记录问题描述。
> **时机**：P3 功能已通过 AI QA 验收，此为补充的人工视觉/交互验证。
> **更新记录**：2026-04-06 V2 — 反映 DR-011 DrillLibrary 全面改造：左侧分类侧边栏 + 2 列网格 BTDrillGridCard；DrillDetailView 新增备注卡、训练维度、查看精讲、真人示范区

---

## 前置条件

- [ ] Debug 构建成功（Scheme: QiuJi, Destination: iPhone 17 Pro Simulator）
- [ ] 全新安装（删除已有 App 后重新安装）
- [ ] 无登录状态（匿名用户）

---

## 一、视觉与 UI

| # | 页面 | 检查项 | 通过 |
|---|------|--------|------|
| V-01 | DrillListView | 球种筛选 Chip 行（全部/中式台球/9球）Capsule 样式，选中态反色 | [ ] |
| V-02 | DrillListView | 左侧分类侧边栏（72pt 固定宽度，垂直 ScrollView，「全部」+ 8 大分类文字按钮，选中态左侧绿色竖条 + btPrimary 文字） | [ ] |
| V-03 | DrillListView | 搜索框（自定义 TextField + magnifyingglass 图标 + xmark 清除按钮），输入时键盘弹出不遮挡 | [ ] |
| V-04 | DrillListView | 加载中状态显示 BTDrillListSkeleton 2 列网格骨架屏 | [ ] |
| V-05 | DrillListView | 右侧 LazyVGrid 2 列网格 + pinned section headers（分类名称 btTitle2 字体） | [ ] |
| V-06 | DrillListView | BTDrillGridCard 卡片：BTMiniTable 缩略图 + BTLevelBadge + PRO/收藏叠加层 + 底部渐变 | [ ] |
| V-07 | DrillDetailView | 顶部 BTBilliardTable Canvas 展示球台动画 + 左下角重放按钮 | [ ] |
| V-08 | DrillDetailView | 灰色操作图标行（要点/历史/图表）水平排列，btBGTertiary 圆底 | [ ] |
| V-09 | DrillDetailView | 标签行：球种胶囊 + 分类胶囊 + BTLevelBadge | [ ] |
| V-10 | DrillDetailView | 备注卡片（square.and.pencil 图标 +「点击此处输入备注」占位文字） | [ ] |
| V-11 | DrillDetailView | 训练要点（coachingPoints）编号列表，绿色数字圆圈 +「查看精讲」primary 按钮 | [ ] |
| V-12 | DrillDetailView | 达标标准高亮卡片（target 图标 + 标准 + 默认组数×球数） | [ ] |
| V-13 | DrillDetailView | 训练维度卡片（5 条进度条：准度/力量控制/走位判断/杆法技巧/心理素质 + 百分比 + 主要训练说明） | [ ] |
| V-14 | DrillDetailView | 真人示范区（6 个视频占位方块 + play.circle.fill 图标 +「即将上线」文字） | [ ] |
| V-15 | DrillDetailView | 固定底栏：免费 Drill 显示 darkPill「关闭」+ primary「加入训练」 | [ ] |
| V-16 | DrillDetailView | 固定底栏：付费 Drill 显示金色 Capsule「解锁 Pro」（crown.fill 图标） | [ ] |
| V-17 | DrillDetailView | 导航栏心形收藏按钮（空心/实心 + 颜色切换：btAccent / btTextSecondary） | [ ] |
| V-18 | BTPremiumLock | 付费 Drill 渐进遮罩（显示 1 条 coachingPoint 后模糊）| [ ] |
| V-19 | BTEmptyState | 搜索无结果时空状态（magnifyingglass 图标 +「没有找到相关动作」+「浏览全部动作」按钮） | [ ] |
| V-20 | BTEmptyState | 分类无数据时空状态（tray 图标 +「该分类暂无训练项目」） | [ ] |
| V-21 | FavoriteDrillsView | 已收藏 Drill 列表布局与动作库一致 | [ ] |

---

## 二、Dark Mode

> 设置 → 显示与亮度 → 切换至深色模式后逐页检查。

| # | 页面 | 检查项 | 通过 |
|---|------|--------|------|
| D-01 | DrillListView | 球种 Chip 选中态反色（Light #1C1C1E → Dark #F2F2F7），未选中 btBGSecondary + btSeparator 描边 | [ ] |
| D-02 | DrillListView | 左侧分类侧边栏 btBGSecondary 背景 Dark 下可见，选中项绿色竖条清晰 | [ ] |
| D-03 | DrillListView | BTDrillGridCard 卡片文字可读，缩略图渲染正常 | [ ] |
| D-04 | DrillListView | 骨架屏（BTDrillListSkeleton）Dark 适配 | [ ] |
| D-05 | DrillDetailView | Canvas 球台使用深绿色变体（btTableFelt #144D2A）| [ ] |
| D-06 | DrillDetailView | 灰色操作图标 Dark 下 btBGTertiary 圆底可见 | [ ] |
| D-07 | DrillDetailView | 球路径动画线条在深色背景下仍清晰 | [ ] |
| D-08 | DrillDetailView | 底栏毛玻璃效果 Dark 下正常 | [ ] |
| D-09 | BTPremiumLock | 遮罩在 Dark Mode 下不与背景融合 | [ ] |
| D-10 | BTEmptyState | 空状态文字与图标在 Dark Mode 下可读 | [ ] |

---

## 三、动画与过渡

| # | 场景 | 检查项 | 通过 |
|---|------|--------|------|
| A-01 | BTBilliardTable Canvas | 进入详情页时动画自动播放，无卡顿 | [ ] |
| A-02 | BTBilliardTable Canvas | 目标球路径先播放，母球路径后播放，时序正确 | [ ] |
| A-03 | BTBilliardTable Canvas | 重放按钮点击后动画完整重播 | [ ] |
| A-04 | BTBilliardTable Canvas | 曲线路径（贝塞尔）渲染圆滑，非折线 | [ ] |
| A-05 | 页面导航 | 列表 → 详情页过渡动画流畅 | [ ] |
| A-06 | 收藏按钮 | 点击时有即时视觉反馈（空心 ↔ 实心 + 颜色切换） | [ ] |

---

## 四、用户流程

### 流程 1：浏览 Drill 分类列表

**步骤**：
1. 启动 App → 点击底部「动作库」Tab
2. 确认球种 Chip 行（全部/中式台球/9球）+ 左侧分类侧边栏（「全部」+ 8 大分类）
3. 在右侧 2 列网格中向下滚动，确认 8 大分类（基本功、准度、杆法、母球分离、走位、力量控制、特殊球、综合）均有内容
4. 点击任意分类下的一个 BTDrillGridCard

**预期结果**：进入 DrillDetailView 详情页

- [ ] 球种 Chip 行与左侧分类侧边栏均可见
- [ ] 8 大分类均有 Drill 条目（右侧网格 + pinned section header 仅分类名 btTitle2，无图标、无数量徽章）
- [ ] 点击卡片后正确进入详情页

### 流程 2：搜索 Drill

**步骤**：
1. 在动作库页面顶部搜索框输入「直线」
2. 观察列表实时过滤
3. 清空搜索框
4. 输入一个不存在的关键词（如「zzzzz」）

**预期结果**：
- 输入「直线」后只显示包含「直线」的 Drill
- 输入不存在的关键词后显示 BTEmptyState 空状态

- [ ] 搜索过滤正确生效
- [ ] 空状态视图正常展示（magnifyingglass 图标 + 换关键词提示）
- [ ] 清空搜索后列表恢复完整

### 流程 3：球种 + 侧边栏筛选

**步骤**：
1. 点击球种 Chip「中式台球」
2. 观察列表只显示中式台球相关 Drill
3. 在左侧侧边栏点击「杆法」
4. 观察列表只显示中式台球 + 杆法的 Drill
5. 点击球种「全部」+ 侧边栏「全部」恢复

**预期结果**：列表根据球种 + 侧边栏分类实时切换

- [ ] 球种筛选切换后列表立即更新
- [ ] 侧边栏分类切换后列表立即更新
- [ ] 双重筛选叠加生效
- [ ] 球种「全部」+ 侧边栏「全部」恢复完整列表

### 流程 4：收藏 Drill 并查看收藏夹

**步骤**：
1. 动作库 Tab → 点击任意免费 Drill 进入详情
2. 点击导航栏心形收藏按钮（空心 → 实心，颜色变为 btAccent 金色）
3. 返回列表
4. 切换到「我的」Tab → 点击「我的收藏」
5. 确认刚收藏的 Drill 出现在列表中
6. 点击进入该 Drill 详情 → 取消收藏（实心 → 空心）
7. 返回收藏夹列表

**预期结果**：收藏/取消收藏实时生效

- [ ] 收藏后心形变为实心 + btAccent 色
- [ ] 收藏夹中出现该 Drill
- [ ] 取消收藏后从收藏夹消失

### 流程 5：付费 Drill 锁定体验

**步骤**：
1. 在动作库列表中找到一个 L2+ 付费 Drill
2. 点击进入详情页
3. 确认 coachingPoints 区域被渐进遮罩覆盖（可见 1 条后模糊）
4. 确认底栏显示金色 Capsule「解锁 Pro」按钮
5. 点击「解锁 Pro」

**预期结果**：遮罩阻止查看完整内容，底栏金色按钮触发订阅页

- [ ] 付费 Drill coachingPoints 渐进遮罩可见
- [ ] 底栏显示金色「解锁 Pro」而非「关闭」+「加入训练」
- [ ] 点击后弹出 SubscriptionView Sheet
- [ ] 免费 Drill 无遮罩，底栏显示 darkPill + primary 双按钮

---

## 五、交互响应

| # | 场景 | 检查项 | 通过 |
|---|------|--------|------|
| I-01 | BTDrillGridCard 点击 | 整个卡片可点击，响应无延迟 | [ ] |
| I-02 | 收藏按钮 | 导航栏心形点击区域 >= 44pt | [ ] |
| I-03 | 搜索框键盘 | 键盘弹出后列表上移，输入区不被遮挡 | [ ] |
| I-04 | 列表滚动 | 快速滑动时无卡顿，pinned section headers 吸顶 | [ ] |
| I-05 | 返回导航 | 详情页左滑手势返回 + 导航栏返回按钮均正常 | [ ] |
| I-06 | 重放按钮 | Canvas 动画播放中点击重放，动画正确重置并重播 | [ ] |
| I-07 | Chip + 侧边栏筛选 | 球种 Chip 切换 + 侧边栏分类切换有选中态绿色竖条 | [ ] |
| I-08 | 侧边栏选中态 | 左侧绿色竖条 + btPrimary 文字 + btBG 背景 | [ ] |

---

## 六、边界场景

| # | 场景 | 检查项 | 通过 |
|---|------|--------|------|
| E-01 | 首次启动（无数据） | 动作库列表正常加载 72 条 Drill（Bundle fallback） | [ ] |
| E-02 | 飞行模式 | 开启飞行模式后动作库仍可浏览全部 Drill | [ ] |
| E-03 | 飞行模式 | 收藏功能在离线状态下正常工作 | [ ] |
| E-04 | 收藏持久化 | 收藏 Drill → 强制退出 App → 重新打开 → 收藏夹中仍存在 | [ ] |
| E-05 | 空收藏夹 | 无收藏时收藏夹页面显示 BTEmptyState | [ ] |

---

## 七、设备矩阵

> 在不同屏幕尺寸上各走一遍流程 1 + 流程 4。

| # | 设备 | 核心流程通过 | 布局正常 | 备注 |
|---|------|------------|---------|------|
| DM-01 | iPhone SE 3rd（4.7"） | [ ] | [ ] | 特别注意 Canvas 球台在小屏上的可视性；侧边栏 72pt 在小屏上占比注意 |
| DM-02 | iPhone 17 Pro（6.3"） | [ ] | [ ] | |
| DM-03 | iPhone 17 Pro Max（6.9"） | [ ] | [ ] | |

---

## 八、可访问性

| # | 检查项 | 通过 |
|---|--------|------|
| AC-01 | Dynamic Type 最大字号下 DrillListView 侧边栏 + 网格布局不溢出 | [ ] |
| AC-02 | Dynamic Type 最大字号下 DrillDetailView 教学要点文字不截断 | [ ] |
| AC-03 | VoiceOver 可朗读 BTDrillGridCard 的名称和等级 | [ ] |

---

## 九、性能

| # | 指标 | 阈值 | 通过 |
|---|------|------|------|
| PF-01 | 动作库列表（72 条）滚动 FPS | >= 55 FPS | [ ] |
| PF-02 | 进入 Drill 详情页时间 | < 0.5 秒 | [ ] |
| PF-03 | Canvas 动画播放时 CPU 占用 | < 30% | [ ] |
| PF-04 | 正常浏览内存峰值 | < 80 MB | [ ] |

---

## 测试结果

| 项目 | 内容 |
|------|------|
| 测试人 | |
| 日期 | YYYY-MM-DD |
| 设备 | [型号 + iOS 版本] |
| 构建版本 | [Build number] |
| 总体结论 | 通过 / 有问题（详见下方） |

### 发现的问题

| # | 严重程度 | 页面/流程 | 描述 | 关联检查项 |
|---|---------|----------|------|-----------|
| | | | | |
