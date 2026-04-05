# The Design System: Tactical Precision & Heritage

## 1. Overview & Creative North Star
The Creative North Star for this design system is **"The Digital Pro-Shop."** 

Billiards is a game of extreme precision, quiet focus, and tactile tradition. This system moves beyond a standard "iOS port" by treating the interface like a premium, physical training environment. We are breaking the "template" look by utilizing **Tactile Layering** and **Asymmetric Balance**. 

Instead of a rigid, centered grid, we use wide-margin editorial layouts that allow the typography to breathe. This isn't just an app; it’s a high-performance coaching tool. We favor "Breathing Room" over "Information Density," ensuring that even the most complex drill data feels as intentional as a perfectly placed cue ball.

---

## 2. Colors: The Baize & The Light
The palette is rooted in the rich, deep greens of professional tournament cloth, accented by the warm glow of amber overhead lighting.

### Tonal Tokens
- **Surface (Background):** `#F2F2F7` (The iOS System Secondary Background)
- **Primary (The Baize):** `#1A6B3C` (Used for key brand moments and heavy action)
- **Secondary (The Amber):** `#D4941A` (Used for focus states, progression, and "Gold" achievements)
- **Surface-Lowest (The Card):** `#FFFFFF` (The purest white for interaction layers)

### The "No-Line" Rule
**Designers are prohibited from using 1px solid borders for sectioning.** To define boundaries, use tonal shifts. A `#FFFFFF` card should sit on the `#F2F2F7` background to create a natural edge. If a sub-section is needed within a card, use a subtle shift to `surface_container` (`#EDEDF2`) rather than drawing a line.

### The "Glass & Gradient" Rule
To elevate the "Premium Fitness" feel, use **Glassmorphism** for bottom tab bars and floating headers. Use `surface_container_lowest` at 80% opacity with a `20px` backdrop blur. For primary CTAs, apply a subtle linear gradient from `primary` (`#1A6B3C`) to `primary_container` (`#005129`) at a 145° angle to simulate the sheen of high-quality felt.

---

## 3. Typography: Editorial Authority
We utilize **SF Pro** with an emphasis on the **Rounded** variant for titles to mimic the soft curves of billiard balls and table cushions.

| Token | Font Face | Size | Weight | Intent |
| :--- | :--- | :--- | :--- | :--- |
| **Display-LG** | SF Pro Rounded | 34pt | Bold | Large Titles (iOS Style) |
| **Headline-MD** | SF Pro | 22pt | Semibold | Section Headers |
| **Title-SM** | SF Pro | 17pt | Semibold | Card Titles |
| **Body-LG** | SF Pro | 17pt | Regular | Primary Reading Content |
| **Body-MD** | SF Pro | 15pt | Regular | Secondary Info (Secondary Text Color) |
| **Label-SM** | SF Pro | 12pt | Medium | Captions & Metadata |

**Editorial Note:** Use `rgba(60, 60, 67, 0.6)` for `Body-MD` and `Label-SM` to create a sophisticated hierarchy. This "faded" look reduces cognitive load and makes the `Primary Black` titles pop with authority.

---

## 4. Elevation & Depth: Tonal Layering
Traditional shadows are too heavy for a "Quiet Focus" app. We achieve depth through **Physical Stacking**.

*   **The Layering Principle:** 
    *   **Level 0 (Base):** `#F2F2F7` (The floor)
    *   **Level 1 (Content):** `#FFFFFF` (The card/sheet)
    *   **Level 2 (Active Elements):** Glassmorphic overlays with a 4% ambient shadow.
*   **Ambient Shadows:** If a card must float (e.g., a "Start Training" button), use a shadow color of `rgba(26, 107, 60, 0.08)` with a `24px` blur and `8px` Y-offset. This "Green-Tinted" shadow feels more natural than grey.
*   **The Ghost Border:** For accessibility in input fields, use a `1px` border of `outline_variant` (`#BFC9BE`) at **20% opacity**. It should be felt, not seen.

---

## 5. Components: Precision Tools

### Cards & Lists
*   **Standard Card:** Background `#FFFFFF`, Radius `16pt`. No borders.
*   **Inner Card:** Background `surface_container_low` (`#F3F3F8`), Radius `12pt`.
*   **The "No-Divider" Rule:** In lists, never use horizontal lines. Use `16pt` vertical spacing to separate items. If a grouping is required, wrap the items in a single white card.

### Buttons
*   **Primary CTA:** `primary` background, `on_primary` text. Rounded `full` (pill shape).
*   **Secondary CTA:** `surface_container` background, `primary` text.
*   **Progress Button:** Use the `secondary` (Amber) color specifically for "Level Up" or "Achievement" actions to signify high value.

### Chips (Drill Tags)
*   **Selection Chips:** Use a `12pt` radius. Unselected states should be `surface_container_highest` (`#E2E2E7`) with `secondary_text`. Selected states use `primary` with `white` text.

### Interactive "Cue" Inputs
*   For numerical inputs (e.g., "Points Scored"), use large `Headline-LG` typography with a subtle `secondary` color underline to emphasize the "Editorial" feel over a "Form" feel.

---

## 6. Do's and Don'ts

### Do
*   **Do** use SF Symbols with "Semibold" weight to match the SF Pro typography.
*   **Do** lean into asymmetry. For example, a "Stats" card can have a large 34pt number on the left and 12pt labels stacked on the right.
*   **Do** use the Amber accent sparingly for "Success" states and progress bars to maintain a premium feel.

### Don't
*   **Don't** use high-contrast black borders or separators. This breaks the "Pro-Shop" elegance.
*   **Don't** use standard iOS "Blue" for links. Always use `Primary Green` or `Secondary Amber`.
*   **Don't** crowd the edges. Maintain a minimum of `20pt` horizontal padding for all screen-level containers.

---

## 7. Signature Pattern: The "Drill Path"
When displaying billiard drills, avoid a standard list. Use a **Vertical Timeline** pattern where the "line" of the timeline is the `Primary Green` and the "nodes" are `surface_container_lowest` circles. This mimics the visual language of a diagrammed shot on a table.