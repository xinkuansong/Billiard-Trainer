```markdown
# Design System: The Precision Playbook

## 1. Overview & Creative North Star
**Creative North Star: "The Master’s Table"**

This design system moves beyond the utility of a standard tracker to become a high-end digital mentor. The experience is rooted in **Organic Precision**: a marriage of the tactile, physical world of billiards (felt, slate, and mahogany) with a sophisticated, editorial iOS interface. 

To break the "template" look, we employ **Intentional Asymmetry**. Instead of perfectly centered modules, we use staggered typography scales and "The Layering Principle" to create a sense of depth and focus. We treat the screen not as a flat surface, but as a series of stacked, premium materials—heavy cardstock, frosted glass, and deep, lush forest-green felt.

---

## 2. Colors: Tonal Depth & The No-Line Rule
Our palette is anchored by a deep, authoritative green, supported by the warm, high-stakes hues of tournament-grade equipment.

### Color Palette Reference
- **Primary (The Table):** `#005129` (Primary) | `#1A6B3C` (Container)
- **Secondary (The Trophy):** `#805600` (Secondary) | `#D4941A` (Amber/Gold)
- **Tertiary (The Red Ball):** `#91000E` (Tertiary) | `#C62828` (Action Red)
- **Neutral/Background:** `#F9F9FE` (Surface) | `#F2F2F7` (System Background)

### The "No-Line" Rule
**Explicit Instruction:** Prohibit 1px solid borders for sectioning. Boundaries must be defined solely through background color shifts. 
- Use `surface-container-low` for secondary content areas.
- Use `surface-container-lowest` (`#FFFFFF`) for primary interactive cards.
- Separation is achieved through the **8pt spacing scale**, never a stroke.

### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers.
1.  **Base Layer:** `surface` (`#F9F9FE`) - The foundation.
2.  **Section Layer:** `surface-container-low` (`#F3F3F8`) - Large groupings of content.
3.  **Active Layer:** `surface-container-lowest` (`#FFFFFF`) - The interactive card.
4.  **Floating Layer:** Glassmorphism - Semi-transparent `surface-variant` with `backdrop-filter: blur(20px)` for navigation bars and overlays.

---

## 3. Typography: Editorial Authority
We utilize a sophisticated scale that pairs the rounded, approachable nature of billiards with the sharp precision of a master coach.

- **Display (The Statement):** `plusJakartaSans` 3.5rem (Display-LG). Used for hero metrics or "Level Up" moments.
- **Section Titles (The Brand):** `SF Pro Rounded` 22pt Bold (`#1A6B3C`). This is our signature brand voice. Use it for category headers to provide a soft, premium feel.
- **The Body (The Instruction):** `inter` or `SF Pro` 15pt-17pt. Focus on line-height (1.4x-1.5x) to ensure legibility during intense training sessions.
- **Labels (The Detail):** `inter` 0.75rem. Use `on-surface-variant` for secondary metadata.

---

## 4. Elevation & Depth: Tonal Layering
We reject the "drop shadow" of the 2010s. Depth is achieved through light and material.

- **The Layering Principle:** Place a `#FFFFFF` (Surface-lowest) card on a `#F3F3F8` (Surface-low) background. This creates a "soft lift" that feels architectural rather than digital.
- **Ambient Shadows:** Only for floating CTAs or critical modals. Use a custom shadow: `0px 12px 32px rgba(26, 28, 31, 0.06)`. The tint is derived from `on-surface` to ensure it feels like a natural shadow cast on the table.
- **The "Ghost Border" Fallback:** In rare cases where a card sits on an identical color (e.g., in dark mode or complex media), use a 1px border of `outline-variant` at **15% opacity**. It should be felt, not seen.
- **Signature Texture:** Use a subtle gradient from `primary` (#005129) to `primary-container` (#1A6B3C) **only** for main action buttons (e.g., "Start Training") to provide a "concave" tactile feel.

---

## 5. Components: The Kit

### Cards & Lists (The Core)
*   **Style:** `surface-container-lowest` (#FFFFFF), Corner Radius: `xl` (1.5rem / 24pt for modern look, or `lg` 16pt for classic).
*   **Rule:** Forbid divider lines. Use `16pt` internal padding and `24pt` vertical margins between cards.

### Primary Buttons
*   **Visuals:** Solid `primary-container` (#1A6B3C) fill. No border.
*   **Interaction:** On press, scale down to 0.98. Use `on-primary` (#FFFFFF) for text.

### Selection Chips
*   **State:** Unselected chips should use `surface-container-high` with no border. Selected chips use `secondary-container` (#FCB73F) to highlight the "Amber" brand color.

### Input Fields
*   **Visuals:** A subtle "inset" look using `surface-container-highest`. No visible border unless focused. When focused, use a `primary` ghost-border at 20% opacity.

### Specialized Component: The "Shot Tracker"
A custom component utilizing a 4:3 aspect ratio card. The background uses a 10% opacity `primary` tint, with a "Glass" overlay for real-time stats (e.g., Angle, Power).

---

## 6. Do’s and Don’ts

### Do
- **Do** use whitespace as a separator. If you feel the need to add a line, add 8px of padding instead.
- **Do** use the "Amber" secondary color for success states and "Gold" achievements to contrast against the green.
- **Do** align icons and text to a strict 8pt grid, but allow large typography to "bleed" slightly into margins for an editorial feel.

### Don't
- **Don't** use 100% black. Use `on-surface` (#1A1C1F) for all "black" text to keep the interface soft.
- **Don't** use gradients on cards or backgrounds. Keep fills solid to maintain the "Clean, Minimal iOS" requirement.
- **Don't** use standard iOS blue for links. Every interactive element must be either `primary` (Green) or `secondary` (Amber).
- **Don't** use sharp corners. Everything in billiards (balls, pockets, table cushions) is rounded; the UI must reflect this.```