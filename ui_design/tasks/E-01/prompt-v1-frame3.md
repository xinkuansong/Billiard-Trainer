# Stitch Prompt — E-01 帧3: ActiveTrainingView 单项记录 Dark Mode

> 任务 ID: E-01 | 帧: 3/5 | 版本: v1 | 日期: 2026-04-05
> Light Mode 基准: P0-04 v4 (`tasks/P0-04/stitch_task_p0_04_04/screen.png`)
> 全屏模态（fullScreenCover），与帧2 共享计时器头部 + 底部工具栏框架
> P0-04 决策 2: 热身行橙色「热」标记 | 决策 5: 添加按钮品牌绿
> 附注: BTRestTimer 弹层（P0-05）为可选追加帧，见文末说明

---

## Stitch 提示词（开启新对话，粘贴以下内容）

Design the **Dark Mode variant** of the Active Training — Single Drill Recording screen for an iOS billiards training app called "QiuJi" (球迹). This is the **detailed drill view** within the full-screen training modal — showing a set-by-set input grid for recording billiard practice. iPhone screen (393 × 852pt), **Dark mode**, scrollable content.

**CRITICAL: This is a color-mapping exercise. The layout, spacing, element positions, and content must be IDENTICAL to the attached light mode screenshot. Only colors change.**

**CRITICAL — this is still the full-screen training modal:**
- Do NOT include the standard iOS large-title navigation bar.
- Do NOT include the 5-tab bottom tab bar.
- This screen shares the SAME fixed top timer bar and SAME bottom toolbar as the training overview.

**CRITICAL color rules (Dark Mode):**
- Brand green is `#25A25A` (brighter than light mode). Use this in your Tailwind config as `primary: "#25A25A"`. Do NOT use #1A6B3C or #005129.
- Page background: `#000000` (pure black, OLED)
- Card/container background: `#1C1C1E`
- Text primary: `#FFFFFF`
- Text secondary: `rgba(235,235,240,0.6)`
- Text tertiary/placeholder: `rgba(235,235,240,0.3)`
- Separator/border: `#38383A`
- Do NOT use gradients — all colored UI elements use solid flat fills only.
- Do NOT use drop shadows — use background color contrast only.

**Overall style:**
- iOS native mobile app design (SF Pro font family feel, SF Symbols icons)
- Clean, focused, task-oriented drill recording interface — now in Dark Mode
- White status bar text (light content style)
- Canvas width: 393px (iPhone 15 Pro)

---

### Top Area: Fixed Timer Bar (Dark Mode)

- **Status bar**: iOS status bar with **white text** (light content style)
- **Timer row** (dark frosted-glass background `rgba(0,0,0,0.9)` + backdrop-blur, 16pt horizontal padding, 12pt vertical padding):
  - **Left**: `00:12:34` in **28pt Bold monospace**, color `#25A25A` (brand green Dark — most prominent element)
  - **Right**: 4 icon buttons, 8pt spacing, each 24pt, color `rgba(235,235,240,0.6)`, 44pt tap area
- **Info row** (4pt below timer):
  - **Left**: "基础直球训练" in **17pt Semibold** `#FFFFFF` + pencil icon (14pt, `rgba(235,235,240,0.3)`)
  - **Right**: "8/15 组  2/4 项目" in **13pt Regular** `rgba(235,235,240,0.6)`

---

### Drill Header Section

Background `#1C1C1E` card area (16pt padding), below fixed header:

- **Left**: Billiard table thumbnail (56pt × 56pt, corner radius 8pt). Dark Mode table: `#144D2A` felt (darker green), `#5C2E00` rail border (darker brown), white `#F5F5F5` cue ball, orange `#F5A623` target ball, faint white dashed path line.
- **Center** (12pt gap):
  - **"五分点直球"** in **20pt Bold** `#FFFFFF`
  - "进球 36/90" in **15pt Regular** `rgba(235,235,240,0.6)`
- **Right**: gear icon ⚙️ 22pt, `rgba(235,235,240,0.3)`, 44pt tap

---

### Notes Input Row

16pt horizontal padding, 12pt vertical, on `#000000` background:
- Placeholder **"点击输入备注…"** in **15pt Regular** `rgba(235,235,240,0.3)`
- Notepad icon (16pt) `rgba(235,235,240,0.3)` at right
- Separator `#38383A` (0.5pt) below

---

### Settings Row + Mode Toggle Chips

16pt horizontal padding:

**Row 1 — Rest settings** (8pt vertical padding):
- Left: alarm icon (16pt, `rgba(235,235,240,0.6)`) + **"休息 60s"** in **15pt Regular** `rgba(235,235,240,0.6)`
- Right: **"设置"** in **15pt Regular** `#25A25A` (brand green Dark)

