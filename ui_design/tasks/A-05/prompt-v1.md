# Stitch Prompt — A-05: BTRestTimer + BTFloatingIndicator 组件表

> 任务 ID: A-05 | 版本: v1 | 日期: 2026-04-03
> 预检：已读取 A-01~A-04 decision-log，沿用纯文档组件表风格、品牌色 #1A6B3C 锚定、纯色填充无渐变约束；琥珀色 #D4941A 延续 A-04 Pro 金色体系

---

## Stitch 提示词（开启新对话，粘贴以下内容）

Design a **Component Reference Sheet** for an iOS billiards training app called "QiuJi" (球迹). This single-page component inventory showcases two training-related components: **BTRestTimer** (rest countdown between sets) and **BTFloatingIndicator** (floating training indicator). iPhone screen (393x852pt), Light mode, scrollable.

**CRITICAL color rules:**
- Brand green is exactly `#1A6B3C`. Do NOT change it.
- Amber/gold accent is exactly `#D4941A`. Do NOT change it.
- Do NOT use gradients on buttons or solid color fills — all colored UI elements use solid flat fills.

**Page style** (must match our established Design Token sheet, Button sheet, List Components sheet, and PremiumLock sheet):
- Page background: `#F2F2F7`
- Content in white cards: `#FFFFFF`, corner radius 16pt, padding 16pt
- Section titles: 22pt Bold Rounded font, color `#1A6B3C`
- No navigation bar, no tab bar — this is a pure design documentation page
- Clean, minimal iOS design system documentation style

---

### Section 1: "BTRestTimer — 组间休息倒计时"

This section shows the rest timer component used between training sets. Display it inside a white card with a mock dark backdrop to simulate its modal presentation context.

**Layout inside the white card (top to bottom, centered):**

1. **Dark backdrop simulation** (to show the timer in its typical modal context):
   - A rounded rectangle area (corner radius 12pt) with background `#1C1C1E` (dark gray, simulating the dimmed background), height about 360pt, full card width minus padding
   - Everything below is centered within this dark area

2. **Concentric dual-ring progress indicator** (centered in the dark area):
   - **Outer ring**: 200pt diameter, stroke width 12pt, color `#1A6B3C` (brand green). This represents total rest progress. Show it about 75% filled (clockwise from top, with the remaining 25% as a faint `rgba(26,107,60,0.2)` track)
   - **Inner ring**: 160pt diameter (concentric, inside the outer ring), stroke width 10pt, color `#D4941A` (amber/gold). This represents remaining seconds. Show it about 45% filled (clockwise from top, with the remaining 55% as a faint `rgba(212,148,26,0.2)` track)
   - Both rings should have rounded end caps
   - The gap between rings should be clearly visible

3. **Center content** (inside the rings, vertically centered):
   - **Countdown number**: "0:23" in 32pt Bold, color `#FFFFFF`, centered
   - **Rest type label** below: "组间休息" in 13pt Regular, color `rgba(255,255,255,0.6)`, centered, 4pt below the number

4. **Action buttons** (below the rings, still inside the dark area, 24pt below the outer ring):
   - Two buttons side by side, centered, 12pt gap between them:
   - **Left button**: "+30s" — secondary style: height 44pt, corner radius 999pt (pill), background `rgba(255,255,255,0.15)`, text "+30s" in 15pt Medium, color `#FFFFFF`, horizontal padding 20pt
   - **Right button**: "完成" — primary style: height 44pt, corner radius 999pt (pill), solid fill `#1A6B3C`, text "完成休息" in 15pt Medium, color `#FFFFFF`, horizontal padding 24pt

Below the card, add annotation (13pt gray text): "使用场景：训练记录中组间休息倒计时，以半透明弹层形式覆盖训练页"

---

### Section 2: "BTFloatingIndicator — 浮动训练指示器"

This section shows the floating indicator that appears when a user navigates away from an active training session. Display it inside a white card.

**Layout inside the white card (top to bottom):**

