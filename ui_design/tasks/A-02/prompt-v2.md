# Stitch 修正提示词 — A-02 v2

> 任务 ID: A-02 | 版本: v2 (审核修正) | 日期: 2026-04-03
> 在 Stitch 的**同一会话**中发送以下修正消息

---

## Stitch 修正消息（粘贴以下内容）

Please make these 3 small fixes to the current design:

1. **segmentedPill disabled row**: The disabled row currently only shows 2 pills ("弹出", "不弹出"). Add the missing third pill "延迟" so it matches the default row (all 3 pills at 50% opacity).

2. **Remove the bottom tab bar**: Delete the entire bottom navigation bar (Drills / Progress / Training / Settings). This is a component reference sheet, not an app screen — it doesn't need navigation.

3. **Remove the top navigation bar**: Remove the back arrow and "Button System" header bar. Instead, keep only the section titles inside the content area. The first section title "BTButton — 7 Styles" already serves as the page header.

Everything else is correct — keep all button styles, colors, hierarchy demo, and touch target section exactly as they are.
