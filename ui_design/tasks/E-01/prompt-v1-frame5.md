# Stitch Prompt — E-01 帧5: PlanListView + PlanDetailView Dark Mode

> 任务 ID: E-01 | 帧: 5/5 | 版本: v1 | 日期: 2026-04-05
> Light Mode 基准:
>   - 帧5a PlanListView: P2-01 帧1 v2 (`tasks/P2-01/stitch_task_p2_01_planlistview_02/screen.png`)
>   - 帧5b PlanDetailView: P2-01 帧2 v1 (`tasks/P2-01/stitch_task_p2_01_plandetailview/screen.png`)
> 两个页面均为 push 子页面模式，无 Tab 栏
> P2-01 决策 2: 卡片沿用 P1-01 缩略图+内容+chevron | 决策 3: Pro CTA 金色填充
> 本帧包含两个子帧，需分别在两个 Stitch 对话中生成

---

## 帧5a — PlanListView Dark Mode

### Stitch 提示词（开启新对话，粘贴以下内容）

Design the **Dark Mode variant** of the Training Plan List screen for an iOS billiards training app called "QiuJi" (球迹). This is a push sub-page showing all training plans organized by difficulty level. iPhone screen (393 × 852pt), **Dark mode**, scrollable.

**CRITICAL: This is a color-mapping exercise. The layout, spacing, element positions, and content must be IDENTICAL to the attached light mode screenshot. Only colors change.**

**CRITICAL — this is a push sub-page:**
- Standard iOS navigation bar with back arrow (not large title)
- **NO bottom 5-tab bar**
- Standard bottom safe area only

**CRITICAL color rules (Dark Mode):**
- Brand green is `#25A25A`. Do NOT use #1A6B3C or #005129.
- Page background: `#000000` (pure black, OLED)
- Card background: `#1C1C1E`
- Text primary: `#FFFFFF`
- Text secondary: `rgba(235,235,240,0.6)`
- Text tertiary: `rgba(235,235,240,0.3)`
- Separator/border: `#38383A`
- Pro/gold accent: `#F0AD30`
- No gradients, no shadows — color-layer contrast only.

**Overall style:**
- iOS native, SF Pro / SF Symbols, Dark Mode
- White status bar text (light content)
- Canvas width: 393px

---

#### Navigation Bar (Dark Mode)

- **Left**: back chevron + **"训练"**, color `#25A25A` (brand green Dark)
- **Center**: **"训练计划"** 17pt Semibold `#FFFFFF`
- **Right**: **"新建"** 17pt Regular `#25A25A`
- Background: `#000000` blending with page, bottom separator `#38383A` (0.5pt)

---

#### Official Plans Section

**Section header**: "官方计划" 13pt Semibold `rgba(235,235,240,0.6)`, 16pt margin

**Level group headers**: 18pt Bold `#FFFFFF` (e.g. "入门计划", "中级计划", "高级计划")

**Plan Cards** (background `#1C1C1E`, radius 12pt, 16pt padding, NO shadow):

- **Thumbnail**: 72×72pt, radius 10pt, billiard-themed — use Dark Mode table colors: subtle `#144D2A` green background with muted ball graphics
- **Name**: 17pt Semibold `#FFFFFF`
- **Tag row**:
  - BTLevelBadge Dark variants:
    - L0 "入门": solid `#25A25A` fill + white text
    - L1 "初学": `rgba(37,162,90,0.15)` fill + `#25A25A` text
    - L2 "进阶": `rgba(240,173,48,0.15)` fill + `#F0AD30` text
    - L3 "熟练": `rgba(255,152,0,0.15)` fill + `#FF9800` text
  - Duration: "8 周" pill — `#2C2C2E` fill + `#FFFFFF` text
  - Gap: 6pt
- **Description**: 13pt Regular `rgba(235,235,240,0.6)`, 1-2 lines
- **PRO badge** (if locked): `rgba(240,173,48,0.15)` fill + `#F0AD30` text
- **Chevron**: `rgba(235,235,240,0.3)`

**6 official plans + 1 custom:**

入门计划 group (FREE):
1. "新手入门 8 周计划" — L0, 8 周
2. "基础杆法专项" — L1, 4 周

