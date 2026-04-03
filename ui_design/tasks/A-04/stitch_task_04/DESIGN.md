# Design System Documentation: The Precision Curator

## 1. Overview & Creative North Star
The vision for this design system is **"The Precision Curator."** 

Billiards is a game of millimeters, geometry, and composure. To reflect this, the UI moves away from generic app templates toward a high-end editorial experience. We achieve this by blending the approachable softness of iOS (via rounded geometries) with the authoritative weight of professional sports journalism. 

The layout breaks the "standard grid" through **intentional white space** and **asymmetric focal points**. We treat the screen not as a container for data, but as a "Digital Baize"—a premium, tactile surface where every element feels placed with the same intent as a cue ball on felt.

---

## 2. Color & Tonal Architecture
The palette is rooted in the heritage of the sport: deep championship greens, trophy golds, and a sophisticated range of architectural greys.

### Palette Tokens
*   **Primary (Brand Green):** `#005129` | The core of the identity. Used for primary actions and brand presence.
*   **Tertiary (Pro Gold):** `#603f00` | Reserved for premium status, achievement unlocks, and high-level progression.
*   **Neutral Surfaces:** 
    *   `background`: `#f9f9fe` (The canvas)
    *   `surface_container_lowest`: `#ffffff` (Elevated cards)
    *   `surface_container_high`: `#e8e8ed` (Sunken UI elements)

### The "No-Line" Rule
To maintain a high-end editorial feel, **1px solid borders are strictly prohibited** for defining sections or containers. Separation must be achieved through:
1.  **Tonal Shifts:** Placing a `surface_container_lowest` card against the `surface_container_low` background.
2.  **Structural Negative Space:** Utilizing the 8pt grid to create clear "islands" of content.

### Surface Hierarchy & Nesting
Think of the UI as physical layers. A coaching module might sit on a `surface_container_low` background, while the individual lesson cards within it use `surface_container_lowest` to "lift" toward the user. This creates depth without visual clutter.

---

## 3. Typography
We utilize **Plus Jakarta Sans** (an editorial alternative to SF Pro) to provide a bespoke, premium feel while maintaining the friendly, rounded terminal aesthetic requested.

*   **Display (Editorial Hero):** `display-lg` (3.5rem). Use for big, bold performance stats or "Level Up" moments.
*   **Section Titles:** `headline-sm` (1.5rem / 24pt Bold). These are the anchors of your layout.
*   **Body Text:** `body-md` (0.875rem). Optimized for readability in training guides.
*   **Labels:** `label-md` (0.75rem). Used for technical data (e.g., "Cue Angle", "Spin Rate").

**Hierarchy Tip:** Always pair a `headline-sm` with a `body-sm` in `on_surface_variant` (secondary text) to create a clear informational scent.

---

## 4. Elevation & Depth
Depth in this system is "Natural," not "Artificial."

*   **The Layering Principle:** Use the `surface-container` tiers (Lowest to Highest) to stack information.
    *   *Lowest:* Used for the most "active" elements (Cards).
    *   *Highest:* Used for "recessed" elements like search bars or inactive input tracks.
*   **Ambient Shadows:** For floating elements (like a FAB), use a highly diffused shadow: `Y: 8, Blur: 24, Color: rgba(26, 28, 31, 0.06)`. It should feel like a soft glow of light, not a hard drop shadow.
*   **The Glassmorphism Rule:** For navigation bars and headers, use a backdrop-blur (20px) with a semi-transparent `surface` fill. This allows the "Baize" green of the content to bleed through, creating an integrated, high-end feel.

---

## 5. Components

### Buttons
*   **Primary:** Capsule shape (`full` radius), `primary` background, `on_primary` text. Height: 44pt.
*   **Premium/Pro:** Capsule shape, `tertiary_container` background, `on_tertiary_container` text.
*   **Ghost (Tertiary):** No background, `primary` text. Used for secondary actions like "Cancel" or "View All."

### Cards
*   **Style:** 16pt corner radius (`DEFAULT`), 16pt padding.
*   **Rule:** No dividers inside cards. Separate content using `body-sm` labels or 8pt/16pt vertical spacing.
*   **Interaction:** On tap, cards should subtly scale to 98% to provide tactile feedback.

### Progress & Training Tracks
*   **The Track:** Use `surface_container_high` for the background of progress bars.
*   **The Fill:** Use a solid `primary` fill. No gradients.
*   **Contextual Feedback:** Use `tertiary_fixed` (Gold) for "Personal Best" milestones.

### Lists
*   **The "No-Divider" Mandate:** Traditional 1px dividers are replaced by 12pt vertical spacing. If content is dense, use a subtle background shift (`surface_container_low`) to group items.

---

## 6. Do's and Don'ts

### Do
*   **Do** use asymmetrical layouts for Hero sections (e.g., text left-aligned, cue-ball graphic partially overflowing the right edge).
*   **Do** use `tertiary` (Gold) sparingly. It is a reward, not a utility color.
*   **Do** embrace "The Breath." If a screen feels crowded, increase the margin from 16pt to 24pt.

### Don't
*   **Don't** use pure black `#000000` for text. Use `on_background` for high contrast and `on_surface_variant` for secondary info.
*   **Don't** use standard iOS blue for links. Everything must be `primary` (Green) or `tertiary` (Gold).
*   **Don't** add borders to cards. If a card isn't visible against the background, your background is too light—shift the background to `surface_container_low`.

---
**Director’s Note:** 
Remember, we are designing for a sport of focus. Every pixel should serve a purpose. If an element doesn't help the user improve their game, remove it. Keep the UI quiet so the user can stay loud.