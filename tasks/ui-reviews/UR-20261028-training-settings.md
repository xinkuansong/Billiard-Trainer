# 训练设置 UI 审核 — 2026-10-28

状态：实现与定向模拟器复验完成，待用户实看；真机、VoiceOver、分屏及发布验收未覆盖。

## U-01 iPad 顶部 Tab 栏遮挡设置标题

- 严重程度：P2；位置：练习 Tab 中准度、分离角、两球、三球、多球、蛇彩、自定义设置。
- 实际证据：基线 iPad mini A17 Pro / iOS 26.2，16入口×横竖屏32张原生截图。12个入口的系统顶部 Tab 栏覆盖“训练设置”；角度与瞄准点4个入口正常。
- 标题AX中心最大误差0.25pt，开始按钮全部在标题右侧。因此原始证据支持“标题被遮挡”，未复现“开始不在右边”。仅看AX坐标会漏报。
- 修复：四个设置组件隐藏Tab栏，显式使用principal居中标题、topBarLeading返回/取消、topBarTrailing开始/重新开始；保留原生导航。
- 回归：加入标题可命中、Tab栏不可命中、标题与主按钮同一行、标题水平居中及主按钮位于右侧的断言，辅以逐图审查。

## U-02 设置语义及模式复用

- 准度“自行调整”与“系统指定”分组；分离角/两球轨迹用“参考路线杆法”，自由走位隐藏并忽略该筛选。
- 两球模式各自保留草稿与已确认设置；退出取消不写偏好，出题成功才保存。旧偏好只读迁移，2D/3D独立。
- 多球先玩法/走位模式/球数后训练量；蛇彩历史默认折叠；自定义标题明确为选择球形。完整顺序/默认见[执行卡](../TRAINING-SETTINGS-REVIEW-20261028.md)。

## 证据索引与范围

- 基线：`output/training-settings-20261028/baseline/evidence/tests.xcresult`，原图`baseline-native/`，逐页标题审查`baseline-headers-1.jpg`与`baseline-headers-2.jpg`。
- 首轮候选r1：12项全部通过（9单元＋3UI，0失败/跳过），包含模式切换、取消与重置事务；新增3条模型/预取测试和6条几何既有断言通过。此候选尚未隐藏Tab栏，不作为最终视觉验收。
- 最终候选r4：源码快照`11884ff389be56d75507b3a330fdfb3fa79c6453729a3abd91201d8e7ecc4fa2`，包含当时共享工作区其他任务的既有更改。测试覆盖iPad mini、iPhone SE3 / iOS17、13英寸iPad Air；后者补浅色及超大文字。
- 尚未验证：真机iPad/手机手感、VoiceOver、分屏窗口、全App回归及发布验收；不以模拟器结果替代。

## 最终候选已核证据

- iPad mini A17 Pro / iOS26.2：3项UI全部通过，0失败/跳过。16入口×横竖屏32张标题原图已逐一核对，标题最大水平偏差0.25pt，与开始按钮中心高度差0pt，未见Tab栏遮挡。
- 全页抽核：准度、两球、三球、多球、蛇彩、自定义的竖屏内容；分组/顺序清晰，蛇彩历史折叠，空模板时开始禁用，无新增重置项。两球模式保存/取消及重置事务有操作证据。
- 证据：`output/training-settings-20261028/review-pad-r4/evidence/tests.xcresult`；原图`review-pad-r4-native/`，标题图册`review-pad-r4-headers-1.jpg`、`review-pad-r4-headers-2.jpg`，坐标`review-pad-r4-header-measurements.json`。

代表原图：[准度](../../output/training-settings-20261028/review-pad-r4-native/header-2D准度-1.png)、[两球](../../output/training-settings-20261028/review-pad-r4-native/header-2D两球走位-1.png)、[多球](../../output/training-settings-20261028/review-pad-r4-native/header-2D多球走位-1.png)、[蛇彩](../../output/training-settings-20261028/review-pad-r4-native/header-蛇彩练习-1.png)。

模型验证沿用r1的9项通过证据：已核对r1与r4的`SceneTrainingRules.swift`、`TwoBallPracticeViewModel.swift`及对应三个测试文件哈希一致。r4的区别是设置导航/测试可见性，以及同期其他任务的页面改动。

- iPhone SE3 / iOS17 r4：7项中6项通过，包含16入口导航、准度重置、蛇彩取消/重置、多球保存、自定义无重置、Pro返回。16张标题原图逐一目视通过，居中≤0.25pt、同行差0pt；准度/多球整页无文案挤压。
- `testTrajectorySettingsRestoreDefaults`失败保留：演示开关后已经在页面底部，旧测试向下寻找上方角度行；iOS17懒加载AX树已移除此行，日志连续向下拖动24次仍停在条件/演示/重置区。r5测试改为先回顶部再按新顺序检查，全部值断言保留，生产代码与r4完全一致，定向复跑准度与轨迹重置。证据`review-phone-r4/evidence/tests.xcresult`，不把原失败改记通过。

- iPad Air 13英寸 M3 / iOS26.2 r4：2项UI通过，0失败/跳过；32张横竖屏标题原图、准度/两球浅色Accessibility XXXL的4张首屏与底部图已核对。长标签、值、开关和恢复默认无重叠，底部动作可达；标题偏差≤0.25pt、同行差0pt。证据`review-largepad-r4/evidence/tests.xcresult`及`review-largepad-r4-native/`。
- 可访问性边界：本轮证明指定大字号下的可见性、排版与恢复默认触摸范围；导航标题/共享选择器及辅助说明仍沿用既有固定字体Token，没有据此宣称全部文字动态缩放、对比度或VoiceOver通过。

## 最终验证汇总

| 范围 | 结果 | 证据目录（`output/training-settings-20261028/`） |
|---|---|---|
| 模型/兼容验证 | 9单元通过，相关源码与最终版一致 | `review-r1` |
| iPad mini A17 Pro / iOS26.2 | 3 UI通过，32导航状态 | `review-pad-r4` |
| iPhone SE3 / iOS17 | 6 UI通过；1条旧滚动路径失败已保留 | `review-phone-r4` |
| iPad Air 13英寸 M3 / iOS26.2 | 2 UI通过，32导航状态＋4张浅色超大字图 | `review-largepad-r4` |
| iPhone SE3 定向复跑 | 准度＋轨迹重置2 UI通过，0失败/跳过 | `review-phone-r5` |

总计80张导航原图均已核对，居中误差≤0.25pt，同行差0pt。另抽核常规完整设置页与浅色超大字；不是全App/全部辅助功能验收。UI阶段13次成功执行包含跨设备/复跑重复，不等于13个独立用例。r1另3条UI仅作诊断及早期事务证据，不重复计入最终界面统计。

手机r5只改变测试滚动顺序：每次需要回到上方设置时先滚至已知训练量位置，再向下寻找；保留全部默认值、模式、条件及开关断言。原r4失败xcresult未覆盖。生产实现以r4为准，r5逐字节相同。

规范门禁与差异检查通过；主工作区没有提交。测试快照与原始失败/通过证据均归档，临时模拟器按所属任务退役，未动其他评审现场。
