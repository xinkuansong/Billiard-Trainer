# Stitch Correction — P1-07 v2

Please make the following corrections to the HistoryCalendarView screen:

## 1. Complete the calendar to show the full month (CRITICAL)

The calendar currently only shows dates 1-12 (two rows). Please expand it to show the **complete April 2026 month** — all 30 days in a standard 6-row × 7-column grid layout:

- Row 1: (empty Mon), (empty Tue), 1 Wed, 2 Thu, 3 Fri, 4 Sat, 5 Sun
- Row 2: 6-12
- Row 3: 13-19
- Row 4: 20-26
- Row 5: 27-30, then empty slots for May 1-3

Keep the same cell style. Add training labels on these additional dates: April 8 ("准度"), April 12 ("综合"), April 15 ("走位"), April 19 ("杆法"). These should join the existing labels on April 2, 4, and 9.

## 2. Change training day labels to pill/tag style

The training labels below dates (like "杆法", "准度", "走位") are currently plain green text. Change them to **small pill tags**: brand green #1A6B3C background + white text, corner radius 4pt, horizontal padding 4pt, font 9pt Medium. The tag should look like a tiny colored badge, not just colored text.

## 3. Remove the photo/video thumbnail from training card 1

The first training card ("杆法专项训练") has a large billiard table photo with a play button overlay. **Remove this entirely.** The card should only contain: the green dot + training name + stats line (same simple layout as the second card "准度练习").

## 4. Add chevron to training cards

Add a "chevron.right" icon (13pt, color rgba(60,60,67,0.3)) on the right side of each training card, vertically centered. This indicates the card is tappable to view training details.

## 5. Remove red color from Sunday column

The weekday header "日" and weekend dates (5, 12, etc.) are currently in red. Change them to the same color as other weekdays — header in rgba(60,60,67,0.3), dates in #000000.

## 6. Remove the settings gear icon from the top-right corner

Remove the circular settings button next to the "记录" large title. The settings function is already covered by the "日历设置" pill button below. The large title should stand alone without right-side icons.
