# Design System Document: The Precision Tactician

## 1. Overview & Creative North Star
The "Precision Tactician" is the creative north star of this design system. It moves beyond a standard sports utility app to create a high-end, editorial experience that mirrors the focus, geometry, and prestige of professional billiards. 

This system rejects the "template" look of modern mobile apps. Instead, it utilizes **intentional asymmetry**, **tonal layering**, and **cinematic scale** to create a digital environment that feels as tactile as the baize of a championship table. We balance the heritage of the sport (Deep Greens and Golds) with a cutting-edge iOS native fluidity.

**The signature aesthetic is defined by:**
*   **Breathing Room:** Aggressive use of white space to isolate data points.
*   **Layered Depth:** Physicality achieved through color shifts rather than lines.
*   **Precision Geometry:** 16pt and 12pt radii that provide a soft, "premium-weighted" hand-feel.

---

## 2. Colors
Our palette is a sophisticated interplay between the traditional "Tournament Green" and the "Championship Gold," grounded in a range of surgical neutrals.

### The Palette
*   **Primary (`#1A6B3C` / `primary_container`):** The soul of the app. Used for main action areas and headers.
*   **Secondary (`#D4941A` / `secondary`):** Reserved for moments of achievement, high-value insights, and premium CTA highlights.
*   **Surface Hierarchy:** We utilize `surface_container_lowest` (#FFFFFF) for interactive cards and `surface` (#F9F9FE) for the canvas.

### The "No-Line" Rule
Explicitly prohibited: 1px solid borders for sectioning. Boundaries must be defined solely through background color shifts. For example, a `surface_container_low` section sitting on a `surface` background creates a natural edge. This forces a cleaner, more modern editorial layout.

### The Glass & Gradient Rule
To add visual "soul," use a subtle linear gradient on primary CTAs transitioning from `primary` (#005129) to `primary_container` (#1A6B3C). For floating overlays (e.g., shot timers), use Glassmorphism: `surface_container_lowest` at 80% opacity with a 20px backdrop blur.

---

## 3. Typography
We utilize a high-contrast scale to create an editorial rhythm. The juxtaposition of rounded, friendly headers with sharp, precise body text mirrors the precision of the game.

*   **Display & Headline (Plus Jakarta Sans):** These are the "hero" moments. The 34pt Bold Rounded style (`display-sm`) should be used for large titles to provide a sporty, high-end feel.
*   **Body (Inter):** Used for all data-heavy descriptions. The `body-md` (0.875rem) provides maximum legibility for training instructions.
*   **Label (Inter):** `label-sm` (0.6875rem) in `on_surface_variant` is used for auxiliary metadata, like ball velocity or shot angles.

**Hierarchy Note:** Always lead with a `display-sm` title, but leave a generous 24px-32px gap before the first body paragraph to ensure the layout feels "custom" and not "standard."

---

## 4. Elevation & Depth
Depth in this system is achieved through **Tonal Layering** rather than traditional structural lines.

*   **The Layering Principle:** Treat the UI as stacked sheets of fine material. A `surface_container_lowest` card (White) should sit on a `surface_container_low` background to create a soft, natural lift.
*   **Ambient Shadows:** For floating elements, use a "Shadow-Glow." Shadows must be extra-diffused (24px-40px blur) and low-opacity (4%-6%). The shadow color should be tinted with `primary` (#1A6B3C) to simulate light reflecting off the billiard table.
*   **The Ghost Border:** If a container requires further definition for accessibility, use a "Ghost Border": the `outline_variant` token at 15% opacity. Never use 100% opaque borders.

---

## 5. Components

### Buttons
*   **Primary:** High-fill `primary_container` with `on_primary` text. 12pt corner radius. Use a subtle 2px inner shadow on top to give a "pressed" felt feel.
*   **Secondary:** `surface_container_highest` background with `primary` text. For lower-priority actions.
*   **Tertiary/Ghost:** No background; `primary` text with a 12pt radius hit area.

### Cards & Lists
*   **Training Cards:** Use `surface_container_lowest` (#FFFFFF) with a 16pt corner radius. **Forbid the use of divider lines.** Separate list items using 12px of vertical white space or a 4px `surface_container` gutter.
*   **Metric Chips:** Small `secondary_container` (#FCB73F) pills with `on_secondary_container` text. These should feel like small brass markers.

### Input Fields
*   **Text Inputs:** Use `surface_container_low` with a 12pt radius. The label should be `label-md` floating above the field in `on_surface_variant`. On focus, the border doesn't change color; instead, the background shifts to `surface_container_lowest`.

### Custom Billiards Components
*   **The Shot Trace:** A high-contrast visualization using `secondary` (Gold) lines over a `primary_container` (Green) canvas.
*   **Progress Rings:** Use `primary` as the track and `secondary` as the progress indicator to denote "Gold Standard" performance.

---

## 6. Do's and Don'ts

### Do
*   **Do** use asymmetrical margins (e.g., 24pt left, 16pt right) for editorial layouts to break the "grid" feel.
*   **Do** use SF Symbols for all iconography, ensuring they are "Medium" weight to match the Inter typography.
*   **Do** rely on `surface_container` tiers to separate a header from a scrollable list.

### Don't
*   **Don't** use pure black (#000000). Use `on_background` (#1A1C1F) for all text to maintain a premium softness.
*   **Don't** use standard iOS 1px separators. They clutter the "Precision" aesthetic.
*   **Don't** use shadows on every card. Only use shadows for "Floating" elements (e.g., a "Start Drill" button).
*   **Don't** crowd the screen. If a screen feels full, increase the spacing tokens and move secondary info to a sub-page.