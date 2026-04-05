# Stitch Prompt — P1-04 v2 (Incremental Fix)

Please make the following corrections to the current design. Do not change the overall layout — only fix these specific items:

## Fix 1: Navigation bar center title color
Change the center title "交叉走位训练" from green (#1A6B3C) to **pure black #000000**. The back arrow "动作库" can stay green, but the center page title must be black to match the established iOS push sub-page pattern.

## Fix 2: PRO badge style
Change the PRO badge in the tag row from solid gold fill + white text to:
- **Background**: very light gold rgba(212,148,26,0.12)
- **Text**: gold color #D4941A, 11pt Bold
- **Border**: thin 1px border rgba(212,148,26,0.3)
- Keep the pill shape

This matches the PRO badge style established in other screens of this app.

## Fix 3: L2 进阶 badge color scheme
Change the "L2 进阶" BTLevelBadge from green tones to **amber/gold tones**:
- **Background**: light amber rgba(212,148,26,0.12)
- **Text**: amber color #D4941A
- Keep the pill shape

In this app's design system, L0/L1 use green, but L2 uses amber to indicate higher difficulty.

## Fix 4: Share icon color
Change the share icon (top-right of navigation bar) from green (#1A6B3C) to **gray rgba(60,60,67,0.6)**. Secondary action icons should not compete with the primary brand color.

## Fix 5: Show 3 fully visible training tips before the lock
Currently only 2 tips are fully readable before the blur starts. Please adjust so that **3 complete tips** are fully visible and readable, then the gradient blur begins after tip #3. The lock message should still say "后面还有 4 条训练要点" (assuming 7 total tips, 3 visible + 4 locked).

Everything else looks great — keep the progressive lock blur effect, the gold outline "点这里解锁" button, the lock icon in amber circle, the bottom bar with dark "关闭" + gold "解锁 Pro", and the overall layout unchanged.
