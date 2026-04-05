# Stitch Prompt — P1-01 DrillListView (Default State)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode only.

## Screen: DrillListView — Drill Library Main List

This is the "动作库" (Drill Library) tab — the second tab in the app's 5-tab bottom navigation. It shows a browsable, filterable list of billiard training drills organized by category. The user comes here to discover drills, browse by ball type or category, and tap into drill details. This screen shows the default state with data populated.

## Layout (top to bottom)

### 1. iOS Large Title Navigation Bar
- Large title text: "动作库" (Drill Library)
- Font: 34pt Bold Rounded, color #000000, on #F2F2F7 background
- Right side: one icon button (e.g., a bookmark or sort icon), 24pt SF Symbol, color rgba(60,60,67,0.6)
- Standard iOS large title behavior — sits below status bar with generous top padding

### 2. Search Bar
- iOS system search bar style: rounded rectangle with light gray fill (#E5E5EA), magnifying glass icon on left, placeholder text "搜索动作" (Search drills) in gray
- Full width with 16pt horizontal margins
- Height ~36pt

### 3. Ball Type Filter Chip Row (Horizontal Scroll)
- Horizontally scrollable row of 4 filter chips, 16pt left margin
- Chips: "全部" (All) | "中式台球" (Chinese Pool) | "九球" (9-Ball) | "通用" (General)
- **Selected chip**: solid near-black fill #1C1C1E + white text 14pt Medium — "全部" is selected by default
- **Unselected chips**: white fill + gray border (#D1D1D6) + dark text (#1C1C1E) 14pt Medium
- Chip height: 32pt, horizontal padding 16pt, pill shape (corner radius 999pt)
- Gap between chips: 8pt

### 4. Category Filter Chip Row (Horizontal Scroll)
- Second horizontally scrollable row below ball type chips, 8pt vertical gap from row above
- Chips: "全部分类" | "基础功" | "准度训练" | "杆法" | "分离角" | "走位" | "控力" | "特殊球路" | "综合球形"
- Same chip styling as ball type row: selected = #1C1C1E fill + white text, unselected = white + gray border
- "全部分类" is selected by default
- Same dimensions as ball type chips

### 5. Drill Card List (Grouped by Category)

The main content area is a vertically scrolling list of BTDrillCard items, grouped under category section headers.

#### Section Headers
- Category name: 15pt Semibold, color rgba(60,60,67,0.6), uppercase style
- 24pt top margin from previous section, 8pt bottom margin before first card
- Example sections to show: "基础功" (3 cards), "准度训练" (3 cards), "杆法" (2 cards visible, list continues below fold)

#### BTDrillCard (Each Card)
- White (#FFFFFF) background, corner radius 12pt, 16pt internal padding
- Full width minus 16pt margins on each side (361pt wide)
- Card height: auto (~72-80pt based on content)
- Gap between cards: 8pt

**Card layout (horizontal):**
- **Left section** (text content, flex grow):
  - Drill name: 17pt Semibold, color #000000, single line (e.g., "直线球定点练习", "五分点准度训练")
  - Tag row below name (4pt gap): horizontal layout of small tags —
    - Ball type capsule: e.g., "中式台球" — tiny pill, 11pt text, light gray fill (#F2F2F7), dark text
    - BTLevelBadge: difficulty badge capsule —
      - L0 "入门": solid green fill #1A6B3C + white text
      - L1 "初学": light green fill rgba(26,107,60,0.12) + green text #1A6B3C
      - L2 "进阶": light amber fill rgba(212,148,26,0.12) + amber text #D4941A
      - L3 "熟练": light orange fill rgba(255,152,0,0.12) + orange text #FF9800
      - L4 "专业": light red fill rgba(198,40,40,0.12) + red text #C62828
    - Recommended sets: "推荐 3 组" — 13pt Regular, color rgba(60,60,67,0.6)
  - Gap between tags: 6pt

- **Right section** (fixed width, vertically centered):
  - If Pro-locked: "PRO" capsule badge — light gold fill rgba(212,148,26,0.12) + gold text #D4941A, 11pt Bold, pill shape, positioned above chevron
  - Chevron: SF Symbol "chevron.right", 13pt, color rgba(60,60,67,0.3)

#### Sample Drill Cards to Display

**基础功 section (3 cards):**
1. "正确站姿与握杆" — 通用, L0 入门, 推荐 2 组
2. "标准架杆训练" — 通用, L0 入门, 推荐 3 组
3. "直线出杆矫正" — 通用, L1 初学, 推荐 3 组

**准度训练 section (3 cards):**
1. "直线球定点练习" — 中式台球, L1 初学, 推荐 5 组
2. "五分点准度训练" — 中式台球, L2 进阶, 推荐 4 组, **PRO locked**
3. "三分点精确瞄准" — 九球, L2 进阶, 推荐 4 组, **PRO locked**

**杆法 section (2 cards, partially visible):**
1. "定杆基础训练" — 通用, L1 初学, 推荐 3 组
2. "高杆跟进练习" — 中式台球, L3 熟练, 推荐 5 组, **PRO locked** (partially visible at bottom, cut off by tab bar)

### 6. Five-Tab Bottom Bar (Fixed)
- 5 tabs horizontally distributed, each with SF Symbol icon (24pt) + label text (10pt)
- Tabs: 训练 | **动作库** | 角度 | 记录 | 我的
- **Active tab "动作库"**: icon + text in brand green #1A6B3C
- Inactive tabs: icon + text in gray rgba(60,60,67,0.6)
- Tab bar background: white with subtle top border
- Tab bar height: ~49pt (standard iOS)
- Tab icons (SF Symbols): "figure.run" | "books.vertical" | "angle" | "calendar" | "person"

## Design Tokens
- Primary color: #1A6B3C (billiard table green)
- Accent/Pro color: #D4941A (amber/gold)
- Page background: #F2F2F7
- Card background: #FFFFFF
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Text tertiary: rgba(60,60,67,0.3)
- Filter chip selected fill: #1C1C1E (near-black)
- Card corner radius: 12pt
- Page horizontal padding: 16pt
- Card internal padding: 16pt
- Card gap: 8pt
- Section gap: 24pt
- Chip height: 32pt, pill shape (999pt radius)
- Minimum touch target: 44pt

## Reference Style
- This screen follows the same iOS large-title tab page pattern established in the app's Training Home screen: large title navigation + content scroll + fixed 5-tab bottom bar
- The drill cards use a clean list style similar to fitness app exercise libraries — white cards on gray background, name + metadata tags + chevron, compact but readable
- Filter chips follow iOS native pill style — near-black solid fill for selected state, not the brand green (brand green is reserved for primary action buttons)
- The overall feel is professional sports training tool, clean and functional, not flashy

## Constraints
- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- iOS native feel: SF Pro font family, SF Symbols icons throughout
- NO gradient fills on any element — all solid colors
- Minimum touch target: 44pt for all interactive elements
- Brand green #1A6B3C for tab highlight and badges only, NOT for filter chip selected state
- Filter chip selected state must be near-black #1C1C1E
- BTLevelBadge colors must be multi-color scheme: green (L0/L1) → amber (L2) → orange (L3) → red (L4)
- PRO badge must use light gold background (not solid gold fill)
- Show at least 3 category sections with real Chinese billiard drill names
- Cards should feel tappable (chevron affordance)

## State
Default state: "全部" ball type selected, "全部分类" category selected, showing all drills grouped by category. Data is populated with 8+ drill cards visible across multiple sections. 3 drills are PRO-locked.
