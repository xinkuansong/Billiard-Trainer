# Stitch Prompt — P1-03 DrillDetailView (Full Detail)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode only.

## Screen: DrillDetailView — Drill Full Detail Page

This is the detail page for a single billiard training drill, pushed from the Drill Library list (DrillListView). It uses a scrollable, layered card layout containing a hero billiard table animation area, drill info, training tips, technical dimensions, video placeholder, and a fixed bottom action bar. This screen shows a fully unlocked drill with complete data.

## Layout (top to bottom)

### 1. Standard iOS Navigation Bar (NOT large title)

- This is a pushed sub-page from DrillListView, NOT a tab root page
- Left side: standard iOS back arrow "chevron.left" + "动作库" back label, color #007AFF (system blue) or brand green #1A6B3C
- Center title: Drill name abbreviated or empty (iOS standard push behavior)
- Right side: share icon button (SF Symbol "square.and.arrow.up"), 22pt, color rgba(60,60,67,0.6)
- Navigation bar background: white/translucent, standard iOS thin bottom separator
- **NO bottom 5-tab bar** — this is a detail sub-page, not a tab root

### 2. Hero Billiard Table Area

- Full width, approximately 350x190pt, background color #1B6B3A (table felt green)
- **Top-down billiard table view** occupying the full area:
  - Green felt surface: #1B6B3A
  - Brown cushion border: #7B3F00, approximately 8pt wide on all sides
  - 6 black pockets (#000000): 4 corners + 2 side centers, circular ~12pt diameter
  - Cue ball (white #F5F5F5): positioned at approximately 38% from left, 70% from top — a solid white circle ~16pt diameter
  - Target ball (orange #F5A623): positioned at approximately 58% from left, 32% from top — a solid orange circle ~16pt diameter
  - Path lines: semi-transparent white dashed line from cue ball toward target ball, semi-transparent orange dashed line from target ball toward a pocket — showing the intended shot trajectory
- **Top-right overlay**: "收藏" (Favorite) capsule button — dark semi-transparent background (rgba(0,0,0,0.5)) + white heart icon (SF Symbol "heart") + white text "收藏" 13pt — pill shape, height 32pt
- **Bottom-right overlay**: "全屏" (Fullscreen) small button — dark semi-transparent circle (rgba(0,0,0,0.5)) + white expand icon (SF Symbol "arrow.up.left.and.arrow.down.right"), 28pt circle
- **Bottom-left overlay**: small circular video thumbnail placeholder (32pt circle), subtle white border — for future video entry point

### 3. Drill Title & Info Area (below hero, on #F2F2F7 background)

- 16pt horizontal padding, 16pt top padding from hero area
- **Drill name**: "直线球定点练习" (example), 22pt Bold Rounded, color #000000
- **Action icon row** (8pt below name): 3 circular icon buttons in a horizontal row, evenly spaced:
  - Each: 44pt circle, light gray fill (#F2F2F7 or slightly darker #E8E8ED), SF Symbol icon 20pt in center, label text 11pt below
  - Button 1: "要点" (Tips) — icon "list.bullet.rectangle"
  - Button 2: "历史" (History) — icon "clock.arrow.circlepath"
  - Button 3: "图表" (Chart) — icon "chart.line.uptrend.xyaxis"
  - Icon color: rgba(60,60,67,0.6), label color: same
- **Tag row** (8pt below icon row): horizontal layout of small tags:
  - Ball type capsule: "中式台球" — tiny pill, 12pt text, light gray fill #F2F2F7, dark text
  - Category capsule: "准度训练" — same style
  - BTLevelBadge: "L1 初学" — light green fill rgba(26,107,60,0.12) + green text #1A6B3C, pill shape
  - Gap between tags: 6pt

### 4. Pinned Note Card

- White (#FFFFFF) card, corner radius 12pt, 16pt internal padding, 16pt horizontal margins
- 12pt top margin from tag row
- Left: pencil icon (SF Symbol "pencil"), 16pt, color rgba(60,60,67,0.3)
- Right of icon: placeholder text "点击此处输入备注" (Tap to enter notes), 15pt Regular, color rgba(60,60,67,0.3)
- Single line, card height ~48pt

### 5. Training Tips Section (White Card)

- White (#FFFFFF) card, corner radius 12pt, 16pt internal padding, 16pt horizontal margins
- 12pt top margin from note card
- **Section header**: "训练要点" (Training Tips), 18pt Bold, color #000000
- **Numbered list** (8pt below header), each item:
  - Bullet number in brand green circle (20pt circle, #1A6B3C fill, white number 12pt Bold)
  - Tip text: 15pt Regular, color #000000, 8pt left of the number circle
  - Example tips (show 4-5 items):
    1. "目标球对准袋口中心，确保瞄准线笔直"
    2. "母球击球点位于中心偏下，确保稳定击打"
    3. "出杆保持水平，避免翘杆导致偏差"
    4. "控制力度在 3-4 成力，关注准度而非力量"
    5. "每次出杆前完成 3 次预备动作"
  - 8pt vertical gap between items
- **Bottom button** (16pt below last item): "查看精讲" (View detailed explanation) — capsule button, brand green #1A6B3C fill + white text 14pt Semibold, pill shape (999pt radius), height 36pt, horizontally centered

### 6. Technical Dimensions Section (White Card)

- White (#FFFFFF) card, corner radius 12pt, 16pt internal padding, 16pt horizontal margins
- 12pt top margin from training tips card
- **Section header**: "训练维度" (Training Dimensions), 18pt Bold, color #000000
- **Horizontal bar chart** (12pt below header), showing 5 dimensions with horizontal progress bars:
  - Each row: dimension label (14pt Regular, color rgba(60,60,67,0.6), fixed 80pt width) + horizontal bar (flex width) + percentage value (14pt, right-aligned)
  - Dimensions:
    - "准度" (Accuracy): 85% — bar fill brand green #1A6B3C
    - "力量控制" (Power Control): 40% — bar fill brand green #1A6B3C
    - "走位判断" (Position): 60% — bar fill brand green #1A6B3C
    - "杆法技巧" (Cue Skills): 30% — bar fill brand green #1A6B3C
    - "心理素质" (Mental): 20% — bar fill brand green #1A6B3C
  - Bar background: #E5E5EA, bar height 8pt, corner radius 4pt
  - 12pt vertical gap between rows
- **Description text** below chart: "此 Drill 主要训练准度能力" 13pt Regular, color rgba(60,60,67,0.6), 8pt top margin

### 7. Video Section (White Card)

- White (#FFFFFF) card, corner radius 12pt, 16pt internal padding, 16pt horizontal margins
- 12pt top margin from dimensions card
- **Section header**: "真人示范" (Live Demonstration), 18pt Bold, color #000000
- **Horizontal scroll row** (12pt below header):
  - 6 square video thumbnails, each 56pt x 56pt, corner radius 8pt
  - Placeholder images: gray fill (#E5E5EA) with play icon overlay (white triangle in center)
  - 8pt gap between thumbnails
- **"即将上线" label** (Coming Soon): centered below thumbnails, 13pt Regular, color rgba(60,60,67,0.3), 8pt top margin
- Card bottom padding should accommodate the label

### 8. Fixed Bottom Action Bar

- Fixed at bottom of screen, above safe area
- White background with subtle top shadow (0 -1px 3px rgba(0,0,0,0.08))
- Height: ~60pt content + safe area padding below
- 16pt horizontal padding
- **Left button**: "关闭" (Close) — darkPill style: dark fill #1C1C1E + white text 16pt Semibold, pill shape (999pt radius), height 50pt, width ~100pt
- **Right button**: "加入训练" (Add to Training) — primary style: brand green #1A6B3C fill + white text 16pt Semibold, pill shape (999pt radius), height 50pt, flex width (fills remaining space with 12pt gap from left button)

## Design Tokens

- Primary brand color: #1A6B3C (billiard table green)
- Accent/Pro color: #D4941A (amber/gold)
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
- Section header: 18pt Bold
- Minimum touch target: 44pt

## Reference Style

- The hero billiard table area follows the same top-down billiard table visual established in the app's component library — green felt surface with brown cushion border, matching the training session screens (ActiveTrainingView and AngleTestView)
- Ball positions use a diagonal layout (cue ball lower-left, target ball upper-right) to show a realistic angled shot scenario, not a boring straight center-line arrangement
- Card sections below the hero follow a clean "detail page" pattern similar to fitness app exercise details — stacked white info cards on gray background, each with a section header and structured content
- The bottom action bar follows the common iOS detail-to-action pattern — dismiss on left, primary action on right
- Overall feel is informational and well-organized, like a sports training reference card

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- iOS native feel: SF Pro font family, SF Symbols icons throughout
- NO gradient fills on any element — all solid colors
- NO bottom 5-tab bar — this is a pushed detail page, not a tab root
- Standard iOS navigation bar with back arrow (not large title style)
- Minimum touch target: 44pt for all interactive elements
- Brand green #1A6B3C only for primary CTA button, badges, and bar chart fills — not for navigation elements
- The hero billiard table must show the diagonal ball layout with path trajectory lines
- Training tips numbered list should use green circle numbers for visual rhythm
- All text in Simplified Chinese
- The page should scroll: hero + title + note + tips + dimensions + video sections, with the bottom action bar fixed
- Show this as an unlocked drill — no BTPremiumLock or blur effects

## State

Full data, unlocked drill: "直线球定点练习" (Straight Ball Fixed-Point Practice), L1 初学 difficulty, 中式台球 ball type, 准度训练 category. Training tips section shows 5 tips fully visible. Technical dimensions populated. Video section in "coming soon" placeholder state. No Pro lock overlay.
