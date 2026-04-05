# Design System: High-End Editorial for Billiards Training

## 1. Overview & Creative North Star

### Creative North Star: "The Precision Playbook"
This design system moves beyond a standard utility app to become a premium digital companion. It is inspired by high-end sports editorial and luxury billiards lifestyle—think the tactile precision of a custom cue and the quiet atmosphere of a championship hall. 

We break the "template" look through **Tonal Architecture**. Instead of relying on lines to separate content, we use staggered surface heights and intentional asymmetry. This creates an interface that feels less like a grid of boxes and more like an organized, sophisticated playbook where every element has its own physical presence.

---

## 2. Colors

The color palette is rooted in the heritage of billiards (Primary Green) and the prestige of professional mastery (Pro Gold).

*   **Primary (`#005129`) & Primary Container (`#1A6B3C`):** Represents the felt of the table—authoritative and steady.
*   **Secondary (`#805600`) & Pro Gold (`#D4941A`):** Used sparingly to denote achievement, "Pro" status, and critical focus points.
*   **Surface & Background Hierarchy:** 
    *   **Background (`#F9F9FE`):** The canvas.
    *   **Surface-Container-Low (`#F3F3F8`):** Use for large secondary content blocks.
    *   **Surface-Container-Lowest (`#FFFFFF`):** Reserved for primary interactive cards to create the highest "lift."

### The "No-Line" Rule
**Explicit Instruction:** Do not use 1px solid borders (`#E5E5EA`) for sectioning. Boundaries must be defined solely through background color shifts. A `surface-container-lowest` card sitting on a `surface-container-low` background is sufficient. This reduces visual noise and emphasizes a premium, editorial feel.

### Signature Textures
While the aesthetic is "clean and professional," we add visual soul through **Subtle Depth**. Main CTAs or active training states (like the `BTFloatingIndicator`) should use a 2-point vertical tonal shift—not a flashy gradient, but a soft transition from `primary` to `primary_container` to give the button a "rounded" physical feel.

---

## 3. Typography

The typography system uses **SF Pro** (iOS native) and **Manrope** for high-impact display moments to bridge the gap between "Tech" and "Sport."

*   **Display/Headline (Manrope):** Used for big numbers (timers, progress) and major titles. The slightly wider stance of Manrope suggests confidence and precision.
*   **Body/Labels (SF Pro):** Used for all instructional content. 
    *   **Titles:** 17pt Semibold (iOS Standard).
    *   **Body:** 13pt–15pt for optimal legibility during active training.

**Editorial Hierarchy:** Use extreme contrast in scale. A `display-lg` timer (3.5rem) should sit near a `label-md` instruction. This hierarchy tells the user exactly where to focus while keeping the rest of the UI out of the way.

---

## 4. Elevation & Depth

We convey hierarchy through **Tonal Layering** rather than traditional drop shadows.

*   **The Layering Principle:** Depth is achieved by stacking surface tiers. A training drill card (`surface-container-lowest`) sits on the exercise list background (`surface-container-low`), which sits on the main app background (`surface`).
*   **Ambient Shadows:** For floating elements like the `BTFloatingIndicator`, shadows must be extra-diffused. 
    *   *Shadow Spec:* `0 8px 24px rgba(0, 81, 41, 0.08)`. Note the use of a primary-tinted shadow rather than grey, which makes the UI feel more integrated and "lit" by the brand color.
*   **Glassmorphism:** Use for modal backgrounds and persistent indicators. A `backdrop-blur` of 20px with a 60% opacity fill (`rgba(0,0,0,0.6)`) creates a "frosted" separation that keeps the training context visible underneath.

---

## 5. Components

### Buttons & Interaction
*   **Primary Button:** Height 48pt–50pt. Radius 12pt. Use `primary` fill with `on_primary` text. No border.
*   **Secondary/Action Chips:** Radius 999px (Pill-shaped). Use `surface-container-high` as the base to keep them distinct from the white background.
*   **BTLevelBadge:** Pill-shaped, using the Tonal Palette. *Example:* L4 Professional uses `tertiary_container` (deep red-grey) to feel serious and earned, rather than "gamified" bright colors.

### The Training Ring
*   **Circular Progress:** Use a thick stroke for the primary progress (`primary`) and a "ghost stroke" (10% opacity of `primary`) for the remaining path. If "Pro Gold" is involved, the secondary progress ring should overlap with a 2px inset to show mastery level.

### Cards & Lists
*   **Forbid Divider Lines:** Lists are separated by 8pt or 12pt vertical spacing. 
*   **Drill Cards:** 16pt radius. Use a `surface-container-lowest` fill. Content is aligned with intentional asymmetry—large numbers on the left, descriptive metadata tucked into the bottom-right.

---

## 6. Do's and Don'ts

### Do
*   **Do** use "Ghost Borders" for input fields: `outline_variant` at 20% opacity. It provides a hint of structure without the "boxiness" of a standard input.
*   **Do** leverage breathing room. If an element feels cramped, increase the padding to the next step in the scale (e.g., from `md` to `lg`).
*   **Do** use Pro Gold (`#D4941A`) as a "North Star" color—it should only appear where the user has succeeded or is looking at "Pro" level content.

### Don'ts
*   **Don't** use 100% opaque grey separators. They kill the editorial vibe and make the app look like a system settings menu.
*   **Don't** use standard iOS blue for links. Every interactive element must be within the brand green or gold spectrum.
*   **Don't** use drop shadows on cards that are nested within other containers. Only the highest-level floating elements (modals, persistent indicators) get a shadow.