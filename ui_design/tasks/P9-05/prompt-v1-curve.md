# Stitch Prompt — P9-05 Frame 2: Sine Curve Chart Section (Light Mode)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode.

## Screen: ContactPointTableView — Sine Curve Section (Scrolled Down)

This shows the same ContactPointTableView page scrolled down to reveal the new "Sine Curve" section at the bottom. The user has scrolled past the slider, the 19-row reference table, and the principle explanation. Now visible: the tail end of the principle explanation card, and the new sine curve chart section. The navigation bar remains fixed at top. This is the bottom portion of the same scrollable page from Frame 1.

## Layout (top to bottom)

### 1. Navigation Bar (Fixed at Top)

- Same as Frame 1: back arrow + "角度训练" label, center title "进球点对照表" 17pt Semibold
- No tab bar below the nav bar — the page has no ball-type switching tabs

### 2. Principle Explanation Section (Partially Visible — Top of Viewport)

Show only the bottom portion of the principle explanation card as a visual cue that the user has scrolled past it. Just the last 1-2 lines of text visible at the top edge of the viewport:
- "切入角越大，接触点越偏离球心，薄球越难控制。"
- This establishes scroll context

### 3. Sine Curve Chart Section (Main Content of This Frame)

White (#FFFFFF) card, corner radius 12pt, 16pt internal padding, 16pt horizontal margins. 12pt top gap from the explanation card.

#### Section Header

- Section icon: SF Symbol "chart.xyaxis.line" in #1A6B3C, 20pt
- Section title: "d/R 与角度关系" 18pt Bold, color #000000, positioned next to the icon with 8pt gap
- 12pt gap below title

#### Chart Area

Canvas-drawn line chart contained within the card. Chart dimensions: full card width minus padding (~329pt wide), approximately 220pt tall.

**Axes:**

- **X-axis** (bottom, horizontal): represents cut angle in degrees (0° to 90°)
  - Axis line: 1pt solid #000000
  - Tick marks at: 0° / 15° / 30° / 45° / 60° / 75° / 90°
  - Tick labels: 12pt Regular, color rgba(60,60,67,0.6), positioned below each tick
  - Axis label: "切入角 (°)" in 12pt Regular rgba(60,60,67,0.6), centered below the tick labels

- **Y-axis** (left, vertical): represents d/R values (0 to 2.0)
  - Axis line: 1pt solid #000000
  - Tick marks at: 0 / 0.5 / 1.0 / 1.5 / 2.0
  - Tick labels: 12pt Regular, color rgba(60,60,67,0.6), positioned left of each tick
  - Axis label: "d/R" in 12pt Regular rgba(60,60,67,0.6), rotated vertically along the left side

**Grid Lines:**

- Horizontal dashed grid lines at each Y-axis tick (0.5, 1.0, 1.5, 2.0)
- Vertical dashed grid lines at each X-axis tick (15°, 30°, 45°, 60°, 75°)
- Grid line style: 0.5pt dashed, color rgba(60,60,67,0.15)

**Sine Curve:**

- The curve plots `d/R = 2sin(θ)` from θ=0° to θ=90°
- This is a smooth, upward-curving line from (0°, 0) to (90°, 2.0)
- Line color: #1A6B3C (brand green)
- Line width: 2.5pt
- Smooth bezier curve, NOT straight line segments

**Special Angle Marker Points (Red Dots + Labels):**

Mark these specific angles on the curve with prominent indicators:

| Angle | d/R Value | Common Name |
|-------|-----------|-------------|
| 0° | 0.00 | 全球 |
| 10° | 0.35 | ≈1/3球 |
| 30° | 1.00 | 半球 |
| 48.6° | 1.50 | 3/4点 |
| 90° | 2.00 | 极薄球 |

For each marker:
- **Red circle**: solid #E53935, 8pt diameter, centered on the curve at the angle's position
- **Value label**: positioned adjacent to the red dot (avoiding overlap), showing the d/R value in 11pt Bold #E53935
- **Common name label**: positioned near the value label, showing the Chinese name in 11pt Regular #000000
- Use alternating label positions (above/below the curve) to avoid overlap between adjacent markers
- The 30° marker is the largest and most prominent since it's at d/R=1.0 (the half-ball reference point)

**Filled area under curve (optional, subtle):**

- Very light green fill below the curve line: rgba(26,107,60,0.06)
- This subtle fill helps visualize the area and adds polish

#### Chart Legend / Note (Below Chart)

- 8pt gap below the chart area
- A small note text: "曲线展示切入角与 d/R 的正弦关系，红点标注常用通称角度" in 12pt Regular, color rgba(60,60,67,0.6)
- Centered within the card

### 4. Bottom Safe Area Spacer

- 48pt bottom padding after the sine curve card
- This is the end of the scrollable page content
- No bottom tab bar

## Design Tokens

- Primary color: #1A6B3C (billiard table green)
- Page background: #F2F2F7
- Card background: #FFFFFF
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Curve line color: #1A6B3C, 2.5pt width
- Marker dot color: #E53935 (red), 8pt diameter
- Marker value label: #E53935, 11pt Bold
- Grid lines: rgba(60,60,67,0.15), 0.5pt dashed
- Axis lines: #000000, 1pt solid
- Axis labels: rgba(60,60,67,0.6), 12pt Regular
- Area fill under curve: rgba(26,107,60,0.06)
- Card corner radius: 12pt
- Card internal padding: 16pt
- Page horizontal padding: 16pt

## Reference Style

- The chart follows the visual style established in the app's AngleHistoryView (P1-06): clean line chart with brand green color, subtle grid, clear axis labels. The chart in P1-06 uses a line chart with green line, orange dashed comparison line, and axis labels in gray — adopt the same clean charting aesthetic.
- The card container follows the same pattern as all other content cards in this page: white #FFFFFF with 12pt corner radius.
- The red marker dots follow the same visual convention as the contact point markers used elsewhere in the app (red dots #E53935 for important reference points).
- This section feels like the "data visualization companion" to the table above — the table gives exact numbers, the chart gives the visual relationship.

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- iOS native feel: SF Pro font family, SF Symbols icons
- NO gradient fills — all solid colors only
- NO bottom 5-tab bar (pushed sub-page)
- The curve must be a smooth, mathematically correct `2sin(θ)` shape — NOT a straight line or triangle
- The curve starts at (0°, 0) and ends at (90°, 2.0) — this is the first quadrant of 2sin(x)
- All 5 marker points (0°, 10°, 30°, 48.6°, 90°) must be visible with red dots and labels
- Labels must not overlap each other — use alternating positions (above/below curve) as needed
- All text in Simplified Chinese (except mathematical notation like d/R, sin, α)
- The chart must have clear axis labels and tick marks for readability
- This frame shows the BOTTOM portion of the same page from Frame 1 — the navigation bar is still visible at top

## State

Scrolled-down state: The page is scrolled to the bottom, showing the new sine curve section as the main visible content. No tab bar. The curve displays `d/R = 2sin(θ)` with 5 red marker points at named angles. The chart is static (no interactive hover or tap states). This is the end of the page — no content below the chart card.
