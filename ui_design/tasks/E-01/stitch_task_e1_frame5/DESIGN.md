```markdown
# Design System: The Precision Masterclass

## 1. Overview & Creative North Star

**Creative North Star: The Midnight Arena**
This design system is built for the "QiuJi" (球迹) experience—a digital sanctuary for the disciplined billiards practitioner. It moves away from the clutter of standard sports apps and toward a "High-End Editorial" aesthetic. We are not just building a tracker; we are building a masterclass. 

The visual identity is anchored in the concept of the **"Midnight Arena"**: a pure black environment where focus is directed solely by light, precision, and trajectory. We break the rigid, templated "iOS grid" through intentional asymmetry—using large-scale typography and overlapping surface elements to mimic the dynamic movement of balls across a felt table. The layout breathes through generous negative space, ensuring every statistic and training drill feels like a curated piece of knowledge.

---

## 2. Colors

The color palette is designed for deep-focus training sessions, specifically optimized for OLED displays to minimize eye strain while maximizing visual punch.

### The Palette
- **Background (OLED Pure Black):** `#131315` (mapped from `#000000`) serves as the canvas. 
- **Brand Primary (The Green):** `#25A25A` / `primary: #69dd8e`. This is our "spotlight" color, representing the felt of the table and the signal of success.
- **Brand Secondary (The Gold):** `#F0AD30` / `secondary: #ffba3d`. Reserved for "Pro" features and high-tier achievements.
- **Surface Hierarchy:** 
  - `surface-container-low`: `#1b1b1d`
  - `surface-container`: `#1f1f21`
  - `surface-container-high`: `#2a2a2c`

### The "No-Line" Rule
Standard iOS apps rely on separators. In this design system, **we prohibit 0.5pt/1pt solid lines for sectioning.** Boundaries must be defined through background color shifts. For example, a training module card (`surface-container-high`) should sit directly on the `background` without a border. The contrast between the pure black and the dark grey is sufficient and more sophisticated.

### The "Glass & Gradient" Rule
To add "soul" to the precision, we employ **Glassmorphism** for persistent elements like the bottom navigation and top header. 
- **CTA Soul:** Main buttons should not be flat. Use a subtle linear gradient from `primary` (#25A25A) to `primary_container` (#29a55d) to provide a 3D "pool ball" luster without using traditional shadows.

---

## 3. Typography

The typography scale is designed to feel like a high-end sports magazine. We use **Inter** (or SF Pro for native iOS parity) to convey technical authority.

- **Display-LG (3.5rem):** Used for big "Hero" numbers—accuracy percentages or high scores. It should feel monumental.
- **Headline-MD (1.75rem):** Used for module titles. Use intentional asymmetry by left-aligning these with significant padding-top to create an editorial feel.
- **Body-MD (0.875rem):** For instructional text. We prioritize `Text Secondary` (rgba 235, 235, 240, 0.6) for long-form reading to reduce contrast-induced eye fatigue.
- **Label-SM (0.6875rem):** All-caps with increased letter spacing for "Meta" information like "DRILL DURATION" or "DIFFICULTY."

---

## 4. Elevation & Depth: Tonal Layering

In a pure black environment, traditional shadows are invisible. We create depth through **Tonal Layering**—stacking containers of increasing lightness.

- **The Layering Principle:** 
  1. Base Layer: `surface-dim` (#131315)
  2. Sectional Layer: `surface-container-low` (#1b1b1d)
  3. Interactive Card: `surface-container-high` (#2a2a2c)
- **The "Ghost Border" Fallback:** If a layout requires a container to be placed on a similarly colored background, use a "Ghost Border"—the `outline_variant` token at **15% opacity**. This creates a suggestion of an edge rather than a hard boundary.
- **Ambient Glow:** Instead of shadows, high-priority elements (like a "Start Training" button) can use a subtle `primary` color outer glow (blur: 20px, opacity: 10%) to simulate light reflecting off the table felt.

---

## 5. Components

### Badges (Level Indicators)
Badges are the "Medals" of QiuJi. They must feel distinct and earned.
- **L0 (入门):** Solid `primary` fill. The "entry" point must feel bold and welcoming.
- **L1 (初学):** `primary_container` at 15% opacity with `primary` text. Subtle, like a student.
- **L2 (进阶):** `secondary_container` at 15% opacity with `secondary` (Gold) text. The first hint of prestige.
- **L3 (熟练):** `tertiary_container` at 15% opacity with `tertiary` (Orange) text. High-performance warmth.

### Buttons
- **Primary:** Rounded `xl` (1.5rem), gradient fill (Primary to Primary-Container), white text.
- **Secondary:** Transparent background with a `Ghost Border` (20% opacity white) and white text.
- **Tertiary:** Pure text with an `SF Symbol` trailing icon, using `primary` color.

### Cards & Lists
- **Cards:** Forbid divider lines within cards. Use `8px` or `12px` of vertical spacing between content blocks.
- **Training List:** Use a "trailing-edge spotlight"—a 2px vertical bar of `primary` color on the left edge of an active list item to indicate focus, rather than a full-box selection.

### Progress Trajectories
Instead of standard horizontal bars, use semi-circular arcs (mimicking the path of a cue ball) with a `secondary_fixed` gold stroke to track "Pro" progress.

---

## 6. Do's and Don'ts

### Do:
- **Do** use `0px` margin on certain hero images to allow them to bleed to the edge of the screen, breaking the "card" feel.
- **Do** use SF Symbols with "Thin" or "Light" weights to match the high-end editorial typography.
- **Do** leverage the pure black background to hide the notch/dynamic island, making the content feel like it's floating in space.

### Don't:
- **Don't** use `#000000` for cards. Use the `surface-container` tiers to ensure the user can perceive the "bounds" of interactive areas.
- **Don't** use standard iOS "Chevron" icons for every list item. Use whitespace and typographic weight to imply tapability.
- **Don't** use high-contrast white text for everything. Use `Text Secondary` for 80% of the UI to maintain a "premium/moody" atmosphere.

---
**Director's Note:** Precision in billiards is about the ghost ball—the invisible target. In this design system, the "ghost" is the structure. Let the content lead, and let the containers disappear into the dark.```