# Design System Document

## 1. Overview & Creative North Star: "The Tactile Court"
This design system moves beyond the standard iOS utility to create a "Tactile Court" experience. For an app centered on the sport of billiards (球迹), the interface should mirror the quiet confidence, precision, and physical texture of the game itself. 

**The Creative North Star** is defined by **Precision Editorialism**. We reject the "generic app" aesthetic of thin gray lines and flat boxes. Instead, we use the billiard green (`primary`) as a grounding force, utilizing **tonal layering** and **intentional asymmetry** to guide the eye. The UI should feel like a high-end sports journal—spacious, authoritative, and sophisticated.

---

## 2. Colors & Surface Logic

The palette is rooted in the deep, felt-like greens of a championship table, supported by a sophisticated "Off-White" ecosystem that prevents eye strain and adds a premium, paper-like quality.

### Primary Palette
- **Primary (#005129):** The "Championship Green." Used for core branding and high-importance actions.
- **Primary Container (#1A6B3C):** The "Billiard Green." Use this for hero areas and primary interaction states.
- **On-Primary (#FFFFFF):** Absolute white for maximum legibility against the green.

### Neutral & Surface Hierarchy (The "No-Line" Rule)
**Rule:** 1px solid borders are strictly prohibited for sectioning. Separation is achieved through background shifts.
- **Surface (#F7FAF3):** The base canvas. A subtle green-tinted white that feels organic.
- **Surface Container Low (#F1F5EE):** Used for large secondary sections or grouping related content.
- **Surface Container Lowest (#FFFFFF):** Reserved for elevated "Cards." This creates a natural "pop" against the Surface background without needing a stroke.
- **Surface Container High (#E6E9E2):** Used for interactive elements like input fields or pressed states.

### Semantic Roles
- **Success:** #34C759 (Native iOS Green)
- **Warning:** #FF9500 (Native iOS Orange)
- **Error:** #BA1A1A (Refined Destructive Red)

---

## 3. Typography: The Editorial Scale

We use **SF Pro** (and SF Pro SC for Chinese characters) to maintain iOS native fluidity, but we apply an editorial hierarchy to break the "template" feel.

- **Display (3.5rem - 2.25rem):** Use `display-md` for scoreboards or major milestones. Tighten letter spacing (-2%) for a bespoke look.
- **Headline (2rem - 1.5rem):** `headline-sm` is the workhorse for screen titles. Bold weights (700) are preferred to establish authority.
- **Title (1.375rem - 1rem):** Use `title-md` for card headings. This provides a clear entry point into content blocks.
- **Body (1rem - 0.75rem):** `body-lg` (16pt) is our standard for readability. 
- **Label (0.75rem - 0.6875rem):** Use for metadata. Increase letter spacing (+5%) for uppercase or English strings to add a "designer" touch.

**Implementation Note:** In Simplified Chinese, ensure a line height of at least 1.5x for body text to maintain the "breathing room" required by the brand.

---

## 4. Elevation & Depth: Tonal Layering

Traditional drop shadows are too "digital." We use physical stacking logic.

- **The Layering Principle:** Place a `surface-container-lowest` (#FFFFFF) card on a `surface` (#F7FAF3) background. The 12pt (`md`) corner radius provides the "shape," while the color shift provides the "edge."
- **Ambient Shadows:** Only use shadows for floating elements (e.g., a "New Game" FAB). Use a `primary-fixed-dim` tint for the shadow at 8% opacity with a 20px blur. It should look like a glow, not a gray smudge.
- **Glassmorphism:** For top navigation bars or bottom tab bars, use `surface` with 80% opacity and a 20px backdrop-blur. This allows the "billiard green" of the content to bleed through as the user scrolls, creating a sense of continuity.
- **The "Ghost Border":** If a button requires a border, use `outline-variant` at 20% opacity. It should be felt, not seen.

---

## 5. Components

### Buttons
- **Primary:** `primary-container` background with `on-primary` text. 12pt corner radius. No border.
- **Secondary:** `surface-container-high` background with `primary` text. Provides a soft, tactile alternative.
- **Tertiary:** No background. Bold `primary` text. Used for low-emphasis actions like "Cancel."

### Cards (The Signature Element)
- **Style:** `surface-container-lowest` background, 16pt internal padding, 12pt corner radius.
- **Rule:** Never use a divider line between card items. Use an 8pt vertical gap or a subtle shift to `surface-container-low` for nested items.

### Input Fields
- **Background:** `surface-container-highest` (soft gray-green).
- **Active State:** Change background to `surface-container-lowest` and add a 1px "Ghost Border" using `primary` at 30% opacity.

### Navigation (Tab Bar)
- Use a "Floating" tab bar approach. A centered pill-shaped container using `surface-container-lowest` with a high-diffusion ambient shadow. This breaks the rigid bottom-docked iOS standard and feels more modern.

### Specialized Components for QiuJi
- **Score Tracker:** Use `display-sm` with tabular lining figures (monospaced numbers) to ensure digits don't jump during score updates.
- **Match Timeline:** Use a vertical "Green Thread"—a 2px line in `primary-fixed` that connects match events, using `primary` circles for key milestones.

---

## 6. Do's and Don'ts

### Do
- **Do** use 16pt margins consistently. The "breath" at the edges of the screen is what makes it feel premium.
- **Do** use `primary-container` (#1A6B3C) for large blocks of color to anchor the brand identity.
- **Do** leverage the `surface-container` tiers to create hierarchy. A darker surface means "deeper" or "less important" in this system.

### Don't
- **Don't** use 100% black (#000000). Always use `on-surface` (#181D19) for text to maintain the organic, dark-green-tinted palette.
- **Don't** use standard iOS dividers. They clutter the UI. Rely on whitespace and background tonal shifts.
- **Don't** use gradients. Our depth comes from layering solid surfaces, mimicking the flat but rich look of billiard cloth.

---
*Note: This design system is intended to be implemented with a focus on "White Space as a Feature." Every element must earn its place on the 393px canvas.*