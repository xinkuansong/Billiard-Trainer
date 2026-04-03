# Stitch Prompt — P0-04: ActiveTrainingView（单项记录）

> 任务 ID: P0-04 | 版本: v1 | 日期: 2026-04-03
> 预检：依赖 A-07 (BTSetInputGrid) ✅ + A-08 (BTBilliardTable) ✅；P0-03 已通过确立全屏训练页框架（固定头部/工具栏）；画布 393px；全屏模式无标准导航栏/Tab 栏

---

## Stitch 提示词（开启新对话，粘贴以下内容）

Design the **Active Training — Single Drill Recording screen** for an iOS billiards training app called "QiuJi" (球迹). This is the **detailed drill view** within the same full-screen training modal — the user tapped on a specific drill from the overview list (P0-03) and now sees the set-by-set recording interface for that drill. iPhone screen (393 × 852pt), Light mode, scrollable content.

**CRITICAL — this is still the full-screen training modal:**
- Do NOT include the standard iOS large-title navigation bar.
- Do NOT include the 5-tab bottom tab bar.
- This screen shares the SAME fixed top timer bar and SAME bottom toolbar as the training overview.

**CRITICAL color rules:**
- Brand green is exactly `#1A6B3C`. Use this in your Tailwind config as `primary: "#1A6B3C"`. Do NOT use #005129 or any other green.
- Page background: `#F2F2F7`
- Card background: `#FFFFFF`
- Do NOT use gradients on buttons or solid color fills — all colored UI elements use solid flat fills only.

**Overall style:**
- iOS native mobile app design (SF Pro font family feel, SF Symbols icons)
- Clean, modern, professional sports-training aesthetic
- Canvas width: 393px (iPhone 15 Pro)

---

### Top Area: Fixed Timer Bar (identical to training overview)

- **Status bar**: standard iOS status bar (time, signal, battery indicators)
- **Timer row** (below status bar, 16pt horizontal padding, 12pt vertical padding, white frosted-glass background `rgba(255,255,255,0.9)` with backdrop blur):
  - **Left side**: large training timer `00:12:34` in **28pt Bold monospace** font (tabular figures), color `#1A6B3C` (brand green)
  - **Right side**: 4 icon buttons in a horizontal row, 8pt spacing:
    - Alarm/bell icon, Clock/history icon, Arrow up-down icon, Checkmark.circle icon
    - Each: 24pt size, `rgba(60,60,67,0.6)` color, 44pt tap area, no background circle
- **Info row** (4pt below timer):
  - **Left**: training name "基础直球训练" in **17pt Semibold** `#000000` + small pencil icon (14pt, `rgba(60,60,67,0.3)`)
  - **Right**: progress stats "8/15 组  2/4 项目" in **13pt Regular** `rgba(60,60,67,0.6)`

---

### Drill Header Section

A white `#FFFFFF` card area (16pt horizontal padding, 16pt vertical padding), sitting just below the fixed header. This identifies which drill the user is currently recording:

- **Left**: Billiard table thumbnail (56pt × 56pt, corner radius 8pt). Top-down schematic: green `#1B6B3A` felt, brown `#7B3F00` rail border, white cue ball dot at ~38% left / 70% top, orange `#F5A623` target ball dot at ~58% left / 32% top (diagonal layout). Faint white dashed line showing the ball path.
- **Center column** (12pt gap from thumbnail):
  - Drill name **"五分点直球"** in **20pt Bold**, color `#000000`
  - Below: "进球 36/90" in **15pt Regular**, color `rgba(60,60,67,0.6)`
- **Right**: gear/settings icon ⚙️ (22pt, `rgba(60,60,67,0.3)`, 44pt tap area)

---

### Notes Input Row

Below the drill header, a horizontal row (16pt horizontal padding, 12pt vertical padding):

- A text input placeholder **"点击输入备注…"** in **15pt Regular**, color `rgba(60,60,67,0.3)`, no visible border, just the placeholder text left-aligned
- A small notepad/pencil icon (16pt) at the right end, color `rgba(60,60,67,0.3)`

Thin separator line (`#E5E5EA`, 0.5pt) below this row.

---

### Settings Row + Mode Toggle Chips

Two rows inside a subtle section area (16pt horizontal padding):

**Row 1 — Rest settings** (8pt vertical padding):
- Left: alarm clock icon (16pt, `rgba(60,60,67,0.6)`) + text **"休息 60s"** in **15pt Regular** `rgba(60,60,67,0.6)`
- Right: a tappable text **"设置"** in **15pt Regular** `#1A6B3C` (brand green, acts as a text button)

