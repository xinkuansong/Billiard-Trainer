# Stitch Prompt — P9-04 Frame 1: GeometricAngleQuizView — Answering State (Light)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode.

## Screen: GeometricAngleQuizView — Geometric Angle Prediction Quiz (Answering State)

This is a pure geometric angle prediction training page. Unlike the app's existing AngleTestView (which uses a billiard table), this page presents angles in an abstract geometric coordinate system — just lines and arcs on a green background. The user sees a random angle displayed as a line from the origin, estimates the angle, and submits their answer. This frame shows the "answering" state — the angle line is displayed, the user has entered a guess but hasn't submitted yet. Sub-page navigation mode, no bottom tab bar.

## Layout (top to bottom)

### 1. Navigation Bar (Sub-page Mode)

- Left: blue back arrow "chevron.left" + "角度训练" back label
- Center title: "角度预测" 17pt Semibold, color #000000
- No bottom tab bar

### 2. Angle Display Canvas

White (#FFFFFF) card, corner radius 12pt, 16pt horizontal margins. The canvas fills the card edge-to-edge (clipped by corner radius).

- Canvas dimensions: full card width (~361pt) × approximately 280pt height (roughly square, slightly wider)
- **Background:** btTableFelt green #1B6B3A (billiard-themed green, same as other angle canvases in the app)
- **Coordinate axes:**
  - X-axis: white solid line (2pt stroke) from origin (bottom-left corner of canvas, ~20pt inset from edges) extending rightward to near the right edge
  - Y-axis: white solid line (2pt stroke) from origin extending upward to near the top edge
  - Small "0°" label in white 12pt Regular near the X-axis end (right side)
  - Small "90°" label in white 12pt Regular near the Y-axis top
- **Random angle line:**
  - A thick white line (3pt stroke) from the origin, extending at an angle of approximately 42° (the random angle for this quiz)
  - Length: about 80% of the canvas diagonal
  - The line should be prominent and clearly visible
- **Angle arc:**
  - At the origin, a small semi-transparent white filled arc (rgba(255,255,255,0.25))
  - Arc radius ~40pt, sweeping from the X-axis to the angle line
  - Shows the angle being measured
- **Origin dot:**
  - Solid white circle, ~8pt diameter, at the origin point

### 3. Control Buttons Row

12pt gap below the canvas card. Horizontal row with 16pt horizontal margins, items spaced evenly.

- **"生成随机角度" button:** brand green #1A6B3C fill, white text 15pt Semibold, corner radius 8pt, ~140pt width, 44pt height. This is the primary action button.
- **"显示参考角度" toggle:** secondary style — rgba(60,60,67,0.08) background fill, #000000 text 14pt Regular, corner radius 8pt. Currently in "off" state (no reference grid shown).
- **"重置统计" button:** text-only style, 14pt Regular, color #E53935 (destructive red). No background fill.

### 4. Input Area

16pt gap below buttons. Centered layout.

- Prompt text: "请估算角度" 17pt Semibold #000000, centered
- 8pt gap
- **Number input field:** centered, ~200pt width, 56pt height
  - Border: 2pt solid brand green #1A6B3C, corner radius 12pt
  - Interior: white background
  - Display: "42°" in 32pt Bold #000000, centered (the user's current input)
  - "°" suffix is part of the displayed value
- Helper text below input: "范围: 0° - 90°" in 13pt Regular rgba(60,60,67,0.6), centered, 4pt gap
- 12pt gap
- **"确认" button:** full width (minus 32pt margins), 50pt height, brand green #1A6B3C fill, white text "确认" 17pt Semibold, corner radius 12pt

### 5. Statistics Panel

16pt gap below confirm button. White (#FFFFFF) card, corner radius 12pt, 16pt padding, 16pt horizontal margins.

4 statistics items in a 2×2 grid layout (2 columns, 2 rows), 12pt gap between cells:

| Position | Label | Value |
|----------|-------|-------|
| Top-left | 练习次数 | 15 |
| Top-right | 正确次数 | 9 |
| Bottom-left | 正确率 | 60% |
| Bottom-right | 平均误差 | 4.2° |

Each cell:
- Value: 22pt Bold #000000, centered
- Label: 13pt Regular rgba(60,60,67,0.6), centered, 2pt below value
- "正确次数" subtitle: "（误差≤3°）" in 11pt Regular rgba(60,60,67,0.4), below the label

### 6. Bottom Spacer

- 24pt bottom padding

## Design Tokens

- Primary color: #1A6B3C
- Page background: #F2F2F7
- Card background: #FFFFFF
- Canvas background: #1B6B3A (btTableFelt green)
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Destructive: #E53935
- Input border: #1A6B3C (2pt)
- Card corner radius: 12pt
- Button corner radius: 12pt (primary), 8pt (secondary)
- Padding: 16pt

## Reference Style

- The overall page layout (canvas → input → confirm button) mirrors the app's existing AngleTestView (P0-07): a visual display area at top, user input in the middle, action button below. But instead of a billiard table with balls, this page shows a pure geometric coordinate system.
- The statistics panel follows the 2×2 grid pattern from AngleHistoryView (P1-06): large numbers with small labels below.
- The input field style (green border, large centered number, degree suffix) is the same as P0-07's angle input.
- This is the "geometric warmup" version of angle training — abstract geometry before moving to billiard table scenarios.

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro)
- iOS native feel: SF Pro font family
- NO gradient fills — all solid colors
- NO bottom tab bar
- The canvas MUST show a geometric coordinate system (X and Y axes with lines), NOT a billiard table
- The canvas background is btTableFelt green #1B6B3A to maintain billiard app branding
- The angle line must be clearly visible (thick white line)
- All text in Simplified Chinese
- Statistics show realistic sample data (not zeros)
- The "生成随机角度" button is the primary control, "确认" submits the answer

## State

Answering state: A random angle (~42°) is displayed on the canvas. The user has entered "42" in the input field but hasn't submitted yet. Statistics show cumulative data from previous attempts (15 rounds, 60% accuracy). No result feedback is shown — this is the pre-submission state. Light mode.
