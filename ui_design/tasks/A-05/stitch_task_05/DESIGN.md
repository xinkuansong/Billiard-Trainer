# Design System Documentation: The Precision Atelier

## 1. Overview & Creative North Star
This design system is built upon the **"Precision Atelier"** concept. In the world of billiards, success is defined by the intersection of geometric calculation and quiet, focused prestige. We are moving away from the "app-as-a-tool" aesthetic toward "app-as-a-private-coach." 

The interface avoids traditional mobile clutter by rejecting standard navigation bars and heavy structural lines. Instead, we use **Tonal Architecture**—defining space through subtle shifts in surface color and intentional white space. The 8pt grid is our mechanical foundation, but the editorial layout is our soul.

---

## 2. Colors: Atmospheric Depth
The palette is rooted in the heritage of the sport. We use the brand green not just as a color, but as an authority, balanced by the amber gold of precision.

### Core Palette
- **Primary High-Contrast:** `#005129` (Primary) / `#1A6B3C` (Primary Container). Used for active states and brand moments.
- **Precision Accent:** `#D4941A` (Secondary). Reserved for achievement, high-level highlights, and "Focus" moments.
- **The Foundation:** `#F2F2F7` (Surface/Background). A clean, slightly cool neutral that provides the canvas for white cards.

### The "No-Line" Rule
**Prohibit 1px solid borders for sectioning.** Boundaries must be defined solely through background color shifts.
- To separate a section, transition from `surface` (`#F2F2F7`) to `surface-container-low` (`#F3F3F8`). 
- **Surface Hierarchy:** 
  - Level 0 (Page): `#F2F2F7`
  - Level 1 (Card/Container): `#FFFFFF` (Surface Container Lowest)
  - Level 2 (In-Card Elements): `#EDEDF2` (Surface Container)

### Signature Textures
While the fills are flat, we introduce depth through **Glassmorphism**. Floating action buttons or contextual overlays should use a semi-transparent `surface-container-lowest` (White at 80% opacity) with a 20px backdrop blur to maintain the premium "atelier" feel.

---

## 3. Typography: The Editorial Scale
We utilize **SF Pro** to maintain iOS familiarity, but we apply it with editorial intentionality.

- **Signature Section Header:** `22pt / Bold / Rounded` in `#1A6B3C`. This is the system's anchor. It must have at least 32pt of top margin to breathe.
- **Display (Metrics):** Use `headline-lg` (`2rem`) for high-level stats like "Win Rate" or "Accuracy." 
- **The Informant:** `body-md` (`0.875rem`) using `on_surface_variant` (`#404940`) for secondary descriptions.
- **Action Labels:** `label-md` (`0.75rem`) in All-Caps with +5% letter spacing for buttons to imply authority.

---

## 4. Elevation & Depth: Tonal Layering
We reject "drop shadows" in favor of **Ambient Lift**.

- **The Layering Principle:** Place a `#FFFFFF` card (`xl` radius 16pt) onto the `#F2F2F7` background. This 5% contrast shift is sufficient for the eye to perceive depth without visual noise.
- **Ambient Shadows:** Only for "Floating" elements (e.g., a cue-ball selector). Use a 15% opacity version of `#1A1C1F` with a 30pt blur and 10pt Y-offset.
- **The Ghost Border:** If a boundary is needed for accessibility in dark-on-dark scenarios, use `outline-variant` (`#BFC9BE`) at **10% opacity**. It should be felt, not seen.

---

## 5. Components

### Cards & Containers
- **Style:** White `#FFFFFF`, 16pt (`xl`) corner radius.
- **Spacing:** 16pt internal padding.
- **Rule:** Never use dividers between items inside a card. Use 12pt or 16pt of vertical space to separate content chunks.

### Buttons (The "Strike" Actions)
- **Primary:** Solid `#1A6B3C` fill, white text, 12pt radius. Height: 56pt for prominence.
- **Secondary (Ghost):** No fill. `1.5pt` ghost border using `primary` at 20% opacity. 
- **Accent (Gold):** Used only for "Level Up" or "Premium" features. Solid `#D4941A`.

### List Items (Drills & Logs)
- **Structure:** Leading icon or thumbnail (12pt radius), followed by Title (`title-sm`) and Subtitle (`body-sm`).
- **Interaction:** On press, the background should shift to `surface-container-high` (`#E8E8ED`). Do not use an arrow chevron unless the tap destination is ambiguous.

### Training Chips
- **Selection:** Solid `surface-container-highest` (`#E2E2E7`) with `on_surface` text. 
- **Selected State:** Solid `primary` (`#005129`) with white text. 
- **Shape:** Full rounded (Pill shape).

---

## 6. Do's and Don'ts

### Do
- **Do** use the 8pt grid religiously. All margins and paddings should be 8, 16, 24, 32, or 48.
- **Do** use "Negative Space" as a design element. If a screen feels crowded, remove a decorative element, don't shrink the text.
- **Do** align the "Center of Mass" of your cards to the vertical center of the screen to evoke the balance of a billiards table.

### Don't
- **Don't** use standard iOS blue for links. Use the Amber Gold or Brand Green.
- **Don't** use 1px dividers. If you feel the need for a line, increase the background color contrast instead.
- **Don't** use sharp corners. Billiards is a game of spheres; every container must have at least an 8pt radius, ideally 16pt.
- **Don't** add a Navigation Bar. Use the Signature Section Header (22pt Rounded Green) at the top of the scroll view to indicate the user's location.