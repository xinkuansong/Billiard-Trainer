# Design System Strategy: The Tactile Geometry

## 1. Overview & Creative North Star
The visual identity of this design system is guided by a Creative North Star we call **"The Tactile Geometry."** 

Billiards is a game of extreme precision, mathematical trajectories, and the physical sensation of felt and slate. This design system moves away from the generic "list-and-line" architecture of standard utility apps. Instead, it adopts a high-end editorial approach that mirrors the sport's sophistication. We achieve this through **intentional asymmetry**, **tonal depth**, and a **"No-Line" philosophy**. Every screen should feel like a premium digital scorecard—authoritative, clean, and meticulously spaced.

## 2. Colors & Surface Philosophy
The palette is anchored by the deep, resonant `#1A6B3C` (Billiard Green), but its power comes from how it interacts with the neutral scale.

### The "No-Line" Rule
To achieve a premium, custom feel, **1px solid borders are strictly prohibited** for sectioning or containment. Boundaries must be defined through:
*   **Background Color Shifts:** A `surface-container-lowest` card sitting on a `surface-container-low` background.
*   **Tonal Transitions:** Use the subtle shift from `#F2F2F7` (Background) to `#FFFFFF` (Surface) to imply edge without drawing it.

### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers. Use the following hierarchy to define importance:
1.  **Level 0 (Background):** `surface` (#f9f9fe) — The base "slate."
2.  **Level 1 (Sections):** `surface-container-low` (#f3f3f8) — Large grouping areas.
3.  **Level 2 (Active Cards):** `surface-container-lowest` (#ffffff) — The interactive "paper" where data lives.
4.  **Level 3 (Floating/Emphasis):** `surface-bright` (#f9f9fe) — For elements that need to pop above the fold.

### The "Glass & Gradient" Rule
Standard flat colors feel static. For primary CTAs and progress indicators, use a **Signature Texture**: a subtle linear gradient from `primary` (#005129) to `primary_container` (#1a6b3c). This adds "soul" and depth, mimicking the way light hits pool table cloth. For floating navigation or headers, apply a **Glassmorphism** effect using a semi-transparent `surface` color with a `20px` backdrop-blur to maintain context of the content underneath.

## 3. Typography
Our typography scale balances the technical nature of "tracking" with the elegance of the sport.

*   **Display & Headlines:** We use `plusJakartaSans`. Its geometric construction mirrors the precision of a shot's trajectory. **Large Titles** must use the **Rounded** variant to feel approachable yet bespoke.
*   **Body & Data:** We use `inter` for maximum legibility in high-density data views (e.g., shot success rates, session history).
*   **Hierarchy Note:** Use `display-lg` sparingly for "Big Wins" or "High Scores." Use `label-sm` in `secondary` text color (#404940) for technical annotations to create a distinct editorial contrast.

## 4. Elevation & Depth
In this design system, depth is a tool for focus, not just decoration.

*   **Tonal Layering:** Avoid drop shadows for standard cards. Achieve "lift" by placing a `surface-container-lowest` (#ffffff) element on a `surface-container-high` (#e8e8ed) background.
*   **Ambient Shadows:** When an element must float (like a "Start Session" button), use an extra-diffused shadow: `Y: 12, Blur: 24, Color: rgba(27, 108, 61, 0.08)`. Note the green tint in the shadow—it feels more natural and "billiard-like" than grey.
*   **The "Ghost Border" Fallback:** If a border is required for accessibility (e.g., input fields), use the `outline-variant` (#bfc9be) at **20% opacity**. It should be felt, not seen.

## 5. Components

### Pill Buttons (Primary)
*   **Shape:** Full radius (`9999px`).
*   **Color:** `primary` (#005129) with `on-primary` text (#ffffff).
*   **Design Note:** Use a subtle inner-glow (1px top-down) to give the pill a "3D" quality like a polished pool ball.

### Rounded Cards
*   **Shape:** `16pt` (1rem) corner radius.
*   **Container:** `surface-container-lowest`.
*   **Constraint:** No dividers. Use `16pt` vertical white space to separate content blocks within the card.

### Underlined Segmented Tabs
*   **Style:** No background container for the tab bar.
*   **Active State:** Text moves to `primary` green. The underline is a `3pt` thick pill-shaped bar using the `primary` color, centered under the label.
*   **Inactive State:** `secondary` text color (#404940).

### Empty States
*   **Layout:** Perfectly centered.
*   **Iconography:** Use large SF Symbols (64pt+) with `primary_container` (#1a6b3c) at **30% opacity**.
*   **Typography:** Use `title-md` for the header and `body-md` for the subtext, ensuring a wide margin for an editorial, airy feel.

### Trajectory Chips
*   **Usage:** For shot types (e.g., "Bank Shot," "Break").
*   **Style:** `surface-container-high` background with `on-surface-variant` text. High-contrast selection uses `primary_fixed` with `on-primary-fixed`.

## 6. Do's and Don'ts

### Do
*   **Do** use asymmetrical padding (e.g., wider left margins) in headers to create an editorial look.
*   **Do** use SF Symbols with "Medium" or "Semibold" weight to match the `plusJakartaSans` headlines.
*   **Do** use background tonal shifts to separate "Current Session" from "Past History."

### Don't
*   **Don't** use 100% black text for body copy; use `on-surface-variant` (#404940) to keep the layout "soft."
*   **Don't** use standard iOS dividers (hairlines). Use whitespace or a subtle background color change.
*   **Don't** use aggressive, high-opacity drop shadows. If it looks like it’s "pasted on," it’s too dark.