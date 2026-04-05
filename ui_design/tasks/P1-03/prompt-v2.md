# Stitch v2 修正指令 — P1-03 DrillDetailView

Please make the following corrections to the current design. Do NOT regenerate from scratch — just apply these specific changes:

## Fix 1: Bottom "加入训练" button — remove gradient, use solid color

Change the "加入训练" button from gradient fill to a **solid flat fill of #1A6B3C** (not #005129). Remove any gradient. The button should be: solid #1A6B3C background + white text + pill shape. No gradient is allowed anywhere in this design.

## Fix 2: Bottom "关闭" button — change to darkPill style

Change the "关闭" button from light gray background to a **dark pill style**: background color **#1C1C1E** (near-black) + **white text** + white ✕ icon on the left. It should look like a dark capsule button, not a light gray one.

## Fix 3: Navigation bar center title — remove English, use black Chinese

Remove the English text "Drill Detail" from the center of the navigation bar. Either leave it empty (standard iOS push behavior) or replace with the Chinese drill name "直线球定点练习" in **#000000 black** color (not green).

## Fix 4: Fix brand green color globally — #1A6B3C not #005129

All green elements currently using #005129 must be changed to **#1A6B3C**. This affects:
- The 5 numbered circles (1-5) in the training tips section
- The "查看精讲" button fill color
- The 5 horizontal bar chart fills in the technical dimensions section
- Any other element currently using #005129 as the primary green

## Fix 5: BTLevelBadge "L1 初学" — use light background style

The "L1 初学" badge currently has a solid green fill with white text (that's the L0 style). Change it to **L1 style**: light green background **rgba(26,107,60,0.12)** + green text **#1A6B3C**. Only L0 badges use solid green fill.

## Fix 6: Split action icons and tags into two separate rows

Currently the 3 circle icon buttons and the tag pills (中式台球, 准度训练, L1 初学) are on the same horizontal row. Split them into **two separate rows**:

- **Row 1 (Action icons)**: Keep the 3 circular icon buttons, but add a small text label below each one: "要点" under the first, "历史" under the second, "图表" under the third. Labels should be 11pt, color rgba(60,60,67,0.6). Also change the icon color from green to **rgba(60,60,67,0.6)** (gray).
- **Row 2 (Tags)**: Below the icon row, show the tag pills in a horizontal row: "中式台球" pill + "准度训练" pill + "L1 初学" BTLevelBadge (with the light green style from Fix 5).

These two rows should be left-aligned below the drill title, with 8pt gap between rows.
