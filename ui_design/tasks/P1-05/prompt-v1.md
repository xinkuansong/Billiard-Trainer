# Stitch Prompt — P1-05 Frame 1: AngleHomeView (角度训练入口页)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode only.

## Screen: AngleHomeView — Angle Training Home

This is the "角度" (Angle) tab — the third tab in the app's 5-tab bottom navigation. It serves as the entry point for the angle training feature module, presenting two primary feature cards and a history shortcut. The user comes here to start an angle estimation quiz or browse the contact-point reference table. This screen shows the default state.

## Layout (top to bottom)

### 1. iOS Large Title Navigation Bar

- Large title text: "角度训练" (Angle Training)
- Font: 34pt Bold Rounded, color #000000, on #F2F2F7 background
- Standard iOS large title behavior — sits below status bar with generous top padding
- No right-side icon buttons on this page (simple entry page)

### 2. Feature Entry Cards

Two large NavigationLink-style cards stacked vertically, serving as the two primary feature entries. Cards are on the page background #F2F2F7, with 16pt horizontal margins.

#### Card A: "角度测试" (Angle Test)

- White (#FFFFFF) background, corner radius 16pt, 16pt internal padding
- Full width minus 16pt margins on each side (361pt wide)
- **Layout (horizontal)**:
  - **Left icon area**: 48pt circle with light brand-green fill rgba(26,107,60,0.12), centered SF Symbol icon "scope" or "target" 24pt in brand green #1A6B3C
  - **Center text area** (12pt left gap from icon, flex grow):
    - Title: "角度测试" 17pt Semibold, color #000000
    - Subtitle: "训练角度视觉感知" 13pt Regular, color rgba(60,60,67,0.6), 2pt below title
  - **Right**: chevron SF Symbol "chevron.right" 13pt, color rgba(60,60,67,0.3), vertically centered
- Card minimum height: ~80pt (auto from content + padding)

#### Card B: "进球点对照表" (Contact Point Table)

- Same card style as Card A
- 12pt vertical gap from Card A
- **Left icon area**: 48pt circle with light brand-green fill rgba(26,107,60,0.12), centered SF Symbol icon "circle.circle" or "record.circle" 24pt in brand green #1A6B3C
- **Center text area**:
  - Title: "进球点对照表" 17pt Semibold, color #000000
  - Subtitle: "角度与接触点对照" 13pt Regular, color rgba(60,60,67,0.6)
- **Right**: chevron "chevron.right" 13pt, color rgba(60,60,67,0.3)

### 3. History Entry Row

- 24pt top gap from the feature cards
- A single list row, white (#FFFFFF) background, corner radius 12pt, 16pt internal padding, 16pt horizontal margins
- **Layout (horizontal)**:
  - Left: SF Symbol "clock.arrow.circlepath" 20pt, color rgba(60,60,67,0.6)
  - 12pt gap
  - Label: "测试历史" 17pt Regular, color #000000, flex grow
  - Right: chevron "chevron.right" 13pt, color rgba(60,60,67,0.3)
- Row height: ~52pt

### 4. Spacer

- The remaining vertical space between the history row and the tab bar is empty #F2F2F7 background
- This is a simple entry page — the content is intentionally minimal and spacious

### 5. Five-Tab Bottom Bar (Fixed)

- 5 tabs horizontally distributed, each with SF Symbol icon (24pt) + label text (10pt)
- Tabs: 训练 | 动作库 | **角度** | 记录 | 我的
- **Active tab "角度"**: icon + text in brand green #1A6B3C
- Inactive tabs: icon + text in gray rgba(60,60,67,0.6)
- Tab bar background: white with subtle top border
- Tab bar height: ~49pt (standard iOS)
- Tab icons (SF Symbols): "figure.run" | "books.vertical" | "angle" | "calendar" | "person"

## Design Tokens

- Primary color: #1A6B3C (billiard table green)
- Page background: #F2F2F7
- Card background: #FFFFFF
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Text tertiary: rgba(60,60,67,0.3)
- Icon circle fill: rgba(26,107,60,0.12) (light green tint)
- Card corner radius: 16pt (feature cards), 12pt (list row)
- Page horizontal padding: 16pt
- Card internal padding: 16pt
- Card gap: 12pt
- Section gap: 24pt
- Minimum touch target: 44pt

## Reference Style

- This screen follows the same iOS large-title tab page pattern established in the app's Training Home (P0-01) and Drill Library (P1-01): large title navigation + content + fixed 5-tab bottom bar
- The feature entry cards are large, tappable NavigationLink cards with icon + title + subtitle + chevron — similar to iOS Settings app's grouped list cells but larger and more card-like
- The icon circles with light-tinted backgrounds follow the iOS system style seen in Settings → Apple ID summary cards
- The overall feel is a clean hub/entry page — minimal content, generous spacing, clear navigation paths
- The page is intentionally simple with only 3 tappable elements (2 feature cards + 1 history row) — this is a feature selection page, not a content-heavy list

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- iOS native feel: SF Pro font family, SF Symbols icons throughout
- NO gradient fills on any element — all solid colors
- Minimum touch target: 44pt for all interactive elements
- Large title must be pure black #000000 text on #F2F2F7 background (NOT green header bar)
- Feature cards should feel like tappable navigation targets (chevron affordance, subtle shadow optional)
- The page should NOT feel cluttered — this is a simple hub with generous whitespace
- All text in Simplified Chinese
- The "角度" tab in the bottom bar must be highlighted in brand green #1A6B3C

## State

Default state: AngleHomeView as the root page of the "角度" (Angle) tab. Two feature entry cards visible: "角度测试" and "进球点对照表". One history entry row: "测试历史". No data dependencies — this is a static entry page.
