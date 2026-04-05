# Stitch Prompt — P1-08: HistoryCalendarView (Empty State) + TrainingDetailView

> 本任务包含两帧，需分两次 Stitch 会话生成。

---

## 帧 1: HistoryCalendarView — Empty State (空状态)

### App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode only.

### Screen: HistoryCalendarView — Empty Training Calendar

This is the "记录" (History) tab — the fourth tab in the app's 5-tab bottom navigation. It is the same page as our previous "has data" design, but now showing the **empty state** for a brand new user who has never completed any training sessions. The calendar grid displays the full month but with no training day labels at all. Below the calendar, a centered BTEmptyState component encourages the user to start their first training. The "历史" tab is selected in the BTSegmentedTab.

### Layout (top to bottom)

#### 1. iOS Large Title Navigation Bar

- Large title text: "记录"
- Font: 34pt Bold Rounded, color #000000, on #F2F2F7 background
- Standard iOS large title behavior — sits below status bar with generous top padding
- No right-side icon buttons on this page (established pattern for the History tab)

#### 2. BTSegmentedTab (History | Statistics)

- 16pt horizontal margins, 12pt below the navigation bar title
- Two horizontal text tabs: "历史" and "统计"
- Each tab label: 16pt Medium
- **Active tab "历史"**: text color brand green #1A6B3C, with a 2pt-thick brand green #1A6B3C underline indicator directly below the text
- **Inactive tab "统计"**: text color rgba(60,60,67,0.6), no underline
- Tab spacing: 24pt between the two labels
- Left-aligned (not centered across full width)

#### 3. Month Navigation Row

- 12pt top gap from the segmented tab
- 16pt horizontal margins
- **Layout (horizontal, vertically centered)**:
  - Left arrow: SF Symbol "chevron.left" 15pt, color rgba(60,60,67,0.6), tappable (44pt touch target)
  - Center: "2026年4月" — 17pt Bold, color #000000
  - Right arrow: SF Symbol "chevron.right" 15pt, color rgba(60,60,67,0.6), tappable (44pt touch target)
  - Centered together horizontally within the row

#### 4. Function Button Row

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

#### 5. Calendar Grid (Empty — No Training Labels)

- 12pt top gap from function button row
- 16pt horizontal margins
- White #FFFFFF card background, corner radius 16pt, 16pt internal padding
- Full width minus margins (361pt)

**Weekday Header Row:**
- 7 columns evenly distributed
- Labels: "一" "二" "三" "四" "五" "六" "日"
- Font: 13pt Regular, color rgba(60,60,67,0.3)
- Row height: 24pt

**Date Grid (6 rows × 7 columns for April 2026):**
- Each cell width: approximately 47pt
- Each cell height: approximately 64pt
- Cell structure (vertically stacked, center-aligned):
  - **Date number**: 15pt Regular, color #000000 (default)
  - **No training labels** — all cells are empty below the date number (this is the empty state)

**Special date styles (empty state):**
- **Today (April 4)**: date number in white #FFFFFF on a filled brand green #1A6B3C circle (28pt diameter) — today is still visually highlighted even though there's no training
- **Previous/next month dates**: date number color rgba(60,60,67,0.18), visible but muted
- **Weekend dates** (六 and 日 columns): same style as weekdays, no special color
- **No date is selected** — no outline circle on any date (no data to browse)

**Calendar shows full April 2026:**
- Row 1: (Mar 31) 1 2 3 4 5 6
- Row 2: 7 8 9 10 11 12 13
- Row 3: 14 15 16 17 18 19 20
- Row 4: 21 22 23 24 25 26 27
- Row 5: 28 29 30 (May 1) (May 2) (May 3) (May 4)
- Row 6: (May 5) (May 6) (May 7) (May 8) (May 9) (May 10) (May 11)
- April 4 (Friday) is today — green filled circle

#### 6. BTEmptyState (Below Calendar)

- 24pt top gap from the calendar card
- Centered horizontally within the 16pt margins
- **Icon**: SF Symbol "calendar.badge.plus" (or "figure.run"), 48pt size, color brand green #1A6B3C at 30% opacity (rgba(26,107,60,0.3))
- **Title**: "还没有训练记录" — 22pt Bold, color #000000, centered, 12pt below icon
- **Subtitle**: "去开始第一次练球吧" — 15pt Regular, color rgba(60,60,67,0.6), centered, 4pt below title
- **CTA Button**: "开始训练" — brand green #1A6B3C solid fill + white #FFFFFF text 17pt Semibold, corner radius 12pt, height 50pt, width ~200pt (auto-size), centered, 16pt below subtitle
- The empty state group is vertically centered in the remaining space between the calendar card bottom and the tab bar

