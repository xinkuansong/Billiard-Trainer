# Stitch Prompt — A-06: BTSegmentedTab + BTTogglePillGroup + BTOverflowMenu 组件表

> 任务 ID: A-06 | 版本: v1 | 日期: 2026-04-03
> 预检：已读取 A-01~A-05 decision-log，沿用纯文档组件表风格、品牌色 #1A6B3C 锚定、纯色填充无渐变约束；三级按钮层级体系延续 A-02 决策

---

## Stitch 提示词（开启新对话，粘贴以下内容）

Design a **Component Reference Sheet** for an iOS billiards training app called "QiuJi" (球迹). This single-page component inventory showcases three navigation/selection/menu components: **BTSegmentedTab** (in-page horizontal tab switcher), **BTTogglePillGroup** (pill-shaped option group), and **BTOverflowMenu** (overflow context menu). iPhone screen (393x852pt), Light mode, scrollable.

**CRITICAL color rules:**
- Brand green is exactly `#1A6B3C`. Do NOT change it.
- Destructive/danger red is exactly `#C62828`. Do NOT change it.
- Do NOT use gradients on buttons or solid color fills — all colored UI elements use solid flat fills.

**Page style** (must match our established Design Token sheet, Button sheet, List Components sheet, PremiumLock sheet, and RestTimer/Indicator sheet):
- Page background: `#F2F2F7`
- Content in white cards: `#FFFFFF`, corner radius 16pt, padding 16pt
- Section titles: 22pt Bold Rounded font, color `#1A6B3C`
- No navigation bar, no tab bar — this is a pure design documentation page
- Clean, minimal iOS design system documentation style

---

### Section 1: "BTSegmentedTab — 页内水平标签"

This section shows the in-page horizontal tab switcher used to toggle between content sections (e.g., "官方计划 / 自定义模版" or "历史 / 统计"). Display it inside a white card.

**Layout inside the white card (top to bottom):**

1. **Example A — Two tabs ("历史 / 统计"):**
   - Two text labels arranged horizontally, centered within the card
   - **Active tab** ("历史"):
     - Text: "历史" in 16pt Medium, color `#1A6B3C` (brand green)
     - A 2pt thick horizontal underline directly below the text, color `#1A6B3C`, width matches the text width, with 4pt gap between text baseline and underline
   - **Inactive tab** ("统计"):
     - Text: "统计" in 16pt Medium, color `rgba(60,60,67,0.6)` (secondary gray)
     - No underline
   - Horizontal spacing between the two tab labels: 24pt
   - Below both tabs, a full-width 0.5pt separator line in `#E5E5EA` (spanning the card width minus padding)

2. **Example B — Three tabs ("官方计划 / 自定义模版 / 个人计划(AI)"):**
   - Three text labels arranged horizontally, left-aligned
   - **Active tab** ("官方计划"):
     - Text in 16pt Medium, color `#1A6B3C`
     - 2pt brand green underline below
   - **Inactive tabs** ("自定义模版", "个人计划(AI)"):
     - Text in 16pt Medium, color `rgba(60,60,67,0.6)`
     - No underline
   - Horizontal spacing between labels: 24pt
   - Full-width 0.5pt separator line below in `#E5E5EA`

3. **Component specs** (below the examples, 12pt spacing, compact vertical list in 13pt, color `rgba(60,60,67,0.6)`):
   - "字号: 16pt Medium"
   - "活跃项: #1A6B3C + 2pt 下划线"
   - "非活跃项: rgba(60,60,67,0.6)"
   - "标签间距: 24pt"

Below the card, add annotation (13pt gray text): "使用场景：训练首页计划分区、历史/统计切换、训练详情标签切换"

---

### Section 2: "BTTogglePillGroup — 胶囊式选项组"

This section shows the pill-shaped toggle button group used for preference selection (e.g., timer mode, filter options). Display it inside a white card.

**Layout inside the white card (top to bottom):**

1. **Example A — Two pills ("倒计时 / 正计时"), first selected:**
   - Two capsule/pill buttons side by side, centered, 8pt gap between them
   - **Selected pill** ("倒计时"):
     - Height 36pt, horizontal padding 16pt, corner radius 999pt (full pill)
     - Background: solid `#1A6B3C` (brand green)
     - Text: "倒计时" in 15pt Medium, color `#FFFFFF`
   - **Unselected pill** ("正计时"):
     - Height 36pt, horizontal padding 16pt, corner radius 999pt (full pill)
     - Background: `#FFFFFF` (white)
     - Border: 1pt solid `#D1D1D6` (light gray)
     - Text: "正计时" in 15pt Medium, color `#000000`

2. **Example B — Three pills ("成功率 / 进球数 / 用时"), second selected:**
   - Three capsule/pill buttons side by side, centered, 8pt gap
   - **Unselected pill** ("成功率"):
     - Same unselected style as above (white bg, gray border, black text)
   - **Selected pill** ("进球数"):
     - Same selected style as above (green bg, white text)
   - **Unselected pill** ("用时"):
     - Same unselected style as above

3. **Example C — Four pills ("全部 / 入门 / 初级 / 中级"), first selected:**
   - Four capsule/pill buttons in a row, left-aligned (may wrap or scroll if narrow), 8pt gap
   - First pill selected (green), other three unselected (white/gray border)

