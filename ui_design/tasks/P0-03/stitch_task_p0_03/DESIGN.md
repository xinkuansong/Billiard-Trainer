# Design System: The Tactical Precision Framework

## 1. Overview & Creative North Star
**Creative North Star: "The Master’s Eye"**

The design system moves beyond the utility of a standard training app to evoke the focused, high-stakes atmosphere of a professional billiards hall. We reject the "generic SaaS" look in favor of a **High-End Editorial** experience. The aesthetic is defined by "The Master’s Eye"—a visual language that prioritizes absolute clarity, rhythmic spacing, and a sense of "quiet power."

By utilizing intentional asymmetry, expansive negative space, and a sophisticated tonal layering system, we transform a task-oriented tool into a premium sporting companion. We avoid rigid grids; instead, we use "weighted layouts" where information is anchored by bold typography and balanced by deep, organic greens.

## 2. Colors
Our palette is a sophisticated evolution of billiards heritage. We utilize the depth of the felt and the precision of the cue ball to drive user focus.

### The Palette (Material Context)
*   **Primary (Action):** `#004392` (A deepened System Blue for authoritative actions)
*   **Secondary (Heritage Green):** `#1B6C3D` (The 'Felt'—used for brand presence)
*   **Tertiary (Cushion):** `#623F00` (Used for technical accents and depth)
*   **Surface Hierarchy:** 
    *   `surface`: `#FAF9FE` (The base sheet)
    *   `surface_container_low`: `#F4F3F8` (Subtle sectioning)
    *   `surface_container_highest`: `#E3E2E7` (Prominent card backgrounds)

### Design Directives
*   **The "No-Line" Rule:** 1px solid borders are strictly prohibited for sectioning content. To separate a training module from a statistics block, use a shift from `surface` to `surface_container_low`. Boundaries are felt, not seen.
*   **Surface Hierarchy & Nesting:** Treat the UI as physical layers. A `surface_container_lowest` card should sit atop a `surface_container_low` section to create a soft, natural lift.
*   **The "Glass & Gradient" Rule:** For floating headers or tactical overlays (like shot diagrams), use a backdrop-blur (20px+) with `surface_variant` at 70% opacity. 
*   **Signature Textures:** Main CTAs should utilize a subtle linear gradient from `primary` to `primary_container` (top-to-bottom) to provide a polished, three-dimensional "button" feel that mimics the gloss of a billiard ball.

## 3. Typography
We use a dual-font strategy to balance athletic energy with technical precision.

*   **Display & Headlines (Manrope):** Chosen for its geometric precision and modern "tech-sport" feel. 
    *   *Display-Lg (3.5rem):* Used for primary data points (e.g., Accuracy %).
    *   *Headline-Sm (1.5rem):* Used for section headers to provide an editorial, magazine-like structure.
*   **Body & Labels (Inter):** A workhorse for legibility. 
    *   *Body-Md (0.875rem):* Standard for all coaching notes and instructional text.
    *   *Label-Sm (0.6875rem):* Used for technical metadata (e.g., ball velocity, spin rate) with increased letter spacing (0.05em).

The hierarchy is intentionally extreme. Use large `display` type against small `label` type to create a sense of professional authority.

## 4. Elevation & Depth
In this system, depth is a result of light and material, not artificial lines.

*   **The Layering Principle:** Avoid shadows where background shifts suffice. If a card needs to pop, place a `#FFFFFF` (`surface_container_lowest`) card on a `#F4F3F8` (`surface_container_low`) background.
*   **Ambient Shadows:** For floating elements (Modals/Action Sheets), use a "Billiard Shadow": 
    *   `Y: 12px, Blur: 24px, Spread: -4px` 
    *   Color: `on_surface` at 6% opacity. This mimics the soft ambient light of a table lamp.
*   **The "Ghost Border" Fallback:** If a layout requires a container boundary for accessibility, use `outline_variant` at 15% opacity. It should be barely perceptible.
*   **Glassmorphism:** Use `surface_tint` with a 40% alpha and a heavy blur for bottom navigation bars, allowing the "felt green" of the content to bleed through.

## 5. Components

### Buttons
*   **Primary:** High-gloss gradient (`primary` to `primary_container`), `xl` (1.5rem) corner radius. Use for "Start Training."
*   **Secondary:** `surface_container_highest` fill with `on_surface` text. No border.
*   **Tertiary:** Ghost style. Text only in `primary` weight, used for "Cancel" or "View Details."

### Cards & Training Modules
*   **Architecture:** Use `lg` (1rem) corner radius. Forbid dividers. 
*   **Layout:** Group related data using `8px` (sm) spacing. Separate distinct groups using `24px` (xl) vertical white space.
*   **Thumbnails:** Always use `md` (0.75rem) corner radius for video drills or shot diagrams.

### Tactical Chips
*   **Filter Chips:** Use `secondary_container` for active states. Use `surface_variant` for inactive.
*   **Action Chips:** Small, pill-shaped (`full` radius) with `label-md` typography.

### Input Fields
*   **Styling:** Subtle `surface_container_high` fill. When focused, transition the background to `surface_container_lowest` and apply a 1pt `primary` ghost border (20% opacity).

## 6. Do's and Don'ts

### Do
*   **Do** use asymmetrical layouts (e.g., a large headline on the left with a small label on the right) to create a premium editorial feel.
*   **Do** use `secondary` (Felt Green) as a flood color for empty states or "Success" screens to reinforce brand identity.
*   **Do** prioritize SF Symbols with 'Semibold' weight to match the Manrope headline weights.

### Don't
*   **Don't** use black (`#000000`). Use `on_surface` (`#1A1B1F`) to keep the "ink" soft and professional.
*   **Don't** use 1px dividers between list items. Use 16px of vertical padding and a tonal shift.
*   **Don't** use standard iOS blue for everything. Reserve `primary` for the "One Main Action" per screen. Everything else should be tonal or `secondary`.

---
*Director's Note: Precision is not the absence of complexity, but the mastery of it. Keep the margins wide and the intent clear.*