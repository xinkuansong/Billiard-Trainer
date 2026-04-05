# Stitch Prompt — P1-07: HistoryCalendarView (训练历史月历视图 — 有数据)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode only.

## Screen: HistoryCalendarView — Training History Calendar

This is the "记录" (History) tab — the fourth tab in the app's 5-tab bottom navigation. It serves as the root page of the History module, displaying a monthly calendar view of the user's training sessions. Users come here to review their training frequency, see which days they trained, and tap a specific date to view that day's training sessions. The top has a segmented tab to switch between "历史" (History/Calendar) and "统计" (Statistics). This screen shows the "has data" state with the "历史" tab selected, showing April 2026 with multiple training days marked.

## Layout (top to bottom)

### 1. iOS Large Title Navigation Bar

- Large title text: "记录"
- Font: 34pt Bold Rounded, color #000000, on #F2F2F7 background
- Standard iOS large title behavior — sits below status bar with generous top padding
- No right-side icon buttons on this page

### 2. BTSegmentedTab (History | Statistics)

- 16pt horizontal margins, 12pt below the navigation bar title
- Two horizontal text tabs: "历史" and "统计"
- Each tab label: 16pt Medium
- **Active tab "历史"**: text color brand green #1A6B3C, with a 2pt-thick brand green #1A6B3C underline indicator directly below the text
- **Inactive tab "统计"**: text color rgba(60,60,67,0.6), no underline
- Tab spacing: 24pt between the two labels
- Left-aligned (not centered across full width)

### 3. Month Navigation Row

- 12pt top gap from the segmented tab
- 16pt horizontal margins
- **Layout (horizontal, vertically centered)**:
  - Left arrow: SF Symbol "chevron.left" 15pt, color rgba(60,60,67,0.6), tappable (44pt touch target)
  - Center: "2026年4月" — 17pt Bold, color #000000
  - Right arrow: SF Symbol "chevron.right" 15pt, color rgba(60,60,67,0.6), tappable (44pt touch target)
  - The arrows and month text are centered together horizontally within the row

### 4. Function Button Row

- 8pt top gap from month navigation
- 16pt horizontal margins
- Two small pill-style buttons, horizontally arranged with 12pt gap
- **Button A: "月报"**
  - SF Symbol "chart.bar" 13pt + label "月报" 13pt Semibold
  - Brand green text #1A6B3C + light green background rgba(26,107,60,0.08), corner radius 999pt (pill), height 32pt, horizontal padding 14pt
- **Button B: "日历设置"**
  - SF Symbol "gearshape" 13pt + label "设置" 13pt Semibold
  - Gray text rgba(60,60,67,0.6) + light gray background rgba(60,60,67,0.06), corner radius 999pt (pill), height 32pt, horizontal padding 14pt
- Buttons left-aligned

### 5. Calendar Grid

- 12pt top gap from function button row
- 16pt horizontal margins
- White #FFFFFF card background, corner radius 16pt, 16pt internal padding
- Full width minus margins (361pt)

#### Weekday Header Row:
- 7 columns evenly distributed
- Labels: "一" "二" "三" "四" "五" "六" "日"
- Font: 13pt Regular, color rgba(60,60,67,0.3)
- Row height: 24pt

#### Date Grid (6 rows × 7 columns for April 2026):
- Each cell width: approximately 47pt (361pt - 32pt padding) / 7
- Each cell height: approximately 64pt (to accommodate date number + training label below)
- Cell structure (vertically stacked, center-aligned):
  - **Date number**: 15pt Regular, color #000000 (default)
  - **Training label** (if applicable): small rounded tag below the number, 8pt top gap

**Special date styles:**
- **Today (April 4)**: date number in white #FFFFFF on a filled brand green #1A6B3C circle (28pt diameter)
- **Selected date (April 2)**: date number in brand green #1A6B3C on a brand green #1A6B3C circle outline (28pt diameter, 2pt stroke, no fill)
- **Has training — single session**: small colored tag below date number — brand green #1A6B3C background + white text, text like "准度" or "杆法" (abbreviated training name), font 9pt Medium, tag height 14pt, corner radius 4pt, horizontal padding 4pt
- **Has training — multiple sessions**: two stacked mini tags (8pt max height each, 2pt gap), or one tag + "+1" indicator in 9pt gray text
- **Previous/next month dates**: date number color rgba(60,60,67,0.2), no training labels
- **Weekend dates** (六 and 日 columns): same style as weekdays, no special color

**Sample training data for April 2026:**
- April 1 (Tue): one tag "准度#1" (green)
- April 2 (Wed): two sessions — "杆法" + "+1" (green tag + gray "+1")
- April 3 (Thu): one tag "走位" (green)
- April 4 (Fri, today): one tag "综合" (green) — today's circle is filled green, tag still visible below
- Other days without tags: April 5-30 mostly empty, with a few more scattered (April 8, April 12, April 15 with single tags)

