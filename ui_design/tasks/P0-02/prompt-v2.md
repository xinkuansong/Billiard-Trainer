# Stitch Prompt — P0-02 v2（增量修正指令）

> 任务 ID: P0-02 | 版本: v2 | 日期: 2026-04-03
> 基于 review-v1.md 审核意见，在 Stitch 同一会话中发送以下修正消息

---

## Stitch 修正消息（在同一会话中发送）

Please make the following 3 corrections to the Training Home (Empty State) screen:

**1. (CRITICAL) Page title color — change from green to black:**
- Change the "训练" title from green `#005129` to pure black `#000000`.
- This must match the iOS native large title style — black text on the `#F2F2F7` background, like Apple's Health or Settings app.
- Keep the same font size (34pt Bold) and left-aligned position.

**2. (CRITICAL) Navigation icon buttons — change from green to black:**
- Change both right-side icon buttons (group + more_horiz) from green `#005129` to pure black `#000000`.
- Keep them on transparent background with no circle backgrounds — just simple black icons.

**3. (MEDIUM) Empty state icon size — reduce from 80px to 48px:**
- Change the fitness_center icon from `font-size: 80px` to `font-size: 48px`.
- Keep the same 30% opacity brand green color (`rgba(26,107,60,0.3)`).
- The icon should feel subtle and supporting, not dominant.

Keep everything else unchanged — the empty state text, buttons, centering, tab bar, and overall layout are all good.

---

## 使用方式

1. 在 Stitch 的 **同一对话** 中，粘贴上面的修正消息
2. Stitch 会生成新版本（保留好的部分，只修改上述 3 项）
3. 将新的导出文件夹保存到 `tasks/P0-02/stitch_task_p0_02_02/`（或 Stitch 自动命名）
4. 完成后说 **"审核 P0-02"** 触发第二轮审核
