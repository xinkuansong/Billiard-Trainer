# Stitch Prompt — A-08: BTShareCard + BTBilliardTable 组件表

> 任务 ID: A-08 | 版本: v1 | 日期: 2026-04-03
> 预检：已读取 A-01~A-07 decision-log，沿用纯文档组件表风格、品牌色 #1A6B3C 锚定、纯色填充无渐变约束；球台专用色 Token 独立于品牌色体系

---

## Stitch 提示词（开启新对话，粘贴以下内容）

Design a **Component Reference Sheet** for an iOS billiards training app called "QiuJi" (球迹). This single-page component inventory showcases two special components: **BTShareCard** (dark-themed training summary share card) and **BTBilliardTable** (top-down billiard table Canvas illustration). iPhone screen (393x852pt), Light mode page, scrollable.

**CRITICAL color rules:**
- Brand green is exactly `#1A6B3C`. Do NOT change it.
- Table felt green is exactly `#1B6B3A` (slightly different from brand green). Do NOT change it.
- Table cushion brown is exactly `#7B3F00`. Do NOT change it.
- Cue ball white is exactly `#F5F5F5`. Do NOT change it.
- Target ball orange is exactly `#F5A623`. Do NOT change it.
- Pro/Accent gold is exactly `#D4941A`. Do NOT change it.
- Do NOT use gradients on buttons or solid color fills — all colored UI elements use solid flat fills.

**Page style** (must match our established component sheets A-01 through A-07):
- Page background: `#F2F2F7`
- Content in white cards: `#FFFFFF`, corner radius 16pt, padding 16pt
- Section titles: 22pt Bold Rounded font, color `#1A6B3C`
- No navigation bar, no tab bar — this is a pure design documentation page
- Clean, minimal iOS design system documentation style

---

### Section 1: "BTShareCard — 训练分享卡片"

This section shows a dark-themed card generated after completing a training session, designed to be shared as an image to social media. Display TWO theme variants side by side (each about 170pt wide) inside a white section card.

**Variant A — "基础绿" (Default Green Theme):**

A tall card (170pt wide × ~280pt tall), with these elements from top to bottom:

1. **Card container**: dark background `#1C1C1E`, corner radius 16pt, padding 16pt
2. **Header area** (top of card):
   - Date line: "2026年4月3日 周四" in 12pt Regular, color `rgba(255,255,255,0.5)`
   - Training name: "台球基础功训练" in 18pt Bold, color `#FFFFFF`
   - Duration tag: a small pill badge "52 分钟" with background `rgba(26,107,60,0.3)`, text `#25A25A` (brand green light variant), 11pt Medium, corner radius 999pt, horizontal padding 8pt
3. **Stats row** (horizontal, 3 items evenly spaced):
   - Each stat: large number in 22pt Bold `#FFFFFF` on top + label in 11pt Regular `rgba(255,255,255,0.5)` below
   - Item 1: "4" / "完成项目"
   - Item 2: "16" / "总组数"
   - Item 3: "78%" / "成功率"
4. **Drill breakdown list** (compact, vertical):
   - A thin horizontal divider line (`rgba(255,255,255,0.1)`) separating stats from drill list
   - 3 drill rows, each row height ~28pt:
     - Row 1: "直线球 - 中袋" in 14pt Regular white + right-aligned "45/60" in 13pt `rgba(255,255,255,0.5)` + small green dot `#1A6B3C` as completed indicator
     - Row 2: "K 球走位" + "36/60" + green dot
     - Row 3: "斯诺克连续进攻" + "21/30" + green dot
5. **Brand footer area** (bottom of card, 12pt top padding):
   - A thin horizontal divider (`rgba(255,255,255,0.08)`)
   - Left side: a small app icon placeholder (24pt × 24pt rounded square, background `#1A6B3C`, with a white circle inside to suggest a ball) + "球迹 QiuJi" in 12pt Medium, color `rgba(255,255,255,0.6)`, 8pt right of icon
   - Right side: a QR code placeholder (36pt × 36pt square, white on dark, grid pattern to suggest QR code)

