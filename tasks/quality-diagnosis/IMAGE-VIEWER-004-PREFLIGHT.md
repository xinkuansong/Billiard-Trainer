# SC02/17/18 图片查看器最小预飞

2026-09-08。只读源与原件索引核查；仅新增本文件，没有构建/注册/执行/设备操作。建议只选**一个正常入口 c001 半台直线球 → 精讲 → 第一张配图**，取得全屏放大、下一图、关闭返回证据。不要重跑 c042/QD029。

## 模型和范围

真实实现集中在 `QiuJi/Features/DrillLibrary/Views/DrillTutorialView.swift`：

- 精讲旧单球形`sections`和多球形`formations`统一成ResolvedFormation；viewer图集只取**当前球形**sections中图片能够加载的项，按section顺序排列。不跨球形翻页。
- 一个球形可以含多张图，因此“单球形”不等于“单图查看器”。c001只有一个球形，但有6张静态图，适合同时观察正常打开、缩放、分页、返回。
- `TutorialMediaViewer`用TabView分页，items>1显示`n / N`，单图不显示页数。每页有各自ZoomableContainer和caption；静态图scaledToFit，有可加载clip则循环视频。本次六项没有clip，不扩视频/音频。
- 双击scale1→2.5，再双击复位；捏合限制1...4，放大后拖动平移。scale1的水平拖动留给TabView，纵向超过120点可关闭；关闭按钮Image(xmark.circle.fill)没有显式AX identifier/label。本次只要求**双击放大→复位→横向下一图→关闭**，不同时扩捏合上限、平移、下滑关闭和单图边界。
- 原SC02入口、SC17精讲、SC18详情相关的图片查看器缺口合并此一链，不把一个图集拓成设备/球形/手势全矩阵。c042多形滚动卡顿仍引用QD029，不能为查看器重复该失败链。

## 当前素材与冻结004一致

当前工作树与 `archive/quality-diagnosis/snapshot-004/source/` 下对应源/JSON/6张HEIC逐字节相同：

| 文件（相对QiuJi） | SHA256 |
|---|---|
| Features/DrillLibrary/Views/DrillTutorialView.swift | cae85895741dbce43938bc8d582540da7c6ab656a88f11665cfd624b3a75ec6a |
| Resources/Drills/fundamentals/drill_c001.json | 8cca5623bdadbf8ee1eb30a5547bee250e2a204a1284805645198bc51216b0ac |
| Resources/TutorialFigures/drill_c001_initial.heic | 47bd355a0ee096b277ff508d19d8bcfc8ea7a4f406a98190532a8e0b3c628802 |
| Resources/TutorialFigures/drill_c001_s01.heic | cb831f38241b82f24acaa90ffd54952277e101f4cfa63d0cc98d08272bd0acff |
| Resources/TutorialFigures/drill_c001_s02.heic | 694c3026500c21bf7c904580022e2c8362050091417c788823fb5d0c9001a75f |
| Resources/TutorialFigures/drill_c001_s03.heic | a133b074c7c932e362cbebbc4f7660f9bffdb92d813249e9b1fa9109f944e297 |
| Resources/TutorialFigures/drill_c001_s04.heic | 04c288b89b7041069669182b7161edb77ce8277ba576567ea498352da357012e |
| Resources/TutorialFigures/drill_c001_s05.heic | a9ad882e3cf969c9e4a57effcfa1a592d46b328fa1393d9f6f772dc40a4f539a |

JSON顺序initial、s01、s02、s03、s04、s05，isPremium=false，无formations，无clip。第一caption字面为「开局：五个独立摆位，目标球依次进入左下角袋」，第二为「第1杆：约 4°」。源文件存在和哈希相等不等于本次实际Bundle能解码；运行必须实见6项页数和对应图像，若少于6，保留缺图/加载问题，不能改预期N追绿。

## 已有测试与可复用原件

