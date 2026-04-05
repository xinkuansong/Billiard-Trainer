# Stitch Prompt — P2-03 Frame 2: ProfileView (Guest State)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode only.

## Screen: ProfileView — Personal Profile (Guest / Not Logged In)

This is the "我的" (Profile/Me) tab root page in **guest mode** — the user has not logged in. The header shows a default placeholder avatar with a "点击登录" prompt instead of a real profile. A warning banner reminds the user their data won't be synced. A Pro promotion card encourages upgrading. The menu list below is the same structure as logged-in but with adjusted right-side hints. A prominent "登录 / 注册" primary button replaces the "退出登录" button.

## Layout (top to bottom)

### 1. iOS Large Title Navigation Bar (Tab Root Page)

- Tab root page — iOS native large title style (identical to Frame 1)
- Large title: "我的" (Me/Profile), 34pt Bold Rounded, color #000000, left-aligned
- Background: #F2F2F7 (seamless with page)
- Standard iOS status bar above

### 2. Guest Header Card

- White (#FFFFFF) card background, corner radius 16pt, 16pt internal padding, 16pt horizontal margins
- 8pt below the large title area

**Card layout (horizontal, vertically centered):**
- **Left: Default Avatar** — 64pt circular placeholder, solid light gray fill #E5E5EA, centered SF Symbol "person.fill" 28pt, color #8E8E93 (system gray)
- **Middle: Guest info** (12pt left gap from avatar, flex grow):
  - "点击登录" (Tap to Log In), 20pt Semibold, color #1A6B3C (brand green, indicating tappable)
  - Below (4pt gap): "游客模式" (Guest Mode), 13pt Regular, color rgba(60,60,67,0.6)
- **Right: No Pro badge** — empty space (guest has no Pro status)

### 3. Guest Warning Banner

- Light amber/warm background card: fill color rgba(212,148,26,0.08) (very light gold tint), corner radius 12pt, 16pt internal padding, 16pt horizontal margins
- 12pt below the header card
- Left: SF Symbol "exclamationmark.triangle.fill" 20pt, color #D4941A (amber)
- Text (12pt left gap from icon, flex): "游客模式下训练数据不会同步到云端，请尽快登录以保存您的练球记录。" (Guest mode data not synced, please log in to save.), 14pt Regular, color rgba(60,60,67,0.8), multi-line wrap
- Minimum height: 52pt, vertically center content if single line

### 4. Pro Promotion Card

- Dark card background: #1C1C1E (near-black), corner radius 16pt, 16pt internal padding, 16pt horizontal margins
- 12pt below the warning banner
- Height: ~120pt

**Card layout:**
- **Left side (text content):**
  - "解锁球迹 Pro" (Unlock QiuJi Pro), 20pt Bold, color #FFFFFF
  - Below (6pt gap): "让你的训练更高效" (Make your training more effective), 14pt Regular, color rgba(255,255,255,0.7)
  - Below (12pt gap): "了解更多 ›" text link, 14pt Semibold, color #D4941A (gold)

- **Right side (visual):**
  - Decorative billiard-themed illustration: a stylized gold crown or trophy icon, SF Symbol "crown.fill" 48pt, color #D4941A, with subtle glow/shadow effect
  - Or abstract billiard balls arrangement in muted gold/white tones
  - Positioned at right edge, vertically centered

- The entire card is tappable → navigates to SubscriptionView

### 5. Menu Section 1 — Features (White Card Group)

- Same white card style as Frame 1 logged-in version
- 24pt top gap from Pro promotion card

**Rows (same icon colors and style as Frame 1):**

**Row 1: "我的收藏" (My Favorites)**
- Left: circular 30pt, fill #FF6B6B, SF Symbol "heart.fill" 16pt white
- Label + chevron (same as Frame 1)

**Row 2: "个人信息" (Personal Info)**
- Left: circular 30pt, fill #5AC8FA, SF Symbol "person.fill" 16pt white
- Label: "个人信息", right hint: "未设置" (Not Set) in 13pt rgba(60,60,67,0.3) + chevron

**Row 3: "训练目标" (Training Goals)**
- Left: circular 30pt, fill #1A6B3C, SF Symbol "target" 16pt white
- Label: "训练目标", right hint: "未设置" + chevron

**Row 4: "订阅管理" (Subscription)**
- Left: circular 30pt, fill #D4941A, SF Symbol "crown.fill" 16pt white
- Label: "订阅管理", right hint: "升级 Pro" in 13pt color #D4941A (gold highlight to attract attention) + chevron

### 6. Menu Section 2 — Settings (White Card Group)

- Same style as Frame 1
- 24pt top gap

**Rows (identical to Frame 1):**
- "偏好设置": gray icon #8E8E93, gearshape.fill + chevron
- "隐私政策": green icon #34C759, hand.raised.fill + chevron
- "关于与反馈": purple icon #AF52DE, info.circle.fill + chevron
- Note: "账号与安全" row can be omitted for guest (no account yet), or kept with "未登录" hint

### 7. Login Button

- 24pt below Menu Section 2
- Full-width primary button (16pt horizontal margins):
  - Background: #1A6B3C (brand green), corner radius 12pt
  - Height: 50pt
  - Text: "登录 / 注册" (Log In / Sign Up), 17pt Semibold, color #FFFFFF, center-aligned
  - This is the Tier 1 primary action button
- Below: "跳过，以游客身份继续" (Skip, continue as guest), 13pt Regular, color rgba(60,60,67,0.6), center-aligned, 12pt below button — text link (already in guest mode, this just dismisses the prompt)

### 8. Bottom 5-Tab Bar

- Same 5-tab bar as Frame 1:
  - "训练", "动作库", "角度", "记录" — all inactive gray
  - "我的" — **active state**, icon and label in brand green #1A6B3C
- Tab bar background: white, standard iOS hairline separator
- Tab bar height: 49pt + 34pt safe area

## Design Tokens

- Primary brand color: #1A6B3C (billiard table green)
- Accent/Pro color: #D4941A (amber/gold)
- Destructive color: #C62828 (not used in this frame)
- Page background: #F2F2F7
- Card background: #FFFFFF
- Dark card background: #1C1C1E
- Warning banner background: rgba(212,148,26,0.08)
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Text tertiary: rgba(60,60,67,0.3)
- Text on dark: #FFFFFF
- Card corner radius: 12pt (menu cards), 16pt (header/promo cards)
- Menu icon circle size: 30pt
- Avatar placeholder size: 64pt circular
- Page horizontal padding: 16pt
- Card internal padding: 16pt
- Section gap: 24pt
- Row height: 52pt
- Login button height: 50pt
- Minimum touch target: 44pt

## Reference Style

- Guest state follows the same reference fitness app (训记) pattern: default avatar with login prompt replaces the real avatar area
- The warning banner is similar to the reference app's amber/yellow tip card reminding guests about data loss
- The Pro promotion card uses a dark background with gold accents, similar to the reference app's "成为训记 PRO." dark promotional card
- Menu structure remains the same but with "未设置" hints and "升级 Pro" gold text to guide the guest toward account creation and subscription
- The prominent green login button at the bottom follows the established primary CTA pattern (same style as "开始训练" button in TrainingHomeView)

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- iOS native feel: SF Pro font family, SF Symbols icons throughout
- NO gradient fills on any element — all solid colors
- This IS a tab root page — show iOS large title "我的" and 5-tab bar at bottom
- "我的" tab is the active/highlighted tab (green #1A6B3C)
- Minimum touch target: 44pt for all interactive elements
- Guest header "点击登录" text in brand green #1A6B3C to signal it's tappable
- Pro promotion card should be visually striking — dark background + gold accents create contrast against the light page
- Warning banner uses very light gold tint, not aggressive red — it's informative, not alarming
- Menu icons use the SAME colors as the logged-in state for consistency
- All text in Simplified Chinese
- The page may scroll slightly — login button should still be reachable

## State

Guest state (not logged in). No user data. Default placeholder avatar. Warning banner visible. Pro promotion card prominent. Menu items show "未设置" for personal data fields and "升级 Pro" for subscription. Login/register primary CTA at bottom.
