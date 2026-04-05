# Stitch Prompt — P2-05 Frame 2: PhoneLoginView (Phone Number Login)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode only.

## Screen: PhoneLoginView — Phone Number + Verification Code Login

This is a sub-page pushed from the LoginView sheet when the user taps "手机号登录". It presents a clean form for entering a phone number and SMS verification code. The navigation bar has a back arrow to return to the login options sheet. The design should feel simple and focused — only the essential inputs and one clear call-to-action.

## Layout (top to bottom)

### 1. Navigation Bar (Push Sub-page Style)
- Standard iOS navigation bar within the sheet context
- Left: back arrow "chevron.left" in brand green #1A6B3C (or system blue #007AFF), tappable to return to LoginView
- Center title: "手机号登录" 17pt Semibold, color #000000
- Right: empty (no right button)
- Thin bottom hairline separator: 0.5pt, color rgba(60,60,67,0.12)

### 2. Instructional Header
- 32pt below the navigation bar
- 24pt horizontal page padding
- Title: "输入手机号" (Enter Phone Number), 26pt Bold Rounded, color #000000, left-aligned
- Below (8pt gap): "我们将发送短信验证码到您的手机" (We'll send an SMS code to your phone), 15pt Regular, color rgba(60,60,67,0.6), left-aligned

### 3. Phone Number Input Area
- 32pt below the instruction text
- 24pt horizontal page padding

**Phone number field (horizontal layout, single row):**
- Left prefix section: "+86" text, 17pt Semibold, color #000000, inside a 60pt wide area with right border separator (0.5pt, color rgba(60,60,67,0.18), 12pt height centered), tappable dropdown hint with SF Symbol "chevron.down" 10pt after "+86" in rgba(60,60,67,0.3)
- Right input area (flex grow): TextField placeholder "请输入手机号" 17pt Regular, color rgba(60,60,67,0.3), left padding 12pt
- The entire row sits within a rounded input container: height 52pt, corner radius 12pt, background #F2F2F7 (light gray input field bg), 16pt horizontal internal padding
- When focused: 2pt border color #1A6B3C (brand green focus ring)

### 4. Verification Code Input Area
- 16pt below the phone number input
- 24pt horizontal page padding

**Verification code field (horizontal layout):**
- Left input area (flex grow): TextField placeholder "请输入验证码" 17pt Regular, color rgba(60,60,67,0.3)
- Right button: "发送验证码" text button, 15pt Semibold, color #1A6B3C (brand green), inside a compact pill/capsule: background rgba(26,107,60,0.1), corner radius 999pt (pill), horizontal padding 16pt, height 36pt
- The entire row sits within the same rounded input container style: height 52pt, corner radius 12pt, background #F2F2F7, 16pt horizontal internal padding
- **Countdown state note** (not shown in this frame but described for reference): after tapping "发送验证码", the button text changes to "60s" in gray rgba(60,60,67,0.3), disabled

### 5. Login Button
- 40pt below the verification code input
- 24pt horizontal page padding
- Full-width button (393 - 48 = 345pt wide), height 50pt
- **Disabled state** (shown in this frame — fields are empty): background rgba(60,60,67,0.12) (light gray), text "登录" 17pt Semibold, color rgba(60,60,67,0.3), corner radius 12pt
- **Enabled state** (when both fields have valid input): background #1A6B3C (brand green solid fill), text "登录" 17pt Semibold, color #FFFFFF, corner radius 12pt — BTButton primary style per A-02

### 6. Help Text
- 24pt below the login button
- Center-aligned: "收不到验证码？" (Can't receive the code?), 13pt Regular, color rgba(60,60,67,0.6), tappable text link
- Below (34pt padding to bottom safe area)

## Design Tokens

- Primary brand color: #1A6B3C (billiard table green)
- Input field background: #F2F2F7
- Input field focused border: #1A6B3C (2pt)
- Send code button tint: #1A6B3C
- Send code pill bg: rgba(26,107,60,0.1)
- Disabled button bg: rgba(60,60,67,0.12)
- Disabled button text: rgba(60,60,67,0.3)
- Sheet/page background: #FFFFFF
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Text tertiary: rgba(60,60,67,0.3)
- Input container height: 52pt
- Input container corner radius: 12pt
- Button height: 50pt
- Button corner radius: 12pt
- Page horizontal padding: 24pt
- Minimum touch target: 44pt

## Reference Style

- This phone login form follows the standard Chinese app phone login pattern — similar to what you'd see in WeChat, Alipay, or Meituan: a clear heading, phone number with country code prefix, separate verification code field with inline "send code" button, and a large login button
- The input field styling uses the iOS-native light gray rounded rectangle (similar to UITextField with .roundedRect border style)
- The "发送验证码" button is a compact pill inside the verification code field — this is a very common Chinese app UX pattern
- The disabled login button uses a muted gray to clearly signal that input is required before proceeding
- Overall feel: clean, straightforward, trustworthy — minimal visual noise so the user can focus on entering their credentials

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- This is a SUB-PAGE within the login sheet — show a navigation bar with back arrow, NOT a drag handle
- iOS native feel: SF Pro font family, SF Symbols icons
- NO gradient fills — all solid colors
- NO tab bar — this is a modal sub-page within the login sheet
- The login button should show DISABLED state (gray) in this frame since the input fields are empty
- The "+86" country code prefix must be visible and look tappable (with a small down chevron)
- The "发送验证码" pill button sits INSIDE the verification code input container (not outside)
- All text in Simplified Chinese
- The form should be vertically centered in the upper portion of the screen — generous white space below the form before the bottom of the screen
- Input fields should look like iOS system text fields — light gray rounded rectangles, clean and minimal

## State

Default state. Both input fields are empty (showing placeholder text). The login button is in disabled/gray state. The "发送验证码" button is in its default active state (green text, not yet tapped). No keyboard shown. No error messages.
