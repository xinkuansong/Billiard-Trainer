```markdown
# The Design System: Tactical Precision & Heritage Greens

## 1. Overview & Creative North Star
The Creative North Star for this design system is **"The Digital Cloth."** 

Billiards is a game of extreme geometric precision paired with a rich, tactile heritage. This system rejects the generic "utility app" aesthetic in favor of a high-end editorial experience. We translate the physical weight of the pool table—the lush felt, the polished resin of the balls, and the mahogany of the cushions—into a digital environment that feels as quiet and focused as a championship match. 

By leveraging intentional asymmetry, expansive negative space, and tonal depth, we move beyond standard iOS patterns to create a signature "Tactile Minimalist" interface.

---

## 2. Colors: The Baize Palette
The color logic is rooted in the "No-Line" Rule. We define boundaries through shifts in value and saturation, never through 1px strokes.

### Core Brand & Table Tones
*   **Primary (`#1A6B3C`):** The "Brand Green." Used for core actions and section headers to establish authority.
*   **Table Felt (`#1B6B3A`):** A slightly more vibrant green used for the `BTBilliardTable` schematic to mimic the playing surface.
*   **Cushion Brown (`#7B3F00`):** Used sparingly as a tertiary accent to ground the UI, providing a warm contrast to the greens.
*   **Target Ball Orange (`#F5A623`):** Reserved strictly for "Focus Points" or "Target Balls" in training drills.
*   **Pro Gold (`#D4941A`):** Our signature accent for "Pro" features, high-achievement streaks, and premium tiers.

### Surface Hierarchy & Nesting
Instead of borders, use the `Surface Container` tokens to create a "nested" layout:
*   **Base Layer:** `surface` (`#FCF8FB`).
*   **Secondary Sectioning:** `surface_container_low` (`#F6F3F5`).
*   **Primary Interaction Cards:** `surface_container_lowest` (`#FFFFFF`).
*   **The "Glass" Exception:** For floating HUD elements over the billiard table, use a 80% opacity blur of `surface_container_high` (`#EAE7EA`) with a 20pt Backdrop Blur.

---

## 3. Typography: The Editorial Scale
We use a high-contrast scale to separate technical data from instructional content.

*   **Display & Headlines:** Using **Plus Jakarta Sans**. The geometric nature of this font mirrors the paths of the balls.
    *   *Headline-LG (22pt Bold Rounded):* Used for primary section titles in Brand Green (`#1A6B3C`).
*   **Titles & Body:** Using **Inter** (as a sophisticated alternative to standard SF Pro) for superior readability in data-heavy training logs.
*   **The "Pro" Label:** All `label-sm` tokens should be uppercase with +5% letter spacing to evoke a premium, watchmaker-style aesthetic.

---

## 4. Elevation & Depth: Tonal Layering
In this system, depth is a result of color theory, not drop shadows.

*   **The Layering Principle:** A `BTShareCard` shouldn't "pop" with a shadow; it should sit on a `surface_dim` (`#DCD9DC`) background to feel like a physical card on a dark table.
*   **Ambient Shadows:** If an element must float (e.g., a cue ball selector), use a shadow tinted with `primary_fixed_variant` (`#005229`) at 6% opacity. Never use pure black or grey shadows.
*   **The "Ghost Border":** For dark theme variants (`#1C1C1E`), use the `outline_variant` token at 10% opacity to provide just enough definition against the dark background without breaking the "No-Line" rule.

---

## 5. Components

### BTBilliardTable (The Schematic)
The centerpiece of the app. 
*   **Field:** Flat fill of Table Felt Green (`#1B6B3A`).
*   **Rails:** Cushion Brown (`#7B3F00`) defined by a simple 8pt inset from the container edge.
*   **The Cue Ball:** A perfect circle in Cue Ball White (`#F5F5F5`). No gradients—use a 2pt inner-glow of `surface_dim` to suggest roundness.

### BTShareCard (Dark Variants)
For high-impact social sharing. 
*   **Theme Midnight:** Background `#1C1C1E`.
*   **Theme Deep Sea:** Background `#0D1B2A`.
*   **Typography:** All text transitions to `inverse_on_surface`.
*   **Accents:** Utilize the Pro/Accent Gold (`#D4941A`) for "Drill Completed" badges to create a high-luxury feel.

### Cards & Action Items
*   **Container:** White (`#FFFFFF`), 16pt radius, 16pt padding.
*   **Spacing:** Forbid dividers. Use 24pt vertical spacing between list items. Use a `surface_container_low` background shift to indicate different groupings.

### Buttons & Inputs
*   **Primary Button:** `primary_container` (`#1A6B3C`) with `on_primary` text. No border, 12pt radius.
*   **Input Fields:** Use `surface_container_highest` (`#E4E2E4`) as a fill. The label should sit 8pt above the field in `on_surface_variant`.

---

## 6. Do’s and Don’ts

### Do
*   **Do** use asymmetrical padding for headlines to create an editorial, "magazine" feel.
*   **Do** use the Pro Gold (`#D4941A`) sparingly; it is a reward, not a utility.
*   **Do** ensure all "Target Balls" in diagrams use the exact Target Ball Orange (`#F5A623`) for instant recognition.

### Don’t
*   **Don’t** use 1px solid lines to separate content. Use whitespace or color blocks.
*   **Don’t** use gradients. Our premium feel comes from flat, perfectly balanced color ratios.
*   **Don’t** use standard iOS blue for links. Everything interactive must be Brand Green or Pro Gold.

---
*Document Version 1.0 | Senior UI/UX Direction*