# Stitch Prompt — P1-10 v2 (增量修正)

> 在 Stitch 同一会话中发送以下修正指令，无需重写完整 prompt。

---

Please make these corrections to the current design:

## Fix 1: Remove extra navigation bar icons

Remove the bar chart icon in the top-left corner and the "..." overflow menu in the top-right corner. The navigation bar should ONLY contain the large title "记录" — no icons or buttons at all. This matches the established pattern from our History and Statistics pages.

## Fix 2: Make locked content area show more chart silhouettes (CRITICAL)

The frosted/locked area currently looks too empty — like a blank page. This is a premium conversion screen, so the user must see THROUGH the frost that there are rich charts and data being locked away.

Behind the frosted overlay, render these visible card silhouettes (faint but recognizable shapes):

**Card 1 — Training Overview card** (top of locked area):
- A white rounded rectangle card shape clearly visible through light frost
- Inside: a faint large number placeholder "—" on the left side, and faint bar chart column shapes (5-6 vertical rectangles of varying heights) on the right side
- The card outline and internal shapes should be at ~20-30% opacity — recognizable but not readable

**Card 2 — Training Duration chart card** (below card 1):
- Another white rounded rectangle card shape, slightly more frosted than card 1
- Inside: faint amber-tinted (#F5A623 at 15% opacity) bar chart columns (8 bars of varying heights) visible as ghost shapes
- A faint dark trend line shape crossing over the bars

**Card 3 — Category Success Rate card** (below card 2, partially cut off by heavy frost):
- Only the top ~40% of this card is visible, the rest fades into near-opaque frost
- Faint green-tinted (#1A6B3C at 12% opacity) bar column shapes barely visible

The gradient overlay should progress:
- At Card 1: ~25% frost — card shape and internal elements recognizable
- At Card 2: ~50% frost — card outline visible, internal chart bars are ghost shapes
- At Card 3: ~75% frost — only the top edge and faintest bar hints visible
- Below Card 3: ~90% frost, transitioning to the lock icon area

The goal: a user looking at this screen should think "I can see there are training charts, duration trends, and success rate graphs locked behind this — I want to see my data!"

## Fix 3: Fix Tab Bar active state

The "记录" tab currently has a green circular background behind the icon. Remove this circular background. The active tab should only show the icon and text colored in brand green #1A6B3C — no background shape. Inactive tabs show icon and text in gray. This matches the standard iOS tab bar pattern used on all our other screens.
