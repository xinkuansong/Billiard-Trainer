# S1 独立曲面相机试用版

日期：2026-10-04。状态：实现、模拟器定向验证与真机包构建完成；23:01安装并启动于iPhone16Pro，手感待用户试用。未提交或发布。

## 交付身份与入口

应用名 **球迹·曲面实验**，Bundle ID `com.xinkuan.qiuji.camerasurface`，独立容器，可与现有球迹并存。生成工程与 Info 位于 `build/camera-surface-experiment/`，原 App 未覆盖。实验标记写入专用 Debug 包，关闭后重新打开仍启用。此包用于每日清台相机试用，未验证独立包的登录、购买等服务。

签名包：`build/camera-surface-experiment/DerivedData/Build/Products/Debug-iphoneos/球迹.app`。最终 `device-final-build.log` 为 BUILD SUCCEEDED，codesign 严格验证通过，`identity.json` 记录独立标识、显示名及实验开关。初次交付时手机断开；用户23:01要求安装后连接恢复，安装成功并启动（PID19676），进程复查存在。`install.json`、`launch.json`、`device-apps-after.json`、`device-processes-after.json`留证；原包与实验包同时存在，原包未覆盖。

## 实现与操作

S1 几何由 `CameraSurface.swift` 实现，沿用已审离线曲面，接入 TwoViewCamera 单一姿态控制器。近区围绕母球，远区逐渐过渡至桌中心超椭圆外沿；外沿无独立全局相机所有权。本杆参考冻结，普通运动母球与杆姿更新不会拖动镜头；新杆取最新参考。

进入「每日清台 → 3D」后：

- 空白处左右滑动观察；方向尺调整真实瞄准。
- 上滑靠近、下滑后退，捏合也控制同一近远行程；松手保持。
- 眼睛按钮退到外沿全桌，人物按钮回到当前杆向的默认位置。
- 俯视按钮打开临时俯视；纯查看返回恢复原机位。

## 最终验证

专用 iPhone 17 Pro / iOS 26.3 模拟器 `Camera Surface S1`。最终源码的 `final-validation.log` 为 TEST SUCCEEDED：

| 范围 | 结果 | 验证内容 |
|---|---|---|
| CameraSurfaceTests | 5/5 | 独立 Python 参考姿态对拍、近区等距、外沿不依赖母球、后退高度/房间边界、端点反向、松手/快照/控制器所有权 |
| 原生触摸流程 | 1/1 | 横滑保留杆向、近端与外沿、外沿绕桌、松手姿态、临时俯视往返、外沿返回 |
| 真实击球流程 | 1/1 | 原生击球、物理停稳后生成下一杆、更新参考并回到默认沿杆姿态 |

xcresult：`build/camera-surface-experiment/Simulator/Logs/Test/Test-QiuJi-2026.10.04_20-56-13-+0800.xcresult`。

最终8张原生截图及对应姿态在 `build/camera-surface-experiment/screenshots-final/`。此前6视角已定向审查，最终击球前/下一杆两张也已审：母球和目标球可见，杆向与新目标一致。近端杆身仍覆盖母球下部，默认/近端允许部分桌面出画；外沿样例全桌可见。截图结论只限采样球形，不代表全场景遮挡保证。

## 失败与修复留证

独立工程最初的重复 Info、扩展相对路径与生成根错误均已修复，早期 build 日志保留。共享模拟器启动桥挂起，保留采样并中止本任务测试，使用新建专用模拟器完成最终验证。

首轮 UI 松手比较失败：旧诊断器取“离默认姿态最远的帧”，但曲面默认姿态随观察方位改变，样本不等于松手前帧。曲面分支改记最后真实持触帧，原姿态容差断言保持；r2 与最终复验通过。

## 尚待体验与边界

手机安装与启动已完成；真实触摸手感及连续击球体验待用户反馈。侧旋沿杆偏移、完整杆身与球群动态遮挡、所有球位/HUD组合、小屏/iPad/旧系统、持续帧率和温升未完整验收。现有 FL-094 不因本次实验关闭。几何采样与模拟器测试不作为这些项目的验收依据。

复建入口：`make -f scripts/Makefile camera-surface-device`；生成工程入口：`make -f scripts/Makefile camera-surface-project`。
