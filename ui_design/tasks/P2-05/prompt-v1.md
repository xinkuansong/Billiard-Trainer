# Stitch Prompt — P2-05 Frame 1: LoginView (Login Options)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode only.

## Screen: LoginView — Login Options Sheet

This is a modal sheet that slides up when the user taps "登录已有账号" from the Onboarding welcome page, or taps the guest avatar area in ProfileView. It presents three login methods: Sign in with Apple, WeChat login, and phone number login. The sheet also provides a "skip" option for anonymous use. The design should feel clean, trustworthy, and simple — login is not the main attraction of the app, it should be quick and frictionless.

## Layout (top to bottom)

### 1. Sheet Drag Handle
- Standard iOS sheet drag indicator: 36pt wide × 5pt tall, centered horizontally, corner radius 2.5pt (pill), color rgba(60,60,67,0.3)
- 8pt below the top of the sheet

### 2. Brand Header Area (centered)
- 40pt below the drag handle
- **App Icon**: 72pt × 72pt rounded square (20pt corner radius, matching iOS app icon shape), showing a billiard ball design — green (#1A6B3C) background with a white stylized cue ball and subtle cue stick motif, centered horizontally
- Below icon (20pt gap): "欢迎使用球迹" (Welcome to QiuJi), 26pt Bold Rounded, color #000000, centered
- Below title (8pt gap): "登录以同步你的训练数据" (Log in to sync your training data), 15pt Regular, color rgba(60,60,67,0.6), centered

### 3. Login Buttons Section
- 48pt below the subtitle
- 24pt horizontal page padding (slightly wider than normal to make buttons narrower and more elegant)
- All buttons are full-width within the padded area (393 - 48 = 345pt wide), height 50pt each
- Button spacing: 12pt between each button

**Button 1: Sign in with Apple**
- Apple system-style button: solid black (#000000) fill, corner radius 12pt
- Left of center: Apple logo (white,  SF Symbol "apple.logo" 20pt), 8pt right gap, then text "通过 Apple 登录" 17pt Semibold, color #FFFFFF
- This should look like the standard ASAuthorizationAppleIDButton — black filled, rounded rectangle

**Button 2: WeChat Login (微信登录)**
- Solid fill: WeChat brand green #07C160, corner radius 12pt
- Left of center: WeChat icon (white, a simplified WeChat chat bubble icon 20pt), 8pt right gap, then text "微信登录" 17pt Semibold, color #FFFFFF

**Button 3: Phone Number Login (手机号登录)**
- Outlined style: white (#FFFFFF) fill background, 1.5pt border color rgba(60,60,67,0.18), corner radius 12pt
- Left of center: SF Symbol "phone.fill" 20pt, color #000000, 8pt right gap, then text "手机号登录" 17pt Semibold, color #000000
- This is the lightest of the three buttons — it is a tertiary option that pushes to PhoneLoginView

### 4. Skip Option
- 32pt below the last button
- Center-aligned text: "暂不登录，匿名使用" (Skip, use anonymously), 15pt Regular, color rgba(60,60,67,0.6)
- No background, no border — subtle text link (Tier 3 per A-02 button hierarchy)
- Minimum touch target: 44pt height

### 5. Legal Text Footer
- Pinned to the bottom of the sheet content, 24pt below the skip option
- Center-aligned two-line text block:
  - Line 1: "登录即表示您同意" 12pt Regular, color rgba(60,60,67,0.3)
  - Line 2: "用户协议" (underlined, color rgba(60,60,67,0.6)) + " 和 " + "隐私政策" (underlined, color rgba(60,60,67,0.6)), 12pt Regular
- 34pt bottom padding to home indicator safe area

## Design Tokens

- Primary brand color: #1A6B3C (billiard table green)
- Apple button fill: #000000
- WeChat button fill: #07C160
- Phone button border: rgba(60,60,67,0.18)
- Page/sheet background: #FFFFFF (white sheet)
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Text tertiary: rgba(60,60,67,0.3)
- Button corner radius: 12pt
- Button height: 50pt
- Button spacing: 12pt
- Page horizontal padding: 24pt
- App icon size: 72pt
- Minimum touch target: 44pt

## Reference Style

- This login sheet follows the standard iOS modal login pattern seen in apps like WeChat, Alipay, and various Chinese lifestyle apps — centered brand logo at top, stacked social login buttons in the middle, skip/anonymous option at bottom
- Sign in with Apple follows Apple's official HIG guidelines for the button appearance (black filled, system font, Apple logo)
- The WeChat button uses WeChat's official brand green (#07C160) — this is a widely recognized Chinese social login method
- The phone login button is intentionally the lightest (outlined) to visually indicate it's a fallback option requiring more effort
- The overall feel should be trustworthy, minimal, and quick — users should feel they can log in with one tap or skip entirely
- Style consistency: the sheet background is white, the brand header area creates vertical breathing space, and the button stack is compact and decisive

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- This is a SHEET modal (not a full page) — show the top drag handle indicator, white background, rounded top corners
- iOS native feel: SF Pro font family, SF Symbols icons
- NO gradient fills — all solid color buttons
- NO navigation bar, NO tab bar — this is a modal sheet
- Sign in with Apple button MUST be black filled (Apple HIG requirement)
- WeChat button MUST use WeChat green #07C160 (brand guideline)
- The three login buttons should have clear visual hierarchy: Apple (black/dark) > WeChat (green) > Phone (outlined/light)
- The "skip" link must be subtle and not compete with the login buttons
- All text in Simplified Chinese
- The sheet should contain all content without scrolling — compact but not cramped
- Do NOT show the underlying page behind the sheet — design the sheet as a standalone screen

## State

Default state. No input, no loading. The user has just opened the login sheet and sees three options plus a skip link. No error messages, no previous login data.