**Row 2 — Mode toggle chips** (8pt below, 8pt gap):
- **"✓ 每组计时"** — selected: `#25A25A` text, dark green tint background `rgba(37,162,90,0.15)`, pill shape 999pt radius, height 32pt, 12pt horizontal padding, **13pt Medium**
- **"✓ 显示成功率"** — same selected style

---

### Set Input Grid (BTSetInputGrid) — Core Interaction Area

White card in Light → `#1C1C1E` card in Dark. Corner radius 12pt, 16pt margin, 16pt internal padding, NO shadow.

**Grid Header Row** (column labels, 12pt Regular, `rgba(235,235,240,0.3)`):
| 组 | 进球 | 总球 | 完成 | |

**Grid Data Rows** — 5 rows, 8pt vertical spacing, each 48pt tall:

**Row 1 — Warmup Set (completed):**
- Col 1: orange `#F5A623` badge (24×20pt, radius 4pt) with white **"热"** (12pt Bold)
- Col 2: input box (44×44pt, radius 8pt) showing **"8"** in **17pt Semibold**, dark green tint background `rgba(37,162,90,0.12)`, text `#FFFFFF`
- Col 3: box showing **"10"**, same dark green tint
- Col 4: green filled circle checkmark — `#25A25A` fill (28pt) with white ✓
- Col 5: overflow ⋯ (16pt, `rgba(235,235,240,0.3)`)
- **Row background**: dark green tint `rgba(37,162,90,0.10)`, radius 8pt

**Row 2 — Set 1 (completed):**
- Col 1: **"1"** in **17pt Bold** `#FFFFFF`
- Col 2-3: boxes showing **"15"** / **"18"**, dark green tint
- Col 4: green checkmark (same as warmup)
- Col 5: overflow ⋯
- **Row background**: dark green tint `rgba(37,162,90,0.10)`

**Row 3 — Set 2 (current, active):**
- Col 1: **"2"** in **17pt Bold** `#25A25A` (brand green, highlighted)
- Col 2: input box **"13"**, `#2C2C2E` background with **2pt solid `#25A25A` border** (current set indicator), text `#FFFFFF`
- Col 3: input box **"18"**, same green border
- Col 4: empty circle — `#3A3A3C` border (1.5pt), hollow
- Col 5: overflow ⋯
- **Row background**: `#1C1C1E` (no tint, green borders are the indicator)

**Row 4 — Set 3 (not started):**
- Col 1: **"3"** in **17pt Regular** `rgba(235,235,240,0.6)` (gray)
- Col 2: empty input box, `#3A3A3C` border (1pt), `#2C2C2E` fill
- Col 3: box showing **"18"** placeholder in `rgba(235,235,240,0.3)`, same dark fill
- Col 4: empty circle `#3A3A3C`
- Col 5: overflow ⋯

**Row 5 — Set 4 (not started):**
- Same style as Row 4, set number **"4"**

---

### Add Set Button

Below grid card, centered, 12pt gap:
- **"+ 添加一组"** in **15pt Medium** `#25A25A`, no background, 44pt tap height

---

### Collapsible Billiard Table Section

16pt below add-set button:

**Header row**: "球台示意" in **15pt Semibold** `#FFFFFF` + chevron.down (14pt, `rgba(235,235,240,0.3)`)

**Table area** (expanded): `#1C1C1E` card (radius 12pt, 16pt margin, 12pt padding):
- **Table**: ~350pt × 190pt
- Felt surface: `#144D2A` (Dark Mode darker green), 4pt radius
- Rail border: `#5C2E00` (Dark Mode darker brown), 6pt thick
- 6 pockets: `#000000` circles at corners + midpoints (8pt diameter — blends with page bg, use subtle `#2C2C2E` ring if needed)
- Cue ball: `#F5F5F5` (14pt) at ~38% left, ~70% top
- Target ball: `#F5A623` (14pt) at ~58% left, ~32% top
- Cue path: `rgba(255,255,255,0.5)` dashed line
- Target path: `rgba(245,166,35,0.5)` dashed line
- Contact point: small diamond marker

Below table: **"五分点直球 — 母球定点击打目标球进袋"** in **13pt Regular** `rgba(235,235,240,0.6)`, centered.

---

### Bottom Toolbar (Fixed, Dark Mode)

Background `#1C1C1E`, top border 0.5pt `#38383A`, height ~56pt + safe area:

