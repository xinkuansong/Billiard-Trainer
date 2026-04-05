# Design System Document: Tactical Precision & Haptic Luxury

## 1. Overview & Creative North Star
**The Creative North Star: "The Master’s Baize"**

This design system moves beyond the utility of a standard tracker to evoke the tactile, focused atmosphere of a professional billiard hall. The "Master’s Baize" philosophy centers on high-contrast clarity, surgical precision, and the physical sensation of depth. 

We break the standard "list-heavy" iOS template by embracing **intentional asymmetry** and **tonal layering**. The layout should feel like a perfectly arranged rack of balls—geometric, intentional, and high-stakes. We achieve a "Custom-Native" feel by adhering to Apple’s Human Interface Guidelines (HIG) while injecting an editorial soul through sophisticated surface nesting and the complete removal of traditional separator lines.

---

## 2. Colors: The Baize & The Ivory
Our palette is rooted in the deep, authoritative green of a competition-grade table, supported by a sophisticated range of "warm-whites" and "cool-shadows" to provide depth without clutter.

### The "No-Line" Rule
**Explicit Instruction:** Designers are prohibited from using 1px solid borders to section content. Boundaries must be defined solely through background color shifts. Use `surface-container-low` for large content blocks sitting on a `surface` background. This creates a seamless, high-end feel that mimics the smooth transition of light across felt.

### Color Tokens (Material Mapping)
*   **Primary (The Baize):** `#005129` (Primary) | `#1A6B3C` (Primary Container). Use for high-action focal points.
*   **Surfaces (The Arena):** 
    *   `surface`: `#f9f9fe` (The base canvas)
    *   `surface-container-low`: `#f3f3f8` (Subtle nesting)
    *   `surface-container-highest`: `#e2e2e7` (Deepest contrast for inputs)
*   **Accents (The High-Stakes):**
    *   `tertiary`: `#782c38` (Deep Burgundy / Chalk Red). Use sparingly for "Critical Error" or "End Match" actions.

### The "Glass & Gradient" Rule
To elevate the app above "stock" iOS, use **Glassmorphism** for floating action bars and navigation headers. Apply a `surface-container-lowest` color at 80% opacity with a `20px` backdrop blur. 
*   **Signature Texture:** Use a subtle linear gradient on primary buttons transitioning from `#1A6B3C` to `#005129` at a 145° angle. This adds a "weighted" feel to the interaction, reminiscent of a heavy cue ball.

---

## 3. Typography: Editorial Authority
We utilize **SF Pro** (Inter-mapped) to maintain native performance while applying a bold, editorial hierarchy.

*   **Display (The Score):** `display-lg` (3.5rem). Used for big-number match scores. Bold weight, tight tracking (-0.02em).
*   **Headline (The Narrative):** `headline-lg` (2rem). Rounded and Bold. Used for page titles and "Session Summary" headers.
*   **Title (The Detail):** `title-md` (1.125rem). Semibold. Used for list headers and card titles.
*   **Body (The Commentary):** `body-md` (0.875rem). Regular. High-contrast (`on-surface`) for maximum legibility in dim pool hall lighting.

The contrast between the oversized `display` typography and the tight, functional `body` text creates a rhythmic hierarchy that feels both modern and authoritative.

---

## 4. Elevation & Depth: Tonal Layering
We reject the 2010-era "Drop Shadow." Hierarchy is achieved through **Tonal Stacking**.

*   **The Layering Principle:** 
    1.  Base: `surface` (#f9f9fe)
    2.  Section: `surface-container-low` (#f3f3f8)
    3.  Interactive Element: `surface-container-lowest` (#ffffff)
*   **Ambient Shadows:** If an element must "float" (e.g., a New Match Modal), use a `12%` opacity of the `on-surface` color with a `32px` blur and `12px` Y-offset. It should feel like a soft glow, not a hard shadow.
*   **The "Ghost Border":** For accessibility in inputs, use `outline-variant` at **15% opacity**. Never use a 100% opaque stroke.

---

## 5. Components: Tactile Instruments

### Buttons: The Weighted Strike
*   **Primary:** Rectangular with `lg` (1rem) corner radius. Background: `primary`. Text: `on-primary` (Bold).
*   **Secondary (Pill):** Full-rounded (`full`). Background: `surface-container-highest`. Text: `on-secondary-container`. Use for "Add Foul" or "Swap Player."

### Input Fields: The Recessed Pocket
*   **Styling:** `12pt` corner radius, `#F2F2F7` background (`surface-container-highest`). 
*   **Interaction:** On focus, the background shifts to `#ffffff` and a "Ghost Border" of `primary` (20% opacity) appears. No shadows.

### Cards & Lists: The Open Layout
*   **Prohibition:** Never use divider lines.
*   **Execution:** Group related match stats into a `surface-container-low` card. Use `xl` (1.5rem) spacing between blocks to allow the layout to breathe.

### Specialized Component: The "Rack" Progress Bar
*   A custom progress bar for frame-tracking. Use `primary-fixed-dim` for the track and a `primary` gradient for the progress. Add a subtle inner-shadow to the track to make it feel "recessed" into the table.

---

## 6. Do’s and Don’ts

### Do:
*   **Do** use extreme vertical whitespace to separate major sections.
*   **Do** use "Billiard Green" (`primary`) for success states and navigation highlights.
*   **Do** treat the "New Game" button as the most "weighted" object on the screen.

### Don’t:
*   **Don't** use black (#000000). Use `on-surface` (#1a1c1f) for text to maintain a premium, ink-like softness.
*   **Don't** use standard iOS blue for links. Every interactive element must be green or grayscale.
*   **Don't** use icons with thin strokes. Use "Bold" or "Heavy" SF Symbols to match the weight of the headers.

---

## 7. Interaction Note
Every tap should feel "deliberate." Use iOS `heavy` haptic feedback for scoring a point and `medium` for switching turns. The UI should respond as if the user is moving physical ivory balls across a table.