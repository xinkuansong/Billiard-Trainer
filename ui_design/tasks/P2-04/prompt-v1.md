# Stitch Prompt — P2-04: OnboardingView (First Launch Welcome)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode only.

## Screen: OnboardingView — First Launch Welcome

This is the very first screen a new user sees when opening QiuJi for the first time. It serves as a feature showcase and brand introduction — similar to Apple's standard onboarding pattern (like the Welcome screen in Apple Health or Fitness apps). The page has a hero brand area at top, three feature highlight rows in the middle, and action buttons at the bottom. There is NO navigation bar and NO tab bar — this is a full-screen standalone welcome page.

## Layout (top to bottom)

### 1. Status Bar Area
- Standard iOS status bar (time, signal, battery)
- Transparent over the page background

### 2. Hero Brand Area (centered, upper portion of screen)
- Top spacing: approximately 100pt from the top of the safe area, vertically balanced so the hero sits in the upper third
- **App Icon / Logo**: a stylized billiard ball or cue icon, rendered as a large 80pt circular graphic — use a white billiard ball with a green (#1A6B3C) stripe/accent on a subtle soft shadow, centered horizontally
- Below icon (16pt gap): App name "球迹" in 34pt Bold Rounded, color #000000, centered
- Below app name (8pt gap): Tagline "你的台球训练伙伴" (Your Billiard Training Companion), 17pt Regular, color rgba(60,60,67,0.6), centered

### 3. Feature Highlights Section (3 rows)
- 40pt below the tagline
- Each row is a horizontal layout, left-aligned, with 16pt horizontal page padding
- Row spacing: 24pt between rows

**Feature Row 1: 动作库与训练记录 (Drill Library & Training Logs)**
- Left: SF Symbol "figure.pool.swim" (or "dumbbell.fill" if unavailable) in 28pt, color #1A6B3C, placed inside a 48pt × 48pt circle with background color rgba(26,107,60,0.1)
- Right text block (16pt left gap from icon circle):
  - Title: "动作库与训练记录" 17pt Semibold, color #000000
  - Subtitle (4pt below): "海量台球练习动作，轻松记录每次训练" 15pt Regular, color rgba(60,60,67,0.6)

**Feature Row 2: 角度训练 (Angle Training)**
- Left: SF Symbol "angle" in 28pt, color #1A6B3C, inside same 48pt circle with rgba(26,107,60,0.1) background
- Right text block:
  - Title: "角度训练" 17pt Semibold, color #000000
  - Subtitle: "模拟球台场景，提升角度判断力" 15pt Regular, color rgba(60,60,67,0.6)

**Feature Row 3: 数据统计与复盘 (Stats & Review)**
- Left: SF Symbol "chart.bar.fill" in 28pt, color #1A6B3C, inside same 48pt circle with rgba(26,107,60,0.1) background
- Right text block:
  - Title: "数据统计与复盘" 17pt Semibold, color #000000
  - Subtitle: "可视化训练进度，发现薄弱环节" 15pt Regular, color rgba(60,60,67,0.6)

### 4. Bottom Action Area (pinned to bottom safe area)
- This section sits at the bottom of the screen, above the home indicator safe area
- 16pt horizontal page padding

**Primary Button: "开始使用" (Get Started)**
- Full-width button (393 - 32 = 361pt wide), height 50pt
- Background fill: #1A6B3C (brand green, solid, NO gradient)
- Text: "开始使用" 17pt Semibold, color #FFFFFF, centered
- Corner radius: 12pt
- This follows the BTButton primary style established in A-02

**Text Link: "登录已有账号" (Log in to existing account)**
- 16pt below the primary button
- Center-aligned text: "登录已有账号" 15pt Regular, color rgba(60,60,67,0.6)
- No background, no border — subtle text link (Tier 3 per A-02 button hierarchy)
- 34pt bottom padding to home indicator safe area

## Design Tokens

- Primary brand color: #1A6B3C (billiard table green)
- Page background: #F2F2F7
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Feature icon tint: #1A6B3C
- Feature icon circle bg: rgba(26,107,60,0.1)
- Feature icon circle size: 48pt
- Button fill: #1A6B3C
- Button text: #FFFFFF
- Button corner radius: 12pt
- Button height: 50pt
- Page horizontal padding: 16pt
- Feature row gap: 24pt
- Minimum touch target: 44pt

## Reference Style

- Follow the Apple-standard onboarding pattern seen in iOS native apps (Apple Health, Apple Fitness, WhatsApp) — large centered logo/icon at top, feature rows with icon + text in middle, CTA button at bottom
- The reference training app (训记) uses a minimalist splash with just the brand name and a poetic tagline — QiuJi's onboarding is more functional, showcasing three core features to set user expectations
- The feature icon circles with light green tinted background are inspired by Apple's onboarding screens (SF Symbol in colored circle + title/subtitle)
- Overall tone: welcoming, clean, professional, confident — the user should feel this is a well-crafted tool for serious billiard practice

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- iOS native feel: SF Pro font family, SF Symbols icons
- NO navigation bar, NO tab bar — this is a standalone full-screen onboarding page
- NO gradient fills — all solid colors
- NO page-scrolling — all content must fit in a single screen viewport
- The primary button ("开始使用") must use solid brand green #1A6B3C fill with white text (BTButton primary style from A-02)
- The "登录已有账号" link must be subtle/understated — it is NOT a primary action
- All 3 feature icons use the SAME green color #1A6B3C — do NOT use different colors per icon (unlike the Settings menu; this is a cohesive brand introduction)
- All text in Simplified Chinese
- The hero area should feel spacious — generous top padding so the logo sits in the upper-third of the screen, not cramped at the very top
- This page should feel like an Apple-designed welcome screen — minimal, elegant, focused

## State

Default state. First-time launch. No user data, no login state. Single static screen — no pagination dots or swipe gestures.
