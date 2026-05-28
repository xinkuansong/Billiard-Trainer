# Design System Document: The Tactile Precision System

## 1. Overview & Creative North Star
The Creative North Star for this design system is **"The Architectural Athlete."** 

Billiards is a game of extreme precision, quiet confidence, and tactile feedback. This system moves away from generic sports app tropes, instead drawing inspiration from high-end horology and architectural drafting. We are not just building a tracker; we are building a digital "cuesport atelier."

The experience is defined by **Intentional Negative Space** and **Asymmetric Balance**. While we honor the iOS native DNA, we elevate it through a "Felt & Glass" philosophy—utilizing the depth of a billiard table to inform a layered, sophisticated interface that feels both grounded and premium.

---

## 2. Colors: Tonal Depth over Borders
Our palette is rooted in the heritage of the game, utilizing `primary` (#005129) and `primary_container` (#1A6B3C) to represent the deep wool of a championship table.

### The "No-Line" Rule
To achieve a high-end editorial feel, **1px solid borders are strictly prohibited for sectioning.** Structural separation must be achieved through:
- **Background Shifts:** Use `surface_container_low` (#f3f3f8) for the main page background and `surface_container_lowest` (#ffffff) for card elements.
- **Tonal Contrast:** Place `primary_container` elements directly against `surface` to create natural edges without artificial strokes.

### Surface Hierarchy & Nesting
Treat the UI as a physical environment. 
1. **Base Layer:** `background` (#f9f9fe)
2. **Sectional Layer:** `surface_container` (#ededf2) for grouped content.
3. **Interactive Layer:** `surface_container_lowest` (#ffffff) for primary cards and input fields.
4. **The Canvas:** `surface_tint` (#1b6c3d) specifically for billiard table visualizations to create a "recessed" feel.

### The "Glass & Gradient" Rule
While the core request specifies solid colors, premium polish is achieved through **Glassmorphism**. For floating action buttons or sticky headers, use `surface_container_lowest` at 80% opacity with a `20px` backdrop blur. This ensures the rich `primary` green of the training "canvas" bleeds through, maintaining a sense of place.

---

## 3. Typography: The Editorial Scale
We use **SF Pro (Inter fallback)** to maintain iOS familiarity but apply an editorial weight distribution to create a "Signature" look.

*   **Display (The Scoreboard):** `display-lg` (3.5rem) is reserved for primary performance metrics. It should be tracked tightly (-0.02em) to feel like a premium stopwatch.
*   **Headlines (The Chapter):** `headline-md` (1.75rem) uses high-contrast weights to define new training modules.
*   **Body (The Instruction):** `body-md` (0.875rem) provides maximum readability for drill instructions.
*   **Labels (The Metadata):** `label-sm` (0.6875rem) in `on_surface_variant` (#404940) provides secondary context without cluttering the visual field.

---

## 4. Elevation & Depth: Tonal Layering
Traditional shadows are too heavy for a precision app. We use **Ambient Layering**.

### The Layering Principle
Hierarchy is achieved by "stacking" the surface tiers. A `surface_container_lowest` card placed on a `surface_container_low` background creates a soft, natural lift.

### Ambient Shadows
Where a "floating" effect is mandatory (e.g., a cue-ball selector), use an extra-diffused shadow:
- **Y-Offset:** 4px | **Blur:** 24px
- **Color:** `on_surface` (#1a1c1f) at 6% opacity. This mimics natural studio lighting.

### The "Ghost Border" Fallback
For the specified input fields, use a **Ghost Border**: `outline` (#707a70) at 15% opacity. This provides the 2pt structure requested while maintaining the premium, non-cluttered aesthetic.

---

## 5. Components

### Primary Buttons
- **Fill:** `primary_container` (#1A6B3C).
- **Text:** `on_primary` (#ffffff), `title-sm` (Bold).
- **Radius:** `md` (0.75rem / 12pt).
- **Style:** No shadow. The depth is achieved through the high-contrast color against the light background.

### Input Fields (The Focus Component)
- **Border:** 2pt `primary` (#005129) or a "Ghost Border" depending on state.
- **Text:** `display-sm` (2.25rem), centered. 
- **Context:** Place on `surface_container_lowest` for maximum focus.

### Statistics Grid (2x2)
- **Layout:** Asymmetric spacing. The left column should be slightly wider than the right to break the "standard grid" feel.
- **Values:** `display-md` (2.75rem) Bold.
- **Labels:** `label-md` (0.75rem) uppercase, tracked out (+0.1em).
- **Note:** Forbid dividers. Use 24pt gutter spacing to define the quadrants.

### Training Cards
- **Structure:** `surface_container_lowest` fill, `md` (12pt) corner radius.
- **Margins:** 16pt horizontal.
- **Nesting:** Small `secondary_container` chips within the card to denote "Drill Type."

### Cue-Ball Navigation (Specialty Component)
A custom selector using `surface_container_highest` (#e2e2e7) with a `full` (9999px) radius to mimic the physical form of a billiard ball.

---

## 6. Do's and Don'ts

### Do
- **Do** use `surface_dim` for "inactive" training states to maintain a sophisticated palette.
- **Do** leverage the `surface_container` tiers to create hierarchy without lines.
- **Do** allow the `display` typography to breathe with at least 32pt of vertical padding.

### Don't
- **Don't** use 100% black text. Use `on_surface` (#1a1c1f) for a softer, more premium reading experience.
- **Don't** use standard iOS dividers between list items. Use 12pt of vertical whitespace or a subtle shift from `surface` to `surface_container_low`.
- **Don't** use sharp corners. Everything must adhere to the `md` (12pt) or `full` roundedness scale to mimic the curves of the game.