**Variant B — "暗夜蓝" (Dark Blue Theme):**

Same layout and content as Variant A, but with these color changes:
- Card background: `#0D1B2A` (deep navy)
- Duration pill background: `rgba(59,130,246,0.25)`, text `#60A5FA`
- Drill completed dots: `#3B82F6` (blue)
- App icon placeholder background: `#1E3A5F`
- Stats numbers remain `#FFFFFF`

**Below both cards**, inside the section card, add:
- **Theme selector mockup**: a horizontal row of 4 small circles (24pt each, 8pt spacing):
  - Circle 1: fill `#1A6B3C` (green, selected — white checkmark inside)
  - Circle 2: fill `#0D1B2A` (navy blue)
  - Circle 3: fill `#1C1C1E` (dark gray / black-white)
  - Circle 4: fill `#2D1B4E` (deep purple, future)

**Component specs** (below, 13pt, color `rgba(60,60,67,0.6)`):
- "卡片: 圆角 16pt, 深色主题容器"
- "配色主题: 基础绿 / 暗夜蓝 / 黑白 / 更多"
- "品牌区: App Logo + 二维码占位"
- "渲染为图片用于社交分享"

Below the card, add annotation (13pt gray text): "使用场景：TrainingShareView 训练完成后的分享卡定制"

---

### Section 2: "BTBilliardTable — 球台 Canvas 组件 (全尺寸)"

This section shows a **top-down overhead view** of a billiard table at full size (~350pt wide × 190pt tall), as used in DrillDetailView. Display it inside a white section card.

**Layout inside the white card:**

1. **Billiard table illustration** (centered, 350pt × 190pt):
   - **Table felt** (playing surface): a large rounded rectangle, fill `#1B6B3A` (table felt green), corner radius 8pt
   - **Cushion border**: a `#7B3F00` (brown) border around the felt, 8pt thick. The outer edge of the cushion has corner radius 12pt, inner edge 8pt
   - **6 pockets**: 6 black circles (`#000000`), diameter 16pt each, positioned at:
     - Top-left corner, top-right corner, bottom-left corner, bottom-right corner (corner pockets, inset at corners of the felt)
     - Top-center, bottom-center (side pockets, centered on the long edges)
   - **Cue ball** (mother ball): a circle, diameter 14pt, fill `#F5F5F5` (near-white), with a subtle 1pt stroke `rgba(0,0,0,0.1)` for definition. Position: lower-center area of the table (about 70% down, 40% from left)
   - **Target ball**: a circle, diameter 14pt, fill `#F5A623` (orange). Position: upper-center area (about 35% down, 55% from left)
   - **Shot path line** (cue ball to target ball): a dashed line from cue ball center to target ball center, stroke color `rgba(245,245,245,0.6)` (semi-transparent white), dash pattern 4pt on / 4pt off, stroke width 1.5pt
   - **Target ball path** (after contact): a dashed line from the target ball continuing toward the nearest pocket (top-right), stroke color `rgba(245,166,35,0.5)` (semi-transparent orange), same dash pattern, stroke width 1.5pt
   - **Contact point marker**: at the point where the shot path meets the target ball, a small ring (8pt diameter, 2pt stroke `#FFFFFF`, no fill) to highlight the contact point

2. **Path legend** (below the table, horizontal row, 8pt spacing):
   - A short white dashed line segment (20pt) + "母球路径" in 12pt, color `rgba(60,60,67,0.6)`
   - A short orange dashed line segment (20pt) + "目标球路径" in 12pt, color `rgba(60,60,67,0.6)`
   - A small white ring (8pt) + "接触点" in 12pt, color `rgba(60,60,67,0.6)`

3. **Component specs** (below legend, 13pt, color `rgba(60,60,67,0.6)`):
   - "全尺寸: ~350 × 190pt (DrillDetailView Hero 区)"
   - "台面: btTableFelt #1B6B3A"
   - "库边: btTableCushion #7B3F00 (8pt)"
   - "袋口: btTablePocket #000000 (16pt ⌀)"
   - "母球: btBallCue #F5F5F5 (14pt ⌀)"
   - "目标球: btBallTarget #F5A623 (14pt ⌀)"
   - "Canvas 绘制, 路径为动画示意"