**Row 2 — Mode toggle chips** (8pt below Row 1, 8pt gap between chips):
- Chip 1: **"✓ 每组计时"** — checkmark + label, selected state: `#1A6B3C` text, light green background `rgba(26,107,60,0.1)`, pill shape (corner radius 999pt, height 32pt, horizontal padding 12pt), **13pt Medium**
- Chip 2: **"✓ 显示成功率"** — same selected style as Chip 1

---

### Set Input Grid (BTSetInputGrid) — Core Interaction Area

This is the main content area in a white `#FFFFFF` card (corner radius 12pt, 16pt margin from screen edges, 16pt internal padding).

**Grid Header Row** (column labels, 12pt Regular, `rgba(60,60,67,0.3)`):
| 组 | 进球 | 总球 | 完成 | |
Each column is evenly distributed across the card width. The last column is narrow (for overflow menu ⋯).

**Grid Data Rows** — 5 rows, representing 5 training sets, 8pt vertical spacing between rows. Each row is 48pt tall:

**Row 1 — Warmup Set (completed):**
- Column 1 (set label): orange `#F5A623` rounded rectangle badge (24pt wide × 20pt tall, corner radius 4pt) with white text **"热"** (12pt Bold) — indicates warmup
- Column 2 (balls in): `#FFFFFF` rounded input box (44pt × 44pt, corner radius 8pt) showing **"8"** in **17pt Semibold** centered, on light green background `rgba(26,107,60,0.08)`
- Column 3 (total balls): similar box showing **"10"** in **17pt**, same light green background
- Column 4 (complete): green filled circle checkmark — `#1A6B3C` fill circle (28pt) with white ✓ icon
- Column 5: overflow ⋯ icon (16pt, `rgba(60,60,67,0.3)`)
- **Entire row background**: light green tint `rgba(26,107,60,0.06)`, corner radius 8pt

**Row 2 — Set 1 (completed):**
- Column 1: **"1"** in **17pt Bold** `#000000`
- Column 2: box showing **"15"**, light green background
- Column 3: box showing **"18"**, light green background
- Column 4: green filled circle checkmark (same as warmup)
- Column 5: overflow ⋯
- **Entire row background**: light green tint `rgba(26,107,60,0.06)`, corner radius 8pt

**Row 3 — Set 2 (current, active):**
- Column 1: **"2"** in **17pt Bold** `#1A6B3C` (brand green, highlighted)
- Column 2: input box **"13"** shown, white background with **2pt solid `#1A6B3C` border** (brand green border = current set indicator), corner radius 8pt
- Column 3: input box **"18"**, same brand green border
- Column 4: empty circle outline — `#D1D1D6` border (1.5pt), hollow, no fill
- Column 5: overflow ⋯
- **Row background**: white (no tint), the green border on inputs is the primary indicator of "current set"

**Row 4 — Set 3 (not started):**
- Column 1: **"3"** in **17pt Regular** `rgba(60,60,67,0.6)` (gray, inactive)
- Column 2: empty input box, `#D1D1D6` border (1pt), white fill, no text
- Column 3: empty input box showing **"18"** placeholder in `rgba(60,60,67,0.3)`
- Column 4: empty circle outline `#D1D1D6`
- Column 5: overflow ⋯

**Row 5 — Set 4 (not started):**
- Same style as Row 4, set number **"4"**

---

### Add Set Button

Below the grid card, centered, 12pt below:
- Text button **"+ 添加一组"** in **15pt Medium**, color `#1A6B3C` (brand green), no background, 44pt tap height

---

### Collapsible Billiard Table Section

Below the add-set button, 16pt spacing. A collapsible section:

**Section header row** (16pt horizontal padding):
- Left: **"球台示意"** in **15pt Semibold** `#000000`
- Right: chevron.down icon (14pt, `rgba(60,60,67,0.3)`) indicating it can collapse

**Table area** (expanded state shown): a billiard table illustration inside a white `#FFFFFF` card (corner radius 12pt, 16pt margin, 12pt internal padding):
- **Table dimensions**: approximately 350pt wide × 190pt tall
- **Felt surface**: `#1B6B3A` (dark green) rounded rectangle with 4pt corner radius
- **Rail border**: `#7B3F00` (brown), 6pt thick border around the felt
- **6 pocket holes**: small black `#1C1C1E` circles at 4 corners + 2 side midpoints (8pt diameter each)
- **Cue ball**: white circle `#F5F5F5` (14pt diameter) at ~38% from left, ~70% from top
- **Target ball**: orange circle `#F5A623` (14pt diameter) at ~58% from left, ~32% from top
- **Ball paths** (animation hint):
  - Cue ball path: semi-transparent white dashed line `rgba(255,255,255,0.5)` from cue ball toward target ball
  - Target ball path: semi-transparent orange dashed line `rgba(245,166,35,0.5)` from target ball toward a pocket
  - Contact point: small diamond marker at the intersection

