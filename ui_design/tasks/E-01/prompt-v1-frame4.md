# Stitch Prompt — E-01 帧4: TrainingSummaryView Dark Mode

> 任务 ID: E-01 | 帧: 4/5 | 版本: v1 | 日期: 2026-04-05
> Light Mode 基准: P0-06 帧1 v2 (`tasks/P0-06/stitch_task_p0_06_trainingsummaryview_02/screen.png`)
> 标准页面模式：导航栏 + Tab 栏 + 滚动内容
> P0-06 决策 1: 统计卡片自适应高度 | 决策 3: 底部三级按钮层级
> 注意: TrainingShareView (帧2) 自身已是深色主题，不做 Dark Mode 变体

---

## Stitch 提示词（开启新对话，粘贴以下内容）

Design the **Dark Mode variant** of the Training Summary screen for an iOS billiards training app called "QiuJi" (球迹). This is a standard scrollable page showing training statistics and drill breakdowns after completing a session. iPhone screen (393 × 852pt), **Dark mode**.

**CRITICAL: This is a color-mapping exercise. The layout, spacing, element positions, and content must be IDENTICAL to the attached light mode screenshot. Only colors change.**

**This is a standard iOS page (Dark Mode):**
- Standard iOS navigation bar at the top (dark background, white text)
- Standard 5-tab bottom tab bar (dark background)
- Page background: `#000000` (pure black, OLED)

**CRITICAL color rules (Dark Mode):**
- Brand green is `#25A25A`. Use this in your Tailwind config as `primary: "#25A25A"`. Do NOT use #1A6B3C or #005129.
- Page background: `#000000`
- Card/container background: `#1C1C1E`
- Text primary: `#FFFFFF`
- Text secondary: `rgba(235,235,240,0.6)`
- Text tertiary: `rgba(235,235,240,0.3)`
- Separator/border: `#38383A`
- Do NOT use gradients — solid flat fills only.
- Do NOT use drop shadows on cards — color contrast layering only.

**Overall style:**
- iOS native mobile app design (SF Pro font family, SF Symbols icons)
- Professional, data-focused training summary — Dark Mode
- White status bar text (light content style)
- Canvas width: 393px (iPhone 15 Pro)

---

### Status Bar

iOS status bar with **white text** (light content style). Height: 54pt.

---

### Navigation Bar (Dark Mode)

- **Left**: back chevron `‹` + **"结束训练"** in `#25A25A` (brand green Dark), 17pt Regular
- **Center**: **"训练总结"** in **22pt Bold Rounded**, color `#FFFFFF`
- **Right**: share icon `square.and.arrow.up` in `#25A25A`, 22pt
- Bar background: `#000000` blending with page, subtle bottom border `#38383A` (0.5pt)

---

### Scrollable Content (background: `#000000`, 16pt horizontal margins)

**Section 1 — Statistics Cards Grid** (16pt top margin):

A `2 × 3` grid (2 cols, 3 rows, last row full-width), 8pt gaps.

Card style: background `#1C1C1E`, corner radius **12pt**, padding 14pt, **NO shadow**.

**Card 1 — 训练时长** (top-left):
- Number: **"48"** in **28pt Bold** `#FFFFFF`
- Unit: **"分钟"** in 13pt Regular `rgba(235,235,240,0.6)`, inline
- Label: **"训练时长"** in 13pt Regular `rgba(235,235,240,0.6)`
- Icon: clock SF Symbol, 18pt, `#25A25A`

**Card 2 — 完成项目** (top-right):
- Number: **"3"** in **28pt Bold** `#FFFFFF`
- Unit: **"项"** 13pt `rgba(235,235,240,0.6)`
- Label: **"完成项目"** 13pt `rgba(235,235,240,0.6)`
- Icon: checklist, 18pt, `#25A25A`

**Card 3 — 总组数** (mid-left):
- Number: **"12"** in **28pt Bold** `#FFFFFF`
- Unit: **"组"** 13pt inline
- Label: **"总组数"** 13pt `rgba(235,235,240,0.6)`
- Icon: grid, 18pt, `#25A25A`

**Card 4 — 总进球** (mid-right):
- Number: **"87"** in **28pt Bold** `#FFFFFF`
- Unit: **"球"** 13pt inline
- Label: **"总进球"** 13pt `rgba(235,235,240,0.6)`
- Icon: circle.fill, 18pt, `#F5A623` (orange ball — unchanged)

**Card 5 — 平均成功率** (full-width bottom):
- Number: **"72"** in **28pt Bold** `#FFFFFF`
- Unit: **"%"** in 20pt Bold `#25A25A` inline
- Label: **"平均成功率"** 13pt `rgba(235,235,240,0.6)`
- Progress bar: height 6pt, radius 3pt; filled 72% in `#25A25A`, unfilled `#3A3A3C`
- Icon: chart.bar, 18pt, `#25A25A`

---

**Section 2 — Drill Breakdown List** (16pt top margin):

Header: **"训练明细"** in **17pt Bold** `#FFFFFF`

3 cards, `#1C1C1E` background, radius **12pt**, 16pt padding, 8pt gaps:

*Card 1 — "定点红球进袋"*:
- Thumbnail: 56×56pt billiard table, radius 10pt, felt `#144D2A`, rail `#5C2E00`, cue `#F5F5F5`, target `#F5A623`
- Name: **"定点红球进袋"** 17pt Semibold `#FFFFFF`
- Badge: "L1 入门" pill — bg `rgba(37,162,90,0.15)`, text `#25A25A`
- Info: **"4 组 · 31/40 球"** 13pt `rgba(235,235,240,0.6)`
- Rate: **"78%"** 17pt Semibold `#25A25A`
- Divider: `#38383A` (1px)
- Set rows (32pt height each):
  - "第 1 组" `rgba(235,235,240,0.6)` 14pt · "8/10" `#FFFFFF` 14pt · checkmark `#25A25A` 16pt
  - "第 2 组" · "7/10" · checkmark
  - "第 3 组" · "8/10" · checkmark
  - "第 4 组" · "8/10" · checkmark

