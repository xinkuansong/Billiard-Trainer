# Stitch 修正指令 — A-06 v2

> 任务 ID: A-06 | 版本: v2 | 日期: 2026-04-03
> 在 Stitch **同一对话**中发送以下修正消息

---

## Stitch 修正消息（粘贴以下内容）

Please make the following 6 corrections to the current design:

**1. Remove the top navigation bar entirely.** Delete the sticky header that says "Component Reference" with the glassmorphism backdrop-blur effect. The page should start directly with the first green section title "BTSegmentedTab — 页内水平标签". No app bar, no header — this is a pure documentation page.

**2. Remove the "Drill Setup Reference" section completely.** Delete the entire bottom section that contains the billiard table photo and "START DRILL" button. The page should only have 3 sections: BTSegmentedTab, BTTogglePillGroup, and BTOverflowMenu. Nothing else.

**3. Remove the bottom footer.** Delete the "© 2024 QiuJi" copyright footer. The page should end after the BTOverflowMenu section's usage annotation text.

**4. Fix the overflow menu trigger icon direction.** Change the trigger icon from horizontal three dots (`more_horiz` / "⋯") to **vertical three dots** (`more_vert` / "⋮"). The design spec requires a vertical "⋮" icon button.

**5. Reduce the menu item icon circle size.** The colored circle backgrounds behind each menu icon should be **24pt diameter** (not 32px). Make them smaller to match the spec: 24pt circle with the icon centered inside.

**6. Remove the green-tinted card shadows.** All white section cards currently use `shadow-[0_4px_20px_rgba(26,107,60,0.08)]` (a green-tinted shadow). Replace with **no visible shadow** — the cards should be plain white `#FFFFFF` on the `#F2F2F7` background, relying only on the background color contrast for definition. This matches our established style from previous component sheets.

Everything else (colors, layout, component examples, specs text, annotations) is correct — please keep those unchanged.
