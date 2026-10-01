# 每日清台球库居中 — DR-335

日期：2026-09-28。范围：每日清台的2D/3D共用顶栏与左右控件列。

## 实现

- 原先母球和15颗目标球一同居中，8号偏右；48/52pt侧栏又使球桌中心偏左2pt。
- 母球拆为左侧独立胶囊，目标球行居中，右侧等宽透明占位。中八1～7｜8｜9～15对称；9/6/5/4球按玩法实际目标球集合居中，偶数颗以中央间隙对齐。
- 进袋球暗显并保留槽位，合法高亮、选球规则、禁用条件保持；左右控件列统一52pt。顶栏仍44pt。
- 3D按HUD中线居中，观察相机自由移动时不追随袋口投影。

## 功能验证

构建通过。标准iPhone（iOS26.3）与紧凑iPhone SE（iOS17.0）各2项UI、0失败：

1. `testGroupedPaletteStatesRemainCenteredInBothModes`：中八全色/花色/黑8/未分组，双模式高亮与点选；黑8及左右球对中心不变量。
2. `testInteractionHUDPaletteAndTwoActionChoice`：中八和9/6/5/4球，双模式球号集合、单行、中心和不重叠，重开确认/继续流程。

断言精度：目标球镜像对的中点、舞台中心与页面中心误差不超过0.5pt；母球与第一颗目标球分开，球库不越过返回/视角按钮。全仓verify-gate与verify-doc-size通过。

日志：`build/daily-palette-center-20260928/{standard,compact}/test.log`；截图同目录。未进行真机、iPad、最大辅助字号或完整物理球局验收，未发布。

## 视觉复核

标准与紧凑中八整页已目视：8号对准上下中袋，母球独立且不遮挡标题，双组对称。五玩法球库尺寸随目标球数量自然收窄，固定位置不随进袋跳动。

首轮部分追分2D截图外围文字未完整绘制，不能作为整页视觉通过证据；保留初始图片并补拍稳定画面。CLI补拍首次过早采到白色启动页，已保留，不作为有效证据。稳定画面已补拍并目视，标题/方向/力度/视角/击球按钮完整，无球库遮挡。首轮截图问题未复现在稳定画面，不据此修改生产渲染。CLI原图按设备方向保存，查看时需横向旋转。


有效截图索引（根目录 `build/daily-palette-center-20260928/`）：

| 设备 | 中八 | 9球 | 6球 | 5球 | 4球 |
|---|---|---|---|---|---|
| standard | palette-selection-2d.png | interaction-nineBall-2d.png | settled-sixBall-2d.png | settled-fiveBall-2d.png | interaction-fourBall-2d.png |
| compact | palette-selection-2d.png | settled-nineBall-2d.png | settled-sixBall-final-2d.png | interaction-fiveBall-2d.png | interaction-fourBall-2d.png |

3D：`standard/palette-selection-3d.png`、`standard/interaction-sixBall-3d.png`、`standard/interaction-fiveBall-3d.png`与`compact/interaction-sixBall-3d.png`已目视，球库保持HUD中心。截图中现有Debug FPS浮标与本改动无关。

结论：本次目标布局与功能回归通过，等待用户视觉确认。代表图：

![中八8号对准中袋](../../build/daily-palette-center-20260928/standard/palette-selection-2d.png)

![四球追分目标球组居中](../../build/daily-palette-center-20260928/compact/interaction-fourBall-2d.png)

## 同日细调：端部高亮、右上留位与击球按钮

- 球库首尾的合法目标底色采用16pt圆角，内侧槽位保留4pt圆角；选中白环和44pt点击区域保持，不裁切交互。
- 按用户补充要求，球库保持第一版大小与位置（112/148pt顶栏翼宽、最大24pt球径）。仅右上视角/更多按钮尾部对齐，并利用右侧安全区最多右移24pt。FPS移到按钮组左侧，按用户最新反馈使用10pt低对比度纯文字、不带胶囊，静止时显示“静止”；其他球桌页不改变FPS默认布局。
- 击球按钮由52pt增至60pt，在力度仪表下方剩余空间居中；左右操作列同步60pt以维持舞台中心，2D按钮与舞台相隔至少4pt。
- 首轮过宽FPS预留使球库缩小，已按用户意见撤销。中间版截图和测试保留在`r2/`、`r3/`，球库/击球几何在`r4/`完成双尺寸五玩法回归，后续右上交互与纯文字FPS另行复验。
- 新增的FPS独立AX元素断言不适用于现有SCNView整表合并可访问性：FPS描述属于`table.scene`。已移除该错误断言，FPS位置以原始截图目视检查；球库镜像、击球按钮60pt/余区中心/不进入2D舞台仍由自动断言验证。

