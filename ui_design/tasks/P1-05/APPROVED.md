# ✅ 任务通过 — P1-05

**任务**: AngleHomeView + ContactPointTableView（角度训练入口页 + 进球点对照表）
**通过日期**: 2026-04-04
**最终版本**: 帧 1 v2 + 帧 2 v2
**迭代轮次**: 2（每帧各 2 轮）

## 最终截图

- 帧 1 (AngleHomeView): `stitch_task_p1_05_02/screen.png`
- 帧 2 (ContactPointTableView): `stitch_task_p1_05_contactpointtableview_02/screen.png`

## 关键设计决策摘要

- **AngleHomeView 为简洁导航枢纽**：拒绝 Stitch 添加的 Hero 横幅、头像/齿轮图标、统计卡片，保持设计文档定义的 3 入口结构（角度测试/对照表/历史）
- **角度训练 Tab 无顶部图标按钮**：与 P0-01（训练 Tab 有朋友+溢出菜单）不同，角度训练页无辅助功能需求，大标题独立展示
- **ContactPointTableView 为纯工具页**：拒绝 Stitch 的底部推广卡片，教育/工具类子页面保持功能纯粹
- **功能入口卡片图标**：浅绿底圆形 rgba(26,107,60,0.12) + 品牌绿 #1A6B3C 图标，与 iOS Settings 风格一致
- **对照表通称高亮**：绿色文字 #1A6B3C 区分有通称的行（全球/二分之一球/四分之三点/极薄球）
- **DESIGN.md 偏离处理**：延续 A-01 模式，以 screen.png 和 code.html 为准

## 确立的页面级设计模式（角度训练模块通用）

- Tab 根页面（AngleHomeView）：简洁导航枢纽，大标题 + 功能入口卡片 + 辅助入口行
- 工具子页面（ContactPointTableView）：返回箭头 + 中文标题，滚动内容，无底部 Tab 栏
- 功能入口卡片：白色 16pt 圆角 + 浅绿底圆形图标 + 标题/副标题 + chevron

## 沉淀的规则

- 无新增规则文件（决策已记录在 decision-log.md）