### 6. Selected Date Training List

- 12pt top gap from the calendar card
- 16pt horizontal margins

#### Section Header:
- "4月2日 周三" — 15pt Semibold, color #000000
- 4pt bottom gap

#### Training Session Cards (2 cards for April 2nd):

**Card 1:**
- White #FFFFFF background, corner radius 12pt, 16pt internal padding
- **Row 1**: Training name "杆法专项训练" 17pt Semibold, color #000000 + small color dot (8pt circle, brand green #1A6B3C) left of name
- **Row 2** (4pt gap below): "3 项目 · 15 组 · 42 分钟 · 14:30-15:12" — 13pt Regular, color rgba(60,60,67,0.6)
- Right side: chevron "chevron.right" 13pt, color rgba(60,60,67,0.3), vertically centered

**Card 2:**
- 8pt gap below Card 1
- Same structure as Card 1
- Name: "准度练习" + color dot (amber #D4941A)
- Stats: "2 项目 · 8 组 · 25 分钟 · 16:00-16:25"

### 7. Bottom Safe Area + Tab Bar

- 16pt gap below the last training card
- Tab bar is fixed at bottom

#### Five-Tab Bottom Bar (Fixed):
- 5 tabs horizontally distributed, each with SF Symbol icon (24pt) + label text (10pt)
- Tabs: 训练 | 动作库 | 角度 | **记录** | 我的
- **Active tab "记录"**: icon + text in brand green #1A6B3C
- Inactive tabs: icon + text in gray rgba(60,60,67,0.6)
- Tab bar background: white with subtle top border
- Tab bar height: ~49pt (standard iOS)
- Tab icons (SF Symbols): "figure.run" | "books.vertical" | "angle" | "calendar" | "person"

## Design Tokens

- Primary color: #1A6B3C (billiard table green)
- Accent color: #D4941A (amber/gold, for secondary training color tags)
- Page background: #F2F2F7
- Card background: #FFFFFF
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Text tertiary: rgba(60,60,67,0.3)
- Large title font: 34pt Bold Rounded
- Body font: 17pt Regular
- Caption font: 13pt Regular
- Card corner radius: 16pt (calendar card), 12pt (training session cards)
- Pill corner radius: 999pt
- Page horizontal padding: 16pt
- Card internal padding: 16pt
- Card gap: 8-12pt
- Tab underline: 2pt thick, brand green #1A6B3C
- Minimum touch target: 44pt
- Calendar cell height: ~64pt
- Today circle diameter: 28pt

## Reference Style

- This screen follows the same iOS large-title tab root page pattern established in Training Home (P0-01) and Drill Library (P1-01): large title navigation + content area + fixed 5-tab bottom bar
- The BTSegmentedTab at the top uses the component style established in A-06: left-aligned text tabs with a 2pt brand-green underline indicator on the active tab (NOT the iOS system segmented control style)
- The calendar grid is similar to Apple Calendar app or fitness app monthly views — clean grid with date numbers and small event indicators below dates
- Training day labels below dates are small colored pills/tags, similar to how Apple Calendar marks events with small colored dots but here using abbreviated text labels instead of just dots
- The selected-date training list below the calendar is a standard card list — similar to how Apple Calendar shows event details below the calendar
- The month navigation row follows the standard pattern: left/right arrows flanking the centered month name
- Overall feel: a clean, data-rich but organized calendar page that gives a sense of training consistency at a glance

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- iOS native feel: SF Pro font family, SF Symbols icons throughout
- NO gradient fills on any element — all solid/flat fills
- Minimum touch target: 44pt for all interactive elements
- Large title must be pure black #000000 (NOT brand green)
- The BTSegmentedTab must use the underline indicator style (NOT iOS system segmented control / pill style)
- Calendar card must feel compact but readable — 6 rows of dates must fit without looking cramped
- Training labels below dates must be tiny but legible (9pt minimum)
- The page should scroll vertically — calendar card + training list may exceed one viewport
- All text in Simplified Chinese
- The "记录" tab in the bottom bar must be highlighted in brand green #1A6B3C
- The today date (April 4) must have a filled green circle, clearly standing out from other dates
- Selected date (April 2) must have a green outline circle, distinct from today's filled style

## State

Has data state: The user has been training for several weeks. April 2026 shows 6-8 training days scattered across the month (more concentrated in the first two weeks). April 2nd is selected (tapped), revealing 2 training sessions for that day in the list below the calendar. Today is April 4th, marked with a filled brand-green circle. The "历史" tab is selected in the BTSegmentedTab, and "周" or default time view is showing the full month calendar.
