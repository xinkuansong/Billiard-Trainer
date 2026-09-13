# W12 — 自由走位 / 编排编辑与观看往返

状态：✅ 本地批次验收，见[W12验收](W12-acceptance.md)。以下保留原始推进与失败记录。

## 入口接入前的检查记录

- 当前PositionPlayComposerView同源承载试打和自由走位。cameraToggle仍被isTryout限定；3D观察栏/透视布局/禁球体拖拽已经共用，可复用W10的已验收能力。
- 已有自由走位能力：录制、重打、序列命名、清空确认、球库、选球/选袋；不得为了统一新增编辑功能。待按实页核对保存和返回的既有语义。
- 场景3D的onTableTapped/onAimNudged为nil且draggableBallNodes为空；球/袋选择仍作为既有击球设置存在，需区分“选择击球目标”和“移动/新增球体”，不能误删现有选择能力。
- cameraToggle当前identifier为tryout.cameraMode，观察栏prefix同为tryout；接入自由走位时按页面变体命名标识，保持试打测试标识兼容。
- 下一步：先实际进入自由走位留基线；开放已有2D/3D入口，验证摆球/选球/目标区/保存命名/撤销返回的真实范围；2D编辑→3D观察→2D核对草稿不丢。W12尚未验收。

## 当前证据
- baseline-r1/session10038终态0；原图B0C589EA已核，2D默认3球、球库、右操作列。当前代码开放cameraToggle并分composer/tryout标识。
- roundtrip-compact-r1/session3711终态2：原相机不变量3.936s通过；实页44.755s通过，改名→自由→3D→旋转观察→2D→回读名称一致。4张改前/3D/旋转/返回原图均已直接查看，标题/球位/菜单入口清楚。
- 同批新录制测试54.334s失败因缺运行SCNView，击球动作无法推进且viewport未设；不是App卡死证据。补实际UIWindow/SCNView后recorded-draft-r2/session76677终态0，14.775s通过；录制一杆后3次往返，排序JSON比较完整序列与球形，选球/袋、isRecording及stop返回均保持。
- 源码补核：页面没有startRecording/stopRecording调用，也没有目标区编辑；ViewModel保留录制，测试只在模型结束，不写生产内容文件。重命名保存为当前内存序列名；不冒充持久保存。
- roundtrip-gate/session29245终态0。下一步：真实摆球/选球选袋/击球重打与返回，标准/iPad回归，既有保存能力范围核对。完整W12仍进行中。

## 击球与摆球复核

- `shot-roundtrip-standard-r1.log/xcresult`：实际编辑并选球/选袋后的相机不变量14.080s通过；标准实页改名、3D观察、击球、重打、返回2D与名称回读58.030s通过。前轮已查看观察/停稳/重打/返回四张原图。
- `ipad-editing-r1.log/xcresult`：同一完整击球往返59.173s通过；观察/重打/返回原图已核。球库用例33.575s自动化通过，但视觉不通过：`CD9DA955-EFED-4C8B-8FF6-3A8DB545F184.png` 中9号仍在桌上，1号已回球库，不能将按钮和导航断言当作正确球体移除的证明。
- 测试根因假设：原窗口归一化(0.45,0.42)靠近默认1号，防重叠摆放调整9号位置后，原点拾取了1号。只调整该新增用例到已查看台面上的空白区域(0.35,0.30)，保留全部原步骤和失败原图；修正版必须核对9号与1号身份。
- `ipad-placement-r2`/session10991终态0，1测试34.259s；三张摆放/返回/移除原图直接查看。摆放与返回保持9号、1号身份；移除图FCDE6E47显示9号停在下库边、球库仍暗，视觉仍不通过。`AngleSceneView.dragSamplePoint`保留52pt死区及越界首样本锁定偏移，快速长拖可能放大偏移；下一轮仅用XCTest慢速拖动复核，未修改生产手势规则。
- `ipad-placement-r3`/session54281终态0，1测试35.814s；移除原图77D4A638仍显示9号停在下库边。慢速拖动没有解决，不能确认“自动化速度过快”根因；需继续核对结束坐标、球库区域和手指偏移。已补“已移回球库”实际反馈断言，补后未运行；球号仍须原图确认，不能靠反馈替代。
- 当前无运行句柄。本轮未修改生产逻辑；W12完整验收仍未完成，下一步定位拖回球库的结束坐标契约，随后补剩余编辑与尺寸验收。

DR-256仅接受已列明的本地范围。

## DR-257 — 拖回球库坐标修复

- 临时坐标诊断r1构建失败（Swift已替换NSStringFromCGPoint等函数），修正后r2/session52554终态0，36.758s。原输出保留；临时诊断代码已移除。
- r2坐标日志显示手指local y=951、偏移后885.5、scene origin y=46、palette minY=928，原命中余量仅3.5pt；该轮恰好移除成功，不将其说成稳定失败。r2/r3此前视觉失败说明入口对偏移敏感。
- AngleSceneView.onDragEndedAt改为手指松开位置，台面onDragMoved偏移不动。已检索全部消费者，均为球库接收；不增加新删除入口。
- `ipad-drop-fix-r1`/session20308终态0，1测试35.252s。返回2D原图E7DDBA8E及移除原图A60BAEEB已直接查看：9号消失、球库9号恢复亮态，默认1/2/母球保留。含实际移除反馈断言。
- `compact-drop-fix-r1`/session78381终态0，1测试34.395s；返回原图8D651434、移除原图DCF5EC12直接查看，9号移除且1/2/母球保留。`drop-fix-gate`/session10282终态0；git diff --check、verify-doc-size通过。DR-257本地两尺寸修复通过，其他共享页面随后续批次回归；完整W12保持未完成。
- 当前无运行句柄。下一步补实际选球/选袋、清空/重来与返回的页面流程，再逐项核对W12 DoD。

## 编辑生命周期补验

- 新增实页步骤：点击新摆9号选中，往返3D/2D后移除；3D清空、2D核对空桌；取消重来保持空桌，确认重来恢复默认，返回首页。
- `ipad-edit-lifecycle-r1`/session99134终态2，49.188s，两失败均为找不到取消按钮。录屏46s与AX树确认iPad使用系统PopoverDismissRegion取消，无独立取消按钮；不是无法取消的产品证据。测试改为优先实际外侧关闭区域，手机保留取消按钮。
- r1选球CF2827C1与返回035C86C6原图已核：9号成为当前瞄准目标、上右袋高亮，往返后保留。3D清空2572D05C原图为空桌；未将求解中截图当作物理预测结果验收。
- `ipad-edit-lifecycle-r2`/session7665终态0，54.391s；取消原图5A822C39保持空桌，确认原图31E8FF60恢复默认三球。compact-edit-lifecycle-r1/session82094终态0，52.650s；默认图87745BAC已核。
- 两尺寸空桌截图仍有旧11°，因此未立即关闭W12；DR-258在clearTable清空cutAngleDeg，新增实页—°断言。compact-edit-lifecycle-r2/session71463复验中；edit-lifecycle-gate/session4966运行中。

最终补充：compact-edit-lifecycle-r2/session71463终态0，52.481s；空桌3D/2D与默认恢复三张原图已核，旧角度消失。edit-lifecycle-gate/session4966终态0。W12本地完成，真机/平台全矩阵留W16；当前无运行句柄。下一批W13三页规划交互，W07–W10兼容/性能缺口继续保留。
