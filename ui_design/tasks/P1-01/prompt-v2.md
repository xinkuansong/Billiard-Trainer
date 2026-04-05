# Stitch Prompt v2 — P1-01 修正指令

Please make the following 3 corrections to the current design:

## Fix 1: Change title "动作库" to BLACK text
The large title "动作库" is currently green. Change it to **solid black (#000000)** text. This is an iOS native large title — it must be black on the light gray background, matching the "训练" title style on the Training Home tab. Do NOT use green for the page title.

## Fix 2: Add chevron arrow to every drill card
Each drill card (BTDrillCard) is missing a right-side chevron arrow. Add a small gray chevron icon (`>`) on the right edge of every card, vertically centered. Color: light gray rgba(60,60,67,0.3), size ~13pt. The chevron indicates the card is tappable and navigates to a detail page.

## Fix 3: Make L0 "入门" badge solid green fill with white text
The L0 "入门" difficulty badges currently use a light green background with green text (same style as L1). Change L0 badges specifically to use a **solid green fill (#1A6B3C) with white (#FFFFFF) text**. This distinguishes L0 (entry-level, recommended) from L1 (light green background + green text). Only L0 badges should change — L1/L2/L3/L4 badges remain as they are.
