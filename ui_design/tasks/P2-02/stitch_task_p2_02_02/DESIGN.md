# Design System Document: The Precision Play

## 1. Overview & Creative North Star

### The Creative North Star: "The Tactical Gentleman"
This design system is not merely a tracker; it is a digital caddie. It balances the heritage and etiquette of billiards with the rigorous data precision of professional training. We move beyond the "standard iOS app" by adopting a **High-End Editorial** approach. 

The aesthetic is driven by **intentional asymmetry** and **tonal depth**. Rather than using rigid boxes and heavy lines, we use the "felt" of the UI—the background and surface layers—to guide the eye. Imagine a perfectly leveled pool table: the beauty is in the flat, expansive surface, but the function is in the subtle physics. Our layout mirrors this by using large headers, significant breathing room, and overlapping elements that feel "placed" rather than "slotted."

---

## 2. Colors

The color palette is rooted in the "Billiard Green" heritage, elevated by "Amber Gold" accents that suggest premium status and achievement.

### Palette Strategy
- **Primary (`#1A6B3C`):** Used for core branding and high-importance interaction states.
- **Secondary (`#D4941A`):** Reserved for "PRO" status, achievements, and highlight-level data points.
- **Surface & Background:** We utilize a sophisticated range of off-whites and cool greys (`#F2F2F7` to `#FFFFFF`) to create depth without clutter.

### The "No-Line" Rule
**Borders are prohibited for sectioning.** To separate the "Official Plans" from "Custom Plans," do not draw a line. Instead, shift the background color. A `surface-container-low` section sitting on a `surface` background provides all the visual affordance needed.

### The "Glass & Gradient" Rule
For floating action buttons or high-profile CTAs, use a subtle gradient transitioning from `primary` (#1A6B3C) to `primary_container` (#1B6C3D). For modal headers or navigation bars, implement **Glassmorphism**: use `surface` at 80% opacity with a `20px` backdrop blur to allow the richness of the underlying content to bleed through.

---

## 3. Typography

The system uses **SF Pro** as its backbone, but applies it with an editorial mindset—leveraging extreme weight contrast to establish hierarchy.

| Level | Size / Weight | Role |
| :--- | :--- | :--- |
| **Display-LG** | 3.5rem / Bold | Massive numeric totals (e.g., total balls potted). |
| **Headline-LG** | 2.0rem / Semibold | Section titles like "Training Plan." |
| **Title-LG** | 1.375rem / Medium | Card titles and primary navigation points. |
| **Body-MD** | 0.875rem / Regular | Secondary descriptions and metadata. |
| **Label-SM** | 0.6875rem / Bold | Upper-case tags and technical stats. |

**The Hierarchy Note:** Headlines should have generous top-padding to create a "Gallery" feel. Use `Label-SM` in `secondary` (Amber) for tags to create a "Signature" look that breaks the monochromatic green/grey flow.

---

## 4. Elevation & Depth

We convey importance through **Tonal Layering** rather than shadows.

*   **The Layering Principle:** 
    *   Base: `surface` (#F2F2F7)
    *   Section Area: `surface-container-low`
    *   Interactive Card: `surface-container-lowest` (#FFFFFF)
*   **Ambient Shadows:** If a card must "float" (e.g., a session-in-progress card), use a shadow color tinted with the `primary` hue (e.g., `rgba(26, 107, 60, 0.06)`) with a blur radius of `24pt`. It should feel like a soft glow, not a dark drop.
*   **The "Ghost Border" Fallback:** If a UI element (like a search bar) disappears into the background, use the `outline-variant` token at **15% opacity**. This creates a "breath" of a border that is felt rather than seen.

---

## 5. Components

### Cards & Lists
*   **Rule:** Forbid divider lines. Use `16pt` vertical spacing to separate items.
*   **Styling:** Cards use a `12pt` (0.75rem) corner radius. Elements within the card (like the pool ball icons) should be slightly inset to create a "frame within a frame" look.

### Buttons
*   **Primary:** Solid `primary` background with `on_primary` text. No border.
*   **Secondary:** `surface-container-high` background with `primary` text.
*   **Tertiary:** Transparent background with `primary` text and a `Ghost Border`.

### Progress Chips
*   Used for difficulty levels (L1, L2, L3).
*   **Design:** Use a pill shape (`full` roundedness). Use low-saturation versions of the brand colors to ensure the "PRO" badge (Amber Gold) remains the highest visual priority.

### Input Fields
*   Text inputs should be "Minimalist Editorial": A simple `surface-container-highest` bottom bar rather than a four-sided box, or a fully flooded `surface-container-low` background with no border.

---

## 6. Do's and Don'ts

### Do
*   **DO** use SF Symbols with "Medium" or "Semibold" weights to match the typography.
*   **DO** leave at least `24pt` of horizontal margin on the main screen to emphasize the premium "Editorial" feel.
*   **DO** use the Amber (`#D4941A`) sparingly—it is a reward, not a utility.

### Don't
*   **DON'T** use pure black (#000000) for text. Use `on_surface` (#1A1C1F) for a softer, high-end feel.
*   **DON'T** use the standard iOS blue for links. Everything interactive must be `primary` green or `secondary` amber.
*   **DON'T** crowd the cards. If a card has more than three lines of text, move the metadata to a "Label" style chip.

---

## 7. Signature Texture: The "Table Surface"
To truly differentiate this design system, use a very subtle grain or noise overlay (2% opacity) on `primary` color hero sections. This mimics the texture of high-quality billiard cloth, adding a tactile dimension to the digital interface.