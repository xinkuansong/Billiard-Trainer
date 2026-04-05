# Design System Strategy: High-Performance Precision

## 1. Overview & Creative North Star: "The Digital Arena"
This design system is built to transform a billiards training app from a simple utility into a high-performance sanctuary. Our Creative North Star is **"The Digital Arena"**—an environment that mimics the focused, low-light atmosphere of a professional tournament hall. 

We move beyond the "template" look by rejecting traditional structural lines. Instead, we use **Tonal Architecture** to define space. By utilizing pure black backgrounds paired with deep, lush greens, we create a sense of infinite depth. Layouts should feel intentional and asymmetric, using typography scales to drive the eye toward performance data and instructional clarity, ensuring the user feels like a pro athlete in a private training session.

---

## 2. Colors: Tonal Depth over Borders
The palette is rooted in a "True Dark" philosophy. We use the contrast between the absolute void of the background and the tactical vibrancy of the billiard felt to create a focused experience.

### The Palette
- **Primary (Brand Green):** `#25A25A` (The "Felt" essence)
- **Surface (Background):** `#000000` (Pure Black for maximum OLED contrast)
- **Surface-Container (Card):** `#1C1C1E`
- **Surface-Container-High:** `#2C2C2E`
- **On-Surface (Primary Text):** `#FFFFFF`
- **On-Surface-Variant (Secondary):** `rgba(235, 235, 240, 0.6)`

### The "No-Line" Rule
Prohibit 1px solid borders for sectioning. Boundaries must be defined solely through background color shifts. A card (`#1C1C1E`) sitting on a page background (`#000000`) provides sufficient contrast. If further nesting is required, move to `#2C2C2E`. Never use a line where a shift in tone can achieve the same result.

### Signature Textures
For main CTAs and "Hero" moments, use a **Linear Gradient** transitioning from `Primary (#25A25A)` to `Primary-Container (#29A55D)`. This adds a "silk-like" finish reminiscent of premium high-speed cloth.

---

## 3. Typography: Editorial Authority
The typography system balances the approachable familiarity of iOS with the rigid precision of high-stakes sports timing.

- **Display & Headlines (Manrope):** Used for session titles and achievement milestones. The wide character stance of Manrope suggests stability and modernism.
- **Body (Inter/SF Pro):** Set at **1rem (17pt)** for optimal legibility during physical activity. The 1.5x line height ensures instructions are readable from a distance (e.g., when the phone is on the table rail).
- **The Performance Timer (Monospace):** 28pt Bold Monospace. This is a non-negotiable signature element. It communicates technical precision and ensures no character "jumping" as the clock ticks.
- **Labels (Space Grotesk):** 0.75rem. Used for technical data points (angle, velocity, cue-ball deflection).

---

## 4. Elevation & Depth: Tonal Layering
We do not use drop shadows. Elevation is conveyed through "Physical Stacking."

- **The Layering Principle:** 
    1. Base: `Surface (#000000)`
    2. Primary Content: `Surface-Container (#1C1C1E)`
    3. Interactive/Floating: `Surface-Container-High (#2C2C2E)`
- **Glassmorphism:** For floating overlays (like an active drill timer), use the `Surface-Variant` color at 70% opacity with a **20px Backdrop Blur**. This allows the green of the "Table Felt" to bleed through, keeping the user grounded in the training environment.
- **The "Ghost Border" Fallback:** In rare cases where a container bleeds into a similar tone, use the `Outline-Variant (#3E4A3F)` at **15% opacity**. This creates a "glint" of light on an edge rather than a hard boundary.

---

## 5. Components: Precision Primitives

### Buttons
- **Primary:** Full fill `Primary (#25A25A)` with `On-Primary (#00391A)` text. Radius: `12pt`.
- **Secondary:** Surface-Container-High fill with On-Surface-Variant text. No border.
- **Tertiary:** Ghost style. No fill, no border. Pure text in `Primary` color.

### Training Cards
Cards must use the **12pt radius**. Content within cards (like table thumbnails) must use the **8pt radius** to create a "nested" visual harmony. Forbid the use of dividers; use **24pt vertical spacing** to separate training modules.

### List Items
Leading elements (icons/thumbnails) should be separated from text by a **16pt horizontal gutter**. Trailing elements (arrows/status) should use `Text-Tertiary (30% opacity)` to remain subordinate to the primary data.

### Billiards-Specific: The Table Thumbnail
- **Felt:** `#144D2A` (Dark Green)
- **Rails:** `#5C2E00` (Dark Brown)
- **Radius:** 8pt.
- **Detail:** Use a 1px inner glow (`rgba(255,255,255,0.05)`) on the rail to simulate the table's edge under spotlights.

---

## 6. Do's and Don'ts

### Do:
- **Do** use pure black `#000000` for the main background to make the billiard green pop.
- **Do** lean into asymmetry. For example, a large 28pt timer left-aligned with a small 12pt label tucked underneath.
- **Do** use `16pt` horizontal padding as a strict margin for all screens.

### Don't:
- **Don't** use standard iOS blue for links. Only use `Primary Green` or `Target Ball Orange (#F5A623)` for highlights.
- **Don't** use 100% opaque separators. If you must use a divider, use `Separator (#38383A)` at 50% opacity.
- **Don't** add drop shadows. The depth must come from the color values alone.
- **Don't** use "Light Mode." This system is purpose-built for the high-focus, dark-room environment of billiards training.