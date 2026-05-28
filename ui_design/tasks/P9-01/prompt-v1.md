# Stitch Prompt — P9-01 Frame 1: AngleHomeView Redesign (Light Mode)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode.

## Screen: AngleHomeView — Angle Training Home (Redesigned)

This is the "角度" (Angle) tab — the third tab in the app's 5-tab bottom navigation. Previously this page had only 3 entries; it is now redesigned to present 7 feature entries + 1 history shortcut, organized into 3 category sections (学习/训练/工具). The user comes here to access various angle training and learning features. This is a scrollable navigation hub page — clean, organized, with clear section grouping. Default state, light mode.

## Layout (top to bottom)

### 1. iOS Large Title Navigation Bar

- Large title text: "角度训练"
- Font: 34pt Bold Rounded, color #000000, on #F2F2F7 background
- Standard iOS large title behavior — sits below status bar with generous top padding
- **No right-side icon buttons** (this tab has no auxiliary functions — established design decision)

### 2. Section: "学习" (Learning) — 3 Feature Cards

Section header label "学习" in 13pt Semibold UPPERCASE-style, color #1A6B3C (brand green), 16pt left margin, 8pt bottom margin to first card.

All cards use the **identical FeatureCard pattern**: white (#FFFFFF) background, corner radius 16pt, 16pt internal padding, full width minus 16pt margins on each side. Card gap: 10pt vertical.

#### Card 2a: "瞄准原理" (Aiming Principle)

- **Left icon area**: 48pt circle, fill rgba(26,107,60,0.12), centered SF Symbol "lightbulb.max" 24pt in #1A6B3C
- **Center text area** (12pt left gap from icon):
  - Title: "瞄准原理" 17pt Semibold, color #000000
  - Subtitle: "切入角、假想球法、厚薄球概念" 13pt Regular, color rgba(60,60,67,0.6), 2pt below title
- **Right**: chevron "chevron.right" 13pt, color rgba(60,60,67,0.3), vertically centered

#### Card 2b: "角度与打点" (Angle & Contact)

- Same card style as 2a
- Left icon: 48pt circle rgba(26,107,60,0.12), SF Symbol "arrow.triangle.branch" 24pt in #1A6B3C
- Title: "角度与打点" 17pt Semibold #000000
- Subtitle: "角度/接触点/厚薄球动态关系" 13pt rgba(60,60,67,0.6)
- Right: chevron

#### Card 2c: "浅淡球感" (Ball Feel)

- Same card style as 2a
- Left icon: 48pt circle rgba(26,107,60,0.12), SF Symbol "hand.point.up.braille" 24pt in #1A6B3C
- Title: "浅淡球感" 17pt Semibold #000000
- Subtitle: "从理性分析到直觉判断" 13pt rgba(60,60,67,0.6)
- Right: chevron

### 3. Section: "训练" (Training) — 3 Feature Cards

Section header "训练" — same style as "学习" header: 13pt Semibold #1A6B3C, 24pt top gap from last card in previous section.

#### Card 3a: "几何角度训练" (Geometric Angle Quiz)

- Same FeatureCard pattern
- Left icon: 48pt circle rgba(26,107,60,0.12), SF Symbol "ruler" 24pt in #1A6B3C
- Title: "几何角度训练" 17pt Semibold #000000
- Subtitle: "纯几何角度预测练习" 13pt rgba(60,60,67,0.6)
- Right: chevron

#### Card 3b: "球台角度预测" (Table Angle Prediction)

- Same FeatureCard pattern
- Left icon: 48pt circle rgba(26,107,60,0.12), SF Symbol "cube.transparent" 24pt in #1A6B3C
- Title: "球台角度预测" 17pt Semibold #000000
- Subtitle: "2D/3D 球台场景训练" 13pt rgba(60,60,67,0.6)
- **Special**: a small badge/tag to the right of the subtitle text — "2D/3D" label in a tiny pill shape: background rgba(26,107,60,0.12), text #1A6B3C 11pt Semibold, horizontal padding 6pt, corner radius 4pt
- Right: chevron

#### Card 3c: "角度测试" (Angle Test)

- Same FeatureCard pattern (preserved from existing design)
- Left icon: 48pt circle rgba(26,107,60,0.12), SF Symbol "scope" 24pt in #1A6B3C
- Title: "角度测试" 17pt Semibold #000000
- Subtitle: "训练角度视觉感知" 13pt rgba(60,60,67,0.6)
- Right: chevron

### 4. Section: "工具" (Tools) — 1 Feature Card

Section header "工具" — same style: 13pt Semibold #1A6B3C, 24pt top gap.

#### Card 4a: "进球点对照表" (Contact Point Table)

- Same FeatureCard pattern (preserved from existing design)
- Left icon: 48pt circle rgba(26,107,60,0.12), SF Symbol "tablecells" 24pt in #1A6B3C
- Title: "进球点对照表" 17pt Semibold #000000
- Subtitle: "角度与接触点对照" 13pt rgba(60,60,67,0.6)
- Right: chevron

### 5. History Entry Row

- 24pt top gap from the tools section
- A single list row: white (#FFFFFF) background, corner radius 12pt, 16pt internal padding, 16pt horizontal margins
- Left: SF Symbol "clock.arrow.circlepath" 20pt, color rgba(60,60,67,0.6)
- 12pt gap
- Label: "测试历史" 17pt Regular, color #000000, flex grow
- Right: chevron "chevron.right" 13pt, color rgba(60,60,67,0.3)
- Row height: ~52pt

### 6. Bottom Spacer

- Some breathing space (16-24pt) between history row and tab bar
- The page is a ScrollView — all content scrolls above the fixed tab bar

### 7. Five-Tab Bottom Bar (Fixed)

- 5 tabs: 训练 | 动作库 | **角度** | 记录 | 我的
- **Active tab "角度"**: icon + text in brand green #1A6B3C
- Inactive tabs: icon + text in gray rgba(60,60,67,0.6)
- Tab bar background: white with subtle top border line
- Tab bar height: ~49pt (standard iOS)
- Tab icons (SF Symbols): "figure.run" | "books.vertical" | "angle" | "calendar" | "person"

## Design Tokens

- Primary color: #1A6B3C (billiard table green)
- Page background: #F2F2F7
- Card background: #FFFFFF
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Text tertiary: rgba(60,60,67,0.3)
- Section header color: #1A6B3C (brand green, 13pt Semibold)
- Icon circle fill: rgba(26,107,60,0.12)
- Badge background: rgba(26,107,60,0.12), badge text: #1A6B3C
- Card corner radius: 16pt (feature cards), 12pt (list row)
- Page horizontal padding: 16pt
- Card internal padding: 16pt
- Card vertical gap: 10pt
- Section gap: 24pt
- Minimum touch target: 44pt

## Reference Style

- This screen is a redesigned version of the app's existing AngleHomeView (previously had only 2 feature cards + 1 history row). The redesign expands to 7 features organized into 3 sections.
- The FeatureCard pattern (white card + light-green circle icon + title/subtitle + chevron) is the established pattern from the existing app — every card must use this exact same style.
- Section headers follow the iOS grouped list style — small colored labels above card groups, similar to iOS Settings section headers but in brand green.
- The overall page remains a clean navigation hub — NO hero banners, NO profile avatars, NO statistics cards, NO promotional content. Just organized feature entry points.
- Similar to a health/fitness app's feature hub — grouped sections of feature shortcuts.

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- iOS native feel: SF Pro font family, SF Symbols icons throughout
- NO gradient fills on any element — all solid colors (flat fill only)
- NO hero banner, NO promotional cards, NO statistics, NO avatars or gear icons in nav bar
- Minimum touch target: 44pt for all interactive elements
- Large title must be pure black #000000 text on #F2F2F7 background (NOT green header bar)
- All text in Simplified Chinese
- The "角度" tab must be highlighted in brand green #1A6B3C
- Section headers are small labels (NOT full-width colored bars)
- All 7 feature cards must use identical FeatureCard style — only icon/title/subtitle differ
- The "2D/3D" badge on "球台角度预测" card is the only card with an extra element
- Page must scroll if content exceeds screen height (ScrollView)
- Keep card density reasonable — don't squeeze cards, maintain consistent 10pt vertical gap

## State

Default state: AngleHomeView as root page of the "角度" tab. Light mode. 7 feature cards organized into 3 sections (学习: 3 cards, 训练: 3 cards, 工具: 1 card) + 1 history row at bottom. No data dependencies — this is a static navigation hub page.