4. **Component specs** (below the examples, 12pt spacing, compact vertical list in 13pt, color `rgba(60,60,67,0.6)`):
   - "高度: 36pt"
   - "圆角: 999pt (full pill)"
   - "水平内边距: 16pt"
   - "选中: #1A6B3C 填充 + 白色文字"
   - "未选中: 白底 + #D1D1D6 描边 + 黑色文字"
   - "间距: 8pt"

Below the card, add annotation (13pt gray text): "使用场景：设置页偏好选项、训练记录模式切换、动作库筛选"

---

### Section 3: "BTOverflowMenu — 溢出菜单"

This section shows the context menu that appears when tapping a "more" button. Display it inside a white card. Show both the trigger button and the expanded floating menu.

**Layout inside the white card (top to bottom):**

1. **Context simulation area** (to show the menu in its typical position):
   - A light gray area (280pt height, corner radius 12pt, background `#E5E5EA`) simulating a page backdrop
   - In the top-right area of this gray backdrop, show a **trigger button**: a small circle (36pt diameter, transparent background) containing a "⋮" three-dot vertical icon (SF Symbol `ellipsis.circle`) in 22pt, color `rgba(60,60,67,0.6)`

2. **The floating menu** (appears below/beside the trigger, overlapping the gray backdrop):
   - **Container**: white card, corner radius 16pt, width about 220pt, shadow `0 4pt 16pt rgba(0,0,0,0.12)`
   - **Menu items** (vertical list, each item height 48pt, horizontal padding 16pt):
     - **Item 1**: colored circle icon bg (24pt diameter, `#E8F5E9` light green fill) with SF Symbol icon (share/export) in `#1A6B3C` centered inside + label "生成分享图" in 16pt Regular, color `#000000`, 12pt gap between icon circle and text
     - **Item 2**: colored circle icon bg (24pt, `#E3F2FD` light blue fill) with icon in `#1565C0` + label "移动到某天" in 16pt Regular, color `#000000`
     - **Item 3**: colored circle icon bg (24pt, `#FFF3E0` light amber fill) with icon in `#E65100` + label "编辑心得" in 16pt Regular, color `#000000`
     - **Item 4**: colored circle icon bg (24pt, `#F3E5F5` light purple fill) with icon in `#6A1B9A` + label "导入为模版" in 16pt Regular, color `#000000`
     - **Separator**: 0.5pt line in `#E5E5EA`, inset 16pt from left (after the icon area)
     - **Item 5 (danger)**: colored circle icon bg (24pt, `#FFEBEE` light red fill) with trash icon in `#C62828` + label "删除" in 16pt Regular, color `#C62828`
   - Between each item (except before the separator), thin 0.5pt dividers in `#F2F2F7`

3. **Component specs** (below the context simulation, 12pt spacing, compact vertical list in 13pt, color `rgba(60,60,67,0.6)`):
   - "浮层圆角: 16pt"
   - "菜单项高度: 48pt"
   - "图标: 24pt 彩色圆底"
   - "文字: 16pt Regular"
   - "危险项: 图标 #C62828 + 文字 #C62828"
   - "阴影: 0 4pt 16pt rgba(0,0,0,0.12)"

Below the card, add annotation (13pt gray text): "使用场景：训练详情更多操作、Drill 列表项操作、计划项操作"

---

**Design constraints (strictly enforced):**
- `#1A6B3C` is the ONLY brand green — do not substitute
- `#C62828` is the ONLY destructive red — do not substitute
- Solid flat fills for all UI elements — NO gradients anywhere
- iOS native feel: SF Pro font, clean flat style
- Card corner radius: 12pt for inner simulation areas, 16pt for section wrapper cards
- All spacing follows 8pt grid system
- BTSegmentedTab underline must be exactly 2pt thick and match text width
- BTTogglePillGroup pills must be true capsule shape (999pt radius)
- BTOverflowMenu floating card must have visible shadow to convey elevation above the page
- Visual style must match Design Token sheet (A-01), Button sheet (A-02), List Components sheet (A-03), PremiumLock sheet (A-04), and RestTimer/Indicator sheet (A-05): white cards on gray `#F2F2F7` background, green `#1A6B3C` section titles, no nav bar, no tab bar

---

## 参考截图

建议附加以下参考图帮助 Stitch 理解组件上下文（如果可用）：
- `ref-screenshots/01-training-home/03-home-with-plan-detail.png` — 竞品标签切换（水平文本标签 + 下划线指示器），球迹使用品牌绿 #1A6B3C
- `ref-screenshots/07-profile/05-settings-1.png` — 竞品胶囊选项组（选中/未选中状态），球迹用绿色填充替代蓝色
- `ref-screenshots/05-history-calendar/05-training-detail-more.png` — 竞品溢出菜单（白色浮层 + 图标行列表），球迹使用彩色圆底图标

⚠️ 注意：参考截图目录尚未导入，如有本地文件请手动附加到 Stitch 对话中。

## 使用说明

1. 在 Google Stitch 中**开启新对话**
2. 粘贴上方提示词，可选附加三张参考截图
3. 导出保存到 `tasks/A-06/`
4. 说「审核 A-06」触发审核智能体
