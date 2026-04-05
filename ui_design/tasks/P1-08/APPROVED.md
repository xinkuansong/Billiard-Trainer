# ✅ 任务通过 — P1-08

**任务**: HistoryCalendarView（空状态）+ TrainingDetailView（两帧）
**通过日期**: 2026-04-04
**最终版本**: v2
**迭代轮次**: 2

## 最终截图

- 帧 1: `stitch_task_p1_08_historycalendarview_02/screen.png`
- 帧 2: `stitch_task_p1_08_trainingdetailview_02/screen.png`

## 关键设计决策摘要

- **空状态保留完整日历**: 6×7 网格 + 今日绿色圆标记，BTEmptyState 在日历下方居中
- **TrainingDetailView 为 Sheet 模态**: 拖拽条 + ✕ 关闭 + 居中标题 + 「存为模版」
- **统计行横向排列**: 大号数字 22pt Bold + 小号标签 12pt，可横向滚动
- **Drill 卡片逐组明细**: 每个 Drill 含球台缩略图 40pt + 逐组详情行（进球数/总球数 + ✓ + 休息时长）
- **球台缩略图双球斜线布局**: 母球白 #F5F5F5 (38%,70%) + 目标球橙 #F5A623 (58%,32%)，沿用 A-08 决策
- **BTOverflowMenu 图标左侧**: 与 A-06 一致，彩色圆形图标（左）+ 文字（右），「删除」红色 + 全宽分隔线
- **底部操作栏三级层次**: 编辑数据 (primary 填充) → 复制到今天 (secondary 描边) → 更多 (icon 方形)

## 确立的页面级设计模式（历史/记录模块通用）

- 空状态：保留页面框架（导航栏 + Tab + 日历/图表骨架），BTEmptyState 在内容区居中
- Sheet 训练详情：拖拽条 + ✕/操作 导航行 + 大号统计行 + Drill 卡片列表 + 固定底部操作栏
- Drill 明细卡片：球台缩略图 + 名称 + 累计统计 + 逐组详情行
- BTOverflowMenu：图标左 + 文字右 + 危险项全宽分隔线隔离

## 沉淀的规则

- 无新增规则文件（决策已记录在 decision-log.md）
