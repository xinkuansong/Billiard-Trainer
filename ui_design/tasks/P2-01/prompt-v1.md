# Stitch Prompt — P2-01 Frame 1: PlanListView (Training Plan List)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode only.

## Screen: PlanListView — Training Plan List

This is the "训练计划" (Training Plans) page, pushed from the Training Home tab. It displays all available training plans organized into two sections: official plans (grouped by difficulty level) and user-created custom plans. Users come here to browse, compare, and select a training plan to follow. The screen shows the default state with 6 official plans and 1 custom plan.

## Layout (top to bottom)

### 1. Standard iOS Navigation Bar (Push Sub-page)

- This is a pushed sub-page from TrainingHomeView, NOT a tab root page
- Left side: standard iOS back arrow "chevron.left" + "训练" back label, color #007AFF (system blue)
- Center title: "训练计划" (Training Plans), 17pt Semibold, color #000000
- Right side: "新建" (New) text button, 17pt Regular, color #1A6B3C (brand green) — creates a custom plan
- Navigation bar background: white/translucent with standard iOS thin bottom separator
- **NO bottom 5-tab bar** — this is a sub-page pushed from a tab root

### 2. Official Plans Section

#### Section Header
- "官方计划" (Official Plans), 13pt Semibold, color rgba(60,60,67,0.6), uppercase tracking
- 16pt horizontal margin, 16pt top margin from navigation bar content area, 8pt bottom margin before first group

#### Level Group Headers
- Official plans are organized into level groups. Each group has a header:
- Group name: 18pt Bold, color #000000 (e.g., "入门计划", "初级计划", "中级计划", "高级计划")
- 20pt top margin from previous group's last card, 8pt bottom margin before first card in group

#### Plan Card (White Card with Thumbnail)
- White (#FFFFFF) background, corner radius 12pt, 16pt internal padding
- Full width minus 16pt margins on each side
- Card height: auto (~88-96pt based on content)
- Gap between cards within a group: 8pt

**Card layout (horizontal):**
- **Left: Thumbnail** (fixed size):
  - 72pt x 72pt square, corner radius 10pt
  - Billiard-themed illustration placeholder — subtle green (#1B6B3A) background with abstract ball/cue graphics in muted colors
  - Each plan has a slightly different thumbnail tint or icon to visually differentiate

- **Middle: Text content** (flex grow, 12pt left gap from thumbnail):
  - Plan name: 17pt Semibold, color #000000, single line
    - e.g., "新手入门 8 周计划", "基础杆法专项"
  - Tag row (4pt below name): horizontal layout of small tags:
    - BTLevelBadge: difficulty level capsule —
      - L0 "入门": solid green fill #1A6B3C + white text 11pt Bold
      - L1 "初学": light green fill rgba(26,107,60,0.12) + green text #1A6B3C, 11pt Bold
      - L2 "进阶": light amber fill rgba(212,148,26,0.12) + amber text #D4941A, 11pt Bold
      - L3 "熟练": light orange fill rgba(255,152,0,0.12) + orange text #FF9800, 11pt Bold
    - Duration capsule: e.g., "8 周" — tiny pill, 11pt text, light gray fill #F2F2F7, dark text
    - Gap between tags: 6pt
  - Description: 13pt Regular, color rgba(60,60,67,0.6), 1-2 lines, 4pt below tags
    - e.g., "从零开始系统学习台球基础", "专项训练杆法技术"

- **Right section** (fixed width, vertically centered):
  - If Pro-locked: "PRO" capsule badge — light gold fill rgba(212,148,26,0.12) + gold text #D4941A, 11pt Bold, pill shape, positioned above chevron
  - Chevron: SF Symbol "chevron.right", 13pt, color rgba(60,60,67,0.3)

#### Sample Plan Cards to Display

**入门计划 group (2 cards — FREE):**
1. "新手入门 8 周计划" — L0 入门, 8 周, "从零开始系统学习台球基础"
2. "基础杆法专项" — L1 初学, 4 周, "专项训练杆法基本功"

**中级计划 group (2 cards — PRO locked):**
1. "走位突破训练" — L2 进阶, 6 周, "系统训练走位能力与判断", **PRO**
2. "中级综合突破" — L2 进阶, 8 周, "全面提升中级选手水平", **PRO**

**高级计划 group (2 cards — PRO locked):**
1. "高级加塞与多库" — L3 熟练, 6 周, "掌握进阶加塞与多库技术", **PRO**
2. "全能综合计划" — L3 熟练, 12 周, "职业级全方位训练体系", **PRO**

### 3. Custom Plans Section

#### Section Header
- "自定义计划" (Custom Plans), 13pt Semibold, color rgba(60,60,67,0.6)
- 24pt top margin from last official plan card, 8pt bottom margin

#### Custom Plan Card (1 card)
- Same card style as official plans but without the level group header
- Plan name: "我的练球日常" — 17pt Semibold, color #000000
- Tags: custom icon badge (SF Symbol "person.fill" in small circle) + "3 项训练" (3 drills) 13pt gray
- Description: "每日基础练习组合" 13pt gray
- No PRO badge, has chevron
- Thumbnail: user-customizable colored square (e.g., brand green #1A6B3C solid fill with a billiard ball icon overlay in white)

### 4. Bottom Safe Area Padding
- 34pt safe area at bottom (no tab bar, just standard iOS bottom padding for push sub-page)

## Design Tokens

- Primary brand color: #1A6B3C (billiard table green)
- Accent/Pro color: #D4941A (amber/gold)
- Page background: #F2F2F7
- Card background: #FFFFFF
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Text tertiary: rgba(60,60,67,0.3)
- Card corner radius: 12pt
- Thumbnail corner radius: 10pt
- Thumbnail size: 72pt x 72pt
- Page horizontal padding: 16pt
- Card internal padding: 16pt
- Card gap: 8pt
- Section gap: 24pt
- Minimum touch target: 44pt

## Reference Style

- This page follows the same "list browsing page" pattern established in the app's Drill Library (DrillListView) — white cards on gray background, thumbnail + text + chevron layout, grouped by category
- Plan cards are similar to drill cards but slightly taller due to the description line and larger thumbnails (72pt vs 64pt)
- The level group headers provide visual hierarchy similar to category section headers in DrillListView
- PRO badges use the same light gold capsule style established across the app
- Overall feel is a structured catalog — users scan plan names, difficulty levels, and durations to make a choice

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- iOS native feel: SF Pro font family, SF Symbols icons throughout
- NO gradient fills on any element — all solid colors
- NO bottom 5-tab bar — this is a pushed sub-page
- Standard iOS navigation bar with back arrow (not large title style)
- Minimum touch target: 44pt for all interactive elements
- Brand green #1A6B3C for "新建" nav button and L0 badge only — not overused
- PRO badge must use light gold fill rgba(212,148,26,0.12) + gold text #D4941A (not solid gold)
- BTLevelBadge multi-color scheme: L0 green solid, L1 light green, L2 amber, L3 orange
- Show exactly 6 official plans (2 free + 4 Pro) across level groups + 1 custom plan
- All text in Simplified Chinese
- Cards should feel tappable (chevron affordance)

## State

Default state with populated data: 6 official plans (2 free, 4 Pro-locked) organized into 3 level groups + 1 custom plan in the custom section. No plan is currently activated. The page is fully scrolled to show all content.
