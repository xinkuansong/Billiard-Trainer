# Stitch Prompt — P2-06: SubscriptionView (Pro Paywall)

## App Context

QiuJi (球迹) is a billiard/pool training tracker iOS app. Design a single mobile screen in iOS native style using SF Pro font family and SF Symbols icons. The brand identity centers on billiard table green (#1A6B3C) with amber/gold (#D4941A) for Pro/premium elements. Canvas width: 393px (iPhone 15 Pro). This screen uses a DARK theme — it is a full-screen paywall with a near-black background.

## Screen: SubscriptionView — Pro Subscription Paywall

This is the full-screen Pro upgrade paywall — the final destination when a user taps any "unlock Pro" or "upgrade" entry point throughout the app (from locked Drill details, locked statistics, the profile subscription menu, or the guest profile Pro promotion card). It uses a dark theme (#111111 background) to create a premium, immersive feel — contrasting with the app's normal light UI. The page showcases Pro features and presents three pricing tiers. The annual plan is selected by default as the recommended option.

## Layout (top to bottom)

### 1. Status Bar Area
- Standard iOS status bar (time, signal, battery) in WHITE text — this is a dark-background page
- No special treatment — the dark background (#111111) extends behind the status bar

### 2. Close Button (top-left)
- Position: top-left corner, 16pt from left edge, aligned with the safe area top
- White "✕" icon (SF Symbol "xmark"), 16pt size, inside a 32pt × 32pt circular touch area
- Color: #FFFFFF at 70% opacity (rgba(255,255,255,0.7))
- Minimum touch target: 44pt

### 3. Brand Hero Area (centered)
- 24pt below the close button
- **App Logo**: a large 72pt circular graphic — a stylized billiard ball icon with green (#1A6B3C) accent on dark background, centered horizontally. The logo should feel premium and polished against the dark backdrop.
- Below logo (20pt gap): Title text in two parts, centered:
  - "解锁球迹" in 26pt Bold Rounded, color #FFFFFF
  - " Pro" appended in the same line, 26pt Bold Rounded, color #D4941A (amber/gold)
  - Together they read: "解锁球迹 Pro"
- Below title (12pt gap): Three lines of brand copy, centered, each line 15pt Regular, color rgba(255,255,255,0.5):
  - Line 1: "72 个专业台球训练动作"
  - Line 2: "完整数据统计与趋势分析"
  - Line 3: "释放你的全部训练潜力"

### 4. Pro Feature List (6 numbered items)
- 32pt below the brand copy
- 20pt horizontal page padding
- Vertical list of 6 feature items, spacing 16pt between items
- Each item is a horizontal row:
  - Left: circled number badge — 28pt circle, border 1.5pt #D4941A (amber), number inside in 14pt Bold, color #D4941A, centered
  - 14pt gap after the number circle
  - Middle text block:
    - Feature name: 16pt Semibold, color #FFFFFF
    - Feature description (4pt below): 13pt Regular, color rgba(255,255,255,0.45)
  - Right: SF Symbol "chevron.right" 12pt, color rgba(255,255,255,0.25), vertically centered

**The 6 features:**
1. Name: "完整动作库" / Description: "解锁全部 72 个训练动作"
2. Name: "统计与趋势图表" / Description: "可视化你的训练进度"
3. Name: "自定义训练计划" / Description: "打造你的专属训练方案"
4. Name: "无限角度测试" / Description: "不限次数提升角度感知"
5. Name: "训练分享卡全样式" / Description: "所有配色主题与分享模版"
6. Name: "云端同步" / Description: "多设备数据无缝同步"

### 5. Pricing Cards Row (bottom CTA zone, fixed)
- This section is anchored to the bottom portion of the screen
- 32pt above the subscribe button
- 16pt horizontal page padding
- Three pricing cards arranged horizontally, equally spaced (3 cards filling the width with 8pt gaps between them)
- Each card width: approximately (393 - 32 - 16) / 3 ≈ 115pt
- Each card height: approximately 100pt
- Card corner radius: 12pt
- Card background: rgba(255,255,255,0.06) (very subtle light overlay on dark)

**Card 1: Monthly (月订阅)**
- Border: 1.5pt rgba(255,255,255,0.15) (subtle gray)
- Top label: "月订阅" 12pt Regular, color rgba(255,255,255,0.5), centered
- Price: "¥18" 24pt Bold, color #FFFFFF, centered
- Sub-label: "/月" 12pt Regular, color rgba(255,255,255,0.4), appended after price

**Card 2: Annual (年订阅) — DEFAULT SELECTED / RECOMMENDED**
- Border: 2pt solid #1A6B3C (brand green) — this card is highlighted
- Background: rgba(26,107,60,0.12) (very subtle green tint)
- **Recommended badge**: a small pill label at the top edge of the card, overlapping the border — background #1A6B3C, text "推荐" 10pt Bold, color #FFFFFF, pill shape (corner radius 999pt), horizontally centered on the card's top edge
- Top label: "年订阅" 12pt Regular, color rgba(255,255,255,0.5), centered
- Price: "¥88" 24pt Bold, color #FFFFFF, centered
- Sub-label: "/年" 12pt Regular, color rgba(255,255,255,0.4)
- Savings tag: "月均¥7.3" 11pt Regular, color #1A6B3C, centered below price
- Checkmark indicator: small green (#1A6B3C) filled circle with white checkmark at top-right corner of the card (indicating selected state)

**Card 3: Lifetime (买断)**
- Border: 1.5pt solid #D4941A (amber/gold)
- Top label: "终身买断" 12pt Regular, color rgba(255,255,255,0.5), centered
- Price: "¥198" 24pt Bold, color #FFFFFF, centered
- Sub-label: "一次性" 12pt Regular, color rgba(255,255,255,0.4), centered below price

### 6. Subscribe Button
- 16pt below the pricing cards
- Full-width within 16pt horizontal padding (393 - 32 = 361pt wide), height 50pt
- Background fill: #1A6B3C (brand green, solid fill)
- Text: "立即订阅 — 年订阅 ¥88" 17pt Semibold, color #FFFFFF, centered
- Corner radius: 12pt
- This is the primary CTA — prominent and thumb-accessible at the bottom of the screen

### 7. Footer Fine Print
- 12pt below the subscribe button
- Center-aligned text block:
  - Line 1: "订阅将自动续期，可随时在设置中取消" 11pt Regular, color rgba(255,255,255,0.3)
  - Line 2: "恢复购买" (underlined, color rgba(255,255,255,0.45)) + " · " + "使用条款" (underlined) + " · " + "隐私政策" (underlined), 11pt Regular
- 20pt bottom padding to home indicator safe area

## Design Tokens

- Page background: #111111 (near-black)
- Card background: rgba(255,255,255,0.06)
- Brand green (primary): #1A6B3C
- Pro gold/amber (accent): #D4941A
- Text white: #FFFFFF
- Text white secondary: rgba(255,255,255,0.5)
- Text white tertiary: rgba(255,255,255,0.3)
- Feature number circle border: #D4941A
- Monthly card border: rgba(255,255,255,0.15)
- Annual card border: #1A6B3C (2pt, selected)
- Lifetime card border: #D4941A
- Annual card selected bg: rgba(26,107,60,0.12)
- Subscribe button fill: #1A6B3C
- Subscribe button text: #FFFFFF
- Card corner radius: 12pt
- Button corner radius: 12pt
- Button height: 50pt
- Page horizontal padding: 16pt
- Feature list horizontal padding: 20pt
- Feature item spacing: 16pt
- Minimum touch target: 44pt

## Reference Style

- Reference the dark paywall/subscription screens commonly seen in premium iOS fitness and productivity apps — the dark background creates an immersive, premium atmosphere that breaks from the app's normal light UI
- The numbered feature list with gold accents is inspired by high-end membership/paywall screens in Chinese training apps (like the reference fitness app 训记's premium paywall at `09-premium-paywall/03-paywall.png`)
- The three pricing cards at the bottom follow a standard iOS subscription pattern: monthly (basic) / annual (recommended, highlighted) / lifetime (special)
- The "recommended" badge overlapping the card top edge is a common conversion optimization pattern
- The overall mood should be: premium, exclusive, confident — the user should feel they're getting access to something valuable
- Dark theme tone connects with the Pro promotion card in the guest profile page (P2-03), which also uses a dark card (#1C1C1E) with gold (#D4941A) accents

## Constraints

- Canvas width exactly 393px (iPhone 15 Pro), NOT desktop width
- DARK THEME page — background #111111, all text in white/light tones
- NO navigation bar, NO tab bar — this is a full-screen standalone paywall
- Close button (✕) at top-left is the only way to dismiss
- iOS native feel: SF Pro font family, SF Symbols icons
- Brand green #1A6B3C is used for: annual card highlight border, selected state, subscribe button fill, savings tag
- Amber/gold #D4941A is used for: "Pro" text in title, numbered feature circles, lifetime card border
- The subscribe button should use SOLID brand green #1A6B3C fill (NO gradient) — maintaining consistency with the app's established button style
- Annual plan card should be visually the most prominent — recommended badge + green border + subtle green tint background + checkmark
- Monthly and lifetime cards should be clearly secondary — lighter borders, no background tint, no checkmark
- All text in Simplified Chinese
- All content must fit in a single screen viewport without scrolling — the feature list may need compact spacing to fit
- Pricing cards and subscribe button are in the lower third (thumb zone) for easy one-handed interaction
- The page should NOT feel like a web pop-up — it should feel like a polished native iOS paywall experience

## State

Default state with the annual plan (¥88/年) pre-selected as the recommended option. The "推荐" badge is visible on the annual card, and the green checkmark indicates it is selected. No loading, no error messages, no animation.
