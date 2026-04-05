# Design System Document: The Precision Green

## 1. Overview & Creative North Star
The Creative North Star for this system is **"The Elite Club House."** 

Billiards is a game of extreme precision, quiet confidence, and tactile luxury. This design system moves away from the "generic fitness app" aesthetic to embrace a high-end editorial feel. We achieve this by blending the heritage of professional billiards (the iconic green felt) with a modern, "Soft Minimalism" interface. 

The system rejects the rigid, boxy constraints of standard mobile grids. Instead, it utilizes **intentional asymmetry**, high-contrast typography scales, and overlapping "glass" layers to create a sense of depth and focus. Every element should feel like it was placed with the same deliberate intent as a championship-winning shot.

---

## 2. Colors
Our palette is rooted in the deep, authoritative green of a premium table, supported by a sophisticated range of neutral surfaces that mimic natural light hitting a felt surface.

### Primary Tones (The "Felt" Core)
- **Primary (`#00522a`)**: Used for brand-critical elements.
- **Primary Container (`#1e6b3e`)**: The signature action color. Use this for main CTAs to ensure high-vibrancy interaction.

### Surface & Functional
- **Surface (`#f8f9fb`)**: Our base canvas. It is a cool, airy gray that prevents the "stark white" digital fatigue.
- **Surface Container Highest (`#e1e2e4`)**: For recessed areas or secondary grouping.
- **Tertiary (`#782e39`)**: A deep "Chalk Burgundy" used for error states or specific accent warnings, providing a classic color contrast to the green.

### The "No-Line" Rule
**Explicit Instruction:** Designers are prohibited from using 1px solid borders to section content. Boundaries must be defined solely through background color shifts. To separate a profile card from the background, use `surface-container-lowest` on a `surface` background. 

### Glass & Gradient Rule
CTAs and Hero sections should not be flat. Use a subtle linear gradient from `primary` to `primary-container` (at a 135-degree angle) to provide visual "soul." For floating elements, utilize Glassmorphism (semi-transparent surface colors with a `20px` backdrop blur) to maintain a premium, layered feel.

---

## 3. Typography
We utilize a dual-font strategy to balance character with readability.

*   **Display & Headlines:** `Plus Jakarta Sans`. This typeface offers a contemporary, geometric feel with a premium editorial "snap." Use high-contrast sizing (e.g., `display-lg` for welcome screens) to create a clear visual entry point.
*   **Body & Labels:** `Manrope`. A highly functional sans-serif that maintains legibility even at small sizes (e.g., `label-sm` for secondary data points like "ID: 2086753").

**Hierarchy Intent:** 
Headlines should feel authoritative. Use `headline-lg` for page titles to establish a "Quiet Luxury" atmosphere. Use `title-md` in semi-bold for card headers to ensure the user's eye is guided through the data hierarchy without the need for heavy dividers.

---

## 4. Elevation & Depth
In this system, depth is a function of light and material, not digital shadows.

### The Layering Principle
Depth is achieved by "stacking" surface-container tiers. 
- **Level 0 (Base):** `surface`
- **Level 1 (Sections):** `surface-container-low`
- **Level 2 (Cards):** `surface-container-lowest` (White)

### Ambient Shadows
When an element must float (like a "Start Training" floating action button), use a **Shadow Tint**. Instead of a grey shadow, use a 6% opacity shadow tinted with `on-surface` (`#191c1e`), with a blur radius of at least `24px`. This mimics the way light diffuses in a well-lit billiard room.

### The "Ghost Border" Fallback
If accessibility requires a container definition, use a **Ghost Border**: `outline-variant` at **15% opacity**. Never use a 100% opaque border.

---

## 5. Components

### Buttons
- **Primary:** Gradient from `primary` to `primary-container`. `xl` rounded corners (`1.5rem`). White text (`on-primary`).
- **Secondary:** Surface-container-lowest background with a Ghost Border.
- **Tertiary:** No background; `primary` colored text; `manrope` bold.

### Cards & Lists
- **Rule:** Forbid divider lines. 
- Separate list items using `12px` of vertical white space or a subtle shift from `surface` to `surface-container-low` on hover/active states.
- **Iconography:** Icons should be housed in circular containers (Glassmorphism or soft primary-container tints) as seen in the onboarding screen to provide a "soft touch" feel.

### Input Fields
- Use `surface-container-highest` for the input track.
- No bottom border. Use `md` (`0.75rem`) rounded corners.
- Focused state: A subtle Ghost Border becomes visible at 40% opacity.

### Training Chips
- For selecting "Game Type" or "Difficulty."
- **Selected:** `primary` background with `on-primary` text.
- **Unselected:** `surface-container-high` with `on-surface-variant` text.

---

## 6. Do's and Don'ts

### Do
- **Do** use whitespace as a functional tool. Content needs room to "breathe" to feel premium.
- **Do** use `plusJakartaSans` for all numerical data (e.g., training hours, score counts) to emphasize precision.
- **Do** use rounded corners (`lg` or `xl`) to soften the professional tone, making it approachable.

### Don't
- **Don't** use pure black (#000000). Use `on-surface` (#191c1e) for all "black" text to maintain tonal warmth.
- **Don't** use standard Material Design drop shadows. They look "cheap" in an editorial context. Stick to Ambient Shadows.
- **Don't** cram multiple data points into a single row. If information is important, give it its own vertical space or a clearly defined surface "island."