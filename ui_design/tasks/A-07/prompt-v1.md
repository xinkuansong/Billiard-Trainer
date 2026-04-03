# Stitch Prompt — A-07: BTExerciseRow + BTSetInputGrid 组件表

> 任务 ID: A-07 | 版本: v1 | 日期: 2026-04-03
> 预检：已读取 A-01~A-06 decision-log，沿用纯文档组件表风格、品牌色 #1A6B3C 锚定、纯色填充无渐变约束；三级按钮层级体系延续 A-02 决策

---

## Stitch 提示词（开启新对话，粘贴以下内容）

Design a **Component Reference Sheet** for an iOS billiards training app called "QiuJi" (球迹). This single-page component inventory showcases two core training-recording components: **BTExerciseRow** (drill row card used in training overview) and **BTSetInputGrid** (set-by-set input grid used in single-drill recording). iPhone screen (393x852pt), Light mode, scrollable.

**CRITICAL color rules:**
- Brand green is exactly `#1A6B3C`. Do NOT change it.
- Destructive/danger red is exactly `#C62828`. Do NOT change it.
- Warmup marker orange is exactly `#F5A623`. Do NOT change it.
- Do NOT use gradients on buttons or solid color fills — all colored UI elements use solid flat fills.

**Page style** (must match our established Design Token sheet, Button sheet, List Components sheet, PremiumLock sheet, RestTimer/Indicator sheet, and SegmentedTab/Pill/Menu sheet):
- Page background: `#F2F2F7`
- Content in white cards: `#FFFFFF`, corner radius 16pt, padding 16pt
- Section titles: 22pt Bold Rounded font, color `#1A6B3C`
- No navigation bar, no tab bar — this is a pure design documentation page
- Clean, minimal iOS design system documentation style

---

### Section 1: "BTExerciseRow — 训练 Drill 行卡片"

This section shows the drill row card used in the training overview. Each row represents one drill exercise within an active training session. Display it inside a white section card.

**Layout inside the white card (top to bottom):**

1. **Example A — Drill row with partial progress ("直线球 - 中袋"):**
   - A single white row card: height 80pt, corner radius 12pt, inner padding 12pt horizontally / 10pt vertically
   - **Left**: a square thumbnail placeholder (56pt × 56pt, corner radius 8pt, background `#E8F5E9` light green) — represents the billiard table animation preview. Inside the square, show a simplified green billiard table icon or rectangle in `#1A6B3C` with small white dots to suggest balls
   - **Center** (vertical stack, 12pt left of the thumbnail):
     - Line 1: Drill name "直线球 - 中袋" in 17pt Semibold, color `#000000`
     - Line 2: "5 组" in 13pt Regular, color `rgba(60,60,67,0.6)` (secondary text)
   - **Right side** (vertically centered, right-aligned):
     - Cumulative pot count "45/180" in 15pt Regular, color `rgba(60,60,67,0.6)`
     - Below it or beside it: a gear icon (SF Symbol `gearshape`) in 18pt, color `rgba(60,60,67,0.3)` (subtle gray)
   - **Bottom strip** (below the main content, inside the same card, 8pt below the center text):
     - Progress dot indicator: 5 dots in a horizontal row with 6pt spacing
     - First 3 dots: solid circles 8pt diameter, color `#1A6B3C` (completed sets)
     - Last 2 dots: hollow circles 8pt diameter, 1.5pt stroke color `#D1D1D6` (pending sets)

2. **Example B — Drill row fully pending ("斯诺克连续进攻"):**
   - Same card structure (80pt height, 12pt radius)
   - Thumbnail: a slightly different placeholder (e.g., `#FFF3E0` light amber background with an orange ball shape `#F5A623`)
   - Name: "斯诺克连续进攻" in 17pt Semibold
   - Sets: "3 组" in 13pt secondary
   - Pot count: "0/90" in 15pt secondary
   - Gear icon on right
   - Progress dots: 3 hollow circles (all pending, gray `#D1D1D6` stroke)

