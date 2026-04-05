# Stitch Prompt — P1-05 Frame 2: ContactPointTableView (进球点对照表)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode only.

## Screen: ContactPointTableView — Contact Point Reference Table

This is a pushed sub-page from AngleHomeView (the "角度" tab). It provides an interactive reference tool mapping cut angles (0°–90°) to contact point positions on the object ball. Users use this to understand the angle aiming method (角度瞄准法) — learning where to aim on the object ball for a given cut angle. The page has three sections: an interactive slider with ball diagram, a brief explanation, and a fixed reference table.

## Layout (top to bottom)

### 1. Standard iOS Navigation Bar (NOT large title)

- Pushed sub-page from AngleHomeView, NOT a tab root page
- Left side: standard iOS back arrow "chevron.left" + "角度训练" back label, color #007AFF (system blue)
- Center title: "进球点对照表", 17pt Semibold, color #000000
- Navigation bar background: white, standard iOS thin bottom separator
- **NO bottom 5-tab bar** — this is a detail sub-page

### 2. Interactive Slider Section

White (#FFFFFF) card, corner radius 16pt, 16pt internal padding, 16pt horizontal margins. This is the hero interactive area.

#### Ball Surface Diagram (centered, top of card)

- A large circle (~120pt diameter) representing the object ball, viewed from the front
- Ball fill: light gray gradient or solid #E8E8ED to represent a pool ball surface
- A small colored dot (~12pt) on the ball surface indicating the **contact point** position
  - Contact point color: brand green #1A6B3C
  - Position: shifts from center (0°) toward the edge (90°) based on the current slider value
  - At 0°: dot is at the center of the ball (full ball hit)
  - At 30°: dot is at 50% offset from center (half ball)
  - At 90°: dot is at the very edge (thin cut)
- A thin horizontal line through the ball center as reference axis (very light gray, 1pt)
- Below the ball: current angle displayed large — e.g., "30°" in 32pt Bold, color #000000
- Below the angle: offset percentage — e.g., "偏移 50%" in 15pt Regular, color rgba(60,60,67,0.6)
- Below the percentage: common name if applicable — e.g., "二分之一球" in 13pt Regular, color #1A6B3C (only shown for named angles)

#### Slider Control

- Full-width iOS-style slider below the ball diagram, 16pt horizontal padding within card
- Track: light gray background (#E5E5EA), green filled portion #1A6B3C
- Thumb: white circle with subtle shadow, 28pt diameter
- Left label: "0°" in 13pt, color rgba(60,60,67,0.6)
- Right label: "90°" in 13pt, color rgba(60,60,67,0.6)
- Current value: slider positioned at 30° (about 1/3 from left) as the default display state

### 3. Explanation Section

White (#FFFFFF) card, corner radius 12pt, 16pt internal padding, 16pt horizontal margins. 12pt top gap from slider card.

- **Section title**: "原理说明" 17pt Semibold, color #000000
- 8pt below title:
- **Formula line**: "偏移量 = sin(α) × R" in 15pt Regular, using a monospace-style presentation or slightly different styling (e.g., background highlight pill #F2F2F7 inline) to distinguish the formula
- 4pt below:
- **Explanation text**: 2-3 lines of 15pt Regular, color rgba(60,60,67,0.6), explaining in plain Chinese:
  - "其中 α 为切入角，R 为目标球半径。"
  - "切入角越大，接触点越偏离球心，薄球越难控制。"

### 4. Reference Table Section

White (#FFFFFF) card, corner radius 12pt, 16pt internal padding, 16pt horizontal margins. 12pt top gap from explanation card.

- **Section title**: "对照表" 17pt Semibold, color #000000
- 8pt below title:

#### Table Header Row
- 4 columns, horizontally distributed:
  - "切入角" — 13pt Semibold, color rgba(60,60,67,0.6)
  - "sin(α)" — 13pt Semibold, color rgba(60,60,67,0.6)
  - "偏移" — 13pt Semibold, color rgba(60,60,67,0.6)
  - "通称" — 13pt Semibold, color rgba(60,60,67,0.6)
- Header row has a light bottom separator line (#E5E5EA, 0.5pt)

#### Table Data Rows (13 rows)
Each row is a horizontal layout with 4 columns aligned to the header. Row height ~40pt. Alternating row backgrounds for readability: odd rows #FFFFFF, even rows #FAFAFA.

| 切入角 | sin(α) | 偏移 | 通称 |
|--------|--------|------|------|
| 0° | 0.00 | 球心 | 全球 |
| 10° | 0.17 | 17% | — |
| 15° | 0.26 | 26% | — |
| 20° | 0.34 | 34% | — |
| 25° | 0.42 | 42% | — |
| 30° | 0.50 | 50% | 二分之一球 |
| 35° | 0.57 | 57% | — |
| 40° | 0.64 | 64% | — |
| 45° | 0.71 | 71% | — |
| 48.6° | 0.75 | 75% | 四分之三点 |
| 60° | 0.87 | 87% | — |
| 75° | 0.97 | 97% | — |
| 90° | 1.00 | 球边缘 | 极薄球 |

- Text in data rows: 14pt Regular, color #000000 for values, color #1A6B3C for 通称 column (named entries only, "—" in gray rgba(60,60,67,0.3))
- **Highlighted rows** (rows with a common name): 0°, 30°, 48.6°, 90° — these rows have a very light green left border (3pt, #1A6B3C at 30% opacity) or a subtle green-tinted background rgba(26,107,60,0.05) to visually distinguish them
- Each row optionally has a tiny ball diagram (~16pt circle) at the far left showing the contact point position for that angle — if space allows; otherwise omit for cleanliness

### 5. Bottom Safe Area Spacing

- 24pt padding below the table card to the bottom of the scroll view
- The page scrolls vertically — the slider section, explanation, and table extend beyond the viewport

## Design Tokens

- Primary color: #1A6B3C (billiard table green)
- Page background: #F2F2F7
- Card background: #FFFFFF
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Text tertiary: rgba(60,60,67,0.3)
- Text accent (named angles): #1A6B3C
- Slider track active: #1A6B3C
- Slider track inactive: #E5E5EA
- Contact point dot: #1A6B3C
- Card corner radius: 16pt (hero card), 12pt (content cards)
- Table row height: ~40pt
- Table alternating row: #FAFAFA
- Highlighted row tint: rgba(26,107,60,0.05)
- Page horizontal padding: 16pt
- Card internal padding: 16pt
- Card gap: 12pt
- Minimum touch target: 44pt

## Reference Style

- This is a reference/educational tool page — clean, readable, table-heavy content similar to a textbook reference card
- The interactive slider + ball diagram at the top provides an engaging "try it yourself" experience before the static reference table
- The overall layout follows the iOS Settings / Health app pattern for detail sub-pages: navigation bar + scrollable card sections
- The ball surface diagram should feel like a simple, clean physics illustration — not a photorealistic rendering
- The reference table should feel like a well-formatted data table with clear column alignment and subtle row alternation
- Visual style must be consistent with the approved AngleHomeView (P1-05 Frame 1) and the broader app design system (P0-01, P1-01)

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- iOS native feel: SF Pro font family, SF Symbols icons
- NO gradient fills on buttons — all solid colors
- NO bottom 5-tab bar — this is a pushed sub-page
- Standard iOS navigation bar with back arrow (not large title style)
- The page must scroll — show the slider section and at least the first 8-10 rows of the table visible, with the rest scrollable below
- All text in Simplified Chinese
- The slider is at 30° in the displayed state (showing "二分之一球" as the named angle)
- The ball diagram is a **front-view circle** (not a 3D sphere or top-down table view) — it represents looking at the object ball from the shooter's perspective
- Keep the mini ball diagrams in table rows only if they fit cleanly; prioritize table readability over decoration

## State

Default state: ContactPointTableView with the slider set to 30° (half-ball cut). The ball diagram shows the contact point at 50% offset from center. The "通称" shows "二分之一球" in brand green. The reference table shows all 13 rows with highlighted entries for 0° (全球), 30° (二分之一球), 48.6° (四分之三点), and 90° (极薄球). The page is scrollable.
