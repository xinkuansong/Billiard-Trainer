# Stitch Prompt — P0-01: TrainingHomeView（有计划态）

> 任务 ID: P0-01 | 版本: v1 | 日期: 2026-04-03
> 预检：Phase A 全部通过 + 一致性审核通过；本任务引用 A-02 (BTButton)、A-03 (BTDrillCard)、A-06 (BTSegmentedTab + BTTogglePillGroup) 已确立组件样式；画布统一 393px iPhone 宽度（A-REVIEW 建议）

---

## Stitch 提示词（开启新对话，粘贴以下内容）

Design the **Training Home screen** for an iOS billiards training app called "QiuJi" (球迹). This is the main tab root view showing today's training schedule and a plan browsing section. The user has an active training plan. iPhone screen (393 × 852pt), Light mode, scrollable.

**CRITICAL color rules:**
- Brand green is exactly `#1A6B3C`. Use this in your Tailwind config as `primary: "#1A6B3C"`. Do NOT use #005129 or any other green.
- Page background: `#F2F2F7`
- Card background: `#FFFFFF`
- Do NOT use gradients on buttons or solid color fills — all colored UI elements use solid flat fills only.

**Overall style:**
- iOS native mobile app design (SF Pro font family feel, SF Symbols icons)
- Clean, modern, professional sports-training aesthetic
- This is a REAL app page (not a component documentation sheet) — include status bar, navigation area, and bottom tab bar
- Canvas width: 393px (iPhone 15 Pro)

---

### Top Area: Navigation

- **Status bar**: standard iOS status bar (time, signal, battery indicators) — keep minimal
- **Large title**: "训练" in 34pt Bold Rounded font, left-aligned, color `#000000`
- **Right side of title row**: two circular icon buttons (24pt icons, 44pt tap area, light gray background `#F2F2F7` with slight border or no background):
  - First icon: people/friends icon (social entry)
  - Second icon: ellipsis.circle or "⋯" overflow menu icon

---

### Section 1: "今日安排" (Today's Schedule)

- **Section header**: "今日安排" in 16pt Bold, color `#000000`, left-aligned, with 16pt horizontal margin
- **Card 1** (white card, corner radius 16pt, padding 16pt, full width minus 16pt horizontal margins):
  - **Left column**:
    - Training name: "五分点专项 #1" in 20pt Bold, color `#000000`
    - Subtitle: "新手入门计划 · 3 练" in 13pt Regular, color `rgba(60,60,67,0.6)`
  - **Right column**: A "GO!" button — brand green `#1A6B3C` filled, white text, bold, rounded corners 8pt, height ~36pt, padding horizontal 20pt
- **Card 2** (same style, stacked below with 8pt gap):
  - Training name: "基础直球推荐 #2" in 20pt Bold
  - Subtitle: "新手入门计划 · 5 练" in 13pt
  - Right side: vertical three-dot menu icon "⋮" in gray `rgba(60,60,67,0.3)`, 44pt tap area

---

### Section 2: "即将到来" (Upcoming)

- **Section header**: "即将到来" in 16pt Bold, color `#000000`, left-aligned
- **Card** (same white card style as above):
  - Left: "走位突破 Day 3" in 20pt Bold + "下一个训练日：周六" in 13pt gray
  - Right: "GO!" button same style as Section 1
  - A small golden `PRO` badge pill next to the subtitle: background `rgba(212,148,26,0.12)`, text `#D4941A`, 10pt font, rounded full, padding 4pt horizontal 8pt

---

### Section 3: Plan Browsing Area

- **BTSegmentedTab** (matches our established component — 16pt Medium text, 2pt brand green underline indicator):
  - Two tabs: "官方计划" (active, text `#1A6B3C`, 2pt `#1A6B3C` underline below) and "自定义模版" (inactive, text `rgba(60,60,67,0.6)`, no underline)
  - Tab spacing: 24pt between labels
  - Full-width 0.5pt separator line `#E5E5EA` below the tabs
  - Left-aligned within 16pt page margin

