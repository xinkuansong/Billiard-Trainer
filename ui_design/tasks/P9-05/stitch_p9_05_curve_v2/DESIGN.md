# Design System Documentation: The Precision Playbook

## 1. Overview & Creative North Star
This design system is built for the "Mathematical Athlete." It moves beyond a standard utility app into a high-end training environment that balances the heritage of the billiard hall with the clinical precision of modern sports science. 

**Creative North Star: The Technical Editorial.**
Our aesthetic rejects the "generic SaaS" look. Instead, we draw inspiration from premium architectural blueprints and luxury sports periodicals. We utilize intentional asymmetry, exaggerated typographic scales, and a "layered glass" philosophy to create an interface that feels like a professional-grade instrument. This is not just a tracker; it is a high-performance lab.

---

## 2. Colors: Tonal Depth & The "No-Line" Rule
The palette is anchored by the deep, authoritative **Primary (#005129)**, reminiscent of premium billiard cloth, contrasted against a crisp, airy **Surface (#faf9fe)**.

### The "No-Line" Rule
Strictly prohibit 1px solid borders for sectioning content. To define boundaries, designers must use background color shifts. A `surface_container_low` card sitting on a `surface` background provides enough contrast to be felt without being "seen" as a hard edge.

### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers. Use the following hierarchy to define importance:
- **Level 0 (Base):** `surface` (#faf9fe) - The main canvas.
- **Level 1 (Sections):** `surface_container_low` (#f4f3f8) - Broad content groupings.
- **Level 2 (Active Cards):** `surface_container_lowest` (#ffffff) - Interactive elements and primary data points.

### The Glass & Gradient Rule
To achieve a "signature" feel, floating action buttons or high-level summary cards should utilize Glassmorphism. Use `surface_container_lowest` with a 70% opacity and a 20px backdrop blur. For main CTAs, use a subtle vertical gradient from `primary` (#005129) to `primary_container` (#1a6b3c) to add "soul" and dimension.

---

## 3. Typography: The Language of Precision
We use **SF Pro** to maintain iOS native fluidity while leveraging a high-contrast scale to emphasize data.

*   **Display (lg/md/sm):** Used for "Hero Metrics" (e.g., Accuracy %). These should be tracked tight and feel like a technical readout.
*   **Headline & Title:** Used for navigation and section headers. High contrast between `headline-lg` and `label-sm` creates an editorial hierarchy.
*   **Body:** `body-md` (0.875rem) is our workhorse for descriptions and training notes, providing maximum legibility.
*   **Labels:** `label-sm` (0.6875rem) in uppercase is reserved for technical metadata (e.g., "STANCE ANGLE" or "BALL VELOCITY").

---

## 4. Elevation & Depth: Tonal Layering
Traditional shadows are a relic of the past. In this design system, we convey depth through light and material.

- **The Layering Principle:** Stack `surface_container_highest` (#e3e2e7) elements behind `surface_container_lowest` (#ffffff) cards to create a natural "lift."
- **Ambient Shadows:** When a floating effect is mandatory (e.g., a modal), use a "Billiard Shadow": a 24px blur at 4% opacity, tinted with `on_surface` (#1a1b1f). It should look like an object softly resting on felt.
- **The Ghost Border:** If a boundary is required for accessibility, use a "Ghost Border" of `outline_variant` (#bfc9be) at 15% opacity. Never use 100% opaque lines.
- **Mathematical Precision:** Charts and grids should use `outline_variant` at 10% opacity. They should be visible enough to act as a guide but faint enough to disappear when the user focuses on the data curve.

---

## 5. Components: Style & Execution

### Buttons
- **Primary:** Full-rounded (`full`: 9999px), using the `primary` to `primary_container` gradient. No shadow.
- **Secondary:** Surface-container-high (#e9e7ed) background with `on_secondary_container` text.
- **Tertiary:** Transparent background, `primary` text, with a subtle `md` (0.75rem) corner radius on hover/tap.

### Cards & Lists
- **The Rule:** No divider lines between list items. Use 12px (`md`) or 16px (`lg`) vertical spacing to separate entries.
- **Card Geometry:** All main cards must use the `md` (0.75rem/12pt) corner radius to match the iOS native aesthetic while maintaining a "snappy," professional feel.

### Charts (The Signature Component)
The "Heartbeat" of this app. 
- **Curves:** Use `primary` (#005129) with a 3pt stroke weight. Use "brand-green" fills with a 10% opacity gradient beneath the curve.
- **Grid Lines:** Only horizontal. Use `outline_variant` at 10% opacity.
- **Data Points:** Small, white circular nodes with a 1pt `primary` border.

### Chips & Tags
- **Filter Chips:** Use `secondary_container` (#caebce) with `on_secondary_container` text. 
- **Action Chips:** `surface_container_highest` for a tactile, "button-like" feel without the weight of a full CTA.

---

## 6. Do’s and Don’ts

### Do
- **Do** use whitespace as a functional tool. If the screen feels crowded, increase the spacing, don't add lines.
- **Do** use SF Symbols with "Medium" or "Semibold" weights to match the SF Pro typography.
- **Do** align all numerical data to a monospaced setting when displaying technical metrics to ensure "Mathematical Precision."

### Don’t
- **Don’t** use a standard #000000 shadow. It ruins the purity of the `surface` colors.
- **Don’t** use the `error` color (#ba1a1a) for anything other than critical failures or foul alerts. Use the Billiard green for all positive and neutral reinforcement.
- **Don’t** use 1px dividers. If you feel the need for a divider, use a 4px `surface_container_low` gap instead.