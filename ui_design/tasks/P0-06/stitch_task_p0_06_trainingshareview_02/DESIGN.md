# Design System Strategy: The Master’s Table

## 1. Overview & Creative North Star
The "Creative North Star" for this design system is **The Quiet Professional**. Billiards is a game of extreme precision, mathematical strategy, and deliberate movement. This system translates those traits into a UI that feels high-stakes yet calm. 

Instead of standard mobile app templates, we embrace an **Editorial Precision** aesthetic. We break the grid through "asymmetric focus"—using generous white space to draw the eye toward critical training data while allowing metadata to sit in the periphery. The interface should feel like a custom-tailored suit: perfectly fitted, minimalist in decoration, but luxurious in material and construction.

---

## 2. Colors: Tonal Depth & The "No-Line" Rule
Our palette is rooted in the rich heritage of the sport but executed through a modern, high-contrast lens.

### Palette Allocation
*   **Primary (`#1A6B3C`):** The "Championship Green." Use this for high-impact actions and progress indicators.
*   **Accent Gold (`#D4941A`):** The "Brass Inlay." Reserved strictly for milestones, high-tier achievement data, and subtle focus states.
*   **Surface Hierarchy:**
    *   `background`: `#F2F2F7` (The iOS System Foundation)
    *   `surface-container-low`: `#FFFFFF` (Standard Cards)
    *   `surface-container-highest`: `#1C1C1E` (The Dark Performance Mode for shareable cards)

### The "No-Line" Rule
**Explicit Instruction:** Prohibit the use of 1px solid borders for sectioning. Sectioning must be achieved through **Background Shift**. To separate content, place a `surface-container-lowest` card on top of a `surface-container-low` background. The change in hex value provides a cleaner, more premium separation than a mechanical line.

### The Glass & Texture Rule
For floating navigation elements or customization chips, utilize **Glassmorphism**. Use semi-transparent surface colors with a `backdrop-filter: blur(20px)`. This creates an "overlaid glass" effect that mimics the way light hits a cue ball or a polished rail, adding depth without visual clutter.

---

## 3. Typography: Authority Through Scale
We use a high-contrast scale to create an editorial feel. By pairing large, rounded displays with ultra-tight metadata, we establish an immediate hierarchy.

*   **Display/Titles (22pt Bold Rounded):** These are the "headlines." Use these for session summaries and drill names. The rounded nature mimics the geometry of the billiards table.
*   **Body (15pt Regular):** Use for instructional text and descriptions. It is optimized for legibility under stadium lighting.
*   **Metadata (11pt/12pt, 60% Opacity):** This is the "caddy’s notes." Use for technical specs (angles, velocity, spin). The reduced opacity ensures the primary data remains the protagonist.

---

## 4. Elevation & Depth: Tonal Layering
Traditional drop shadows are too "software-generic." We move toward **Ambient Sophistication**.

*   **The Layering Principle:** Stacking is our primary depth tool. 
    *   *Base Level:* `surface-container-low` (#F2F2F7)
    *   *Action Level:* `surface-container-lowest` (#FFFFFF)
*   **Ambient Shadows:** For floating elements, use an extra-diffused shadow: `Offset: 0, 8 | Blur: 24 | Spread: 0 | Color: 4% Black`. This mimics natural light rather than a digital effect.
*   **The Ghost Border Fallback:** If a border is required for accessibility on high-contrast backgrounds, use a "Ghost Border": the `outline-variant` token at **15% opacity**.

---

## 5. Components: Precision Engineered

### The iOS Navigation Bar
*   **Surface:** White (#FFFFFF) with a 20px backdrop blur.
*   **Constraint:** No bottom border. Use a subtle shadow (2% opacity) to signify the transition to the scrollable area.

### Performance Cards & Lists
*   **Corner Radius:** Strict `16pt` (xl) for main cards.
*   **Spacing:** No dividers. Use `1.5rem` (24px) vertical spacing to separate list items.
*   **Dark Mode (Shareable):** Use `surface-container-highest` (#1C1C1E) with Gold (#D4941A) typography for a high-prestige "Pro-Card" look.

### Toggle Pill Groups
*   **Selected State:** `Primary Brand Green` (#1A6B3C) with white text.
*   **Unselected State:** `surface-container-low` (#F2F2F7) with `on-surface-variant` text. 
*   **Shape:** Full rounding (pill shape).

### Customization Chips (Circular Theme Selectors)
*   **Interaction:** Circular chips for color themes should have a "Ghost Border" that appears only when selected, colored in `Accent Gold` (#D4941A) to signify active status.

---

## 6. Do’s and Don’ts

### Do
*   **DO** use whitespace as a functional tool. If a screen feels crowded, increase the margin rather than adding a box.
*   **DO** use "Primary Green" for CTAs that advance the user (e.g., "Start Drill").
*   **DO** treat the dark-themed shareable card like a luxury watch advertisement: high contrast, minimal text, maximum "vibe."

### Don't
*   **DON'T** use 100% opaque black for text. Use `on-surface` (#1A1C1F) to keep the look soft and professional.
*   **DON'T** use standard iOS "Chevron" icons for navigation where a background shift could explain the hierarchy better.
*   **DON'T** apply gradients. The "Quiet Professional" North Star relies on solid, confident color blocks and material depth.