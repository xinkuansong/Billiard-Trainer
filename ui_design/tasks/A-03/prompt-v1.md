# Stitch Prompt — A-03: BTEmptyState + BTDrillCard + BTLevelBadge Component Sheet

> 任务 ID: A-03 | 版本: v1 | 日期: 2026-04-03
> 预检：已读取 A-01/A-02 decision-log，沿用纯文档组件表风格、品牌色锚定、纯色填充约束

---

## Stitch 提示词（开启新对话，粘贴以下内容）

Design a **Component Reference Sheet** for an iOS billiards training app called "QiuJi" (球迹). This single-page component inventory shows 3 list/content-related components: BTEmptyState, BTDrillCard, and BTLevelBadge. iPhone screen (393x852pt), Light mode, scrollable.

**CRITICAL color rule:** The brand green is exactly `#1A6B3C`. Do NOT change it to any other value. Do NOT use gradients — all colored elements use solid flat fills only.

**Page style** (must match our established Design Token sheet and Button sheet):
- Page background: `#F2F2F7`
- Content in white cards: `#FFFFFF`, corner radius 16pt, padding 16pt
- Section titles: 22pt Bold Rounded font, color `#1A6B3C`
- No navigation bar, no tab bar — this is a pure design documentation page
- Clean, minimal iOS design system documentation style

---

### Section 1: "BTEmptyState — 空状态组件"

Show a complete empty state component centered in a white card. The component is vertically centered with these elements stacked:

1. **SF Symbol icon** at the top center: use a magnifying glass icon (like "magnifyingglass" from SF Symbols), rendered at 48pt size, color `#1A6B3C` at **30% opacity** (very light green tint)
2. **Title text** below the icon (12pt spacing): "未找到相关动作" in 22pt Bold, color black `#000000`, centered
3. **Subtitle text** below the title (8pt spacing): "试试其他关键词或浏览全部动作库" in 15pt Regular, color `rgba(60,60,67,0.6)` (secondary gray), centered, max 2 lines
4. **CTA button** below the subtitle (20pt spacing): full-width pill button, height 50pt, corner radius 12pt, solid fill `#1A6B3C`, white text "浏览全部动作" 16pt Medium centered

Below the component, add a small annotation row (13pt gray text): "使用场景：无训练计划 / 搜索无结果 / 无收藏 / 无训练记录"

---

### Section 2: "BTDrillCard — Drill 列表卡片"

Show **3 example Drill cards** stacked vertically with 8pt gap between them. Each card is a white rectangle with corner radius 12pt and padding 16pt.

**Card layout (each card):**
- Left side, vertically centered:
  - **Drill name**: 17pt Semibold, black, one line (e.g. "直线球定位训练")
  - **Tag row** below the name (6pt spacing): a horizontal row of small pill-shaped tags:
    - Ball type tag: small pill (height 22pt, corner radius 999pt, horizontal padding 8pt), light green background `#1A6B3C` at 12% opacity, text in `#1A6B3C` 12pt Medium (e.g. "中式台球")
    - Level badge (BTLevelBadge): small pill same height, e.g. green "L0 入门"
    - Recommended sets: plain text 13pt `rgba(60,60,67,0.6)` (e.g. "推荐 5 组")
  - 8pt gap between each tag
- Right side, vertically centered: a chevron.right icon in light gray `#C7C7CC`, 14pt

**Card 1 — Normal Drill:**
- Name: "直线球定位训练"
- Tags: "中式台球" (green pill) + "L0 入门" (green badge) + "推荐 5 组"
- Standard chevron right

**Card 2 — Higher Level Drill:**
- Name: "三分点走位练习"
- Tags: "九球" (green pill) + "L2 进阶" (amber badge, see BTLevelBadge colors) + "推荐 3 组"
- Standard chevron right

**Card 3 — Pro Locked Drill:**
- Name: "高级K球技巧"
- Tags: "中式台球" (green pill) + "L4 专业" (red badge) + "推荐 4 组"
- Standard chevron right
- **Pro lock badge** in the top-right corner of the card: a small overlay showing a lock icon (10pt) + "Pro" text (10pt Bold) in gold `#D4941A`, with a subtle gold-tinted background pill

Below the 3 cards, add a small annotation (13pt gray): "使用场景：动作库列表 / 收藏列表 / 训练项目选择"

---

### Section 3: "BTLevelBadge — 等级徽章"

Show all **5 level badges** in a horizontal row inside a white card, evenly spaced:

Each badge is a small pill shape (height 22pt, corner radius 999pt, horizontal padding 10pt):

1. **L0 入门**: Solid fill `#1A6B3C`, white text "L0 入门" 12pt Medium
2. **L1 初学**: Light background `#1A6B3C` at 12% opacity, text `#1A6B3C` 12pt Medium "L1 初学"
3. **L2 进阶**: Light background `#D4941A` at 12% opacity, text `#D4941A` 12pt Medium "L2 进阶"
4. **L3 熟练**: Light background `#F5A623` at 12% opacity, text `#E67C00` (darker orange for readability) 12pt Medium "L3 熟练"
5. **L4 专业**: Light background `#C62828` at 12% opacity, text `#C62828` 12pt Medium "L4 专业"

Below the badges row, show a small mapping table or annotation (13pt gray):
"L0 品牌绿(实心) → L1 品牌绿(浅底) → L2 琥珀色 → L3 橙色 → L4 红色"

---

**Design constraints (strictly enforced):**
- `#1A6B3C` is the ONLY brand green — do not substitute
- `#D4941A` amber/gold for Pro elements and L2 badge
- `#C62828` for destructive red and L4 badge
- `#F5A623` / `#E67C00` for L3 orange badge
- Solid flat fills ONLY — absolutely no gradients
- iOS native feel: SF Pro font, clean flat style
- Card corner radius: 12pt for component cards, 16pt for section wrapper cards
- All text spacing follows the 8pt grid system
- Visual style must match the Design Token sheet (A-01) and Button sheet (A-02): white cards on gray background, green section titles

---

## 参考截图

建议附加这两张参考图帮助 Stitch 理解列表卡片和空状态的布局风格：
- `ref-screenshots/04-exercise-library/04-list-no-result.png` — 训记搜索无结果的空状态效果（SF Symbol 图标 + 标题 + 引导文案），球迹中将蓝色替换为品牌绿 #1A6B3C
- `ref-screenshots/04-exercise-library/01-list-default.png` — 训记动作库列表的卡片样式（名称 + 标签行 + chevron），球迹中使用自己的颜色体系和等级徽章

## 使用说明

1. 在 Google Stitch 中**开启新对话**
2. 粘贴上方提示词，可选附加两张参考截图
3. 导出保存到 `tasks/A-03/`
4. 说「审核 A-03」触发审核智能体
