# Stitch Prompt — P2-07 帧 2: FavoriteDrillsView（空状态）

> 任务 ID: P2-07 | 版本: v1 | 帧: 2/2 | 日期: 2026-04-05
> 预检：依赖 A-03 (BTEmptyState) ✅；P1-02 (搜索无结果空状态风格基准) ✅；画布 393px

---

## Stitch 提示词（开启新对话，粘贴以下内容）

Design the **Favorite Drills screen (Empty State)** for an iOS billiards training app called "QiuJi" (球迹). This screen is accessed from the Profile tab → "我的收藏" menu row. The user has no favorited drills yet, so the screen shows a centered empty state message with a call-to-action button guiding the user to browse the drill library. iPhone screen (393 × 852pt), Light mode.

**CRITICAL color rules:**
- Brand green is exactly `#1A6B3C`. Use this in your Tailwind config as `primary: "#1A6B3C"`. Do NOT use #005129 or any other green.
- Page background: `#F2F2F7`
- Do NOT use gradients on any element — all colored UI elements use solid flat fills only.

**Overall style:**
- iOS native mobile app design (SF Pro font family feel, SF Symbols icons)
- Clean, modern, professional sports-training aesthetic
- This is a REAL app page — include status bar and navigation bar
- Canvas width: 393px (iPhone 15 Pro)
- This is a push sub-page (NOT a tab root), so: standard back arrow navigation, NO bottom tab bar

---

### Top Area: Navigation Bar

- **Status bar**: standard iOS status bar (time, signal, battery indicators)
- **Navigation bar**: standard iOS compact navigation bar (NOT large title), white/translucent background
  - Left side: back arrow chevron `‹` + back label "我的" in `#1A6B3C` (brand green, standard iOS back button)
  - Center: title "我的收藏" in 17pt Semibold, color `#000000`
  - Right side: empty (no action buttons)
- Thin bottom separator line 0.5pt `#E5E5EA`

---

### Center Area: Empty State (BTEmptyState component)

The empty state should be **vertically centered** in the full remaining space below the navigation bar down to the bottom of the screen (no tab bar on this page).

- **Container**: no card background — the empty state elements sit directly on the `#F2F2F7` page background, horizontally centered
- **Icon**: a star or heart SF Symbol icon (e.g. `star.slash` or `heart.slash`), displayed at **48pt** size, color `rgba(26,107,60,0.3)` (brand green `#1A6B3C` at 30% opacity)
- **Title**: "还没有收藏" in **22pt Bold** font, color `#000000`, centered, 16pt below the icon
- **Subtitle**: "去动作库看看吧" in **15pt Regular** font, color `rgba(60,60,67,0.6)` (secondary gray), centered, 8pt below the title
- **CTA button**: "浏览动作库" — full brand green `#1A6B3C` solid fill, white text 17pt Bold, height 44pt, width ~200pt (centered), corner radius 12pt, 24pt below the subtitle

---

### Design Tokens Summary

| Token | Value |
|-------|-------|
| Primary (brand green) | `#1A6B3C` — USE THIS EXACTLY |
| Background | `#F2F2F7` |
| Text primary | `#000000` |
| Text secondary | `rgba(60,60,67,0.6)` |
| Separator | `#E5E5EA` |
| Button radius | 12pt |
| Padding | 16pt |
| Min touch target | 44pt |

---

### Constraints

- This is a **sub-page** (push from ProfileView), NOT a tab root — use compact center title navigation, not large title
- Do NOT include a bottom tab bar — this page is pushed on top of the tab bar
- Do NOT include any drill cards, search bars, or filter chips — this is a clean empty state
- The empty state group (icon + title + subtitle + button) should be perfectly vertically centered in the available space
- The screen should feel calm and inviting, not like an error — encourage the user to explore the drill library
- The navigation bar must look identical to the data-state version of this screen (same back button style, same title)
- Brand green `#1A6B3C` is used for: back button text, empty state icon tint (at 30%), and the CTA button fill

---

### State

This screen shows the **"no favorites"** state: the user has not yet favorited any drills. A friendly empty state guides them to browse the drill library.

---

## 推荐附加参考截图

在 Stitch 中粘贴提示词后，建议同时附加以下参考截图：

1. `tasks/P1-02/stitch_task_p1_02/screen.png` — P1-02 已通过截图，DrillListView 搜索无结果空状态风格基准
2. `tasks/P2-03/stitch_task_p2_03_userprofile_02/screen.png` — P2-03 已通过截图，入口 ProfileView 风格基准

## Stitch 导出处理

1. Stitch 生成后会导出一个文件夹 `stitch_task_XX/`（含 `DESIGN.md` + `code.html` + `screen.png`）+ 同名 `.zip`
2. 将导出文件夹保存到 `tasks/P2-07/` 目录下
3. 两帧都完成后说 **"审核 P2-07"** 触发审核智能体
