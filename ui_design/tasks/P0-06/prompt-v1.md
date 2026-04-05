# Stitch Prompt — P0-06: TrainingSummaryView + TrainingShareView

> 任务 ID: P0-06 | 版本: v1 | 日期: 2026-04-03
> 预检：依赖 A-02 (BTButton) ✅ + A-08 (BTShareCard/BTBilliardTable) ✅；P0-01~P0-05 已通过确立 Phase B 页面框架
> 本任务包含两帧，需分别在两个 Stitch 对话中生成

---

## 帧 1 — TrainingSummaryView（训练数据总结页）

### Stitch 提示词（开启新对话，粘贴以下内容）

Design the **Training Summary Screen** for an iOS billiards training app called "QiuJi" (球迹). This is a **standard scrollable page** shown after the user completes a training session — it displays training statistics and drill breakdowns. iPhone screen (393 × 852pt), Light mode.

**This is a standard iOS page (NOT a full-screen modal):**
- Includes the standard iOS **navigation bar** at the top (with large title style transitioning to compact on scroll)
- Includes the standard **5-tab bottom tab bar** (训练 / 动作库 / 角度 / 记录 / 我的)
- The page background color is `#F2F2F7` (iOS light gray system background)

**CRITICAL color rules:**
- Brand green is exactly `#1A6B3C`. Use this in your Tailwind config as `primary: "#1A6B3C"`. Do NOT use #005129, #2E7D32, or any other green.
- Accent/gold: `#D4941A`
- Page background: `#F2F2F7`
- Card background: `#FFFFFF`
- Text primary: `#000000`
- Text secondary: `rgba(60,60,67,0.6)`
- Do NOT use gradients on any element — all fills are solid flat color only.

**Overall style:**
- iOS native mobile app design (SF Pro font family feel, SF Symbols icons)
- Professional sports-training aesthetic, clean and data-focused
- Canvas width: 393px (iPhone 15 Pro)

---

#### Status Bar

Standard iOS status bar at top: time on left, signal/battery icons on right. Height: 54pt (including safe area notch).

---

#### Navigation Bar

