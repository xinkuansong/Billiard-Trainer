# Design System Document

## 1. Overview & Creative North Star: "The Tactical Editorial"
This design system moves beyond the utility of a standard tracker to create a "Tactical Editorial" experience. It draws inspiration from high-end sports journals and professional billiard halls, where precision meets prestige. 

The system rejects the "boxed-in" feeling of generic apps. Instead, it utilizes intentional asymmetry, generous negative space, and a sophisticated layering of surfaces. By overlapping core elements—such as a hero billiard table view breaking the grid or floating action buttons—we create a sense of tactile depth. Our goal is to make the user feel like they are interacting with a premium physical kit, not just a digital interface.

---

## 2. Colors
Our palette is rooted in the heritage of the sport. We use deep, saturated greens to evoke the felt of a championship table, punctuated by amber-gold accents that signify professional-grade achievement.

### Color Tokens
- **Primary / Brand Green:** `#1A6B3C` (The core identity; used for primary actions and key thematic blocks).
- **Secondary / Pro Gold:** `#D4941A` (Reserved exclusively for premium features, Pro badges, and "locked" states).
- **Surface (Base):** `#F9F9FE` (A cool, crisp off-white that provides a breathable canvas).
- **Surface-Container-Low:** `#F3F3F8` (For secondary sections or card backgrounds).
- **Surface-Container-Highest:** `#E2E2E7` (For deepest nesting and active states).

### The "No-Line" Rule
To maintain an editorial feel, **1px solid borders are prohibited for sectioning.** Boundaries must be defined solely through background color shifts. For example, a card (using `surface_container_lowest`) sits on a background (`surface`) to define its edge. If a separator is needed, use vertical white space or a subtle change in tonal value, never a line.

### Surface Hierarchy & Nesting
Think of the UI as layers of fine paper. 
1.  **Level 0:** `surface` (The desk).
2.  **Level 1:** `surface_container_low` (The folder).
3.  **Level 2:** `surface_container_lowest` (The document).
Each inner container should use a slightly different tier to denote its importance without the clutter of lines.

### Signature Textures
Main CTAs or hero backgrounds should utilize a subtle linear gradient from `primary` (`#005129`) to `primary_container` (`#1A6B3C`) at a 135-degree angle. This provides a "soul" and professional polish that flat fills cannot achieve.

---

## 3. Typography
We utilize a pairing of **Manrope** for high-impact editorial moments and **Inter** (or SF Pro for native feel) for functional data.

- **Display & Headlines (Manrope):** These are the "voice" of the app. Bold, authoritative, and spacious. Used for drill titles and achievement milestones.
- **Titles & Body (Inter):** Clean, highly legible, and neutral. These handle the technical data—stroke counts, percentages, and instructional steps.

The contrast between the geometric Manrope and the functional Inter communicates a brand that is both an elite athlete and a precise scientist.

---

## 4. Elevation & Depth
Depth is achieved through **Tonal Layering** and **Ambient Light**, not structural shadows.

- **The Layering Principle:** Always stack from darkest/most recessed to lightest/most prominent. A progress bar should feel recessed into its container by being slightly darker than the card background.
- **Ambient Shadows:** For floating elements like circular action buttons, use a shadow with a blur radius of `24px` and an opacity of `6%`. The shadow color should be a tinted version of the surface color (e.g., a dark forest green tint) to mimic natural light.
- **Glassmorphism:** For the 'Progressive Lock' component, use a backdrop-blur of `20px` combined with a 40% opacity `surface_container_low`. This ensures the content feels integrated rather than just covered.

---

## 5. Components

### The Hero Billiard Table
- **Style:** Uses `#1B6B3A` felt texture. 
- **Interaction:** Floating elements (like the 'Favorite' heart) should use the **Ghost Border** fallback (10% opacity white) to define their shape against the dark green without being distracting.

### Circular Action Buttons
- **Tokens:** Background: `surface_container_high` (`#E8E8ED`). Icon: `on_surface_variant`.
- **Layout:** Use these for secondary navigation (Points, History, Charts) in a horizontal row with clear `label-md` text underneath.

### Buttons
- **Primary:** Pill-shaped, `primary` background with `on_primary` text. No shadow.
- **Pro/Unlock:** `outline` style using `secondary` (Gold) at 100% opacity for the border and text.

### Progressive Lock Component
- **Transition:** A gradient blur that transitions from clear to a `20px` Gaussian blur.
- **Overlay:** A gold lock icon centered, followed by a Pro-branded CTA button.

### Cards & Lists
- **Rule:** Forbid divider lines. Use `16px` of vertical white space to separate items within a card.
- **Radius:** All cards must maintain a `12pt` (0.75rem / `md`) corner radius to align with iOS native aesthetics.

---

## 6. Do's and Don'ts

### Do
- **Do** use `secondary_container` (Amber) for progress bars that indicate a "Pro" level of skill.
- **Do** lean into asymmetry. A hero image can be wider than the text container below it to create visual interest.
- **Do** use SF Symbols for all icons to maintain the iOS-native promise.

### Don't
- **Don't** use a black shadow. It kills the vibrancy of the green brand colors.
- **Don't** use high-contrast borders. If you can't see the edge, use a subtle tonal shift instead.
- **Don't** overcrowd the screen. If in doubt, add `8px` of extra padding.
- **Don't** use the Pro Gold (`#D4941A`) for non-essential items. It is a reward for the user's eyes; don't devalue it.