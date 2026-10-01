# 每日清台：目标进袋后恢复第三人称

日期：2026-10-01。状态：本地实现、定向测试与视觉验证完成；真机待验。

## 原因与改动

当前 `PositionPlayViewModel.launchBalls` 在触球回调启动全部轨迹之前调用 `transitionPlayerCameraForShot`，第一人称立刻进入第三人称。2026-09-29 的整体相机回退文档也明确撤回了此前进袋切换要求；本次按用户要求单独恢复这一时机，不恢复整套已撤回相机策略。

- 仅每日清台的第一人称实际击球延后自动站起。相机动作与母球轨迹在同一 SceneKit action group，按本杆目标球的 pocket 事件时间启动；不根据最终 `objectPocketed` 预告进球，也不用固定延时。
- 自由瞄准没有指定目标球，按第一颗非母球进袋事件触发。仅母球落袋、目标未进袋时，整杆停稳后回切。
- 延后触发使用击球前母球位置和本杆瞄准方向，避免母球走位后不再匹配第一人称相机引用。
- 回调检查击球代际与播放状态；取消/重开移除球动作，旧杆不能改变新局相机。全局/第三人称出杆、手势接管、历史回放保留既有行为。重打恢复原相机快照。

代码：`CueStroke.swift`、`PositionPlayViewModel.swift`；新增真实 SceneKit 生命周期测试 `DailyPocketCameraTimingTests`。

## 验证

独立 iPhone 17 Pro / iOS 26.3 模拟器：`53DE88C3-C74A-4706-95B6-38FAF72CF532`，独立 DerivedData：`build/DailyPocketCameraDerived`。

- 改前：既有每日第一人称击球原生 UI 测试通过，画面保存在 `build/daily-pocket-camera-20261001/before/`。
- 改后：4项真实播放测试 + 2项原生UI回归通过，`TEST SUCCEEDED`。最终强化时序复验再次执行4项播放测试，0失败（39.630秒）：触球后保持第一人称、持续采样目标仍可见期间不得站起、实际目标捕获后站起且剩余回放继续；同时覆盖未进袋杆末站起、取消后新局保留视角、全局/第三人称保持及重打快照恢复。原生UI两项0失败（73.490秒），覆盖相机三状态、2D往返、缩放、打点盘和手势接管。
- 首轮及两次重试完整测试目标构建失败：`X1_CameraAndAngleArcTests.swift` 的独立相机覆盖诊断代码触发 Swift frontend 字典表达式 coercion 崩溃（SIGSEGV / EXC_BAD_ACCESS），没有业务断言失败；原日志在 `after/`、`after-r2/`、`after-r3/`。对应 crash report 为 `~/Library/Logs/DiagnosticReports/swift-frontend-2026-10-01-123929.ips` 等。应用代码已编译/链接完成。
- 定向测试仅在命令行设置 `EXCLUDED_SOURCE_FILE_NAMES=X1_CameraAndAngleArcTests.swift` 隔离该编译器崩溃；未修改该文件、项目配置或跳过本次断言。`RailPlayerCameraTests` 因定义在该文件内尚未执行，不能宣称完整相机回归通过。
- 证据与定向原始日志：`build/daily-pocket-camera-20261001/focused/`。
- 最终播放复验：`build/daily-pocket-camera-20261001/timing/test.log`；该目录的 `before-target-capture.png`、`after-target-capture.png` 是真实SCNView播放截图，已打开目视。目标进袋前仍是低位第一人称，进袋后第三人称且目标已离台；它们是场景夹具画面，不冒充正式页面HUD截图。正式页面原图另在 focused 目录，审查见 [UI报告](ui-reviews/UR-20261001-daily-pocket-camera.md)。
- `verify-doc-size` 与 `git diff --check` 通过。未执行全量内容门禁或全量单元／UI回归。

## 交付边界

未安装真机、未提交或发布。完整测试目标编译崩溃单独保留；定向播放测试和实际页面截图分别判定。