Standard iOS compact navigation bar (not large title — the large title is collapsed because we're showing the content below):
- **Left**: Back chevron `‹` + text **"结束训练"** in `#1A6B3C` (brand green), 17pt Regular
- **Center title**: **"训练总结"** in **22pt Bold, Rounded style**, color `#000000`
- **Right**: share icon (SF Symbol `square.and.arrow.up`) in `#1A6B3C`, 22pt
- Bar background: `#FFFFFF` with very subtle bottom border `rgba(60,60,67,0.15)`

---

#### Scrollable Content (background: `#F2F2F7`, 16pt horizontal page margins)

**Section 1 — Statistics Cards Grid** (top of content, 16pt top margin below nav bar):

A `2 × 3` grid of stat cards (2 columns, 3 rows — last row has one card spanning full width):

Card style: white `#FFFFFF`, corner radius **12pt**, padding 14pt, subtle shadow `0 2pt 8pt rgba(0,0,0,0.06)`.

Grid layout: 8pt gap between cards.

The 5 stat cards are:

**Card 1 — 训练时长** (top-left):
- Big number: **"48"** in **28pt Bold**, color `#000000`
- Unit: **"分钟"** in 13pt Regular, color `rgba(60,60,67,0.6)`, inline after the number
- Label below: **"训练时长"** in 13pt Regular, color `rgba(60,60,67,0.6)`
- Icon: clock SF Symbol at top-right corner, 18pt, color `#1A6B3C`

**Card 2 — 完成项目** (top-right):
- Big number: **"3"** in **28pt Bold**, color `#000000`
- Unit: **"项"** in 13pt Regular, color `rgba(60,60,67,0.6)`, inline
- Label: **"完成项目"** in 13pt Regular, color `rgba(60,60,67,0.6)`
- Icon: checklist SF Symbol at top-right, 18pt, color `#1A6B3C`

**Card 3 — 总组数** (middle-left):
- Big number: **"12"** in **28pt Bold**, color `#000000`
- Unit: **"组"** in 13pt Regular, inline
- Label: **"总组数"** in 13pt Regular, color `rgba(60,60,67,0.6)`
- Icon: square.grid.2x2 SF Symbol, 18pt, color `#1A6B3C`

**Card 4 — 总进球** (middle-right):
- Big number: **"87"** in **28pt Bold**, color `#000000`
- Unit: **"球"** in 13pt Regular, inline
- Label: **"总进球"** in 13pt Regular, color `rgba(60,60,67,0.6)`
- Icon: circle.fill SF Symbol (representing billiard ball), 18pt, color `#F5A623` (orange ball color)

**Card 5 — 平均成功率** (bottom row, FULL WIDTH spanning both columns):
- Big number: **"72"** in **28pt Bold**, color `#000000`
- Unit: **"%"** in 20pt Bold, inline, color `#1A6B3C`
- Label: **"平均成功率"** in 13pt Regular, color `rgba(60,60,67,0.6)`
- A thin horizontal progress bar below the number: 100% width of card interior, height 6pt, corner radius 3pt; filled portion `72%` in `#1A6B3C`, unfilled in `rgba(60,60,67,0.1)`
- Icon: chart.bar SF Symbol at top-right, 18pt, color `#1A6B3C`

---

**Section 2 — Drill Breakdown List** (16pt top margin below stats grid):

Section header row:
- **"训练明细"** in **17pt Bold**, color `#000000`, left-aligned

3 drill breakdown cards (one per Drill), each is a white `#FFFFFF` card, corner radius **12pt**, 16pt padding, 8pt gap between cards:

**Drill Card layout** (show 3 cards):

*Drill Card 1 — "定点红球进袋"*:
- **Top row** (full width):
  - Left: a small **BTBilliardTable thumbnail** square `56×56pt`, corner radius 10pt — showing simplified billiard table with cushion color `#7B3F00` border, felt color `#1B6B3A` fill, with a small white cue ball and orange target ball in diagonal positions. Use a simple CSS rounded rectangle for the table.
  - Right of thumbnail (8pt gap): 
    - Line 1: **"定点红球进袋"** in **17pt Semibold**, color `#000000`
    - Line 2: **"L1 入门"** — small pill badge: background `rgba(26,107,60,0.12)`, text `#1A6B3C`, 12pt Regular, corner radius 999pt (pill), 6pt horizontal padding, 4pt vertical padding
    - Line 3 (13pt Regular, `rgba(60,60,67,0.6)`): **"4 组 · 31/40 球"** (sets count · pockets/total)
  - Far right of top row: **"78%"** in **17pt Semibold**, color `#1A6B3C` (success rate)
- **Divider**: 1px line `rgba(60,60,67,0.12)`, full width, 10pt top margin
- **Set detail rows** below divider (each row: 32pt height, 10pt vertical padding):
  - Row header: "各组详情" in 12pt Regular, `rgba(60,60,67,0.5)`, 10pt top padding
  - 4 set rows:
    - **"第 1 组"** `rgba(60,60,67,0.6)` 14pt · **"8/10"** `#000000` 14pt · green checkmark SF Symbol `checkmark.circle.fill` 16pt `#1A6B3C` → all on one horizontal row, evenly spaced
    - **"第 2 组"** · **"7/10"** · checkmark (same style)
    - **"第 3 组"** · **"8/10"** · checkmark (same style)
    - **"第 4 组"** · **"8/10"** · checkmark (same style)

*Drill Card 2 — "斯诺克直线进袋"*:
- Same layout as Card 1
- Name: **"斯诺克直线进袋"**, badge: **"L0 基础"** (green pill), pocket data: **"3 组 · 28/30 球"**, success rate: **"93%"** (color `#1A6B3C`)
- 3 set rows: 10/10, 9/10, 9/10, all with checkmarks

*Drill Card 3 — "走位练习 A"*:
- Same layout
- Name: **"走位练习 A"**, badge: **"L2 中级"** (amber pill: background `rgba(212,148,26,0.12)`, text `#D4941A`), pocket data: **"5 组 · 28/50 球"**, success rate: **"56%"** (color `rgba(60,60,67,0.6)` since below 70%)
- 5 set rows: 6/10, 5/10, 6/10, 5/10, 6/10

---

**Section 3 — Training Notes** (16pt top margin, only show if there are notes):

A white `#FFFFFF` card, corner radius 12pt, 16pt padding:
- Header: quote SF Symbol `quote.opening` in `#1A6B3C` 18pt + **"训练心得"** 17pt Semibold black, on same row
- Body text below: "今天练习走位感觉明显进步，斯诺克直线进袋成功率很高，走位A还需要加强。" in 15pt Regular, color `rgba(60,60,67,0.8)`, 2 lines

---

**Bottom padding**: 100pt (to ensure content is not hidden behind fixed bottom buttons)

---

#### Bottom Action Area (FIXED to screen bottom, above tab bar)

A fixed bottom action panel, placed above the tab bar (not overlapping it):
- Background: white `#FFFFFF` with top border `rgba(60,60,67,0.12)` and top blur effect
- Total height: ~120pt, 16pt horizontal padding, 12pt vertical padding
- Safe area padding at bottom: handled by tab bar position

**Three stacked buttons** (top to bottom, 8pt gap):

**Button 1 — Primary "保存"**:
- Full width, height **50pt**, corner radius **12pt**
- Background: solid `#1A6B3C` (brand green), NO gradient
- Text: **"保存训练"** in **17pt Semibold**, color `#FFFFFF`
- Checkmark SF Symbol on left: `checkmark` 17pt white

**Button 2 — Secondary "生成分享图"**:
- Full width, height **44pt**, corner radius **12pt**
- Background: `#FFFFFF`, border: 1.5pt solid `#1A6B3C`
- Text: **"生成分享图"** in **17pt Regular**, color `#1A6B3C`
- share SF Symbol `square.and.arrow.up` on left: 17pt, color `#1A6B3C`

**Button 3 — Text "查看历史"**:
- Full width, height **36pt**, no background, no border
- Text: **"查看历史"** in **15pt Regular**, color `rgba(60,60,67,0.6)`, centered

---

#### Bottom Tab Bar

Standard 5-tab iOS tab bar at screen bottom:
- Background: `#FFFFFF`, top shadow
- Tabs: 训练 (selected, `#1A6B3C`) / 动作库 / 角度 / 记录 / 我的 (unselected `rgba(60,60,67,0.45)`)
- Icon size: 24pt, label: 10pt, each tab 44pt+ touch area
- Active tab uses brand green `#1A6B3C` for icon and text

---

## 帧 2 — TrainingShareView（训练分享卡定制页）

### Stitch 提示词（开启新对话，粘贴以下内容）

Design the **Training Share Card Screen** for an iOS billiards training app called "QiuJi" (球迹). This screen allows users to preview and customize a shareable training summary card before sharing it. iPhone screen (393 × 852pt), Light mode.

**Page structure:**
- Standard iOS **navigation bar** at top
- Scrollable area showing the **dark-theme share card preview** (takes up approximately the top 55% of the screen)
- A **fixed bottom panel** (sheet-like) with customization controls and share buttons
- The page background is `#F2F2F7`

**CRITICAL color rules:**
- Brand green is exactly `#1A6B3C`. Use this in your Tailwind config as `primary: "#1A6B3C"`. Do NOT use #005129 or any other green.
- Accent/gold: `#D4941A`
- Share card background (dark theme — "基础绿"): `#1C1C1E` with brand green accent elements
- Page background: `#F2F2F7`
- Card background: `#FFFFFF`
- Do NOT use gradients on buttons — all fills are solid flat color only.

**Overall style:**
- iOS native mobile app design (SF Pro font family feel, SF Symbols icons)
- The share card itself uses a DARK theme (dark background, light text) — this is intentional and is the key visual feature
- Canvas width: 393px (iPhone 15 Pro)

---

#### Status Bar

Standard iOS status bar: time left, signal/battery right. Height: 54pt.

---

#### Navigation Bar

- **Left**: chevron back + **"返回"** in `#1A6B3C`, 17pt Regular
- **Center title**: **"分享训练"** in **17pt Semibold**, color `#000000`
- **Right**: (empty or subtle more-options icon)
- Bar background: `#FFFFFF` with subtle bottom border

---

#### Share Card Preview Area (scrollable, 16pt horizontal margin)

A card that represents the SHAREABLE IMAGE the user will export. This card uses a DARK THEME:

**Outer container**: corner radius **16pt**, overflow hidden, shadow `0 8pt 24pt rgba(0,0,0,0.18)`

**Card background**: `#1C1C1E` (near-black, dark charcoal — the "基础绿" dark theme)

**Card width**: 361pt (full width minus 16pt margins on each side). **Card height**: approximately 480pt (tall card).

**Card internal layout** (16pt padding all sides):

*Card Header Row* (top of card, 14pt bottom margin):
- Left: app icon placeholder — rounded square 36×36pt, background `#1A6B3C`, corner radius 8pt, with "Q" text or billiard ball icon in white 18pt Bold inside
- Right of icon (10pt gap):
  - Line 1: **"QiuJi 球迹"** in **15pt Semibold**, color `#FFFFFF`
  - Line 2: **"2026年4月3日 · 台球训练"** in **12pt Regular**, color `rgba(255,255,255,0.55)`
- Far right: a small green accent dot or nothing

*Training Title Block* (below header, 14pt top margin):
- **"力量训练 Day 1"** in **22pt Bold Rounded**, color `#FFFFFF`
- **"共 3 项 · 48 分钟"** in **13pt Regular**, color `rgba(255,255,255,0.6)`, 4pt below title

*Thin divider line*: 1px, `rgba(255,255,255,0.12)`, full width, 14pt top margin

*Drill List Summary* (14pt top margin, 10pt gap between drill rows):
Show 3 drill rows inside the dark card:

Each drill row is a mini-card inside the dark card:
- Background: `rgba(255,255,255,0.06)` (subtle light overlay on dark)
- Corner radius: 8pt
- Padding: 10pt horizontal, 8pt vertical
- Layout: Left section: drill name in **14pt Semibold** white + set info in **12pt** `rgba(255,255,255,0.55)` below; Right section: success rate in **15pt Bold** colored text

Drill 1: Name **"定点红球进袋"** | Sets **"4组"** · `rgba(255,255,255,0.55)` 12pt | Rate **"78%"** in `#1A6B3C` green 15pt Bold
Drill 2: Name **"斯诺克直线进袋"** | **"3组"** | Rate **"93%"** in `#25A25A` (lighter green for high score) 15pt Bold
Drill 3: Name **"走位练习 A"** | **"5组"** | Rate **"56%"** in `rgba(255,255,255,0.45)` 15pt (dim for low score)

*Stats Row* (14pt top margin):
A horizontal row of 3 mini-stat blocks, evenly spaced, no borders between them:
- Block 1: number **"87"** in **22pt Bold** white + label **"总进球"** in 11pt `rgba(255,255,255,0.55)` below
- Block 2: number **"12"** in **22pt Bold** white + label **"总组数"** below
- Block 3: number **"72%"** in **22pt Bold** `#25A25A` + label **"平均成功率"** below
Add subtle vertical dividers `rgba(255,255,255,0.12)` between blocks.

*Card Footer / Brand Area* (thin divider above it, then):
- Background slightly darker: `rgba(0,0,0,0.2)`, full width, 14pt top margin from stats row
- Left section: 
  - **"QiuJi 球迹"** in 13pt Bold white
  - **"台球训练记录 App"** in 11pt `rgba(255,255,255,0.5)`
- Right section: a QR code placeholder — 44×44pt square, background `rgba(255,255,255,0.9)`, corner radius 4pt, with a simple grid pattern suggesting a QR code (just a small rounded square with inner grid dots), to the right side of the footer
- All in `#1A6B3C` brand green accent: a small vertical left border strip 3pt wide on the very left edge of footer

---

#### Customization Controls Panel (FIXED BOTTOM SHEET)

A fixed panel at the bottom of the screen, above the safe area. Background: `#FFFFFF`, top corner radius **20pt**, top shadow `0 -4pt 16pt rgba(0,0,0,0.1)`.

Panel total height: approximately 200pt.

Inside the panel (16pt horizontal padding, 16pt top padding, 12pt bottom padding), three rows:

**Row 1 — 字体** (font selection):
- Left label: **"字体"** in 15pt Regular, color `rgba(60,60,67,0.6)`, width ~36pt
- Right side: `BTTogglePillGroup` — two pill buttons in a row (8pt gap):
  - Pill A: **"跟随系统"** — currently SELECTED: background `#1A6B3C`, text `#FFFFFF`, 15pt Regular, height 32pt, horizontal padding 14pt, corner radius 999pt (pill)
  - Pill B: **"圆角字体"** — unselected: background `#F2F2F7`, text `rgba(60,60,67,0.6)`, 15pt Regular, same size
- 14pt bottom margin

**Row 2 — 颜色** (color theme, horizontal scroll):
- Left label: **"颜色"** in 15pt Regular, color `rgba(60,60,67,0.6)`, width ~36pt
- Right side: horizontal row of 4 color theme chips (10pt gap, scrollable):
  - Chip 1 — **"基础绿"** (SELECTED): small circle 28×28pt solid `#1C1C1E` (dark) with a thin `#1A6B3C` green border ring outside, 2pt border-offset; below circle: label **"基础绿"** in 11pt, color `#000000`; selection indicator: `#1A6B3C` checkmark below label
  - Chip 2 — **"黑白"**: circle `#1C1C1E` left half / `#FFFFFF` right half; label **"黑白"** in 11pt `rgba(60,60,67,0.6)`
  - Chip 3 — **"暗夜蓝"**: circle `#0D1B2A` solid; label **"暗夜蓝"** 11pt `rgba(60,60,67,0.6)`
  - Chip 4 — **"更多"**: circle `#F2F2F7` with `+` symbol in center `rgba(60,60,67,0.5)`; label **"更多"** 11pt
- 14pt bottom margin

**Row 3 — 选项** (toggle options):
- Left label: **"选项"** in 15pt Regular, color `rgba(60,60,67,0.6)`, width ~36pt
- Right side: `BTTogglePillGroup` — three toggle pill buttons (8pt gap, may wrap to next line):
  - **"隐藏备注"** — unselected (off state): background `#F2F2F7`, text `rgba(60,60,67,0.6)`, 15pt Regular, 32pt height, pill corner radius
  - **"隐藏成功率"** — unselected: same style
  - **"隐藏球台图"** — unselected: same style
  - (Unselected pills use `#F2F2F7` background + gray text; if selected, use `#1A6B3C` bg + white text — all currently unselected/off)

---

#### Share Targets Row (below customization panel, still inside fixed bottom area)

A separate row, 16pt top margin from options row, 8pt bottom margin before safe area:
- **Left section** (flex-grow): three circular share buttons (horizontal, 32pt gap between centers):
  - Button 1: circle 52×52pt, background `#07C160` (WeChat green), white icon (chat bubble with WeChat feel), label **"微信好友"** in 11pt `rgba(60,60,67,0.6)` below, 6pt gap
  - Button 2: circle 52×52pt, background `#07C160` slightly lighter or moments icon, label **"朋友圈"** in 11pt `rgba(60,60,67,0.6)` below
  - Button 3: circle 52×52pt, background `#1A6B3C`, white download SF Symbol `arrow.down.to.line`, label **"保存相册"** in 11pt `rgba(60,60,67,0.6)` below
- **Right section**: a secondary "返回" button
  - Text **"返回"** in 15pt Regular, color `rgba(60,60,67,0.6)`, no background, vertically centered in the row

---

## 参考截图使用说明

将以下截图附加到对应 Stitch 对话中（可选但推荐）：

| 帧 | 推荐截图 | 说明 |
|----|---------|------|
| 帧 1（TrainingSummaryView）| `ref-screenshots/02-training-active/07-training-summary.png` | 布局参考：运动训练 App 总结页的数据卡片 + 列表风格 |
| 帧 2（TrainingShareView）| `ref-screenshots/02-training-active/07-training-summary.png` | 分享定制控件（字体/颜色/选项）底部面板布局参考 |
| 帧 2（TrainingShareView）| `ref-screenshots/02-training-active/08-training-summary-scrolled.png` | 分享目标按钮行（微信/朋友圈/保存）布局参考 |

---

## 一致性声明

> 此任务的两帧页面应与 P0-01~P0-05 保持一致的视觉风格：品牌绿 `#1A6B3C`、卡片白 `#FFFFFF`、页面背景 `#F2F2F7`、按钮圆角 12pt、卡片圆角 12~16pt、iOS 原生导航栏风格。
