# Design System Strategy: QiuJi (球迹)

## 1. Overview & Creative North Star

### Creative North Star: "The Tactile Masterclass"
This design system moves beyond the utility of a sports tracker to embody the focused, quiet, and precise atmosphere of a high-end billiard lounge. The aesthetic is defined by **Editorial Precision**—where every element feels intentionally placed on a canvas, rather than snapped to a generic grid.

We break the "template" look through:
*   **Asymmetric Breathing Room:** Large titles and headers are given generous top padding to allow the eye to rest before engaging with data.
*   **Layered Materiality:** We treat the UI as a series of stacked, physical surfaces. We use tonal shifts and glassmorphism to create depth, mimicking the way light hits a felt table.
*   **High-Contrast Sophistication:** By pairing the deep `primary` (#005129) with expansive `surface` areas (#f9f9fe), we create an authoritative, premium feel that mirrors the focus required for a championship shot.

---

## 2. Colors

### Palette Strategy
The color system is rooted in "Billiard Green" but expanded into a sophisticated range of functional tones.

*   **Primary Tier:** 
    *   `primary` (#005129): Used for high-emphasis actions and key brand moments.
    *   `primary_container` (#1A6B3C): The iconic brand green, reserved for feature cards and primary headers.
*   **Tertiary Accents:** 
    *   `tertiary` (#5c4100) & `tertiary_fixed` (#ffdea6): A warm, "Cue Wood" gold used sparingly for "Pro" features or achievement badges, providing a high-contrast complement to the green.

### The "No-Line" Rule
**Explicit Instruction:** 1px solid borders are strictly prohibited for sectioning or containment. Boundaries must be defined through background color shifts. To separate content:
1.  Place a `surface_container_lowest` card on a `surface` background.
2.  Nest a `surface_container` element inside a `surface_container_low` section.
3.  Use vertical white space from the spacing scale to denote transition.

### Glass & Gradient Rule
To provide visual "soul," use subtle linear gradients (e.g., `primary` to `primary_container`) on large CTAs. For floating elements like the 5-tab navigation bar, utilize a **Glassmorphism** effect: 
*   **Color:** `surface_container_lowest` at 85% opacity.
*   **Effect:** 20px Backdrop Blur. 
This ensures the UI feels like a cohesive, integrated environment rather than a series of flat blocks.

---

## 3. Typography

The typography scale utilizes **SF Pro Rounded** for high-impact editorial moments and **Inter** (or SF Pro Text) for functional data to ensure maximum legibility.

*   **Display (Large Titles):** `display-sm` (2.25rem) or `headline-lg` (2rem). Use SF Pro Rounded with tight tracking (-2%) to create a bold, modern "Sport-Editorial" look.
*   **Body Content:** `body-lg` (1rem) for general reading. Use `on_surface_variant` (#404940) for secondary metadata to reduce visual noise.
*   **Labels:** `label-md` (0.75rem) in all-caps with +5% letter spacing for category tags (e.g., "ADVANCED", "DRILL") to provide a professional, instructional feel.

---

## 4. Elevation & Depth

### The Layering Principle
Depth is achieved through **Tonal Layering** rather than structural lines.
1.  **Level 0 (Background):** `surface` (#f9f9fe).
2.  **Level 1 (Sub-sections):** `surface_container_low` (#f3f3f8).
3.  **Level 2 (Interactive Cards):** `surface_container_lowest` (#ffffff).

### Ambient Shadows
When a card requires a "floating" effect (e.g., a featured training module), use an ambient shadow:
*   **Shadow Color:** `on_surface` (#1a1c1f) at 6% opacity.
*   **Blur:** 24pt.
*   **Spread:** -4pt.
This mimics natural light and avoids the "muddy" look of standard grey shadows.

### The "Ghost Border" Fallback
If a boundary is required for accessibility (e.g., an input field), use a **Ghost Border**: `outline_variant` (#bfc9be) at **15% opacity**. Never use 100% opaque outlines.

---

## 5. Components

### Cards & Lists
*   **Feature Cards:** 16pt corner radius (`xl`). Use `surface_container_lowest` backgrounds. 
*   **List Rows:** 12pt corner radius (`md`). 
*   **Interaction:** Forbid divider lines. Use an 8pt vertical gap between list items. Leading icons should use a `primary` tint background (`rgba(26,107,60,0.12)`) to anchor the eye.

### Buttons
*   **Primary CTA:** `primary` (#005129) background with `on_primary` (#ffffff) text. 12pt corner radius.
*   **Secondary/Ghost:** `surface_container_high` background. No border.
*   **"Go" Buttons:** Use `primary_container` (#1A6B3C) for high-energy training starts.

### Tab Bar (5-Tab)
*   **Visual Style:** Floating pill or edge-to-edge with a 20px backdrop blur. 
*   **Active State:** Use `primary` for the icon and a small 4pt "cue ball" dot indicator below the icon.

### Chips & Tags
*   **Selection Chips:** 9999px radius (`full`). 
*   **Unselected:** `surface_container` background with `on_surface_variant` text.
*   **Selected:** `primary` background with `on_primary` text.

---

## 6. Do's and Don'ts

### Do
*   **DO** use SF Symbols with "Medium" or "Semibold" weight to match the weight of SF Pro Rounded titles.
*   **DO** use a "tinted white" approach. Every "white" area should have a nearly imperceptible hint of the brand green to maintain warmth.
*   **DO** embrace "Negative Space." If a screen feels crowded, increase the vertical margin between sections rather than shrinking the text.

### Don't
*   **DON'T** use pure black (#000000). Use `on_surface` (#1a1c1f) for text to maintain a premium, softer contrast.
*   **DON'T** use 1px dividers between list items. Use the change in surface color or 8pt of clear space.
*   **DON'T** use standard iOS blue for links or buttons. Every interactive element must stem from the `primary` or `tertiary` palettes.