- 已读 frozen004 `QiuJiUITests/V49W1CopyEvidenceUITests.swift` 的c001/c012选择器和captureTutorial实现。`testW1_Light_02_C001Tutorial`、Dark及SmallLight变体以deeplink直接详情，打开「查看精讲」后核文案、滚动截图；没有点poster进入viewer，没有双击/翻页/关闭。不能作为本次正常入口或查看器手势已通过的证据；此处不声称旧执行原件齐全。
- 当前 `tasks/quality-diagnosis/DetailJourneyDiagnosticUITests.swift` c042精讲方法只核球形与图片/段落位置，未验证viewer；其QD029失败不需要再跑。
- `archive/quality-diagnosis/runs/formal-004-m1-light-roots-detail-001/` 与dark对应run内 `tested-sources/QiuJiUITests/QualityDiagnosticUITests.swift` 可复用正常动作库搜索/详情入口证据，但其c012详情不等于c001图库实测。
- `B6-COVERAGE-AUDIT-004.md` SC02/SC18明确查看器仍缺；在snapshot004现有UI测试中定向查viewer/pinch/doubleTap没有发现对应查看器手势方法，不能把包含“放大”的其他教学文案测试当查看器测试。未做全仓库全历史证明，因此结论限当前已核测试域。

## 一条正常链及硬验收

新专用guest iPhone，主控严格设备匹配、正常单次launch/foreground、全新输出目录。正常底部动作库入口→`librarySearchField`搜索「半台直线球」→唯一`drillCard_drill_c001`→详情「查看精讲」→实际`Button tutorialPoster_drill_c001_initial`。不使用deep link、预览/图集注入/Pro强制，不创建资产。必要上滚仅限露出第一张图；frame必须在真实ScrollView/window/nav/TabBar可视交集，不能点section卡片冒充图片按钮。

推荐证据阶段和判据：

1. `tutorial-before-open`：第一poster完整可见，记录其frame、caption、页面标题；正常点击poster一次。
2. `viewer-initial`：实际全屏黑底图像、第一caption、`1 / 6`（精确实际AX需观察），图中内容与initial原件一致；不能只凭caption仍存在证明已进入fullScreenCover。
3. `viewer-zoomed`：根据当次实际图片节点/媒体框中心双击，保存前后PNG/AX及连续视频。必须由图审比较同一图形地标距离/裁切确认确实放大，不能用画面hash变化、页码未变或XCTest动作返回当缩放成功；scale私有且没AX值，自动层不能直接证明2.5倍。
4. 再双击复位，图审确认恢复适配画面；仅复位后在实际媒体区域水平滑一次。`viewer-next`必须页码`2 / 6`、第二caption「第1杆：约 4°」且实际s01图替换initial。仅换页码不代表图已切换，须对照PNG。放大状态横拖属于平移，不能误认翻页。
5. 使用本次实际AX观察到的关闭按钮正常关闭一次；`tutorial-returned`必须fullScreenCover消失、回精讲原poster与caption，比较打开前后位置且不补滚动造返回。若只能确认语义返回，滚动偏移保持未核则明确写界限；不扩大为c042多形回F1要求。

所有读文字用实际可见frame和唯一有效节点，不能仅exists命中隐藏TabView邻页；操作节点要求enabled/hittable。失败PNG先保存，再AX；连续视频、运行源/参数/截图附件均由主控归档。无任何新的延迟/FPS阈值。

## 为什么现在不写“全链通过”脚本

当前有源identifier可安全写**打开到观察**的脚本，但没有此viewer的实际AX原件，三个具体信息不能猜：全屏媒体可操作节点/边界；页码与caption在TabView中的可见节点集合；关闭按钮实际AX名称（不能根据SF Symbol猜必为「关闭」或identifier=xmark.circle.fill）。另外zoom没有可读scale，即使脚本绿，视觉缩放也必须外部验收。

