# Stitch Prompt — P1-10: StatisticsView (Pro 锁定态 — 全遮罩)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode only.

## Screen: StatisticsView — Pro Locked State (Full Overlay)

This is the same Statistics page as the data-filled version, but the user is a FREE-tier user. The entire statistics module is a Pro-only feature. The page should clearly show "this is a statistics dashboard" through visible chart silhouettes and layout structure, but all specific data values are hidden. A semi-transparent frosted overlay covers the content area, with a gradient that becomes more opaque toward the bottom. A prominent gold upgrade CTA is centered on the overlay. The goal is to tease the value of statistics to motivate the user to upgrade.

## Layout (top to bottom)

### 1. iOS Large Title Navigation Bar

- Large title text: "记录"
- Font: 34pt Bold Rounded, color #000000, on #F2F2F7 background
- Standard iOS large title behavior — sits below status bar with generous top padding
- No right-side icon buttons (consistent with P1-07/P1-09)

### 2. BTSegmentedTab (History | Statistics)

- 16pt horizontal margins, 12pt below the navigation bar title
- Two horizontal text tabs: "历史" and "统计"
- Each tab label: 16pt Medium
- **Active tab "统计"**: text color brand green #1A6B3C, with a 2pt-thick brand green #1A6B3C underline indicator directly below the text
- **Inactive tab "历史"**: text color rgba(60,60,67,0.6), no underline
- Tab spacing: 24pt between the two labels
- Left-aligned (not centered across full width)

### 3. Time Range Selector Row

- 12pt top gap from the segmented tab
- 16pt horizontal margins
- A horizontal row of pill-shaped buttons
- 5 pills: "周" (active) | "月" | "年" | "自定时间" | "设置"
- **Active pill "周"**: white #FFFFFF background, 1pt border brand green #1A6B3C, text brand green #1A6B3C 14pt Semibold
- **Inactive pills**: rgba(60,60,67,0.06) background, no border, text rgba(60,60,67,0.6) 14pt Regular
- Pill height: 32pt, corner radius 999pt (full pill), horizontal padding 14pt
- "设置" pill has a SF Symbol "gearshape" icon (13pt) before the text

> **Everything above (sections 1-3) renders normally — no blur, no overlay.**
> **Everything below (sections 4-7) is covered by the frosted lock overlay.**

### 4. Training Overview Card — LOCKED (partially visible through frost)

- Same card layout as the data-filled version but all numbers are replaced:
  - Where "5" (big number) would be → show "—" in 40pt Bold, color rgba(0,0,0,0.15)
  - Where "本周训练数" label would be → still show the label text in rgba(60,60,67,0.3)
  - Category breakdown row: show placeholder bars (short horizontal lines) in rgba(60,60,67,0.1) instead of category text
  - Mini bar chart on right: show bar silhouettes in rgba(26,107,60,0.08) — shapes visible but very faint, no value labels
- White #FFFFFF card, corner radius 16pt, 16pt internal padding
- Section header: "训练概况" — 17pt Bold, color rgba(26,107,60,0.3) (faded brand green — locked feel)

### 5. Training Duration Chart Card — LOCKED (heavily blurred)

- Card outline visible: white #FFFFFF card, corner radius 16pt
- Section title: "训练时长" — 17pt Bold, rgba(26,107,60,0.3) (faded)
- Inside the card: show faint bar chart silhouettes — 8 amber-tinted ghost bars in rgba(245,166,35,0.08), varying heights to suggest a chart exists
- No actual numbers, no trend line, no legend text visible
- A subtle frosted glass effect (backdrop-filter: blur) over this entire card

### 6. Category Success Rate Card — LOCKED (mostly hidden by gradient)

- Only the top edge of this card is barely visible through heavy blur
- The rest fades into a strong white-to-transparent gradient that obscures the remaining content

### 7. Pro Lock Overlay (centered on the content area)

This overlay sits on top of sections 4-6, with a gradient that goes from light frost at the top (allowing section 4 to be partially visible) to heavy white frost at the bottom.

#### Gradient overlay:
- Top of overlay (at section 4 top): rgba(242,242,247,0.3) — light frost, card shapes visible
- Middle (at section 5): rgba(242,242,247,0.65) — medium frost, only silhouettes
- Bottom (section 6 onward): rgba(242,242,247,0.9) — near-opaque, content barely visible

#### Lock icon (centered horizontally, positioned at roughly 55% vertical of the content area):
- Circular amber container: 72pt diameter circle
- Container fill: #FFDDAF (light amber, per P1-04 established pattern)
- Lock icon inside: SF Symbol "lock.fill", 32pt, color #D4941A (deep gold)
- 2pt subtle border: rgba(212,148,26,0.2) around the circle

#### Prompt text (16pt below lock icon):
- Line 1: "统计功能为 Pro 专属" — 17pt Semibold, #000000
- Line 2: "升级 Pro 解锁训练统计、趋势图表和分类对比" — 14pt Regular, rgba(60,60,67,0.6)
- Both lines center-aligned, max width 300pt

