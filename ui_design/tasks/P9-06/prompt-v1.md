# Stitch Prompt — P9-06: BallFeelView (Light Mode)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode.

## Screen: BallFeelView — Ball Feel Tutorial Page (浅淡球感)

This is a pure educational content page, accessed by tapping "浅淡球感" (Ball Feel) from the Angle Training home page. It teaches the user about developing intuitive ball feel — the progression from analytical calculation to instinctive judgment when aiming. The page is a long ScrollView with 4 content sections: concept introduction, visual anchors showing what different cut angles look like from the cue ball's perspective, a recommended training path, and a comparison of 2D overhead vs 3D standing perspective. Sub-page navigation mode: back arrow + centered title, no bottom tab bar.

## Layout (top to bottom)

### 1. Navigation Bar (Sub-page Mode)

- Standard iOS navigation bar with back button
- Left: blue back arrow "chevron.left" + "角度训练" back label in system blue
- Center title: "浅淡球感" 17pt Semibold, color #000000
- Background: #F2F2F7 (seamless with page background)
- **No bottom 5-tab bar** — this is a pushed sub-page

### 2. Section 1 — "什么是球感" (What is Ball Feel)

Section title: "什么是球感" 18pt Bold, color #000000, 16pt left margin, 12pt bottom margin.

#### Concept card

