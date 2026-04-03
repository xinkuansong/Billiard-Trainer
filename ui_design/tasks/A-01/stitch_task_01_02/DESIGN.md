# Design System Strategy: Precision & Pedigree

## 1. Overview & Creative North Star
**The Creative North Star: "The Tactical Atelier"**

This design system transcends the typical sports app by treating billiards as a high-stakes discipline of geometry and focus. We are moving away from "gym aesthetics" toward a look that feels like a precision instrument—athletic yet editorial. 

To break the "template" look, we employ **Intentional Asymmetry** and **Tonal Depth**. Our layouts should feel like a premium sports magazine: generous whitespace, high-contrast typography, and layered surfaces that mimic the tactile feel of a high-end billiard room—baize green, polished amber, and slate grey.

---

## 2. Colors & Surface Philosophy

### Color Tokens
- **Primary (Billiard Green):** `#005129` (The foundation of authority and focus).
- **Primary Container:** `#1A6B3C` (Used for larger surface areas and emphasis).
- **Secondary (Amber/Gold):** `#805600` / **Secondary Container:** `#FCB73F` (The "spark" of precision and achievement).
- **Tertiary (Deep Rose):** `#782C38` (Used for sophisticated secondary actions).
- **Neutral Background:** `surface-container-lowest` (`#FFFFFF`) to `surface` (`#F9F9FE`).

### The "No-Line" Rule
To maintain a high-end editorial feel, **1px solid borders are strictly prohibited** for sectioning content. Boundaries must be defined solely through:
1.  **Background Shifts:** Placing a `surface-container-low` card on a `surface` background.
2.  **Negative Space:** Utilizing the `spacing-8` (2rem) or `spacing-10` (2.5rem) tokens to create natural breathing room between content blocks.

### The Glass & Gradient Rule
CTAs and Hero elements should utilize a **Signature Texture**. Instead of flat colors, use a subtle linear gradient from `primary` (`#005129`) to `primary-container` (`#1A6B3C`) at a 135-degree angle. For floating navigation or over-image overlays, apply **Glassmorphism**: a semi-transparent `surface` color with a `20px` backdrop blur to soften the transition between layers.

---

### 3. Typography: The Voice of Precision

Our type system pairs the authority of **SF Pro** with the approachable, technical feel of **SF Pro Rounded**.

*   **Display (SF Pro):** Used for large achievement numbers or training milestones. *Display-lg (3.5rem)*.
*   **Headline (SF Pro Rounded):** Used for section titles. The rounded terminals mirror the geometry of the balls. *Headline-md (1.75rem)*.
*   **Title (SF Pro):** Medium weight for card titles and navigation headers. *Title-lg (1.375rem)*.
*   **Body (SF Pro):** Regular weight for descriptions and instruction. *Body-md (0.875rem)*.
*   **Label (SF Pro Rounded - All Caps):** Used for tactical metadata (e.g., "SHOT ANGLE," "VELOCITY"). This adds a technical, athletic grit to the UI.

---

## 4. Elevation & Depth: Tonal Layering

We do not use structural lines. Depth is achieved by "stacking" the surface-container tiers to create a physical sense of hierarchy.

*   **The Layering Principle:** Place a `surface-container-lowest` (`#FFFFFF`) card on top of a `surface-container-low` (`#F3F3F8`) section. This creates a soft, natural "lift" that mimics ambient light hitting a surface.
*   **Ambient Shadows:** For floating elements (like a shot-timer FAB), use extra-diffused shadows. 
    *   *Shadow:* 0px 12px 32px rgba(0, 0, 0, 0.06). 
    *   The shadow should never be pure black; it should be a deep, low-opacity tint of the background color.
*   **The "Ghost Border" Fallback:** If a container sits on a background of the exact same color, use the `outline-variant` token at **15% opacity**. This provides a "suggestion" of a boundary without the harshness of a line.

---

## 5. Component Guidelines

### Buttons (The "Tactical" CTA)
*   **Primary:** Gradient fill (`primary` to `primary-container`), `16pt` (xl) corner radius. Use `on-primary` text in `label-md` (All Caps).
*   **Secondary:** `surface-container-high` background with `primary` text. No border.
*   **Tertiary:** Transparent background with `primary` text and a subtle underline (2px) using `primary-fixed-dim`.

### Cards & Training Modules
*   **Rule:** Forbid divider lines within cards.
*   **Separation:** Use `spacing-4` (1rem) between header and body content.
*   **Geometry:** Always use a `16pt` corner radius (`xl`) to maintain the "QiuJi" athletic identity.

### Tactical Inputs & Sliders
*   **Input Fields:** Use `surface-container-low` as the field background. Labels should use `label-sm` in `on-surface-variant`.
*   **Checkboxes/Radios:** When selected, use the `secondary` (Amber) token. This provides high-contrast feedback that feels like a premium "Gold Medal" status.

### Contextual Components
*   **Shot-Trace Overlay:** Use semi-transparent `secondary-container` paths with a `surface-tint` glow to visualize ball trajectories.
*   **Performance Chips:** Use `primary-fixed` backgrounds with `on-primary-fixed` text for positive metrics (e.g., "98% Accuracy").

---

## 6. Do’s and Don’ts

### Do
*   **Do** use asymmetrical margins (e.g., more padding on the left than the right in hero sections) to create an editorial, "scanned" look.
*   **Do** use the `secondary` (Amber) color sparingly—it should feel like a reward or a critical point of focus.
*   **Do** prioritize typography scale over color to show importance.

### Don't
*   **Don't** use 100% opaque black for text. Use `on-surface` (`#1A1C1F`) for primary and `on-surface-variant` (`#404940`) for secondary to maintain "air" in the design.
*   **Don't** use standard iOS dividers. If a list feels cluttered, increase the vertical padding using the `spacing-6` token.
*   **Don't** use sharp corners. Billiards is a game of spheres; our design system should reflect that fluidity with `lg` and `xl` corner radii.