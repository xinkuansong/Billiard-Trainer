# Stitch 修正指令 — E-01 帧4 v2: TrainingSummaryView Dark Mode

> 任务 ID: E-01 | 帧: 4/5 | 版本: v2 | 日期: 2026-04-05
> 审核问题: P4-1 统计卡片内容偏离 / P4-2 Drill 明细重构 / P4-3 Tab 标签错误 / P4-4 心得区改名
> 修正策略: 在 Stitch 同一会话中发送追加修正指令

---

## Stitch 修正指令（在帧4同一对话中追加以下消息）

I need major corrections. The current design has changed the content and layout from the light mode reference. **This must be a pixel-identical color remap.** Please look at the attached light mode screenshot again and fix ALL of these:

### Fix 1: RESTORE the exact statistics cards — correct data, correct layout

Replace the current stat cards with the **exact same 2×3 grid from the light mode screenshot**:

**Row 1 (2 cards side by side):**
- Left card: clock icon `#25A25A` top-right, number **"48"** in 28pt Bold `#FFFFFF`, unit **"分钟"** 13pt `rgba(235,235,240,0.6)` inline, label **"训练时长"** 13pt `rgba(235,235,240,0.6)`
- Right card: checklist icon `#25A25A`, number **"3"**, unit **"项"**, label **"完成项目"**

**Row 2 (2 cards side by side):**
- Left card: grid icon `#25A25A`, number **"12"**, unit **"组"**, label **"总组数"**
- Right card: circle.fill icon `#F5A623` (orange), number **"87"**, unit **"球"**, label **"总进球"**

**Row 3 (1 full-width card):**
- chart.bar icon `#25A25A`, number **"72"** 28pt Bold `#FFFFFF`, **"%"** 20pt Bold `#25A25A` inline, label **"平均成功率"**
- Horizontal progress bar below: 6pt height, 3pt radius, filled 72% in `#25A25A`, track `#3A3A3C`

All cards: `#1C1C1E` background, 12pt radius, 14pt padding, NO shadow. 8pt gaps between cards.

**Remove "平均偏角" and "训练强度" — these do not exist in the app.**

### Fix 2: RESTORE the drill breakdown with correct names, thumbnails, and expanded set details

Replace the current drill cards with **3 cards matching the light mode exactly**:

**Card 1 — "定点红球进袋":**
- Left: billiard table thumbnail 56×56pt (dark felt `#144D2A`, dark rail `#5C2E00`, white + orange balls)
- Right of thumbnail: name **"定点红球进袋"** 17pt Semibold `#FFFFFF`, badge **"入门 L1"** pill `rgba(37,162,90,0.15)` + `#25A25A`, info **"4 组 · 31/40 球"** 13pt `rgba(235,235,240,0.6)`
- Far right: **"78%"** 17pt Semibold `#25A25A`
- Divider: `#38383A` 1px
- **Expanded set detail rows (MUST show all 4 rows):**
  - "第 1 组" `rgba(235,235,240,0.6)` · "8/10" `#FFFFFF` · checkmark `#25A25A`
  - "第 2 组" · "7/10" · checkmark
  - "第 3 组" · "8/10" · checkmark
  - "第 4 组" · "8/10" · checkmark

**Card 2 — "斯诺克直线进袋":**
- Badge: "基础 L0" green. Rate: **"93%"** `#25A25A`. Info: "3 组 · 28/30 球"
- 3 set rows: 10/10, 9/10, 9/10

**Card 3 — "走位练习 A":**
- Badge: "中级 L2" amber pill `rgba(240,173,48,0.15)` + `#F0AD30`. Rate: **"56%"** `rgba(235,235,240,0.6)` (dim). Info: "5 组 · 28/50 球"
- 5 set rows: 6/10, 5/10, 6/10, 5/10, 6/10

### Fix 3: FIX the bottom tab bar labels

The tab labels are wrong. Change to the correct 5 tabs:
1. **"训练"** (active, icon + label in `#25A25A`)
2. **"动作库"** (inactive, `rgba(235,235,240,0.6)`)
3. **"角度"** (inactive)
4. **"记录"** (inactive)
5. **"我的"** (inactive)

Tab bar background: `#1C1C1E`, top separator `#38383A`.

### Fix 4: Rename "教练笔记" back to "训练心得"

In the notes section, change the header from "教练笔记" to **"训练心得"**, with a quote.opening icon in `#25A25A` before it.

Body text: **"今天练习走位感觉明显进步，斯诺克直线进袋成功率很高，走位A还需要加强。"** in 15pt `rgba(235,235,240,0.8)`.

**Summary: Fix all 4 issues. The layout and content must match the attached light mode screenshot exactly — only colors change to dark mode tokens.**

---

## 推荐操作

1. 在帧4 的 Stitch **同一对话**中发送以上修正消息
2. **再次附加** `tasks/P0-06/stitch_task_p0_06_trainingsummaryview_02/screen.png` 并说 "Match this layout and content exactly, only change colors"
3. 导出保存到 `tasks/E-01/`
4. 完成后说 **"审核 E-01 帧3帧4"** 触发修改后审核
