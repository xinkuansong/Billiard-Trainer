# Design System Strategy: The Professional Green

## 1. Overview & Creative North Star

### The "Precision Editorial"
This design system is built for the focused athlete. It moves beyond the clutter of typical sports apps to embrace a "Precision Editorial" aesthetic. Our North Star is the billiard table itself: a vast, clean surface where every element has a purpose, and every movement is calculated. 

We break the "standard app" feel through **Intentional Asymmetry** and **Tonal Depth**. By utilizing high-contrast typography scales and overlapping elements (like floating indicators that break the container bounds), we create a digital experience that feels as tactile and premium as a custom-weighted cue.

---

## 2. Colors

The palette is rooted in the heritage of the sport—Deep Billiard Green and Gold—but executed with a modern, Material-inspired logic for functional clarity.

### Primary & Secondary (Brand Soul)
- **Primary (`#005129` / `#1A6B3C`):** Represents the baize. Use `primary` for main actions and `primary_container` for prominent card headers or success states.
- **Secondary (`#805600` / `#D4941A`):** The "Gold Standard." Reserved exclusively for PRO features and high-achievement milestones.

### The "No-Line" Rule
**Explicit Instruction:** Designers are prohibited from using 1px solid borders to section content. Boundaries must be defined solely through background color shifts. Use `surface_container_low` sections against a `surface` background to create a logical break. Visual separation is achieved through white space, not strokes.

### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers. 
- **Base Layer:** `surface` (`#F9F9FE`).
- **Nesting:** Place a `surface_container_lowest` (#FFFFFF) card on top of a `surface_container_low` section to create a soft, natural lift.

### The "Glass & Gradient" Rule
To add "soul," use subtle linear gradients on primary CTAs (e.g., `primary` to `primary_container`). For floating elements like the `BTFloatingIndicator`, apply a **Glassmorphism** effect using a semi-transparent `primary` color with a `backdrop-blur(12px)` to ensure it feels integrated into the environment.

---

## 3. Typography

We utilize **Inter** (as a high-performance alternative to SF Pro for cross-platform consistency) to deliver an authoritative, sports-focused tone.

- **Display Scale (`display-lg` to `display-sm`):** Used for big numbers—timers, scores, and shot counts. These should feel monumental.
- **Headline Scale:** Reserved for "Editorial" section headers (e.g., "Accuracy Training").
- **Body Scale:** Use `body-lg` for primary instructions. Its generous x-height ensures readability in low-light pool halls.
- **Label Scale:** Use `label-md` for metadata (e.g., "3 Sets Recommended").

The contrast between a `display-lg` timer and a `label-sm` caption creates a visual hierarchy that guides the eye instantly to the most critical data point.

---

## 4. Elevation & Depth

### The Layering Principle
Depth is achieved by "stacking" surface tiers. A `surface_container_lowest` card provides the cleanest "white card" look. To emphasize importance, do not add a border; instead, increase the tonal contrast of the background behind it.

### Ambient Shadows
For floating elements (like the action pill), use the **"Lifted" Shadow**: 
- **Value:** `0 2pt 8pt rgba(0,0,0,0.15)`
- **Philosophy:** Shadows must be extra-diffused. The shadow color should technically be a tinted version of `on_surface` to mimic natural ambient light.

### The "Ghost Border" Fallback
If a container lacks sufficient contrast (e.g., a white card on a light grey background for accessibility), use a **Ghost Border**: `outline_variant` at **15% opacity**. Never use a 100% opaque stroke.

---

## 5. Components

### Buttons & Indicators
- **Primary Pill:** `999pt` radius. Background: `primary`. Text: `on_primary`. High-contrast, bold, and unmistakable.
- **Secondary/Ghost Pill:** `999pt` radius. Background: `surface_container_highest` or transparent with a Ghost Border.
- **Floating Indicators:** As seen in `BTFloatingIndicator`, these should feature a `44pt` height and a `999pt` radius, floating `16pt` from the screen edge with a Lifted Shadow.

### Cards & Lists
- **The "No-Divider" Rule:** Forbid the use of horizontal lines between list items. Separate items using `12pt` vertical spacing or subtle alternating backgrounds (`surface_container_low` vs `surface_container_lowest`).
- **Card Radius:** Strictly `12pt` for content cards to maintain the "Modern iOS" feel.

### Specialized Components
- **PRO Badges:** Small, `secondary_container` background with `on_secondary_container` text. High-contrast Gold to signify premium value.
- **Level Chips:** Use `tertiary_container` (Subtle Green) for difficulty levels (L0, L1, L2). This keeps the UI "Sports-Focused" without overwhelming the user with the Primary Brand Green.

---

## 6. Do's and Don'ts

### Do
- **DO** use SF Symbols for all iconography to maintain a native iOS feel.
- **DO** use "Breathing Room." If an element feels cramped, double the padding. 
- **DO** lean into the asymmetry of editorial layouts—align titles to the left but keep tactical data (like PRO badges) anchored to the right.

### Don't
- **DON'T** use pure black `#000000` for long-form text; use `on_surface` (#1A1C1F) to reduce eye strain.
- **DON'T** ever use a standard "Drop Shadow" preset. Always manually adjust the blur and opacity to meet the "Ambient Shadow" requirement.
- **DON'T** use cards inside cards. Use tonal shifts to indicate nesting instead.