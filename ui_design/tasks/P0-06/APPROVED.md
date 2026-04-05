# ✅ 任务通过 — P0-06

**任务**: TrainingSummaryView + TrainingShareView（训练数据总结页 + 训练分享卡定制页）
**通过日期**: 2026-04-04
**最终版本**: v2
**迭代轮次**: 2

## 最终截图

- 帧 1: `stitch_task_p0_06_trainingsummaryview_02/screen.png`
- 帧 2: `stitch_task_p0_06_trainingshareview_02/screen.png`

## 关键设计决策摘要

- **统计卡片布局**：采用 2×2 + 1 全宽网格，自适应高度（非正方形），标签 13pt Regular iOS Gray
- **Drill 明细展开**：全部组数详情行默认展开，各组一行（组号 + 进球数 + 绿色勾选），不折叠
- **底部三级按钮层级**：保存训练（品牌绿填充）→ 生成分享图（品牌绿描边）→ 查看历史记录（灰色文字）
- **分享卡深色主题**：`#1C1C1E` 背景 + 白色/绿色文字，成功率按数值着色（≥70% 绿色 / <70% 低透明度白色）
- **分享卡定制面板**：字体 BTTogglePillGroup + 颜色圆圈含文字标签 + 选项胶囊组，固定底部 Sheet 样式
- **Tab 栏统一**：帧 1 保持 训练/动作库/角度/记录/我的 五 Tab，与 P0-01~P0-05 一致
- **帧 2 无 Tab 栏**：TrainingShareView 是从 TrainingSummaryView 导航进入的子页面，不显示底部 Tab

## 残留项（供开发参考）

1. 帧 1 统计卡片单位文字（「分钟」等）颜色 `#64748B` → 开发时建议用 `Color(.secondaryLabel)`
2. 帧 2 选项胶囊行在极端宽度下可能截断 → 开发时建议用 `ScrollView(.horizontal)` 包裹

## 沉淀的规则

- 无新增规则（本任务的修正均为已有规则的执行）
