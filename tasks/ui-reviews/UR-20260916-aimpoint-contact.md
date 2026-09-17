# 瞄准点训练切点标记验证

日期：2026-09-16。范围仅为 AimPointTrainingView 的 AimPointDragFigure。

- 在目标球与假想球圆心中点画红点，复用原瞄准点尺寸、颜色、提交后透明度。
- 最终修正为过切点的竖直虚线（平行白色瞄准线），复用 FigureLine.hint、lineHintWidth、[5, 4] dash；两条线在球体下方，切点在球体与假想球圈上方。
- 坐标为屏幕 pt，右正、下正。7档 -90/-60/-30/0/30/60/90 度数值检查：切点到两圆心均等于半径，左右水平偏移量相等。

## 验证

标准 iPhone 17 Pro / iOS 26.3：改前与改后均执行 S3_AimPointUITests/testAimPointTrainingLayout，分别 Executed 1 test, with 0 failures，TEST SUCCEEDED。改后包含左右拖动及提交。

证据：`output/aimpoint-contact-20260916/before.xcresult`、`after.xcresult`；导出截图及 manifest 在同目录 before/after。四张改后原图已目视：正碰、左偏、右偏、提交态均显示切点，辅助线平行；红点无球体遮挡，原球号/布局保持。改前后随机题目不同，不作为同题评分对照。git diff --check 通过。

未做：真机、iPad、完整可访问性与全仓回归。Impeccable context 启动器 permission denied，依据现有组件与用户截图实施。

## FL-078 方向修正
用户指出应为垂直线，前版水平方案不符合需求。最终端点 x 均取 contactPoint.x，y 与白色瞄准线一致。`vertical.xcresult`：Executed 1 test, with 0 failures / TEST SUCCEEDED；vertical 目录左右拖动原图已复核，竖直虚线穿切点并平行白线，保留原水平参考线。真机未验。
