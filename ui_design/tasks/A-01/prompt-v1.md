# Stitch Prompt — A-01: Design Token Visual Sheet

> 任务 ID: A-01 | 版本: v1 | 日期: 2026-04-03

---

## Stitch 提示词（复制以下内容到 Google Stitch）

Design a **Design Token reference sheet** for a billiards training iOS app called "QiuJi" (球迹). This is a single-page visual inventory showing all color tokens, typography scale, spacing system, and corner radius tokens used in the app. Light mode only.

**Layout (top to bottom):**

### Section 1: Color Palette (top area)

**Row 1 — Brand & Functional Colors** (6 color swatches in a horizontal row):
- Each swatch is a 60x60pt rounded rectangle with the color fill, token name below (12pt gray text), and hex value (11pt lighter gray)
- btPrimary: #1A6B3C (billiard green) — labeled "Brand Primary"
- btPrimaryMuted: #1A6B3C at 10% opacity — labeled "Primary Muted"
- btAccent: #D4941A (amber/gold) — labeled "Accent/Pro"
- btSuccess: #2E7D32 — labeled "Success"
- btWarning: #E65100 — labeled "Warning"
- btDestructive: #C62828 — labeled "Destructive"

**Row 2 — Background Colors** (4 swatches):
- btBG: #F2F2F7 — labeled "Page BG"
- btBGSecondary: #FFFFFF — labeled "Card BG"
- btBGTertiary: #F2F2F7 — labeled "Tertiary BG"
- btBGQuaternary: #E5E5EA — labeled "Quaternary"

**Row 3 — Text & Separator** (4 swatches, use dark fill with white text for text colors):
- btText: #000000 — labeled "Text Primary"
- btTextSecondary: rgba(60,60,67,0.6) — labeled "Text Secondary"
- btTextTertiary: rgba(60,60,67,0.3) — labeled "Text Tertiary"
- btSeparator: #C6C6C8 — labeled "Separator"

**Row 4 — Billiard Table Colors** (7 swatches):
- btTableFelt: #1B6B3A — labeled "Table Felt"
- btTableCushion: #7B3F00 — labeled "Cushion"
- btTablePocket: #1A1A1A — labeled "Pocket"
- btBallCue: #F5F5F5 (with thin gray border) — labeled "Cue Ball"
- btBallTarget: #F5A623 — labeled "Target Ball"
- btPathCue: white at 60% — labeled "Cue Path"
- btPathTarget: #F5A623 at 70% — labeled "Target Path"

### Section 2: Typography Scale (middle area)

Display each of the 13 font levels as a single line of sample text, stacked vertically. Each line shows the actual font size/weight and a label on the right:
- "Aa 球迹" in btDisplay: 48pt Bold Rounded — right label: "Display 48/Bold/Rounded"
- "Aa 球迹" in btLargeTitle: 34pt Bold Rounded — "LargeTitle 34/Bold/Rounded"
- "Aa 球迹" in btTitle: 22pt Bold Rounded — "Title 22/Bold/Rounded"
- "Aa 球迹" in btTitle2: 20pt Semibold — "Title2 20/Semi"
- "Aa 球迹" in btHeadline: 17pt Semibold — "Headline 17/Semi"
- "Aa 球迹" in btBody: 17pt Regular — "Body 17/Reg"
- "Aa 球迹" in btBodyMedium: 17pt Medium — "BodyMed 17/Med"
- "Aa 球迹" in btCallout: 16pt Regular — "Callout 16/Reg"
- "Aa 球迹" in btSubheadline: 15pt Regular — "Subhead 15/Reg"
- "Aa 球迹" in btSubheadlineMedium: 15pt Medium — "SubheadMed 15/Med"
- "Aa 球迹" in btFootnote: 13pt Regular — "Footnote 13/Reg"
- "Aa 球迹" in btCaption: 12pt Regular — "Caption 12/Reg"
- "Aa 球迹" in btCaption2: 11pt Medium — "Caption2 11/Med"

The top 3 lines (Display, LargeTitle, Title) should visually show rounded font style.

### Section 3: Spacing System (bottom-left area)

Show 8 horizontal bars of increasing width, each labeled with the token name and pt value:
- xs: 4pt bar
- sm: 8pt bar
- md: 12pt bar
- lg: 16pt bar
- xl: 20pt bar
- xxl: 24pt bar
- xxxl: 32pt bar
- xxxxl: 48pt bar

Each bar uses btPrimary (#1A6B3C) fill, height 16pt, with the token name left-aligned and pt value right of the bar.

### Section 4: Corner Radius (bottom-right area)

Show 6 rounded rectangles (80x50pt each) demonstrating each radius level:
- xs: 6pt radius — labeled "xs 6pt"
- sm: 8pt radius — labeled "sm 8pt"
- md: 12pt radius — labeled "md 12pt"
- lg: 16pt radius — labeled "lg 16pt"
- xl: 20pt radius — labeled "xl 20pt"
- full: fully rounded pill — labeled "full (pill)"

Each rectangle has a light green (#1A6B3C at 15%) fill and green (#1A6B3C) border.

**Overall design:**
- Page background: #F2F2F7
- Content cards: white #FFFFFF, 16pt corner radius, 16pt padding
- Each section has a section title in 22pt Bold Rounded, green #1A6B3C
- Clean, minimal iOS design system documentation style
- SF Pro and SF Pro Rounded fonts
- Total page fits an iPhone 15 Pro screen (393x852pt) with scrolling

---

## 使用说明

1. 将上方提示词复制到 Google Stitch
2. 无需附加参考截图（这是纯 Token 展示）
3. 生成后将截图保存到 `tasks/A-01/screenshot-v1.png`
4. 然后说"审核 A-01"触发审核智能体
