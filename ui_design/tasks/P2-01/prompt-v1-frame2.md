# Stitch Prompt — P2-01 Frame 2: PlanDetailView (Official Plan Detail with Pro Lock)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode only.

## Screen: PlanDetailView — Official Training Plan Detail (Pro Locked)

This is the detail page for a single official training plan, pushed from PlanListView. It shows the plan's full information, weekly schedule, and a CTA to activate the plan. This screen displays a **Pro-locked plan** — the first 1-2 weeks of content are visible, then a progressive blur lock (BTPremiumLock) covers the remaining weeks with a gold unlock prompt. Users see enough to understand the plan's value before being prompted to upgrade.

## Layout (top to bottom)

### 1. Standard iOS Navigation Bar (Push Sub-page)

- Pushed from PlanListView — standard iOS navigation style
- Left side: back arrow "chevron.left" + "训练计划" back label, color #007AFF (system blue)
- Center title: "走位突破训练" (plan name), 17pt Semibold, color #000000
- Right side: share icon button (SF Symbol "square.and.arrow.up"), 22pt, color rgba(60,60,67,0.6)
- Navigation bar background: white/translucent with thin bottom separator
- **NO bottom 5-tab bar** — this is a detail sub-page

### 2. Plan Header Card (White Card)

- White (#FFFFFF) card, corner radius 16pt, 16pt internal padding, 16pt horizontal margins
- 12pt top margin from navigation bar area

**Layout:**
- **Plan name**: "走位突破训练" (Position Breakthrough Training), 22pt Bold Rounded, color #000000
- **Tag row** (6pt below name): horizontal tags:
  - BTLevelBadge: "L2 进阶" — light amber fill rgba(212,148,26,0.12) + amber text #D4941A, pill shape, 12pt Bold
  - Duration: "6 周" — light gray fill #F2F2F7, dark text, pill, 12pt
  - "PRO" capsule badge — light gold fill rgba(212,148,26,0.12) + gold text #D4941A, 11pt Bold, pill shape
  - Gap between tags: 6pt
- **Goal description** (8pt below tags): "系统训练走位能力与母球控制，从基础定位到复杂局面的走位规划", 15pt Regular, color rgba(60,60,67,0.6), max 3 lines

### 3. Statistics Row (Inside Header Card or Separate Card)

- Horizontal layout of 3 stat items, evenly distributed within the header card
- 16pt top margin from goal description, separated by a thin divider line (#E5E5EA) above
- Each stat item:
  - Large number: 28pt Bold, color #000000
  - Label below: 13pt Regular, color rgba(60,60,67,0.6)
- Stats:
  - "42" + "训练天数" (Training Days)
  - "18" + "训练项目" (Drill Items)
  - "45 分钟" + "预计每日" (Estimated Daily)

### 4. Activate Button

- 16pt horizontal margins, 16pt top margin from stats
- Full width button: brand green #1A6B3C fill + white text "开始此计划" (Start This Plan) 16pt Semibold
- Height 50pt, corner radius 12pt
- Since this is a Pro plan, the button should show a lock icon (SF Symbol "lock.fill") before the text: "🔒 开始此计划" — but the button itself is still brand green (tapping will trigger the paywall)
- Alternatively, the button can read "解锁并开始" (Unlock & Start) with gold #D4941A fill + white text to indicate it's a Pro action

**Design choice**: Use gold #D4941A fill + white text + lock icon: "解锁此计划" (Unlock This Plan), 16pt Semibold, 50pt height, 12pt corner radius — this clearly signals Pro upgrade action, consistent with the gold CTA pattern established in Pro lock screens

### 5. Weekly Schedule Section (Expandable List)

- 16pt horizontal margins, 20pt top margin from activate button
- Section title: "训练安排" (Training Schedule), 18pt Bold, color #000000

#### Week Groups (Visible — First 2 Weeks)

Each week is a collapsible group within a white card:

**Week Card** (white #FFFFFF, corner radius 12pt, 16pt internal padding):
- **Week header row** (tappable to expand/collapse):
  - Left: "第 1 周" (Week 1), 16pt Semibold, color #000000
  - Right: expand/collapse chevron (SF Symbol "chevron.down" or "chevron.up"), 14pt, color rgba(60,60,67,0.3)
  - If expanded, a thin #E5E5EA separator line below header
- **Day rows** (when expanded), 8pt vertical gap between days:
  - Day label: "第 1 天" (Day 1), 14pt Semibold, color rgba(60,60,67,0.6)
  - Drill list below day label (4pt gap):
    - Each drill: "• 直线球定点练习 — 3 组 × 15 球", 14pt Regular, color #000000
    - 4pt gap between drill rows
  - Show 2-3 drills per day

**Week 1** (expanded, showing day details):
- 第 1 天: "直线球定点练习" 3组×15球, "定杆基础训练" 2组×10球
- 第 2 天: "五分点准度训练" 4组×15球, "低杆回缩控制" 3组×10球
- 第 3 天: 综合测试日 (can show abbreviated)
- (Show 3 days expanded, remaining 2 days collapsed with "第 4 天" / "第 5 天" as collapsed rows)

**Week 2** (collapsed — only header visible):
- "第 2 周" + chevron.right

8pt gap between week cards

#### Remaining Weeks — BTPremiumLock Progressive Blur

After Week 2, the content transitions into a progressive blur lock:

- **Visible-to-blur transition**: Week 3 card starts to appear but fades into a gaussian blur gradient over ~60pt vertical distance
- **Lock area** (below the blur zone):
  - Centered amber circular container: 56pt circle, fill #FFDDAF (light amber), containing a lock icon (SF Symbol "lock.fill") 24pt, color #D4941A (deep gold)
  - 12pt below lock icon: prompt text "后面还有 4 周训练计划" (4 more weeks of training plan), 15pt Semibold, color #000000, centered
  - 8pt below: secondary text "解锁 Pro 查看完整计划" (Unlock Pro to see full plan), 13pt Regular, color rgba(60,60,67,0.6), centered
  - 16pt below: gold outline capsule button "点这里解锁" (Tap to unlock) — border 1.5pt #D4941A + text #D4941A 14pt Semibold, pill shape (999pt radius), height 36pt, horizontally centered — **outline style, NOT filled** (consistent with progressive lock pattern: outline for in-content CTA, filled for primary CTA)

### 6. Bottom Safe Area Padding
- 34pt safe area at bottom

## Design Tokens

- Primary brand color: #1A6B3C (billiard table green)
- Accent/Pro color: #D4941A (amber/gold)
- Lock icon container: #FFDDAF (light amber circle)
- Page background: #F2F2F7
- Card background: #FFFFFF
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Text tertiary: rgba(60,60,67,0.3)
- Separator: #E5E5EA
- Card corner radius: 12pt (standard), 16pt (header card)
- Page horizontal padding: 16pt
- Card internal padding: 16pt
- Card gap: 8pt
- Section gap: 20pt
- Minimum touch target: 44pt

## Reference Style

- The header card follows the same "detail page hero" pattern as DrillDetailView — page title + tags + description in a prominent top card
- Statistics row uses the same "large number + small label" horizontal layout established in TrainingSummaryView and TrainingDetailView
- The expandable week list is similar to iOS Settings grouped list with disclosure indicators — clean white cards with collapsible sections
- The BTPremiumLock progressive blur follows the exact pattern from DrillDetailView Pro lock: content fades into blur → amber lock container → prompt text → gold outline button
- The gold "解锁此计划" CTA button at the top signals this is a Pro plan, matching the amber/gold Pro visual system used throughout the app
- Overall feel is an informational plan overview that reveals enough to motivate upgrade

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- iOS native feel: SF Pro font family, SF Symbols icons throughout
- NO gradient fills on any solid element — all solid colors (the blur gradient for lock is an exception, it's a transparency effect)
- NO bottom 5-tab bar — this is a pushed detail sub-page
- Standard iOS navigation bar with back arrow (not large title)
- Minimum touch target: 44pt
- BTPremiumLock progressive blur must show a clear transition from visible content to blurred, with the amber lock zone below
- Gold outline button "点这里解锁" must be OUTLINE style (border only, not filled) — consistent with the app's progressive lock CTA pattern
- The gold filled CTA button "解锁此计划" at the top is the strong action; the in-content gold outline is the gentle nudge — intentional visual hierarchy
- BTLevelBadge "L2 进阶" must use amber color scheme
- All text in Simplified Chinese
- Week 1 should be expanded showing drill details; other visible weeks collapsed

## State

Pro-locked plan detail: "走位突破训练" (Position Breakthrough Training), L2 进阶, 6 weeks, 42 training days, 18 drills. Week 1 is expanded showing daily drill assignments. Weeks 3-6 are hidden behind the BTPremiumLock progressive blur. The activate button shows as gold "解锁此计划" indicating Pro upgrade required.