1. **最小化** — icon + label 10pt, `rgba(235,235,240,0.6)`
2. **更多** — ellipsis.circle, same gray
3. **添加** — **56pt circle**, `#25A25A` solid fill (brand green Dark), white `+` 28pt bold, rises ~12pt. Label "添加" 10pt `#25A25A`
4. **心得** — icon + label, gray
5. **切换** — icon + label, gray

---

### Design Tokens Summary (Dark Mode)

| Token | Dark Mode Value |
|-------|----------------|
| Primary (brand green) | `#25A25A` — USE THIS EXACTLY |
| Primary muted (completed row) | `rgba(37,162,90,0.10)` |
| Primary tint (chip/input) | `rgba(37,162,90,0.15)` |
| Warmup orange | `#F5A623` |
| Background (page) | `#000000` |
| Card / container | `#1C1C1E` |
| Tertiary bg (inputs) | `#2C2C2E` |
| Quaternary (borders) | `#3A3A3C` |
| Text primary | `#FFFFFF` |
| Text secondary | `rgba(235,235,240,0.6)` |
| Text tertiary | `rgba(235,235,240,0.3)` |
| Separator / border | `#38383A` |
| Active border (current set) | `#25A25A` (2pt solid) |
| Table felt (dark) | `#144D2A` |
| Table cushion (dark) | `#5C2E00` |
| Cue ball | `#F5F5F5` |
| Target ball | `#F5A623` |
| Card radius | 12pt |
| Input box | 44pt × 44pt |
| Padding | 16pt |
| Min touch target | 44pt |

---

### Constraints

- FULL-SCREEN training modal — shared timer bar + toolbar with overview
- The set input grid is the CORE — visual focal point, maximum readability on dark background
- Completed rows have subtle dark-green tint `rgba(37,162,90,0.10)` — must be visible but not overwhelming on `#1C1C1E` card
- Current active row stands out with `#25A25A` borders on input boxes
- Warmup "热" badge stays orange `#F5A623` — high contrast on dark background
- Input boxes use `#2C2C2E` fill (tertiary dark) to differentiate from card background `#1C1C1E`
- Billiard table thumbnails use darker felt/rail colors for Dark Mode
- The add button is brand green `#25A25A` (NOT blue — P0-04 decision 5)
- NO shadows, NO gradients

---

### State

Dark Mode variant of the single drill recording view for "五分点直球". Timer at 12:34. 5 sets (1 warmup + 4 regular): warmup and Set 1 completed (dark green tint + checkmark), Set 2 active (green border), Sets 3-4 pending. Score 36/90. Billiard table expanded. Layout pixel-identical to light mode — only colors mapped to Dark Mode tokens.

---

## 推荐附加参考截图

**必须附加：**
1. **`tasks/P0-04/stitch_task_p0_04_04/screen.png`** — Light Mode 已通过版本，完全复制此布局

**可选附加：**
2. `tasks/E-01/stitch_task_*/screen.png` — 帧1 或帧2 的 Dark Mode 截图（如已完成），作为风格基准
3. `tasks/A-07/stitch_task_07_02/screen.png` — BTSetInputGrid 组件参考

> 提示："Recreate this exact layout in Dark Mode. Completed rows should have a subtle dark green tint. Current active row has green borders on inputs."

---

## BTRestTimer Dark Mode（可选追加）

如需为 BTRestTimer 弹层生成 Dark Mode 变体，可在同一 Stitch 对话中追加以下消息：

> Now create the **Dark Mode variant of the Rest Timer overlay**. Same layout as the rest timer from light mode. Key changes:
> - Dark overlay remains `rgba(0,0,0,0.7)` (slightly darker than light mode's 0.6)
> - Modal card background: `#1C1C1E` (was white)
> - Card title "组间休息": `#FFFFFF`
> - Pill buttons ("震动"/"最小化"): background `#2C2C2E`, text `rgba(235,235,240,0.6)`
> - Separator: `#38383A`
> - Outer ring: `#25A25A` (brand green Dark), track `#3A3A3C`
> - Inner ring: `#F0AD30` (gold Dark), track `#3A3A3C`
> - Countdown "0:32": `#FFFFFF` (was black)
> - "+30s" button: background `#2C2C2E`, text `#25A25A`
> - "完成休息" button: `#25A25A` fill, white text
> - Attach `tasks/P0-05/stitch_task_p0_05_restTimer/screen.png` as layout reference.

## Stitch 导出处理

1. 主帧（单项记录）导出保存到 `tasks/E-01/`
2. BTRestTimer（如生成）也保存到 `tasks/E-01/`
3. 完成后说 **"审核 E-01 帧3"** 或 **"生成提示词 E-01 帧4"** 继续
