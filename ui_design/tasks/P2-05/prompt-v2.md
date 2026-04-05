# Stitch 修正指令 — P2-05 帧 1 v2 (LoginView)

> 在 Stitch 同一会话中发送以下修正消息：

Please make the following corrections to the LoginView screen:

## 1. All text must be in Simplified Chinese
Replace every English string:
- "The Precision Green" → "欢迎使用球迹"
- "Elevate your game with professional-grade billiards analytics." → "登录以同步你的训练数据"
- "Login with WeChat" → "微信登录"
- "Login with Phone Number" → "手机号登录"
- "Continue as Guest" → remove this button entirely
- "OR" separator → remove entirely
- "Skip for now" → "暂不登录，匿名使用"
- "BY SIGNING IN YOU AGREE TO OUR TERMS OF SERVICE AND PRIVACY POLICY" → two lines: "登录即表示您同意" then "用户协议 和 隐私政策" (12pt, gray, centered)
- Remove the "Master the Table / MASTER CLASS" decorative card entirely

## 2. Add Sign in with Apple button (FIRST in the list)
Insert a new button at the TOP of the button stack, above WeChat:
- Full-width, height 50pt, corner radius 12pt
- Solid BLACK (#000000) fill, NO gradient
- White Apple logo icon on the left + white text "通过 Apple 登录" (17pt Semibold)
- This follows Apple's official Sign in with Apple button style

## 3. Fix WeChat button color
- Change the WeChat button from the dark green gradient to WeChat's official brand green: solid fill #07C160, NO gradient
- White WeChat chat bubble icon + white text "微信登录"

## 4. Make it a Sheet modal
- Add a drag handle indicator at the very top: a centered pill shape, 36pt wide × 5pt tall, corner radius 2.5pt, color rgba(60,60,67,0.3), 8pt below the top edge
- The background should be white (#FFFFFF), not the gray surface color
- The sheet should have rounded top corners (suggest 12pt radius on top-left and top-right)

## 5. Fix button order and styling
The final button stack should be exactly 3 buttons, top to bottom:
1. **通过 Apple 登录** — solid black #000000, white text, 12pt corner radius
2. **微信登录** — solid WeChat green #07C160, white text, 12pt corner radius
3. **手机号登录** — white fill, 1.5pt border rgba(60,60,67,0.18), black text, 12pt corner radius

All buttons: 50pt height, 12pt corner radius (NOT 24pt pill shape), NO gradient on any button. Spacing between buttons: 12pt.

## 6. Remove all extra decorative elements
- Remove the "Master the Table / Master Class" promotional card with the background image
- Remove the "OR" divider line
- Remove the "Continue as Guest" button (the "暂不登录" text link at the bottom replaces it)

## 7. Keep the brand header clean
- App icon: keep the rounded square icon but make sure it uses brand green #1A6B3C (not #00522a)
- Below icon: "欢迎使用球迹" in 26pt Bold, black, centered
- Below that: "登录以同步你的训练数据" in 15pt Regular, gray rgba(60,60,67,0.6), centered

The final layout from top to bottom should be:
1. Drag handle (sheet indicator)
2. App icon (72pt)
3. "欢迎使用球迹" title
4. "登录以同步你的训练数据" subtitle
5. Apple login button (black)
6. WeChat login button (#07C160 green)
7. Phone login button (outlined)
8. "暂不登录，匿名使用" subtle gray text link
9. Legal text footer (tiny gray text)

Nothing else. Clean, minimal, focused.
