# E-01 APPROVED — Dark Mode 训练流程（含训练计划）

**审核通过日期**: 2026-04-05
**迭代轮次**: 帧1/帧2/帧5a = v1 通过 | 帧3/帧4 = v2 通过

---

## 最终交付物

| 帧 | 页面 | 版本 | 截图路径 | 评分 |
|----|------|------|---------|------|
| 帧1 | TrainingHomeView Dark | v1 | `stitch_task_e_01/screen.png` | ⭐⭐⭐⭐ |
| 帧2 | ActiveTrainingView 总览 Dark | v1 | `stitch_task_e_01_frame2/screen.png` | ⭐⭐⭐⭐½ |
| 帧3 | ActiveTrainingView 单项记录 Dark | **v2** | `stitch_task_e_01_frame3_02/screen.png` | ⭐⭐⭐⭐ |
| 帧4 | TrainingSummaryView Dark | **v2** | `stitch_task_e_01_frame4_02/screen.png` | ⭐⭐⭐⭐½ |
| 帧5a | PlanListView Dark | v1 | `stitch_task_e1_frame5/screen.png` | ⭐⭐⭐½ |

## 开发标注——已知偏差

1. **帧1 筛选 Chip 选中态**: Stitch 渲染为白色描边深色填充，开发以 `#F2F2F7` 填充 + 黑色文字为准
2. **帧3 球台区琥珀边框**: Stitch 创意装饰，开发时以 P0-04 为准（无边框）
3. **帧4 训练明细「详情」标签**: Stitch 添加，开发跟随 Light Mode
4. **帧5a 底部 Tab 栏**: PlanListView 为 push 子页面，开发时不显示 Tab
5. **帧5a PRO/Level 徽章合并**: 开发时以 Light Mode 为准，分别显示
6. **帧5a 缺少 chevron**: 开发时补充右侧 chevron 指示器

## 未覆盖

- **帧5b PlanDetailView Dark**: 未生成，后续补充或合并到 E-05 终审

## 关键决策

详见 `decision-log.md`，核心经验：
- Dark Mode 复杂布局页需 v2 修正指令模式（同一 Stitch 会话追加 + 重新附加 Light Mode 截图）
- Stitch 对「pixel-identical」指令的理解需通过**逐区域具体描述**来强制