1. **Context simulation area** (to show the indicator in its typical position):
   - A light gray area (240pt height, corner radius 12pt, background `#E5E5EA`) simulating a non-training tab page
   - Inside this gray area, show a faint mock of a tab page — a centered text "动作库" in 17pt Regular `rgba(0,0,0,0.3)` near the top, and a few light placeholder lines below to suggest content
   - At the very bottom of this gray area, show a simplified mock tab bar: a thin horizontal strip (49pt height, background `#F9F9F9`, top border 0.5pt `#C6C6C8`) with 4 small gray circle icons evenly spaced (simulating tab items)

2. **The floating indicator** (positioned above the mock tab bar):
   - **Position**: right-aligned, 16pt from right edge, 8pt above the mock tab bar's top edge
   - **Shape**: capsule/pill (corner radius 999pt), height 44pt, horizontal padding 16pt
   - **Background**: solid `#1A6B3C` (brand green)
   - **Shadow**: `0 2pt 8pt rgba(0,0,0,0.15)` (subtle elevation)
   - **Content**: white text "训练中 12:34 ←" in 15pt Medium, color `#FFFFFF`
   - The "←" arrow suggests "tap to return to training"

3. **Component specs callout** (below the context simulation, 16pt spacing):
   - A small specs summary in 13pt:
     - "高度: 44pt"
     - "圆角: 999pt (full pill)"
     - "背景: #1A6B3C"
     - "位置: Tab 栏上方 8pt, 右对齐"
     - "阴影: 0 2pt 8pt rgba(0,0,0,0.15)"
   - Displayed as a compact vertical list, color `rgba(60,60,67,0.6)`

Below the card, add annotation (13pt gray text): "使用场景：训练进行中用户切换到其他 Tab 时，全局持续显示浮动胶囊，点击可返回训练"

---

### Section 3: "BTFloatingIndicator — 尺寸与细节"

A white card showing an enlarged/isolated view of just the floating indicator itself.

**Layout inside the white card (centered):**

1. **Enlarged indicator**: Show the capsule at 1.5x scale (66pt height) for detail visibility:
   - Solid `#1A6B3C` background, corner radius 999pt
   - White text "训练中 12:34 ←" in 22pt Medium (scaled up), centered
   - Visible shadow: `0 3pt 12pt rgba(0,0,0,0.15)`

2. **Dimension annotations** (around the enlarged indicator, using thin gray lines and labels):
   - Height label: "44pt" with a vertical dimension line on the right side
   - Padding label: "16pt" arrows on left and right inside the capsule
   - An annotation line pointing to the shadow: "阴影增强浮层感"

Below the card, add annotation (13pt gray text): "支持呼吸动画（轻微上下浮动），增强视觉吸引力"

---

**Design constraints (strictly enforced):**
- `#1A6B3C` is the ONLY brand green — do not substitute
- `#D4941A` is the ONLY amber/gold for accent elements — do not substitute
- Solid flat fills for all UI elements — NO gradients anywhere
- iOS native feel: SF Pro font, clean flat style
- Card corner radius: 12pt for inner elements, 16pt for section wrapper cards
- All spacing follows 8pt grid system
- BTRestTimer dual rings must be clearly distinguishable (green outer + amber inner, visible gap)
- BTFloatingIndicator must look like it's floating above the page (shadow is essential)
- Visual style must match Design Token sheet (A-01), Button sheet (A-02), List Components sheet (A-03), and PremiumLock sheet (A-04): white cards on gray `#F2F2F7` background, green `#1A6B3C` section titles, no nav bar, no tab bar

---

## 参考截图

建议附加以下参考图帮助 Stitch 理解组件上下文（如果可用）：
- `ref-screenshots/02-training-active/05-active-rest-timer.png` — 竞品休息倒计时弹层效果（同心双环 + 中心倒计时 + 操作按钮），球迹使用绿色外环 + 琥珀色内环
- `ref-screenshots/09-premium-paywall/04-paywall-selected.png` — 右下角浮动胶囊的位置参考（品牌绿色背景 + 白色文字）

⚠️ 注意：参考截图目录尚未导入，如有本地文件请手动附加到 Stitch 对话中。

## 使用说明

1. 在 Google Stitch 中**开启新对话**
2. 粘贴上方提示词，可选附加两张参考截图
3. 导出保存到 `tasks/A-05/`
4. 说「审核 A-05」触发审核智能体
