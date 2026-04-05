# Stitch Prompt — P0-07: AngleTestView — 答题 + 结果反馈

> 任务 ID: P0-07 | 版本: v1 | 日期: 2026-04-04
> 预检：依赖 A-08 (BTBilliardTable) ✅；P0-01~P0-06 已通过确立 Phase B 页面框架；画布 393px
> 本任务包含两帧，需分别在两个 Stitch 对话中生成

---

## 帧 1 — AngleTestView 答题中状态

### Stitch 提示词（开启新对话，粘贴以下内容）

Design the **Angle Test Question Screen** for an iOS billiards training app called "QiuJi" (球迹). This is the core angle perception training feature — a quiz where users view a billiard table from above and estimate the cut angle between the cue ball and target ball. This screen shows the **"answering" state** — the user sees the table layout and needs to input their angle estimate. iPhone screen (393 × 852pt), Light mode.

**Page context:**
- This is a PUSHED view from the Angle Training home screen (Tab 3: "角度"). It has a back button at the top left.
- This is an IMMERSIVE quiz experience — do NOT show the 5-tab bottom tab bar. The user is focused on answering questions.
- The page background is `#F2F2F7`.

**CRITICAL color rules:**
- Brand green is exactly `#1A6B3C`. Use this in your Tailwind config as `primary: "#1A6B3C"`. Do NOT use #005129 or any other green.
- Billiard table felt: `#1B6B3A` (slightly different from brand green — this is the table surface)
- Table cushion (rail): `#7B3F00` (brown)
- Pockets: `#111111` (near-black circles)
- Cue ball: `#F5F5F5` (off-white)
- Target ball: `#F5A623` (orange)
- Do NOT use gradients on any element — all fills are solid flat color only.

**Overall style:**
- iOS native mobile app design (SF Pro font family feel, SF Symbols icons)
- Clean, focused quiz/test aesthetic — minimal distractions, the billiard table is the visual centerpiece
- Canvas width: 393px (iPhone 15 Pro)

---

#### Status Bar

Standard iOS status bar at top: time on left, signal/battery icons on right. Height: 54pt (including safe area notch).

---

#### Navigation Bar

Compact iOS navigation bar:
- **Left**: back chevron `‹` + text **"角度训练"** in `#1A6B3C` (brand green), 17pt Regular
- **Center title**: **"角度测试"** in **17pt Semibold**, color `#000000`
- **Right**: a small info/help icon `questionmark.circle` in `rgba(60,60,67,0.45)`, 22pt — for explaining the quiz rules
- Bar background: `#FFFFFF` with subtle bottom border `rgba(60,60,67,0.15)`

---

#### Progress Indicator (below navigation bar, 16pt horizontal margin, 12pt top margin)

A horizontal progress section:

- **Top row**: Left text **"第 8 题"** in **15pt Semibold**, color `#000000` + right text **"共 20 题"** in **15pt Regular**, color `rgba(60,60,67,0.6)`
- **Progress bar** (4pt below text): full width (361pt), height **6pt**, corner radius **3pt**
  - Track: `rgba(60,60,67,0.1)` (light gray)
  - Fill: `#1A6B3C` (brand green), width = 40% (8/20 questions completed)
  - Smooth rounded ends on the fill

---

#### Billiard Table Canvas (the visual centerpiece)

16pt horizontal margin, 16pt top margin below progress bar. This is the main interactive area.

**Table container**: A white `#FFFFFF` card, corner radius **16pt**, padding **12pt**, subtle shadow `0 2pt 8pt rgba(0,0,0,0.06)`.

**Inside the card — the billiard table** (full card width minus padding, approximately 337 × 180pt, aspect ratio roughly 1.88:1 like a real billiard table):

- **Table surface**: rounded rectangle, background `#1B6B3A` (table felt green), corner radius **8pt** (inner corners of the playing area)
- **Cushion rail border**: a `#7B3F00` (brown) border around the table surface, **8pt** wide, corner radius **12pt** on outer edge — this represents the wooden rail
- **6 pockets**: dark circles `#111111`, diameter **14pt**, positioned at the 4 corners and 2 mid-side positions of the table:
  - Top-left corner, top-right corner, bottom-left corner, bottom-right corner
  - Middle of top rail, middle of bottom rail
  - Each pocket should slightly indent into the rail (half-circle cut into the cushion)

**Balls on the table:**
- **Target ball** (orange `#F5A623`): diameter **18pt**, positioned at approximately 55% from left, 30% from top — slightly right-of-center and toward the top. Draw a subtle highlight (small white circle `rgba(255,255,255,0.4)` at upper-left of ball for 3D feel).
- **Cue ball** (white `#F5F5F5`): diameter **18pt**, positioned at approximately 30% from left, 72% from top — lower-left area. Same subtle highlight.

