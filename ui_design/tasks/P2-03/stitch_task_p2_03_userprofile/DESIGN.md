# Design System Document

## 1. Overview & Creative North Star: "The Grandmaster’s Ledger"
This design system moves away from the generic utility of fitness trackers to embrace the prestige and focused quietude of a professional billiard hall. The Creative North Star is **"The Grandmaster’s Ledger"**—a digital experience that feels like a bespoke, leather-bound journal used by a professional to track a lifetime of precision.

We break the standard iOS "list-view" template by employing **intentional asymmetry**. Headers are not just aligned; they are staged. We use overlapping elements where cards gently bleed into headers, creating a sense of physical depth. The interplay between the organic, rounded nature of billiard balls and the rigid, high-contrast typography creates an editorial aesthetic that feels both authoritative and approachable.

---

## 2. Colors: The Palette of the Table
The color strategy is rooted in the haptic experience of billiards: the deep green felt, the polished brass accents, and the stark white of the cue ball.

### Core Brand Tokens
*   **Primary (`#1A6B3C`):** The "Billiard Green." Use this for key brand moments and containers that signify the "playing surface."
*   **Secondary/Pro (`#D4941A`):** The "Championship Gold." Reserved for Pro-tier features, achievement badges, and high-level milestones.
*   **Destructive (`#C62828`):** Use with restraint for critical errors or session terminations.

### The "No-Line" Rule
To maintain a premium editorial feel, **1px solid borders are strictly prohibited** for sectioning. Boundaries must be defined through:
*   **Tonal Shifts:** Placing a `surface_container_lowest` (#FFFFFF) card on a `surface_container` (#EDEDF2) background.
*   **Negative Space:** Using the spacing scale to create clear mental models of grouping without physical lines.

### Surface Hierarchy & Nesting
Treat the UI as a series of stacked materials. 
1.  **Base Layer:** `surface` (#F9F9FE) for the overall page.
2.  **Section Layer:** `surface_container_low` (#F3F3F8) to group related activities.
3.  **Interaction Layer:** `surface_container_lowest` (#FFFFFF) for primary cards and menu items.

### The "Glass & Gradient" Rule
Standard flat colors feel static. To inject "soul," apply a subtle **Felt Gradient** to Primary CTAs, transitioning from `primary` (#1B6C3D) to `primary_container` (#1A6B3C) at a 135-degree angle. For floating navigation or Pro-level overlays, use **Glassmorphism**: a background blur of 20px over a 70% opacity `surface_container_lowest`.

---

## 3. Typography: Editorial Authority
The typography system balances the friendly accessibility of **SF Pro Rounded** with the rigid precision of an editorial layout.

*   **Display/Hero Titles:** Use `display-lg` (SF Pro Rounded Bold, 34pt). This should be used sparingly for page titles to establish a strong visual anchor.
*   **The Pro Contrast:** Pair the bold rounded headers with `body-md` (SF Pro Regular, 17pt) for descriptions. The contrast between the heavy "ball-like" curves of the headers and the sharp, legible body text creates a signature high-end look.
*   **Information Density:** Use `label-md` (Inter/SF Pro, 12pt) for metadata. These should be tracked out (+2% to +5%) to feel like technical notations in a ledger.

---

## 4. Elevation & Depth: Tonal Layering
We reject the heavy, muddy shadows of 2010s UI. Depth is achieved through **Tonal Layering** and **Ambient Shadows**.

*   **The Layering Principle:** A Header Card (16pt radius) should sit on the `surface_container_low`. A Menu Card (12pt radius) nested within a section should use `surface_container_lowest`. This creates a natural "lift" through color value rather than structural lines.
*   **Ambient Shadows:** If an element must float (e.g., a "Start Training" FAB), use a shadow with a 24px blur and only 4% opacity. The shadow color should not be black; it must be a tinted version of `on_surface` (#1A1C1F) to mimic natural light in a room.
*   **The Ghost Border:** If accessibility requires a border, use the `outline_variant` token at 15% opacity. It should be felt, not seen.
*   **Glassmorphism Depth:** Use backdrop blurs on the tab bar and header navigation to allow the "Billiard Green" of the content to bleed through as the user scrolls, creating a sense of environmental immersion.

---

## 5. Components

### Cards & Lists
*   **Header Cards:** 16pt corner radius. Used for hero stats or the current training session.
*   **Menu Cards:** 12pt corner radius. **Never use divider lines.** Separate list items using 12pt of vertical whitespace or a 4pt height `surface_container` strip if absolute separation is needed.
*   **Iconography:** SF Symbols must be housed in 30pt circular backgrounds. Use the `primary_fixed` (#A5F4B8) for training icons and `secondary_fixed` (#FFDDAF) for achievement icons to provide soft, color-coded categorization.

### Buttons
*   **Primary CTA:** High-contrast `primary` background with `on_primary` text. Apply a subtle 8px inner shadow at the top to give a "pressed into the felt" feel.
*   **Pro Button:** Use the `secondary` (#D4941A) gradient. This button should be the only element on the screen using this hue to ensure it feels exclusive.

### Chips & Tags
*   **Status Chips:** Use `surface_container_high` with `on_surface_variant` text. Keep them small and pill-shaped (full radius) to mimic the shape of a billiard ball.

### Specialized Component: "The Shot Tracker"
A custom horizontal scroll component for recording ball positions. Use `surface_container_lowest` cards with a `ghost border` to define individual shots, allowing the user to swipe through their "ledger" of training.

---

## 6. Do's and Don'ts

### Do
*   **Do** use generous whitespace (24pt+) between major sections to let the design breathe.
*   **Do** use asymmetrical text alignment in headers (e.g., Title left-aligned, subtitle right-aligned) to create an editorial feel.
*   **Do** use SF Pro Rounded specifically for numbers; the rounded glyphs mimic the circularity of the sport.

### Don't
*   **Don't** use 100% black (#000000). Always use `on_surface` or `on_background` for text to maintain a softer, premium contrast.
*   **Don't** use standard iOS "Chevron-right" icons on every list item unless the interaction is non-obvious. Rely on the "Card" metaphor to imply tapability.
*   **Don't** use high-contrast borders. If the card isn't visible against the background, adjust the `surface_container` tier rather than adding a stroke.