# Stitch Prompt — P1-09: StatisticsView (训练统计图表 — 有数据周视图)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode only.

## Screen: StatisticsView — Training Statistics Dashboard

This is the "记录" (History) tab root page, but with the "统计" (Statistics) sub-tab selected. The page shares the same top-level structure as the History Calendar view — same large title "记录", same BTSegmentedTab, but the content area shows data visualization charts and statistics instead of a calendar. The user has been actively training for several weeks, so all charts show meaningful data. Currently showing the weekly ("周") time range view.

## Layout (top to bottom)

### 1. iOS Large Title Navigation Bar

- Large title text: "记录"
- Font: 34pt Bold Rounded, color #000000, on #F2F2F7 background
- Standard iOS large title behavior — sits below status bar with generous top padding
- No right-side icon buttons (consistent with P1-07 HistoryCalendarView)

### 2. BTSegmentedTab (History | Statistics)

- 16pt horizontal margins, 12pt below the navigation bar title
- Two horizontal text tabs: "历史" and "统计"
- Each tab label: 16pt Medium
- **Active tab "统计"**: text color brand green #1A6B3C, with a 2pt-thick brand green #1A6B3C underline indicator directly below the text
- **Inactive tab "历史"**: text color rgba(60,60,67,0.6), no underline
- Tab spacing: 24pt between the two labels
- Left-aligned (not centered across full width)

### 3. Time Range Selector Row

- 12pt top gap from the segmented tab
- 16pt horizontal margins
- A horizontal row of pill-shaped buttons (like a segmented control but pill style)
- 5 pills in a row with 8pt gaps: "周" | "月" | "年" | "自定时间" | "设置"
- **Active pill "周"**: white #FFFFFF background, 1pt border brand green #1A6B3C, text brand green #1A6B3C 14pt Semibold
- **Inactive pills**: rgba(60,60,67,0.06) background, no border, text rgba(60,60,67,0.6) 14pt Regular
- Pill height: 32pt, corner radius 999pt (full pill), horizontal padding 14pt
- "设置" pill has a SF Symbol "gearshape" icon (13pt) before the text

### 4. Training Overview Card — "训练概况"

- 12pt top gap from time range selector
- 16pt horizontal margins
- White #FFFFFF card, corner radius 16pt, 16pt internal padding

