# Design System Document

## 1. Overview & Creative North Star: "The Tactical Precision"
This design system is built for the QiuJi (球迹) iOS experience—a high-performance training environment for billiards athletes. Moving beyond standard fitness apps, our "Creative North Star" is **The Tactical Precision**. 

The aesthetic is rooted in the quiet authority of a professional billiards hall: high-contrast focus, intentional geometry, and an editorial layout that prioritizes clarity over clutter. We utilize a "Flat-Depth" approach—breaking the traditional iOS grid by using oversized headlines and asymmetric chip arrangements, creating a sense of professional movement and athletic discipline. By leaning into tonal shifts rather than lines, the UI feels like a seamless tactical surface rather than a collection of boxes.

---

## 2. Colors: Tonal Depth & Discipline
We utilize a sophisticated palette where the brand green acts as a signal of expertise and action, while the neutral scale provides the "felt" texture of the training environment.

### Core Palette
*   **Primary (`#005129`):** The "Chalk Green." Use this for core actions and primary indicators.
*   **Primary Container (`#1A6B3C`):** The "Felt Green." High-visibility backgrounds for CTAs.
*   **Background (`#FAF9FE`):** A cool, crisp white that ensures high contrast and a clinical, professional feel.
*   **Surface Tiers:**
    *   `surface_container_lowest`: Pure White (`#FFFFFF`) - Use for the "closest" interactive cards.
    *   `surface_container`: Subtle Grey (`#EEEDF3`) - The standard grouping background.
    *   `surface_dim`: Soft Shadowing (`#DAD9DF`) - For deep-set utility areas.

### The "No-Line" Rule
To maintain an editorial, premium feel, **1px solid borders are strictly prohibited** for sectioning. Separation must be achieved via background shifts. For example, a training module card (`surface_container_lowest`) should sit on a page background (`background`) to create a natural, borderless definition.

### Surface Hierarchy & Nesting
Treat the screen as a series of stacked tactical layers.
*   **Layer 0 (Base):** `background` or `surface`.
*   **Layer 1 (Grouping):** `surface_container_low` for large section blocks.
*   **Layer 2 (Interaction):** `surface_container_highest` for secondary buttons or nested content.

---

## 3. Typography: Editorial Authority
We use a high-contrast typography scale to create a sense of hierarchy that feels like a premium sports magazine.

*   **Display-LG (3.5rem / Inter):** For peak achievement stats and motivational hero moments.
*   **Headline-LG (2rem / Inter Bold):** Used for main screen titles (e.g., "动作库"). This should be oversized and impactful.
*   **Title-MD (1.125rem / Inter Semibold):** For card headings and section labels.
*   **Body-LG (1rem / Inter):** The primary reading font for instructions and descriptions.
*   **Label-MD (0.75rem / Inter Medium):** For secondary metadata, using `on_surface_variant` (`#404940`) to ensure readability without competing for attention.

---

## 4. Elevation & Depth
In this system, depth is a function of light and tone, not shadows.

*   **Tonal Layering:** Instead of drop shadows, "lift" an element by moving it up the surface scale. A card with a white background (`surface_container_lowest`) on a light grey background (`surface_container_low`) creates a sophisticated, "flat" lift.
*   **Ambient Shadows:** If a floating element (like a FAB or Action Sheet) is required, use a high-dispersion shadow: `y: 8, blur: 24, spread: 0`, with the color set to `on_surface` at 5% opacity.
*   **The "Ghost Border" Fallback:** For input fields or cards that require high accessibility, use `outline_variant` (`#BFC9BE`) at 15% opacity. It should be felt, not seen.
*   **Glassmorphism:** For top navigation bars and bottom tab bars, utilize a 70% opacity `surface` with a 20pt backdrop blur. This allows the "Felt Green" and other brand elements to bleed through subtly as the user scrolls.

---

## 5. Components

### Buttons (12pt Radius)
*   **Primary:** Solid `primary_container` with `on_primary` text. No gradients.
*   **Secondary:** Solid `secondary_container` with `on_secondary_container` text.
*   **Tertiary:** Transparent background with `primary` text. Use for low-priority "Cancel" or "More" actions.

### Chips (High-Tactical Selection)
*   **Default:** `surface_container_highest` background with `on_surface_variant` text.
*   **Selected:** Solid `on_background` (Black) with `surface` text. This high-contrast flip provides immediate visual feedback.

### Lists & Cards
*   **Dividers:** Strictly forbidden. Use 16pt or 24pt vertical spacing to separate list items.
*   **List Interaction:** On tap, the background should transition briefly to `surface_container_high`.

### Input Fields
*   **Style:** Minimalist. A subtle `surface_variant` background with `on_surface` text. 
*   **Focus State:** The container background remains the same, but a 2pt `primary` ghost border (20% opacity) appears.

### Billiards-Specific Components
*   **The "Table View" Card:** A specialized container using `primary_container` to house ball-positioning diagrams, ensuring the user's focus is on the tactical layout.
*   **The "Shot Meter":** A horizontal bar using `secondary_fixed` for the track and `primary` for the progress, signifying precision and power.

---

## 6. Do's and Don'ts

### Do
*   **Do** use asymmetrical layouts for chips and filters to create a dynamic, modern feel.
*   **Do** utilize large, bold headlines that "break" the top of the grid.
*   **Do** rely on `on_surface_variant` for secondary text to maintain a soft visual hierarchy.

### Don't
*   **Don't** use 100% opaque black lines to separate content; use `surface` shifts instead.
*   **Don't** use gradients or inner glows. The aesthetic must remain "tactically flat."
*   **Don't** use standard iOS blue for links. All interactive cues must be `primary` green or `on_background` black.
*   **Don't** clutter the screen. If a piece of information isn't vital to the "shot" or "training," move it to a sub-page.