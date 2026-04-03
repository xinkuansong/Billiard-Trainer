# Stitch Prompt — A-02: BTButton 7 Styles Component Sheet

> 任务 ID: A-02 | 版本: v1 (预检后重生成) | 日期: 2026-04-03
> 预检：已读取 A-01 decision-log，补充了品牌色锚定和纯色填充约束

---

## Stitch 提示词（开启新对话，粘贴以下内容）

Design a **Button Style Reference Sheet** for an iOS billiards training app called "QiuJi" (球迹). This single-page component inventory shows all 7 button styles in Default and Disabled states. iPhone screen (393x852pt), Light mode, scrollable.

**CRITICAL color rule:** The brand green is exactly `#1A6B3C`. Do NOT change it to any other value. Do NOT use gradients — all buttons use solid flat fills only.

**Page style** (must match our established Design Token sheet):
- Page background: `#F2F2F7`
- Content in white cards: `#FFFFFF`, corner radius 16pt, padding 16pt
- Section titles: 22pt Bold Rounded font, color `#1A6B3C`
- Clean, minimal iOS design system documentation style

---

### Section 1: "BTButton — 7 Styles"

For each of the 7 styles below, show **two versions side by side**: "Default" on the left, "Disabled" (50% opacity) on the right. Below each pair, show the style name (15pt Semibold black) and a usage description (13pt gray `rgba(60,60,67,0.6)`).

**1. primary**
- Full-width, height 50pt, corner radius 12pt
- Solid fill `#1A6B3C` (NO gradient), white text "开始训练" 16pt Medium centered
- Disabled: identical layout at 50% opacity
- Label: "primary — 主操作（开始训练、确认、保存）"

**2. secondary**
- Full-width, height 50pt, corner radius 12pt
- White background, 1.5pt border color `#1A6B3C`, text "复制到今天" in `#1A6B3C` 16pt Medium centered
- Disabled: 50% opacity
- Label: "secondary — 次要操作（复制、编辑）"

**3. text**
- No background, no border, inline
- Text "跳过" in `#1A6B3C` 16pt Medium
- Disabled: 50% opacity
- Label: "text — 文字链接（跳过、取消）"

**4. destructive**
- Full-width, height 50pt, corner radius 12pt
- Solid fill `#C62828` (red), white text "删除训练" 16pt Medium centered
- Disabled: 50% opacity
- Label: "destructive — 危险操作（删除、结束训练）"

**5. darkPill**
- Pill shape (corner radius 999pt), height 40pt, horizontal padding 20pt, inline (not full-width)
- Solid fill `#1C1C1E`, white text "关闭" 15pt Medium
- Disabled: 50% opacity
- Label: "darkPill — 深色场景关闭/返回按钮"

**6. iconCircle**
- Circle, 48pt diameter
- Solid fill `#1A6B3C`, white "+" icon centered (24pt, SF Symbols style)
- Show a second example beside it: same circle with white checkmark icon
- Disabled: 50% opacity (show only one disabled circle)
- Label: "iconCircle — 工具栏图标按钮（48pt 圆形）"

**7. segmentedPill**
- Horizontal row of 3 pill-shaped options (like iOS segmented control)
- Each pill: height 36pt, horizontal padding 16pt, corner radius 999pt, gap 8pt between pills
- Selected pill: solid fill `#1A6B3C`, white text 15pt Medium (text: "弹出")
- Unselected pills: white fill, 1pt border `#C6C6C8`, black text 15pt Medium (text: "不弹出", "延迟")
- Show one row Default (first selected), one row Disabled (50% opacity)
- Label: "segmentedPill — 分段选项组（偏好设置）"

---

### Section 2: "Button Hierarchy — 3-Tier System"

Show a mock confirmation dialog (white card, corner radius 16pt, padding 24pt, centered on page) to demonstrate the 3-tier button visual hierarchy:

- A party popper emoji at the top center
- Title "完成训练" in 20pt Semibold, centered
- Subtitle "是否已经完成训练" in 15pt Regular gray, centered
- 24pt spacing, then 3 buttons stacked vertically with 12pt gaps:
  - **Tier 1** (strongest): full-width primary "完成并生成分享图" — solid `#1A6B3C`, white text
  - **Tier 2** (medium): text "完成训练" — black 16pt Medium, no background
  - **Tier 3** (weakest): text "取消" — gray `rgba(60,60,67,0.6)` 16pt Regular, no background

---

### Section 3: "Touch Target Rule"

Small annotation card at the bottom: a 44x44pt dashed-border square with the label "最小触控区域 44×44pt" (13pt gray). Brief note: "All buttons must meet this minimum touch target."

---

**Design constraints (strictly enforced):**
- `#1A6B3C` is the ONLY brand green — do not substitute
- `#C62828` for destructive red
- `#D4941A` amber/gold for Pro elements (not used in this sheet)
- Solid flat fills ONLY — absolutely no gradients on any button
- iOS native feel: SF Pro font, clean flat style
- Visual style must match the Design Token sheet (A-01): white cards on gray background, green section titles

---

## 参考截图

建议附加这两张参考图帮助 Stitch 理解按钮层级和胶囊选项样式：
- `ref-screenshots/02-training-active/06-active-end-confirm.png` — 训记确认弹窗的三级按钮层级（蓝色填充 > 黑色文字 > 灰色文字），球迹中蓝色替换为绿色 #1A6B3C
- `ref-screenshots/07-profile/05-settings-1.png` — 训记设置页的 segmentedPill 胶囊选项组（选中蓝色填充 + 未选中白底），球迹中蓝色替换为绿色 #1A6B3C

## 使用说明

1. 在 Google Stitch 中**开启新对话**
2. 粘贴上方提示词，可选附加两张参考截图
3. 导出保存到 `tasks/A-02/`
4. 说「审核 A-02」
