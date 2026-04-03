# Stitch Prompt — P0-03: ActiveTrainingView（训练总览）

> 任务 ID: P0-03 | 版本: v1 | 日期: 2026-04-03
> 预检：依赖 A-02 (BTButton) ✅ + A-07 (BTExerciseRow + BTSetInputGrid) ✅；P0-01/P0-02 已通过确立品牌色/卡片风格基准；画布 393px；本页面为全屏模式（fullScreenCover），无标准导航栏和 Tab 栏

---

## Stitch 提示词（开启新对话，粘贴以下内容）

Design the **Active Training Overview screen** for an iOS billiards training app called "QiuJi" (球迹). This is a **full-screen modal** (presented via fullScreenCover) showing the user's current training session. It displays a timer, a list of training drills, and a bottom toolbar. The user is mid-training with 4 drills loaded. iPhone screen (393 × 852pt), Light mode, scrollable content.

**CRITICAL — this is a full-screen overlay:**
- Do NOT include the standard iOS large-title navigation bar (no "训练" title bar).
- Do NOT include the 5-tab bottom tab bar.
- This screen has its OWN top timer bar and its OWN bottom toolbar.

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

### Top Area: Timer Bar

- **Status bar**: standard iOS status bar (time, signal, battery indicators)
- **Timer row** (below status bar, 16pt horizontal padding, 12pt vertical padding, on `#F2F2F7` background):
  - **Left side**: large training timer `00:12:34` in **28pt Bold monospace** font (tabular figures), color `#1A6B3C` (brand green)
  - **Right side**: 4 icon buttons in a horizontal row, 8pt spacing between icons:
    - Alarm/bell icon (rest timer setting)
    - Clock/history icon (history)
    - Arrow up-down icon (sort/reorder)
    - Checkmark.circle or square.and.arrow.down icon (save/finish)
    - Each icon: 24pt size, `rgba(60,60,67,0.6)` color, 44pt tap area, no background circle

- **Info row** (directly below timer row, 16pt horizontal padding, 4pt below timer):
  - **Left**: training name "基础直球训练" in **17pt Semibold**, color `#000000`, with a small pencil/edit icon (14pt, `rgba(60,60,67,0.3)`) to its right indicating it's editable
  - **Right**: progress stats "8/15 组  2/4 项目" in **13pt Regular**, color `rgba(60,60,67,0.6)`

---

### Main Content: Drill List (ScrollView)

4 drill cards in a vertical list, each is a **BTExerciseRow** card. Cards have 8pt vertical spacing between them, 16pt horizontal margin from screen edges.

**Drill Card Structure** (white `#FFFFFF` card, corner radius 12pt, height ~80pt, padding 12pt):

- **Left**: square billiard table thumbnail (56pt × 56pt, corner radius 8pt). Show a simplified top-down billiard table: green `#1B6B3A` surface with brown `#7B3F00` border rail, small white dot (cue ball) and orange `#F5A623` dot (target ball).
- **Center column** (12pt gap from thumbnail):
  - Drill name in **17pt Semibold**, color `#000000` (e.g. "五分点直球")
  - Second line: set count "5 组" in **13pt Regular**, color `rgba(60,60,67,0.6)` — followed inline by **progress dots** (6pt circles, 4pt spacing): 3 filled dots in `#1A6B3C` (completed sets) + 2 hollow dots in `#D1D1D6` (remaining sets)
- **Right column** (right-aligned):
  - Score "36/90" in **15pt Regular**, color `#000000`
  - Below: a small gear icon ⚙️ (settings), 18pt, color `rgba(60,60,67,0.3)`

**The 4 drill cards with sample data:**

1. "五分点直球" — 5 组, 3/5 completed (●●●○○), score 36/90, thumbnail with cue ball + target ball
2. "半台走位" — 3 组, 1/3 completed (●○○), score 8/27, thumbnail variation
3. "定点叫位" — 4 组, 0/4 completed (○○○○), score 0/60, thumbnail variation
4. "自由击球" — 3 组, 0/3 completed (○○○), score 0/45, thumbnail variation

