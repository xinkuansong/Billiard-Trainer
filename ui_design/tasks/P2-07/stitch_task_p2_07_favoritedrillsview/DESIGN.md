# Design System Strategy: High-End Billiards Editorial

## 1. Overview & Creative North Star
This design system is anchored by a Creative North Star we define as **"The Precision Curator."** 

Billiards is a game of geometry, silence, and absolute focus. To reflect this, the UI moves away from the "clutter" of traditional sports apps. Instead, it adopts a high-end editorial feel—treating each training drill like a curated gallery piece. We achieve this through **intentional asymmetry**, generous **breathing room (whitespace)**, and a strict adherence to **tonal depth** over structural lines. By utilizing the Manrope and Inter typography pairings alongside a deep forest green palette, we create an environment that feels authoritative, premium, and focused.

## 2. Colors & Surface Architecture

The palette is designed to evoke the tactile feel of high-grade billiard baize and polished wood, translated into a modern digital interface.

### The Palette (Material Design Tokens)
*   **Primary (`#005129`)**: Our "Deep Baize." Used for core actions and brand presence.
*   **Primary Container (`#1A6B3C`)**: The "Action Green." Reserved for solid flat fills on high-priority buttons and active states.
*   **Secondary (`#805600`) & Secondary Container (`#FCB73F`)**: The "Trophy Gold." Used exclusively for PRO status, high-level mastery (L2/L3), and achievement accents.
*   **Surface / Background (`#F9F9FE`)**: A crisp, cool-toned base that provides high contrast for content.

### The "No-Line" Rule
To maintain an editorial aesthetic, **1px solid borders are strictly prohibited for sectioning.** 
Visual boundaries must be created through:
1.  **Background Shifts**: Using `surface-container-low` against a `surface` background.
2.  **Vertical Space**: Utilizing the spacing scale to group related elements.
3.  **Soft Shadows**: Ambient, low-opacity shadows that suggest elevation without hard edges.

### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers. Use the following nesting logic:
*   **Level 0 (Base)**: `surface` (#F9F9FE) – The main page canvas.
*   **Level 1 (Sectioning)**: `surface-container-low` (#F3F3F8) – Large content groupings.
*   **Level 2 (Interaction)**: `surface-container-lowest` (#FFFFFF) – The BTDrillCard background. Placing a white card on a slightly off-white background creates a "soft lift" that feels more premium than a heavy shadow.

---

## 3. Typography

The typography strategy leverages the authority of **Manrope** for headers and the clarity of **Inter** (or SF Pro) for functional data.

| Level | Font Family | Size | Weight | Role |
| :--- | :--- | :--- | :--- | :--- |
| **Display-MD** | Manrope | 2.75rem | Bold | Hero stats and achievement numbers. |
| **Headline-SM** | Manrope | 1.5rem | Semibold | Section titles (e.g., "Accuracy Drills"). |
| **Title-SM** | Inter | 1.0rem | Semibold | BTDrillCard Titles (Primary Information). |
| **Body-LG** | Inter | 1.0rem | Regular | Primary body text and descriptions. |
| **Label-MD** | Inter | 0.75rem | Medium | Meta-data, Level badges, and secondary text. |

**Tonal Hierarchy**: Primary text uses `on-surface` (#1A1C1F). Secondary/Supporting text uses `on-surface-variant` with a 60% opacity (`rgba(60, 60, 67, 0.6)`), ensuring the eye hits the most important information first.

---

## 4. Elevation & Depth

### The Layering Principle
Depth is achieved through **Tonal Layering**. Avoid the "pasted-on" look of heavy drop shadows. 
*   **The Ambient Shadow**: When a card requires a floating state (e.g., a modal or a primary CTA), use a shadow with a blur radius of 24pt-32pt and an opacity of 4%-6%. The shadow color should be tinted with our brand green (`#005129`) at low opacity to feel like natural, ambient light.
*   **The "Ghost Border" Fallback**: For components like search bars or input fields, if a container needs definition, use a `1pt` stroke of `outline-variant` at 15% opacity. It should be felt, not seen.

### Glassmorphism
For floating navigation elements (like a custom Tab Bar or a persistent "Start Drill" button), use a semi-transparent `surface` color with a **20px Backdrop Blur**. This integrates the element into the layout while maintaining legibility.

---

## 5. Components

### BTDrillCard
The signature component of the system.
*   **Background**: `surface-container-lowest` (#FFFFFF).
*   **Radius**: `12pt` (Scale: `lg`).
*   **Padding**: `16pt` all around.
*   **Style**: No border. Use a subtle `4%` ambient shadow. Content should be asymmetrically balanced, with the level badge providing a "weight" anchor in the top right or bottom left.

### BTLevelBadge (Pill Shape)
*   **Shape**: Full round (`9999px`).
*   **L0 (Entry)**: Background `primary-container`, Text `on-primary`.
*   **L2-L4 (Advanced)**: Background `secondary-container` (#FCB73F), Text `on-secondary-container`.
*   **PRO Badge**: Background `secondary` (#805600), Text `#FFFFFF`.

### Buttons
*   **Primary**: Solid `primary-container` (#1A6B3C). Flat fill only. No gradients.
*   **Secondary**: `surface-container-high` background with `on-surface` text.
*   **Tertiary**: Text-only using `primary` color, Semibold weight.

### Lists & Cards
**Forbid divider lines.** Use `16pt` or `24pt` vertical gaps between cards to separate content. In long lists, use a subtle background toggle (alternating between `surface` and `surface-container-low`) to maintain row tracking without the visual noise of lines.

---

## 6. Do's and Don'ts

### Do
*   **Do** use asymmetrical layouts for headers to create a "magazine" feel.
*   **Do** leverage the contrast between the deep Green (`#1A6B3C`) and the Gold (`#D4941A`) to highlight progression.
*   **Do** use large, high-quality imagery within cards that bleeds to the edges where possible.

### Don't
*   **Don't** use 1px solid black or grey borders. This instantly degrades the "premium" feel.
*   **Don't** apply gradients. The "Precision Curator" aesthetic relies on the confidence of solid, flat color blocks.
*   **Don't** crowd the interface. If an element isn't strictly necessary for the drill, move it to a secondary layer.
*   **Don't** use standard iOS blue for links. Always use the brand primary green.