#### Section Header Row:
- Left: "训练概况" — 17pt Bold, color brand green #1A6B3C (data/statistics page section title uses brand green per P1-06 decision)
- Right side: "统计所有分类" text 13pt Regular rgba(60,60,67,0.6) + a green filled checkbox icon (SF Symbol "checkmark.square.fill" 16pt, brand green #1A6B3C)

#### Main Content (horizontal split):
- **Left area (approx 55% width)**:
  - Big number: "5" — 40pt Bold, color #000000
  - Subscript: "天" — 17pt Regular, color #000000, baseline-aligned to the right of "5"
  - Label below: "本周训练数" — 13pt Regular, color rgba(60,60,67,0.6), 4pt gap
  - 12pt gap below
  - Category breakdown row (horizontal, wrapping):
    - "3天" 13pt Bold brand green #1A6B3C + "准度" 13pt Regular rgba(60,60,67,0.6)
    - "2天" 13pt Bold amber #D4941A + "杆法" 13pt Regular rgba(60,60,67,0.6)
    - "1天" 13pt Bold #5C6BC0 + "走位" 13pt Regular rgba(60,60,67,0.6)
    - Items separated by 12pt gaps, wrap to second line if needed

- **Right area (approx 45% width)**:
  - Mini vertical bar chart showing last 6 weeks of training day counts
  - 6 bars, each width ~16pt, gap ~6pt
  - Bar colors: brand green #1A6B3C for the current week's bar, rgba(26,107,60,0.3) for past weeks
  - Bar heights proportional to data (example: heights from left to right — 3, 4, 2, 5, 3, 5)
  - The current week (rightmost) bar has a small label "5天" above it in 11pt Regular rgba(60,60,67,0.6)
  - Below the bars: "过去6周训练" text in 11pt Regular rgba(60,60,67,0.3), right-aligned
  - A thin dashed horizontal line at the average level — rgba(60,60,67,0.15) dashed 1pt

### 5. Training Duration Trend Chart — "训练时长"

- 12pt top gap
- 16pt horizontal margins
- White #FFFFFF card, corner radius 16pt, 16pt internal padding

#### Section Header:
- "训练时长" — 17pt Bold, color brand green #1A6B3C

#### Summary Row:
- Line 1: "平均训练" — 13pt Regular rgba(60,60,67,0.6)
- Line 2: "1.8" 28pt Bold #000000 + "小时/周" 15pt Regular rgba(60,60,67,0.6)
- Line 3: "2026-03-02~2026-04-05" — 12pt Regular rgba(60,60,67,0.3)

#### Week-over-Week Change Indicator (right-aligned, same row as summary):
- "+0.4 小时 (+28%)" — 15pt Semibold, color brand green #1A6B3C (positive = green)
- Below: "👍 环比上周" — 13pt Regular rgba(60,60,67,0.6), with thumbs-up emoji for positive change
- Positive change: green text + 👍
- Negative change: red #C62828 text + 😢
- Flat: gray rgba(60,60,67,0.6) text + ⚖️

#### Bar Chart Area:
- Full card width, height ~160pt
- X-axis: week labels (week numbers or date ranges like "26", "27", ... "本周"), 11pt Regular rgba(60,60,67,0.3)
- Y-axis (right side): hour values "0.0", "0.5", "1.0", "1.5", "2.0", 11pt Regular rgba(60,60,67,0.3)
- **Bars**: amber/orange #F5A623 filled rectangles, width ~20pt, corner radius 3pt top, representing weekly total hours
- **Trend line**: dark line #1A1A1A, 2pt stroke, connecting the moving average points across weeks — line overlays on top of bars
- Data points on trend line: small circles 4pt diameter, filled dark #1A1A1A
- Horizontal grid lines: rgba(60,60,67,0.06) 0.5pt
- Show ~8 weeks of data, the current week's bar slightly taller (more data)

#### Chart Legend:
- Below the chart, 8pt gap
- "■ 总量图" — small amber #F5A623 square (8pt) + "总量图" 12pt Regular rgba(60,60,67,0.6)
- "— 均值线" — short dark line (12pt wide, 2pt) + "均值线" 12pt Regular rgba(60,60,67,0.6)
- 16pt gap between the two legend items
- Left-aligned

### 6. Category Success Rate Chart — "分类成功率"

- 12pt top gap
- 16pt horizontal margins
- White #FFFFFF card, corner radius 16pt, 16pt internal padding
- Same structure as Section 5, but showing success rate percentage instead of hours:
  - Section title: "分类成功率" — 17pt Bold brand green #1A6B3C
  - Summary: "平均成功率" + "72.5" 28pt Bold + "%" 15pt Regular
  - WoW indicator: "+3.2% (+4.6%)" green + 👍
  - Bar chart: brand green #1A6B3C bars (not amber), same chart style, Y-axis shows percentages "0%", "25%", "50%", "75%", "100%"
  - Trend line: dark #1A1A1A 2pt stroke
  - Legend: "■ 成功率" green square + "— 趋势线" dark line

### 7. Category Comparison Grid — "各分类对比"

- 12pt top gap
- 16pt horizontal margins

#### Toggle Row:
- Two pill-style toggle buttons: "组数对比" (active) | "成功率对比" (inactive)
- Active pill: brand green #1A6B3C background + white text 13pt Semibold, corner radius 999pt, height 28pt
- Inactive pill: rgba(60,60,67,0.06) background + rgba(60,60,67,0.6) text 13pt Regular
- Right-aligned text link: "管理分类" — 13pt Semibold brand green #1A6B3C
- 12pt gap below

#### 2-Column Card Grid (LazyVGrid):
- 2 columns with 12pt horizontal gap, 12pt vertical gap
- 8 cards total (4 rows × 2 columns), representing billiard training categories:

**Each card structure:**
- White #FFFFFF background, corner radius 12pt, 12pt internal padding
- **Row 1**: Category name — 17pt Bold #000000 (e.g. "准度", "杆法", "走位", "防守", "翻袋", "组合球", "安全球", "K球")
- **Row 1 right side**: WoW change — 13pt Semibold
  - Positive: green #1A6B3C text like "+12%" + small line break + "环比上周" 11pt rgba(60,60,67,0.6)
  - Flat: gray rgba(60,60,67,0.6) text "持平" + ⚖️ emoji + "环比上周" 11pt
  - Negative: red #C62828 text like "-5%" + 😢
- **Mini bar chart** below (8pt top gap):
  - 8 thin bars representing last 8 data points, each bar width ~12pt, gap ~4pt
  - Bar height proportional to data, max height ~36pt
  - Current period bar: brand green #1A6B3C, past bars: rgba(26,107,60,0.25)
  - Small value labels below each bar: "0", "3", "5", etc. — 9pt Regular rgba(60,60,67,0.3)
  - Rightmost label: "本周" — 9pt Regular rgba(60,60,67,0.3)

**Sample data for the 8 category cards:**
1. 准度: "+12% 环比上周" (green) — bars trending up
2. 杆法: "+5% 环比上周" (green) — bars slightly up
3. 走位: "持平 ⚖️ 环比上周" (gray) — bars flat
4. 防守: "-8% 环比上周" (red) — bars trending down
5. 翻袋: "+20% 环比上周" (green) — bars significantly up
6. 组合球: "持平 ⚖️ 环比上周" (gray) — bars flat
7. 安全球: "+3% 环比上周" (green) — bars slightly up
8. K球: "-2% 环比上周" (red) — bars slightly down

### 8. Bottom Safe Area + Tab Bar

- 24pt gap below the last grid card
- Tab bar is fixed at bottom

#### Five-Tab Bottom Bar (Fixed):
- 5 tabs: 训练 | 动作库 | 角度 | **记录** | 我的
- **Active tab "记录"**: icon + text in brand green #1A6B3C
- Inactive tabs: icon + text in gray rgba(60,60,67,0.6)
- Tab bar background: white with subtle top border
- Tab bar height: ~49pt (standard iOS)
- Tab icons (SF Symbols): "figure.run" | "books.vertical" | "angle" | "calendar" | "person"

## Design Tokens

- Primary color: #1A6B3C (billiard table green)
- Accent color: #D4941A (amber/gold, for Pro elements)
- Chart bar amber: #F5A623 (for duration bars)
- Page background: #F2F2F7
- Card background: #FFFFFF
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Text tertiary: rgba(60,60,67,0.3)
- Positive trend: #1A6B3C (green) + 👍
- Negative trend: #C62828 (red) + 😢
- Flat trend: rgba(60,60,67,0.6) (gray) + ⚖️
- Trend line: #1A1A1A 2pt stroke
- Large title font: 34pt Bold Rounded
- Section title font: 17pt Bold, brand green #1A6B3C
- Big number font: 28-40pt Bold
- Body font: 17pt Regular
- Caption font: 13pt Regular
- Mini label font: 11pt Regular
- Card corner radius: 16pt (main cards), 12pt (grid cards)
- Pill corner radius: 999pt
- Page horizontal padding: 16pt
- Card internal padding: 16pt (main), 12pt (grid)
- Card gap: 12pt
- Bar chart bar width: ~20pt (main), ~12pt (mini)
- Bar corner radius: 3pt (top only)
- Tab underline: 2pt thick, brand green #1A6B3C

## Reference Style

- The top of the page (large title "记录" + BTSegmentedTab + time range pills) mirrors the reference fitness app's statistics tab layout — a clean horizontal tab for History/Statistics, then time range pill selector
- The training overview card uses the same pattern as the reference: big number left + mini bar chart right, with category breakdowns below — adapted from body part categories to billiard training categories (准度/杆法/走位 etc.)
- The trend charts follow the reference app's style: amber/orange bars for volume data + dark overlay trend line + week-over-week change indicator with emoji
- The category comparison grid follows the reference's 2-column card layout with mini bar charts per category — but uses billiard categories instead of muscle groups
- Section titles use brand green #1A6B3C (a pattern established in P1-06 AngleHistoryView for data/statistics pages)
- Overall feel: a data-rich statistics dashboard that gives the user an at-a-glance understanding of their billiard training patterns, trends, and category-level performance

## Consistency Notes

- This page shares the exact same navigation header as P1-07 (HistoryCalendarView) — same "记录" large title, same BTSegmentedTab component, but with "统计" selected instead of "历史"
- Section titles in brand green #1A6B3C — established in P1-06 for data/statistics pages
- The 5-tab bottom bar matches all previous screens (P0-01 through P1-08) with "记录" as the active tab
- Category cards in the grid use the same icon+label horizontal row + big value pattern established in P1-06

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- iOS native feel: SF Pro font family, SF Symbols icons throughout
- NO gradient fills on any element — all solid/flat fills
- NO body/muscle diagram — this is a billiard training app, NOT a fitness/gym app
- Minimum touch target: 44pt for all interactive elements
- Large title must be pure black #000000 (NOT brand green)
- Section titles ("训练概况", "训练时长", "分类成功率") MUST be brand green #1A6B3C
- The BTSegmentedTab must use the underline indicator style (NOT iOS system segmented control / pill style)
- Bar chart bars must use AMBER #F5A623 for duration, BRAND GREEN #1A6B3C for success rate — do NOT use the same color for both charts
- Trend lines must be dark #1A1A1A (NOT brand green or amber)
- Week-over-week emoji indicators: 👍 for positive, 😢 for negative, ⚖️ for flat — must be visible
- The page scrolls vertically — all sections won't fit in one viewport
- All text in Simplified Chinese
- The "记录" tab in the bottom bar must be highlighted in brand green #1A6B3C
- Category names must be billiard-specific: 准度, 杆法, 走位, 防守, 翻袋, 组合球, 安全球, K球

## State

Has data state (weekly view): The user has been training consistently for 8+ weeks. All charts show meaningful data with visible trends. The weekly time range ("周") is selected. Training overview shows 5 training days this week across 3 categories. Duration trend chart shows increasing trend. Category success rate shows moderate improvement. The 8-category comparison grid shows a mix of improving, flat, and declining categories. This is a data-rich, optimistic view that motivates the user to see their progress.
