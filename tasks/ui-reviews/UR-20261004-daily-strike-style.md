# 每日清台击球按钮样式（2026-10-04）

用户要求：平时与其他按钮同色，点击才变色。

## 实现

`FreePlayView.dailyRightControls` 使用私有 `DailyStrikeButtonStyle`：常态 `HUDStyle.controlBackground` / `btText`，按下 `HUDStyle.accent` / `onAccent`，松开恢复。沿用圆形尺寸和描边、禁用逻辑、辅助功能标识及原击球动作。2D/3D 共用。

## 验证边界

- `git diff --check -- QiuJi/Features/PositionPlay/Views/FreePlayView.swift` 通过。
- 通过 Makefile 发起 Debug 构建，实际失败：磁盘空间不足，`No space left on device`，make exit 65；日志 `build/daily-strike-style-20261004/build.log`。不能宣称编译通过。
- 改前默认模拟器出现账户提示，随后启动停滞；未获得目标页面基线。独立临时模拟器同样未能完成页面验证，已删除本次创建的临时设备。
- 尚未完成实际页面的常态/按下/松开截图与颜色核验，未安装手机。后续需空间恢复后构建并复验 2D/3D 按下与释放反馈。

本轮为局部样式调整，未新增镜像实现的单元测试。已有工作区其他修改保留。
