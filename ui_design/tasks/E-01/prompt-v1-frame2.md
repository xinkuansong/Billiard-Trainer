# Stitch Prompt — E-01 帧2: ActiveTrainingView 训练总览 Dark Mode

> 任务 ID: E-01 | 帧: 2/5 | 版本: v1 | 日期: 2026-04-05
> Light Mode 基准: P0-03 v2 (`tasks/P0-03/stitch_task_p0_03_02/screen.png`)
> 注意: 全屏模态（fullScreenCover），无标准导航栏、无 Tab 栏，自建计时器头部 + 底部工具栏
> P0-04 决策 5: 添加按钮统一为品牌绿（覆盖 P0-03 的蓝色）

---

## Stitch 提示词（开启新对话，粘贴以下内容）

Design the **Dark Mode variant** of the Active Training Overview screen for an iOS billiards training app called "QiuJi" (球迹). This is a **full-screen modal** showing the user's current training session — timer, drill list, and bottom toolbar. iPhone screen (393 × 852pt), **Dark mode**, scrollable content.

**CRITICAL: This is a color-mapping exercise. The layout, spacing, element positions, and content must be IDENTICAL to the attached light mode screenshot. Only colors change.**

**CRITICAL — this is a full-screen overlay:**
- Do NOT include the standard iOS large-title navigation bar.
- Do NOT include the 5-tab bottom tab bar.
- This screen has its OWN top timer bar and its OWN bottom toolbar.

**CRITICAL color rules (Dark Mode):**
- Brand green is `#25A25A` (brighter than light mode). Use this in your Tailwind config as `primary: "#25A25A"`. Do NOT use #1A6B3C or #005129.
- Page background: `#000000` (pure black, OLED)
- Card/container background: `#1C1C1E`
- Text primary: `#FFFFFF`
- Text secondary: `rgba(235,235,240,0.6)`
- Text tertiary: `rgba(235,235,240,0.3)`
- Separator/border: `#38383A`
- Do NOT use gradients — all colored UI elements use solid flat fills only.
- Do NOT use drop shadows on cards — use background color contrast only.

**Overall style:**
- iOS native mobile app design (SF Pro font family feel, SF Symbols icons)
- Clean, modern, focused training interface — now in Dark Mode
- White status bar text (light content style)
- Canvas width: 393px (iPhone 15 Pro)

---

### Top Area: Timer Bar

- **Status bar**: iOS status bar with **white text** (light content style)
- **Timer row** (below status bar, 16pt horizontal padding, 12pt vertical padding, on `#000000` background with subtle dark frosted glass effect `rgba(0,0,0,0.9)` + backdrop-blur):
  - **Left side**: large training timer `00:12:34` in **28pt Bold monospace** (tabular figures), color `#25A25A` (brand green Dark — the most prominent element)
  - **Right side**: 4 icon buttons in a row, 8pt spacing:
    - Alarm/bell icon (rest timer)
    - Clock/history icon
    - Arrow up-down icon (sort)
    - Checkmark.circle icon (save/finish)
    - Each icon: 24pt, `rgba(235,235,240,0.6)` color, 44pt tap area

- **Info row** (directly below timer, 16pt horizontal padding, 4pt gap):
  - **Left**: "基础直球训练" in **17pt Semibold**, color `#FFFFFF`, with pencil icon (14pt, `rgba(235,235,240,0.3)`)
  - **Right**: "8/15 组  2/4 项目" in **13pt Regular**, color `rgba(235,235,240,0.6)`

---

### Main Content: Drill List (ScrollView)

4 drill cards in a vertical list, 8pt spacing between cards, 16pt horizontal margin.

**Drill Card Structure** (background `#1C1C1E`, corner radius 12pt, height ~80pt, padding 12pt, NO shadow):

