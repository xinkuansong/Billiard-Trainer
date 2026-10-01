# 每日清台进袋回切：页面审查

日期：2026-10-01。iPhone 17 Pro / iOS 26.3，横屏，每日 selection fixture。

## 功能证据

本次新增 `DailyPocketCameraTimingTests` 的真实 SCNView 播放覆盖回切时机；页面回归覆盖第一／第三人称按钮、击球后的观察态、2D往返、缩放、打点盘与手势接管。定向日志见 `build/daily-pocket-camera-20261001/focused/test.log`；完整测试目标的编译器崩溃限制见 [实施报告](../DAILY-POCKET-CAMERA-20261001.md)。

## 视觉审查

已打开改前 `before/camera-first-shot-standing.png` 和改后 `focused/camera-first-person.png`、`focused/camera-first-shot-standing.png` 原图（均位于 `build/daily-pocket-camera-20261001/`）。改前触球后即站起，目标球仍在台面；改后原生页面进球后进入第三人称，目标球已离台。静态页面画面不能独立证明每一帧切换时序，以播放断言为准。

改后第一人称画面保留母球、球杆和目标球，进球后回到站立观察，剩余球与母球走位可见；顶部球库与两侧控件保持原布局，未发现新增遮挡、截断或错位。此次未改 Design Token、按钮尺寸、明暗样式或相机取景算法。

强化时序测试中的两张真实SCNView场景截图 `timing/before-target-capture.png` / `timing/after-target-capture.png` 也已打开：前者目标仍可见、保持低位第一人称；后者目标离台，镜头已经站起。该夹具画面没有正式页面HUD，不作为页面布局验收证据。

发现新增视觉问题：0。真机动画手感、iPad、小屏及完整明暗／辅助字号矩阵未验，不能据此宣称全页面或所有设备验收。
