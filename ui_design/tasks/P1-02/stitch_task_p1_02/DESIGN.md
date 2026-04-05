# Design System Document: Tactical Elegance

## 1. Overview & Creative North Star

### The Creative North Star: "The Master’s Stroke"
This design system is built for the focused practitioner. It eschews the clutter of traditional sports apps in favor of an **Editorial Precision** aesthetic. It treats the billiards table not just as a game, but as a discipline of geometry and focus.

By leveraging intentional asymmetry, high-contrast typography, and a "No-Line" philosophy, we create an environment that feels as quiet and high-stakes as a professional billiards hall. We break the "standard app" mold by using a sophisticated layering system where depth is communicated through tonal shifts rather than harsh borders, allowing the content to breathe within a premium, expansive space.

---

## 2. Colors & Surface Architecture

The palette is anchored by the deep, authoritative **Primary Green (#1A6B3C)**, reminiscent of tournament-grade felt. 

### The Color Tokens
*   **Primary:** `#005129` (The deep soul of the brand)
*   **Primary Container:** `#1A6B3C` (Used for key brand moments and active states)
*   **Background:** `#F2F2F7` (The iOS-standard base for familiarity)
*   **Surface:** `#FFFFFF` (The pure canvas for content cards)
*   **Surface-Container Tiers:** 
    *   *Lowest:* `#FFFFFF`
    *   *Low:* `#F3F3F8`
    *   *High:* `#E8E8ED`
    *   *Highest:* `#E2E2E7`

### The "No-Line" Rule
**Designers are strictly prohibited from using 1px solid borders for sectioning.** Hierarchy must be defined through background color shifts. A card (`surface-container-lowest`) should sit on the background (`surface-container-low`) to create distinction. This creates a "soft-edge" layout that feels modern and editorial.

### Surface Hierarchy & Nesting
Treat the UI as physical layers of fine paper. 
- **Tier 0 (Background):** `#F2F2F7`
- **Tier 1 (Section Blocks):** Subtle shifts to `#FFFFFF` for main content areas.
- **Tier 2 (Floating Elements):** Use the `surface_container_highest` token with a **Backdrop Blur (20px-30px)** for elements like the Tab Bar or floating headers to create a "Frosted Glass" effect.

### Signature Textures
While the brand green is solid, main CTAs can utilize a "Tonal Depth" approach. Instead of a gradient, use a **10% opacity white overlay** on the top half of a button to provide a subtle, tactile "pill" feel without breaking the solid-color brand mandate.

---

## 3. Typography: The Editorial Scale

We use **SF Pro** as a tribute to the precision of the iOS ecosystem, but we apply it with an editorial eye for scale.

*   **Display-Lg (34pt Bold):** Used exclusively for page titles to establish a strong, authoritative starting point.
*   **Headline-Sm (1.5rem):** For section headers (e.g., "Accuracy Drills").
*   **Title-Sm (17pt):** The standard body text. It must be high-contrast (`on_surface`) to ensure maximum legibility against the white cards.
*   **Label-Sm (10pt):** For tab labels and metadata.

**Intentional Asymmetry:** Align Large Titles to the far left with a 16pt margin, but allow secondary metadata to float with generous right-hand whitespace to create a "negative space" luxury feel.

---

## 4. Elevation & Depth

We achieve depth through **Tonal Layering** rather than structural shadows.

*   **The Layering Principle:** A card should feel "pressed" into the surface or "resting" on it. Place a `surface_container_lowest` (#FFFFFF) card on a `surface_container_low` (#F3F3F8) background for a natural, soft lift.
*   **Ambient Shadows:** If a card requires a floating state (e.g., a modal or an active drill state), use a shadow with a **30px Blur** and **4% Opacity**. The shadow color should be a tinted green-grey (`#1A1C1F` at 4%) to mimic natural light.
*   **The "Ghost Border" Fallback:** If a border is required for accessibility, use the `outline_variant` token at **15% opacity**. Never use 100% opaque borders.
*   **Glassmorphism:** The Tab Bar must use a `surface` color at 80% opacity with a heavy background blur. This integrates the navigation into the content, making the UI feel like one cohesive piece of glass.

---

## 5. Components

### Buttons
*   **Primary:** Solid `#1A6B3C`, white text, 12pt corner radius. No border.
*   **Secondary:** `#F2F2F7` fill, `#1C1C1E` text, 12pt radius.
*   **State:** On press, apply a 10% black overlay to simulate physical depression.

### Chips (Pill-Shaped)
*   **Selected:** `#1C1C1E` (Dark Mode impact) with `#FFFFFF` text.
*   **Unselected:** `#FFFFFF` fill with a "Ghost Border" of `#D1D1D6`.
*   **Radius:** 999pt (Full Pill).

### Cards & Lists
*   **The Divider Forbid:** Do not use line dividers between list items. Use **24pt vertical spacing** or subtle tonal shifts in the background of the card to denote the start of a new item.
*   **Drill Cards:** These should feature a 12pt corner radius with a `surface_container_lowest` fill.

### Training-Specific Components
*   **Progress Orbs:** For training stats, use the Primary Green in a circular stroke (2px) to visualize completion.
*   **The "Cue" Indicator:** A signature vertical line element (Primary Green) used to highlight the active category in the sidebar or menu, mimicking the straight lines of a cue stick.

---

## 6. Do’s and Don’ts

### Do:
*   **Do** use extreme whitespace. If a screen feels "empty," it’s likely on the right track for this high-end aesthetic.
*   **Do** use SF Symbols with a "Medium" or "Semibold" weight to match the weight of the typography.
*   **Do** rely on the 16pt horizontal margin as a sacred boundary for content.

### Don’t:
*   **Don’t** use 1px dividers to separate items in a list. It creates visual "noise" that contradicts the premium feel.
*   **Don’t** use gradients in any Primary Green elements. Keep the brand green pure and solid.
*   **Don’t** use sharp corners. Every interactive element should feel approachable with either a 12pt or 999pt radius.
*   **Don’t** use high-contrast shadows. If you can clearly see the shadow, it is too dark. It should be felt, not seen.