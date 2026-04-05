# Stitch Revision — P2-06 v2: SubscriptionView Fixes

Please make the following corrections to the current design. Do NOT regenerate from scratch — only modify the items listed below.

---

## Fix 1: Replace ALL 6 feature items with the correct content [CRITICAL]

The current feature names and descriptions are incorrect — they describe features that do not exist in this app. Replace ALL 6 items with the exact content below. Keep the same visual format (gold numbered circle + white title + gray description + chevron).

1. Title: "完整动作库" / Description: "解锁全部 72 个训练动作"
2. Title: "统计与趋势图表" / Description: "可视化你的训练进度"
3. Title: "自定义训练计划" / Description: "打造你的专属训练方案"
4. Title: "无限角度测试" / Description: "不限次数提升角度感知"
5. Title: "训练分享卡全样式" / Description: "所有配色主题与分享模版"
6. Title: "云端同步" / Description: "多设备数据无缝同步"

---

## Fix 2: Make the 3 pricing cards visible on screen [CRITICAL]

The 3 pricing cards (月订阅 ¥18, 年订阅 ¥88, 终身买断 ¥198) are currently scrolled off-screen and invisible. The user cannot see them at all. Fix this by:

- Move the pricing cards OUT of the scrollable area and into the fixed bottom section, directly ABOVE the subscribe button
- Reduce the vertical spacing in the feature list section (reduce gap between feature rows from 16pt to 10pt) so the feature list takes less vertical space
- The final bottom layout should be (from top to bottom within the fixed footer): **3 pricing cards row → subscribe button → fine print**
- All 3 cards must be fully visible without scrolling

The 3 cards should remain as they are in the code: Monthly (gray border), Annual (green border + "推荐" badge + checkmark, selected), Lifetime (gold border).

---

## Fix 3: Reduce feature list vertical spacing

To ensure all content fits in one screen without scrolling:
- Reduce gap between feature rows to approximately 10-12pt (currently too much)
- The feature section should be compact enough that a user can see ALL 6 features + the pricing cards + the subscribe button on one screen without scrolling
