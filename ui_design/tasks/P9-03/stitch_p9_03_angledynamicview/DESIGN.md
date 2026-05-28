# Design System: Editorial Precision in Billiards

## 1. Overview & Creative North Star: "The Tactical Architect"
The Creative North Star for this system is **The Tactical Architect**. Most sports apps feel like noisy news feeds; this system feels like a high-end architectural blueprint overlaid on a premium physical space. 

We are moving away from the "generic list app" look. By leveraging the **SF Pro** typeface and **iOS Native** logic, we create a bridge between the physical weight of a billiard table and the ethereal precision of digital data. The design breaks the grid through **intentional layering**: photorealistic billiard table assets act as the "ground," while vector annotations and UI cards float as "glass instrumentation." We emphasize a "Pro-Tool" aesthetic—clean, authoritative, and unapologetically data-driven.

---

## 2. Colors: The Baize & The Blueprint
Our palette is rooted in the high-contrast environment of a professional billiard hall, refined through a modern digital lens.

*   **Primary (`#1B6C3D`):** Our "Billiard Green." Use this for focus states and primary actions. It should feel deep and lush, never neon.
*   **Surface Hierarchy (The "No-Line" Rule):** 
    *   **Prohibit 1px solid borders.** To separate a card from the background, do not use a stroke. Instead, place a `surface_container_lowest` (#FFFFFF) card onto a `surface_container_low` (#F3F3F8) background.
    *   **Nesting:** Use `surface_container_high` (#E8E8ED) for inner elements like search bars within a white card. This "tonal stepping" creates depth without visual clutter.
*   **The Glass & Gradient Rule:** For overlaying data on table images, use **Glassmorphism**. Apply `surface_container_lowest` at 80% opacity with a `20px` backdrop blur. 
*   **Signature Textures:** Use a subtle linear gradient from `primary` (#005129) to `primary_container` (#1A6B3C) on high-value CTAs (like "Start Training") to give them a satin, "felt-like" premium finish.

---

## 3. Typography: Authoritative Editorial
We use **SF Pro** (Inter as the web-equivalent token) to maintain an iOS-native feel while pushing the scale for an editorial look.

*   **Display & Headline (The Statement):** Use `display-md` or `headline-lg` for session titles or "Win Rate" percentages. These should feel like headers in a premium sports magazine.
*   **Title (The Label):** `title-md` is the workhorse for card headers. It provides a clear, bold entry point for the eye.
*   **Body & Labels (The Data):** `body-md` and `label-md` are for technical specs (angles, velocity, spin). 
*   **The Hierarchy Goal:** By pairing a large `display-md` metric with a tiny, all-caps `label-sm` subtitle, we create a "Technical Blueprint" aesthetic that feels professional and intentional.

---

## 4. Elevation & Depth: Tonal Layering
Traditional shadows are too heavy for a "clean" app. We use light and tone to define space.

*   **The Layering Principle:** Place `surface_container_lowest` (#FFFFFF) cards on the `background` (#F9F9FE). This 12pt corner radius `md` scale creates a soft "lift."
*   **Ambient Shadows:** If an element must float (e.g., a "Next Step" FAB), use an extra-diffused shadow: `Y: 8, Blur: 24, Color: rgba(26, 28, 31, 0.06)`. It should feel like air, not a drop-shadow.
*   **The Ghost Border:** If a button is placed on a white background, use an `outline_variant` (#BFC9BE) at **15% opacity**. This "Ghost Border" provides just enough definition for accessibility without breaking the "No-Line" rule.
*   **Vector Overlays:** Aiming lines (`#4A90D9`) and Contact points (`#E53935`) should have a subtle outer glow when placed over dark table images to ensure they "pop" as digital overlays.

---

## 5. Components: Precision Instrumentation

### Cards & Lists
*   **No Dividers:** Never use a horizontal line to separate players or drills. Use 16px of vertical whitespace or a subtle background shift to `surface_container_low`.
*   **Corner Radius:** Standardize on `md` (12pt/0.75rem) for all main containers to match the iOS rounded aesthetic.

### Buttons
*   **Primary:** Gradient fill (`primary` to `primary_container`), white text, `full` (pill) radius.
*   **Secondary:** `surface_container_high` background with `on_surface` text. No border.
*   **Tertiary/Ghost:** `on_surface` text with no background. Use for "Cancel" or "Skip."

### Billiard-Specific Components
*   **The "Shot Map" Overlay:** A photorealistic table view using `surface_dim` for the cloth texture. Use `Aiming line` (#4A90D9) with a dashed stroke and `Ghost ball` (rgba(255,215,0,0.3)) for future positioning.
*   **The Power Slider:** A custom slider using a gradient from `primary_fixed` to `primary`. The thumb should be a `surface_container_lowest` circle with a subtle ambient shadow.
*   **Data Chips:** Use `secondary_container` (#6FB2FD) at 20% opacity for tactical chips (e.g., "High Difficulty," "Corner Pocket") to keep the focus on the data.

---

## 6. Do’s and Don'ts

### Do
*   **Do** use SF Symbols for all iconography to maintain iOS native familiarity.
*   **Do** overlap vector lines over photorealistic ball images to reinforce the "Digital Coach" metaphor.
*   **Do** leave generous breathing room (16px–24px) between the card edge and the content.
*   **Do** use `tertiary` (#603F00) tones for "History" or "Legacy" data to provide a warmth contrast to the cool green.

### Don’t
*   **Don’t** use black (#000000) for text. Use `on_surface` (#1A1C1F) to maintain a premium, softened contrast.
*   **Don’t** use high-contrast borders or dividers. Let the background tones do the work.
*   **Don’t** crowd the Shot Map. If a diagram is complex, use "Ghosting" (lower opacity) for non-essential balls.
*   **Don’t** use standard iOS "Blue" for links. Use the `secondary` (#0061A5) or `primary` (#005129) to keep the brand cohesive.