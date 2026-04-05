# Stitch 修正指令 — P1-09 v2（在同一会话中发送）

Please make the following corrections to the StatisticsView screen:

## Fix 1: Remove navigation bar icons
- Remove the hamburger menu (≡) icon on the left side of "记录"
- Remove the search (🔍) icon on the right side of "记录"
- The large title "记录" should stand alone with no icons — just the text, same as a standard iOS large title tab root page

## Fix 2: Change duration chart bar color to amber
- In the "训练时长" chart card, change ALL bar colors from green to amber/orange #F5A623
- Keep the trend line dark #1A1A1A (unchanged)
- This differentiates the duration chart (amber bars) from the success rate chart (green bars)
- The "综合成功率" chart should keep its green #1A6B3C bars — no change there

## Fix 3: Add emoji trend indicators with full text
- For each week-over-week change indicator, use this format:
  - **训练时长 card**: right side of the summary area, show "+0.4 小时 (+28%)" in green #1A6B3C text on one line, then "👍 环比上周" in gray rgba(60,60,67,0.6) 13pt on the line below
  - **综合成功率 card**: same format — "+3.2% (+4.6%)" green text, then "👍 环比上周" gray text below
  - **分类对比小卡片**: keep the current percentage text, but add the emoji after the percentage: "+12% 👍" for positive (green), "-2% 😢" for negative (red), "持平 ⚖️" for flat (gray)
- The emoji must be visible, not just colored text

## Fix 4: Remove the "训练建议" card at the bottom
- Completely remove the green gradient "训练建议 — 提高杆法精控度" card and its "开始专项练习" button
- After the category comparison grid, there should be just empty space before the tab bar

## Fix 5: Section titles in brand green
- Change the section title text color for "训练概况", "训练时长", and "综合成功率" (or "分类成功率") from black to brand green #1A6B3C
- Also change the "各分类对比" section title to brand green #1A6B3C
- These section titles should be 17pt Bold, color #1A6B3C

## Fix 6: Add "统计所有分类" checkbox
- In the "训练概况" card, on the right side of the section header row (same line as "训练概况"):
  - Add text "统计所有分类" in 13pt Regular gray rgba(60,60,67,0.6)
  - Followed by a filled green checkbox icon (a square with checkmark, green #1A6B3C)

## Fix 7: Add chart detail elements
- **训练时长 card**: above the big number, add a small label "平均训练" in 13pt Regular gray. Below the big number line "1.8 小时/周", add a date range "2026-03-02~2026-04-05" in 12pt Regular light gray rgba(60,60,67,0.3). Below the chart, add a legend row: a small amber #F5A623 filled square + "总量图" text, then a short dark line + "均值线" text, both in 12pt Regular gray.
- **综合成功率 card**: same structure — "平均成功率" small label above, date range below, legend with green square + "成功率" and dark line + "趋势线"

## Fix 8: Settings pill text label
- The last pill in the time range selector row currently shows only a gear icon ⚙️
- Change it to show the gear icon + "设置" text label together (icon left, text right)

## Optional improvements (if easy):
- Rename "综合成功率" to "分类成功率"
- Rename the toggle buttons from "组数 | 成功率" to "组数对比 | 成功率对比"
- Add a "管理分类" text link (green #1A6B3C, 13pt Semibold) on the far right of the toggle row
