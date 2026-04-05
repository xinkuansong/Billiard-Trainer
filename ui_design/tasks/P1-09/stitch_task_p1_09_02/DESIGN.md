# Design System: Editorial Precision for the Modern Athlete

## 1. Overview & Creative North Star
The design system for '球迹' (QiuJi) is guided by the Creative North Star: **"The Precision Playmaker."** 

Rather than a generic utility for tracking, the interface is treated like a high-end, editorial sports journal. It balances the tactical rigidity of billiard physics with the organic flow of human performance. We break the standard iOS "list-view" monotony through intentional white space, rhythmic typography, and a "Tonal First" layering logic. The experience must feel as deliberate and polished as a professional cue ball strike—clean, balanced, and perfectly weighted.

---

## 2. Colors: The Baize & The Light
The palette is rooted in the heritage of the sport. The Brand Green represents the focus of the table, while the supporting neutrals provide a breathable, gallery-like environment.

### Color Roles
- **Primary (`#1A6B3C`):** The signature Billiard Green. Reserved for "Win States," success rates, and primary actionable points.
- **Secondary (`#F5A623`):** Amber. Used exclusively for temporal data—duration and time-on-table—to provide a high-contrast visual distinction from performance metrics.
- **Surface & Background:** Utilizing `surface` (#f9f9fe) and `background` (#f2f2f7) to create environmental depth.

### The "No-Line" Rule
**Borders are prohibited for sectioning.** To define a new content area, use a background shift (e.g., a `surface-container-low` card nested on a `surface` background). The eye should recognize boundaries through tonal contrast, not structural strokes.

### The "Glass & Gradient" Rule
Floating navigation bars and specialized modal headers must utilize **Glassmorphism**. Apply a semi-transparent `surface` color with a 20px backdrop blur. This ensures the UI feels like a physical layer hovering over the "table" of data. Use subtle linear gradients on Primary CTAs (Primary to Primary-Container) to avoid a "flat plastic" appearance.

---

## 3. Typography: Editorial Authority
We utilize **SF Pro** as our structural backbone, but apply it with an editorial hierarchy that prioritizes rapid data scanning.

- **Display & Large Titles:** SF Pro Rounded (34pt Bold). Use these for high-level summaries and session titles. The rounded terminals mirror the geometry of the billiard ball.
- **Headlines:** `headline-lg` (SF Pro, 2rem). Used to introduce major data sections.
- **Body:** `body-lg` (Inter/SF Pro, 1rem). Optimized for legibility during active training.
- **Labels:** `label-sm` (0.6875rem). Use these for secondary chart metadata, ensuring they never compete with the primary data points.

**Hierarchy Note:** Use a tight tracking (-2%) on Large Titles to give them a "compact" and authoritative feel, while increasing leading in body text to maintain breathability.

---

## 4. Elevation & Depth: Tonal Layering
Depth in this system is a product of light and material, not drop shadows.

- **The Layering Principle:** 
    1. Base: `background` (#f2f2f7)
    2. Section: `surface-container-low`
    3. Component Card: `surface-container-lowest` (#ffffff)
- **Ambient Shadows:** For elements that require true "lift" (like the Floating Action Button), use a highly diffused shadow: `0px 12px 24px rgba(26, 107, 60, 0.06)`. Notice the tint—we use a trace amount of the Brand Green in the shadow to simulate natural light reflecting off the table.
- **The "Ghost Border":** If a boundary is required for accessibility on high-key screens, use `outline-variant` at 15% opacity. It should be felt, not seen.

---

## 5. Components: Precision Primitives

### Cards & Containers
- **Corner Radius:** Fixed at 16pt (Scale: `DEFAULT`).
- **Styling:** White background (`surface-container-lowest`). No borders. Separation is achieved through 24pt vertical spacing.
- **Interaction:** On tap, cards should subtly scale to 98% to simulate physical depression.

### Buttons
- **Primary:** Pill-shaped, `primary` background with `on-primary` text.
- **Segmented Tabs:** Use the "Underline Indicator" (2pt) in `primary` to denote the active state. The background of the inactive tabs should remain transparent to keep the layout light.

### Charts & Status
- **Success Rates:** Expressed in `primary` (#1A6B3C).
- **Duration/Time:** Expressed in `secondary` (#F5A623).
- **Status Indicators:** 
    - **Positive:** Green (`primary`).
    - **Negative:** Red (`error` #C62828).
    - **Flat:** Gray (`outline`).

### Input Fields
- **Styling:** Minimalist. No bounding box. Use a 1pt `outline-variant` line only at the bottom of the field, which transforms into a 2pt `primary` line on focus.

---

## 6. Do's and Don'ts

### Do
- **Do** use SF Symbols for all iconography to ensure native iOS consistency.
- **Do** leverage asymmetric layouts for training summaries; let data "bleed" to the edges to create a sense of scale.
- **Do** use `surface-bright` for highlights within charts to guide the user's eye to peak performance points.

### Don't
- **Don't** use 100% black text. Use `on-surface` (#1a1c1f) to maintain a premium, softened contrast.
- **Don't** use standard iOS dividers. If content needs to be separated within a card, use an 8pt or 16pt gap.
- **Don't** crowd the interface. If a training session has 10+ metrics, use a horizontal paging system (Carousel) rather than a long vertical list.