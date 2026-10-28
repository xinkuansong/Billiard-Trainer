# 第一人称方向尺拖动中断

用户报告：准度 3D 第三人称方向尺正常，第一人称滑动时特写短暂出现，随后调向停止。

## 范围与根因

只修输入与相机跟随。继续遵守 TP09：球桌不做大字号适配；保留现有 HUD、字号、背景和同一 3D 场景地毯。

`AccuracyPracticeViewModel.nudgeAim` 在调向后调用 `requestPlayerView(animated: false)`。第一人称的 `TwoViewCamera.enterFirstPerson` 却用 `max(0.1, duration)` 建立动画连接，导致 `cameraTransitionBusy` 变为 true、`canAim` 变为 false，`BTAimWheel` 在一次拖动内收到禁用并结束手势。第三人称曲面入口已正确支持零时长。

已修复：第一人称零时长请求立即应用最新机位并取消旧连接；正时长的显式切换仍保留动画与输入保护。生产改动仅在 `TwoViewCamera.enterFirstPerson`，不绕开业务禁用条件，不修改手势增益或相机几何。

## 共用消费者排查

| 页面 | 实际输入路径 | 结论 |
|---|---|---|
| 准度 | 每个方向增量后请求同人称零时长跟随，方向尺受 cameraTransitionBusy 禁用 | 直接触发本缺陷 |
| 瞄准点 | 调向重画球杆，内部更新相机；不在每个增量请求零时长入场，方向尺不受 cameraTransitionBusy 禁用 | 无相同禁用链，两系统连续拖动回归通过 |
| 多球／每日清台／自由练习 | FreePlayView 共用 nudgeFreeAim；方向尺 dailyControlsDisabled 不包含 cameraTransitionBusy | 无相同禁用链；多球作为实际共用消费者，两系统原生拖动通过；每日／自由未另跑独立页面UI |
| 角度 | 答题杆向来自题目，没有手动方向尺 | 本拖动故障不适用 |
| 分离角／两球／三球 | 固定杆向，BTTeachingAimRulerSpace 为占位；出杆阶段有零时长相机请求 | 无手动调向故障入口；共享相机修复同时覆盖零时长请求 |

## 局部 TP 判定

- TP10 继承：连续上拖、反向拖动消费实际杆向，松手可继续操作。
- TP13 继承：调向不自动出杆、不换题；正常过渡仍受原输入保护。
- TP16、TP17 继承：同场景第一／第三人称与 2D 业务状态不变，立即跟随与显式动画区分。
- TP35 按局部修改验证：相机状态单测、准度真实宿主、可调向页面原生手势；不机械重跑全部布局设备。
- 其余 TP 沿用七项合并与视觉回退记录，本次未改页面合同。

## 验证状态

Xcode 27.1（27A9275），原定字号。证据根：[run-paths.json](../../output/first-person-aim-20261028/run-paths.json) 指向受管目录 `64fd82b9668f48e585082819a25d4832/evidence/`。源哈希及唯一生产补丁见同目录外层 `source-manifest.json`、`camera-fix.diff`。

| 批次 | 实际结果 | 说明 |
|---|---|---|
| SE3／iOS17，red | 4项，1过3败 | 两个零时长相机测试复现；正时长对照通过。首轮宿主漏viewport，失败单独留档，不能算产品证据 |
| 同设备，red-ui | 2项，2败 | 补齐viewport后真实准度宿主确认输入被锁；原生UI第三人称通过，第一人称整段拖动只改变约0.0089° |
| 同设备，green | 单元49过；UI准度、多球过，瞄准点失败 | 47项TwoViewCamera＋准度连续输入/特写2项均过；瞄准点UI误读相机旧参考，后续修测试读取实际杆向 |
| 同设备，green-ui-r2 | 书签单元1过；准度、瞄准点UI过，多球测试探针失败 | 多球当前杆向在dailyLayout.controlsProbe，非multiBall.landscape；只修测试标识和开关 |
| 同设备，green-ui-r3 | 多球UI 1过 | 修正后读取真实当前杆向，第三／第一人称持续拖动和反向均通过 |
| Pad13／iOS26.3.1，pad-final | 8项全过 | 5项相机／宿主／书签单元＋准度、瞄准点、多球3项原生UI |
| verify-gate | PASS | 内容、同步、文案与v47门禁；diff空白检查通过 |

最终覆盖：SE分批50项不同单元测试通过；3页原生手势在SE17横屏、Pad26.3.1竖屏均通过。UI断言实际杆向、长拖不是只消费首个采样、反向继续响应；相机单测验证立即替换正在进行的跟随、无旧动画回拉，以及正时长动画仍正常。原失败包和失败视频保留，不覆盖为成功。

已目视两设备共12张最终截图，确认页面身份、第一／第三人称和方向尺所在位置；图片是手势结束后的取景证据，持续输入由数值断言验证，不把静态截图当作特写全程录像。图册：[手机](../../output/first-person-aim-20261028/phone-review.png)、[iPad](../../output/first-person-aim-20261028/pad-review.png)。不同台呢来自设备既存偏好，本轮未改材质。

修复前Xcode在失败后启动冗长的simctl diagnose；测试已执行完毕后，仅终止本轮诊断收集子进程以完成结果包，原始断言和UI录像保留。后续批次关闭额外sysdiagnose收集，保留正常日志、附件和xcresult。

资源：测试后释放本轮租约，核心设备保留；临时构建按local-test-lifecycle完成后回收，结果留在evidence。正式回收状态见同证据根的 `cleanup.json`。

未做真机、VoiceOver 或发布验收。
