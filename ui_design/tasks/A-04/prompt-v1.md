# Stitch Prompt — A-04: BTPremiumLock 两种模式组件表

> 任务 ID: A-04 | 版本: v1 | 日期: 2026-04-03
> 预检：已读取 A-01/A-02/A-03 decision-log，沿用纯文档组件表风格、品牌色锚定、纯色填充约束；金色 #D4941A 与 A-03 BTDrillCard Pro 角标一致

---

## Stitch 提示词（开启新对话，粘贴以下内容）

Design a **Component Reference Sheet** for an iOS billiards training app called "QiuJi" (球迹). This single-page component inventory showcases **BTPremiumLock**, a paywall/content-lock overlay component with **two distinct modes**: Progressive Lock and Full Overlay. iPhone screen (393x852pt), Light mode, scrollable.

**CRITICAL color rules:**
- Brand green is exactly `#1A6B3C`. Do NOT change it.
- Pro/premium gold is exactly `#D4941A`. Do NOT change it.
- Do NOT use gradients on buttons or solid color fills — all colored UI elements use solid flat fills. The ONLY gradient allowed is the blur/fade transition in the progressive lock mode.

**Page style** (must match our established Design Token sheet, Button sheet, and List Components sheet):
- Page background: `#F2F2F7`
- Content in white cards: `#FFFFFF`, corner radius 16pt, padding 16pt
- Section titles: 22pt Bold Rounded font, color `#1A6B3C`
- No navigation bar, no tab bar — this is a pure design documentation page
- Clean, minimal iOS design system documentation style

---

### Section 1: "BTPremiumLock — 渐进式锁（Progressive Lock）"

This section demonstrates the progressive lock mode inside a white card. The idea: some real content is visible at the top, then it fades into a blurred/frosted area, and below the blur is a gold-themed unlock prompt.

**Layout inside the white card (top to bottom):**

1. **Visible content area** (top portion, about 40% of the card height):
   - Show 2-3 example "training tips" as numbered list items to simulate locked Drill tutorial content:
     - "1. 瞄准时保持身体稳定，前手握杆自然放松" — 15pt Regular, color black `#000000`
     - "2. 出杆保持水平，避免上下抖动影响精度" — 15pt Regular, color black `#000000`
     - "3. 击球后手腕保持固定，不要急于抬头看球" — 15pt Regular, color black `#000000`
   - Each line has 8pt vertical spacing
   - These items look completely normal and readable

2. **Gradient blur transition zone** (about 15% of card height):
   - The text content gradually fades into a frosted/blurred white overlay
   - Use a vertical gradient from transparent at top to opaque white/frosted at bottom
   - There should be a sense of "there's more content below, but you can't read it"
   - You can show 1-2 more faintly visible but unreadable blurred text lines beneath the fade

3. **Gold unlock prompt area** (bottom portion, centered):
   - **Lock icon**: A padlock icon (SF Symbol "lock.fill"), 32pt, solid color `#D4941A` (gold)
   - **Hint text** below icon (8pt spacing): "后面还有 5 条训练要点" in 15pt Regular, color `rgba(60,60,67,0.6)` (secondary gray), centered
   - **Unlock button** below text (16pt spacing): A **gold outline capsule button** (NOT filled) — border 2pt solid `#D4941A`, height 44pt, corner radius 999pt (full pill), horizontal padding 24pt, text "点这里解锁" in 15pt Medium color `#D4941A`, centered. The button interior is transparent/white, only the border and text are gold.

Below the card, add annotation (13pt gray text): "使用场景：Drill 详情被锁内容 / 教学内容渐进展示"

---

### Section 2: "BTPremiumLock — 全遮罩（Full Overlay）"

This section demonstrates the full overlay lock mode. Show a white card that contains a **mock content area** with a **semi-transparent dark overlay** on top.

**Layout inside the white card:**

