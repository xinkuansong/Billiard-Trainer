# 训练辅助视觉审查（DR-121）

2026-09-08；iPhone 17 Pro / iOS 26.2，独立设备 `A08B717C-E678-4B37-BD1A-1E1632C3A5BD`，训练页固有深色外观、默认字号。

## 已实现范围

- 3D 角度训练：辅助开启时木色球杆随当前观察方向转动，关闭辅助、结果或换题清理；半透明乳白假想球为完整 SCNSphere，与母球同半径；青蓝瞄准点半径 3.25mm、橙黄接触点半径 4.5mm，均为旧半径一半。球位与正确辅助线计算不变。
- 3D 瞄准点训练：已有球杆保留，两点改青蓝/橙黄、半径均 3.25mm；G1 垂足与射线球面交点定义不变，未新增假想球或辅助开关。近区特写同步颜色和实际比例。
- 共享 2D 训练消费者继承样式；其他翻袋/反射等场景默认仍是旧圈与旧色；独立二维拖圈“瞄准点训练”未改。此页名称歧义已向用户询问，本次暂按 3D 场景解释。

## 功能验证

`output/aim-assist-20260908/final.log`，`Test-QiuJi-2026.09.08_17-02-31-+0800.xcresult`：

- AngleSceneCalculatorTests：6/6，通过坐标转换、球心间距、切角等既有回归。
- TrainingAssistSceneTests：1/1（0.421s），实际场景验证开关、球体半径/相切距离、四方向球杆局部轴与视线相反、隐藏后更新不复现、换题清理。
- UI：2/2（66.573s），从练习入口进入 3D 角度训练并开/关辅助、横滑；进入 3D 瞄准点训练并调整方向，提交按钮可用。
- 最终日志 `TEST SUCCEEDED`；最终源码经 `make -f scripts/Makefile build SIM_DEVICE=QiuJi-AimAssist-20260908` 构建，`build.log` 含 `BUILD SUCCEEDED`。`git diff --check` 与 `make -f scripts/Makefile verify-doc-size` 通过。
- 首次旧双模式 UI 测试：2D 成功取证，重启后第二轮 3D 未进入练习分类而失败，日志和视频完整保留在 before*。另设独立 3D 单场景测试，改前和改后均通过；没有用旧失败作为产品视觉结论。

## 视觉审查

已打开整页原图：

- [角度训练改前](../../output/aim-assist-20260908/angle-before.png)
- [角度训练改后](../../output/aim-assist-20260908/angle-after.png)
- [关闭辅助](../../output/aim-assist-20260908/angle-hidden.png)
- [瞄准点训练改前](../../output/aim-assist-20260908/aim-point-before-live.png)
- [瞄准点训练改后](../../output/aim-assist-20260908/aim-point-after.png)
- 转动后的原图见 `final-attachments/2B6F16D7-C322-4D0D-9EA9-5CAEBE1DD6C5.png`。

结论：当前标准手机两页样本通过；球杆、完整半透明球、小点可辨识，关闭辅助后球杆与标记消失，按钮未被遮挡。沿用已有机位与页面空间分配。本次题目随机生成，前后不是同一球局，不用于像素级几何对比；几何由单元测试验证。

## 尚未验证

- 真机、iPad、紧凑手机，以及完整颜色/球号/角度组合的可读性。
- 共享 2D 页面最终样式、近区特写最终渲染和提交后整段物理回放未在本轮单独截图验收；相关几何、击球流程未变。
- 此次没有发布或提交，仓库其他并行修改保持原状。