---

### Bottom Toolbar (Fixed at bottom)

A fixed bottom toolbar with 5 equally-spaced items, sitting above the safe area. Toolbar background: white `#FFFFFF`, top border 0.5pt `#E5E5EA`, height ~56pt + safe area padding below.

Each toolbar item is icon (24pt) + label (10pt) stacked vertically, except the center item which is special:

1. **Minimize** (left): minimize/pip icon (e.g. arrow.down.right.and.arrow.up.left), label "最小化", color `rgba(60,60,67,0.6)`, 44pt tap area
2. **More** (second): ellipsis.circle icon, label "更多", color `rgba(60,60,67,0.6)`, 44pt tap area
3. **Add** (center, prominent): a **large circle button** (56pt diameter) with `#007AFF` (iOS system blue) solid fill, white `+` icon (28pt bold) centered. This button rises ~12pt above the toolbar surface. Label "添加" in 10pt below the circle, color `#007AFF`
4. **Notes** (fourth): square.and.pencil icon, label "心得", color `rgba(60,60,67,0.6)`, 44pt tap area
5. **Switch View** (right): list.bullet / rectangle.grid icon, label "切换", color `rgba(60,60,67,0.6)`, 44pt tap area

---

### Design Tokens Summary

| Token | Value |
|-------|-------|
| Primary (brand green) | `#1A6B3C` — USE THIS EXACTLY |
| System blue (add button) | `#007AFF` |
| Background | `#F2F2F7` |
| Card white | `#FFFFFF` |
| Text primary | `#000000` |
| Text secondary | `rgba(60,60,67,0.6)` |
| Text tertiary | `rgba(60,60,67,0.3)` |
| Outline/border | `#D1D1D6` |
| Separator | `#E5E5EA` |
| Table felt green | `#1B6B3A` |
| Table cushion brown | `#7B3F00` |
| Cue ball | `#F5F5F5` |
| Target ball | `#F5A623` |
| Card radius | 12pt |
| Thumbnail radius | 8pt |
| Padding | 16pt |
| Min touch target | 44pt |

---

### Constraints

- This is a FULL-SCREEN MODAL — no standard nav bar, no tab bar. It has its own timer bar at top and toolbar at bottom.
- The drill list should feel like a focused, task-oriented training interface — minimal chrome, maximum readability
- The timer in brand green should be the most prominent element at the top, conveying "you are in an active training session"
- The center "add" button should visually stand out from the other 4 toolbar items as the primary action
- Billiard table thumbnails should be simplified schematic top-down views (green rectangle with rail border + 2 balls), not photographic
- Keep the same card white / gray background / brand green color scheme as the rest of the app for consistency

---

### State

This screen shows an **active training session in progress** with 4 drills. The timer shows 12 minutes 34 seconds elapsed. The first drill has 3 of 5 sets completed, the second has 1 of 3 completed, and the last two haven't been started yet. This represents a typical mid-training moment.

---

## 推荐附加参考截图

在 Stitch 中粘贴提示词后，建议同时附加以下参考截图：

1. `ref-screenshots/02-training-active/03-active-main.png` — 主参考：训练总览的整体布局和 Drill 列表
2. `ref-screenshots/02-training-active/01-plan-day-overview.png` — 辅助：训练概览结构
3. `tasks/P0-01/stitch_task_p0_01_02/screen.png` — P0-01 已通过截图，品牌色和卡片风格基准
4. `tasks/A-07/stitch_task_07_02/screen.png` — A-07 已通过截图，BTExerciseRow 组件样式基准

⚠️ 强烈建议至少附加参考截图 1 和 3，让 Stitch 理解训练记录页的布局和品牌色基准。

## Stitch 导出处理

1. Stitch 生成后会导出一个文件夹 `stitch_task_XX/`（含 `DESIGN.md` + `code.html` + `screen.png`）+ 同名 `.zip`
2. 将导出文件夹保存到 `tasks/P0-03/` 目录下
3. 完成后说 **"审核 P0-03"** 触发审核智能体
