# Stitch 增量修正 — A-05 v2

> 任务 ID: A-05 | 版本: v2（增量修正）| 日期: 2026-04-03
> 基于 review-v1 中的问题项，在同一 Stitch 会话中发送以下修正指令

---

## Stitch 修正指令（在同一会话中发送）

Please fix the following issues:

1. **BTFloatingIndicator must be RIGHT-ALIGNED, not centered.** In Section 2, move the green floating pill to the right side of the mock screen area. It should be positioned 16pt from the right edge, sitting 8pt above the mock tab bar. Remove the center alignment. This is critical — the design spec requires it at the bottom-right corner.

2. **BTRestTimer buttons must be SIDE BY SIDE, not stacked vertically.** In Section 1, change the two buttons ("+30s" and "完成") from a vertical column layout to a horizontal row layout. Place them next to each other with 12pt gap between them. The "+30s" button should be on the left, the "完成休息" button on the right. Also change the "完成" button text to "完成休息".

3. **Add a 4th icon to the mock tab bar** in Section 2. The app has 4 main tabs (训练/动作库/历史/我的), so the mock tab bar should show 4 evenly spaced icons instead of 3.

Everything else looks great — keep the ring design, colors, section titles, page style, and Section 3 unchanged.
