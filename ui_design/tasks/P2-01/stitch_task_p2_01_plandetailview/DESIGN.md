# Design System Strategy: The Master’s Table

## 1. Overview & Creative North Star
The creative north star for this design system is **"The Digital Clubhouse."** 

We are moving away from the "utility tracker" aesthetic and toward a premium, editorial experience that feels like a private billiards lounge. This system rejects the cluttered, line-heavy interfaces of standard fitness apps. Instead, it utilizes **intentional negative space, tonal layering, and high-contrast accents** to create an environment of focus and prestige. The interface should feel as tactile and balanced as a custom-weighted cue, using "Quiet Luxury" as a guiding principle to elevate the user's training journey.

---

## 2. Colors & Surface Philosophy
Our palette is rooted in the heritage of the game—deep felt greens and polished amber resins—reimagined through a modern, high-fidelity iOS lens.

### Color Tokens
- **Primary (The Table):** `#005129` (Core Brand Green) / `#1A6B3C` (Container).
- **Secondary (The Trophy):** `#805600` (Core Gold) / `#D4941A` (Accent).
- **Surface Tiers:** 
  - `surface_container_lowest`: `#FFFFFF` (Card highlight)
  - `surface`: `#f9f9fe` (App canvas)
  - `surface_container_low`: `#f3f3f8` (Subtle sectioning)
- **Status & Utility:** `tertiary` (`#004392`) for system actions; `error` (`#ba1a1a`) for critical alerts.

### The "No-Line" Rule
To maintain a high-end editorial feel, **1px solid borders are strictly prohibited for sectioning.** Structural boundaries must be defined solely through:
1. **Background Shifts:** Placing a `surface_container_lowest` card on a `surface` background.
2. **Tonal Transitions:** Using `surface_container_low` to define a header region against the main canvas.

### The "Glass & Gradient" Rule
Floating elements (such as navigation bars and locked content overlays) must utilize **Glassmorphism**. Apply a `backdrop-blur` of 20px–30px to semi-transparent surface colors. For primary CTAs, use a subtle linear gradient from `primary` to `primary_container` (top-to-bottom) to give buttons a "polished resin" depth that flat colors cannot achieve.

---

## 3. Typography: Editorial Authority
Typography is our primary tool for hierarchy. We use SF Pro not just for legibility, but as a structural element.

- **Display & Headline (The Statement):** Use `headline-lg` (22pt Bold Rounded) for screen titles. The rounded terminals mirror the geometry of the billiard ball, softening the "pro" intensity with a premium feel.
- **Title (The Navigation):** `title-md` (17pt Semibold) for navigation bars.
- **Body (The Data):** `body-md` (15pt Regular) for primary content.
- **Secondary Text:** Use `on_surface_variant` at 60% opacity for metadata. This creates a natural hierarchy without introducing new colors.

*Director’s Note: Always favor generous line-height (1.4x+) to ensure the "Editorial" breathing room required for a premium experience.*

---

## 4. Elevation & Depth
In this system, depth is biological, not artificial. We mimic the way light hits a pool table.

- **The Layering Principle:** Stack surfaces to create focus. An athlete’s "Practice Session" card (`surface_container_lowest`) should sit atop a `surface_container_low` activity feed. This creates a "soft lift."
- **Ambient Shadows:** Standard drop shadows are banned. Use only **Ambient Shadows**: 20px–40px blur, 4% opacity, tinted with the `primary` green or `on_surface` color. It should feel like a glow, not a shadow.
- **The "Ghost Border" Fallback:** If a container requires definition against an identical background, use the `outline_variant` token at **10% opacity**. It should be felt, not seen.
- **Locked Content:** Use a progressive blur (0px to 15px) over content, overlaid with a `Light amber fill` (rgba(212,148,26,0.12)). The icon should be a `secondary_fixed` gold lock.

---

## 5. Components

### Buttons & Interaction
- **Primary Action:** Rounded (Pill) shape, `primary` gradient fill, white text. No border.
- **Secondary Action:** Gold outline (`secondary`) using the "Ghost Border" logic—2pt stroke, but at 40% opacity for a sophisticated "Pro" look.
- **Badges/Pills:** Use `Light amber fill` with `secondary` (Gold) text for "Pro" stats.

### Cards & Lists
- **The Card:** Radius of `16pt` (xl) for main containers; `12pt` (md) for nested elements. 
- **The List Rule:** **Forbid divider lines.** Separate list items using 12px of vertical white space or by alternating between `surface` and `surface_container_low`.

### Data Visualization (Billiard Specific)
- **Progress Tracking:** Use a thick (6px) rounded track. The "Fill" should be `primary`, and the "Track" should be `primary_fixed_dim` at 20% opacity.
- **Shot Accuracy Heatmaps:** Use soft-edged radial gradients instead of hard-edged grids to represent ball positioning.

---

## 6. Do’s and Don’ts

### Do:
- **Do** use `plusJakartaSans` for large numerical data (e.g., win percentages) to provide a custom, high-end feel.
- **Do** allow content to bleed to the edges of the screen in "Hero" sections, using the `background` color to "pull" the content back in.
- **Do** use SF Symbols with a "Semibold" weight to match the `title-md` typography.

### Don’t:
- **Don’t** use pure black (#000000) for text. Use `on_surface` (#1a1c1f) to maintain visual softness.
- **Don’t** use standard iOS blue for primary billiards actions; keep `System Blue` strictly for native system links or standard "Share" sheets.
- **Don’t** crowd the interface. If a screen feels "full," increase the `surface_container` padding rather than shrinking the text.