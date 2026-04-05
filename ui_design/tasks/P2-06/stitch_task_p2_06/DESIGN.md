# Design System Document: The Professional Edge

## 1. Overview & Creative North Star
**Creative North Star: The Midnight Masterclass**

This design system is engineered to evoke the focused, high-stakes atmosphere of a professional billiard hall after hours. We are moving away from the "app-as-a-utility" look and toward an "app-as-a-mentor" experience. By utilizing a deep obsidian foundation punctuated by "Baize Green" and "Championship Gold," the UI should feel like a premium physical tool.

To break the standard mobile template, we employ **Intentional Asymmetry**. Key information should not always be centered; use staggered typography scales and overlapping "glass" containers to create a sense of movement—mimicking the calculated paths of a billiard ball. The interface is not a flat screen; it is a layered environment of light and shadow.

---

## 2. Colors: Tonal Depth & The "No-Line" Rule
The palette is rooted in `background: #131313`. Our goal is to define space through light, not through strokes.

### The "No-Line" Rule
**Explicit Instruction:** Designers are prohibited from using 1px solid borders to section content. Traditional dividers are replaced by background color shifts. A `surface-container-low` card sitting on a `surface` background provides all the definition needed. 

### Surface Hierarchy & Nesting
We use Material 3 tonal tiers to create physical depth:
- **Surface (Background):** `#131313` — The base floor.
- **Surface-Container-Low:** `#1c1b1b` — For secondary content sections.
- **Surface-Container-High:** `#2a2a2a` — The standard card elevation.
- **Surface-Container-Highest:** `#353534` — For active states or modal elements.

### The Glass & Gradient Rule
To achieve a signature premium feel, use **Glassmorphism** for floating action buttons and navigation bars. Use `surface-variant` at 60% opacity with a `20px` backdrop blur. 
- **Signature Texture:** Primary CTAs should use a subtle linear gradient from `primary (#89d89e)` to `primary_container (#1a6b3c)` at a 135-degree angle to provide a satin-like finish.

---

## 3. Typography: Editorial Authority
We utilize the **SF Pro** family for its iOS-native reliability, paired with **Simplified Chinese** for a clean, professional aesthetic.

| Level | Token | Font / Size | Purpose |
| :--- | :--- | :--- | :--- |
| **Display** | `display-lg` | Manrope / 3.5rem | High-impact numbers (e.g., Win Rate %) |
| **Headline** | `headline-md` | Manrope / 1.75rem | Section titles (e.g., "Training Routine") |
| **Title** | `title-md` | SF Pro / 1.125rem | Card headers and primary navigation |
| **Body** | `body-md` | SF Pro / 0.875rem | Content and descriptions |
| **Label** | `label-sm` | SF Pro / 0.6875rem | Metadata, tags, and tertiary info |

**Editorial Contrast:** Combine `display-lg` (bold) with `body-sm` (secondary white 50%) to create a massive hierarchy gap. This makes the data the hero and the UI the supporting actor.

---

## 4. Elevation & Depth: Tonal Layering
Traditional shadows are too heavy for this dark theme. We use "Atmospheric Depth."

- **The Layering Principle:** Place a `surface-container-lowest (#0e0e0e)` card inside a `surface-container (#201f1f)` section to create a "recessed" look. This is ideal for input fields or inset training logs.
- **Ambient Shadows:** For floating elements like the "Start Training" button, use an extra-diffused shadow: `Y: 20, Blur: 40, Color: #000000 (15%)`.
- **The "Ghost Border" Fallback:** If a border is required for accessibility, use `outline-variant (#404940)` at **15% opacity**. It should be felt, not seen.

---

## 5. Components: Engineered Precision

### Buttons (The "Championship" Style)
- **Primary:** Gradient fill (`primary` to `primary_container`), `12pt` radius. Text: `on_primary`. 
- **Secondary (Paywall/Pro):** `secondary (#ffba44)` fill. Used exclusively for "Unlock Pro" actions.
- **Tertiary:** No fill. `12pt` radius with a `Ghost Border`.

### Cards & Lists
- **The Card:** `12pt` radius, `surface-container-high` background. 
- **Strict Rule:** Forbid divider lines. Separate list items using `12px` of vertical white space or a subtle shift to `surface-container-low` on every second item.
- **iOS Integration:** Use **SF Symbols** with `secondary` (Gold) tinting for icons to denote high-value actions.

### Training Progress Chips
- Use `primary_fixed_dim` for selected states and `surface_variant` for unselected.
- **Asymmetry:** In a list of training days, make the "Current Day" card 10% larger than the others to break the grid.

---

## 6. Do’s and Don’ts

### Do:
- **Use "Baize Green" (`#1A6B3C`) sparingly:** It is an accent for success and branding, not a background color.
- **Respect the 12pt Radius:** Maintain the iOS native aesthetic consistently across all cards and buttons.
- **Leverage Transparency:** Use 50% white for secondary text to ensure the background "breathes" through the typography.

### Don’t:
- **Never use Pure Black (#000000):** It kills the depth. Use the `surface` tokens.
- **No Harsh Borders:** If the UI looks like a "grid of boxes," increase the spacing and remove the strokes.
- **Avoid Over-Gilding:** The Gold/Amber (`#D4941A`) is for "Pro" features and achievements only. If used everywhere, it loses its premium value.

---

## 7. Token Summary
- **Primary:** `#89d89e`
- **Secondary (Gold):** `#ffba44`
- **Background:** `#131313`
- **Text (Primary):** `#FFFFFF` (100%)
- **Text (Secondary):** `#FFFFFF` (50%)
- **Radius:** `12pt / 0.75rem`