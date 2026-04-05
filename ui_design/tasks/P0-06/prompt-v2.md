# Stitch 修正指令 — P0-06 v2

> 任务 ID: P0-06 | 版本: v2（增量修正） | 日期: 2026-04-04
> 基于 review-v1.md 审核意见生成的修正指令
> 在对应 Stitch 对话中追加发送以下修正消息

---

## 帧 1 修正 — TrainingSummaryView（在帧 1 的 Stitch 对话中发送）

Please make the following corrections to the Training Summary Screen:

**1. Fix the bottom tab bar labels (CRITICAL):**
The 5 tab labels must be exactly: **训练 / 动作库 / 角度 / 记录 / 我的**. Currently they say "动作 / 工具 / 历史" which is wrong. Change:
- Tab 2: "动作" → **"动作库"**
- Tab 3: "工具" → **"角度"** (use a `straighten` or angle-related icon)
- Tab 4: "历史" → **"记录"**
Keep 训练 (selected, `#1A6B3C`) and 我的 as-is. All unselected tabs use `rgba(60,60,67,0.45)`.

**2. Fix page background color:**
Change the body/page background from `#F8F9FA` to exactly **`#F2F2F7`** (iOS system light gray). This is the standard iOS grouped background color we use across all screens.

**3. Fix the "生成分享图" secondary button:**
The second button currently has a gray border and black text. Change it to:
- Border: **1.5pt solid `#1A6B3C`** (brand green outline)
- Text color: **`#1A6B3C`** (brand green), 17pt Regular
- Icon: change from `image` to **`share`** (share/export icon), color `#1A6B3C`
- Background remains `#FFFFFF`
- Keep the same height (44pt) and corner radius (12pt)

**4. Expand all Drill set detail rows:**
Currently Drill Cards 2 and 3 show a collapsed "各组详情 ▼" instead of listing each set. Card 1 only shows 1 set row. Please expand ALL set rows for ALL 3 drill cards:

- **Drill Card 1** "定点红球进袋": Show 4 rows — 第1组 8/10 ✓, 第2组 7/10 ✓, 第3组 8/10 ✓, 第4组 8/10 ✓
- **Drill Card 2** "斯诺克直线进袋": Show 3 rows — 第1组 10/10 ✓, 第2组 9/10 ✓, 第3组 9/10 ✓
- **Drill Card 3** "走位练习 A": Show 5 rows — 第1组 6/10 ✓, 第2组 5/10 ✓, 第3组 6/10 ✓, 第4组 5/10 ✓, 第5组 6/10 ✓

Each row format: "第 X 组" on the left (14pt, `rgba(60,60,67,0.6)`) · "X/10" in the middle (14pt, `#000000`) · green checkmark `checkmark.circle.fill` on the right (16pt, `#1A6B3C`).

**5. Fix stat card labels to iOS native style:**
The stat card labels currently use 11px bold uppercase with tracking (editorial style). Change them to:
- Font size: **13pt Regular** (not bold, not uppercase)
- Color: **`rgba(60,60,67,0.6)`** (iOS system secondary label), NOT `#64748B`
- Normal case (e.g. "训练时长" not "训练时长" in uppercase) — keep the Chinese text as-is, just fix the font weight and color
- Apply this change to all 5 stat cards' label text

**6. Fix stat card proportions:**
Remove the `aspect-square` constraint from the 4 small stat cards. Let them have auto height based on content. They should be compact rectangles (roughly 1.2:1 width:height ratio or auto), not tall squares. The icon stays at top-right, the number+unit at bottom-left, and the label below. Reduce vertical padding if needed to make cards more compact.

**7. Fix BTLevelBadge to pill shape:**
The level badges on drill cards (e.g. "入门 L1", "基础 L0", "中级 L2") currently use `rounded-md`. Change to **`rounded-full`** (corner radius 999pt, pill shape) to match the BTLevelBadge component spec.

---

## 帧 2 修正 — TrainingShareView（在帧 2 的 Stitch 对话中发送）

Please make the following corrections to the Training Share Card Screen:

**1. Fix Tailwind primary color in config (CRITICAL):**
In the Tailwind config, change `"primary": "#005129"` to **`"primary": "#1A6B3C"`**. This is critical — `#005129` is the wrong green. Our brand green is `#1A6B3C` and must be set as the primary color in the Tailwind configuration.

**2. Add text labels below color theme circles:**
Each color theme circle in the "颜色" row must have a **text label below it**. Add these labels:
- Circle 1 (dark `#1C1C1E` with green ring — selected): label **"基础绿"** in 11pt, color `#000000`
- Circle 2 (half black/half white): label **"黑白"** in 11pt, color `rgba(60,60,67,0.6)`
- Circle 3 (dark navy `#0D1B2A`): label **"暗夜蓝"** in 11pt, color `rgba(60,60,67,0.6)`
- Circle 4 (light gray `#F2F2F7` with + icon): label **"更多"** in 11pt, color `rgba(60,60,67,0.6)`

Place each label centered below its circle with 6pt gap. The selected theme ("基础绿") label should be `#000000` (darker) to indicate active state.

**3. Fix the "隐藏球台图" pill text truncation:**
The third option pill "隐藏球台图" is being cut off. Fix this by either:
- Reducing the horizontal padding of all three option pills from `px-4` to `px-3`
- Or reducing the font size from 13pt to 12pt
- Ensure all three pills ("隐藏备注", "隐藏成功率", "隐藏球台图") display their full text without truncation within the screen width.

---

## 参考截图使用说明

同 v1，将以下截图附加到对应 Stitch 对话中（可选但推荐）：

| 帧 | 推荐截图 | 说明 |
|----|---------|------|
| 帧 1（TrainingSummaryView）| `ref-screenshots/02-training-active/07-training-summary.png` | 布局参考 |
| 帧 2（TrainingShareView）| `ref-screenshots/02-training-active/07-training-summary.png` | 定制控件参考 |
| 帧 2（TrainingShareView）| `ref-screenshots/02-training-active/08-training-summary-scrolled.png` | 分享目标按钮参考 |

---

## 修正项与审核问题对应关系

| 帧 | 修正项 | 对应审核问题 | 优先级 |
|----|--------|------------|--------|
| 1 | Tab 栏标签 | 问题 1【高】 | 必须 |
| 1 | 背景色 | 问题 2【高】 | 必须 |
| 1 | 按钮边框 | 问题 3【高】 | 必须 |
| 1 | Drill 详情展开 | 问题 4【中】 | 必须 |
| 1 | 标签样式 | 问题 5【中】 | 推荐 |
| 1 | 卡片比例 | 问题 6【低】 | 推荐 |
| 1 | 药丸形徽章 | 建议 1 | 推荐 |
| 2 | Primary 色值 | 问题 1【高】 | 必须 |
| 2 | 颜色标签 | 问题 2【中】 | 必须 |
| 2 | 文字截断 | 问题 3【中】 | 推荐 |
