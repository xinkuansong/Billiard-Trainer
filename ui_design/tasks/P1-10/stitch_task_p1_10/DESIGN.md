# Design System Document

## 1. Overview & Creative North Star
**Creative North Star: The Disciplined Green**
This design system is built for the precision-obsessed athlete. It moves beyond a simple utility tracker to become a digital training partner that mirrors the atmosphere of a professional billiard hall. The aesthetic is "Editorial Athleticism"—combining the structured, clean layouts of high-end sports journalism with the tactile, premium feel of bespoke pool table craft. 

To break the "standard iOS" template look, we use intentional white space, dramatic typography scale shifts, and an asymmetrical approach to information density. We don't just present data; we curate it on a stage of "Billiard Green" and "Gold," ensuring the user feels the weight of their progress.

---

## 2. Colors
Our palette is rooted in the heritage of the game, utilizing deep, saturated greens and luminous ambers to denote expertise and achievement.

*   **Primary (Table Green):** `primary (#005129)` and `primary_container (#1A6B3C)`. Use these for the core brand identity and main actions. 
*   **Premium/Pro (The Gold Standard):** `secondary (#805600)` and `secondary_fixed (#FFDDAF)`. These are reserved for "Pro" features, achievement highlights, and high-tier subscription states.
*   **Neutral (Surface):** `surface (#F9F9FE)` and `surface_container_lowest (#FFFFFF)`.

### The "No-Line" Rule
Sectioning must be achieved without 1px solid borders. Boundaries are defined strictly through background shifts. For example, a card (`surface-container-lowest`) sits on a background (`surface`), creating a natural edge through tonal contrast alone.

### Surface Hierarchy & Nesting
Treat the UI as physical layers. 
*   **Level 0:** `surface` (The "table" base).
*   **Level 1:** `surface-container-low` (Secondary groupings).
*   **Level 2:** `surface-container-lowest` (The primary content cards).
*   By nesting a `lowest` card inside a `low` container, we create depth without visual noise.

### The "Glass & Gradient" Rule
For floating elements or "locked" Pro states, use **Glassmorphism**. Apply a `surface` color at 70% opacity with a 20px backdrop blur. For Hero CTAs, use a subtle linear gradient from `primary` to `primary_container` (top-left to bottom-right) to add a three-dimensional "felt" texture.

---

## 3. Typography
We utilize the **SF Pro (Inter equivalent)** family to maintain native iOS familiarity while pushing editorial limits.

*   **Display (Display-LG/MD):** Used for massive "Win Rate" percentages or "Total Games." These should feel monumental.
*   **Headline (Headline-LG):** Bold and authoritative. Used for section titles like "Training Overview."
*   **Title (Title-LG/MD):** For card headers. High contrast (`on_surface`) against the white background is mandatory.
*   **Body & Labels:** `body-md` is the workhorse. `label-sm` is reserved for metadata (e.g., timestamps or small captions).

**Signature Detail:** Tighten the letter-spacing on Display and Headline styles by -2% to create a more "bespoke" and aggressive editorial feel.

---

## 4. Elevation & Depth
We eschew traditional drop shadows for **Tonal Layering**.

*   **The Layering Principle:** Depth is achieved by stacking. A card does not need a shadow if the background color provides a 3-5% shift in luminance.
*   **Ambient Shadows:** If a "floating" Action Button is required, use a shadow with a 24pt Blur, 0pt Offset, and 6% Opacity using the `on_surface` color. This mimics the soft, diffused lighting of a pool hall.
*   **The "Ghost Border":** For accessibility in input fields, use `outline_variant` at 15% opacity. Never use 100% opaque lines.
*   **Locked States:** Use a "Frosted Glass" overlay. Apply `surface_variant` at 40% opacity with a heavy backdrop blur. This keeps the layout integrated while clearly signaling the content is behind a premium "vault."

---

## 5. Components

### Buttons
*   **Primary:** Pill-shaped (`999pt`), `primary` background, `on_primary` text.
*   **Secondary/Pro:** Pill-shaped, `secondary_container` background, `on_secondary_container` text.
*   **Ghost:** Transparent background with `primary` text. No border.

### Cards & Lists
*   **Cards:** Fixed `16pt` corner radius. Background: `surface-container-lowest`. 
*   **List Items:** Forbid the use of divider lines. Use `12pt` or `16pt` vertical spacing (from the Spacing Scale) to separate items.
*   **Dividers:** If a separator is functionally required, use a `4pt` wide "Pill" divider rather than a thin line, colored in `surface-variant`.

### Chips (Pills)
*   Used for filtering (e.g., "Weekly", "Monthly").
*   **Unselected:** `surface-container-high` background.
*   **Selected:** `primary` background with `on_primary` text.
*   Radius: Always `999pt`.

### Input Fields
*   Minimalist style. No bottom line or box. Use a slightly darker `surface-container` background with `12pt` rounded corners to create a "recessed" look into the card.

---

## 6. Do's and Don'ts

### Do
*   **DO** use SF Symbols with "Semibold" weight to match the high-contrast typography.
*   **DO** leave generous margins (minimum 20pt) at the screen edges to create an editorial "frame."
*   **DO** use the `secondary` (Gold) color sparingly—only for moments of genuine user success or premium upsells.

### Don't
*   **DON'T** use pure black (#000000) for text. Use `on_surface` (#1A1C1F) to maintain tonal depth.
*   **DON'T** use 1px dividers to separate card content. Use a `8pt` height gap or a subtle background color shift.
*   **DON'T** use standard iOS "Blue" for links. Every interactive element must be either `primary` (Green) or `secondary` (Gold).