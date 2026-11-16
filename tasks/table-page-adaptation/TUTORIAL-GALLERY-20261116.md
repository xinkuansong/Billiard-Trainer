# 精讲图集左右翻页恢复（2026-11-16）

用户要求：实际复现、确认原因后修复，恢复点击精讲图片后左右切图，同时保留缩放和下滑关闭。

状态：✅ 原版缺陷与手势单变量对照已实证；正式修复完成，iPhone／iPad六个设备×用例组合分轮通过。未做真机或全App验收。

## 范围与现行交互

截图对应 `drill_c011`「近台小角度进球」，首张 `drill_c011_initial`，共六图。正式路径：动作详情 → 查看精讲 → 点击配图 → 全屏图集。当前 `TutorialMediaViewer` 仍使用 `.page` TabView；`ZoomableContainer` 的全方向 DragGesture 在回调内判断是否处理横移/纵移。

本轮只修图集手势；不修改内容、球形、素材、布局、会员权限或教学信息。原尺寸横滑翻页；双击/捏合缩放；放大后拖动观察；缩回原尺寸恢复翻页；向下拖动超过既有120pt关闭，短拖动回弹；关闭按钮保持。

## 局部 TP 判定

|条款|判定及本轮范围|
|---|---|
|TP01|继承真实详情→精讲→配图入口、点击图索引与返回位置。|
|TP02/03|继承现有静态图比例和阅读方向，不套交互球桌横屏模板。|
|TP18|按阅读业务调整：图片平移与父级分页必须在识别开始时仲裁；无移球能力。|
|TP29/30|继承本地图集、媒体和页面生命周期；不改变资源加载。|
|TP35|功能实测、原图审查、真机/用户复验分别列证据。|

此为既有精讲局部交互修复；其余训练能力未涉及，不启动整页迁移或全App设备矩阵。

## 验证计划

1. iPhone16Pro / iOS26.2，同一构建同一六张图，原路径横滑与禁用内层拖动对照；各自截图。
2. 修复后六图向前向后、边界、点开非首图、重入、双击与捏合、放大后横纵移动、缩回后翻页、短下滑回弹、上滑不关闭、下滑关闭和关闭按钮。
3. iPad代表同合同复验；原图检查首图、次图、末图、放大和平移。
4. 冻结源码、选择器、xcresult摘要、截图及原始日志；回传校验后关闭本轮临时资源。

诊断脚本：`scripts/research/tutorial_gallery_20261116/`。诊断快照：`6e84273f758210dd4e3a0017be85f4295bc2ffc0e9cccd43bc7b795ea4a0cceb`；job：`tutorial-gallery-20261116-diagnosis-r1`。只在隔离副本注入禁用手势开关；生产App不加入诊断开关。

## 原始失败（不计功能复现）

R1 完整App构建通过、进入正确精讲页，但 `app.buttons["tutorialPoster_drill_c011_initial"]` 未解析到目标，脚本滚到页尾后断言失败；尚未横滑，不能算翻页缺陷的失败证据。原件见 `output/tutorial-gallery-20261116/diagnosis-r1`。R2 增加实际AX树诊断，按本图唯一图注的可见frame定位上方图片，仍断言打开后为1/6；不改变App导航或分页逻辑。R1准备工作目录已由生命周期关闭，释放约1.46GiB。

## 根因实证与修复

R2 iPhone16Pro/iOS26.2，实际详情→精讲→同一首图。原版中央横滑两次仍1/6；同一安装包用诊断参数仅将内部DragGesture的mask改为none，中央横滑一次为2/6。`TutorialGalleryDiagnosisUITests/testOriginalAndWithoutInnerDrag`通过（46.225s）；这里的通过表示反例与对照均符合诊断假设，不表示原App通过功能验收。原图已打开核对，分别显示用户同款1/6初始图和2/6下一杆配图。证据：`output/tutorial-gallery-20261116/diagnosis-r2`、`diagnosis-shots`。

已确认机制：内层全方向SwiftUI DragGesture在onChanged里忽略横向位移，仍已取得手势识别，外层TabView无法翻页。是否由某次系统升级／重新编译首次触发没有历史运行对照，不将iOS版本变化断言为已证明的时间原因。

正式修复：以透明UIKit pan表面替换内层DragGesture；未放大时只接受向下且纵向占优的手势，横向／上滑在shouldBegin即失败；祖先UIScrollView pan显式等待此判定。放大后接受图片平移，单指pan与现有捏合／双击缩放共存。位移在window坐标读取；取消回弹；120pt关闭阈值不变，向上不再误关闭。关闭按钮补语义标签，媒体暴露真实缩放百分比。调用方只包括精讲静态图与无控件循环视频；当前内容无clip字段，本轮真实媒体回归以静态图为准。

