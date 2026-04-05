# The Design System: Editorial Precision in Motion

## 1. Overview & Creative North Star: "The Tactical Precision"
This design system moves beyond a standard sports utility app to create a high-end, editorial training experience. The Creative North Star is **Tactical Precision**. Just as a professional player views a billiards table as a canvas of geometry and physics, our UI treats the screen as a sophisticated workspace defined by mathematical clarity and breathable elegance.

We reject the "boxed-in" nature of mobile templates. Instead, we embrace **Intentional Asymmetry** and **Tonal Depth**. By utilizing wide margins, overlapping elements, and a hierarchy that prioritizes data visualization over decorative lines, we create an environment that feels authoritative, calm, and premium.

---

## 2. Colors: Tonal Layers & The "No-Line" Rule
The palette is rooted in the heritage of the sport. We use the deep, resonant `primary` (#1A6B3C) not just as a color, but as a signature of quality.

### Color Tokens
*   **Surface Foundation:** `surface` (#F9F9FE) and `surface_container_low` (#F3F3F8) provide a crisp, modern alternative to standard greys.
*   **The Signature Green:** `primary` (#005129) and `primary_container` (#1A6B3C) represent the felt—tactile and focused.
*   **The Counter-Accent:** `tertiary` (#782C38) is reserved for "breaking" moments—foul indicators or high-intensity focus areas—mimicking the red of a snooker ball or a leather bridge.

### The "No-Line" Rule
**Explicit Instruction:** Traditional 1px solid borders are prohibited for sectioning. We define space through "The Tonal Shift." Boundaries are created by nesting a `surface_container_highest` (#E2E2E7) element against a `surface` background. This creates a sophisticated, "carved" look rather than a "sketched" look.

### The "Glass & Gradient" Rule
To add soul to the tactical aesthetic, use **Glassmorphism** for floating action bars or persistent stats. Apply a backdrop blur (20pt-30pt) to a 70% opacity `surface_container_lowest`. For main CTAs, use a subtle linear gradient from `primary` (#005129) to `primary_container` (#1A6B3C) at a 135-degree angle to give the button a slight "sheen" reminiscent of a polished billiard ball.

---

## 3. Typography: The Editorial Scale
We utilize **SF Pro** (Inter-flavored) to maintain iOS native performance while pushing layout boundaries. Typography is the primary driver of the "Tactical" feel.

*   **Display (Editorial Hero):** Use `display-lg` for large numeric data (e.g., Accuracy %). These should feel like a magazine header—heavy, confident, and slightly offset.
*   **Headlines & Titles:** `headline-sm` is used for drill titles. Pair this with `label-md` in all caps with +5% letter spacing to create a "Technical Blueprint" aesthetic.
*   **Body & Labels:** `body-md` is our workhorse. For secondary metadata, use `on_surface_variant` (#404940) to ensure high readability without the harshness of pure black.

---

## 4. Elevation & Depth: The Layering Principle
Depth in this system is a result of **Tonal Stacking**, not shadows.

*   **The Layering Principle:** 
    *   Level 0: `surface` (Base layer/Main background)
    *   Level 1: `surface_container_low` (In-feed sections/Drill categories)
    *   Level 2: `surface_container_lowest` (Individual interactive cards)
*   **Ambient Shadows:** If an element must float (e.g., a cue-ball positioner), use a "Billiard Shadow": Color: `on_surface` (#1A1C1F) at 6% opacity, Blur: 24pt, Y-Offset: 12pt.
*   **The Ghost Border:** For capsule buttons or secondary inputs, use the `outline_variant` token at 20% opacity. This "Ghost Border" provides just enough definition for accessibility without breaking the minimalist aesthetic.

---

## 5. Components: Precision Primitives

### Buttons
*   **Primary:** `primary_container` (#1A6B3C) fill, `on_primary` (#FFFFFF) text. Corner radius: `md` (0.75rem / 12pt). 
*   **Capsule:** Fill `on_surface` at 0.06 opacity. Border: 1px "Ghost Border" (outline_variant at 20%). Radius: `full`.
*   **Text-only:** Use `on_surface_variant` (#404940). Reserved for "Cancel" or secondary navigation.

### Cards & Lists (The Divider-Free Rule)
Forbid the use of horizontal divider lines. 
*   **Lists:** Use vertical white space (1.5rem / `xl`) to separate list items. 
*   **Cards:** Use a `surface_container_lowest` background on a `surface_container_low` backdrop. This "nested glass" effect creates visual separation through tone alone.

### Tactical Inputs (Specific to QiuJi)
*   **The Coordinate Picker:** A circular surface using `surface_container_highest` with a `primary` crosshair.
*   **The Drill Progress Bar:** A thin (4pt) track using `outline_variant` with a `primary` fill. No rounded caps; keep ends square for a technical, "measured" feel.

---

## 6. Do’s and Don’ts

### Do:
*   **Do** use asymmetrical margins. For example, a 24pt left margin for text and a 16pt right margin for graphics to create editorial tension.
*   **Do** lean into white space. If a screen feels "empty," it’s likely working correctly.
*   **Do** use `tertiary` colors for high-stakes feedback (failing a drill or a missing cue-ball placement).

### Don't:
*   **Don’t** use high-contrast black borders or separators. It ruins the "Tactical Precision" atmosphere.
*   **Don’t** use standard iOS "System Blue" for links. Every interactive element must be rooted in the `primary` or `on_surface_variant` tokens.
*   **Don’t** crowd the interface. If more than three metrics are on screen, use a horizontal scroll (carousel) rather than stacking them vertically.