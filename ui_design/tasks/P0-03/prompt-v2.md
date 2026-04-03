# Stitch Prompt — P0-03 v2（增量修正）

> 任务 ID: P0-03 | 版本: v2 | 日期: 2026-04-03
> 在 Stitch **同一会话**中发送以下修正指令，无需重写完整 prompt

---

## Stitch 修正指令（在同一对话中发送）

Please make the following 3 changes to the current design:

**1. Remove the motivational card**
Delete the green "保持手感" card at the bottom of the drill list. It should not exist — the drill list should end after the last drill card ("自由击球"). Do not add any extra cards, tips, or motivational content below the drill list.

**2. Move progress dots inline with set count**
Currently the progress dots (●●●○○) are on a separate line below "5 组". Move them to the **same line** as the set count text, placed directly to the right of "5 组" with 8px gap. Also reduce the dot size from 7px to 6px. Like this layout:

```
五分点直球                    36/90
5 组 ●●●○○                     ⚙
```

The dots should be vertically centered with the "5 组" text on the same line. Apply this change to all 4 drill cards.

**3. Reduce timer font size**
Change the timer "00:12:34" from 36px to 28px. Keep it bold monospace and brand green `#1A6B3C`.

No other changes needed — the rest of the layout is correct.

---

## Stitch 导出处理

1. Stitch 生成后将导出文件夹保存到 `tasks/P0-03/` 目录下（命名类似 `stitch_task_p0_03_02/`）
2. 完成后说 **"审核 P0-03"** 触发审核智能体
