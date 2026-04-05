# Design System Document: The Tactile Tactician

## 1. Overview & Creative North Star
**Creative North Star: "The Digital Felt"**
This design system moves beyond basic utility to evoke the quiet, focused atmosphere of a high-end billiards hall. We are not just building a training app; we are creating a digital sanctuary for precision. By leveraging the heavy, deliberate textures of billiard equipment—the deep green felt and the rich wood of the rails—the system achieves a "Tactile Editorial" feel.

The "template" look is avoided through **Atmospheric Immersion**. We prioritize large, high-contrast typography and intentional negative space, allowing the training content to breathe like a well-positioned cue ball on an open table.

## 2. Colors: Tonal Depth & Discipline
Our palette is rooted in the tradition of the sport but executed with modern digital precision.

| Role | Token | Value | Intent |
| :--- | :--- | :--- | :--- |
| **Primary** | `primary` | `#005129` | The core brand action color. Deep, authoritative green. |
| **Felt Surface** | `tertiary_container` | `#1B6B3A` | Used for immersive quiz backgrounds and active zones. |
| **The Rail** | `secondary` | `#8E4E11` | Accents, cues, and navigational anchors. |
| **Canvas** | `background` | `#F9F9FE` | The crisp, iOS-native base for maximum readability. |
| **Active Border** | `outline` | `#707A70` | Used exclusively for 2pt active state borders. |

### The "No-Line" Rule
To maintain a premium, editorial feel, **1px solid borders are strictly prohibited** for sectioning content. Boundaries must be defined by:
1.  **Background Shifts:** Place a `surface_container_low` card on a `surface` background.
2.  **Tonal Transitions:** Use the contrast between `#F9F9FE` (Background) and `#EDEDF2` (Surface Container) to imply hierarchy without "caging" the content in lines.

### Surface Hierarchy & Nesting
Treat the UI as a physical environment. 
- **Base Level:** `surface` (The floor).
- **Secondary Level:** `surface_container_low` (The table area).
- **Interaction Level:** `surface_container_lowest` (White cards) used for questions and data points to provide "pop" against the background.

## 3. Typography: The High-Contrast Scale
We utilize a highly disciplined typographic scale to guide the eye through complex training data.

*   **Display (SF Pro Heavy):** `3.5rem` / `display-lg`. Used for score milestones and big "Win" states.
*   **Headline (SF Pro Bold):** `1.5rem` / `headline-sm`. Used for quiz questions. Must be `#000000` for maximum impact.
*   **Body (Inter/SF Pro Regular):** `1rem` / `body-lg`. Used for instructional text. 
*   **Secondary Text:** `rgba(60, 60, 67, 0.6)`. Use for metadata and helper text.
*   **Tertiary Text:** `rgba(60, 60, 67, 0.45)`. Use for disabled states and subtle watermarks.

**Editorial Tip:** Use "Asymmetric Tension." Pair a large `headline-lg` title with a significantly smaller `label-md` sub-header to create a sophisticated, non-generic layout.

## 4. Elevation & Depth: Tonal Layering
We reject heavy drop shadows in favor of **Tonal Layering**.

*   **The Layering Principle:** Depth is achieved by stacking. A `surface_container_lowest` card sitting on a `surface_container_high` background creates a natural lift.
*   **Ambient Shadows:** For floating action buttons or modal cards, use a "Whisper Shadow": `0 2pt 8pt rgba(0,0,0,0.06)`. This mimics the soft, diffused lighting found over a professional billiard table.
*   **The "Ghost Border":** If a container requires definition against a similar tone, use the `outline_variant` token at 15% opacity. Never use a 100% opaque border unless it is the 2pt "Active State."

## 5. Components: Precision Primitives

### Buttons
*   **Primary:** `primary_container` fill, `on_primary` text. 12pt corner radius. No gradient.
*   **Secondary:** `surface_container_highest` fill, `on_surface` text.
*   **Active State:** Add a 2pt border using `primary` or `outline` to indicate selection.

### Training Cards
*   **Structure:** 16pt corner radius. Use `surface_container_lowest` (Pure White).
*   **Spacing:** Content must have at least 24pt internal padding to maintain the "Editorial" breathing room.
*   **No Dividers:** Separate list items within cards using 12pt of vertical whitespace or a subtle background shift to `surface_container_low`.

### Quiz Inputs (The Rail Logic)
*   **Selection Chips:** Use `secondary_fixed` (The Rail tone) for unselected and `primary` for selected.
*   **Progress Bars:** A solid track of `surface_container_highest` with a `primary` fill indicating progress. Avoid rounded ends on the progress fill for a more architectural look.

### The "Shot Map" Component (Custom)
*   An immersive, full-bleed container using `tertiary_container` (#1B6B3A) to simulate the table felt. All overlays within this component should use Glassmorphism (Background Blur 20px) to feel like they are floating above the table.

## 6. Do's and Don'ts

### Do:
*   **Do** use extreme white space. Billiards is a game of angles and gaps; the UI should reflect that.
*   **Do** use `headline-sm` for questions to create an "authoritative" training tone.
*   **Do** ensure all interactive elements meet a 44x44pt touch target, even if the visual asset is smaller.

### Don't:
*   **Don't** use 1px dividers. They clutter the "Digital Felt" and look cheap.
*   **Don't** use gradients. We rely on the purity of solid colors to convey a modern, "Flat-Plus" aesthetic.
*   **Don't** center-align long passages of instructional text. Keep it flush-left (ragged right) for a professional editorial feel.
*   **Don't** use generic blue for links. Use `primary` (#1A6B3C) or `secondary` (#7B3F00).