#### 7. Bottom Tab Bar (Fixed)

- Tab bar is fixed at bottom
- 5 tabs horizontally distributed, each with SF Symbol icon (24pt) + label text (10pt)
- Tabs: 训练 | 动作库 | 角度 | **记录** | 我的
- **Active tab "记录"**: icon + text in brand green #1A6B3C
- Inactive tabs: icon + text in gray rgba(60,60,67,0.6)
- Tab bar background: white with subtle top border
- Tab bar height: ~49pt (standard iOS)
- Tab icons (SF Symbols): "figure.run" | "books.vertical" | "angle" | "calendar" | "person"

### Design Tokens

- Primary color: #1A6B3C (billiard table green)
- Page background: #F2F2F7
- Card background: #FFFFFF
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Text tertiary: rgba(60,60,67,0.3)
- Large title font: 34pt Bold Rounded
- Body font: 17pt Regular
- Caption font: 13pt Regular
- Card corner radius: 16pt (calendar card)
- Pill corner radius: 999pt
- Page horizontal padding: 16pt
- Card internal padding: 16pt
- Tab underline: 2pt thick, brand green #1A6B3C
- Minimum touch target: 44pt
- Calendar cell height: ~64pt
- Today circle diameter: 28pt
- Empty state icon size: 48pt at 30% opacity

### Reference Style

- This screen is identical in structure to the "has data" version of HistoryCalendarView — same navigation bar, segmented tab, month navigation, function buttons, calendar grid, and tab bar. The ONLY differences are: (1) no training day labels on any calendar dates, (2) no date is selected, (3) a BTEmptyState component appears below the calendar instead of a training session list.
- The BTEmptyState follows the pattern established in P0-02 (Training Home empty state): centered icon at 30% opacity + title + subtitle + CTA button.
- The calendar grid should still feel "alive" — today's date is filled green, month dates are clearly legible. The emptiness is conveyed by the lack of training labels and the explicit empty state message, not by graying out the entire calendar.
- Overall feel: a clean but inviting empty page that clearly communicates "you haven't trained yet" and provides a direct call-to-action.

### Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- iOS native feel: SF Pro font family, SF Symbols icons throughout
- NO gradient fills on any element — all solid/flat fills
- Minimum touch target: 44pt for all interactive elements
- Large title must be pure black #000000 (NOT brand green)
- The BTSegmentedTab must use the underline indicator style (NOT iOS system segmented control / pill style)
- Calendar must show full 6 rows × 7 columns with next-month dates in light gray
- NO training labels, NO selected date highlight — the calendar is completely clean except for the today marker
- Weekend dates: same color as weekday dates (no red)
- All text in Simplified Chinese
- The "记录" tab in the bottom bar must be highlighted in brand green #1A6B3C

### State

Empty state: A brand new user who has never recorded a training session. April 2026 calendar is displayed with all 30 days visible plus next-month overflow dates. Today is April 4th (Friday), marked with a filled brand-green circle. No dates have any training labels below them. No date is selected. Below the calendar, a BTEmptyState component displays an encouraging message with a "开始训练" CTA button. The "历史" tab is selected in the BTSegmentedTab.

---

## 帧 2: TrainingDetailView — Training Session Detail Sheet

### App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode only.

### Screen: TrainingDetailView — Single Training Session Detail

This is a modal Sheet that slides up from the bottom when the user taps on a training session card in the HistoryCalendarView. It shows the complete record of one training session — overall stats, each drill's per-set details, and action buttons at the bottom. This sheet also displays a BTOverflowMenu (floating menu) triggered by the "更多" button, shown in its expanded/open state so the menu options are visible.

### Layout (top to bottom)

#### 1. Sheet Drag Handle

- Centered horizontal drag indicator bar at the very top of the sheet
- 36pt wide, 5pt tall, corner radius 2.5pt, color rgba(60,60,67,0.3)
- 8pt top margin from sheet top edge

#### 2. Top Navigation Row

- 12pt below drag handle
- 16pt horizontal margins
- **Left**: "✕" close button — SF Symbol "xmark" 17pt, inside a 32pt circle with light gray background rgba(60,60,67,0.06), tappable 44pt target
- **Right**: "存为模版" text button — 15pt Semibold, color brand green #1A6B3C, tappable

