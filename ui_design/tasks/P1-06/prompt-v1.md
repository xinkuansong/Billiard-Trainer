# Stitch Prompt — P1-06: AngleHistoryView (角度测试历史统计)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode only.

## Screen: AngleHistoryView — Angle Test History & Statistics

This is a sub-page pushed from the "角度训练" (Angle Training) tab's home page, via the "测试历史" (Test History) entry row. It displays the user's historical performance in angle estimation tests — summary statistics, trend over time, and per-angle-range accuracy breakdown. The user comes here to review progress and identify weak angle ranges. This screen shows the "has data" state with meaningful statistics.

## Layout (top to bottom)

### 1. Standard iOS Navigation Bar (not large title)

- Left: back arrow "chevron.left" in brand green #1A6B3C, acts as back button to AngleHomeView
- Center title: "测试历史" 17pt Semibold, color #000000
- No right-side buttons
- Navigation bar background: white or transparent over #F2F2F7, with subtle bottom separator
- NO bottom 5-tab bar on this page (this is a pushed sub-page, not a tab root)

### 2. Summary Statistics Cards (2×2 Grid)

- 16pt horizontal margins, 16pt top gap from navigation bar
- LazyVGrid layout: 2 columns, 12pt gap between cards
- Each card: white #FFFFFF background, corner radius 12pt, 16pt internal padding
- Card width: approximately (393 - 16 - 16 - 12) / 2 ≈ 174pt each

#### Card A: 总测试次数 (Total Tests)
- Top: SF Symbol "number.circle" 20pt, color #1A6B3C
- Middle: "128" — 28pt Bold, color #000000
- Bottom: "总测试次数" — 13pt Regular, color rgba(60,60,67,0.6)

#### Card B: 平均误差 (Average Error)
- Top: SF Symbol "arrow.left.arrow.right" 20pt, color #D4941A (amber)
- Middle: "4.2°" — 28pt Bold, color #000000
- Bottom: "平均误差" — 13pt Regular, color rgba(60,60,67,0.6)

#### Card C: 最佳成绩 (Best Score)
- Top: SF Symbol "trophy" 20pt, color #1A6B3C
- Middle: "1.0°" — 28pt Bold, color #1A6B3C (highlighted in brand green)
- Bottom: "最佳成绩" — 13pt Regular, color rgba(60,60,67,0.6)

#### Card D: 正确率 (Accuracy Rate)
- Top: SF Symbol "checkmark.circle" 20pt, color #1A6B3C
- Middle: "76%" — 28pt Bold, color #000000
- Bottom: "正确率" — 13pt Regular, color rgba(60,60,67,0.6)

### 3. Time Range Selector

- 24pt top gap from statistics cards
- 16pt horizontal margins
- Segmented control with 3 options: "周" (Week) | "月" (Month) | "全部" (All)
- Selected segment: brand green #1A6B3C filled background + white text 15pt Semibold
- Unselected segments: transparent background + #000000 text 15pt Regular
- Overall control: pill shape (corner radius 999pt), light gray border or background rgba(60,60,67,0.08), height 36pt
- Full width within margins

### 4. Trend Chart Card

- 12pt top gap from time range selector
- 16pt horizontal margins
- White #FFFFFF card, corner radius 12pt, 16pt internal padding

#### Card header row:
- Left: Section title "误差趋势" 18pt Bold, color #000000
- Right: Toggle pills for "角袋" | "中袋" — small text pills 12pt, selected in brand green #1A6B3C fill + white text, unselected in gray border + gray text. Each pill height 28pt, corner radius 999pt, horizontal padding 12pt.

#### Chart area:
- Height approximately 180pt
- Canvas-drawn line chart
- X-axis: date labels (e.g., "3/28", "3/29", "3/30", "3/31", "4/1", "4/2", "4/3", "4/4") — 11pt Regular, color rgba(60,60,67,0.6), bottom aligned
- Y-axis: error degree labels (e.g., "0°", "3°", "6°", "9°", "12°") — 11pt Regular, color rgba(60,60,67,0.6), left aligned
- Grid lines: very light gray rgba(60,60,67,0.08), horizontal only
- Primary line (角袋): brand green #1A6B3C, 2pt stroke, smooth curve, with small 6pt circle data points at each value
- Secondary line (中袋): amber #D4941A, 2pt stroke, dashed style, with small 6pt circle data points
- Area fill below primary line: rgba(26,107,60,0.08) subtle gradient to transparent
- Latest data point on primary line: larger 8pt circle with brand green fill, to show current position

