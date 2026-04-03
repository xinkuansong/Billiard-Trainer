# Stitch Prompt — P0-02: TrainingHomeView（空状态）

> 任务 ID: P0-02 | 版本: v1 | 日期: 2026-04-03
> 预检：依赖 A-02 (BTButton) ✅ + A-03 (BTEmptyState) ✅；P0-01（有计划态）已通过，本页面复用其导航栏和 Tab 栏；画布 393px

---

## Stitch 提示词（开启新对话，粘贴以下内容）

Design the **Training Home screen (Empty State)** for an iOS billiards training app called "QiuJi" (球迹). This is the same Training tab root view as the "has plan" version, but now the user has **no active training plan**. The screen shows a centered empty state message encouraging the user to pick a plan or start a free session. iPhone screen (393 × 852pt), Light mode.

**CRITICAL color rules:**
- Brand green is exactly `#1A6B3C`. Use this in your Tailwind config as `primary: "#1A6B3C"`. Do NOT use #005129 or any other green.
- Page background: `#F2F2F7`
- Card background: `#FFFFFF`
- Do NOT use gradients on buttons or solid color fills — all colored UI elements use solid flat fills only.

**Overall style:**
- iOS native mobile app design (SF Pro font family feel, SF Symbols icons)
- Clean, modern, professional sports-training aesthetic
- This is a REAL app page — include status bar, navigation area, and bottom tab bar
- Canvas width: 393px (iPhone 15 Pro)
- This page should look visually consistent with the "has plan" version of this same screen (same nav bar, same tab bar, same background color)

---

### Top Area: Navigation

- **Status bar**: standard iOS status bar (time, signal, battery indicators) — keep minimal
- **Large title**: "训练" in 34pt Bold Rounded font, left-aligned with 16pt left margin, color `#000000` (pure black), directly on the `#F2F2F7` page background — iOS native large title style (like Apple Health or Settings app)
- **Right side of title row**: two icon buttons (24pt icons, 44pt tap area, `#000000` icons on transparent background, no circle backgrounds):
  - First icon: people/friends icon (person.2 SF Symbol)
  - Second icon: ellipsis.circle overflow menu icon

---

### Center Area: Empty State (BTEmptyState component)

This is the main content area. The empty state should be **vertically centered** in the space between the navigation bar and the bottom tab bar.

- **Container**: no card background — the empty state elements sit directly on the `#F2F2F7` page background, horizontally centered, vertically centered in the available space
- **Icon**: a billiard/sports-related SF Symbol icon (e.g. `figure.pool.swim` or `sportscourt` — use a training/activity related icon), displayed at **48pt** size, color `rgba(26,107,60,0.3)` (brand green #1A6B3C at 30% opacity)
- **Title**: "还没有训练计划" in **22pt Bold** font, color `#000000`, centered, 16pt below the icon
- **Subtitle**: "选择一个训练计划开始练球，或直接自由记录" in **15pt Regular** font, color `rgba(60,60,67,0.6)` (secondary gray), centered, max width ~300pt, 8pt below the title
- **Primary button**: "选择训练计划" — full brand green `#1A6B3C` solid fill, white text 17pt Bold, height 50pt, width ~280pt (centered), corner radius 12pt, 24pt below the subtitle
- **Secondary button**: "自由记录" — no background fill, text only, color `#000000` (dark text, Tier 2 button style), 17pt Medium, height 44pt, 8pt below the primary button. This is a plain text button (no border, no background), just tappable text.

---

### Bottom Tab Bar

- Standard iOS tab bar with 5 items (same as the "has plan" version):
  - "训练" (active, icon and label in `#1A6B3C`)
  - "动作库" (inactive, gray `rgba(60,60,67,0.6)`)
  - "角度" (inactive, gray)
  - "记录" (inactive, gray)
  - "我的" (inactive, gray)
- Tab bar background: white `#FFFFFF` with top 0.5pt separator line `#E5E5EA`
- Icon size: 24pt, label: 10pt Regular
- Active tab: both icon and label in `#1A6B3C`

---

### Design Tokens Summary

| Token | Value |
|-------|-------|
| Primary (brand green) | `#1A6B3C` — USE THIS EXACTLY |
| Background | `#F2F2F7` |
| Card white | `#FFFFFF` |
| Text primary | `#000000` |
| Text secondary | `rgba(60,60,67,0.6)` |
| Separator | `#E5E5EA` |
| Button radius (rectangle) | 12pt |
| Padding | 16pt |
| Min touch target | 44pt |

---

### Constraints

- The empty state area should feel spacious and inviting, not cramped
- The icon + text + buttons group should be vertically centered between the nav bar bottom and the tab bar top
- Do NOT add any cards, lists, or other content — this is a minimal empty state
- Do NOT add a fixed bottom "开始训练" button — the CTA buttons are part of the empty state group
- Keep the same navigation bar and tab bar as the "has plan" version for consistency

---

### State

This screen shows the **"empty / no plan"** state: the user has just installed the app or has not activated any training plan yet. There are no training sessions scheduled. The screen should feel welcoming and guide the user toward their first action.

---

## 推荐附加参考截图

在 Stitch 中粘贴提示词后，建议同时附加以下参考截图：

1. `tasks/P0-01/stitch_task_p0_01_02/screen.png` — P0-01 已通过截图，保持导航栏/Tab 栏一致性
2. `ref-screenshots/01-training-home/01-home-with-plan.png` — 对比参考：有计划态的布局

⚠️ 强烈建议附加 P0-01 的已通过截图，让 Stitch 能准确复现导航栏和 Tab 栏风格。

## Stitch 导出处理

1. Stitch 生成后会导出一个文件夹 `stitch_task_XX/`（含 `DESIGN.md` + `code.html` + `screen.png`）+ 同名 `.zip`
2. 将导出文件夹保存到 `tasks/P0-02/` 目录下
3. 完成后说 **"审核 P0-02"** 触发审核智能体
