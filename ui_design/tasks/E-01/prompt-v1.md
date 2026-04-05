# Stitch Prompt — E-01 帧1: TrainingHomeView Dark Mode

> 任务 ID: E-01 | 帧: 1/5 | 版本: v1 | 日期: 2026-04-05
> Light Mode 基准: P0-01 v2 (`tasks/P0-01/stitch_task_p0_01_02/screen.png`)
> Dark Mode Token 来源: `dark-mode-rules.md` DM-001 ~ DM-009
> 布局完全复用 P0-01 已通过设计，仅进行颜色映射反转

---

## Stitch 提示词（开启新对话，粘贴以下内容）

Design the **Dark Mode variant** of the Training Home screen for an iOS billiards training app called "QiuJi" (球迹). This is the exact same layout as the attached light mode screenshot, but rendered in **OLED-optimized Dark Mode** with pure black background. iPhone screen (393 × 852pt), Dark mode, scrollable.

**CRITICAL: This is a color-mapping exercise. The layout, spacing, element positions, and content must be IDENTICAL to the attached light mode screenshot. Only colors change.**

**CRITICAL color rules (Dark Mode):**
- Brand green is `#25A25A` (brighter than light mode). Use this in your Tailwind config as `primary: "#25A25A"`. Do NOT use #1A6B3C (that's light mode) or #005129.
- Page background: `#000000` (pure black, OLED)
- Card/container background: `#1C1C1E`
- Text primary: `#FFFFFF`
- Text secondary: `rgba(235,235,240,0.6)`
- Text tertiary/placeholder: `rgba(235,235,240,0.3)`
- Separator/border: `#38383A`
- Pro/gold accent: `#F0AD30` (brighter than light mode's #D4941A)
- Do NOT use gradients on buttons — all colored UI elements use solid flat fills only.
- Do NOT use drop shadows on cards — use background color contrast only for layering.

**Overall style:**
- iOS native mobile app design (SF Pro font family feel, SF Symbols icons)
- Clean, modern, professional sports-training aesthetic — now in Dark Mode
- White status bar text (light content style)
- Canvas width: 393px (iPhone 15 Pro)

---

### Top Area: Navigation

- **Status bar**: iOS status bar with **white text** (time, signal, battery) — light content style for dark background
- **Large title**: "训练" in 34pt Bold Rounded font, left-aligned, color `#FFFFFF` (was black in light mode)
- **Right side of title row**: two circular icon buttons (24pt icons, 44pt tap area):
  - Icon color: `rgba(235,235,240,0.6)`
  - Background: subtle `#1C1C1E` circle or transparent (no light gray)
  - First icon: people/friends icon
  - Second icon: ellipsis.circle overflow menu icon

---

### Section 1: "今日安排" (Today's Schedule)

- **Section header**: "今日安排" in 16pt Bold, color `#FFFFFF`, left-aligned, 16pt horizontal margin
- **Card 1** (background `#1C1C1E`, corner radius 16pt, padding 16pt, NO shadow):
  - **Left column**:
    - Training name: "五分点专项 #1" in 20pt Bold, color `#FFFFFF`
    - Subtitle: "新手入门计划 · 3 练" in 13pt Regular, color `rgba(235,235,240,0.6)`
  - **Right column**: "GO!" button — brand green `#25A25A` filled, white text `#FFFFFF`, bold, rounded corners 8pt, height ~36pt, padding horizontal 20pt
- **Card 2** (same dark card style, 8pt gap below):
  - Training name: "基础直球推荐 #2" in 20pt Bold, color `#FFFFFF`
  - Subtitle: "新手入门计划 · 5 练" in 13pt, color `rgba(235,235,240,0.6)`
  - Right side: vertical three-dot menu icon "⋮" in `rgba(235,235,240,0.3)`, 44pt tap area

---

### Section 2: "即将到来" (Upcoming)

- **Section header**: "即将到来" in 16pt Bold, color `#FFFFFF`, left-aligned
- **Card** (background `#1C1C1E`, same dark card style):
  - Left: "走位突破 Day 3" in 20pt Bold `#FFFFFF` + "下一个训练日：周六" in 13pt `rgba(235,235,240,0.6)`
  - Right: "GO!" button same green `#25A25A` style
  - `PRO` badge pill: background `rgba(240,173,48,0.15)`, text `#F0AD30`, 10pt font, rounded full, padding 4pt horizontal 8pt

---

### Section 3: Plan Browsing Area

- **BTSegmentedTab**:
  - Two tabs: "官方计划" (active, text `#25A25A`, 2pt `#25A25A` underline below) and "自定义模版" (inactive, text `rgba(235,235,240,0.6)`, no underline)
  - Tab spacing: 24pt between labels
  - Full-width 0.5pt separator line `#38383A` below the tabs
  - Left-aligned within 16pt page margin

- **Filter chip row** (horizontal scrolling, below tabs with 12pt gap):
  - Chips: "全部" (selected) / "入门" / "初级" / "中级" / "高级" / "综合"
  - **Selected chip** (Dark Mode inversion): near-white fill `#F2F2F7` + dark text `#000000` 13pt Medium, height 32pt, corner radius 999pt (full pill), horizontal padding 14pt
  - **Unselected chip**: dark background `#2C2C2E` + white text `#FFFFFF` 13pt Medium, 1pt border `#38383A`, same dimensions
  - Chip spacing: 8pt between chips

- **Plan card list** (vertical, 8pt gap, below chips with 16pt gap):
  - **Plan Card 1** (background `#1C1C1E`, corner radius 16pt, padding 16pt, NO shadow):
    - Left: square thumbnail (80pt × 80pt, rounded 12pt, dark green tint `rgba(37,162,90,0.1)` with billiard icon placeholder)
    - Right of thumbnail (12pt gap):
      - Plan name: "新手入门 8 周计划" in 16pt Bold, color `#FFFFFF`
      - Description: "从零开始系统学习台球基础" in 13pt Regular, color `rgba(235,235,240,0.6)`, max 2 lines
      - Badge: "入门" pill — background `rgba(37,162,90,0.15)`, text `#25A25A`, 11pt, rounded full
    - Right edge: chevron "›" in `rgba(235,235,240,0.3)`, vertically centered
  - **Plan Card 2** (same dark card style):
    - Name: "基础杆法专项" in 16pt Bold `#FFFFFF`
    - Description: "练习基础杆法控制" in 13pt `rgba(235,235,240,0.6)`
    - Badge: "初级" — same green badge style
    - Right: chevron
  - **Plan Card 3** (with Pro lock):
    - Name: "走位突破 12 周" in 16pt Bold `#FFFFFF`
    - Description: "提升走位意识和白球控制" in 13pt
    - Badge: "中级" — amber badge: background `rgba(240,173,48,0.15)`, text `#F0AD30`
    - Small golden lock icon 🔒 color `#F0AD30`
    - Right: chevron

---

### Fixed Bottom Area

- **"开始训练" button**: full-width (minus 16pt margins), height 50pt, background `#25A25A` (brand green Dark, solid fill, NO gradient), text "开始训练" in 17pt Bold white, corner radius 12pt
- Bottom safe area padding: 16pt below button

---

### Bottom Tab Bar

- Tab bar background: `#1C1C1E` (solid dark, or semi-transparent dark `rgba(28,28,30,0.94)` with blur) with top 0.5pt separator `#38383A`
- 5 items:
  - "训练" (**active**, icon and label in `#25A25A`)
  - "动作库" (inactive, `rgba(235,235,240,0.6)`)
  - "角度" (inactive)
  - "记录" (inactive)
  - "我的" (inactive)
- Icon size: 24pt, label: 10pt Regular

---

### Design Tokens Summary (Dark Mode)

| Token | Dark Mode Value |
|-------|----------------|
| Primary (brand green) | `#25A25A` — USE THIS EXACTLY |
| Accent (Pro/gold) | `#F0AD30` |
| Background (page) | `#000000` |
| Card / container | `#1C1C1E` |
| Tertiary background | `#2C2C2E` |
| Text primary | `#FFFFFF` |
| Text secondary | `rgba(235,235,240,0.6)` |
| Text tertiary | `rgba(235,235,240,0.3)` |
| Separator / border | `#38383A` |
| Card radius | 16pt |
| Button radius (rect) | 12pt |
| Pill radius | 999pt |
| Padding | 16pt |
| Min touch target | 44pt |

---

### State

This screen shows the **Dark Mode variant** of the "has active plan" state — identical content and layout to the light mode version. The user has an active training plan with scheduled sessions. Plan browsing shows "官方计划" tab with "全部" filter selected.

**This is a Dark Mode color-mapping of the approved light mode design. Layout must be pixel-identical; only colors differ.**

---

## 推荐附加参考截图

在 Stitch 中粘贴提示词后，**必须**附加以下 Light Mode 已通过截图作为布局参考：

1. **`tasks/P0-01/stitch_task_p0_01_02/screen.png`** — 必须附加：Light Mode 已通过版本，Stitch 需要完全复制此布局
2. `ref-screenshots/01-training-home/01-home-with-plan.png` — 可选：原始参考截图

> 提示：告诉 Stitch "Recreate this exact layout in Dark Mode using the color tokens specified above"

## Stitch 导出处理

1. Stitch 生成后会导出一个文件夹 `stitch_task_XX/`（含 `DESIGN.md` + `code.html` + `screen.png`）+ 同名 `.zip`
2. 将导出文件夹保存到 `tasks/E-01/` 目录下
3. 完成后说 **"审核 E-01 帧1"** 触发审核，或继续生成帧2
