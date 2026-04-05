# Design System Document

## 1. Overview & Creative North Star
The design system for QiuJi (球迹) is built upon the Creative North Star: **"The Disciplined Athlete."** It moves beyond the utility of a standard tracker to create a high-fidelity, editorial experience that mirrors the focus and precision of professional billiards. 

This system rejects "template" aesthetics. Instead of flat layouts and rigid grids, it utilizes intentional asymmetry, tonal depth, and a sophisticated layering strategy. We treat the iOS interface as a tactile training environment where every element feels earned, premium, and intentional. By leveraging the contrast between the deep `primary` (Billiard Green) and the elite `secondary` (Amber Gold), we establish a visual hierarchy that communicates mastery and pro-level performance.

---

## 2. Colors
Our palette is rooted in the heritage of the sport but executed through a modern, digital-first lens.

*   **Primary (#005129 / #1A6B3C):** Use for high-action areas and status indicators. It represents the "felt" and the ground truth of training.
*   **Secondary/Pro (#D4941A / #805600):** Reserved exclusively for "Pro" status indicators and elite achievement markers. It should be used sparingly to maintain its value.
*   **Surface Hierarchy (The Foundation):**
    *   `surface`: The base layer (#f9f9fe).
    *   `surface-container-low`: Used for secondary grouping.
    *   `surface-container-highest`: Used for active card states or elevated modules.

### The "No-Line" Rule
**Explicit Instruction:** Do not use 1px solid borders for sectioning. Boundaries must be defined solely through background color shifts. For example, a training module card (`surface_container_lowest`) should sit on a `surface_container` background to define its edges. Natural tonal transitions create a more sophisticated, "breathable" interface than structural lines ever could.

### The "Glass & Gradient" Rule
To elevate CTAs and floating elements beyond standard iOS buttons, use subtle linear gradients. A transition from `primary` to `primary_container` adds "visual soul" and depth. For floating navigation or action sheets, apply Glassmorphism: use a semi-transparent `surface` color with a 20pt-30pt backdrop blur to integrate the element into the environment.

---

## 3. Typography
We utilize the **SF Pro** family, optimized for high-readability and editorial authority.

*   **Display & Headlines:** Use `display-sm` or `headline-lg` for category titles (e.g., "动作库"). These should feel bold and anchored, providing a strong starting point for the eye.
*   **Titles:** `title-md` and `title-sm` are the workhorses for card titles and training names. They carry a medium-to-semibold weight to ensure they command attention.
*   **Body & Labels:** `body-md` is for instructional text. `label-sm` is reserved for metadata (e.g., "推荐 4 组") and the L0-L3 badges.

**Editorial Tip:** Use "intentional white space" between typography blocks rather than dividers. Increasing the leading (line height) on body text enhances the premium feel and reduces visual clutter during intense training sessions.

---

## 4. Elevation & Depth
Hierarchy in this system is achieved through **Tonal Layering** rather than traditional drop shadows.

*   **The Layering Principle:** Stack surfaces from lowest to highest. A `surface_container_lowest` card placed on a `surface_container_low` background creates a soft, natural lift. This mimics fine paper or layered glass.
*   **Ambient Shadows:** If a card requires a "floating" effect, use an extra-diffused shadow. 
    *   *Settings:* Blur: 24pt, Opacity: 6%, Color: A tinted version of `on_surface`. Avoid generic black/grey shadows.
*   **The "Ghost Border" Fallback:** If accessibility requirements demand a border, use the `outline_variant` token at **15% opacity**. A 100% opaque border is strictly prohibited as it flattens the design.

---

## 5. Components

### Cards & Training Modules
*   **Radius:** 12pt (Standard Card) / 10pt (Thumbnail).
*   **Layout:** Forbid divider lines. Use vertical spacing (`spacing-md`) to separate content within the card.
*   **Thumbnails:** Fixed 72x72pt. Use a 10pt corner radius to create a "squircle" feel that complements the card's 12pt radius.

### Badges & Capsules
*   **Difficulty (L0-L3):** Use `primary_container` backgrounds with `on_primary_container` text. These should be rectangular with a small (4pt) radius to feel "technical."
*   **Pro Status:** Use `secondary_fixed_dim` (Amber) for the capsule background. Use a fully rounded pill shape (`999px`) to distinguish "status" from "difficulty."

### Buttons
*   **Primary CTA:** Gradient of `primary` to `primary_container`. 12pt radius.
*   **Filter Chips:** Use `surface_container_highest` for unselected states. For selected states, use `on_background` (Black) with `surface` text to create high-contrast "impact" points, as seen in professional training layouts.

### Navigation
*   **Bottom Tab Bar:** Use a Glassmorphic effect (Backdrop blur) with a `surface_container_lowest` tint at 80% opacity. 
*   **Indicator:** Use a simple `primary` dot below the active icon rather than a full background highlight to maintain a clean, airy feel.

---

## 6. Do's and Don'ts

### Do:
*   **Do** use asymmetrical spacing to create visual interest.
*   **Do** rely on font weight and color (e.g., `on_surface_variant` for metadata) to create hierarchy.
*   **Do** ensure all interactive elements have a minimum hit target of 44x44pt, even if the visual asset is smaller.
*   **Do** use the `surface_container` tiers to group related training drills without adding lines.

### Don't:
*   **Don't** use 1px dividers between list items. Use 12pt-16pt of vertical white space instead.
*   **Don't** use pure black (#000000) for text. Use `on_background` (#1a1c1f) for a softer, more premium look.
*   **Don't** use high-contrast, opaque borders around cards. Let the background tone do the work.
*   **Don't** clutter the screen with icons. Use SF Symbols only where they provide immediate functional clarity.