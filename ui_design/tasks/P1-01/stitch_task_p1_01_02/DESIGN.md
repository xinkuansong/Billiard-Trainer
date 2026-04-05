# Design System Document: Tactical Precision

## 1. Overview & Creative North Star
The Creative North Star for this design system is **"The Elite Tactician."** 

Billiards is a game of millimeters, calculated risks, and quiet focus. This system moves beyond a standard utility tracker to create an editorial, high-end training environment. It honors the heritage of the sport while embracing a modern, data-driven edge. 

By utilizing **intentional asymmetry** (such as left-aligned editorial headings paired with floating action elements) and **tonal layering**, we transform the interface from a list of drills into a curated masterclass. We reject the "boxed-in" feel of traditional apps in favor of an open, airy canvas where content breathes and hierarchy is felt rather than seen through lines.

---

## 2. Colors & Surface Philosophy

### Color Palette
- **Primary (Table Green):** `#005129` (Core Brand) / `#1A6B3C` (Container Active)
- **Secondary (Billiard Slate):** `#5F5E60`
- **Surface (Canvas):** `#F9F9FE` (Primary Background)
- **Accent (Gold/PRO):** `#D4941A` (Authority and Premium access)

### The "No-Line" Rule
To achieve a high-end editorial look, **1px solid borders are strictly prohibited** for sectioning or grouping content. Boundaries must be defined through:
1. **Background Color Shifts:** Use `surface-container-low` for secondary sections sitting on a `surface` background.
2. **Soft Tonal Transitions:** Define areas using subtle value changes in the neutral palette.

### Surface Hierarchy & Nesting
Treat the UI as a physical stack of fine paper. 
*   **Level 0 (Base):** `surface` (`#F9F9FE`) - The bottom-most layer.
*   Level 1 (Sections):** `surface-container-low` (`#F3F3F8`) - For large content groupings.
*   Level 2 (Cards):** `surface-container-lowest` (`#FFFFFF`) - For interactive drill cards and primary containers.

### The Glass & Gradient Rule
Floating elements (like the bottom tab bar or secondary modals) should utilize **Glassmorphism**. Use a semi-transparent `surface` color with a `20px` backdrop-blur to allow the rich green accents of the content to bleed through, creating an integrated, premium feel. 

---

## 3. Typography
We utilize a sophisticated typographic scale to provide an authoritative, instructional tone.

*   **Display (Large Titles):** `display-md` (Inter, 2.75rem). Used for primary screen entry points. 
*   **Headlines:** `headline-sm` (Inter, 1.5rem). Bold and commanding for section titles like "Today's Schedule."
*   **Drill Titles:** `title-md` (Inter, 1.125rem). Semi-bold for high legibility within cards.
*   **Body:** `body-md` (Inter, 0.875rem). Optimized for instructional text.
*   **Labels/Badges:** `label-sm` (Inter, 0.6875rem). All-caps for badges (Difficulty/PRO) to provide a "technical specification" aesthetic.

---

## 4. Elevation & Depth

### The Layering Principle
Avoid drop shadows for standard UI components. Instead, place a white card (`surface-container-lowest`) on the light grey background (`surface-container-low`). The contrast in light value provides a natural, clean lift.

### Ambient Shadows
For "Floating" actions (like the primary "Start Training" FAB), use a large-radius ambient shadow:
*   **Shadow:** `0px 12px 32px rgba(26, 107, 60, 0.08)`
*   Note the color tint: The shadow is not grey; it is a desaturated, low-opacity version of the brand green to simulate natural lighting.

### The "Ghost Border" Fallback
If a border is required for accessibility on unselected chips, use `outline-variant` (`#BFC9BE`) at **20% opacity**. It should appear as a mere suggestion of a boundary, not a hard line.

---

## 5. Components

### Drill Cards
The core of the experience.
*   **Background:** `#FFFFFF` (`surface-container-lowest`).
*   **Corner Radius:** `12pt` (`md` scale).
*   **Padding:** `16pt` all around.
*   **Interaction:** On press, the card should scale down slightly (0.98) rather than changing color.

### Pill-Shaped Filter Chips
*   **Selected:** Background `#1C1C1E`, Text `#FFFFFF`.
*   **Unselected:** Background `#FFFFFF`, Ghost Border (20% `outline-variant`), Text `on-surface-variant`.
*   **Shape:** Full pill radius (`9999px`).

### Difficulty & PRO Badges
*   **L0/L1:** `primary` green background at 10% opacity, `primary` green text.
*   **L2-L4:** Amber/Orange/Red at 10% opacity, solid hex text.
*   **PRO Badge:** Light Gold `#D4941A` at 12% opacity. Use a subtle `0.5pt` border in the same color to give it a "stamped" certificate look.

### Navigation & Tab Bar
*   **Large Title:** Standard iOS Native implementation, but with `primary` color for the back button and trailing icons to reinforce brand identity.
*   **Bottom Tab Bar:** 5-tab layout. Use a Glassmorphism background. Active icons use `#1A6B3C` with a small `4px` dot indicator underneath for tactical clarity.

---

## 6. Do's and Don'ts

### Do
*   **Do** use vertical white space to separate training blocks instead of horizontal lines.
*   **Do** use the `primary-container` (`#1A6B3C`) for primary CTAs like "Start Training" to evoke the feeling of the billiard table.
*   **Do** align "Large Title" navigation to the left while keeping difficulty badges right-aligned within cards to create a balanced, asymmetrical rhythm.

### Don't
*   **Don't** use standard black (`#000000`) for text. Use `on-surface` (`#1A1C1F`) for a softer, more professional editorial feel.
*   **Don't** use high-contrast borders. If a card isn't visible, increase the background contrast between the surface and the container instead of adding a stroke.
*   **Don't** use traditional "Material" ripples. Use elegant fades and scale transforms to maintain the high-end iOS aesthetic.