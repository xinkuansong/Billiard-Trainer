# Design System Document: The Precision Play

## 1. Overview & Creative North Star
**The Creative North Star: "The Elite Academy"**
This design system moves beyond the "hobbyist" aesthetic of mobile games to establish a high-performance environment for serious athletes. We avoid the cluttered, neon-soaked tropes of billiards apps in favor of an **Editorial Precision** layout. By utilizing expansive whitespace, intentional asymmetry, and a rigorous tonal hierarchy, we create a digital training facility that feels as quiet and focused as a professional tournament hall. 

The system rejects the "template" look by ignoring traditional divider lines, instead using sophisticated tonal layering to guide the eye. It is an aesthetic of high-contrast professional sports—clean, authoritative, and clinical.

---

## 2. Colors
Our palette is rooted in the deep green of professional felt, supported by a clinical iOS-inspired neutral scale.

### Core Brand Tones
*   **Primary (`#1A6B3C`):** The "Felt Green." Used for high-impact brand moments and active states.
*   **Secondary (`#007AFF`):** The "Action Blue." Reserved exclusively for primary CTAs (e.g., "Add Session") to ensure immediate cognitive recognition.
*   **Tertiary/Accent (`#F5A623`):** "Warmup Orange." Used sparingly for status badges (In Progress, Warning) to provide a warm counterpoint to the cool greens and blues.

### Surface Hierarchy & Nesting (The "No-Line" Rule)
Sectioning must be achieved through background shifts, never 1px solid borders.
*   **Base Layer:** `background` (#F9F9FE) — The canvas.
*   **Container Low:** `surface_container_low` (#F3F3F8) — Secondary information clusters.
*   **Primary Card:** `surface_container_lowest` (#FFFFFF) — The highest importance data.
*   **Deep Layer:** `surface_container_high` (#E8E8ED) — Interactive wells or inset training zones.

**The "Glass" Exception:** While the user requests flat fills, floating elements (like a session timer) should utilize a semi-transparent `surface` with a 20pt backdrop blur to create a premium "frosted glass" look that keeps the user grounded in the training environment.

---

## 3. Typography
We use a high-contrast editorial scale to establish an authoritative hierarchy. The font family is **Inter** (or SF Pro for native iOS), focusing on tight tracking and robust weights.

*   **Display (3.5rem - 2.25rem):** Used for session scores or "Big Data" moments. Bold weight, tight letter spacing (-0.02em).
*   **Headline (2rem - 1.5rem):** Used for screen titles. These should be placed with generous top-padding to create an "Editorial Header" feel.
*   **Title (1.375rem - 1rem):** For card headers and section titles.
*   **Body (1rem - 0.75rem):** Standardized for all instructional text. Use `on_surface_variant` (#404940) for secondary descriptions to reduce visual noise.
*   **Label (0.75rem - 0.6875rem):** All-caps for status badges and technical data metadata (e.g., "SQUIRT ANGLE").

---

## 4. Elevation & Depth
In "The Elite Academy," depth is felt, not seen. We move away from heavy dropshadows toward **Tonal Layering**.

*   **The Layering Principle:** To separate a "Drill Card" from the background, place a `#FFFFFF` card (`surface-container-lowest`) on the `#F2F2F7` background. The 4% luminance shift is sufficient for the eye to perceive a "lift."
*   **Ambient Shadows:** For floating action buttons or modals, use a shadow with a 32pt blur and 6% opacity, tinted with the `primary` green to mimic the light reflection off a billiard table.
*   **The Ghost Border:** If a button requires more definition against a similar background, use the `outline_variant` (#BFC9BE) at **15% opacity**. This creates a "breathable" boundary that doesn't break the editorial flow.

---

## 5. Components

### Buttons
*   **Primary (`secondary` Blue):** Rounded-full (9999px) or `xl` (1.5rem) corner radius. Solid fill, white text. No gradient.
*   **Secondary (Ghost):** `outline_variant` at 20% opacity with `primary` green text.
*   **Tertiary (Text):** Bold `primary` green text with no container.

### Cards & Training Lists
*   **Radius:** 12pt (`md` to `lg` scale).
*   **Layout:** Forbid the use of divider lines. Separate drills or history items using `0.75rem` (12pt) of vertical whitespace.
*   **Training Chips:** Small `sm` radius (0.25rem) containers with `surface_container_highest` fills for "Drill Type" tags (e.g., "Bank Shot," "Safety").

### Input Fields
*   **Style:** 8pt (`sm`) corner radius. 
*   **Focus State:** A 2pt solid `primary` green border is the *only* time a high-contrast border is permitted, signifying active "Data Entry" mode.

### Specialized Billiards Components
*   **Table View Pro:** A high-contrast flat green container (`primary_container`) representing the table, utilizing `on_primary_container` for ball positions.
*   **Session Progress Bar:** A thick 8pt track using `surface_variant` with a solid `primary` green fill.

---

## 6. Do’s and Don’ts

### Do
*   **Do** use asymmetrical margins. For example, a screen title might have a 32pt left margin while the card content has a 16pt margin.
*   **Do** use SF Symbols with "Medium" or "Semibold" weights to match the authoritative typography.
*   **Do** prioritize vertical rhythm. Use the Spacing Scale (0.5rem, 1rem, 1.5rem) consistently to define groups.

### Don’t
*   **Don’t** use black (`#000000`). Use `on_surface` (#1A1C1F) for all "black" text to keep the UI from feeling harsh.
*   **Don’t** use 1px dividers between list items. Use tonal shifts in the background or simply whitespace.
*   **Don’t** use gradients. Professionalism in this system is conveyed through perfect color choice and spacing, not decorative fades.