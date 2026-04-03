# Design System: High-End Billiards Editorial

## 1. Overview & Creative North Star
**The Creative North Star: "The Elite Academy"**

This design system moves beyond basic fitness tracking to create a premium, editorial experience tailored for the discerning billiards athlete. We reject the "standard app" aesthetic in favor of a layout that feels like a high-end sports journal. 

The system achieves this through **Intentional Asymmetry** and **Tonal Depth**. While the user request specifies flat solid fills and a clean aesthetic, we elevate this by using large-scale typography and sophisticated layering of whites and cool grays to create a sense of focus. The interface shouldn't just present data; it should provide a "stage" for the user’s training journey.

---

## 2. Colors
Our palette is rooted in the "Brand Green," evocative of premium pool table felt, contrasted against a clinical, high-end iOS background scale.

### Core Palette
- **Primary:** `#005129` (The "Felt" Green) - Used for primary actions and brand emphasis.
- **Primary Container:** `#1A6B3C` - High-visibility buttons and active states.
- **Surface:** `#F9F9FE` - A slightly cooled page background to make white cards pop.
- **Surface-Container-Lowest:** `#FFFFFF` - Our primary card and elevation color.
- **On-Surface:** `#1A1C1F` - Deep charcoal for maximum readability.

### The Rules of Engagement
*   **The "No-Line" Rule:** Explicitly prohibit 1px solid borders for sectioning content. To separate "Today's Schedule" from "Upcoming," use vertical whitespace or a shift from `surface-container-low` to `surface`. Never use a stroke where a color shift can do the work.
*   **Surface Hierarchy & Nesting:** Treat the UI as a physical stack of fine paper. 
    *   *Level 0:* `background` (#f9f9fe)
    *   *Level 1:* `surface-container-low` (#f3f3f8) for grouping secondary elements.
    *   *Level 2:* `surface-container-lowest` (#ffffff) for high-priority interactive cards.
*   **The "Ghost Border" Fallback:** If a container requires a boundary (e.g., in a high-density list), use `outline-variant` (#bfc9be) at **15% opacity**. This creates a "breath" of a line rather than a hard constraint.

---

## 3. Typography
We utilize a sophisticated editorial scale. The choice of **Plus Jakarta Sans** for headlines paired with **Inter** for utility creates a balance between "Sports Prestige" and "Scientific Precision."

| Level | Token | Font | Size | Weight | Character |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Display** | `display-md` | Plus Jakarta Sans | 2.75rem | Bold | For major milestones |
| **Headline**| `headline-lg` | Plus Jakarta Sans | 2.0rem | Bold | Main Page Titles (e.g., 训练) |
| **Title** | `title-lg` | Inter | 1.375rem | SemiBold | Card Headings |
| **Body** | `body-lg` | Inter | 1.0rem | Regular | Core Training Instructions |
| **Label** | `label-md` | Inter | 0.75rem | Medium | Metadata & Captions |

*Editorial Note:* Headlines should utilize tight letter-spacing (-0.02em) to feel authoritative and "locked in," reflecting the precision of the sport.

---

## 4. Elevation & Depth
In this system, depth is a result of **Tonal Layering**, not shadows.

*   **The Layering Principle:** A card (#FFFFFF) sitting on a surface (#F9F9FE) creates enough natural contrast to define its shape. For high-priority floating elements, we utilize an **Ambient Shadow**:
    *   *Shadow Style:* 0px 4px 20px rgba(0, 0, 0, 0.04). It must be barely perceptible, mimicking natural studio lighting.
*   **Tactile Feedback:** When a card is pressed, it should not gain a shadow; it should shift its background color to `surface-container-high` (#e8e8ed), providing a physical "depressed" feel.

---

## 5. Components

### Buttons
*   **Primary (Action):** `primary-container` (#1A6B3C) background with `on-primary` (#FFFFFF) text. 
    *   *Shape:* 12pt (0.75rem) corner radius.
    *   *Interaction:* On tap, color shifts to `primary` (#005129).
*   **Secondary (Ghost):** No fill. `primary` text. `outline-variant` at 20% opacity for the border.

### Training Cards
*   **Structure:** `surface-container-lowest` (#FFFFFF) background. 
*   **Content:** Avoid internal dividers. Use `label-md` for metadata (e.g., "3 drills") and `title-lg` for the workout name.
*   **Asymmetry:** Position the "GO!" or "Action" button asymmetrically to the right to create a dynamic flow that leads the eye across the card.

### Chips (Filter & Category)
*   **Selected:** `on-background` (#1a1c1f) fill with `surface` text.
*   **Unselected:** `surface-container-highest` (#e2e2e7) fill with `on-surface-variant` text.
*   *Styling:* Use "full" (999px) roundedness for chips to contrast against the 12pt card/button radius.

### Navigation & Tab Bar
*   **Visual Treatment:** The tab bar must use a `surface-container-lowest` (#FFFFFF) background with a very subtle `outline-variant` top edge (10% opacity). 
*   **Active State:** Icons should utilize the `primary` green with a clear visual indicator (dot or font-weight shift).

---

## 6. Do's and Don'ts

### Do
*   **Do** use extreme vertical white space (32px+) to separate distinct sections like "Today's Plan" and "Official Training."
*   **Do** use "Plus Jakarta Sans" for all numbers (scores, drill counts) to highlight the "Academy" aesthetic.
*   **Do** ensure all cards have a consistent 12pt corner radius to maintain the professional, engineered feel.

### Don't
*   **Don't** use 1px solid black or dark gray dividers. If separation is needed, use a 4px height block of `surface-container-low`.
*   **Don't** use gradients or glow effects. The premium feel comes from the purity of the solid colors and the quality of the typography.
*   **Don't** crowd the edges. Maintain a minimum 20pt (1.25rem) horizontal margin for all content to allow the design to "breathe."