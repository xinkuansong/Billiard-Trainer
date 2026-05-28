# Stitch Prompt — P9-04 Frame 2: GeometricAngleQuizView — Result Feedback (Light)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode.

## Screen: GeometricAngleQuizView — Result Feedback State

Same page as the quiz, but now showing the result after the user submitted their answer. The canvas now shows both the random angle and a reference grid. A result feedback card appears between the canvas and the statistics panel, showing the user's answer, the actual angle, and the error. This is the "post-submission" state.

## Layout (top to bottom)

### 1. Navigation Bar

- Same as Frame 1: back arrow + "角度训练" + centered "角度预测"
- No bottom tab bar

### 2. Angle Display Canvas (with result annotations)

Same white card as Frame 1, but the canvas now has additional overlays:

- **All elements from Frame 1 remain:** green background, coordinate axes, origin dot, random angle line (~42°), angle arc
- **Additional — Reference angle grid (now visible):**
  - Dashed lines at 15°, 30°, 45°, 60°, 75° from the origin — light green color (rgba(255,255,255,0.2)), 1pt dashed stroke
  - Small angle labels at the end of each reference line: "15°" / "30°" / "45°" / "60°" / "75°" in white 10pt Regular
  - Concentric arc helper lines at 2-3 radii (rgba(255,255,255,0.1)), to help visualize angle sectors
- **Actual angle annotation:**
  - The actual angle value "42°" displayed near the angle line in a small yellow/gold pill badge — background rgba(255,215,0,0.9), text #000000 12pt Bold, corner radius 4pt
  - A yellow arc line (rgba(255,215,0,0.6), 2pt) tracing from X-axis to the angle line

### 3. Result Feedback Card

12pt gap below canvas card. White (#FFFFFF) card, corner radius 12pt, 16pt padding, 16pt horizontal margins.

- **Top row:**
  - Left: judgment chip — in this case, the user answered 45° and actual was 42°, error is 3°:
    - "精准" pill badge: background rgba(52,199,89,0.15), text #34C759 (btSuccess green), 13pt Semibold, corner radius 6pt, 8pt horizontal padding + 4pt vertical padding
  - Right: "测试编号 #3916" in 13pt Regular rgba(60,60,67,0.6)
- **Result text (8pt below top row):**
  - "你答了 **45°**，实际是 **42°**" in 17pt Regular #000000, with the numbers in Bold
- **Error display (4pt below):**
  - "误差 **3°**" in 20pt Bold #34C759 (green, because ≤3° is "精准")
- **Tip text (12pt below):**
  - "提示：注意 45° 参考线的位置，它将坐标系分为两个相等的区域。" in 15pt Regular rgba(60,60,67,0.6)

### 4. Statistics Panel (updated)

12pt gap below result card. Same 2×2 grid layout as Frame 1, but with updated values:

| Position | Label | Value |
|----------|-------|-------|
| Top-left | 练习次数 | 16 |
| Top-right | 正确次数 | 10 |
| Bottom-left | 正确率 | 62.5% |
| Bottom-right | 平均误差 | 4.0° |

Same styling as Frame 1.

### 5. Bottom Spacer

- 24pt bottom padding

## Design Tokens

Same as Frame 1, plus:
- Success color: #34C759 (btSuccess green, for ≤3° accuracy)
- Warning color: #FF9500 (btWarning amber, for 3-10° accuracy) — not used in this frame but part of the system
- Destructive color: #E53935 (for >10° accuracy) — not used in this frame
- Reference grid lines: rgba(255,255,255,0.2) on canvas
- Actual angle badge: rgba(255,215,0,0.9) background, #000000 text

## Reference Style

- The result feedback card mirrors the app's existing AngleTestView result state (P0-07): judgment chip + "你答了 X°，实际是 Y°" text + error display + educational tip. The layout pattern is identical but the content relates to geometric angles rather than billiard table cut angles.
- The reference grid on the canvas is unique to this page — it helps users calibrate their angle perception by showing standard reference angles (every 15°).
- The judgment system uses the same 3-tier threshold as P0-07: ≤3° = 精准 (green), 3-10° = 接近 (amber), >10° = 偏差大 (red).

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro)
- iOS native feel: SF Pro font family
- NO gradient fills — all solid colors
- NO bottom tab bar
- The reference grid should be subtle (low opacity) so it doesn't overwhelm the main angle line
- The judgment chip color must match the error magnitude (green for this example since error = 3°)
- The error number color matches the judgment (green #34C759 for "精准")
- All text in Simplified Chinese
- The canvas still shows the geometric coordinate system, NOT a billiard table

## State

Result feedback state: The user answered 45° for an actual angle of 42°, giving an error of 3° (classified as "精准"). The reference angle grid is now visible on the canvas. Statistics have been updated (+1 round, +1 correct). The feedback card shows the comparison and an educational tip. Light mode.
