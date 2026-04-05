# P2-08 Stitch Prompt v1 — BTFloatingIndicator 跨 Tab 展示

## App Context

QiuJi (球迹) — a billiards training iOS app. iOS native design using SF Pro fonts, SF Symbols icons, and standard iOS navigation patterns. Brand color is billiard-table green (#1A6B3C). This screen shows the "Drill Library" tab while a training session is actively running in the background, with a floating indicator pill overlaying the bottom-right area.

## Screen: DrillListView with BTFloatingIndicator Overlay

The user is currently in a training session but has switched to the "Drill Library" (动作库) tab to browse exercises. A floating green pill indicator hovers above the tab bar, showing "训练中 12:34 ←" to remind the user that training is ongoing and they can tap to return.

The key purpose of this screen is to demonstrate the BTFloatingIndicator component in its real usage context — floating above a normal tab page.

## Layout (top to bottom)

### 1. Status Bar
- Standard iOS status bar (time, signal, battery) at top, black text on #F2F2F7 background

### 2. iOS Large Title Navigation Bar
- Large title "动作库" in 34pt Bold Rounded, black (#000000) text
- Background: #F2F2F7 (same as page)
- Right side: one icon button (heart/star for favorites), 24pt, gray (#8E8E93)

### 3. Search Bar
- Standard iOS `.searchable` style: rounded rectangle, light gray (#E5E5EA) background, magnifying glass icon, placeholder text "搜索动作" in gray
- Full width with 16pt horizontal margins

### 4. Filter Chip Row (horizontal scroll)
- First row — Ball type chips: "全部" (selected: #1C1C1E fill + white text), "中式台球", "九球", "通用" (unselected: white fill + gray border + black text)
- Chip height 36pt, pill shape (BTRadius.full), horizontal padding 16pt, gap 8pt between chips

### 5. Category Section — "基础功" (section title 18pt Bold black)
- Two BTDrillCard items stacked vertically:

**Card 1:**
- White background card, 12pt corner radius, 16pt inner padding
- Left: 64pt square rounded (8pt radius) billiard photo thumbnail
- Center: Drill name "直线击球练习" 17pt Semibold black + tag row below: gray pill "中式台球" 12pt + green BTLevelBadge "L0 入门" (solid #1A6B3C fill + white text 12pt) + "5组×20球" 13pt gray
- Right: chevron "›" gray
- Card gap: 8pt

**Card 2:**
- Same card layout
- Drill name "定位停球" + tag row: gray pill "通用" + BTLevelBadge "L1 初学" (light green tinted bg + #1A6B3C text) + "4组×15球" 13pt gray + gold PRO badge (rgba(212,148,26,0.12) bg + #D4941A text "PRO")
- Right: chevron

### 6. Category Section — "准度训练" (section title 18pt Bold black, 24pt top margin)
- Two more BTDrillCard items:

**Card 3:**
- Drill name "角度瞄准训练" + tag row: "中式台球" pill + BTLevelBadge "L2 进阶" (light amber tinted bg + amber text) + "6组×10球"
- Right: chevron

**Card 4 (partially visible, cut off at bottom):**
- Drill name "长台直线准度" + partial tag row visible
- This card is partially obscured — the bottom portion fades behind the floating indicator and tab bar area

### 7. BTFloatingIndicator (FLOATING OVERLAY — KEY ELEMENT)
- **Position**: floating above tab bar, right-aligned. Exactly 8pt above the tab bar top edge, 16pt from right screen edge
- **Shape**: pill/capsule shape (BTRadius.full = 999pt corner radius)
- **Size**: height 44pt, width auto-fit to content (approximately 160-180pt)
- **Background**: solid #1A6B3C (brand green), NO gradient
- **Content**: white text "训练中 12:34 ←" — "训练中" in 15pt Medium, "12:34" in 15pt Bold Mono (timer), "←" arrow hint 15pt
- **Shadow**: subtle drop shadow (black 15% opacity, offset-y 2pt, blur 8pt) to create floating depth
- **This is the HERO element of this screen — make it visually prominent and clearly floating above the page content**

### 8. Tab Bar (bottom, fixed)
- Standard iOS 5-tab bar, white background with thin top separator line
- Tabs left to right: 训练 (dumbbell icon, gray inactive) | 动作库 (list icon, #1A6B3C active green + green text) | 角度 (angle icon, gray) | 记录 (calendar icon, gray) | 我的 (person icon, gray)
- Tab icon size 24pt, label text 10pt
- Safe area padding at bottom

## Design Tokens
- Primary color: #1A6B3C (billiard table green)
- Accent color: #D4941A (amber/gold for Pro elements)
- Background: #F2F2F7 (light gray page bg)
- Card background: #FFFFFF
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Filter chip selected: #1C1C1E (near-black)
- Card corner radius: 12pt
- Large card/container radius: 16pt
- Pill radius: 999pt (BTRadius.full)
- Standard padding: 16pt
- Card gap: 8pt
- Section gap: 24pt
- Floating indicator height: 44pt
- Floating indicator shadow: 0 2pt 8pt rgba(0,0,0,0.15)

## Reference Style
- This is a standard iOS tab root page (similar to fitness app exercise library) with a floating action indicator overlaying it
- The DrillListView background follows the established pattern from earlier screens: large title nav bar, search bar, horizontal filter chips, vertically stacked white cards with thumbnails
- The floating indicator pill should feel like a system-level overlay — similar to iOS "now playing" indicators or navigation app "continue on route" floating pills
- The indicator must clearly float ABOVE the page content with shadow separation

## Constraints
- Canvas width: 393px (iPhone 15 / iPhone 16 size), NOT desktop width
- iOS native feel (SF Pro font family, SF Symbols icons)
- Minimum touch target: 44pt
- Brand color #1A6B3C must be exact — no substitution
- NO gradients on buttons or the floating indicator — solid color fills only
- The floating indicator is the FOCAL POINT of this design — it should be immediately noticeable
- Tab bar must show 5 tabs with "动作库" as the active (green) tab
- All Chinese text, no English UI labels

## State
- Floating indicator visible state: training session active (timer running at 12:34), user browsing Drill Library tab
- DrillListView showing default state with data (multiple drill cards visible)
- Filter chips: "全部" selected in ball type row

## Consistency Note
This screen should match the visual style established in P1-01 (DrillListView) and A-05 (BTFloatingIndicator component). The floating indicator pill uses the exact same design as the A-05 component sheet — brand green #1A6B3C capsule with white text, 44pt height, full pill radius.
