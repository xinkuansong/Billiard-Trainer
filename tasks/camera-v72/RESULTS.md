# v72 第一人称推进与后退实施验收

日期：2026-11-22  
范围：共用 `AngleSceneView`、`CameraRig`、`P01CameraMotion`、`TwoViewCamera` 相机链路  
产品语义：沿当前实际杆轴 dolly，保持当前 `fieldOfView`，同一杆内保留推进位置。H-05 不属于本功能门禁。

## 实现结果

- P01 相机新增 `firstPersonDolly`，以真实杆轴 setback 计算眼点，使用桌房布局、球杆净空和已有清障回调夹紧边界。
- TwoView 相机新增同语义的推进状态，加入快照、模式记忆、上下文切换和第一人称手动接管。
- 第一人称捏合由 `AngleSceneView` 进入 `CameraRig` 共用派发。第三人称临时观察回调不再接管第一人称推进。
- 第一人称推进期间保持当前仰角。再次点击第一人称，或从第三人称重新点击第一人称，都会清除本次 dolly 并回到默认第一人称眼点。
- 推进字段按可选值编码，旧快照缺少该字段时按 0 偏移解码，保留历史第一人称默认眼点。
- 新杆、上下文变更和显式重新进入第一人称沿现有相机生命周期清除偏移。第一人称横滑继续负责头部观察，捏合不改球位、杆向、打点、力度、预测、计分或题目状态。

## 实际宿主矩阵

| 宿主 | 实际入口 | 本轮处理 | 权限边界 |
|---|---|---|---|
| 共用教学球桌 | `QiuJi/Core/Components/BTTeachingTablePage.swift:874` | 共享链路接入 | `firstPersonAvailable`、观察只读和教学阶段门禁保留 |
| 自由训练 | `QiuJi/Features/PositionPlay/Views/FreePlayView.swift:923` | 共享链路接入 | 页面原有 2D/3D 和击球锁定保留 |
| 角度训练 | `QiuJi/Features/AngleTraining/Views/SceneAimingView.swift:391` | 共享链路接入 | `canAim`、结果态和只读阶段保留 |
| 瞄准点训练 | `QiuJi/Features/AngleTraining/Views/AimPointSceneTrainingView.swift:1002` | 共享链路接入 | `permitsFirstPersonAddress` 保留 |
| 球体提取 | `QiuJi/Features/BallExtraction/Views/BallExtractionView.swift:402` | 共享入口审计 | 编辑态仍由 `interactionMode` 控制 |
| Drill 场景 | `QiuJi/Core/Scene/DrillSceneView.swift:925` | 共享入口审计 | 只有 `.cameraControl` 阶段可接收手势 |
| 批量编排与批量提取 | `QiuJi/Features/BatchDrillStudio/BatchAuthoringView.swift:928`、`BatchBallExtractionView.swift:617` | 共享入口审计 | `.tapsOnly` 等原有编辑限制保留 |
| `BTTeachingTablePage` 页面族 | 分离角、吃库、准度、翻袋、解球、防守、K 球、两球、三球、多球、蛇彩、打一走二想三、扎杆与跳球等调用方 | 由统一页组件继承 | 页面自身没有合法杆向或声明禁用时继续禁用 |

入口盘点命令：`rg -n 'BTTeachingTablePage\\(|AngleSceneView\\(' QiuJi --glob '*.swift'`。页面没有复制第一人称推进实现。

## 自动化结果

### 新增与关键生命周期用例

命令目标为 `QiuJiTests/P01CameraMotionTests`、`QiuJiTests/TwoViewCameraTests` 中 8 项定向用例。

- P01 第一人称推进、反向恢复、几何边界：3/3 通过。
- TwoView 第一人称推进、反向恢复、FOV、快照往返、头部观察、新杆上下文：5/5 通过。
- 日志：`/tmp/camera-v72-targeted-unit.log`。

### 当前相机单元全集

当前选择的 P01 与 TwoView 共执行 76 项。P01 27/27 通过。TwoView 49 项中有 13 项失败，集中在原有视口重建、布局取消和极小四元数精度断言，失败方法为：

