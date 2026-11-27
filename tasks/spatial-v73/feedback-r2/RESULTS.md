# v73.5 示范开播相机修复验收

2026-11-26（北京时间）。扎杆、跳球共同修复，工程定向验证通过；未提交、发布或进行真机验收。

## 行为与实现

示范先恢复本题初始球位和参考杆姿，再经 `TeachingTableHost.requestPlayerView(.thirdPerson, animated:false, resetThirdPerson:true)` 同步完成默认第三人称复位，确认无过渡或待布局后才锁定出杆。停止后仍由原 `ShotReplayCamera` 恢复玩家观察视角。个人回放保持原杆镜头语义。

生产修改限于 `SpatialQuizViewModel.play` 的准备顺序与示范分支；不修改共享相机公式、物理、渲染或题库。没有用固定延迟等待相机。[源码指纹](evidence/source-identity.json)记录当前共享脏工作区，非独立提交身份；修改前文件保留在 `evidence/before/`。

## 开播瞬间与恢复回归

`camera-unit-r4`：`SpatialQuizIntegrationTests/testDemonstrationSeatsReferenceThirdPersonBeforeStrokeAndRestoresObservation` **1/1通过**，内部遍历两模式、第一人称和已缩放侧看第三人称。无renderer推进时检查出杆调度瞬间的视角、默认距离/高度、零侧偏、无缩放俯仰偏移、参考母球/方向/仰角、无未完过渡；停止恢复完整pose，首答不变，求解中取消不发生迟到切镜。

第三人称缩放前置由共用书签与 `P01CameraMotion.evaluate` 构造有效非默认状态，侧看走实际水平手势入口；不是声称通过本轮测试验证了所有捏合边界。

## 原生操作与视觉

`camera-r2` 中 `SpatialQuizUITests/testBothPagesSuccessfulStrokeReplayDemoAndRetry` **1/1通过（119.801秒）**，在large-pad角色的13英寸iPad模拟器上遍历两模式：成功结果→第一人称→示范第三人称→停止恢复第一人称→个人回放→重打。此批新单元测试当时失败，不能把该批整体写成全通过；单元最终结果见上节。

已逐张查看[原生附件清单](evidence/camera-r2/manifest.json)中两模式各一张示范前与示范中原图：示范画面进入第三人称、停止入口存在，未见黑屏。截图是播放中证据，开播瞬间保证来自独立VM断言，不用播放中截图替代时序检查。

|模式|示范前|示范中|
|---|---|---|
|跳球|[第一人称](evidence/camera-r2/3C02F1A9-EA71-44AF-A035-398CE94A83D9.png)|[第三人称](evidence/camera-r2/2BD965D5-F4A0-47C6-8ECE-A414D14C3ADE.png)|
|扎杆|[第一人称](evidence/camera-r2/AC1609FF-6048-4917-9989-ACAA8C577F9D.png)|[第三人称](evidence/camera-r2/50D29620-9DBD-4BDF-A660-04880B6BDC9F.png)|

## 失败记录与复验

- `camera-r1`：compact-phone-floor租约请求遇设备忙，未执行测试，没有绕过租约。
- `camera-r2`：独立VM场景仍为默认2D，缺真实页面进入3D步骤，导致返回视角未捕获；仅修测试前置条件。
- `camera-unit-r3`：示范及恢复断言通过，但测试用于准备缩放的捏合受到杆头可见性边界限制，非默认距离前置断言失败；改为明确的共用书签准备，保留全部示范/恢复断言与非默认状态断言。
- `camera-unit-r4`：最终通过。r2到r4生产代码未变化，调整限测试准备。

原始日志与xcresult：`output/local-test-runs/0f403f03417249578985aa27db0af824/evidence/`，保留失败与通过记录，不覆盖历史。

## 静态检查与范围

`verify-gate`、`verify-doc-size`与`git diff --check`通过，见[门禁日志](evidence/verify-gate.log)、[文档体积](evidence/doc-size.log)及[空白检查](evidence/diff-check.log)。本轮局部复核TP17/25及播放取消依赖；不重复声称全部TP01–TP36、全尺寸、真机或用户接受已验证。v73.4此前六项验证保留在[前轮结果](../feedback-r1/RESULTS.md)。
