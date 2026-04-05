# Stitch 修正指令 — P1-08 v2

> 在 Stitch 的同一会话中发送以下修正消息（分帧发送）。

---

## 帧 1 修正（HistoryCalendarView 空状态）

Please make these 2 corrections to the calendar empty state screen:

1. **Remove the settings gear icon** in the top-right corner of the navigation bar. The "记录" large title should stand alone with NO icon buttons on the right side. The settings functionality is already covered by the "日历设置" pill button below the month navigation.

2. **Change the "记录" large title color to pure black #000000.** Currently it appears to be a dark green (emerald-900). The large title text must be pure black #000000 on the #F2F2F7 background, consistent with other tab root pages in this app.

Everything else on this screen looks great — keep the calendar grid, empty state component, tab bar, and all other elements exactly as they are.

---

## 帧 2 修正（TrainingDetailView Sheet）

Please make these 4 corrections to the training detail sheet:

1. **Move overflow menu icons to the LEFT side of each menu item.** Currently the layout is "text (left) + colored circle icon (right)". Change it to "colored circle icon (LEFT) + text label (RIGHT)" for each menu item. The "删除" danger item should also follow this pattern: red circle icon on the left + "删除" red text on the right. Keep the full-width divider above "删除".

2. **Add per-set detail rows to Drill Card 2 "中袋定位练习".** Currently it only shows the cumulative footer. Add 3 set rows matching the same format as Drill Card 1:
   - 第1组  8/10  ✓  休息 60s
   - 第2组  9/10  ✓  休息 60s
   - 第3组  7/10  ✓

3. **Add a third Drill Card "走位控制练习"** below the second card, with:
   - Ball table thumbnail (same 40pt style as the other cards)
   - Name: "走位控制练习", cumulative: 45/60
   - 4 set rows: 第1组 12/15 ✓ 休息 90s, 第2组 11/15 ✓ 休息 90s, 第3组 10/15 ✓ 休息 60s, 第4组 12/15 ✓
   - Footer: 累计进球 45

4. **Add an orange dot to each ball table thumbnail** representing the object ball. Each 40pt thumbnail should show TWO dots: a white dot (#F5F5F5) for the cue ball positioned at roughly 38%,70% AND an orange dot (#F5A623) for the object ball at roughly 58%,32% — creating a diagonal layout.

Keep everything else exactly as is — the sheet structure, navigation, stats row, notes section, bottom action bar, and overflow menu styling are all correct.
