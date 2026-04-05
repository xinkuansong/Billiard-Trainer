# Stitch Prompt — P0-05: BTRestTimer 弹层 + DrillPickerSheet

> 任务 ID: P0-05 | 版本: v1 | 日期: 2026-04-03
> 预检：依赖 A-03 (BTDrillCard/BTLevelBadge) ✅ + A-05 (BTRestTimer) ✅；P0-03/P0-04 已通过确立全屏训练页框架；画布 393px
> 本任务包含两帧，需分别在两个 Stitch 对话中生成

---

## 帧 1 — BTRestTimer 组间休息倒计时弹层

### Stitch 提示词（开启新对话，粘贴以下内容）

Design the **Rest Timer Overlay** for an iOS billiards training app called "QiuJi" (球迹). This is a **modal overlay** that appears on top of the active training recording screen when the user completes a set and the rest timer triggers. iPhone screen (393 × 852pt), Light mode.

**CRITICAL — this is a modal overlay on top of the training screen:**
- The BACKGROUND behind the modal is the training recording screen (from P0-04), shown through a **dark semi-transparent overlay** (black at 60% opacity). You should render a blurred/dimmed version of a training screen behind the modal card.
- The modal card is CENTERED vertically and horizontally on screen.
- Do NOT include the iOS status bar, navigation bar, or tab bar — this is a floating modal overlay.

**CRITICAL color rules:**
- Brand green is exactly `#1A6B3C`. Use this in your Tailwind config as `primary: "#1A6B3C"`. Do NOT use #005129 or any other green.
- Accent/gold color: `#D4941A`
- Do NOT use gradients on buttons or solid color fills — all colored UI elements use solid flat fills only.

**Overall style:**
- iOS native mobile app design (SF Pro font family feel, SF Symbols icons)
- Clean, professional sports-training aesthetic
- Canvas width: 393px (iPhone 15 Pro)

---

#### Background Layer

A full-screen dark overlay covering the entire 393 × 852pt canvas:
- Background color: `rgba(0, 0, 0, 0.6)` (black at 60% opacity)
- Behind this overlay, render a faint impression of a training screen (blurred cards on gray background) to suggest the training session continues underneath
- This overlay is NOT tappable — user must interact with the modal card

---

#### Modal Card (Centered)

A white `#FFFFFF` card, centered both vertically and horizontally on the screen. Card dimensions: approximately 340pt wide × auto height (content-driven). Corner radius: **16pt**. Subtle shadow: `0 8pt 32pt rgba(0,0,0,0.15)`.

**Title Row** (16pt horizontal padding, 16pt top padding, 12pt bottom padding):
- **Left**: title text **"组间休息"** in **17pt Semibold**, color `#000000`
- **Right**: two small pill-shaped action buttons, horizontal, 8pt gap between them:
  - Pill 1: vibration/bell icon (14pt) + label **"震动"** (12pt), background `#F2F2F7`, corner radius 999pt (pill), height 28pt, horizontal padding 10pt, text color `rgba(60,60,67,0.6)`
  - Pill 2: minimize/arrow-down icon (14pt) + label **"最小化"** (12pt), same style as Pill 1

Thin separator line `#E5E5EA` (0.5pt) below title row, full width with 16pt horizontal inset.

---

#### Dual-Ring Progress Indicator (Centered in Card)

Centered horizontally, 24pt below the separator. This is the visual centerpiece:

