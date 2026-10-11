# P10瞄准点 r01 原生审查

- 用户要求：两固定入口继承每日核心，P09/P10四标题指定单行；授权继续所有球相关页。
- 构建：output/table-page-adaptation/P10/r01/build-r3.log，TEST BUILD SUCCEEDED。
- 回归：final/matrix.json，6单测/8UI全通过。手机/SE/iPad两P10入口，iPad横竖与恢复；P09两入口标题/设置/结果/临时2D回归。
- 已目视：phone 2D瞄准/3D临时俯视；SE 2D设置/3D结果；iPad2D/3D竖屏；P09 2D结果。台面和标题/球库不相交，透明2D叠层无地毯遮底，结果保留球杆和当前用户线，设置深色。平板竖屏3D沿标准机位，球桌在下部；未据此宣称全机型取景完美。
- 标题：UIFont13semibold测量2D角度45.06、3D角度45.38、2D瞄准点57.96、3D瞄准点58.28pt。AX测到字形宽高，不是SwiftUI60×34外框；字形容量与球库无重叠断言通过。
- 历史失败：first-unit-failure保留旧机位/旧viewport测试；second-run-ax-bounds保留AX误测。修正测试前提后保留球可见/方向/题目/成绩/标题无交叠不变量。
- 边界：未装真机、未Figma编辑、未提交/发布；手感/触觉强度需实际手机，不外推模拟器。图册与原图在output/table-page-adaptation/P10/r01/index.html。
- 下一步：依用户连续授权进入P02自由击球。