Below the table, a brief text hint: **"五分点直球 — 母球定点击打目标球进袋"** in **13pt Regular** `rgba(60,60,67,0.6)`, centered.

---

### Bottom Toolbar (Fixed at bottom, identical to training overview)

Fixed bottom toolbar, 5 equally-spaced items. Background: white `#FFFFFF`, top border 0.5pt `#E5E5EA`, height ~56pt + safe area.

1. **最小化** — minimize icon, label 10pt, color `rgba(60,60,67,0.6)`
2. **更多** — ellipsis.circle icon, same gray
3. **添加** — **large 56pt circle button**, `#007AFF` (iOS system blue) solid fill, white `+` icon 28pt bold, rises ~12pt above toolbar. Label "添加" 10pt `#007AFF` below
4. **心得** — square.and.pencil icon, gray
5. **切换** — list.bullet icon, gray

---

### Design Tokens Summary

| Token | Value |
|-------|-------|
| Primary (brand green) | `#1A6B3C` — USE THIS EXACTLY |
| Primary muted (completed set bg) | `rgba(26,107,60,0.06)` |
| Primary light (chip/input tint) | `rgba(26,107,60,0.1)` |
| System blue (add button) | `#007AFF` |
| Warmup orange | `#F5A623` |
| Background | `#F2F2F7` |
| Card white | `#FFFFFF` |
| Text primary | `#000000` |
| Text secondary | `rgba(60,60,67,0.6)` |
| Text tertiary | `rgba(60,60,67,0.3)` |
| Outline/border | `#D1D1D6` |
| Separator | `#E5E5EA` |
| Active border (current set) | `#1A6B3C` (2pt solid) |
| Table felt green | `#1B6B3A` |
| Table cushion brown | `#7B3F00` |
| Cue ball | `#F5F5F5` |
| Target ball | `#F5A623` |
| Card radius | 12pt |
| Input box size | 44pt × 44pt |
| Thumbnail radius | 8pt |
| Padding | 16pt |
| Min touch target | 44pt |

---

### Constraints

- This is a DRILL DETAIL VIEW within the full-screen training modal — it shares the same top timer bar and bottom toolbar with the training overview
- The set input grid is the CORE of this screen — it should be the visual focal point, taking up the majority of screen real estate
- Completed sets (rows 1-2) should have a subtle green tint to clearly contrast with pending sets
- The current active set (row 3) must stand out with brand green borders on the input boxes
- The warmup set marker (orange "热" badge) must be clearly distinguishable from regular numbered sets
- Input boxes should feel tappable (44pt touch target) and the numbers inside should be easy to read (17pt)
- The collapsible billiard table section adds context but should NOT compete with the grid for attention — it sits below and can be collapsed
- Keep the same white card / gray background / brand green accent color scheme as the training overview (P0-03)
- All solid fills, NO gradients

---

### State

This screen shows the **single drill recording view for "五分点直球"** (Five-point straight shot). The training is in progress (12:34 elapsed). This drill has 5 sets total (1 warmup + 4 regular). The warmup set and Set 1 are completed (green background + checkmark), Set 2 is the current active set (green border, partially filled), Sets 3-4 are not yet started. Score: 36 out of 90 total balls. The billiard table section is expanded showing the drill diagram.

---

## 推荐附加参考截图

在 Stitch 中粘贴提示词后，建议同时附加以下参考截图：

1. `ref-screenshots/02-training-active/04-active-set-progress.png` — 主参考：单项记录的组数网格布局
2. `tasks/P0-03/stitch_task_p0_03_02/screen.png` — P0-03 已通过截图，固定头部和底部工具栏基准
3. `tasks/A-07/stitch_task_07_02/screen.png` — A-07 已通过截图，BTExerciseRow + BTSetInputGrid 组件样式基准

⚠️ 强烈建议至少附加参考截图 1 和 2，让 Stitch 理解单项记录界面的网格布局和训练页整体框架。

## Stitch 导出处理

1. Stitch 生成后会导出一个文件夹 `stitch_task_XX/`（含 `DESIGN.md` + `code.html` + `screen.png`）+ 同名 `.zip`
2. 将导出文件夹保存到 `tasks/P0-04/` 目录下
3. 完成后说 **"审核 P0-04"** 触发审核智能体
