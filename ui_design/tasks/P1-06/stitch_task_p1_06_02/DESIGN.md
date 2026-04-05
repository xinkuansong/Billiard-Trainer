# Design System: The Precision Table

## 1. Overview & Creative North Star
**The Creative North Star: "The Tactical Architect"**

This design system moves beyond a standard tracker to become a high-end digital caddy. The aesthetic is inspired by the physical properties of a premium billiard room: the heavy weight of the slate, the tactile precision of the felt, and the focused light of the overhead lamp. 

We break the "generic iOS template" by embracing **Tonal Architecturalism**. Instead of using lines to define spaces, we use shifts in light and depth. The layout is intentionally rhythmic, using generous white space and high-contrast typography to create an editorial feel that treats a user’s practice session with the same reverence as a professional tournament.

---

## 2. Colors & Surface Philosophy
The palette is rooted in "Billiard Green" but evolved through Material Design logic to provide tonal depth that flat hex codes cannot achieve.

### The Palette (Core Tokens)
- **Primary (`#005129`)**: Use for heavy brand moments and key interactive states.
- **Primary Container (`#1A6B3C`)**: The "Felt" color. Use for hero surfaces and primary CTAs.
- **Secondary (`#805600`) / Secondary Container (`#FCB73F`)**: The "Amber" accent. Use sparingly for "Golden Moments" (Personal Bests, high streaks).
- **Surface Tiering**:
    - `surface_container_lowest` (#FFFFFF): Floating cards and active inputs.
    - `surface_container_low` (#F3F3F8): The primary content area background.
    - `surface_container_highest` (#E2E2E7): Elevated header backgrounds or inactive states.

### The "No-Line" Rule
**Explicit Instruction:** Prohibit 1px solid borders for sectioning. 
Visual separation must be achieved through background shifts. For example, a `surface_container_lowest` card should sit on a `surface_container_low` background. This creates a "soft edge" that feels integrated and premium rather than boxed-in.

### The "Glass & Gradient" Rule
To add "soul," use subtle linear gradients on Primary CTAs (transitioning from `primary` to `primary_container` at a 135° angle). For floating navigation or modals, apply **Glassmorphism**: use `surface` at 80% opacity with a `20px` backdrop blur to mimic the focused atmosphere of a dimly lit billiard hall.

---

## 3. Typography
We use the **SF Pro** family with an editorial hierarchy. The goal is to make data look like a sports magazine, not a spreadsheet.

*   **Display (Large/Medium)**: Used for "Big Numbers" (e.g., Win Rate %). Use `tight` letter spacing (-0.02em) to give it a heavy, authoritative feel.
*   **Headline (Small/Medium)**: Used for section titles. Pair with `primary` color to anchor the eye.
*   **Title (Large/Medium)**: For card headers.
*   **Body (Medium)**: For instructional text and metadata.
*   **Label (Small)**: Use for "Stat Captions" in uppercase with +0.05em tracking to ensure legibility at small sizes.

**Identity Hook:** Use `headline-lg` for session summaries but offset it slightly to the left of the grid to create a signature, asymmetrical "architectural" look.

---

## 4. Elevation & Depth
Depth in this system is a product of **Tonal Layering**, not structural scaffolding.

- **The Layering Principle:** Treat the UI as a series of stacked felt sheets. 
  - *Layer 0 (Base):* `surface_container_low`
  - *Layer 1 (Cards):* `surface_container_lowest`
  - *Layer 2 (Modals/Popovers):* `surface_container_lowest` with an Ambient Shadow.
- **Ambient Shadows:** Shadows must be felt, not seen. Use `on_surface` at 4% opacity with a `32px` blur and `8px` Y-offset. This mimics natural light falling across a table.
- **The "Ghost Border" Fallback:** If a divider is mandatory for accessibility, use `outline_variant` at 15% opacity. Never use a 100% opaque border.

---

## 5. Components

### Cards & Progress
- **The Precision Card**: Forbid divider lines. Use `surface_container_lowest` for the card body. Use vertical spacing (1.5rem) to separate internal groups.
- **Tactile Progress Bars**: Use `primary_fixed` as the track and `primary` as the fill. The corner radius must be `full` to mimic the smooth rail of a billiard table.

### Buttons & Interaction
- **Primary CTA**: Roundedness `md` (0.75rem). Use the signature gradient (Primary to Primary Container).
- **Segmented Control**: iOS-native style but use `surface_container_highest` for the background and `surface_container_lowest` for the active segment toggle.

### Data Visualization (Line Charts)
- **The "Trace" Line**: Use `primary` with a 3pt stroke. 
- **The Glow**: Apply a subtle drop shadow to the data line itself in the `primary` color (10% opacity) to make the "ball path" feel illuminated.
- **Grid Lines**: Use `outline_variant` at 10% opacity. If the data is clear, remove grid lines entirely to maintain the "No-Line" rule.

### Contextual Components
- **The "Cue Ball" Fab**: A floating action button for "New Session" using `primary`. It should be a perfect circle (`full` roundedness) with a high-diffusion shadow.
- **Shot Result Chips**: Use `secondary_container` for "Success" and `error_container` for "Miss." Text should be `on_secondary_container` and `on_error_container` respectively.

---

## 6. Do's and Don'ts

### Do
- **Do** use `display-lg` for the most important number on the screen (e.g., current streak).
- **Do** lean on SF Symbols using the "Multicolor" or "Hierarchical" rendering modes to match the `primary` green.
- **Do** provide at least `24px` (1.5rem) of padding between major surface containers.

### Don't
- **Don't** use black (`#000000`) for text. Always use `on_surface` to keep the tone sophisticated and soft.
- **Don't** use standard iOS dividers (`<hr>`). Use a 16px vertical gap instead.
- **Don't** use high-saturation reds for "Destructive" actions. Use the refined `tertiary` (#91000E) to maintain the premium color story.
- **Don't** crowd the "Table." If a screen feels busy, increase the background `surface_container_low` area to let the elements breathe.