#### Upgrade CTA button (16pt below prompt text):
- Gold filled capsule button (full overlay mode uses FILLED button per A-04 decision)
- Background: #D4941A (Pro gold)
- Text: "解锁 Pro" — 17pt Semibold, #FFFFFF
- SF Symbol "crown.fill" icon (15pt, white) to the left of text, 6pt gap
- Button height: 50pt, horizontal padding: 32pt, corner radius: 999pt (pill)
- Subtle shadow: 0 4pt 12pt rgba(212,148,26,0.3)

### 8. Bottom Safe Area + Tab Bar

- Tab bar is fixed at bottom, fully visible (NOT covered by overlay)

#### Five-Tab Bottom Bar (Fixed):
- 5 tabs: 训练 | 动作库 | 角度 | **记录** | 我的
- **Active tab "记录"**: icon + text in brand green #1A6B3C
- Inactive tabs: icon + text in gray rgba(60,60,67,0.6)
- Tab bar background: white with subtle top border
- Tab bar height: ~49pt (standard iOS)
- Tab icons (SF Symbols): "figure.run" | "books.vertical" | "angle" | "calendar" | "person"

## Design Tokens

- Primary color: #1A6B3C (billiard table green)
- Pro/Premium gold: #D4941A
- Light amber container: #FFDDAF
- Chart bar amber (ghost): rgba(245,166,35,0.08)
- Chart bar green (ghost): rgba(26,107,60,0.08)
- Page background: #F2F2F7
- Card background: #FFFFFF
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Text tertiary: rgba(60,60,67,0.3)
- Locked text: rgba(0,0,0,0.15)
- Locked section title: rgba(26,107,60,0.3)
- Overlay frost top: rgba(242,242,247,0.3)
- Overlay frost mid: rgba(242,242,247,0.65)
- Overlay frost bottom: rgba(242,242,247,0.9)
- Large title font: 34pt Bold Rounded
- Section title font: 17pt Bold
- Body font: 17pt Regular
- Caption font: 13pt Regular
- Card corner radius: 16pt
- Pill corner radius: 999pt
- Lock circle: 72pt diameter
- CTA button height: 50pt
- CTA corner radius: 999pt (pill)
- Page horizontal padding: 16pt
- Card internal padding: 16pt

## Reference Style

- The top navigation structure (large title "记录" + BTSegmentedTab + time range pills) is identical to P1-09 StatisticsView with data — the user can clearly see they are on the Statistics tab
- The locked content area takes inspiration from premium paywall patterns in fitness apps — enough content shape visible to convey value, but all actual data hidden behind a frosted overlay
- The lock icon uses the circular amber container pattern established in P1-04 DrillDetailView Pro lock — consistent Pro lock visual language
- The gold filled CTA button follows the A-04 "full overlay = filled button" decision, distinct from the progressive lock's outline button
- The gradient overlay creates a natural top-to-bottom reveal: the user sees the structure (cards, chart shapes) fading into a lock prompt, creating curiosity and upgrade motivation

## Consistency Notes

- Navigation header identical to P1-07 and P1-09 — same "记录" large title + BTSegmentedTab with "统计" active
- Lock icon amber circle (#FFDDAF + #D4941A) matches P1-04 established pattern
- Gold filled CTA button matches A-04 full overlay mode decision
- "解锁 Pro" wording consistent with P1-04 bottom bar CTA
- 5-tab bottom bar matches all previous screens with "记录" as active tab
- Time range selector pills identical to P1-09 — functional elements remain normal above the lock

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- iOS native feel: SF Pro font family, SF Symbols icons throughout
- The frosted overlay must NOT cover the navigation bar, tab selector, time range pills, or bottom tab bar — only the chart content area
- The lock overlay gradient should feel like iOS frosted glass (not a flat semi-transparent color)
- Chart card shapes (rounded rectangles) must be visible through the frost — the user should recognize "this is a statistics page with charts"
- But NO actual data values (numbers, percentages, dates) should be readable
- The gold lock icon must be the clear visual focal point of the page
- The CTA button must be FILLED gold #D4941A (not outline) — this is a full overlay lock, not progressive
- Crown icon on the CTA button reinforces the premium/Pro branding
- All text in Simplified Chinese
- The "记录" tab in the bottom bar must be highlighted in brand green #1A6B3C
- NO gradient fills on cards or buttons (except the overlay frost effect itself)
- Minimum touch target 44pt for CTA button

## State

Pro locked state (full overlay): The user is a free-tier user viewing the Statistics tab for the first time. The entire statistics module is locked behind Pro subscription. The page structure and chart silhouettes are faintly visible through a frosted gradient overlay, creating a "preview" effect. A gold lock icon, explanatory text, and a prominent gold "解锁 Pro" CTA button are centered on the overlay, encouraging the user to upgrade. The time range selector at the top is visible but non-functional (decorative only in this state). This is a conversion-focused screen designed to show value without giving away data.
