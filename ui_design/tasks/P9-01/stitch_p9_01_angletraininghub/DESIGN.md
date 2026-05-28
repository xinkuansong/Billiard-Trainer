# Design System Document: The Tactile Green

## 1. Overview & Creative North Star
**The Creative North Star: "The Modern Clubhouse"**

This design system moves away from the sterile, utilitarian nature of typical sports trackers to embrace the high-end, tactile world of professional billiards. It is a "Modern Clubhouse"—an experience that feels as premium as a bespoke felt table and as precise as a calculated bank shot. 

We break the "template" look through **Tonal Depth** and **Organic Layering**. By eschewing traditional borders in favor of background shifts and soft-focus glass effects, we create a layout that feels curated rather than constructed. The interface should breathe, using intentional white space to mirror the quiet focus required before a break.

---

## 2. Colors: Tonal Precision
The palette is anchored in `Primary (#1A6B3C)`, a deep, "Billiard Green" that evokes heritage and focus.

### The "No-Line" Rule
**Strict Mandate:** Designers are prohibited from using 1px solid borders to section content. Boundaries must be defined solely through:
- **Tonal Shifts:** Placing a `surface_container_lowest` card on a `surface_container_low` background.
- **Negative Space:** Utilizing the 24pt section gaps to imply separation.

### Surface Hierarchy & Nesting
Treat the UI as a physical stack of materials.
- **Base Level:** `background (#f9f9fe)`
- **Sectioning:** `surface_container_low (#f3f3f8)` for grouping related modules.
- **Interaction Layer:** `surface_container_lowest (#ffffff)` for primary cards and actionable items.
- **Highlight Layer:** `primary_container (#1a6b3c)` used sparingly for high-impact focus areas.

### The "Glass & Gradient" Rule
To elevate the "out-of-the-box" iOS feel, use Glassmorphism for floating navigation elements. 
- **Header/Nav:** Use `surface` colors at 85% opacity with a `20px` backdrop blur.
- **Signature Texture:** Apply a subtle linear gradient (Top-Left to Bottom-Right) from `primary` to `primary_container` on hero CTA buttons to provide a "sheen" reminiscent of polished slate.

---

## 3. Typography: Editorial Authority
We utilize a mix of **Plus Jakarta Sans** for high-impact display and **Inter** for data-heavy utility to ensure the brand feels both sophisticated and readable.

*   **Display-LG (3.5rem):** Used for "Big Wins" or major training milestones. 
*   **Headline-SM (1.5rem):** The standard for section headers, mirroring the "Large Title" request but with tighter tracking for a premium feel.
*   **Body-LG (1rem):** The primary reading weight for instructions and analysis.
*   **Label-MD (0.75rem):** Reserved for technical metadata (e.g., "Spin Rate," "Angle").

The hierarchy conveys authority: Large titles are "Rounded" to feel approachable, while body text remains sharp and technical to imply data accuracy.

---

## 4. Elevation & Depth: The Layering Principle
Depth in this system is achieved through light and material, not artificial shadows.

*   **Tonal Layering:** Place a `surface_container_lowest` (#FFFFFF) card atop a `surface_container_low` (#F3F3F8) background. This creates a "soft lift" that feels native to the eye.
*   **Ambient Shadows:** If an element must "float" (e.g., a floating action button), use a diffused shadow: 
    *   `Y: 8, Blur: 24, Color: rgba(26, 107, 60, 0.08)`. 
    *   Note the green tint in the shadow—this makes the shadow feel like a natural reflection of the "billiard green" brand rather than a generic grey.
*   **The "Ghost Border" Fallback:** If accessibility requires a stroke, use `outline_variant` at **15% opacity**. Never use a 100% opaque border.

---

## 5. Components: Tactile Objects

### Buttons
*   **Primary:** `primary` fill, `on_primary` text. Radius: `xl (1.5rem)`.
*   **Secondary:** `surface_container_highest` fill, `on_surface` text. No border.
*   **Tertiary:** Ghost style. `on_surface` text with no container.

### The "Icon Orb"
All SF Symbols (24pt) must be placed on a 48pt circle.
*   **Fill:** `rgba(26, 107, 60, 0.12)` (Brand green at 12%).
*   **Icon Color:** `primary (#1A6B3C)`.

### Cards & Lists
*   **Internal Padding:** Always 16pt.
*   **Corner Radius:** 16pt (`lg`).
*   **Constraint:** Forbid divider lines. Use 10pt vertical gaps (`card gaps`) between list items within a container to separate data points.

### Specialty: The "Drill Tracker"
A custom component for this app: A horizontally scrolling series of cards using `surface_container_lowest`. Each card features a small `primary` colored sparkline to show progress over time, nested within the 16pt internal padding.

---

## 6. Do's and Don'ts

### Do
*   **Do** use asymmetrical layouts in the header (e.g., Large Title left-aligned, profile picture slightly offset).
*   **Do** favor vertical white space (24pt) to allow the "Billiard Green" accents to pop.
*   **Do** use `surface_dim` for "disabled" states to keep the palette harmonious.

### Don't
*   **Don't** use pure black (#000000) for text. Use `on_surface` (#1A1C1F) to maintain a soft, premium feel.
*   **Don't** use standard iOS "Separator Lines" between list items. Use tonal shifts or spacing.
*   **Don't** use sharp 0px corners. Every element must feel "honed" and smooth, like a billiard ball.