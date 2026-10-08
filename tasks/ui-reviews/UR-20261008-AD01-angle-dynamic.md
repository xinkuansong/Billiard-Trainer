# AD01 角度与瞄准 · 2026-10-08

用户指定在上一轮真机闪白修复后继续本页重构。实际入口为 AngleDynamicView，属于拖球／选袋的互动教学；不是角度测验，不复用出杆裁决或成绩逻辑。

## 实现与复用边界

- 从 FreePlayView 抽出实际 DailyTemplateHeader 与 DailyCarpetBackground；每日清台、分离角与走位、角度与瞄准直接使用同一份顶部、球槽和状态布局。
- 本页使用 DailyLayoutMetrics.Foundation/Palette、DailyHUDMenuPanel/DailyPanelSurface、参考渲染配置。地毯常驻，2D/3D 保留单一 AngleSceneView 实例。
- 15 个数字球槽；母球留台拖动。保留原页 2D 增减球、多障碍球、台上选择目标与目标袋、3D 拖球及四种观察语义。ViewModel 只新增参考渲染配置，未修改几何／遮挡算法。
- 五项教学读数放左侧；教学提示仍为持久状态。设置提供原本适用的视图和网格选项，深浅外观同用深色面板。未引入本页没有的击球、杆速、打点、回放或每日规则。
- 手机横屏，iPad 横竖；本轮不改变 iPad 的系统状态栏策略，系统已显示时间／电量时只补充 FPS。

## 发现与修正

1. 初次编译未收录新公共 Swift 文件；按项目流程运行 xcodegen 后重建成功，失败日志保留。
2. XCTest 自动计算顶部更多按钮的点击点失败（边框在窗口上沿外 0.2pt）；使用实际按钮中心坐标点击后菜单正常打开。本轮没有将该自动化差异解释成产品按钮不可点击，也不据此宣称 VoiceOver 已验收。
3. 初次拖动距离未超过共享拖球的 52pt 手指偏移死区，抓取发生但世界坐标未变。根据实际投影位置增加拖动距离后，坐标与读数同步变化；没有修改生产手势算法以迎合测试。
4. r01 iPad 竖屏目视发现球库与桌沿分离：旧 autoFitsRotatedTable 路径强制附加最小 scale。r02 与每日核心一致，2D 横竖都接 autoFitsLandscapeTable，由已有 rotated 分支取景。该问题由逐图检查发现，不能由 r01 测试通过推导布局正确。

## 最终证据

最终候选目录：`output/table-page-adaptation/AD01/r02/`。所有最终运行均 exit 0，完整日志、xcresult、matrix.json、source-final.json 和原图均留存。r01 与失败中间证据保留在父目录。

| 核验 | 当前结果 |
|---|---|
| Makefile build-for-testing | 成功；build-full.log |
| DailyLayoutMetricsTests ＋ AngleDiagramAnnotationTests 两项 | 26 项通过（24＋2）；unit.log |
| 标准手机浅色：testAngleDynamicObservationRoundTrip | 15 槽且无母球槽，增减三个数字球，四种观察保持读数，往返后实际拖球改变数值，无目标／重加状态；通过 |
| 标准手机深色：testAngleDynamicTemplateRotationAndGrid | 网格切换、2D/3D 与设备旋转后保留读数；手机仍按横屏策略，非手机竖屏验收；通过 |
| SE：同一 ObservationRoundTrip | 通过；小屏原图检查完成 |
| iPad：同一 TemplateRotationAndGrid | 横竖 3D、竖屏 2D、网格／菜单通过；r02 桌体取景原图检查完成 |
| 共同消费者：testP01FifteenSlotsMatchesDailyTableLayout | 每日／P01 同窗 10 项布局框一致、15 槽可触、母球不撤回；通过 |

模拟器均为 iOS/iPadOS 26.3：标准手机 874×402pt，SE 667×375pt；iPad 截图窗口横向 1210×834pt、竖向 834×1210pt。测试名称中的 portrait 在手机只表示发起旋转，不表示手机页面支持竖屏。

目视：标准机／SE 的 15 槽、六袋、五项读数无截断；共享时间电量／FPS 可见。深浅设置均为深色，网格状态与操作一致；实际拖球后切角从 28° 到 40°，其余读数同步改变。iPad 竖屏 r02 球库与桌沿恢复贴合，横竖 3D 保留原有观察相机语义。iPad 系统栏与 FPS 不重复显示时间电量。

[最终原图评审](../../output/table-page-adaptation/AD01/r02/index.html) · [执行记录](../../output/table-page-adaptation/AD01/r02/matrix.json)。最终 verify-gate、verify-doc-size、git diff --check 均通过，日志在同一目录。

## 交付边界

未安装真机、未提交／发布，未改 Figma。未执行最低 Runtime、最大辅助字号、VoiceOver 或持续性能采样；本页不以单帧模拟器图证明真机无闪白。新布局待用户体验，不沿用上一轮白屏修复的认可。