中级计划 group (PRO):
3. "走位突破训练" — L2 进阶, 6 周, **PRO**
4. "中级综合突破" — L2 进阶, 8 周, **PRO**

高级计划 group (PRO):
5. "高级加塞与多库" — L3 熟练, 6 周, **PRO**
6. "全能综合计划" — L3 熟练, 12 周, **PRO**

---

#### Custom Plans Section

Header: "自定义计划" 13pt Semibold `rgba(235,235,240,0.6)`, 24pt top margin

1 card: "我的练球日常" — custom icon thumbnail (`#25A25A` solid + white icon), "3 项训练", no PRO badge, chevron

---

#### Design Tokens (Dark Mode)

| Token | Value |
|-------|-------|
| Primary | `#25A25A` |
| Accent/Pro | `#F0AD30` |
| Background | `#000000` |
| Card | `#1C1C1E` |
| Tertiary bg | `#2C2C2E` |
| Text primary | `#FFFFFF` |
| Text secondary | `rgba(235,235,240,0.6)` |
| Text tertiary | `rgba(235,235,240,0.3)` |
| Separator | `#38383A` |
| L0 badge | `#25A25A` solid + white |
| L1 badge | `rgba(37,162,90,0.15)` + `#25A25A` |
| L2 badge | `rgba(240,173,48,0.15)` + `#F0AD30` |
| L3 badge | `rgba(255,152,0,0.15)` + `#FF9800` |
| Card radius | 12pt |
| Thumbnail | 72×72pt, radius 10pt |
| Padding | 16pt |

#### State

Dark Mode variant of PlanListView. 6 official plans (2 free, 4 Pro) in 3 level groups + 1 custom plan. Layout identical to light mode.

---

### 帧5a 推荐附加参考截图

**必须附加：**
1. **`tasks/P2-01/stitch_task_p2_01_planlistview_02/screen.png`** — Light Mode 已通过版本

**可选：**
2. `tasks/E-01/stitch_task_*/screen.png` — 已完成的 Dark Mode 帧（风格基准）

> 提示："Recreate this exact plan list layout in Dark Mode. Cards use #1C1C1E on #000000. Level badges use brighter Dark Mode colors."

---

## 帧5b — PlanDetailView (Pro Lock) Dark Mode

### Stitch 提示词（开启新对话，粘贴以下内容）

Design the **Dark Mode variant** of the Training Plan Detail screen for an iOS billiards training app called "QiuJi" (球迹). This shows a Pro-locked plan with weekly schedule and progressive blur lock. iPhone screen (393 × 852pt), **Dark mode**, scrollable.

**CRITICAL: Layout identical to the attached light mode screenshot. Only colors change.**

**CRITICAL — push sub-page, no tab bar.**