### 5. Angle Range Analysis Card

- 12pt top gap from trend chart card
- 16pt horizontal margins
- White #FFFFFF card, corner radius 12pt, 16pt internal padding

#### Card header:
- Section title "角度区间分析" 18pt Bold, color #000000
- Subtitle: "各角度范围正确率" 13pt Regular, color rgba(60,60,67,0.6), 4pt below title

#### Range rows (6 rows stacked vertically, 12pt gap between each):
Each row layout:

- **Row label** (left): angle range text "0°-15°" 15pt Regular, color #000000, fixed width ~70pt
- **Progress bar** (center, flex grow): height 24pt, corner radius 12pt
  - Background: rgba(60,60,67,0.06)
  - Fill bar: brand green #1A6B3C, width proportional to accuracy percentage
- **Percentage** (right): "92%" 15pt Semibold, color #000000, fixed width ~45pt, right aligned

The 6 rows with sample data:
1. "0°-15°" — 92% — brand green #1A6B3C fill (high accuracy, long bar)
2. "15°-30°" — 85% — brand green #1A6B3C fill
3. "30°-45°" — 78% — brand green #1A6B3C fill
4. "45°-60°" — 62% — amber #D4941A fill (medium-low, indicating weaker range)
5. "60°-75°" — 48% — #C62828 red fill (weak range, visually highlighted as problem area)
6. "75°-90°" — 35% — #C62828 red fill (weakest, shortest bar, most prominent warning)

Color coding logic: ≥70% → brand green #1A6B3C, 50%-69% → amber #D4941A, <50% → red #C62828

### 6. Bottom safe area padding

- 34pt bottom padding (iPhone home indicator safe area) below the last card
- The page scrolls vertically if content exceeds viewport — ScrollView behavior

## Design Tokens

- Primary color: #1A6B3C (billiard table green)
- Accent color: #D4941A (amber/gold)
- Destructive color: #C62828 (red, for weak performance indicators)
- Page background: #F2F2F7
- Card background: #FFFFFF
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Text tertiary: rgba(60,60,67,0.3)
- Card corner radius: 12pt
- Pill corner radius: 999pt
- Page horizontal padding: 16pt
- Card internal padding: 16pt
- Card gap: 12pt
- Section gap: 24pt
- Minimum touch target: 44pt

## Reference Style

- This screen follows the pushed sub-page pattern: standard iOS navigation bar with back arrow + centered Chinese title, no bottom tab bar — same pattern as DrillDetailView (P1-03) and ContactPointTableView (P1-05 frame 2)
- The 2×2 statistics grid is similar to fitness apps' workout summary cards (like Apple Fitness summary tiles) — each card shows one key metric with icon + big number + label
- The trend line chart follows the iOS Health app's line chart style — clean, minimal grid, smooth curves, colored area fill
- The angle range analysis uses horizontal progress bars similar to storage breakdown views (like iPhone Storage) — clear visual comparison between ranges
- Color coding (green → amber → red) for performance ranges follows the traffic light pattern common in fitness/health apps
- Overall page is a scrollable statistics dashboard — cards stacked vertically with consistent spacing

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- iOS native feel: SF Pro font family, SF Symbols icons throughout
- NO gradient fills on any solid-color element — all flat/solid fills
- Minimum touch target: 44pt for all interactive elements
- NO bottom 5-tab bar (this is a pushed sub-page from AngleHomeView)
- Back arrow color must be brand green #1A6B3C (iOS default tint)
- Chart should look hand-drawn/Canvas style — not a screenshot of a charting library
- All text in Simplified Chinese
- The trend line should show a generally improving (downward) trend to convey practice benefit
- The angle range bars should clearly show a gradient from "easy small angles" to "hard large angles"

## State

Has data state: User has completed 128 angle tests over the past few weeks. Statistics show meaningful patterns — small angles (0°-30°) are relatively easy, while large angles (60°-90°) need more practice. The "周" (Week) time range is selected. The trend chart shows the last 7-8 days of data with a generally improving (decreasing error) trajectory.
