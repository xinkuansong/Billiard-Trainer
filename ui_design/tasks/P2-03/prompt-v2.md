# Stitch 修正指令 — P2-03 v2

## 帧 1（已登录态）修正

在 Stitch 的已登录态会话中发送以下修正：

---

Please make this one change to the current design:

**Change the "退出登录" (Log Out) text color from the current green/dark color to destructive red #C62828.** This is a logout/destructive action and must use red color to visually warn the user, consistent with the app's button hierarchy system (destructive actions always use #C62828). The text should remain center-aligned with no background — just change the color to #C62828.

---

## 帧 2（访客态）修正

在 Stitch 的访客态会话中发送以下修正：

---

Please make these changes to the current design:

**Remove the two extra icons in the navigation/title area:**
1. Remove the 📍 location pin icon that appears to the left of the "我的" title
2. Remove the ⚙ gear icon that appears at the top-right corner

The title area should only show the large title "我的" (34pt Bold Rounded, left-aligned) with no additional icons — matching the logged-in state frame exactly. This is a tab root page; settings are accessed through the menu list below, not through a navigation bar button.
