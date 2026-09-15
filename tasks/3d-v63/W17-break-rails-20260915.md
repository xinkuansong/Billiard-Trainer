# W17-D 开球支架库存衔接（FL-073）

2026-09-15，用户授权继续 v63 普通击球；扎杆/跳球继续延期。本轮不提交、不发布。

## 根因及修复

`BreakFlowRunner.runBreakMotion` 是遗漏的正式回放入口：未传 `scene.railInventory`，只有临时尾段，没有跨杆克隆库存。另 `PositionPlayViewModel.loadBoard` 为外部导入清空库存，开球完成复用了该入口，不能直接保留同一局的进袋球。

- 开球回放使用共享库存；正常停稳先 `finishPlayback` 再清动作/隐藏进袋球，取消使用 `cancelPlayback`。
- runner 创建时保存 `railsBeforeBreak`；摆新架/重开清所有链。三宿主先恢复桌面，再恢复进入开球前的支架快照，避免可见球的 reconcile 提前删库存。
- 自由击球完成开球时，在 `loadBoard` 前保存库存、之后恢复；保留外部导入本来清库存的含义。思路/打三页的完成入口本来不清库存。
- 未改变开球物理、力度、种子、规则或页面布局。

## 验证轨迹

证据根 `output/3d-v63/break-rails-20260915/`；Makefile test，Debug -O / coverage NO。

1. `red/` 首次新测试编译失败：CanvasPoint 非 Equatable。改为逐 key、逐 x/y 比较，不删恢复断言。
2. `red-r2/` 生产代码未修，实际 SCNRenderer 驱动 runner.breakNow，12.742 s 失败：已知进袋开球结束后库存为空。xcresult `Test-QiuJi-2026.09.15_01-25-58-+0800.xcresult`。
3. `green/` 修复后 iPad 模拟器 25 项、0 失败、18.600 s；包含真实开球新回归、FreePlayPerspectiveBreakTests 2 项和 PocketNetPresentationTests 22 项。xcresult `Test-QiuJi-2026.09.15_01-27-23-+0800.xcresult`。首次 green 后新增三宿主恢复断言，留给最终真机用例验证。
4. `device/` 真机新回归（含自由击球/思路/打三恢复）14.298 s 通过，实测保留 `_7`；种子 844924979980821639、6 m/s、默认平面物理、轨迹 8.9915285 s。同次 UI runner 在启用自动化模式时超时，没有执行 UI 用例，整次 test 命令退出 65；不将单项通过记为整轮成功。xcresult `Test-QiuJi-2026.09.15_01-28-32-+0800.xcresult`。手机 wired、passcodeRequired=false；`device-ui-r2/` 正在单独有限重试。

模拟器 xcresult 位于 `build/DerivedData-v63-w17c/Logs/Test/`；真机位于 `build/DerivedData-v63-device/Logs/Test/`。源码 SHA-256 位于证据根。新回归没有直接伪造 settled 状态或强制灌入开球结果，沿真实求解、运杆、回放、停稳、确认调用链执行。规划页取消恢复复用该次实际开球形成的非空快照。

完整六袋视觉、VoiceOver 动作、持续性能/内存/热仍不在本次通过范围。


## 最终定向结果

`device-ui-r2` 单独重试成功：真实15/9球摆架、开球、2D/3D切换、散局确认、续打和取消恢复用例 110.109 s，1项0失败，退出0。xcresult `build/DerivedData-v63-device/Logs/Test/Test-QiuJi-2026.09.15_01-30-47-+0800.xcresult`。24张1206×2622独立截图已导出，打开15球交付与9球续打代表原图确认页面正常；这两个全桌镜头不等于六袋支架近景视觉验收，库存保留由确定性真机核心断言证明。首次UI初始化超时保留为基础设施失败，没有更改断言重试。

最终源码无漂移；verify-gate FAIL 0、verify-doc-size 和 git diff --check 通过。手机已安装此次测试构建；01:33恢复不带测试参数的正常启动，见 normal-launch.log。FL-073 本次定向缺陷已修，完整 v63 仍未完成。
