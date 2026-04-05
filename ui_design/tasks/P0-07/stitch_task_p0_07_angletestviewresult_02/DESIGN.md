# Design System Strategy: The Master’s Table

## 1. Overview & Creative North Star
The Creative North Star for this design system is **"The Technical Atelier."** 

Billiards is a game of extreme precision, quiet focus, and centuries of tradition. This design system rejects the "gamified" look of casual sports apps in favor of a high-end, editorial experience that feels like a private coaching session in a premium lounge. We achieve this by blending the clinical clarity of a physics engine with the tactile luxury of a mahogany-and-felt billiard club.

To break the "template" look, we utilize **Intentional Asymmetry**. We move away from perfectly centered grids to create "breathing gutters" and overlapping elements. Text may bleed into image containers, and floating table visualizations will break the card boundaries to create a sense of depth and motion.

---

## 2. Colors & Surface Logic
The palette is rooted in the rich, deep tones of a championship table, elevated by a sophisticated neutral system.

### Color Tokens
*   **Primary (The Felt):** `#005129` (Primary) | `#1A6B3C` (Primary Container)
*   **Secondary (The Wood):** `#8E4E11` (Secondary) | `#FDA865` (Secondary Container)
*   **Tertiary (The Target):** `#623F00` (Tertiary) | `#FFB955` (Tertiary Fixed Dim)
*   **Neutral Surfaces:** `#F9F9FE` (Surface) | `#EDEDF2` (Surface Container) | `#FFFFFF` (Lowest)

### The "No-Line" Rule
**Explicit Instruction:** Designers are prohibited from using 1px solid borders for sectioning. Structural boundaries must be defined solely through background color shifts. 
*   *Implementation:* A training module (`surface-container-low`) sits directly on the app background (`surface`) without a stroke. Separation is felt, not seen.

### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers—like stacked sheets of fine paper.
*   **Level 0 (Base):** `surface` (#F9F9FE) – The foundation.
*   **Level 1 (Sections):** `surface-container-low` (#F3F3F8) – Inset content areas.
*   **Level 2 (Cards):** `surface-container-lowest` (#FFFFFF) – High-priority interactive elements.

### The "Glass & Tone" Rule
While the user requested "solid fills," we elevate this by using **Tone-on-Tone Depth**. For floating elements like ball-positioning overlays, use semi-transparent versions of `surface` with a 20pt backdrop blur. Main CTAs should utilize a subtle transition from `primary` (#005129) to `primary-container` (#1A6B3C) to give the button a "weighted" feel that flat hex codes cannot provide.

---

## 3. Typography: Editorial Precision
The typography scale uses a dual-font approach to balance authority with utility.

| Level | Token | Font | Size | Weight | Intent |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Display** | `display-lg` | Manrope | 3.5rem | 700 | Large score/angle figures |
| **Headline** | `headline-md` | Manrope | 1.75rem | 600 | Chapter/Lesson titles |
| **Title** | `title-lg` | Inter/SF | 1.375rem | 600 | Card headings |
| **Body** | `body-md` | Inter/SF | 0.875rem | 400 | Instructional text |
| **Label** | `label-md` | Inter/SF | 0.75rem | 500 | Metadata/Technical specs |

**Identity Logic:** Manrope provides a geometric, modern "technical" feel for headings, while Inter/SF Pro ensures the high legibility required for instructional content. Use `display-lg` with tight letter spacing for a premium, magazine-style look.

---

## 4. Elevation & Depth: Tonal Layering
We do not use structural lines. Depth is achieved through "Tonal Stacking."

*   **The Layering Principle:** To lift a card, do not add a shadow immediately. Instead, place a `#FFFFFF` card on a `#F3F3F8` background. 
*   **Ambient Shadows:** If a floating action button or a modal requires a shadow, it must be "Ambient."
    *   *Specs:* Blur: 32px, Y: 8px, Opacity: 6% of `#1A1C1F`. This mimics natural light falling on a felt surface.
*   **The "Ghost Border" Fallback:** For accessibility in dark-mode or low-contrast ball visualizations, use a 1px border with `outline-variant` at **15% opacity**.

---

## 5. Components

### Primary Training Button
*   **Style:** `primary` fill, 50pt height, 12pt radius (rounded but structured).
*   **Typography:** `title-sm` (White, Bold).
*   **Interaction:** On press, the color shifts to `primary-fixed-dim`. No stroke.

### Table Visualization Elements
*   **The Felt:** Use `surface-tint` (#1B6C3D) for the main table area.
*   **The Cushion:** Represented by a subtle `on-secondary-fixed-variant` (#6F3800) perimeter.
*   **The Cue Ball:** A perfect circle of `surface-container-lowest` with a "Ghost Border" to ensure it pops against the green felt.

### Progress & Feedback
*   **Pill Badges:** Use `secondary-container` for "In Progress" and `primary-fixed` for "Mastered." Use `label-md` for the text.
*   **Error States:** Incorrect cue paths must use `error` (#BA1A1A) with a 2pt stroke width. Avoid solid red blocks; use lines to maintain the "Technical Atelier" aesthetic.

### Cards & Lists
*   **Rule:** Forbid divider lines.
*   **Alternative:** Use `1.5rem` (xl) vertical spacing between list items, or place each item in a separate `surface-container-lowest` card with a `16pt` radius.

---

## 6. Do’s and Don’ts

### Do
*   **Do** use extreme whitespace (32pt+) to separate major training modules.
*   **Do** allow the table visualization to bleed off the edge of the screen to suggest a larger world.
*   **Do** use "Surface Tints" (Primary at 5% opacity) for background washes to keep the brand present.

### Don't
*   **Don't** use 100% black (#000000). Use `on-surface` (#1A1C1F) for text to keep it sophisticated.
*   **Don't** use standard iOS blue for links. Everything interactive must be `primary` green or `secondary` wood-brown.
*   **Don't** use sharp 90-degree corners. Even the "Technical" elements must feel premium with a minimum `0.25rem` (sm) radius.