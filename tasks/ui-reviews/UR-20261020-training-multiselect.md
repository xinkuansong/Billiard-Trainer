# 训练设置多选与准度原生审查

首轮覆盖现有四入口设置表单；下方同日追加覆盖六入口及准度击球页。规则为准度方案v1.3及`docs/05`同日设置修订。

## 已查看证据

- SE／iOS26.3，原生四入口多选截图：`output/accuracy-practice-20261020/settings-screens/manifest.json`。四张均已逐图查看。浅色页面；角度小角度与极薄球同时勾选；条件弹层短、长同时勾选，其余为空框。距离摘要原来包含完整区间，在窄屏发生换行，属于P2密度问题。
- 对应修订：表单摘要改为“短、长”等档位名，弹层仍显示完整范围，避免信息丢失。最新SE截图待回收，不沿用修订前截图验收。
- iPad Pro 11英寸／iOS26.3，四入口原图：`output/accuracy-practice-20261020/settings-pad-screens/manifest.json`。四张均已逐图查看。实际为竖屏深色，不能据设备标签声称横屏覆盖。新摘要单行、空框和勾选清楚，四条球形条件及底部说明完整；弹层无截断，四入口同态。来源结果包：`output/accuracy-practice-20261020/settings-pad.xcresult`。

## 功能证据与边界

SE第一轮13项单测及1项遍历四入口的UI测试通过。iPad同一UI测试通过。已验证连续选择保持弹层、关闭重开保留选项、角度随机标签0–85°及半贴库／贴库多选。

首次UI测试在导航标题处点击关闭，只证明外部关闭，不能证明点击底层“开始训练”不穿透。已补充真实坐标点击开始按钮、最后一项保护及随机互斥检查，等待新构建实操结果。

当前未发现已查看画面的P0／P1问题。完整Visual Gate尚未结束：标准手机、iPad横屏、Dynamic Type／VoiceOver、新准度表单和击球页仍待验证；不把自动化或截图审阅称为用户验收。


## 同日准度与六入口复验

- `six-settings-history.xcresult`：六入口连续多选、随机互斥／最后一项保护、外部点击开始按钮仅关闭弹层、重新打开保留草稿全部通过；4项记录合同／历史隔离／额度幂等测试通过。替代上述首轮待验状态。
- `accuracy-final-regression.xcresult`中的`TrainingMultiSelectionUITests/testAccuracyBothModesFreezeTipAndPreserveResultAcrossReturn`通过：SE两种模式固定打点拖动不变，关闭打点盘已明确等待消失；菜单无答题辅助，实际出杆→静态结果→回放→返回重进→手动下一题。此结果包原四类测试有4项失败（表单懒加载行未滚动就查存在），已修测试滚动，另包复跑，不能将整个结果包写为通过。
- `accuracy-pad-final.xcresult`同一准度流程通过，包含iPad两种模式竖屏→横屏→竖屏可操作性断言。两种模式／方向下题目、球、方向尺、打点、杆速及击球键可见；3D沿用共享视角，竖屏保留球房上方空间。
- 已逐图查看最新SE两模式aiming及3D result（`accuracy-final-regression-screens/`），以及Pad的2D landscape、3D aiming/landscape（`accuracy-pad-final-screens/`）。单条用户方向线、无假想球、固定杆法与指定袋文字符合合同；回放图标已正常显示。打点盘关闭后的图替代旧r3带浮层图。未对未查看图片作视觉通过声明。
- `accuracy-native-r2.xcresult`中的额度／Pro门控测试及6项封面路由测试通过。

当前所检画面未见阻断问题；真机手感、VoiceOver、极大字体及全App回归未验，用户视觉接受仍待实际试用。题库物理证明与筛选覆盖见实施报告，不由截图外观推断。

旧四类补充：`old-four-regression.xcresult`四项全部通过（193.7秒），对应本次题库迁移后的实际答题流程。六入口设置新导出的2D准度原图已查看，角度两项勾选、条件短长两项勾选、空框、随机0–85°、库边距离与杆法开关均可见。可审阅图册：`output/accuracy-practice-20261020/验收预览.html`。

最终补充：`accuracy-relaunch-r2.xcresult`双模式进程重启恢复与结束总结通过（92.403秒）。两张SE浅色总结原图已实看于`accuracy-relaunch-r2-screens/`，分项记录为长滚动内容。首次根AX标识被ProAccessGate覆盖的定位失败保留；复验改为核实际可见标题和正文，未改变App总结流程。