- **Filter chip row** (horizontal scrolling, below tabs with 12pt gap):
  - Chips: "全部" (selected) / "入门" / "初级" / "中级" / "高级" / "综合"
  - Selected chip: dark fill `#1C1C1E` (near-black) + white text 13pt Medium, height 32pt, corner radius 999pt (full pill), horizontal padding 14pt
  - Unselected chip: white background `#FFFFFF` + gray border 1pt `#D1D1D6` + dark text `#000000` 13pt Medium, same dimensions
  - Chip spacing: 8pt between chips

- **Plan card list** (vertical, 8pt gap between cards, below chips with 16pt gap):
  - **Plan Card 1** (white card, corner radius 16pt, padding 16pt):
    - Left: square thumbnail placeholder (80pt × 80pt, rounded 12pt, light green background `rgba(26,107,60,0.08)` with a centered billiard-related icon or illustration placeholder)
    - Right of thumbnail (12pt gap):
      - Plan name: "新手入门 8 周计划" in 16pt Bold, color `#000000`
      - Description: "从零开始系统学习台球基础" in 13pt Regular, color `rgba(60,60,67,0.6)`, max 2 lines
      - Badge row: a level badge pill "入门" — background `rgba(26,107,60,0.12)`, text `#1A6B3C`, 11pt, rounded full
    - Right edge: chevron.right icon "›" in `rgba(60,60,67,0.3)`, vertically centered
  - **Plan Card 2** (same style):
    - Thumbnail: different color placeholder
    - Name: "基础杆法专项" in 16pt Bold
    - Description: "练习基础杆法控制" in 13pt
    - Badge: "初级" — same green badge style
    - Right: chevron
  - **Plan Card 3** (same style, but with Pro lock):
    - Name: "走位突破 12 周" in 16pt Bold
    - Description: "提升走位意识和白球控制" in 13pt
    - Badge: "中级" — amber badge: background `rgba(212,148,26,0.12)`, text `#D4941A`
    - A small golden lock icon 🔒 to the right of the plan name or near the chevron, color `#D4941A`
    - Right: chevron

---

### Fixed Bottom Area

- **"开始训练" button**: full-width (minus 16pt margins each side), height 50pt, background `#1A6B3C` (brand green, solid fill, NO gradient), text "开始训练" in 17pt Bold white, corner radius 12pt
- Bottom safe area padding: 16pt below button to screen edge
- The button sits above the Tab bar area

---

### Bottom Tab Bar

- Standard iOS tab bar with 5 items (compact icon + label style):
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
| Accent (Pro/gold) | `#D4941A` |
| Background | `#F2F2F7` |
| Card white | `#FFFFFF` |
| Text primary | `#000000` |
| Text secondary | `rgba(60,60,67,0.6)` |
| Outline/border | `#D1D1D6` |
| Separator | `#E5E5EA` |
| Card radius | 16pt |
| Button radius (rectangle) | 12pt |
| Pill radius | 999pt |
| Padding | 16pt |
| Min touch target | 44pt |

---

### State

This screen shows the **"has active plan"** state: the user has activated a training plan and there are scheduled training sessions for today and upcoming days. The plan browsing area shows official plans with the "官方计划" tab active and "全部" filter selected.

---

## 推荐附加参考截图

在 Stitch 中粘贴提示词后，建议同时附加以下参考截图（帮助 Stitch 理解布局风格）：

1. `ref-screenshots/01-training-home/01-home-with-plan.png` — 主参考：整体布局和今日安排区
2. `ref-screenshots/01-training-home/04-home-scrolled-plans.png` — 计划浏览区卡片列表风格
3. `ref-screenshots/01-training-home/03-home-with-plan-detail.png` — 标签切换效果

⚠️ 参考截图目录可能尚未导入，请从原始设计资料中手动附加。

## Stitch 导出处理

1. Stitch 生成后会导出一个文件夹 `stitch_task_XX/`（含 `DESIGN.md` + `code.html` + `screen.png`）+ 同名 `.zip`
2. 将导出文件夹保存到 `tasks/P0-01/` 目录下
3. 完成后说 **"审核 P0-01"** 触发审核智能体