**Pocket direction indicator**: A small arrow or triangular marker near one of the corner pockets (top-right corner pocket), colored `#C62828` (red), pointing toward the pocket opening. This shows which pocket the target ball should be aimed at. The arrow is approximately 12pt, positioned just outside the pocket.

**Angle arc indicator** (subtle visual hint): A thin dashed arc line from the cue ball toward the target ball's direction, in `rgba(26,107,60,0.3)` (faint green), suggesting the cut angle line the user needs to estimate. This is optional — just a subtle visual cue, not the answer.

---

#### Input Area (below the table card)

16pt top margin below the table card, 16pt horizontal margin.

**Prompt text**: **"请估算切入角度"** in **17pt Semibold**, color `#000000`, center-aligned, 12pt bottom margin.

**Angle input field**: A large, prominent input area centered on screen:
- Container: white `#FFFFFF` rounded rectangle, width **180pt**, height **64pt**, corner radius **16pt**, border **2pt** solid `#1A6B3C` (brand green, indicating active input focus), shadow `0 2pt 8pt rgba(26,107,60,0.12)`
- Inside the field:
  - Large number **"35"** in **36pt Bold** tabular/monospace style, color `#000000`, horizontally centered
  - Degree symbol **"°"** in **24pt Regular**, color `rgba(60,60,67,0.6)`, immediately after the number, baseline-aligned

**Helper text**: 8pt below the input field, center-aligned:
- **"范围: 5° - 85°"** in **13pt Regular**, color `rgba(60,60,67,0.45)`

**Confirm button**: 20pt below helper text, centered:
- Width: **200pt**, height: **50pt**, corner radius **12pt**
- Background: `#1A6B3C` (brand green, solid fill)
- Text: **"确认"** in **17pt Semibold**, color `#FFFFFF`
- Centered both horizontally and vertically

---

#### Design Tokens Summary

| Token | Value |
|-------|-------|
| Primary (brand green) | `#1A6B3C` — USE THIS EXACTLY |
| Table felt | `#1B6B3A` |
| Table cushion (rail) | `#7B3F00` |
| Table pockets | `#111111` |
| Cue ball | `#F5F5F5` |
| Target ball | `#F5A623` |
| Pocket indicator (red) | `#C62828` |
| Background | `#F2F2F7` |
| Card white | `#FFFFFF` |
| Card corner radius | 16pt |
| Button corner radius | 12pt |
| Button height | 50pt |
| Progress bar height | 6pt |
| Progress fill | `#1A6B3C` |
| Text primary | `#000000` |
| Text secondary | `rgba(60,60,67,0.6)` |
| Text tertiary | `rgba(60,60,67,0.45)` |
| Min touch target | 44pt |

---

#### Constraints

- The billiard table is the VISUAL CENTERPIECE — it should take up significant vertical space (about 40% of the content area) and feel like a realistic overhead view of a pool table
- The table MUST have visible brown cushion rails, 6 black pockets, an orange target ball, and a white cue ball — these are critical for the user to estimate the angle
- The red arrow indicating the target pocket is important — it tells the user WHICH pocket they're aiming for
- The input field should feel large and easy to tap — this is used during practice at a billiard hall (possibly with one hand)
- No bottom tab bar — this is an immersive quiz experience
- All solid fills, NO gradients
- The overall feel should be focused and quiz-like — similar to a flashcard or test app but with billiards aesthetics

#### State

This shows **question 8 of 20** in an angle test session. The user sees a billiard table with the cue ball in the lower-left area and the target ball in the upper-right area. A red arrow marks the top-right corner pocket as the target. The user has typed "35" as their angle estimate and is about to tap "确认" to submit their answer. The progress bar shows 40% completion (8/20).

---
---

## 帧 2 — AngleTestView 结果反馈状态

### Stitch 提示词（开启新对话，粘贴以下内容）

Design the **Angle Test Result Feedback Screen** for an iOS billiards training app called "QiuJi" (球迹). This is the same angle test screen but now showing the **result after the user submitted their answer**. The billiard table now displays the correct shot line, contact point, and error feedback. iPhone screen (393 × 852pt), Light mode.

**Page context:**
- Same pushed view as the question screen — back button at top, no bottom tab bar (immersive quiz)
- The page background is `#F2F2F7`
- The user just submitted "35°" as their answer, but the correct angle was "30°" — so the error is 5° (INCORRECT, since tolerance is ±3°)

