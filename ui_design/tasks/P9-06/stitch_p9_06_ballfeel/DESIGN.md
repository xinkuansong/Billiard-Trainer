# Design System Strategy: The Master’s Table

## 1. Overview & Creative North Star
This design system is built upon the North Star of **"Tactile Precision."** Unlike standard utility apps, this system treats the interface as an elite training ground—mimicking the focus, quiet confidence, and physical depth of a professional billiard hall. 

We move beyond the "flat app" aesthetic by utilizing **Tonal Architecture**. By rejecting rigid lines and 1px borders, we create a layout that feels carved rather than constructed. The experience is educational and professional, using intentional asymmetry in data visualization to guide the student’s eye through shot trajectories and physics-based training modules.

---

## 2. Colors: The Palette of the Felt
The palette is rooted in `primary` (#005129), a deep, authoritative green that evokes the high-grade wool of a tournament table.

### The "No-Line" Rule
**Prohibit all 1px solid borders for sectioning.** Elements must be defined by their container shifts. A `surface-container-lowest` card (#FFFFFF) gains its boundary naturally by sitting atop a `surface-container-low` (#F3F3F8) background.

### Surface Hierarchy & Nesting
Use the hierarchy below to create "nested" depth. Treat the UI as layers of fine paper stacked on a felt table:
- **Surface (Base):** #F9F9FE — The "room" light.
- **Surface-Container-Low:** #F3F3F8 — The general "table" area.
- **Surface-Container-Lowest:** #FFFFFF — The "active" card or cue-ball focal point.
- **Surface-Container-Highest:** #E2E2E7 — Reserved for inactive or recessed instructional elements.

### The "Glass & Gradient" Rule
To elevate the "professional" feel, floating action buttons or high-level progress indicators should utilize **Glassmorphism**. Apply a `surface` color at 80% opacity with a `backdrop-filter: blur(20px)`. 

### Signature Textures
Main CTAs must use a subtle linear gradient: `primary` (#005129) to `primary-container` (#1A6B3C) at a 145° angle. This adds a "sheen" reminiscent of polished phenolic resin balls.

---

## 3. Typography: Editorial Authority
We utilize **SF Pro** (Inter as the web-safe equivalent) to maintain the iOS native DNA, but we apply an editorial scale to break the "system" look.

*   **Display (L/M/S):** Used for big-number stats (e.g., "98% Accuracy"). Tight letter-spacing (-0.02em) to feel cinematic.
*   **Headline (L/M/S):** Used for lesson titles. These should feel heavy and grounded, providing the "Title" of a training chapter.
*   **Body (MD):** The workhorse. Always use `on-surface-variant` (#404940) for long-form instructional text to reduce eye strain.
*   **Label (SM):** Used for technical specs (e.g., "Backspin: 2.4 rps"). High letter-spacing (+0.05em) and all-caps for a blueprint feel.

---

## 4. Elevation & Depth: Tonal Layering
Traditional shadows are too heavy for a "clean" billiard aesthetic. We use light to define geometry.

*   **The Layering Principle:** Depth is achieved by stacking `surface-container` tiers. An inner training canvas (`surface-container-high`) should sit inside a lesson card (`surface-container-lowest`) to feel "inset" like the pocket of a table.
*   **Ambient Shadows:** If an element must float (e.g., a cue-ball selector), use a `primary-fixed-dim` tinted shadow: `0px 10px 30px rgba(0, 81, 41, 0.08)`. This mimics the soft shadow a ball casts on the felt.
*   **The Ghost Border:** If accessibility requires a stroke, use `outline-variant` (#BFC9BE) at **15% opacity**. It should be felt, not seen.

---

## 5. Components: Precision Tools

### Buttons
- **Primary:** Gradient-fill (`primary` to `primary-container`), 12pt corner radius. White text. No shadow.
- **Secondary:** `surface-container-highest` background with `primary` text. Use for "Analyze" or "View Diagram."
- **Tertiary:** No background. `secondary` (#0061A5) text for "Skip" or "Later."

### Cards & Lists
- **Forbid Dividers:** Do not use line separators between list items. Use 16pt vertical spacing or a subtle shift from `surface-container-lowest` to `surface-container-low`.
- **Inner Canvases:** 8pt corner radius. This is the "felt" where the shot diagrams live. Use `table-felt-color` (#1B6B3A) as the background for these canvases.

### Shot-Path Chips
- **Status Chips:** Use `secondary-container` (#6FB2FD) for "Perfect Path" and `tertiary-container` (#825400) for "Correction Needed."

### Interactive Cue Ball (Custom Component)
- A circular container using `surface-container-lowest` (#FFFFFF) with a `surface-dim` (#D9DADE) radial gradient to simulate 3D volume. The contact point uses `error` (#BA1A1A) with a soft glow.

---

## 6. Do’s and Don'ts

### Do:
- **Do** use `primary-fixed` (#A5F4B8) as a background for "Success" states—it feels like a brightly lit table.
- **Do** allow content to bleed off-edge in horizontal scrolls to suggest the continuity of the table surface.
- **Do** use SF Symbols with "Medium" or "Semibold" weights to match the typographic density.

### Don’t:
- **Don’t** use pure black (#000000). Use `on-surface` (#1A1C1F) for all high-contrast text.
- **Don’t** use harsh 90-degree corners. Even the most technical diagrams must use the `md` (0.75rem) or `sm` (0.25rem) roundedness to maintain the "organic" feel of the sport.
- **Don’t** use standard iOS "Separator Lines." Separate thoughts with white space and tonal blocks.