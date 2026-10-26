# 球库窄窗比例修复 · 2026-10-26

状态：修复完成，本轮32项布局单测＋6项原生UI共38/38通过，0失败/跳过；原生截图复核通过，待用户体验。推荐补验U-01技术修复闭合；原22项功能结果保留为历史，不混算本轮数量。

## 修复与范围

用户指出少球窄窗球库过大，以全屏紧凑比例为参考。旧代码按窗口/障碍能否放下选择最大档，9球在窄桌仍36pt。DR-441：按未缩放2D桌宽的完整15球参考选择36/34/30/25pt基础上限，再应用当前球数和原避让；最低25pt。少球仅缩短总宽，15球不是业务数量要求。3D使用稳定HUD桌框。FoundationReservation、Foundation、球桌/仪表位置、球面材质、固定槽位和选择权限均保持。

源码直接调用方：FreePlayView、BTTeachingTablePage、BatchAuthoringView、AimPointSceneTrainingView、SceneAimingView。共享视觉规则一致；本轮原生聚焦用户反馈的多球和复用的蛇彩/工具/每日。教学、瞄准点和内部编排未逐页原生重测；这些页面没有新增自动推荐。

坐标为页面pt、原点左上、x向右/y向下；实际table.width是未缩放桌外框。参考宽36档588pt、34档558pt、30档498pt，低于25档参考宽仍保留25pt。九球在274pt桌宽时总宽251pt（旧350pt），531pt桌宽30pt，900pt桌宽36pt。不是物理球径或袋口几何变化。

## 局部适用性

|条款|判定及检查|
|---|---|
|TP05|继承修订后的桌宽基础档、居中贴桌顶、固定槽位；少球不放大|
|TP06|继承选择与已落袋语义；真实窄窗点击选1号球|
|TP07/28|继承；不改Foundation或保存布局，原生旋转/缩窗/恢复保留球形|
|TP35|继承；独立源码冻结、原生截图、单元/交互证据与未验范围|
|其他|延续多球/推荐既有页面卡，无本轮合同变化，不把未测项标为不适用|

## 证据

`output/palette-proportion-20261026/`：source-binding.json冻结身份；tested-source保留改动源码；commands.json实际命令/退出码；selectors.json范围；standard-pad和compact-phone的结果包/截图。修前与用户参考保留在`output/shot-recommendation-acceptance-20261026/`。最终结果见下文及verification.json。

真机按用户要求暂缓；极端字号、VoiceOver与全部设备矩阵未验。未提交、推送、发布。

## 已完成的iPad复验

iPad Pro 11 M4 / iOS 26.3.1：32项布局单测＋3项原生UI，共35项通过，0失败/跳过。包含窗口容量扫值、少球同桌尺寸、新窄窗复现；原生多球旋转/缩窗/恢复/重新开始/设置取消、3D临时摆球/打点/布局取消；蛇彩3到15球与2D/3D。`PALETTE_PROPORTION fullSlot=38.0 smallSlot=27.0`，恢复全屏槽宽38pt断言通过；分别对应36/25/36pt球面。窄窗实际点击1号球并断言目标已切换，球形位置全程保持。

已实看原图：`05-ipad-portrait`、`07-ipad-small-window-2d`、`09-ipad-full-window-restored`、`35-layout-cancelled`、`table-3-2d`、`table-15-2d`、`07-fifteen-3d`，并与旧同设备/种子/缩窗原图对照。窄窗球库从超出桌宽收为桌宽内，球号与选择边框清晰；全屏仍为用户参考的紧凑比例，球库居中贴桌顶。3D是稳定HUD锚，不能把投影中的桌边当作HUD对齐线。未发现本次尺寸调整引入的截断或遮挡。

[修前/修后完整原图对照](../../output/palette-proportion-20261026/comparison.html)。原图未重绘，截图状态栏FPS/短亮选球动画的时刻不同；此比较证明布局差异，不宣称逐像素等同。

## 手机回归与最终收尾

iPhone SE 3 / iOS 26.3.1：3项原生UI通过，0失败/跳过（工具读数/renderer、多球9球设置与重开、每日满15球连续3杆并2D→3D→2D）。三杆后剩14→13→12球，推荐7→5→3号，0犯规。实看`02-rotation-nine-2d`、`p01-readout-landscape`、`recommendation-shot-2-3D-before`和`recommendation-shot-3-2D-settled`：球号、固定槽位/落袋态、布局完整；9球比15球只缩短总宽，球面同档30pt。

构建成功；38项定向测试通过；改动文件`git diff --check`与文档体积门禁通过。全仓`verify-gate`仍因既有`route-coverage.csv:87`未声明`ControlLayoutLibrary.swift`失败（其余同步/发布/schema/文案阶段通过）；本次未改该登记，不能宣称全仓门禁通过。PROGRESS旧10-08球库历史段原文已滚动归档，未上调体积阈值。

本结果绑定冻结源码。结束时并发工作只改了`AimPointSceneTrainingView.swift`、`SceneTrainingRulesUITests.swift`，详current-source-comparison.json；本轮球库实现与测试源未漂移。未把并发瞄准点变更当作已测。完整命令退出均0。

设备共用既有SE/iPad，已恢复原字号large、关机并释放租约；未新建/删除设备或触碰其他任务现场。受管测试工作区`f0ef26dfaf5d49d3a714ea0381c0c84b`成功自动回收，实际空间净增约1.40GiB；源码身份、原始截图、日志和两个xcresult保留在证据目录。用户真机验收按要求暂缓，未提交、推送、发布。
