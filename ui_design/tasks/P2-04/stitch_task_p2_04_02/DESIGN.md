# Design System Strategy: The Master's Table

## 1. Overview & Creative North Star: "The Tactile Professional"
The design system for this billiard training tracker is guided by the Creative North Star: **The Tactile Professional**. We are moving away from the "utility app" aesthetic and toward a "Digital Boutique" experience. 

Billiards is a game of extreme precision, geometry, and sensory feedback (the felt of the table, the polish of the balls, the quiet focus of the room). The UI must mirror this. We achieve this by using high-end editorial layouts that favor breathing room over density, and tonal depth over structural lines. This system feels like a high-performance instrument—authoritative, sleek, and intentional.

## 2. Color & Surface Architecture
We do not use borders to define space. We use **Tonal Layering**.

### The Palette
- **Primary (`#1A6B3C`):** The "Championship Green." Use this for high-impact moments and primary actions. It represents the felt of the table—the field of play.
- **Surface & Backgrounds:** Our foundation is `surface` (`#F9F9FE`). We transition into `surface-container-low` and `surface-container-high` to create organic zones of focus.
- **Tonal Secondary:** `secondary-container` (`rgba(26, 107, 60, 0.1)`) acts as our "soft" highlight for inactive states or background grouping.

### The "No-Line" Rule
**Explicit Instruction:** Prohibit the use of 1px solid borders for sectioning content. Boundaries must be defined solely through:
1.  **Background Color Shifts:** Placing a `surface-container-lowest` card on a `surface-container-low` background.
2.  **Signature Textures:** Use subtle gradients (e.g., `primary` to `primary-container`) on hero elements to provide a sense of curvature, mimicking the spherical nature of billiard balls.

### The "Glass & Gradient" Rule
To elevate the app above standard iOS clones, use **Glassmorphism** for floating headers or navigation bars. Apply a `backdrop-blur` with a semi-transparent `surface-container-lowest` color. This ensures the "green" of the training data bleeds through subtly, keeping the user grounded in the "arena."

## 3. Typography: Editorial Precision
The typography scale leverages **Plus Jakarta Sans** for high-impact displays and **Inter** for data-heavy training metrics, creating a sophisticated hierarchy.

*   **Display & Headline (Plus Jakarta Sans):** Used for "Big Moments"—score tallies, session summaries, and the app title '球迹'. This adds a modern, geometric flair that feels custom.
*   **Title & Body (Inter):** Used for instructional text and training logs. It provides the neutral, legible clarity required for professional tracking.
*   **The Signature Header:** The app name '球迹' uses **SF Pro Rounded (34pt Bold)** to soften the technical nature of the app, making it feel approachable.

| Level | Token | Font | Size | Weight |
| :--- | :--- | :--- | :--- | :--- |
| Brand | `display-lg` | SF Pro Rounded | 3.5rem | Bold |
| Hero | `headline-lg` | Plus Jakarta Sans | 2rem | Bold |
| Section | `title-lg` | Inter | 1.375rem | Medium |
| Primary Data | `body-lg` | Inter | 1rem | Regular |
| Metadata | `label-md` | Inter | 0.75rem | Medium |

## 4. Elevation & Depth: Tonal Layering
We reject the "flat" look. Instead, we use **The Layering Principle**.

*   **The Stack:** 
    *   Base: `surface`
    *   Section Area: `surface-container-low`
    *   Interactive Card: `surface-container-lowest` (pure white)
*   **Ambient Shadows:** For floating elements like the 80pt circular logo, use an ambient shadow: `Offset: 0, 10; Blur: 30; Opacity: 6%; Color: on-surface`. This creates a "lift" that feels like a ball hovering slightly off the felt.
*   **The Ghost Border:** If a boundary is strictly required for accessibility, use `outline-variant` at **15% opacity**. Never use a high-contrast black or grey line.

## 5. Components: The Training Toolkit

### Buttons (The "Power Shot")
*   **Primary Button:** Height: 50pt | Radius: 12pt (`md`).
    *   *Style:* `primary` fill with `on-primary` text. Use a very subtle top-down gradient to give the button a "pressed-felt" texture.
*   **Secondary/Action Chips:** Use `secondary-container` with `on-secondary-container` text. These should have a `full` (9999px) radius to mimic the shape of billiard balls.

### Feature Rows & Lists
*   **The Icon Circle:** 48pt circles using `primary-container`. Icons inside should be `on-primary-container`.
*   **Anti-Divider Rule:** Forbid the use of horizontal divider lines in lists. Instead, use a **16px (1rem)** vertical gap between list items or a subtle background shift between grouped items.

### Interactive Elements
*   **Input Fields:** Use `surface-container-highest` as a subtle recessed background. No borders. On focus, transition the background to `surface-container-lowest` with a soft `primary` ghost-border.
*   **Training Progress Cards:** Use a "Glass" effect. Semi-transparent `surface` with a heavy blur, allowing the `primary` brand color to peak through from underneath.

### Relevant Custom Components
*   **The "Cue-Ball" Tracker:** A custom circular slider (80pt) that mimics a cue ball, allowing users to mark where they hit the ball during a session.
*   **Heatmap Layers:** Semi-transparent green overlays on `surface-variant` containers to show table coverage.

## 6. Do's and Don'ts

### Do
*   **Do** use extreme whitespace. Billiards is about the "space between the balls." Give your data room to breathe.
*   **Do** use asymmetrical layouts for onboarding—place the 80pt logo off-center to create a sense of dynamic movement.
*   **Do** prioritize "Natural Light" shadows over artificial "Drop" shadows.

### Don't
*   **Don't** use 100% black (`#000000`) for anything other than primary headlines. Use `on-surface-variant` for body text to reduce eye strain.
*   **Don't** use sharp corners. Everything must adhere to the `md` (12pt) or `full` roundedness scale to maintain the "billiard ball" softness.
*   **Don't** use standard iOS dividers. They clutter the editorial feel of the training logs.