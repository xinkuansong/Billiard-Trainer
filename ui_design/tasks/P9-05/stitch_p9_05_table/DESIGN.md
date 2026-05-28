# Design System Document

## 1. Overview & Creative North Star: "The Tactical Green"
This design system is engineered to elevate the billiard training experience from a casual hobby to a disciplined craft. Our Creative North Star is **The Tactical Green**—an aesthetic that blends the heritage of the billiard hall with the precision of a professional athlete's performance dashboard.

We move beyond the "standard iOS app" by treating the interface as a digital extension of the billiard table itself. By utilizing high-contrast editorial typography against a "Billiard Green" palette and employing **Tonal Layering** instead of rigid dividers, we create a layout that feels as fluid and focused as a perfect break. The experience must feel premium, quiet, and authoritative.

---

## 2. Color Palette & The Layering Philosophy

### Color Tokens
Our palette is rooted in the deep, concentrated green of high-grade baize, supported by a sophisticated range of neutrals to maintain a light, airy mobile environment.

| Role | Token | Hex | Usage |
| :--- | :--- | :--- | :--- |
| **Primary** | `primary` | `#005129` | Active states, branding, and core focus elements. |
| **Primary Container** | `primary_container` | `#1A6B3C` | The signature "Billiard Green." Used for heavy UI elements. |
| **Surface** | `surface` | `#F9F9FE` | The canvas for our content. |
| **Background** | `background` | `#F2F2F7` | Standard iOS light mode background. |
| **Surface Container**| `surface_container` | `#EDEDF2` | Subtle nesting for grouped data. |
| **Pill Background** | `accent_alpha` | `rgba(26,60,107,0.12)`| Soft highlights for badges and secondary indicators. |

### The "No-Line" Rule
To maintain a high-end editorial feel, **do not use 1px solid borders to section off content.** Structure must be defined through background color shifts. For example, a card (`surface_container_lowest`) should sit on the page background (`background`) to create a boundary through value contrast alone.

### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers. 
- **Base Level:** `background` (#F2F2F7).
- **Content Level:** Cards using `surface_container_lowest` (#FFFFFF) with a 12pt corner radius.
- **Data Level:** Nested tables or secondary information using `surface_container_low` (#F3F3F8) to create "wells" of information within a card.

---

## 3. Typography: Precision Print
We utilize the **SF Pro** family to maintain iOS familiarity, but we apply it with editorial intent. The contrast between large, heavy headlines and compact, technical data labels creates a "pro-tool" atmosphere.

*   **Display/Headline:** Use `headline-lg` (2rem) for session summaries or "Big Wins." These should feel bold and commanding.
*   **Title:** Use `title-md` (1.125rem) for card headers to provide a clear entry point for the eye.
*   **Data Labels:** Use `label-sm` (0.6875rem) with increased tracking (letter-spacing) for technical stats (e.g., "SQUIRT ANGLE" or "CUE SPEED"). This mimics the look of technical blueprints.

---

## 4. Elevation & Depth

### The Layering Principle
Depth is achieved through **Tonal Layering**. Avoid drop shadows for standard cards. Instead, rely on the 12pt rounded `surface_container_lowest` container against the `#F2F2F7` background. This creates a soft, natural lift that doesn't clutter the visual space.

### Ambient Shadows & Glassmorphism
*   **Floating Elements:** For primary action buttons or floating "Add Shot" buttons, use an ambient shadow: `shadow-color: rgba(26, 107, 60, 0.08)`, `blur: 20pt`, `y-offset: 8pt`.
*   **Navigation:** The top navigation bar and the `BTSegmentedTab` should utilize a **Backdrop Blur (20pt)** with a semi-transparent white background to allow the green hues of the content to bleed through slightly as the user scrolls.

---

## 5. Components

### Cards & Lists
*   **Geometry:** 12pt corner radius (`md`), 16pt internal padding.
*   **Constraint:** Forbid the use of divider lines. Use 8pt or 12pt vertical white space to separate list items within a card.
*   **Data Tables:** 19-row compact style. Use `primary_fixed` (#A5F4B8) at 20% opacity as a row highlight for "Success Shots" to provide a rhythmic, green-tinted scan-path.

### Buttons & Inputs
*   **Primary Button:** `primary_container` (#1A6B3C) background with `on_primary` (#FFFFFF) text. High-gloss, high-precision.
*   **Pill/Badge:** `rgba(26,107,60,0.12)` background with `primary_container` text. Used for shot types (e.g., "Bank Shot").
*   **Tabs (BTSegmentedTab):** Standard iOS width, featuring a 2pt thick `primary_container` underline for the active state. This line acts as a "laser-sight" for navigation.

### The "Contact Point" Dot
A signature UI element. When representing ball contact or aim points, use a 6pt circular dot in `primary_container` (#1A6B3C). If used on a dark green background, use `primary_fixed` (#A5F4B8) for maximum visibility.

---

## 6. Do's and Don'ts

### Do:
*   **Use Intentional Asymmetry:** When displaying shot statistics, align primary numbers to the left and technical labels to the right to create a sophisticated, non-template look.
*   **Embrace Breathing Room:** Use the `xl` (1.5rem) spacing scale between unrelated content cards to prevent the UI from feeling "cramped."
*   **Use SF Symbols:** Use the 'weight' variants of SF Symbols (Semibold) to match the `title-sm` typography for iconography.

### Don't:
*   **No Black Borders:** Never use #000000 for borders or text. Use `on_surface_variant` (#404940) for a softer, more premium feel.
*   **No Sharp Corners:** Every interactive element must respect the 12pt (`md`) or 16pt (`lg`) corner radius scale.
*   **No Flat Grids:** Avoid perfectly symmetrical 2x2 grids. Try 60/40 splits in cards to emphasize the most important training metric.

### Accessibility Note:
Ensure all text placed on the `primary_container` (#1A6B3C) is `#FFFFFF` or `#A5F4B8` to maintain a high contrast ratio for legibility in various lighting conditions (like dimly lit billiard halls).