#### 3. Header Information Area

- 16pt below navigation row
- 16pt horizontal margins

**Row A — Training Name + Color Label:**
- Training name: "杆法专项训练" — 20pt Bold, color #000000
- Right of name (8pt gap): small color tag pill — "设置颜色" text 12pt in brand green #1A6B3C, with brand green border 1pt + transparent fill, corner radius 999pt, height 24pt, horizontal padding 8pt

**Row B — Statistics (horizontal scroll):**
- 8pt below Row A
- 4-5 stat items horizontally arranged with 16pt gap between each:
  - "180" large number 22pt Bold #000000 + "进球" label 12pt Regular rgba(60,60,67,0.6) stacked below
  - "15" + "组" (sets completed)
  - "42" + "分钟" (duration)
  - "14:30–15:12" + "时段" (time range)
  - "4月2日" + "日期" (date)
- Each stat item is vertically stacked: large number on top, small label below, center-aligned

#### 4. Drill List (ScrollView)

- 16pt below statistics row
- 16pt horizontal margins
- Each drill is a separate white #FFFFFF card section, corner radius 12pt, 16pt internal padding, 8pt gap between cards

**Drill Card Structure (example: 3 drill cards):**

**Drill Card 1: "直线准度练习"**
- **Drill Header Row**: 
  - Left: billiard table mini thumbnail (40pt × 40pt square, corner radius 8pt) — simplified top-down view showing green felt #1B6B3A surface + brown rail border #7B3F00 + tiny white dot (cue ball) at ~38%,70% + tiny orange dot (object ball) at ~58%,32% (diagonal layout)
  - Center (12pt gap from thumbnail): drill name "直线准度练习" 17pt Semibold #000000
  - Right: cumulative stat "60/90" 15pt Regular rgba(60,60,67,0.6)
- **Per-Set Detail Rows** (4pt gap below header, left-aligned with 52pt indent to align past thumbnail):
  - Row format: "第1组  12/15  ✓  休息 60s" — 14pt Regular
  - Completed sets: text color #000000 + green checkmark ✓ in brand green #1A6B3C
  - Show 5 set rows:
    - "第1组  12/15  ✓  休息 60s"
    - "第2组  14/15  ✓  休息 60s"  
    - "第3组  10/15  ✓  休息 90s"
    - "第4组  13/15  ✓  休息 60s"
    - "第5组  11/15  ✓"
  - Divider line below sets: 1pt, color rgba(60,60,67,0.08), full card width minus padding
- **Drill Footer**: "累计进球 60" — 13pt Regular, color rgba(60,60,67,0.6), 4pt below divider

**Drill Card 2: "中袋定位练习"**
- Same structure, 3 sets, ball counts "8/10", "9/10", "7/10"
- Cumulative: "累计进球 24"

**Drill Card 3: "走位控制练习"**
- Same structure, 4 sets
- Cumulative: "累计进球 45"

#### 5. Notes Section (Optional)

- 8pt below last drill card
- 16pt horizontal margins
- White #FFFFFF card, corner radius 12pt, 16pt padding
- Section icon: SF Symbol "note.text" 15pt rgba(60,60,67,0.6) + label "训练心得" 15pt Semibold #000000
- Note text: "今天杆法控制有进步，第三组开始找到了发力节奏。下次重点练习低杆走位。" — 15pt Regular, color #000000, 8pt below label

#### 6. Bottom Action Bar (Fixed at bottom)

- Fixed at the bottom of the sheet, above the safe area
- White background with subtle top shadow (0,0,0,0.05)
- 16pt horizontal padding, 12pt vertical padding
- **Horizontal layout with 8pt gaps between buttons:**
  - **"编辑数据"**: primary style — brand green #1A6B3C solid fill + white text 15pt Semibold, corner radius 12pt, height 44pt, flex-grow (takes most space)
  - **"复制到今天"**: secondary style — white fill + brand green #1A6B3C text 15pt Semibold + brand green 1pt border, corner radius 12pt, height 44pt
  - **"更多"**: secondary icon-only — SF Symbol "ellipsis" 17pt in brand green #1A6B3C, white fill + brand green 1pt border, 44pt × 44pt square, corner radius 12pt

#### 7. BTOverflowMenu (Floating, Expanded State)

