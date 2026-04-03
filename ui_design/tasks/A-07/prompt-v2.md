# Stitch Prompt — A-07 v2（增量修正）

> 任务 ID: A-07 | 版本: v2 | 日期: 2026-04-03
> 在 Stitch **同一会话**中发送以下修正指令

---

## Stitch 修正指令（在同一对话中粘贴）

Please make the following corrections to the component sheet:

### Fix 1: BTExerciseRow layout — move pot count to the right side

Each BTExerciseRow card should have a **three-column layout**:
- **Left**: 56pt thumbnail (keep as-is)
- **Center** (vertical stack): Drill name on line 1 + "X 组" on line 2 — do NOT put the pot count here
- **Right** (vertically centered, right-aligned): cumulative pot count "45/180" in **15pt** on top + gear icon below it

Currently the pot count "45/180" sits on the same line as "5 组" in the center area. Move it to the right side as a separate column.

### Fix 2: BTExerciseRow font sizes — increase all text sizes

- Drill name: change from 15pt to **17pt Semibold** (e.g. `text-[17px] font-semibold`)
- Set count "X 组": change from 12pt to **13pt** (e.g. `text-[13px]`)
- Pot count "45/180" (now on the right side): change from 12pt to **15pt** (e.g. `text-[15px]`)

### Fix 3: Warmup row — move "热" badge to the set number column

In the BTSetInputGrid warmup row (currently Row 5):
- **Remove** the number "5" from the # column
- **Move** the orange "热" badge INTO the # column (where the number was), replacing it entirely
- Change the badge style from solid orange background with white text to: **light orange background `rgba(245,166,35,0.15)`** with **orange text `#F5A623`**
- The badge should be a small rounded rectangle (about 28×20pt, corner radius 4pt)
- The pots input column should now just contain a normal 44pt input square (same as Row 4), without the "热" badge next to it

### Fix 4: Completed rows — add 44pt input squares for pot/total values

In the BTSetInputGrid completed rows (Row 1 and Row 2):
- The pot count and total ball count values are currently shown as plain floating text
- Wrap each value inside a **44pt × 44pt rounded rectangle** (corner radius 8pt, white background `#FFFFFF`) — same as the input squares in Row 3 and Row 4
- Keep the bold green text color `#1A6B3C` for the pot count value inside the square
- This ensures all 5 rows have a consistent grid of 44pt squares

### Fix 5: Completed rows — set number color

In the completed rows (Row 1 and Row 2):
- Change the set number color from gray to **`#1A6B3C`** (brand green) to indicate completed status
- This matches the green checkmark and green-tinted background of completed rows

---

All other elements (progress dots, empty state, add button, section titles, page background) are correct — do not change them.