- **Overall diameter**: 200pt
- **Outer ring**: 8pt stroke width, color `#1A6B3C` (brand green). This ring represents total rest time progress. Show it at ~70% progress (the arc starts from 12 o'clock and sweeps clockwise ~252°). The remaining portion is a light gray track `#E5E5EA` (2pt stroke).
- **Inner ring**: 6pt stroke width, color `#D4941A` (amber/gold), positioned concentrically inside the outer ring with a 12pt gap. This represents countdown seconds. Show it at ~50% progress (~180° sweep). Remaining portion: light gray track `#E5E5EA` (2pt stroke).
- **Center content** (inside the inner ring):
  - Countdown number **"0:32"** in **36pt Bold** monospace/tabular-figures font, color `#000000`, centered
  - Below the number (4pt gap): label **"组间休息"** in **13pt Regular**, color `rgba(60,60,67,0.6)`, centered

---

#### Suggestion Text

Below the dual-ring area, 16pt spacing, centered horizontally:
- Text: **"建议放松手腕，活动手指关节"** in **13pt Regular**, color `rgba(60,60,67,0.6)`, max-width 280pt, text-align center

---

#### Button Row (Horizontal, Side by Side)

Below suggestion text, 20pt spacing, 16pt horizontal padding, 16pt bottom padding. Two buttons side by side with 12pt gap between them:

- **Left button — "+30s"** (secondary style):
  - Width: ~48% of card inner width
  - Height: 48pt
  - Background: `#F2F2F7` (light gray)
  - Text: **"+30s"** in **17pt Semibold**, color `#1A6B3C` (brand green)
  - Corner radius: 12pt
  - Centered text

- **Right button — "完成休息"** (primary style):
  - Width: ~48% of card inner width
  - Height: 48pt
  - Background: `#1A6B3C` (brand green, solid fill)
  - Text: **"完成休息"** in **17pt Semibold**, color `#FFFFFF` (white)
  - Corner radius: 12pt
  - Centered text

---

#### Design Tokens Summary

| Token | Value |
|-------|-------|
| Primary (brand green) | `#1A6B3C` — USE THIS EXACTLY |
| Accent (amber/gold) | `#D4941A` |
| Overlay background | `rgba(0,0,0,0.6)` |
| Card white | `#FFFFFF` |
| Card corner radius | 16pt |
| Ring outer diameter | 200pt |
| Ring outer stroke | 8pt, `#1A6B3C` |
| Ring inner stroke | 6pt, `#D4941A` |
| Ring track (inactive) | `#E5E5EA`, 2pt |
| Button height | 48pt |
| Button corner radius | 12pt |
| Secondary button bg | `#F2F2F7` |
| Text primary | `#000000` |
| Text secondary | `rgba(60,60,67,0.6)` |
| Pill bg | `#F2F2F7` |
| Separator | `#E5E5EA` |
| Min touch target | 44pt |

---

#### Constraints

- This is a MODAL OVERLAY — the card floats on top of a dimmed training screen
- The dual-ring progress indicator is the VISUAL CENTERPIECE — it should feel elegant and precise, like a sports stopwatch
- The two buttons MUST be side by side horizontally (NOT stacked vertically) — "+30s" on the left, "完成休息" on the right
- The card should feel compact and focused — no unnecessary padding or empty space
- All solid fills, NO gradients
- The dark overlay behind the card must be clearly visible, giving depth to the modal

#### State

This shows the **rest timer overlay during an active rest period**. The timer is counting down from 60 seconds, currently at 32 seconds remaining. The outer ring (green, total progress) is at ~70%. The inner ring (amber, seconds) is at ~50%. The user can either add 30 more seconds or tap "完成休息" to end the rest early and continue training.

---

## 帧 2 — DrillPickerSheet 训练项目选择弹窗

### Stitch 提示词（开启新对话，粘贴以下内容）

Design the **Drill Picker Sheet** for an iOS billiards training app called "QiuJi" (球迹). This is a **full-screen modal sheet** that slides up when the user taps the "+" add button in the training toolbar to add new drills to their active training session. iPhone screen (393 × 852pt), Light mode.

**CRITICAL — this is a full-screen modal sheet:**
- This sheet covers the entire screen (presented as `.sheet` in SwiftUI).
- It has its OWN navigation structure — a close button at the top left.
- Do NOT include the iOS large-title navigation bar or the 5-tab bottom tab bar.

**CRITICAL color rules:**
- Brand green is exactly `#1A6B3C`. Use this in your Tailwind config as `primary: "#1A6B3C"`. Do NOT use #005129 or any other green.
- Accent/gold for Pro: `#D4941A`
- Do NOT use gradients — all colored fills are solid.

**Overall style:**
- iOS native mobile app design (SF Pro font family feel, SF Symbols icons)
- Clean, professional sports-training aesthetic
- Canvas width: 393px (iPhone 15 Pro)

---

#### Top Bar

White `#FFFFFF` background, 16pt horizontal padding, 12pt vertical padding:

- **Left**: circular close button — `#F2F2F7` filled circle (32pt diameter) with ✕ icon (14pt, `#000000`) centered inside. 44pt tap area.
- **Center**: title **"选择训练项目"** in **17pt Semibold**, color `#000000`, centered
- **Right**: empty space (balances the close button)

---

#### Search Bar

Below the top bar, 12pt spacing, 16pt horizontal padding:

- Rounded search field: height 36pt, corner radius 10pt, background `#F2F2F7`
- Left: magnifying glass icon 🔍 (16pt, `rgba(60,60,67,0.3)`) with 8pt left padding
- Placeholder: **"搜索训练项目"** in **15pt Regular**, color `rgba(60,60,67,0.3)`, 8pt after icon
- Right edge: microphone icon (16pt, `rgba(60,60,67,0.3)`), 8pt right padding

---

#### Two-Column Content Area

Below the search bar, 12pt spacing. This is the main content area that fills the remaining space above the bottom bar. Split into a **left sidebar** and a **right content grid**:

**Left Sidebar — Category List** (width: ~100pt, background `#FFFFFF`):

A vertical scrollable list of 8 drill categories. Each category row:
- Height: 48pt
- Horizontal padding: 12pt
- Text: category name in **14pt Medium**, single line, vertically centered
- **Default state**: text color `rgba(60,60,67,0.6)`, no indicator
- **Selected state**: text color `#1A6B3C` (brand green), **Bold** weight, plus a **3pt wide vertical bar** on the LEFT edge of the row, color `#1A6B3C`, full row height, corner radius 2pt on right side

The 8 categories (top to bottom):
1. **"直球"** ← selected (show with green indicator)
2. "角度球"
3. "组合球"
4. "翻袋"
5. "贴库"
6. "K球/安全球"
7. "走位"
8. "综合"

Thin vertical separator line `#E5E5EA` (0.5pt) between sidebar and content grid.

---

**Right Content — Drill Card Grid** (fills remaining width):

A 2-column grid with 8pt gap between cards, 12pt padding on all sides. Scrollable vertically.

Each **Drill Card**:
- Width: fills column (approximately 120pt each)
- Background: `#FFFFFF`
- Corner radius: 12pt
- Border: 1pt solid `#E5E5EA`
- Padding: 12pt internal
- Layout (vertical stack):
  - **Top**: billiard table mini thumbnail (full card width × 60pt height, corner radius 8pt top-left/top-right). Green felt `#1B6B3A` rectangle with tiny white and orange dots.
  - **Middle** (8pt below thumbnail): Drill name in **14pt Semibold**, color `#000000`, max 2 lines
  - **Bottom** (4pt below name): BTLevelBadge — small pill (height 20pt, corner radius 999pt, horizontal padding 8pt):
    - L0 badge: solid `#1A6B3C` fill + white text **"入门"** (11pt Medium)
    - L1 badge: `rgba(26,107,60,0.12)` fill + `#1A6B3C` text **"初学"**
    - L2 badge: `rgba(212,148,26,0.12)` fill + `#D4941A` text **"进阶"**

**Card States:**

- **Default card**: as described above (white background, gray border)
- **Selected card** (user picked this drill): background changes to `rgba(26,107,60,0.08)` (light green tint), border changes to `#1A6B3C` (2pt solid brand green). Plus a **count badge** in the top-right corner: small circle (22pt diameter) with `#1A6B3C` solid fill + white text count number (12pt Bold). E.g., **"1"** if selected once.

Show approximately 6 cards in the visible area. Make **2 cards selected** (with green border + count badge showing "1") and the rest in default state.

Drill names for the grid (all in the "直球" category):
1. **"五分点直球"** — L0 入门, **selected** (badge count "1")
2. **"三分点直球"** — L0 入门
3. **"七分点直球"** — L1 初学, **selected** (badge count "1")
4. **"中袋直球"** — L0 入门
5. **"底袋直球"** — L1 初学
6. **"长台直球"** — L2 进阶

---

#### Bottom Confirmation Bar

Fixed at the bottom, full width. White `#FFFFFF` background, top border 0.5pt `#E5E5EA`. Padding: 16pt horizontal, 12pt vertical (+ safe area bottom).

- **Single button**, full width (393pt - 32pt padding = 361pt wide):
  - Height: 50pt
  - Background: `#1A6B3C` (brand green, solid fill)
  - Corner radius: 12pt
  - Text: **"完成 (2)"** in **17pt Semibold**, color `#FFFFFF`
  - The number in parentheses reflects the count of selected drills (2 in this state)

---

#### Design Tokens Summary

| Token | Value |
|-------|-------|
| Primary (brand green) | `#1A6B3C` — USE THIS EXACTLY |
| Accent (Pro gold) | `#D4941A` |
| Background | `#F2F2F7` |
| Card white | `#FFFFFF` |
| Card border | `#E5E5EA`, 1pt |
| Selected card bg | `rgba(26,107,60,0.08)` |
| Selected card border | `#1A6B3C`, 2pt |
| Badge circle | `#1A6B3C` fill, 22pt |
| L0 badge | `#1A6B3C` solid fill, white text |
| L1 badge | `rgba(26,107,60,0.12)` fill, `#1A6B3C` text |
| L2 badge | `rgba(212,148,26,0.12)` fill, `#D4941A` text |
| Search bar bg | `#F2F2F7` |
| Search bar radius | 10pt |
| Sidebar width | ~100pt |
| Category indicator | 3pt wide, `#1A6B3C` |
| Card corner radius | 12pt |
| Button height | 50pt |
| Button corner radius | 12pt |
| Text primary | `#000000` |
| Text secondary | `rgba(60,60,67,0.6)` |
| Text tertiary | `rgba(60,60,67,0.3)` |
| Table felt | `#1B6B3A` |
| Min touch target | 44pt |

---

#### Constraints

- This is a FULL-SCREEN SHEET — it has its own close button and navigation, not part of the main app navigation
- The LEFT SIDEBAR + RIGHT GRID layout is the defining layout pattern — it should feel like a category browser (similar to an emoji picker or sticker picker)
- Selected cards must be CLEARLY distinguishable from unselected — green tint background + green border + count badge in the corner
- The bottom "完成 (2)" button is FIXED and always visible — the count updates dynamically
- BTLevelBadge uses the multi-color scheme: green for L0/L1, amber for L2 (established in Phase A component library)
- The category sidebar should feel like a vertical tab bar — compact, scannable, with clear active indicator
- All solid fills, NO gradients
- Keep the same clean iOS aesthetic as the rest of the training flow

#### State

This shows the **Drill Picker Sheet** with the **"直球" (straight shot) category selected** in the sidebar. The grid shows 6 drills in this category. The user has **selected 2 drills** ("五分点直球" and "七分点直球"), each showing a green highlight and a "1" count badge. The bottom confirmation button shows "完成 (2)" indicating 2 drills are ready to be added to the training session.

---

## 推荐附加参考截图

### 帧 1（BTRestTimer）
1. `ref-screenshots/02-training-active/05-active-rest-timer.png` — 主参考：休息倒计时的整体布局和双环样式
2. `tasks/A-05/stitch_task_05_02/screen.png` — A-05 已通过截图，BTRestTimer 组件样式基准
3. `tasks/P0-04/stitch_task_p0_04_04/screen.png` — P0-04 已通过截图，底层训练页面（会透过暗色遮罩隐约可见）

### 帧 2（DrillPickerSheet）
1. `ref-screenshots/03-training-plan/04-custom-plan-pick.png` — 主参考：Drill 选择弹窗的双栏布局
2. `tasks/A-03/stitch_task_03_02/screen.png` — A-03 已通过截图，BTDrillCard + BTLevelBadge 组件样式基准

⚠️ 强烈建议每帧至少附加 1 张主参考截图 + 1 张已通过组件截图，让 Stitch 理解视觉基准。

## Stitch 导出处理

1. 帧 1（BTRestTimer）：Stitch 导出文件夹保存到 `tasks/P0-05/stitch_task_p0_05_01/`
2. 帧 2（DrillPickerSheet）：Stitch 导出文件夹保存到 `tasks/P0-05/stitch_task_p0_05_02/`
3. 两帧都完成后说 **"审核 P0-05"** 触发审核智能体