因此本次不新增诊断Swift；建议主控下一次仅通过已知正常入口打开viewer，保存完整PNG/AX后结束观察（正常退出可由后续已知节点或测试进程结束，不给未知按钮造selector）。拿到该**一次真实观察**即可在同一有限合同下补全上述双击/复位/翻页/关闭方法。若要求先交观察草稿，应明确方法名含Observation，状态仅“取得查看器节点”，不计SC完成。没有新节点证据前，不应重复不同猜测关闭按钮、盲目pinch或坐标滑动。

单图无页码、动态clip播放、捏合最大倍率、任意多球形跨图集等未纳入本次一链，按原场景必要子要求处理，不自行增加无限组合；此代表入口不宣称这些全通过。

## 观察草稿主控复审修正（2026-09-08）

后续已按主控授权新增 `ImageViewerObservationDiagnosticUITests.swift`，只正常打开c001初图并采集PNG/AX；不是上述完整手势验收。设备UUID仍是硬拒绝占位符，未注册/运行。原“本次不新增Swift”描述的是初次预飞交付时点，以此补充为最新。

纠正初稿每页强要求TabBar的测试错误：`DrillDetailView.swift:135`明确隐藏tabBar。现`bounds(page:)`区分library/detail/tutorial：库必须真实可用TabBar；详情/精讲必须真实navigationBar，不能要求隐藏TabBar存在。所有页面都使用实际ScrollView/window/导航交集；详情/精讲底部采用**44pt保守排除带**，是主控基于17Pro 402×874归档画面批准的安全点击边界，**不是声称实测safeAreaInsets=44**。不新增外部safe-inset参数或授权。代码硬验窗口402×874；不同设备应重新审核，不能套用。

只读证据：`archive/quality-diagnosis/runs/formal-004-c042-tutorial-003/screenshots/`下`detail--[DetailJourneyDiagnosticUITests testC042TutorialTwoFormationsKeepDistinctPostersAndReadingPosition]-detail-68FB99EF-C280-46F0-8E70-6AF0197292C3.txt`中主window402×874、NavigationBar y62/h54、ScrollView覆盖全窗、无TabBar；guest-free-before同run有TabBar y791/h83。teardown同run中NavigationBar下嵌套Other里的真实StaticText label为「精讲」（第20行），所以`application.navigationBars.staticTexts["精讲"].firstMatch`有实际AX依据；不能按NavigationBar identifier猜为精讲。本次仅读既有AX，不再次执行c042。

根页详情补充原图来源：`formal-004-m1-light-roots-detail-001/screenshots/library-detail.png`及`library-detail-after-3s.png`；该run截图目录没有旁置详情AX文本，不能声称它提供了不存在的AX。具体无TabBar的结构证据由上述当前004详情AX提供。

poster仍要求完整frame位于最终交集内。若其高/宽超过保守可视区，立即硬失败并留图，不能无限reveal、缩小目标为中心点或假称全图可见；其余滚动最多6次，方向按实际frame决定。最终语法parse通过，仍待主控类型编译/运行。无生产、快照或共享台账更改。


2026-09-08 查看器观察001失败24.663秒，runner2/recorder0，1427文件及6观察文件归档。主控完整终态图和AX：正常库搜索c001成功；三个ScrollView分别等级(0,130,402,44)、分类栏(0,182,76,692)、结果列表(76,182,326,692)，目标卡完整可见(88,260,145,146)。脚本要求全页唯一ScrollView失配，尚未点卡/配图，不记产品缺陷。002仅以包含唯一drillCard_drill_c001的实际ScrollView定位，保留完整可视边界。001原tested-source保留。


查看器观察003终态1/1通过36.923秒，runner0/recorder0，82文件及6观察文件归档；主控两张完整PNG/AX已审：初始六球图、全屏1/6、caption与原图一致。真实关闭按钮xmark.circle.fill/关闭，CollectionView单cell媒体框(0,68.3,402,715)。前两次测试定位失败保留；本方法只取得节点，不算缩放/切图/关闭通过。gesture001在此实证上补一条正常链。
