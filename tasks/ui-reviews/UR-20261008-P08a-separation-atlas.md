# P08a r01 分离角图谱

用户认可AD01后指定继续本页。源范围与DC映射见[P08a卡](../table-page-adaptation/P08a-SEPARATION-ATLAS.md)。

## 实施

直接提取AD01当前公共容器和每日相机桥接，两页调用同一代码；模板基础仍复用DailyLayoutMetrics、DailyTemplateHeader、DailyHUDMenuPanel、DailyStatusCluster、BTShotInstrumentColumn、ShotPlayerCameraButtons。图谱保留八路simulateFree、色序/至少一档、杆速绑定、碰后到首库/停球的切片、台面选球选袋与球库拖入拖回。用户补充后左列改为八档紧凑全显、无滚动；右侧四键按真实杆速外框中心对齐。AD01无杆速分支的原布局保持。

## 验证与失败轨迹

- before真实原生图已目视，旧版黑底、顶栏读数、底部16球库、旧观察菜单有存档。before UI执行中在43.99999999999994与44直接比较上失败；属于浮点表示，原日志保留。新版仍要求44pt，仅用0.001pt数值误差检查。
- build首次通过；补球库拖入能力后协议要求了AD01没有的方法导致编译失败，改成页面可选能力闭包，未给AD01补虚假实现；新增相机单测漏MainActor标注的编译失败也保留，修正后build-r4通过。
- 14项单测通过，含同输入每日相机姿态、普通调速/轨迹不抢相机、临时俯视更新与返回、八档至少一档与轨迹切片等。
- 最终6次原生UI执行通过；截图/命令/xcresult在output/table-page-adaptation/P08a/r01/compact。

状态：最终原图已完成目视检查；未安装真机、未提交发布、未改Figma。

用户追加紧凑八档不滚动，覆盖最初滚动方案；旧checks目录保留为过程记录。首轮UI在读取shotStage.powerShell时失败：该可访问性ID被外层solver.power覆盖，实际相机按钮已可见可点。新版按只有单尺的真实solver.power外框核对中心；新增8行同时完整可见、无重叠、无ScrollView、逐项点击断言。

## 最终结果

最终构建build-compact通过；14单测及6次UI执行全部通过；verify-gate（FAIL 0）、verify-doc-size和git diff --check通过。原始矩阵及source/app身份在compact。启动SE前读取字号遇设备Shutdown，runner在测试执行前退出，未伪记用例失败或通过；补显式boot/bootstatus后恢复剩余两作业，已通过项不覆盖。测试期间生产/测试源码身份保持一致。

目视：标准手机/SE八个圆盘完整同时可见、色序一致，紧凑独立触点无重叠；两种外观均使用同源深色菜单；球库15槽、切角与八档数量、时间电量FPS完整；四相机按钮在杆速尺左侧并沿实际外框中心对齐。iPad横竖2D保持桌比与六袋，3D使用每日生产取景；AD01共享抽取后标题/读数/四按钮/空态/旋转回归通过。

本轮实测台面拖球与点击球库加减；跨区拖入拖回代码保留但未单独做全流程实测。快速手势、最低Runtime、最大辅助字号、VoiceOver和真机手感/温升不作已通过声明。紧凑八档按用户指令覆盖此前44pt高行+滚动方案；并未把本页触点裁定推广为全App要求。

[最终原生图册](../../output/table-page-adaptation/P08a/r01/index.html)。下一步为本页体验反馈。


2026-10-08 / r02最终复验：标题共用AD01、上方仅切角、计数置于八档下方、显示进球线及角标不显示线名；修复FL-136投影缓存错位。构建/21单测/4次UI通过，手机/SE/iPad主要2D图与AD01原图已实际对照，初始错位消除。证据output/table-page-adaptation/P08a/r02/final；未装真机、待用户视觉体验；用户指示优先提交push。


## r03 · 临时俯视标注补齐（2026-10-08）

复审r02临时俯视图发现台面缺少数值，左侧切角不能替代台面标注。临时正交SCNView复制了主场景隐藏的SCNText，却没有自己的DiagramLabelOverlay。本轮共用同一标注组件，以临时层自身相机投影；退出时恢复主视图标签，反复进入创建新实例，不改相机/物理。AD01仍保留线名，图谱仅角度数值。

构建、22项定向单测及4次原生UI执行全部通过（标准手机图谱、AD01、SE图谱、iPad图谱横竖）。新增检查临时投影端点、11pt字体、数字和角弧可见、反复进出、主相机姿态及源场景弧线不变；gate/doc-size/diff通过。已逐图对照手机/SE/iPad临时俯视和AD01，并检查手机2D/3D/拖球及iPad横竖图。iPad固定屏幕半径角弧与目标球局部重叠仍是既有共同样式，本轮没有重新设计，不能据此宣称所有视觉细节完美。

[新版原生图册](../../output/table-page-adaptation/P08a/r03/index.html)，原始日志/截图/矩阵/源码及App哈希在r03/final。r02已推送main（2cd43617）；r03未提交、未安装真机，待用户体验。
