# Stitch Prompt — P2-02: CustomPlanBuilderView (Custom Plan Editor)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode only.

## Screen: CustomPlanBuilderView — Custom Plan Editor

This is the "编辑计划" (Edit Plan) page, pushed from the Training Plan List (PlanListView) via the "新建" (New) button. Users use this page to create or edit a custom training plan by naming it, setting training frequency, and adding billiard drills in their desired order. The screen shows a plan with 4 drills already added — an active editing session.

## Layout (top to bottom)

### 1. Standard iOS Navigation Bar (Push Sub-page)

- This is a pushed sub-page from PlanListView, NOT a tab root page
- Left side: standard iOS back arrow "chevron.left" + "训练计划" back label, color #007AFF (system blue)
- Center title: "编辑计划" (Edit Plan), 17pt Semibold, color #000000
- Right side: "保存" (Save) text button, 17pt Regular, color #1A6B3C (brand green)
- Navigation bar background: white/translucent with standard iOS thin bottom separator
- **NO bottom 5-tab bar** — this is a sub-page pushed from another sub-page

### 2. Plan Info Row

- Full width, 16pt horizontal margins, 16pt top padding below navigation bar
- Left side: SF Symbol "pencil" icon (13pt, color rgba(60,60,67,0.6)) + plan name "我的台球日常" (17pt Semibold, color #000000) — the name is an editable text field with the pencil icon as an inline edit affordance
- Right side: stats summary "12 组  4 动作" (13pt Regular, color rgba(60,60,67,0.6)), aligned to trailing edge
- A thin separator line below this row (1px, color rgba(60,60,67,0.1)), 16pt horizontal margins, 12pt bottom padding

### 3. Training Frequency Setting

- White card (#FFFFFF), corner radius 12pt, 16pt internal padding
- 16pt horizontal page margins, 12pt top margin below the separator
- Single row with iOS List insetGrouped style:
  - Left label: "每周训练天数" (Weekly Training Days), 17pt Regular, color #000000
  - Right side: iOS native Stepper showing value "5", 17pt Semibold, color #1A6B3C (brand green). The Stepper has minus/plus buttons with brand green tint
- Card has subtle iOS grouped list appearance

### 4. Drill List Section

- Section header: "训练项目" (Training Items), 13pt Semibold, color rgba(60,60,67,0.6), uppercase tracking style
- 16pt horizontal margin, 20pt top margin from frequency card, 8pt bottom margin

#### Drill Cards Container
- White card (#FFFFFF) background, corner radius 12pt, no internal horizontal padding (full-bleed rows inside)
- 16pt horizontal page margins
- Contains 4 drill rows separated by thin dividers (1px, color rgba(60,60,67,0.1), inset 88pt from left to match text start)

#### Each Drill Row (4 rows total)
- Height: ~72pt, vertical center aligned
- 16pt internal horizontal padding
- **Left: Drag handle** — SF Symbol "line.3.horizontal" (≡), 15pt, color rgba(60,60,67,0.3), indicating drag-to-reorder
- **Thumbnail** (12pt gap from drag handle): 56pt x 56pt square, corner radius 8pt — billiard table mini illustration:
  - Green surface #1B6B3A with brown rail border #7B3F00
  - Tiny white cue ball and orange target ball #F5A623
  - Diagonal layout (cue ball lower-left area, target ball upper-right area)
- **Text content** (12pt gap from thumbnail, flex grow):
  - Drill name: 17pt Semibold, color #000000, single line
  - Detail row (4pt below): "X 组 · 每组 Y 球" format, 13pt Regular, color rgba(60,60,67,0.6)
- **Right: Settings gear** — SF Symbol "gearshape", 18pt, color rgba(60,60,67,0.3), tappable (opens per-drill settings like set count and ball count)

#### Sample Drill Data (4 drills):
1. "直线准度练习" — "4 组 · 每组 20 球"
2. "中袋切球训练" — "3 组 · 每组 15 球"
3. "低杆拉球练习" — "3 组 · 每组 10 球"
4. "走位路线训练" — "2 组 · 每组 12 球"

### 5. Add Drill Row

- Below the drill cards container, 12pt gap
- Full width white card (#FFFFFF), corner radius 12pt, height 48pt, 16pt horizontal page margins
- Center aligned content: SF Symbol "plus.circle.fill" (17pt, color #1A6B3C) + "添加训练项目" (17pt Regular, color #1A6B3C), 6pt gap between icon and text
- This tappable row opens a Sheet to pick drills from the drill library

### 6. Bottom Toolbar

- Fixed to bottom of screen, above safe area
- White (#FFFFFF) background with top thin separator line (1px, color rgba(60,60,67,0.1))
- Height: 56pt (content area) + 34pt (safe area padding)
- 4 items evenly distributed horizontally:

**Item 1 — 模版配色 (Template Color):**
- SF Symbol "paintpalette" (24pt, color rgba(60,60,67,0.6))
- Label below: "配色" (Color), 10pt Regular, color rgba(60,60,67,0.6)

**Item 2 — 开始训练 (Start Training):**
- SF Symbol "figure.run" (24pt, color rgba(60,60,67,0.6))
- Label below: "开始训练" (Start), 10pt Regular, color rgba(60,60,67,0.6)

**Item 3 — 添加动作 (Add Drill):**
- SF Symbol "plus.circle.fill" (32pt, color #1A6B3C, brand green — visually prominent as primary action)
- Label below: "添加动作" (Add Drill), 10pt Regular, color #1A6B3C
- This is the center primary action, slightly larger icon

**Item 4 — 容量 (Capacity):**
- Large number: "960" (20pt Bold, color #000000)
- Label below: "容量" (Capacity), 10pt Regular, color rgba(60,60,67,0.6)

## Design Tokens

- Primary brand color: #1A6B3C (billiard table green)
- Accent/Pro color: #D4941A (amber/gold)
- Page background: #F2F2F7
- Card background: #FFFFFF
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Text tertiary: rgba(60,60,67,0.3)
- Card corner radius: 12pt
- Thumbnail corner radius: 8pt
- Thumbnail size: 56pt x 56pt
- Page horizontal padding: 16pt
- Card internal padding: 16pt
- Card gap: 8pt
- Drill row height: ~72pt
- Toolbar height: 56pt + 34pt safe area
- Separator color: rgba(60,60,67,0.1)
- Minimum touch target: 44pt

## Reference Style

- This page follows an iOS "List insetGrouped" editing pattern — similar to Settings app or Reminders list editing
- The drill list rows use the same billiard table thumbnail style established in the app's active training view (BTExerciseRow from A-07) — 56pt square mini table with diagonal ball layout
- The drag handle (≡) on the left of each drill row provides a clear reorder affordance, similar to iOS Reminders reorder mode
- The bottom toolbar mirrors the reference app's plan editor toolbar with 4 actions, where the center "add" action is visually emphasized
- Overall feel is a focused editing workspace — clean, organized, with clear action affordances

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- iOS native feel: SF Pro font family, SF Symbols icons throughout
- NO gradient fills on any element — all solid colors
- NO bottom 5-tab bar — this is a pushed sub-page (two levels deep from tab root)
- Standard iOS navigation bar with back arrow (not large title style)
- Minimum touch target: 44pt for all interactive elements
- Brand green #1A6B3C used sparingly: "保存" nav button, Stepper value/tint, "添加训练项目" row, toolbar center "添加动作" icon
- Drill thumbnails must show billiard table mini illustrations (green surface #1B6B3A + brown rail #7B3F00 + white/orange balls), NOT photo placeholders
- Show exactly 4 drill rows with realistic billiard drill names in Simplified Chinese
- Drag handles visible on all drill rows (this is an editable list)
- The toolbar is fixed at the bottom, always visible regardless of scroll position
- All text in Simplified Chinese

## State

Active editing state with populated data: a custom plan named "我的台球日常" with 4 billiard drills added, each with specified set counts and ball counts. The weekly training frequency is set to 5 days. The plan is being actively edited (not yet saved). The content fits within the visible viewport without needing to scroll.
