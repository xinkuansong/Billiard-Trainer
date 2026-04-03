# Design System Strategy: The Master’s Stroke

## 1. Overview & Creative North Star: "The Precision Green"
This design system moves beyond the utility of a scoring app to become a digital extension of the billiards table itself. Our Creative North Star is **The Precision Green**—an aesthetic rooted in high-end, editorial sports journalism combined with the tactile elegance of professional pool halls.

The design breaks the "template" look by rejecting rigid, boxy grids in favor of **intentional tonal layering** and **asymmetric focal points**. We treat the screen as a high-stakes surface where negative space represents the "run of the table." By utilizing high-contrast typography scales and overlapping structural elements, we create an experience that feels as intentional as a championship-winning shot.

---

## 2. Colors: Tonal Architecture
We use color not just for branding, but to define the physical hierarchy of the interface.

*   **Primary (`#005129`):** The "Championship Cloth." Used for authoritative actions and core brand presence.
*   **Secondary (`#835500`):** The "Polished Wood." Used for progress, warmup states, and secondary momentum.
*   **Tertiary (`#91000e`):** The "Foul." Reserved strictly for destructive actions or critical errors.

### The "No-Line" Rule
**Explicit Instruction:** Designers are prohibited from using 1px solid borders for sectioning. Boundaries must be defined solely through background color shifts. For example, a `surface-container-low` section sitting on a `surface` background creates a natural boundary without the visual "noise" of a line.

### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers—like stacked sheets of fine paper.
*   **Base:** `surface` (#f9f9fe)
*   **Nested Elements:** Place a `surface-container-lowest` card on a `surface-container-low` section to create a soft, natural lift. This nesting defines importance without traditional heavy shadows.

### The "Glass & Tone" Rule
To elevate the experience, use **Glassmorphism** for floating elements (like a sticky "Live Session" bar). Use semi-transparent surface colors with a `backdrop-filter: blur(20px)` to allow the "table" (the background content) to bleed through.

---

## 3. Typography: The Editorial Scale
We use **SF Pro Rounded** (system) or **Plus Jakarta Sans** (editorial) to balance the precision of the sport with an approachable, modern feel.

*   **Display (`3.5rem`):** Reserved for "Hero" stats, like a high-break score or win percentage.
*   **Headline-LG (`2rem` / `primary`):** Used for section titles to command attention.
*   **Title-MD (`1.125rem`):** The standard for card headers.
*   **Body-MD (`0.875rem`):** Optimized for readability in drills and training logs.

**Hierarchy Strategy:** Use `on-surface-variant` for metadata and `primary` for headlines to create a clear "read-first, read-second" flow that mimics a premium sports magazine.

---

## 4. Elevation & Depth: Tonal Layering
Traditional shadows and borders are discarded in favor of **Ambient Depth**.

*   **The Layering Principle:** Stacking tiers (e.g., `surface-container-lowest` on `surface-container-high`) creates a "soft lift."
*   **Ambient Shadows:** If a floating action button (FAB) or modal requires a shadow, it must be ultra-diffused. Use a 24pt-32pt blur at 6% opacity, using a tinted `on-surface` color rather than pure black.
*   **The "Ghost Border" Fallback:** If accessibility requires a border, use the `outline-variant` token at **15% opacity**. Never use 100% opaque borders.
*   **Tactile Feedback:** Use `surface-bright` for active states to make the component appear to "catch the light."

---

## 5. Components: The Billiards Toolkit

### Buttons & Inputs
*   **Primary CTA:** Uses `primary_container` (#1A6B3C). Minimum 44pt touch target. No gradients, but a subtle 4% `on-primary` inner glow is permitted for a "pressed" feel.
*   **Ghost Inputs:** Text fields should not have boxes. Use a `surface-container-highest` bottom-only highlight or a subtle tonal shift for the entire input area.

### Cards & Lists
*   **The Divider Prohibition:** Forbid the use of divider lines. Use **24pt vertical white space** or a shift from `surface-container-low` to `surface-container-lowest` to separate drills or match history items.
*   **Cards:** Radius is fixed at `xl` (1.5rem / 24pt) for a premium, hand-held feel. Padding is a strict 16pt.

### Training-Specific Components
*   **The Heatmap Chip:** Small chips using `secondary_container` to indicate "warmup" areas or ball frequency.
*   **Progress Orbs:** Instead of a flat bar, use a series of `surface-variant` dots that fill with `primary` as drills are completed.

---

## 6. Do's and Don'ts

### Do
*   **Do** use `primary_fixed` for background accents to create "vignettes" around important data.
*   **Do** leverage `SF Pro Rounded` to soften the "math-heavy" nature of billiards training.
*   **Do** ensure all interactive elements maintain a 44pt hit area, even if the visual asset is smaller.

### Don't
*   **Don't** use 1px dividers. It clutters the "table."
*   **Don't** use pure black (#000000) for text. Use `on-surface` (#1a1c1f) for a high-end, ink-on-paper look.
*   **Don't** use standard iOS "Blue." Every accent must be `primary` (Green) or `secondary` (Orange) to reinforce the QiuJi brand identity.