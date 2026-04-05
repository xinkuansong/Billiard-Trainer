# Design System Strategy: The Focused Athlete

## 1. Overview & Creative North Star
The Creative North Star for this design system is **"The Nocturnal Arena."** 

Unlike generic training apps that feel cluttered and loud, this system leverages the pitch-black environment of a late-night billiards hall. It is designed to mimic the high-contrast focus of a single spotlight hitting the green felt. We move beyond "Dark Mode" as a setting and treat it as a premium canvas. By utilizing intentional asymmetry, varying depths of black, and sharp, monastic typography, we create an interface that disappears, leaving only the user and their performance data. 

The aesthetic avoids the "template" look by eschewing standard dividers in favor of **Tonal Layering**—creating a layout that feels carved out of stone rather than built with lines.

---

## 2. Colors: Tonal Depth & The "No-Line" Rule
The palette is rooted in absolute blacks and deep, organic greens to maintain "Pure Black" OLED integrity while providing enough hierarchy for complex training data.

### The Foundation
- **Surface (Background):** `#000000` (Pure Black). The primary canvas.
- **Surface-Container-Low:** `#131313`. Used for subtle sectioning.
- **Surface-Container:** `#1C1C1E`. The primary card background.
- **Surface-Container-High:** `#2C2C2E`. Reserved for interactive elements like inputs.

### The Brand & Action
- **Primary:** `#69DD8E` (Refined Brand Green). High-visibility for active states and CTAs.
- **Tertiary:** `#FFB955` (Warmup/Alert). High-contrast amber to catch the eye without screaming.
- **Table Specialty:** `#144D2A` (Felt) and `#5C2E00` (Cushion). To be used exclusively for diagrammatic representations.

### The "No-Line" Rule
**Strict Mandate:** Designers are prohibited from using 1px solid borders for sectioning or grouping. 
- **The Technique:** To separate a "Training Drill" card from the "Dashboard" background, do not draw a line. Instead, nest the `surface-container` card directly onto the `surface` background. 
- **Nesting Hierarchy:** Use the `surface-container-lowest` to `highest` tiers to define importance. An input field (`#2C2C2E`) should sit inside a card (`#1C1C1E`), which sits on the page (`#000000`). This "stacked paper" approach creates natural, sophisticated boundaries.

---

## 3. Typography: Editorial Authority
We use a tri-font strategy to balance legibility with a high-end, data-driven feel.

| Level | Token | Font | Size | Weight | Intent |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Display** | `display-lg` | Manrope | 3.5rem | Bold | Hero stats (e.g., Win Rate %) |
| **Headline** | `headline-sm` | Manrope | 1.5rem | Semi-Bold | Section headers / Title cards |
| **Timer** | `custom-mono` | SF Mono | 1.75rem | Bold | Performance tracking / Drills |
| **Body** | `body-lg` | Inter | 1rem | Regular | Descriptions and instructions |
| **Label** | `label-md` | Space Grotesk | 0.75rem | Medium | Metadata, chips, and caps-only tags |

**Editorial Contrast:** Use `display-lg` (Manrope) for large numerical data and immediately follow it with `label-sm` (Space Grotesk) in `text-secondary` for a premium, magazine-style layout.

---

## 4. Elevation & Depth: Tonal Layering
Since we are avoiding traditional drop shadows to maintain a "Task-Oriented" flat style, depth is achieved through **Luminance Shifts**.

- **The Layering Principle:** Higher-priority items are physically "closer" to the user and thus lighter.
    - Level 0 (Base): `#000000`
    - Level 1 (Content Block): `#1C1C1E`
    - Level 2 (Interactive/Floating): `#2C2C2E`
- **Ghost Borders:** For accessibility in active states, use the `outline-variant` token at **20% opacity**. This creates a "glow" effect rather than a hard structural line, maintaining the "Nocturnal Arena" vibe.
- **Glassmorphism:** For the bottom Navigation Bar or floating Action Buttons, use `surface-container` at 80% opacity with a **20px Backdrop Blur**. This allows the "table felt" colors to bleed through as the user scrolls, creating a sense of environmental immersion.

---

## 5. Components: Precision Tools

### Buttons
- **Primary:** `primary` (#69DD8E) background with `on-primary` (#00391A) text. Roundedness: `lg` (1rem). No gradients.
- **Secondary:** Transparent background with a `2pt` border of `primary`. 
- **Tertiary (Quiet):** `surface-container-highest` background with `on-surface` text.

### Performance Chips
- **Style:** 999pt pill shapes.
- **Interaction:** Use `primary-container` for selected states. Use `surface-container-high` for unselected. Never use a border on a chip unless it is the "Active" filter.

### Training Inputs
- **Base:** `#2C2C2E` background, `md` (0.75rem) corner radius.
- **Active State:** Change border to `primary` (#25A25A) at `2pt` thickness. The background should remain dark to keep the focus on the cursor.

### List Items & Cards
- **The Divider Ban:** Strictly forbid the use of horizontal lines between list items. Instead, use a **12px vertical spacing gap**. If grouping is required, wrap the items in a single `surface-container` with a `12pt` radius.

### Additional Specialty Components
- **The "Drill Progress" Bar:** A 4px slim track using `surface-container-highest` with a `primary` fill. No rounded caps on the progress—keep the ends square for a "technical" look.
- **The Shot Diagram Container:** Use `surface-container-lowest` (#0E0E0E) to frame the billiard table diagrams, making the felt color (#144D2A) pop with realistic intensity.

---

## 6. Do’s and Don’ts

### Do:
- **Embrace Negative Space:** Use double the standard spacing (e.g., 32px instead of 16px) between major sections to let the OLED black "breathe."
- **Use Intentional Asymmetry:** Align large numerical stats to the left and metadata labels to the right to break the "standard list" monotony.
- **Color Logic:** Use `primary` only for success or action. Use `tertiary` (Amber) for "In Progress" or "Warmup."

### Don’t:
- **Don't use 100% White for Body Text:** Use `text-secondary` (rgba 235, 235, 240, 0.6) for long-form reading to prevent eye strain against the pure black background.
- **Don't use Shadows:** Rely on color shifts between `#000000`, `#131313`, and `#1C1C1E` to define edges.
- **Don't use Icons for Everything:** This is a high-end system. Often, a well-set label in **Space Grotesk** is more "premium" than a generic icon.