右移后的菜单补测保留了r4至r7失败现场；检查AX树发现外层装饰被标为按钮、内部原生Menu另有真实按钮。标识移到共享菜单已有的accessibilityId入口，避免把外层框当成操作目标。右上真实布局容器一并扩展，舞台单独锁定原有安全区宽度。菜单点击修复后已走通换玩法与放弃确认；旧用例仍检查非横屏分支的breakStatus，现以确认后固定1～9号球、无10～15号球验证真实玩法切换，未移除确认流程。最终确认：iOS17在玩法sheet退场期间直接弹确认会漏显示，改为sheet的onDismiss接续所选玩法；保留放弃确认和取消语义。生产路由不变，已登记路由状态与FreePlayView签名。


### 最终证据

根目录`build/daily-palette-center-20260928/final/`：

- `standard/test.log`：3项UI、0失败，五玩法2D/3D＋中八四状态＋菜单流程。
- `compact/test.log`：两项布局/玩法UI通过；菜单的iOS17确认退场问题在此留下原失败。
- `menu-compact/test.log`、`menu-standard/test.log`：时序修复后各1项通过，实际点开右移后的菜单、打开玩法面板、选择9球、确认放弃并验证1～9球/无10～15球。
- `gate-final.log`、`doc-size.log`、`git diff --check`通过。共享工作区另有调节/渲染任务变更，未回退或纳入本次布局结论。
- 两尺寸原图均目视：首尾圆弧不外溢（右端9号另见`r4/standard/right-edge-final-2d.png`）；中八8号与中袋中心相同；纯文字FPS在球库和右上按钮之间，小屏无胶囊边缘相碰；2D击球圆按钮与舞台分离。3D仍为可移动场景上的HUD，不承诺所有自由相机姿态下与球桌投影分离。
- 未进行真机、iPad、最大辅助字号或完整物理球局验收，未提交发布。

![最终2D布局](../../build/daily-palette-center-20260928/final/standard/palette-selection-2d.png)

![最终纯文字FPS](../../build/daily-palette-center-20260928/final/standard/palette-selection-3d.png)

## 球径恢复与FPS位置二次修正

前次声称“保持原大小”不准确：只恢复了112/148pt翼宽，母球镜像占位仍参与缩放，导致标准球径22.24pt、SE21.59pt。对照HEAD原始公式与初始截图，原球径为24pt。本次沿用原球径算法，再拓宽居中容器，中八容器484pt、目标球行408pt；目标行中心仍固定。新增球槽26pt（24pt球面＋2pt选中圈空间）断言覆盖全部玩法与两种模式。FPS纯文字下移到按钮下方、打点盘左边；标题背景在内容外绘制，不再填满翼宽。验证完成，证据目录`build/daily-palette-size-20260928/`。

标准屏与SE原图均已目视：球面恢复24pt，8号对准中袋；FPS与打点盘同高且位于其左侧，标题完整、外框紧贴内容。代表图：

![恢复球径与FPS下移](../../build/daily-palette-size-20260928/standard/palette-selection-3d.png)

![SE小屏](../../build/daily-palette-size-20260928/compact/palette-selection-3d.png)

二次修正验证：standard/test.log与compact/test.log均2项UI测试、0失败，覆盖中八四状态与五玩法双模式、球径/居中/击球区域断言；gate与doc-size通过，diff检查通过。未做真机/iPad验收。

用户继续要求FPS上移：仅每日页读数中心距安全区顶部74pt改为62pt（上移12pt），靠近视角按钮下沿。水平位置与纯文字样式不变。本次仅静态差异检查，未重跑模拟器，以上截图对应上移前。

## 按视觉反馈进一步放大

