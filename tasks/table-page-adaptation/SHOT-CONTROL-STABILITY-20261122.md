# 台面瞄准拖动期间动作按键闪烁修复 · 2026-11-22

状态：代码修复完成，模拟器定向验证通过。真机和用户手感未验。

## 根因

力度尺和方向尺发布了完整的拖动生命周期，台面瞄准拖动只更新瞄准特写 Gate，没有进入动作控件的忙碌状态。一次物理预览在两次手势采样之间完成时，`isComputing` 会短暂变为 `false`，相机键、击球按钮和“计算中”文案因此闪烁。

## 修复

- `PositionPlayViewModel` 增加台面瞄准拖动状态，并纳入 `shotControlsBusy` 与计算文案门控。
- `BTTeachingTablePage` 在台面瞄准拖动期间锁定相机键，保持计算态动作文案稳定。
- 走位规划、打一走二想三、翻袋和解球页面接入相同的台面拖动生命周期。
- 松手后仍触发最后一次预览求解，后台或离页时清除拖动状态。

## 验证

- `ContinuousTrajectoryPreviewTests`：10/10 通过，含新增 `testTableAimControlsStayBusyAcrossCompletedPreviews`。
- `CameraV67PilotUITests/testFormalFramePacingTouchPaths`：1/1 通过，覆盖 iPhone 模拟器 2D/3D、进袋/自由瞄准和连续反向滑动。
- `swiftc -frontend -parse`、`git diff --check` 通过。

证据目录：`output/local-test-runs/c7ca3f703c724bf28f5a528adf916fe7/evidence/`。

