# Stitch Prompt — P0-08: TrainingNoteView (v1)

## App Context

QiuJi (球迹) — a billiard/pool training iOS app. iOS native design using SF Pro fonts, SF Symbols icons, and system-level styling. Clean, professional sports-training aesthetic with billiard table green (#1A6B3C) as the brand color.

## Screen: TrainingNoteView — Training Note (Empty Input State)

This is a full-screen note-taking page that appears after the user finishes all training drills. The user can write down training thoughts, technique notes, or skip to proceed to the training summary. This is a transitional page in the training flow, presented without keyboard visible, showing the complete layout with bottom action buttons.

## Layout (top to bottom)

1. **Status Bar**: Standard iOS status bar (time, signal, battery) at the very top.

2. **Back Capsule Button** (top-left, below status bar):
   - A pill-shaped button with text "返回" (Back)
   - Background: #000000 with ~0.06 opacity (very light gray fill), border: 1px solid rgba(0,0,0,0.1)
   - Text: 17pt Regular, color #000000
   - Corner radius: 999pt (full pill shape)
   - Padding: 8pt vertical, 16pt horizontal
   - Positioned 16pt from left edge, 8pt below safe area

3. **Hint Text Section** (below back button, 16pt top margin):
   - Two lines of gray placeholder/guide text, left-aligned, 16pt horizontal padding
   - Line 1: "1、您可以输入一些今天的训练感悟" — 13pt Regular, color rgba(60,60,67,0.6)
   - Line 2: "2、还可以记录需要注意的技术要点" — 13pt Regular, color rgba(60,60,67,0.6)
   - Line spacing: 6pt between the two lines

4. **Text Editor Area** (fills remaining vertical space):
   - A large empty text input area spanning the full width (16pt horizontal padding)
   - No visible border — just an open writing canvas
   - Background: matches page background #F2F2F7
   - This area takes up most of the screen, providing ample space for writing
   - No placeholder text inside the editor (the hint text above serves as the guide)

5. **Bottom Action Bar** (fixed at bottom, above safe area):
   - Background: transparent (no separate bar background)
   - Horizontal layout with two buttons, 16pt horizontal padding, 16pt bottom margin above safe area
   - **Left — "跳过" (Skip) button**:
     - Text-only button (no background, no border)
     - Text: "跳过", 17pt Regular, color rgba(60,60,67,0.6) (gray, Tier 3 per A-02 button hierarchy)
     - Minimum touch target: 44pt
   - **Right — "完成" (Done) button**:
     - Filled primary button using established BTButton primary style
     - Background: #1A6B3C (brand green)
     - Text: "完成", 17pt Semibold, color #FFFFFF
     - Corner radius: 12pt
     - Padding: 12pt vertical, 32pt horizontal
     - Minimum touch target: 44pt

6. **No Bottom Tab Bar**: This is an immersive flow page within the training session. No tab bar at the bottom.

## Design Tokens

- Primary / Brand green: #1A6B3C
- Page background: #F2F2F7
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6) — iOS secondaryLabel
- Card/surface white: #FFFFFF
- Button corner radius: 12pt
- Pill corner radius: 999pt
- Standard horizontal padding: 16pt
- Minimum touch target: 44pt

## Reference Style

- Reference a fitness tracking app's training-note screen: a minimal full-screen note page with a back capsule at top-left, two lines of numbered hint text in gray, a large open text area taking up most of the screen, and skip/done action buttons at the bottom.
- The overall feel should be calm and focused — this is a moment of reflection after an intense training session. Keep the design minimal with plenty of white space.
- The back button uses a subtle pill/capsule shape similar to the reference app's navigation style.

## Constraints

- iOS native feel (SF Pro font family, SF Symbols icons)
- Minimum touch target: 44pt for all interactive elements
- Primary "完成" button at bottom-right (thumb zone, easy to reach)
- Brand color: billiard table green (#1A6B3C) — only used for the primary button
- No keyboard shown — display the full page layout in empty/idle state
- Keep the page extremely simple and clean — this is a note-taking page, not a feature-rich screen
- This page should be consistent with P0-01 through P0-07 in visual style

## State

Empty input state — no text has been entered yet. The text editor area is blank. The hint text above the editor provides guidance. The keyboard is NOT visible (showing the complete page layout with bottom action buttons).
