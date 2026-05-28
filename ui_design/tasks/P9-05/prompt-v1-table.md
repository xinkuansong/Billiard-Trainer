# Stitch Prompt — P9-05 Frame 1: ContactPointTableView Enhanced (Light Mode)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode.

## Screen: ContactPointTableView — Enhanced Contact Point Reference Table

This is an enhanced version of an existing contact point reference tool page. The page is accessed by tapping "进球点对照表" from the Angle Training home page. It maps cut angles (0°–90°) to contact point positions on the object ball, with an expanded 19-row table with d/R values, and actual displacement in millimeters. Fixed to Chinese 8-ball (中八) specifications (ball radius R=28.575mm, diameter 57.15mm). No ball-type switching tabs. The page scrolls vertically with these sections: interactive slider with ball diagram → expanded reference table → principle explanation.

## Layout (top to bottom)

### 1. Navigation Bar (Sub-page Mode)

- Standard iOS navigation bar, pushed sub-page from AngleHomeView
- Left: system blue back arrow "chevron.left" + "角度训练" back label
- Center title: "进球点对照表" 17pt Semibold, color #000000
- Background: white, thin bottom separator
- **No bottom 5-tab bar** — this is a pushed sub-page

### 2. Interactive Slider Section

White (#FFFFFF) card, corner radius 12pt, 16pt internal padding, 16pt horizontal margins. 12pt top gap from navigation bar.

#### Ball Surface Diagram (centered)

- A circle (~120pt diameter) representing the object ball, viewed from the front
- Ball fill: light gray solid #E8E8ED
- A small green dot (~12pt) on the ball surface indicating the contact point
  - Color: #1A6B3C (brand green)
  - Position: at 50% offset from center (showing 30° state)
- Thin horizontal reference line through ball center (very light gray, 1pt)

#### Value Display (below ball, centered)

- **Angle**: "30°" in 32pt Bold, color #000000
- **Offset**: "偏移 50%" in 15pt Regular, color rgba(60,60,67,0.6)
- **d/R value**: "d/R = 1.00" in 14pt Medium, color #1A6B3C
- **Common name**: "半球" in a small pill/badge — background rgba(26,107,60,0.12), text #1A6B3C, 13pt Medium, corner radius 999pt (pill shape), horizontal padding 10pt, vertical padding 3pt

#### Slider Control

- Full-width iOS slider, 16pt horizontal padding within card
- Track: inactive #E5E5EA, active #1A6B3C
- Thumb: white circle with subtle shadow
- Left label: "0°" in 13pt rgba(60,60,67,0.6)
- Right label: "90°" in 13pt rgba(60,60,67,0.6)
- Position: at 30° (1/3 from left)

### 3. Expanded Reference Table

White (#FFFFFF) card, corner radius 12pt, 16pt internal padding, 16pt horizontal margins. 12pt top gap from slider card.

- **Section icon + title**: grid icon (SF Symbol "tablecells") + "对照表" 17pt Semibold, color #000000
- **Subtitle**: "球径 57.15mm（中八）" in 13pt Regular, rgba(60,60,67,0.6)

#### Table Header Row

6 columns, horizontally distributed with compact spacing:

| Column | Label | Width | Align |
|--------|-------|-------|-------|
| 1 | 切入角 | ~50pt | left |
| 2 | sin(α) | ~48pt | center |
| 3 | d/R | ~38pt | center |
| 4 | 偏移% | ~42pt | center |
| 5 | d(mm) | ~46pt | center |
| 6 | 通称 | ~55pt | right |

- Header text: 12pt Semibold, color rgba(60,60,67,0.6)
- Bottom separator: 0.5pt #E5E5EA

#### Table Data Rows (19 rows, every 5° from 0° to 90°)

Row height: ~36pt. All value text: 13pt Regular, color #000000.

**Regular rows** — white #FFFFFF background:

| 切入角 | sin(α) | d/R | 偏移% | d(mm) | 通称 |
|--------|--------|-----|-------|-------|------|
| 5° | 0.09 | 0.17 | 8.7% | 4.98 | — |
| 15° | 0.26 | 0.52 | 25.9% | 14.80 | — |
| 20° | 0.34 | 0.68 | 34.2% | 19.54 | — |
| 25° | 0.42 | 0.85 | 42.3% | 24.14 | — |
| 35° | 0.57 | 1.15 | 57.4% | 32.77 | — |
| 40° | 0.64 | 1.29 | 64.3% | 36.74 | — |
| 45° | 0.71 | 1.41 | 70.7% | 40.41 | — |
| 50° | 0.77 | 1.53 | 76.6% | 43.77 | — |
| 55° | 0.82 | 1.64 | 81.9% | 46.82 | — |
| 60° | 0.87 | 1.73 | 86.6% | 49.51 | — |
| 65° | 0.91 | 1.81 | 90.6% | 51.81 | — |
| 70° | 0.94 | 1.88 | 94.0% | 53.70 | — |
| 75° | 0.97 | 1.93 | 96.6% | 55.21 | — |
| 80° | 0.98 | 1.97 | 98.5% | 56.30 | — |
| 85° | 1.00 | 1.99 | 99.6% | 56.94 | — |

**Highlighted rows** (rows with common names) — background rgba(26,107,60,0.12), all text in this row uses #1A6B3C color:

| 切入角 | sin(α) | d/R | 偏移% | d(mm) | 通称 |
|--------|--------|-----|-------|-------|------|
| 0° | 0.00 | 0.00 | 0% | 0.00 | 全球 |
| 10° | 0.17 | 0.35 | 17.4% | 9.91 | ≈1/3球 |
| 30° | 0.50 | 1.00 | 50.0% | 28.58 | 半球 |
| 90° | 1.00 | 2.00 | 100% | 57.15 | 极薄球 |

- "通称" column values for highlighted rows: 13pt Semibold #1A6B3C
- "—" for rows without common names: 13pt Regular rgba(60,60,67,0.3)
- Thin 0.5pt #F2F2F7 separator between rows
- The highlighted rows should clearly stand out with their green-tinted background

### 4. Principle Explanation Section

White (#FFFFFF) card, corner radius 12pt, 16pt internal padding, 16pt horizontal margins. 12pt top gap from table card.

- **Section icon + title**: info.circle icon + "原理说明" 17pt Semibold, #000000
- Formula: "偏移量 = sin(α) × R" in 15pt monospace-style, color #1A6B3C
- Explanation text (15pt Regular, rgba(60,60,67,0.6)):
  - "其中 α 为切入角，R 为目标球半径。"
  - "d/R = 2sin(α) 表示接触点偏移量与球半径之比，是一个无量纲的通用比值——不随球种改变。实际偏移距离 d(mm) = d/R × R，随球种变化。"
  - "切入角越大，接触点越偏离球心，薄球越难控制。"

### 5. Bottom Spacer

- 32pt bottom padding below the last card
- No bottom tab bar

## Design Tokens

- Primary color: #1A6B3C (billiard table green)
- Page background: #F2F2F7
- Card background: #FFFFFF
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Text tertiary: rgba(60,60,67,0.3)
- Text accent: #1A6B3C
- Highlighted row background: rgba(26,107,60,0.12)
- Highlighted row text: #1A6B3C
- Slider track active: #1A6B3C
- Slider track inactive: #E5E5EA
- Contact point dot: #1A6B3C
- Common name pill: bg rgba(26,107,60,0.12), text #1A6B3C
- Card corner radius: 12pt
- Section gap: 12pt
- Card internal padding: 16pt
- Page horizontal padding: 16pt

## Reference Style

- This is an ENHANCED version of an existing page. The original had 4 columns (切入角/sin(α)/偏移/通称) with 13 rows. The enhanced version adds 2 new columns (d/R, d(mm)) and expands to 19 rows (every 5°). No tab bar — fixed to Chinese 8-ball (中八) data.
- The overall card-based ScrollView layout follows the existing pattern: white cards with 12pt corner radius stacked on #F2F2F7 background.
- The ball surface diagram is a front-view circle (not 3D sphere), representing looking at the object ball from the shooter's perspective — identical to the existing design.
- The slider + ball diagram section is preserved from the original, only adding the d/R value display.
- The table should feel clean and readable despite having 6 columns — use compact font size (13pt) and tight column spacing.

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- iOS native feel: SF Pro font family, SF Symbols icons
- NO gradient fills — all solid colors (flat fill only)
- NO bottom 5-tab bar (pushed sub-page)
- NO promotional cards, marketing content, or call-to-action buttons at the bottom
- The page ends after the principle explanation section — nothing else below
- All text in Simplified Chinese
- Slider is at 30° showing "半球" as default state
- NO tab bar at top — the page starts directly with the slider section below the navigation bar
- Show ALL 19 rows of the table (0° through 90° every 5°). The page is scrollable — show at least the slider section and beginning of the table visible on screen, with the rest scrollable below
- Highlighted rows (0°, 10°, 30°, 90°) must clearly stand out with green-tinted background
- This is an incremental upgrade of an existing design — maintain the same visual DNA, do not redesign from scratch

## State

Default state: Slider at 30° (half-ball), ball diagram showing contact point at 50% offset. d/R displays "1.00". Common name badge shows "半球". Table shows all 19 rows for 中八 ball type (R=28.575mm, diameter 57.15mm). Four rows highlighted green (0° 全球, 10° ≈1/3球, 30° 半球, 90° 极薄球). Principle explanation visible at bottom. Page scrolls vertically. No tab bar.
