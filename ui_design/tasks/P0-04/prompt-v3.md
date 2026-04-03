# Stitch Prompt — P0-04 v3（增量修正）

> 任务 ID: P0-04 | 版本: v3 | 日期: 2026-04-03
> 在 Stitch 同一会话中发送以下修正指令

---

## Stitch 修正指令（在同一对话中粘贴以下内容）

Two small fixes needed:

### 1. Add a 5th row (Set 4) to the set input grid

The grid currently has 4 rows (warmup, Set 1, Set 2, Set 3). Add a **Set 4 row** at the bottom, right after Set 3. It should be identical in style to the Set 3 row (not started):

- Column 1: **"4"** in gray text (same opacity as Set 3)
- Column 2: empty input box with gray border, showing "0"
- Column 3: empty input box with gray border, showing "0"
- Column 4: hollow circle outline (unchecked, same as Set 3)
- Column 5: ⋯ overflow icon

### 2. Remove "DONE" from the header

In the top header, Row 2 right side currently shows "DONE" in green text. Remove it entirely. Row 2 should only have:
- Left: "基础直球训练" (with the progress info "8/15 组 2/4 项目" below it)
- Right: nothing (or just the progress stats if they were on the right before)

That's it — everything else looks great.

---

## Stitch 导出处理

1. Stitch 生成后将导出文件夹保存到 `tasks/P0-04/stitch_task_p0_04_03/`
2. 完成后说 **"审核 P0-04"** 触发审核智能体
