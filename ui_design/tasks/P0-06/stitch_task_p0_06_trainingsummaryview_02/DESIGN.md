# Design System: The Precision Playbook

This design system is a bespoke framework for a high-end iOS billiards training experience. It moves beyond standard mobile templates to embrace an "Editorial Athlete" aesthetic—combining the precision of professional sports data with the sophisticated layouts of a luxury lifestyle journal.

---

## 1. Creative North Star: The Silent Coach
The design language is rooted in the concept of **"The Silent Coach."** Like a high-end billiard room, the interface should feel quiet, expensive, and focused. We achieve this through "Atmospheric Space"—using generous white space and tonal shifts rather than lines to guide the eye. The UI never competes with the user’s focus; it frames it.

### Editorial Asymmetry
To break the "standard app" feel, we use intentional asymmetry. Data points are not always centered; they are anchored to a grid that allows for large, breathing headers and overlapping elements that suggest depth and motion.

---

## 2. Color & Surface Architecture

The palette is anchored in the traditional baize green, but elevated through a tiered surface system.

### The "No-Line" Rule
**Explicit Instruction:** Designers are prohibited from using 1px solid borders to section content. Boundaries must be defined solely through background color shifts or subtle tonal transitions. A section is defined by its container level, not its stroke.

### Surface Hierarchy & Nesting
We use a "Physical Layering" approach. Treat the UI as a series of stacked sheets:
- **System Background (`surface` #F9F9FE):** The base floor.
- **Sectioning (`surface-container-low` #F3F3F8):** Used for large grouped areas.
- **Primary Content (`surface-container-lowest` #FFFFFF):** Reserved for interactive cards and primary data inputs.
- **Elevated Interactive (`surface-bright` #F9F9FE):** For floating elements.

### Signature Textures
While the brand green is solid, secondary visual interest is created through **Glassmorphism**. Floating action buttons or navigation overlays should use a semi-transparent `surface` color with a `20px` backdrop blur. This ensures the "green" of the billiards world bleeds through the UI, making the app feel integrated into the environment.

---

## 3. Typography: The Authority Scale

We utilize the SF Pro style (Inter) to convey technical precision. The hierarchy is designed to highlight performance metrics first.

*   **Display (The Scoreboard):** `display-md` (2.75rem). Used for primary session percentages or high-level win rates. Tight letter spacing (-0.02em).
*   **Headline (The Drill):** `headline-sm` (1.5rem). Semi-bold. Used for drill titles.
*   **Title (The Detail):** `title-md` (1.125rem). Medium weight. Used for card headers.
*   **Body (The Guidance):** `body-md` (0.875rem). Regular weight. Used for coaching tips and drill descriptions.
*   **Label (The Metadata):** `label-sm` (0.6875rem). All-caps with +5% letter spacing. Used for technical specs (e.g., "CUE ANGLE", "SQUIRT OFFSET").

---

## 4. Elevation & Depth

We eschew traditional shadows in favor of **Tonal Layering**.

*   **The Layering Principle:** To lift a card, place a `surface-container-lowest` (#FFFFFF) element on a `surface-container-low` (#F3F3F8) background. This creates a "soft lift" that is easier on the eyes during long training sessions.
*   **Ambient Shadows:** For floating elements (like the Bottom Tab Bar), use a signature shadow: `0 8pt 24pt rgba(0,0,0,0.04)`. The shadow must be large and diffused, mimicking a soft overhead light.
*   **The Ghost Border:** If a distinction is absolutely required for accessibility, use `outline-variant` at **10% opacity**. Never use a high-contrast stroke.

---

## 5. Component Logic

### Navigation & Command
*   **Compact Navigation Bar:** Transparent background on scroll, transitioning to a `surface-container-lowest` blur. Title is `title-sm` centered.
*   **Bottom Tab Bar (5 Tabs):** A floating "island" or a grounded blur bar. Active state uses `primary` (#005129) for the icon and a 4pt dot indicator.
*   **Primary Action Button:** 12pt corner radius. Background: `primary` (#005129). Text: `on-primary` (#FFFFFF) in `title-sm`. No gradients.
*   **Secondary Action:** `surface-container-highest` background with `on-surface` text. This ensures it looks like a "tool" rather than a "call to action."

### Data & Performance
*   **Data Stat Cards:** White background (`surface-container-lowest`). Use the `label-sm` for the metric name and `display-sm` for the value. Forbid dividers; use 24pt of vertical padding to separate metric groups.
*   **Progress Bars:** 6pt height. Track: `surface-container-high`. Fill: `primary`. For "Success Rates," the fill can transition to `tertiary-fixed` (Gold) to denote mastery.
*   **Drill Badges:** Small, pill-shaped (`radius-full`). Background: `secondary-container`. Text: `on-secondary-container`. These categorize drills (e.g., "Side Pocket", "English").

---

## 6. Do’s and Don’ts

### Do
*   **Do** use asymmetrical margins. If the left margin is 24pt, try a 16pt right margin for data-heavy tables to create an editorial "lean."
*   **Do** use SF Symbols with "Medium" or "Semibold" weights to match the typography's authority.
*   **Do** prioritize "Negative Space." If a screen feels crowded, increase the background-to-surface ratio.

### Don’t
*   **Don’t** use dividers or "hairlines." If content needs to be separated, use a 8pt height `surface-container-low` spacer block instead.
*   **Don’t** use the Gold accent (`tertiary`) for primary actions. Gold is a reward color; it should be reserved for achievements, mastery levels, and "Pro" features.
*   **Don’t** use standard iOS "Blue" for links. All interactive elements must be `primary` green or `secondary` slate.