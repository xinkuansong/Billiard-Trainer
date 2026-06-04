# T-P9-D-REVIEW — P9 设计一致性审查

- **角色**：QA Reviewer
- **日期**：2026-06-02
- **输入**：P9-01~07 设计帧（6/7 APPROVED）+ 已实现页面 + 近期 UI 审查（UR-20260529 / UR-20260601）
- **结论**：✅ 通过（无 P1 偏差；P2 改进项转 backlog）

---

## 一、审查矩阵（字体 / 间距 / 颜色 / 图标 / Dark Mode）

| 设计任务 | 对应实现 | APPROVED | 一致性 | 备注 |
|----------|----------|:--------:|:------:|------|
| P9-01 AngleHomeView 重设计 | `AngleHomeView` | ✅ | ✅ | 分组卡片（学习/训练/工具）+ 历史入口；FeatureCard 范式与既有页一致 |
| P9-02 AimingPrincipleView | `AimingPrincipleView` | ✅ | ✅ | 工具子页面样式（返回箭头+中文标题、隐藏 tabBar）；公式 monospace + btPrimary |
| P9-03 AngleDynamicView | `AngleDynamicView` | ✅ | ✅ | 交互台面 + 第一人称重叠 + 数值面板；黑底为场景叠加层惯例 |
| P9-04 GeometricAngleQuizView | `GeometricAngleQuizView` | ✅ | ✅ | 拟真台面夹角 + 量角弧 + 统计面板；**新增 Freemium 限额卡沿用 btAccent/皇冠范式**（与 Scene 页一致） |
| P9-05 ContactPointTableView 增强 | `ContactPointTableView` | ✅ | ✅ | **遵循 APPROVED：移除球种切换、固定中八**；19×5°+48.6° 表 + 正弦曲线；标记点 `.red`→`.btAccent`（token 合规） |
| P9-05 SceneAnglePredictionView（帧 1-6） | `SceneAnglePredictionView` | ✅ | ✅ | BTSegmentedTab 2D/3D + 毛玻璃 HUD + 结果面板；评级 chip 复用既有样式 |
| P9-07 BallFeelView | `BallFeelView` | ⚠️ 无正式 APPROVED（6/7） | ✅ | 教学长页面，与 AimingPrincipleView 同风格；视觉已随 2026-06-01 拟真化统一 |

> 编号说明：phase 卡的 T-P9-D-05 在 `ui_design/tasks/P9-05/APPROVED.md` 中合并承载了对照表与 SceneKit 预测两套帧。

---

## 二、跨页视觉连续性

- **与既有 AngleTestView / ContactPointTableView 无断裂**：子页面统一「返回箭头 + 居中中文标题 + 隐藏 tabBar」；学习页统一卡片间距 `Spacing.xl`、圆角 `BTRadius.lg`。
- **台面/球渲染统一**（2026-06-01 拟真化收敛）：学习页与几何页统一走 `BTAimTableView(.feltOnly)` + `BTRealisticBall`，去掉早期"廉价球桌"装饰，让角度/线/假想球为主角。
- **图标语言统一**（2026-06-01 图标系统收敛，FL-015）：入口/列表图标走品牌绿为主、金为唯一强调。
- **台呢色**（FL-011 已修）：2D/动态/3D 三页台呢统一为自然深绿，无荧光绿。

---

## 三、Dark Mode

- 文档/列表/表格页使用 BT* 语义 Token，Light/Dark 双值通过（21 Token 双值此前已在 P8-11 验证）。
- Scene 全屏页 + 几何/原理画布叠加层使用 `.white`/`.black.opacity` —— 属 SceneKit/Canvas HUD 叠加惯例，已被设计 APPROVED 认可，**非偏差**。

---

## 四、偏差登记

| 级别 | 偏差 | 处置 |
|------|------|------|
| P1 | 无 | — |
| P2 | P9-07 BallFeelView 缺正式 APPROVED 签收（实现已存在且风格一致） | 补签收或在 T-P9-00 文档中追认（非阻塞） |
| P2 | Scene/Canvas HUD 的 `.white/.black` 叠加未 Token 化 | 设计认可的叠加层惯例，保留；后续若做 Token 化统一再处理 |

**审查结论：通过，无 P1。**