用户认为24pt仍小，本轮不再以恢复旧值作为视觉完成标准：标准安全区宽度≥740pt的球面改为28pt（直径增加16.7%，数字同步缩放），SE窄屏保留24pt以保证完整标题与按钮间距。母球及各追分玩法采用同一档球径，中八目标行仍以8号居中。前次FPS上移12pt一并进入本轮截图。证据目录`build/daily-palette-larger-20260928/standard/`：2项UI测试0失败，覆盖中八四状态、五玩法双模式与放大后的球径/居中/间距断言；标准屏截图已目视，FPS上移位置已确认。gate、doc-size与diff检查通过。SE布局数值不变，本轮未重跑SE。

![28pt球库与上移的FPS](../../build/daily-palette-larger-20260928/standard/palette-selection-3d.png)

用户追加标题间距细调：返回箭头与“每日清台”的HStack间距从0改为-6pt，让文字利用箭头44pt点击框右侧留白；返回按钮点击框仍44×44pt，球库与右侧控件位置不变。本次静态差异检查通过，未重拍，以上截图为间距调整前。

## 标题位置与球库继续细调（需截图验收）

返回箭头与标题的布局间距进一步改为-12pt，标题组标准屏左移12pt、窄屏左移2pt并下移3pt；背景胶囊高度从44pt收至34pt，保留返回44pt点击框。球库标准屏30pt、窄屏25pt，数字与母球同步放大，8号与追分集合中心保持。新证据目录`build/daily-header-tight-20260928/`，验证完成。

截图复核：首轮发现标题可用宽度被外层压缩，改为显式分配包含左移空间的宽度，最终标准屏图保存在`final-standard/`。标准屏与SE的2D/3D图均已目视：标题完整且间距收紧、向左下移动，球库增大，8号中线及两端高亮保持，未见与模式按钮重叠。

![最终标准屏](../../build/daily-header-tight-20260928/final-standard/palette-selection-3d.png)

![最终SE](../../build/daily-header-tight-20260928/compact/palette-selection-3d.png)

验证结果：standard/test.log两项通过（五玩法双模式与四状态）；标题可用宽度补调后final-standard/test.log四状态双模式一项通过；compact/test.log最终版本两项通过。以上均0失败；gate、doc-size、diff检查通过。仅模拟器，未真机/iPad验收。

## 两侧控件对齐试版

开球移至方向条顶部，采用与击球点一致的44pt图标＋标签；按用户追加要求，方向条与力度条均固定144pt；小屏底部重打/回放改为并排，避免挤压刻度高度。三个3D观察按钮移至力度条外侧并围绕刻度区居中。右侧安全区不足48pt时，两侧控件对称内收补足空间，2D/3D保持相同仪表位置与舞台中线。

首轮构建发现替换误及非每日页相机offset，已在生成截图前还原该处；失败日志保留`build/daily-balanced-controls-20260928/standard/`。修正验证目录`r2-standard/`，增加两条刻度上下端点对齐、顶部按钮对齐、相机按钮位于力度条右侧且不越屏断言，并实际点选三种视角。

中间版r2-standard的五玩法布局通过；相机点击Dark三种视角通过，但Light重新启动后等待观察按钮超时，日志出现启动阶段多次转屏。用例增加横屏、2D状态和fixture目标球就绪条件后再点击模式开关，保留原失败，不用固定延迟重试。最终固定高度版本验证在fixed-standard/与fixed-compact/。

固定高度版本截图已目视：标准屏与SE均开球/击球点顶部对齐，方向/力度刻度上下端点一致，3D观察按钮在力度条右侧；SE重打/回放并排，没有越屏。

![固定高度3D标准屏](../../build/daily-balanced-controls-20260928/fixed-standard/camera-icons-Dark-overview.png)

![固定高度2D标准屏](../../build/daily-balanced-controls-20260928/fixed-standard/interaction-chineseEightBall-2d.png)

![固定高度SE](../../build/daily-balanced-controls-20260928/fixed-compact/camera-icons-Dark-overview.png)

最终验证：fixed-standard/test.log与fixed-compact/test.log均2项UI测试、0失败，覆盖五玩法2D/3D、固定144pt高度/上下对齐/顶部按钮对齐/相机右侧与屏幕边界，以及Dark/Light下三种观察按钮实际点击与选中状态。构建、gate、doc-size、diff检查通过。首轮失败均保留；本轮未做真机/iPad验证，待用户视觉审看，未发布。
