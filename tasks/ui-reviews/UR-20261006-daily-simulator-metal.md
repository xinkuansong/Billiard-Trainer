# 每日清台：iPhone 17 Pro 模拟器点击无响应

日期：2026-10-06。用户反馈手机正常、默认 iPhone 17 Pro 模拟器点击每日清台无响应。

## 已确认根因

目标设备 AE86244C-EE61-4585-882F-E39B892214DB，iOS 26.3 (23D8133)。原进程 4560 由 Xcode debugserver 启动，停在 SIGABRT，主线程采样完整落在 FreePlayView.onAppear → setupScene → enhanceBallMaterials → RoomReflectionProbe.prefiltered → PrefilteredReflection.programs → dispatchThreads → MTLValidateFeatureSupport → abort。点击已经触发页面创建，并非按钮未命中。

Xcode 控制台原文：`Dispatch Threads with Non-Uniform Threadgroup Size is not supported on this device`。因此调试器暂停并留下首页旧画面。手机正常是用户报告，本轮未连接手机验证。

## 修复

仅修改 PrefilteredReflection.swift 的 LUT 和反射 mip 两处计算派发：使用固定 8×8 线程组的 dispatchThreadgroups，网格向上取整。原 kernel 已检查输出边界，覆盖最小 mip；采样算法、纹理尺寸、颜色和材质参数保持不变。没有关闭 Metal 校验，也没有恢复预加载。

依据：[Apple 线程组与网格尺寸说明](https://developer.apple.com/documentation/metal/calculating-threadgroup-and-grid-sizes)。非均匀派发需要设备支持，固定线程组可结合 shader 边界判断覆盖纹理。

## 验证与证据

- `TEST_RUNNER_MTL_DEBUG_LAYER=1`，构建并执行 RoomReflectionProbeTests 的 testPrefilterPreservesLinearHDREnergyAndReusesResources、testPrefilterRoomStyleCacheAndRelease：2 测 0 失败。涵盖各 mip HDR 能量、LUT 有限值、三种球房及资源缓存/释放；日志确认 Metal API Validation Enabled。
- 将修复包覆盖安装到用户原 iPhone 17 Pro 模拟器，未卸载或清空数据。通过 `SIMCTL_CHILD_MTL_DEBUG_LAYER=1` 正常启动；从原首页点击每日清台，确认横屏球桌显示、2D→3D、返回首页再次进入成功。保留球桌供用户试用。
- 证据：`output/daily-simulator-unresponsive-20261006/app-sample.txt`、`fixed-launch.log`、`fixed-3d.png`、`fixed-reentry.png`；测试日志 `build/daily-simulator-metal-20261006/tests.log`。
- xcresult：`build/daily-spin-setting-20261005/DerivedData/Logs/Test/Test-QiuJi-2026.10.06_01-28-26-+0800.xcresult`。
- 仍观察到横屏请求初次被 portrait mask 拒绝的日志，但两次最终均显示横屏球桌。这是独立的方向时序问题，本轮不将其标记为根治；前一轮已移除以该回调阻断页面的门控。
- 前一轮普通 UI 自动化未显式启用 Metal API Validation，不能代表 Xcode 调试校验路径；后续此渲染路径应显式开启校验。
- 未安装手机、未提交或发布。