*Card 2 — "斯诺克直线进袋"*:
- Same layout. Rate: **"93%"** `#25A25A`. Badge: "L0 基础" green pill.
- 3 sets: 10/10, 9/10, 9/10 with checkmarks

*Card 3 — "走位练习 A"*:
- Badge: "L2 中级" amber pill — bg `rgba(240,173,48,0.15)`, text `#F0AD30`
- Rate: **"56%"** `rgba(235,235,240,0.6)` (dim for <70%)
- 5 sets: 6/10, 5/10, 6/10, 5/10, 6/10

---

**Section 3 — Training Notes** (16pt top margin):

Card `#1C1C1E`, radius 12pt, 16pt padding:
- Header: quote icon `#25A25A` 18pt + **"训练心得"** 17pt Semibold `#FFFFFF`
- Body: "今天练习走位感觉明显进步，斯诺克直线进袋成功率很高，走位A还需要加强。" 15pt Regular `rgba(235,235,240,0.8)`

---

**Bottom padding**: 100pt (space for fixed buttons)

---

### Bottom Action Area (FIXED, above tab bar)

Background `#1C1C1E`, top border `#38383A` (0.5pt), 16pt horizontal padding, 12pt vertical:

**Button 1 — Primary "保存"**:
- Full width, 50pt height, radius 12pt
- Background: `#25A25A` solid (brand green Dark)
- Text: **"保存训练"** 17pt Semibold `#FFFFFF`
- Left: checkmark icon 17pt white

**Button 2 — Secondary "生成分享图"**:
- Full width, 44pt height, radius 12pt
- Background: transparent, border 1.5pt `#25A25A`
- Text: **"生成分享图"** 17pt Regular `#25A25A`
- Left: share icon 17pt `#25A25A`

**Button 3 — Text "查看历史"**:
- Full width, 36pt, no bg, no border
- Text: **"查看历史"** 15pt Regular `rgba(235,235,240,0.6)`, centered

---

### Bottom Tab Bar (Dark Mode)

Background: `#1C1C1E` (or semi-transparent `rgba(28,28,30,0.94)` + blur), top separator `#38383A` (0.5pt):
- "训练" (**active**, `#25A25A`)
- "动作库" / "角度" / "记录" / "我的" (inactive, `rgba(235,235,240,0.6)`)
- Icon 24pt, label 10pt

---

### Design Tokens Summary (Dark Mode)

| Token | Dark Mode Value |
|-------|----------------|
| Primary (brand green) | `#25A25A` — USE THIS EXACTLY |
| Accent (gold) | `#F0AD30` |
| Background | `#000000` |
| Card / container | `#1C1C1E` |
| Tertiary bg | `#2C2C2E` |
| Quaternary / unfilled | `#3A3A3C` |
| Text primary | `#FFFFFF` |
| Text secondary | `rgba(235,235,240,0.6)` |
| Text tertiary | `rgba(235,235,240,0.3)` |
| Separator | `#38383A` |
| Table felt (dark) | `#144D2A` |
| Table cushion (dark) | `#5C2E00` |
| Ball orange | `#F5A623` |
| Card radius | 12pt |
| Button radius | 12pt |
| Padding | 16pt |
| Min touch target | 44pt |

---

### Constraints

- Standard page with nav bar + tab bar (both in dark)
- Stat cards are data-focused: big numbers in white on `#1C1C1E` cards, NO shadows, color-layer contrast only
- Green stat icons (#25A25A) pop against dark card backgrounds
- Progress bar unfilled portion uses `#3A3A3C` (visible on #1C1C1E)
- Three-level button hierarchy clear in Dark Mode: green fill → green outline → gray text
- L2 amber badge uses Dark accent `#F0AD30` (not light mode's #D4941A)
- Layout pixel-identical to light mode

---

### State

Dark Mode variant of the training summary after completing a session. 48 minutes, 3 drills, 12 sets, 87 balls, 72% avg success rate. One drill >90% (green), one ~78% (green), one 56% (dim gray). Training notes present. Layout identical to light mode — colors mapped to Dark tokens.

---

## 推荐附加参考截图

**必须附加：**
1. **`tasks/P0-06/stitch_task_p0_06_trainingsummaryview_02/screen.png`** — Light Mode 已通过版本

**可选附加：**
2. `tasks/E-01/stitch_task_*/screen.png` — 已完成的 E-01 帧（Dark Mode 风格基准）

> 提示："Recreate this exact training summary layout in Dark Mode. All stat cards use #1C1C1E backgrounds, no shadows. Green icons and accents use #25A25A."

## TrainingShareView 说明

P0-06 帧2 TrainingShareView 的分享卡预览区自身已是深色主题（`#1C1C1E` 背景 + 白色/绿色文字），无需单独生成 Dark Mode 变体。定制面板部分在 Dark Mode 下的适配属于开发实现范畴（底部 Sheet 自动继承系统深色模式），不在 Stitch 设计稿范围内。

## Stitch 导出处理

1. 导出文件夹保存到 `tasks/E-01/`
2. 完成后说 **"生成提示词 E-01 帧5"** 继续最后一帧（PlanListView + PlanDetailView Dark Mode）
