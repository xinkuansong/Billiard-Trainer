# Stitch Prompt — A-01 v2 (增量修正)

> 任务 ID: A-01 | 版本: v2 | 日期: 2026-04-03
> 基于 review-v1.md 审核意见的修正指令，在 Stitch 同一会话中追加发送

---

## Stitch 修正提示词（在同一对话中追加发送）

Please fix the following issues in the Design Token sheet:

**1. Fix all color values (CRITICAL — do not change these colors):**

The brand primary color MUST be exactly `#1A6B3C`, not `#005129`. Please update:
- btPrimary swatch: `#1A6B3C` (this is THE brand color, do not use any other green)
- btAccent swatch: `#D4941A` (amber gold, not #805600 or #FCB73F)
- btText: `#000000` (pure black, not #1A1C1F)
- btTextSecondary: `rgba(60,60,67,0.6)` (not on-surface-variant)
- Page background: `#F2F2F7` (not #F9F9FE)

Do NOT introduce any colors not in the original spec (no tertiary rose, no gradient fills, no Material Design 3 color system).

**2. Fix Typography Scale — must show exactly 13 levels with correct sizes:**

Replace the current typography section with exactly these 13 lines, each showing "Aa 球迹" as sample text at the specified size:

| # | Token Name | Size | Weight | Font Style | Right Label |
|---|-----------|------|--------|------------|-------------|
| 1 | btDisplay | 48pt | Bold | Rounded | Display 48/Bold/Rounded |
| 2 | btLargeTitle | 34pt | Bold | Rounded | LargeTitle 34/Bold/Rounded |
| 3 | btTitle | 22pt | Bold | Rounded | Title 22/Bold/Rounded |
| 4 | btTitle2 | 20pt | Semibold | Default | Title2 20/Semi |
| 5 | btHeadline | 17pt | Semibold | Default | Headline 17/Semi |
| 6 | btBody | 17pt | Regular | Default | Body 17/Reg |
| 7 | btBodyMedium | 17pt | Medium | Default | BodyMed 17/Med |
| 8 | btCallout | 16pt | Regular | Default | Callout 16/Reg |
| 9 | btSubheadline | 15pt | Regular | Default | Subhead 15/Reg |
| 10 | btSubheadlineMed | 15pt | Medium | Default | SubheadMed 15/Med |
| 11 | btFootnote | 13pt | Regular | Default | Footnote 13/Reg |
| 12 | btCaption | 12pt | Regular | Default | Caption 12/Reg |
| 13 | btCaption2 | 11pt | Medium | Default | Caption2 11/Med |

Key: lines 1-3 use Rounded font, lines 4-13 use default (non-rounded) font. All 13 lines must be present.

**3. Fix Corner Radius — must show exactly 6 levels:**

Show all 6 rounded rectangles:
- xs: 6pt
- sm: 8pt (currently missing — add this)
- md: 12pt
- lg: 16pt
- xl: 20pt (currently missing — add this)
- full: pill (999pt)

**4. Remove the bottom tab bar** (SYSTEM/PALETTE/TYPE/LAYOUT) — this is a single-page reference sheet, not a multi-tab app.

Keep everything else that's working well: the brand banner card, the billiard table colors with circular swatches, the spacing bar chart, and the overall card-based layout.

---

## 使用说明

1. 在 Stitch 的**同一对话**中追加发送上方修正内容
2. 将新生成的导出文件夹保存到 `tasks/A-01/stitch_task_02/`
3. 然后说「审核 A-01」触发第二轮审核