**CRITICAL color rules (Dark Mode):**
- Brand green: `#25A25A`. Do NOT use #1A6B3C.
- Pro/gold: `#F0AD30` (brighter than light mode's #D4941A)
- Page background: `#000000`
- Card background: `#1C1C1E`
- Text primary: `#FFFFFF`
- Text secondary: `rgba(235,235,240,0.6)`
- Separator: `#38383A`
- No gradients on solid elements, no card shadows.

**Style:** iOS native, Dark Mode, white status bar, 393px canvas.

---

#### Navigation Bar

- **Left**: chevron + **"训练计划"** `#25A25A`
- **Center**: **"走位突破训练"** 17pt Semibold `#FFFFFF`
- **Right**: share icon `rgba(235,235,240,0.6)`
- Background: `#000000`, separator `#38383A`

---

#### Plan Header Card

Background `#1C1C1E`, radius 16pt, 16pt padding:

- **Name**: "走位突破训练" 22pt Bold Rounded `#FFFFFF`
- **Tags**: L2 "进阶" amber pill `rgba(240,173,48,0.15)` + `#F0AD30` | "6 周" pill `#2C2C2E` + `#FFFFFF` | "PRO" pill `rgba(240,173,48,0.15)` + `#F0AD30`
- **Description**: 15pt Regular `rgba(235,235,240,0.6)`, 3 lines max

**Statistics row** (divider `#38383A` above):
- "42" + "训练天数" | "18" + "训练项目" | "45 分钟" + "预计每日"
- Numbers: 28pt Bold `#FFFFFF`, labels: 13pt `rgba(235,235,240,0.6)`

---

#### Gold CTA Button

Full width, 50pt, radius 12pt:
- Background: `#F0AD30` (gold Dark) solid fill
- Text: **"解锁此计划"** 16pt Semibold `#FFFFFF`
- Lock icon (lock.fill) white, before text

---

#### Weekly Schedule

Section title: "训练安排" 18pt Bold `#FFFFFF`

**Week cards** (background `#1C1C1E`, radius 12pt, 16pt padding):

**Week 1** (expanded):
- Header: "第 1 周" 16pt Semibold `#FFFFFF` + chevron.down `rgba(235,235,240,0.3)`
- Separator: `#38383A`
- Day labels: "第 1 天" 14pt Semibold `rgba(235,235,240,0.6)`
- Drill items: "• 直线球定点练习 — 3 组 × 15 球" 14pt Regular `#FFFFFF`

**Week 2** (collapsed):
- "第 2 周" + chevron.right

---

#### BTPremiumLock Progressive Blur (Dark Mode)

After Week 2, content fades into blur on `#000000` background:

- **Blur transition**: Week 3 card starts visible then fades via gaussian blur over ~60pt — the blur blends into pure black `#000000` (not gray like light mode)
- **Lock zone** (centered below blur):
  - Amber circle: 56pt, fill `rgba(240,173,48,0.2)` (darker than light mode's #FFDDAF — adapted for dark bg), lock icon `#F0AD30` 24pt
  - Prompt: "后面还有 4 周训练计划" 15pt Semibold `#FFFFFF`
  - Secondary: "解锁 Pro 查看完整计划" 13pt Regular `rgba(235,235,240,0.6)`
  - Gold outline button: "点这里解锁" — border 1.5pt `#F0AD30` + text `#F0AD30` 14pt Semibold, pill 999pt radius, 36pt height, **outline only NOT filled**

---

#### Design Tokens (Dark Mode)

| Token | Value |
|-------|-------|
| Primary | `#25A25A` |
| Gold/Pro | `#F0AD30` — USE THIS (not #D4941A) |
| Gold CTA fill | `#F0AD30` solid |
| Gold outline | `#F0AD30` border 1.5pt |
| Lock circle bg | `rgba(240,173,48,0.2)` |
| Background | `#000000` |
| Card | `#1C1C1E` |
| Tertiary | `#2C2C2E` |
| Text primary | `#FFFFFF` |
| Text secondary | `rgba(235,235,240,0.6)` |
| Separator | `#38383A` |
| Card radius | 12pt / 16pt (header) |
| Padding | 16pt |

#### Constraints

- BTPremiumLock blur fades into pure BLACK (not gray) — the transition must feel natural on OLED
- Gold CTA at top is FILLED `#F0AD30`; in-content "点这里解锁" is OUTLINE only — intentional hierarchy
- Lock amber circle uses semi-transparent gold `rgba(240,173,48,0.2)` on dark background (not light mode's opaque #FFDDAF)
- Week card expanded/collapsed states use same card bg `#1C1C1E`

#### State

Dark Mode variant of Pro-locked plan "走位突破训练". L2 进阶, 6 weeks. Week 1 expanded, Week 2 collapsed, Weeks 3-6 behind BTPremiumLock blur. Gold CTA at top + gold outline button in lock zone. Layout identical to light mode.

---

### 帧5b 推荐附加参考截图

**必须附加：**
1. **`tasks/P2-01/stitch_task_p2_01_plandetailview/screen.png`** — Light Mode 已通过版本

**可选：**
2. `tasks/E-01/stitch_task_*/screen.png` — 帧5a 完成后附加作为 Dark Mode 风格一致性参考

> 提示："Recreate this plan detail page in Dark Mode. The BTPremiumLock blur fades to pure black. Gold elements use #F0AD30 (brighter than light mode)."

---

## Stitch 导出处理

1. 帧5a（PlanListView Dark）和 帧5b（PlanDetailView Dark）分别导出
2. 所有文件夹保存到 `tasks/E-01/` 目录下
3. **E-01 全部 5 帧完成后**，说 **"审核 E-01"** 触发整体审核
