# SettingsView 路由增量审计（2026-09-13）

本轮 W07 门禁报告 SettingsView 新增路由源，静态核对当前共享工作区后登记；未修改 SettingsView、两个子页面或其偏好模型。

- SettingsView 的 appearanceSection 后无条件显示 tableStyleSection 与 ballStickerLink；二者是生产 NavigationLink，不在 DEBUG 条件内。
- tableStyleSection → TableStyleSelectionView，声明位于 QiuJi/Features/Profile/Views/TableStyleSelectionView.swift。选择按钮写 UserPreferences.shared.tableStyle；叶页未发现新的 NavigationLink/sheet 路由。
- ballStickerLink → BallStickerSettingsView，声明位于 QiuJi/Features/Profile/Views/BallStickerSettingsView.swift。选择按钮写 UserPreferences.shared.ballStickerStyle；叶页未发现新的 NavigationLink/sheet 路由。
- roomStyleSection 仍由 DEBUG 条件控制，本次两个生产入口与该条件分开。
- 本次只有源码可达性/目标存在/构建解析证据。没有执行两个页面的截图、导航往返、选项持久化或跨设备验收；route-coverage.csv 明确记为 pending，不借旧 SettingsView 截图声称新增子页面已验。
- 路由签名仅更新本次核对的 SettingsView；其他文件签名不改。门禁通过仅说明当前已登记的路由表层匹配。