- White (#FFFFFF) card, corner radius 12pt, 16pt internal padding
- At the top of the card: a centered decorative icon — SF Symbol "eye.circle.fill" rendered at 40pt in #1A6B3C (brand green), representing visual perception
- 12pt gap below icon
- Title text: "从计算到直觉" 17pt Semibold #000000, centered
- 8pt gap
- Body text (15pt Regular, color rgba(60,60,67,0.6), line height 22pt, left-aligned):
  - Paragraph 1: "刚开始学习瞄准时，我们需要计算切入角、偏移量、接触点位置。这是理性分析阶段。"
  - 8pt gap
  - Paragraph 2: "随着练习增多，这些计算会逐渐内化为直觉判断 —— 看到球形就能感知大致角度和厚薄。这就是球感。"
  - 8pt gap
  - Paragraph 3: "球感不是天赋，而是通过大量有意识的练习建立的视觉记忆。"

### 3. Section 2 — "从母球看过去" (View from the Cue Ball)

24pt gap from Section 1.

Section title: "从母球看过去" 18pt Bold, color #000000, 16pt left margin, 12pt bottom margin.

#### 4 mini-canvas illustrations — 2×2 grid

White (#FFFFFF) card, corner radius 12pt, 16pt padding. Inside the card, a 2×2 grid with 10pt gap between cells.

Each cell contains:
- A small square canvas (~160pt × 120pt, btTableFelt #1B6B3A background, corner radius 8pt):
  - Two circles viewed from the cue ball's approach direction
  - The cue ball (white #F5F5F5, ~24pt diameter) at the bottom of the canvas, partially cut off (showing it's "behind" the viewer)
  - The object ball (orange #F5A623, ~24pt diameter) ahead, with varying degrees of visual overlap/offset depending on the cut angle
  - A thin white dashed center line showing the aiming direction

**Cell layout (2 columns × 2 rows):**

| Cell | Label | Angle | Visual description |
|------|-------|-------|--------------------|
| Top-left | "全球" | 0° | Object ball directly ahead, fully overlapping with aiming line — the entire ball is visible, no lateral offset |
| Top-right | "半球" | 30° | Object ball offset to one side, roughly half the ball visible from the approach angle |
| Bottom-left | "3/4 球" | 48.6° | Object ball mostly offset, only about 1/4 overlap visible — a thinner contact |
| Bottom-right | "薄球" | 75°+ | Object ball barely edging into view, very thin sliver of contact |

Below each canvas within the cell:
- Bold label: "全球" / "半球" / "3/4 球" / "薄球" in 14pt Semibold #000000, centered
- Sub-label: angle value in 12pt Regular rgba(60,60,67,0.6), centered
  - "0°" / "30°" / "48.6°" / "75°+"

### 4. Section 3 — "训练建议" (Training Recommendations)

24pt gap from Section 2.

Section title: "训练建议" 18pt Bold, color #000000, 16pt left margin, 12pt bottom margin.

#### Training path card — 5 steps

White (#FFFFFF) card, corner radius 12pt, 16pt padding.

A vertical list of 5 training steps, each step as a row with:
- Left: a circled step number (28pt circle, #1A6B3C background, white number 14pt Bold centered)
- Right of number (12pt gap): step title (15pt Semibold #000000) + brief description below (13pt Regular rgba(60,60,67,0.6))
- 16pt vertical gap between steps
- A thin vertical green line (#1A6B3C, 2pt width) connecting the step circles (from circle 1 to circle 5), behind the circles

**Steps:**

1. **"理解原理"** — "学习切入角、偏移量和假想球法的基本概念"
2. **"几何练习"** — "通过纯几何角度预测训练，建立角度数感"
3. **"2D 球台"** — "在俯视球台上练习角度判断，熟悉球位关系"
4. **"3D 视角"** — "切换到站位视角，缩小训练与实战的差距"
5. **"实战应用"** — "将练习中建立的视觉记忆带到球台前"

### 5. Section 4 — "2D 到 3D 的视角差异" (2D to 3D Perspective Difference)

24pt gap from Section 3.

Section title: "2D 到 3D 的视角差异" 18pt Bold, color #000000, 16pt left margin, 12pt bottom margin.

#### Two comparison canvases — vertically stacked

White (#FFFFFF) card, corner radius 12pt, 16pt padding.

**Canvas 1 — 2D Overhead View (俯视角度):**
- Label above canvas: "俯视角度（2D）" 13pt Semibold #1A6B3C
- 6pt gap
- Canvas area (~160pt height, btTableFelt #1B6B3A background, corner radius 8pt):
  - Top-down view of a billiard table partial area
  - Cue ball (white #F5F5F5, ~22pt) at lower portion
  - Object ball (orange #F5A623, ~22pt) at upper portion, offset to the right
  - Pocket (black circle ~16pt) at upper-right
  - White dashed line from object ball to pocket (potting line)
  - Blue dashed line (#4A90D9) from cue ball toward object ball (shot line)
  - Cut angle arc (rgba(255,215,0,0.4)) at object ball
  - Small label "30°" in white 12pt Bold near the angle arc
- Below canvas: "从正上方看，球的位置关系一目了然" 13pt Regular rgba(60,60,67,0.6), 6pt top margin

**12pt gap between canvases**

**Canvas 2 — 3D Standing View (站位角度):**
- Label above canvas: "站位角度（3D）" 13pt Semibold #1A6B3C
- 6pt gap
- Canvas area (~160pt height, btTableFelt #1B6B3A background, corner radius 8pt):
  - Perspective/angled view simulating what the player sees standing at the table
  - The table surface recedes into the background (slight perspective foreshortening)
  - Cue ball (white, larger ~26pt, closer to viewer) at the bottom-center
  - Object ball (orange, smaller ~18pt, farther away) at upper area, offset
  - Pocket (black, small ~12pt) near the far edge
  - Same dashed lines but drawn with perspective (converging slightly)
  - The angle appears different from this viewpoint — visually demonstrating the distortion
- Below canvas: "站在球台前，透视让角度看起来不同" 13pt Regular rgba(60,60,67,0.6), 6pt top margin

#### Guidance text

- 12pt gap below the second canvas
- A small callout box within the same card: light green background (rgba(26,107,60,0.08)), corner radius 8pt, 12pt padding
- Icon: SF Symbol "cube.transparent" 16pt #1A6B3C, inline left
- Text (right of icon, 8pt gap): "使用 3D 模式练习，可以缩小训练与实战的视角差距" 14pt Regular #1A6B3C

### 6. Bottom Spacer

- 32pt bottom padding after the last section, ensuring comfortable scroll ending
- No bottom tab bar (sub-page)

## Design Tokens

- Primary color: #1A6B3C (billiard table green, for brand accents and step numbers)
- Page background: #F2F2F7
- Card background: #FFFFFF
- Canvas background (table felt): #1B6B3A
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Text on canvas: #FFFFFF
- Cue ball: #F5F5F5
- Object ball: #F5A623 (orange)
- Shot direction line: #4A90D9 (blue dashed)
- Potting direction line: white dashed
- Cut angle arc: rgba(255,215,0,0.4) (yellow semi-transparent)
- Contact point: #E53935 (red dot)
- Card corner radius: 12pt
- Canvas corner radius: 8pt (within cards)
- Card internal padding: 16pt
- Section gap: 24pt
- Card gap: 10pt
- Section title: 18pt Bold #000000
- Step number circle: 28pt, #1A6B3C background, white text
- Callout background: rgba(26,107,60,0.08)

## Reference Style

- This page has the exact same structure and visual style as the app's AimingPrincipleView (瞄准原理) page — both are educational sub-pages with card-based ScrollView layout, billiard table canvas diagrams, and explanatory text.
- Sub-page navigation: back arrow + parent title "角度训练" on left, current page title "浅淡球感" centered.
- The card-based ScrollView layout follows the established pattern: white cards with 12pt corner radius, 16pt padding, stacked vertically on a light gray #F2F2F7 background.
- The billiard table canvas diagrams use the same visual style as the app's AngleTestView: btTableFelt #1B6B3A green background, white/orange ball nodes, dashed annotation lines.
- This is a purely educational page — no buttons, no inputs, no interactive controls. Just illustrated content sections with canvas diagrams and explanatory text.
- The training path section (Section 3) uses a step-by-step vertical timeline layout with numbered circles and a connecting line, similar to a progress tracker.

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- iOS native feel: SF Pro font family, SF Symbols icons
- NO gradient fills — all solid colors (flat fill only)
- NO bottom tab bar (this is a pushed sub-page)
- NO interactive controls (no buttons, sliders, inputs) — pure educational content
- NO hero banners, promotional cards, or marketing content
- All text in Simplified Chinese
- Canvas diagrams are schematic illustrations — they don't need to be geometrically precise, just clear enough to convey the concept
- The billiard table canvas must use #1B6B3A (felt green), NOT the brand primary #1A6B3C
- Ball sizes should be proportional and clearly distinguishable (cue ball white, object ball orange)
- Each section flows naturally into the next via scrolling — no tab switching or pagination
- The page should feel cohesive — all 4 sections are part of one continuous educational flow
- This page should be visually consistent with the AimingPrincipleView (瞄准原理) page — same card style, same canvas style, same section title style, same navigation pattern
- The 2×2 grid in Section 2 should be balanced and each cell of similar dimensions
- The 3D perspective canvas in Section 4 should clearly look different from the 2D canvas — use size differences and slight convergence to suggest depth

## State

Default state: BallFeelView showing complete educational content in Light mode. All 4 sections fully visible (scrollable). The page is a static read-only tutorial — no interactive states, no loading states, no empty states. Single continuous ScrollView from Section 1 (什么是球感) through Section 4 (2D到3D视角差异).
