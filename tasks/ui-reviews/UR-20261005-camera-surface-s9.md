# DR-348 S9：首次3D初始化与旧球杆避让追溯

## 本轮范围
修复首次进入3D先到旧全局机位、再向开球最远第三人称转镜的问题。球杆遮挡按用户要求追溯既有定义与实现；本轮不重新设计曲面高度或恢复旧构图算法。

## 根因与修改
`ShotPlayCamera.setMode` 的旧focus在普通2D所有权下不会推进TwoView；`AngleTrainingScene.setCameraMode`无保存机位时先调用固定yaw=π的旧全桌轨道并立即推进到终点；随后FreePlayView才请求沿开球方向的travel=1。默认摆位下两个方向近乎相反。

场景切换新增可选首次机位初始化回调，在3D获得展示所有权之后、旧全桌兜底之前执行。生产曲面由VM依据当前母球/瞄准方向以duration=0初始化：开球travel=1，普通瞄准travel=0.5。成功后页面不再发第二次请求。初始化不成功仍走原兜底；有保存机位的2D往返先恢复原姿态，开球回3D再沿既有速度策略取景。重摆、换球与手动观察不改速度/曲面/输入。

## 球杆避让找回结果（未接回当前曲面）
- `CameraRig.dailyPlayerPose`：第一人称从实际击球点沿抬起后的杆轴后退0.90m，眼位在该杆轴点上方0.13m，水平后距为0.90cos(elevation)，不是固定水平0.90m。运杆不让头部跟着杆往复。
- 第三人称基线水平后退1.65m，眼位为max(台呢+0.90m，实际击球点Y+后距×tan(抬杆角)+0.35m)。`dailyObservationPose`保留同一杆轴净空，并对近库母球下轮廓做检查，必要时缩短后距。
- `TwoViewCamera.firstPersonEntry`还通过场景提供的真实球桌视线查询保护打点/母球下轮廓，必要时提高眼位。这不是完整球杆网格/全盘遮挡保证。
- 当前曲面`CameraSurface`仅保存母球平面位置、台呢高、画幅、方位、travel，不接收实际击球点与抬杆角；`CameraRig.enterPlayerView`在surface分支直接构造曲面并返回，且显式排除了mergedNearPose的旧第一人称安全机位。
- 因此当前低/中环不会随抬杆避让。数值例：中心母球、中杆打点、默认水平后距1.65m/台上高0.65m，杆轴在约20.637°抬角时达到眼高；30°时该轴点比眼位高0.3312m。例子用于解释缺失约束，不作为用户截图实际抬角的测量。
- 历史规格在docs/05 §每日相机与tasks/DAILY-CAMERA-FORMATIONS-20261001.md；后者已注明旧全盘遮挡验收不成立，不能直接把整套旧算法移回并声称全域安全。后续需在连续曲面中接入真实杆姿/有限杆身约束，并明确与等高圈的优先关系。

## 验证与交付
证据：build/camera-surface-s9-20261005/。
- 修前真实VM/SceneKit首次模式切换回归已失败：机位距离目标6.207933m，四元数点积绝对值约0.00000926（约180°方向差）；普通/旋转2D入口都复现。before.xcresult保留首帧原图。
- after.log/after.xcresult：27项CameraSurface核心测试＋2项原生UI，全部通过（TEST SUCCEEDED）。新测试覆盖普通/旋转2D首帧精确目的地、后续不漂移、重复请求无动画、保存视角恢复；原生UI覆盖开球/重摆/2D往返和重复选球返回。
- 原图对比已审：修前首帧母球在远端，修后首帧母球在近端、球堆在远端；原生每日页开球远景与选球后默认构图正常。图片位于before-attachments/与after-attachments/；不是对用户两张抬杆遮挡截图的修复验收。
- verify-gate及本轮源码diff空白检查通过。设备Debug-O构建BUILD SUCCEEDED、严格codesign验证通过。

## 本轮交付
2026-10-05 14:32已安装普通球迹com.xinkuan.qiuji到连接的iPhone16Pro，并启动每日清台入口，未重置用户数据。install.json与launch.json记录成功。可执行SHA256：43eea942a11fc3913ffc8b06f6a8f0f7a4f9020dce1967e84718d0a504838650。verify-doc-size通过。真机手感及首次切换视觉待用户实看；球杆避让尚未接入曲面。未提交/推送/发布。
