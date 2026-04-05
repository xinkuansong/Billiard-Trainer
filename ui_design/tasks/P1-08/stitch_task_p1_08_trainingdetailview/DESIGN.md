# Design System: The Tactical Green

## 1. Overview & Creative North Star
This design system is built for precision and focused athleticism. Our Creative North Star is **"The Digital Baize"**—an editorial-grade experience that mirrors the quiet, high-stakes atmosphere of a professional billiard hall. 

We move beyond the "standard" fitness tracker by utilizing a high-fidelity, light-mode-only aesthetic that prioritizes scannability through extreme clarity. The layout avoids rigid, boxy templates in favor of a fluid, layered experience. We use intentional asymmetry and white space to guide the eye through complex training data, making the app feel like a premium coaching journal rather than a simple database.

## 2. Colors
Our palette is rooted in the heritage of the sport, using deep, saturated greens balanced by crisp architectural whites and luxury metal accents.

### Core Palette
*   **Primary (Billiard Green):** `#005129` (Primary) / `#1A6B3C` (Container). This is our anchor. It represents the felt, the field of play, and the focus of the athlete.
*   **Secondary (Pro Gold):** `#805600` (Secondary) / `#D4941A` (Container). Reserved exclusively for Pro-tier features, achievement milestones, and high-level training insights.
*   **Destructive:** `#C62828`. High-contrast red for errors and critical actions.
*   **Neutrals:** 
    *   `#F2F2F7` (Surface Container): The standard page/sheet background.
    *   `#FFFFFF` (Surface Container Lowest): The pure white used for elevated cards and foreground content.

### Color Rules
*   **The "No-Line" Rule:** 1px solid borders are strictly prohibited for sectioning. Structural boundaries must be defined solely by background shifts. For example, a white card (`surface-container-lowest`) sits on a light gray page (`surface-container-low`) to define its edge.
*   **Surface Hierarchy:** Use the Material-inspired stacking order. A training session view might have a `surface-container` background, with stats modules using `surface-container-highest` for subtle emphasis.
*   **The Signature Gradient:** While the UI is primarily solid, the Primary CTA and Hero Stat Cards may use a subtle vertical gradient (e.g., `#1A6B3C` to `#005129`) to provide a "felt-like" depth that flat color cannot replicate.

## 3. Typography
We use the **SF Pro** family to maintain a native iOS feel while applying an editorial scale to create a clear informational hierarchy.

*   **Display (Large Stats):** 22pt Bold. Used for primary metrics (e.g., Win Rate %, Potting Consistency).
*   **Headline (Section Titles):** 20pt Bold. Used for screen titles and major module headers.
*   **Title (Card Headers):** 17pt Semibold. Used to identify specific drills or dates.
*   **Body (Primary Content):** 17pt Regular. The standard for all readable descriptions and list data.
*   **Label/Caption:** 13pt Regular. Used for metadata, helper text, and secondary units (e.g., "kg", "mins").

The contrast between the 22pt Display and 13pt Caption creates an authoritative, data-first identity.

## 4. Elevation & Depth
In this system, depth is a functional tool for focus, not just a decorative effect.

*   **Tonal Layering:** Depth is achieved by "stacking" surface tiers. Cards never use shadows when resting on a gray background; the color contrast is the separator.
*   **The Ambient Shadow:** Floating elements—such as overflow menus or modal sheets—use an extra-diffused shadow. 
    *   *Spec:* `Y: 4, Blur: 16, Color: rgba(0, 0, 0, 0.08)`. This mimics soft, overhead pool-table lighting.
*   **The Ghost Border:** If a boundary is required for accessibility in a dense table, use the `outline-variant` token at 15% opacity. Never use a 100% opaque border.
*   **Billiard-Themed Elements:** Table thumbnails must utilize the "felt" (`#1B6B3A`) and "rail" (`#7B3F00`) colors. These elements should have a 4pt radius to maintain a technical, schematic look within the 12pt-radius parent cards.

## 5. Components

### Buttons
*   **Primary:** Billiard Green fill, White text, 12pt radius. Height: 50pt for main actions.
*   **Secondary:** White fill with a "Ghost Border," Green text, 12pt radius.
*   **Pro Action:** Gold fill, White text, 12pt radius.

### Cards & Lists
*   **Rule:** Forbid divider lines.
*   **Style:** Use 12pt corner radius. Separate list items with 12pt or 16pt of vertical whitespace. If a visual break is needed, use a 4pt tall `surface-container-highest` spacer.

### Floating Overflow Menus
*   **Radius:** 16pt (xl).
*   **Icons:** 24pt circular backgrounds in secondary/tonal colors with SF Symbols centered within.
*   **Effect:** Apply a `systemUltraThin` backdrop blur (Glassmorphism) to the menu background to let the training data peek through, making the UI feel integrated and light.

### Modal Sheets
*   **Style:** Standard iOS-style bottom sheets.
*   **Handle:** 36pt x 5pt capsule, centered, color `#C5C5C7`.
*   **Backdrop:** 40% opacity black dimming.

## 6. Do's and Don'ts

### Do
*   **Do** use SF Symbols with "Medium" or "Semibold" weights to match the typography.
*   **Do** use 24pt spacing (3x) for major page margins and 16pt (2x) for internal card padding.
*   **Do** allow stats to "breathe" with generous white space; density is the enemy of precision.

### Don't
*   **Don't** use generic blue for links or highlights; everything must stay within the Green/Gold/Red/Gray ecosystem.
*   **Don't** use sharp 0pt corners. Everything from buttons to table thumbnails must follow the roundedness scale (12pt for primary containers).
*   **Don't** use heavy dropshadows. If the surface color doesn't provide enough contrast, adjust the surface tier rather than adding a shadow.