1. **Background mock content** (the underlying content being locked):
   - Show a simplified mock of a statistics chart area: a few gray bar chart shapes (simple rectangles of varying heights, light gray `#E5E5EA`) and some placeholder text lines ("训练时长趋势", "本周 vs 上周") in 15pt Regular gray — this represents the content that would be locked
   - This content should be slightly visible through the overlay but NOT readable

2. **Semi-transparent overlay** covering the entire mock content area:
   - Background: `rgba(0, 0, 0, 0.45)` (dark semi-transparent, about 45% opacity)
   - Corner radius matching the inner content area: 12pt

3. **Centered lock prompt** (on top of the overlay, vertically and horizontally centered):
   - **Lock icon**: padlock icon "lock.fill", 40pt, solid color `#D4941A` (gold)
   - **Title text** below icon (12pt spacing): "解锁 Pro 查看完整统计" in 17pt Semibold, color `#FFFFFF` (white), centered
   - **Upgrade button** below title (16pt spacing): Solid fill capsule button, height 44pt, corner radius 999pt (full pill), horizontal padding 28pt, solid fill `#D4941A` (gold), text "升级 Pro" in 15pt Medium color `#FFFFFF` (white), centered

Below the card, add annotation (13pt gray text): "使用场景：统计图表锁定 / Pro 计划内容遮罩"

---

### Section 3: "模式对比（Mode Comparison）"

A small comparison summary in a white card with a simple two-column layout:

| Left column | Right column |
|---|---|
| **渐进式锁** | **全遮罩** |
| Partial content visible | Content fully hidden |

Show this as two side-by-side mini cards or a simple table:
- Left mini card: label "渐进式锁" (13pt Semibold, `#1A6B3C`), description "部分内容可见，渐变过渡" (12pt Regular, gray), small thumbnail representation (a tiny version showing visible→blurred→lock)
- Right mini card: label "全遮罩" (13pt Semibold, `#1A6B3C`), description "内容完全遮盖，适合图表" (12pt Regular, gray), small thumbnail representation (a tiny version showing dark overlay+lock)

Below: annotation (13pt gray): "渐进式锁适合文字内容（教学要点），全遮罩适合图表和计划内容"

---

**Design constraints (strictly enforced):**
- `#1A6B3C` is the ONLY brand green — do not substitute
- `#D4941A` is the ONLY gold/amber for Pro premium elements — do not substitute
- The progressive lock's unlock button must be **outline/stroke only** (gold border, transparent fill), NOT a solid gold filled button
- The full overlay's upgrade button IS solid gold filled — these two buttons deliberately contrast
- Solid flat fills for all UI elements — the ONLY gradient allowed is the blur transition in progressive lock
- iOS native feel: SF Pro font, clean flat style
- Card corner radius: 12pt for inner elements, 16pt for section wrapper cards
- All spacing follows 8pt grid system
- Visual style must match Design Token sheet (A-01), Button sheet (A-02), and List Components sheet (A-03): white cards on gray `#F2F2F7` background, green `#1A6B3C` section titles, no nav bar, no tab bar

---

## 参考截图

建议附加这两张参考图帮助 Stitch 理解渐进式锁的视觉效果（如果可用）：
- `ref-screenshots/09-premium-paywall/01-premium-lock.png` — 竞品渐进式锁效果（内容渐变模糊 + 锁图标 + 解锁按钮），球迹中将蓝色替换为金色 #D4941A
- `ref-screenshots/09-premium-paywall/02-premium-lock-2.png` — 竞品部分内容展示锁定效果，球迹中使用品牌金色体系

⚠️ 注意：参考截图目录尚未导入，如有本地文件请手动附加到 Stitch 对话中。

## 使用说明

1. 在 Google Stitch 中**开启新对话**
2. 粘贴上方提示词，可选附加两张参考截图
3. 导出保存到 `tasks/A-04/`
4. 说「审核 A-04」触发审核智能体
