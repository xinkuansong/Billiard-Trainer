# Design System Document

## 1. Overview & Creative North Star
The Creative North Star for this design system is **"The Disciplined Athlete."** 

This system transcends the typical "recreational app" look by adopting a high-end, editorial approach to sports science. It mimics the precision of a professional billiards table—where every millimeter matters. We move away from the generic iOS list-view by utilizing a sophisticated architectural layout: intentional asymmetry, "breathe-first" spacing, and a tonal depth that reflects the hushed, focused environment of a championship match. The goal is to make training feel like an elite consultation, combining the technicality of a reference manual with the fluid, premium feel of modern native hardware.

## 2. Colors
Our palette is rooted in the deep, concentrated tones of the pool hall, elevated for a high-contrast digital interface.

### Tonal Foundation
*   **Primary (#005129):** The "Championship Green." Used for high-priority actions and brand signaling.
*   **Primary Container (#1A6B3C):** Used for large surface areas like Hero sections or headers to provide a lush, immersive background.
*   **Surface (#F9F9FE):** The default page background. A crisp, cool-toned white that prevents the "yellowing" effect of standard neutrals.
*   **Surface Container (Low to Highest):** These are your structural workhorses (#F3F3F8 to #E2E2E7).
*   **Tertiary (#6E3800):** Inspired by the "Table Cushion," used sparingly for accents, wood-grain warmth, or high-level progress indicators.

### The Editorial Rules
*   **The "No-Line" Rule:** 1px solid borders are strictly prohibited for sectioning. Separation must be achieved through background shifts. A `surface-container-lowest` card (#FFFFFF) should sit on a `surface` background (#F9F9FE) to create a natural, borderless boundary.
*   **Surface Hierarchy & Nesting:** Treat the UI as a physical stack. The most important data sits on the "highest" elevation (brightest surface). Use `surface-container-high` for sub-sections within a primary card to define hierarchy without adding visual noise.
*   **Glass & Gradient:** For floating navigation or action bars, use Glassmorphism (Surface color at 80% opacity with a 20px backdrop-blur). Main CTAs should feature a subtle linear gradient from `primary` to `primary-container` at a 135° angle to provide a "felt-like" depth.

## 3. Typography
We use a dual-personality typographic scale to balance technical precision with approachable modernism.

*   **Display & Headlines (Plus Jakarta Sans):** These are our "Impact" levels. Used for training module titles and score summaries. The font’s wider stance provides an authoritative, editorial feel.
*   **Title & Body (Inter / SF Pro):** For information density. We leverage **Rounded weights** for Titles (Title-LG, Title-MD) to echo the geometry of the billiard ball, while using standard Inter for Body text to ensure maximum legibility during intense training sessions.
*   **Hierarchy as Identity:** Use `display-md` for hero stats and `label-sm` in all-caps (with +5% letter spacing) for technical metadata. This contrast—massive numbers against tiny, precise labels—creates the "Professional Reference" aesthetic.

## 4. Elevation & Depth
Depth in this design system is felt, not seen. We move away from heavy, dated shadows in favor of light and physics.

*   **The Layering Principle:** Depth is achieved by stacking. Place a `surface-container-lowest` card on top of a `surface-container-low` area. The 2-3% difference in hex value is enough for the human eye to perceive a "step," maintaining a clean, "flat-plus" look.
*   **Ambient Shadows:** If a card must float (e.g., a "Current Drill" tracker), use an extra-diffused shadow: `Y: 8, Blur: 24, Color: rgba(0, 81, 41, 0.06)`. Note the green tint in the shadow—this makes the element feel like it is reflecting the table's "felt," rather than sitting in a grey void.
*   **The "Ghost Border" Fallback:** For high-density data tables where boundaries are essential, use the `outline-variant` token at 15% opacity. It should be barely perceptible—a "whisper" of a line.

## 5. Components

### Buttons
*   **Primary (Pill-shaped, 999pt):** Solid `primary` fill with `on-primary` text. No border. High-gloss gradient active state.
*   **Secondary:** `surface-container-high` fill with `primary` text. For secondary actions like "Save for Later."
*   **Tertiary:** Ghost style. No fill, `primary` text. Used for "Cancel" or "Back."

### Cards & Lists
*   **Training Cards:** 12pt corner radius (`md` scale). Forbid divider lines. Separate list items using 12px or 16px of vertical white space.
*   **Nested Cards:** A card within a card must use a contrasting surface token (e.g., a `surface-variant` card inside a `surface-container-lowest` parent).

### Specialized Training Components
*   **The Felt-View (Table Interface):** Background color must be `Table Felt (#1B6B3A)`. Overlays (aiming lines, ball positions) use `on-primary` (white) for maximum contrast.
*   **Drill Progress Chips:** Pill-shaped, using `secondary-container` backgrounds with `on-secondary-container` text to indicate "In Progress" or "Mastered."
*   **Instructional Steps:** Large `display-sm` numerals in 10% opacity `primary` color, positioned asymmetrically behind the body text to act as a structural anchor.

## 6. Do's and Don'ts

### Do
*   **Do** use SF Symbols with "Medium" or "Semibold" weights to match the typographic density.
*   **Do** embrace white space. If a screen feels "empty," it is usually working correctly; it provides the mental "quiet" needed for sports concentration.
*   **Do** use Rounded font weights for any numerical data (scores, angles, degrees).

### Don't
*   **Don't** use pure black (#000000) for long-form body text; use `on-surface-variant` (#404940) to reduce eye strain.
*   **Don't** use standard 1px separators in lists. Use tonal shifts or 8px gaps.
*   **Don't** use sharp corners. Billiards is a game of spheres and rounded cushions—every container must follow the 12pt (`md`) or higher (`lg`/`xl`) radius rule.