3. **Example C — Drill row completed ("K 球走位"):**
   - Same card structure
   - Thumbnail: `#E3F2FD` light blue background placeholder
   - Name: "K 球走位" in 17pt Semibold
   - Sets: "4 组" in 13pt secondary
   - Pot count: "72/120" in 15pt secondary
   - Progress dots: 4 solid green circles (all completed `#1A6B3C`)

4. **Component specs** (below the examples, 12pt spacing, compact vertical list in 13pt, color `rgba(60,60,67,0.6)`):
   - "卡片高度: 80pt, 圆角: 12pt"
   - "缩略图: 56pt 方形, 圆角 8pt"
   - "名称: 17pt Semibold"
   - "组数: 13pt Regular, 辅助灰色"
   - "进球统计: 15pt Regular, 辅助灰色"
   - "进度圆点: 8pt, 已完成 #1A6B3C 实心 / 待完成 #D1D1D6 空心"

Below the card, add annotation (13pt gray text): "使用场景：ActiveTrainingView 训练总览中的 Drill 列表"

---

### Section 2: "BTSetInputGrid — 组数输入网格"

This section shows the set-by-set input grid used when a user taps into a specific drill to record detailed per-set data. This is the core data entry component. Display it inside a white section card.

**Layout inside the white card (top to bottom):**

1. **Column header row** (light gray background strip `#F2F2F7`, height 32pt, horizontal padding 12pt):
   - 5 columns evenly labeled in 12pt Medium, color `rgba(60,60,67,0.6)`:
     - Column 1 (width 32pt): "#" (set number)
     - Column 2 (width ~72pt): "进球" (pots made)
     - Column 3 (width ~72pt): "总球" (total balls)
     - Column 4 (width 44pt): "✓" (completion)
     - Column 5 (width 44pt): "⋯" (overflow actions)

2. **Data rows — Row 1 (completed set):**
   - Background: `rgba(26,107,60,0.08)` (btPrimaryMuted — very light green tint)
   - Set number: "1" in 15pt Bold, color `#1A6B3C`
   - Pots input square: 44pt × 44pt rounded rectangle (corner radius 8pt), background `#FFFFFF`, showing "9" in 17pt Bold centered, color `#000000`
   - Total balls input square: same style, showing "10"
   - Completion button: 44pt circle, solid fill `#1A6B3C`, white checkmark "✓" icon inside (SF Symbol `checkmark`, 18pt, white)
   - Overflow: "⋯" icon 18pt, color `rgba(60,60,67,0.3)`

3. **Data rows — Row 2 (completed set):**
   - Same green-tinted background
   - Set number: "2"
   - Pots: "7", Total: "10"
   - Green filled checkmark
   - Overflow dots

4. **Data rows — Row 3 (current active set):**
   - Background: `#FFFFFF` (no tint)
   - **Entire row has a 2pt left border accent in `#1A6B3C`** to indicate "current set"
   - Set number: "3" in 15pt Bold, color `#1A6B3C`
   - Pots input square: 44pt × 44pt, corner radius 8pt, **border: 2pt solid `#1A6B3C`** (brand green border to indicate active/editable), background white, showing "—" in 17pt color `#D1D1D6` (placeholder, not yet entered)
   - Total balls input square: same active border style, showing "10" in 17pt
   - Completion button: 44pt circle, **1.5pt stroke `#D1D1D6`** (hollow gray outline), no fill
   - Overflow dots

5. **Data rows — Row 4 (pending set):**
   - Background: `#FFFFFF`
   - Set number: "4" in 15pt Regular, color `rgba(60,60,67,0.6)` (gray, not bold)
   - Pots input: 44pt square, 1pt border `#E5E5EA` (light gray), "—" placeholder
   - Total balls input: same gray border, "10"
   - Completion: hollow gray circle
   - Overflow dots

6. **Data rows — Row 5 (warmup set):**
   - Background: `#FFFFFF`
   - Set number position: instead of a number, show an orange rounded rectangle badge (28pt × 20pt, corner radius 4pt, background `rgba(245,166,35,0.15)`) with text "热" in 12pt Bold, color `#F5A623`
   - Pots input: 44pt square, 1pt border `#E5E5EA`, "—" placeholder
   - Total balls input: same, "10"
   - Completion: hollow gray circle
   - Overflow dots

