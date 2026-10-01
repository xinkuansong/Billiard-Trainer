# 开球与力度调节球杆连续显示（2026-09-28）

## 范围与改动

- `BreakFlowRunner.breakNow` 删除计算前主动藏杆，保留当前瞄准姿态；计算成功直接接 `runCueStroke`，失败继续由原 `acceptCompletedSimulation` 恢复瞄准，取消仍隐藏。
- `PositionPlayViewModel.showGeometryPreviewOnly` 在进袋模式的力度拖动期间，清理过期预测线后，复用与当前目标球、袋口及完整盘面一致的解，通过原 `updateCueStickAiming` 更新球杆。旧解仅作为等待新预测时的瞄准姿态；不作为新力度的预测结果，不改变模式。
- 原打点校正、击球可达性和避障路径继续生效；母球缺失、盘面不匹配及无可用解时仍隐藏。自由模式逻辑不变。
- 未调整物理引擎、力度映射、触感或相机。本任务只增加以上两处生产逻辑及测试；工作区同文件内其他会话改动保留。

## 自动化证据

独立目录：`build/cue-visibility-20260928/`。

1. 首轮构建与测试：`tests.log`，实际执行 7 项，0 失败，`TEST SUCCEEDED`。首轮额外指定的失败恢复用例类名有误、执行 0 项，未计入通过数，后续已按正确类名补验。
2. 补验构建完成但模拟器启动被 Busy 拒绝：`final-tests.log`，未执行测试，保留失败日志。
3. 新建专用 iPhone 17 Pro / iOS 26.3 模拟器 `CDA117DB-2BE5-4861-AA0C-D8FAB4620093`，使用同一构建产物重跑：`retry-tests.log`，实际执行 14 项，0 失败，`TEST EXECUTE SUCCEEDED`。
   - DailyPowerReleaseTests：7 项，覆盖连续输入、按住停顿重算、松手不击球、取消、最新参数回填、自由模式及重新选回目标球、旧盘面拒绝、母球缺失和实际渲染。
   - DailyAimSelectionTests：4 项，覆盖模式及合法目标/袋口选择。
   - BreakFlowRunnerV6Tests：3 项，覆盖计算到运杆连续显示、计算失败恢复、真实开球到停稳交付及重开取消。
4. 新增 4 项用例，另加强已有失败恢复用例的球杆显示断言。
5. 全仓 verify-gate 通过。文档门禁与 diff 检查见本轮执行记录。

## 图像检查

`build/cue-visibility-20260928/attachments/manifest.json` 保存 6 张 1000×700 原生 SceneKit 渲染图与测试映射，已逐张打开检查：

- break-before / break-computing / break-stroke-start：球杆可见，计算期间清理瞄准线没有再隐藏球杆。
- power-before / power-during / power-after：球杆持续可见，拖动中旧预测线消失，完成后新预测恢复。

图像为生产场景的离屏渲染，非完整 SwiftUI 页面手势录像；运杆接续另有状态与动作断言，不能据静帧宣称屏幕逐帧无掉帧。

## 待用户验证

- 真机点击开球，观察计算到运杆是否仍有闪断。
- 开球后直接调力度；拖住停顿后再滑动；松手后再调。
- 先调方向再调力度；选回目标球后再次调力度。
- 未进行真机安装、iPad 验收、持续性能测试或发布。

## 追加：运动中重开后球杆跳向旧母球（用户反馈，2026-09-28）

状态：调查中，尚未复现，未修改生产代码。此前连续显示修复不代表本问题已解决。

- 核对 `cancelDailyAttempt`：已有 strokeGeneration 作废、预测取消、球体与球杆动作清除；新 runner 摆架会重设 aimDir。不能直接断言漏了取消。
- 发现待验证风险：`breakNow` 抓取计算输入，但 `startPlayback` 仍重新读取实时母球节点和参数；目前未获得该节点被旧状态覆盖的证据。
- 新增 3 项回归探针分别通过（每项实际执行 1 测、0 失败）：普通击球运动中重开、开球散球中重开、实时 SCNView 持续渲染下两种运动中重摆后立即点击击球。检查新球架到开球计算结束/运杆开始的母球位置、球杆枢轴及朝向一致。
- 日志：`build/cue-visibility-20260928/restart-probe.log`、`restart-break-probe.log`、`restart-live-probe.log`。前两项 SCNRenderer 逐帧驱动，后一项真实 SCNView；都不是用户手机上的现场复现。
- 待澄清：此前是开球散球还是普通走位；表现是球杆跳回旧位置还是仅转向旧方向，是否伴随镜头移动。未宣称修复。

### 用户确认后的完整页面复测

用户确认：上一轮开球仍在散球，重开后新杆跳向旧母球方向，并提到开球线限制。

增加 `V52DailyClearanceUITests.testRerackDuringLiveBreakKeepsCueAtNewRack`，真实每日清台页面进入3D，开球后经左侧开球按钮和重新开球确认，再次击球。

- 第一次等待1秒时截图显示尚在运杆，不能算散球中复现；该批图保存在 `build/cue-visibility-20260928/ui-before-contact/`，日志 `restart-ui-probe.log`。
- 改为等待4秒，第二次实际1项UI测试通过；`restart-ui-scatter.log`。已打开三张图确认第一张球堆完全散开且母球离开开球点，第二张新球架/球杆正确，第三张新运杆方向正常。图在 `build/cue-visibility-20260928/ui-during-scatter/`。
- 该UI测试验证流程及禁用状态，球杆方向以这三张关键帧目视核对；不包含异常现场的逐帧录屏，不能排除未采样瞬间或真机特有时序。
- 仍未复现用户异常，未修改生产代码；下一步需要用户提供从旧局散球到新开球跳向的短录屏，以定位发生时刻及移动主体。
