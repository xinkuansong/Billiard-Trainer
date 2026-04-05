# QiuJi (球迹) Design System: The Tactical Precision Guide

## 1. Overview & Creative North Star
**Creative North Star: "The Elite Baize"**
The design system for QiuJi (球迹) is not merely a utility; it is a digital extension of the billiard table itself. We are moving away from the "standard app" aesthetic toward a **High-End Editorial** experience. By blending the organic depth of professional billiard felt with the precision of tactical sports analysis, we create an environment that feels both authoritative and breathable. 

We break the traditional iOS "list-template" look through intentional asymmetry. This is achieved by utilizing larger headline scales, varied card heights (12pt vs 16pt radii), and "The Layering Principle" to define hierarchy rather than using heavy lines. Every screen should feel like a curated tactical manual for a professional athlete.

---

## 2. Colors: Tonal Depth & Discipline
Our palette is rooted in the tradition of the game but executed with modern digital sophistication.

### Primary Palette
- **Primary (Billiard Green):** `#005129` (Core) / `#1A6B3C` (Container). This represents the table surface. Use for main actions and focus states.
- **Secondary (Amber/Gold):** `#805600` (Core) / `#D4941A` (Accent). This is our "Pro" indicator—used for premium features, achievements, and tactical highlights.
- **Surface (Background):** `#F9F9FE`. A clean, high-end paper white that provides maximum contrast for content.

### The "No-Line" Rule
**Explicit Instruction:** Designers are prohibited from using 1px solid borders for sectioning. Boundaries must be defined solely through:
1. **Background Color Shifts:** Use `surface_container_low` on top of a `surface` background.
2. **Tonal Transitions:** A card at `surface_container_lowest` (#FFFFFF) sitting on a `surface_container` (#EDEDF2) background creates a clear, sophisticated boundary without the visual "noise" of a line.

### Glass & Gradient Rule
To move beyond a flat feel, use semi-transparent surfaces (`rgba(255, 255, 255, 0.7)`) with a `backdrop-filter: blur(20px)` for floating navigation elements. For Primary CTAs, utilize a subtle linear gradient from `primary` (#005129) to `primary_container` (#1A6B3C) at a 135-degree angle to provide a "felt-like" tactile quality.

---

## 3. Typography: The Editorial Voice
We utilize the **SF Pro** family, leveraging its technical precision.

- **Display-LG (3.5rem):** Used for "Big Numbers"—score tracking or break speeds.
- **Headline-MD/SM (1.75rem - 1.5rem):** High-contrast headers for main sections. These should sit with more leading (line-height) than default to feel editorial.
- **Title-LG (1.375rem):** Used for Card headers. Always paired with `on_surface` (#1A1C1F).
- **Body-MD (0.875rem):** The workhorse. Use `text_secondary` (rgba(60,60,67,0.6)) for descriptions to ensure the hierarchy remains clear.

**Hierarchy Strategy:** Use the **Amber/Gold** (`secondary`) sparingly in typography—only for "Pro" labels or critical tactical insights—to keep its impact high.

---

## 4. Elevation & Depth: Tonal Layering
In this design system, depth is a matter of light and material, not "shadow-casting."

- **The Layering Principle:** 
    - **Base:** `surface` (#F9F9FE)
    - **Sectioning:** `surface_container_low` (#F3F3F8)
    - **Interactive Cards:** `surface_container_lowest` (#FFFFFF) with a 12pt or 16pt radius.
- **Ambient Shadows:** When a card must float (e.g., a "Start Session" button), use a shadow with a 24px blur, 4% opacity, and a slight green tint derived from the `primary` color. 
- **The "Ghost Border":** If accessibility requires a container edge, use the `outline_variant` token at **15% opacity**. This creates a whisper of an edge that disappears into the background, maintaining the "No-Line" philosophy.
- **Glassmorphism:** Use for the Bottom Tab Bar. It should feel like a precision tool resting on the table, allowing the content to flow beneath it.

---

## 5. Components: Tactile Precision

### Cards & Menu Items
- **Pro/Header Cards:** 16pt Corner Radius (`xl`). Used for promotional banners or session summaries.
- **Menu/Content Cards:** 12pt Corner Radius (`md`). 
- **Constraint:** Forbid divider lines within cards. Use **8pt or 12pt vertical white space** to separate list items.

### Buttons
- **Primary:** Gradient fill (Billiard Green), 16pt radius, `on_primary` (White) text.
- **Pro (Secondary):** Amber fill, used exclusively for high-value conversions.
- **Tertiary:** Ghost style—no background, just a `primary` or `secondary` text label.

### Chips & Badges
- **Tactical Chips:** Use `secondary_container` with `on_secondary_container` for "Pro" drills.
- **Status Chips:** Use `primary_fixed` for completed sessions—soft green background with deep green text.

### Inputs
- **Search/Fields:** Use `surface_container_highest` (#E2E2E7) as the fill. No border. Use a 12pt radius to match menu elements.

### Specialized Component: The Shot-Trace Banner
- Use the **Warning Banner** logic: `rgba(212,148,26,0.08)` background with a 1px "Ghost Border" of `secondary` color. This is for real-time coaching feedback during training.

---

## 6. Do's and Don'ts

### Do
- **Do** use SF Symbols with "Medium" or "Semibold" weights to match the editorial typography.
- **Do** allow for "Breathing Room." Increase margins to 20pt on the screen edges to emphasize the premium nature of the app.
- **Do** use intentional asymmetry—place a large Display-scale number next to a small Title-sm label for tactical metrics.

### Don't
- **Don't** use pure black (#000000) for backgrounds. Use the `surface` tokens to maintain the "paper and felt" feel.
- **Don't** use standard iOS 1px dividers. If you feel the need for a line, increase the background contrast between containers instead.
- **Don't** use high-intensity shadows. If the shadow is clearly visible as a "grey smudge," it is too heavy.