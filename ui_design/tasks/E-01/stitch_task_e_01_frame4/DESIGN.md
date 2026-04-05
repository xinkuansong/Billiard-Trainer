# Design System: The Precision Vault

## 1. Overview & Creative North Star
The creative direction for this design system is **"The Precision Vault."** 

Billiards is a game of absolute geometry, calculated focus, and the hushed atmosphere of a high-end hall. We are moving away from the "generic fitness tracker" aesthetic toward a high-contrast, editorial dashboard that feels like a professional toolkit. By leveraging the **Pure Black OLED (#000000)** background, we treat the screen as a dark void where data becomes the hero. 

The design breaks the "template" look through **intentional negative space** and **tonal layering**. We avoid the clutter of traditional borders, allowing the user's focus to rest entirely on their training performance metrics.

---

## 2. Colors
Our palette is rooted in high-contrast functionality, optimized for low-light environments.

| Role | Token | Value | Hex |
| :--- | :--- | :--- | :--- |
| **Primary/Brand** | `primary` | Solid Brand Green | `#25A25A` |
| **Accent** | `secondary` | Precision Amber | `#F0AD30` |
| **Page Background** | `surface` | Pure Black OLED | `#000000` |
| **Main Container** | `surface-container` | Card Background | `#1C1C1E` |
| **Nested Surface** | `surface-container-high` | Tertiary Background | `#2C2C2E` |
| **Unfilled/Inactive** | `outline-variant` | Quaternary | `#3A3A3C` |
| **Text Primary** | `on-surface` | Pure White | `#FFFFFF` |
| **Text Secondary** | `on-surface-variant` | 60% White | `rgba(235, 235, 240, 0.6)` |
| **Text Tertiary** | `outline` | 30% White | `rgba(235, 235, 240, 0.3)` |

### The "No-Line" Rule
To achieve a premium editorial feel, **1px solid borders are prohibited for sectioning.** Structural boundaries must be defined solely through background shifts. For example, a card (`#1C1C1E`) sits directly on the page background (`#000000`) to create a natural edge. 

### Surface Hierarchy & Nesting
Use depth to guide the eye. 
*   **Level 0:** Page Background (`#000000`).
*   **Level 1:** Primary Cards (`#1C1C1E`).
*   **Level 2:** Elements inside cards, such as progress bar tracks or nested tags (`#2C2C2E` or `#3A3A3C`).

### Signature Textures
While the aesthetic is flat, main CTAs can utilize a subtle "Inner Glow" logic—not via gradients, but by placing high-contrast `on-primary` text against the solid `primary` green to create a vibrating, energetic focal point.

---

## 3. Typography
We utilize **SF Pro** to maintain iOS native familiarity, but we apply an editorial hierarchy to make the data feel authoritative.

*   **Display (Large Stats):** Use `display-md` (2.75rem) for primary metrics (e.g., "72%"). This should be `Text Primary`.
*   **Headlines:** Use `headline-sm` (1.5rem) for section titles like "Training Details."
*   **Labels:** Use `label-md` (0.75rem) with 5% letter-spacing for category headers. This adds a technical, "instrument-panel" feel.
*   **Body:** Use `body-md` (0.875rem) for secondary descriptions and list items.

The contrast between the oversized display numbers and the refined, small-scale labels creates a sophisticated visual tension that defines the "QiuJi" brand.

---

## 4. Elevation & Depth
In a flat, dark-mode system, depth is achieved through **Tonal Layering** rather than shadows.

*   **The Layering Principle:** Depth is "stacked." To highlight a specific training set within a card, change the nested background to `surface-container-high` (#2C2C2E).
*   **Ambient Glow (The Exception):** We do not use drop shadows. However, for floating elements like a "Start Training" FAB, you may use a **Ghost Border**—a 1px stroke using the `primary` green at 20% opacity. This suggests a neon-like lift without breaking the flat mandate.
*   **Glassmorphism:** Navigation bars and Tab bars should use a `backdrop-blur` (20px) over a semi-transparent version of `#1C1C1E`. This allows the "Precision Green" of the content to bleed through as the user scrolls, creating a sense of environmental depth.

---

## 5. Components

### Cards & Data Grids
*   **Radius:** 12pt.
*   **Padding:** 16pt.
*   **Layout:** Use the 2x2 grid for top-level stats as seen in the reference.
*   **No Dividers:** Lists within cards (like the "Set 1, Set 2" rows) must not use line separators. Instead, use 12pt vertical spacing to separate rows.

### Buttons
*   **Primary:** Solid `#25A25A` with `#FFFFFF` text. 12pt radius.
*   **Secondary:** Ghost style. 1pt border using `#38383A` with `#FFFFFF` text.
*   **States:** On press, the background should shift 10% lighter. No shadows.

### Progress Bars
*   **Track:** `#3A3A3C`.
*   **Indicator:** `#25A25A`.
*   **Visual Style:** Square ends for a more technical, "pro-tool" appearance, despite the card's 12pt radius.

### Training Status Chips
*   **Success:** A small SF Symbol (checkmark.circle.fill) in `#25A25A`.
*   **Warning/Alert:** Text or icons in `#F0AD30`.

---

## 6. Do's and Don'ts

### Do:
*   **Embrace the OLED Black:** Allow large areas of `#000000` to remain untouched to maximize visual pop.
*   **Use SF Symbols:** Use "Thin" or "Light" weights to match the sophisticated typography.
*   **Align to 8pt Grid:** Ensure all spacing (16pt, 24pt, 32pt) is strictly mathematical to reinforce the "Precision" theme.

### Don't:
*   **No Drop Shadows:** Shadows look "muddy" on pure black. Use background color shifts instead.
*   **No Heavy Borders:** Never use `#FFFFFF` for borders. It creates "visual vibration" that fatigues the eye. Use the `separator` token (`#38383A`) only when tonal shifts aren't possible.
*   **Avoid Pure White Body Text:** Reserve `#FFFFFF` for titles and data. Use the 60% white (`Text Secondary`) for descriptions to improve long-term readability and reduce glare.