R1脚本定位原因由R2真实AX树补证：父section的accessibilityIdentifier传播到子节点，未暴露预期tutorialPoster标识。正式回归按图注可见frame定位图像，不修改生产AX结构来迎合原错误查询。

## 修复回归证据

正式修复快照 `8a9eb97ba41f350ec9ea3b716c216ec555c076157080cb849ab8381a00c4dcb5`，隔离scheme仅移除不相关单元测试target，App源码与工作区一致。iPhone16Pro/iOS26.2 phone-r1：3项中2项通过；六图双向翻页/首尾边界/关闭后点开第二图通过（43.802s），短下拉回弹/上滑保持/下滑关闭/关闭按钮通过（22.113s）。缩放用例双击250%、横纵平移仍1/6、双击回100%再翻页、捏合放大均已执行，末段一次合成向内捏合只到109%，严格100%断言失败（32.019s）。这不是功能通过；原件与失败录像保留于 `output/tutorial-gallery-20261116/phone-r1`，摘要和导出附件在 `phone-r1-analysis`。

修正自动化：按实际缩放读数至多继续向内捏合3次，每次必须下降，仍必须到100%才能执行翻页和关闭断言；未放宽产品阈值、未修改生产修复。新测试快照 `97652ea2fce800a4316e45453c1452a3a69f1f5a50d8ca095482ae6e5950d238`，phone-r2只补跑原失败用例。

`swiftc -frontend -parse`及`git diff --check`通过，实际App/UITest已在Mac mini Xcode26.2完整构建。`verify-doc-size`通过。`verify-gate`已执行但被本任务之外的测试写盘登记漂移拦截：`extra=['QiuJiTests/ModelAssetTrialTests.swift']`；此前内容/同步/文案检查通过，不将整体门禁记为通过。日志位于 `output/tutorial-gallery-20261116/verify-gate.log`。

原始xcresult由远端回传校验，分析前先在受管临时目录clone，再用本机较新xcresulttool读取，避免工具升级数据库导致原件hash改变。诊断r2首次读取的转换副本保留为 `diagnosis-r2-readable`；重新回传的 `diagnosis-r2` 为校验原件。


iPad Pro11 M4/iOS26.2 pad-r1：六图双向/边界/非首图打开通过（55.509s），短下拉/上滑/下滑关闭/重入/按钮通过（24.620s）；缩放最后一次向内捏合停在121%，同一严格断言失败（33.949s）。同上测试修正后仅补跑缩放用例pad-r2，未修改生产代码。r1原件和分析分别为 `pad-r1` / `pad-r1-analysis`。

生产文件SHA256 `59515ac7c8f2408aa132e38900b55757252216dab12f1ffc60f7f036886bb7e3`，与r1、r2冻结快照均一致；测试文件仅修正缩小手势循环，当前SHA与r2一致，见 `output/tutorial-gallery-20261116/source-parity.json`。

phone-r2完整缩放序列通过（36.333s，1/1）：250%双击、横纵平移、双击回100%、下一图、捏合放大与连续缩回100%、返回上一图、下滑返回精讲。实际原图确认缩回后的首图完整、与初始图一致；证据 `phone-r2` / `phone-r2-analysis`。

pad-r2完整缩放序列通过（37.749s，1/1），与手机相同的严格100%缩回→翻页→下滑关闭。最终为两个设备各3项、共6个设备×用例组合分轮通过；不是单轮全绿，r1原始失败均保留。生产代码在这四轮回归中一致。

## 交付范围

修复与3项正式UI回归已落入工作区。已验证iPhone16Pro和iPad Pro11 M4、iOS26.2、竖屏、真实c011六张图；原版诊断与最终结果各自留证。[原图审查](../ui-reviews/UR-20261116-tutorial-gallery.md)。不代表真机、旧系统、全App、视频/VoiceOver或iPad横屏/分屏通过。未提交或推送代码。

六轮任务的临时模拟器均由管理器回收，最终逐一核对不存在，见 `output/tutorial-gallery-20261116/simulator-final.json`。本地快照/分析工作目录均通过local_test_lifecycle回收，源码清单及证据保留。

北京时间2026-11-16 18:16，六个远端job均完成回传校验和complete收尾，临时source/build及无引用snapshot回收，失败job状态仍保持failed。各目录`cleanup-response.json`留存记录。必要原始xcresult、源码清单、截图和失败录像保留。
