# 假想母球虚线圈白色 · 2026-10-12

按用户要求，将共用假想母球虚线圈从绿色改为白色。

- SceneKit：AngleTrainingScene.setupVisualizationNodes 使用独立 TrajectoryStyle.ghostColor（白色，alpha 0.95）。
- SwiftUI：BTGhostCircle 经 FigureLine.ghost 使用同一颜色，额外 opacity 0.9 保留。教学图与瞄准特写共享。
- 接触点、瞄准点、线宽、虚线节奏及几何逻辑保持。

功能验证：`make -f scripts/Makefile build` 返回成功，日志含 `BUILD SUCCEEDED`。verify-gate、verify-doc-size、git diff --check通过。纯颜色改动未新增测试。

视觉验证：未完成。独立启动原本 Shutdown 的 iPhone 17 Pro（AE86244C-EE61-4585-882F-E39B892214DB），安装旧构建并打开自由击球；before.png 实际被 Apple 账户验证系统提示遮挡，不是有效页面基线。两次尝试 UI 操作均返回用户改变应用状态，停止争用控制；未输入账户信息。未获得有效改前/改后页面图，不宣称实际效果通过。未改动十台既有评审模拟器；本轮启动的iPhone 17 Pro已成功Shutdown。

构建日志及被遮挡截图：`output/ghost-ring-white-20261012/`。下一步补原生页面前后对照；未安装真机、提交或发布。
