# Stitch Prompt — P9-02: AimingPrincipleView (Light Mode)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode.

## Screen: AimingPrincipleView — Aiming Principle Tutorial Page

This is a pure educational content page, accessed by tapping "瞄准原理" (Aiming Principle) from the Angle Training home page. It teaches the user about cut angles, the ghost ball method, and thick/thin ball concepts through illustrated sections. The page is a long ScrollView with 4 content sections, each containing billiard table canvas diagrams and text explanations. No interactive controls — just read-only educational content. Sub-page navigation mode: back arrow + centered title, no bottom tab bar.

## Layout (top to bottom)

### 1. Navigation Bar (Sub-page Mode)

- Standard iOS navigation bar with back button
- Left: blue back arrow "chevron.left" + "角度训练" back label in system blue
- Center title: "瞄准原理" 17pt Semibold, color #000000
- Background: #F2F2F7 (seamless with page background)
- **No bottom 5-tab bar** — this is a pushed sub-page

### 2. Section 1 — "什么是切入角" (What is a Cut Angle)

Section title: "什么是切入角" 18pt Bold, color #000000, 16pt left margin, 12pt bottom margin.

#### Canvas — Top-view billiard table partial diagram

- Contained in a white (#FFFFFF) card, corner radius 12pt, 16pt internal padding
- Canvas area: full card width, approximately 200pt height
- Background: btTableFelt green #1B6B3A (billiard table felt color)
- Corner radius 8pt for the canvas area within the card
- **Elements on canvas:**
  - Cue ball (mother ball): white circle #F5F5F5, diameter ~28pt, positioned lower-left area
  - Object ball (target ball): orange circle #F5A623, diameter ~28pt, positioned upper-center area
  - Pocket: black circle ~20pt, positioned at upper-right corner of the table area
  - Potting direction line: white dashed line from object ball to pocket
  - Shot direction line: blue dashed line (#4A90D9) from cue ball toward the object ball
  - Cut angle α: yellow semi-transparent arc (rgba(255,215,0,0.4)) at the object ball where the two lines meet, with "α" label in white 14pt Bold near the arc
  - Small white text labels: "母球" near cue ball, "目标球" near object ball, "袋口" near pocket

#### Text explanation card

- Below the canvas, same white card continues (or a separate card with 8pt gap)
- Text content (17pt Regular, color #000000, line height 24pt):
  - "切入角是指母球击球方向与目标球进球方向之间的夹角。"
  - "取值范围：0°（直球）到 90°（极薄球）"
- 16pt internal padding

### 3. Section 2 — "核心公式" (Core Formula)

24pt gap from Section 1.

Section title: "核心公式" 18pt Bold, color #000000.

#### Formula display card

- White (#FFFFFF) card, corner radius 12pt, 16pt padding
- Formula text centered: `偏移量 = sin(α) × R`
- Formula font: monospace style (SF Mono or similar), 20pt Bold, color #1A6B3C (brand green)
- Below formula (8pt gap): explanation "其中 α 为切入角，R 为目标球半径" in 13pt Regular rgba(60,60,67,0.6)

#### 30° Example Canvas

- White card, corner radius 12pt, 16pt padding, 10pt gap from formula card
- Canvas area (btTableFelt #1B6B3A background, corner radius 8pt, ~150pt height):
  - Object ball: orange #F5A623 circle, center of canvas
  - Contact point: red dot (#E53935) on the object ball surface, offset 50% from center
  - Offset annotation: white dashed line from ball center to contact point, with "50%" label
  - `sin(30°) = 0.5` text in white 14pt Bold, positioned in canvas corner
- Below canvas: text "即接触点偏离球心半个球半径" in 15pt Regular #000000, 8pt top margin

### 4. Section 3 — "假想球法" (Ghost Ball Method)

24pt gap from Section 2.

Section title: "假想球法（Ghost Ball）" 18pt Bold, color #000000.

#### 3-step diagram — vertically stacked

Three canvas diagrams stacked vertically, each in a white card (corner radius 12pt, 16pt padding), 10pt gap between cards.

**Step 1 card:**
- Small step label: "步骤 1" 13pt Semibold, color #1A6B3C, top-left
- Canvas (~140pt height, btTableFelt #1B6B3A background, corner radius 8pt):
  - Pocket (black circle) at right edge
  - Object ball (orange #F5A623) center-right
  - White dashed line from pocket through object ball, extending beyond to point "A"
  - Point A labeled: small white circle + "A" label in white 13pt Bold
- Description below canvas: "从袋口经目标球连线延长，取 A 点" 15pt Regular, 8pt top margin

**Step 2 card:**
- Step label: "步骤 2" 13pt Semibold #1A6B3C
- Canvas (~140pt height):
  - Same object ball position
  - "正视" perspective annotation
  - Point B at the outermost edge of the object ball (from cue ball's viewing angle)
  - B labeled: small white circle + "B" label
- Description: "从母球方向正视，取目标球最边缘 B 点" 15pt Regular

**Step 3 card:**
- Step label: "步骤 3" 13pt Semibold #1A6B3C
- Canvas (~140pt height):
  - Object ball (orange)
  - Points A and B marked
  - Point C = mirror of B about A
  - Ghost ball: semi-transparent yellow circle (rgba(255,215,0,0.3)), same diameter as object ball, centered at point C, overlapping the object ball
  - C labeled: "C (击打点)" in white 13pt Bold
- Description: "以 A 为中心镜像 B，得 C 点 = 假想球击打位置" 15pt Regular

### 5. Section 4 — "厚薄球概念" (Thick/Thin Ball Concepts)

24pt gap from Section 3.

Section title: "厚薄球概念" 18pt Bold, color #000000.

#### 4 mini-canvas illustrations — 2×2 grid

White (#FFFFFF) card, corner radius 12pt, 16pt padding. Inside the card, a 2×2 grid with 10pt gap between cells.

Each cell contains:
- A small square canvas (~160pt × 120pt, btTableFelt #1B6B3A background, corner radius 8pt):
  - Two circles representing cue ball approach angle to object ball
  - Visual overlap indicating the "thickness" of contact
  - The degree of overlap varies per cell

**Cell layout (2 columns × 2 rows):**

| Cell | Label | Angle | Offset |
|------|-------|-------|--------|
| Top-left | "全球" | 0° | 0% |
| Top-right | "半球" | 30° | 50% |
| Bottom-left | "3/4 球" | 48.6° | 75% |
| Bottom-right | "极薄球" | 90° | 100% |

Below each canvas within the cell:
- Bold label: "全球" / "半球" / "3/4 球" / "极薄球" in 14pt Semibold #000000, centered
- Sub-label: angle + offset percentage in 12pt Regular rgba(60,60,67,0.6), centered
  - e.g., "0° · 偏移 0%" / "30° · 偏移 50%" / "48.6° · 偏移 75%" / "90° · 偏移 100%"

### 6. Bottom Spacer

- 32pt bottom padding after the last section, ensuring comfortable scroll ending
- No bottom tab bar (sub-page)

## Design Tokens

- Primary color: #1A6B3C (billiard table green, for brand accents and formula text)
- Page background: #F2F2F7
- Card background: #FFFFFF
- Canvas background (table felt): #1B6B3A
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Text on canvas: #FFFFFF
- Cue ball: #F5F5F5
- Object ball: #F5A623 (orange)
- Ghost ball: rgba(255,215,0,0.3) (semi-transparent yellow)
- Contact point: #E53935 (red dot)
- Shot direction line: #4A90D9 (blue dashed)
- Potting direction line: white dashed
- Cut angle arc: rgba(255,215,0,0.4) (yellow semi-transparent)
- Card corner radius: 12pt
- Canvas corner radius: 8pt (within cards)
- Card internal padding: 16pt
- Section gap: 24pt
- Card gap: 10pt
- Section title: 18pt Bold #000000
- Step label: 13pt Semibold #1A6B3C

## Reference Style

- This is a sub-page pushed from the Angle Training home, using the standard iOS back navigation pattern (back arrow + parent title "角度训练" on left, current page title "瞄准原理" centered).
- The card-based ScrollView layout follows the established pattern from the app's ContactPointTableView (white cards with 12pt corner radius, 16pt padding, stacked vertically on a light gray #F2F2F7 background).
- The billiard table canvas diagrams use the same visual style as the app's AngleTestView: btTableFelt #1B6B3A green background, white/orange ball nodes, dashed annotation lines.
- This is a purely educational page — no buttons, no inputs, no interactive elements. Just illustrated content sections with canvas diagrams and explanatory text.
- Think of it like a "textbook page" within a sports training app — clear diagrams, concise explanations, billiard-themed visuals.

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- iOS native feel: SF Pro font family, SF Symbols icons
- NO gradient fills — all solid colors (flat fill only)
- NO bottom tab bar (this is a pushed sub-page)
- NO interactive controls (no buttons, sliders, inputs) — pure educational content
- NO hero banners, promotional cards, or marketing content
- Minimum touch target: not applicable (read-only page)
- All text in Simplified Chinese
- Canvas diagrams are schematic illustrations — they don't need to be geometrically precise, just clear enough to convey the concept
- The billiard table canvas must use #1B6B3A (felt green), NOT the brand primary #1A6B3C
- Ball sizes should be proportional and clearly distinguishable (cue ball white, object ball orange, ghost ball semi-transparent yellow)
- Each section flows naturally into the next via scrolling — no tab switching or pagination
- The page should feel cohesive — all 4 sections are part of one continuous educational flow
- This page should be visually consistent with the app's existing AngleTestView (billiard table canvas style) and ContactPointTableView (card-based scroll layout)

## State

Default state: AimingPrincipleView showing complete educational content in Light mode. All 4 sections fully visible (scrollable). The page is a static read-only tutorial — no interactive states, no loading states, no empty states. Single continuous ScrollView from Section 1 (切入角) through Section 4 (厚薄球).
