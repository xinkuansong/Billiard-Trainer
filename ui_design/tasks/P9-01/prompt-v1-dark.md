# Stitch Prompt — P9-01 Frame 2: AngleHomeView Redesign (Dark Mode)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. Canvas width: 393px (iPhone 15 Pro). **Dark mode variant.**

## Screen: AngleHomeView — Angle Training Home (Dark Mode)

Dark mode variant of the AngleHomeView redesign. Pure black background (#000000) — iOS OLED-optimized. All card containers use #1C1C1E background. This screen must have **identical layout, spacing, and element positions** as the light mode version — only colors change per the dark mode token mapping below.

## Layout (top to bottom)

Identical structure to light mode version — 7 feature cards in 3 sections + 1 history row + 5-tab bottom bar. Only color values change as specified below.

### 1. iOS Large Title Navigation Bar

- Large title text: "角度训练"
- Font: 34pt Bold Rounded, color **#FFFFFF** (white), on **#000000** background
- Standard iOS large title, no right-side icon buttons

### 2. Section: "学习" (Learning) — 3 Feature Cards

Section header "学习": 13pt Semibold, color **#25A25A** (dark mode brand green).

All cards: **#1C1C1E** background (NOT white), corner radius 16pt, 16pt internal padding. Card gap: 10pt.

#### Card 2a: "瞄准原理"
- Left icon: 48pt circle, fill **rgba(37,162,90,0.15)**, SF Symbol "lightbulb.max" 24pt **#25A25A**
- Title: "瞄准原理" 17pt Semibold **#FFFFFF**
- Subtitle: "切入角、假想球法、厚薄球概念" 13pt **rgba(235,235,240,0.6)**
- Right: chevron 13pt **rgba(235,235,240,0.3)**

#### Card 2b: "角度与打点"
- Same dark card style, icon "arrow.triangle.branch" in **#25A25A**
- Title: "角度与打点" **#FFFFFF**, Subtitle: "角度/接触点/厚薄球动态关系" **rgba(235,235,240,0.6)**

#### Card 2c: "浅淡球感"
- Same dark card style, icon "hand.point.up.braille" in **#25A25A**
- Title: "浅淡球感" **#FFFFFF**, Subtitle: "从理性分析到直觉判断" **rgba(235,235,240,0.6)**

### 3. Section: "训练" (Training) — 3 Feature Cards

Section header "训练": 13pt Semibold **#25A25A**. 24pt top gap.

#### Card 3a: "几何角度训练"
- Dark card, icon "ruler" **#25A25A**
- Title: "几何角度训练" **#FFFFFF**, Subtitle: "纯几何角度预测练习" **rgba(235,235,240,0.6)**

#### Card 3b: "球台角度预测"
- Dark card, icon "cube.transparent" **#25A25A**
- Title: "球台角度预测" **#FFFFFF**, Subtitle: "2D/3D 球台场景训练" **rgba(235,235,240,0.6)**
- "2D/3D" badge pill: background **rgba(37,162,90,0.15)**, text **#25A25A** 11pt Semibold

#### Card 3c: "角度测试"
- Dark card, icon "scope" **#25A25A**
- Title: "角度测试" **#FFFFFF**, Subtitle: "训练角度视觉感知" **rgba(235,235,240,0.6)**

### 4. Section: "工具" (Tools) — 1 Card

Section header "工具": 13pt Semibold **#25A25A**. 24pt top gap.

#### Card 4a: "进球点对照表"
- Dark card, icon "tablecells" **#25A25A**
- Title: "进球点对照表" **#FFFFFF**, Subtitle: "角度与接触点对照" **rgba(235,235,240,0.6)**

### 5. History Entry Row

- **#1C1C1E** background, corner radius 12pt
- Left icon "clock.arrow.circlepath" 20pt **rgba(235,235,240,0.6)**
- Label: "测试历史" 17pt **#FFFFFF**
- Right: chevron 13pt **rgba(235,235,240,0.3)**

### 6. Five-Tab Bottom Bar (Fixed)

- Tab bar background: dark **#1C1C1E** semi-transparent with subtle top border **#38383A**
- Active tab "角度": icon + text **#25A25A**
- Inactive tabs: icon + text **rgba(235,235,240,0.6)**
- Tab icons same as light mode: "figure.run" | "books.vertical" | "angle" | "calendar" | "person"

## Design Tokens (Dark Mode)

- Primary color: **#25A25A** (dark mode brand green, brighter than light #1A6B3C)
- Page background: **#000000** (pure black, OLED)
- Card background: **#1C1C1E** (elevated surface)
- Text primary: **#FFFFFF**
- Text secondary: **rgba(235,235,240,0.6)**
- Text tertiary: **rgba(235,235,240,0.3)**
- Section header color: **#25A25A**
- Icon circle fill: **rgba(37,162,90,0.15)**
- Badge background: **rgba(37,162,90,0.15)**, badge text: **#25A25A**
- Separator: **#38383A**
- Card corner radius: 16pt, 12pt (same as light)
- No card shadows in dark mode — layer differentiation via background color contrast only

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro)
- Layout MUST be pixel-identical to the light mode version — same positions, sizes, spacing, element count
- iOS OLED dark mode: pure black #000000 background, NOT dark gray
- Cards use #1C1C1E — NOT #000000 (must have visible separation from page background)
- Brand green is #25A25A in dark mode — NOT #1A6B3C
- NO gradient fills — all solid colors
- White status bar text (light content style)
- All text in Simplified Chinese
- NO card shadows (invisible on dark backgrounds)

## State

Dark mode variant of AngleHomeView redesign. Identical content and layout to light mode frame. All 7 feature cards + 1 history row + 5-tab bar visible. Static navigation hub page.