**CRITICAL color rules:**
- Brand green is exactly `#1A6B3C`. Use this in your Tailwind config as `primary: "#1A6B3C"`. Do NOT use #005129 or any other green.
- Billiard table felt: `#1B6B3A`
- Table cushion: `#7B3F00`
- Pockets: `#111111`
- Cue ball: `#F5F5F5`
- Target ball: `#F5A623`
- Correct result color: `#1A6B3C` (brand green)
- Incorrect result color: `#C62828` (red)
- Do NOT use gradients — all fills are solid flat color only.

**Overall style:**
- iOS native mobile app design (SF Pro font family feel, SF Symbols icons)
- The result feedback should feel clear and educational — showing the user what the correct answer was
- Canvas width: 393px (iPhone 15 Pro)

---

#### Status Bar + Navigation Bar

Identical to Frame 1:
- Status bar: 54pt
- Nav bar: back `‹ 角度训练` in `#1A6B3C` + center title "角度测试" 17pt Semibold + right help icon

---

#### Progress Indicator

Same as Frame 1 — **question 8 of 20**, progress bar at 40% `#1A6B3C` fill.

---

#### Billiard Table Canvas (now with result overlay)

Same table card container (white `#FFFFFF`, 16pt corner radius, 12pt padding, shadow).

**The table is identical to Frame 1** (same felt `#1B6B3A`, cushion `#7B3F00`, 6 pockets, same ball positions), BUT now with additional overlay elements showing the correct answer:

**Shot line (cue ball → target ball)**: A solid line from the center of the cue ball to the contact point on the target ball:
- Line color: `rgba(255,255,255,0.85)` (bright white, semi-transparent)
- Line width: **2pt**
- This line represents the direction the cue ball would travel

**Target ball → pocket line**: A solid line from the center of the target ball to the target pocket (top-right corner):
- Line color: `rgba(245,166,35,0.7)` (orange, matching the target ball)
- Line width: **2pt**
- This line represents the path the target ball takes to the pocket after being hit

**Contact point marker**: A small filled circle on the target ball's surface where the cue ball would make contact:
- Diameter: **6pt**
- Color: `#FFFFFF` (white) with a `#C62828` (red) border ring 2pt — to highlight the exact contact point
- Positioned on the side of the target ball facing the cue ball

**Ghost ball** (optional helper visualization): A dashed circle outline at the contact point position, showing where the cue ball would be at the moment of contact:
- Diameter: **18pt** (same as cue ball)
- Stroke: `rgba(245,245,245,0.5)` (semi-transparent white), 1.5pt dashed line
- Positioned so it touches the target ball at the contact point

**Angle arc**: A small arc drawn near the contact point, showing the actual 30° cut angle:
- Arc color: `#FFFFFF` at 70% opacity
- Arc radius: ~24pt, spanning from the pocket direction to the shot line
- A small label **"30°"** in **11pt Bold**, color `#FFFFFF`, positioned near the arc

---

#### Result Feedback Card (replaces the input area)

Below the table card, 16pt top margin, 16pt horizontal margin.

A single white `#FFFFFF` card, corner radius **16pt**, padding **20pt**, subtle shadow `0 2pt 8pt rgba(0,0,0,0.06)`. This card contains the result:

**Result badge** (centered at top of card):
- A rounded pill badge: background `#C62828` (red, because incorrect), height **32pt**, horizontal padding **16pt**, corner radius **999pt** (pill)
- Inside: SF Symbol `xmark.circle.fill` 16pt white + text **"不正确"** in **15pt Semibold**, color `#FFFFFF`, 6pt gap between icon and text
- (If the answer were correct, this would be `#1A6B3C` green with `checkmark.circle.fill` + "正确!")

**Error breakdown** (12pt below badge, center-aligned):
- Line 1: **"你答了 35°，实际是 30°"** in **17pt Regular**, color `#000000`
- Line 2: **"误差 5°"** in **22pt Bold**, color `#C62828` (red, emphasizing the error)
- (If correct: "误差 0°" or "误差 2°" in `#1A6B3C` green)

**Judgment criteria hint** (8pt below error text):
- **"容差 ±3° 内为正确"** in **13pt Regular**, color `rgba(60,60,67,0.45)`, center-aligned

---

#### Running Score Bar (below result card)

12pt top margin, 16pt horizontal margin. A compact horizontal stats row on a white `#FFFFFF` card, corner radius **12pt**, height **48pt**, padding **16pt** horizontal:

