# Design System Specification: The Technical Master

## 1. Overview & Creative North Star
**Creative North Star: "The Architectural Schematic"**

This design system moves away from the "recreational" feel of sports apps and leans into the "surgical" precision of an architectural blueprint. We are not just tracking scores; we are documenting the geometry of a masterwork. 

To achieve a high-end editorial feel, the layout must embrace **Intentional Asymmetry**. We break the "template" look by using a rigorous "No-Line" philosophy—defining space through tonal shifts and sophisticated layering rather than rigid borders. The experience should feel like a premium, native iOS utility that has been elevated by a boutique design studio: clean, authoritative, and obsessively focused on the schematic diagram.

---

## 2. Colors
Our palette is rooted in the "Billiard Green" heritage but executed with a modern, Material-inspired tonal range.

### Tonal Hierarchy
*   **The Primary Core:** Use `primary` (#005129) for high-emphasis actions and `primary_container` (#1A6B3C) for the "Table Felt" identity. 
*   **Neutral Surfaces:** The `background` (#FAF9FE) provides a cool, airy atmosphere. Use `surface_container_lowest` (#FFFFFF) for primary content cards to create a "paper on felt" aesthetic.

### The "No-Line" Rule
**Explicit Instruction:** Do not use 1px solid borders to section content. Boundaries must be defined solely through background color shifts.
*   *Implementation:* A `surface_container_low` section sitting on a `surface` background creates a clear but soft structural break. If you feel the need for a line, increase the spacing or shift the background tone instead.

### The "Glass & Gradient" Rule
To add "soul" to the schematic language:
*   **Hero CTA Gradients:** Use a subtle linear gradient from `primary` (#005129) to `primary_container` (#1A6B3C) at a 135° angle.
*   **Floating Elements:** For top-navigation bars or floating action buttons, use **Glassmorphism**. Apply `surface_container_low` with a 70% opacity and a `20px` backdrop-blur to allow the green "felt" diagrams to bleed through.

---

## 3. Typography
We utilize a clean, sans-serif stack (Inter/SF Pro) to maintain a "Native Pro" feel. 

| Level | Size | Weight | Role |
| :--- | :--- | :--- | :--- |
| **Display-LG** | 3.5rem | Bold | Data-driven milestones (e.g., "98% Accuracy") |
| **Headline-SM** | 1.5rem | Semi-Bold | Page headers and diagram titles |
| **Title-MD** | 1.125rem | Medium | Card titles and drill names |
| **Body-LG** | 1rem | Regular | Instructional text and educational content |
| **Label-MD** | 0.75rem | Bold | Micro-stats, Ball types (White, Orange, Ghost) |

**Editorial Contrast:** Use `display-lg` in close proximity to `label-md`. This high-contrast scale hierarchy makes the UI feel curated and modern rather than a flat, monotonous list.

---

## 4. Elevation & Depth
Depth in this system is achieved through **Tonal Layering**, not structural shadows.

### The Layering Principle
Think of the UI as stacked sheets of fine paper. 
1.  **Level 0 (Base):** `background` (#FAF9FE).
2.  **Level 1 (Sections):** `surface_container_low` (#F4F3F8).
3.  **Level 2 (Cards):** `surface_container_lowest` (#FFFFFF).

### Ambient Shadows
Shadows should be rare. When required for "floating" elements:
*   **Values:** `0px 12px 32px rgba(26, 27, 31, 0.06)`
*   The shadow is ultra-diffused and tinted with the `on_surface` color to feel like natural ambient light.

### The "Ghost Border" Fallback
If accessibility demands a border (e.g., in high-contrast modes), use a **Ghost Border**: `outline_variant` (#BFC9BE) at **15% opacity**. Never use a 100% opaque border.

---

## 5. Components

### The Schematic Diagram (Signature Component)
The core of the app. 
*   **Felt:** `primary_container` (#1A6B3C).
*   **Shot Lines:** `secondary_container` (#68ABFF) with a 2pt dashed stroke.
*   **Contact Points:** `error` (#BA1A1A) small circles with a `surface_container_lowest` white glow.
*   **Ghost Ball:** `rgba(255, 215, 0, 0.3)` with a subtle `outline` stroke.

### Buttons
*   **Primary:** Solid `primary` gradient. Roundedness: `md` (0.75rem).
*   **Secondary:** `surface_container_high` background with `on_primary_fixed_variant` text. No border.
*   **Tertiary:** Ghost style. `label-md` text only, centered.

### Cards & Lists
**Forbid divider lines.** 
*   Separate list items using `12px` vertical white space.
*   Use `surface_container_low` for the "unselected" state and `surface_container_lowest` with an ambient shadow for the "active" state.

### Input Fields
*   **Style:** Minimalist. No bottom line. Use a `surface_container_highest` background with a `sm` (0.25rem) corner radius. 
*   **Focus:** Transition background to `primary_fixed` at 10% opacity.

---

## 6. Do's and Don'ts

### Do:
*   **Do** use asymmetrical padding. Give the schematic diagrams more "air" at the top than the bottom to create a sense of focus.
*   **Do** use "Billiard Green" sparingly in the UI (only for primary actions) so that it retains its impact when it appears in the billiard table diagrams.
*   **Do** prioritize the "Ghost Ball" yellow for instructional overlays—it should feel like a digital HUD.

### Don't:
*   **Don't** use standard "Grey" for shadows. Use tinted translucency.
*   **Don't** use 1px dividers between list items. Use whitespace or subtle background color steps.
*   **Don't** use sharp corners. Billiard balls and table pockets are rounded; the UI should reflect this with the `md` (0.75rem) and `lg` (1rem) corner scales.