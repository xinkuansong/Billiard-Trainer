# Stitch Prompt — P2-03 Frame 1: ProfileView (Logged-in State)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C). Canvas width: 393px (iPhone 15 Pro). Light mode only.

## Screen: ProfileView — Personal Profile (Logged-in)

This is the "我的" (Profile/Me) tab root page. The logged-in user sees their avatar, nickname, Pro membership badge, training overview stats, and a grouped menu list for app settings and features. It follows the same tab root page layout pattern as the Training Home and Drill Library pages — large title navigation bar at top, 5-tab bar at bottom. The user is a Pro subscriber.

## Layout (top to bottom)

### 1. iOS Large Title Navigation Bar (Tab Root Page)

- This is a tab root page — use iOS native large title style
- Large title: "我的" (Me/Profile), 34pt Bold Rounded, color #000000, left-aligned
- Background: #F2F2F7 (same as page background, seamless)
- No right-side buttons in the navigation bar (settings are in the menu below)
- Standard iOS status bar above

### 2. User Header Card

- White (#FFFFFF) card background, corner radius 16pt, 16pt internal padding, 16pt horizontal margins
- 8pt below the large title area

**Card layout (horizontal, vertically centered):**
- **Left: Avatar** — 64pt circular photo placeholder (use a generic avatar with a slight green tint or a billiard-themed silhouette, round clipped)
- **Middle: User info** (12pt left gap from avatar, flex grow):
  - Nickname: "台球小王子" (Pool Prince), 20pt Semibold, color #000000
  - Below nickname (4pt gap): "修改信息" text button, 13pt Regular, color rgba(60,60,67,0.6), with SF Symbol "chevron.right" 10pt after text — tappable to edit profile
  - Below (4pt gap): "球迹 ID 2086753", 13pt Regular, color rgba(60,60,67,0.3)
- **Right: Pro Badge area** (fixed width, vertically centered):
  - Gold shield/crown icon: SF Symbol "crown.fill", 28pt, color #D4941A
  - Below icon (4pt gap): "Pro 会员" label, 12pt Bold, color #D4941A
  - Optional: tiny expiry hint "2027.04" in 10pt, color rgba(60,60,67,0.3)

### 3. Training Overview Stats Card

- White (#FFFFFF) card background, corner radius 12pt, 16pt internal padding, 16pt horizontal margins
- 12pt below the header card
- Section mini-title (optional): "本月概览" 13pt Semibold, color rgba(60,60,67,0.6), 4pt bottom margin inside card

**Stats row (3 items, horizontal, equal width, center-aligned):**
- Each stat block:
  - Large number: 22pt Bold, color #000000
  - Label below: 13pt Regular, color rgba(60,60,67,0.6)
  - Vertical thin divider line between stats (0.5pt, color rgba(60,60,67,0.12))

- Stat 1: "12" + "练习天数" (Practice Days)
- Stat 2: "8.5h" + "训练时长" (Training Hours)
- Stat 3: "7" + "连续打卡" (Streak Days)

### 4. Menu Section 1 — Features (White Card Group)

- White (#FFFFFF) card background, corner radius 12pt, 16pt horizontal margins
- 24pt top gap from stats card (new section)
- iOS insetGrouped list style — all rows within one continuous white card, separated by thin divider lines

**Rows (each row 52pt height, 16pt internal horizontal padding):**

**Row 1: "我的收藏" (My Favorites)**
- Left: circular icon background 30pt, fill color #FF6B6B (coral red), SF Symbol "heart.fill" 16pt white
- Label: "我的收藏", 17pt Regular, color #000000, 12pt left gap from icon
- Right: chevron "chevron.right" 14pt, color rgba(60,60,67,0.3)
- Thin divider below (0.5pt, color rgba(60,60,67,0.12)), inset 58pt from left (aligned after icon)

**Row 2: "个人信息" (Personal Info)**
- Left: circular icon background 30pt, fill color #5AC8FA (sky blue), SF Symbol "person.fill" 16pt white
- Label: "个人信息", right side: "中式八球 · L2 进阶" hint text 13pt color rgba(60,60,67,0.3) + chevron

**Row 3: "训练目标" (Training Goals)**
- Left: circular icon background 30pt, fill color #1A6B3C (brand green), SF Symbol "target" 16pt white
- Label: "训练目标", right side: "每周 4 天" hint text 13pt + chevron

**Row 4: "订阅管理" (Subscription)**
- Left: circular icon background 30pt, fill color #D4941A (gold), SF Symbol "crown.fill" 16pt white
- Label: "订阅管理", right side: "Pro 年度会员" hint text 13pt + chevron

### 5. Menu Section 2 — Settings (White Card Group)

- Same white card style as Section 1
- 24pt top gap from Menu Section 1

**Rows:**

**Row 1: "偏好设置" (Preferences)**
- Left: circular icon background 30pt, fill color #8E8E93 (gray), SF Symbol "gearshape.fill" 16pt white
- Label: "偏好设置" + chevron

**Row 2: "账号与安全" (Account & Security)**
- Left: circular icon background 30pt, fill color #007AFF (blue), SF Symbol "lock.shield.fill" 16pt white
- Label: "账号与安全" + chevron

**Row 3: "隐私政策" (Privacy Policy)**
- Left: circular icon background 30pt, fill color #34C759 (green), SF Symbol "hand.raised.fill" 16pt white
- Label: "隐私政策" + chevron

**Row 4: "关于与反馈" (About & Feedback)**
- Left: circular icon background 30pt, fill color #AF52DE (purple), SF Symbol "info.circle.fill" 16pt white
- Label: "关于与反馈" + chevron
- No divider below (last row in card)

### 6. Logout Button

- 24pt below Menu Section 2
- Center-aligned text button: "退出登录" (Log Out), 17pt Regular, color #C62828 (destructive red)
- No background, no border — text-only destructive action (Tier 3 level per button hierarchy)
- Below: version info "版本 1.0.0", 12pt Regular, color rgba(60,60,67,0.3), center-aligned, 8pt below logout

### 7. Bottom 5-Tab Bar

- Standard iOS tab bar, 5 tabs with icons + labels:
  - "训练" (Training): SF Symbol "figure.pool.swim" or crossed-cues icon, inactive gray
  - "动作库" (Drills): SF Symbol "books.vertical.fill", inactive gray
  - "角度" (Angles): SF Symbol "angle", inactive gray
  - "记录" (History): SF Symbol "clock.arrow.circlepath", inactive gray
  - "我的" (Me): SF Symbol "person.fill", **active state** — icon and label in brand green #1A6B3C
- Tab bar background: white with standard iOS top hairline separator
- Tab bar height: 49pt + 34pt safe area

## Design Tokens

- Primary brand color: #1A6B3C (billiard table green)
- Accent/Pro color: #D4941A (amber/gold)
- Destructive color: #C62828
- Page background: #F2F2F7
- Card background: #FFFFFF
- Text primary: #000000
- Text secondary: rgba(60,60,67,0.6)
- Text tertiary: rgba(60,60,67,0.3)
- Card corner radius: 12pt (menu cards), 16pt (header card)
- Menu icon circle size: 30pt
- Avatar size: 64pt circular
- Page horizontal padding: 16pt
- Card internal padding: 16pt
- Section gap: 24pt
- Row height: 52pt
- Minimum touch target: 44pt

## Reference Style

- This page follows the same profile/settings pattern as fitness training apps — avatar header at top, stats overview, then grouped menu lists
- Menu rows use colorful circular icon backgrounds (each icon has a unique color) similar to iOS Settings app and the reference training app (训记)
- The stats card uses a clean horizontal 3-column layout with vertical dividers, similar to the fitness app's monthly overview
- Pro badge prominently displayed next to avatar to reinforce subscription value
- Overall feel is organized, personal, and inviting — users feel ownership of their training journey

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- iOS native feel: SF Pro font family, SF Symbols icons throughout
- NO gradient fills on any element — all solid colors
- This IS a tab root page — show iOS large title "我的" and 5-tab bar at bottom
- "我的" tab should be the active/highlighted tab (green #1A6B3C)
- Minimum touch target: 44pt for all interactive elements
- Brand green #1A6B3C used sparingly — tab active state, training goals icon, Pro badge gold #D4941A
- Each menu icon has a DIFFERENT color background to provide visual variety
- Menu dividers inset from left to align after the icon (not full-width)
- All text in Simplified Chinese
- Show a realistic logged-in state with actual Chinese data

## State

Logged-in state with Pro subscription active. User has training data (12 practice days, 8.5 hours, 7-day streak this month). All menu items visible. The page content fits within one screen without scrolling (or minimal scroll).