- Left: **"当前正确率"** in **13pt Regular**, color `rgba(60,60,67,0.6)`
- Right: **"5/8"** in **17pt Bold**, color `#1A6B3C` + text **"62.5%"** in **15pt Regular**, color `rgba(60,60,67,0.6)`, 8pt gap between fraction and percentage

---

#### Next Question Button (below score bar)

20pt top margin, centered:
- Width: **361pt** (full width minus margins), height: **50pt**, corner radius **12pt**
- Background: `#1A6B3C` (brand green, solid fill)
- Text: **"下一题 →"** in **17pt Semibold**, color `#FFFFFF`

---

#### Design Tokens Summary

| Token | Value |
|-------|-------|
| Primary (brand green) | `#1A6B3C` — USE THIS EXACTLY |
| Incorrect/error red | `#C62828` |
| Table felt | `#1B6B3A` |
| Table cushion | `#7B3F00` |
| Pockets | `#111111` |
| Cue ball | `#F5F5F5` |
| Target ball | `#F5A623` |
| Shot line (cue→target) | `rgba(255,255,255,0.85)`, 2pt |
| Target path line | `rgba(245,166,35,0.7)`, 2pt |
| Ghost ball stroke | `rgba(245,245,245,0.5)`, 1.5pt dashed |
| Contact point | `#FFFFFF` fill, `#C62828` border |
| Background | `#F2F2F7` |
| Card white | `#FFFFFF` |
| Card corner radius | 16pt |
| Button corner radius | 12pt |
| Button height | 50pt |
| Correct badge bg | `#1A6B3C` |
| Incorrect badge bg | `#C62828` |
| Text primary | `#000000` |
| Text secondary | `rgba(60,60,67,0.6)` |
| Text tertiary | `rgba(60,60,67,0.45)` |
| Min touch target | 44pt |

---

#### Constraints

- The billiard table MUST look identical to Frame 1 (same balls, same positions) — but NOW with the shot line, contact point, and ghost ball OVERLAID on top
- The shot line from cue ball to target ball and the line from target ball to pocket must be clearly visible against the green felt — use white and orange semi-transparent lines
- The result badge (red "不正确" or green "正确!") should be the first thing the user notices below the table
- The error text "误差 5°" should be prominently displayed — this is the key learning feedback
- The "下一题" button should be easy to reach with one thumb (bottom of screen)
- No bottom tab bar — immersive quiz continues
- All solid fills, NO gradients
- The angle arc label "30°" on the table should be small but legible — it's educational

#### State

This shows the **result feedback for question 8 of 20**. The user answered **35°** but the correct cut angle was **30°**, giving an error of **5°** — which exceeds the ±3° tolerance, so it's marked INCORRECT (red). The table now shows the correct shot line (white line from cue ball to contact point on target ball), the target ball's path to the pocket (orange line), the contact point (white dot with red ring), and a ghost ball outline. The running score shows 5 correct out of 8 questions (62.5%). The user can tap "下一题" to continue.

---

## 推荐附加参考截图

### 帧 1（答题中）
1. `tasks/P0-04/stitch_task_p0_04_04/screen.png` — P0-04 已通过截图，底部「球台示意」区域展示了完整球台：绿色台面 + 棕色库边 + 白色母球 + 橙色目标球 + 路径虚线。这是球台视觉风格的最佳参考。

### 帧 2（结果反馈）
1. `tasks/P0-04/stitch_task_p0_04_04/screen.png` — 同上，重点参考球台的配色、球位布局和路径线表现

> 注意：P0-07 是球迹独创功能，无直接参考截图。P0-04 底部的球台示意图是最接近的视觉参考（A-08 截图中球台部分被截断，不适合作参考）。建议附加以帮助 Stitch 理解球台的配色和布局风格。

---

## Stitch 导出处理

1. 帧 1（答题中）：将 Stitch 导出文件夹保存到 `tasks/P0-07/` 目录下
2. 帧 2（结果反馈）：将 Stitch 导出文件夹保存到 `tasks/P0-07/` 目录下
3. 两帧都完成后说 **"审核 P0-07"** 触发审核智能体

---

## 一致性声明

> 此任务的两帧页面应与 P0-01~P0-06 保持一致的视觉风格：品牌绿 `#1A6B3C`、卡片白 `#FFFFFF`、页面背景 `#F2F2F7`、按钮圆角 12pt、卡片圆角 16pt、iOS 原生导航栏风格。球台视觉使用 A-08 确立的专用色 Token（台面 `#1B6B3A`、库边 `#7B3F00`、母球 `#F5F5F5`、目标球 `#F5A623`）。
