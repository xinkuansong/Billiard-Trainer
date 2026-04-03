# Design System Documentation: Professional Billiards Training

## 1. Creative North Star: "The Tactical Green"
This design system is built upon the concept of **Tactical Precision**. Much like the felt of a championship billiards table, the interface must feel tensioned, purposeful, and quiet. We move beyond the "generic app" look by embracing **High-Contrast Minimalist Editorial**—where whitespace isn't just empty; it's a structural element that guides the athlete’s focus. 

We reject the "boxed-in" nature of traditional UI. By utilizing tonal layering instead of harsh outlines, we create a digital environment that feels as fluid and professional as a perfect break.

---

## 2. Color Architecture & Surface Philosophy
The palette is rooted in the deep tradition of the sport. We use tonal transitions to define hierarchy, strictly adhering to the **No-Line Rule**.

### Brand & Semantic Tones
*   **Primary (#1A6B3C):** The "Championship Green." Used for high-priority actions and section headers.
*   **Secondary (#C62828):** The "Warning Red." Reserved strictly for destructive actions or critical errors.
*   **Background (#F2F2F7):** A cool, neutral iOS-standard base that allows our white cards to "float" naturally.

### The Surface Hierarchy
Depth is achieved through the **Layering Principle**. We stack containers to create focus without clutter:
1.  **Level 0 (Base):** `surface` (#F9F9FE) or system background (#F2F2F7).
2.  **Level 1 (Content Cards):** `surface_container_lowest` (#FFFFFF). These are our primary interaction zones.
3.  **Level 2 (Inset Components):** `surface_container` (#EDEDF2) for inner elements like input fields or secondary buttons.

**The "No-Line" Rule:** 1px borders are prohibited. Define boundaries via background shifts. For example, a `surface_container_low` button sitting inside a `surface_container_lowest` (white) card.

---

## 3. Typography: Editorial Precision
We utilize **SF Pro** (system font) to maintain iOS native feel, but we apply it with editorial weight to signify authority.

*   **Section Titles:** `22pt Bold Rounded` in Primary Green (#1A6B3C). These act as the "anchor" for every view.
*   **Display/Headline:** `plusJakartaSans` (Headline-LG/MD) for performance metrics and high-level stats to provide a modern, athletic edge.
*   **Body & Labels:** `inter` (Body-MD) for all instructional text. Use `label-md` for technical data like ball velocity or angle degrees.

---

## 4. Elevation & Depth: Tonal Layering
To achieve a high-end feel, we replace shadows with **Ambient Depth**.

*   **The Layering Principle:** A white card (`radius 16pt`) on the light gray background provides enough contrast. If further separation is needed, use `surface_container_high` for a subtle "lift."
*   **Ghost Borders:** For accessibility in forms, use `outline_variant` at **20% opacity**. Never use 100% black or high-contrast borders.
*   **Frosted Glass:** For floating navigation or top bars, use `surface` at 80% opacity with a `20px` backdrop blur to allow the table-green or background colors to bleed through softly.

---

## 5. Components: The Billiards Toolkit

### Buttons (The Primary Interaction)
Buttons must feel tactile and "weighted."
*   **Primary Action:** Solid `primary_container` (#1A6B3C) with `on_primary` (#FFFFFF) text. Radius: `full`.
*   **Destructive Action:** Solid `secondary` (#C62828) with `on_secondary` (#FFFFFF) text. Used for "Reset Session" or "Delete Drill."
*   **Secondary/Ghost:** `surface_container_highest` (#E2E2E7) fill with `on_surface` text. No border.

### Cards & Lists
*   **Drill Cards:** White `surface_container_lowest`, `radius 16pt`, `padding 16pt`. 
*   **The No-Divider Rule:** Forbid the use of hairline dividers between list items. Use `8pt` or `12pt` vertical spacing (from the Spacing Scale) to separate drill steps.

### Specialty Components: "The Shot HUD"
*   **Data Chips:** Small, pill-shaped `primary_fixed` containers with `on_primary_fixed` text for displaying "Success Rate" or "Difficulty."
*   **Progress Inputs:** Use thick, `12pt` track heights for sliders (representing power/force) to mimic the substantial feel of a pool cue.

---

## 6. Do’s and Don’ts

### Do
*   **DO** use 16pt padding as your absolute minimum internal margin for cards.
*   **DO** use the `22pt Bold Rounded` green titles to create a signature "QiuJi" rhythm across screens.
*   **DO** lean on typography size (Headline vs. Label) to create hierarchy rather than adding more boxes or lines.

### Don’t
*   **DON'T** use 1px solid borders. If an element isn't visible, adjust the background tone of the container.
*   **DON'T** use gradients. This system relies on "Flat Sophistication"—the quality comes from the color choice, not the effect.
*   **DON'T** use standard iOS blue for links. Everything is either Tactical Green, Neutral Gray, or Destructive Red.