Below the card, add annotation (13pt gray text): "使用场景：DrillDetailView Hero 区 + ActiveTrainingView 球台动画展开模式"

---

### Section 3: "BTBilliardTable — 缩略图模式"

This section shows the **thumbnail version** of the billiard table (56pt × 56pt), as used inside BTExerciseRow. Display 3 thumbnail variants in a horizontal row inside a white section card.

**Layout inside the white card:**

1. **Thumbnail row** (horizontal, centered, 16pt spacing between items):

   - **Thumbnail A — "直线球" (straight shot):**
     - A 56pt × 56pt rounded square, corner radius 8pt
     - Background: `#1B6B3A` (table felt green)
     - Border: 3pt `#7B3F00` (brown cushion) on all sides
     - Inside: 2 tiny circles — a 6pt white circle `#F5F5F5` (cue ball, lower area) and a 6pt orange circle `#F5A623` (target ball, upper area)
     - A thin dashed line connecting them (1pt, white semi-transparent)

   - **Thumbnail B — "K 球走位" (positional play):**
     - Same 56pt container and border
     - Inside: 2 tiny ball circles at different positions (cue ball lower-left, target ball center-right)
     - Two dashed path lines forming an angle (cue→target in white, target→pocket in orange)

   - **Thumbnail C — "低杆" (draw shot):**
     - Same 56pt container and border
     - Inside: 2 ball circles close together (center area)
     - A curved-ish path line suggesting backspin direction

2. **Below thumbnails**, labels centered under each:
   - "直线球" / "K 球走位" / "低杆" — each in 12pt Regular, color `rgba(60,60,67,0.6)`

3. **Component specs** (below, 13pt, color `rgba(60,60,67,0.6)`):
   - "缩略图: 56 × 56pt, 圆角 8pt"
   - "简化球台: 省略袋口细节, 保留台面色 + 库边色 + 球位"
   - "使用场景: BTExerciseRow 左侧缩略图, BTDrillCard 缩略图"

Below the card, add annotation (13pt gray text): "使用场景：BTExerciseRow (A-07) 和 BTDrillCard (A-03) 左侧的球台缩略图"

---

**Design constraints (strictly enforced):**
- `#1A6B3C` is the brand green — used for section titles, UI elements. Do NOT substitute.
- `#1B6B3A` is the table felt green — used ONLY for the billiard table surface. Do NOT substitute.
- `#7B3F00` is the cushion brown — used ONLY for table borders. Do NOT substitute.
- `#F5F5F5` is the cue ball color. `#F5A623` is the target ball color. Do NOT substitute.
- `#D4941A` is the Pro/accent gold. Do NOT substitute.
- Solid flat fills for all UI elements — NO gradients anywhere.
- iOS native feel: SF Pro font, clean flat style.
- The BTShareCard uses DARK backgrounds (`#1C1C1E` or themed dark colors) — this is intentional as it's a share image, not a regular app screen.
- The BTBilliardTable is a Canvas-drawn illustration — Stitch should render a static schematic showing ball positions and path indicators. Actual animation is handled in code.
- White section cards on gray `#F2F2F7` background, green `#1A6B3C` section titles, no nav bar, no tab bar.
- Visual style must match established component sheets A-01 through A-07.

---

## 参考截图

建议附加以下参考图帮助 Stitch 理解组件上下文（如果可用）：
- `ref-screenshots/02-training-active/07-training-summary.png` — 竞品训练总结+分享卡页面，球迹使用品牌绿主题 + 深色卡片背景
- 无直接球台参考截图，以上方文字描述为主

⚠️ 注意：参考截图目录可能未完全导入，如有本地文件请手动附加到 Stitch 对话中。

## 使用说明

1. 在 Google Stitch 中**开启新对话**
2. 粘贴上方提示词，可选附加参考截图
3. 导出保存到 `tasks/A-08/`
4. 说「审核 A-08」触发审核智能体
