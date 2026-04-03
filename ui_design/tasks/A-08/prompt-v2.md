# Stitch Prompt — A-08 v2 (增量修正)

> 任务 ID: A-08 | 版本: v2 | 日期: 2026-04-03
> 在 Stitch 同一会话中发送以下修正指令

---

## Stitch 追加消息（粘贴到同一对话中）

Please make these 3 fixes to the current design:

**Fix 1 — Share card corner radius:**
Change the two dark share cards (both the green "#1C1C1E" card and the blue "#0D1B2A" card) from 12pt corner radius to **16pt corner radius**. They should match the outer white section card's radius.

**Fix 2 — Billiard table ball positions:**
In the full-size BTBilliardTable (Section 2), move the balls OFF the vertical center line to create a more realistic angled shot:
- **Cue ball**: position at approximately **70% from top, 38% from left** (lower-left area of the table)
- **Target ball**: position at approximately **32% from top, 58% from left** (upper-right area)
- Update the **white dashed path line** to connect from the new cue ball position to the new target ball position (a diagonal line)
- Update the **orange dashed path line** from the target ball toward the **top-right corner pocket**
- Move the **contact point ring** to the new target ball position

This creates a diagonal shot scenario that better demonstrates path animation capabilities.

**Fix 3 — Add component specs text:**
Add a compact specs list (13pt, gray `rgba(60,60,67,0.6)` text) below the content in each section, BEFORE the italic usage annotation line:

For Section 1 (BTShareCard), add:
- 卡片: 圆角 16pt, 深色主题容器
- 配色主题: 基础绿 / 暗夜蓝 / 黑白 / 更多
- 品牌区: App Logo + 二维码占位
- 渲染为图片用于社交分享

For Section 2 (BTBilliardTable full size), add:
- 全尺寸: ~350 × 190pt (DrillDetailView Hero 区)
- 台面: btTableFelt #1B6B3A
- 库边: btTableCushion #7B3F00 (8pt)
- 袋口: btTablePocket #000000 (16pt ⌀)
- 母球: btBallCue #F5F5F5 (14pt ⌀)
- 目标球: btBallTarget #F5A623 (14pt ⌀)
- Canvas 绘制, 路径为动画示意

For Section 3 (thumbnails), add:
- 缩略图: 56 × 56pt, 圆角 8pt
- 简化球台: 省略袋口细节, 保留台面色 + 库边色 + 球位
- 使用场景: BTExerciseRow 左侧, BTDrillCard 缩略图

Keep everything else exactly the same. Do not change any colors or other layout elements.

---

## 使用说明

1. 在 Stitch 的 **A-08 同一会话** 中粘贴上方修正指令
2. 导出保存到 `tasks/A-08/stitch_task_08_02/`
3. 说「审核 A-08」触发审核
