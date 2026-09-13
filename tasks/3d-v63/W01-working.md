# W01 实施检查点

状态：🔄 首项竞态修复已实现，定向测试构建中。W01 尚未完成。

## 已复核的入口与根因假设

1. `ShotPlayCamera.setMode` 每次进入 perspective3D 都调用 focus，再强制 rig.update(deltaTime:1)，因此同杆恢复观察机位被沿杆取景覆盖。W01 需要区分初次进入/有效业务上下文变化与同杆观看往返。
2. `AngleTrainingScene.setCameraMode` 存在两条不同链路：试点 animated:false 用 snapToTarget；其他消费者 animated:true 用 transitionToPerspective，后者重新按母球/杆向计算 aim pose。不能只修两页辅助函数就声称共享契约完成。
3. `transitionToTopDown` 的嵌套 SCNTransaction completion 未核对当前模式或转换代次；快速切回 3D 后旧回调可能把投影改回正交并错误清理 transitioning。需要代次校验与真实快速往返回归，暂为源码支持的竞态假设，尚无本批运行证据。
4. 现有 CameraRig 内部 current/target/smooth pose 与节点世界姿态不能混同。保存仅节点变换会被下一帧 rig 覆盖；保存仅 target 会跳过尚未完成的过渡。必须定义并测试恢复的可见姿态与后续手势连续性。
5. 原有 ShotSimulationCameraTests 只断言球形/参数/预测不变和旋转生效，没有验证 3D 姿态往返保持或旧 completion 竞态。保留原断言，新增这些覆盖。

## 下一步

- 读取 W01 完成标准与相机剩余实现，建立独立观看快照/有效上下文契约；不把业务参数复制进相机模块。
- 先补失败测试（真实 setCameraMode 快速交错、同杆保存恢复、显式 focus、新杆、播放中切换），再改共享实现。
- 保留基线里的 CameraRig.hasPendingDamping；新状态字段若需持续更新，纳入同一收敛判断。
- 运行专用 DerivedData 与独立 simulator，不与其他任务共享活动 UDID。代码文件当前仍是基线版本；开始编辑前再次比对 SHA，保留其他任务变动。


## 首项实现与运行句柄

- AngleTrainingScene 新增每次模式切换的 UUID，三个延迟完成回调核对代次，避免过期回调重新设置投影或清理新转换状态。
- PositionPlayFreeAimTests.swift 新增 CameraModeInterruptionV63Tests，两向中断覆盖；既有 ShotSimulationCameraTests 同批运行，原断言保留。
- 定向运行：exec session `92184`，日志 `output/3d-v63/W01/camera-r1.log`，结果 `camera-r1.xcresult`；专用 UDID `2447DFF4-394E-4707-8063-87F4763B3704`，DerivedData `output/3d-v63/DerivedData`。
- 当前仅确认构建进程仍在运行、diff 空白检查通过；未宣称测试通过。下一次先轮询同一 session 或查该 xcodebuild PID/log，不能因观察超时重复启动。
- 测试通过后仍须用移除代次保护的隔离副本证明新增断言能捕获旧竞态；若 SceneKit 离屏事务没有被驱动，需修测试宿主而非接受空覆盖。
- 同杆观看姿态保持、新杆失效、播放/前后台状态仍待实现与验证。


## 2026-09-12 后续实现与验证

- r1 已结束，3/3 通过；r2 已结束，5/5 通过（新增同杆观察机位往返、阻尼恢复后下一帧一致）。这些只证明各自断言，不代表 W01 全验收。
- CameraRig 新增 PerspectiveState，独立保存 current/target/smooth 运动状态与投影参数；AngleTrainingScene 保存/恢复此状态，显式 focus 清旧观察记录，换盘面及杆结束使旧上下文失效。ShotPlayCamera 不再每次回到 3D 都沿杆重新聚焦。
- r2 后补充了显式 focus 与新盘面失效边界，当前版本尚需重跑；不要把 r2 作为这些后续改动的通过证据。
- 反向控制 `red-control`（只去掉回调代次保护）2/2 仍绿，说明原离屏回归没有证明旧竞态可检出；不能作为修复验收。已改成可见 UIWindow/持续 SCNView 渲染，动画开始100ms后再中断。
- 最新运行句柄 `43223`：隔离红控制的可见窗口测试；日志 `output/3d-v63/W01/red-visible.log`，结果 `red-visible.xcresult`。下一轮先查询该句柄。若仍绿，继续修测试可观测性，不删除断言或把红控制省掉。
- W01 剩余：可信快速切换红绿证明、显式 focus/新杆/播放/前后台状态验证、真实 UI 视觉，及相关 gate/文档回写。W02 及之后未开始。

红控制可见宿主已结束：1通过/1预期失败，`testInterruptedTopDownCannotOverwriteLatestPerspective` 的 usesOrthographicProjection 断言捕获过期回调（red-visible.log:335）。旧实现确实可被此回归检出。当前修复开始同样宿主的 r3 五测；日志 camera-r3.log，xcresult camera-r3.xcresult，下一轮查询正在运行的 make test 句柄。
当前 r3 exec session：32737。先轮询同一进程，再根据结果继续；不得将尚未结束的 r3 标为通过。

## W01 后续证据（2026-09-12）

- r3 五测全部通过，已使用能在红控制中检出旧问题的可见窗口宿主。
- r4 八项单测＋一项真实 UI 流程通过。UI 覆盖后台再激活、2D/3D往返、旋转/捏合、显式focus、打点、击球时切换、回放/重打；截图保留 `output/3d-v63/W01/screenshots`。已直接查看 after-orbit 与 v63-restored-orbit，球桌/球杆/球位构图一致；只作机位保持证据，既有遮挡/布局仍归W09。
- r5 七项观看状态单测通过，含已提交理论答案/误差保持、序列准备态杆序/球形/意图保持。
- verify-gate / verify-doc-size 均 exit 0（gate.log / doc-size.log）。
- 审核补齐 resetAll/clearTable/startBreakFlow 的观看上下文失效入口；新增固定seed63开球/清空/重置检查。最新 r6 正在运行（camera-r6.log / camera-r6.xcresult）；这三处后续变更尚不能引用r5作为通过证据。
- 尚待：r6结果、W01逐项验收记录/DR回写与下一批状态更新。不能将本页历史“尚未修改”段落视为当前状态；以本页末尾最新检查点为准。
当前 r6 exec session：69909。另一个待核验边界：setCameraMode 对同模式 animated:true 请求目前仍可重新恢复旧 savedPerspectiveState；下一轮先查真实调用/补幂等测试，再决定是否统一无操作，避免重入请求夺走手动观察机位。

r6 已结束：11/11 通过。补齐同模式请求幂等（避免 savedPerspectiveState 抢回手动观察），新增一项测试；r7 当前 exec session 64675，日志 camera-r7.log。下一轮先轮询，后完成 W01-acceptance.md 的验收状态/DR141记录与W02开工。用户授权始终有效，无需再确认执行。
