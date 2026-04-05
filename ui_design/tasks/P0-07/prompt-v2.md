# Stitch Prompt — P0-07 v2（增量修正）

> 任务 ID: P0-07 | 版本: v2 | 日期: 2026-04-04
> 基于 review-v1.md 的审核意见，在 Stitch 同一会话中发送以下修正指令

---

## 帧 1 修正（在帧 1 的 Stitch 对话中发送）

The billiard table orientation is wrong — it's currently portrait (1:2 aspect ratio, taller than wide). Real billiard tables viewed from above are **landscape** (wider than tall).

Please fix:

1. **Change the table aspect ratio to 2:1 (landscape)** — the table should be approximately 337pt wide × 170pt tall, matching a real overhead billiard table view. The width fills the card, the height is about half the width.
2. Keep everything else the same: green felt `#1B6B3A`, brown cushion `#7B3F00`, 6 black pockets, orange target ball at upper-right area, white cue ball at lower-left area, red arrow pointing to target pocket.
3. The ball positions should maintain a diagonal layout on the now-landscape table: cue ball at roughly (30%, 70%) and target ball at roughly (55%, 30%).
4. The input area below the table stays unchanged.

---

## 帧 2 修正（在帧 2 的 Stitch 对话中发送）

Two fixes needed:

1. **Change the progress text from English to Chinese**: Replace "Question 8/20" with **"第 8 题"** (left-aligned) and "40% Complete" with **"共 20 题"** (right-aligned). This must match Frame 1's Chinese text style exactly.

2. **Unify the cushion/rail color**: The table rail border should use `#7B3F00` (wood brown) to match the design spec. Currently it appears to use a different brown shade.
