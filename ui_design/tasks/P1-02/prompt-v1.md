# Stitch Prompt — P1-02: DrillListView（搜索无结果）

> 任务 ID: P1-02 | 版本: v1 | 日期: 2026-04-04
> 预检：依赖 A-03 (BTEmptyState) ✅；P1-01（有数据态）已通过，本页面复用其导航栏、搜索栏、Tab 栏；画布 393px

---

## Stitch 提示词（开启新对话，粘贴以下内容）

Design the **Drill Library screen (Search No Results)** for an iOS billiards training app called "QiuJi" (球迹). This is the same "动作库" tab as the default list view, but the user has typed a search query that returned no matching drills. The screen shows the search bar with text input and a centered empty state message. iPhone screen (393 × 852pt), Light mode.

**CRITICAL color rules:**
- Brand green is exactly `#1A6B3C`. Use this in your Tailwind config as `primary: "#1A6B3C"`. Do NOT use #005129 or any other green.
- Page background: `#F2F2F7`
- Card background: `#FFFFFF`
- Do NOT use gradients on any element — all colored UI elements use solid flat fills only.

**Overall style:**
- iOS native mobile app design (SF Pro font family feel, SF Symbols icons)
- Clean, modern, professional sports-training aesthetic
- This is a REAL app page — include status bar, navigation area, and bottom tab bar
- Canvas width: 393px (iPhone 15 Pro)
- This page should look visually consistent with the default Drill Library list screen (same nav bar, search bar, tab bar, background color)

---

### Top Area: Navigation

- **Status bar**: standard iOS status bar (time, signal, battery indicators) — keep minimal
- **Large title**: "动作库" in 34pt Bold Rounded font, left-aligned with 16pt left margin, color `#000000` (pure black), directly on the `#F2F2F7` page background — iOS native large title style
- **Right side of title row**: one icon button (bookmark or sort icon), 24pt SF Symbol, color `rgba(60,60,67,0.6)`, 44pt tap area

---

### Search Bar (Active with Input Text)

- iOS system search bar style: rounded rectangle with light gray fill (`#E5E5EA`), height ~36pt
- Full width with 16pt horizontal margins
- **The search bar has user-typed text**: "直线球进阶" (or similar real drill name that yields no results) displayed in 17pt Regular, color `#000000`
- Right side of search bar: a small circular "✕" clear button (standard iOS search bar clear control) in gray
- The search bar should look "active" — the user has searched and is seeing results (none)

---

### Filter Chip Rows (Below Search)

Show both filter chip rows to maintain layout consistency with the default list view. They provide context that the user can still adjust filters.

**Ball type filter row** (horizontal scroll):
- Chips: "全部" | "中式台球" | "九球" | "通用"
- "全部" is selected: solid near-black fill `#1C1C1E` + white text 14pt Medium
- Unselected chips: white fill + gray border `#D1D1D6` + dark text `#1C1C1E`, 14pt Medium
- Chip height: 32pt, horizontal padding 16pt, pill shape (corner radius 999pt), gap 8pt

**Category filter row** (8pt below ball type row):
- Chips: "全部分类" | "基础功" | "准度训练" | "杆法" | "分离角" | "走位" | "控力" | "特殊球路" | "综合球形"
- "全部分类" is selected (same near-black style)
- Same chip styling as ball type row

---

### Center Area: Empty State (BTEmptyState component)

This is the main content area below the filter chips. The empty state should be **vertically centered** in the remaining space between the filter chip rows and the bottom tab bar.

- **Container**: no card background — the empty state elements sit directly on the `#F2F2F7` page background, horizontally centered
- **Icon**: a search-related SF Symbol icon (e.g. `magnifyingglass` or `doc.text.magnifyingglass`), displayed at **48pt** size, color `rgba(26,107,60,0.3)` (brand green `#1A6B3C` at 30% opacity)
- **Title**: "没有找到相关动作" in **22pt Bold** font, color `#000000`, centered, 16pt below the icon
- **Subtitle**: "试试其他关键词或浏览分类" in **15pt Regular** font, color `rgba(60,60,67,0.6)` (secondary gray), centered, 8pt below the title
- **CTA button**: "浏览全部动作" — full brand green `#1A6B3C` solid fill, white text 17pt Bold, height 44pt, width ~240pt (centered), corner radius 12pt, 24pt below the subtitle. This button clears the search and returns to the full list.

---

### Bottom Tab Bar

- Standard iOS tab bar with 5 items (same as the default Drill Library screen):
  - "训练" (inactive, gray `rgba(60,60,67,0.6)`)
  - "动作库" (**active**, icon and label in `#1A6B3C`)
  - "角度" (inactive, gray)
  - "记录" (inactive, gray)
  - "我的" (inactive, gray)
- Tab bar background: white `#FFFFFF` with top 0.5pt separator line `#E5E5EA`
- Icon size: 24pt, label: 10pt Regular
- Tab icons (SF Symbols): "figure.run" | "books.vertical" | "angle" | "calendar" | "person"

---

### Design Tokens Summary

| Token | Value |
|-------|-------|
| Primary (brand green) | `#1A6B3C` — USE THIS EXACTLY |
| Background | `#F2F2F7` |
| Card white | `#FFFFFF` |
| Text primary | `#000000` |
| Text secondary | `rgba(60,60,67,0.6)` |
| Text tertiary | `rgba(60,60,67,0.3)` |
| Separator | `#E5E5EA` |
| Filter chip selected | `#1C1C1E` (near-black, NOT brand green) |
| Button radius | 12pt |
| Chip radius | 999pt (pill) |
| Padding | 16pt |
| Min touch target | 44pt |

---

### Constraints

- The empty state area should feel spacious and calm — communicate "no results" without feeling like an error
- The icon + text + button group should be vertically centered in the space between the filter chips bottom and the tab bar top
- Do NOT add any drill cards, list items, or skeleton loaders — this is a clean "no search results" state
- Keep the search bar, filter chips, navigation bar and tab bar exactly as they would appear in the populated list view, for layout consistency
- The filter chips show that the user CAN still adjust their search/filter to find results
- Brand green `#1A6B3C` is ONLY used for: tab bar active state, empty state icon tint (at 30%), and the CTA button fill. NOT for filter chip selected state or nav title.

---

### State

This screen shows the **"search no results"** state: the user has typed a search query (visible in the search bar) but no drills match. The filter chips are still showing (both set to "全部"), and the empty state guides the user to try different keywords or browse all drills.

---

## 推荐附加参考截图

在 Stitch 中粘贴提示词后，建议同时附加以下参考截图：

1. `tasks/P1-01/stitch_task_p1_01_02/screen.png` — P1-01 已通过截图，保持导航栏/搜索栏/筛选 Chip/Tab 栏一致性
2. `ref-screenshots/04-exercise-library/04-list-no-result.png` — 主参考：搜索无结果空状态布局

⚠️ 强烈建议附加 P1-01 的已通过截图，让 Stitch 能准确复现页面上半部分（导航栏 + 搜索栏 + 筛选 Chip 行）的风格。

## Stitch 导出处理

1. Stitch 生成后会导出一个文件夹 `stitch_task_XX/`（含 `DESIGN.md` + `code.html` + `screen.png`）+ 同名 `.zip`
2. 将导出文件夹保存到 `tasks/P1-02/` 目录下
3. 完成后说 **"审核 P1-02"** 触发审核智能体