- Floating above the "更多" button, bottom-right anchored
- White #FFFFFF background card, corner radius 16pt, shadow (0pt 4pt 24pt rgba(0,0,0,0.15))
- Width: ~220pt
- **Menu Items (vertical list, each item 48pt tall, 16pt horizontal padding):**
  - Item 1: colored circle icon (24pt, light blue bg #E3F2FD + blue icon #1976D2) + "生成分享图" 16pt Regular #000000
  - Item 2: colored circle icon (24pt, light purple bg #F3E5F5 + purple icon #7B1FA2) + "移动到某天" 16pt Regular #000000
  - Item 3: colored circle icon (24pt, light green bg rgba(26,107,60,0.1) + green icon #1A6B3C) + "编辑心得" 16pt Regular #000000
  - Item 4: colored circle icon (24pt, light amber bg rgba(212,148,26,0.1) + amber icon #D4941A) + "导入为模版" 16pt Regular #000000
  - **Full-width divider** (0pt horizontal margin, 1pt height, color rgba(60,60,67,0.12)) — separating danger zone
  - Item 5 (danger): colored circle icon (24pt, light red bg rgba(198,40,40,0.1) + red icon #C62828) + "删除" 16pt Regular #C62828 red text
- Subtle backdrop dimming behind menu (black 20% opacity) to indicate the menu is a floating overlay

### Design Tokens

- Primary color: #1A6B3C (billiard table green)
- Accent color: #D4941A (amber/gold, for Pro elements)
- Destructive color: #C62828 (red, for delete action)
- Page background: #F2F2F7
- Sheet background: #F2F2F7
- Card background: #FFFFFF
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Text tertiary: rgba(60,60,67,0.3)
- Title font: 20pt Bold
- Body font: 17pt Regular
- Caption font: 13pt Regular
- Stat number font: 22pt Bold
- Card corner radius: 12pt
- Menu corner radius: 16pt
- Button corner radius: 12pt
- Pill corner radius: 999pt
- Page horizontal padding: 16pt
- Card internal padding: 16pt
- Card gap: 8pt
- Table felt green: #1B6B3A
- Table rail brown: #7B3F00
- Cue ball white: #F5F5F5
- Object ball orange: #F5A623
- Minimum touch target: 44pt

### Reference Style

- This is a modal Sheet that slides up over the calendar page — similar to Apple Fitness activity detail or Apple Health record detail sheets
- The header area (name + stats row) follows a pattern similar to the TrainingSummaryView (P0-06) — large name + horizontal stat items with big numbers + small labels
- The drill detail cards with per-set rows are unique to this view — think of a workout log app showing each exercise with set-by-set breakdown (reps/weight per set)
- The bottom action bar follows the multi-button pattern: one primary action (filled green) + secondary actions (outlined)
- The BTOverflowMenu follows the A-06 established component: white floating card with shadow, colored circle icon backgrounds for each menu item, danger item (delete) separated by a full-width divider with red icon and red text
- The ball table mini thumbnails in drill cards use the A-08 established diagonal ball layout: simplified top-down billiard table at 40pt size
- Overall feel: a comprehensive but scannable training record sheet — the user can quickly see overall stats, then scroll through each drill's set-by-set performance

### Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- iOS native feel: SF Pro font family, SF Symbols icons throughout
- NO gradient fills on any element — all solid/flat fills
- This is a **Sheet modal** — no iOS large title navigation bar, no bottom tab bar. The sheet has its own top navigation (close button + save as template)
- The sheet should show a drag handle at top
- Minimum touch target: 44pt for all interactive elements
- Drill cards should show realistic billiard training data (进球数/总球数 format, like "12/15" meaning 12 made out of 15 total balls)
- The BTOverflowMenu must be shown in its **expanded/open state** — the floating menu is visible above the "更多" button
- The full-width divider above the "删除" danger item must have NO horizontal margin (full card width) — this is distinct from the indented dividers between normal items
- All text in Simplified Chinese
- Ball table thumbnails should be simplified but recognizable: green rectangle + brown border + 2 tiny dots for balls

### State

Detailed training session view: The user has tapped on a training session from April 2nd (a "杆法专项训练" session). The sheet shows the complete training record with 3 drills, each with their set-by-set details (all completed). Overall stats show 180 balls made across 15 sets in 42 minutes. A training note is present. The "更多" overflow menu is shown in its expanded state, floating above the bottom action bar, displaying 5 menu options with the "删除" danger option separated by a full-width divider at the bottom.