- `testInitialAutomaticShotEntryRebuildsLatestViewportAndHUDBeforeFirstUpdateAndCompletes`
- `testModeSwitchRestoresIndependentVisiblePosesAndExplicitEntryResetsHead`
- `testPendingShotEntryCancellationByContextOrUnusableLayoutReleasesBusyWithoutClaimingArrival`
- `testRigLayoutChangeWaitsForEffectiveGestureThenReconnectsEachInputFromActualPose`

这 13 项没有第一人称推进断言失败。当前日志保留于 `/tmp/camera-v72-full-unit-current.log`，作为待独立处理的已有回归边界，不能被本轮报告写成完整全集通过。

### v72.4 跟进运行结果

- 重新编译后的定向相机单元共 77 项，P01CameraMotion 与 TwoViewCamera 全部通过，结果文件：`output/camera-v72/pitch-reset9/unit.xcresult`。
- 新增的旧快照缺少 `firstPersonDolly` 解码测试通过。合成 `Codable` 对缺失可选字段返回 `nil`，继续使用默认第一人称眼点。
- 新增独立 UI 用例 `CameraV67PilotUITests/testFirstPersonZoomKeepsPitchAndReentersDefault` 在 iOS 17.0 iPhone SE（第三代）通过 1/1，结果文件：`output/camera-v72/pitch-reset17/ui.xcresult`。该用例确认第一人称捏合只移动眼点、四元数保持不变，重复点击第一人称和第三人称往返后均回到默认眼点。
- 综合四机位 UI 用例在最新代码下于 iOS 17.0 iPhone SE（第三代）通过 1/1，结果文件：`output/camera-v72/pitch-reset20/ui.xcresult`。历史 iPhone 17 Pro 与 iPad Air 13 的 1/1 证据仍保留在本报告上方。一次 iOS 26.3.1 标准机重跑另遇模拟器 Runner `SBMainWorkspace Busy` 启动失败，该次不作为功能失败计数。
- 代码通过 Swift 语法解析和 `git diff --check`。H-05 未参与本功能门禁。

## 原生交互验收

统一执行 `CameraV67PilotUITests/testFormalRailPositionsPinchAndTabletRotation`。该用例在四个实际机位进入第一人称，执行捏合并检查眼点移动和 FOV 保持，同时覆盖方向切换与原有球桌状态。

| 设备 | Runtime | 结果 | 证据 |
|---|---|---|---|
| `QiuJi-Remaining-SE-20261013` | iOS 17.0 | 1/1 通过，先前运行 | `/tmp/camera-v72-ui.log` |
| iPhone 17 Pro | iOS 26.3.1 | 1/1 通过，140.782 秒 | `/tmp/camera-v72-ui-iphone17.log`、`output/camera-v72/iphone17-result.json` |
| iPad Air 13-inch (M4) | iOS 26.3.1 | 1/1 通过，166.847 秒 | `/tmp/camera-v72-ui-ipad.log`、`output/camera-v72/ipad-result.json` |

iPad 测试结束后 Xcode 的自动 `simctl diagnose` 收集进程长期未退出。本轮停止该诊断子进程并保留已完成的 1/1 测试日志，设备租约已回收。日志中的 `invalidDigitCount(94232)` 是 Xcode 版本记录警告，不是应用测试失败。

## 构建与验收边界

- Debug 模拟器构建通过，日志：`/tmp/camera-v72-build.log`，结果为 `BUILD SUCCEEDED`。
- 后续为检查旧录像兼容性而做的临时自定义 `State` 解码补丁已撤回。正式实现保留可选 `firstPersonDolly` 字段，由合成解码在旧快照缺字段时返回 `nil`，再按 0 偏移计算。该次强制增量重编译暴露工作区已有的 `TableInteractionPerformanceProbe`／`interactionPerformanceProbe` 缺失符号，错误位于本轮相机改动之外。
- 本次跟进补充了第一人称仰角不变、重复进入第一人称复位、第三人称往返复位以及旧 `State` 缺字段默认值测试。后续重编译已完成并产出独立 UI 用例 1/1 通过结果。
- 第一人称相机代码、定向单元测试、iPhone 原生交互和 iPad 原生交互均已完成。
- 真机、完整 App 全量 UI 和上表 13 项既有 TwoView 单元失败不宣称已通过。
- 现有代码工作区含其他任务的未提交修改，本轮只对 v72 相关文件、测试和文档做定向回写，没有执行清理或重置。