7. **Below the grid:** a dashed-outline button spanning the grid width:
   - Height 40pt, corner radius 8pt, dashed border 1.5pt `#D1D1D6`
   - Text: "+ 添加一组" in 15pt Medium, color `rgba(60,60,67,0.6)`
   - Centered

8. **Component specs** (below the grid area, 12pt spacing, compact vertical list in 13pt, color `rgba(60,60,67,0.6)`):
   - "输入方块: 44pt × 44pt, 圆角 8pt"
   - "已完成组: btPrimaryMuted 浅绿底 + 实心绿 ✓"
   - "当前组: #1A6B3C 2pt 边框高亮"
   - "未完成组: #E5E5EA 1pt 灰色边框"
   - "热身组: 橙色 #F5A623「热」标记"
   - "勾选按钮: 44pt 圆形"

Below the card, add annotation (13pt gray text): "使用场景：ActiveTrainingView 单项记录视图中的逐组数据录入"

---

### Section 3: "BTSetInputGrid — 空状态"

This section shows the empty state of BTSetInputGrid when no sets have been added yet. Display it inside a white section card.

**Layout inside the white card:**

1. **Column header row**: same as Section 2 (gray strip with 5 column labels)

2. **Empty area** (centered, 120pt height):
   - An SF Symbol icon `tablecells` or `square.grid.3x3` in 36pt, color `rgba(60,60,67,0.2)` (very faint)
   - Below: "还没有组数" in 15pt Regular, color `rgba(60,60,67,0.4)`
   - Below (4pt gap): "点击下方按钮添加" in 13pt Regular, color `rgba(60,60,67,0.3)`

3. **Add button** (same dashed-outline style as Section 2):
   - "+ 添加一组" centered, dashed border

Below the card, add annotation (13pt gray text): "空状态：新 Drill 刚加入训练时的初始视图"

---

**Design constraints (strictly enforced):**
- `#1A6B3C` is the ONLY brand green — do not substitute
- `#C62828` is the ONLY destructive red — do not substitute
- `#F5A623` is the warmup/target ball orange — do not substitute
- Solid flat fills for all UI elements — NO gradients anywhere
- iOS native feel: SF Pro font, clean flat style
- Card corner radius: 12pt for inner component cards (BTExerciseRow), 16pt for section wrapper cards
- Input squares must be exactly 44pt to meet minimum touch target
- BTExerciseRow thumbnail is exactly 56pt square with 8pt corner radius
- Progress dots must clearly show completed (solid green) vs pending (hollow gray) distinction
- BTSetInputGrid current-set row must have visible brand green border accent to indicate editability
- Warmup set "热" badge must use orange `#F5A623`, not the brand green
- Visual style must match Design Token sheet (A-01), Button sheet (A-02), List Components sheet (A-03), PremiumLock sheet (A-04), RestTimer/Indicator sheet (A-05), and SegmentedTab/Pill/Menu sheet (A-06): white cards on gray `#F2F2F7` background, green `#1A6B3C` section titles, no nav bar, no tab bar

---

## 参考截图

建议附加以下参考图帮助 Stitch 理解组件上下文（如果可用）：
- `ref-screenshots/02-training-active/03-active-main.png` — 竞品训练总览页（Drill 行卡片列表），球迹使用品牌绿 #1A6B3C + 球台缩略图
- `ref-screenshots/02-training-active/04-active-set-progress.png` — 竞品逐组记录页（组数网格布局），球迹使用表格式 44pt 方块输入 + 绿色完成状态

⚠️ 注意：参考截图目录尚未导入，如有本地文件请手动附加到 Stitch 对话中。

## 使用说明

1. 在 Google Stitch 中**开启新对话**
2. 粘贴上方提示词，可选附加两张参考截图
3. 导出保存到 `tasks/A-07/`
4. 说「审核 A-07」触发审核智能体
