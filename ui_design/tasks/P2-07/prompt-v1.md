# Stitch Prompt — P2-07 帧 1: FavoriteDrillsView（有数据态）

> 任务 ID: P2-07 | 版本: v1 | 帧: 1/2 | 日期: 2026-04-05
> 预检：依赖 A-03 (BTDrillCard/BTLevelBadge) ✅；P1-01 (DrillListView 卡片基准) ✅；P2-03 (入口 ProfileView) ✅；画布 393px

---

## Stitch 提示词（开启新对话，粘贴以下内容）

Design the **Favorite Drills list screen (with data)** for an iOS billiards training app called "QiuJi" (球迹). This screen is accessed from the Profile tab → "我的收藏" menu row (push navigation). It shows the user's favorited drills in a simple scrollable list using BTDrillCard components. No search bar, no filter chips — just a clean card list. iPhone screen (393 × 852pt), Light mode.

**CRITICAL color rules:**
- Brand green is exactly `#1A6B3C`. Use this in your Tailwind config as `primary: "#1A6B3C"`. Do NOT use #005129 or any other green.
- Page background: `#F2F2F7`
- Card background: `#FFFFFF`
- Do NOT use gradients on any element — all colored UI elements use solid flat fills only.

**Overall style:**
- iOS native mobile app design (SF Pro font family feel, SF Symbols icons)
- Clean, modern, professional sports-training aesthetic
- This is a REAL app page — include status bar and navigation bar
- Canvas width: 393px (iPhone 15 Pro)
- This is a push sub-page (NOT a tab root), so: standard back arrow navigation, NO bottom tab bar
- This page should look visually consistent with the Drill Library list screen (same card styling)

---

### Top Area: Navigation Bar

- **Status bar**: standard iOS status bar (time, signal, battery indicators)
- **Navigation bar**: standard iOS compact navigation bar (NOT large title), white/translucent background
  - Left side: back arrow chevron `‹` + back label "我的" in `#1A6B3C` (brand green, standard iOS back button), tapping returns to ProfileView
  - Center: title "我的收藏" in 17pt Semibold, color `#000000`
  - Right side: empty (no action buttons)
- Thin bottom separator line 0.5pt `#E5E5EA`

---

### Main Content: Drill Card List

A scrollable vertical list of favorited drill cards on the `#F2F2F7` background, 16pt horizontal margins, 8pt vertical gap between cards. Show **5 drill cards** representing different difficulty levels.

**Each card** is a white (`#FFFFFF`) rounded rectangle, corner radius 12pt, with 16pt internal padding. Card layout (left to right):

1. **Left thumbnail** (64pt × 64pt square, corner radius 8pt): a billiard-themed photo or illustration (green felt table, balls, cue etc.) — each card has a slightly different image
2. **Center content area** (flex, to the right of thumbnail, 12pt gap):
   - **Drill name**: 17pt Semibold, color `#000000`, single line, e.g. "直线球基础", "中袋角度练习", "走位控制进阶", "薄球切球", "组合球入门"
   - **Tag row** (4pt below name, horizontal, 6pt gap between items):
     - **Ball type chip**: small pill (height 22pt, horizontal padding 8pt, corner radius 999pt), light gray fill `#F2F2F7` + dark text `#3C3C43` in 12pt Medium — e.g. "中式台球", "九球", "通用"
     - **Level badge (BTLevelBadge)**: small pill same size as ball type chip, with level-specific colors:
       - L0 "入门": solid `#1A6B3C` fill + white text
       - L1 "初学": light green fill `rgba(26,107,60,0.12)` + green text `#1A6B3C`
       - L2 "进阶": light amber fill `rgba(212,148,26,0.12)` + amber text `#D4941A`
       - L3 "熟练": light orange fill `rgba(255,152,0,0.12)` + orange text `#E65100`
     - **Recommended sets**: "推荐 3 组" in 13pt Regular, color `rgba(60,60,67,0.6)`
3. **Right side**: chevron icon `›` in `rgba(60,60,67,0.3)`, vertically centered, 13pt

**Card #4 has a PRO lock badge**: in the tag row area, after the level badge, show a small "PRO" pill — light gold fill `rgba(212,148,26,0.12)` + gold text `#D4941A` in 11pt Bold, height 20pt, corner radius 999pt.

**5 cards with these details** (top to bottom):
1. "直线球基础" — 通用, L0 入门, 推荐 3 组
2. "中袋角度练习" — 中式台球, L1 初学, 推荐 4 组
3. "走位控制进阶" — 中式台球, L2 进阶, 推荐 5 组
4. "薄球精准切入" — 九球, L3 熟练, 推荐 4 组, **PRO** badge
5. "组合球基础" — 通用, L1 初学, 推荐 3 组

---

### Design Tokens Summary

| Token | Value |
|-------|-------|
| Primary (brand green) | `#1A6B3C` — USE THIS EXACTLY |
| Pro/Accent gold | `#D4941A` |
| Background | `#F2F2F7` |
| Card white | `#FFFFFF` |
| Text primary | `#000000` |
| Text secondary | `rgba(60,60,67,0.6)` |
| Text tertiary | `rgba(60,60,67,0.3)` |
| Separator | `#E5E5EA` |
| Card radius | 12pt |
| Thumbnail radius | 8pt |
| Chip radius | 999pt (pill) |
| Padding | 16pt |
| Card gap | 8pt |
| Min touch target | 44pt |

---

### Constraints

- This is a **sub-page** (push from ProfileView), NOT a tab root — use compact center title navigation, not large title
- Do NOT include a bottom tab bar — this page is pushed on top of the tab bar
- Do NOT include a search bar or filter chips — this is a simple favorites list, not the full Drill Library
- The card layout should match the Drill Library list page exactly (same thumbnail + content + chevron pattern)
- BTLevelBadge colors must follow the multi-color scheme: L0 green solid, L1 green light, L2 amber light, L3 orange light
- Only one card (#4) shows the PRO badge — the rest are free drills
- Keep the list content-rich but not crowded — 5 cards is enough to show a meaningful collection
- Brand green `#1A6B3C` is used for: back button text, L0/L1 badge colors. NOT for card backgrounds or nav title.

---

### State

This screen shows the **"has favorites"** state: the user has 5 drills in their favorites list. The list is scrollable with a variety of difficulty levels and ball types, including one Pro-locked drill.

---

## 推荐附加参考截图

在 Stitch 中粘贴提示词后，建议同时附加以下参考截图：

1. `tasks/P1-01/stitch_task_p1_01_02/screen.png` — P1-01 已通过截图，卡片样式/缩略图/标签行基准
2. `tasks/A-03/stitch_task_03_02/screen.png` — A-03 已通过截图，BTDrillCard/BTLevelBadge 组件基准

⚠️ 强烈建议附加 P1-01 截图，让 Stitch 准确复现 DrillCard 的缩略图+内容+chevron 布局模式。

## Stitch 导出处理

1. Stitch 生成后会导出一个文件夹 `stitch_task_XX/`（含 `DESIGN.md` + `code.html` + `screen.png`）+ 同名 `.zip`
2. 将导出文件夹保存到 `tasks/P2-07/` 目录下
3. 帧 2（空状态）的提示词见 `prompt-v1-frame2.md`
