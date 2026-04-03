# Design System Documentation: Professional Billiards Training

## 1. Overview & Creative North Star: "The Precise Tactician"
The design system for this billiards training experience is anchored by a Creative North Star we call **"The Precise Tactician."** Unlike generic sports apps that lean into aggressive grit, this system treats the billiards table as a canvas of geometry and focus. 

The aesthetic is an "Editorial iOS" approach. It breaks the standard template look by utilizing **Intentional Asymmetry** and **Tonal Depth**. By moving away from rigid lines and embracing a "layered paper" philosophy, we create a digital environment that feels as quiet and focused as a championship match.

## 2. Colors: Tonal Depth vs. Structural Lines
This system rejects the use of traditional borders. We establish hierarchy through a sophisticated palette of greens and neutrals that mimic the felt and lighting of a high-end billiard hall.

### The Palette
*   **Primary (`#1A6B3C`):** The "Tournament Green." Used for high-level branding, section titles, and primary actions.
*   **Surface (`#F2F2F7`):** The base canvas. A cool, light grey that allows card elements to breathe.
*   **Surface-Lowest (`#FFFFFF`):** Reserved for interactive cards and primary content containers.
*   **Danger (`#C62828`):** The "Foul Red." Used sparingly for destructive actions or critical errors.

### The "No-Line" Rule
**Explicit Instruction:** Do not use 1px solid borders to define sections. Boundaries must be defined solely through background shifts. 
*   Place a `surface-container-lowest` (#FFFFFF) card on a `surface` (#F2F2F7) background to create definition.
*   If a container requires further nesting, use `surface-container-low` (#EEEEEA) to create a "recessed" feel.

### Signature Textures
While the UI remains flat, "soul" is added through **Glassmorphism**. Floating action buttons or top navigation bars should utilize a `backdrop-blur` (20px+) with a 70% opacity white fill. This creates a sense of professional polish, ensuring the UI feels like a high-end tool rather than a static document.

## 3. Typography: Editorial Authority
We utilize the SF Pro Rounded family to mirror the soft curves of the billiard ball while maintaining the authority of a training manual.

*   **Display / Section Titles:** `22pt Bold Rounded` in Primary Green (#1A6B3C). Use generous top-padding (32pt+) to signal a new chapter in the training flow.
*   **Titles:** `SF Pro Rounded Medium`. Used for card headers to provide a friendly yet firm structure.
*   **Body:** `SF Pro Regular`. Optimized for legibility in training drills and setup instructions.
*   **Annotation:** `13pt Regular`, Color `rgba(60,60,67,0.6)`. This "Subtle Slate" is used for secondary data, captions, and non-essential tips.

## 4. Elevation & Depth: Tonal Layering
In this design system, depth is a matter of "stacking" rather than "shadowing."

*   **The Layering Principle:** Strive for a "3-Tier Stack." 
    1.  **Level 0 (Base):** Background (#F2F2F7).
    2.  **Level 1 (Content):** White Cards (#FFFFFF) with `16pt` radius.
    3.  **Level 2 (Interaction):** Subtle Tonal Shift or Glassmorphism for overlays.
*   **Ambient Shadows:** If a card must float (e.g., a "Quick Start" button), use an ultra-diffused shadow: `Y: 4, Blur: 20, Color: rgba(26, 107, 60, 0.08)`. This tints the shadow with our brand green, making the "glow" feel like light reflecting off the table felt.
*   **The "Ghost Border":** If a button sits on a white background, use an `outline-variant` at 10% opacity. Never use a 100% opaque border.

## 5. Components: Precision Primitives

### Cards & Lists
*   **The Divider Forbiddance:** Divider lines between list items are prohibited. Use **Vertical White Space** (12pt-16pt) to separate list items.
*   **Card Styling:** All cards must use `16pt` corner radius (`xl` scale). Content within cards should have a minimum of `16pt` internal padding.

### Buttons
*   **Primary:** Solid Primary Green (#1A6B3C) with White text. Radius: `12pt`.
*   **Secondary:** Surface-Container-Low (#EEEEEA) with Primary Green text. This creates a "recessed" button feel that doesn't compete with the main CTA.

### Input Fields
*   **Form Style:** Use a "Ghost Style" input. No bottom line, no box. Instead, use a subtle `surface-container-low` background fill with a `12pt` radius. This keeps the interface feeling "soft" and approachable.

### Specialized Components for Billiards
*   **The Drill Step:** A numbered chip using `primary-fixed` (#A5F4B8) with a small, bold number. This guides the user through complex table setups.
*   **Shot Outcome Chips:** Small, pill-shaped indicators. "Success" uses a soft green tint; "Miss" uses a soft red tint—both at 15% opacity to avoid visual "noise."

## 6. Do’s and Don’ts

### Do
*   **Do** use asymmetrical margins. For example, a 24pt left margin and 16pt right margin can create a modern, editorial look for text-heavy screens.
*   **Do** prioritize "Breathing Room." If a screen feels crowded, increase the vertical spacing between sections to 40pt+.
*   **Do** use `SF Pro Rounded` for any numerical data (scores, angles, power %) to give it a custom, bespoke feel.

### Don’t
*   **Don’t** use pure black (#000000). It is too harsh against the "Precise Tactician" palette. Use `on-surface` (#1A1C1A) for maximum contrast.
*   **Don’t** use standard iOS 1px separators. They break the fluid, premium feel of the tonal layers.
*   **Don’t** use high-intensity red for anything other than a genuine error or "Danger" state. Billiards requires calm; red should be an alarm, not a highlight.