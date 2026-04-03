# Stitch Prompt — P0-04 v2（增量修正）

> 任务 ID: P0-04 | 版本: v2 | 日期: 2026-04-03
> 在 Stitch 同一会话中发送以下修正指令（不需要重新开始对话）

---

## Stitch 修正指令（在同一对话中粘贴以下内容）

Please revise this screen with the following corrections. This is a significant update — please read all items carefully before regenerating.

---

### 1. Replace the Top Header (CRITICAL)

The current centered "Session Recording / Finish" header is wrong. Replace it with this **exact two-row layout** (white frosted-glass background `rgba(255,255,255,0.9)` with backdrop blur, fixed at top):

**Row 1 — Timer Row** (16pt horizontal padding, 12pt vertical padding):
- **Left**: green timer `00:12:34` in **28pt Bold monospace**, color `#1A6B3C`
- **Right**: 4 small icon buttons in a row (8pt spacing): alarm bell, clock/history, arrow up-down, checkmark.circle — each 24pt, color `rgba(60,60,67,0.6)`, no background

**Row 2 — Info Row** (4pt below Row 1):
- **Left**: "基础直球训练" in **17pt Semibold** black, with a tiny pencil icon (14pt, `rgba(60,60,67,0.3)`) to its right
- **Right**: "8/15 组  2/4 项目" in **13pt Regular** `rgba(60,60,67,0.6)`

Remove the "Session Recording" title and the "Finish" button entirely.

---

### 2. Fix the Set Input Grid (CRITICAL)

The grid needs major changes:

**A. Add a 5th column — overflow menu ⋯:**
Grid columns should be: 组 | 进球 | 总球 | 完成 | (⋯ overflow)
The last column is narrow, just showing a ⋯ icon (16pt, `rgba(60,60,67,0.3)`) for each row.

**B. Add a warmup row as Row 1 (before the current rows):**
- Column 1: instead of a number, show an **orange badge** — small rounded rectangle (24pt × 20pt, corner radius 4pt, fill `#F5A623`) with white text **"热"** (12pt Bold) centered inside
- Columns 2-3: input boxes showing "8" and "10", with light green background `rgba(26,107,60,0.06)`
- Column 4: green filled circle checkmark `#1A6B3C` (completed)
- Column 5: ⋯ overflow icon
- **Row background**: light green tint `rgba(26,107,60,0.06)` — this is a completed warmup set

**C. The full 5-row grid should be:**
1. **热身 (warmup)** — completed, green background, "8/10", green ✓
2. **Set 1** — completed, green background, "15/18", green ✓
3. **Set 2** — CURRENT active set, white background, "13/18" in input boxes with **2pt solid `#1A6B3C` border**, empty hollow circle (NOT a "SAVE" button)
4. **Set 3** — not started, gray border input boxes, "0" placeholder, hollow circle `#D1D1D6`
5. **Set 4** — not started, same as Set 3

**D. Remove the blue "SAVE" button** on the current row. Replace it with an empty circle outline (1.5pt `#D1D1D6` border, hollow, same as not-started rows).

**E. Change column headers to Chinese**: 组 | 进球 | 总球 | 完成 | (no header for ⋯ column)

**F. Strengthen the completed row background**: use `rgba(26,107,60,0.06)` — it should be visibly tinted green, not nearly invisible.

---

### 3. Add Missing Elements

**A. Notes input row** — add this between the Drill Header and the Rest Settings row:
- A single line: left-aligned placeholder text **"点击输入备注…"** in 15pt Regular `rgba(60,60,67,0.3)`, with a small notepad icon (16pt) on the right end
- Thin separator line `#E5E5EA` (0.5pt) below it

**B. "+ 添加一组" button** — add below the grid card:
- Centered text **"+ 添加一组"** in 15pt Medium, color `#1A6B3C`, no background, 44pt tap height

---

### 4. Fix All Text to Chinese

Replace these English strings with Chinese:
- "DRILL SCHEMATIC" → **"球台示意"**
- "Rest Settings" → **"休息设置"** (with alarm clock icon)
- "30s" → **"60s"**
- "NORMAL MODE" → **"✓ 每组计时"** (green text + light green pill background, indicating selected)
- "TIMED CHALLENGE" → **"✓ 显示成功率"** (same selected style)

