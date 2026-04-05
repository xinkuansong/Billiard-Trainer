# Stitch Prompt — P1-04 DrillDetailView (Pro Locked State)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode only.

## Screen: DrillDetailView — Pro Locked Drill

This is the same Drill detail page as the previously approved DrillDetailView, but showing a **Pro-locked drill**. The user can see the hero billiard table, drill title, tags, and the first 2-3 training tips. The remaining training tips and all content below are hidden behind a **progressive lock** — a gradient blur transition followed by a gold lock icon, explanatory text, and a gold outline "unlock" button. This represents the freemium content gating for L2-L4 difficulty drills.

## Layout (top to bottom)

### 1. Standard iOS Navigation Bar (NOT large title)

- Pushed sub-page from DrillListView, NOT a tab root page
- Left side: standard iOS back arrow "chevron.left" + "动作库" back label, color #007AFF (system blue)
- Center title: "交叉走位训练" (example locked drill name), 17pt Semibold, color #000000
- Right side: share icon button (SF Symbol "square.and.arrow.up"), 22pt, color rgba(60,60,67,0.6)
- Navigation bar background: white, standard iOS thin bottom separator
- **NO bottom 5-tab bar** — this is a detail sub-page

### 2. Hero Billiard Table Area

- Full width, approximately 350x190pt, background color #1B6B3A (table felt green)
- **Top-down billiard table view**:
  - Green felt surface: #1B6B3A
  - Brown cushion border: #7B3F00, approximately 8pt wide on all sides
  - 6 black pockets (#000000): 4 corners + 2 side centers, circular ~12pt diameter
  - Cue ball (white #F5F5F5): positioned at approximately 38% from left, 70% from top — solid white circle ~16pt
  - Target ball (orange #F5A623): positioned at approximately 58% from left, 32% from top — solid orange circle ~16pt
  - Path lines: semi-transparent white dashed line from cue ball toward target ball, semi-transparent orange dashed line from target ball toward a pocket
- **Top-right overlay**: "收藏" capsule button — dark semi-transparent background rgba(0,0,0,0.5) + white heart icon + white text "收藏" 13pt, pill shape, height 32pt
- **Bottom-right overlay**: expand button — dark semi-transparent circle rgba(0,0,0,0.5) + white icon "arrow.up.left.and.arrow.down.right", 28pt circle

### 3. Drill Title & Info Area

- 16pt horizontal padding, 16pt top padding from hero area
- **Drill name**: "交叉走位训练" (example), 22pt Bold Rounded, color #000000
- **Action icon row** (8pt below name): 3 circular icon buttons horizontally:
  - Each: 44pt circle, light gray fill #E8E8ED, SF Symbol 20pt center, label 11pt below
  - "要点" — icon "list.bullet.rectangle"
  - "历史" — icon "clock.arrow.circlepath"
  - "图表" — icon "chart.line.uptrend.xyaxis"
  - Icon and label color: rgba(60,60,67,0.6)
- **Tag row** (8pt below icon row):
  - Ball type capsule: "中式台球" — pill, 12pt text, light gray fill #F2F2F7
  - Category capsule: "走位训练" — same style
  - BTLevelBadge: "L2 进阶" — amber light fill rgba(212,148,26,0.12) + amber text #D4941A, pill shape
  - **PRO badge**: pill shape, light gold fill rgba(212,148,26,0.12) + gold text "PRO" #D4941A 11pt Bold + thin gold border rgba(212,148,26,0.3)
  - Gap between tags: 6pt

### 4. Pinned Note Card

- White (#FFFFFF) card, corner radius 12pt, 16pt padding, 16pt horizontal margins
- 12pt top margin from tag row
- Pencil icon 16pt, color rgba(60,60,67,0.3) + placeholder text "点击此处输入备注" 15pt, color rgba(60,60,67,0.3)
- Single line, card height ~48pt

### 5. Training Tips Section — PARTIALLY VISIBLE with Progressive Lock

This is the KEY section showing the BTPremiumLock progressive lock effect:

- White (#FFFFFF) card, corner radius 12pt, 16pt internal padding, 16pt horizontal margins
- 12pt top margin from note card
- **Section header**: "训练要点" 18pt Bold, color #000000

- **Visible tips** (first 2-3 items, fully readable):
  - Green circle number bullets (20pt circle, #1A6B3C fill, white number 12pt Bold)
  - Tip text: 15pt Regular, color #000000
  - Show 3 visible tips:
    1. "母球与目标球形成交叉角度，注意瞄准偏移量"
    2. "击打后母球走位到对侧，为下一杆做准备"
    3. "控制力度在 5-6 成力，兼顾准度和走位"
  - 8pt vertical gap between items

- **Gradient blur transition zone** (immediately after tip #3):
  - The area below tip #3 begins a vertical gradient that goes from fully opaque content → progressively blurred and faded
  - Height of blur transition: approximately 60-80pt
  - Use a white-to-transparent gradient overlay that makes the text below appear to fade into blurriness
  - There should be a sense of "more content is here but hidden"

- **Gold lock section** (centered below the blur zone, still within the same white card or slightly overlapping it):
  - **Gold lock icon**: SF Symbol "lock.fill", 32pt, color #D4941A, centered horizontally
  - 8pt below icon: **Hint text**: "后面还有 4 条训练要点" (4 more tips remaining), 15pt Regular, color rgba(60,60,67,0.6), centered
  - 12pt below text: **Gold outline capsule button**: "点这里解锁" (Tap to unlock)
    - **Outline/stroke style** (NOT filled): 1.5pt border color #D4941A, transparent/white background
    - Text: "点这里解锁" 15pt Semibold, color #D4941A
    - Pill shape (999pt radius), height 40pt, horizontal padding 24pt
    - Centered horizontally

### 6. Content Below Lock — NOT VISIBLE

- The following sections from the unlocked version are **completely hidden** (not rendered at all, NOT blurred):
  - Technical Dimensions card
  - Video section card
  - Training suggestions card
  - History quick-view card
- The page ends after the progressive lock section. There should be adequate spacing (~24pt) between the lock unlock button and the bottom action bar area.

### 7. Fixed Bottom Action Bar

- Fixed at bottom of screen, above safe area
- White background with subtle top shadow (0 -1px 3px rgba(0,0,0,0.08))
- Height: ~60pt content + safe area padding
- 16pt horizontal padding
- **Left button**: "关闭" — darkPill style: #1C1C1E fill + white "✕" icon + white text "关闭" 16pt Semibold, pill shape (999pt radius), height 50pt, width ~100pt
- **Right button**: "解锁 Pro" — gold fill style: #D4941A fill + white text "解锁 Pro" 16pt Semibold, pill shape (999pt radius), height 50pt, flex width (fills remaining space, 12pt gap from left button)
  - This replaces the green "加入训练" button since the drill is locked

## Design Tokens

- Primary brand color: #1A6B3C (billiard table green)
- Accent/Pro color: #D4941A (amber/gold) — used for lock icon, outline button, PRO badge, bottom CTA
- Page background: #F2F2F7
- Card background: #FFFFFF
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Text tertiary/placeholder: rgba(60,60,67,0.3)
- Table felt: #1B6B3A
- Table cushion: #7B3F00
- Table pocket: #000000
- Cue ball: #F5F5F5
- Target ball: #F5A623
- Card corner radius: 12pt
- Button corner radius: 8pt (standard) or 999pt (pill)
- Page horizontal padding: 16pt
- Card internal padding: 16pt
- Card gap: 12pt
- Gold outline button border: 1.5pt #D4941A
- Minimum touch target: 44pt

## Reference Style

- The overall page structure is identical to the approved DrillDetailView (P1-03) — same navigation bar with back arrow and center Chinese title, same hero billiard table with diagonal ball layout, same title/icon/tag area below the hero
- The critical difference is the progressive lock effect on the training tips section: visible content smoothly transitions into a blurred/faded zone, creating a "peek behind the curtain" effect that shows valuable content exists but is locked
- The gold lock icon and outline unlock button follow the BTPremiumLock component style established in the component library (A-04) — gold #D4941A for all Pro/premium visual elements
- The bottom action bar uses the same darkPill + CTA pattern from P1-03, but the right button changes from brand green "加入训练" to gold "解锁 Pro" to clearly communicate the locked state
- The progressive lock should feel inviting rather than frustrating — the user sees enough to understand value, and the unlock path is clear and prominent

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- iOS native feel: SF Pro font family, SF Symbols icons throughout
- NO gradient fills on buttons — all solid colors for filled buttons, solid borders for outline buttons
- The gradient blur effect is ONLY used for the content fade transition in the lock zone, not decorative
- NO bottom 5-tab bar — this is a pushed detail page
- Standard iOS navigation bar with back arrow (not large title style)
- Minimum touch target: 44pt
- The gold outline unlock button must be OUTLINE/STROKE style (transparent background + #D4941A border), NOT a gold filled button — this is the progressive lock mode per A-04 design decision
- The bottom "解锁 Pro" button IS filled gold (#D4941A) — this is different from the in-content outline button, creating a clear action hierarchy
- All text in Simplified Chinese
- The page should show the hero + title + note + partial tips + lock, with the bottom bar fixed
- The BTLevelBadge for L2 uses amber color scheme (not green) to indicate higher difficulty

## State

Pro-locked drill: "交叉走位训练" (Cross-Position Training), L2 进阶 difficulty, 中式台球 ball type, 走位训练 category. Training tips show first 3 of 7 tips visible, remaining 4 locked behind gradient blur + gold lock icon + "后面还有 4 条训练要点" text + gold outline "点这里解锁" button. Technical dimensions, video, and other sections completely hidden. Bottom action bar shows gold "解锁 Pro" instead of green "加入训练". PRO badge visible in tag row.
