# Stitch 增量修正 — A-03 v2

> 任务 ID: A-03 | 版本: v2（增量修正）| 日期: 2026-04-03
> 基于 review-v1 中的问题项，在同一 Stitch 会话中发送以下修正指令

---

## Stitch 修正指令（在同一会话中发送）

Please fix the BTLevelBadge section:

1. **All 5 badges must fit in a single horizontal row** — they currently wrap with "L4 专业" dropping to a second line. Reduce the horizontal padding of each badge from `px-3` to `px-2`, or make the badges slightly smaller so all 5 fit in one row within the 393pt screen width. The row should not wrap.

2. **Improve L3 color distinction** — make the L3 熟练 badge slightly more obviously orange compared to L2 进阶 (amber). Use a more saturated orange background tint and keep the text `#E67C00`.

Everything else looks great — keep all other sections unchanged.
