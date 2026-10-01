# 重新开球全局视角与摆球参数恢复（2026-10-01）

用户要求恢复此前参数，并在 3D 点击重新开球后默认全局；物理引擎不能改动。

## 实现

- RackLayout 名义表面缝隙恢复 0.20 mm，世界 X–Z 平面每球均匀圆盘随机偏移半径恢复 0.09 mm。生成策略保持现有逐球独立方式；理论相邻缝隙 0.02～0.38 mm，不互穿。
- FreePlayView 在新球架 seed 到位时调用现有全局相机入口。每日清台涵盖局中、动画中途和待开球再次重开；普通自由击球已有球架换 seed 同样进入全局。每日沿用最近长库侧、35°取景；普通入口沿用已有全桌相机参数。
- 取消重开保留原镜头；2D 重开仍为 2D；完成交付时 runner 变 nil 不复位相机。普通首次进入开球保留原瞄准入口。
- 本轮前后 Core/Physics 全部 Swift 与 BreakSimulator 共28文件 SHA256 一致，CameraRig 未编辑。工作区其他既有物理和相机改动未回退。

## 功能验证

设备 QiuJi-3DScope-Standard / iPhone 17 Pro / iOS 26.3，隔离于其它会话的模拟器。

- 改前新回归真实执行1项、1失败：观察视角重开后全局按钮仍为“未选中”。截图先取证再修改生产代码。
- 改后 11 单元＋2 UI 全部通过（after.log）：8 RackGeneratorTests；3 jitter 测试覆盖五玩法×201 seed、不互穿、确定性与有界扰动。最小实测球心距57.179 mm，大于球径57.15 mm。
- testRerackReturns3DToGlobalCamera 覆盖观察/第一人称、取消、确认、再次重开、2D保持，检查实际相机35°与全局高亮。testRerackDuringLiveBreakKeepsCueAtNewRack 验动画中途重开及再次出杆。
- 普通自由击球 testPerspectiveBreakAndContinue 1 UI通过（freeplay.log）：15球/9球重开、2D/3D往返、停稳交付、继续击打、取消开球。共14项相关测试通过。
- 内容/发布图/DTO/文案部分门禁通过；全库 verify-gate 被已有写盘测试清单漂移阻塞：PocketMarkerHighlightTests.swift 未登记（本轮未修改此测试）。初次完整 diff --check 发现其它会话修改的设计系统技能末尾空行；本轮新增代码定向检查见最终检查。

日志：build/rerack-reset-20261001/{before.log,after.log,freeplay.log,gate.log}。改前、改后截图与相机诊断：同目录 before/、after/。

## 视觉审查

当前执行者切换 UI Reviewer，按现有设计系统、Token、docs/05 核对原生整页截图。页面固定深色，未更改布局、颜色、字体、点击框或共享相机算法。

改前重开保留沿杆近景，桌面下缘超出画面；改后从观察/第一人称重开均回全桌，六袋、新球架与母球可见，全局眼睛高亮，两侧仪表及击球按钮可用。未发现本轮新增文字截断、溢出或遮挡主球组；全桌构图为现有已选35°入口。普通自由击球重开15球的原生竖屏图也已目视，完整球桌与六袋在画面内。问题数量：本轮新增P0/P1/P2均0。

代表图：[观察视角重开后的全局](../../build/rerack-reset-20261001/after/rerack-shotCamera.thirdPerson-after.png)、[第一人称重开后的全局](../../build/rerack-reset-20261001/after/rerack-shotCamera.firstPerson-after.png)。

已安装并启动默认 iPhone 17 Pro 模拟器（AE86244C-EE61-4585-882F-E39B892214DB）每日清台入口；安装包可执行文件与通过测试的构建 SHA256 一致，见 build/rerack-reset-20261001/install-check.json。

真机体验及工作区其它相机缺陷不在此次验收范围；未提交或发布。
