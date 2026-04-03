# Stitch Prompt — P0-01 v2（增量修正指令）

> 任务 ID: P0-01 | 版本: v2 | 日期: 2026-04-03
> 基于 review-v1.md 审核意见，在 Stitch 同一会话中发送以下修正消息

---

## Stitch 修正消息（在同一会话中发送）

Please make the following 7 corrections to the Training Home screen:

**1. (CRITICAL) Navigation bar — switch to iOS native large title style:**
- Remove the dark green header bar entirely (the `bg-emerald-900/80` section).
- Replace with iOS native large title layout: the title "训练" should be displayed directly on the `#F2F2F7` page background, left-aligned with 16pt left margin, in **34pt Bold Rounded** font, color `#000000` (pure black).
- The two icon buttons (group + more) should sit on the same row as the title, right-aligned. Change their style to: simple icon buttons with `#000000` icons on transparent background (no circle backgrounds), 24pt icon size, 44pt tap area. Think of how Apple's Settings or Health app shows their large title with right-side action buttons.

**2. Training name font size — increase to 20pt:**
- In the "今日安排" and "即将到来" sections, change the training name (e.g. "五分点专项 #1") from `text-[17px]` to `text-[20px]` (20pt Bold).

**3. Section header color — change to black:**
- Change "今日安排" and "即将到来" section headers from the current muted gray color (`text-on-surface-variant`) to `#000000` (pure black), font-weight Bold (not just semibold).

**4. GO! button shape — rectangle not pill:**
- Change the GO! button from `rounded-full` (pill shape) to `rounded-lg` (approximately 8pt corner radius). Keep the green fill `#1A6B3C`, white bold text, and similar padding.

**5. PRO badge — light gold background with gold text:**
- Change the PRO badge from solid gold fill + white text to: background `rgba(212,148,26,0.12)` (very light gold) + text color `#D4941A` (gold) + `rounded-full` pill shape + font-weight bold + padding `px-2 py-0.5`.

**6. Add missing "综合" filter chip:**
- Add a 6th filter chip "综合" after "高级", using the same unselected style (white background, gray border, dark text).

**7. Plan card level badges — use colored pill style:**
- Change the level badges on plan cards from gray rectangular tags to colored pill badges:
  - "入门" badge: background `rgba(26,107,60,0.12)`, text `#1A6B3C`, `rounded-full`, 11pt font, bold
  - "初级" badge: same green style as 入门
  - "中级" badge: background `rgba(212,148,26,0.12)`, text `#D4941A`, `rounded-full`, 11pt font, bold

Keep everything else unchanged — the page structure, card layouts, plan thumbnails, bottom button, and tab bar are all good.

---

## 使用方式

1. 在 Stitch 的 **同一对话** 中，粘贴上面的修正消息
2. Stitch 会生成新版本（保留好的部分，只修改上述 7 项）
3. 将新的导出文件夹保存到 `tasks/P0-01/stitch_task_p0_01_02/`（或 Stitch 自动命名）
4. 完成后说 **"审核 P0-01"** 触发第二轮审核
