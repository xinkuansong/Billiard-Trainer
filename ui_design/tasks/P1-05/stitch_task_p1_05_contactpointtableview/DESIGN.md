# Design System Document

## 1. Overview & Creative North Star: "The Tactical Sanctuary"

This design system is built to transform a technical training app into an immersive, premium environment. The Creative North Star, **"The Tactical Sanctuary,"** balances the quiet intensity of a billiard hall with the precision of a masterclass. 

We move beyond the "standard iOS" look by embracing **intentional negative space** and **tonal depth**. Rather than using lines to divide information, we use light and volume. The interface should feel like a physical extension of a high-end billiard table—tactile, focused, and impeccably organized. We reject generic grid-based layouts in favor of an editorial hierarchy that prioritizes data as art.

---

## 2. Colors

The color palette is anchored in `#1A6B3C`, a deep, sophisticated green that evokes the felt of a championship table.

### Primary & Brand
- **Primary (`#005129`):** The core brand color, used for high-emphasis actions and key branding.
- **Primary Container (`#1A6B3C`):** The "Billiard Green." Use this for hero states, active progress bars, and significant UI markers.
- **Surface Tint (`#1B6C3D`):** Applied to interactive elements to provide a cohesive green-tinted ecosystem.

### Tonal Neutrals & The "No-Line" Rule
To achieve a premium, editorial feel, **1px solid borders are strictly prohibited** for sectioning. Boundaries must be created through background shifts:
- **Background (`#F7F9FC`):** The canvas.
- **Surface Container Lowest (`#FFFFFF`):** Reserved for primary cards and floating elements.
- **Surface Container Low (`#F2F4F7`):** Used to define background regions or "wells" for secondary information.

### The Glass & Gradient Rule
- **Signature Textures:** For primary CTA buttons or key data visualizations, use a subtle linear gradient from `primary` to `primary_container`. This adds a "weighted" feel that flat colors lacks.
- **Glassmorphism:** Navigation bars and floating headers should use a semi-transparent `surface` color with a `backdrop-blur` (20px-30px). This ensures the "Tactical Sanctuary" feels deep and layered rather than flat.

---

## 3. Typography

The system utilizes **SF Pro** (Inter as a web fallback) in a high-contrast editorial scale. Typography is the primary driver of the app's professional, educational authority.

- **Display (3.5rem - 2.25rem):** Large, bold, and authoritative. Used for performance milestones or category headers (e.g., "Angle Training").
- **Headline (2rem - 1.5rem):** Used for primary section titles. Maintain generous tracking for a modern feel.
- **Title (1.375rem - 1rem):** Semi-bold. Used within cards to identify specific training modules.
- **Body (1rem - 0.75rem):** Clean and highly legible. Used for instructional text and educational content.
- **Label (0.75rem - 0.6875rem):** All-caps or high-letter-spacing variants for secondary metadata.

---

## 4. Elevation & Depth

Hierarchy is achieved through **Tonal Layering** rather than structural lines.

- **The Layering Principle:** Stack `surface_container_lowest` cards on top of a `surface_container_low` background. This creates a natural, soft lift. 
- **Ambient Shadows:** When a card requires a floating effect, use an extra-diffused shadow.
    - **Shadow Token:** `0px 10px 30px rgba(25, 28, 30, 0.06)`. 
    - The shadow is tinted with the `on_surface` color to mimic natural light hitting a matte surface.
- **The "Ghost Border":** If a container requires further definition (e.g., on a white background), use the `outline_variant` token at **15% opacity**. Never use a 100% opaque border.
- **Frosted Integration:** Use `backdrop-blur` on overlays to allow the `primary_container` green to bleed through, creating a "frosted glass on green felt" aesthetic.

---

## 5. Components

### Cards & Lists
- **Cards:** White (`surface_container_lowest`), 16pt corner radius (`xl`). 
- **The Divider Ban:** Do not use line dividers between list items. Use **vertical white space** (16px or 24px) or a 1-step shift in the surface-container tier to separate content blocks.

### Buttons
- **Primary:** Gradient fill (`primary` to `primary_container`), white text, 12pt radius (`lg`).
- **Secondary:** Surface-container-high fill with `primary` text. No border.
- **Tertiary:** Text-only with an SF Symbol, using `primary` color.

### Sliders (iOS Style)
- **Track:** `surface_container_highest` with a 4px height.
- **Thumb:** Pure white with an ambient shadow.
- **Fill:** `primary_container` to indicate progress.

### Specialized Training Components
- **Angle Input:** A large, centered display using `headline_lg` typography. Enclosed in a "Ghost Border" container with an 8px radius.
- **Data Tables:** High-contrast text on a `surface_container_low` background. Use `label_md` for headers and `title_sm` for data points to emphasize the educational aspect.
- **Progress Steppers:** Use a thick (4px) bar in `primary_container` against a `surface_container_high` track, anchored to the top of the view to maintain the "Tactical" feel.

---

## 6. Do’s and Don’ts

### Do
- **DO** use SF Symbols with a "Medium" or "Semibold" weight to match the typography.
- **DO** lean into asymmetry. For example, left-align headlines while right-aligning data metrics to create a dynamic, professional layout.
- **DO** use the `primary_fixed_dim` color for subtle icons that don't need to shout.

### Don't
- **DON'T** use pure black `#000000`. Use `on_surface` (`#191C1E`) for all text to keep the interface soft.
- **DON'T** use "Standard" 1px gray dividers. They break the sanctuary feel and make the app look like a generic utility.
- **DON'T** overcrowd cards. If a card has more than three lines of text, increase the `xl` corner radius or add more padding.