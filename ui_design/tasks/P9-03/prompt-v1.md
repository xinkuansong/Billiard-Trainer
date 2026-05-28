# Stitch Prompt — P9-03: AngleDynamicView (Light Mode)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode.

## Screen: AngleDynamicView — Angle & Contact Point Dynamic Relationship

This is an interactive exploration page accessed from the Angle Training home. It shows how cut angle, contact point, and thick/thin ball classification relate to each other dynamically. The top portion features a **real billiard table photograph** (top-down view, portrait orientation — long axis vertical) with annotation overlays (balls, lines, angles drawn on top of the photo). The bottom portion shows a first-person overlap view and a data panel. A slider controls the angle. Sub-page navigation mode: back arrow + centered title, no bottom tab bar. This is a snapshot of one specific angle state (e.g., 35°) — all interactive elements are shown in their "current" state.

## Layout (top to bottom)

### 1. Navigation Bar (Sub-page Mode)

- Standard iOS navigation bar
- Left: blue back arrow "chevron.left" + "角度训练" back label in system blue
- Center title: "角度与打点" 17pt Semibold, color #000000
- Background: seamless with page background #F2F2F7
- **No bottom tab bar** — this is a pushed sub-page

### 2. Billiard Table Photo with Annotation Overlays

White (#FFFFFF) card, corner radius 12pt, no internal padding (image fills edge-to-edge within the card with rounded corners clipping). Full width minus 16pt page margins on each side.

#### Table Image

- **Use a real top-down photograph of a billiard table** (NOT a drawn/illustrated canvas). The table image shows realistic green felt, dark wood rails, leather pockets, and diamond markers — a photorealistic billiard table view from directly above.
- **Portrait orientation** — the table's long axis runs vertically (top to bottom on screen), short axis runs horizontally. This is the natural orientation for a phone held in portrait mode.
- **Standard billiard table proportions:** the playing area is 2:1 ratio (the long side is 2× the short side). In portrait mode on a 361pt wide card (393 - 32 margins), the table width is ~361pt and the table height is ~722pt — but capped to fit comfortably on screen, approximately **320pt height** (showing the full table scaled to fit, with some cropping or the table taking about 55-60% of screen height).
- The table image has: green baize/felt playing surface, dark brown/wood rail cushions, 6 pocket openings (4 corners + 2 middle), visible pocket nets or holes

#### Annotation Overlays (drawn on top of the photo)

All the following elements are rendered as overlays on top of the table photo:

- **Object ball (target):** orange #F5A623 circle, ~20pt diameter, positioned in the upper-center area of the table
- **Selected pocket:** the top-right corner pocket highlighted with a gold ring #D4941A (2pt stroke glow)
- **Other pockets:** subtle dashed circles (rgba(255,255,255,0.4) dashed stroke) indicating they are switchable
- **Cue ball (mother ball):** white #F5F5F5 circle, ~20pt diameter, positioned in the lower portion of the table. A faint semi-transparent glow ring around it (rgba(255,255,255,0.25), ~30pt) to hint it's draggable
- **Potting line:** white dashed line (1.5pt stroke, dash pattern 6-4) from object ball to selected pocket
- **Ghost ball position:** semi-transparent yellow circle (rgba(255,215,0,0.3)), same diameter as object ball (~20pt), positioned where the cue ball needs to aim — along the potting line extended behind the object ball
- **Aiming line:** blue dashed line (#4A90D9, 1.5pt stroke, dash pattern 6-4) from cue ball to ghost ball position
- **Cut angle arc:** yellow semi-transparent arc (rgba(255,215,0,0.4)) at the object ball, spanning from the potting line to the aiming line, with angle value "35°" in white 13pt Bold near the arc
- **Contact point:** red dot (#E53935), ~6pt diameter, on the object ball surface (the point where cue ball would contact)
- **Perpendicular helper line:** yellow solid line (1pt) passing through the object ball center, perpendicular to the aiming line direction

### 3. Angle Slider

Below the table canvas card, 12pt gap.

- Full width minus 32pt horizontal margins (16pt each side)
- Left label: "0°" in 13pt Regular rgba(60,60,67,0.6)
- Right label: "85°" in 13pt Regular rgba(60,60,67,0.6)
- Slider track: thin horizontal line, inactive portion in rgba(60,60,67,0.12), active portion (left of thumb) in brand green #1A6B3C
- Slider thumb: white circle with subtle shadow, standard iOS slider style
- Current position: at approximately 35° (about 41% from left)
- Above the slider (centered): current angle value "35°" in 20pt Bold #000000

### 4. First-Person Overlap View

12pt gap below slider. White (#FFFFFF) card, corner radius 12pt, 16pt padding.

Section label inside card: "第一人称视角" 13pt Semibold rgba(60,60,67,0.6), top-left within the card.

#### Overlap Canvas

- Centered within the card, approximately 160pt × 160pt square area
- Light gray background (#F5F5F5), corner radius 8pt
- **Two overlapping circles** (each ~80pt diameter):
  - Left circle: "假想球" — purple semi-transparent (rgba(128,0,128,0.3)), with thin purple outline (1pt)
  - Right circle: "目标球" — orange semi-transparent (rgba(245,166,35,0.3)), with thin orange outline (1pt)
  - The circles partially overlap — the overlap amount corresponds to the 35° angle
  - The offset distance between centers = `2sin(35°) × R ≈ 1.15R`
- Below circles, centered:
  - Formula: `d/R = 2sin(35°) = 1.15` in 14pt Semibold #000000
  - Classification label: "介于半球与3/4球之间" in a small pill badge — background rgba(26,107,60,0.12), text #1A6B3C 12pt Semibold, corner radius 4pt, 6pt horizontal padding

### 5. Data Panel

10pt gap below overlap view. White (#FFFFFF) card, corner radius 12pt, 16pt padding.

5 data items arranged in a horizontal row (equal width columns), separated by thin vertical dividers (1pt rgba(60,60,67,0.08)):

| Item | Value | Label |
|------|-------|-------|
| 切入角 | 35° | (large 22pt Bold #000000) |
| sin(α) | 0.574 | (16pt Semibold #000000) |
| 偏移 | 57.4% | (16pt Semibold #000000) |
| d/R | 1.15 | (16pt Semibold #000000) |
| 通称 | — | (16pt Regular rgba(60,60,67,0.6)) |

- Each item: value on top (larger), label below (13pt Regular rgba(60,60,67,0.6))
- "切入角" value "35°" is the largest number (22pt Bold), others are 16pt Semibold
- "通称" shows "—" because 35° doesn't correspond to a named thickness (named ones are 0°/30°/48.6°/90°)

### 6. Bottom Spacer

- 24pt bottom padding after the data panel
- No bottom tab bar (sub-page)

## Design Tokens

- Primary color: #1A6B3C (brand green, for slider active track, badge background)
- Page background: #F2F2F7
- Card background: #FFFFFF
- Table image: real billiard table photo (portrait orientation, photorealistic)
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Text on canvas: #FFFFFF
- Cue ball: #F5F5F5
- Object ball: #F5A623 (orange)
- Ghost ball: rgba(255,215,0,0.3) (semi-transparent yellow)
- Contact point: #E53935 (red dot)
- Aiming line: #4A90D9 (blue dashed)
- Potting line: white dashed
- Cut angle arc: rgba(255,215,0,0.4)
- Selected pocket ring: #D4941A (gold)
- Ghost ball overlap circle: rgba(128,0,128,0.3) (purple)
- Target ball overlap circle: rgba(245,166,35,0.3) (orange)
- Classification pill: background rgba(26,107,60,0.12), text #1A6B3C
- Card corner radius: 12pt
- Canvas corner radius: 8pt (overlap view)
- Card internal padding: 16pt
- Section gap: 12pt
- Slider track active: #1A6B3C
- Slider track inactive: rgba(60,60,67,0.12)

## Reference Style

- Unlike the app's existing AngleTestView (P0-07) which uses a drawn canvas, this page uses a **real billiard table photograph** as the base, with vector annotation overlays on top. This gives a more realistic, immersive feel — like looking down at an actual table.
- The table is shown in **portrait orientation** (long axis vertical) to maximize use of the phone's screen real estate and match the natural viewing angle when standing at a table.
- The annotation overlays (lines, arcs, balls) use the same visual language as P0-07's result view (dashed lines, angle arcs, ghost ball, contact point) but are rendered on top of a photo instead of a drawn canvas.
- The slider and data panel follow the style established in ContactPointTableView (P1-05): a clean slider with angle value display and organized numerical data.
- The first-person overlap view is a new element unique to this page — two semi-transparent circles showing how the ghost ball and target ball overlap from the cue ball's perspective.
- Think of it as a "billiard angle laboratory" — the user can explore different angles on a realistic table view and see all related measurements update in real-time. The static snapshot shows one specific state (35°).

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- iOS native feel: SF Pro font family, SF Symbols icons
- NO gradient fills on UI elements — all solid colors (flat fill only)
- NO bottom tab bar (this is a pushed sub-page)
- The billiard table MUST be in **portrait orientation** (long axis vertical, short axis horizontal) — NOT the landscape 2:1 used in P0-07. The table's playing area ratio is still 2:1 but rotated 90° so the long dimension runs top-to-bottom
- The table is a **photorealistic image** (top-down photograph of a real billiard table), NOT a drawn/illustrated canvas. It should look like the user is looking straight down at an actual table with real felt, wood rails, and leather pockets
- Annotation overlays (lines, arcs, dots, ball markers) are drawn as vector graphics on top of the photo
- All annotation lines (potting, aiming, perpendicular) must be clearly distinguishable by color and style
- The ghost ball must be semi-transparent yellow (NOT solid)
- The overlap view circles must be semi-transparent (NOT solid) to show the overlap area
- The data panel shows exactly 5 items in one horizontal row
- All text in Simplified Chinese
- The page layout is compact — table photo fills upper portion (~55-60% of screen), slider + overlap view + data panel fill lower portion, the page may scroll slightly
- Slider shows a specific angle state (35°) — this is a static snapshot of a dynamic interface
- The cue ball should have a subtle glow to hint at draggability
- The selected pocket has a gold ring (#D4941A), other pockets have faint dashed rings

## State

Static snapshot of AngleDynamicView at 35° cut angle. Light mode. The billiard table is shown as a photorealistic top-down image in portrait orientation (long axis vertical). The cue ball is positioned in the lower portion and the object ball in the upper-center, such that the cut angle is 35°. Vector annotation overlays show the potting line, aiming line, ghost ball, angle arc, and contact point on top of the photo. The slider is at the 35° position. The first-person overlap view shows the corresponding ball overlap for 35°. The data panel displays: 35° / sin=0.574 / offset=57.4% / d/R=1.15 / 通称=—. This is a read-only visual snapshot of an interactive state.
