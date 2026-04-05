# Design System Strategy: The Midnight Felt

## 1. Overview & Creative North Star
The Creative North Star for this design system is **"The Focused Observer."** 

Unlike typical sports apps that use aggressive gradients and loud energetic bursts, this system adopts a "High-End Editorial" approach to billiards training. It mimics the quiet, intense atmosphere of a private pool hall at midnight. By utilizing a True Black (#000000) foundation, we eliminate the "backlight glow" of OLED screens, allowing the UI to vanish so the content—the green of the cloth and the gold of the trophy—can breathe. 

We break the "template" look through **intentional asymmetry** (e.g., left-aligned oversized headers paired with right-aligned technical data) and **tonal layering**, ensuring the interface feels like a precision instrument rather than a generic mobile app.

---

## 2. Colors: Tonal Architecture
The depth of the interface is defined not by lines, but by the physical "stacking" of surfaces.

### Color Palette
- **Deep Void (Background):** `#000000` — The absolute base. Use this for the main canvas to ensure pixel-perfect OLED blacks.
- **Felt Primary (Primary):** `#25A25A` — Used for success states and primary actions. It represents the "Green" of the game.
- **Championship Gold (Accent/Pro):** `#F0AD30` — Reserved for premium features and achievement milestones.
- **Surface Tiers:**
    - `Surface-Low` (Cards): `#1C1C1E`
    - `Surface-High` (Tertiary): `#2C2C2E`
- **Typography:**
    - `On-Surface-Primary`: `#FFFFFF` (100% opacity)
    - `On-Surface-Secondary`: `rgba(235, 235, 240, 0.6)`
    - `On-Surface-Tertiary`: `rgba(235, 235, 240, 0.3)`

### The "No-Line" Rule
Explicitly prohibit 1px solid borders for sectioning. Boundaries must be defined solely through background color shifts. To separate a list of drills, do not use a line; instead, place the drill items on `#1C1C1E` cards against the `#000000` background.

### Surface Hierarchy & Nesting
Treat the UI as a series of nested physical layers. 
- **Level 0:** `#000000` (Main App Canvas)
- **Level 1:** `#1C1C1E` (Main Content Cards)
- **Level 2:** `#2C2C2E` (Nested elements like search bars or input fields inside cards)

---

## 3. Typography: Editorial Authority
The typography scale creates a rhythmic contrast between "Technical Data" and "Sporting Elegance."

### Display & Headlines (Plus Jakarta Sans / Rounded)
*Use for session titles, score summaries, and brand moments.*
- **Display-LG:** 3.5rem / 56pt. Bold, Rounded. Negative tracking (-2%) to feel compact and premium.
- **Headline-MD:** 1.75rem / 28pt. Medium, Rounded. 

### Body & Labels (Inter / SF Pro Style)
*Use for technical instructions and data points.*
- **Body-LG:** 1rem / 16pt. Regular. High legibility for training guides.
- **Label-MD:** 0.75rem / 12pt. All-caps with +5% letter spacing. Use for "TECHNICAL SPECS" or "DRILL TYPE" tags.

---

## 4. Elevation & Depth: Tonal Layering
In "The Midnight Felt," depth is a result of light, not shadow.

- **The Layering Principle:** To create a "lifted" effect, move from a darker surface to a lighter surface. For example, a "Start Practice" floating panel should be `#2C2C2E` sitting on the `#000000` background.
- **Ambient Shadows:** Shadows are strictly forbidden for standard UI. If a "floating" modal is required, use a 64pt Blur with 4% opacity of the `#FFFFFF` color to create a "Glow" rather than a "Shadow."
- **The "Ghost Border" Fallback:** In high-density data views where contrast is critical, use a "Ghost Border" of `#38383A` at 20% opacity. This provides a structural hint without breaking the flat-fill aesthetic.

---

## 5. Components: Precision Tools

### Buttons (Radii: 12pt / 999pt)
- **Primary Action:** Flat Fill `#25A25A` with `#FFFFFF` text. No gradients.
- **Secondary Action:** Flat Fill `#1C1C1E` with `#25A25A` text.
- **Pill Stats:** Use 999pt radii for status indicators (e.g., "Pro Mode" or "Completed") to contrast against the 16pt card corners.

### Drills & List Cards (Radii: 16pt)
- **Rule:** Forbid the use of divider lines. 
- **Style:** Each drill is a `#1C1C1E` block. Use the `Title-MD` typography for the drill name and `Label-SM` in `Text-Secondary` for the difficulty level. Separate blocks with 12pt or 16pt of vertical whitespace.

### Progress Trackers (The "Cue" Indicator)
- Use a horizontal bar. Background: `#2C2C2E`. Progress Fill: `#25A25A`. 
- For "Pro" or "Master" level drills, swap the fill to Championship Gold (`#F0AD30`).

### Interactive Inputs
- **Text Fields:** Background `#1C1C1E`. Active State: Change background to `#2C2C2E` and change the label color to `#25A25A`. Avoid "Focus Borders."

---

## 6. Do’s and Don’ts

### Do
- **Use Wide Gutters:** Maintain at least 20pt of horizontal padding from the device edge to keep the "Editorial" feel.
- **Embrace the Pitch Black:** Ensure the `#000000` is the dominant color on the screen to save battery and increase focus.
- **Use "Championship Gold" Sparingly:** Use it only for top-tier achievements to maintain its value.

### Don't
- **No Gradients:** Do not add "vignettes" or "lighting effects" to buttons. Stick to flat, confident fills.
- **No 1px Dividers:** Do not use separators between list items. Use 8pt–16pt gaps of `#000000` to create separation.
- **No Pure White for Body Text:** Use `rgba(235, 235, 240, 0.6)` for long-form reading to prevent eye strain on OLED displays. Only use `#FFFFFF` for titles.