The mode chips should look like toggle pills: both selected with `#1A6B3C` text, `rgba(26,107,60,0.1)` fill, pill shape (999pt radius), height 32pt. The checkmark ✓ is part of the label text.

---

### 5. Move and Fix the Billiard Table Section

**A. Move the billiard table section to BELOW the "+ 添加一组" button** (currently it sits above the grid, which is wrong).

**B. Fix the table illustration** (I will attach a reference photo of a real billiard table — use it as visual style reference for the schematic):
- The table should look like a **simplified top-down schematic** inspired by the attached reference photo: bright green felt, dark wooden rails with visible corner/side pockets
- Outer rail border: **6pt thick `#7B3F00`** (brown, like the wooden rails in the reference photo) around the green felt
- Felt surface: `#1B6B3A` (dark green, matching the felt color)
- **6 pocket holes**: small black `#1C1C1E` circles (8pt diameter) at the 4 corners and 2 side midpoints (clearly visible as in the reference photo)
- **Cue ball**: white `#F5F5F5` circle (14pt) at position **38% from left, 70% from top** (diagonal layout)
- **Target ball**: **orange `#F5A623`** circle (14pt, NOT red) at **58% from left, 32% from top**
- **Path lines**: semi-transparent white dashed line from cue ball to target ball, semi-transparent orange dashed line from target ball toward a pocket
- The overall feel should be a clean, flat, schematic representation of a billiard table — not photographic, but clearly recognizable as a billiard table with proper proportions (approximately 2:1 width-to-height ratio like in the reference)
- Below the table: centered text "五分点直球 — 母球定点击打目标球进袋" in 13pt `rgba(60,60,67,0.6)`

---

### 6. Fix the Bottom Toolbar

Update the 5 toolbar items to match this exact order and add Chinese text labels below each icon (10pt):

1. **最小化** — `arrow.down.right.and.arrow.up.left` icon, color `rgba(60,60,67,0.6)`
2. **更多** — `ellipsis.circle` icon, same gray
3. **添加** — large 56pt circle, `#007AFF` blue fill, white `+` icon, rises above toolbar. Label "添加" in `#007AFF`
4. **心得** — `square.and.pencil` icon, gray
5. **切换** — `list.bullet` icon, gray

Each item must have both an icon AND a Chinese label below it.

---

### 7. Fix the Drill Header Thumbnail

Replace the AI-generated photo with a **simple CSS top-down billiard table schematic**: green `#1B6B3A` rectangle with brown `#7B3F00` border, white dot (cue ball) and orange `#F5A623` dot (target ball). Same as the thumbnails in the training overview screen. Also add a gear/settings icon ⚙️ (22pt, `rgba(60,60,67,0.3)`) on the right side of the drill header.

---

### 8. Fix Colors

- Page background: use `#F2F2F7` (not `#F9F9FE`)
- Tailwind primary should be `#1A6B3C` (not `#005129`)
- All text that was `#1A1C1F` should be `#000000` for primary text

---

### Summary of the corrected screen layout (top to bottom):

1. Fixed frosted header: timer row + info row (matching training overview)
2. Drill header card: CSS schematic thumbnail + "五分点直球" + "进球 36/90" + gear icon
3. Notes input: "点击输入备注…" placeholder
4. Rest settings: alarm icon + "休息设置" + "60s" + edit
5. Mode toggle chips: "✓ 每组计时" + "✓ 显示成功率" (both selected, green pills)
6. Set input grid card: 5 columns × 5 rows (warmup → set 1 → set 2 active → set 3 → set 4)
7. "+ 添加一组" green text button
8. Collapsible billiard table section: "球台示意" header + full table with rails/pockets/balls/paths
9. Fixed bottom toolbar: 最小化 / 更多 / 添加(blue) / 心得 / 切换 (with labels)

---

## 推荐附加参考截图

在 Stitch 中发送修正指令时，**额外附加这张球台参考图**：

1. `tasks/P0-04/ref-billiard-table.png` — **球台俯视图参考**：展示真实球桌的俯视角度、绿色台面、深色木质库边、6个袋口的比例和位置关系。Stitch 生成的球台示意图应参照此图的比例和布局风格，简化为扁平示意图。

---

## Stitch 导出处理

1. Stitch 生成后将导出文件夹保存到 `tasks/P0-04/stitch_task_p0_04_02/`
2. 完成后说 **"审核 P0-04"** 触发审核智能体
