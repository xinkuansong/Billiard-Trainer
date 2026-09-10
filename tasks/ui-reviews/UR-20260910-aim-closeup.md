# 瞄准特写手势保持修复（DR-131）

## 问题与实现

用户报告2D瞄准点训练中手指未松开特写已消失。原始逻辑隔离复现表明：最后一次移动280ms后即隐藏；共享Gate的瞄准轮也被noteAimChanged重新安排的计时覆盖。

修复：AngleSceneView发出实际瞄准pan开始/结束/取消/失败事件，禁用交互后仍消费终止事件；Gate按table/wheel保存独立活跃源，任一仍活跃就不安排隐藏，最后释放后保留原280ms；reset清除所有源。BTAimWheel覆盖GestureState取消和onDisappear收尾。AimPoint页复用同一Gate，保留近区滞回、快照与画面几何。

## 验证记录

- `unit-tests.log`：9项通过，含8项Gate与1项真实AimPoint VM。
- `ui-tests.log`：手势Coordinator测试通过，覆盖ended/cancelled/failed且交互已禁用时的释放；UI准备因误用SearchField定位TextField失败。
- `ui-tests-r2.log`：2D瞄准点训练UI通过；分离角页面准备因模式按钮定位不正确失败。
- `ui-tests-r3.log`：四条页面操作完成。逐图复核发现翻袋/分离角的第一次台面触点落在48pt球命中热区，反射默认方向是打库而非目标球近区；这些图不作为台面特写保持通过证据。已修正测试前置后单独复跑，未据此更改产品。
- 所有UI测试期间只通过simctl读取截图，不与人工模拟器操作并行。

## 视觉验收方法

标准iPhone 17 Pro / iOS26.2。XCUITest发出真实press → drag → hold(8s) → release；宿主监测hold标记，在3/5/7秒截实际屏幕，松手0.6秒后再截一张。功能状态由单测断言，实际hold画面由原图目视确认。UI脚本本身的通过不替代截图验收。

改前：SE3/iOS26.2实际2D页截图 `before-aimpoint.png`；改前计时缺陷由前轮独立原逻辑程序复现。改后标准手机随机题不同，不能作为同题/同尺寸像素对照；本轮未修改布局/配色/几何。

## 验收边界

全量运行日志、截图在 `output/aim-closeup-diagnosis-20260910/`。Debug构建成功（build.log，退出码0），verify-gate通过（FAIL 0 / WARN 0），git diff --check及文档体积检查通过。真机触摸/系统中断、iPad、旧Runtime及试打所有球形未验；未提交、未发布。

## 最终页面复核

以下为有效近区下保持触点的5秒原图及松手0.6秒后原图，位于上述证据目录的 `ui/`。文件格式为 `<前缀>-wheel/table-held-5s.png` 与 `<前缀>-wheel/table-released.png`。

| 页面 | 最终图片前缀 | 已复核路径 |
| --- | --- | --- |
| 2D瞄准点 | aimpoint2d | 瞄准轮、台面 |
| 3D瞄准点 | aimpoint3d | 瞄准轮 |
| 自由走位 | composer | 瞄准轮、台面 |
| 自由击球 | freeplay | 瞄准轮、台面 |
| 每日清台 | daily | 瞄准轮、台面 |
| 翻袋解球器 | bankBlank | 瞄准轮、台面 |
| 分离角与走位 | shotBlank | 瞄准轮、台面 |
| 反射解球器 | diamondAimed | 瞄准轮、台面 |

r4覆盖3D、翻袋、每日清台、自由击球；r5的shotBlank通过有效近区图审。r4/r5的diamondNear/diamondSlow未进入目标球近区，不作为保持验收。r6使用真实瞄准轮调整至“首碰”后，diamondAimed瞄准轮与台面保持及释放图审通过。所有最终路径均表现为近区按住保留、释放收起。3D页台面用于相机交互，未计为瞄准pan验证。
