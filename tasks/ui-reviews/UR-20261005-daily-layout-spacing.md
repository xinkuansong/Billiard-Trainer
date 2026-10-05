# 每日清台布局收紧（DR-335 r11，2026-10-05）

用户要求：球桌稍向上、球库向下贴近上方桌框、重打/回放/击球与两条标尺的间距约减半。

坐标使用SwiftUI窗口pt，x右/y下。中央stage整体上移8pt，大小和2D投影逻辑保持；球库用同一stage及已有CameraRig外框比例求上沿，胶囊下沿留2pt。3D球库保持此HUD锚点，不随透视机位漂移。动作命中尺寸保持。

改前：当前构建执行testDailyModeSwitchKeepsRendererAndTableHitCoordinates，1项通过；before-2d.png/before-3d.png为本轮实页截图。最初simctl启动因bundle名错误未启动，修正后停在横屏准备页，未用这些截图作页面基线；随后原生测试正确进入目标页。

最终本地验收通过（见下）。首次编译提示GeometryReader闭包捕获非escaping content，已修正@escaping；并非运行时失败。

证据目录：build/daily-layout-spacing-20261005。未安装真机，未提交发布。

## 中间检查与修正

标准屏after2：渲染身份/坐标测试通过；球库分组测试失败于已被生产曲面替换的shotCamera.firstPerson标识，改为同一右侧相机列真实存在的temporaryTopDown，保留列位置断言。final-standard构建及1项分组UI（四球组×双模式）通过。

像素核验：同一选择夹具的before/after 2D，台面顶部225→201px、底部1112→1088px，高度888px不变；3×屏上整体上移8pt。测量脚本结果pixel-measurements.json。

小屏final-compact：切换/点选1项通过，分组测试在两尺顶端126与122.5pt不一致处失败。原图同时发现母球球库与开球入口重叠（P2）。根因：两侧最小高度不同且HStack默认居中；小屏球库左翼超出中央球桌通道。修正为HStack顶部对齐，球库按实际横向是否重叠增加开球入口边界，不按设备名硬编码。保留失败日志与compact-first原图，修复后两尺寸复验。

## 最终验证与视觉审查

- compact-fixed.log / xcresult：Debug构建成功，667×375pt小屏两项UI全部通过（0失败）。
- standard-fixed.log / xcresult：同一构建在874×402pt标准屏两项UI全部通过（0失败，TEST EXECUTE SUCCEEDED）。总计4次测试执行、2个唯一用例。
- 每个尺寸覆盖三次2D/3D往返，同一渲染实例、2D实际stage框/3D全屏框、球位与镜头恢复、实际台面点选；四种球组×双模式的球库居中、两尺上下端点、相机按钮列与击球按钮新位置。
- 两尺寸各8张球组截图的contact已审，双模式整屏原图已打开。标准球库与桌框上沿靠拢，六袋及球桌大小保持；小屏球库保留上方位置以避让开球入口。三动作上移，文字/触控尺寸保持，两尺对齐；本轮发现的P2重叠/错位已闭合。此处不重新验收既有3D机位遮挡/画质。
- 最终标准屏像素复核与前述结果相同：台面上下沿均上移24px，台面高度888px不变。standard-final/2d.png、3d.png以及compact/2d.png、3d.png为代表图。
- 源码diff空白检查、verify-doc-size通过；本轮View差异保存在task-view.diff，工作区原有其他修改保留。未安装真机、未提交或发布；手感待用户体验。