- **Left**: square billiard table thumbnail (56pt × 56pt, corner radius 8pt). Dark Mode billiard table: dark green `#144D2A` surface (darker than light mode) with dark brown `#5C2E00` rail border, white dot `#F5F5F5` (cue ball) and orange `#F5A623` dot (target ball).
- **Center column** (12pt gap from thumbnail):
  - Drill name in **17pt Semibold**, color `#FFFFFF`
  - Set count "5 组" in **13pt Regular**, color `rgba(235,235,240,0.6)` — followed by **progress dots** (6pt circles, 4pt spacing): completed dots in `#25A25A` (brand green Dark) + remaining dots in `#3A3A3C` (dark gray, was #D1D1D6)
- **Right column** (right-aligned):
  - Score "36/90" in **15pt Regular**, color `#FFFFFF`
  - Gear icon ⚙️ 18pt, color `rgba(235,235,240,0.3)`

**The 4 drill cards with sample data:**

1. "五分点直球" — 5 组, 3/5 completed (●●●○○), score 36/90
2. "半台走位" — 3 组, 1/3 completed (●○○), score 8/27
3. "定点叫位" — 4 组, 0/4 completed (○○○○), score 0/60
4. "自由击球" — 3 组, 0/3 completed (○○○), score 0/45

---

### Bottom Toolbar (Fixed at bottom)

Fixed toolbar, above safe area. Background: `#1C1C1E`, top border 0.5pt `#38383A`, height ~56pt + safe area padding.

5 equally-spaced items, icon (24pt) + label (10pt) stacked vertically:

1. **Minimize** (left): pip icon, label "最小化", color `rgba(235,235,240,0.6)`, 44pt tap
2. **More** (second): ellipsis.circle, label "更多", color `rgba(235,235,240,0.6)`, 44pt tap
3. **Add** (center, prominent): **large circle button** (56pt diameter) with `#25A25A` (brand green Dark, solid fill — per P0-04 decision 5 overriding blue to green). White `+` icon (28pt bold). Button rises ~12pt above toolbar. Label "添加" in 10pt below, color `#25A25A`
4. **Notes** (fourth): square.and.pencil, label "心得", color `rgba(235,235,240,0.6)`, 44pt tap
5. **Switch View** (right): list.bullet icon, label "切换", color `rgba(235,235,240,0.6)`, 44pt tap

---

### Design Tokens Summary (Dark Mode)

| Token | Dark Mode Value |
|-------|----------------|
| Primary (brand green) | `#25A25A` — USE THIS EXACTLY |
| Background (page) | `#000000` |
| Card / container | `#1C1C1E` |
| Tertiary bg | `#2C2C2E` |
| Text primary | `#FFFFFF` |
| Text secondary | `rgba(235,235,240,0.6)` |
| Text tertiary | `rgba(235,235,240,0.3)` |
| Separator / border | `#38383A` |
| Progress dot (done) | `#25A25A` |
| Progress dot (remain) | `#3A3A3C` |
| Table felt (dark) | `#144D2A` |
| Table cushion (dark) | `#5C2E00` |
| Cue ball | `#F5F5F5` |
| Target ball | `#F5A623` |
| Card radius | 12pt |
| Thumbnail radius | 8pt |
| Padding | 16pt |
| Min touch target | 44pt |

---

### Constraints

- FULL-SCREEN MODAL — no standard nav bar, no tab bar. Own timer bar + own toolbar.
- The timer in `#25A25A` brand green should be the most prominent element at top.
- The center "add" button uses brand green `#25A25A` (NOT blue — this was updated in P0-04 decision 5).
- Billiard table thumbnails use Dark Mode tokens (`#144D2A` felt, `#5C2E00` rail) — darker than light mode.
- Cards use `#1C1C1E` on pure `#000000` — no shadows, just color-layer contrast.
- Dark frosted glass effect on timer bar: subtle blur, near-opaque black.

---

### State

This screen shows the **Dark Mode variant** of an active training session in progress. 4 drills loaded, timer at 12:34, first drill 3/5 sets done, second 1/3 done, last two not started. Content and layout identical to light mode — only colors are mapped to Dark Mode tokens.

---

## 推荐附加参考截图

在 Stitch 中粘贴提示词后，**必须**附加以下截图：

1. **`tasks/P0-03/stitch_task_p0_03_02/screen.png`** — 必须：Light Mode 已通过版本，完全复制此布局
2. `tasks/P0-04/stitch_task_p0_04_04/screen.png` — 可选：P0-04 单项记录参考（确认品牌绿添加按钮）
3. `tasks/E-01/stitch_task_*/screen.png` — 可选：如 E-01 帧1 已完成，附加作为 Dark Mode 风格基准

> 提示：告诉 Stitch "Recreate this exact layout in Dark Mode. The center add button should be green #25A25A (not blue)."

## Stitch 导出处理

1. Stitch 导出文件夹保存到 `tasks/E-01/` 目录下
2. 完成后说 **"审核 E-01 帧2"** 或 **"生成提示词 E-01 帧3"** 继续
